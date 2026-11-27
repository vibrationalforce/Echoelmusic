import EchoelCore
import EchoelDSP
import EchoelKernels
import Foundation
import XCTest
@testable import EchoelEngine

/// The self-test (test agent TA-S1, 2026-11-27): each built-in instrument and each standard effect
/// rendered offline a block at a time — a bar untimed, then a bar timed by the clock the caller
/// hands in, here a scripted one, so every time is known — and every sample it wrote checked.
final class SelfTestTests: XCTestCase {
    /// A clock the test writes: read twice a timed block, it says timed block `b` took
    /// `durations[b]` nanoseconds (from the start again when there are more blocks), and 1 µs passes
    /// between blocks.
    private final class Script {
        private let durations: [UInt64]
        private var now: UInt64 = 1_000_000_000
        /// How often the clock was read.
        private(set) var reads = 0

        init(_ durations: [UInt64]) {
            self.durations = durations
        }

        func read() -> UInt64 {
            now += reads % 2 == 1 ? durations[(reads / 2) % durations.count] : 1_000
            reads += 1
            return now
        }
    }

    /// A unit that writes what a test needs: a 440 Hz tone at `level` on both sides on the frames in
    /// `sounding` (counted from the start of the test) and silence on the others, then `poisonLeft`
    /// and `poisonRight` over the first samples of each side of every block that starts before
    /// frame `poisonedBefore`.
    private final class StandIn: SelfTestUnit {
        let name: StaticString
        private let level: Float
        private let sounding: Range<Int>
        private let poisonLeft: [Float]
        private let poisonRight: [Float]
        private let poisonedBefore: Int

        init(_ name: StaticString, level: Float, sounding: Range<Int> = 0..<Int.max, poisonLeft: [Float] = [],
             poisonRight: [Float] = [], poisonedBefore: Int = Int.max) {
            self.name = name
            self.level = level
            self.sounding = sounding
            self.poisonLeft = poisonLeft
            self.poisonRight = poisonRight
            self.poisonedBefore = poisonedBefore
        }

        func render(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            for i in 0..<frames {
                let phase: Double = 2 * Double.pi * 440 * Double(start + i) / 48_000
                let sample: Float = sounding.contains(start + i) ? level * Float(sin(phase)) : 0
                left[i] = sample
                right[i] = sample
            }
            guard start < poisonedBefore else { return }
            for (i, value) in poisonLeft.enumerated() where i < frames { left[i] = value }
            for (i, value) in poisonRight.enumerated() where i < frames { right[i] = value }
        }
    }

    /// A unit that notes, in order, what the measurement asked of it and how often the clock had
    /// been read at each step.
    private final class Witness: SelfTestUnit {
        enum Event: Equatable {
            case reset(reads: Int)
            case prepare(start: Int, reads: Int)
            case render(start: Int, reads: Int)
        }

        let name: StaticString = "witness"
        private let script: Script
        private(set) var events: [Event] = []

        init(_ script: Script) {
            self.script = script
        }

        func reset() {
            events.append(.reset(reads: script.reads))
        }

        func prepare(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            events.append(.prepare(start: start, reads: script.reads))
        }

        func render(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            events.append(.render(start: start, reads: script.reads))
            left.update(repeating: 0.5, count: frames)
            right.update(repeating: 0.5, count: frames)
        }
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("selftest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// A diagnostics log with a run begun, in a folder of its own.
    private func log() throws -> DiagnosticLog {
        let log = DiagnosticLog(url: try folder().appendingPathComponent("a.log"))
        log.begin(version: "11.0.0", build: "1")
        return log
    }

    /// The names a song stores for the built-in instruments and the standard effects, in the
    /// order the self-test plays them.
    private var storedNames: [String] {
        InstrumentDevice.builtIn.map(\.rawValue) + StandardEffect.allCases.map(\.rawValue)
    }

    /// `count` timed blocks that take 1 … `count` µs, in the scrambled order `(b × 37) % count + 1`
    /// (37 shares no factor with the counts used, so every time comes once).
    private func scrambled(_ count: Int) -> [UInt64] {
        (0..<count).map { (block: Int) -> UInt64 in UInt64((block * 37) % count + 1) * 1_000 }
    }

    // MARK: - Time

    /// Timed blocks that take 1 … N µs in a scrambled order: the median and the 99th percentile are
    /// nearest ranks — the smallest time with at least half, or 99 %, of the blocks at or below
    /// it — so both are times a block really took. Where the rank is not whole it is rounded up:
    /// the median of 101 is the 51st, the 99th percentile of 101 the 100th and of 150 the 149th
    /// (148.5); rounded down they would be the 50th, the 99th and the 148th.
    func testTheMedianAndThe99thPercentileAreNearestRanks() {
        for (count, median, percentile99) in [(100, 50, 99), (101, 51, 100), (150, 75, 149)] {
            let script = Script(scrambled(count))
            let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: count)
            let measured = test.measure(StandIn("tone", level: 0.5), clock: script.read)
            XCTAssertEqual(measured.blocks, count)
            XCTAssertEqual(measured.median, UInt64(median) * 1_000, "median of \(count)")
            XCTAssertEqual(measured.percentile99, UInt64(percentile99) * 1_000, "99th percentile of \(count)")
            XCTAssertEqual(script.reads, 2 * count, "two readings a timed block")
        }
    }

    /// At 48 kHz in blocks of 256 a block lasts 5⅓ ms. Two blocks of 6 ms among 198 of 1 ms are the
    /// slowest hundredth: the 99th percentile — the 198th of 200 — stays at 1 ms and the unit is
    /// in time, although its slowest blocks were not; a third slow block is inside the hundredth,
    /// and the unit is late.
    func testThe99thPercentileLeavesOutTheSlowestHundredth() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 200)
        var durations = [UInt64](repeating: 1_000_000, count: 200)
        durations[17] = 6_000_000
        durations[160] = 6_000_000
        let two = test.measure(StandIn("tone", level: 0.5), clock: Script(durations).read)
        XCTAssertEqual(two.median, 1_000_000)
        XCTAssertEqual(two.percentile99, 1_000_000)
        XCTAssertEqual(two.percentile99Load, 0.1875)
        XCTAssertFalse(two.isOverBudget, "the two slowest blocks are left out")
        durations[90] = 6_000_000
        let three = test.measure(StandIn("tone", level: 0.5), clock: Script(durations).read)
        XCTAssertEqual(three.median, 1_000_000)
        XCTAssertEqual(three.percentile99, 6_000_000)
        XCTAssertTrue(three.isOverBudget)
    }

    /// The loads, the verdict, the log and the summary each read the right one of the numbers: at
    /// 48 kHz in blocks of 256 (5⅓ ms), 196 blocks of 1 ms and 4 of 6 ms put the median at 1 ms,
    /// 0.1875 of the budget, the 99th percentile at 6 ms, 1.125 of it, and the mean at 1.1 ms,
    /// 0.20625 of it — a unit that is late although its median is far inside its budget.
    func testTheLoadsTheVerdictAndTheLogEachReadTheRightNumber() throws {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 200)
        var durations = [UInt64](repeating: 1_000_000, count: 200)
        for block in [3, 77, 150, 199] { durations[block] = 6_000_000 }
        let measured = test.measure(StandIn("late", level: 0.5), clock: Script(durations).read)
        XCTAssertEqual(measured.median, 1_000_000)
        XCTAssertEqual(measured.percentile99, 6_000_000)
        XCTAssertEqual(measured.mean, 1_100_000)
        XCTAssertEqual(measured.medianLoad, 0.1875)
        XCTAssertEqual(measured.percentile99Load, 1.125)
        XCTAssertEqual(measured.meanLoad, 0.206_25, accuracy: 1e-15)
        XCTAssertTrue(measured.isOverBudget, "the 99th percentile decides, not the median or the mean")

        let result = SelfTest.Result(test, [measured])
        XCTAssertEqual(result.overBudget, 1)
        XCTAssertEqual(result.highestLoad, 1.125)
        let diagnostics = try log()
        result.write(to: diagnostics)
        let lines = DiagnosticReport(log: diagnostics.text()).lines
        let unit = try XCTUnwrap(lines.first { $0.event == "selftest: unit" })
        XCTAssertEqual(unit.number("median_us"), 1_000)
        XCTAssertEqual(unit.number("p99_us"), 6_000)
        XCTAssertEqual(unit.number("mean_us"), 1_100)
        XCTAssertEqual(unit.number("median_load"), 0.188, "0.1875 to three places")
        XCTAssertEqual(unit.number("p99_load"), 1.125)
        XCTAssertEqual(unit.number("mean_load"), 0.206, "0.20625 to three places")
        let summary = try XCTUnwrap(lines.first { $0.event == "selftest: summary" })
        XCTAssertEqual(summary.number("over_budget"), 1)
        XCTAssertEqual(summary.number("highest_p99_load"), 1.125, "the highest 99th percentile, not the highest median")
    }

    /// A unit whose blocks alternate between light and heavy — as a pitch tracker that analyses
    /// every other block makes them — has its median on whichever kind has the one block more, and
    /// a mean that hardly moves: 51 blocks of 1 µs and 50 of 61 µs put the median at 1 µs and the
    /// mean at 30.70 µs, 50 and 51 put the median at 61 µs and the mean at 31.30 µs.
    func testTheMeanHoldsWhereTheMedianFallsBetweenTwoKindsOfBlock() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 101)
        let lightFirst = (0..<101).map { (block: Int) -> UInt64 in block % 2 == 0 ? 1_000 : 61_000 }
        let heavyFirst = (0..<101).map { (block: Int) -> UInt64 in block % 2 == 0 ? 61_000 : 1_000 }
        let light = test.measure(StandIn("tone", level: 0.5), clock: Script(lightFirst).read)
        let heavy = test.measure(StandIn("tone", level: 0.5), clock: Script(heavyFirst).read)
        XCTAssertEqual(light.median, 1_000)
        XCTAssertEqual(heavy.median, 61_000)
        XCTAssertEqual(light.mean, 3_101_000.0 / 101)
        XCTAssertEqual(heavy.mean, 3_161_000.0 / 101)
        XCTAssertEqual(light.percentile99, 61_000)
        XCTAssertEqual(heavy.percentile99, 61_000)
    }

    /// A unit starts over before its first block, plays its warm-up with no clock read at all, and
    /// then each timed block is read twice, around its render alone: the input before it and the
    /// check of what it wrote after it are not timed. The blocks follow on from each other.
    func testTheClockIsReadOnlyAroundTheRenderOfATimedBlock() {
        let script = Script([2_000])
        let witness = Witness(script)
        let test = SelfTest(sampleRate: 48_000, blockFrames: 4_096, blocks: 5)
        XCTAssertEqual(test.warmUpBlocks, 24, "2 s at 48 kHz is 23.4 blocks of 4,096, rounded up")
        _ = test.measure(witness, clock: script.read)
        var expected: [Witness.Event] = [.reset(reads: 0)]
        for block in 0..<24 {
            expected += [.prepare(start: block * 4_096, reads: 0), .render(start: block * 4_096, reads: 0)]
        }
        for block in 0..<5 {
            let start = (24 + block) * 4_096
            expected += [.prepare(start: start, reads: 2 * block), .render(start: start, reads: 2 * block + 1)]
        }
        XCTAssertEqual(witness.events, expected)
        XCTAssertEqual(script.reads, 10)
    }

    /// A run plays one bar untimed and times one more, in whole blocks at any rate and block size:
    /// 2 s is 375 blocks of 256 at 48 kHz, 344.5 rounded up to 345 at 44.1 kHz, 750 at 96 kHz and
    /// 23.4 rounded up to 24 blocks of 4,096 — the fewest blocks that last the bar. A number of timed
    /// blocks the caller names replaces the second bar, never the first; and where a bar takes more
    /// blocks than a unit keeps times for — at 96 kHz in blocks of one frame — the timed blocks
    /// stop at the most.
    func testARunPlaysABarUntimedAndTimesOneMore() {
        let settings: [(Double, Int, Int)] = [(48_000, 256, 375), (44_100, 256, 345), (96_000, 256, 750),
                                              (48_000, 4_096, 24), (44_100, 128, 690), (96_000, 64, 3_000)]
        for (rate, frames, bar) in settings {
            let test = SelfTest(sampleRate: rate, blockFrames: frames)
            XCTAssertEqual(test.warmUpBlocks, bar, "\(frames) frames at \(rate) Hz")
            XCTAssertEqual(test.blocks, bar, "\(frames) frames at \(rate) Hz")
            XCTAssertGreaterThanOrEqual(Double(bar * frames), SelfTest.barSeconds * rate, "the blocks last the bar")
            XCTAssertLessThan(Double((bar - 1) * frames), SelfTest.barSeconds * rate, "and one fewer would not")
            let short = SelfTest(sampleRate: rate, blockFrames: frames, blocks: 7)
            XCTAssertEqual(short.warmUpBlocks, bar, "the warm-up stays a bar")
            XCTAssertEqual(short.blocks, 7)
        }
        let tiny = SelfTest(sampleRate: 96_000, blockFrames: 1)
        XCTAssertEqual(tiny.warmUpBlocks, 192_000)
        XCTAssertEqual(tiny.blocks, SelfTest.maximumBlocks)
    }

    /// A block's budget is the time its frames last, frames ÷ rate. Where that is a whole number of
    /// nanoseconds the shares come out exact: 480 frames at 48 kHz, 441 at 44.1 kHz and 960 at
    /// 96 kHz each last 10 ms, and 5 ms of render is half of it, 10 ms all of it.
    func testTheBudgetIsTheTimeABlocksFramesLast() {
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 256).budgetSeconds, 256.0 / 48_000)
        for (rate, frames) in [(48_000.0, 480), (44_100, 441), (96_000, 960)] {
            let test = SelfTest(sampleRate: rate, blockFrames: frames, blocks: 10)
            XCTAssertEqual(test.budgetSeconds, 0.01, "\(frames) frames at \(rate) Hz")
            let half = test.measure(StandIn("tone", level: 0.5), clock: Script([5_000_000]).read)
            XCTAssertEqual(half.budgetSeconds, 0.01)
            XCTAssertEqual(half.medianLoad, 0.5)
            XCTAssertEqual(half.percentile99Load, 0.5)
            XCTAssertFalse(half.isOverBudget)
            let whole = test.measure(StandIn("tone", level: 0.5), clock: Script([10_000_000]).read)
            XCTAssertEqual(whole.percentile99Load, 1)
            XCTAssertFalse(whole.isOverBudget, "the whole budget is still in time")
        }
    }

    /// Over is over by a nanosecond: 256 frames at 48 kHz last 5,333,333⅓ ns, so a block of
    /// 5,333,333 ns is in time and one of 5,333,334 ns is not — compared without rounding.
    func testABlockOverItsBudgetByANanosecondIsOver() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 4)
        let inTime = test.measure(StandIn("tone", level: 0.5), clock: Script([5_333_333]).read)
        XCTAssertFalse(inTime.isOverBudget)
        XCTAssertLessThan(inTime.percentile99Load, 1)
        let late = test.measure(StandIn("tone", level: 0.5), clock: Script([5_333_334]).read)
        XCTAssertTrue(late.isOverBudget)
        XCTAssertGreaterThan(late.percentile99Load, 1)
        let tenMs = SelfTest(sampleRate: 44_100, blockFrames: 441, blocks: 4)
        XCTAssertTrue(tenMs.measure(StandIn("tone", level: 0.5), clock: Script([10_000_001]).read).isOverBudget)
    }

    // MARK: - Sound

    /// A unit that writes a not-a-number and two infinities into every block is counted sample by
    /// sample, in the warm-up as in the timed blocks, and so are its samples past full scale; full
    /// scale itself is not past it. One not-a-number on the test's first frame, before any clock
    /// runs, is counted too.
    func testNotANumberAndInfinityAreCountedSampleBySample() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 20)
        let played = test.warmUpBlocks + test.blocks
        XCTAssertEqual(played, 395)
        let poisoned = StandIn("poisoned", level: 0.5, poisonLeft: [.nan, 0.25, -.infinity, 0.25, -1.25, 1],
                               poisonRight: [0.25, .infinity, 0.25, 1.5, 0.25, -1])
        let measured = test.measure(poisoned, clock: Script([1_000]).read)
        XCTAssertEqual(measured.nonFinite, 3 * played)
        XCTAssertEqual(measured.overFullScale, 2 * played)
        XCTAssertFalse(measured.isSilent, "the tone around the poison sounds")
        let early = test.measure(StandIn("early", level: 0.5, poisonLeft: [.nan], poisonedBefore: 1),
                                 clock: Script([1_000]).read)
        XCTAssertEqual(early.nonFinite, 1, "the warm-up's samples are checked")
        XCTAssertEqual(early.overFullScale, 0)
    }

    /// A unit that writes only silence, only not-a-number, or a sound below −100 dBFS has sounded
    /// nothing; one at −90 dBFS has.
    func testAUnitThatSoundsNothingIsSilent() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 128, blocks: 8)
        let quiet = test.measure(StandIn("quiet", level: 0), clock: Script([1_000]).read)
        XCTAssertTrue(quiet.isSilent)
        XCTAssertEqual(quiet.nonFinite, 0)
        let broken = test.measure(StandIn("broken", level: 0, poisonLeft: Array(repeating: .nan, count: 128),
                                          poisonRight: Array(repeating: .nan, count: 128)), clock: Script([1_000]).read)
        XCTAssertTrue(broken.isSilent, "not a number is not sound")
        XCTAssertEqual(broken.nonFinite, 128 * 2 * (test.warmUpBlocks + test.blocks))
        XCTAssertTrue(test.measure(StandIn("faint", level: 3e-6), clock: Script([1_000]).read).isSilent, "−110 dBFS")
        XCTAssertFalse(test.measure(StandIn("low", level: 3e-5), clock: Script([1_000]).read).isSilent, "−90 dBFS")
    }

    /// A unit that sounds through its warm-up and then falls silent is silent, and so is one that
    /// sounds only once its clock runs: every part sounds through both. A few frames of sound on
    /// each side of the clock's start are enough.
    func testAUnitSilentInItsWarmUpOrInItsTimedBlocksIsSilent() {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 10)
        let clockStarts = test.warmUpBlocks * 256
        let fallsSilent = StandIn("falls silent", level: 0.5, sounding: 0..<clockStarts)
        XCTAssertTrue(test.measure(fallsSilent, clock: Script([1_000]).read).isSilent, "silent once timed")
        let startsLate = StandIn("starts late", level: 0.5, sounding: clockStarts..<Int.max)
        XCTAssertTrue(test.measure(startsLate, clock: Script([1_000]).read).isSilent, "silent in the warm-up")
        let both = StandIn("both", level: 0.5, sounding: (clockStarts - 10)..<(clockStarts + 10))
        XCTAssertFalse(test.measure(both, clock: Script([1_000]).read).isSilent)
    }

    // MARK: - The built-in units

    /// The units are the built-in instruments and then every standard effect, each named as a song
    /// stores it — the name the log writes, never one a musician typed.
    func testTheUnitsAreTheBuiltInInstrumentsAndTheStandardEffectsByTheirStoredNames() {
        let units = SelfTest(sampleRate: 48_000, blockFrames: 256).units()
        XCTAssertEqual(units.map { $0.name.description }, storedNames)
        for effect in StandardEffect.allCases {
            XCTAssertEqual(SelfTest.name(of: effect).description, effect.rawValue)
        }
        for device in InstrumentDevice.allCases {
            XCTAssertEqual(SelfTest.name(of: device)?.description, InstrumentDevice.builtIn.contains(device) ? device.rawValue : nil)
        }
    }

    /// Every built-in unit renders whole at 44.1, 48 and 96 kHz in 256-frame blocks: no value that
    /// is not a number, none past full scale, and never silent — over the run the app makes, a bar
    /// untimed and a bar timed, so the kit strikes all eight pieces twice and the chords change on
    /// each of the 32 sixteenths.
    func testEveryBuiltInUnitRendersWholeAtTheThreeRates() {
        for rate in [44_100.0, 48_000, 96_000] {
            let test = SelfTest(sampleRate: rate, blockFrames: 256)
            let bar = Int((SelfTest.barSeconds * rate / 256).rounded(.up))
            var now: UInt64 = 0
            let result = test.run(clock: {
                now += 1_000
                return now
            })
            XCTAssertEqual(result.measurements.map(\.unit), storedNames)
            for measured in result.measurements {
                XCTAssertEqual(measured.sampleRate, rate)
                XCTAssertEqual(measured.blockFrames, 256)
                XCTAssertEqual(measured.warmUpBlocks, bar)
                XCTAssertEqual(measured.blocks, bar)
                XCTAssertEqual(measured.nonFinite, 0, "\(measured.unit) at \(rate) Hz")
                XCTAssertEqual(measured.overFullScale, 0, "\(measured.unit) at \(rate) Hz")
                XCTAssertFalse(measured.isSilent, "\(measured.unit) at \(rate) Hz")
                XCTAssertEqual(measured.median, 1_000, "the scripted clock: 1 µs a block")
            }
            XCTAssertEqual(result.nonFinite, 0)
            XCTAssertEqual(result.overFullScale, 0)
            XCTAssertEqual(result.silent, 0)
            XCTAssertEqual(result.overBudget, 0)
        }
    }

    /// A bar of the beat strikes every piece of the kit, and the warm-up and the timed blocks each
    /// hold a whole bar at every rate and block size — so a run strikes all eight pieces before its
    /// clock starts and all eight again while it runs.
    func testEveryRunStrikesEveryPieceOfTheKitBeforeAndWhileItIsTimed() throws {
        let kit = Set(DrumKit.Piece.allCases)
        let settings: [(Double, Int)] = [(44_100, 256), (48_000, 256), (96_000, 256), (48_000, 128), (96_000, 4_096), (44_100, 1)]
        for (rate, frames) in settings {
            let test = SelfTest(sampleRate: rate, blockFrames: frames)
            let unit = try XCTUnwrap(SelfTest.InstrumentUnit(.drums, test: test))
            let clockStarts = test.warmUpBlocks * frames
            let spans = [("warm-up", unit.steps(start: 0, frames: clockStarts)),
                         ("timed", unit.steps(start: clockStarts, frames: test.blocks * frames))]
            for (span, steps) in spans {
                var struck = Set<DrumKit.Piece>()
                for step in steps {
                    unit.forEachNote(of: step) { _, note, _ in
                        if let piece = DrumKit.Piece.forPitch(note) { struck.insert(piece) }
                    }
                }
                XCTAssertEqual(struck, kit, "\(span) at \(rate) Hz in blocks of \(frames)")
                XCTAssertGreaterThanOrEqual(steps.count, 16, "\(span): a whole bar of sixteenths")
            }
        }
    }

    /// The chords hand over without a gap and without a stuck note: each change releases exactly the
    /// chord that sounded and starts the next, so after every step eight notes are held — C, then
    /// F, then C again.
    func testEachChordEndsWhereTheNextBegins() throws {
        let unit = try XCTUnwrap(SelfTest.InstrumentUnit(.synth, test: SelfTest(sampleRate: 48_000, blockFrames: 256)))
        let first: Set<UInt8> = [36, 48, 55, 59, 64, 67, 71, 76]
        let second: Set<UInt8> = [41, 53, 60, 64, 69, 72, 76, 81]
        var held: [UInt8: Int] = [:]
        for step in 0..<9 {
            unit.forEachNote(of: step) { status, note, _ in
                held[note, default: 0] += status == 0x90 ? 1 : -1
            }
            let sounding = Set(held.filter { $0.value > 0 }.keys)
            XCTAssertEqual(sounding, step % 2 == 0 ? first : second, "after step \(step)")
            XCTAssertTrue(held.values.allSatisfy { $0 == 0 || $0 == 1 }, "no note struck twice or released unheld")
        }
    }

    /// An instrument's part, cut into blocks: every step falls in exactly one block — the one that
    /// holds its frame — in order, at 44.1 kHz too, where a sixteenth is 5,512.5 frames; and the
    /// same block asked for again holds the same steps, so a unit measured twice plays its part twice.
    func testEveryStepOfAPartFallsInTheBlockThatHoldsItsFrame() throws {
        let parts: [(InstrumentDevice, Double)] = [(.drums, 44_100), (.drums, 96_000), (.synth, 48_000)]
        for (device, rate) in parts {
            let unit = try XCTUnwrap(SelfTest.InstrumentUnit(device, test: SelfTest(sampleRate: rate, blockFrames: 256)))
            var played: [Int] = []
            for block in 0..<Int(4.2 * rate / 256) {
                let start = block * 256
                let due = unit.steps(start: start, frames: 256)
                for step in due {
                    XCTAssertTrue((start..<start + 256).contains(unit.frame(of: step)), "step \(step) in block \(block)")
                }
                played += Array(due)
            }
            let expected = Array(0..<played.count)
            XCTAssertEqual(played, expected, "\(device.rawValue) at \(rate) Hz: each step once, in order")
            XCTAssertGreaterThan(played.count, 32, "the part ran on past its second bar")
            XCTAssertEqual(unit.steps(start: 0, frames: 256), 0..<1, "the first block holds the first step again")
        }
    }

    /// A rate outside the engine's runs at 48 kHz, as an export does; a block holds 1 … 4,096
    /// frames, and a unit is timed for 1 … `maximumBlocks` blocks — a bar unless the caller names
    /// a number.
    func testARateOrABlockSizeOutsideTheEnginesIsHeldInIt() {
        XCTAssertEqual(SelfTest(sampleRate: .nan, blockFrames: 256).sampleRate, 48_000)
        XCTAssertEqual(SelfTest(sampleRate: 0, blockFrames: 256).sampleRate, 48_000)
        XCTAssertEqual(SelfTest(sampleRate: 10_000_000, blockFrames: 256).sampleRate, 48_000)
        XCTAssertEqual(SelfTest(sampleRate: 44_100, blockFrames: 256).sampleRate, 44_100)
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 0).blockFrames, 1)
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 1_000_000).blockFrames, EngineCore.maximumFrames)
        XCTAssertEqual(SelfTest(sampleRate: .nan, blockFrames: 256).blocks, 375, "a bar at the 48 kHz it runs at")
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: -3).blocks, 1)
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 0).blocks, 1)
        XCTAssertEqual(SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: Int.max).blocks, SelfTest.maximumBlocks)
    }

    // MARK: - The log

    /// A run writes one line per unit — `selftest: unit`, the unit's stored name, its numbers — and
    /// one summary, in the log's own shape, so the report reads them as it reads every other line.
    func testTheLogGetsALinePerUnitAndOneSummaryInFixedWords() throws {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 256, blocks: 8)
        var now: UInt64 = 0
        let result = test.run(clock: {
            now += 2_000
            return now
        })
        let diagnostics = try log()
        let written = result.write(to: diagnostics)
        XCTAssertEqual(written.count, storedNames.count + 1)

        let report = DiagnosticReport(log: diagnostics.text())
        let units = report.lines.filter { $0.event == "selftest: unit" }
        XCTAssertEqual(units.map(\.reason), storedNames.map { Optional($0) })
        let names = ["Hz", "frames", "warmup_blocks", "blocks", "budget_us", "median_us", "p99_us", "mean_us",
                     "median_load", "p99_load", "mean_load", "nonfinite", "over0db", "silent"]
        for line in units {
            XCTAssertEqual(Set(line.fields.keys), Set(names), line.text)
            for name in names { XCTAssertNotNil(line.number(name), "\(name) in \(line.text)") }
            XCTAssertEqual(line.number("Hz"), 48_000)
            XCTAssertEqual(line.number("frames"), 256)
            XCTAssertEqual(line.number("warmup_blocks"), 375)
            XCTAssertEqual(line.number("blocks"), 8)
            XCTAssertEqual(line.number("budget_us"), 5_333.333, "256 frames at 48 kHz, to the nanosecond")
            XCTAssertEqual(line.number("median_us"), 2, "2 µs a block on the scripted clock")
            XCTAssertEqual(line.number("p99_us"), 2)
            XCTAssertEqual(line.number("mean_us"), 2)
            XCTAssertEqual(line.number("nonfinite"), 0)
            XCTAssertEqual(line.number("silent"), 0)
        }
        let first = try XCTUnwrap(units.first)
        let line = try XCTUnwrap(written.first)
        XCTAssertTrue(line.hasPrefix("selftest: unit (synth) Hz=48000 frames=256 warmup_blocks=375 blocks=8 budget_us=5333.333 "), line)
        XCTAssertTrue(first.text.hasSuffix("  " + line), "the file holds the line as written, after its time")

        let summaries = report.lines.filter { $0.event == "selftest: summary" }
        XCTAssertEqual(summaries.count, 1)
        let summary = try XCTUnwrap(summaries.first)
        XCTAssertNil(summary.reason)
        XCTAssertEqual(summary.number("units"), Double(storedNames.count))
        XCTAssertEqual(summary.number("Hz"), 48_000)
        XCTAssertEqual(summary.number("warmup_blocks"), 375)
        XCTAssertEqual(summary.number("blocks"), 8)
        XCTAssertEqual(summary.number("over_budget"), 0)
        XCTAssertEqual(summary.number("nonfinite"), 0)
        XCTAssertEqual(summary.number("silent"), 0)
        XCTAssertNotNil(summary.number("over0db"))
        XCTAssertNotNil(summary.number("highest_p99_load"))
        XCTAssertEqual(report.lines.last?.event, "selftest: summary", "the summary closes the run")
    }

    /// The summary counts units, one for each fault however many samples it has: a unit that is
    /// late, one with a value that is not a number, one past full scale, one silent — and the
    /// highest 99th percentile any unit had.
    func testTheSummaryCountsTheUnitsWithEachFault() throws {
        let test = SelfTest(sampleRate: 48_000, blockFrames: 480, blocks: 10)
        let late = test.measure(StandIn("late", level: 0.5), clock: Script([15_000_000]).read)
        let poisoned = test.measure(StandIn("poisoned", level: 0.5, poisonLeft: [.nan, .nan]), clock: Script([1_000]).read)
        let loud = test.measure(StandIn("loud", level: 1.5), clock: Script([1_000]).read)
        let quiet = test.measure(StandIn("quiet", level: 0), clock: Script([1_000]).read)
        let fine = test.measure(StandIn("fine", level: 0.5), clock: Script([2_500_000]).read)
        let result = SelfTest.Result(test, [late, poisoned, loud, quiet, fine])
        XCTAssertEqual(result.overBudget, 1)
        XCTAssertEqual(result.nonFinite, 1)
        XCTAssertEqual(result.overFullScale, 1)
        XCTAssertEqual(result.silent, 1)
        XCTAssertEqual(result.highestLoad, 1.5, "15 ms of a 10 ms budget")

        let diagnostics = try log()
        result.write(to: diagnostics)
        let lines = DiagnosticReport(log: diagnostics.text()).lines
        let summary = try XCTUnwrap(lines.first { $0.event == "selftest: summary" })
        XCTAssertEqual(summary.number("units"), 5)
        XCTAssertEqual(summary.number("over_budget"), 1)
        XCTAssertEqual(summary.number("nonfinite"), 1)
        XCTAssertEqual(summary.number("over0db"), 1)
        XCTAssertEqual(summary.number("silent"), 1)
        XCTAssertEqual(summary.number("highest_p99_load"), 1.5)
        let unit = try XCTUnwrap(lines.first { $0.reason == "poisoned" })
        XCTAssertEqual(unit.number("nonfinite"), 420, "two a block, over 200 warm-up blocks and 10 timed")
        XCTAssertEqual(lines.first { $0.reason == "late" }?.number("p99_load"), 1.5)
        XCTAssertEqual(lines.first { $0.reason == "fine" }?.number("median_load"), 0.25)
        XCTAssertEqual(lines.first { $0.reason == "quiet" }?.number("silent"), 1)
    }
}

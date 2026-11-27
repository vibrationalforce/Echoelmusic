import EchoelCore
import EchoelDSP
import EchoelKernels
import Foundation

/// One unit the self-test plays (`SelfTest`), a block at a time.
public protocol SelfTestUnit: AnyObject {
    /// The unit's name in the log: the name a song stores for it (`InstrumentDevice`,
    /// `StandardEffect`). A `StaticString`, as `DiagnosticLog` takes it, so only a name written in
    /// the source reaches the file — never one a musician typed.
    var name: StaticString { get }
    /// Before the first block, not timed: the unit starts over from silence, so nothing an earlier
    /// measurement left ringing carries into this one.
    func reset()
    /// Before the block's clock starts: what lies in `left` and `right` when the block begins — an
    /// effect's input. Not timed.
    func prepare(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>)
    /// The block: `frames` frames from `start` frames into the test, written over `left` and
    /// `right` — timed once the warm-up is over. Under the render thread's rules: no lock, no
    /// allocation, no file I/O, no GCD, no log.
    func render(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>)
}

extension SelfTestUnit {
    /// A unit that keeps nothing from one block to the next has nothing to start over.
    public func reset() {}
    /// An instrument plays from silence: nothing goes in.
    public func prepare(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {}
}

/// The self-test (test agent TA-S1, 2026-11-27): how long this device takes to render a block of
/// each built-in instrument and each standard effect, against the time the block lasts, and
/// whether the sound came out whole — no value that is not a number, none past full scale, and not
/// silent while a part plays. No test measures audio latency; this narrows the gap by measuring the
/// compute time on this very device. The latency the hardware adds it does not measure.
///
/// It renders offline into buffers of its own: nothing reaches the output and no song is read; the
/// app starts it only while the song is stopped (TA-S2). Each unit is made as the engine makes it —
/// an instrument by `BuiltInKernels`, an effect as an `EffectKernel` at its defaults — and plays a
/// fixed part (`Part`, `signal`): the synth and the sampler chords of eight notes that change on
/// every sixteenth at 120 BPM and keep all sixteen voices sounding (the sampler from a tone made
/// for the test), the drums a bar of sixteenths that strikes all eight pieces, each effect a tone
/// with a little noise.
///
/// A run is measured in time, not in blocks. Each unit starts from silence and first plays one bar
/// (`barSeconds`) untimed: its part plays and every sample is checked, but no time is kept, so its
/// voices and tails reach the state they stay in while the part goes on. Then it is timed for one
/// more bar, which plays the whole bar again. Both are rounded up to whole blocks, so at any rate
/// and any block size a run plays the same music for the same time, and its numbers come from the
/// part as it goes on rather than from its first notes: measured 2026-11-27 (Linux, release build,
/// the least disturbed of five runs each), every unit's mean came out within 4 % of a run timed
/// for eight seconds, at 44.1, 48 and 96 kHz in blocks of 256 and at 44.1 kHz in blocks of 128.
/// So two devices, two builds or two rates compare by their loads, as far as the machine was
/// quiet (below). A caller may name a number of timed blocks instead of the bar — a test's short
/// run; the warm-up stays a bar.
///
/// A block is timed by the clock the caller hands in — monotonic, in nanoseconds; a test hands in a
/// fake one. The clock is read twice a timed block, around the unit's render alone: the input
/// before it and the check of what it wrote after it are not timed. Each unit reports three figures
/// for its blocks: the median, the typical block; the mean, the share of the device the unit takes
/// while it plays; and the 99th percentile, which decides whether it is late (`isOverBudget`) —
/// not the slowest block, because the test runs on an ordinary thread, which the system may stop
/// at any moment, so the slowest blocks tell more about the system than about the unit. Where a
/// unit's work comes in a cycle of blocks the median falls on whichever kind of block has a few
/// more, and the mean holds. Pitch correction and the harmonizer listen through a pitch tracker
/// that analyses every 256 samples at 44.1 and 48 kHz and every 512 at 96 kHz, so in blocks of
/// 128, or of 256 at 96 kHz, every other block holds an analysis: three runs of the harmonizer at
/// 44.1 kHz in blocks of 128, the same part each time, gave medians of 2.6, 16.5 and 19.7 µs and
/// means of 26.6 to 26.7 µs (measured 2026-11-27).
///
/// On a busy system the wall clock carries the system's stops even into the 99th percentile, and
/// the thread's own CPU time (`CLOCK_THREAD_CPUTIME_ID`) leaves them out. Measured 2026-11-27
/// (Linux, release build, four cores shared with other builds): with sixteen compilers running,
/// the wall clock put the multiband clipper's 99th percentile at 4.1 ms against a median of 69 µs
/// (runs of 200 blocks) and the thread's CPU time did not; at a load of about four, neither clock
/// put a unit near its budget — the highest 99th percentile came to 7 % of it on the wall clock and
/// to 5 % on the thread's CPU time. The thread's CPU time does not leave out a core the thread
/// shares or a slower clock speed: the synth's median at 44.1 kHz in blocks of 256 came to 41.0 µs
/// in three runs and to 74.5 µs in a fourth, timed for eight seconds, while other work ran. Which
/// clock the app hands in, how fine a thread's CPU time is on a device, and how quiet the device
/// is while the test runs, the app's slice measures (TA-S2).
///
/// Main thread or a background task, never the render thread: making the units and the buffers
/// allocates. The measured loop does not: it calls the units' render, the clock and arithmetic on
/// buffers made before it, as the render thread would. Measured 2026-11-27 (Linux, release build, a
/// count of every heap call from the reset before the warm-up to the last reading of the clock,
/// for each unit at 44.1, 48 and 96 kHz in blocks of 1, 64, 256 and 4,096 frames): none, where the
/// same count saw the 2,421 heap calls that making the units takes. A debug build allocates inside
/// the instruments' kernels — `activeVoiceCount`, a `reduce` the unoptimised build does not
/// specialise, once per voice per call — as the engine's own render does in a debug build; the app
/// ships release builds.
public struct SelfTest: Sendable {
    /// One bar of the parts, 4/4 at 120 BPM: sixteen sixteenths. A unit plays one bar before its
    /// clock starts and is timed for one more.
    public static let barSeconds: Double = 2
    /// The most blocks one unit is timed for: the time of every block is kept until the unit ends.
    /// A bar takes fewer blocks than that at any rate up to 48 kHz, and at any rate in blocks of 16
    /// frames or more.
    public static let maximumBlocks = 100_000

    public let sampleRate: Double
    public let blockFrames: Int
    /// The blocks a unit plays before its clock starts: one bar, rounded up to whole blocks.
    public let warmUpBlocks: Int
    /// The blocks a unit is timed for: one more bar, rounded up, unless the caller names a number.
    public let blocks: Int

    /// A rate outside the engine's runs at 48 kHz, as an export does (`OfflineRender`); a block
    /// holds 1 … `EngineCore.maximumFrames` frames, the most the engine renders at once. `blocks`
    /// names the timed blocks, 1 … `maximumBlocks`; nil times one bar.
    public init(sampleRate: Double, blockFrames: Int, blocks: Int? = nil) {
        let rate = sampleRate.isFinite && OfflineRender.rates.contains(sampleRate) ? sampleRate : 48_000
        let frames = Swift.min(Swift.max(blockFrames, 1), EngineCore.maximumFrames)
        let bar = Self.blockCount(lasting: Self.barSeconds, sampleRate: rate, blockFrames: frames)
        self.sampleRate = rate
        self.blockFrames = frames
        warmUpBlocks = bar
        self.blocks = Swift.min(Swift.max(blocks ?? bar, 1), Self.maximumBlocks)
    }

    /// The time one block lasts, `blockFrames ÷ sampleRate`: what its render must stay within.
    public var budgetSeconds: Double { Double(blockFrames) / sampleRate }

    /// The fewest whole blocks of `blockFrames` that last `seconds` at `sampleRate`. When the time
    /// is a whole number of frames, as two seconds at a rate of whole hertz is, the quotient's
    /// fraction is a multiple of 1 ÷ `blockFrames`, far above the rounding of a `Double` this size,
    /// so rounding it up is exact.
    static func blockCount(lasting seconds: Double, sampleRate: Double, blockFrames: Int) -> Int {
        Int((seconds * sampleRate / Double(blockFrames)).rounded(.up))
    }

    // MARK: - The units

    /// Every unit the self-test plays, in the order the log lists them: the built-in instruments
    /// (`InstrumentDevice.builtIn`), then the standard effects (`StandardEffect.allCases`), each
    /// made at `sampleRate` for blocks of `blockFrames`. Allocates.
    public func units() -> [any SelfTestUnit] {
        var made: [any SelfTestUnit] = []
        for device in InstrumentDevice.builtIn {
            if let unit = InstrumentUnit(device, test: self) { made.append(unit) }
        }
        for effect in StandardEffect.allCases { made.append(EffectUnit(effect, test: self)) }
        return made
    }

    /// The name a song stores for a built-in device, written out as a `StaticString` — a raw value
    /// is a `String`, and the log takes only text written in the source. Nil for a device the
    /// self-test does not play (a plugin, an instrument from a later build).
    static func name(of device: InstrumentDevice) -> StaticString? {
        switch device {
        case .synth: "synth"
        case .drums: "drums"
        case .sampler: "sampler"
        case .plugin, .unrecognized: nil
        }
    }

    /// The name a song stores for a standard effect, written out as a `StaticString` (see above).
    static func name(of effect: StandardEffect) -> StaticString {
        switch effect {
        case .equalizer: "equalizer"
        case .compressor: "compressor"
        case .delay: "delay"
        case .reverb: "reverb"
        case .chorus: "chorus"
        case .phaser: "phaser"
        case .flanger: "flanger"
        case .limiter: "limiter"
        case .saturation: "saturation"
        case .tremolo: "tremolo"
        case .bitcrusher: "bitcrusher"
        case .tape: "tape"
        case .stereoWidth: "stereoWidth"
        case .ringModulator: "ringModulator"
        case .frequencyShifter: "frequencyShifter"
        case .pitchCorrection: "pitchCorrection"
        case .harmonizer: "harmonizer"
        case .granular: "granular"
        case .formantFilter: "formantFilter"
        case .transientDesigner: "transientDesigner"
        case .midSide: "midSide"
        case .multibandCompressor: "multibandCompressor"
        case .dynamicEQ: "dynamicEQ"
        case .multibandClipper: "multibandClipper"
        case .deEsser: "deEsser"
        }
    }

    // MARK: - Measuring

    /// `unit` from silence through `warmUpBlocks` untimed blocks and then `blocks` timed ones of
    /// `blockFrames`, each timed render read by `clock` (nanoseconds on a monotonic clock), and every
    /// sample it wrote checked, in the warm-up too.
    public func measure(_ unit: any SelfTestUnit, clock: () -> UInt64) -> Measurement {
        let left = UnsafeMutablePointer<Float>.allocate(capacity: blockFrames)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: blockFrames)
        // A `var` for the sort at the end; the buffer itself never moves.
        var times = UnsafeMutableBufferPointer<UInt64>.allocate(capacity: blocks)
        left.initialize(repeating: 0, count: blockFrames)
        right.initialize(repeating: 0, count: blockFrames)
        times.initialize(repeating: 0)
        defer {
            left.deallocate()
            right.deallocate()
            times.deallocate()
        }
        unit.reset()
        var tally = Tally()
        for block in 0..<warmUpBlocks {
            let start = block * blockFrames
            unit.prepare(start: start, frames: blockFrames, left: left, right: right)
            unit.render(start: start, frames: blockFrames, left: left, right: right)
            tally.take(left: left, right: right, frames: blockFrames)
        }
        let soundedWarmingUp = tally.audible
        tally.audible = false
        for block in 0..<blocks {
            let start = (warmUpBlocks + block) * blockFrames
            unit.prepare(start: start, frames: blockFrames, left: left, right: right)
            let begun = clock()
            unit.render(start: start, frames: blockFrames, left: left, right: right)
            let ended = clock()
            // A clock that went backwards measured nothing: the block counts as taking no time.
            times[block] = ended >= begun ? ended - begun : 0
            tally.take(left: left, right: right, frames: blockFrames)
        }
        // Whole nanoseconds, so the sum stays exact below 2⁵³ ns, more than a hundred days.
        var total: Double = 0
        for time in times { total += Double(time) }
        times.sort()
        return Measurement(name: unit.name, sampleRate: sampleRate, blockFrames: blockFrames,
                           warmUpBlocks: warmUpBlocks, blocks: blocks,
                           median: Self.nearestRank(50, of: times), percentile99: Self.nearestRank(99, of: times),
                           mean: total / Double(blocks), nonFinite: tally.nonFinite,
                           overFullScale: tally.overFullScale, isSilent: !(soundedWarmingUp && tally.audible))
    }

    /// Every unit of `units()`, one after another.
    public func run(clock: () -> UInt64) -> Result {
        Result(self, units().map { measure($0, clock: clock) })
    }

    /// The value at `percent` of `sorted` (ascending, not empty) by nearest rank: the smallest one
    /// with at least `percent` % of the values at or below it — always a time a block really took.
    /// Integer arithmetic, so the rank is exact.
    static func nearestRank(_ percent: Int, of sorted: UnsafeMutableBufferPointer<UInt64>) -> UInt64 {
        guard !sorted.isEmpty else { return 0 }
        let rank = (sorted.count * percent + 99) / 100
        return sorted[Swift.min(Swift.max(rank, 1), sorted.count) - 1]
    }

    /// What a unit's output held, sample by sample, over both sides.
    struct Tally {
        var nonFinite = 0
        var overFullScale = 0
        var audible = false

        mutating func take(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
            for i in 0..<frames {
                take(left[i])
                take(right[i])
            }
        }

        /// A value that is not finite is counted as such and nothing else; a finite one past full
        /// scale (|x| > 1) is over 0 dBFS; one at or above −100 dBFS (the export's quiet level) is
        /// sound.
        mutating func take(_ sample: Float) {
            guard sample.isFinite else {
                nonFinite += 1
                return
            }
            let magnitude = Swift.abs(sample)
            if magnitude > 1 { overFullScale += 1 }
            if magnitude >= OfflineRender.quietLevel { audible = true }
        }
    }

    // MARK: - Results

    /// What one unit did over its blocks.
    public struct Measurement: Sendable {
        /// The unit's stored name, as the log writes it.
        public let name: StaticString
        public let sampleRate: Double
        public let blockFrames: Int
        /// The blocks played before the clock started, untimed; their samples are counted below.
        public let warmUpBlocks: Int
        /// The blocks timed.
        public let blocks: Int
        /// Nanoseconds a timed block's render took: the median and the 99th percentile, each by
        /// nearest rank — the 99th percentile of 200 blocks is the third slowest.
        public let median: UInt64
        public let percentile99: UInt64
        /// Nanoseconds a timed block's render took on average: the share of the device the unit
        /// takes while it plays. Where a unit's work comes in a cycle of blocks the median falls on
        /// whichever kind of block has a few more, and the mean holds (see `SelfTest`).
        public let mean: Double
        /// Samples of both sides, over the warm-up and the timed blocks, that were not finite: not a
        /// number, or an infinity.
        public let nonFinite: Int
        /// Finite samples past full scale (|x| > 1), over 0 dBFS, over the same blocks.
        public let overFullScale: Int
        /// No finite sample reached −100 dBFS in the warm-up, or none in the timed blocks. Every
        /// unit's part sounds through both, so a unit that is silent in either is a fault — one
        /// that falls silent after its first bar too.
        public let isSilent: Bool

        /// The stored name as text.
        public var unit: String { name.description }
        /// The time one block lasts, `blockFrames ÷ sampleRate`.
        public var budgetSeconds: Double { Double(blockFrames) / sampleRate }
        /// The median block as a share of the budget, 1 = all of it.
        public var medianLoad: Double { load(Double(median)) }
        /// The 99th percentile as a share of the budget, 1 = all of it.
        public var percentile99Load: Double { load(Double(percentile99)) }
        /// The mean block as a share of the budget, 1 = all of it.
        public var meanLoad: Double { load(mean) }

        /// Whether the 99th percentile ran past the budget: nanoseconds × rate against frames ×
        /// 10⁹, two whole numbers below 2⁵³ — so a `Double` holds both exactly — while a block takes
        /// under ten seconds at a rate of whole hertz up to the engine's 768 kHz. A block over by one
        /// nanosecond is over; one that takes the whole budget is not.
        public var isOverBudget: Bool {
            Double(percentile99) * sampleRate > Double(blockFrames) * 1_000_000_000
        }

        private func load(_ nanoseconds: Double) -> Double {
            nanoseconds * sampleRate / (Double(blockFrames) * 1_000_000_000)
        }

        /// The line's numbers, in the order the log writes them: times in microseconds (to the
        /// nanosecond, as the log keeps three places), loads as shares, counts as counts.
        var fields: [(StaticString, Double)] {
            [("Hz", sampleRate), ("frames", Double(blockFrames)), ("warmup_blocks", Double(warmUpBlocks)),
             ("blocks", Double(blocks)), ("budget_us", Double(blockFrames) * 1_000_000 / sampleRate),
             ("median_us", Double(median) / 1_000), ("p99_us", Double(percentile99) / 1_000),
             ("mean_us", mean / 1_000), ("median_load", medianLoad), ("p99_load", percentile99Load),
             ("mean_load", meanLoad), ("nonfinite", Double(nonFinite)), ("over0db", Double(overFullScale)),
             ("silent", isSilent ? 1 : 0)]
        }
    }

    /// What one run measured, and the lines it writes to the diagnostics log.
    public struct Result: Sendable {
        public let sampleRate: Double
        public let blockFrames: Int
        public let warmUpBlocks: Int
        public let blocks: Int
        /// One per unit, in the order they played.
        public let measurements: [Measurement]

        public init(_ test: SelfTest, _ measurements: [Measurement]) {
            sampleRate = test.sampleRate
            blockFrames = test.blockFrames
            warmUpBlocks = test.warmUpBlocks
            blocks = test.blocks
            self.measurements = measurements
        }

        /// The units whose 99th percentile ran past the budget.
        public var overBudget: Int { measurements.filter(\.isOverBudget).count }
        /// The units that wrote a value that is not finite.
        public var nonFinite: Int { measurements.filter { $0.nonFinite > 0 }.count }
        /// The units that wrote a sample over 0 dBFS.
        public var overFullScale: Int { measurements.filter { $0.overFullScale > 0 }.count }
        /// The units that were silent in their warm-up or in their timed blocks.
        public var silent: Int { measurements.filter(\.isSilent).count }
        /// The highest 99th percentile of any unit as a share of the budget; 0 without a unit.
        public var highestLoad: Double { measurements.map(\.percentile99Load).max() ?? 0 }

        /// Writes the run to `log`: a line per unit — `selftest: unit (<stored name>)` and its
        /// numbers (`Measurement.fields`) — then `selftest: summary`, whose counts are of units.
        /// Fixed words and numbers only, which the report's rules read; keep them as they are.
        /// Returns the lines without their times.
        @discardableResult
        public func write(to log: DiagnosticLog) -> [String] {
            var lines = measurements.map { log.note("selftest: unit", because: $0.name, $0.fields) }
            lines.append(log.note("selftest: summary", [
                ("Hz", sampleRate), ("frames", Double(blockFrames)), ("warmup_blocks", Double(warmUpBlocks)),
                ("blocks", Double(blocks)), ("units", Double(measurements.count)),
                ("over_budget", Double(overBudget)), ("nonfinite", Double(nonFinite)),
                ("over0db", Double(overFullScale)), ("silent", Double(silent)),
                ("highest_p99_load", highestLoad),
            ]))
            return lines
        }
    }
}

// MARK: - The built-in units and their parts

extension SelfTest {
    /// What an instrument plays.
    enum Part {
        /// Eight notes held, changing on every sixteenth between two chords. One chord ends on the
        /// frame the next begins and rings on in its release, which at the default patches outlasts
        /// a sixteenth (the synth's 0.25 s, the sampler's 0.15 s): so all sixteen voices sound
        /// throughout, each new chord taking the voices of the oldest release, and the timed blocks
        /// differ only where a chord changes — measured 2026-11-27, the synth's blocks at 48 kHz in
        /// blocks of 256 took 40.8 to 41.1 µs from the 10th to the 75th percentile. A chord every
        /// half second would leave about half the blocks at eight voices and half at sixteen, and
        /// the median would fall between the two.
        case chords
        /// A bar of sixteen sixteenths that strikes all eight pieces of the kit.
        case beat

        /// Seconds from one step to the next, in both parts: a sixteenth at 120 BPM.
        static let stepSeconds: Double = 0.125

        /// How hard each note is struck: softly enough that a sound unit stays well below full
        /// scale, so a sample past it is a fault and not the part. The velocity changes the level,
        /// not what a block costs: a drum's voice ends on its envelope, and neither velocity reaches
        /// the synth's accent (`PolySynth.accentVelocity`). Measured 2026-11-27 (Linux, release
        /// build, the run at 44.1, 48 and 96 kHz in blocks of 64 to 4,096 frames): no unit past
        /// full scale, the loudest the synth at −4.0 dBFS and the harmonizer at −4.1, every other
        /// unit −5.7 or below, the sampler −6.8 and the kit −8.0 at most; played for 62 s, the
        /// synth −4.1, the sampler −6.8 and the kit −7.1. Struck at 64 the kit had come to
        /// −2.1 dBFS over 62 s, too near full scale.
        var velocity: UInt8 {
            switch self {
            case .chords: 80
            case .beat: 48
            }
        }
    }

    /// A built-in instrument as the engine makes it (`BuiltInKernels`), playing its part. A step of
    /// the part falls on the first frame of the block it is due in, and a kernel with nothing
    /// sounding is not rendered, as the engine renders none (`EngineCore`).
    final class InstrumentUnit: SelfTestUnit {
        let name: StaticString
        private let kernel: any EngineInstrumentKernel
        /// The sampler's sound, kept alive while the kernel plays it.
        private let sample: SampleBuffer?
        private let part: Part
        /// Frames from one step of the part to the next.
        private let stepFrames: Double
        /// The parts' notes, values rather than arrays, so the render reads them without touching
        /// the heap: two chords (C and then F, each with its major seventh, from the bass to the
        /// fifth octave), and the kit's pieces — kick, snare, clap, closed hat, low tom, open hat,
        /// crash, high tom — with a bar of sixteen steps, bit `j` of a step striking piece `j`.
        private let firstChord = SIMD8<UInt8>(36, 48, 55, 59, 64, 67, 71, 76)
        private let secondChord = SIMD8<UInt8>(41, 53, 60, 64, 69, 72, 76, 81)
        private let pieces = SIMD8<UInt8>(36, 38, 39, 42, 45, 46, 49, 50)
        private let bar = SIMD16<UInt8>(0x41, 0x08, 0x08, 0x08, 0x0A, 0x08, 0x09, 0x20,
                                        0x09, 0x08, 0x08, 0x08, 0x0E, 0x10, 0x80, 0x20)

        init?(_ device: InstrumentDevice, test: SelfTest) {
            guard let name = SelfTest.name(of: device),
                  let kernel = BuiltInKernels.kernel(for: device, sampleRate: test.sampleRate,
                                                     maximumFrames: EngineCore.maximumFrames) else { return nil }
            let part: Part = device == .drums ? .beat : .chords
            self.name = name
            self.kernel = kernel
            self.part = part
            stepFrames = Part.stepSeconds * test.sampleRate
            if let sampler = kernel as? any SampleAssigningKernel {
                let tone = SelfTest.testSample(sampleRate: test.sampleRate)
                sampler.assign(tone)
                sample = tone
            } else {
                sample = nil
            }
        }

        /// Every voice silent and every controller at rest, as the engine starts a kernel over for
        /// a new owner (`EngineInstrumentKernel.reset`); the sampler keeps its sound.
        func reset() {
            kernel.reset()
        }

        func render(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            for step in steps(start: start, frames: frames) {
                forEachNote(of: step) { status, note, velocity in kernel.receive(status: status, note, velocity) }
            }
            guard kernel.isSounding else {
                left.update(repeating: 0, count: frames)
                right.update(repeating: 0, count: frames)
                return
            }
            kernel.render(frames: frames, left: left, right: right, gain: 1)
        }

        /// The steps of the part that fall inside the block of `frames` from `start`: found from the
        /// block's place alone, not from a count the unit keeps, so every step falls in exactly one
        /// block, and a unit measured again plays its part from the start again.
        func steps(start: Int, frames: Int) -> Range<Int> {
            firstStep(from: start)..<firstStep(from: start + Swift.max(frames, 0))
        }

        /// The frame step `index` falls on.
        func frame(of index: Int) -> Int {
            Int((Double(index) * stepFrames).rounded())
        }

        /// The first step that falls on `start` or after it.
        private func firstStep(from start: Int) -> Int {
            var index = Swift.max(0, Int((Double(start) / stepFrames).rounded(.down)))
            while index > 0, frame(of: index - 1) >= start { index -= 1 }
            while frame(of: index) < start { index += 1 }
            return index
        }

        /// The notes of step `index`, in the order the kernel gets them, each as a status, a note
        /// and a velocity: the last chord's note-offs and then the next chord's note-ons, or the
        /// bar's hits. The closure does not escape, so the render calls it without the heap.
        func forEachNote(of index: Int, _ send: (_ status: UInt8, _ note: UInt8, _ velocity: UInt8) -> Void) {
            switch part {
            case .chords:
                let next = index % 2 == 0 ? firstChord : secondChord
                if index > 0 {
                    let last = index % 2 == 0 ? secondChord : firstChord
                    for voice in 0..<8 { send(0x80, last[voice], 0) }
                }
                for voice in 0..<8 { send(0x90, next[voice], part.velocity) }
            case .beat:
                let hits = bar[index % 16]
                for piece in 0..<8 where (hits >> UInt8(piece)) & 1 == 1 {
                    send(0x90, pieces[piece], part.velocity)
                }
            }
        }
    }

    /// A standard effect as an insert plays it (`EffectKernel` at its defaults), fed the test signal.
    final class EffectUnit: SelfTestUnit {
        let name: StaticString
        private let kernel: EffectKernel
        private let sampleRate: Double

        init(_ effect: StandardEffect, test: SelfTest) {
            name = SelfTest.name(of: effect)
            kernel = EffectKernel(effect: effect, sampleRate: test.sampleRate)
            sampleRate = test.sampleRate
        }

        /// Delay lines and tails emptied (`EffectKernel.reset`).
        func reset() {
            kernel.reset()
        }

        func prepare(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            SelfTest.signal(start: start, frames: frames, sampleRate: sampleRate, left: left, right: right)
        }

        func render(start: Int, frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
            kernel.process(left: left, right: right, frames: frames)
        }
    }

    /// The effects' input from `start` frames into the test: 220 Hz with its third harmonic on the
    /// left and its fifth on the right, so the sides differ and a stereo effect has something to
    /// work on, and on each side a little noise of its own across the spectrum, for the effects that
    /// work in bands. About −7 dBFS at its peak. The same at every run and in every block size: it is
    /// computed from each frame's place in the test, never from a clock or a random source.
    static func signal(start: Int, frames: Int, sampleRate: Double, left: UnsafeMutablePointer<Float>,
                       right: UnsafeMutablePointer<Float>) {
        for i in 0..<frames {
            let frame = start + i
            let phase: Double = 2 * Double.pi * 220 * Double(frame) / sampleRate
            let fundamental: Double = 0.3 * sin(phase)
            let third: Double = 0.1 * sin(3 * phase)
            let fifth: Double = 0.1 * sin(5 * phase)
            left[i] = Float(fundamental + third) + 0.02 * noise(frame, side: 0)
            right[i] = Float(fundamental + fifth) + 0.02 * noise(frame, side: 1)
        }
    }

    /// White noise in −1 ..< 1 for one frame and side: a SplitMix64 step on the frame's place, so
    /// a frame has the same value whichever block holds it.
    static func noise(_ frame: Int, side: UInt64) -> Float {
        var z = (UInt64(truncatingIfNeeded: frame) &* 2 &+ side &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        // The top 24 bits, which a Float holds exactly: 0 ..< 2, then centred.
        return Float(z >> 40) / Float(1 << 23) - 1
    }

    /// The sampler's sound: one second of middle C — the sample's root key, 60 — with its octave,
    /// fading to nothing, made at the test's rate so it plays at its own speed on the root key.
    static func testSample(sampleRate: Double) -> SampleBuffer? {
        let count = Swift.max(1, Int(sampleRate.rounded()))
        let tone = (0..<count).map { (i: Int) -> Float in
            let t: Double = Double(i) / sampleRate
            let phase: Double = 2 * Double.pi * 261.625_565 * t
            let fade: Double = 1 - t
            return Float((0.6 * sin(phase) + 0.4 * sin(2 * phase)) * 0.25 * fade)
        }
        return SampleBuffer(samples: tone, sampleRate: sampleRate, rootPitch: 60)
    }
}

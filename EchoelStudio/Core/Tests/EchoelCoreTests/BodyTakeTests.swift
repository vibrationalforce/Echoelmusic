import Foundation
import XCTest
@testable import EchoelCore

/// A body take (body recording BR-1): how one body source moved while Record ran, as runs of
/// points with gaps where it was not measured, thinned within an error the take states. The tests
/// hand the recorder what a capture would: a value or nothing, at a song position.
final class BodyTakeTests: XCTestCase {
    /// SplitMix64: the same numbers on every platform, so a failure is the same failure each run.
    private struct Numbers {
        var state: UInt64

        /// A number in 0 ..< 1.
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(UInt64(1) << 53)
        }
    }

    /// One reading every 32 ticks: sixty a second at 120 bpm.
    private let step: Tick = 32

    private func point(_ tick: Tick, _ value: Double) -> BodyTake.Point {
        BodyTake.Point(tick: tick, value: value)
    }

    /// A recorder fed `readings` in order.
    private func recorder(_ readings: [(position: Double, value: Double?)],
                          source: ModulationSource = .breath) throws -> BodyTakeRecorder {
        var capture = try XCTUnwrap(BodyTakeRecorder(source: source))
        for reading in readings { capture.record(reading.value, atPosition: reading.position) }
        return capture
    }

    /// The take `readings` land as, over `earlier`.
    private func landed(_ readings: [(position: Double, value: Double?)], over earlier: BodyTake? = nil) throws -> BodyTake {
        try XCTUnwrap(recorder(readings).landing(over: earlier).take)
    }

    /// The largest distance between the take and a reading, measured at the reading's tick;
    /// infinity where the take has nothing for a reading.
    private func largestError(of take: BodyTake?, from readings: [(tick: Tick, value: Double)]) -> Double {
        guard let take else { return .infinity }
        var largest = 0.0
        for reading in readings {
            guard let value = take.value(atPosition: Double(reading.tick)) else { return .infinity }
            largest = Swift.max(largest, Swift.abs(value - reading.value))
        }
        return largest
    }

    /// One loop pass's readings, every 32 ticks from `start` through `end`, around `level`.
    private func pass(from start: Tick, through end: Tick, level: Double) -> [(tick: Tick, value: Double)] {
        var readings: [(tick: Tick, value: Double)] = []
        var tick = start
        while tick <= end {
            readings.append((tick, level + 0.05 * Foundation.sin(Double(tick) / 500)))
            tick += step
        }
        return readings
    }

    func testAReadingThatIsNotMeasuredLeavesAGapNeverAZero() throws {
        let unmeasured: [Double?] = [nil, .nan, .infinity, -.infinity, -0.1, 1.1]
        var readings: [(position: Double, value: Double?)] = [(0, 0.4), (32, 0.43)]
        for (index, value) in unmeasured.enumerated() { readings.append((Double(64 + 32 * index), value)) }
        readings += [(256, 0.45), (288, 0.5)]
        let take = try landed(readings)
        XCTAssertEqual(take.runs.count, 2, "two stretches and a gap between, not one line through a made-up value")
        let filled = (65..<256).filter { (tick: Int) -> Bool in take.value(atPosition: Double(tick)) != nil }
        XCTAssertEqual(filled, [], "nothing in the gap: no 0, no 1, nothing clamped from −0.1 or 1.1")
        let stored = Set(take.runs.flatMap(\.points).map(\.value))
        XCTAssertEqual(stored, [0.4, 0.43, 0.45, 0.5], "only values that were read")
    }

    func testARunEndsAtTheFirstReadingThatFoundTheSourceAbsent() throws {
        let take = try landed([(0, 0.3), (32, 0.35), (64, 0.42), (96, nil), (128, nil), (160, 0.6), (192, 0.66)])
        XCTAssertEqual(take.value(atPosition: 80), 0.42, "the last value holds, as the engine held it")
        XCTAssertEqual(take.value(atPosition: 96), 0.42, "up to the reading that found the source gone")
        XCTAssertNil(take.value(atPosition: 96.5))
        XCTAssertNil(take.value(atPosition: 128))
        XCTAssertNil(take.value(atPosition: 159.5))
        XCTAssertEqual(take.value(atPosition: 160), 0.6, "a new run starts at the first reading that measured it again")
        XCTAssertEqual(take.value(atPosition: 192), 0.66)
        XCTAssertNil(take.value(atPosition: 192.5), "the last reading ends the last run: nothing is made up after it")

        let once = try landed([(0, nil), (32, 0.5), (64, nil)])
        XCTAssertEqual(once.runs, [BodyTake.Run(points: [point(32, 0.5), point(64, 0.5)])],
                       "measured once: the reading, held up to the one that found it gone")
        let last = try recorder([(0, nil), (32, 0.5)]).landing(over: nil)
        XCTAssertNil(last.take, "one reading at the very end is no stretch of time")
        XCTAssertEqual(last.outcome, .nothingMeasured)
    }

    func testAPositionThatDoesNotRiseIsIgnored() throws {
        let take = try landed([(0, 0.5), (32, 0.6), (32, 0.95), (31.6, 0.05), (16, 0.05), (.nan, 0.9), (-.infinity, 0.9),
                               (-8, 0.9), (64, 0.62), (40, nil), (96, 0.3), (1e30, 0.9), (.infinity, 0.9), (128.4, 0.35)])
        XCTAssertEqual(take.runs, [BodyTake.Run(points: [point(0, 0.5), point(32, 0.6), point(64, 0.62), point(96, 0.3),
                                                         point(128, 0.35)])],
                       "a repeated or earlier tick, a position that is not a number or outside the song: ignored, "
                           + "and a nothing read there does not end the run")
    }

    func testThinningKeepsEveryReadingWithinTheStatedError() throws {
        let count = 10_800
        var numbers = Numbers(state: 20_261_127)
        var walk: [Double] = []
        var level = 0.5
        for _ in 0..<count {
            level += 0.004 * (numbers.next() - 0.5)
            if level < 0 { level = -level }
            if level > 1 { level = 2 - level }
            walk.append(level)
        }
        var sine: [Double] = []
        for index in 0..<count {
            sine.append(0.5 + 0.4 * Foundation.sin(2 * Double.pi * 0.2 * Double(index) / 60))
        }
        var steps: [Double] = []
        var stepLevel = 0.5
        for index in 0..<count {
            if index % 600 == 0 { stepLevel = 0.1 + 0.8 * numbers.next() }
            steps.append(stepLevel)
        }
        let signals: [(name: String, values: [Double], share: Double)] = [("random walk", walk, 0.6),
                                                                          ("sine", sine, 0.2),
                                                                          ("steps", steps, 0.01)]
        for signal in signals {
            var readings: [(tick: Tick, value: Double)] = []
            for (index, value) in signal.values.enumerated() { readings.append((Tick(index) * step, value)) }
            var capture = try XCTUnwrap(BodyTakeRecorder(source: .breath))
            for reading in readings { capture.record(reading.value, atPosition: Double(reading.tick) + 0.25) }
            let landing = capture.landing(over: nil)
            let take = try XCTUnwrap(landing.take, signal.name)
            XCTAssertEqual(landing.outcome, .landed, signal.name)
            XCTAssertEqual(take.tolerance, 0.001, signal.name)
            XCTAssertEqual(take.runs.count, 1, signal.name)
            XCTAssertLessThanOrEqual(largestError(of: take, from: readings), take.tolerance,
                                     "\(signal.name): every reading within the stated error, at its tick")
            XCTAssertLessThan(Double(take.pointCount), signal.share * Double(count), "\(signal.name): thinned")
            var read: [Tick: Double] = [:]
            for reading in readings { read[reading.tick] = reading.value }
            let changed = take.runs.flatMap(\.points).filter { (kept: BodyTake.Point) -> Bool in read[kept.tick] != kept.value }
            XCTAssertEqual(changed, [], "\(signal.name): every kept point is a reading, exactly as read")
        }
    }

    func testTheSameReadingsMakeTheSameTake() throws {
        var numbers = Numbers(state: 41)
        var readings: [(position: Double, value: Double?)] = []
        for index in 0..<6_000 {
            let value = 0.5 + 0.3 * Foundation.sin(Double(index) / 90) + 0.02 * numbers.next()
            readings.append((31.75 * Double(index), index % 1_000 < 40 ? nil : value))
        }
        let first = try recorder(readings).landing(over: nil)
        XCTAssertEqual(first, try recorder(readings).landing(over: nil))
        let take = try XCTUnwrap(first.take)
        XCTAssertEqual(take.runs.count, 6, "a gap each time the source was lost")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(take)
        XCTAssertEqual(bytes, try encoder.encode(try XCTUnwrap(try recorder(readings).landing(over: nil).take)),
                       "the same bytes")
        XCTAssertEqual(try JSONDecoder().decode(BodyTake.self, from: bytes), take,
                       "and the same take after a trip through its written form")

        let again: [(position: Double, value: Double?)] = readings[1_500..<3_500].map {
            (reading: (position: Double, value: Double?)) -> (position: Double, value: Double?) in
            (reading.position, reading.value.map { (value: Double) -> Double in 1 - value })
        }
        XCTAssertEqual(try recorder(again).landing(over: take), try recorder(again).landing(over: take),
                       "over an earlier take, too")
    }

    func testATakeTooLongForTheLimitStatesTheLargerErrorItUsed() throws {
        // A busy source: each reading a little above or below the middle, by 0.6 to 0.9 thousandths
        // of its travel. At 0.1 % most readings must stay, more than the limit; at 0.2 % one line
        // holds them all.
        var numbers = Numbers(state: 50_000)
        var readings: [(tick: Tick, value: Double)] = []
        for index in 0..<80_000 {
            let size = 0.0006 + 0.0003 * numbers.next()
            readings.append((Tick(index) * step, index % 2 == 0 ? 0.5 + size : 0.5 - size))
        }
        var capture = try XCTUnwrap(BodyTakeRecorder(source: .motionEnergy))
        for reading in readings { capture.record(reading.value, atPosition: Double(reading.tick)) }
        let landing = capture.landing(over: nil)
        let take = try XCTUnwrap(landing.take)
        XCTAssertEqual(landing.outcome, .landed)
        XCTAssertEqual(take.tolerance, 0.002, "the take states the larger error it used")
        XCTAssertLessThanOrEqual(take.pointCount, BodyTake.maximumPoints)
        let error = largestError(of: take, from: readings)
        XCTAssertLessThanOrEqual(error, take.tolerance, "every reading within what it states")
        XCTAssertGreaterThan(error, BodyTake.defaultTolerance, "the default would have been a false statement")

        var shorter = try XCTUnwrap(BodyTakeRecorder(source: .motionEnergy))
        for reading in readings.prefix(10_000) { shorter.record(reading.value, atPosition: Double(reading.tick)) }
        XCTAssertEqual(shorter.landing(over: nil).take?.tolerance, BodyTake.defaultTolerance,
                       "a shorter stretch of the same source fits at the default: the limit made the difference")

        // Too busy even at 1 %, against a limit of 1,000 points: the recording stops where the take
        // is full, keeps what came before, and says where.
        var busy = try XCTUnwrap(BodyTakeRecorder(source: .motionEnergy, maximumPoints: 1_000))
        var jolts: [(tick: Tick, value: Double)] = []
        for index in 0..<3_000 {
            let size = 0.006 + 0.003 * numbers.next()
            jolts.append((Tick(index) * step, index % 2 == 0 ? 0.5 + size : 0.5 - size))
        }
        for reading in jolts { busy.record(reading.value, atPosition: Double(reading.tick)) }
        let stopped = busy.landing(over: nil)
        guard case let .stopped(at: stop) = stopped.outcome else { return XCTFail("\(stopped.outcome)") }
        let kept = try XCTUnwrap(stopped.take)
        XCTAssertEqual(kept.tolerance, 0.01)
        XCTAssertLessThanOrEqual(kept.pointCount, 1_000)
        XCTAssertGreaterThan(stop, 0)
        let before = jolts.filter { (reading: (tick: Tick, value: Double)) -> Bool in reading.tick < stop }
        XCTAssertGreaterThan(before.count, 900, "it stopped where the take was full, not at the start")
        XCTAssertLessThanOrEqual(largestError(of: kept, from: before), 0.01)
        let after = jolts.filter { (reading: (tick: Tick, value: Double)) -> Bool in reading.tick >= stop }
            .filter { (reading: (tick: Tick, value: Double)) -> Bool in kept.value(atPosition: Double(reading.tick)) != nil }
        XCTAssertEqual(after.count, 0, "nothing from where it stopped")
    }

    func testRecordingAgainReplacesOnlyTheSpanItCovered() throws {
        var first: [(position: Double, value: Double?)] = []
        for index in 0...300 {
            let tick = Double(index) * 32
            first.append((tick, 0.5 + 0.3 * Foundation.sin(tick / 600)))
        }
        let earlier = try landed(first)
        // Again from 3,200 to 6,400, the source lost from 4,480 until 4,992.
        var again: [(position: Double, value: Double?)] = []
        for index in 100...200 {
            again.append((Double(index) * 32, (140..<156).contains(index) ? nil : 0.9 - Double(index) / 4_000))
        }
        let landing = try recorder(again).landing(over: earlier)
        let take = try XCTUnwrap(landing.take)
        XCTAssertEqual(landing.outcome, .landed)
        XCTAssertEqual(take.tolerance, 0.001)

        var moved: [Int] = []
        for tick in Array(0..<3_200) + Array(6_401...9_600) {
            let before = earlier.value(atPosition: Double(tick)) ?? -1
            let after = take.value(atPosition: Double(tick)) ?? -2
            if Swift.abs(before - after) > 1e-12 { moved.append(tick) }
        }
        XCTAssertEqual(moved, [], "outside the span the recording covered, the earlier take is where it was")
        let measured = again.compactMap { (reading: (position: Double, value: Double?)) -> (tick: Tick, value: Double)? in
            reading.value.map { (value: Double) -> (tick: Tick, value: Double) in (Tick(reading.position), value) }
        }
        XCTAssertLessThanOrEqual(largestError(of: take, from: measured), 0.001, "inside it, the new readings")
        XCTAssertNotNil(earlier.value(atPosition: 4_700))
        XCTAssertNil(take.value(atPosition: 4_700),
                     "where the new recording lost the source, its gap stays: nothing of the earlier take shows through")

        let nothing = try recorder([(2_000, nil), (2_032, nil), (2_064, nil)]).landing(over: take)
        XCTAssertEqual(nothing.outcome, .nothingMeasured)
        XCTAssertEqual(nothing.take, take, "a recording that measured nothing covers nothing")
    }

    func testALandingStatesTheLargerErrorOfWhatItKeepsAndPlays() throws {
        // An earlier take, switched off and thinned at 0.4 %: one run up to 3,968, one from 6,016.
        var opening: [BodyTake.Point] = []
        var closing: [BodyTake.Point] = []
        var tick: Tick = 0
        while tick <= 9_984 {
            let reading = point(tick, 0.5 + 0.2 * Foundation.sin(Double(tick) / 700))
            if tick <= 3_968 { opening.append(reading) } else if tick >= 6_016 { closing.append(reading) }
            tick += step
        }
        let earlier = BodyTake(source: .breath, enabled: false, tolerance: 0.004,
                               runs: [BodyTake.Run(points: opening), BodyTake.Run(points: closing)])

        // Again from 3,008 to 4,992, a slow rise that fits at the default.
        var again: [(position: Double, value: Double?)] = []
        for index in 94...156 { again.append((Double(index) * 32, 0.3 + Double(index) / 10_000)) }
        let punch = try recorder(again).landing(over: earlier)
        let take = try XCTUnwrap(punch.take)
        XCTAssertEqual(punch.outcome, .landed)
        XCTAssertEqual(take.tolerance, 0.004,
                       "what it keeps of the earlier take was thinned at 0.4 %: stating 0.1 % would be false there")
        XCTAssertTrue(take.enabled, "a recording plays: the take it lands in is switched on")

        // Over all of the earlier take, in two stretches with a jump between them: nothing of it is left.
        var whole = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for index in 0...150 { whole.record(0.6, atPosition: Double(index) * 32) }
        whole.wrap(from: 4_800, to: 5_216)
        for index in 163...320 { whole.record(0.65, atPosition: Double(index) * 32) }
        let replaced = try XCTUnwrap(whole.landing(over: earlier).take)
        XCTAssertNil(replaced.value(atPosition: 5_000), "the jump skipped only where the earlier take had a gap")
        XCTAssertEqual(replaced.tolerance, 0.001, "only the new readings are left, thinned at 0.1 %")

        // By hand, the same statement; and an edit leaves on or off as it was.
        let edited = earlier.replacing(span: 3_008...4_992,
                                       with: BodyTake(source: .breath, runs: [BodyTake.Run(points: [point(3_008, 0.3),
                                                                                                    point(4_992, 0.35)])]))
        XCTAssertEqual(edited.tolerance, 0.004)
        XCTAssertFalse(edited.enabled, "an edit does not switch a take on")
    }

    func testACutEdgeKeepsTheCurveExactly() {
        let take = BodyTake(source: .breath, runs: [BodyTake.Run(points: [point(0, 0.2), point(4_000, 0.8),
                                                                          point(8_000, 0.3)])])
        let cut = take.removing(span: 1_000...2_000)
        XCTAssertEqual(cut.runs.count, 2)
        XCTAssertEqual(cut.value(atPosition: 999), take.value(atPosition: 999), "the edge sits on the old line, to the last bit")
        XCTAssertEqual(cut.value(atPosition: 2_001), take.value(atPosition: 2_001))
        XCTAssertEqual(cut.runs.first?.points.first, point(0, 0.2), "points outside the span stay as they were")
        XCTAssertEqual(cut.runs.last?.points.suffix(2).map { $0 }, [point(4_000, 0.8), point(8_000, 0.3)])
        let gap = (1_000...2_000).filter { (tick: Int) -> Bool in cut.value(atPosition: Double(tick)) != nil }
        XCTAssertEqual(gap, [])
        var moved: [Int] = []
        for tick in Array(0...999) + Array(2_001...8_000) {
            let before = take.value(atPosition: Double(tick)) ?? -1
            let after = cut.value(atPosition: Double(tick)) ?? -2
            if Swift.abs(before - after) > 1e-12 { moved.append(tick) }
        }
        XCTAssertEqual(moved, [], "between its points the line is the old one, to the rounding of one division")
        XCTAssertEqual(take.removing(span: 4_001...5_000).runs.first?.points.last, point(4_000, 0.8),
                       "an edge on a point keeps that point, and adds none")

        let punched = take.replacing(span: 1_000...2_000,
                                     with: BodyTake(source: .breath, runs: [BodyTake.Run(points: [point(1_000, 0.9),
                                                                                                  point(2_000, 0.95)])]))
        XCTAssertEqual(punched.value(atPosition: 999), take.value(atPosition: 999))
        XCTAssertEqual(punched.value(atPosition: 1_000), 0.9)
        XCTAssertEqual(punched.value(atPosition: 2_000), 0.95)
        XCTAssertEqual(punched.value(atPosition: 2_001), take.value(atPosition: 2_001))
        XCTAssertEqual(punched.runs.count, 1, "the old curve and the new meet on neighbouring ticks: one run")
        XCTAssertNotNil(punched.value(atPosition: 999.5), "so a route never drops to nothing between them")
        XCTAssertNotNil(punched.value(atPosition: 2_000.5))
    }

    func testTheNewestPassOfALoopWins() throws {
        // A loop of two bars, 0 ..< 7,680. Record starts half way into the first pass; the third
        // pass is stopped half way.
        let loopEnd = Double(7_680)
        let first = pass(from: 1_920, through: 7_660, level: 0.2)
        let second = pass(from: 10, through: 7_660, level: 0.5)
        let third = pass(from: 10, through: 3_850, level: 0.8)
        var capture = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for reading in first { capture.record(reading.value, atPosition: Double(reading.tick)) }
        capture.wrap(from: loopEnd, to: 0)
        for reading in second { capture.record(reading.value, atPosition: Double(reading.tick)) }
        capture.wrap(from: loopEnd, to: 0)
        for reading in third { capture.record(reading.value, atPosition: Double(reading.tick)) }
        let take = try XCTUnwrap(capture.landing(over: nil).take)
        XCTAssertLessThanOrEqual(largestError(of: take, from: third), 0.001, "the newest pass, where it ran")
        let rest = second.filter { (reading: (tick: Tick, value: Double)) -> Bool in reading.tick > 3_850 }
        XCTAssertLessThanOrEqual(largestError(of: take, from: rest), 0.001, "the pass before it, beyond where the newest stopped")
        XCTAssertEqual(take.value(atPosition: 0), third.first?.value, "the newest pass holds its first reading back to the loop's start")
        XCTAssertEqual(take.value(atPosition: loopEnd), second.last?.value, "a pass holds its last reading up to the loop's end")
        XCTAssertNotNil(take.value(atPosition: 3_850.5), "no gap where the two passes meet")

        var lost = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for reading in first { lost.record(reading.value, atPosition: Double(reading.tick)) }
        lost.wrap(from: loopEnd, to: 0)
        for reading in second { lost.record(reading.value, atPosition: Double(reading.tick)) }
        lost.wrap(from: loopEnd, to: 0)
        for reading in third { lost.record(nil, atPosition: Double(reading.tick)) }
        XCTAssertLessThanOrEqual(largestError(of: lost.landing(over: nil).take, from: second), 0.001,
                                 "a pass that never measured the source replaces nothing")
    }

    func testAJumpOfTheSongPositionLeavesAGap() throws {
        // Record from the start; at 10,000 the song position jumps to 50,000, as a chase or a jam's
        // re-sync can move it, and the capture reports the jump as it reports a loop's wrap.
        var capture = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        var tick: Tick = 0
        while tick < 10_000 {
            capture.record(0.3, atPosition: Double(tick))
            tick += step
        }
        capture.wrap(from: 10_000, to: 50_000)
        tick = 50_000
        while tick < 60_000 {
            capture.record(0.31, atPosition: Double(tick))
            tick += step
        }
        let take = try XCTUnwrap(capture.landing(over: nil).take)
        XCTAssertEqual(take.runs.count, 2, "the two stretches the song played, and a gap between")
        XCTAssertEqual(take.value(atPosition: 10_000), 0.3, "the run holds up to where the song left off")
        let skipped: [Double] = [10_000.5, 30_000, 49_999.5]
        let filled = skipped.filter { (position: Double) -> Bool in take.value(atPosition: position) != nil }
        XCTAssertEqual(filled, [], "no line over song time that never played")
        XCTAssertEqual(take.value(atPosition: 50_000), 0.31, "the next run starts where the song went on")

        let earlier = BodyTake(source: .breath, runs: [BodyTake.Run(points: [point(0, 0.7), point(70_000, 0.7)])])
        let over = try XCTUnwrap(capture.landing(over: earlier).take)
        XCTAssertEqual(over.value(atPosition: 5_000), 0.3)
        XCTAssertEqual(over.value(atPosition: 30_000), 0.7, "where the song never played, the earlier take stays")
        XCTAssertEqual(over.value(atPosition: 55_000), 0.31)
        XCTAssertEqual(over.value(atPosition: 65_000), 0.7)
    }

    func testOutsideEveryRunTheSourceIsAbsent() throws {
        let take = BodyTake(source: .heartRate, runs: [BodyTake.Run(points: [point(100, 0.4), point(200, 0.6)]),
                                                       BodyTake.Run(points: [point(500, 0.5), point(600, 0.7)])])
        let outside: [Double] = [-1, 0, 99.999, 200.001, 350, 499.5, 600.5, 1e9, .nan, .infinity, -.infinity]
        let found = outside.filter { (position: Double) -> Bool in take.value(atPosition: position) != nil }
        XCTAssertEqual(found, [], "before, between and after the runs, and at no position at all, the source is absent")
        XCTAssertEqual(take.value(atPosition: 100), 0.4)
        XCTAssertEqual(take.value(atPosition: 150) ?? 0, 0.5, accuracy: 1e-12)
        XCTAssertEqual(take.value(atPosition: 200), 0.6)
        XCTAssertEqual(take.value(atPosition: 500), 0.5)
        XCTAssertEqual(take.value(atPosition: 600), 0.7)
        XCTAssertNil(BodyTake(source: .heartRate, runs: []).value(atPosition: 0))

        let recorded = try landed([(960, 0.5), (992, 0.6), (1_024, 0.55)])
        XCTAssertNil(recorded.value(atPosition: 959), "before the recording's first reading")
        XCTAssertNil(recorded.value(atPosition: 1_025), "after its last")
    }

    func testBetweenTwoPointsATakeStaysBetweenTheirValues() {
        // Lines rising, falling and flat, the first from tick 0 to the top of the travel; each is read
        // just after its first point, half a tick in, and just before its last point.
        var numbers = Numbers(state: 20_261_127)
        var lines: [BodyTake.Run] = [BodyTake.Run(points: [point(0, 0.3), point(7, 1)])]
        for index in 1..<15_000 {
            let start = Tick(index) * 2_000
            let length = index % 3 == 0 ? Tick(1) : 1 + Tick(numbers.next() * 1_500)
            let first = numbers.next()
            let last = index % 4 == 0 ? first : numbers.next()
            lines.append(BodyTake.Run(points: [point(start, first), point(start + length, last)]))
        }
        let take = BodyTake(source: .breath, runs: lines)
        var strays: [Double] = []
        for line in lines {
            guard let a = line.points.first, let b = line.points.last else { continue }
            let low = Swift.min(a.value, b.value), high = Swift.max(a.value, b.value)
            let positions: [Double] = [Double(a.tick).nextUp, Double(a.tick) + 0.5, Double(b.tick).nextDown]
            for position in positions {
                let value = take.value(atPosition: position) ?? -1
                let inside: Bool
                if a.value == b.value {
                    inside = value == a.value
                } else {
                    inside = value >= low && value <= high
                }
                if !inside { strays.append(position) }
            }
        }
        XCTAssertEqual(strays, [], "never past either point's value, and a flat stretch reads its value exactly")
    }

    func testOnlyABodySourceIsRecorded() {
        let recorded = ModulationSource.allCases.filter { (source: ModulationSource) -> Bool in
            BodyTakeRecorder(source: source) != nil
        }
        XCTAssertEqual(recorded.map(\.rawValue), ["body.heartRate", "body.hrv", "body.coherence", "body.breath",
                                                  "body.motion.tiltX", "body.motion.tiltY", "body.motion.rotation",
                                                  "body.motion.energy"],
                       "an LFO, a macro, a wheel and the Weave come from the song or a hand, not a body")
    }

    // MARK: - In the song (body recording BR-2)

    /// A take of `source`: one stretch from `start`, a point every 32 ticks with the values given.
    private func oneStretch(of source: ModulationSource, from start: Tick = 0, values: [Double] = [0.4, 0.45, 0.5],
                            tolerance: Double = BodyTake.defaultTolerance) -> BodyTake {
        var points: [BodyTake.Point] = []
        for (offset, value) in values.enumerated() { points.append(point(start + Tick(offset) * step, value)) }
        return BodyTake(source: source, tolerance: tolerance, runs: [BodyTake.Run(points: points)])
    }

    /// One stretch of the points given as tick and value.
    private func stretch(_ points: [(tick: Tick, value: Double)]) -> BodyTake.Run {
        BodyTake.Run(points: points.map { (reading: (tick: Tick, value: Double)) -> BodyTake.Point in
            point(reading.tick, reading.value)
        })
    }

    func testOnlyABodySourceCanHaveATake() throws {
        var song = Project()
        var taken: [ModulationSource] = []
        // Last source first: the song keeps its takes in the order of the sources, not of the recordings.
        for source in ModulationSource.allCases.reversed() {
            let before = song
            do {
                try Command.setBodyTake(oneStretch(of: source)).apply(to: &song)
                taken.append(source)
            } catch {
                XCTAssertEqual(song, before, "\(source.rawValue): a refused take leaves the song as it was")
            }
        }
        let bodySources = ["body.heartRate", "body.hrv", "body.coherence", "body.breath", "body.motion.tiltX",
                           "body.motion.tiltY", "body.motion.rotation", "body.motion.energy"]
        XCTAssertEqual(Set(taken.map(\.rawValue)), Set(bodySources),
                       "an LFO, a macro, a wheel and the Weave come from the song or a hand: there is no body to keep")
        XCTAssertEqual(song.bodyTakes.map(\.source.rawValue), bodySources, "one take each, in the order of the sources")
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(song)), song, "and the song opens again as it was")

        var made = Project()
        made.bodyTakes = [oneStretch(of: .lfo1)]
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(made)), "a file with a take of the LFO is refused") { error in
            guard case .invalidContent = error as? ProjectCodec.DecodeError else { return XCTFail("\(error)") }
        }
    }

    func testABrokenTakeIsRefusedAndTheSongStaysAsItWas() throws {
        var song = Project()
        try Command.setBodyTake(oneStretch(of: .breath)).apply(to: &song)
        let before = song
        var tooMany: [(tick: Tick, value: Double)] = []
        for index in 0...BodyTake.maximumPoints { tooMany.append((Tick(index), 0.5)) }
        let broken: [(reason: String, take: BodyTake)] = [
            ("two points on one tick", BodyTake(source: .breath, runs: [stretch([(0, 0.5), (0, 0.6)])])),
            ("a tick that falls back", BodyTake(source: .breath, runs: [stretch([(0, 0.5), (64, 0.6), (32, 0.7)])])),
            ("a stretch from the tick the one before ends on",
             BodyTake(source: .breath, runs: [stretch([(0, 0.5), (100, 0.6)]), stretch([(100, 0.6), (200, 0.7)])])),
            ("a stretch inside the one before",
             BodyTake(source: .breath, runs: [stretch([(0, 0.5), (100, 0.6)]), stretch([(50, 0.6), (200, 0.7)])])),
            ("stretches out of order",
             BodyTake(source: .breath, runs: [stretch([(1_000, 0.5), (2_000, 0.6)]), stretch([(0, 0.6), (100, 0.7)])])),
            ("a tick before the song", BodyTake(source: .heartRate, runs: [stretch([(-1, 0.5), (32, 0.5)])])),
            ("a tick past the song",
             BodyTake(source: .heartRate, runs: [stretch([(0, 0.5), (MusicalTime.maximumTick + 1, 0.5)])])),
            ("a value that is not a number", BodyTake(source: .breath, runs: [stretch([(0, .nan), (32, 0.5)])])),
            ("a value without end", BodyTake(source: .breath, runs: [stretch([(0, 0.5), (32, .infinity)])])),
            ("a value below 0", BodyTake(source: .breath, runs: [stretch([(0, -0.001), (32, 0.5)])])),
            ("a value above 1", BodyTake(source: .breath, runs: [stretch([(0, 0.5), (32, 1.001)])])),
            ("a stretch of one point", BodyTake(source: .breath, runs: [stretch([(0, 0.5)])])),
            ("no stretch at all", BodyTake(source: .breath, runs: [])),
            ("one point past the limit", BodyTake(source: .breath, runs: [stretch(tooMany)])),
            ("a stated error that is not a number", oneStretch(of: .breath, tolerance: .nan)),
            ("a stated error below 0", oneStretch(of: .breath, tolerance: -0.001)),
            ("a stated error above 1 %", oneStretch(of: .breath, tolerance: 0.0101)),
            ("a stated error without end", oneStretch(of: .breath, tolerance: .infinity)),
        ]
        for (reason, take) in broken {
            var attempt = song
            XCTAssertThrowsError(try Command.setBodyTake(take).apply(to: &attempt), reason)
            XCTAssertEqual(attempt, before, "\(reason): the song stays as it was")
            var stored = before
            stored.bodyTakes = [take]
            XCTAssertThrowsError(try stored.validate(), "\(reason): the reader refuses a song that holds it")
        }

        // On each edge, a take the song keeps.
        var full: [(tick: Tick, value: Double)] = []
        for index in 0..<BodyTake.maximumPoints { full.append((Tick(index), 0.5)) }
        let edges: [(reason: String, take: BodyTake)] = [
            ("as many points as a take holds", BodyTake(source: .breath, runs: [stretch(full)])),
            ("the song's first and last tick, 0 and 1",
             BodyTake(source: .breath, runs: [stretch([(0, 0), (MusicalTime.maximumTick, 1)])])),
            ("a stretch from the tick after the one before ends",
             BodyTake(source: .breath, runs: [stretch([(0, 0.5), (100, 0.6)]), stretch([(101, 0.6), (200, 0.7)])])),
            ("no error at all: every point a reading", oneStretch(of: .breath, tolerance: 0)),
            ("the largest error a recording states", oneStretch(of: .breath, tolerance: 0.01)),
        ]
        for (reason, take) in edges {
            var kept = song
            XCTAssertNoThrow(try Command.setBodyTake(take).apply(to: &kept), reason)
            XCTAssertEqual(kept.bodyTakes, [take], "\(reason): it replaces the source's take")
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(kept)), kept, "\(reason): and the song opens again")
        }

        var removed = song
        XCTAssertThrowsError(try Command.removeBodyTake(.coherence).apply(to: &removed), "a source without a take")
        XCTAssertEqual(removed, before)
    }

    func testRecordingAndUndoAreOneStep() async throws {
        // One recording of the breath and the pulse, landed as a capture lands it, then a second
        // pass over part of the breath.
        var breathing = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        var beating = try XCTUnwrap(BodyTakeRecorder(source: .heartRate))
        for index in 0...200 {
            let position = Double(index) * 32
            breathing.record(0.5 + 0.3 * Foundation.sin(position / 600), atPosition: position)
            beating.record(0.45 + Double(index) / 4_000, atPosition: position)
        }
        let breath = try XCTUnwrap(breathing.landing(over: nil).take)
        let pulse = try XCTUnwrap(beating.landing(over: nil).take)
        var again = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for index in 80...120 { again.record(0.9, atPosition: Double(index) * 32) }
        let punched = try XCTUnwrap(again.landing(over: breath).take)
        XCTAssertNotEqual(punched, breath)
        let broken = BodyTake(source: .breath, tolerance: .nan, runs: breath.runs)
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform([.setBodyTake(breath), .setBodyTake(pulse)], title: "Record Body")
            XCTAssertEqual(store.undoStack.count, 1, "one Stop, one step, however many sources it kept")
            XCTAssertEqual(store.project.bodyTakes, [pulse, breath], "in the order of the sources, not of the recording")
            try store.perform(.setBodyTake(punched))
            XCTAssertEqual(store.undoTitle, "Edit Body Take")
            XCTAssertEqual(store.project.bodyTake(of: .breath), punched)
            store.undo()
            XCTAssertEqual(store.project.bodyTake(of: .breath), breath, "undo brings the earlier take back exactly")
            store.undo()
            XCTAssertEqual(store.project, Project(), "and before the recording the song had none")
            store.redo()
            XCTAssertEqual(store.project.bodyTakes, [pulse, breath])
            try store.perform(.removeBodyTake(.heartRate))
            XCTAssertEqual(store.undoTitle, "Delete Body Take")
            XCTAssertEqual(store.project.bodyTakes, [breath])
            store.undo()
            XCTAssertEqual(store.project.bodyTakes, [pulse, breath], "a deleted take comes back with one undo")
            let steps = store.undoStack.count
            XCTAssertThrowsError(try store.perform(.setBodyTake(broken)))
            XCTAssertThrowsError(try store.perform(.removeBodyTake(.coherence)))
            XCTAssertEqual(store.undoStack.count, steps, "a refused edit is no step")
            XCTAssertEqual(store.project.bodyTakes, [pulse, breath])
            try store.perform(.removeBodyTake(.breath))
            try store.perform(.removeBodyTake(.heartRate))
            XCTAssertEqual(store.project, Project(), "with every take deleted the song holds none, not an empty list")
            let root = try JSONSerialization.jsonObject(with: ProjectCodec.encode(store.project)) as? [String: Any]
            XCTAssertNil(root?["bodyTakes"], "and its file has no key for them")
        }
    }

    func testATakeTheRecorderLandsIsOneTheSongKeeps() throws {
        // Recordings with gaps, over a loop's passes, across a jump, at the limit and over an
        // earlier take: each lands as a take the door lets in and the reader opens.
        var numbers = Numbers(state: 7)
        var gaps = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for index in 0..<3_000 {
            let value = 0.5 + 0.3 * Foundation.sin(Double(index) / 90) + 0.02 * numbers.next()
            gaps.record(index % 700 < 30 ? nil : value, atPosition: 31.75 * Double(index))
        }
        var loop = try XCTUnwrap(BodyTakeRecorder(source: .hrv))
        for lap in 0..<3 {
            for reading in pass(from: lap == 0 ? 1_920 : 10, through: 7_660, level: 0.2 + 0.3 * Double(lap)) {
                loop.record(reading.value, atPosition: Double(reading.tick))
            }
            if lap < 2 { loop.wrap(from: 7_680, to: 0) }
        }
        var jump = try XCTUnwrap(BodyTakeRecorder(source: .motionTiltX))
        for index in 0..<300 { jump.record(0.3, atPosition: Double(index) * 32) }
        jump.wrap(from: 9_600, to: 50_000)
        for index in 0..<300 { jump.record(0.7, atPosition: 50_000 + Double(index) * 32) }
        var busy = try XCTUnwrap(BodyTakeRecorder(source: .motionEnergy, maximumPoints: 1_000))
        for index in 0..<3_000 {
            let size = 0.006 + 0.003 * numbers.next()
            busy.record(index % 2 == 0 ? 0.5 + size : 0.5 - size, atPosition: Double(index) * 32)
        }
        let earlier = try XCTUnwrap(gaps.landing(over: nil).take)
        var punch = try XCTUnwrap(BodyTakeRecorder(source: .breath))
        for index in 1_000...1_400 { punch.record(0.8, atPosition: 31.75 * Double(index)) }
        let landings = [gaps.landing(over: nil), loop.landing(over: nil), jump.landing(over: nil), busy.landing(over: nil),
                        punch.landing(over: earlier)]
        guard case .stopped = landings[3].outcome else { return XCTFail("the busy recording stops at the limit") }
        var song = Project()
        for landing in landings {
            let take = try XCTUnwrap(landing.take)
            XCTAssertNil(take.problem, "\(take.source.rawValue): \(landing.outcome)")
            try Command.setBodyTake(take).apply(to: &song)
        }
        XCTAssertEqual(song.bodyTakes.map(\.source), [.hrv, .breath, .motionTiltX, .motionEnergy])
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(song)), song)
    }

    func testEveryBodySourceCanKeepAFullTakeInOneSong() throws {
        // The most a song's takes can hold: every body source at the limit, the ticks past a million
        // and each value one that needs all its digits.
        var numbers = Numbers(state: 8)
        var song = Project()
        for source in ModulationSource.allCases where BioEgressPolicy.measuresBody(source) {
            var points: [BodyTake.Point] = []
            points.reserveCapacity(BodyTake.maximumPoints)
            for index in 0..<BodyTake.maximumPoints {
                points.append(point(1_000_000 + Tick(index) * step, numbers.next()))
            }
            try Command.setBodyTake(BodyTake(source: source, runs: [BodyTake.Run(points: points)])).apply(to: &song)
        }
        let data = try ProjectCodec.encode(song)
        XCTAssertLessThan(data.count, ProjectCodec.maximumDocumentBytes / 2,
                          "a full take of every body source leaves more than half of a song's room to the rest of it")
        // Compared whole, not printed: a failure would otherwise write 400 000 points into the log.
        XCTAssertTrue(try ProjectCodec.decode(data) == song, "and the song opens again with every value as it was")
    }

    func testTheCatalogNamesTheBodyTakeCommands() {
        XCTAssertEqual(Command.setBodyTake(oneStretch(of: .breath)).kind, .setBodyTake)
        XCTAssertEqual(Command.removeBodyTake(.breath).kind, .removeBodyTake)
        XCTAssertEqual(CommandCatalog.spec(for: .setBodyTake).name, "body.take.set")
        XCTAssertEqual(CommandCatalog.spec(for: .removeBodyTake).name, "body.take.remove")
    }
}

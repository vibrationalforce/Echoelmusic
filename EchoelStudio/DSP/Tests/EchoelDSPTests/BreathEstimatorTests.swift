import Foundation
import XCTest
@testable import EchoelDSP

/// The breath from the heartbeat (W12b): a heart whose rate swings with a breath reads as that
/// breath — its rate, and the top of a breath in at the top — and nothing else reads as a breath.
final class BreathEstimatorTests: XCTestCase {
    private struct Beat {
        let interval: Double
        let end: Double
    }

    private struct Reading {
        let time: Double
        let amplitude: Double
        let breath: Double?
        let confidence: Double
        let rate: Double?
    }

    /// A heart whose rate is `pulse + swing · sin(2π · perMinute/60 · t + phase)`: breathing in
    /// speeds it up, so the top of a breath in is where the sine is 1. Beats where the heart's
    /// phase completes a turn, on a one-millisecond step.
    private func breathing(seconds: Double, pulse: Double, swing: Double, perMinute: Double,
                           phase: Double = 0) -> [Beat] {
        var beats: [Beat] = []
        var time = 0.0
        var heart = 0.0
        var last = 0.0
        let step = 0.001
        let frequency = perMinute / 60
        while time < seconds {
            let rate = pulse + swing * Foundation.sin(2 * Double.pi * frequency * time + phase)
            heart += rate / 60 * step
            time += step
            if heart >= 1 {
                heart -= 1
                beats.append(Beat(interval: (time - last) * 1_000, end: time))
                last = time
            }
        }
        return beats
    }

    /// Where the breath stands at `time` in the heart `breathing` makes: 1 at the top of a breath in.
    private func truth(_ time: Double, perMinute: Double, phase: Double = 0) -> Double {
        Foundation.sin(2 * Double.pi * perMinute / 60 * time + phase)
    }

    /// A seeded generator, the same numbers on every platform.
    private struct Numbers {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
    }

    /// Beats fed when they end, the estimator aged every `tick` in between.
    private func drive(_ beats: [Beat], into estimator: inout BreathEstimator, until stop: Double,
                       tick: Double = 0.05, resolution: Double = 1) -> [Reading] {
        var readings: [Reading] = []
        var next = 0
        var time = 0.0
        while time <= stop {
            while next < beats.count, beats[next].end <= time {
                estimator.add(intervalMilliseconds: beats[next].interval, endingAt: beats[next].end,
                              resolutionMilliseconds: resolution)
                next += 1
            }
            estimator.age(to: time)
            readings.append(Reading(time: time, amplitude: estimator.amplitude, breath: estimator.breath,
                                    confidence: estimator.confidence, rate: estimator.ratePerMinute))
            time += tick
        }
        return readings
    }

    private func mean(_ values: [Double]) -> Double {
        values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count)
    }

    /// The rate, the top of a breath in at the top, and how soon it is published, for one breath.
    private func assertReads(perMinute: Double, pulse: Double, swing: Double, publishedBefore: Double,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        for phase in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 3) {
            var estimator = BreathEstimator()
            let beats = breathing(seconds: 150, pulse: pulse, swing: swing, perMinute: perMinute, phase: phase)
            let readings = drive(beats, into: &estimator, until: 150)
            let rate = try XCTUnwrap(estimator.ratePerMinute, "a rate after 150 s", file: file, line: line)
            XCTAssertEqual(rate, perMinute, accuracy: 1, "the breaths a minute", file: file, line: line)
            let first = try XCTUnwrap(readings.first { $0.breath != nil }, "published at all", file: file, line: line)
            XCTAssertLessThan(first.time, publishedBefore, "published soon enough", file: file, line: line)
            let settled = readings.filter { $0.time > 60 }
            let published = settled.filter { $0.breath != nil }
            XCTAssertGreaterThan(Double(published.count) / Double(settled.count), 0.95,
                                 "an even breath stays published", file: file, line: line)
            let inhaled = settled.filter { truth($0.time, perMinute: perMinute, phase: phase) > 0.95 }.map(\.amplitude)
            let exhaled = settled.filter { truth($0.time, perMinute: perMinute, phase: phase) < -0.95 }.map(\.amplitude)
            XCTAssertGreaterThan(mean(inhaled), 0.8, "the top of a breath in is the top", file: file, line: line)
            XCTAssertLessThan(mean(exhaled), 0.2, "the bottom of a breath out is the bottom", file: file, line: line)
        }
    }

    // MARK: A breath reads as itself

    func testSixBreathsAMinuteReadAsSixWithTheTopOfABreathInAtTheTop() throws {
        try assertReads(perMinute: 6, pulse: 65, swing: 6, publishedBefore: 50)
    }

    func testFifteenBreathsAMinuteReadAsFifteenWithTheTopOfABreathInAtTheTop() throws {
        try assertReads(perMinute: 15, pulse: 70, swing: 4, publishedBefore: 30)
    }

    /// Beats that arrive a second and a half late, a second's worth at a time — a camera's way —
    /// still put the top of a breath in at the top: the swing is turned forward to now.
    func testLateBeatsStillPutTheTopOfABreathInAtTheTop() {
        var estimator = BreathEstimator()
        let beats = breathing(seconds: 150, pulse: 65, swing: 6, perMinute: 6)
        var inhaled: [Double] = []
        var exhaled: [Double] = []
        var next = 0
        var time = 0.0
        while time <= 150 {
            if Int((time * 20).rounded()) % 20 == 0 {
                while next < beats.count, beats[next].end + 1.5 <= time {
                    estimator.add(intervalMilliseconds: beats[next].interval, endingAt: beats[next].end)
                    next += 1
                }
            }
            estimator.age(to: time)
            if time > 60, estimator.breath != nil {
                let now = truth(time, perMinute: 6)
                if now > 0.95 { inhaled.append(estimator.amplitude) }
                if now < -0.95 { exhaled.append(estimator.amplitude) }
            }
            time += 0.05
        }
        XCTAssertFalse(inhaled.isEmpty)
        XCTAssertGreaterThan(mean(inhaled), 0.8)
        XCTAssertLessThan(mean(exhaled), 0.2)
    }

    // MARK: Nothing else reads as a breath

    /// Beats at random intervals cross zero as often as a breath does; they do not repeat, so the
    /// confidence stays low and nothing is published.
    func testRandomBeatsReadAsNoBreath() {
        for seed in UInt64(1)...5 {
            var numbers = Numbers(state: seed)
            var beats: [Beat] = []
            var time = 0.0
            while time < 300 {
                let interval = 600 + 600 * numbers.next()
                time += interval / 1_000
                beats.append(Beat(interval: interval, end: time))
            }
            var estimator = BreathEstimator()
            let readings = drive(beats, into: &estimator, until: 300, tick: 0.2)
            let published = readings.filter { $0.breath != nil }.count
            XCTAssertLessThan(Double(published) / Double(readings.count), 0.01, "seed \(seed)")
            XCTAssertLessThan(mean(readings.map(\.confidence)), 0.05, "seed \(seed)")
        }
    }

    /// A pulse steady against a camera's frames makes a long-and-short pattern that repeats as
    /// evenly as a breath. Its swing is a fraction of one frame step, so a source that names its
    /// frame period never reads it as a breath.
    func testASteadyPulseOnACamerasFramesReadsAsNoBreath() {
        let frame = 1_000.0 / 15
        for seed in UInt64(1)...3 {
            var numbers = Numbers(state: seed)
            var times: [Double] = [0]
            var time = 0.0
            while time < 300 {
                time += (750 + 6 * (numbers.next() - 0.5)) / 1_000
                times.append((time * 1_000 / frame).rounded(.down) * frame / 1_000)
            }
            var beats: [Beat] = []
            for index in 1..<times.count where times[index] > times[index - 1] {
                beats.append(Beat(interval: (times[index] - times[index - 1]) * 1_000, end: times[index]))
            }
            var estimator = BreathEstimator()
            let readings = drive(beats, into: &estimator, until: 300, tick: 0.2, resolution: frame)
            XCTAssertTrue(readings.allSatisfy { $0.breath == nil }, "seed \(seed)")
        }
    }

    // MARK: Old data

    /// When the beats stop, the confidence holds a few seconds — beats arrive late and in batches —
    /// then falls to nothing.
    func testTheConfidenceFallsWhenTheBeatsStop() throws {
        var estimator = BreathEstimator()
        let beats = breathing(seconds: 90, pulse: 65, swing: 6, perMinute: 6)
        let last = try XCTUnwrap(beats.last).end
        _ = drive(beats, into: &estimator, until: last)
        XCTAssertNotNil(estimator.breath)
        estimator.age(to: last + 3)
        let held = estimator.confidence
        XCTAssertGreaterThan(held, BreathEstimator.publishConfidence, "three seconds without a beat still hold")
        estimator.age(to: last + 5)
        XCTAssertLessThan(estimator.confidence, held, "five seconds on, it falls")
        estimator.age(to: last + 7)
        XCTAssertEqual(estimator.confidence, 0)
        XCTAssertNil(estimator.breath, "seven seconds on, no breath")
        estimator.age(to: last + 4)
        XCTAssertEqual(estimator.confidence, 0, "time does not run back")
    }

    /// When the breathing stops and the heart beats on evenly, the breath ends within a few
    /// breaths' time; it is not held on the strength of the last one.
    func testTheBreathEndsWhenTheBreathingStops() throws {
        var estimator = BreathEstimator()
        var beats = breathing(seconds: 90, pulse: 65, swing: 6, perMinute: 6)
        var time = try XCTUnwrap(beats.last).end
        let stopped = time
        var numbers = Numbers(state: 7)
        while time < stopped + 60 {
            let interval = 923 + 10 * (numbers.next() - 0.5)
            time += interval / 1_000
            beats.append(Beat(interval: interval, end: time))
        }
        let readings = drive(beats, into: &estimator, until: time)
        XCTAssertNotNil(readings.last { $0.time < stopped }?.breath, "breathing, it is published")
        let later = readings.filter { $0.time > stopped + 35 }
        XCTAssertFalse(later.isEmpty)
        XCTAssertTrue(later.allSatisfy { $0.breath == nil }, "35 s after the breathing stopped, no breath")
    }

    // MARK: At the boundary

    /// Not a number, an endless or implausible interval, a time that is not a number or does not
    /// move forward: each is ignored, and the reading is exactly what the clean beats give.
    func testBeatsThatCannotBeRealChangeNothing() throws {
        let beats = breathing(seconds: 90, pulse: 65, swing: 6, perMinute: 6)
        var clean = BreathEstimator()
        var guarded = BreathEstimator()
        for beat in beats {
            clean.add(intervalMilliseconds: beat.interval, endingAt: beat.end)
            guarded.add(intervalMilliseconds: beat.interval, endingAt: beat.end)
            for interval in [Double.nan, .infinity, -.infinity, -800, 0, 250, 2_500] {
                guarded.add(intervalMilliseconds: interval, endingAt: beat.end + 0.01)
            }
            for end in [Double.nan, .infinity, beat.end, beat.end - 1] {
                guarded.add(intervalMilliseconds: 900, endingAt: end)
            }
            guarded.add(intervalMilliseconds: 900, endingAt: beat.end, resolutionMilliseconds: .nan)
            guarded.age(to: .nan)
            guarded.age(to: beat.end - 0.5)
            clean.age(to: beat.end)
            guarded.age(to: beat.end)
            XCTAssertEqual(guarded.amplitude, clean.amplitude)
            XCTAssertEqual(guarded.confidence, clean.confidence)
        }
        XCTAssertEqual(try XCTUnwrap(guarded.ratePerMinute), try XCTUnwrap(clean.ratePerMinute))
        XCTAssertEqual(guarded.breath, clean.breath)
    }

    /// A missed beat — one interval twice as long — is left out, not read as a breath out.
    func testAMissedBeatNowAndThenLeavesTheBreath() throws {
        let beats = breathing(seconds: 150, pulse: 65, swing: 6, perMinute: 6)
        var thinned: [Beat] = []
        var index = 0
        while index < beats.count {
            if index % 23 == 11, index + 1 < beats.count {
                thinned.append(Beat(interval: beats[index].interval + beats[index + 1].interval, end: beats[index + 1].end))
                index += 2
            } else {
                thinned.append(beats[index])
                index += 1
            }
        }
        var estimator = BreathEstimator()
        let readings = drive(thinned, into: &estimator, until: 150)
        XCTAssertEqual(try XCTUnwrap(estimator.ratePerMinute), 6, accuracy: 1)
        let settled = readings.filter { $0.time > 60 }
        XCTAssertGreaterThan(Double(settled.filter { $0.breath != nil }.count) / Double(settled.count), 0.9)
    }

    /// A pause longer than a few seconds begins a new run: nothing before it vouches for what comes
    /// after, so the breath is measured anew.
    func testAPauseBeginsANewRun() throws {
        let beats = breathing(seconds: 200, pulse: 65, swing: 6, perMinute: 6)
        let paused = beats.filter { $0.end < 70 || $0.end > 80 }
        var estimator = BreathEstimator()
        let readings = drive(paused, into: &estimator, until: 200)
        XCTAssertNotNil(readings.last { $0.time < 70 }?.breath, "measured before the pause")
        let after = try XCTUnwrap(readings.first { $0.time > 80.5 })
        XCTAssertNil(after.breath, "a new run starts unmeasured")
        XCTAssertNil(after.rate)
        XCTAssertEqual(after.confidence, 0)
        XCTAssertNotNil(readings.last?.breath, "and measures the breath again")
    }

    /// A strap sends its intervals in packets; they are placed back from the packet's arrival,
    /// which reads exactly as the same beats one by one.
    func testAPacketReadsAsItsBeatsPlacedBackFromItsArrival() throws {
        let beats = breathing(seconds: 90, pulse: 65, swing: 6, perMinute: 6)
        var single = BreathEstimator()
        var packed = BreathEstimator()
        var index = 0
        while index < beats.count {
            let size = index % 3 == 0 && index + 1 < beats.count ? 2 : 1
            let packet = beats[index..<(index + size)]
            for beat in packet { single.add(intervalMilliseconds: beat.interval, endingAt: beat.end) }
            let arrival = try XCTUnwrap(packet.last).end
            packed.add(packet: packet.map(\.interval), arrivedAt: arrival)
            single.age(to: arrival)
            packed.age(to: arrival)
            XCTAssertEqual(packed.amplitude, single.amplitude, accuracy: 1e-9)
            XCTAssertEqual(packed.confidence, single.confidence, accuracy: 1e-9)
            index += size
        }
        XCTAssertEqual(try XCTUnwrap(packed.ratePerMinute), try XCTUnwrap(single.ratePerMinute), accuracy: 1e-9)
    }

    /// Nothing is said before a breath has been measured: no rate, no breath, no confidence.
    func testNothingIsSaidBeforeABreathIsMeasured() {
        var estimator = BreathEstimator()
        let beats = breathing(seconds: 8, pulse: 65, swing: 6, perMinute: 6)
        let readings = drive(beats, into: &estimator, until: 8)
        XCTAssertTrue(readings.allSatisfy { $0.breath == nil && $0.rate == nil && $0.confidence == 0 })
        estimator.reset()
        XCTAssertNil(estimator.ratePerMinute)
        XCTAssertEqual(estimator.amplitude, 0.5)
    }
}

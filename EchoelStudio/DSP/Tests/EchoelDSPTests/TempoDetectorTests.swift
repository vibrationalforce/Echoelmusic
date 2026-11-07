import Foundation
import XCTest
@testable import EchoelDSP

/// W-1: the tempo a loop was played at, heard from its samples (the earlier app's detector, ported).
final class TempoDetectorTests: XCTestCase {
    private let rate = 48_000.0

    /// A 4 ms click at 3 kHz, dying away over a millisecond.
    private func click() -> [Float] {
        let count = Int(rate * 0.004)
        return (0..<count).map { (index: Int) -> Float in
            let t = Double(index) / rate
            let tone = Foundation.sin(2 * Double.pi * 3_000 * t)
            return Float(tone * Foundation.exp(-t / 0.001))
        }
    }

    /// A 150 ms kick: a sine falling from 145 Hz to 55 Hz, dying away over 50 ms.
    private func kick() -> [Float] {
        let count = Int(rate * 0.15)
        return (0..<count).map { (index: Int) -> Float in
            let t = Double(index) / rate
            let hertz = 55 + 90 * Foundation.exp(-t / 0.02)
            let tone = Foundation.sin(2 * Double.pi * hertz * t)
            return Float(tone * Foundation.exp(-t / 0.05))
        }
    }

    /// `sound` on every beat at `bpm`, for `seconds`.
    private func train(_ sound: [Float], bpm: Double, seconds: Double) -> [Float] {
        var samples = [Float](repeating: 0, count: Int(seconds * rate))
        let period = 60 / bpm
        var beat = 0
        while Double(beat) * period < seconds {
            let start = Int((Double(beat) * period * rate).rounded())
            for (offset, value) in sound.enumerated() where start + offset < samples.count {
                samples[start + offset] += value
            }
            beat += 1
        }
        return samples
    }

    /// The same tempo whatever its octave: folded into 80…160 BPM, as the break slicer folds it.
    private func folded(_ bpm: Double) -> Double {
        var value = bpm
        while value >= 160 { value /= 2 }
        while value < 80 { value *= 2 }
        return value
    }

    func testAClickOrKickTrainIsHeardAtItsTempo() throws {
        for bpm in [93.5, 128, 174] {
            for (name, sound) in [("click", click()), ("kick", kick())] {
                let samples = train(sound, bpm: bpm, seconds: 10)
                let heard = try XCTUnwrap(TempoDetector.detect(samples, sampleRate: rate), "\(name) at \(bpm)")
                XCTAssertEqual(folded(heard.bpm), folded(bpm), accuracy: 0.5, "\(name) at \(bpm)")
                XCTAssertTrue(heard.isKnown)
                XCTAssertGreaterThanOrEqual(heard.confidence, TempoDetector.confidenceFloor)
            }
        }
    }

    func testNoiseAndAHeldToneHaveNoTempo() {
        var state: UInt64 = 7
        let count = Int(10 * rate)
        var noise = [Float](repeating: 0, count: count)
        for index in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(state >> 11) / 9_007_199_254_740_992.0
            noise[index] = Float((unit * 2 - 1) * 0.3)
        }
        XCTAssertNil(TempoDetector.detect(noise, sampleRate: rate), "noise")

        for hertz in [440.0, 41.2] {
            let held = (0..<count).map { (index: Int) -> Float in
                let t = Double(index) / rate
                return Float(0.5 * Foundation.sin(2 * Double.pi * hertz * t))
            }
            XCTAssertNil(TempoDetector.detect(held, sampleRate: rate), "a held \(hertz) Hz sine")
        }
    }

    func testAWholeLoopTakesTheExactTempoItsLengthImplies() throws {
        // Four bars at 128 BPM are 7.5 s.
        let heard = try XCTUnwrap(TempoDetector.detect(train(kick(), bpm: 128, seconds: 7.5), sampleRate: rate))
        XCTAssertEqual(heard.loopBars, 4)
        XCTAssertEqual(heard.bpm, 128, accuracy: 1e-9)
        XCTAssertEqual(heard.octaveAlternativeBPM, 64, accuracy: 1e-9)
    }

    func testADecodedSampleIsHeardAsItsSamplesAre() throws {
        let samples = train(kick(), bpm: 128, seconds: 10)
        let mono = try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate))
        XCTAssertNotNil(TempoDetector.detect(mono))
        XCTAssertEqual(TempoDetector.detect(mono), TempoDetector.detect(samples, sampleRate: rate))

        let quieter: [Float] = samples.map { (value: Float) -> Float in value * 0.5 }
        let stereo = try XCTUnwrap(SampleBuffer(left: samples, right: quieter, sampleRate: rate))
        XCTAssertEqual(stereo.channelCount, 2)
        let heard = try XCTUnwrap(TempoDetector.detect(stereo))
        XCTAssertEqual(heard.bpm, 128, accuracy: 0.5)
    }

    func testTooShortSilentOrCancelledHearsNothing() {
        XCTAssertNil(TempoDetector.detect(train(click(), bpm: 128, seconds: 1), sampleRate: rate), "one second")
        XCTAssertNil(TempoDetector.detect([Float](repeating: 0, count: Int(8 * rate)), sampleRate: rate), "silence")
        XCTAssertNil(TempoDetector.detect([], sampleRate: rate))
        XCTAssertNil(TempoDetector.detect(train(click(), bpm: 128, seconds: 10), sampleRate: .nan))
        XCTAssertNil(TempoDetector.detect(train(click(), bpm: 128, seconds: 10), sampleRate: rate, isCancelled: { true }))
    }

    func testTheEnvelopeDoesNotDependOnHowTheStreamWasCut() throws {
        let samples = train(kick(), bpm: 110, seconds: 3)
        var whole = try XCTUnwrap(TempoOnsetEnvelope(sampleRate: rate, maxSeconds: 90))
        whole.append(samples)
        var pieces = try XCTUnwrap(TempoOnsetEnvelope(sampleRate: rate, maxSeconds: 90))
        var start = 0
        while start < samples.count {
            let end = Swift.min(samples.count, start + 1_001)
            pieces.append(samples[start..<end])
            start = end
        }
        XCTAssertEqual(whole.values, pieces.values)
        XCTAssertFalse(whole.values.isEmpty)
    }
}

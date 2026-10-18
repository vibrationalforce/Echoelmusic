import Foundation
import XCTest
@testable import EchoelDSP

final class LoudnessMeterTests: XCTestCase {
    private let rate = 48_000.0

    private func measure(seconds: Double, rate: Double = 48_000, _ sample: (Int) -> (Float, Float)) -> LoudnessMeter {
        var meter = LoudnessMeter(sampleRate: rate)
        let frames = Int(seconds * rate)
        var left = [Float](repeating: 0, count: 1_000), right = left
        var done = 0
        while done < frames {
            let n = Swift.min(1_000, frames - done)
            for i in 0..<n { (left[i], right[i]) = sample(done + i) }
            left.withUnsafeBufferPointer { l in
                right.withUnsafeBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    meter.process(left: lp, right: rp, count: n)
                }
            }
            done += n
        }
        return meter
    }

    private func sine(amplitude: Float, frequency: Double, rate: Double = 48_000) -> (Int) -> (Float, Float) {
        { i in
            let value = amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / rate))
            return (value, value)
        }
    }

    /// EBU Tech 3341 case 1: a stereo 1 kHz sine at −23 dBFS reads −23 LUFS.
    func testAStereoSineAtMinus23DBFSReadsMinus23LUFS() {
        let meter = measure(seconds: 10, sine(amplitude: Float(pow(10, -23.0 / 20)), frequency: 1_000))
        XCTAssertEqual(meter.integratedLoudness, -23, accuracy: 0.1)
    }

    func testTheReadingHoldsAtAnotherSampleRate() {
        let meter = measure(seconds: 10, rate: 44_100,
                            sine(amplitude: Float(pow(10, -23.0 / 20)), frequency: 1_000, rate: 44_100))
        XCTAssertEqual(meter.integratedLoudness, -23, accuracy: 0.1)
    }

    /// EBU Tech 3341 case 3 shape: quiet passages below the relative gate do not pull the
    /// reading down.
    func testTheRelativeGateIgnoresQuietPassages() {
        let loud = sine(amplitude: Float(pow(10, -20.0 / 20)), frequency: 1_000)
        let quiet = sine(amplitude: Float(pow(10, -40.0 / 20)), frequency: 1_000)
        let meter = measure(seconds: 20) { i in i < 480_000 ? quiet(i) : loud(i) }
        XCTAssertEqual(meter.integratedLoudness, -20, accuracy: 0.2)
    }

    func testSilenceHasNoLoudnessAndNoPeak() {
        let meter = measure(seconds: 2) { _ in (0, 0) }
        XCTAssertEqual(meter.integratedLoudness, LoudnessMeter.silent)
        XCTAssertEqual(meter.truePeak, LoudnessMeter.silent)
    }

    func testTheTruePeakFindsThePeakBetweenSamples() {
        // A quarter-rate sine at 45° lands every sample at ±0.707 of its true peak.
        let meter = measure(seconds: 1) { i in
            let value = Float(sin(Double.pi / 2 * Double(i) + Double.pi / 4))
            return (value * 0.5, 0)
        }
        XCTAssertEqual(meter.truePeak, 20 * Foundation.log10(0.5), accuracy: 0.3)
    }

    func testNonFiniteSamplesCountAsSilence() {
        let meter = measure(seconds: 1) { _ in (.nan, .infinity) }
        XCTAssertEqual(meter.truePeak, LoudnessMeter.silent)
    }
}

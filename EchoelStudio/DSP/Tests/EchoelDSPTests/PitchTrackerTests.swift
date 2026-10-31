import Foundation
import XCTest
@testable import EchoelDSP

final class PitchTrackerTests: XCTestCase {
    /// A tone with a strong second harmonic, the way a voice carries its fundamental.
    private func tone(_ hertz: Double, rate: Double, seconds: Double = 0.3) -> [Float] {
        let count = Int(rate * seconds)
        return (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / rate
            return Float(0.5 * Foundation.sin(phase) + 0.2 * Foundation.sin(2 * phase))
        }
    }

    private func cents(_ found: Double, _ expected: Double) -> Double {
        1_200 * Foundation.log2(found / expected)
    }

    func testItFindsTheFundamentalWithinTwoCents() throws {
        for hertz in [82.41, 110.0, 196.0, 261.63, 440.0, 659.25, 880.0] {
            let found = try XCTUnwrap(PitchTracker.frequency(of: tone(hertz, rate: 48_000), sampleRate: 48_000),
                                      "\(hertz) Hz")
            XCTAssertEqual(cents(found, hertz), 0, accuracy: 2, "\(hertz) Hz")
        }
    }

    func testItWorksAtTheCommonRates() throws {
        for rate in [44_100.0, 48_000, 96_000] {
            let found = try XCTUnwrap(PitchTracker.frequency(of: tone(220, rate: rate), sampleRate: rate), "\(rate)")
            XCTAssertEqual(cents(found, 220), 0, accuracy: 2, "\(rate)")
        }
    }

    func testSilenceAndNoiseHaveNoPitch() {
        XCTAssertNil(PitchTracker.frequency(of: [Float](repeating: 0, count: 12_000), sampleRate: 48_000))
        var state: UInt64 = 12_345
        let noise = (0..<12_000).map { (_: Int) -> Float in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(Int64(bitPattern: state >> 1) % 1_000 - 500) / 1_000
        }
        XCTAssertNil(PitchTracker.frequency(of: noise, sampleRate: 48_000), "noise is not a note")
    }

    func testAnAnalysisRunsEveryHopAndAResetForgets() {
        let tracker = PitchTracker(sampleRate: 48_000)
        var analyses = 0
        for sample in tone(330, rate: 48_000) where tracker.push(sample) { analyses += 1 }
        XCTAssertEqual(analyses, Int(48_000 * 0.3) / tracker.hop)
        XCTAssertGreaterThan(tracker.frequency, 0)
        tracker.reset()
        XCTAssertEqual(tracker.period, 0)
        XCTAssertFalse(tracker.push(.nan), "a bad sample is taken as silence")
    }
}

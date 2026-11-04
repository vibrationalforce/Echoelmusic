import XCTest
@testable import EchoelDSP

final class SamplePitchTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, seconds: Double = 2, level: Float = 0.5) -> [Float] {
        let count = Int(seconds * rate)
        return (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return level * Float(sin(phase))
        }
    }

    /// A seeded noise: the same every run.
    private func noise(seconds: Double = 2) -> [Float] {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        return (0..<Int(seconds * rate)).map { (_: Int) -> Float in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(Int64(bitPattern: state >> 11) % 2_000_000) / 2_000_000 - 0.5
        }
    }

    func testASineAt220HertzReadsAsA3WithinFiveCents() throws {
        let reading = try XCTUnwrap(SamplePitch.reading(of: sine(220), sampleRate: rate))
        XCTAssertEqual(reading.note, 57, "A3 is MIDI 57")
        XCTAssertLessThanOrEqual(abs(reading.cents), 5)
        XCTAssertEqual(reading.hertz, 220, accuracy: 1)
        XCTAssertGreaterThanOrEqual(reading.confidence, SamplePitch.minimumConfidence)
    }

    func testADetunedSineReadsItsCents() throws {
        // 20 cents above A3.
        let hertz = 220 * pow(2, 20.0 / 1_200)
        let reading = try XCTUnwrap(SamplePitch.reading(of: sine(hertz), sampleRate: rate))
        XCTAssertEqual(reading.note, 57)
        XCTAssertEqual(reading.cents, 20, accuracy: 5)
    }

    func testNoiseGivesNoNote() {
        XCTAssertNil(SamplePitch.reading(of: noise(), sampleRate: rate))
    }

    func testSilenceAndASoundTooShortGiveNoNote() {
        XCTAssertNil(SamplePitch.reading(of: [Float](repeating: 0, count: 96_000), sampleRate: rate))
        XCTAssertNil(SamplePitch.reading(of: sine(220, seconds: 0.05), sampleRate: rate))
        XCTAssertNil(SamplePitch.reading(of: sine(220), sampleRate: .nan))
    }

    func testTheSameInputAlwaysGivesTheSameReading() {
        let input = sine(330)
        let first = SamplePitch.reading(of: input, sampleRate: rate)
        XCTAssertNotNil(first)
        for _ in 0..<3 { XCTAssertEqual(SamplePitch.reading(of: input, sampleRate: rate), first) }
        XCTAssertEqual(SamplePitch.measure(noise(), sampleRate: rate), SamplePitch.measure(noise(), sampleRate: rate))
    }

    func testABufferIsReadAsItsMonoMix() throws {
        let tone = sine(220)
        let buffer = try XCTUnwrap(SampleBuffer(left: tone, right: tone, sampleRate: rate))
        XCTAssertEqual(SamplePitch.reading(of: buffer)?.note, 57)
    }
}

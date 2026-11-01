import Foundation
import XCTest
@testable import EchoelDSP

final class OnsetDetectorTests: XCTestCase {
    private let rate = 22_050.0

    private func detect(_ samples: [Float], rate: Double = 22_050, block: Int = 1_000) -> [Double] {
        var detector = OnsetDetector(sampleRate: rate)
        var start = 0
        while start < samples.count {
            let end = Swift.min(start + block, samples.count)
            detector.process(Array(samples[start..<end]))
            start = end
        }
        return detector.onsets
    }

    /// A deterministic noise source, -1 … 1.
    private struct Noise {
        var seed: UInt32
        mutating func next() -> Float {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Float(Int32(bitPattern: seed)) / Float(Int32.max)
        }
    }

    /// `seconds` of silence with a hit — noise dying away over 20 ms — starting at each of `at`.
    private func hits(_ at: [Double], seconds: Double, rate: Double = 22_050, level: Float = 0.8,
                      under: (Int) -> Float = { _ in 0 }) -> [Float] {
        var noise = Noise(seed: 7)
        var samples = (0..<Int(seconds * rate)).map(under)
        for start in at {
            let first = Int((start * rate).rounded())
            for index in first..<Swift.min(samples.count, first + Int(0.2 * rate)) {
                let since = Double(index - first) / rate
                samples[index] += level * Float(Foundation.exp(-since / 0.02)) * noise.next()
            }
        }
        return samples
    }

    private func assertOnsets(_ found: [Double], _ expected: [Double], within tolerance: Double = 0.002,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(found.count, expected.count, "found \(found)", file: file, line: line)
        for (one, other) in zip(found, expected) {
            XCTAssertEqual(one, other, accuracy: tolerance, "found \(found)", file: file, line: line)
        }
    }

    func testTheFFTFindsACosineInItsBin() {
        let fft = FFT(size: 64)
        var real = (0..<64).map { (index: Int) -> Float in Float(Foundation.cos(2 * Double.pi * 5 * Double(index) / 64)) }
        var imaginary = [Float](repeating: 0, count: 64)
        fft.transform(real: &real, imaginary: &imaginary)
        for bin in 0..<64 {
            let magnitude = (real[bin] * real[bin] + imaginary[bin] * imaginary[bin]).squareRoot()
            XCTAssertEqual(magnitude, bin == 5 || bin == 59 ? 32 : 0, accuracy: 1e-3, "bin \(bin)")
        }
    }

    /// Hits in silence: each found where it starts, to the millisecond — finer than a video frame.
    func testHitsInSilenceAreFoundToTheMillisecond() {
        let expected = [0.5, 1.25, 2.0, 2.6]
        assertOnsets(detect(hits(expected, seconds: 3)), expected)
    }

    /// The same at the 48 kHz of a video's own sound.
    func testTheTimesHoldAtAnotherSampleRate() {
        let expected = [0.4, 1.1, 1.9]
        assertOnsets(detect(hits(expected, seconds: 2.5, rate: 48_000), rate: 48_000, block: 4_096), expected)
    }

    /// A held tone has no onset of its own after it is under way; hits over it do.
    func testHitsOverAHeldToneAreFoundAndTheToneIsNot() {
        let tone = { (index: Int) -> Float in Float(0.2 * Foundation.sin(2 * Double.pi * 220 * Double(index) / 22_050)) }
        let expected = [1.0, 2.0, 3.0]
        assertOnsets(detect(hits(expected, seconds: 4, level: 0.6, under: tone)), expected)
    }

    /// Steady noise and a slow swell out of it start nothing: no onset at all.
    func testSteadyNoiseAndASlowSwellHaveNoOnset() {
        var noise = Noise(seed: 3)
        let samples = (0..<Int(5 * rate)).map { (index: Int) -> Float in
            let seconds = Double(index) / 22_050
            // −40 dB of noise, swelling to −14 dB between 2 s and 4 s.
            let swell = seconds < 2 ? 0 : Swift.min(1, (seconds - 2) / 2)
            return Float(0.01 + 0.19 * swell) * noise.next()
        }
        XCTAssertEqual(detect(samples), [])
    }

    /// A sound present from the first sample did not start in the file: nothing is found at 0,
    /// and a held tone's frames, which wobble by a little, start nothing later either.
    func testASoundFromTheFirstSampleIsNoOnset() {
        let tone = { (index: Int) -> Float in Float(0.5 * Foundation.sin(2 * Double.pi * 440 * Double(index) / 22_050)) }
        XCTAssertEqual(detect((0..<Int(2 * rate)).map(tone)), [])
    }

    /// A hit far under what is heard — about −66 dBFS in digital silence — starts nothing.
    func testAHitTooQuietToHearIsNoOnset() {
        XCTAssertEqual(detect(hits([1.0], seconds: 2, level: 0.0005)), [])
        XCTAssertEqual(detect(hits([1.0], seconds: 2, level: 0.005)).count, 1, "−46 dBFS is heard")
    }

    /// A quiet hit after silence is a hit too: the log scale hears it beside a loud one.
    func testAQuietHitCountsBesideALoudOne() {
        var samples = hits([0.5], seconds: 2, level: 0.8)
        let quiet = hits([1.5], seconds: 2, level: 0.05)
        for index in samples.indices { samples[index] += quiet[index] }
        assertOnsets(detect(samples), [0.5, 1.5])
    }

    /// Two hits closer than the shortest gap are one onset.
    func testHitsCloserThanTheShortestGapCountOnce() {
        XCTAssertEqual(detect(hits([1.0, 1.02], seconds: 2)).count, 1)
    }

    /// How the samples arrive changes nothing.
    func testTheBlockSizeDoesNotChangeTheOnsets() {
        let samples = hits([0.3, 0.9, 1.7], seconds: 2)
        XCTAssertEqual(detect(samples, block: 64), detect(samples, block: 10_000))
    }

    /// Silence, and samples that are not numbers, start nothing.
    func testSilenceAndNonFiniteSamplesHaveNoOnset() {
        var samples = [Float](repeating: 0, count: Int(2 * rate))
        for index in stride(from: 1_000, to: samples.count, by: 3_000) { samples[index] = .nan }
        samples[20_000] = .infinity
        XCTAssertEqual(detect(samples), [])
        XCTAssertEqual(detect([]), [])
    }
}

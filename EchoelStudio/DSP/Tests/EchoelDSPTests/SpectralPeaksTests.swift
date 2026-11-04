import XCTest
@testable import EchoelDSP

/// The partials the Chladni plate reads: a sine is found where it is and as loud as it is,
/// silence has none, two tones are two peaks, strongest first.
final class SpectralPeaksTests: XCTestCase {
    private func sine(_ hertz: Double, amplitude: Double, count: Int, rate: Double) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / rate
            return Float(amplitude * sin(phase))
        }
    }

    private func analyze(_ samples: [Float], rate: Double = 48_000) -> SpectralPeaks {
        let analyzer = SpectrumAnalyzer(sampleRate: rate)
        samples.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress { analyzer.push(base, count: buffer.count) }
        }
        return analyzer.analyze()
    }

    func testASineIsFoundAtItsFrequencyAndLevel() {
        let peaks = analyze(sine(440, amplitude: 0.5, count: 8_192, rate: 48_000))
        XCTAssertGreaterThanOrEqual(peaks.count, 1)
        XCTAssertEqual(peaks.frequencies[0], 440, accuracy: 1.5)
        XCTAssertEqual(peaks.amplitudes[0], 0.5, accuracy: 0.03)
    }

    func testSilenceHasNoPartials() {
        let peaks = analyze([Float](repeating: 0, count: 8_192))
        XCTAssertEqual(peaks.count, 0)
        XCTAssertEqual(peaks, .silent)
    }

    func testTwoTonesAreTwoPeaksStrongestFirst() {
        let low = sine(220, amplitude: 0.2, count: 8_192, rate: 44_100)
        let high = sine(1_760, amplitude: 0.6, count: 8_192, rate: 44_100)
        let mixed = zip(low, high).map { (pair: (Float, Float)) -> Float in pair.0 + pair.1 }
        let peaks = analyze(mixed, rate: 44_100)
        XCTAssertGreaterThanOrEqual(peaks.count, 2)
        XCTAssertEqual(peaks.frequencies[0], 1_760, accuracy: 2)
        XCTAssertEqual(peaks.frequencies[1], 220, accuracy: 2)
        XCTAssertGreaterThan(peaks.amplitudes[0], peaks.amplitudes[1])
    }

    func testNonFiniteSamplesAreSilence() {
        let peaks = analyze([Float](repeating: .nan, count: 4_096))
        XCTAssertEqual(peaks.count, 0)
    }

    func testTheSameSoundGivesTheSamePeaks() {
        let samples = sine(330, amplitude: 0.3, count: 4_096, rate: 48_000)
        XCTAssertEqual(analyze(samples), analyze(samples))
    }

    func testPairsAreSortedAndBounded() {
        let pairs = (1...12).map { (index: Int) -> (frequency: Double, amplitude: Double) in
            (frequency: Double(index) * 100, amplitude: Double(index) / 12)
        }
        let peaks = SpectralPeaks(pairs + [(frequency: .nan, amplitude: 1)])
        XCTAssertEqual(peaks.count, SpectralPeaks.capacity)
        XCTAssertEqual(peaks.frequencies[0], 1_200)
        XCTAssertEqual(peaks.frequencies[7], 500)
    }
}

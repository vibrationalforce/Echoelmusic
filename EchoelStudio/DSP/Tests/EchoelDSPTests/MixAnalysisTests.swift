import XCTest
@testable import EchoelDSP

final class MixAnalysisTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hz: Double, seconds: Double = 3, amplitude: Double = 0.25) -> [Float] {
        let count = Int(rate * seconds)
        return (0..<count).map { (index: Int) -> Float in
            let phase: Double = 2 * Double.pi * hz * Double(index) / 48_000
            return Float(amplitude * sin(phase))
        }
    }

    /// Deterministic white noise (a 32-bit LCG), the same on every run and platform.
    private func noise(seconds: Double = 4, amplitude: Float = 0.2, seed: UInt32 = 1) -> [Float] {
        var state = seed
        return (0..<Int(rate * seconds)).map { (_: Int) -> Float in
            state = state &* 1_664_525 &+ 1_013_904_223
            let unit: Float = Float(state >> 8) / Float(1 << 24)
            return (unit * 2 - 1) * amplitude
        }
    }

    private func analyse(_ left: [Float], _ right: [Float], bandsOnly: Bool = false) -> MixAnalysis {
        var analyzer = MixAnalyzer(sampleRate: rate, bandsOnly: bandsOnly)
        left.withUnsafeBufferPointer { l in
            right.withUnsafeBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let n = Swift.min(512, l.count - done)
                    analyzer.process(left: a + done, right: b + done, count: n)
                    done += n
                }
            }
        }
        return analyzer.analysis
    }

    func testSilenceMeasuresNothingAndSaysSo() {
        let quiet = [Float](repeating: 0, count: 48_000)
        let report = analyse(quiet, quiet)
        XCTAssertTrue(report.isSilent)
        XCTAssertNil(report.tilt)
        XCTAssertNil(report.correlation)
        XCTAssertTrue(report.bandLevels.allSatisfy { !$0.isFinite })
    }

    func testAMonoMixIsFullyCorrelatedAndLosesNothingInMono() {
        let signal = noise()
        let report = analyse(signal, signal)
        XCTAssertEqual(report.correlation ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(report.lowCorrelation ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(report.monoLoss ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(report.sideToMid, -.infinity)
    }

    func testOppositePolarityCancelsInMono() {
        let signal = noise()
        let report = analyse(signal, signal.map { -$0 })
        XCTAssertEqual(report.correlation ?? 0, -1, accuracy: 1e-9)
        XCTAssertEqual(report.monoLoss, -.infinity)
    }

    func testUncorrelatedChannelsLoseThreeDecibelsInMono() {
        let report = analyse(noise(seed: 1), noise(seed: 99))
        XCTAssertEqual(report.correlation ?? 1, 0, accuracy: 0.05)
        XCTAssertEqual(report.monoLoss ?? 0, -3.01, accuracy: 0.3)
        XCTAssertEqual(report.sideToMid ?? 1, 0, accuracy: 0.3)
    }

    /// White noise doubles its power with every octave: +3 dB per octave band.
    func testWhiteNoiseTiltsUpThreeDecibelsAnOctave() {
        let signal = noise()
        let report = analyse(signal, signal)
        XCTAssertEqual(report.tilt ?? 0, 3.01, accuracy: 0.5)
    }

    func testASineLandsInItsOwnOctave() {
        let tone = sine(1_000)
        let report = analyse(tone, tone)
        let loudest = report.bandLevels.indices.max { report.bandLevels[$0] < report.bandLevels[$1] }
        XCTAssertEqual(loudest.map { MixAnalysis.bandCenters[$0] }, 1_000)
        // A 0.25 sine has a mean square of 0.03125, −15.05 dBFS; the band passes it at 0 dB.
        XCTAssertEqual(report.bandLevels[5], -15.05, accuracy: 0.2)
        XCTAssertLessThan(report.bandLevels[2], report.bandLevels[5] - 25, "two octaves away is far down")
    }

    func testSilentHopsDoNotLowerTheBandLevels() {
        let tone = sine(1_000)
        let padded = [Float](repeating: 0, count: 48_000 * 3) + tone
        let alone = analyse(tone, tone), late = analyse(padded, padded)
        XCTAssertEqual(late.bandLevels[5], alone.bandLevels[5], accuracy: 0.1)
    }

    func testTheSameSamplesGiveTheSameReport() {
        let left = noise(seed: 3), right = noise(seed: 4)
        XCTAssertEqual(analyse(left, right), analyse(left, right))
    }

    func testBandsOnlyMeasuresTheBandsAndNothingElse() {
        let tone = sine(250)
        let full = analyse(tone, tone), bands = analyse(tone, tone, bandsOnly: true)
        XCTAssertEqual(bands.bandLevels, full.bandLevels)
        XCTAssertNil(bands.correlation)
        XCTAssertTrue(bands.isSilent, "no loudness was measured")
    }

    func testLoudnessAgreesWithTheMeter() {
        let left = noise(seed: 5), right = noise(seed: 6)
        var meter = LoudnessMeter(sampleRate: rate)
        left.withUnsafeBufferPointer { l in
            right.withUnsafeBufferPointer { r in
                if let a = l.baseAddress, let b = r.baseAddress { meter.process(left: a, right: b, count: l.count) }
            }
        }
        let report = analyse(left, right)
        XCTAssertEqual(report.integratedLoudness, meter.integratedLoudness, accuracy: 1e-9)
        XCTAssertEqual(report.truePeak, meter.truePeak, accuracy: 1e-9)
    }

    func testTwoStemsOnTheSameOctaveAreAMaskingHint() {
        let bass = analyse(sine(125), sine(125), bandsOnly: true)
        let keys = analyse(sine(125, amplitude: 0.2), sine(125, amplitude: 0.2), bandsOnly: true)
        let lead = analyse(sine(2_000), sine(2_000), bandsOnly: true)
        let hints = MaskingHint.find(stems: [bass.bandLevels, keys.bandLevels, lead.bandLevels])
        XCTAssertEqual(hints.count, 1)
        XCTAssertEqual(hints.first?.bandCenter, 125)
        XCTAssertEqual(hints.first?.stems, [0, 1], "loudest first; the lead is elsewhere")
        XCTAssertEqual(hints.first?.spread ?? 0, 20 * log10(0.25 / 0.2), accuracy: 0.2)
    }

    func testStemsFarApartInLevelAreNoHint() {
        let loud = analyse(sine(500), sine(500), bandsOnly: true)
        let faint = analyse(sine(500, amplitude: 0.01), sine(500, amplitude: 0.01), bandsOnly: true)
        XCTAssertTrue(MaskingHint.find(stems: [loud.bandLevels, faint.bandLevels]).isEmpty)
    }
}

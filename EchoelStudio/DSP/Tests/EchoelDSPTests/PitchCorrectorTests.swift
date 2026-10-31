import Foundation
import XCTest
@testable import EchoelDSP

final class PitchCorrectorTests: XCTestCase {
    private let rate = 48_000.0
    private let cMajor = PitchCorrector.Settings.mask(root: 0, steps: [0, 2, 4, 5, 7, 9, 11])

    private func tone(_ hertz: Double, seconds: Double = 1) -> [Float] {
        (0..<Int(rate * seconds)).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(0.5 * Foundation.sin(phase) + 0.2 * Foundation.sin(2 * phase))
        }
    }

    private func run(_ corrector: PitchCorrector, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                corrector.process(left: x, right: y, frames: a.count)
            }
        }
        return l
    }

    private func cents(_ found: Double, _ expected: Double) -> Double {
        1_200 * Foundation.log2(found / expected)
    }

    private func pitch(of samples: some Collection<Float>) throws -> Double {
        try XCTUnwrap(PitchTracker.frequency(of: Array(samples), sampleRate: rate))
    }

    private func level(_ samples: some Collection<Float>) -> Double {
        let squares = samples.reduce(0.0) { (sum: Double, sample: Float) -> Double in sum + Double(sample) * Double(sample) }
        return (squares / Double(Swift.max(samples.count, 1))).squareRoot()
    }

    func testTheMaskNamesThePitchClassesOfAScale() {
        XCTAssertEqual(cMajor, 0b1010_1011_0101)
        XCTAssertEqual(PitchCorrector.Settings.mask(root: 2, steps: [0, 2, 4, 5, 7, 9, 11]),
                       PitchCorrector.Settings.mask(root: 0, steps: [1, 2, 4, 6, 7, 9, 11]), "D major")
    }

    /// A flat or a sharp A in C major lands on 440 Hz, and stays there without flutter.
    func testAnOutOfTuneNoteLandsOnTheScaleAndHolds() throws {
        for (detune, expected) in [(-30.0, 440.0), (40.0, 440.0), (25.0, 196.0)] {
            let sung = expected * Foundation.pow(2, detune / 1_200)
            let corrector = PitchCorrector(sampleRate: rate, settings: .init(allowed: cMajor))
            let output = run(corrector, tone(sung))
            XCTAssertEqual(cents(try pitch(of: output.suffix(4_096)), expected), 0, accuracy: 3, "\(detune) cents")
            var found: [Double] = []
            for start in stride(from: 24_000, to: 48_000 - 4_096, by: 2_048) {
                found.append(try pitch(of: output[start..<(start + 4_096)]))
            }
            let spread = cents(found.max() ?? 1, found.min() ?? 1)
            XCTAssertLessThan(spread, 2, "a held note does not chirp (\(detune) cents)")
            XCTAssertEqual(level(output.suffix(4_096)) / level(tone(sung).suffix(4_096)), 1, accuracy: 0.03)
        }
    }

    func testAnInTuneNoteIsLeftAsItIs() throws {
        let output = run(PitchCorrector(sampleRate: rate, settings: .init(allowed: cMajor)), tone(440))
        XCTAssertEqual(cents(try pitch(of: output.suffix(4_096)), 440), 0, accuracy: 1)
        XCTAssertEqual(level(output.suffix(4_096)) / level(tone(440).suffix(4_096)), 1, accuracy: 0.02)
    }

    func testWithNoTargetNothingIsCorrected() throws {
        let sung = 440 * Foundation.pow(2.0, -30.0 / 1_200)
        let corrector = PitchCorrector(sampleRate: rate, settings: .init(allowed: 0))
        let output = run(corrector, tone(sung))
        XCTAssertEqual(cents(try pitch(of: output.suffix(4_096)), sung), 0, accuracy: 1)
        XCTAssertEqual(corrector.correction, 0)
    }

    /// In just intonation over C the major third sits 13.7 cents below the equal one.
    func testTheToneSystemMovesTheTarget() throws {
        var deviations = SIMD16<Float>.zero
        deviations[4] = -13.686
        let corrector = PitchCorrector(sampleRate: rate, settings: .init(allowed: cMajor, cents: deviations))
        let output = run(corrector, tone(329.63))
        XCTAssertEqual(cents(try pitch(of: output.suffix(4_096)), 329.63), -13.686, accuracy: 2)
        XCTAssertLessThan(corrector.correction, 0)
    }

    func testSettingsAreClampedAndABadSampleDoesNotRingOn() {
        var deviations = SIMD16<Float>.zero
        deviations[0] = .nan
        deviations[13] = 50
        let corrector = PitchCorrector(sampleRate: rate, settings: .init(allowed: 0xFFFF, cents: deviations,
                                                                           reference: 1_000, speed: -1, amount: .nan))
        XCTAssertEqual(corrector.settings, .init(allowed: 0x0FFF, cents: .zero, reference: 480, speed: 0, amount: 1))
        var input = tone(220, seconds: 0.2)
        input[100] = .nan
        input[5_000] = .infinity
        XCTAssertTrue(run(corrector, input).allSatisfy(\.isFinite))
    }
}

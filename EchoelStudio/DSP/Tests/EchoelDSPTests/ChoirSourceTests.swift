import Foundation
import XCTest
@testable import EchoelDSP

/// The choir engine's voice (VOX): the vocal tract rings at each vowel's formants, character walks
/// the vowels from dark to bright, and the ensemble is several singers, not one.
final class ChoirSourceTests: XCTestCase {
    private let rate: Float = 48_000

    /// The tract's magnitude response from 100 Hz to 2.8 kHz in 10 Hz steps, by a DFT of its
    /// impulse response (85 ms: the narrowest formant has rung out long before).
    private func response(_ vowel: Vowel) -> [(hertz: Float, magnitude: Float)] {
        var tract = VocalTract()
        tract.tune(to: vowel, sampleRate: rate)
        var impulse = [Float](repeating: 0, count: 4_096)
        impulse[0] = 1
        let ir = impulse.map { (x: Float) -> Float in tract.process(x) }
        return stride(from: Float(100), through: 2_800, by: 10).map { (hertz: Float) -> (hertz: Float, magnitude: Float) in
            var re: Float = 0, im: Float = 0
            for (n, x) in ir.enumerated() {
                let angle = 2 * Float.pi * hertz * Float(n) / rate
                re += x * cosf(angle)
                im -= x * sinf(angle)
            }
            return (hertz, (re * re + im * im).squareRoot())
        }
    }

    /// The frequencies where the response has a local peak, lowest first.
    private func peaks(_ curve: [(hertz: Float, magnitude: Float)]) -> [Float] {
        var found: [Float] = []
        for i in 1..<(curve.count - 1) where curve[i].magnitude > curve[i - 1].magnitude
            && curve[i].magnitude >= curve[i + 1].magnitude {
            found.append(curve[i].hertz)
        }
        return found
    }

    /// Each vowel's first two formants are peaks of the tract, a bass's and a soprano's, within 8 %.
    func testEachVowelRingsAtItsFormants() throws {
        let expected: [(character: Float, register: Float, f1: Float, f2: Float, name: String)] = [
            (0, 0, 350, 600, "bass oo"), (0.25, 0, 400, 750, "bass oh"), (0.5, 0, 600, 1_040, "bass ah"),
            (0.75, 0, 400, 1_620, "bass eh"), (1, 0, 250, 1_750, "bass ee"),
            (0, 1, 325, 700, "soprano oo"), (0.25, 1, 450, 800, "soprano oh"), (0.5, 1, 800, 1_150, "soprano ah"),
            (0.75, 1, 350, 2_000, "soprano eh"), (1, 1, 270, 2_140, "soprano ee"),
        ]
        for vowel in expected {
            let found = peaks(response(Vowel.at(character: vowel.character, register: vowel.register)))
            for formant in [vowel.f1, vowel.f2] {
                let nearest = try XCTUnwrap(found.min { Swift.abs($0 - formant) < Swift.abs($1 - formant) })
                XCTAssertEqual(nearest / formant, 1, accuracy: 0.08, "\(vowel.name) \(formant) Hz, peaks \(found.prefix(4))")
            }
        }
    }

    /// Moving character from 0 to 1 moves the second formant up all the way: oo, oh, ah, eh, ee.
    func testCharacterMovesTheVowelFromDarkToBright() {
        for register: Float in [0, 0.5, 1] {
            var last: Float = 0
            for step in 0...8 {
                let found = peaks(response(Vowel.at(character: Float(step) / 8, register: register)))
                let second = found.count > 1 ? found[1] : 0
                XCTAssertGreaterThan(second, last, "register \(register) step \(step): \(found.prefix(3))")
                last = second
            }
        }
    }

    private func sing(character: Float = 0.5, dt: Float, frames: Int, pitch: UInt8 = 57) -> [Float] {
        var choir = ChoirSource()
        choir.strike(pitch: pitch, sampleRate: rate, order: 1)
        return (0..<frames).map { (_: Int) -> Float in choir.next(character: character, dt: dt) }
    }

    /// Three singers a few cents apart, each with its own vibrato: the sound never repeats exactly
    /// from one cycle to the next, as one steady voice would.
    func testTheEnsembleIsSeveralSingers() {
        let period = 256
        let out = Array(sing(dt: 1 / Float(period), frames: 48_000).suffix(24_000))
        var difference: Float = 0, energy: Float = 0
        for n in period..<out.count {
            difference += (out[n] - out[n - period]) * (out[n] - out[n - period])
            energy += out[n] * out[n]
        }
        XCTAssertGreaterThan(energy, 0)
        XCTAssertGreaterThan((difference / energy).squareRoot(), 0.1, "not one steady voice")
    }

    /// The same note struck twice sings the same samples: an export renders the same breath.
    func testTheSameNoteSingsTheSameEveryTime() {
        XCTAssertEqual(sing(dt: 220 / rate, frames: 4_800), sing(dt: 220 / rate, frames: 4_800))
    }

    func testABadPitchOrCharacterIsSilenceOrTheMiddleVowelAndNeverNotANumber() {
        for character: Float in [.nan, .infinity, -3, 7] {
            XCTAssertTrue(sing(character: character, dt: 220 / rate, frames: 2_000).allSatisfy(\.isFinite))
        }
        for dt: Float in [.nan, 0, -0.1, 0.5, .infinity] {
            XCTAssertTrue(sing(dt: dt, frames: 500).allSatisfy { $0 == 0 }, "\(dt)")
        }
        XCTAssertEqual(Vowel.at(character: .nan, register: .nan), Vowel.at(character: 0.5, register: 0.5))
        var tract = VocalTract()
        tract.tune(to: Vowel((30_000, .nan, -5, 1_000, 2_000), (100, 100, 100, .infinity, 0)), sampleRate: rate)
        XCTAssertEqual(tract.process(1), 1, "a formant it cannot ring passes the signal unchanged")
    }

    /// Every vowel on every register comes out at about one level: a harmonic landing on a narrow
    /// formant does not ring many times louder than one between them.
    func testEveryVowelAndRegisterSingsAtAboutOneLevel() {
        for pitch: UInt8 in [45, 57, 69, 81] {
            let hertz = 440 * powf(2, (Float(pitch) - 69) / 12)
            for character: Float in [0, 0.25, 0.5, 0.75, 1] {
                let tail = sing(character: character, dt: hertz / rate, frames: 24_000, pitch: pitch).suffix(12_000)
                let rms = (tail.reduce(0) { $0 + $1 * $1 } / Float(tail.count)).squareRoot()
                XCTAssertGreaterThan(rms, ChoirSource.level / 3, "note \(pitch) character \(character)")
                XCTAssertLessThan(rms, ChoirSource.level * 2, "note \(pitch) character \(character)")
                XCTAssertLessThan(tail.map { Swift.abs($0) }.max() ?? 0, 2, "note \(pitch) character \(character)")
            }
        }
    }
}

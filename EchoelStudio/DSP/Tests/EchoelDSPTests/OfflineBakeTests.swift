@testable import EchoelDSP
import XCTest

/// The region bake's two edits (W3): pitch correction lands a detuned note on its target and
/// leaves it alone at strength 0; the granular texture repeats bit for bit under one seed; silence
/// stays silence and nothing that is not a number comes out.
final class OfflineBakeTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(hertz: Double, seconds: Double, level: Double = 0.5) -> [Float] {
        let count = Int(seconds * rate)
        return (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / rate
            return Float(level * sin(phase))
        }
    }

    /// The frequency from the rising zero crossings in `range`, each placed between its two
    /// samples — independent of the tracker under test.
    private func measuredHertz(_ samples: [Float], in range: Range<Int>) -> Double? {
        var first: Double?, last = 0.0, crossings = 0
        var index = Swift.max(range.lowerBound, 1)
        while index < Swift.min(range.upperBound, samples.count) {
            let before = samples[index - 1], after = samples[index]
            if before < 0, after >= 0 {
                let fraction = Double(-before) / Double(after - before)
                let at = Double(index - 1) + fraction
                if first == nil { first = at }
                last = at
                crossings += 1
            }
            index += 1
        }
        guard let start = first, crossings > 2, last > start else { return nil }
        return Double(crossings - 1) / ((last - start) / rate)
    }

    private func cents(_ hertz: Double, from reference: Double) -> Double {
        1_200 * Foundation.log2(hertz / reference)
    }

    func testANoteThirtyCentsSharpLandsOnItsTargetAtFullStrength() throws {
        let sharp = 440 * Foundation.pow(2, 30.0 / 1_200)
        let input = sine(hertz: sharp, seconds: 2)
        let settings = PitchCorrector.Settings(speed: 0.02, amount: 1)
        let output = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: input), sampleRate: rate, settings: settings))
        XCTAssertEqual(output.frameCount, input.count)
        XCTAssertNil(output.right)
        let hertz = try XCTUnwrap(measuredHertz(output.left, in: Int(0.5 * rate)..<Int(1.8 * rate)))
        XCTAssertEqual(cents(hertz, from: 440), 0, accuracy: 5, "the note lands on A within 5 cents")
        let before = try XCTUnwrap(measuredHertz(input, in: Int(0.5 * rate)..<Int(1.8 * rate)))
        XCTAssertEqual(cents(before, from: 440), 30, accuracy: 1, "the measurement itself is sound")
    }

    func testAKeyPullsToItsOwnNotesOnly() throws {
        // B♭ sharp by 30 cents in C major: B♭ is not in the key, A and B are; it lands on the nearer.
        let flatB = 440 * Foundation.pow(2, 130.0 / 1_200)
        let mask = PitchCorrector.Settings.mask(root: 0, steps: [0, 2, 4, 5, 7, 9, 11])
        let settings = PitchCorrector.Settings(allowed: mask, speed: 0, amount: 1)
        let output = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: sine(hertz: flatB, seconds: 2)), sampleRate: rate,
                                                              settings: settings))
        let hertz = try XCTUnwrap(measuredHertz(output.left, in: Int(0.5 * rate)..<Int(1.8 * rate)))
        XCTAssertEqual(cents(hertz, from: 440 * Foundation.pow(2, 2.0 / 12)), 0, accuracy: 5, "B, the nearest note of C major")
    }

    func testAVibratoAroundADetunedNoteKeepsItsSwing() throws {
        // A 6 Hz vibrato of ±40 cents around A + 30 cents: the centre moves, the swing stays.
        let count = Int(2 * rate)
        var phase = 0.0
        let input = (0..<count).map { (index: Int) -> Float in
            let t = Double(index) / rate
            let hertz = 440 * Foundation.pow(2, (30 + 40 * sin(2 * Double.pi * 6 * t)) / 1_200)
            phase += 2 * Double.pi * hertz / rate
            return Float(0.5 * sin(phase))
        }
        let output = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: input), sampleRate: rate,
                                                              settings: .init(speed: 0.02, amount: 1)))
        let mean = try XCTUnwrap(measuredHertz(output.left, in: Int(0.5 * rate)..<Int(1.5 * rate)))
        XCTAssertEqual(cents(mean, from: 440), 0, accuracy: 8, "the centre lands on A")
        // Over a twelfth of a second at the peak and the trough of the swing, a sixth apart.
        var spans: [Double] = []
        for start in stride(from: 0.75, to: 1.25, by: 1.0 / 24) {
            if let hertz = measuredHertz(output.left, in: Int(start * rate)..<Int((start + 1.0 / 24) * rate)) {
                spans.append(cents(hertz, from: 440))
            }
        }
        let swing = (spans.max() ?? 0) - (spans.min() ?? 0)
        XCTAssertGreaterThan(swing, 40, "the vibrato is still there")
    }

    func testAtZeroStrengthTheOutputIsTheOriginal() throws {
        let input = sine(hertz: 447.7, seconds: 1)
        let right = sine(hertz: 300, seconds: 1)
        let output = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: input, right: right), sampleRate: rate,
                                                              settings: .init(amount: 0)))
        XCTAssertEqual(output.left, input)
        XCTAssertEqual(output.right, right)
    }

    func testSilenceStaysSilenceThroughBoth() throws {
        let silence = OfflineBake.Audio(left: [Float](repeating: 0, count: 24_000))
        let tuned = try XCTUnwrap(OfflineBake.pitchCorrected(silence, sampleRate: rate, settings: .init(amount: 1)))
        XCTAssertTrue(tuned.left.allSatisfy { $0 == 0 })
        let grains = try XCTUnwrap(OfflineBake.texture(silence, sampleRate: rate, settings: .init(pitch: 7, seed: 3)))
        XCTAssertEqual(grains.frameCount, 24_000)
        XCTAssertTrue(grains.left.allSatisfy { $0 == 0 } && (grains.right ?? []).allSatisfy { $0 == 0 })
    }

    func testTheSameSeedGivesTheSameGrainsBitForBit() throws {
        let input = OfflineBake.Audio(left: sine(hertz: 220, seconds: 1.5))
        let settings = OfflineBake.Texture(size: 0.06, density: 0.8, scatter: 0.1, pitch: -5, seed: 42)
        let first = try XCTUnwrap(OfflineBake.texture(input, sampleRate: rate, settings: settings))
        let second = try XCTUnwrap(OfflineBake.texture(input, sampleRate: rate, settings: settings))
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.left.contains { $0 != 0 }, "the cloud sounds")
        var other = settings
        other.seed = 43
        XCTAssertNotEqual(try XCTUnwrap(OfflineBake.texture(input, sampleRate: rate, settings: other)), first)
    }

    func testNothingThatIsNotANumberGoesInOrComesOut() throws {
        var input = sine(hertz: 447.7, seconds: 1)
        for index in stride(from: 0, to: input.count, by: 997) { input[index] = index % 2 == 0 ? .nan : .infinity }
        let wild = OfflineBake.Texture(size: .nan, density: .infinity, scatter: -3, pitch: .nan, seed: 0)
        let grains = try XCTUnwrap(OfflineBake.texture(.init(left: input), sampleRate: .nan, settings: wild))
        XCTAssertTrue(grains.left.allSatisfy(\.isFinite) && (grains.right ?? []).allSatisfy(\.isFinite))
        let tuned = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: input), sampleRate: rate,
                                                             settings: .init(speed: .nan, amount: .infinity)))
        XCTAssertTrue(tuned.left.allSatisfy(\.isFinite))
        let untouched = try XCTUnwrap(OfflineBake.pitchCorrected(.init(left: input), sampleRate: rate, settings: .init(amount: 0)))
        XCTAssertTrue(untouched.left.allSatisfy(\.isFinite), "even the untouched copy reads a non-number as silence")
    }

    func testABakeStopsWhenItIsCancelled() {
        let input = OfflineBake.Audio(left: sine(hertz: 447.7, seconds: 1))
        XCTAssertNil(OfflineBake.pitchCorrected(input, sampleRate: rate, settings: .init(), isCancelled: { true }))
        XCTAssertNil(OfflineBake.texture(input, sampleRate: rate, settings: .init(), isCancelled: { true }))
    }
}

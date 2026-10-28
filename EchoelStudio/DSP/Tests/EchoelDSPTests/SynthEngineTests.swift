import XCTest
@testable import EchoelDSP

final class SynthEngineTests: XCTestCase {
    private let rate: Float = 48_000

    /// One held A3 (220 Hz), filter wide open and flat, so the engine's own tone comes out.
    private func tone(_ engine: SynthEngine, character: Float, waveform: Oscillator.Waveform = .saw,
                      frames: Int = 9_600) -> [Float] {
        var patch = SynthPatch(waveform: waveform, cutoff: 18_000, resonance: 0, filterEnvelopeAmount: 0,
                               ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2), level: 1)
        patch.engine = engine
        patch.character = character
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 57, velocity: 127)
        var buffer = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let end = Swift.min(start + 256, frames)
            buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func rms(_ samples: [Float]) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(Swift.max(1, samples.count))).squareRoot()
    }

    /// The magnitude of one frequency in `samples`, by a single-bin DFT.
    private func magnitude(_ samples: [Float], hertz: Float) -> Float {
        var re: Float = 0, im: Float = 0
        for (n, x) in samples.enumerated() {
            let angle = 2 * Float.pi * hertz * Float(n) / rate
            re += x * cosf(angle)
            im -= x * sinf(angle)
        }
        return (re * re + im * im).squareRoot() / Float(samples.count)
    }

    func testEveryEngineSoundsAndStaysFinite() {
        for engine in SynthEngine.allCases {
            for character: Float in [0, 0.5, 1, .nan] {
                let out = tone(engine, character: character)
                XCTAssertTrue(out.allSatisfy(\.isFinite), "\(engine) \(character)")
                XCTAssertGreaterThan(rms(out), 0.05, "\(engine) \(character)")
            }
        }
    }

    func testTheClassicEngineIgnoresCharacter() {
        XCTAssertEqual(tone(.classic, character: 0), tone(.classic, character: 1))
    }

    /// No index, no modulation: FM at character 0 is the plain sine.
    func testFMWithoutIndexIsTheSine() {
        let fm = tone(.fm, character: 0), sine = tone(.classic, character: 0, waveform: .sine)
        for (a, b) in zip(fm, sine) { XCTAssertEqual(a, b, accuracy: 1e-4) }
        XCTAssertGreaterThan(magnitude(tone(.fm, character: 1), hertz: 660), magnitude(fm, hertz: 660) + 0.01,
                             "an index puts energy on the sidebands")
    }

    func testTheSupersawDetunesAndKeepsItsLevel() {
        let tight = tone(.supersaw, character: 0), wide = tone(.supersaw, character: 1)
        XCTAssertNotEqual(tight, wide)
        let saw = rms(tone(.classic, character: 0))
        XCTAssertGreaterThan(rms(wide), saw * 0.3)
        XCTAssertLessThan(rms(wide), saw * 3)
    }

    /// The morph's ends are its first and last shape, and its middle is neither.
    func testTheMorphRunsFromSineToSquare() {
        let start = tone(.morph, character: 0), sine = tone(.classic, character: 0, waveform: .sine)
        for (a, b) in zip(start, sine) { XCTAssertEqual(a, b, accuracy: 1e-4) }
        let end = tone(.morph, character: 1), square = tone(.classic, character: 0, waveform: .square)
        for (a, b) in zip(end, square) { XCTAssertEqual(a, b, accuracy: 1e-4) }
        let middle = tone(.morph, character: 0.5)
        XCTAssertNotEqual(middle, start)
        XCTAssertNotEqual(middle, end)
        XCTAssertGreaterThan(magnitude(middle, hertz: 440), magnitude(start, hertz: 440) + 0.01,
                             "away from the sine the tone gains harmonics")
    }

    func testTheSubAddsTheOctaveBelow() {
        XCTAssertEqual(tone(.sub, character: 0), tone(.classic, character: 0), "no sub, the oscillator alone")
        XCTAssertGreaterThan(magnitude(tone(.sub, character: 1), hertz: 110),
                             magnitude(tone(.sub, character: 0), hertz: 110) + 0.05)
    }
}

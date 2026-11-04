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
        // The engine's own tone: its loudness trim (a gain inside the voice) taken back out.
        return buffer.map { $0 / engine.loudnessTrim }
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

    /// A struck object: loud at the strike, then dying on its own while the key is held, and
    /// metal rings longer and less harmonically than wood.
    func testTheMalletRingsOutAndMetalRingsLonger() {
        let frames = 48_000
        let wood = tone(.mallet, character: 0, frames: frames), metal = tone(.mallet, character: 1, frames: frames)
        for out in [wood, metal] { XCTAssertTrue(out.allSatisfy(\.isFinite)) }
        let early = { (x: [Float]) -> Float in self.rms(Array(x[0..<4_800])) }
        let late = { (x: [Float]) -> Float in self.rms(Array(x[38_400..<48_000])) }
        XCTAssertGreaterThan(early(wood), 0.05)
        XCTAssertLessThan(late(wood), early(wood) * 0.25, "a held key still dies away: nothing sustains a bar")
        XCTAssertGreaterThan(late(metal) / early(metal), late(wood) / early(wood), "metal rings longer")
        let start = Array(metal[0..<9_600]), woodStart = Array(wood[0..<9_600])
        XCTAssertGreaterThan(magnitude(start, hertz: 220 * 2.756), magnitude(woodStart, hertz: 220 * 2.756),
                             "metal's second mode sits at 2.756 times the note")
    }

    /// The choir sings oo at character 0 and ee at 1: oo's second formant rings near the third
    /// harmonic of A3, ee's near the ninth.
    func testTheChoirSingsOoAtOneEndAndEeAtTheOther() {
        let oo = tone(.choir, character: 0, frames: 24_000), ee = tone(.choir, character: 1, frames: 24_000)
        let ooTail = Array(oo.suffix(19_200)), eeTail = Array(ee.suffix(19_200))
        XCTAssertGreaterThan(magnitude(ooTail, hertz: 660), magnitude(eeTail, hertz: 660) * 2, "oo's second formant")
        XCTAssertGreaterThan(magnitude(eeTail, hertz: 1_980), magnitude(ooTail, hertz: 1_980) * 2, "ee's second formant")
    }

    /// Sixteen voices of each engine, one 128-frame block after another for a second of sound: the
    /// seconds it takes, for a chord held through the whole second.
    private func chordSeconds(_ engine: SynthEngine) -> Double {
        var patch = SynthPatch(cutoff: 18_000, ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2))
        patch.engine = engine
        var synth = PolySynth(patch: patch, sampleRate: rate)
        for pitch in 0..<16 { synth.noteOn(pitch: UInt8(48 + pitch * 2), velocity: 100) }
        var block = [Float](repeating: 0, count: 128)
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<375 {
            for i in block.indices { block[i] = 0 }
            block.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        }
        XCTAssertTrue(block.allSatisfy(\.isFinite))
        return ProcessInfo.processInfo.systemUptime - start
    }

    /// The choir's budget per 128-frame block: a full chord of sixteen voices renders faster than it
    /// plays even in a debug build, and costs at most six times the classic oscillator's. Each is the
    /// best of three runs, so one slow run of a shared machine does not decide. Measured for the
    /// second of sound, debug: 0.28 s against 0.13 s on Linux (2026-11-01, ratio 2.0 … 2.7), 0.73 …
    /// 0.89 s against 0.16 … 0.19 s on the macOS runner (2026-11-04, ratio 3.7 … 4.6 — the factor 4
    /// that stood here failed there on unchanged choir code, AUD).
    func testAFullChoirChordStaysWithinTheBudget() {
        let choir = (0..<3).map { (_: Int) -> Double in chordSeconds(.choir) }.min() ?? 0
        let classic = (0..<3).map { (_: Int) -> Double in chordSeconds(.classic) }.min() ?? 0
        XCTAssertLessThan(choir, 1, "375 blocks of 128 frames: one second of sound in under a second")
        XCTAssertLessThan(choir, classic * 6, "choir \(choir) s, classic \(classic) s")
    }

    /// A plucked string (A6): it sounds its note — a period of noise in a loop one period long —
    /// and the same note plucks the same string again.
    func testThePluckSoundsItsNoteAndIsTheSameEveryTime() {
        let out = tone(.pluck, character: 0.5, frames: 24_000)
        XCTAssertEqual(out, tone(.pluck, character: 0.5, frames: 24_000), "seeded by the note counter")
        let tail = Array(out[4_800..<24_000])
        let fundamental = magnitude(tail, hertz: 220)
        XCTAssertGreaterThan(fundamental, magnitude(tail, hertz: 207.65) * 5, "in tune, not a semitone down")
        XCTAssertGreaterThan(fundamental, magnitude(tail, hertz: 233.08) * 5, "in tune, not a semitone up")
        XCTAssertGreaterThan(fundamental, 0.01)
    }

    /// Character is the pick: bright lets the noise's top through and damps the loop less.
    func testThePluckIsBrighterAtHigherCharacter() {
        let dark = Array(tone(.pluck, character: 0, frames: 9_600)[2_400...])
        let bright = Array(tone(.pluck, character: 1, frames: 9_600)[2_400...])
        let high = { (x: [Float]) -> Float in
            [1_760, 1_980, 2_200, 2_640].reduce(Float(0)) { $0 + self.magnitude(x, hertz: $1) } / self.rms(x)
        }
        XCTAssertGreaterThan(high(bright), high(dark) * 2)
    }

    /// Decay and Sustain are how long the string rings: a short one has died where a long one rings.
    func testThePluckRingsAsLongAsDecayAndSustainSay() {
        func ring(decay: Float, sustain: Float) -> Float {
            var patch = SynthPatch(cutoff: 18_000, resonance: 0, filterEnvelopeAmount: 0,
                                   ampEnvelope: .init(attack: 0.001, decay: 10, sustain: 1, release: 0.2), level: 1)
            patch.engine = .pluck
            var synth = PolySynth(patch: patch, sampleRate: rate)
            var string = patch
            string.ampEnvelope = .init(attack: 0.001, decay: decay, sustain: sustain, release: 0.2)
            // The ring follows the patch; the amp envelope of `patch` holds the level open.
            synth.setPatch(string)
            synth.noteOn(pitch: 57, velocity: 127)
            var buffer = [Float](repeating: 0, count: 48_000)
            var start = 0
            while start < buffer.count {
                let end = Swift.min(start + 256, buffer.count)
                buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
                start = end
            }
            return rms(Array(buffer[38_400...])) / Swift.max(rms(Array(buffer[0..<4_800])), 1e-9)
        }
        let short = ring(decay: 0.02, sustain: 0), long = ring(decay: 1, sustain: 1)
        XCTAssertLessThan(short, 0.01, "a short string has died after a second")
        XCTAssertGreaterThan(long, 0.2, "a long one still rings")
    }

    func testTheSubAddsTheOctaveBelow() {
        for (a, b) in zip(tone(.sub, character: 0), tone(.classic, character: 0)) {
            XCTAssertEqual(a, b, accuracy: 1e-5, "no sub, the oscillator alone")
        }
        XCTAssertGreaterThan(magnitude(tone(.sub, character: 1), hertz: 110),
                             magnitude(tone(.sub, character: 0), hertz: 110) + 0.05)
    }
}

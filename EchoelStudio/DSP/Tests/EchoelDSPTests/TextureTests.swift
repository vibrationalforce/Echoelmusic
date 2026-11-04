import XCTest
@testable import EchoelDSP

/// The texture engine (A10): a cellular automaton's row shapes the partials of the note.
final class TextureTests: XCTestCase {
    private let rate: Float = 48_000

    private func patch(rule: Int = 0, density: Float = 0.8, evolve: Float = 8, seed: UInt32 = 0,
                       character: Float = 0.5, level: Float = 1) -> SynthPatch {
        var p = SynthPatch(cutoff: 18_000, resonance: 0, filterEnvelopeAmount: 0,
                           ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2), level: level)
        p.engine = .texture
        p.character = character
        p.textureRule = rule
        p.textureDensity = density
        p.textureRate = evolve
        p.textureSeed = seed
        return p
    }

    /// One held A3 for `frames`, rendered in blocks of `block`.
    private func play(_ p: SynthPatch, frames: Int = 24_000, block: Int = 256, pitches: [UInt8] = [57]) -> [Float] {
        var synth = PolySynth(patch: p, sampleRate: rate)
        for pitch in pitches { synth.noteOn(pitch: pitch, velocity: 120) }
        var buffer = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let end = Swift.min(start + block, frames)
            buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func rms(_ x: [Float]) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(Swift.max(1, x.count))).squareRoot()
    }

    private func magnitude(_ x: [Float], hertz: Float) -> Float {
        var re: Float = 0, im: Float = 0
        for (n, value) in x.enumerated() {
            let angle = 2 * Float.pi * hertz * Float(n) / rate
            re += value * cosf(angle)
            im -= value * sinf(angle)
        }
        return (re * re + im * im).squareRoot() / Float(x.count)
    }

    /// Wolfram's numbering is the table: rule 90 from one cell is the Sierpinski triangle (each
    /// cell the XOR of its neighbours), rule 184 moves a lone cell one step to the right.
    func testTheRuleIsWolframsElementaryRuleOnARing() {
        let one: UInt64 = 1 << 32
        XCTAssertEqual(TextureSource.evolve(one, rule: 90), (1 << 31) | (1 << 33))
        XCTAssertEqual(TextureSource.evolve(one, rule: 184), 1 << 33, "a car moves on")
        XCTAssertEqual(TextureSource.evolve(1 << 63, rule: 184), 1, "the ring wraps")
        XCTAssertEqual(TextureSource.evolve(.max, rule: 0), 0)
        // Every cell reads the generation before, never its neighbour's new state.
        let row: UInt64 = 0b1011_0110 << 20
        var expected: UInt64 = 0
        for i in 0..<64 {
            let l = (row >> UInt64((i + 63) % 64)) & 1, c = (row >> UInt64(i)) & 1, r = (row >> UInt64((i + 1) % 64)) & 1
            let bit = (UInt64(110) >> (l << 2 | c << 1 | r)) & 1
            expected |= bit << UInt64(i)
        }
        XCTAssertEqual(TextureSource.evolve(row, rule: 110), expected)
        XCTAssertEqual(TextureSource.ruleNumber(index: 0), 90)
        XCTAssertEqual(TextureSource.ruleNumber(index: 7), 105)
        XCTAssertEqual(TextureSource.ruleNumber(index: 99), 90, "an index past the list plays the default")
        XCTAssertEqual(TextureSource.initialRow(seed: 0), one, "seed 0 is the middle cell")
        XCTAssertNotEqual(TextureSource.initialRow(seed: 1), TextureSource.initialRow(seed: 2))
        XCTAssertNotEqual(TextureSource.initialRow(seed: 9_999), 0)
    }

    /// Same seed, same rule, same rate: the same sound, every time and for every block size.
    func testTheSameSeedAndRulePlayTheSameSoundInEveryBlockSize() {
        let p = patch(rule: 2, evolve: 20, seed: 4_711)
        let reference = play(p, block: 256)
        XCTAssertEqual(play(p, block: 256), reference, "the same note, the same sound")
        XCTAssertEqual(play(p, block: 64), reference)
        XCTAssertEqual(play(p, block: 4_096), reference)
        XCTAssertNotEqual(play(patch(rule: 2, evolve: 20, seed: 4_712)), reference, "another seed, another row")
        XCTAssertNotEqual(play(patch(rule: 1, evolve: 20, seed: 4_711)), reference, "another rule, another texture")
    }

    /// The row evolves at the rate, and a rate of 0 holds it: the spectrum stands still.
    func testTheSpectrumMovesAtTheRateAndStandsAtZero() {
        let frozen = play(patch(rule: 1, evolve: 0, seed: 3), frames: 48_000)
        let moving = play(patch(rule: 1, evolve: 20, seed: 3), frames: 48_000)
        // A3 is 220 Hz: compare the harmonics of two windows half a second apart.
        func spectrum(_ x: [Float], from start: Int) -> [Float] {
            let window = Array(x[start..<(start + 4_800)])
            return (2...16).map { magnitude(window, hertz: 220 * Float($0)) }
        }
        let a = spectrum(frozen, from: 9_600), b = spectrum(frozen, from: 33_600)
        for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: 1e-3, "a held row does not move") }
        let c = spectrum(moving, from: 9_600), d = spectrum(moving, from: 33_600)
        XCTAssertGreaterThan(zip(c, d).map { Swift.abs($0 - $1) }.reduce(0, +), 0.01, "an evolving row moves")
    }

    /// Density 0 is the fundamental alone; density 1 lets the harmonics through.
    func testDensityOpensTheHarmonics() {
        let thin = Array(play(patch(rule: 1, density: 0, evolve: 4, seed: 7))[4_800...])
        let full = Array(play(patch(rule: 1, density: 1, evolve: 4, seed: 7))[4_800...])
        let upper = { (x: [Float]) -> Float in (2...8).reduce(Float(0)) { $0 + self.magnitude(x, hertz: 220 * Float($1)) } }
        XCTAssertLessThan(upper(thin), 1e-3, "no harmonics at density 0")
        XCTAssertGreaterThan(magnitude(thin, hertz: 220), 0.05, "the note keeps its fundamental")
        XCTAssertGreaterThan(upper(full), 0.02)
    }

    /// Level 0 is silence, exactly.
    func testLevelZeroIsSilence() {
        XCTAssertTrue(play(patch(level: 0), frames: 9_600).allSatisfy { $0 == 0 })
    }

    /// Whatever arrives — not a number, past the ranges, the highest note — the output stays finite
    /// and bounded.
    func testTheOutputStaysFiniteForEveryInput() {
        let cases: [SynthPatch] = [
            patch(rule: -3, density: .nan, evolve: .nan, seed: .max, character: .nan),
            patch(rule: 1_000, density: .infinity, evolve: .infinity, seed: 1, character: -.infinity),
            patch(rule: 1, density: -1, evolve: -5, seed: 9_999, character: 2),
            patch(rule: 3, density: 1, evolve: 40, seed: 12, character: 1),
        ]
        for p in cases {
            let out = play(p, frames: 9_600, pitches: [24, 57, 100, 127])
            XCTAssertTrue(out.allSatisfy(\.isFinite))
            // Four voices at full level, the engine's trim taken out: each stays near one sine.
            let peak = (out.map { Swift.abs($0) }.max() ?? 0) / SynthEngine.texture.loudnessTrim
            XCTAssertLessThan(peak, 8, "four voices at full level")
        }
    }

    /// A new generation glides in: no sample jumps further than the note itself moves.
    func testANewGenerationDoesNotClick() {
        let out = play(patch(rule: 1, density: 1, evolve: 40, seed: 5, character: 1), frames: 24_000)
        var largest: Float = 0
        for i in 2..<out.count {
            // The second difference of a smooth tone stays small; a step makes it jump.
            largest = Swift.max(largest, Swift.abs(out[i] - 2 * out[i - 1] + out[i - 2]))
        }
        XCTAssertLessThan(largest, 0.2)
    }

    /// Sixteen voices for a second of sound, one 128-frame block after another.
    private func chordSeconds(_ engine: SynthEngine) -> Double {
        var p = patch(rule: 1, density: 1, evolve: 40, seed: 9)
        p.engine = engine
        var synth = PolySynth(patch: p, sampleRate: rate)
        for pitch in 0..<16 { synth.noteOn(pitch: UInt8(36 + pitch * 2), velocity: 100) }
        var block = [Float](repeating: 0, count: 128)
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<375 {
            for i in block.indices { block[i] = 0 }
            block.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        }
        XCTAssertTrue(block.allSatisfy(\.isFinite))
        return ProcessInfo.processInfo.systemUptime - start
    }

    /// The texture's budget: a full sixteen-voice chord, every partial sounding and the row evolving
    /// as fast as it can, renders faster than it plays, and costs at most six times the classic
    /// oscillator's (the choir's bound; best of three each, so one slow run does not decide).
    func testAFullTextureChordStaysWithinTheBudget() {
        let texture = (0..<3).map { (_: Int) -> Double in chordSeconds(.texture) }.min() ?? 0
        let classic = (0..<3).map { (_: Int) -> Double in chordSeconds(.classic) }.min() ?? 0
        #if DEBUG
        XCTAssertLessThan(texture, 1.5, "a second of sound in \(texture) s")
        #else
        XCTAssertLessThan(texture, 1, "a second of sound in \(texture) s")
        #endif
        XCTAssertLessThan(texture, Swift.max(classic, 0.01) * 6, "texture \(texture) s, classic \(classic) s")
    }
}

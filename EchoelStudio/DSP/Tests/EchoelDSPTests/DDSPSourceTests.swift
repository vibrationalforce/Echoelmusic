import XCTest
@testable import EchoelDSP

/// The seventh engine (W5): the harmonic-plus-noise model, rendered through the synth as a
/// song or a host plays it. Analysis windows are 24 000 samples — exactly 110 cycles of the
/// A3 every test holds — so a harmonic of 220 Hz sits on a bin of its own and the bins between
/// the harmonics hold only the noise.
final class DDSPSourceTests: XCTestCase {
    private let rate: Float = 48_000
    private let block = 256

    /// One A3 (220 Hz) at full level, filter wide open and flat, in 256-frame blocks. `noteOff`
    /// releases the key at that frame; `sweep` sets Character block by block, the last value
    /// holding to the end.
    private func tone(character: Float, frames: Int, noteOff: Int? = nil, level: Float = 1,
                      pitch: UInt8 = 57, sweep: [Float]? = nil) -> (samples: [Float], synth: PolySynth) {
        var patch = SynthPatch(waveform: .saw, cutoff: 18_000, resonance: 0, filterEnvelopeAmount: 0,
                               ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2), level: level)
        patch.engine = .ddsp
        patch.character = character
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: pitch, velocity: 127)
        var buffer = [Float](repeating: 0, count: frames)
        var start = 0
        var index = 0
        while start < frames {
            if let sweep, index < sweep.count {
                patch.character = sweep[index]
                synth.setPatch(patch)
            }
            if let noteOff, start == noteOff { synth.noteOff(pitch: pitch) }
            let end = Swift.min(start + block, frames)
            buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
            index += 1
        }
        return (buffer, synth)
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        var sum: Double = 0
        for x in samples { sum += Double(x) * Double(x) }
        return Float((sum / Double(Swift.max(1, samples.count))).squareRoot())
    }

    /// The magnitude of one frequency in `samples`, by a single-bin DFT in double precision.
    private func magnitude(_ samples: ArraySlice<Float>, hertz: Double) -> Double {
        var re: Double = 0, im: Double = 0
        var n: Double = 0
        for x in samples {
            let angle = 2 * Double.pi * hertz * n / Double(rate)
            re += Double(x) * cos(angle)
            im -= Double(x) * sin(angle)
            n += 1
        }
        return (re * re + im * im).squareRoot() / Double(samples.count)
    }

    /// The largest jump between neighbouring samples.
    private func maxStep(_ samples: ArraySlice<Float>) -> Float {
        var largest: Float = 0
        var previous = samples.first ?? 0
        for x in samples {
            largest = Swift.max(largest, Swift.abs(x - previous))
            previous = x
        }
        return largest
    }

    /// The window of the last 24 000 samples: 110 whole cycles of A3.
    private func steady(_ samples: [Float]) -> ArraySlice<Float> { samples[(samples.count - 24_000)...] }

    func testTheSinePolynomialIsASine() {
        var phases = DDSPSource.Bank()
        for i in 0..<DDSPSource.partialCount { phases[i] = Float(i) / Float(DDSPSource.partialCount) + 0.0071 }
        let sines = DDSPSource.sine(phases)
        for i in 0..<DDSPSource.partialCount {
            XCTAssertEqual(sines[i], sinf(2 * Float.pi * phases[i]), accuracy: 1e-5, "phase \(phases[i])")
        }
    }

    func testTheRenderIsDeterministicAndFinite() {
        let first = tone(character: 0.3, frames: 12_000).samples
        let second = tone(character: 0.3, frames: 12_000).samples
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(rms(first[6_000...]), 0.1)
    }

    /// Character 0 is dark and breathy, 1 bright and pure, 0.5 between: the third and seventh
    /// harmonics grow against the fundamental, and the energy between the harmonics — the
    /// noise — falls to nothing.
    func testCharacterTravelsFromDarkAndBreathyToBrightAndPure() {
        var brightness: [Float: Double] = [:], seventh: [Float: Double] = [:], breath: [Float: Double] = [:]
        for character: Float in [0, 0.5, 1] {
            let window = steady(tone(character: character, frames: 48_000).samples)
            XCTAssertTrue(window.allSatisfy(\.isFinite))
            XCTAssertGreaterThan(rms(window), 0.3, "character \(character)")
            XCTAssertLessThan(rms(window), 1, "character \(character)")
            let fundamental = magnitude(window, hertz: 220)
            XCTAssertGreaterThan(fundamental, 0.1)
            brightness[character] = magnitude(window, hertz: 660) / fundamental
            seventh[character] = magnitude(window, hertz: 1_540)
            var between: Double = 0
            for hertz in [330.0, 550, 770, 990, 1_210, 1_430] { between += magnitude(window, hertz: hertz) }
            breath[character] = between
        }
        XCTAssertLessThan(brightness[0] ?? 1, brightness[0.5] ?? 0, "the third harmonic grows with Character")
        XCTAssertLessThan(brightness[0.5] ?? 1, brightness[1] ?? 0)
        XCTAssertLessThan(brightness[0] ?? 1, 0.1, "dark: the third harmonic is far below the fundamental")
        XCTAssertGreaterThan(brightness[1] ?? 0, 0.4, "bright: the third harmonic is near the fundamental")
        XCTAssertLessThan(seventh[0] ?? 1, seventh[0.5] ?? 0, "the seventh harmonic grows with Character")
        XCTAssertLessThan(seventh[0.5] ?? 1, seventh[1] ?? 0)
        XCTAssertGreaterThan(breath[0] ?? 0, (breath[0.5] ?? 0) * 2, "the breath is loudest at 0")
        XCTAssertGreaterThan(breath[0.5] ?? 0, breath[1] ?? 0, "and fades toward 1")
        XCTAssertGreaterThan(breath[0] ?? 0, 0.005)
        XCTAssertLessThan(breath[1] ?? 1, 0.001, "at 1 nothing is left between the harmonics")
    }

    func testZeroLevelAndZeroVelocityAreExactSilence() {
        let silent = tone(character: 0.5, frames: 9_600, level: 0).samples
        XCTAssertTrue(silent.allSatisfy { $0 == 0 })

        var patch = SynthPatch(level: 1)
        patch.engine = .ddsp
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 57, velocity: 0)
        XCTAssertEqual(synth.activeVoiceCount, 0)
        var buffer = [Float](repeating: 0, count: 4_800)
        buffer.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        XCTAssertTrue(buffer.allSatisfy { $0 == 0 })
    }

    /// At the brightest Character, where the waveform's own steps are largest: the onset starts
    /// from nothing and climbs over its first millisecond, no step at the key down or the key up
    /// exceeds a step of the held tone, and the release ends in exact silence.
    func testANoteStartsAndEndsWithoutAClick() {
        let noteOff = 19_200
        let (out, synth) = tone(character: 1, frames: 38_400, noteOff: noteOff)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        let held = out[9_600..<noteOff]
        let heldStep = maxStep(held)
        XCTAssertGreaterThan(heldStep, 0.1)
        XCTAssertLessThan(Swift.abs(out[0]), 0.01, "the first sample is next to nothing")
        XCTAssertLessThan(rms(out[0..<48]), rms(held) * 0.3, "the first millisecond is still climbing")
        XCTAssertLessThan(maxStep(out[0..<96]), heldStep, "the key down steps less than the tone itself")
        XCTAssertLessThanOrEqual(maxStep(out[noteOff...]), heldStep * 1.001, "the key up steps less than the tone")
        XCTAssertTrue(out[33_600...].allSatisfy { $0 == 0 }, "the release has ended")
        XCTAssertEqual(synth.activeVoiceCount, 0)
    }

    /// Character turned from 0 to 1 while the note holds: the partials and the blend glide, so no
    /// sample steps further than the bright tone steps on its own.
    func testCharacterSweepsWithoutAStep() {
        let steps = 24_000 / block
        var sweep: [Float] = []
        for i in 0...steps { sweep.append(Float(i) / Float(steps)) }
        let swept = tone(character: 0, frames: 24_000 + 9_600, sweep: sweep).samples
        let bright = tone(character: 1, frames: 24_000).samples
        XCTAssertTrue(swept.allSatisfy(\.isFinite))
        XCTAssertLessThanOrEqual(maxStep(swept[480...]), maxStep(bright[9_600...]) * 1.1)
        XCTAssertGreaterThan(rms(swept[4_800..<9_600]), 0.3, "it sounds throughout")
    }

    /// The lowest and the highest key: finite, and above Nyquist a partial is silent rather than
    /// folded back — at the top key only the fundamental is left.
    func testExtremePitchesStayFinite() {
        for pitch: UInt8 in [0, 127] {
            let out = tone(character: 1, frames: 9_600, pitch: pitch).samples
            XCTAssertTrue(out.allSatisfy(\.isFinite), "pitch \(pitch)")
            XCTAssertGreaterThan(rms(out[4_800...]), 0.05, "pitch \(pitch)")
        }
    }

    /// Two notes never share a noise sequence: the same engine seeded from two note counters
    /// renders different breath under the same harmonics — at Character 1, where there is no
    /// breath, the seed changes nothing — and the same seed renders the same. (The fundamental's
    /// bin carries some of the pink noise, about 0.03 of 0.29 in a 4 800-sample window, so the
    /// harmonic comparison allows for it.)
    func testEveryNoteHasItsOwnNoise() {
        func render(seed: UInt64, character: Float) -> [Float] {
            var source = DDSPSource()
            source.reseed(seed)
            var out: [Float] = []
            for _ in 0..<4_800 { out.append(source.next(character: character, dt: 220 / rate)) }
            return out
        }
        let first = render(seed: 1, character: 0), second = render(seed: 2, character: 0)
        XCTAssertEqual(first, render(seed: 1, character: 0), "the same seed renders the same")
        var difference: [Float] = []
        for i in first.indices { difference.append(first[i] - second[i]) }
        XCTAssertGreaterThan(rms(difference[2_400...]), 0.05, "different seeds, different noise")
        XCTAssertEqual(magnitude(first[...], hertz: 220), magnitude(second[...], hertz: 220), accuracy: 0.1,
                       "the harmonics are the same")
        XCTAssertEqual(render(seed: 1, character: 1), render(seed: 2, character: 1),
                       "without breath the seed changes no sample")
    }
}

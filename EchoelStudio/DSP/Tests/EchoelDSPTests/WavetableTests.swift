import XCTest
@testable import EchoelDSP

/// The wavetable engine (EchoelTools: a synth fed with the musician's own sample): the factory
/// shapes, a sample cut into cycles, the band limit per octave, and the voice that plays it.
final class WavetableTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(position: Float, pitch: UInt8 = 57, frames: Int = 9_600, bank: WavetableBank? = nil,
                        engine: SynthEngine = .wavetable) -> [Float] {
        var patch = SynthPatch(waveform: .sine, cutoff: 18_000, resonance: 0, filterEnvelopeAmount: 0,
                               ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2), level: 1)
        patch.engine = engine
        patch.character = position
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.setWavetable(bank)
        synth.noteOn(pitch: pitch, velocity: 127)
        var buffer = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let end = Swift.min(start + 256, frames)
            buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
        }
        return buffer.map { $0 / engine.loudnessTrim }
    }

    private func magnitude(_ samples: [Float], hertz: Float) -> Float {
        var re: Float = 0, im: Float = 0
        for (n, x) in samples.enumerated() {
            let angle = 2 * Float.pi * hertz * Float(n) / rate
            re += x * cosf(angle)
            im -= x * sinf(angle)
        }
        return (re * re + im * im).squareRoot() / Float(samples.count)
    }

    /// One second of a 220 Hz tone that turns from a sine into a bright, saw-like tone.
    private func sweep(seconds: Double = 1, hertz: Double = 220) -> [Float] {
        let count = Int(seconds * 48_000)
        return (0..<count).map { (i: Int) -> Float in
            let t = Double(i) / 48_000, bright = Double(i) / Double(count)
            var x = sin(2 * Double.pi * hertz * t)
            for h in 2...12 { x += bright * sin(2 * Double.pi * hertz * Double(h) * t) / Double(h) }
            return Float(0.5 * x)
        }
    }

    func testTheFactoryStartsWithASineAndHoldsEightShapes() {
        let bank = WavetableBank.factory
        XCTAssertEqual(bank.frameCount, 8)
        let n = WavetableBank.cycleLength
        for i in stride(from: 0, to: n, by: 64) {
            XCTAssertEqual(bank.value(frame: 0, level: 0, at: i), sinf(2 * Float.pi * Float(i) / Float(n)), accuracy: 1e-3)
        }
        for frame in 0..<bank.frameCount {
            let peak = (0..<n).map { abs(bank.value(frame: frame, level: 0, at: $0)) }.max() ?? 0
            XCTAssertEqual(peak, 1, accuracy: 1e-4, "cycle \(frame) is normalized")
            XCTAssertEqual(bank.value(frame: frame, level: 0, at: n), bank.value(frame: frame, level: 0, at: 0),
                           "the guard point repeats the first")
        }
    }

    func testPositionZeroPlaysTheSine() {
        let out = render(position: 0), sine = render(position: 0, engine: .classic)
        for i in stride(from: 0, to: out.count, by: 37) { XCTAssertEqual(out[i], sine[i], accuracy: 2e-3) }
    }

    /// The top note on the factory saw: nothing above Nyquist folds back. 4186 Hz's 5th harmonic
    /// (20.9 kHz) may sound; its 6th (25.1 kHz) would fold to 22.9 kHz, its 7th to 18.7 kHz.
    func testAHighNoteDoesNotAlias() {
        let saw: Float = 2.0 / 7
        let out = Array(render(position: saw, pitch: 108, frames: 9_600)[960...])
        let fundamental = magnitude(out, hertz: 4_186)
        XCTAssertGreaterThan(fundamental, 0.1)
        for alias: Float in [22_884, 18_698, 14_512] {
            XCTAssertLessThan(magnitude(out, hertz: alias), fundamental * 0.01, "folded energy at \(alias) Hz")
        }
    }

    func testEveryPositionSoundsAndStaysFinite() {
        for position: Float in [0, 0.13, 0.5, 0.77, 1, .nan] {
            let out = render(position: position, frames: 4_800)
            XCTAssertTrue(out.allSatisfy(\.isFinite), "\(position)")
            XCTAssertGreaterThan(out.map { abs($0) }.max() ?? 0, 0.3, "\(position)")
            XCTAssertLessThan(out.map { abs($0) }.max() ?? 2, 1.3, "\(position)")
        }
    }

    func testThePitchOfASampleIsFound() throws {
        let tone = sweep()
        let period = try XCTUnwrap(WavetableAnalysis.period(of: tone, around: 24_000, sampleRate: 48_000))
        XCTAssertEqual(period, 48_000 / 220, accuracy: 0.5)
        XCTAssertNil(WavetableAnalysis.period(of: [Float](repeating: 0, count: 48_000), around: 24_000, sampleRate: 48_000))
    }

    /// A sample becomes its cycles: the first as dark as the file's start, the last as bright as its
    /// end, each one period of the note — and the same file always gives the same table.
    func testASampleIsCutIntoItsCycles() throws {
        let buffer = try XCTUnwrap(SampleBuffer(samples: sweep(), sampleRate: 48_000))
        let bank = try XCTUnwrap(WavetableBank(sample: buffer, frames: 8))
        XCTAssertEqual(bank.frameCount, 8)
        let again = try XCTUnwrap(WavetableBank(sample: buffer, frames: 8))
        let n = WavetableBank.cycleLength
        for frame in 0..<8 {
            for i in stride(from: 0, to: n, by: 97) {
                XCTAssertEqual(bank.value(frame: frame, level: 0, at: i), again.value(frame: frame, level: 0, at: i))
            }
        }
        // One period per cycle: the energy sits on harmonic 1, not on a half or a double.
        func harmonic(_ frame: Int, _ h: Int) -> Float {
            let cycle = (0..<n).map { bank.value(frame: frame, level: 0, at: $0) }
            return WavetableAnalysis.spectrum(of: cycle).sine.indices.contains(h - 1)
                ? hypotf(WavetableAnalysis.spectrum(of: cycle).sine[h - 1], WavetableAnalysis.spectrum(of: cycle).cosine[h - 1]) : 0
        }
        XCTAssertGreaterThan(harmonic(0, 1), 0.5)
        XCTAssertLessThan(harmonic(0, 3), harmonic(7, 3), "the end of the file is brighter")
        XCTAssertGreaterThan(harmonic(7, 3), 0.05)
        // Starts at a rising zero crossing, so the loop has no seam.
        XCTAssertEqual(bank.value(frame: 4, level: 0, at: 0), 0, accuracy: 0.05)
    }

    func testASilentSampleMakesNoTable() throws {
        let buffer = try XCTUnwrap(SampleBuffer(samples: [Float](repeating: 0, count: 48_000), sampleRate: 48_000))
        XCTAssertNil(WavetableBank(sample: buffer, frames: 16))
    }

    /// A drum or a noise has no pitch: it is still cut, at a fixed cycle length, and plays.
    func testANoiseIsCutAtTheFallbackLength() throws {
        var seed: UInt32 = 7
        let noise = (0..<24_000).map { (_: Int) -> Float in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Float(Int32(bitPattern: seed)) / 2_147_483_648 * 0.5
        }
        let buffer = try XCTUnwrap(SampleBuffer(samples: noise, sampleRate: 48_000))
        let bank = try XCTUnwrap(WavetableBank(sample: buffer, frames: 4))
        let out = render(position: 0.5, frames: 4_800, bank: bank)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(out.map { abs($0) }.max() ?? 0, 0.1)
    }
}

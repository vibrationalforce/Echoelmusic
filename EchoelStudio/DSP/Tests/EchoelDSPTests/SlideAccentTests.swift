import XCTest
@testable import EchoelDSP

/// The bass-line glide and accent (EchoelTools A2): a key struck while another is held slides
/// there on the same voice; a hard note opens the filter further and plays louder.
final class SlideAccentTests: XCTestCase {
    private let rate: Float = 48_000

    private func patch(slide: Float = 0, accent: Float = 0) -> SynthPatch {
        var patch = SynthPatch(waveform: .saw, cutoff: 600, resonance: 0.2, filterEnvelopeAmount: 2,
                               filterEnvelope: .init(attack: 0.002, decay: 0.2, sustain: 0, release: 0.2),
                               ampEnvelope: .init(attack: 0.002, decay: 0.1, sustain: 0.8, release: 0.1), level: 1)
        patch.slide = slide
        patch.accent = accent
        return patch
    }

    private func run(_ synth: inout PolySynth, frames: Int) -> [Float] {
        var out = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let end = Swift.min(start + 128, frames)
            out[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
        }
        return out
    }

    /// Rising zero crossings per second over `x`: the frequency of a plain tone.
    private func hertz(_ x: [Float]) -> Float {
        var crossings: [Float] = []
        for i in 1..<x.count where x[i - 1] <= 0 && x[i] > 0 {
            crossings.append(Float(i - 1) + x[i - 1] / (x[i - 1] - x[i]))
        }
        guard let first = crossings.first, let last = crossings.last, crossings.count > 2 else { return 0 }
        return Float(crossings.count - 1) / (last - first) * rate
    }

    func testAnOverlappingNoteSlidesOnTheSameVoice() {
        var synth = PolySynth(patch: patch(slide: 0.06), sampleRate: rate)
        synth.noteOn(pitch: 45, velocity: 90)
        _ = run(&synth, frames: 4_800)
        synth.noteOn(pitch: 57, velocity: 90)
        XCTAssertEqual(synth.activeVoiceCount, 1, "one voice: the line moves")
        let glide = run(&synth, frames: 9_600)
        let early = hertz(Array(glide[0..<1_440])), late = hertz(Array(glide[7_200..<9_600]))
        XCTAssertGreaterThan(early, 115, "on its way up from 110 Hz")
        XCTAssertLessThan(early, 210, "not there yet")
        XCTAssertEqual(late, 220, accuracy: 3, "arrived")
        // The old key's release does not stop the slid note; the new key's does.
        synth.noteOff(pitch: 45)
        XCTAssertGreaterThan(Array(run(&synth, frames: 2_400)[1_200...]).map { abs($0) }.max() ?? 0, 0.05)
        synth.noteOff(pitch: 57)
        XCTAssertLessThan(Array(run(&synth, frames: 24_000)[20_000...]).map { abs($0) }.max() ?? 1, 1e-4)
    }

    func testWithoutSlideOrAtTheSameMomentEveryNoteHasItsVoice() {
        var plain = PolySynth(patch: patch(), sampleRate: rate)
        plain.noteOn(pitch: 45, velocity: 90)
        _ = run(&plain, frames: 480)
        plain.noteOn(pitch: 57, velocity: 90)
        XCTAssertEqual(plain.activeVoiceCount, 2)
        var chord = PolySynth(patch: patch(slide: 0.1), sampleRate: rate)
        for pitch: UInt8 in [45, 52, 57] { chord.noteOn(pitch: pitch, velocity: 90) }
        XCTAssertEqual(chord.activeVoiceCount, 3, "a chord struck at once is not a slide")
    }

    func testASlideDoesNotClick() {
        var synth = PolySynth(patch: patch(slide: 0.03), sampleRate: rate)
        synth.noteOn(pitch: 40, velocity: 100)
        var out = run(&synth, frames: 4_800)
        for (pitch, velocity) in [(52, 60), (47, 127), (59, 80)] as [(UInt8, UInt8)] {
            synth.noteOn(pitch: pitch, velocity: velocity)
            out += run(&synth, frames: 4_800)
        }
        // A step shows as a sample-to-sample jump far above what a 600 Hz-filtered saw moves.
        var worst: Float = 0
        for i in 1..<out.count { worst = Swift.max(worst, abs(out[i] - out[i - 1])) }
        XCTAssertLessThan(worst, 0.12)
    }

    /// A note at velocity 100 or more is accented: louder, and brighter while its filter
    /// envelope is open. Below it, and with Accent at 0, nothing changes.
    func testAHardNoteIsAccented() {
        func strike(_ velocity: UInt8, accent: Float) -> [Float] {
            var synth = PolySynth(patch: patch(accent: accent), sampleRate: rate)
            synth.noteOn(pitch: 45, velocity: velocity)
            return run(&synth, frames: 4_800)
        }
        func rms(_ x: [Float]) -> Float { (x.reduce(0) { $0 + $1 * $1 } / Float(x.count)).squareRoot() }
        let soft = rms(strike(99, accent: 1)), hard = rms(strike(100, accent: 1))
        // Velocity alone moves the level by (100/99)², 2 %; the accent by far more.
        XCTAssertGreaterThan(hard, soft * 1.3)
        XCTAssertEqual(strike(100, accent: 0), {
            var synth = PolySynth(patch: patch(), sampleRate: rate)
            synth.noteOn(pitch: 45, velocity: 100)
            return run(&synth, frames: 4_800)
        }(), "Accent 0 plays as before")
        XCTAssertEqual(strike(99, accent: 1), strike(99, accent: 0), "below the accent velocity, as before")
    }
}

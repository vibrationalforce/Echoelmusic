import XCTest
@testable import EchoelDSP

final class PolySynthTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(_ synth: inout PolySynth, seconds: Float) -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(seconds * rate))
        // Render in device-sized blocks, the way the engine will.
        var start = 0
        while start < buffer.count {
            let end = Swift.min(start + 256, buffer.count)
            buffer[start..<end].withUnsafeMutableBufferPointer { synth.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func peak(_ samples: [Float]) -> Float { samples.reduce(0) { Swift.max($0, Swift.abs($1)) } }

    func testANoteSoundsAndItsReleaseEndsInSilence() {
        var synth = PolySynth(sampleRate: rate)
        XCTAssertEqual(peak(render(&synth, seconds: 0.05)), 0)
        synth.noteOn(pitch: 60, velocity: 100)
        XCTAssertGreaterThan(peak(render(&synth, seconds: 0.2)), 0.01)
        synth.noteOff(pitch: 60)
        _ = render(&synth, seconds: 1)
        XCTAssertEqual(synth.activeVoiceCount, 0)
        XCTAssertEqual(peak(render(&synth, seconds: 0.05)), 0)
    }

    func testAChordUsesOneVoicePerNoteAndTheSamePitchRetriggersItsOwn() {
        var synth = PolySynth(sampleRate: rate)
        for pitch: UInt8 in [60, 64, 67] { synth.noteOn(pitch: pitch, velocity: 90) }
        XCTAssertEqual(synth.activeVoiceCount, 3)
        synth.noteOn(pitch: 64, velocity: 90)
        XCTAssertEqual(synth.activeVoiceCount, 3)
    }

    func testStealingTakesAReleasedVoiceFirstThenTheOldest() {
        var synth = PolySynth(voiceCount: 4, sampleRate: rate)
        for pitch: UInt8 in [60, 62, 64, 65] { synth.noteOn(pitch: pitch, velocity: 90) }
        synth.noteOff(pitch: 64)                      // released but still ringing
        synth.noteOn(pitch: 67, velocity: 90)
        XCTAssertEqual(Set(synth.voices.map(\.pitch)), [60, 62, 65, 67])

        synth.noteOn(pitch: 69, velocity: 90)         // all held: the oldest (60) goes
        XCTAssertEqual(Set(synth.voices.map(\.pitch)), [62, 65, 67, 69])
        XCTAssertEqual(synth.activeVoiceCount, 4)
    }

    func testThePitchIsInTune() {
        var patch = SynthPatch(waveform: .sine, cutoff: 18_000, filterEnvelopeAmount: 0)
        patch.ampEnvelope = .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.1)
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 69, velocity: 127)
        let samples = render(&synth, seconds: 1)
        var crossings = 0
        for i in 1..<samples.count where samples[i - 1] < 0 && samples[i] >= 0 { crossings += 1 }
        XCTAssertTrue((439...441).contains(crossings), "\(crossings)")
    }

    func testAFullHardChordAtMaximumResonanceNeverRunsAway() {
        var synth = PolySynth(patch: SynthPatch(resonance: 0.95), sampleRate: rate)
        for pitch in stride(from: UInt8(24), through: 120, by: 6) { synth.noteOn(pitch: pitch, velocity: 127) }
        let samples = render(&synth, seconds: 0.5)
        XCTAssertTrue(samples.allSatisfy(\.isFinite))
        // A resonant peak may ring loud (Q 20 on 16 voices); it must not grow without bound.
        XCTAssertLessThan(peak(samples), 100)
    }

    func testVelocityZeroIsANoteOffAndNonsenseIsIgnored() {
        var synth = PolySynth(sampleRate: rate)
        synth.noteOn(pitch: 60, velocity: 100)
        synth.noteOn(pitch: 60, velocity: 0)
        XCTAssertFalse(synth.voices.contains { $0.isHeld })
        synth.noteOn(pitch: 200, velocity: 100)
        synth.noteOff(pitch: 33)
        XCTAssertFalse(synth.voices.contains { $0.isHeld })
    }

    func testAllNotesOffReleasesAndResetSilencesAtOnce() {
        var synth = PolySynth(sampleRate: rate)
        for pitch: UInt8 in [48, 52, 55] { synth.noteOn(pitch: pitch, velocity: 100) }
        _ = render(&synth, seconds: 0.05)
        synth.allNotesOff()
        XCTAssertFalse(synth.voices.contains { $0.isHeld })
        XCTAssertGreaterThan(synth.activeVoiceCount, 0)    // still ringing out
        synth.reset()
        XCTAssertEqual(synth.activeVoiceCount, 0)
    }

    func testAPatchChangeReachesSoundingVoices() {
        var synth = PolySynth(sampleRate: rate)
        synth.noteOn(pitch: 60, velocity: 100)
        var patch = synth.patch
        patch.level = 0
        synth.setPatch(patch)
        XCTAssertEqual(peak(render(&synth, seconds: 0.05)), 0)
    }
}

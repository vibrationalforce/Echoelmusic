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

    private func render(_ synth: inout PolySynth, frames: Int) -> [Float] {
        var buffer = [Float](repeating: 0, count: frames)
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

    func testALevelOrCutoffChangeGlidesInsteadOfJumping() {
        var patch = SynthPatch(waveform: .sine, cutoff: 12_000, filterEnvelopeAmount: 0,
                               ampEnvelope: .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.2), level: 1)
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 69, velocity: 127)
        let before = peak(Array(render(&synth, seconds: 0.1).suffix(480)))
        patch.level = 0
        synth.setPatch(patch)
        let firstMillisecond = peak(render(&synth, seconds: 0.001))
        XCTAssertGreaterThan(firstMillisecond, before * 0.5, "the level glides down, it does not cut")
        let later = peak(Array(render(&synth, seconds: 0.06).suffix(480)))
        XCTAssertLessThan(later, before * 0.01, "and arrives within a few time constants")
    }

    /// A note struck hard and then again softly while it still sounds moves to the softer
    /// level without a step: the largest sample-to-sample change at the re-strike stays near the
    /// sine's own (audit 2026-10-23).
    func testAReStruckNoteGlidesToItsNewVelocityInsteadOfClicking() {
        let patch = SynthPatch(waveform: .sine, cutoff: 18_000, filterEnvelopeAmount: 0,
                               ampEnvelope: .init(attack: 0.003, decay: 0.2, sustain: 0.9, release: 0.2), level: 0.35)
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 45, velocity: 120)
        // 110 Hz: 33¼ periods, so the re-strike lands near the top of the waveform, where a
        // jump in gain is largest.
        let periodFrames: Double = 48_000 / 110
        let before = render(&synth, frames: Int((33.25 * periodFrames).rounded()))
        synth.noteOff(pitch: 45)
        synth.noteOn(pitch: 45, velocity: 70)
        let after = render(&synth, frames: 480)
        func largestStep(_ samples: [Float]) -> Float {
            var largest: Float = 0
            for index in 1..<samples.count { largest = Swift.max(largest, Swift.abs(samples[index] - samples[index - 1])) }
            return largest
        }
        let steady = largestStep(Array(before.suffix(480)))
        XCTAssertGreaterThan(steady, 0.001, "the note sounds")
        let joined: [Float] = [before[before.count - 1]] + after
        XCTAssertLessThan(largestStep(joined), steady * 1.5, "the softer strike glides, it does not step")
        let settled: Float = peak(Array(render(&synth, seconds: 0.1).suffix(480)))
        let hard: Float = peak(Array(before.suffix(480)))
        XCTAssertLessThan(settled, hard * 0.5, "and arrives at the softer level")
    }

    func testANoteEndsWhileItsPatchIsAutomated() {
        var patch = SynthPatch(waveform: .saw, cutoff: 2_000,
                               ampEnvelope: .init(attack: 0.003, decay: 0.1, sustain: 0.7, release: 0.1))
        var synth = PolySynth(patch: patch, sampleRate: rate)
        synth.noteOn(pitch: 60, velocity: 100)
        var buffer = [Float](repeating: 0, count: 32)
        // A cutoff sweep, applied every 32 frames as the engine does.
        for step in 0..<Int(0.3 * rate / 32) {
            if step == Int(0.15 * rate / 32) { synth.noteOff(pitch: 60) }
            patch.cutoff = 2_000 + Float(step % 100) * 20
            synth.setPatch(patch)
            buffer.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        }
        XCTAssertEqual(synth.activeVoiceCount, 0, "the release finished although the patch moved every block")
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

    private func crossings(_ samples: [Float]) -> Int {
        var count = 0
        for i in 1..<samples.count where samples[i - 1] < 0 && samples[i] >= 0 { count += 1 }
        return count
    }

    private func sineSynth() -> PolySynth {
        var patch = SynthPatch(waveform: .sine, cutoff: 18_000, filterEnvelopeAmount: 0)
        patch.ampEnvelope = .init(attack: 0.001, decay: 0.01, sustain: 1, release: 0.05)
        return PolySynth(patch: patch, sampleRate: rate)
    }

    func testTheWheelBendsTwoSemitonesEachWayAndRestsInTune() {
        var synth = sineSynth()
        synth.noteOn(pitch: 69, velocity: 127)
        synth.pitchBend(16_383)
        _ = render(&synth, seconds: 0.01)
        let up = crossings(render(&synth, seconds: 1))
        XCTAssertTrue((492...496).contains(up), "A4 two semitones up is 493.9 Hz, got \(up)")
        synth.pitchBend(0)
        _ = render(&synth, seconds: 0.01)
        let down = crossings(render(&synth, seconds: 1))
        XCTAssertTrue((391...393).contains(down), "two semitones down is 392 Hz, got \(down)")
        synth.pitchBend(8_192)
        _ = render(&synth, seconds: 0.01)
        XCTAssertTrue((439...441).contains(crossings(render(&synth, seconds: 1))))
    }

    func testTheBendGlidesAcrossABufferInsteadOfStepping() {
        var synth = sineSynth()
        synth.noteOn(pitch: 69, velocity: 127)
        _ = render(&synth, seconds: 0.05)
        synth.pitchBend(16_383)
        var block = [Float](repeating: 0, count: 4_800)
        block.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        // Over the 100 ms block the frequency moves from 440 to 494 Hz: in between, not at either end.
        let measured = crossings(block)
        XCTAssertTrue((45...48).contains(measured), "\(measured)")
    }

    func testTheSustainPedalHoldsReleasedKeysUntilItComesUp() {
        var synth = sineSynth()
        synth.sustain(true)
        synth.noteOn(pitch: 60, velocity: 100)
        _ = render(&synth, seconds: 0.05)
        synth.noteOff(pitch: 60)
        XCTAssertGreaterThan(peak(Array(render(&synth, seconds: 0.5).suffix(480))), 0.01, "the pedal holds it")
        synth.sustain(false)
        _ = render(&synth, seconds: 0.5)
        XCTAssertEqual(synth.activeVoiceCount, 0, "pedal up releases it")
    }

    func testAKeyStillDownWhenThePedalComesUpKeepsSounding() {
        var synth = sineSynth()
        synth.sustain(true)
        synth.noteOn(pitch: 60, velocity: 100)
        synth.sustain(false)
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 1)
        synth.noteOff(pitch: 60)
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 0)
    }

    func testAllNotesOffLiftsThePedalAndCentresTheWheel() {
        var synth = sineSynth()
        synth.sustain(true)
        synth.pitchBend(16_383)
        synth.noteOn(pitch: 69, velocity: 127)
        synth.noteOff(pitch: 69)
        synth.allNotesOff()
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 0)
        synth.noteOn(pitch: 69, velocity: 127)
        _ = render(&synth, seconds: 0.01)
        XCTAssertTrue((439...441).contains(crossings(render(&synth, seconds: 1))))
    }

    /// The frequency of every whole cycle, from one rising zero crossing to the next.
    private func cycleFrequencies(_ samples: [Float]) -> [Float] {
        var rising: [Float] = []
        for i in 1..<samples.count where samples[i - 1] < 0 && samples[i] >= 0 {
            rising.append(Float(i - 1) + -samples[i - 1] / (samples[i] - samples[i - 1]))
        }
        return zip(rising, rising.dropFirst()).map { rate / ($1 - $0) }
    }

    /// Derived, not observed: 440 Hz × 2^(±0.5/12) is 427.5 … 452.9 Hz, and a model of this
    /// algorithm (blocks of 32 frames, 256-frame buffers) measures exactly that.
    func testTheModulationWheelSwingsThePitchFiftyCentsEachWayAndRestsInTune() throws {
        var synth = sineSynth()
        synth.noteOn(pitch: 69, velocity: 127)
        synth.modulation(127)
        _ = render(&synth, seconds: 0.5)
        let swung = cycleFrequencies(render(&synth, seconds: 2))
        let low = try XCTUnwrap(swung.min()), high = try XCTUnwrap(swung.max())
        XCTAssertTrue((426...429).contains(low), "50 cents down is 427.5 Hz, got \(low)")
        XCTAssertTrue((451...454.5).contains(high), "50 cents up is 452.9 Hz, got \(high)")
        synth.modulation(0)
        _ = render(&synth, seconds: 0.5)
        let rested = cycleFrequencies(render(&synth, seconds: 1))
        XCTAssertTrue(rested.allSatisfy { (439.5...440.5).contains($0) }, "the wheel down, the note is in tune again")
    }

    func testAWheelAtRestAndAControllerTheSynthDoesNotReadChangeNothing() {
        var plain = sineSynth(), touched = sineSynth()
        touched.modulation(0)
        touched.controller(7, 20)
        touched.controller(74, 127)
        plain.noteOn(pitch: 64, velocity: 100)
        touched.noteOn(pitch: 64, velocity: 100)
        XCTAssertEqual(render(&plain, seconds: 0.2), render(&touched, seconds: 0.2))
    }

    func testTheControllersAGeneralMIDISynthReads() {
        var synth = sineSynth()
        synth.controller(64, 127)
        synth.noteOn(pitch: 60, velocity: 100)
        synth.noteOff(pitch: 60)
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 1, "controller 64 is the pedal")
        synth.controller(121, 0)
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 0, "121 resets the controllers: the pedal comes up")

        synth.noteOn(pitch: 62, velocity: 100)
        synth.controller(123, 0)
        _ = render(&synth, seconds: 0.3)
        XCTAssertEqual(synth.activeVoiceCount, 0, "123 releases every note")

        synth.noteOn(pitch: 64, velocity: 100)
        _ = render(&synth, seconds: 0.05)
        synth.controller(120, 0)
        XCTAssertEqual(synth.activeVoiceCount, 0, "120 silences at once")

        synth.controller(1, 127)
        synth.pitchBend(16_383)
        synth.controller(121, 0)
        synth.noteOn(pitch: 69, velocity: 127)
        _ = render(&synth, seconds: 0.5)
        let after = cycleFrequencies(render(&synth, seconds: 1))
        XCTAssertTrue(after.allSatisfy { (439.5...440.5).contains($0) }, "121 also centres the wheel and lowers the modulation")
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

    func testAfterResetAndResetControllersTheNextNoteSoundsAsOnAFreshSynth() {
        var used = PolySynth(sampleRate: rate)
        used.noteOn(pitch: 60, velocity: 100)
        used.pitchBend(16_383)
        used.modulation(127)
        used.sustain(true)
        _ = render(&used, seconds: 0.25)
        used.noteOff(pitch: 60)
        used.reset()
        used.resetControllers()

        var fresh = PolySynth(sampleRate: rate)
        used.noteOn(pitch: 64, velocity: 100)
        fresh.noteOn(pitch: 64, velocity: 100)
        let usedHeld = render(&used, seconds: 0.1)
        let freshHeld = render(&fresh, seconds: 0.1)
        used.noteOff(pitch: 64)
        fresh.noteOff(pitch: 64)
        let heard: [Float] = usedHeld + render(&used, seconds: 0.5)
        let expected: [Float] = freshHeld + render(&fresh, seconds: 0.5)
        XCTAssertNil(heard.indices.first { heard[$0] != expected[$0] },
                     "first differing sample: the note is bent, vibrating or held by the pedal")
        XCTAssertGreaterThan(peak(expected), 0.01, "the reference plays")
        XCTAssertEqual(used.activeVoiceCount, 0, "the pedal is up, so the key-up released the note")
    }

    func testAPatchChangeReachesSoundingVoices() {
        var synth = PolySynth(sampleRate: rate)
        synth.noteOn(pitch: 60, velocity: 100)
        var patch = synth.patch
        patch.level = 0
        synth.setPatch(patch)
        // The level glides (5 ms), so the sounding voice falls silent within a few time
        // constants instead of at the next sample.
        _ = render(&synth, seconds: 0.1)
        XCTAssertLessThan(peak(render(&synth, seconds: 0.02)), 1e-6)
    }
}

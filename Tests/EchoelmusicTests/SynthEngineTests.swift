import XCTest
@testable import Echoelmusic

/// Comprehensive Unit Tests for SynthEngine
/// Tests synthesis, oscillators, filters, envelopes, LFOs, modulation, voice management
@MainActor
final class SynthEngineTests: XCTestCase {

    var synthEngine: SynthEngine!

    override func setUp() async throws {
        await MainActor.run {
            synthEngine = SynthEngine()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            synthEngine = nil
        }
    }

    // MARK: - Initialization Tests

    func testSynthEngineInitialization() async throws {
        await MainActor.run {
            XCTAssertEqual(synthEngine.maxPolyphony, 16)
            XCTAssertEqual(synthEngine.voices.count, 0)
            XCTAssertEqual(synthEngine.currentPatch.name, "Init")
            XCTAssertEqual(synthEngine.currentPatch.type, .subtractive)
        }
    }

    // MARK: - Oscillator Tests

    func testOscillatorConfiguration() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            // Configure first oscillator
            patch.oscillators[0].enabled = true
            patch.oscillators[0].waveform = .saw
            patch.oscillators[0].octave = 0
            patch.oscillators[0].semitone = 0
            patch.oscillators[0].level = 1.0

            synthEngine.loadPatch(patch)

            XCTAssertTrue(synthEngine.currentPatch.oscillators[0].enabled)
            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].waveform, .saw)
            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].level, 1.0)
        }
    }

    func testMultipleOscillators() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            // Enable three oscillators with different waveforms
            patch.oscillators[0].enabled = true
            patch.oscillators[0].waveform = .saw

            patch.oscillators[1].enabled = true
            patch.oscillators[1].waveform = .square
            patch.oscillators[1].octave = 1 // One octave up

            patch.oscillators[2].enabled = true
            patch.oscillators[2].waveform = .sine
            patch.oscillators[2].octave = -1 // One octave down

            synthEngine.loadPatch(patch)

            let enabledCount = synthEngine.currentPatch.oscillators.filter { $0.enabled }.count
            XCTAssertEqual(enabledCount, 3)
        }
    }

    func testOscillatorDetune() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.oscillators[0].enabled = true
            patch.oscillators[0].semitone = 7 // Perfect fifth
            patch.oscillators[0].cents = 10.0 // Slightly sharp

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].semitone, 7)
            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].cents, 10.0)
        }
    }

    func testOscillatorUnison() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.oscillators[0].enabled = true
            patch.oscillators[0].unisonVoices = 4
            patch.oscillators[0].unisonDetune = 20.0

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].unisonVoices, 4)
            XCTAssertEqual(synthEngine.currentPatch.oscillators[0].unisonDetune, 20.0)
        }
    }

    // MARK: - Filter Tests

    func testFilterConfiguration() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.filter.enabled = true
            patch.filter.type = .lowpass
            patch.filter.cutoff = 1000.0
            patch.filter.resonance = 0.7
            patch.filter.keyTracking = 0.5

            synthEngine.loadPatch(patch)

            XCTAssertTrue(synthEngine.currentPatch.filter.enabled)
            XCTAssertEqual(synthEngine.currentPatch.filter.type, .lowpass)
            XCTAssertEqual(synthEngine.currentPatch.filter.cutoff, 1000.0)
            XCTAssertEqual(synthEngine.currentPatch.filter.resonance, 0.7)
        }
    }

    func testFilterTypes() async throws {
        await MainActor.run {
            let filterTypes: [SynthEngine.Filter.FilterType] = [
                .lowpass, .highpass, .bandpass, .notch,
                .lowshelf, .highshelf, .peak, .allpass
            ]

            for filterType in filterTypes {
                var patch = synthEngine.currentPatch
                patch.filter.enabled = true
                patch.filter.type = filterType
                synthEngine.loadPatch(patch)

                XCTAssertEqual(synthEngine.currentPatch.filter.type, filterType)
            }
        }
    }

    // MARK: - Envelope Tests

    func testAmpEnvelope() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.ampEnvelope.attack = 0.01
            patch.ampEnvelope.decay = 0.1
            patch.ampEnvelope.sustain = 0.7
            patch.ampEnvelope.release = 0.5

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.ampEnvelope.attack, 0.01)
            XCTAssertEqual(synthEngine.currentPatch.ampEnvelope.decay, 0.1)
            XCTAssertEqual(synthEngine.currentPatch.ampEnvelope.sustain, 0.7)
            XCTAssertEqual(synthEngine.currentPatch.ampEnvelope.release, 0.5)
        }
    }

    func testFilterEnvelope() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.filterEnvelope.attack = 0.5
            patch.filterEnvelope.decay = 1.0
            patch.filterEnvelope.sustain = 0.3
            patch.filterEnvelope.release = 2.0

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.filterEnvelope.attack, 0.5)
            XCTAssertEqual(synthEngine.currentPatch.filterEnvelope.decay, 1.0)
            XCTAssertEqual(synthEngine.currentPatch.filterEnvelope.sustain, 0.3)
            XCTAssertEqual(synthEngine.currentPatch.filterEnvelope.release, 2.0)
        }
    }

    func testEnvelopeCurves() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.ampEnvelope.attackCurve = .exponential
            patch.filterEnvelope.attackCurve = .logarithmic

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.ampEnvelope.attackCurve, .exponential)
            XCTAssertEqual(synthEngine.currentPatch.filterEnvelope.attackCurve, .logarithmic)
        }
    }

    // MARK: - LFO Tests

    func testLFOConfiguration() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.lfos[0].enabled = true
            patch.lfos[0].waveform = .sine
            patch.lfos[0].rate = 2.0
            patch.lfos[0].depth = 0.5
            patch.lfos[0].syncToTempo = false

            synthEngine.loadPatch(patch)

            XCTAssertTrue(synthEngine.currentPatch.lfos[0].enabled)
            XCTAssertEqual(synthEngine.currentPatch.lfos[0].waveform, .sine)
            XCTAssertEqual(synthEngine.currentPatch.lfos[0].rate, 2.0)
            XCTAssertEqual(synthEngine.currentPatch.lfos[0].depth, 0.5)
        }
    }

    func testLFOTempoSync() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            patch.lfos[0].enabled = true
            patch.lfos[0].syncToTempo = true
            patch.lfos[0].tempoMultiplier = .quarter

            synthEngine.loadPatch(patch)

            XCTAssertTrue(synthEngine.currentPatch.lfos[0].syncToTempo)
            XCTAssertEqual(synthEngine.currentPatch.lfos[0].tempoMultiplier, .quarter)
        }
    }

    func testMultipleLFOs() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            // LFO 1: Modulate filter cutoff
            patch.lfos[0].enabled = true
            patch.lfos[0].waveform = .sine
            patch.lfos[0].destination = .filterCutoff

            // LFO 2: Modulate pitch
            patch.lfos[1].enabled = true
            patch.lfos[1].waveform = .triangle
            patch.lfos[1].destination = .pitch

            synthEngine.loadPatch(patch)

            let enabledLFOs = synthEngine.currentPatch.lfos.filter { $0.enabled }
            XCTAssertEqual(enabledLFOs.count, 2)
        }
    }

    // MARK: - Modulation Matrix Tests

    func testModulationRoute() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            let route = SynthEngine.ModulationMatrix.ModulationRoute(
                source: .lfo1,
                destination: .filterCutoff,
                amount: 0.8
            )

            patch.modulationMatrix.routes.append(route)
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.modulationMatrix.routes.count, 1)
            XCTAssertEqual(synthEngine.currentPatch.modulationMatrix.routes[0].source, .lfo1)
            XCTAssertEqual(synthEngine.currentPatch.modulationMatrix.routes[0].destination, .filterCutoff)
            XCTAssertEqual(synthEngine.currentPatch.modulationMatrix.routes[0].amount, 0.8)
        }
    }

    func testComplexModulationMatrix() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch

            // Multiple modulation routes
            patch.modulationMatrix.routes = [
                SynthEngine.ModulationMatrix.ModulationRoute(source: .lfo1, destination: .filterCutoff, amount: 0.7),
                SynthEngine.ModulationMatrix.ModulationRoute(source: .lfo2, destination: .pitch, amount: 0.3),
                SynthEngine.ModulationMatrix.ModulationRoute(source: .velocity, destination: .filterResonance, amount: 0.5),
                SynthEngine.ModulationMatrix.ModulationRoute(source: .modWheel, destination: .lfo1Depth, amount: 1.0)
            ]

            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.modulationMatrix.routes.count, 4)
        }
    }

    // MARK: - Voice Management Tests

    func testNoteOn() async throws {
        await MainActor.run {
            synthEngine.noteOn(note: 60, velocity: 100)

            XCTAssertEqual(synthEngine.voices.count, 1)
            XCTAssertEqual(synthEngine.voices[0].note, 60)
            XCTAssertEqual(synthEngine.voices[0].velocity, 100)
            XCTAssertTrue(synthEngine.voices[0].isActive)
        }
    }

    func testNoteOff() async throws {
        await MainActor.run {
            synthEngine.noteOn(note: 60, velocity: 100)
            XCTAssertEqual(synthEngine.voices.count, 1)

            synthEngine.noteOff(note: 60)

            // Voice should be in release phase
            XCTAssertFalse(synthEngine.voices[0].isActive)
        }
    }

    func testPolyphony() async throws {
        await MainActor.run {
            // Play multiple notes
            for note in 60...70 {
                synthEngine.noteOn(note: note, velocity: 100)
            }

            XCTAssertEqual(synthEngine.voices.count, 11)
        }
    }

    func testVoiceStealing() async throws {
        await MainActor.run {
            synthEngine.maxPolyphony = 4

            // Play more notes than polyphony limit
            for note in 60...65 {
                synthEngine.noteOn(note: note, velocity: 100)
            }

            // Should not exceed max polyphony
            XCTAssertLessThanOrEqual(synthEngine.voices.filter { $0.isActive }.count, 4)
        }
    }

    func testVelocitySensitivity() async throws {
        await MainActor.run {
            synthEngine.noteOn(note: 60, velocity: 50)
            let lowVelocityVoice = synthEngine.voices[0]

            synthEngine.noteOff(note: 60)
            synthEngine.voices.removeAll()

            synthEngine.noteOn(note: 60, velocity: 127)
            let highVelocityVoice = synthEngine.voices[0]

            XCTAssertLessThan(lowVelocityVoice.velocity, highVelocityVoice.velocity)
        }
    }

    // MARK: - Audio Generation Tests

    func testAudioGeneration() async throws {
        await MainActor.run {
            synthEngine.noteOn(note: 60, velocity: 100)

            let frameCount = 512
            let sampleRate = 44100.0

            let audioBuffer = synthEngine.generateAudio(frameCount: frameCount, sampleRate: sampleRate)

            XCTAssertEqual(audioBuffer.count, frameCount)

            // Check that audio is not silent
            let rms = sqrt(audioBuffer.map { $0 * $0 }.reduce(0, +) / Float(audioBuffer.count))
            XCTAssertGreaterThan(rms, 0.0)
        }
    }

    func testSilenceWhenNoNotes() async throws {
        await MainActor.run {
            let frameCount = 512
            let sampleRate = 44100.0

            let audioBuffer = synthEngine.generateAudio(frameCount: frameCount, sampleRate: sampleRate)

            // Should be silent
            let rms = sqrt(audioBuffer.map { $0 * $0 }.reduce(0, +) / Float(audioBuffer.count))
            XCTAssertEqual(rms, 0.0, accuracy: 0.0001)
        }
    }

    // MARK: - Synthesis Type Tests

    func testSubtractiveSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .subtractive
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .subtractive)
        }
    }

    func testFMSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .fm
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .fm)
        }
    }

    func testWavetableSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .wavetable
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .wavetable)
        }
    }

    func testAdditiveSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .additive
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .additive)
        }
    }

    func testGranularSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .granular
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .granular)
        }
    }

    func testPhysicalModelingSynthesis() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.type = .physical
            synthEngine.loadPatch(patch)

            XCTAssertEqual(synthEngine.currentPatch.type, .physical)
        }
    }

    // MARK: - Patch Management Tests

    func testSavePatch() async throws {
        await MainActor.run {
            var patch = synthEngine.currentPatch
            patch.name = "My Awesome Synth"
            patch.oscillators[0].enabled = true
            patch.filter.enabled = true
            synthEngine.loadPatch(patch)

            let savedPatch = synthEngine.savePatch(name: "My Awesome Synth")

            XCTAssertEqual(savedPatch.name, "My Awesome Synth")
            XCTAssertTrue(savedPatch.oscillators[0].enabled)
            XCTAssertTrue(savedPatch.filter.enabled)
        }
    }

    func testLoadPatch() async throws {
        await MainActor.run {
            // Create custom patch
            var customPatch = SynthEngine.SynthPatch(
                name: "Custom",
                type: .fm,
                oscillators: [
                    SynthEngine.Oscillator(enabled: true, waveform: .sine, octave: 0, semitone: 0, cents: 0, level: 1.0, unisonVoices: 1, unisonDetune: 0),
                    SynthEngine.Oscillator(enabled: true, waveform: .square, octave: 1, semitone: 7, cents: 0, level: 0.5, unisonVoices: 1, unisonDetune: 0),
                    SynthEngine.Oscillator(enabled: false, waveform: .saw, octave: 0, semitone: 0, cents: 0, level: 0, unisonVoices: 1, unisonDetune: 0)
                ],
                filter: SynthEngine.Filter(enabled: true, type: .lowpass, cutoff: 2000.0, resonance: 0.5, keyTracking: 0.0),
                ampEnvelope: SynthEngine.Envelope(attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.3, attackCurve: .linear, decayCurve: .exponential, releaseCurve: .exponential),
                filterEnvelope: SynthEngine.Envelope(attack: 0.1, decay: 0.5, sustain: 0.3, release: 1.0, attackCurve: .exponential, decayCurve: .linear, releaseCurve: .exponential),
                lfos: [
                    SynthEngine.LFO(enabled: true, waveform: .sine, rate: 4.0, depth: 0.5, syncToTempo: true, tempoMultiplier: .quarter, destination: .filterCutoff),
                    SynthEngine.LFO(enabled: false, waveform: .triangle, rate: 1.0, depth: 0.0, syncToTempo: false, tempoMultiplier: .whole, destination: .pitch)
                ],
                modulationMatrix: SynthEngine.ModulationMatrix(routes: []),
                createdBy: "User"
            )

            synthEngine.loadPatch(customPatch)

            XCTAssertEqual(synthEngine.currentPatch.name, "Custom")
            XCTAssertEqual(synthEngine.currentPatch.type, .fm)
            XCTAssertTrue(synthEngine.currentPatch.oscillators[0].enabled)
            XCTAssertTrue(synthEngine.currentPatch.oscillators[1].enabled)
            XCTAssertFalse(synthEngine.currentPatch.oscillators[2].enabled)
        }
    }

    func testPatchUserOwnership() async throws {
        await MainActor.run {
            let patch = synthEngine.savePatch(name: "User Created")

            XCTAssertEqual(patch.createdBy, "User")
        }
    }

    // MARK: - Performance Tests

    func testPerformanceAudioGeneration() throws {
        measure {
            Task { @MainActor in
                let synth = SynthEngine()
                synth.noteOn(note: 60, velocity: 100)

                // Generate 1 second of audio at 44.1kHz
                for _ in 0..<86 {
                    _ = synth.generateAudio(frameCount: 512, sampleRate: 44100.0)
                }
            }
        }
    }

    func testPerformancePolyphonicAudio() throws {
        measure {
            Task { @MainActor in
                let synth = SynthEngine()
                synth.maxPolyphony = 16

                // Play full chord
                for note in [60, 64, 67, 71, 74, 77] {
                    synth.noteOn(note: note, velocity: 100)
                }

                // Generate audio
                for _ in 0..<86 {
                    _ = synth.generateAudio(frameCount: 512, sampleRate: 44100.0)
                }
            }
        }
    }

    func testPerformanceVoiceManagement() throws {
        measure {
            Task { @MainActor in
                let synth = SynthEngine()

                // Rapidly trigger and release voices
                for i in 0..<100 {
                    let note = 60 + (i % 24)
                    synth.noteOn(note: note, velocity: 100)
                    if i > 10 {
                        synth.noteOff(note: note - 10)
                    }
                }
            }
        }
    }
}

#if canImport(AVFoundation)
// MIDIExtendedTests.swift
// Echoelmusic — Extended MIDI Module Test Coverage
//
// Tests for AudioToQuantumMIDI types, QuantumMIDIOut types,
// VoiceToQuantumMIDI types, TouchInstruments types, and PianoRoll types.

import XCTest
@testable import Echoelmusic

// MARK: - AudioInputSource Tests

final class AudioInputSourceTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AudioInputSource.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(AudioInputSource.microphone.rawValue, "Mikrofon")
        XCTAssertEqual(AudioInputSource.lineIn.rawValue, "Line-In / Klinke")
        XCTAssertEqual(AudioInputSource.audioInterface.rawValue, "Audio Interface")
        XCTAssertEqual(AudioInputSource.audioFile.rawValue, "Audio Datei")
        XCTAssertEqual(AudioInputSource.bluetooth.rawValue, "Bluetooth Audio")
        XCTAssertEqual(AudioInputSource.aggregate.rawValue, "Aggregat (Mehrere)")
    }

    func testIdentifiable() {
        for source in AudioInputSource.allCases {
            XCTAssertEqual(source.id, source.rawValue)
        }
    }

    func testSystemIcons() {
        XCTAssertEqual(AudioInputSource.microphone.systemIcon, "mic.fill")
        XCTAssertEqual(AudioInputSource.lineIn.systemIcon, "cable.connector")
        XCTAssertEqual(AudioInputSource.audioInterface.systemIcon, "rectangle.connected.to.line.below")
        XCTAssertEqual(AudioInputSource.audioFile.systemIcon, "doc.richtext.fill")
        XCTAssertEqual(AudioInputSource.bluetooth.systemIcon, "airpodspro")
        XCTAssertEqual(AudioInputSource.aggregate.systemIcon, "square.stack.3d.up.fill")
    }

    func testSystemIconsNotEmpty() {
        for source in AudioInputSource.allCases {
            XCTAssertFalse(source.systemIcon.isEmpty)
        }
    }
}

// MARK: - PitchDetectionMode Tests

final class PitchDetectionModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PitchDetectionMode.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(PitchDetectionMode.monophonic.rawValue, "Monophon (Stimme/Solo)")
        XCTAssertEqual(PitchDetectionMode.polyphonic.rawValue, "Polyphon (Akkorde/Gitarre)")
        XCTAssertEqual(PitchDetectionMode.percussive.rawValue, "Perkussiv (Drums)")
        XCTAssertEqual(PitchDetectionMode.hybrid.rawValue, "Hybrid (Automatisch)")
    }

    func testIdentifiable() {
        for mode in PitchDetectionMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testDescriptionNotEmpty() {
        for mode in PitchDetectionMode.allCases {
            XCTAssertFalse(mode.description.isEmpty)
        }
    }

    func testDescriptionValues() {
        XCTAssertTrue(PitchDetectionMode.monophonic.description.contains("YIN"))
        XCTAssertTrue(PitchDetectionMode.polyphonic.description.contains("FFT"))
        XCTAssertTrue(PitchDetectionMode.percussive.description.contains("Onset"))
        XCTAssertTrue(PitchDetectionMode.hybrid.description.contains("Automatische"))
    }
}

// MARK: - DetectedNote Tests

final class DetectedNoteTests: XCTestCase {

    func testInit() {
        let note = DetectedNote(midiNote: 60, frequency: 261.63)
        XCTAssertEqual(note.midiNote, 60)
        XCTAssertEqual(note.frequency, 261.63, accuracy: 0.01)
        XCTAssertEqual(note.amplitude, 0.5)
        XCTAssertEqual(note.cents, 0)
        XCTAssertEqual(note.confidence, 1.0)
        XCTAssertFalse(note.onset)
        XCTAssertFalse(note.isPercussive)
    }

    func testInitWithAllParameters() {
        let note = DetectedNote(
            midiNote: 69,
            frequency: 440.0,
            amplitude: 0.8,
            cents: -5.0,
            confidence: 0.95,
            onset: true,
            isPercussive: true
        )
        XCTAssertEqual(note.midiNote, 69)
        XCTAssertEqual(note.frequency, 440.0)
        XCTAssertEqual(note.amplitude, 0.8)
        XCTAssertEqual(note.cents, -5.0)
        XCTAssertEqual(note.confidence, 0.95)
        XCTAssertTrue(note.onset)
        XCTAssertTrue(note.isPercussive)
    }

    func testIdentifiable() {
        let note = DetectedNote(midiNote: 60, frequency: 261.63)
        XCTAssertNotNil(note.id)
    }

    func testUniqueIds() {
        let note1 = DetectedNote(midiNote: 60, frequency: 261.63)
        let note2 = DetectedNote(midiNote: 60, frequency: 261.63)
        XCTAssertNotEqual(note1.id, note2.id)
    }
}

// MARK: - AudioInputDevice Tests

final class AudioInputDeviceTests: XCTestCase {

    func testInitDefaults() {
        let device = AudioInputDevice(id: "test-id", name: "Test Mic")
        XCTAssertEqual(device.id, "test-id")
        XCTAssertEqual(device.name, "Test Mic")
        XCTAssertEqual(device.manufacturer, "Unknown")
        XCTAssertEqual(device.channelCount, 2)
        XCTAssertEqual(device.sampleRate, 48000)
        XCTAssertFalse(device.isDefault)
        XCTAssertEqual(device.source, .microphone)
    }

    func testInitWithAllParameters() {
        let device = AudioInputDevice(
            id: "focusrite-1",
            name: "Scarlett 2i2",
            manufacturer: "Focusrite",
            channelCount: 2,
            sampleRate: 96000,
            isDefault: true,
            source: .audioInterface
        )
        XCTAssertEqual(device.id, "focusrite-1")
        XCTAssertEqual(device.name, "Scarlett 2i2")
        XCTAssertEqual(device.manufacturer, "Focusrite")
        XCTAssertEqual(device.channelCount, 2)
        XCTAssertEqual(device.sampleRate, 96000)
        XCTAssertTrue(device.isDefault)
        XCTAssertEqual(device.source, .audioInterface)
    }

    func testIdentifiable() {
        let device = AudioInputDevice(id: "unique-id", name: "Mic")
        XCTAssertEqual(device.id, "unique-id")
    }
}

// MARK: - AudioInputError Tests

final class AudioInputErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(AudioInputError.engineSetupFailed.errorDescription, "Audio engine setup failed")
        XCTAssertEqual(AudioInputError.invalidFormat.errorDescription, "Invalid audio format")
        XCTAssertEqual(AudioInputError.fileLoadFailed.errorDescription, "Failed to load audio file")
        XCTAssertEqual(AudioInputError.deviceNotAvailable.errorDescription, "Audio device not available")
    }

    func testErrorConformsToError() {
        let error: Error = AudioInputError.engineSetupFailed
        XCTAssertNotNil(error)
    }

    func testLocalizedErrorConformance() {
        let error: LocalizedError = AudioInputError.invalidFormat
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - QuantumMIDIConstants Tests

final class QuantumMIDIConstantsTests: XCTestCase {

    func testMaxPolyphony() {
        XCTAssertEqual(QuantumMIDIConstants.maxPolyphony, 64)
    }

    func testMPEVoices() {
        XCTAssertEqual(QuantumMIDIConstants.mpeVoices, 15)
    }

    func testDefaultVelocity() {
        XCTAssertEqual(QuantumMIDIConstants.defaultVelocity, 0.75)
    }

    func testCoherenceToVelocityRange() {
        XCTAssertEqual(QuantumMIDIConstants.coherenceToVelocityRange, 0.4...1.0)
    }

    func testHRVToExpressionRange() {
        XCTAssertEqual(QuantumMIDIConstants.hrvToExpressionRange, 0.0...1.0)
    }

    func testPhaseToModulationRange() {
        XCTAssertEqual(QuantumMIDIConstants.phaseToModulationRange, 0.0...1.0)
    }

    func testBaseOctave() {
        XCTAssertEqual(QuantumMIDIConstants.baseOctave, 3)
    }

    func testOctaveRange() {
        XCTAssertEqual(QuantumMIDIConstants.octaveRange, 5)
    }

    func testMicrotonalResolution() {
        XCTAssertEqual(QuantumMIDIConstants.microtonalResolution, 4096)
    }

    func testPhi() {
        XCTAssertEqual(QuantumMIDIConstants.phi, 1.618033988749895, accuracy: 0.0001)
    }

    func testGoldenAngle() {
        XCTAssertEqual(QuantumMIDIConstants.goldenAngle, 137.5077640500378, accuracy: 0.001)
    }

    func testSchumannHz() {
        XCTAssertEqual(QuantumMIDIConstants.schumannHz.count, 5)
        XCTAssertEqual(QuantumMIDIConstants.schumannHz[0], 7.83, accuracy: 0.01)
    }

    func testUpdateHz() {
        XCTAssertEqual(QuantumMIDIConstants.updateHz, 120.0)
    }

    func testNoteOnThreshold() {
        XCTAssertEqual(QuantumMIDIConstants.noteOnThreshold, 0.1)
    }

    func testNoteOffThreshold() {
        XCTAssertEqual(QuantumMIDIConstants.noteOffThreshold, 0.05)
    }

    func testNoteOnGreaterThanNoteOff() {
        XCTAssertGreaterThan(QuantumMIDIConstants.noteOnThreshold, QuantumMIDIConstants.noteOffThreshold)
    }
}

// MARK: - QuantumMIDIVoice Tests

final class QuantumMIDIVoiceTests: XCTestCase {

    func testDefaultInit() {
        let voice = QuantumMIDIVoice()
        XCTAssertEqual(voice.midiNote, 60)
        XCTAssertEqual(voice.velocity, 0.75)
        XCTAssertEqual(voice.pitchBend, 0)
        XCTAssertEqual(voice.pressure, 0)
        XCTAssertEqual(voice.timbre, 0.5)
        XCTAssertEqual(voice.brightness, 0.5)
        XCTAssertEqual(voice.channel, 0)
        XCTAssertFalse(voice.isActive)
        XCTAssertEqual(voice.instrumentTarget, .piano)
    }

    func testCustomInit() {
        let voice = QuantumMIDIVoice(
            midiNote: 72,
            velocity: 0.9,
            pitchBend: 0.5,
            pressure: 0.3,
            timbre: 0.8,
            brightness: 0.7,
            channel: 5,
            isActive: true,
            instrumentTarget: .violins
        )
        XCTAssertEqual(voice.midiNote, 72)
        XCTAssertEqual(voice.velocity, 0.9)
        XCTAssertEqual(voice.pitchBend, 0.5)
        XCTAssertEqual(voice.pressure, 0.3)
        XCTAssertEqual(voice.timbre, 0.8)
        XCTAssertEqual(voice.brightness, 0.7)
        XCTAssertEqual(voice.channel, 5)
        XCTAssertTrue(voice.isActive)
        XCTAssertEqual(voice.instrumentTarget, .violins)
    }

    func testIdentifiable() {
        let voice = QuantumMIDIVoice()
        XCTAssertNotNil(voice.id)
    }

    func testUniqueIds() {
        let v1 = QuantumMIDIVoice()
        let v2 = QuantumMIDIVoice()
        XCTAssertNotEqual(v1.id, v2.id)
    }
}

// MARK: - QuantumVoiceState Tests

final class QuantumVoiceStateTests: XCTestCase {

    func testDefaultInit() {
        let state = QuantumMIDIVoice.QuantumVoiceState()
        XCTAssertEqual(state.coherence, 0.5)
        XCTAssertEqual(state.phase, 0)
        XCTAssertNil(state.entangledVoiceId)
        XCTAssertEqual(state.superposition, 0)
        XCTAssertFalse(state.waveformCollapse)
    }

    func testCustomInit() {
        let id = UUID()
        let state = QuantumMIDIVoice.QuantumVoiceState(
            coherence: 0.9,
            phase: 1.5,
            entangledVoiceId: id,
            superposition: 0.7,
            waveformCollapse: true
        )
        XCTAssertEqual(state.coherence, 0.9)
        XCTAssertEqual(state.phase, 1.5)
        XCTAssertEqual(state.entangledVoiceId, id)
        XCTAssertEqual(state.superposition, 0.7)
        XCTAssertTrue(state.waveformCollapse)
    }
}

// MARK: - InstrumentTarget Tests

final class InstrumentTargetTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.allCases.count, 48)
    }

    func testOrchestralsExist() {
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.violins)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.violas)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.cellos)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.basses)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.trumpets)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.piano)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.harp)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.timpani)
    }

    func testSynthesizersExist() {
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.subtractive)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.fm)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.wavetable)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.granular)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.bioReactive)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.tr808)
    }

    func testGlobalInstrumentsExist() {
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.sitar)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.erhu)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.koto)
        XCTAssertNotNil(QuantumMIDIVoice.InstrumentTarget.didgeridoo)
    }

    func testRawValues() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.piano.rawValue, "Piano")
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.violins.rawValue, "Violins")
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.tr808.rawValue, "EchoelBeat")
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.bioReactive.rawValue, "Bio-Reactive Synth")
    }

    func testMidiChannelRange() {
        for instrument in QuantumMIDIVoice.InstrumentTarget.allCases {
            XCTAssertLessThanOrEqual(instrument.midiChannel, 15, "\(instrument.rawValue) channel out of range")
        }
    }

    func testMidiChannelAssignments() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.violins.midiChannel, 0)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.cellos.midiChannel, 1)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.trumpets.midiChannel, 2)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.piano.midiChannel, 5)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.tr808.midiChannel, 11)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.quantumField.midiChannel, 15)
    }

    func testNoteRangeValid() {
        for instrument in QuantumMIDIVoice.InstrumentTarget.allCases {
            let range = instrument.noteRange
            XCTAssertLessThanOrEqual(range.lowerBound, range.upperBound, "\(instrument.rawValue) has invalid range")
            XCTAssertLessThanOrEqual(range.upperBound, 127, "\(instrument.rawValue) exceeds MIDI range")
        }
    }

    func testPianoFullRange() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.piano.noteRange, 21...108)
    }

    func testSynthFullRange() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.subtractive.noteRange, 0...127)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.bioReactive.noteRange, 0...127)
    }

    func testDrumMapRange() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.tr808.noteRange, 36...51)
    }
}

// MARK: - QuantumMIDIRouting Tests

final class QuantumMIDIRoutingTests: XCTestCase {

    func testDefaultInit() {
        let routing = QuantumMIDIRouting()
        XCTAssertEqual(routing.enabledInstruments.count, QuantumMIDIVoice.InstrumentTarget.allCases.count)
        XCTAssertTrue(routing.orchestralEnabled)
        XCTAssertTrue(routing.synthesizersEnabled)
        XCTAssertTrue(routing.globalInstrumentsEnabled)
        XCTAssertTrue(routing.touchInstrumentsEnabled)
        XCTAssertTrue(routing.quantumInstrumentsEnabled)
        XCTAssertTrue(routing.mpeEnabled)
        XCTAssertTrue(routing.midi2Enabled)
    }

    func testEnableAll() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        XCTAssertEqual(routing.enabledInstruments.count, 0)

        routing.enableAll()
        XCTAssertEqual(routing.enabledInstruments.count, QuantumMIDIVoice.InstrumentTarget.allCases.count)
    }

    func testEnableOrchestral() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()

        routing.enableOrchestral()
        XCTAssertTrue(routing.enabledInstruments.contains(.violins))
        XCTAssertTrue(routing.enabledInstruments.contains(.piano))
        XCTAssertTrue(routing.enabledInstruments.contains(.timpani))
        XCTAssertTrue(routing.enabledInstruments.contains(.harp))
        XCTAssertEqual(routing.enabledInstruments.count, 20)
    }

    func testEnableSynthesizers() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()

        routing.enableSynthesizers()
        XCTAssertTrue(routing.enabledInstruments.contains(.subtractive))
        XCTAssertTrue(routing.enabledInstruments.contains(.fm))
        XCTAssertTrue(routing.enabledInstruments.contains(.bioReactive))
        XCTAssertTrue(routing.enabledInstruments.contains(.tr808))
        XCTAssertEqual(routing.enabledInstruments.count, 11)
    }
}

// MARK: - QuantumIntelligenceMode Tests

final class QuantumIntelligenceModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(QuantumIntelligenceMode.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(QuantumIntelligenceMode.classical.rawValue, "Classical")
        XCTAssertEqual(QuantumIntelligenceMode.quantumInspired.rawValue, "Quantum Inspired")
        XCTAssertEqual(QuantumIntelligenceMode.superIntelligent.rawValue, "Super Intelligent")
        XCTAssertEqual(QuantumIntelligenceMode.bioCoherent.rawValue, "Bio-Coherent")
        XCTAssertEqual(QuantumIntelligenceMode.fibonacciHarmonic.rawValue, "Fibonacci Harmonic")
        XCTAssertEqual(QuantumIntelligenceMode.sacredGeometry.rawValue, "Sacred Geometry")
        XCTAssertEqual(QuantumIntelligenceMode.lambdaTranscendent.rawValue, "λ∞ Transcendent")
    }

    func testIdentifiable() {
        for mode in QuantumIntelligenceMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testVoiceAllocationStrategies() {
        XCTAssertEqual(QuantumIntelligenceMode.classical.voiceAllocationStrategy, .roundRobin)
        XCTAssertEqual(QuantumIntelligenceMode.quantumInspired.voiceAllocationStrategy, .probabilistic)
        XCTAssertEqual(QuantumIntelligenceMode.superIntelligent.voiceAllocationStrategy, .adaptive)
        XCTAssertEqual(QuantumIntelligenceMode.bioCoherent.voiceAllocationStrategy, .coherenceWeighted)
        XCTAssertEqual(QuantumIntelligenceMode.fibonacciHarmonic.voiceAllocationStrategy, .fibonacciSpiral)
        XCTAssertEqual(QuantumIntelligenceMode.sacredGeometry.voiceAllocationStrategy, .goldenRatio)
        XCTAssertEqual(QuantumIntelligenceMode.lambdaTranscendent.voiceAllocationStrategy, .quantum)
    }

    func testEachModeHasUniqueStrategy() {
        var strategies: Set<String> = []
        for mode in QuantumIntelligenceMode.allCases {
            let strategyString = String(describing: mode.voiceAllocationStrategy)
            strategies.insert(strategyString)
        }
        XCTAssertEqual(strategies.count, 7)
    }
}

// MARK: - QuantumBioInput Tests

final class QuantumBioInputTests: XCTestCase {

    func testDefaultInit() {
        let bio = QuantumBioInput()
        XCTAssertEqual(bio.heartRate, 70.0)
        XCTAssertEqual(bio.hrvMs, 50.0)
        XCTAssertEqual(bio.coherence, 0.5)
        XCTAssertEqual(bio.breathingRate, 12.0)
        XCTAssertEqual(bio.breathPhase, 0.0)
        XCTAssertEqual(bio.lambdaState, .aware)
        XCTAssertEqual(bio.quantumPhase, 0.0)
        XCTAssertEqual(bio.entanglementStrength, 0.3)
    }

    func testQuantumVelocity() {
        var bio = QuantumBioInput()
        bio.coherence = 0.5
        bio.breathPhase = 0.0
        let vel = bio.quantumVelocity
        XCTAssertGreaterThan(vel, 0)
        XCTAssertLessThanOrEqual(vel, 1.0)
    }

    func testQuantumVelocityClampedTo01() {
        var bio = QuantumBioInput()
        bio.coherence = 1.0
        bio.breathPhase = 0.5
        XCTAssertLessThanOrEqual(bio.quantumVelocity, 1.0)
        XCTAssertGreaterThanOrEqual(bio.quantumVelocity, 0.0)
    }

    func testHrvExpression() {
        var bio = QuantumBioInput()
        bio.hrvMs = 50.0
        XCTAssertEqual(bio.hrvExpression, 0.5, accuracy: 0.01)

        bio.hrvMs = 100.0
        XCTAssertEqual(bio.hrvExpression, 1.0, accuracy: 0.01)

        bio.hrvMs = 0.0
        XCTAssertEqual(bio.hrvExpression, 0.0, accuracy: 0.01)
    }

    func testHrvExpressionClamped() {
        var bio = QuantumBioInput()
        bio.hrvMs = 200.0
        XCTAssertLessThanOrEqual(bio.hrvExpression, 1.0)
    }

    func testPhaseModulation() {
        var bio = QuantumBioInput()
        bio.quantumPhase = 0.0
        let mod = bio.phaseModulation
        XCTAssertEqual(mod, 0.5, accuracy: 0.01)
    }

    func testPhaseModulationRange() {
        var bio = QuantumBioInput()
        for phase in stride(from: Float(0), to: Float.pi * 2, by: 0.1) {
            bio.quantumPhase = phase
            XCTAssertGreaterThanOrEqual(bio.phaseModulation, 0.0)
            XCTAssertLessThanOrEqual(bio.phaseModulation, 1.0)
        }
    }
}

// MARK: - LambdaState Tests

final class LambdaStateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(QuantumBioInput.LambdaState.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(QuantumBioInput.LambdaState.dormant.rawValue, 0)
        XCTAssertEqual(QuantumBioInput.LambdaState.awakening.rawValue, 1)
        XCTAssertEqual(QuantumBioInput.LambdaState.aware.rawValue, 2)
        XCTAssertEqual(QuantumBioInput.LambdaState.flowing.rawValue, 3)
        XCTAssertEqual(QuantumBioInput.LambdaState.coherent.rawValue, 4)
        XCTAssertEqual(QuantumBioInput.LambdaState.transcendent.rawValue, 5)
        XCTAssertEqual(QuantumBioInput.LambdaState.unified.rawValue, 6)
        XCTAssertEqual(QuantumBioInput.LambdaState.lambdaInfinity.rawValue, 7)
    }

    func testExpressionMultiplierIncreases() {
        let states = QuantumBioInput.LambdaState.allCases.sorted { $0.rawValue < $1.rawValue }
        for i in 1..<states.count {
            XCTAssertGreaterThan(
                states[i].expressionMultiplier,
                states[i - 1].expressionMultiplier,
                "\(states[i]) should have higher multiplier than \(states[i - 1])"
            )
        }
    }

    func testExpressionMultiplierRange() {
        for state in QuantumBioInput.LambdaState.allCases {
            XCTAssertGreaterThan(state.expressionMultiplier, 0.0)
            XCTAssertLessThanOrEqual(state.expressionMultiplier, 1.0)
        }
    }

    func testExpressionMultiplierValues() {
        XCTAssertEqual(QuantumBioInput.LambdaState.dormant.expressionMultiplier, 1.0 / 8.0, accuracy: 0.001)
        XCTAssertEqual(QuantumBioInput.LambdaState.lambdaInfinity.expressionMultiplier, 1.0, accuracy: 0.001)
    }

    func testHarmonyComplexity() {
        XCTAssertEqual(QuantumBioInput.LambdaState.dormant.harmonyComplexity, 2)
        XCTAssertEqual(QuantumBioInput.LambdaState.awakening.harmonyComplexity, 2)
        XCTAssertEqual(QuantumBioInput.LambdaState.aware.harmonyComplexity, 3)
        XCTAssertEqual(QuantumBioInput.LambdaState.flowing.harmonyComplexity, 3)
        XCTAssertEqual(QuantumBioInput.LambdaState.coherent.harmonyComplexity, 4)
        XCTAssertEqual(QuantumBioInput.LambdaState.transcendent.harmonyComplexity, 4)
        XCTAssertEqual(QuantumBioInput.LambdaState.unified.harmonyComplexity, 5)
        XCTAssertEqual(QuantumBioInput.LambdaState.lambdaInfinity.harmonyComplexity, 5)
    }

    func testHarmonyComplexityNonDecreasing() {
        let states = QuantumBioInput.LambdaState.allCases.sorted { $0.rawValue < $1.rawValue }
        for i in 1..<states.count {
            XCTAssertGreaterThanOrEqual(
                states[i].harmonyComplexity,
                states[i - 1].harmonyComplexity
            )
        }
    }
}

// MARK: - QuantumChordType Tests

final class QuantumChordTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(QuantumChordType.allCases.count, 13)
    }

    func testRawValues() {
        XCTAssertEqual(QuantumChordType.majorTriad.rawValue, "Major")
        XCTAssertEqual(QuantumChordType.minorTriad.rawValue, "Minor")
        XCTAssertEqual(QuantumChordType.diminished.rawValue, "Diminished")
        XCTAssertEqual(QuantumChordType.augmented.rawValue, "Augmented")
        XCTAssertEqual(QuantumChordType.major7.rawValue, "Major 7")
        XCTAssertEqual(QuantumChordType.minor7.rawValue, "Minor 7")
        XCTAssertEqual(QuantumChordType.dominant7.rawValue, "Dominant 7")
        XCTAssertEqual(QuantumChordType.halfDiminished.rawValue, "Half-Diminished")
        XCTAssertEqual(QuantumChordType.fibonacci.rawValue, "Fibonacci")
        XCTAssertEqual(QuantumChordType.goldenRatio.rawValue, "Golden Ratio")
        XCTAssertEqual(QuantumChordType.quantumSuperposition.rawValue, "Quantum Superposition")
        XCTAssertEqual(QuantumChordType.sacredGeometry.rawValue, "Sacred Geometry")
        XCTAssertEqual(QuantumChordType.schumannResonance.rawValue, "Schumann Resonance")
    }

    func testIdentifiable() {
        for chord in QuantumChordType.allCases {
            XCTAssertEqual(chord.id, chord.rawValue)
        }
    }

    func testTriadIntervals() {
        let major = QuantumChordType.majorTriad.intervals(for: .classical)
        XCTAssertEqual(major, [0, 4, 7])

        let minor = QuantumChordType.minorTriad.intervals(for: .classical)
        XCTAssertEqual(minor, [0, 3, 7])

        let dim = QuantumChordType.diminished.intervals(for: .classical)
        XCTAssertEqual(dim, [0, 3, 6])

        let aug = QuantumChordType.augmented.intervals(for: .classical)
        XCTAssertEqual(aug, [0, 4, 8])
    }

    func testSeventhChordIntervals() {
        let maj7 = QuantumChordType.major7.intervals(for: .classical)
        XCTAssertEqual(maj7, [0, 4, 7, 11])

        let min7 = QuantumChordType.minor7.intervals(for: .classical)
        XCTAssertEqual(min7, [0, 3, 7, 10])

        let dom7 = QuantumChordType.dominant7.intervals(for: .classical)
        XCTAssertEqual(dom7, [0, 4, 7, 10])

        let halfDim = QuantumChordType.halfDiminished.intervals(for: .classical)
        XCTAssertEqual(halfDim, [0, 3, 6, 10])
    }

    func testIntervalsStartWithZero() {
        for chord in QuantumChordType.allCases {
            let intervals = chord.intervals(for: .classical)
            XCTAssertEqual(intervals.first, 0, "\(chord.rawValue) should start with root")
        }
    }

    func testIntervalsNotEmpty() {
        for chord in QuantumChordType.allCases {
            for mode in QuantumIntelligenceMode.allCases {
                let intervals = chord.intervals(for: mode)
                XCTAssertFalse(intervals.isEmpty, "\(chord.rawValue) with \(mode.rawValue) should have intervals")
            }
        }
    }

    func testQuantumSuperpositionModeDependent() {
        let classical = QuantumChordType.quantumSuperposition.intervals(for: .classical)
        let transcendent = QuantumChordType.quantumSuperposition.intervals(for: .lambdaTranscendent)
        XCTAssertEqual(classical.count, 3)
        XCTAssertEqual(transcendent.count, 7)
    }
}

// MARK: - VoiceQuantumConstants Tests

final class VoiceQuantumConstantsTests: XCTestCase {

    func testMinFrequency() {
        XCTAssertEqual(VoiceQuantumConstants.minFrequency, 60.0)
    }

    func testMaxFrequency() {
        XCTAssertEqual(VoiceQuantumConstants.maxFrequency, 2000.0)
    }

    func testMinLessThanMax() {
        XCTAssertLessThan(VoiceQuantumConstants.minFrequency, VoiceQuantumConstants.maxFrequency)
    }

    func testSilenceThreshold() {
        XCTAssertEqual(VoiceQuantumConstants.silenceThreshold, 0.01)
    }

    func testPitchSmoothingFactor() {
        XCTAssertEqual(VoiceQuantumConstants.pitchSmoothingFactor, 0.7)
        XCTAssertGreaterThan(VoiceQuantumConstants.pitchSmoothingFactor, 0.0)
        XCTAssertLessThan(VoiceQuantumConstants.pitchSmoothingFactor, 1.0)
    }

    func testMidiNoteA4() {
        XCTAssertEqual(VoiceQuantumConstants.midiNoteA4, 69)
    }

    func testFrequencyA4() {
        XCTAssertEqual(VoiceQuantumConstants.frequencyA4, 440.0)
    }

    func testHarmonizerIntervals() {
        XCTAssertEqual(VoiceQuantumConstants.majorTriad, [0, 4, 7])
        XCTAssertEqual(VoiceQuantumConstants.minorTriad, [0, 3, 7])
        XCTAssertEqual(VoiceQuantumConstants.powerChord, [0, 7, 12])
        XCTAssertEqual(VoiceQuantumConstants.fifthsStack, [0, 7, 14, 21])
        XCTAssertEqual(VoiceQuantumConstants.octaves, [-12, 0, 12, 24])
    }
}

// MARK: - VoiceInputMode Tests

final class VoiceInputModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(VoiceInputMode.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(VoiceInputMode.direct.rawValue, "Direct")
        XCTAssertEqual(VoiceInputMode.harmonizer.rawValue, "Harmonizer")
        XCTAssertEqual(VoiceInputMode.quantumChoir.rawValue, "Quantum Choir")
        XCTAssertEqual(VoiceInputMode.bioReactive.rawValue, "Bio-Reactive")
        XCTAssertEqual(VoiceInputMode.entangled.rawValue, "Entangled Duet")
        XCTAssertEqual(VoiceInputMode.vocoder.rawValue, "Quantum Vocoder")
        XCTAssertEqual(VoiceInputMode.formantShift.rawValue, "Formant Shifter")
        XCTAssertEqual(VoiceInputMode.pitchCorrect.rawValue, "Pitch Correct")
    }

    func testIdentifiable() {
        for mode in VoiceInputMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testDescriptionNotEmpty() {
        for mode in VoiceInputMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode.rawValue) description should not be empty")
        }
    }
}

// MARK: - HarmonyMode Tests

final class HarmonyModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(HarmonyMode.allCases.count, 9)
    }

    func testRawValues() {
        XCTAssertEqual(HarmonyMode.major.rawValue, "Dur")
        XCTAssertEqual(HarmonyMode.minor.rawValue, "Moll")
        XCTAssertEqual(HarmonyMode.power.rawValue, "Power Chord")
        XCTAssertEqual(HarmonyMode.fifths.rawValue, "Quinten-Stapel")
        XCTAssertEqual(HarmonyMode.octaves.rawValue, "Oktaven")
        XCTAssertEqual(HarmonyMode.quantum.rawValue, "Quantum Superposition")
        XCTAssertEqual(HarmonyMode.fibonacci.rawValue, "Fibonacci Harmonie")
        XCTAssertEqual(HarmonyMode.sacredGeometry.rawValue, "Sacred Geometry")
        XCTAssertEqual(HarmonyMode.bioCoherent.rawValue, "Bio-Coherent")
    }

    func testIdentifiable() {
        for mode in HarmonyMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testIntervalsNotEmpty() {
        for mode in HarmonyMode.allCases {
            XCTAssertFalse(mode.intervals.isEmpty, "\(mode.rawValue) should have intervals")
        }
    }

    func testIntervalsStartWithRoot() {
        for mode in HarmonyMode.allCases {
            let intervals = mode.intervals
            XCTAssertTrue(intervals.contains(0), "\(mode.rawValue) should contain root (0)")
        }
    }

    func testMajorIntervals() {
        XCTAssertEqual(HarmonyMode.major.intervals, [0, 4, 7])
    }

    func testMinorIntervals() {
        XCTAssertEqual(HarmonyMode.minor.intervals, [0, 3, 7])
    }

    func testPowerIntervals() {
        XCTAssertEqual(HarmonyMode.power.intervals, [0, 7, 12])
    }

    func testOctavesIntervals() {
        XCTAssertEqual(HarmonyMode.octaves.intervals, [-12, 0, 12, 24])
    }
}

// MARK: - VoiceAnalysisData Tests

final class VoiceAnalysisDataTests: XCTestCase {

    func testDefaultInit() {
        let data = VoiceAnalysisData()
        XCTAssertEqual(data.frequency, 0)
        XCTAssertEqual(data.midiNote, 60)
        XCTAssertEqual(data.midiNoteFraction, 0)
        XCTAssertEqual(data.amplitude, 0)
        XCTAssertFalse(data.isVoiced)
        XCTAssertEqual(data.confidence, 0)
        XCTAssertTrue(data.formantFrequencies.isEmpty)
        XCTAssertEqual(data.brightness, 0.5)
        XCTAssertEqual(data.breathiness, 0)
    }

    func testFrequencyToMIDI_A4() {
        let result = VoiceAnalysisData.frequencyToMIDI(440.0)
        XCTAssertEqual(result.note, 69)
        XCTAssertEqual(result.cents, 0, accuracy: 1.0)
    }

    func testFrequencyToMIDI_MiddleC() {
        let result = VoiceAnalysisData.frequencyToMIDI(261.63)
        XCTAssertEqual(result.note, 60)
        XCTAssertEqual(result.cents, 0, accuracy: 5.0)
    }

    func testFrequencyToMIDI_Zero() {
        let result = VoiceAnalysisData.frequencyToMIDI(0)
        XCTAssertEqual(result.note, 0)
        XCTAssertEqual(result.cents, 0)
    }

    func testFrequencyToMIDI_Negative() {
        let result = VoiceAnalysisData.frequencyToMIDI(-100)
        XCTAssertEqual(result.note, 0)
        XCTAssertEqual(result.cents, 0)
    }

    func testFrequencyToMIDI_HighFrequency() {
        let result = VoiceAnalysisData.frequencyToMIDI(4186.01) // C8
        XCTAssertEqual(result.note, 108)
        XCTAssertEqual(result.cents, 0, accuracy: 5.0)
    }
}

// MARK: - VoiceQuantumError Tests

final class VoiceQuantumErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(VoiceQuantumError.audioEngineSetupFailed.errorDescription, "Audio engine setup failed")
        XCTAssertEqual(VoiceQuantumError.invalidAudioFormat.errorDescription, "Invalid audio format")
        XCTAssertEqual(VoiceQuantumError.microphonePermissionDenied.errorDescription, "Microphone permission denied")
    }

    func testErrorConformsToError() {
        let error: Error = VoiceQuantumError.audioEngineSetupFailed
        XCTAssertNotNil(error)
    }

    func testLocalizedErrorConformance() {
        let error: LocalizedError = VoiceQuantumError.invalidAudioFormat
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - TouchMusicalScale Tests

final class TouchMusicalScaleTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TouchMusicalScale.allCases.count, 14)
    }

    func testRawValues() {
        XCTAssertEqual(TouchMusicalScale.major.rawValue, "Major")
        XCTAssertEqual(TouchMusicalScale.minor.rawValue, "Minor")
        XCTAssertEqual(TouchMusicalScale.harmonicMinor.rawValue, "Harmonic Minor")
        XCTAssertEqual(TouchMusicalScale.melodicMinor.rawValue, "Melodic Minor")
        XCTAssertEqual(TouchMusicalScale.dorian.rawValue, "Dorian")
        XCTAssertEqual(TouchMusicalScale.phrygian.rawValue, "Phrygian")
        XCTAssertEqual(TouchMusicalScale.lydian.rawValue, "Lydian")
        XCTAssertEqual(TouchMusicalScale.mixolydian.rawValue, "Mixolydian")
        XCTAssertEqual(TouchMusicalScale.locrian.rawValue, "Locrian")
        XCTAssertEqual(TouchMusicalScale.pentatonicMajor.rawValue, "Pentatonic Major")
        XCTAssertEqual(TouchMusicalScale.pentatonicMinor.rawValue, "Pentatonic Minor")
        XCTAssertEqual(TouchMusicalScale.blues.rawValue, "Blues")
        XCTAssertEqual(TouchMusicalScale.chromatic.rawValue, "Chromatic")
        XCTAssertEqual(TouchMusicalScale.wholeNote.rawValue, "Whole Tone")
    }

    func testIntervalsNotEmpty() {
        for scale in TouchMusicalScale.allCases {
            XCTAssertFalse(scale.intervals.isEmpty, "\(scale.rawValue) should have intervals")
        }
    }

    func testIntervalsStartWithZero() {
        for scale in TouchMusicalScale.allCases {
            XCTAssertEqual(scale.intervals.first, 0, "\(scale.rawValue) should start at root")
        }
    }

    func testIntervalsBoundedByOctave() {
        for scale in TouchMusicalScale.allCases {
            for interval in scale.intervals {
                XCTAssertGreaterThanOrEqual(interval, 0, "\(scale.rawValue) interval out of range")
                XCTAssertLessThanOrEqual(interval, 11, "\(scale.rawValue) interval exceeds octave")
            }
        }
    }

    func testMajorScaleIntervals() {
        XCTAssertEqual(TouchMusicalScale.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testMinorScaleIntervals() {
        XCTAssertEqual(TouchMusicalScale.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testChromaticScaleHas12Notes() {
        XCTAssertEqual(TouchMusicalScale.chromatic.intervals.count, 12)
    }

    func testPentatonicScalesHave5Notes() {
        XCTAssertEqual(TouchMusicalScale.pentatonicMajor.intervals.count, 5)
        XCTAssertEqual(TouchMusicalScale.pentatonicMinor.intervals.count, 5)
    }

    func testBluesScaleHas6Notes() {
        XCTAssertEqual(TouchMusicalScale.blues.intervals.count, 6)
    }

    func testWholeNoteScaleHas6Notes() {
        XCTAssertEqual(TouchMusicalScale.wholeNote.intervals.count, 6)
    }

    func testNoteInScaleRootDegree() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 0, root: 60)
        XCTAssertEqual(note, 60)
    }

    func testNoteInScaleSecondDegree() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 1, root: 60)
        XCTAssertEqual(note, 62)
    }

    func testNoteInScaleOctaveWrap() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 7, root: 60) // One octave up
        XCTAssertEqual(note, 72)
    }

    func testNoteInScaleClampedTo127() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 50, root: 120)
        XCTAssertLessThanOrEqual(note, 127)
    }

    func testNoteInScaleClampedTo0() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 0, root: 0)
        XCTAssertGreaterThanOrEqual(note, 0)
    }
}

// MARK: - ChordType Tests (TouchInstruments)

final class TouchChordTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordType.allCases.count, 11)
    }

    func testRawValues() {
        XCTAssertEqual(ChordType.major.rawValue, "Major")
        XCTAssertEqual(ChordType.minor.rawValue, "Minor")
        XCTAssertEqual(ChordType.diminished.rawValue, "Dim")
        XCTAssertEqual(ChordType.augmented.rawValue, "Aug")
        XCTAssertEqual(ChordType.major7.rawValue, "Maj7")
        XCTAssertEqual(ChordType.minor7.rawValue, "Min7")
        XCTAssertEqual(ChordType.dominant7.rawValue, "7")
        XCTAssertEqual(ChordType.sus2.rawValue, "Sus2")
        XCTAssertEqual(ChordType.sus4.rawValue, "Sus4")
        XCTAssertEqual(ChordType.add9.rawValue, "Add9")
        XCTAssertEqual(ChordType.power.rawValue, "5")
    }

    func testIntervalsNotEmpty() {
        for chord in ChordType.allCases {
            XCTAssertFalse(chord.intervals.isEmpty, "\(chord.rawValue) should have intervals")
        }
    }

    func testIntervalsStartWithRoot() {
        for chord in ChordType.allCases {
            XCTAssertEqual(chord.intervals.first, 0, "\(chord.rawValue) should start with root")
        }
    }

    func testMajorChordIntervals() {
        XCTAssertEqual(ChordType.major.intervals, [0, 4, 7])
    }

    func testMinorChordIntervals() {
        XCTAssertEqual(ChordType.minor.intervals, [0, 3, 7])
    }

    func testPowerChordIntervals() {
        XCTAssertEqual(ChordType.power.intervals, [0, 7])
    }

    func testNotesFunction() {
        let notes = ChordType.major.notes(root: 60)
        XCTAssertEqual(notes, [60, 64, 67])
    }

    func testNotesFunctionMinor() {
        let notes = ChordType.minor.notes(root: 60)
        XCTAssertEqual(notes, [60, 63, 67])
    }

    func testNotesFunctionClampedHigh() {
        let notes = ChordType.major.notes(root: 125)
        for note in notes {
            XCTAssertLessThanOrEqual(note, 127)
        }
    }

    func testNotesFunctionClampedLow() {
        let notes = ChordType.major.notes(root: 0)
        for note in notes {
            XCTAssertGreaterThanOrEqual(note, 0)
        }
    }

    func testTriadHas3Notes() {
        XCTAssertEqual(ChordType.major.intervals.count, 3)
        XCTAssertEqual(ChordType.minor.intervals.count, 3)
        XCTAssertEqual(ChordType.diminished.intervals.count, 3)
        XCTAssertEqual(ChordType.augmented.intervals.count, 3)
    }

    func testSeventhHas4Notes() {
        XCTAssertEqual(ChordType.major7.intervals.count, 4)
        XCTAssertEqual(ChordType.minor7.intervals.count, 4)
        XCTAssertEqual(ChordType.dominant7.intervals.count, 4)
    }

    func testPowerHas2Notes() {
        XCTAssertEqual(ChordType.power.intervals.count, 2)
    }
}

// MARK: - ChordPad Tests

final class ChordPadTests: XCTestCase {

    func testInit() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.rootNote, 60)
        XCTAssertEqual(pad.chordType, .major)
        XCTAssertNotNil(pad.id)
    }

    func testChordNameC() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.chordName, "C")
    }

    func testChordNameD() {
        let pad = ChordPad(rootNote: 62, chordType: .minor, color: .red)
        XCTAssertEqual(pad.chordName, "D")
    }

    func testChordNameA() {
        let pad = ChordPad(rootNote: 69, chordType: .minor, color: .green)
        XCTAssertEqual(pad.chordName, "A")
    }

    func testNotes() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.notes, [60, 64, 67])
    }

    func testNotesMinor() {
        let pad = ChordPad(rootNote: 69, chordType: .minor, color: .blue)
        XCTAssertEqual(pad.notes, [69, 72, 76])
    }

    func testIdentifiable() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertNotNil(pad.id)
    }

    func testUniqueIds() {
        let pad1 = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        let pad2 = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertNotEqual(pad1.id, pad2.id)
    }
}

// MARK: - DrumPadModel Tests

final class DrumPadModelTests: XCTestCase {

    func testInit() {
        let pad = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        XCTAssertEqual(pad.name, "Kick")
        XCTAssertEqual(pad.midiNote, 36)
        XCTAssertNotNil(pad.id)
    }

    func testUniqueIds() {
        let pad1 = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        let pad2 = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        XCTAssertNotEqual(pad1.id, pad2.id)
    }
}

// MARK: - DrumKit Tests

final class DrumKitTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(DrumKit.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(DrumKit.acoustic.rawValue, "Acoustic")
        XCTAssertEqual(DrumKit.electronic.rawValue, "Electronic")
        XCTAssertEqual(DrumKit.tr808.rawValue, "808")
        XCTAssertEqual(DrumKit.tr909.rawValue, "909")
        XCTAssertEqual(DrumKit.hiphop.rawValue, "Hip Hop")
        XCTAssertEqual(DrumKit.percussion.rawValue, "Percussion")
    }

    func testAllKitsHave16Pads() {
        for kit in DrumKit.allCases {
            XCTAssertEqual(kit.pads.count, 16, "\(kit.rawValue) should have 16 pads")
        }
    }

    func testAcousticKitKick() {
        let pads = DrumKit.acoustic.pads
        XCTAssertEqual(pads[0].name, "Kick")
        XCTAssertEqual(pads[0].midiNote, 36)
    }

    func testTR808KitKick() {
        let pads = DrumKit.tr808.pads
        XCTAssertEqual(pads[0].name, "Kick")
        XCTAssertEqual(pads[0].midiNote, 36)
    }

    func testAllKitPadsHaveNames() {
        for kit in DrumKit.allCases {
            for pad in kit.pads {
                XCTAssertFalse(pad.name.isEmpty, "\(kit.rawValue) pad should have a name")
            }
        }
    }

    func testAllKitPadsHaveValidMIDINotes() {
        for kit in DrumKit.allCases {
            for pad in kit.pads {
                XCTAssertLessThanOrEqual(pad.midiNote, 127, "\(kit.rawValue) \(pad.name) exceeds MIDI range")
            }
        }
    }
}

// MARK: - MIDINote (PianoRoll) Tests

final class PianoRollMIDINoteTests: XCTestCase {

    func testDefaultInit() {
        let note = MIDINote(pitch: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        XCTAssertEqual(note.pitch, 60)
        XCTAssertEqual(note.velocity, 100)
        XCTAssertEqual(note.startBeat, 0.0)
        XCTAssertEqual(note.duration, 1.0)
        XCTAssertEqual(note.pitchBend, 0.0)
        XCTAssertEqual(note.pressure, 0.0)
        XCTAssertEqual(note.brightness, 0.5)
        XCTAssertEqual(note.timbre, 0.5)
        XCTAssertNil(note.mpeVoiceID)
    }

    func testIdentifiable() {
        let note = MIDINote(pitch: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        XCTAssertNotNil(note.id)
    }

    func testUniqueIds() {
        let n1 = MIDINote(pitch: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        let n2 = MIDINote(pitch: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        XCTAssertNotEqual(n1.id, n2.id)
    }

    func testVelocity32bit() {
        let note = MIDINote(pitch: 60, velocity: 127, startBeat: 0.0, duration: 1.0)
        XCTAssertEqual(note.velocity32bit, 1.0, accuracy: 0.01)
    }

    func testVelocity32bitZero() {
        let note = MIDINote(pitch: 60, velocity: 0, startBeat: 0.0, duration: 1.0)
        XCTAssertEqual(note.velocity32bit, 0.0)
    }

    func testVelocity32bitMidpoint() {
        let note = MIDINote(pitch: 60, velocity: 64, startBeat: 0.0, duration: 1.0)
        XCTAssertEqual(note.velocity32bit, 64.0 / 127.0, accuracy: 0.01)
    }

    func testAutomationPointsInitiallyEmpty() {
        let note = MIDINote(pitch: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        XCTAssertTrue(note.pitchBendAutomation.isEmpty)
        XCTAssertTrue(note.pressureAutomation.isEmpty)
        XCTAssertTrue(note.brightnessAutomation.isEmpty)
    }

    func testAutomationPoint() {
        let point = MIDINote.AutomationPoint(beat: 1.0, value: 0.75)
        XCTAssertEqual(point.beat, 1.0)
        XCTAssertEqual(point.value, 0.75)
        XCTAssertNotNil(point.id)
    }
}

// MARK: - PerNoteExpression (PianoRoll) Tests

final class PianoRollPerNoteExpressionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PerNoteExpression.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(PerNoteExpression.pitchBend.rawValue, "Pitch Bend")
        XCTAssertEqual(PerNoteExpression.pressure.rawValue, "Pressure")
        XCTAssertEqual(PerNoteExpression.brightness.rawValue, "Brightness (Y)")
        XCTAssertEqual(PerNoteExpression.timbre.rawValue, "Timbre")
    }

    func testIcons() {
        XCTAssertEqual(PerNoteExpression.pitchBend.icon, "arrow.up.arrow.down")
        XCTAssertEqual(PerNoteExpression.pressure.icon, "hand.point.down.fill")
        XCTAssertEqual(PerNoteExpression.brightness.icon, "sun.max.fill")
        XCTAssertEqual(PerNoteExpression.timbre.icon, "waveform")
    }

    func testIconsNotEmpty() {
        for expr in PerNoteExpression.allCases {
            XCTAssertFalse(expr.icon.isEmpty)
        }
    }

    func testPitchBendRange() {
        XCTAssertEqual(PerNoteExpression.pitchBend.range, -1.0...1.0)
    }

    func testPressureRange() {
        XCTAssertEqual(PerNoteExpression.pressure.range, 0.0...1.0)
    }

    func testBrightnessRange() {
        XCTAssertEqual(PerNoteExpression.brightness.range, 0.0...1.0)
    }

    func testTimbreRange() {
        XCTAssertEqual(PerNoteExpression.timbre.range, 0.0...1.0)
    }

    func testPitchBendRangeIsBipolar() {
        let range = PerNoteExpression.pitchBend.range
        XCTAssertLessThan(range.lowerBound, 0)
        XCTAssertGreaterThan(range.upperBound, 0)
    }

    func testUnipolarRangesStartAtZero() {
        XCTAssertEqual(PerNoteExpression.pressure.range.lowerBound, 0.0)
        XCTAssertEqual(PerNoteExpression.brightness.range.lowerBound, 0.0)
        XCTAssertEqual(PerNoteExpression.timbre.range.lowerBound, 0.0)
    }
}

// MARK: - PianoRollViewModel.EditMode Tests

final class PianoRollEditModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PianoRollViewModel.EditMode.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(PianoRollViewModel.EditMode.select.rawValue, "Select")
        XCTAssertEqual(PianoRollViewModel.EditMode.draw.rawValue, "Draw")
        XCTAssertEqual(PianoRollViewModel.EditMode.erase.rawValue, "Erase")
        XCTAssertEqual(PianoRollViewModel.EditMode.velocity.rawValue, "Velocity")
    }

    func testIcons() {
        XCTAssertEqual(PianoRollViewModel.EditMode.select.icon, "arrow.up.left.and.arrow.down.right")
        XCTAssertEqual(PianoRollViewModel.EditMode.draw.icon, "pencil")
        XCTAssertEqual(PianoRollViewModel.EditMode.erase.icon, "eraser")
        XCTAssertEqual(PianoRollViewModel.EditMode.velocity.icon, "waveform")
    }

    func testIconsNotEmpty() {
        for mode in PianoRollViewModel.EditMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }
}

// MARK: - PianoRollViewModel.Quantize Tests

final class PianoRollQuantizeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PianoRollViewModel.Quantize.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(PianoRollViewModel.Quantize.none.rawValue, "Off")
        XCTAssertEqual(PianoRollViewModel.Quantize.whole.rawValue, "1")
        XCTAssertEqual(PianoRollViewModel.Quantize.half.rawValue, "1/2")
        XCTAssertEqual(PianoRollViewModel.Quantize.quarter.rawValue, "1/4")
        XCTAssertEqual(PianoRollViewModel.Quantize.eighth.rawValue, "1/8")
        XCTAssertEqual(PianoRollViewModel.Quantize.sixteenth.rawValue, "1/16")
        XCTAssertEqual(PianoRollViewModel.Quantize.thirtysecond.rawValue, "1/32")
    }

    func testBeatsValues() {
        XCTAssertEqual(PianoRollViewModel.Quantize.none.beats, 0)
        XCTAssertEqual(PianoRollViewModel.Quantize.whole.beats, 4)
        XCTAssertEqual(PianoRollViewModel.Quantize.half.beats, 2)
        XCTAssertEqual(PianoRollViewModel.Quantize.quarter.beats, 1)
        XCTAssertEqual(PianoRollViewModel.Quantize.eighth.beats, 0.5)
        XCTAssertEqual(PianoRollViewModel.Quantize.sixteenth.beats, 0.25)
        XCTAssertEqual(PianoRollViewModel.Quantize.thirtysecond.beats, 0.125)
    }

    func testBeatsHalveCorrectly() {
        XCTAssertEqual(PianoRollViewModel.Quantize.whole.beats / 2, PianoRollViewModel.Quantize.half.beats)
        XCTAssertEqual(PianoRollViewModel.Quantize.half.beats / 2, PianoRollViewModel.Quantize.quarter.beats)
        XCTAssertEqual(PianoRollViewModel.Quantize.quarter.beats / 2, PianoRollViewModel.Quantize.eighth.beats)
        XCTAssertEqual(PianoRollViewModel.Quantize.eighth.beats / 2, PianoRollViewModel.Quantize.sixteenth.beats)
        XCTAssertEqual(PianoRollViewModel.Quantize.sixteenth.beats / 2, PianoRollViewModel.Quantize.thirtysecond.beats)
    }
}

// MARK: - TouchInstrumentsHub.InstrumentType Tests

final class TouchInstrumentTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.chordPad.rawValue, "Chord Pad")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.drumPad.rawValue, "Drum Pad")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.melodyPad.rawValue, "Melody XY")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.keyboard.rawValue, "Keyboard")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.strumPad.rawValue, "Strum Pad")
    }
}

// MARK: - ChordPadViewModel.PlayMode Tests

final class ChordPadPlayModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordPadViewModel.PlayMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(ChordPadViewModel.PlayMode.simultaneous.rawValue, "Chord")
        XCTAssertEqual(ChordPadViewModel.PlayMode.strum.rawValue, "Strum")
        XCTAssertEqual(ChordPadViewModel.PlayMode.arpeggio.rawValue, "Arp")
    }
}

// MARK: - ChordPadViewModel.ArpPattern Tests

final class ChordPadArpPatternTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordPadViewModel.ArpPattern.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(ChordPadViewModel.ArpPattern.up.rawValue, "Up")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.down.rawValue, "Down")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.upDown.rawValue, "Up/Down")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.random.rawValue, "Random")
    }
}

// MARK: - DrumPadViewModel.VelocityCurve Tests

final class VelocityCurveTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.soft.rawValue, "Soft")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.linear.rawValue, "Linear")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.hard.rawValue, "Hard")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.fixed.rawValue, "Fixed")
    }

    func testLinearApply() {
        let curve = DrumPadViewModel.VelocityCurve.linear
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.01)
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.01)
    }

    func testSoftApply() {
        let curve = DrumPadViewModel.VelocityCurve.soft
        // sqrt(0.25) = 0.5 — soft curve should be higher than linear for mid values
        XCTAssertGreaterThan(curve.apply(0.25), 0.25)
    }

    func testHardApply() {
        let curve = DrumPadViewModel.VelocityCurve.hard
        // pow(0.5, 2.0) = 0.25 — hard curve should be lower than linear for mid values
        XCTAssertLessThan(curve.apply(0.5), 0.5)
    }

    func testFixedApply() {
        let curve = DrumPadViewModel.VelocityCurve.fixed
        XCTAssertEqual(curve.apply(0.1), 0.9)
        XCTAssertEqual(curve.apply(0.5), 0.9)
        XCTAssertEqual(curve.apply(1.0), 0.9)
    }

    func testAllCurvesReturnValidRange() {
        for curve in DrumPadViewModel.VelocityCurve.allCases {
            for input in stride(from: Float(0), through: Float(1.0), by: 0.1) {
                let result = curve.apply(input)
                XCTAssertGreaterThanOrEqual(result, 0.0, "\(curve.rawValue) returned negative for input \(input)")
                XCTAssertLessThanOrEqual(result, 1.0, "\(curve.rawValue) exceeded 1.0 for input \(input)")
            }
        }
    }
}
#endif

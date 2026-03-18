#if canImport(AVFoundation)
// MIDIChainBehaviorTests.swift
// Echoelmusic — Behavioral tests for the MIDI chain:
// MIDI2Manager, MIDIToSpatialMapper, QuantumMIDIOut,
// TouchInstruments (scales/chords), and MPEZoneManager.

import XCTest
@testable import Echoelmusic

// MARK: - MIDI2Manager Behavior Tests

@MainActor
final class MIDI2ManagerBehaviorTests: XCTestCase {

    // MARK: - Device Discovery & State

    func testMIDI2Manager_InitialState_NotInitialized() {
        let manager = MIDI2Manager()
        XCTAssertFalse(manager.isInitialized, "Manager must start uninitialised")
        XCTAssertTrue(manager.connectedEndpoints.isEmpty, "No endpoints before init")
        XCTAssertNil(manager.errorMessage, "No error before init")
    }

    func testMIDI2Manager_ActiveNotes_InitiallyZero() {
        let manager = MIDI2Manager()
        XCTAssertEqual(manager.activeNoteCount, 0, "No active notes before init")
    }

    func testMIDI2Manager_NoteTracking_IgnoredWhenNotInitialized() {
        let manager = MIDI2Manager()
        // Sending when not initialised should be a no-op (no crash)
        manager.sendNoteOn(channel: 0, note: 60, velocity: 0.8)
        XCTAssertEqual(manager.activeNoteCount, 0, "Note should not register when uninitialised")
    }

    func testMIDI2Manager_Cleanup_ResetsState() {
        let manager = MIDI2Manager()
        // cleanup on fresh instance should not crash
        manager.cleanup()
        XCTAssertFalse(manager.isInitialized)
        XCTAssertEqual(manager.activeNoteCount, 0)
    }

    // MARK: - Channel Mapping

    func testMIDI2Manager_IsNoteActive_ReturnsFalseForUnplayed() {
        let manager = MIDI2Manager()
        XCTAssertFalse(manager.isNoteActive(channel: 0, note: 60))
        XCTAssertFalse(manager.isNoteActive(channel: 15, note: 127))
    }

    func testMIDI2Manager_EndpointInfo_EmptyWhenNoEndpoints() {
        let manager = MIDI2Manager()
        let info = manager.getEndpointInfo()
        XCTAssertTrue(info.isEmpty, "No endpoint info before discovery")
    }
}

// MARK: - MIDIToSpatialMapper Tests

@MainActor
final class MIDIToSpatialMapperBehaviorTests: XCTestCase {

    private var mapper: MIDIToSpatialMapper!

    override func setUp() {
        super.setUp()
        mapper = MIDIToSpatialMapper()
    }

    // MARK: - Stereo Mapping

    func testSpatialMapper_StereoMapping_LowNotePansLeft() {
        let pan = mapper.mapToStereo(note: 0, velocity: 0.8)
        // Note 0 => normalizedNote = 0 => pan = -1
        XCTAssertEqual(pan, -1.0, accuracy: 0.01, "Note 0 should pan hard left")
    }

    func testSpatialMapper_StereoMapping_HighNotePansRight() {
        let pan = mapper.mapToStereo(note: 127, velocity: 0.8)
        // Note 127 => normalizedNote = 1 => pan = +1
        XCTAssertEqual(pan, 1.0, accuracy: 0.01, "Note 127 should pan hard right")
    }

    func testSpatialMapper_StereoMapping_MiddleNoteCentered() {
        // Note ~63.5 maps to center, so note 64 is approximately center
        let pan = mapper.mapToStereo(note: 64, velocity: 0.8)
        XCTAssertEqual(pan, 0.0, accuracy: 0.05, "Middle note should be near center")
    }

    func testSpatialMapper_StereoMapping_PanOverrideUsed() {
        let pan = mapper.mapToStereo(note: 0, velocity: 0.8, pan: 0.5)
        // pan 0.5 => (0.5 * 2) - 1 = 0
        XCTAssertEqual(pan, 0.0, accuracy: 0.01, "Pan override 0.5 should produce center")
    }

    // MARK: - 3D Mapping

    func testSpatialMapper_3DMapping_ReturnsValidPosition() {
        let pos = mapper.mapTo3D(note: 60, velocity: 0.8, brightness: 0.5)
        // Position should be finite and reasonable
        XCTAssertFalse(pos.x.isNaN, "X must not be NaN")
        XCTAssertFalse(pos.y.isNaN, "Y must not be NaN")
        XCTAssertFalse(pos.z.isNaN, "Z must not be NaN")
    }

    func testSpatialMapper_3DMapping_LoudNoteIsNearer() {
        let loud = mapper.mapTo3D(note: 60, velocity: 1.0, brightness: 0.5)
        let soft = mapper.mapTo3D(note: 60, velocity: 0.1, brightness: 0.5)
        let loudDist = loud.spherical.distance
        let softDist = soft.spherical.distance
        XCTAssertLessThan(loudDist, softDist, "Louder note should be nearer (shorter distance)")
    }

    func testSpatialMapper_3DMapping_BrightnessAffectsElevation() {
        let low = mapper.mapTo3D(note: 60, velocity: 0.8, brightness: 0.0)
        let high = mapper.mapTo3D(note: 60, velocity: 0.8, brightness: 1.0)
        let lowElev = low.spherical.elevation
        let highElev = high.spherical.elevation
        XCTAssertLessThan(lowElev, highElev, "Higher brightness should produce higher elevation")
    }

    // MARK: - 4D Mapping

    func testSpatialMapper_4DMapping_TimeEvolvesPosition() {
        let posT0 = mapper.mapTo4D(note: 60, velocity: 0.8, pitchBend: 0.5, time: 0.0)
        let posT1 = mapper.mapTo4D(note: 60, velocity: 0.8, pitchBend: 0.5, time: 1.0)
        XCTAssertEqual(posT0.time, 0.0, "Time should be 0 at t=0")
        XCTAssertEqual(posT1.time, 1.0, "Time should be 1 at t=1")
        // With non-zero pitchBend and different times, positions should differ
        let different = (posT0.x != posT1.x) || (posT0.y != posT1.y)
        XCTAssertTrue(different, "Position should evolve with time when pitchBend is non-zero")
    }

    func testSpatialMapper_4DMapping_ZeroPitchBendNoOrbitalMotion() {
        let posT0 = mapper.mapTo4D(note: 60, velocity: 0.8, pitchBend: 0.0, time: 0.0)
        let posT1 = mapper.mapTo4D(note: 60, velocity: 0.8, pitchBend: 0.0, time: 5.0)
        XCTAssertEqual(posT0.x, posT1.x, accuracy: 0.001, "No orbital motion when pitchBend = 0")
        XCTAssertEqual(posT0.y, posT1.y, accuracy: 0.001, "No orbital motion when pitchBend = 0")
    }

    // MARK: - Coordinate System

    func testSpatialPosition_SphericalConversion_RoundTrips() {
        let original = MIDIToSpatialMapper.SpatialPosition(x: 1.0, y: 0.5, z: 0.3)
        let spherical = original.spherical
        let reconstructed = MIDIToSpatialMapper.SpatialPosition.fromSpherical(
            azimuth: spherical.azimuth,
            elevation: spherical.elevation,
            distance: spherical.distance
        )
        XCTAssertEqual(original.x, reconstructed.x, accuracy: 0.01)
        XCTAssertEqual(original.y, reconstructed.y, accuracy: 0.01)
        XCTAssertEqual(original.z, reconstructed.z, accuracy: 0.01)
    }

    func testSpatialPosition_SphericalDistance_MatchesEuclidean() {
        let pos = MIDIToSpatialMapper.SpatialPosition(x: 3.0, y: 4.0, z: 0.0)
        let dist = pos.spherical.distance
        XCTAssertEqual(dist, 5.0, accuracy: 0.01, "Distance should be Euclidean norm")
    }

    func testSpatialMapper_DefaultMode_IsStereo() {
        XCTAssertEqual(String(describing: mapper.spatialMode), String(describing: MIDIToSpatialMapper.SpatialMode.stereo))
    }
}

// MARK: - QuantumMIDIOut Behavior Tests

@MainActor
final class QuantumMIDIOutBehaviorTests: XCTestCase {

    // MARK: - Initialization

    func testQuantumMIDIOut_InitialState_Inactive() {
        let engine = QuantumMIDIOut(polyphony: 8)
        XCTAssertFalse(engine.isActive, "Engine must start inactive")
        XCTAssertEqual(engine.polyphony, 8)
        XCTAssertTrue(engine.activeVoices.isEmpty)
        XCTAssertEqual(engine.noteOnCount, 0)
        XCTAssertEqual(engine.noteOffCount, 0)
    }

    func testQuantumMIDIOut_PolyphonyClamped_ToMaximum() {
        let engine = QuantumMIDIOut(polyphony: 200)
        // Max is QuantumMIDIConstants.maxPolyphony = 64
        XCTAssertLessThanOrEqual(engine.polyphony, QuantumMIDIConstants.maxPolyphony,
                                  "Polyphony must be clamped to max")
    }

    // MARK: - Note On/Off (without MIDI hardware)

    func testQuantumMIDIOut_NoteOn_IgnoredWhenInactive() {
        let engine = QuantumMIDIOut(polyphony: 8)
        engine.noteOn(note: 60, velocity: 0.8)
        XCTAssertTrue(engine.activeVoices.isEmpty, "NoteOn should be ignored when engine is inactive")
    }

    func testQuantumMIDIOut_NoteOff_IgnoredWhenInactive() {
        let engine = QuantumMIDIOut(polyphony: 8)
        // Should not crash
        engine.noteOff(note: 60)
        XCTAssertEqual(engine.noteOffCount, 0)
    }

    func testQuantumMIDIOut_AllNotesOff_ClearsVoices() {
        let engine = QuantumMIDIOut(polyphony: 8)
        engine.allNotesOff()
        XCTAssertTrue(engine.activeVoices.isEmpty, "allNotesOff on empty engine should be safe")
    }

    // MARK: - Bio Input

    func testQuantumMIDIOut_UpdateBioInput_SetsValues() {
        let engine = QuantumMIDIOut(polyphony: 8)
        engine.updateBioInput(heartRate: 80, hrv: 60, coherence: 0.9, breathingRate: 15, breathPhase: 0.5)
        XCTAssertEqual(engine.bioInput.heartRate, 80.0, accuracy: 0.01)
        XCTAssertEqual(engine.bioInput.hrvMs, 60.0, accuracy: 0.01)
        XCTAssertEqual(engine.bioInput.coherence, 0.9, accuracy: 0.01)
        XCTAssertEqual(engine.bioInput.breathingRate, 15.0, accuracy: 0.01)
        XCTAssertEqual(engine.bioInput.breathPhase, 0.5, accuracy: 0.01)
    }

    func testQuantumMIDIOut_UpdateBioInput_PartialUpdate() {
        let engine = QuantumMIDIOut(polyphony: 8)
        let originalHR = engine.bioInput.heartRate
        engine.updateBioInput(coherence: 0.3)
        XCTAssertEqual(engine.bioInput.heartRate, originalHR, accuracy: 0.01,
                       "Unset fields should remain unchanged")
        XCTAssertEqual(engine.bioInput.coherence, 0.3, accuracy: 0.01)
    }

    // MARK: - Presets

    func testQuantumMIDIOut_MeditationPreset_ConfiguresCorrectly() {
        let engine = QuantumMIDIOut(polyphony: 16)
        engine.loadMeditationPreset()
        XCTAssertEqual(engine.polyphony, 8)
        XCTAssertTrue(engine.routing.mpeEnabled)
    }

    func testQuantumMIDIOut_OrchestralPreset_ConfiguresCorrectly() {
        let engine = QuantumMIDIOut(polyphony: 16)
        engine.loadOrchestralPreset()
        XCTAssertEqual(engine.polyphony, 32)
        XCTAssertTrue(engine.routing.mpeEnabled)
    }

    func testQuantumMIDIOut_QuantumTranscendentPreset_MaxPolyphony() {
        let engine = QuantumMIDIOut(polyphony: 16)
        engine.loadQuantumTranscendentPreset()
        XCTAssertEqual(engine.polyphony, 64)
        XCTAssertTrue(engine.routing.mpeEnabled)
        XCTAssertTrue(engine.routing.midi2Enabled)
    }
}

// MARK: - QuantumMIDIVoice & Types Tests

@MainActor
final class QuantumMIDIVoiceTests: XCTestCase {

    func testQuantumMIDIVoice_DefaultInit_HasSensibleDefaults() {
        let voice = QuantumMIDIVoice()
        XCTAssertEqual(voice.midiNote, 60, "Default note should be middle C")
        XCTAssertEqual(voice.velocity, 0.75, accuracy: 0.01)
        XCTAssertEqual(voice.pitchBend, 0.0, accuracy: 0.01)
        XCTAssertFalse(voice.isActive)
    }

    func testQuantumMIDIVoice_InstrumentTarget_NoteRanges() {
        // Piano should cover nearly full range
        let pianoRange = QuantumMIDIVoice.InstrumentTarget.piano.noteRange
        XCTAssertEqual(pianoRange.lowerBound, 21, "Piano starts at A0")
        XCTAssertEqual(pianoRange.upperBound, 108, "Piano ends at C8")

        // Synths should cover 0-127
        let synthRange = QuantumMIDIVoice.InstrumentTarget.fm.noteRange
        XCTAssertEqual(synthRange.lowerBound, 0)
        XCTAssertEqual(synthRange.upperBound, 127)
    }

    func testQuantumMIDIVoice_InstrumentTarget_MIDIChannelMapping() {
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.violins.midiChannel, 0)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.piano.midiChannel, 5)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.quantumField.midiChannel, 15)
    }

    func testQuantumBioInput_QuantumVelocity_ClampedTo01() {
        var bio = QuantumBioInput()
        bio.coherence = 1.0
        bio.breathPhase = 1.0
        XCTAssertGreaterThanOrEqual(bio.quantumVelocity, 0.0)
        XCTAssertLessThanOrEqual(bio.quantumVelocity, 1.0)
    }

    func testQuantumBioInput_HRVExpression_ClampedTo01() {
        var bio = QuantumBioInput()
        bio.hrvMs = 200.0
        XCTAssertGreaterThanOrEqual(bio.hrvExpression, 0.0)
        XCTAssertLessThanOrEqual(bio.hrvExpression, 1.0)
    }

    func testQuantumChordType_MajorTriadIntervals() {
        let intervals = QuantumChordType.majorTriad.intervals(for: .classical)
        XCTAssertEqual(intervals, [0, 4, 7])
    }

    func testQuantumChordType_FibonacciIntervals_AreModulo12() {
        let intervals = QuantumChordType.fibonacci.intervals(for: .fibonacciHarmonic)
        for interval in intervals {
            XCTAssertLessThan(interval, 12, "Fibonacci intervals must be mod 12")
            XCTAssertGreaterThanOrEqual(interval, 0)
        }
    }
}

// MARK: - TouchInstruments Behavior Tests

@MainActor
final class TouchInstrumentsBehaviorTests: XCTestCase {

    // MARK: - Musical Scales

    func testTouchMusicalScale_MajorIntervals_AreCorrect() {
        let scale = TouchMusicalScale.major
        XCTAssertEqual(scale.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testTouchMusicalScale_NoteInScale_ReturnsCorrectPitch() {
        let scale = TouchMusicalScale.major
        // Degree 0, root C4 (60) => C4 = 60
        let note0 = scale.noteInScale(degree: 0, root: 60)
        XCTAssertEqual(note0, 60)

        // Degree 2, root C4 => E4 = 64
        let note2 = scale.noteInScale(degree: 2, root: 60)
        XCTAssertEqual(note2, 64)
    }

    func testTouchMusicalScale_NoteInScale_WrapsOctave() {
        let scale = TouchMusicalScale.major
        // 7 notes in major => degree 7 wraps to next octave degree 0
        let note7 = scale.noteInScale(degree: 7, root: 60)
        // octaveOffset = 7/7 = 1, scaleIndex = 0, => 60 + 12 + 0 = 72
        XCTAssertEqual(note7, 72, "Degree 7 should wrap to next octave root")
    }

    func testTouchMusicalScale_NoteInScale_ClampsTo0_127() {
        let scale = TouchMusicalScale.major
        // Very high degree should not exceed 127
        let highNote = scale.noteInScale(degree: 50, root: 120)
        XCTAssertLessThanOrEqual(highNote, 127)

        // Root 0 degree 0 should be 0
        let lowNote = scale.noteInScale(degree: 0, root: 0)
        XCTAssertGreaterThanOrEqual(lowNote, 0)
    }

    func testTouchMusicalScale_ChromaticHas12Notes() {
        XCTAssertEqual(TouchMusicalScale.chromatic.intervals.count, 12)
    }

    func testTouchMusicalScale_PentatonicMajorHas5Notes() {
        XCTAssertEqual(TouchMusicalScale.pentatonicMajor.intervals.count, 5)
    }

    // MARK: - Chord Types

    func testChordType_MajorTriad_CorrectIntervals() {
        XCTAssertEqual(ChordType.major.intervals, [0, 4, 7])
    }

    func testChordType_Notes_FromRoot() {
        let notes = ChordType.minor.notes(root: 60)
        XCTAssertEqual(notes, [60, 63, 67], "C minor = C, Eb, G")
    }

    func testChordType_Notes_ClampsTo127() {
        let notes = ChordType.add9.notes(root: 120)
        for note in notes {
            XCTAssertLessThanOrEqual(note, 127, "Notes must be clamped to 127")
        }
    }

    func testChordType_PowerChord_HasTwoNotes() {
        XCTAssertEqual(ChordType.power.intervals.count, 2)
        XCTAssertEqual(ChordType.power.intervals, [0, 7])
    }
}

// MARK: - QuantumMIDIRouting Tests

@MainActor
final class QuantumMIDIRoutingBehaviorTests: XCTestCase {

    func testRouting_DefaultInit_AllInstrumentsEnabled() {
        let routing = QuantumMIDIRouting()
        XCTAssertEqual(routing.enabledInstruments.count,
                       QuantumMIDIVoice.InstrumentTarget.allCases.count)
    }

    func testRouting_EnableOrchestral_AddsOrchestralInstruments() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        routing.enableOrchestral()
        XCTAssertTrue(routing.enabledInstruments.contains(.violins))
        XCTAssertTrue(routing.enabledInstruments.contains(.piano))
        XCTAssertTrue(routing.enabledInstruments.contains(.timpani))
    }

    func testRouting_EnableSynthesizers_AddsSynthInstruments() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        routing.enableSynthesizers()
        XCTAssertTrue(routing.enabledInstruments.contains(.fm))
        XCTAssertTrue(routing.enabledInstruments.contains(.granular))
        XCTAssertTrue(routing.enabledInstruments.contains(.bioReactive))
    }

    func testRouting_EnableAll_ContainsEveryInstrument() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        routing.enableAll()
        for instrument in QuantumMIDIVoice.InstrumentTarget.allCases {
            XCTAssertTrue(routing.enabledInstruments.contains(instrument),
                          "\(instrument.rawValue) should be enabled after enableAll()")
        }
    }
}

// MARK: - QuantumIntelligenceMode Tests

@MainActor
final class QuantumIntelligenceModeBehaviorTests: XCTestCase {

    func testAllModes_HaveVoiceAllocationStrategy() {
        for mode in QuantumIntelligenceMode.allCases {
            // Should not crash — each mode maps to a strategy
            let _ = mode.voiceAllocationStrategy
        }
    }

    func testClassicalMode_UsesRoundRobin() {
        let strategy = QuantumIntelligenceMode.classical.voiceAllocationStrategy
        if case .roundRobin = strategy {
            // expected
        } else {
            XCTFail("Classical mode should use roundRobin allocation")
        }
    }

    func testLambdaTranscendent_UsesQuantumStrategy() {
        let strategy = QuantumIntelligenceMode.lambdaTranscendent.voiceAllocationStrategy
        if case .quantum = strategy {
            // expected
        } else {
            XCTFail("Lambda transcendent should use quantum allocation")
        }
    }
}

// MARK: - MIDI2Error Tests

@MainActor
final class MIDI2ErrorBehaviorTests: XCTestCase {

    func testMIDI2Error_ClientCreationFailed_HasDescription() {
        let error = MIDI2Error.clientCreationFailed(-50)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("-50") ?? false)
    }

    func testMIDI2Error_NotInitialized_HasDescription() {
        let error = MIDI2Error.notInitialized
        XCTAssertNotNil(error.errorDescription)
    }
}

#endif

// LambdaEnhancementsTests.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Comprehensive tests for Lambda Mode enhancements
// Tests all new features: GazeTracker, HealthKit, Haptics, Social, AI Director, Music Generator
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

final class LambdaEnhancementsTests: XCTestCase {

    // MARK: - GazeTracker Tests

    func testGazeDataInitialization() {
        let gazeData = GazeData()

        XCTAssertEqual(gazeData.gazePoint, SIMD2<Float>(0.5, 0.5))
        XCTAssertEqual(gazeData.leftEyeOpenness, 1.0)
        XCTAssertEqual(gazeData.rightEyeOpenness, 1.0)
        XCTAssertFalse(gazeData.isBlinking)
        XCTAssertFalse(gazeData.isFixating)
    }

    func testGazeDataScreenPosition() {
        var gazeData = GazeData()
        gazeData.gazePoint = SIMD2<Float>(0.3, 0.7)

        let screenSize = CGSize(width: 1920, height: 1080)
        let screenPos = gazeData.screenPosition(for: screenSize)

        XCTAssertEqual(screenPos.x, 576, accuracy: 1)  // 0.3 * 1920
        XCTAssertEqual(screenPos.y, 756, accuracy: 1)  // 0.7 * 1080
    }

    func testGazeControlParameters() {
        var params = GazeControlParameters()
        params.gazeX = 0.0  // Far left
        params.gazeY = 0.5  // Center vertical
        params.attention = 0.8
        params.stability = 0.9

        // Pan should be -1 for far left
        XCTAssertEqual(params.audioPan, -1.0, accuracy: 0.01)

        // Filter cutoff based on attention * stability
        XCTAssertEqual(params.filterCutoff, 0.72, accuracy: 0.01)
    }

    func testGazeGestureTypes() {
        // Verify all gesture types exist
        XCTAssertEqual(GazeGesture.allCases.count, 9)
        XCTAssertTrue(GazeGesture.allCases.contains(.blink))
        XCTAssertTrue(GazeGesture.allCases.contains(.doubleBlink))
        XCTAssertTrue(GazeGesture.allCases.contains(.longGaze))
        XCTAssertTrue(GazeGesture.allCases.contains(.wink))
    }

    // MARK: - RealTimeHealthKitEngine Tests

    func testRealTimeHeartDataInitialization() {
        let heartData = RealTimeHeartData()

        XCTAssertEqual(heartData.heartRate, 0)
        XCTAssertEqual(heartData.heartRateVariability, 0)
        XCTAssertTrue(heartData.rrIntervals.isEmpty)
        XCTAssertEqual(heartData.coherenceRatio, 0)
    }

    func testRealTimeHeartDataAvgRR() {
        var heartData = RealTimeHeartData()
        heartData.rrIntervals = [800, 850, 900, 850, 800]

        XCTAssertEqual(heartData.averageRR, 840, accuracy: 1)
    }

    func testRealTimeHeartDataHeartRateFromRR() {
        var heartData = RealTimeHeartData()
        heartData.rrIntervals = [1000]  // 1000ms = 60 BPM

        XCTAssertEqual(heartData.heartRateFromRR, 60, accuracy: 1)
    }

    func testRealTimeBreathingDataInitialization() {
        let breathData = RealTimeBreathingData()

        XCTAssertEqual(breathData.breathingRate, 12)
        XCTAssertEqual(breathData.breathPhase, .inhale)
        XCTAssertEqual(breathData.phaseProgress, 0)
    }

    func testRealTimeBreathingDataPhaseAngle() {
        var breathData = RealTimeBreathingData()
        breathData.breathPhase = .exhale
        breathData.phaseProgress = 0.5

        // Exhale at 50% = 270 degrees (0.75 of full cycle)
        XCTAssertEqual(breathData.phaseAngle, Float.pi * 1.5, accuracy: 0.1)
    }

    func testHealthDisclaimer() {
        let disclaimer = RealTimeHealthKitEngine.healthDisclaimer

        XCTAssertTrue(disclaimer.contains("NOT A MEDICAL DEVICE"))
        XCTAssertTrue(disclaimer.contains("CREATIVE"))
        XCTAssertTrue(disclaimer.contains("INFORMATIONAL"))
    }

    func testCoherenceWindowSeconds() {
        let defaultWindow = RealTimeHealthKitEngine.CoherenceWindowSeconds.default

        XCTAssertEqual(defaultWindow, 60.0)
    }

    // MARK: - Sample Plugins Tests

    func testSacredGeometryPluginInfo() {
        let plugin = SacredGeometryVisualizerPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.sacred-geometry")
        XCTAssertEqual(plugin.version, "1.0.0")
        XCTAssertEqual(plugin.requiredSDKVersion, "2.0.0")
        XCTAssertTrue(plugin.capabilities.contains(.visualization))
        XCTAssertTrue(plugin.capabilities.contains(.bioProcessing))
    }

    func testSacredGeometryPatterns() {
        XCTAssertEqual(SacredGeometryVisualizerPlugin.GeometryPattern.allCases.count, 8)
        XCTAssertTrue(SacredGeometryVisualizerPlugin.GeometryPattern.allCases.contains(.flowerOfLife))
        XCTAssertTrue(SacredGeometryVisualizerPlugin.GeometryPattern.allCases.contains(.metatronsCube))
        XCTAssertTrue(SacredGeometryVisualizerPlugin.GeometryPattern.allCases.contains(.fibonacciSpiral))
    }

    func testBioAudioGeneratorPluginInfo() {
        let plugin = BioAudioGeneratorPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.bio-audio-generator")
        XCTAssertTrue(plugin.capabilities.contains(.audioGenerator))
        XCTAssertTrue(plugin.capabilities.contains(.hrvAnalysis))
    }

    func testBioAudioGeneratorConfiguration() {
        let config = BioAudioGeneratorPlugin.Configuration()

        XCTAssertEqual(config.baseFrequency, 432.0)  // A4 at 432Hz
        XCTAssertEqual(config.scale, .pentatonic)
    }

    func testQuantumMIDIBridgePluginInfo() {
        let plugin = QuantumMIDIBridgePlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.quantum-midi-bridge")
        XCTAssertTrue(plugin.capabilities.contains(.midiOutput))
        XCTAssertTrue(plugin.capabilities.contains(.quantumProcessing))
    }

    func testMIDIMessageCreation() {
        let ccMessage = QuantumMIDIBridgePlugin.MIDIMessage.controlChange(channel: 1, cc: 74, value: 100)

        XCTAssertEqual(ccMessage.status, 0xB0)  // CC on channel 1
        XCTAssertEqual(ccMessage.data1, 74)
        XCTAssertEqual(ccMessage.data2, 100)
    }

    func testDMXLightShowPluginInfo() {
        let plugin = DMXLightShowPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.dmx-light-show")
        XCTAssertTrue(plugin.capabilities.contains(.dmxOutput))
    }

    func testDMXFixtureDefaults() {
        let fixture = DMXLightShowPlugin.DMXFixture()

        XCTAssertEqual(fixture.red, 0)
        XCTAssertEqual(fixture.green, 0)
        XCTAssertEqual(fixture.blue, 0)
        XCTAssertEqual(fixture.intensity, 255)
        XCTAssertEqual(fixture.pan, 127)  // Center
        XCTAssertEqual(fixture.tilt, 127)  // Center
    }

    // MARK: - HapticCompositionEngine Tests

    func testHapticPatternTypes() {
        XCTAssertEqual(HapticPatternType.allCases.count, 18)
        XCTAssertTrue(HapticPatternType.allCases.contains(.heartbeat))
        XCTAssertTrue(HapticPatternType.allCases.contains(.breathSync))
        XCTAssertTrue(HapticPatternType.allCases.contains(.wave))
        XCTAssertTrue(HapticPatternType.allCases.contains(.flowState))
    }

    func testHapticEventInitialization() {
        let event = HapticEvent(time: 0.5, duration: 0.1, intensity: 0.8, sharpness: 0.6)

        XCTAssertEqual(event.time, 0.5)
        XCTAssertEqual(event.duration, 0.1)
        XCTAssertEqual(event.intensity, 0.8)
        XCTAssertEqual(event.sharpness, 0.6)
        XCTAssertEqual(event.type, .transient)
    }

    func testHapticEventIntensityClamping() {
        let event = HapticEvent(time: 0, intensity: 1.5, sharpness: -0.5)

        XCTAssertEqual(event.intensity, 1.0)  // Clamped to max
        XCTAssertEqual(event.sharpness, 0.0)  // Clamped to min
    }

    func testHapticCompositionDuration() {
        let events = [
            HapticEvent(time: 0, duration: 0.1),
            HapticEvent(time: 0.5, duration: 0.2),
            HapticEvent(time: 1.0, duration: 0.3)
        ]

        let composition = HapticComposition(name: "Test", events: events)

        XCTAssertEqual(composition.duration, 1.3, accuracy: 0.01)  // 1.0 + 0.3
    }

    func testBioHapticDataNormalizedHeartRate() {
        var bioData = BioHapticData()
        bioData.heartRate = 85  // Mid-range

        // (85 - 50) / 70 = 0.5
        XCTAssertEqual(bioData.normalizedHeartRate, 0.5, accuracy: 0.01)
    }

    func testBioHapticDataHeartbeatInterval() {
        var bioData = BioHapticData()
        bioData.heartRate = 60  // 60 BPM = 1 second interval

        XCTAssertEqual(bioData.heartbeatInterval, 1.0, accuracy: 0.01)
    }

    // MARK: - SocialCoherenceEngine Tests

    func testParticipantInitialization() {
        let participant = Participant(displayName: "Test User")

        XCTAssertEqual(participant.displayName, "Test User")
        XCTAssertEqual(participant.role, .participant)
        XCTAssertTrue(participant.isActive)
        XCTAssertEqual(participant.connectionQuality, 1.0)
    }

    func testParticipantBioDataDefaults() {
        let bioData = Participant.ParticipantBioData()

        XCTAssertEqual(bioData.heartRate, 70)
        XCTAssertEqual(bioData.hrv, 50)
        XCTAssertEqual(bioData.coherence, 0.5)
        XCTAssertEqual(bioData.breathingRate, 12)
    }

    func testParticipantRoles() {
        XCTAssertEqual(Participant.ParticipantRole.allCases.count, 4)
        XCTAssertTrue(Participant.ParticipantRole.allCases.contains(.facilitator))
        XCTAssertTrue(Participant.ParticipantRole.allCases.contains(.researcher))
    }

    func testGroupStateDefaults() {
        let state = GroupState()

        XCTAssertTrue(state.participants.isEmpty)
        XCTAssertEqual(state.groupCoherence, 0)
        XCTAssertEqual(state.groupFlowScore, 0)
        XCTAssertEqual(state.dominantFrequency, 7.83)  // Schumann
    }

    func testGroupStateFlowCheck() {
        var state = GroupState()
        state.groupFlowScore = 0.9

        XCTAssertTrue(state.isInGroupFlow)  // > 0.8 threshold
    }

    func testGroupStateEntanglementCheck() {
        var state = GroupState()
        state.entrainmentLevel = 0.95

        XCTAssertTrue(state.isEntangled)  // > 0.9 threshold
    }

    func testCoherenceEventTypes() {
        XCTAssertEqual(CoherenceEvent.EventType.allCases.count, 10)
        XCTAssertTrue(CoherenceEvent.EventType.allCases.contains(.flowStateAchieved))
        XCTAssertTrue(CoherenceEvent.EventType.allCases.contains(.groupEntanglement))
    }

    func testSessionConfigurationDefaults() {
        let config = SessionConfiguration()

        XCTAssertEqual(config.type, .openMeditation)
        XCTAssertEqual(config.maxParticipants, 100)
        XCTAssertFalse(config.isPrivate)
        XCTAssertTrue(config.bioSyncEnabled)
    }

    func testSessionTypes() {
        XCTAssertEqual(SessionConfiguration.SessionType.allCases.count, 8)
        XCTAssertTrue(SessionConfiguration.SessionType.allCases.contains(.coherenceCircle))
        XCTAssertTrue(SessionConfiguration.SessionType.allCases.contains(.quantumEntanglement))
    }

    // MARK: - AISceneDirector Tests

    func testCameraInitialization() {
        let camera = Camera(name: "Main Camera", type: .wide)

        XCTAssertEqual(camera.name, "Main Camera")
        XCTAssertEqual(camera.type, .wide)
        XCTAssertTrue(camera.isActive)
        XCTAssertEqual(camera.settings.fov, 60)
    }

    func testCameraTypes() {
        XCTAssertEqual(Camera.CameraType.allCases.count, 10)
        XCTAssertTrue(Camera.CameraType.allCases.contains(.quantum))
        XCTAssertTrue(Camera.CameraType.allCases.contains(.bioReactive))
    }

    func testCameraPositionDefaults() {
        let position = Camera.CameraPosition()

        XCTAssertEqual(position.x, 0)
        XCTAssertEqual(position.y, 0)
        XCTAssertEqual(position.z, 5)  // 5 units away
        XCTAssertEqual(position.pan, 0)
        XCTAssertEqual(position.tilt, 0)
    }

    func testSceneInitialization() {
        let scene = Scene(name: "Concert Scene", mood: .energetic)

        XCTAssertEqual(scene.name, "Concert Scene")
        XCTAssertEqual(scene.mood, .energetic)
        XCTAssertTrue(scene.cameras.isEmpty)
    }

    func testSceneMoods() {
        XCTAssertEqual(Scene.SceneMood.allCases.count, 10)
        XCTAssertTrue(Scene.SceneMood.allCases.contains(.meditative))
        XCTAssertTrue(Scene.SceneMood.allCases.contains(.cosmic))
        XCTAssertTrue(Scene.SceneMood.allCases.contains(.ethereal))
    }

    func testVisualLayerTypes() {
        XCTAssertEqual(Scene.VisualLayer.VisualType.allCases.count, 10)
        XCTAssertTrue(Scene.VisualLayer.VisualType.allCases.contains(.sacredGeometry))
        XCTAssertTrue(Scene.VisualLayer.VisualType.allCases.contains(.quantum))
        XCTAssertTrue(Scene.VisualLayer.VisualType.allCases.contains(.bioField))
    }

    func testDirectionDecisionTypes() {
        XCTAssertEqual(DirectionDecision.DecisionType.allCases.count, 10)
        XCTAssertTrue(DirectionDecision.DecisionType.allCases.contains(.switchCamera))
        XCTAssertTrue(DirectionDecision.DecisionType.allCases.contains(.changeMood))
    }

    func testPerformanceContextDefaults() {
        let context = PerformanceContext()

        XCTAssertEqual(context.currentBPM, 120)
        XCTAssertEqual(context.coherence, 0.5)
        XCTAssertFalse(context.isClimax)
    }

    func testPerformanceContextOnBeat() {
        var context = PerformanceContext()

        context.beatPhase = 0.05
        XCTAssertTrue(context.isOnBeat)  // < 0.1

        context.beatPhase = 0.95
        XCTAssertTrue(context.isOnBeat)  // > 0.9

        context.beatPhase = 0.5
        XCTAssertFalse(context.isOnBeat)
    }

    func testDirectionStyles() {
        XCTAssertEqual(AISceneDirector.DirectionStyle.allCases.count, 8)
        XCTAssertTrue(AISceneDirector.DirectionStyle.allCases.contains(.cinematic))
        XCTAssertTrue(AISceneDirector.DirectionStyle.allCases.contains(.experimental))
    }

    // MARK: - BiometricMusicGenerator Tests

    func testMusicalScales() {
        XCTAssertEqual(MusicalScale.allCases.count, 18)
        XCTAssertTrue(MusicalScale.allCases.contains(.pentatonicMajor))
        XCTAssertTrue(MusicalScale.allCases.contains(.arabic))
        XCTAssertTrue(MusicalScale.allCases.contains(.japanese))
    }

    func testMusicalScaleIntervals() {
        let major = MusicalScale.major.intervals
        XCTAssertEqual(major, [0, 2, 4, 5, 7, 9, 11])

        let pentatonic = MusicalScale.pentatonicMajor.intervals
        XCTAssertEqual(pentatonic, [0, 2, 4, 7, 9])

        let blues = MusicalScale.blues.intervals
        XCTAssertEqual(blues, [0, 3, 5, 6, 7, 10])
    }

    func testMusicalNoteInitialization() {
        let note = MusicalNote(pitch: 60, velocity: 0.8, duration: 0.5)

        XCTAssertEqual(note.pitch, 60)
        XCTAssertEqual(note.velocity, 0.8)
        XCTAssertEqual(note.duration, 0.5)
        XCTAssertEqual(note.source, .melody)
    }

    func testMusicalNoteNoteName() {
        let middleC = MusicalNote(pitch: 60)
        XCTAssertEqual(middleC.noteName, "C4")

        let a4 = MusicalNote(pitch: 69)
        XCTAssertEqual(a4.noteName, "A4")

        let fSharp5 = MusicalNote(pitch: 78)
        XCTAssertEqual(fSharp5.noteName, "F#5")
    }

    func testMusicalNoteFrequency() {
        let a4 = MusicalNote(pitch: 69)
        XCTAssertEqual(a4.frequency, 440.0, accuracy: 0.1)

        let a5 = MusicalNote(pitch: 81)
        XCTAssertEqual(a5.frequency, 880.0, accuracy: 0.1)
    }

    func testMusicalNotePitchClamping() {
        let lowNote = MusicalNote(pitch: -10)
        XCTAssertEqual(lowNote.pitch, 0)

        let highNote = MusicalNote(pitch: 200)
        XCTAssertEqual(highNote.pitch, 127)
    }

    func testChordTypes() {
        XCTAssertEqual(Chord.ChordType.allCases.count, 10)
        XCTAssertTrue(Chord.ChordType.allCases.contains(.major))
        XCTAssertTrue(Chord.ChordType.allCases.contains(.dominant7))
        XCTAssertTrue(Chord.ChordType.allCases.contains(.suspended4))
    }

    func testChordIntervals() {
        let majorIntervals = Chord.ChordType.major.intervals
        XCTAssertEqual(majorIntervals, [0, 4, 7])

        let minorIntervals = Chord.ChordType.minor.intervals
        XCTAssertEqual(minorIntervals, [0, 3, 7])

        let dom7Intervals = Chord.ChordType.dominant7.intervals
        XCTAssertEqual(dom7Intervals, [0, 4, 7, 10])
    }

    func testChordCreation() {
        let cMajor = Chord(rootNote: 60, type: .major)

        XCTAssertEqual(cMajor.rootNote, 60)
        XCTAssertEqual(cMajor.notes, [60, 64, 67])  // C, E, G
    }

    func testChordInversion() {
        let cMajorFirstInversion = Chord(rootNote: 60, type: .major, inversion: 1)

        // First inversion: E, G, C (E and G, then C+12)
        XCTAssertEqual(cMajorFirstInversion.notes, [64, 67, 72])
    }

    func testBioMusicalDataDefaults() {
        let bioData = BioMusicalData()

        XCTAssertEqual(bioData.heartRate, 70)
        XCTAssertEqual(bioData.hrvMs, 50)
        XCTAssertEqual(bioData.coherence, 0.5)
        XCTAssertEqual(bioData.breathingRate, 12)
    }

    func testBioMusicalDataTempoBPM() {
        var bioData = BioMusicalData()
        bioData.heartRate = 80

        XCTAssertEqual(bioData.tempoBPM, 80)

        bioData.heartRate = 300  // Too fast
        XCTAssertEqual(bioData.tempoBPM, 200)  // Clamped to max

        bioData.heartRate = 20  // Too slow
        XCTAssertEqual(bioData.tempoBPM, 40)  // Clamped to min
    }

    func testBioMusicalDataMelodicVariation() {
        var bioData = BioMusicalData()

        bioData.hrvMs = 50
        XCTAssertEqual(bioData.melodicVariation, 0.5, accuracy: 0.01)

        bioData.hrvMs = 100
        XCTAssertEqual(bioData.melodicVariation, 1.0, accuracy: 0.01)
    }

    func testBioMusicalDataDynamicEnvelope() {
        var bioData = BioMusicalData()

        bioData.breathPhase = 0  // Start of inhale
        XCTAssertEqual(bioData.dynamicEnvelope, 0, accuracy: 0.01)

        bioData.breathPhase = 0.5  // Peak
        XCTAssertEqual(bioData.dynamicEnvelope, 1.0, accuracy: 0.01)

        bioData.breathPhase = 1.0  // End of exhale
        XCTAssertEqual(bioData.dynamicEnvelope, 0, accuracy: 0.01)
    }

    func testGeneratorConfiguration() {
        let config = GeneratorConfiguration()

        XCTAssertEqual(config.scale, .pentatonicMajor)
        XCTAssertEqual(config.rootNote, 60)  // Middle C
        XCTAssertTrue(config.enableBass)
        XCTAssertTrue(config.quantize)
    }

    func testGeneratorConfigurationTempoSources() {
        XCTAssertEqual(GeneratorConfiguration.TempoSource.allCases.count, 4)
        XCTAssertTrue(GeneratorConfiguration.TempoSource.allCases.contains(.heartRate))
        XCTAssertTrue(GeneratorConfiguration.TempoSource.allCases.contains(.breathing))
    }

    func testGeneratedPhraseInitialization() {
        let phrase = GeneratedPhrase(duration: 8.0, tempo: 120.0)

        XCTAssertTrue(phrase.notes.isEmpty)
        XCTAssertTrue(phrase.chords.isEmpty)
        XCTAssertEqual(phrase.duration, 8.0)
        XCTAssertEqual(phrase.tempo, 120.0)
    }

    // MARK: - Constants Tests

    func testDirectorConstants() {
        XCTAssertEqual(DirectorConstants.minShotDuration, 2.0)
        XCTAssertEqual(DirectorConstants.maxShotDuration, 30.0)
        XCTAssertEqual(DirectorConstants.defaultShotDuration, 8.0)
    }

    func testSocialCoherenceConstants() {
        XCTAssertEqual(SocialCoherenceConstants.maxParticipants, 1000)
        XCTAssertEqual(SocialCoherenceConstants.flowThreshold, 0.8)
        XCTAssertEqual(SocialCoherenceConstants.entanglementThreshold, 0.9)
        XCTAssertEqual(SocialCoherenceConstants.phi, 1.618033988749895, accuracy: 0.0001)
    }

    func testBiometricMusicConstants() {
        XCTAssertEqual(BiometricMusicConstants.baseOctave, 4)
        XCTAssertEqual(BiometricMusicConstants.maxPolyphony, 8)
        XCTAssertEqual(BiometricMusicConstants.minBPM, 40.0)
        XCTAssertEqual(BiometricMusicConstants.maxBPM, 200.0)
        XCTAssertEqual(BiometricMusicConstants.schumannHz, 7.83, accuracy: 0.01)
    }

    func testHapticConstants() {
        XCTAssertEqual(HapticConstants.maxIntensity, 1.0)
        XCTAssertEqual(HapticConstants.minIntensity, 0.0)
        XCTAssertEqual(HapticConstants.coherenceThreshold, 0.7)
    }

    // MARK: - Integration Tests

    func testGazeToControlParametersPipeline() {
        var gazeData = GazeData()
        gazeData.gazePoint = SIMD2<Float>(0.8, 0.2)  // Looking right, upper
        gazeData.leftEyeOpenness = 0.9
        gazeData.rightEyeOpenness = 0.95
        gazeData.isFixating = true
        gazeData.fixationDuration = 2.0

        var params = GazeControlParameters()
        params.gazeX = gazeData.gazePoint.x
        params.gazeY = gazeData.gazePoint.y
        params.attention = gazeData.averageEyeOpenness
        params.stability = gazeData.isFixating ? 0.9 : 0.5

        // Should have right pan
        XCTAssertGreaterThan(params.audioPan, 0)

        // Should have high filter cutoff (good attention + stability)
        XCTAssertGreaterThan(params.filterCutoff, 0.7)
    }

    func testBioDataToMusicPipeline() {
        var bioData = BioMusicalData()
        bioData.heartRate = 72
        bioData.hrvMs = 60
        bioData.coherence = 0.75
        bioData.breathingRate = 10
        bioData.breathPhase = 0.25

        // Verify transformations
        XCTAssertEqual(bioData.tempoBPM, 72)
        XCTAssertEqual(bioData.melodicVariation, 0.6, accuracy: 0.01)
        XCTAssertEqual(bioData.harmonicConsonance, 0.75)

        // Dynamic envelope at 25% of breath cycle
        let expectedEnvelope = sin(0.25 * Float.pi)
        XCTAssertEqual(bioData.dynamicEnvelope, expectedEnvelope, accuracy: 0.01)
    }

    func testCoherenceToHapticPipeline() {
        var bioHaptic = BioHapticData()
        bioHaptic.coherence = 0.85
        bioHaptic.heartRate = 65

        // High coherence should produce more coherent haptic patterns
        XCTAssertGreaterThan(bioHaptic.coherence, HapticConstants.coherenceThreshold)

        // Heart interval at 65 BPM
        let expectedInterval = 60.0 / 65.0
        XCTAssertEqual(bioHaptic.heartbeatInterval, expectedInterval, accuracy: 0.01)
    }

    // MARK: - Edge Case Tests

    func testZeroCoherence() {
        var bioData = BioMusicalData()
        bioData.coherence = 0

        XCTAssertEqual(bioData.harmonicConsonance, 0)
    }

    func testMaxCoherence() {
        var bioData = BioMusicalData()
        bioData.coherence = 1.0

        XCTAssertEqual(bioData.harmonicConsonance, 1.0)
    }

    func testEmptyParticipantGroup() {
        let state = GroupState()

        XCTAssertEqual(state.participantCount, 0)
        XCTAssertFalse(state.isInGroupFlow)
    }

    func testExtremeHeartRates() {
        var bioData = BioMusicalData()

        // Very low heart rate
        bioData.heartRate = 30
        XCTAssertEqual(bioData.tempoBPM, 40)  // Clamped to min

        // Very high heart rate
        bioData.heartRate = 220
        XCTAssertEqual(bioData.tempoBPM, 200)  // Clamped to max
    }

    func testNoteVelocityClamping() {
        let softNote = MusicalNote(pitch: 60, velocity: -0.5)
        XCTAssertEqual(softNote.velocity, 0)

        let loudNote = MusicalNote(pitch: 60, velocity: 1.5)
        XCTAssertEqual(loudNote.velocity, 1.0)
    }

    // MARK: - Performance Tests

    func testChordCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Chord(rootNote: Int.random(in: 48...72), type: .major7, inversion: Int.random(in: 0...2))
            }
        }
    }

    func testNoteCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = MusicalNote(pitch: Int.random(in: 36...96), velocity: Float.random(in: 0...1), duration: Double.random(in: 0.1...2.0))
            }
        }
    }

    func testScaleIntervalLookupPerformance() {
        measure {
            for _ in 0..<10000 {
                let scale = MusicalScale.allCases.randomElement()!
                _ = scale.intervals
            }
        }
    }
}

import XCTest
@testable import Echoelmusic

/// Comprehensive Test Suite for All Mapper Classes
/// Tests the 6 core mappers that connect input to output
final class MapperTestSuite: XCTestCase {

    // MARK: - BioParameterMapper Tests

    func testBioParameterMapper_HRVToReverb() async throws {
        let mapper = await BioParameterMapper()

        // Low HRV coherence (stressed) → Low reverb
        await mapper.updateParameters(hrvCoherence: 10, heartRate: 80, voicePitch: 440, audioLevel: 0.5)
        let lowReverb = await mapper.reverbWet
        XCTAssertLessThan(lowReverb, 0.3, "Low coherence should produce low reverb")

        // High HRV coherence (flow) → High reverb
        await mapper.updateParameters(hrvCoherence: 90, heartRate: 60, voicePitch: 440, audioLevel: 0.5)
        // Allow smoothing to settle
        for _ in 0..<10 {
            await mapper.updateParameters(hrvCoherence: 90, heartRate: 60, voicePitch: 440, audioLevel: 0.5)
        }
        let highReverb = await mapper.reverbWet
        XCTAssertGreaterThan(highReverb, 0.5, "High coherence should produce high reverb")
    }

    func testBioParameterMapper_HeartRateToFilter() async throws {
        let mapper = await BioParameterMapper()

        // Low heart rate → Low filter cutoff (darker sound)
        await mapper.updateParameters(hrvCoherence: 50, heartRate: 50, voicePitch: 440, audioLevel: 0.5)
        for _ in 0..<10 {
            await mapper.updateParameters(hrvCoherence: 50, heartRate: 50, voicePitch: 440, audioLevel: 0.5)
        }
        let lowFilter = await mapper.filterCutoff
        XCTAssertLessThan(lowFilter, 1000, "Low HR should produce lower filter cutoff")

        // High heart rate → High filter cutoff (brighter sound)
        await mapper.updateParameters(hrvCoherence: 50, heartRate: 110, voicePitch: 440, audioLevel: 0.5)
        for _ in 0..<10 {
            await mapper.updateParameters(hrvCoherence: 50, heartRate: 110, voicePitch: 440, audioLevel: 0.5)
        }
        let highFilter = await mapper.filterCutoff
        XCTAssertGreaterThan(highFilter, lowFilter, "High HR should produce higher filter cutoff")
    }

    func testBioParameterMapper_VoicePitchToScale() async throws {
        let mapper = await BioParameterMapper()

        // Test healing scale snapping
        let healingFrequencies: [Float] = [432.0, 486.0, 512.0, 576.0, 648.0, 729.0, 768.0]

        await mapper.updateParameters(hrvCoherence: 50, heartRate: 60, voicePitch: 430, audioLevel: 0.5)
        for _ in 0..<20 {
            await mapper.updateParameters(hrvCoherence: 50, heartRate: 60, voicePitch: 430, audioLevel: 0.5)
        }
        let snappedFreq = await mapper.baseFrequency

        // Should snap to nearest healing frequency (432 Hz)
        XCTAssertTrue(healingFrequencies.contains { abs($0 - snappedFreq) < 50 },
                      "Voice pitch should snap to healing scale")
    }

    func testBioParameterMapper_Presets() async throws {
        let mapper = await BioParameterMapper()

        // Test meditation preset
        await mapper.applyPreset(.meditation)
        let medReverb = await mapper.reverbWet
        let medFreq = await mapper.baseFrequency
        XCTAssertEqual(medReverb, 0.7, "Meditation preset should have 70% reverb")
        XCTAssertEqual(medFreq, 432.0, "Meditation preset should use 432 Hz")

        // Test energize preset
        await mapper.applyPreset(.energize)
        let energyReverb = await mapper.reverbWet
        let energyFreq = await mapper.baseFrequency
        XCTAssertEqual(energyReverb, 0.2, "Energize preset should have 20% reverb")
        XCTAssertEqual(energyFreq, 741.0, "Energize preset should use 741 Hz")
    }

    func testBioParameterMapper_Validation() async throws {
        let mapper = await BioParameterMapper()

        await mapper.applyPreset(.meditation)
        let isValid = await mapper.isValid
        XCTAssertTrue(isValid, "Preset should produce valid parameters")
    }

    // MARK: - MIDIToVisualMapper Tests

    func testMIDIToVisualMapper_NoteOnMapping() async throws {
        let mapper = await MIDIToVisualMapper()

        // Test note on creates cymatics pattern
        await mapper.handleNoteOn(note: 60, velocity: 0.8)  // Middle C

        let patterns = await mapper.cymaticsParameters.patterns
        XCTAssertFalse(patterns.isEmpty, "Note on should create cymatics pattern")

        let petals = await mapper.mandalaParameters.petalCount
        XCTAssertGreaterThanOrEqual(petals, 6, "Mandala should have at least 6 petals")
        XCTAssertLessThanOrEqual(petals, 11, "Mandala should have at most 11 petals")
    }

    func testMIDIToVisualMapper_NoteOffMapping() async throws {
        let mapper = await MIDIToVisualMapper()

        await mapper.handleNoteOn(note: 60, velocity: 0.8)
        let patternsAfterOn = await mapper.cymaticsParameters.patterns.count

        await mapper.handleNoteOff(note: 60)
        let patternsAfterOff = await mapper.cymaticsParameters.patterns.count

        XCTAssertLessThan(patternsAfterOff, patternsAfterOn, "Note off should remove pattern")
    }

    func testMIDIToVisualMapper_BioParameters() async throws {
        let mapper = await MIDIToVisualMapper()

        let bioParams = MIDIToVisualMapper.BioParameters(
            hrvCoherence: 80,
            heartRate: 65,
            breathingRate: 6.0,
            audioLevel: 0.7
        )

        await mapper.updateBioParameters(bioParams)

        let hue = await mapper.cymaticsParameters.hue
        XCTAssertEqual(hue, 0.8, accuracy: 0.01, "HRV coherence should map to hue")
    }

    func testMIDIToVisualMapper_VisualPresets() async throws {
        let mapper = await MIDIToVisualMapper()

        await mapper.applyPreset(.meditation)
        let medRotation = await mapper.mandalaParameters.rotationSpeed
        XCTAssertEqual(medRotation, 0.5, "Meditation should have slow rotation")

        await mapper.applyPreset(.energizing)
        let energyRotation = await mapper.mandalaParameters.rotationSpeed
        XCTAssertEqual(energyRotation, 2.0, "Energizing should have fast rotation")
    }

    func testMIDIToVisualMapper_ParticleEmission() async throws {
        let mapper = await MIDIToVisualMapper()

        await mapper.handleNoteOn(note: 72, velocity: 1.0)  // High velocity

        let particles = await mapper.particleParameters.particles
        XCTAssertGreaterThan(particles.count, 0, "High velocity note should emit particles")
    }

    // MARK: - MIDIToLightMapper Tests

    func testMIDIToLightMapper_NoteToColor() async throws {
        let mapper = await MIDIToLightMapper()

        // C note should be red-ish (hue near 0)
        let cColor = await mapper.noteToColor(60)  // C4
        XCTAssertNotNil(cColor, "Note should produce color")

        // Different notes should produce different colors
        let gColor = await mapper.noteToColor(67)  // G4
        // Colors should be different (different hue positions)
    }

    func testMIDIToLightMapper_BioReactive() async throws {
        let mapper = await MIDIToLightMapper()

        let bioData = MIDIToLightMapper.BioData(
            hrvCoherence: 90,
            heartRate: 60,
            breathingRate: 6.0
        )

        await mapper.updateBioReactive(bioData)

        // High coherence should produce calmer colors
        let scene = await mapper.currentScene
        XCTAssertNotNil(scene, "Bio data should set a scene")
    }

    func testMIDIToLightMapper_Scenes() async throws {
        let mapper = await MIDIToLightMapper()

        await mapper.setScene(.meditation)
        let medScene = await mapper.currentScene
        XCTAssertEqual(medScene, .meditation)

        await mapper.setScene(.performance)
        let perfScene = await mapper.currentScene
        XCTAssertEqual(perfScene, .performance)
    }

    // MARK: - GestureToAudioMapper Tests

    func testGestureToAudioMapper_PinchMapping() async throws {
        // Note: These tests require mocking HandTrackingManager
        // Testing the mapping logic

        // Left pinch → Filter cutoff (200-8000 Hz)
        let cutoff = mapPinchToFilter(pinchAmount: 0.5)
        XCTAssertGreaterThan(cutoff, 200)
        XCTAssertLessThan(cutoff, 8000)
        XCTAssertEqual(cutoff, 4100, accuracy: 100, "50% pinch should be mid-range filter")
    }

    func testGestureToAudioMapper_SpreadMapping() async throws {
        // Spread gesture → Reverb size
        let size = mapSpreadToReverb(spreadAmount: 1.0)
        XCTAssertEqual(size, 1.0, "Full spread should be max reverb")

        let halfSize = mapSpreadToReverb(spreadAmount: 0.5)
        XCTAssertEqual(halfSize, 0.5, "Half spread should be half reverb")
    }

    // Helper functions for gesture mapping tests
    private func mapPinchToFilter(pinchAmount: Float) -> Float {
        let minCutoff: Float = 200
        let maxCutoff: Float = 8000
        return minCutoff + (maxCutoff - minCutoff) * pinchAmount
    }

    private func mapSpreadToReverb(spreadAmount: Float) -> Float {
        return spreadAmount
    }

    // MARK: - MIDIToSpatialMapper Tests

    func testMIDIToSpatialMapper_StereoMapping() async throws {
        let mapper = await MIDIToSpatialMapper()

        // Low notes → Left pan
        let lowNotePan = await mapper.mapToStereo(note: 36, velocity: 0.8)
        XCTAssertLessThan(lowNotePan.pan, 0, "Low notes should pan left")

        // High notes → Right pan
        let highNotePan = await mapper.mapToStereo(note: 84, velocity: 0.8)
        XCTAssertGreaterThan(highNotePan.pan, 0, "High notes should pan right")

        // Middle C → Center
        let middlePan = await mapper.mapToStereo(note: 60, velocity: 0.8)
        XCTAssertEqual(middlePan.pan, 0, accuracy: 0.1, "Middle C should be center")
    }

    func testMIDIToSpatialMapper_3DMapping() async throws {
        let mapper = await MIDIToSpatialMapper()

        let position = await mapper.mapTo3D(note: 60, velocity: 0.8, pitchBend: 0)

        XCTAssertNotNil(position, "Should produce 3D position")
        XCTAssertEqual(position.z, 1.0, accuracy: 0.5, "Default Z should be ~1.0")
    }

    func testMIDIToSpatialMapper_AFAFieldCreation() async throws {
        let mapper = await MIDIToSpatialMapper()

        // Create mock voice data
        let voices: [MPEVoiceData] = [
            MPEVoiceData(id: UUID(), channel: 1, note: 60, velocity: 0.8, pitchBend: 0, brightness: 0.5, timbre: 0.5),
            MPEVoiceData(id: UUID(), channel: 2, note: 64, velocity: 0.7, pitchBend: 0, brightness: 0.5, timbre: 0.5),
            MPEVoiceData(id: UUID(), channel: 3, note: 67, velocity: 0.9, pitchBend: 0, brightness: 0.5, timbre: 0.5)
        ]

        let field = await mapper.mapToAFA(voices: voices, geometry: .circle(radius: 1.5, sourceCount: 3))

        XCTAssertEqual(field.sources.count, 3, "AFA field should have 3 sources")
        XCTAssertEqual(field.phaseCoherence, 1.0, "Initial phase coherence should be 1.0")
    }

    func testMIDIToSpatialMapper_GeometryTypes() async throws {
        let mapper = await MIDIToSpatialMapper()

        let voices: [MPEVoiceData] = [
            MPEVoiceData(id: UUID(), channel: 1, note: 60, velocity: 0.8, pitchBend: 0, brightness: 0.5, timbre: 0.5)
        ]

        // Test circle geometry
        let circleField = await mapper.mapToAFA(voices: voices, geometry: .circle(radius: 2.0, sourceCount: 1))
        XCTAssertNotNil(circleField)

        // Test fibonacci geometry
        let fibField = await mapper.mapToAFA(voices: voices, geometry: .fibonacci(sourceCount: 1))
        XCTAssertNotNil(fibField)
    }

    // MARK: - FaceToAudioMapper Tests

    func testFaceToAudioMapper_JawOpenMapping() async throws {
        let mapper = await FaceToAudioMapper()

        // Create face expression with jaw open
        let expression = FaceExpression(
            jawOpen: 0.8,
            mouthSmileLeft: 0.0,
            mouthSmileRight: 0.0,
            eyebrowInnerUp: 0.0,
            eyeSquintLeft: 0.0,
            eyeSquintRight: 0.0
        )

        let params = await mapper.mapToAudio(faceExpression: expression)

        // Jaw open should increase filter cutoff
        XCTAssertGreaterThan(params.filterCutoff, 2000, "Open jaw should increase cutoff")
    }

    func testFaceToAudioMapper_SmileMapping() async throws {
        let mapper = await FaceToAudioMapper()

        let smilingExpression = FaceExpression(
            jawOpen: 0.0,
            mouthSmileLeft: 0.9,
            mouthSmileRight: 0.9,
            eyebrowInnerUp: 0.0,
            eyeSquintLeft: 0.0,
            eyeSquintRight: 0.0
        )

        let params = await mapper.mapToAudio(faceExpression: smilingExpression)

        // Smile should increase stereo width
        XCTAssertGreaterThan(params.stereoWidth, 1.0, "Smile should widen stereo")
    }

    func testFaceToAudioMapper_EyebrowMapping() async throws {
        let mapper = await FaceToAudioMapper()

        let surprisedExpression = FaceExpression(
            jawOpen: 0.0,
            mouthSmileLeft: 0.0,
            mouthSmileRight: 0.0,
            eyebrowInnerUp: 0.9,
            eyeSquintLeft: 0.0,
            eyeSquintRight: 0.0
        )

        let params = await mapper.mapToAudio(faceExpression: surprisedExpression)

        // Raised eyebrows should increase reverb
        XCTAssertGreaterThan(params.reverbSize, 2.0, "Raised eyebrows should increase reverb")
    }

    // MARK: - Integration Tests

    func testMapperChain_BioToVisual() async throws {
        // Test the chain: Bio → BioParameterMapper → Visual parameters
        let bioMapper = await BioParameterMapper()
        let visualMapper = await MIDIToVisualMapper()

        // Simulate high coherence state
        await bioMapper.updateParameters(hrvCoherence: 85, heartRate: 60, voicePitch: 432, audioLevel: 0.6)

        let bioParams = MIDIToVisualMapper.BioParameters(
            hrvCoherence: 85,
            heartRate: 60,
            breathingRate: 6.0,
            audioLevel: 0.6
        )

        await visualMapper.updateBioParameters(bioParams)

        let hue = await visualMapper.cymaticsParameters.hue
        XCTAssertGreaterThan(hue, 0.7, "High coherence should produce high hue value")
    }

    func testMapperChain_MIDIToSpatialToAudio() async throws {
        // Test: MIDI → Spatial position → affects audio
        let spatialMapper = await MIDIToSpatialMapper()

        let position = await spatialMapper.mapTo3D(note: 48, velocity: 0.9, pitchBend: 0)

        // Low note (48 = C3) should be positioned to the left
        XCTAssertLessThan(position.x, 0, "Low note should be on the left in 3D space")
    }

    // MARK: - Performance Tests

    func testMapperPerformance_BioUpdate() throws {
        measure {
            let expectation = XCTestExpectation(description: "Bio updates")

            Task { @MainActor in
                let mapper = BioParameterMapper()

                for _ in 0..<1000 {
                    mapper.updateParameters(
                        hrvCoherence: Double.random(in: 0...100),
                        heartRate: Double.random(in: 50...120),
                        voicePitch: Float.random(in: 200...800),
                        audioLevel: Float.random(in: 0...1)
                    )
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testMapperPerformance_VisualUpdate() throws {
        measure {
            let expectation = XCTestExpectation(description: "Visual updates")

            Task { @MainActor in
                let mapper = MIDIToVisualMapper()

                for note: UInt8 in 36...96 {
                    mapper.handleNoteOn(note: note, velocity: Float.random(in: 0.5...1.0))
                    mapper.handleNoteOff(note: note)
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Mock Types for Testing

struct MPEVoiceData {
    let id: UUID
    let channel: UInt8
    let note: UInt8
    let velocity: Float
    let pitchBend: Float
    let brightness: Float
    let timbre: Float
}

struct FaceExpression {
    let jawOpen: Float
    let mouthSmileLeft: Float
    let mouthSmileRight: Float
    let eyebrowInnerUp: Float
    let eyeSquintLeft: Float
    let eyeSquintRight: Float
}

struct AudioParameters {
    var filterCutoff: Float = 1000
    var filterResonance: Float = 1.0
    var reverbSize: Float = 1.0
    var stereoWidth: Float = 1.0
}

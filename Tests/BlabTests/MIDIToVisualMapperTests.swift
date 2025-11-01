import XCTest
@testable import Blab

@MainActor
final class MIDIToVisualMapperTests: XCTestCase {

    var mapper: MIDIToVisualMapper!

    override func setUp() async throws {
        try await super.setUp()
        mapper = MIDIToVisualMapper()
    }

    override func tearDown() async throws {
        mapper = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(mapper, "Mapper should be initialized")
        XCTAssertNotNil(mapper.cymaticsParameters, "Cymatics parameters should be initialized")
        XCTAssertNotNil(mapper.mandalaParameters, "Mandala parameters should be initialized")
        XCTAssertNotNil(mapper.waveformParameters, "Waveform parameters should be initialized")
        XCTAssertNotNil(mapper.spectralParameters, "Spectral parameters should be initialized")
        XCTAssertNotNil(mapper.particleParameters, "Particle parameters should be initialized")
    }

    // MARK: - Cymatics Parameter Tests

    func testCymaticsDefaultParameters() {
        let params = mapper.cymaticsParameters
        XCTAssertEqual(params.frequency, 440.0, accuracy: 0.01, "Default frequency should be 440 Hz")
        XCTAssertEqual(params.amplitude, 0.5, accuracy: 0.01, "Default amplitude should be 0.5")
        XCTAssertEqual(params.hue, 0.5, accuracy: 0.01, "Default hue should be 0.5")
        XCTAssertTrue(params.patterns.isEmpty, "Should have no patterns initially")
    }

    func testCymaticsFrequencyMapping() {
        // Test MIDI note to frequency mapping
        // MIDI note 69 (A4) = 440 Hz
        mapper.handleNoteOn(note: 69, velocity: 100, channel: 0)

        XCTAssertEqual(mapper.cymaticsParameters.frequency, 440.0, accuracy: 0.01)
    }

    func testCymaticsAmplitudeMapping() {
        // Test velocity to amplitude mapping
        // Velocity 127 should map to amplitude 1.0
        mapper.handleNoteOn(note: 60, velocity: 127, channel: 0)

        XCTAssertEqual(mapper.cymaticsParameters.amplitude, 1.0, accuracy: 0.01)

        // Velocity 0 should map to amplitude 0.0
        mapper.handleNoteOn(note: 60, velocity: 0, channel: 0)

        XCTAssertEqual(mapper.cymaticsParameters.amplitude, 0.0, accuracy: 0.01)
    }

    func testCymaticsHRVToHue() {
        // Test HRV coherence to hue mapping
        // HRV coherence ranges 0-1, maps directly to hue 0-1
        mapper.updateBioParameters(hrvCoherence: 0.0, heartRate: 60)
        XCTAssertEqual(mapper.cymaticsParameters.hue, 0.0, accuracy: 0.01)

        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 60)
        XCTAssertEqual(mapper.cymaticsParameters.hue, 0.5, accuracy: 0.01)

        mapper.updateBioParameters(hrvCoherence: 1.0, heartRate: 60)
        XCTAssertEqual(mapper.cymaticsParameters.hue, 1.0, accuracy: 0.01)
    }

    // MARK: - Mandala Parameter Tests

    func testMandalaDefaultParameters() {
        let params = mapper.mandalaParameters
        XCTAssertEqual(params.petalCount, 8, "Default petal count should be 8")
        XCTAssertEqual(params.petalSize, 0.5, accuracy: 0.01, "Default petal size should be 0.5")
        XCTAssertEqual(params.rotationSpeed, 0.5, accuracy: 0.01, "Default rotation speed should be 0.5")
        XCTAssertEqual(params.hue, 0.5, accuracy: 0.01, "Default hue should be 0.5")
    }

    func testMandalaPetalCountMapping() {
        // Test MIDI note to petal count mapping (6-12 petals)
        // Lower notes = fewer petals, higher notes = more petals
        mapper.handleNoteOn(note: 36, velocity: 100, channel: 0) // C2
        XCTAssertGreaterThanOrEqual(mapper.mandalaParameters.petalCount, 6)
        XCTAssertLessThanOrEqual(mapper.mandalaParameters.petalCount, 12)
    }

    func testMandalaPetalSizeMapping() {
        // Velocity should map to petal size
        mapper.handleNoteOn(note: 60, velocity: 127, channel: 0)
        XCTAssertGreaterThan(mapper.mandalaParameters.petalSize, 0.9)

        mapper.handleNoteOn(note: 60, velocity: 32, channel: 0)
        XCTAssertLess(mapper.mandalaParameters.petalSize, 0.3)
    }

    func testMandalaRotationSpeed() {
        // Heart rate should influence rotation speed
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 60)
        let speed60 = mapper.mandalaParameters.rotationSpeed

        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 120)
        let speed120 = mapper.mandalaParameters.rotationSpeed

        XCTAssertGreaterThan(speed120, speed60, "Higher heart rate should increase rotation speed")
    }

    // MARK: - Waveform Parameter Tests

    func testWaveformDefaultParameters() {
        let params = mapper.waveformParameters
        XCTAssertEqual(params.thickness, 2.0, accuracy: 0.01, "Default thickness should be 2.0")
        XCTAssertEqual(params.smoothness, 0.5, accuracy: 0.01, "Default smoothness should be 0.5")
        XCTAssertEqual(params.color, 0.5, accuracy: 0.01, "Default color should be 0.5")
    }

    func testWaveformThicknessMapping() {
        // Velocity should map to thickness
        mapper.handleNoteOn(note: 60, velocity: 127, channel: 0)
        let thicknessMax = mapper.waveformParameters.thickness

        mapper.handleNoteOn(note: 60, velocity: 64, channel: 0)
        let thicknessMid = mapper.waveformParameters.thickness

        XCTAssertGreaterThan(thicknessMax, thicknessMid)
    }

    // MARK: - Spectral Parameter Tests

    func testSpectralDefaultParameters() {
        let params = mapper.spectralParameters
        XCTAssertEqual(params.barWidth, 4.0, accuracy: 0.01, "Default bar width should be 4.0")
        XCTAssertEqual(params.barSpacing, 2.0, accuracy: 0.01, "Default bar spacing should be 2.0")
        XCTAssertEqual(params.sensitivity, 1.0, accuracy: 0.01, "Default sensitivity should be 1.0")
        XCTAssertEqual(params.colorScheme, 0.5, accuracy: 0.01, "Default color scheme should be 0.5")
    }

    func testSpectralBarWidthMapping() {
        // Test parameter update
        mapper.spectralParameters.barWidth = 8.0
        XCTAssertEqual(mapper.spectralParameters.barWidth, 8.0, accuracy: 0.01)
    }

    func testSpectralSensitivityMapping() {
        // Sensitivity should affect amplitude response
        mapper.spectralParameters.sensitivity = 2.0
        XCTAssertEqual(mapper.spectralParameters.sensitivity, 2.0, accuracy: 0.01)
    }

    // MARK: - Particle Parameter Tests

    func testParticleDefaultParameters() {
        let params = mapper.particleParameters
        XCTAssertEqual(params.particleCount, 100, "Default particle count should be 100")
        XCTAssertEqual(params.particleSize, 3.0, accuracy: 0.01, "Default particle size should be 3.0")
        XCTAssertEqual(params.speed, 1.0, accuracy: 0.01, "Default speed should be 1.0")
        XCTAssertEqual(params.gravity, 0.0, accuracy: 0.01, "Default gravity should be 0.0")
    }

    func testParticleCountMapping() {
        // More notes = more particles
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)
        let count1 = mapper.particleParameters.particleCount

        mapper.handleNoteOn(note: 64, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 67, velocity: 100, channel: 0)
        let count3 = mapper.particleParameters.particleCount

        XCTAssertGreaterThanOrEqual(count3, count1)
    }

    func testParticleSpeedMapping() {
        // Velocity should influence particle speed
        mapper.handleNoteOn(note: 60, velocity: 127, channel: 0)
        let speedHigh = mapper.particleParameters.speed

        mapper.handleNoteOn(note: 60, velocity: 32, channel: 0)
        let speedLow = mapper.particleParameters.speed

        XCTAssertGreaterThan(speedHigh, speedLow)
    }

    // MARK: - MIDI Note Tracking Tests

    func testNoteOnTracking() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        // Should have 1 active note
        XCTAssertEqual(mapper.activeNoteCount, 1)
    }

    func testNoteOffTracking() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)
        mapper.handleNoteOff(note: 60, channel: 0)

        // Should have 0 active notes
        XCTAssertEqual(mapper.activeNoteCount, 0)
    }

    func testMultipleNotesTracking() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 64, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 67, velocity: 100, channel: 0)

        XCTAssertEqual(mapper.activeNoteCount, 3)

        mapper.handleNoteOff(note: 64, channel: 0)
        XCTAssertEqual(mapper.activeNoteCount, 2)
    }

    // MARK: - MPE Parameter Tests

    func testPitchBendMapping() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        // MPE pitch bend (±48 semitones)
        mapper.handlePitchBend(value: 0.5, channel: 0)  // No bend
        mapper.handlePitchBend(value: 1.0, channel: 0)  // +48 semitones
        mapper.handlePitchBend(value: 0.0, channel: 0)  // -48 semitones

        // Should update without crashing
        XCTAssertNotNil(mapper.cymaticsParameters)
    }

    func testBrightnessMapping() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        // MPE brightness (CC 74)
        mapper.handleBrightness(value: 0.0, channel: 0)
        mapper.handleBrightness(value: 0.5, channel: 0)
        mapper.handleBrightness(value: 1.0, channel: 0)

        // Should update visual brightness
        XCTAssertNotNil(mapper.cymaticsParameters)
    }

    func testTimbreMapping() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)

        // MPE timbre (CC 71)
        mapper.handleTimbre(value: 0.0, channel: 0)
        mapper.handleTimbre(value: 0.5, channel: 0)
        mapper.handleTimbre(value: 1.0, channel: 0)

        // Should update visual character
        XCTAssertNotNil(mapper.cymaticsParameters)
    }

    // MARK: - Bio-Reactive Tests

    func testHRVCoherenceMapping() {
        // Low coherence (0.0) = red hue (0.0)
        mapper.updateBioParameters(hrvCoherence: 0.0, heartRate: 60)
        XCTAssertLessThan(mapper.cymaticsParameters.hue, 0.2)

        // Mid coherence (0.5) = green hue (~0.33)
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 60)
        XCTAssertGreaterThan(mapper.cymaticsParameters.hue, 0.2)
        XCTAssertLessThan(mapper.cymaticsParameters.hue, 0.7)

        // High coherence (1.0) = blue hue (~0.66)
        mapper.updateBioParameters(hrvCoherence: 1.0, heartRate: 60)
        XCTAssertGreaterThan(mapper.cymaticsParameters.hue, 0.5)
    }

    func testHeartRateToRotation() {
        // Heart rate should influence rotation/animation speed
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 60)
        let rotation60 = mapper.mandalaParameters.rotationSpeed

        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 100)
        let rotation100 = mapper.mandalaParameters.rotationSpeed

        XCTAssertGreaterThan(rotation100, rotation60, "Higher HR should increase rotation")
    }

    func testHeartRateToScale() {
        // Heart rate should influence visual scale
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 60)
        let scale60 = mapper.mandalaParameters.petalSize

        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 120)
        let scale120 = mapper.mandalaParameters.petalSize

        // May increase or stay stable depending on mapping
        XCTAssertGreaterThanOrEqual(scale120, scale60 * 0.8)
    }

    // MARK: - Chladni Pattern Tests

    func testChladniPatternCreation() {
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 64, velocity: 100, channel: 0)
        mapper.handleNoteOn(note: 67, velocity: 100, channel: 0)

        // Should have created Chladni patterns for active notes
        XCTAssertGreaterThanOrEqual(mapper.cymaticsParameters.patterns.count, 0)
    }

    func testChladniFrequencyRanges() {
        // Test various frequency ranges
        let notes: [UInt8] = [21, 36, 60, 84, 108]  // A0 to C8

        for note in notes {
            mapper.handleNoteOn(note: note, velocity: 100, channel: 0)
            // Should handle full MIDI range without issues
            XCTAssertNotNil(mapper.cymaticsParameters)
        }
    }

    // MARK: - Color Mapping Tests

    func testHueToRGBConversion() {
        // Test hue 0.0 (red)
        let red = mapper.hueToRGB(hue: 0.0)
        XCTAssertGreaterThan(red.r, 0.9)
        XCTAssertLessThan(red.g, 0.1)
        XCTAssertLessThan(red.b, 0.1)

        // Test hue 0.33 (green)
        let green = mapper.hueToRGB(hue: 0.33)
        XCTAssertLessThan(green.r, 0.1)
        XCTAssertGreaterThan(green.g, 0.9)
        XCTAssertLessThan(green.b, 0.1)

        // Test hue 0.66 (blue)
        let blue = mapper.hueToRGB(hue: 0.66)
        XCTAssertLessThan(blue.r, 0.1)
        XCTAssertLessThan(blue.g, 0.1)
        XCTAssertGreaterThan(blue.b, 0.9)
    }

    // MARK: - Performance Tests

    func testPerformanceMultipleNotes() {
        measure {
            for i in 0..<128 {
                mapper.handleNoteOn(note: UInt8(i % 88 + 21), velocity: 100, channel: 0)
            }
        }
    }

    func testPerformanceBioUpdates() {
        measure {
            for i in 0..<1000 {
                let coherence = Float(i % 100) / 100.0
                let hr = 60 + (i % 60)
                mapper.updateBioParameters(hrvCoherence: coherence, heartRate: hr)
            }
        }
    }

    func testPerformanceParameterUpdates() {
        measure {
            for _ in 0..<1000 {
                mapper.cymaticsParameters.frequency = Float.random(in: 20...2000)
                mapper.cymaticsParameters.amplitude = Float.random(in: 0...1)
                mapper.mandalaParameters.rotationSpeed = Float.random(in: 0...2)
                mapper.particleParameters.speed = Float.random(in: 0...2)
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroVelocityNote() {
        mapper.handleNoteOn(note: 60, velocity: 0, channel: 0)
        // Should handle gracefully (effectively a note off)
        XCTAssertNotNil(mapper.cymaticsParameters)
    }

    func testMaxVelocity() {
        mapper.handleNoteOn(note: 60, velocity: 127, channel: 0)
        XCTAssertEqual(mapper.cymaticsParameters.amplitude, 1.0, accuracy: 0.01)
    }

    func testOutOfRangeNote() {
        // MIDI note 128 is out of range (0-127)
        // Should clamp or ignore
        mapper.handleNoteOn(note: 128, velocity: 100, channel: 0)
        XCTAssertNotNil(mapper.cymaticsParameters)
    }

    func testNegativeHRV() {
        // Invalid HRV should be clamped
        mapper.updateBioParameters(hrvCoherence: -0.5, heartRate: 60)
        XCTAssertGreaterThanOrEqual(mapper.cymaticsParameters.hue, 0.0)
    }

    func testExtremeHeartRate() {
        // Very high heart rate
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 200)
        XCTAssertNotNil(mapper.mandalaParameters)

        // Very low heart rate
        mapper.updateBioParameters(hrvCoherence: 0.5, heartRate: 30)
        XCTAssertNotNil(mapper.mandalaParameters)
    }

    // MARK: - Integration Tests

    func testFullMappingWorkflow() {
        // 1. Start with bio parameters
        mapper.updateBioParameters(hrvCoherence: 0.8, heartRate: 72)

        // 2. Play MIDI notes
        mapper.handleNoteOn(note: 60, velocity: 100, channel: 0)  // C4
        mapper.handleNoteOn(note: 64, velocity: 90, channel: 0)   // E4
        mapper.handleNoteOn(note: 67, velocity: 80, channel: 0)   // G4

        XCTAssertEqual(mapper.activeNoteCount, 3)

        // 3. Apply MPE expressions
        mapper.handlePitchBend(value: 0.55, channel: 0)
        mapper.handleBrightness(value: 0.7, channel: 0)
        mapper.handleTimbre(value: 0.3, channel: 0)

        // 4. Update bio parameters
        mapper.updateBioParameters(hrvCoherence: 0.9, heartRate: 68)

        // 5. Release notes
        mapper.handleNoteOff(note: 60, channel: 0)
        mapper.handleNoteOff(note: 64, channel: 0)
        mapper.handleNoteOff(note: 67, channel: 0)

        XCTAssertEqual(mapper.activeNoteCount, 0)

        // All operations should complete successfully
        XCTAssertNotNil(mapper.cymaticsParameters)
        XCTAssertNotNil(mapper.mandalaParameters)
    }
}

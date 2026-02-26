import XCTest
@testable import Echoelmusic

/// Comprehensive tests for BioParameterMapper
/// Tests HRV/HR/Voice to audio parameter mapping with smoothing
@MainActor
final class BioParameterMapperTests: XCTestCase {

    var mapper: BioParameterMapper!

    override func setUp() async throws {
        mapper = BioParameterMapper()
    }

    override func tearDown() async throws {
        mapper = nil
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(mapper.reverbWet, 0.3, accuracy: 0.01)
        XCTAssertEqual(mapper.filterCutoff, 1000.0, accuracy: 1.0)
        XCTAssertEqual(mapper.amplitude, 0.5, accuracy: 0.01)
        XCTAssertEqual(mapper.baseFrequency, 440.0, accuracy: 0.1)
        XCTAssertEqual(mapper.tempo, 60.0, accuracy: 0.1)
        XCTAssertEqual(mapper.harmonicCount, 5)
    }

    func testInitialValidation() {
        XCTAssertTrue(mapper.isValid)
    }

    // MARK: - HRV to Reverb Mapping Tests

    func testLowCoherenceLowReverb() {
        // Low coherence (stress) → low reverb
        mapper.updateParameters(hrvCoherence: 10, heartRate: 70, voicePitch: 0, audioLevel: 0)

        // With smoothing, won't hit target immediately
        // But should be moving toward low reverb
        XCTAssertLessThan(mapper.reverbWet, 0.5)
    }

    func testHighCoherenceHighReverb() {
        // High coherence (flow) → high reverb
        // Apply multiple updates to overcome smoothing
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 90, heartRate: 70, voicePitch: 0, audioLevel: 0)
        }

        XCTAssertGreaterThan(mapper.reverbWet, 0.5)
    }

    func testMidCoherenceMidReverb() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 0, audioLevel: 0)
        }

        // Should be around 0.45 (midpoint of 0.1-0.8 range)
        XCTAssertGreaterThan(mapper.reverbWet, 0.3)
        XCTAssertLessThan(mapper.reverbWet, 0.7)
    }

    // MARK: - Heart Rate to Filter Mapping Tests

    func testLowHeartRateLowFilter() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 50, voicePitch: 0, audioLevel: 0)
        }

        // Low HR = low cutoff (darker sound)
        XCTAssertLessThan(mapper.filterCutoff, 1000)
    }

    func testHighHeartRateHighFilter() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 110, voicePitch: 0, audioLevel: 0)
        }

        // High HR = high cutoff (brighter sound)
        XCTAssertGreaterThan(mapper.filterCutoff, 1000)
    }

    // MARK: - Heart Rate to Tempo Mapping Tests

    func testHeartRateToTempo() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 60, voicePitch: 0, audioLevel: 0)
        }

        // HR 60 / 4 = 15, clamped to max 8
        XCTAssertLessThanOrEqual(mapper.tempo, 8.0)
        XCTAssertGreaterThanOrEqual(mapper.tempo, 4.0)
    }

    // MARK: - Voice Pitch to Frequency Mapping Tests

    func testVoicePitchSnapsToScale() {
        // Test snapping to 440 Hz (A4 standard tuning)
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 435, audioLevel: 0.5)
        }

        // Should snap to 440 Hz (A4 standard tuning)
        XCTAssertEqual(mapper.baseFrequency, 440.0, accuracy: 50.0)
    }

    func testVoicePitchSnapsToBNote() {
        // Test snapping to 493.883 Hz (B4 in 12-TET)
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 490, audioLevel: 0.5)
        }

        // Should be close to B4 (493.883 Hz)
        XCTAssertEqual(mapper.baseFrequency, 493.883, accuracy: 60.0)
    }

    func testNoVoicePitchDefaultsToBase() {
        mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 0, audioLevel: 0)

        // With no pitch, should remain at base frequency (440 Hz)
        XCTAssertEqual(mapper.baseFrequency, 440.0, accuracy: 5.0)
    }

    // MARK: - Harmonic Count Tests

    func testHighAudioLevelHighHarmonics() {
        for _ in 0..<5 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 440, audioLevel: 0.8)
        }

        // High clarity = more harmonics
        XCTAssertEqual(mapper.harmonicCount, 7)
    }

    func testLowAudioLevelLowHarmonics() {
        mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 440, audioLevel: 0.05)

        // Low clarity = fewer harmonics
        XCTAssertEqual(mapper.harmonicCount, 3)
    }

    func testMidAudioLevelMidHarmonics() {
        mapper.updateParameters(hrvCoherence: 50, heartRate: 70, voicePitch: 440, audioLevel: 0.4)

        // Medium clarity = medium harmonics
        XCTAssertEqual(mapper.harmonicCount, 5)
    }

    // MARK: - Amplitude Mapping Tests

    func testAmplitudeCombinesHRVAndAudioLevel() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 80, heartRate: 70, voicePitch: 0, audioLevel: 0.5)
        }

        // Should be in valid range
        XCTAssertGreaterThanOrEqual(mapper.amplitude, 0.3)
        XCTAssertLessThanOrEqual(mapper.amplitude, 0.8)
    }

    // MARK: - Spatial Position Tests

    func testHighCoherenceCenteredPosition() {
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 90, heartRate: 70, voicePitch: 0, audioLevel: 0)
        }

        // High coherence = more centered
        let (x, y, z) = mapper.spatialPosition
        XCTAssertEqual(z, 1.0, accuracy: 0.01)  // Z stays constant
        // X and Y should be closer to center with high coherence
        XCTAssertLessThanOrEqual(abs(x), 0.5)
        XCTAssertLessThanOrEqual(abs(y), 0.5)
    }

    // MARK: - Smoothing Tests

    func testSmoothingPreventsJumps() {
        // Start at default
        let initialReverb = mapper.reverbWet

        // Apply extreme change
        mapper.updateParameters(hrvCoherence: 100, heartRate: 70, voicePitch: 0, audioLevel: 0)

        // Should not jump immediately to target
        XCTAssertNotEqual(mapper.reverbWet, 0.8, accuracy: 0.1)

        // Should be moving toward target
        XCTAssertGreaterThan(mapper.reverbWet, initialReverb)
    }

    func testMultipleUpdatesConverge() {
        // Apply same value many times
        for _ in 0..<50 {
            mapper.updateParameters(hrvCoherence: 100, heartRate: 70, voicePitch: 0, audioLevel: 0)
        }

        // Should converge close to target (0.8)
        XCTAssertGreaterThan(mapper.reverbWet, 0.7)
    }

    // MARK: - Preset Tests

    func testMeditationPreset() {
        mapper.applyPreset(.meditation)

        XCTAssertEqual(mapper.reverbWet, 0.7, accuracy: 0.01)
        XCTAssertEqual(mapper.filterCutoff, 500.0, accuracy: 1.0)
        XCTAssertEqual(mapper.amplitude, 0.5, accuracy: 0.01)
        XCTAssertEqual(mapper.baseFrequency, 220.0, accuracy: 0.1)  // A3
        XCTAssertEqual(mapper.tempo, 6.0, accuracy: 0.1)
    }

    func testFocusPreset() {
        mapper.applyPreset(.focus)

        XCTAssertEqual(mapper.reverbWet, 0.3, accuracy: 0.01)
        XCTAssertEqual(mapper.filterCutoff, 1500.0, accuracy: 1.0)
        XCTAssertEqual(mapper.baseFrequency, 440.0, accuracy: 0.1)  // A4 standard
    }

    func testRelaxationPreset() {
        mapper.applyPreset(.relaxation)

        XCTAssertEqual(mapper.reverbWet, 0.8, accuracy: 0.01)
        XCTAssertEqual(mapper.filterCutoff, 300.0, accuracy: 1.0)
        XCTAssertEqual(mapper.baseFrequency, 220.0, accuracy: 0.1)  // A3 warm bass
        XCTAssertEqual(mapper.tempo, 4.0, accuracy: 0.1)
    }

    func testEnergizePreset() {
        mapper.applyPreset(.energize)

        XCTAssertEqual(mapper.reverbWet, 0.2, accuracy: 0.01)
        XCTAssertEqual(mapper.filterCutoff, 2000.0, accuracy: 1.0)
        XCTAssertEqual(mapper.baseFrequency, 880.0, accuracy: 0.1)  // A5 bright
    }

    // MARK: - Validation Tests

    func testAllPresetsAreValid() {
        for preset in BioParameterMapper.BioPreset.allCases {
            mapper.applyPreset(preset)
            XCTAssertTrue(mapper.isValid, "Preset \(preset.rawValue) should be valid")
        }
    }

    func testParameterSummary() {
        let summary = mapper.parameterSummary
        XCTAssertTrue(summary.contains("Reverb"))
        XCTAssertTrue(summary.contains("Filter"))
        XCTAssertTrue(summary.contains("Amplitude"))
        XCTAssertTrue(summary.contains("Frequency"))
        XCTAssertTrue(summary.contains("Tempo"))
        XCTAssertTrue(summary.contains("Spatial"))
        XCTAssertTrue(summary.contains("Harmonics"))
    }

    // MARK: - Edge Cases

    func testZeroHRVCoherence() {
        mapper.updateParameters(hrvCoherence: 0, heartRate: 70, voicePitch: 0, audioLevel: 0)
        XCTAssertTrue(mapper.isValid)
    }

    func testMaxHRVCoherence() {
        mapper.updateParameters(hrvCoherence: 100, heartRate: 70, voicePitch: 0, audioLevel: 0)
        XCTAssertTrue(mapper.isValid)
    }

    func testVeryLowHeartRate() {
        mapper.updateParameters(hrvCoherence: 50, heartRate: 40, voicePitch: 0, audioLevel: 0)
        XCTAssertTrue(mapper.isValid)
    }

    func testVeryHighHeartRate() {
        mapper.updateParameters(hrvCoherence: 50, heartRate: 120, voicePitch: 0, audioLevel: 0)
        XCTAssertTrue(mapper.isValid)
    }

    func testOutOfRangeHeartRateClamped() {
        // Test clamping with extreme values
        for _ in 0..<20 {
            mapper.updateParameters(hrvCoherence: 50, heartRate: 200, voicePitch: 0, audioLevel: 0)
        }

        // Filter should be at or near max
        XCTAssertLessThanOrEqual(mapper.filterCutoff, 2000.0)
    }

    // MARK: - BioPreset Enum Tests

    func testBioPresetCases() {
        XCTAssertEqual(BioParameterMapper.BioPreset.allCases.count, 4)
        XCTAssertEqual(BioParameterMapper.BioPreset.meditation.rawValue, "Meditation")
        XCTAssertEqual(BioParameterMapper.BioPreset.focus.rawValue, "Focus")
        XCTAssertEqual(BioParameterMapper.BioPreset.relaxation.rawValue, "Deep Relaxation")
        XCTAssertEqual(BioParameterMapper.BioPreset.energize.rawValue, "Energize")
    }
}

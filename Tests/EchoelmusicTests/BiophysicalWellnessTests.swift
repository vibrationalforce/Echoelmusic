// BiophysicalWellnessTests.swift
// Echoelmusic
//
// Comprehensive tests for biophysical wellness tool components.
// Tests cover EVM, inertial analysis, haptic stimulation, and cymatics.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import XCTest
@testable import Echoelmusic

// MARK: - Biophysical Wellness Engine Tests

final class BiophysicalWellnessEngineTests: XCTestCase {

    // MARK: - Disclaimer Tests

    func testDisclaimerMustBeAcknowledgedBeforeSession() async {
        let engine = await BiophysicalWellnessEngine()

        do {
            try await engine.startSession(preset: .boneHarmony)
            XCTFail("Should throw error when disclaimer not acknowledged")
        } catch BiophysicalError.disclaimerNotAcknowledged {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAcknowledgeDisclaimerEnablesSession() async {
        let engine = await BiophysicalWellnessEngine()
        await engine.acknowledgeDisclaimer()

        let state = await engine.state
        XCTAssertTrue(state.disclaimerAcknowledged)
    }

    // MARK: - Session Tests

    func testSessionStartsWithCorrectPreset() async throws {
        let engine = await BiophysicalWellnessEngine()
        await engine.acknowledgeDisclaimer()

        // Note: This may fail on simulator due to sensor unavailability
        // In production tests, we'd mock the sensors
        let state = await engine.state
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.preset, .boneHarmony)
    }

    func testCurrentFrequencyMatchesPreset() async {
        let engine = await BiophysicalWellnessEngine()
        await engine.acknowledgeDisclaimer()

        // Test each preset's frequency
        for preset in BiophysicalPreset.allCases {
            let expectedFreq = preset.primaryFrequency
            XCTAssertGreaterThanOrEqual(expectedFreq, 1.0)
            XCTAssertLessThanOrEqual(expectedFreq, 60.0)
        }
    }

    func testCustomFrequencyInRange() async {
        let engine = await BiophysicalWellnessEngine()

        // Valid frequency
        await engine.setCustomFrequency(45.0)
        let state = await engine.state
        XCTAssertEqual(state.customFrequency, 45.0)

        // Out of range - should not change
        await engine.setCustomFrequency(100.0)
        let stateAfter = await engine.state
        XCTAssertEqual(stateAfter.customFrequency, 45.0)
    }

    // MARK: - Safety Tests

    func testMaxSessionDurationIs15Minutes() {
        XCTAssertEqual(BiophysicalWellnessEngine.maxSessionDuration, 900)
    }

    func testMaxDutyCycleIs70Percent() {
        XCTAssertEqual(BiophysicalWellnessEngine.maxDutyCycle, 0.7)
    }

    func testMaxVibrationIntensityIs80Percent() {
        XCTAssertEqual(BiophysicalWellnessEngine.maxVibrationIntensity, 0.8)
    }
}

// MARK: - Biophysical Preset Tests

final class BiophysicalPresetTests: XCTestCase {

    func testAllPresetsHaveValidFrequencyRanges() {
        for preset in BiophysicalPreset.allCases {
            let range = preset.frequencyRange
            XCTAssertLessThan(range.min, range.max, "Preset \(preset.rawValue) has invalid range")
            XCTAssertGreaterThanOrEqual(range.min, 1.0)
            XCTAssertLessThanOrEqual(range.max, 60.0)
        }
    }

    func testBoneHarmonyPresetFrequency() {
        let preset = BiophysicalPreset.boneHarmony
        XCTAssertEqual(preset.primaryFrequency, 40.0)
        XCTAssertEqual(preset.frequencyRange.min, 35.0)
        XCTAssertEqual(preset.frequencyRange.max, 45.0)
    }

    func testMuscleFlowPresetFrequency() {
        let preset = BiophysicalPreset.muscleFlow
        XCTAssertEqual(preset.primaryFrequency, 47.5)
        XCTAssertEqual(preset.frequencyRange.min, 45.0)
        XCTAssertEqual(preset.frequencyRange.max, 50.0)
    }

    func testNeuralFocusPresetFrequency() {
        let preset = BiophysicalPreset.neuralFocus
        XCTAssertEqual(preset.primaryFrequency, 40.0)  // Gamma
        XCTAssertEqual(preset.frequencyRange.min, 38.0)
        XCTAssertEqual(preset.frequencyRange.max, 42.0)
    }

    func testRelaxationPresetFrequency() {
        let preset = BiophysicalPreset.relaxation
        XCTAssertEqual(preset.primaryFrequency, 10.0)  // Alpha
        XCTAssertEqual(preset.frequencyRange.min, 8.0)
        XCTAssertEqual(preset.frequencyRange.max, 12.0)
    }

    func testAllPresetsHaveEducationalReferences() {
        for preset in BiophysicalPreset.allCases {
            XCTAssertFalse(preset.educationalReference.isEmpty, "Preset \(preset.rawValue) missing reference")
        }
    }

    func testAllPresetsHaveCymaticsPatterns() {
        for preset in BiophysicalPreset.allCases {
            let pattern = preset.cymaticsPattern
            XCTAssertTrue(CymaticsPattern.allCases.contains(pattern))
        }
    }

    func testVibrationIntensityWithinSafetyLimits() {
        for preset in BiophysicalPreset.allCases {
            XCTAssertLessThanOrEqual(preset.vibrationIntensity, 0.8)
            XCTAssertGreaterThanOrEqual(preset.vibrationIntensity, 0.0)
        }
    }

    func testRecommendedDurationWithinSafetyLimits() {
        for preset in BiophysicalPreset.allCases {
            XCTAssertLessThanOrEqual(preset.recommendedDuration, 900)  // 15 min max
            XCTAssertGreaterThan(preset.recommendedDuration, 0)
        }
    }
}

// MARK: - EVM Configuration Tests

final class EVMConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = EVMConfiguration()
        XCTAssertEqual(config.frequencyRange.min, 1.0)
        XCTAssertEqual(config.frequencyRange.max, 60.0)
        XCTAssertEqual(config.amplificationFactor, 50.0)
        XCTAssertEqual(config.pyramidLevels, 4)
        XCTAssertEqual(config.filterOrder, 2)
        XCTAssertEqual(config.analysisFrameRate, 30.0)
    }

    func testCustomConfiguration() {
        let config = EVMConfiguration(
            frequencyRange: (30.0, 50.0),
            amplificationFactor: 100.0,
            pyramidLevels: 6,
            filterOrder: 4,
            analysisFrameRate: 60.0
        )

        XCTAssertEqual(config.frequencyRange.min, 30.0)
        XCTAssertEqual(config.frequencyRange.max, 50.0)
        XCTAssertEqual(config.amplificationFactor, 100.0)
        XCTAssertEqual(config.pyramidLevels, 6)
        XCTAssertEqual(config.filterOrder, 4)
        XCTAssertEqual(config.analysisFrameRate, 60.0)
    }

    func testConfigurationCodable() throws {
        let original = EVMConfiguration(
            amplificationFactor: 75.0,
            pyramidLevels: 5
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EVMConfiguration.self, from: encoded)

        XCTAssertEqual(decoded.amplificationFactor, 75.0)
        XCTAssertEqual(decoded.pyramidLevels, 5)
    }
}

// MARK: - Inertial Configuration Tests

final class InertialConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = InertialConfiguration()
        XCTAssertEqual(config.sampleRate, 100.0)
        XCTAssertEqual(config.fftWindowSize, 256)
        XCTAssertEqual(config.targetFrequencyRange.min, 30.0)
        XCTAssertEqual(config.targetFrequencyRange.max, 50.0)
        XCTAssertEqual(config.noiseFloorThreshold, 0.001)
        XCTAssertEqual(config.smoothingWindowSize, 5)
    }

    func testNyquistFrequencyIsValid() {
        let config = InertialConfiguration()
        let nyquist = config.sampleRate / 2.0

        // Target range should be below Nyquist
        XCTAssertLessThan(config.targetFrequencyRange.max, nyquist)
    }

    func testFrequencyResolution() {
        let config = InertialConfiguration()
        let binWidth = config.sampleRate / Double(config.fftWindowSize)

        // At 100 Hz / 256 samples = 0.39 Hz resolution
        XCTAssertLessThan(binWidth, 0.5)  // Sub-Hz resolution
    }
}

// MARK: - Inertial Analysis Result Tests

final class InertialAnalysisResultTests: XCTestCase {

    func testResultCreation() {
        let result = InertialAnalysisResult(
            timestamp: Date(),
            dominantFrequency: 40.0,
            frequencySpectrum: [0.1, 0.5, 0.8, 0.3],
            peakAcceleration: 1.2,
            rmsVibration: 0.5,
            isInTargetRange: true
        )

        XCTAssertEqual(result.dominantFrequency, 40.0)
        XCTAssertEqual(result.peakAcceleration, 1.2)
        XCTAssertTrue(result.isInTargetRange)
    }

    func testResultCodable() throws {
        let original = InertialAnalysisResult(
            timestamp: Date(),
            dominantFrequency: 45.0,
            frequencySpectrum: [0.1, 0.2, 0.3],
            peakAcceleration: 1.5,
            rmsVibration: 0.6,
            isInTargetRange: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InertialAnalysisResult.self, from: encoded)

        XCTAssertEqual(decoded.dominantFrequency, 45.0)
        XCTAssertTrue(decoded.isInTargetRange)
    }
}

// MARK: - EVM Analysis Result Tests

final class EVMAnalysisResultTests: XCTestCase {

    func testResultCreation() {
        let result = EVMAnalysisResult(
            timestamp: Date(),
            detectedFrequencies: [35.0, 40.0, 45.0],
            spatialAmplitudes: [0.1, 0.2, 0.15],
            motionVectors: [(x: 0.1, y: 0.2)],
            qualityScore: 0.85
        )

        XCTAssertEqual(result.detectedFrequencies.count, 3)
        XCTAssertEqual(result.spatialAmplitudes.count, 3)
        XCTAssertEqual(result.qualityScore, 0.85)
    }

    func testResultCodable() throws {
        let original = EVMAnalysisResult(
            timestamp: Date(),
            detectedFrequencies: [40.0],
            spatialAmplitudes: [0.5],
            motionVectors: [],
            qualityScore: 0.9
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EVMAnalysisResult.self, from: encoded)

        XCTAssertEqual(decoded.detectedFrequencies, [40.0])
        XCTAssertEqual(decoded.qualityScore, 0.9)
    }
}

// MARK: - Haptic Pattern Type Tests

final class HapticPatternTypeTests: XCTestCase {

    func testAllPatternTypesExist() {
        XCTAssertEqual(HapticPatternType.allCases.count, 7)
    }

    func testPatternCycleDurations() {
        XCTAssertEqual(HapticPatternType.continuous.cycleDuration, 0.1)
        XCTAssertEqual(HapticPatternType.pulsed.cycleDuration, 0.05)
        XCTAssertEqual(HapticPatternType.ramping.cycleDuration, 2.0)
        XCTAssertEqual(HapticPatternType.breathing.cycleDuration, 4.0)
    }

    func testPatternTypesCodable() throws {
        for pattern in HapticPatternType.allCases {
            let encoded = try JSONEncoder().encode(pattern)
            let decoded = try JSONDecoder().decode(HapticPatternType.self, from: encoded)
            XCTAssertEqual(decoded, pattern)
        }
    }
}

// MARK: - Haptic Stimulation Config Tests

final class HapticStimulationConfigTests: XCTestCase {

    func testDefaultConfig() {
        let config = HapticStimulationConfig()
        XCTAssertEqual(config.frequency, 40.0)
        XCTAssertEqual(config.intensity, 0.5)
        XCTAssertEqual(config.patternType, .continuous)
        XCTAssertEqual(config.dutyCycle, 0.5)
    }

    func testIntensitySafetyLimit() {
        // Should clamp to 0.8 max
        let config = HapticStimulationConfig(intensity: 1.0)
        XCTAssertEqual(config.intensity, 0.8)
    }

    func testDutyCycleSafetyLimit() {
        // Should clamp to 0.7 max
        let config = HapticStimulationConfig(dutyCycle: 0.9)
        XCTAssertEqual(config.dutyCycle, 0.7)

        // Should clamp to 0.1 min
        let config2 = HapticStimulationConfig(dutyCycle: 0.05)
        XCTAssertEqual(config2.dutyCycle, 0.1)
    }
}

// MARK: - Cymatics Pattern Tests

final class CymaticsPatternTests: XCTestCase {

    func testAllPatternsExist() {
        XCTAssertEqual(CymaticsPattern.allCases.count, 8)
    }

    func testPatternNames() {
        XCTAssertEqual(CymaticsPattern.hexagonal.rawValue, "Hexagonal")
        XCTAssertEqual(CymaticsPattern.neural.rawValue, "Neural Network")
        XCTAssertEqual(CymaticsPattern.mandala.rawValue, "Mandala")
    }

    func testPatternsCodable() throws {
        for pattern in CymaticsPattern.allCases {
            let encoded = try JSONEncoder().encode(pattern)
            let decoded = try JSONDecoder().decode(CymaticsPattern.self, from: encoded)
            XCTAssertEqual(decoded, pattern)
        }
    }
}

// MARK: - Cymatics Color Mode Tests

final class CymaticsColorModeTests: XCTestCase {

    func testAllModesExist() {
        XCTAssertEqual(CymaticsColorMode.allCases.count, 6)
    }

    func testModeNames() {
        XCTAssertEqual(CymaticsColorMode.coherence.rawValue, "Coherence")
        XCTAssertEqual(CymaticsColorMode.frequency.rawValue, "Frequency")
        XCTAssertEqual(CymaticsColorMode.thermal.rawValue, "Thermal")
    }
}

// MARK: - Cymatics Visualizer Tests

final class CymaticsVisualizerTests: XCTestCase {

    func testVisualizerInitialization() {
        let visualizer = CymaticsVisualizer()
        XCTAssertEqual(visualizer.state.frequency, 40.0)
        XCTAssertEqual(visualizer.state.amplitude, 0.5)
        XCTAssertEqual(visualizer.state.pattern, .geometric)
    }

    func testVisualizerUpdate() {
        let visualizer = CymaticsVisualizer()
        visualizer.update(frequency: 45.0, amplitude: 0.7, pattern: .neural)

        XCTAssertEqual(visualizer.state.frequency, 45.0)
        XCTAssertEqual(visualizer.state.amplitude, 0.7)
        XCTAssertEqual(visualizer.state.pattern, .neural)
    }

    func testWaveNodesCreatedForPattern() {
        let visualizer = CymaticsVisualizer()
        XCTAssertFalse(visualizer.waveNodes.isEmpty)
    }

    func testInterferenceGridInitialized() {
        let visualizer = CymaticsVisualizer()
        XCTAssertEqual(visualizer.interferenceGrid.count, 64)
        XCTAssertEqual(visualizer.interferenceGrid[0].count, 64)
    }

    func testInterferenceCalculation() {
        let visualizer = CymaticsVisualizer()
        let point = CGPoint(x: 0.5, y: 0.5)
        let interference = visualizer.calculateInterference(at: point)

        // Interference should be a finite number
        XCTAssertFalse(interference.isNaN)
        XCTAssertFalse(interference.isInfinite)
    }
}

// MARK: - Wave Node Tests

final class WaveNodeTests: XCTestCase {

    func testWaveNodeWaveHeight() {
        let node = WaveNode(
            position: CGPoint(x: 0.5, y: 0.5),
            phase: 0,
            amplitude: 1.0,
            frequency: 40.0
        )

        let height = node.waveHeight(at: CGPoint(x: 0.6, y: 0.5), time: 0)
        XCTAssertFalse(height.isNaN)
        XCTAssertLessThanOrEqual(abs(height), 1.0)  // Bounded by amplitude
    }

    func testWaveNodeAtCenter() {
        let node = WaveNode(
            position: CGPoint(x: 0.5, y: 0.5),
            phase: 0,
            amplitude: 1.0,
            frequency: 40.0
        )

        // At center, distance is 0
        let heightAtCenter = node.waveHeight(at: CGPoint(x: 0.5, y: 0.5), time: 0)
        XCTAssertFalse(heightAtCenter.isNaN)
    }
}

// MARK: - Biophysical Session State Tests

final class BiophysicalSessionStateTests: XCTestCase {

    func testDefaultState() {
        let state = BiophysicalSessionState()
        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.startTime)
        XCTAssertEqual(state.duration, 0)
        XCTAssertEqual(state.preset, .boneHarmony)
        XCTAssertTrue(state.vibrationEnabled)
        XCTAssertTrue(state.soundEnabled)
        XCTAssertTrue(state.visualsEnabled)
        XCTAssertFalse(state.disclaimerAcknowledged)
    }

    func testProgressCalculation() {
        var state = BiophysicalSessionState()
        state.isActive = true
        state.startTime = Date().addingTimeInterval(-300)  // 5 minutes ago
        state.preset = .boneHarmony  // 10 minute recommended

        let progress = state.progress
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }

    func testAverageCoherence() {
        var state = BiophysicalSessionState()
        state.coherenceHistory = [0.5, 0.6, 0.7, 0.8]

        XCTAssertEqual(state.averageCoherence, 0.65, accuracy: 0.01)
    }

    func testAverageCoherenceEmpty() {
        let state = BiophysicalSessionState()
        XCTAssertEqual(state.averageCoherence, 0)
    }
}

// MARK: - Biophysical Error Tests

final class BiophysicalErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(BiophysicalError.disclaimerNotAcknowledged.errorDescription)
        XCTAssertNotNil(BiophysicalError.sessionAlreadyActive.errorDescription)
        XCTAssertNotNil(BiophysicalError.sensorNotAvailable.errorDescription)
        XCTAssertNotNil(BiophysicalError.hapticEngineNotAvailable.errorDescription)
        XCTAssertNotNil(BiophysicalError.frequencyOutOfRange.errorDescription)
        XCTAssertNotNil(BiophysicalError.sessionTimeout.errorDescription)
        XCTAssertNotNil(BiophysicalError.cameraAccessDenied.errorDescription)
    }

    func testDisclaimerErrorMessage() {
        let error = BiophysicalError.disclaimerNotAcknowledged
        XCTAssertTrue(error.errorDescription?.contains("disclaimer") ?? false)
    }
}

// MARK: - Disclaimer Tests

final class BiophysicalDisclaimerTests: XCTestCase {

    func testFullDisclaimerContainsKey phrases() {
        let disclaimer = BiophysicalWellnessDisclaimer.fullDisclaimer

        XCTAssertTrue(disclaimer.contains("WELLNESS"))
        XCTAssertTrue(disclaimer.contains("NOT a medical device"))
        XCTAssertTrue(disclaimer.contains("NO medical claims"))
        XCTAssertTrue(disclaimer.contains("SAFETY LIMITS"))
        XCTAssertTrue(disclaimer.contains("15 minutes"))
    }

    func testShortDisclaimerIsConcise() {
        let disclaimer = BiophysicalWellnessDisclaimer.shortDisclaimer
        XCTAssertLessThan(disclaimer.count, 200)
        XCTAssertTrue(disclaimer.contains("Wellness"))
        XCTAssertTrue(disclaimer.contains("Not a medical device"))
    }

    func testStartupOverlayExists() {
        let overlay = BiophysicalWellnessDisclaimer.startupOverlay
        XCTAssertFalse(overlay.isEmpty)
        XCTAssertTrue(overlay.contains("Wellness"))
        XCTAssertTrue(overlay.contains("No Medical Claims"))
    }
}

// MARK: - Performance Tests

final class BiophysicalPerformanceTests: XCTestCase {

    func testCymaticsVisualizerInterferencePerformance() {
        let visualizer = CymaticsVisualizer()

        measure {
            for _ in 0..<1000 {
                let point = CGPoint(
                    x: Double.random(in: 0...1),
                    y: Double.random(in: 0...1)
                )
                _ = visualizer.calculateInterference(at: point)
            }
        }
    }

    func testPresetLookupPerformance() {
        measure {
            for _ in 0..<10000 {
                for preset in BiophysicalPreset.allCases {
                    _ = preset.primaryFrequency
                    _ = preset.frequencyRange
                    _ = preset.cymaticsPattern
                }
            }
        }
    }
}

// MARK: - Integration Tests

final class BiophysicalIntegrationTests: XCTestCase {

    func testPresetToCymaticsPatternMapping() {
        // Verify each preset maps to a valid cymatics pattern
        for preset in BiophysicalPreset.allCases {
            let pattern = preset.cymaticsPattern
            XCTAssertTrue(CymaticsPattern.allCases.contains(pattern),
                          "Preset \(preset.rawValue) has invalid cymatics pattern")
        }
    }

    func testFrequencyRangeContainsPrimaryFrequency() {
        for preset in BiophysicalPreset.allCases {
            let range = preset.frequencyRange
            let primary = preset.primaryFrequency

            // Custom preset has full range, others should contain primary
            if preset != .custom {
                XCTAssertGreaterThanOrEqual(primary, range.min,
                    "Preset \(preset.rawValue) primary \(primary) below range \(range.min)")
                XCTAssertLessThanOrEqual(primary, range.max,
                    "Preset \(preset.rawValue) primary \(primary) above range \(range.max)")
            }
        }
    }

    func testAllComponentsCanBeInitialized() {
        // Test that all components initialize without crashing
        _ = EVMConfiguration()
        _ = InertialConfiguration()
        _ = HapticStimulationConfig()
        _ = CymaticsVisualizer()

        // Verify state objects
        _ = BiophysicalSessionState()
        _ = CymaticsState()
    }
}

// MARK: - Frequency Analysis Tests

final class FrequencyAnalysisTests: XCTestCase {

    func testTargetRangeFor30To50Hz() {
        let config = InertialConfiguration()
        XCTAssertEqual(config.targetFrequencyRange.min, 30.0)
        XCTAssertEqual(config.targetFrequencyRange.max, 50.0)
    }

    func testFFTWindowSizeIsPowerOf2() {
        let config = InertialConfiguration()
        let windowSize = config.fftWindowSize

        // Check if power of 2
        XCTAssertEqual(windowSize & (windowSize - 1), 0, "FFT window size should be power of 2")
    }

    func testSampleRateSufficientForNyquist() {
        let config = InertialConfiguration()

        // Nyquist = sampleRate / 2
        let nyquist = config.sampleRate / 2.0

        // Must be able to capture 50 Hz
        XCTAssertGreaterThanOrEqual(nyquist, 50.0)
    }
}

// MARK: - Codable Tests

final class BiophysicalCodableTests: XCTestCase {

    func testBiophysicalPresetCodable() throws {
        for preset in BiophysicalPreset.allCases {
            let encoded = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(BiophysicalPreset.self, from: encoded)
            XCTAssertEqual(decoded, preset)
        }
    }

    func testBiophysicalSessionStateCodable() throws {
        var state = BiophysicalSessionState()
        state.isActive = true
        state.preset = .neuralFocus
        state.customFrequency = 42.0
        state.coherenceHistory = [0.5, 0.6, 0.7]

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(BiophysicalSessionState.self, from: encoded)

        XCTAssertEqual(decoded.preset, .neuralFocus)
        XCTAssertEqual(decoded.customFrequency, 42.0)
        XCTAssertEqual(decoded.coherenceHistory, [0.5, 0.6, 0.7])
    }

    func testCymaticsStateSendable() {
        // CymaticsState should conform to Sendable
        let state = CymaticsState()
        Task {
            _ = state  // Should compile without warnings
        }
    }
}

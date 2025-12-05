import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Bio-Mapping Presets System
final class BioMappingPresetsTests: XCTestCase {

    // MARK: - Preset Tests

    func testAllPresetsExist() {
        // Verify all 10 presets are defined
        let presets = BioMappingPreset.allCases
        XCTAssertEqual(presets.count, 10, "Should have exactly 10 presets")
    }

    func testPresetIdentifiers() {
        // Verify each preset has unique identifier
        let ids = BioMappingPreset.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All preset IDs should be unique")
    }

    func testPresetIcons() {
        // Verify each preset has an icon
        for preset in BioMappingPreset.allCases {
            XCTAssertFalse(preset.icon.isEmpty, "\(preset.rawValue) should have an icon")
        }
    }

    func testPresetDescriptions() {
        // Verify each preset has a meaningful description
        for preset in BioMappingPreset.allCases {
            XCTAssertGreaterThan(preset.description.count, 20,
                                 "\(preset.rawValue) should have a meaningful description")
        }
    }

    func testPresetUseCases() {
        // Verify each preset has use cases
        for preset in BioMappingPreset.allCases {
            XCTAssertGreaterThan(preset.useCases.count, 0,
                                 "\(preset.rawValue) should have at least one use case")
        }
    }

    // MARK: - Configuration Tests

    func testConfigurationReverbRange() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThanOrEqual(config.hrvToReverbRange.min, 0.0,
                                        "\(preset.rawValue) reverb min should be >= 0")
            XCTAssertLessThanOrEqual(config.hrvToReverbRange.max, 1.0,
                                     "\(preset.rawValue) reverb max should be <= 1")
            XCTAssertLessThan(config.hrvToReverbRange.min, config.hrvToReverbRange.max,
                              "\(preset.rawValue) reverb min should be less than max")
        }
    }

    func testConfigurationFilterRange() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThan(config.hrToFilterRange.min, 0,
                                 "\(preset.rawValue) filter min should be > 0")
            XCTAssertLessThanOrEqual(config.hrToFilterRange.max, 20000,
                                     "\(preset.rawValue) filter max should be <= 20kHz")
            XCTAssertLessThan(config.hrToFilterRange.min, config.hrToFilterRange.max,
                              "\(preset.rawValue) filter min should be less than max")
        }
    }

    func testConfigurationAmplitudeRange() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThanOrEqual(config.coherenceToAmplitudeRange.min, 0.0,
                                        "\(preset.rawValue) amplitude min should be >= 0")
            XCTAssertLessThanOrEqual(config.coherenceToAmplitudeRange.max, 1.0,
                                     "\(preset.rawValue) amplitude max should be <= 1")
        }
    }

    func testConfigurationBaseFrequency() {
        // All base frequencies should be valid audio frequencies
        for preset in BioMappingPreset.allCases {
            let freq = preset.mapping.baseFrequency

            XCTAssertGreaterThan(freq, 20, "\(preset.rawValue) base frequency should be > 20 Hz")
            XCTAssertLessThan(freq, 1000, "\(preset.rawValue) base frequency should be < 1000 Hz")
        }
    }

    func testConfigurationTempoRange() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThan(config.tempoRange.min, 0,
                                 "\(preset.rawValue) tempo min should be > 0")
            XCTAssertLessThanOrEqual(config.tempoRange.max, 20,
                                     "\(preset.rawValue) tempo max should be reasonable")
        }
    }

    func testConfigurationSpatialParameters() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThanOrEqual(config.coherenceToSpatialStability, 0,
                                        "\(preset.rawValue) spatial stability should be >= 0")
            XCTAssertLessThanOrEqual(config.coherenceToSpatialStability, 1,
                                     "\(preset.rawValue) spatial stability should be <= 1")

            XCTAssertGreaterThanOrEqual(config.spatialMovementIntensity, 0,
                                        "\(preset.rawValue) movement intensity should be >= 0")
            XCTAssertLessThanOrEqual(config.spatialMovementIntensity, 1,
                                     "\(preset.rawValue) movement intensity should be <= 1")
        }
    }

    func testConfigurationKalmanParameters() {
        for preset in BioMappingPreset.allCases {
            let config = preset.mapping

            XCTAssertGreaterThan(config.kalmanProcessNoise, 0,
                                 "\(preset.rawValue) process noise should be > 0")
            XCTAssertLessThan(config.kalmanProcessNoise, 1,
                              "\(preset.rawValue) process noise should be < 1")

            XCTAssertGreaterThan(config.kalmanMeasurementNoise, 0,
                                 "\(preset.rawValue) measurement noise should be > 0")
            XCTAssertLessThan(config.kalmanMeasurementNoise, 1,
                              "\(preset.rawValue) measurement noise should be < 1")
        }
    }

    func testConfigurationSmoothingFactor() {
        for preset in BioMappingPreset.allCases {
            let smoothing = preset.mapping.parameterSmoothingFactor

            XCTAssertGreaterThanOrEqual(smoothing, 0,
                                        "\(preset.rawValue) smoothing should be >= 0")
            XCTAssertLessThanOrEqual(smoothing, 1,
                                     "\(preset.rawValue) smoothing should be <= 1")
        }
    }

    // MARK: - Mapping Curve Tests

    func testLinearCurve() {
        let curve = MappingCurve.linear

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testLogarithmicCurve() {
        let curve = MappingCurve.logarithmic

        // Logarithmic should be more sensitive at lower values
        let lowValue = curve.apply(0.1)
        let midValue = curve.apply(0.5)

        XCTAssertGreaterThan(lowValue, 0.1, "Log curve should amplify low values")
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testExponentialCurve() {
        let curve = MappingCurve.exponential(factor: 2.0)

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.5), 0.25, accuracy: 0.001) // 0.5^2 = 0.25
    }

    // MARK: - Kalman Filter Tests

    func testKalmanFilterInitialization() {
        let kalman = KalmanFilter(processNoise: 0.01, measurementNoise: 0.1)
        XCTAssertEqual(kalman.estimate, 0.0, "Initial estimate should be 0")
    }

    func testKalmanFilterConvergence() {
        let kalman = KalmanFilter(processNoise: 0.01, measurementNoise: 0.1)

        // Feed constant measurements
        var lastEstimate = 0.0
        for _ in 0..<100 {
            lastEstimate = kalman.update(measurement: 50.0)
        }

        XCTAssertEqual(lastEstimate, 50.0, accuracy: 1.0,
                       "Kalman filter should converge to constant measurement")
    }

    func testKalmanFilterSmoothing() {
        let kalman = KalmanFilter(processNoise: 0.01, measurementNoise: 0.5)

        // Feed noisy measurements
        let noisyMeasurements: [Double] = [50, 55, 45, 52, 48, 51, 49, 53, 47, 50]
        var estimates: [Double] = []

        for measurement in noisyMeasurements {
            estimates.append(kalman.update(measurement: measurement))
        }

        // Variance of estimates should be less than variance of measurements
        let measurementVariance = variance(noisyMeasurements)
        let estimateVariance = variance(estimates)

        XCTAssertLessThan(estimateVariance, measurementVariance,
                          "Kalman filter should reduce variance")
    }

    func testKalmanFilterReset() {
        let kalman = KalmanFilter(processNoise: 0.01, measurementNoise: 0.1)

        _ = kalman.update(measurement: 100.0)
        kalman.reset(initialValue: 0.0)

        XCTAssertEqual(kalman.estimate, 0.0, "Reset should restore initial value")
    }

    // MARK: - BioData Tests

    func testBioDataPresets() {
        let relaxed = BioData.relaxed
        let stressed = BioData.stressed
        let flow = BioData.flow

        // Relaxed state
        XCTAssertGreaterThan(relaxed.hrvCoherence, 50)
        XCTAssertLessThan(relaxed.heartRate, 80)

        // Stressed state
        XCTAssertLessThan(stressed.hrvCoherence, 40)
        XCTAssertGreaterThan(stressed.heartRate, 85)

        // Flow state
        XCTAssertGreaterThan(flow.hrvCoherence, 80)
    }

    func testBioDataFromHealthKit() async {
        // This would require mocking HealthKitManager
        // For now, test the manual initializer
        let bioData = BioData(
            hrvCoherence: 65.0,
            heartRate: 72.0,
            hrvRMSSD: 55.0,
            breathingRate: 6.0,
            audioLevel: 0.5,
            voicePitch: 440.0
        )

        XCTAssertEqual(bioData.hrvCoherence, 65.0)
        XCTAssertEqual(bioData.heartRate, 72.0)
        XCTAssertEqual(bioData.voicePitch, 440.0)
    }

    // MARK: - Preset Manager Tests

    @MainActor
    func testPresetManagerInitialization() {
        let manager = BioPresetManager()

        // Should have a default preset
        XCTAssertNotNil(manager.currentPreset)
    }

    @MainActor
    func testPresetManagerCycling() {
        let manager = BioPresetManager()
        let initialPreset = manager.currentPreset

        manager.nextPreset()
        XCTAssertNotEqual(manager.currentPreset, initialPreset,
                          "nextPreset should change the preset")

        // Cycle through all presets
        for _ in 0..<9 {
            manager.nextPreset()
        }
        XCTAssertEqual(manager.currentPreset, initialPreset,
                       "Should cycle back to initial preset after 10 nexts")
    }

    @MainActor
    func testPresetManagerCallback() {
        let manager = BioPresetManager()
        var callbackCalled = false
        var receivedPreset: BioMappingPreset?

        manager.onPresetChanged = { preset in
            callbackCalled = true
            receivedPreset = preset
        }

        manager.currentPreset = .energize

        XCTAssertTrue(callbackCalled, "Callback should be called on preset change")
        XCTAssertEqual(receivedPreset, .energize, "Callback should receive correct preset")
    }

    // MARK: - Configuration Equality Tests

    func testConfigurationEquality() {
        let config1 = BioMappingPreset.meditation.mapping
        let config2 = BioMappingPreset.meditation.mapping

        XCTAssertEqual(config1, config2, "Same preset should produce equal configurations")
    }

    func testConfigurationInequality() {
        let config1 = BioMappingPreset.meditation.mapping
        let config2 = BioMappingPreset.energize.mapping

        XCTAssertNotEqual(config1, config2, "Different presets should produce different configurations")
    }

    // MARK: - Codable Tests

    func testMappingCurveCodable() throws {
        let curves: [MappingCurve] = [.linear, .logarithmic, .exponential(factor: 1.5)]

        for curve in curves {
            let encoded = try JSONEncoder().encode(curve)
            let decoded = try JSONDecoder().decode(MappingCurve.self, from: encoded)
            XCTAssertEqual(curve, decoded, "Curve should survive encode/decode cycle")
        }
    }

    func testBioMappingPresetCodable() throws {
        for preset in BioMappingPreset.allCases {
            let encoded = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(BioMappingPreset.self, from: encoded)
            XCTAssertEqual(preset, decoded, "\(preset.rawValue) should survive encode/decode cycle")
        }
    }

    func testConfigurationCodable() throws {
        let config = BioMappingPreset.creative.mapping

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BioMappingConfiguration.self, from: encoded)

        XCTAssertEqual(config, decoded, "Configuration should survive encode/decode cycle")
    }

    // MARK: - Helper Functions

    private func variance(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}


// MARK: - Bio Parameter Mapping Tests

final class BioParameterMappingTests: XCTestCase {

    @MainActor
    func testMappingInitialization() {
        let presetManager = BioPresetManager()
        let mapping = BioParameterMapping(presetManager: presetManager)

        XCTAssertNotNil(mapping, "Mapping should initialize successfully")
    }

    @MainActor
    func testMappingApply() {
        let presetManager = BioPresetManager()
        presetManager.currentPreset = .meditation
        let mapping = BioParameterMapping(presetManager: presetManager)

        let bioData = BioData.relaxed
        mapping.apply(bioData: bioData)

        // Verify parameters are within expected ranges
        XCTAssertGreaterThanOrEqual(mapping.reverbWet, 0.0)
        XCTAssertLessThanOrEqual(mapping.reverbWet, 1.0)

        XCTAssertGreaterThan(mapping.filterCutoff, 0)
        XCTAssertLessThan(mapping.filterCutoff, 20000)

        XCTAssertGreaterThanOrEqual(mapping.amplitude, 0.0)
        XCTAssertLessThanOrEqual(mapping.amplitude, 1.0)
    }

    @MainActor
    func testMappingPresetChange() {
        let presetManager = BioPresetManager()
        presetManager.currentPreset = .meditation
        let mapping = BioParameterMapping(presetManager: presetManager)

        let initialFrequency = mapping.baseFrequency

        // Change preset
        presetManager.currentPreset = .focus

        // Frequency should change to match new preset
        XCTAssertNotEqual(mapping.baseFrequency, initialFrequency,
                          "Base frequency should change with preset")
    }

    @MainActor
    func testMappingSmoothing() {
        let presetManager = BioPresetManager()
        presetManager.currentPreset = .meditation  // High smoothing
        let mapping = BioParameterMapping(presetManager: presetManager)

        // Apply first measurement
        mapping.apply(bioData: BioData(hrvCoherence: 20, heartRate: 60))
        let firstReverb = mapping.reverbWet

        // Apply drastically different measurement
        mapping.apply(bioData: BioData(hrvCoherence: 80, heartRate: 100))
        let secondReverb = mapping.reverbWet

        // Due to smoothing, the change shouldn't be instant
        // The difference should be less than the full range difference
        XCTAssertLessThan(abs(secondReverb - firstReverb), 0.5,
                          "Smoothing should prevent instant parameter jumps")
    }

    @MainActor
    func testSpatialPositionCalculation() {
        let presetManager = BioPresetManager()
        presetManager.currentPreset = .grounding  // High stability
        let mapping = BioParameterMapping(presetManager: presetManager)

        // Apply high coherence (should be centered)
        mapping.apply(bioData: BioData.flow)

        // Position should be near center
        XCTAssertEqual(mapping.spatialPosition.x, 0, accuracy: 0.1)
        XCTAssertEqual(mapping.spatialPosition.y, 0, accuracy: 0.1)
        XCTAssertEqual(mapping.spatialPosition.z, 1, accuracy: 0.1)
    }

    @MainActor
    func testHarmonicCountCalculation() {
        let presetManager = BioPresetManager()
        presetManager.currentPreset = .creative
        let mapping = BioParameterMapping(presetManager: presetManager)

        // High coherence and audio level should produce more harmonics
        mapping.apply(bioData: BioData(
            hrvCoherence: 90,
            heartRate: 65,
            audioLevel: 0.8
        ))

        XCTAssertGreaterThan(mapping.harmonicCount, 3,
                             "High coherence should produce more harmonics")

        // Low coherence and audio level should produce fewer harmonics
        mapping.apply(bioData: BioData(
            hrvCoherence: 10,
            heartRate: 95,
            audioLevel: 0.1
        ))

        XCTAssertLessThanOrEqual(mapping.harmonicCount, 5,
                                  "Low coherence should produce fewer harmonics")
    }

    @MainActor
    func testParameterSummary() {
        let presetManager = BioPresetManager()
        let mapping = BioParameterMapping(presetManager: presetManager)

        let summary = mapping.parameterSummary
        XCTAssertFalse(summary.isEmpty, "Parameter summary should not be empty")
        XCTAssertTrue(summary.contains("Reverb"), "Summary should contain reverb info")
        XCTAssertTrue(summary.contains("Filter"), "Summary should contain filter info")
    }
}


// MARK: - Extended Kalman Filter Tests

final class ExtendedBioKalmanFilterTests: XCTestCase {

    func testInitialization() {
        let filter = ExtendedBioKalmanFilter()
        XCTAssertNotNil(filter, "Extended Kalman filter should initialize")
    }

    func testUpdate() {
        let filter = ExtendedBioKalmanFilter()

        let result = filter.update(
            hrvRMSSD: 50.0,
            heartRate: 70.0,
            coherence: 60.0,
            breathingRate: 6.0
        )

        // Results should be valid
        XCTAssertGreaterThan(result.hrvRMSSD, 0)
        XCTAssertGreaterThan(result.heartRate, 0)
        XCTAssertGreaterThanOrEqual(result.coherence, 0)
        XCTAssertGreaterThan(result.breathingRate, 0)
    }

    func testConvergence() {
        let filter = ExtendedBioKalmanFilter()

        // Feed consistent measurements
        var lastResult: (hrvRMSSD: Double, heartRate: Double, coherence: Double, breathingRate: Double)?

        for _ in 0..<50 {
            lastResult = filter.update(
                hrvRMSSD: 55.0,
                heartRate: 72.0,
                coherence: 65.0,
                breathingRate: 6.5
            )
        }

        guard let result = lastResult else {
            XCTFail("Should have result")
            return
        }

        XCTAssertEqual(result.hrvRMSSD, 55.0, accuracy: 2.0)
        XCTAssertEqual(result.heartRate, 72.0, accuracy: 2.0)
        XCTAssertEqual(result.coherence, 65.0, accuracy: 2.0)
        XCTAssertEqual(result.breathingRate, 6.5, accuracy: 0.5)
    }

    func testReset() {
        let filter = ExtendedBioKalmanFilter()

        _ = filter.update(hrvRMSSD: 100, heartRate: 120, coherence: 90, breathingRate: 12)

        filter.reset()

        // After reset, filter should start fresh
        let result = filter.update(hrvRMSSD: 50, heartRate: 60, coherence: 50, breathingRate: 6)

        // Should not be influenced much by pre-reset values
        XCTAssertLessThan(result.heartRate, 70, "Reset should clear previous state influence")
    }
}

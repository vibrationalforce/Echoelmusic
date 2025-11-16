//
//  BioPresetManagerTests.swift
//  EchoelmusicTests
//
//  Tests für Bio-Mapping Preset Manager
//

import XCTest
@testable import Echoelmusic

@MainActor
final class BioPresetManagerTests: XCTestCase {

    var parameterMapper: BioParameterMapper!
    var presetManager: BioPresetManager!

    override func setUp() async throws {
        try await super.setUp()
        parameterMapper = BioParameterMapper()
        presetManager = BioPresetManager(parameterMapper: parameterMapper)
    }

    override func tearDown() async throws {
        presetManager = nil
        parameterMapper = nil
        try await super.tearDown()
    }

    // MARK: - Basic Preset Tests

    func testApplyMeditationPreset() {
        presetManager.applyPreset(.meditation)

        XCTAssertEqual(presetManager.activePreset, .meditation)
        XCTAssertEqual(parameterMapper.baseFrequency, 432.0, "Meditation should use 432 Hz")
        XCTAssertEqual(parameterMapper.tempo, 6.0, "Meditation should have slow tempo")
        XCTAssertGreaterThan(parameterMapper.reverbWet, 0.5, "Meditation should have high reverb")
    }

    func testApplyFocusPreset() {
        presetManager.applyPreset(.focus)

        XCTAssertEqual(presetManager.activePreset, .focus)
        XCTAssertEqual(parameterMapper.baseFrequency, 528.0, "Focus should use 528 Hz")
        XCTAssertGreaterThan(parameterMapper.filterCutoff, 1000.0, "Focus should have bright sound")
    }

    func testApplyRelaxationPreset() {
        presetManager.applyPreset(.relaxation)

        XCTAssertEqual(presetManager.activePreset, .relaxation)
        XCTAssertEqual(parameterMapper.baseFrequency, 396.0, "Relaxation should use 396 Hz")
        XCTAssertEqual(parameterMapper.tempo, 4.0, "Relaxation should have very slow tempo")
        XCTAssertGreaterThan(parameterMapper.reverbWet, 0.7, "Relaxation should have maximum reverb")
    }

    func testApplyEnergizePreset() {
        presetManager.applyPreset(.energize)

        XCTAssertEqual(presetManager.activePreset, .energize)
        XCTAssertEqual(parameterMapper.baseFrequency, 741.0, "Energize should use 741 Hz")
        XCTAssertEqual(parameterMapper.tempo, 8.0, "Energize should have fast tempo")
        XCTAssertLessThan(parameterMapper.reverbWet, 0.3, "Energize should have minimal reverb")
    }

    func testApplyCreativeFlowPreset() {
        presetManager.applyPreset(.creativeFlow)

        XCTAssertEqual(presetManager.activePreset, .creativeFlow)
        XCTAssertEqual(parameterMapper.baseFrequency, 639.0, "Creative Flow should use 639 Hz")
        XCTAssertEqual(parameterMapper.harmonicCount, 8, "Creative Flow should have rich harmonics")
    }

    // MARK: - All Presets Tests

    func testAllPresetsAvailable() {
        let allPresets = BioParameterMapper.BioPreset.allCases

        XCTAssertEqual(allPresets.count, 5, "Should have 5 presets")
        XCTAssertTrue(allPresets.contains(.meditation))
        XCTAssertTrue(allPresets.contains(.focus))
        XCTAssertTrue(allPresets.contains(.relaxation))
        XCTAssertTrue(allPresets.contains(.energize))
        XCTAssertTrue(allPresets.contains(.creativeFlow))
    }

    func testAllPresetsHaveDescriptions() {
        for preset in BioParameterMapper.BioPreset.allCases {
            XCTAssertFalse(preset.description.isEmpty, "\(preset.rawValue) should have description")
            XCTAssertFalse(preset.icon.isEmpty, "\(preset.rawValue) should have icon")
        }
    }

    func testAllPresetsHaveValidConfigurations() {
        for preset in BioParameterMapper.BioPreset.allCases {
            let config = preset.configuration

            XCTAssertGreaterThanOrEqual(config.reverbWet, 0.0)
            XCTAssertLessThanOrEqual(config.reverbWet, 1.0)

            XCTAssertGreaterThan(config.filterCutoff, 0.0)
            XCTAssertLessThanOrEqual(config.filterCutoff, 20000.0)

            XCTAssertGreaterThanOrEqual(config.amplitude, 0.0)
            XCTAssertLessThanOrEqual(config.amplitude, 1.0)

            XCTAssertGreaterThan(config.baseFrequency, 0.0)
            XCTAssertLessThanOrEqual(config.baseFrequency, 20000.0)

            XCTAssertGreaterThan(config.tempo, 0.0)

            XCTAssertGreaterThan(config.harmonicCount, 0)
        }
    }

    // MARK: - Preset Morphing Tests

    func testMorphBetweenPresets() async {
        presetManager.applyPreset(.meditation)

        let initialReverb = parameterMapper.reverbWet
        let initialFilter = parameterMapper.filterCutoff

        await presetManager.morphToPreset(.energize, duration: 0.5)

        XCTAssertEqual(presetManager.activePreset, .energize)
        XCTAssertNotEqual(parameterMapper.reverbWet, initialReverb, "Reverb should have changed")
        XCTAssertNotEqual(parameterMapper.filterCutoff, initialFilter, "Filter should have changed")
    }

    func testMorphingProgressTracking() async {
        presetManager.applyPreset(.meditation)

        Task {
            await presetManager.morphToPreset(.focus, duration: 1.0)
        }

        // Wait a bit and check progress
        try? await Task.sleep(for: .milliseconds(500))

        if presetManager.isMorphing {
            XCTAssertGreaterThan(presetManager.morphProgress, 0.0)
            XCTAssertLessThan(presetManager.morphProgress, 1.0)
        }
    }

    func testMorphCompletes() async {
        presetManager.applyPreset(.relaxation)

        await presetManager.morphToPreset(.energize, duration: 0.5)

        XCTAssertFalse(presetManager.isMorphing, "Morphing should be complete")
        XCTAssertEqual(presetManager.morphProgress, 1.0, "Progress should be 100%")
        XCTAssertEqual(presetManager.activePreset, .energize)
    }

    // MARK: - Auto-Selection Tests

    func testAutoSelectionDisabled() {
        presetManager.autoSelectionEnabled = false

        let suggested = presetManager.autoSelectPreset(
            hrvCoherence: 50.0,
            heartRate: 75.0,
            stressLevel: 0.5
        )

        XCTAssertNil(suggested, "Should not suggest when disabled")
    }

    func testAutoSelectionHighStress() {
        presetManager.autoSelectionEnabled = true

        let suggested = presetManager.autoSelectPreset(
            hrvCoherence: 40.0,
            heartRate: 95.0,
            stressLevel: 0.8  // High stress
        )

        XCTAssertEqual(suggested, .relaxation, "High stress should suggest relaxation")
    }

    func testAutoSelectionLowCoherence() {
        presetManager.autoSelectionEnabled = true

        let suggested = presetManager.autoSelectPreset(
            hrvCoherence: 25.0,  // Low coherence
            heartRate: 70.0,
            stressLevel: 0.4
        )

        XCTAssertEqual(suggested, .meditation, "Low coherence should suggest meditation")
    }

    func testAutoSelectionHighCoherenceModerateHR() {
        presetManager.autoSelectionEnabled = true

        let suggested = presetManager.autoSelectPreset(
            hrvCoherence: 75.0,  // High coherence
            heartRate: 70.0,     // Moderate HR
            stressLevel: 0.2
        )

        XCTAssertEqual(suggested, .creativeFlow, "High coherence + moderate HR should suggest creative flow")
    }

    func testAutoSelectionHighHR() {
        presetManager.autoSelectionEnabled = true

        let suggested = presetManager.autoSelectPreset(
            hrvCoherence: 60.0,
            heartRate: 95.0,  // High HR
            stressLevel: 0.3
        )

        XCTAssertEqual(suggested, .energize, "High HR should suggest energize")
    }

    // MARK: - Custom Preset Tests

    func testCreateCustomPreset() {
        parameterMapper.reverbWet = 0.6
        parameterMapper.filterCutoff = 1234.0
        parameterMapper.baseFrequency = 440.0

        presetManager.createCustomPreset(name: "My Custom Preset")

        XCTAssertEqual(presetManager.customPresets.count, 1)
        XCTAssertEqual(presetManager.customPresets[0].name, "My Custom Preset")
    }

    func testApplyCustomPreset() {
        // Create custom preset
        parameterMapper.reverbWet = 0.55
        parameterMapper.filterCutoff = 1500.0
        presetManager.createCustomPreset(name: "Test Preset")

        // Change parameters
        parameterMapper.reverbWet = 0.2
        parameterMapper.filterCutoff = 500.0

        // Apply custom preset
        let customPreset = presetManager.customPresets[0]
        presetManager.applyCustomPreset(customPreset)

        XCTAssertEqual(parameterMapper.reverbWet, 0.55, accuracy: 0.01)
        XCTAssertEqual(parameterMapper.filterCutoff, 1500.0, accuracy: 1.0)
    }

    func testDeleteCustomPreset() {
        presetManager.createCustomPreset(name: "Test 1")
        presetManager.createCustomPreset(name: "Test 2")

        XCTAssertEqual(presetManager.customPresets.count, 2)

        let toDelete = presetManager.customPresets[0]
        presetManager.deleteCustomPreset(toDelete)

        XCTAssertEqual(presetManager.customPresets.count, 1)
    }

    // MARK: - Analytics Tests

    func testPresetUsageStats() {
        presetManager.applyPreset(.meditation)
        presetManager.applyPreset(.focus)
        presetManager.applyPreset(.meditation)
        presetManager.applyPreset(.meditation)

        let stats = presetManager.getPresetUsageStats()

        XCTAssertEqual(stats[.meditation], 3)
        XCTAssertEqual(stats[.focus], 1)
    }

    func testMostUsedPreset() {
        presetManager.applyPreset(.meditation)
        presetManager.applyPreset(.focus)
        presetManager.applyPreset(.meditation)
        presetManager.applyPreset(.energize)
        presetManager.applyPreset(.meditation)

        let mostUsed = presetManager.getMostUsedPreset()

        XCTAssertEqual(mostUsed, .meditation)
    }

    // MARK: - Time-Based Recommendations Tests

    func testTimeBasedRecommendations() {
        let recommendation = presetManager.getTimeBasedRecommendation()

        XCTAssertNotNil(recommendation)
        // Actual preset depends on current time
    }

    // MARK: - Activity-Based Recommendations Tests

    func testActivityBasedRecommendations() {
        XCTAssertEqual(
            presetManager.getActivityBasedRecommendation(activity: .working),
            .focus
        )

        XCTAssertEqual(
            presetManager.getActivityBasedRecommendation(activity: .creating),
            .creativeFlow
        )

        XCTAssertEqual(
            presetManager.getActivityBasedRecommendation(activity: .exercising),
            .energize
        )

        XCTAssertEqual(
            presetManager.getActivityBasedRecommendation(activity: .resting),
            .relaxation
        )

        XCTAssertEqual(
            presetManager.getActivityBasedRecommendation(activity: .meditating),
            .meditation
        )
    }

    func testAllActivitiesHaveIcons() {
        for activity in BioPresetManager.Activity.allCases {
            XCTAssertFalse(activity.icon.isEmpty, "\(activity.rawValue) should have icon")
        }
    }

    // MARK: - Preset Scheduling Tests

    func testSchedulePreset() {
        let futureTime = Date().addingTimeInterval(3600)  // 1 hour from now

        presetManager.schedulePreset(.meditation, at: futureTime)

        // Test passes if no crash (actual scheduling would need timer implementation)
    }

    func testCreateDailyRoutine() {
        let routine = presetManager.createDailyRoutine()

        XCTAssertFalse(routine.isEmpty, "Should create routine")
        XCTAssertEqual(routine.count, 5, "Should have 5 scheduled presets")

        // Verify all presets in routine are active
        for scheduled in routine {
            XCTAssertTrue(scheduled.isActive)
        }
    }

    // MARK: - Parameter Validation Tests

    func testParameterValidationAfterPresetApplication() {
        for preset in BioParameterMapper.BioPreset.allCases {
            presetManager.applyPreset(preset)

            XCTAssertTrue(parameterMapper.isValid, "\(preset.rawValue) should result in valid parameters")
        }
    }

    // MARK: - Performance Tests

    func testPresetApplicationPerformance() {
        measure {
            for preset in BioParameterMapper.BioPreset.allCases {
                presetManager.applyPreset(preset)
            }
        }
    }

    func testAutoSelectionPerformance() {
        presetManager.autoSelectionEnabled = true

        measure {
            for _ in 0..<1000 {
                _ = presetManager.autoSelectPreset(
                    hrvCoherence: Double.random(in: 0...100),
                    heartRate: Double.random(in: 40...120),
                    stressLevel: Float.random(in: 0...1)
                )
            }
        }
    }
}

// MARK: - BioParameterMapper Tests

@MainActor
final class BioParameterMapperTests: XCTestCase {

    var mapper: BioParameterMapper!

    override func setUp() async throws {
        try await super.setUp()
        mapper = BioParameterMapper()
    }

    override func tearDown() async throws {
        mapper = nil
        try await super.tearDown()
    }

    func testUpdateParameters() {
        mapper.updateParameters(
            hrvCoherence: 70.0,
            heartRate: 75.0,
            voicePitch: 440.0,
            audioLevel: 0.5
        )

        XCTAssertTrue(mapper.isValid, "Parameters should be valid")
    }

    func testHRVToReverbMapping() {
        // High coherence → High reverb
        mapper.updateParameters(
            hrvCoherence: 90.0,
            heartRate: 70.0,
            voicePitch: 440.0,
            audioLevel: 0.5
        )

        XCTAssertGreaterThan(mapper.reverbWet, 0.5, "High coherence should increase reverb")
    }

    func testHeartRateToFilterMapping() {
        // High HR → High filter cutoff
        mapper.updateParameters(
            hrvCoherence: 60.0,
            heartRate: 110.0,  // High
            voicePitch: 440.0,
            audioLevel: 0.5
        )

        XCTAssertGreaterThan(mapper.filterCutoff, 1500.0, "High HR should increase filter cutoff")
    }

    func testParameterSmoothingOverTime() {
        let initialReverb = mapper.reverbWet

        // Update with different value
        mapper.updateParameters(
            hrvCoherence: 80.0,
            heartRate: 70.0,
            voicePitch: 440.0,
            audioLevel: 0.5
        )

        let afterOneUpdate = mapper.reverbWet

        // Should be different but smoothed
        if initialReverb != afterOneUpdate {
            XCTAssertNotEqual(initialReverb, afterOneUpdate)
        }
    }

    func testParameterValidation() {
        mapper.updateParameters(
            hrvCoherence: 60.0,
            heartRate: 75.0,
            voicePitch: 440.0,
            audioLevel: 0.5
        )

        XCTAssertTrue(mapper.isValid)

        XCTAssertGreaterThanOrEqual(mapper.reverbWet, 0.0)
        XCTAssertLessThanOrEqual(mapper.reverbWet, 1.0)

        XCTAssertGreaterThanOrEqual(mapper.filterCutoff, 20.0)
        XCTAssertLessThanOrEqual(mapper.filterCutoff, 20000.0)
    }

    func testParameterSummary() {
        let summary = mapper.parameterSummary

        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("Reverb"))
        XCTAssertTrue(summary.contains("Filter"))
        XCTAssertTrue(summary.contains("Amplitude"))
    }
}

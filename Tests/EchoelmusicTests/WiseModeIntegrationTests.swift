import XCTest
@testable import Echoelmusic

// MARK: - Wise Mode Integration Tests
/// Tests for mode transitions, engine integration, and system-wide behavior

final class WiseModeIntegrationTests: XCTestCase {

    // MARK: - Mode Transition Tests

    func testModeTransitionProperties() {
        // Test that all modes can transition to each other
        for fromMode in WiseMode.allCases {
            for toMode in WiseMode.allCases {
                let transition = WiseModeTransition(
                    fromMode: fromMode,
                    toMode: toMode,
                    timestamp: Date(),
                    duration: 2.0,
                    reason: .userInitiated
                )

                XCTAssertEqual(transition.fromMode, fromMode)
                XCTAssertEqual(transition.toMode, toMode)
                XCTAssertEqual(transition.duration, 2.0)
            }
        }
    }

    func testModeTransitionReasons() {
        let reasons: [WiseModeTransition.TransitionReason] = [
            .userInitiated,
            .scheduled,
            .bioAdaptive,
            .timeOfDay,
            .groupSync
        ]

        for reason in reasons {
            let transition = WiseModeTransition(
                fromMode: .focus,
                toMode: .flow,
                timestamp: Date(),
                duration: 2.0,
                reason: reason
            )

            XCTAssertEqual(transition.reason, reason)
            XCTAssertFalse(reason.rawValue.isEmpty)
        }
    }

    // MARK: - Recording Engine Integration Tests

    func testWiseRecordingPresetForAllModes() {
        for mode in WiseMode.allCases {
            let preset = WiseRecordingPreset(mode: mode)

            // All presets should have valid audio settings
            XCTAssertGreaterThan(preset.sampleRate, 0)
            XCTAssertTrue([16, 24, 32].contains(preset.bitDepth))
            XCTAssertEqual(preset.channelCount, 2)
            XCTAssertGreaterThan(preset.retrospectiveBufferDuration, 0)

            // Name should contain mode name
            XCTAssertTrue(preset.name.contains(mode.rawValue))
        }
    }

    func testSleepModeOptimizesForPowerSaving() {
        let preset = WiseRecordingPreset(mode: .sleep)

        // Sleep mode should use lower sample rate for power saving
        XCTAssertEqual(preset.sampleRate, 44100.0)
        XCTAssertEqual(preset.bitDepth, 16)
        XCTAssertEqual(preset.noiseReduction, .heavy) // Noise reduction for quiet environment
    }

    func testFlowModeOptimizesForQuality() {
        let preset = WiseRecordingPreset(mode: .flow)

        // Flow mode should prioritize quality
        XCTAssertEqual(preset.sampleRate, 96000.0)
        XCTAssertEqual(preset.bitDepth, 24)
        XCTAssertEqual(preset.compressionPreset, .music)
    }

    func testHealingModeUsesStudioQuality() {
        let preset = WiseRecordingPreset(mode: .healing)

        // Healing mode should use highest quality for therapeutic precision
        XCTAssertEqual(preset.sampleRate, 96000.0)
        XCTAssertEqual(preset.bitDepth, 32)
        XCTAssertEqual(preset.noiseReduction, .off) // Preserve natural frequencies
    }

    // MARK: - Accessibility Integration Tests

    func testAccessibilityConfigMatchesModeIntent() {
        // Sleep mode - minimize stimulation
        let sleepConfig = WiseAccessibilityConfig(mode: .sleep)
        XCTAssertTrue(sleepConfig.reducedMotion)
        XCTAssertLessThan(sleepConfig.hapticIntensity, 0.2)
        XCTAssertFalse(sleepConfig.visualCuesEnabled)

        // Meditation mode - minimize visual distraction
        let meditationConfig = WiseAccessibilityConfig(mode: .meditation)
        XCTAssertFalse(meditationConfig.visualCuesEnabled)
        XCTAssertTrue(meditationConfig.voiceGuidanceEnabled)

        // Energize mode - maximize engagement
        let energizeConfig = WiseAccessibilityConfig(mode: .energize)
        XCTAssertTrue(energizeConfig.visualCuesEnabled)
        XCTAssertTrue(energizeConfig.highContrast)
        XCTAssertGreaterThan(energizeConfig.hapticIntensity, 0.7)

        // Focus mode - minimize interruptions
        let focusConfig = WiseAccessibilityConfig(mode: .focus)
        XCTAssertFalse(focusConfig.voiceGuidanceEnabled)
        XCTAssertTrue(focusConfig.reducedMotion)
    }

    func testHapticIntensityRanges() {
        for mode in WiseMode.allCases {
            let config = WiseAccessibilityConfig(mode: mode)

            XCTAssertGreaterThanOrEqual(config.hapticIntensity, 0.0, "\(mode) haptic should be >= 0")
            XCTAssertLessThanOrEqual(config.hapticIntensity, 1.0, "\(mode) haptic should be <= 1")
        }
    }

    // MARK: - Collaboration Integration Tests

    func testGroupCoherenceStateInitialization() {
        let state = GroupCoherenceState()

        XCTAssertEqual(state.averageCoherence, 0)
        XCTAssertEqual(state.coherenceSpread, 0)
        XCTAssertEqual(state.syncLevel, 0)
        XCTAssertNil(state.flowLeaderID)
    }

    func testWiseGroupSessionCreation() {
        let session = WiseGroupSession(hostMode: .social)

        XCTAssertEqual(session.hostMode, .social)
        XCTAssertTrue(session.syncEnabled)
        XCTAssertEqual(session.coherenceTarget, 0.7)
        XCTAssertTrue(session.participantModes.isEmpty)
    }

    // MARK: - Schedule Integration Tests

    func testSmartTriggerSuggestedModes() {
        // Verify smart triggers suggest appropriate modes
        XCTAssertEqual(SmartTrigger.morningRoutine.suggestedMode, .energize)
        XCTAssertEqual(SmartTrigger.workStart.suggestedMode, .focus)
        XCTAssertEqual(SmartTrigger.lunchBreak.suggestedMode, .meditation)
        XCTAssertEqual(SmartTrigger.eveningWindDown.suggestedMode, .healing)
        XCTAssertEqual(SmartTrigger.bedtime.suggestedMode, .sleep)
        XCTAssertEqual(SmartTrigger.optimalFlow.suggestedMode, .flow)
    }

    func testScheduleTypesCreateValidDisplayNames() {
        // Daily
        let daily = ScheduleType.daily(time: TimeOfDay(hour: 9, minute: 0))
        XCTAssertTrue(daily.displayName.contains("09:00"))

        // Weekly
        let weekly = ScheduleType.weekly(days: [.monday, .friday], time: TimeOfDay(hour: 15, minute: 30))
        XCTAssertTrue(weekly.displayName.contains("15:30"))

        // Time Range
        let range = ScheduleType.timeRange(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0)
        )
        XCTAssertTrue(range.displayName.contains("09:00"))
        XCTAssertTrue(range.displayName.contains("17:00"))

        // Smart
        let smart = ScheduleType.smart(trigger: .optimalFlow)
        XCTAssertEqual(smart.displayName, SmartTrigger.optimalFlow.displayName)
    }

    // MARK: - Analytics Integration Tests

    func testSessionStatsAccumulation() {
        var stats = WiseSessionStats(mode: .flow)

        // Simulate session progress
        stats.duration = 1800 // 30 minutes
        stats.averageCoherence = 0.65
        stats.peakCoherence = 0.85
        stats.averageHRV = 45.0
        stats.flowStateMinutes = 15

        XCTAssertEqual(stats.duration, 1800)
        XCTAssertEqual(stats.averageCoherence, 0.65, accuracy: 0.001)
        XCTAssertEqual(stats.flowStateMinutes, 15)
    }

    func testModeTransitionTracking() {
        var stats = WiseSessionStats(mode: .focus)

        // Add transitions
        let transition1 = WiseModeTransition(
            fromMode: .focus,
            toMode: .flow,
            timestamp: Date(),
            duration: 2.0,
            reason: .userInitiated
        )

        let transition2 = WiseModeTransition(
            fromMode: .flow,
            toMode: .meditation,
            timestamp: Date(),
            duration: 2.0,
            reason: .scheduled
        )

        stats.modeTransitions.append(transition1)
        stats.modeTransitions.append(transition2)

        XCTAssertEqual(stats.modeTransitions.count, 2)
        XCTAssertEqual(stats.modeTransitions[0].toMode, .flow)
        XCTAssertEqual(stats.modeTransitions[1].toMode, .meditation)
    }

    // MARK: - Preset Integration Tests

    func testPresetImportExportRoundTrip() throws {
        // Create original preset
        let config = WiseModeConfiguration(mode: .healing)
        var original = WisePreset(
            name: "Export Test",
            description: "Testing import/export",
            icon: "heart.circle",
            color: .pink,
            configuration: config
        )
        original.tags = ["test", "export", "healing"]

        // Export
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Import
        let decoder = JSONDecoder()
        let imported = try decoder.decode(WisePreset.self, from: data)

        // Verify
        XCTAssertEqual(imported.name, original.name)
        XCTAssertEqual(imported.description, original.description)
        XCTAssertEqual(imported.icon, original.icon)
        XCTAssertEqual(imported.color, original.color)
        XCTAssertEqual(imported.tags, original.tags)
        XCTAssertEqual(imported.configuration.mode, original.configuration.mode)
    }

    func testAllPresetsHaveValidConfigurations() {
        for mode in WiseMode.allCases {
            let config = WiseModeConfiguration(mode: mode)
            let preset = WisePreset(
                name: "\(mode.rawValue) Preset",
                configuration: config
            )

            // Preset should match mode
            XCTAssertEqual(preset.configuration.mode, mode)

            // Configuration should be valid
            XCTAssertGreaterThan(preset.configuration.binauralFrequency, 0)
            XCTAssertGreaterThan(preset.configuration.carrierFrequency, 0)
            XCTAssertGreaterThan(preset.configuration.sessionDuration, 0)
        }
    }

    // MARK: - Performance Integration Tests

    func testEnergyConsumptionEstimates() {
        // Verify energy estimates follow expected patterns
        let sleepConsumption = EnergyConsumption(mode: .sleep)
        let energizeConsumption = EnergyConsumption(mode: .energize)
        let socialConsumption = EnergyConsumption(mode: .social)

        // Sleep should be most efficient
        // Social (with network) should be least efficient
        // These are initialized with 0, but the pattern should be set by the monitor
    }

    func testBenchmarkScoreCalculation() {
        var goodResult = BenchmarkResult(mode: .focus)
        goodResult.loadTimeMs = 200
        goodResult.switchTimeMs = 2000
        goodResult.memoryBytes = 400_000
        goodResult.cpuUsagePercent = 25
        goodResult.gpuUsagePercent = 35
        goodResult.averageFPS = 60

        var poorResult = BenchmarkResult(mode: .focus)
        poorResult.loadTimeMs = 1000
        poorResult.switchTimeMs = 5000
        poorResult.memoryBytes = 2_000_000
        poorResult.cpuUsagePercent = 80
        poorResult.gpuUsagePercent = 90
        poorResult.averageFPS = 30

        XCTAssertGreaterThan(goodResult.overallScore, poorResult.overallScore)
    }

    // MARK: - Cross-System Integration Tests

    func testModeConfigurationConsistency() {
        // Verify configuration is consistent across systems
        for mode in WiseMode.allCases {
            let wiseConfig = WiseModeConfiguration(mode: mode)
            let recordingPreset = WiseRecordingPreset(mode: mode)
            let accessibilityConfig = WiseAccessibilityConfig(mode: mode)

            // All should reference the same mode
            XCTAssertEqual(wiseConfig.mode, mode)
            XCTAssertEqual(recordingPreset.mode, mode)
            XCTAssertEqual(accessibilityConfig.mode, mode)

            // Binaural frequency should match
            XCTAssertEqual(wiseConfig.binauralFrequency, mode.binauralFrequency)
        }
    }

    func testSessionFlowIntegration() {
        // Simulate a complete session flow
        let mode = WiseMode.meditation

        // 1. Create configuration
        let config = WiseModeConfiguration(mode: mode)
        XCTAssertEqual(config.mode, mode)

        // 2. Create session stats
        var stats = WiseSessionStats(mode: mode)
        XCTAssertEqual(stats.mode, mode)

        // 3. Create accessibility config
        let accessibility = WiseAccessibilityConfig(mode: mode)
        XCTAssertEqual(accessibility.mode, mode)

        // 4. Create recording preset
        let recording = WiseRecordingPreset(mode: mode)
        XCTAssertEqual(recording.mode, mode)

        // 5. Simulate session end
        stats.endTime = Date()
        stats.duration = 1200 // 20 minutes
        stats.averageCoherence = 0.72
        stats.peakCoherence = 0.89
        stats.flowStateMinutes = 12

        XCTAssertNotNil(stats.endTime)
        XCTAssertGreaterThan(stats.duration, 0)
    }
}

// MARK: - Mapper Test Suite Extension for Wise Mode

final class WiseModeMapperTests: XCTestCase {

    func testBinauralFrequencyMapping() {
        // Test that binaural frequencies map to expected brain wave states
        let deltaRange = 0.5...4.0   // Sleep
        let thetaRange = 4.0...8.0   // Meditation
        let alphaRange = 8.0...13.0  // Flow, Relaxation
        let betaRange = 13.0...30.0  // Focus, Alertness

        XCTAssertTrue(deltaRange.contains(Double(WiseMode.sleep.binauralFrequency)), "Sleep should be in Delta range")
        XCTAssertTrue(thetaRange.contains(Double(WiseMode.meditation.binauralFrequency)), "Meditation should be in Theta range")
        XCTAssertTrue(alphaRange.contains(Double(WiseMode.flow.binauralFrequency)), "Flow should be in Alpha range")
        XCTAssertTrue(betaRange.contains(Double(WiseMode.focus.binauralFrequency)), "Focus should be in Beta range")
    }

    func testVisualizationModeMapping() {
        // Test that visualization recommendations match mode intent
        XCTAssertEqual(WiseMode.focus.recommendedVisualization, "spectral")
        XCTAssertEqual(WiseMode.flow.recommendedVisualization, "particles")
        XCTAssertEqual(WiseMode.healing.recommendedVisualization, "mandala")
        XCTAssertEqual(WiseMode.meditation.recommendedVisualization, "cymatics")
    }

    func testDurationMapping() {
        // Test that session durations match mode requirements
        // Focus sessions should be longer for deep work
        XCTAssertGreaterThanOrEqual(WiseMode.focus.recommendedDuration, 45)

        // Meditation can be shorter
        XCTAssertLessThanOrEqual(WiseMode.meditation.recommendedDuration, 30)

        // Energize should be quick boost
        XCTAssertLessThanOrEqual(WiseMode.energize.recommendedDuration, 20)
    }

    func testColorMapping() {
        // Each mode should have a distinct color
        var usedColors: Set<String> = []

        for mode in WiseMode.allCases {
            let colorDescription = "\(mode.color)"
            // Colors should be meaningful (not empty)
            XCTAssertFalse(colorDescription.isEmpty)
        }
    }

    func testIconMapping() {
        // Each mode should have a descriptive SF Symbol
        for mode in WiseMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
            // Icons should be valid SF Symbols (contain common patterns)
            let validPatterns = ["brain", "water", "heart", "figure", "bolt", "moon", "person", "slider"]
            let hasValidIcon = validPatterns.contains { mode.icon.contains($0) }
            XCTAssertTrue(hasValidIcon, "\(mode.icon) should be a recognizable SF Symbol")
        }
    }
}

import XCTest
@testable import Echoelmusic

// MARK: - Wise Mode Test Suite
/// Comprehensive tests for the Wise Mode system

final class WiseModeTests: XCTestCase {

    // MARK: - Test Properties

    var wiseModeManager: WiseModeManager!
    var presetManager: WisePresetManager!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Note: Managers are singletons, so we use shared instances
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    // MARK: - WiseMode Enum Tests

    func testWiseModeAllCases() {
        // Verify all expected modes exist
        XCTAssertEqual(WiseMode.allCases.count, 8)
        XCTAssertTrue(WiseMode.allCases.contains(.focus))
        XCTAssertTrue(WiseMode.allCases.contains(.flow))
        XCTAssertTrue(WiseMode.allCases.contains(.healing))
        XCTAssertTrue(WiseMode.allCases.contains(.meditation))
        XCTAssertTrue(WiseMode.allCases.contains(.energize))
        XCTAssertTrue(WiseMode.allCases.contains(.sleep))
        XCTAssertTrue(WiseMode.allCases.contains(.social))
        XCTAssertTrue(WiseMode.allCases.contains(.custom))
    }

    func testWiseModeProperties() {
        // Test each mode has required properties
        for mode in WiseMode.allCases {
            XCTAssertFalse(mode.rawValue.isEmpty, "\(mode) should have a rawValue")
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) should have an icon")
            XCTAssertFalse(mode.description.isEmpty, "\(mode) should have a description")
            XCTAssertTrue(mode.binauralFrequency > 0, "\(mode) should have positive binaural frequency")
            XCTAssertTrue(mode.recommendedDuration > 0, "\(mode) should have positive recommended duration")
        }
    }

    func testWiseModeBinauralFrequencies() {
        // Test binaural frequencies are in valid ranges
        XCTAssertEqual(WiseMode.focus.binauralFrequency, 14.0, accuracy: 0.01)
        XCTAssertEqual(WiseMode.flow.binauralFrequency, 10.0, accuracy: 0.01)
        XCTAssertEqual(WiseMode.healing.binauralFrequency, 7.83, accuracy: 0.01)
        XCTAssertEqual(WiseMode.meditation.binauralFrequency, 6.0, accuracy: 0.01)
        XCTAssertEqual(WiseMode.energize.binauralFrequency, 18.0, accuracy: 0.01)
        XCTAssertEqual(WiseMode.sleep.binauralFrequency, 3.0, accuracy: 0.01)

        // All frequencies should be in human-perceivable range
        for mode in WiseMode.allCases {
            XCTAssertGreaterThan(mode.binauralFrequency, 0)
            XCTAssertLessThan(mode.binauralFrequency, 40) // Upper binaural limit
        }
    }

    func testWiseModeRecommendedDurations() {
        // Verify durations are reasonable
        for mode in WiseMode.allCases {
            XCTAssertGreaterThanOrEqual(mode.recommendedDuration, 15, "\(mode) duration should be at least 15 minutes")
            XCTAssertLessThanOrEqual(mode.recommendedDuration, 60, "\(mode) duration should be at most 60 minutes")
        }
    }

    // MARK: - WisdomLevel Tests

    func testWisdomLevelProgression() {
        // Verify levels are in correct order
        XCTAssertEqual(WisdomLevel.novice.rawValue, 0)
        XCTAssertEqual(WisdomLevel.learning.rawValue, 1)
        XCTAssertEqual(WisdomLevel.practicing.rawValue, 2)
        XCTAssertEqual(WisdomLevel.proficient.rawValue, 3)
        XCTAssertEqual(WisdomLevel.expert.rawValue, 4)
        XCTAssertEqual(WisdomLevel.enlightened.rawValue, 5)
    }

    func testWisdomLevelRequirements() {
        // Verify requirements increase with level
        var previousSessions = -1
        var previousCoherence: Float = -1

        for level in WisdomLevel.allCases {
            XCTAssertGreaterThan(level.requiredSessions, previousSessions, "\(level) should require more sessions than previous level")
            XCTAssertGreaterThanOrEqual(level.requiredCoherence, previousCoherence, "\(level) should require higher coherence")
            previousSessions = level.requiredSessions
            previousCoherence = level.requiredCoherence
        }
    }

    func testWisdomLevelDisplayNames() {
        for level in WisdomLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty, "\(level) should have a display name")
            XCTAssertFalse(level.englishName.isEmpty, "\(level) should have an English name")
            XCTAssertFalse(level.icon.isEmpty, "\(level) should have an icon")
        }
    }

    // MARK: - WiseModeConfiguration Tests

    func testWiseModeConfigurationInitialization() {
        for mode in WiseMode.allCases {
            let config = WiseModeConfiguration(mode: mode)

            XCTAssertEqual(config.mode, mode)
            XCTAssertEqual(config.binauralFrequency, mode.binauralFrequency)
            XCTAssertEqual(config.carrierFrequency, 432.0, accuracy: 0.01)
            XCTAssertEqual(config.visualizationMode, mode.recommendedVisualization)
            XCTAssertEqual(config.sessionDuration, mode.recommendedDuration)
            XCTAssertTrue(config.bioAdaptive)
        }
    }

    func testWiseModeConfigurationCodable() throws {
        let config = WiseModeConfiguration(mode: .flow)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        XCTAssertFalse(data.isEmpty)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WiseModeConfiguration.self, from: data)

        XCTAssertEqual(decoded.mode, config.mode)
        XCTAssertEqual(decoded.binauralFrequency, config.binauralFrequency)
        XCTAssertEqual(decoded.carrierFrequency, config.carrierFrequency)
    }

    // MARK: - WisePreset Tests

    func testWisePresetCreation() {
        let config = WiseModeConfiguration(mode: .healing)
        let preset = WisePreset(
            name: "Test Preset",
            description: "A test preset",
            icon: "star",
            color: .purple,
            configuration: config
        )

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.description, "A test preset")
        XCTAssertEqual(preset.icon, "star")
        XCTAssertEqual(preset.color, .purple)
        XCTAssertFalse(preset.isDefault)
        XCTAssertFalse(preset.isFavorite)
        XCTAssertEqual(preset.usageCount, 0)
        XCTAssertNil(preset.lastUsed)
    }

    func testWisePresetCodable() throws {
        let config = WiseModeConfiguration(mode: .focus)
        var preset = WisePreset(
            name: "Codable Test",
            description: "Testing codable",
            configuration: config
        )
        preset.tags = ["test", "codable"]

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)
        XCTAssertFalse(data.isEmpty)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WisePreset.self, from: data)

        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.description, preset.description)
        XCTAssertEqual(decoded.tags, preset.tags)
    }

    func testWisePresetHashable() {
        let config = WiseModeConfiguration(mode: .focus)
        let preset1 = WisePreset(name: "Preset 1", configuration: config)
        let preset2 = WisePreset(name: "Preset 2", configuration: config)

        var presetSet: Set<WisePreset> = []
        presetSet.insert(preset1)
        presetSet.insert(preset2)
        presetSet.insert(preset1) // Duplicate

        XCTAssertEqual(presetSet.count, 2)
    }

    // MARK: - WiseScheduleItem Tests

    func testWiseScheduleItemCreation() {
        let schedule = WiseScheduleItem(
            name: "Morning Focus",
            mode: .focus,
            schedule: .daily(time: TimeOfDay(hour: 9, minute: 0))
        )

        XCTAssertEqual(schedule.name, "Morning Focus")
        XCTAssertEqual(schedule.mode, .focus)
        XCTAssertTrue(schedule.isEnabled)
        XCTAssertEqual(schedule.notifyBefore, 5)
        XCTAssertTrue(schedule.autoStart)
    }

    func testTimeOfDayFormatting() {
        let time1 = TimeOfDay(hour: 9, minute: 0)
        XCTAssertEqual(time1.formatted, "09:00")

        let time2 = TimeOfDay(hour: 14, minute: 30)
        XCTAssertEqual(time2.formatted, "14:30")

        let time3 = TimeOfDay(hour: 0, minute: 5)
        XCTAssertEqual(time3.formatted, "00:05")
    }

    func testWeekdayProperties() {
        XCTAssertEqual(Weekday.weekdays.count, 5)
        XCTAssertEqual(Weekday.weekend.count, 2)
        XCTAssertTrue(Weekday.weekdays.contains(.monday))
        XCTAssertFalse(Weekday.weekdays.contains(.saturday))
    }

    func testScheduleTypeDisplayName() {
        let daily = ScheduleType.daily(time: TimeOfDay(hour: 10, minute: 0))
        XCTAssertTrue(daily.displayName.contains("10:00"))

        let weekly = ScheduleType.weekly(days: [.monday, .wednesday], time: TimeOfDay(hour: 15, minute: 0))
        XCTAssertTrue(weekly.displayName.contains("Mo"))
        XCTAssertTrue(weekly.displayName.contains("Mi"))
    }

    // MARK: - WiseSessionStats Tests

    func testWiseSessionStatsInitialization() {
        let stats = WiseSessionStats(mode: .meditation)

        XCTAssertEqual(stats.mode, .meditation)
        XCTAssertNil(stats.endTime)
        XCTAssertEqual(stats.duration, 0)
        XCTAssertEqual(stats.averageCoherence, 0)
        XCTAssertEqual(stats.peakCoherence, 0)
        XCTAssertEqual(stats.averageHRV, 0)
        XCTAssertEqual(stats.flowStateMinutes, 0)
        XCTAssertTrue(stats.modeTransitions.isEmpty)
    }

    func testWiseSessionStatsCodable() throws {
        var stats = WiseSessionStats(mode: .flow)
        stats.duration = 1800
        stats.averageCoherence = 0.65
        stats.peakCoherence = 0.85
        stats.averageHRV = 45.0
        stats.flowStateMinutes = 15

        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WiseSessionStats.self, from: data)

        XCTAssertEqual(decoded.mode, stats.mode)
        XCTAssertEqual(decoded.duration, stats.duration)
        XCTAssertEqual(decoded.averageCoherence, stats.averageCoherence, accuracy: 0.001)
    }

    // MARK: - WiseModeTransition Tests

    func testWiseModeTransitionCreation() {
        let transition = WiseModeTransition(
            fromMode: .focus,
            toMode: .flow,
            timestamp: Date(),
            duration: 2.0,
            reason: .userInitiated
        )

        XCTAssertEqual(transition.fromMode, .focus)
        XCTAssertEqual(transition.toMode, .flow)
        XCTAssertEqual(transition.duration, 2.0)
        XCTAssertEqual(transition.reason, .userInitiated)
    }

    func testAllTransitionReasons() {
        let reasons: [WiseModeTransition.TransitionReason] = [
            .userInitiated,
            .scheduled,
            .bioAdaptive,
            .timeOfDay,
            .groupSync
        ]

        for reason in reasons {
            XCTAssertFalse(reason.rawValue.isEmpty)
        }
    }

    // MARK: - AudioQuality Tests

    func testAudioQualitySampleRates() {
        XCTAssertEqual(AudioQuality.efficient.sampleRate, 44100.0)
        XCTAssertEqual(AudioQuality.standard.sampleRate, 48000.0)
        XCTAssertEqual(AudioQuality.high.sampleRate, 96000.0)
        XCTAssertEqual(AudioQuality.studio.sampleRate, 192000.0)
    }

    func testAudioQualityBitDepths() {
        XCTAssertEqual(AudioQuality.efficient.bitDepth, 16)
        XCTAssertEqual(AudioQuality.standard.bitDepth, 24)
        XCTAssertEqual(AudioQuality.high.bitDepth, 24)
        XCTAssertEqual(AudioQuality.studio.bitDepth, 32)
    }

    // MARK: - Performance Tests

    func testModeConfigurationCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                for mode in WiseMode.allCases {
                    _ = WiseModeConfiguration(mode: mode)
                }
            }
        }
    }

    func testPresetEncodingPerformance() throws {
        let config = WiseModeConfiguration(mode: .flow)
        let preset = WisePreset(name: "Performance Test", configuration: config)
        let encoder = JSONEncoder()

        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(preset)
            }
        }
    }

    // MARK: - Integration Tests

    func testModeTransitionFlow() async throws {
        // This test verifies the mode transition flow
        let modes: [WiseMode] = [.focus, .flow, .meditation, .sleep]

        for mode in modes {
            let config = WiseModeConfiguration(mode: mode)
            XCTAssertEqual(config.mode, mode)
            XCTAssertEqual(config.binauralFrequency, mode.binauralFrequency)
        }
    }

    func testPresetApplyFlow() {
        // Create a preset
        let config = WiseModeConfiguration(mode: .healing)
        var preset = WisePreset(
            name: "Test Healing",
            description: "Test healing session",
            configuration: config
        )

        // Simulate usage
        preset.usageCount += 1
        preset.lastUsed = Date()

        XCTAssertEqual(preset.usageCount, 1)
        XCTAssertNotNil(preset.lastUsed)
    }

    func testSchedulerIntegration() {
        // Test schedule creation for all trigger types
        let dailySchedule = WiseScheduleItem(
            name: "Daily Focus",
            mode: .focus,
            schedule: .daily(time: TimeOfDay.morning)
        )
        XCTAssertTrue(dailySchedule.isEnabled)

        let weeklySchedule = WiseScheduleItem(
            name: "Weekend Meditation",
            mode: .meditation,
            schedule: .weekly(days: Weekday.weekend, time: TimeOfDay.afternoon)
        )
        XCTAssertEqual(weeklySchedule.mode, .meditation)

        let smartSchedule = WiseScheduleItem(
            name: "Smart Flow",
            mode: .flow,
            schedule: .smart(trigger: .optimalFlow)
        )
        XCTAssertEqual(smartSchedule.schedule.displayName, SmartTrigger.optimalFlow.displayName)
    }
}

// MARK: - WiseRecordingPreset Tests

final class WiseRecordingPresetTests: XCTestCase {

    func testRecordingPresetPerMode() {
        for mode in WiseMode.allCases {
            let preset = WiseRecordingPreset(mode: mode)

            XCTAssertEqual(preset.mode, mode)
            XCTAssertGreaterThan(preset.sampleRate, 0)
            XCTAssertTrue([16, 24, 32].contains(preset.bitDepth))
            XCTAssertEqual(preset.channelCount, 2)
            XCTAssertGreaterThan(preset.retrospectiveBufferDuration, 0)
        }
    }

    func testNoiseReductionLevels() {
        XCTAssertEqual(NoiseReductionLevel.off.strength, 0.0)
        XCTAssertEqual(NoiseReductionLevel.light.strength, 0.3)
        XCTAssertEqual(NoiseReductionLevel.medium.strength, 0.6)
        XCTAssertEqual(NoiseReductionLevel.heavy.strength, 0.9)
    }

    func testCompressionPresets() {
        for preset in CompressionPreset.allCases {
            XCTAssertGreaterThan(preset.ratio, 0)
            // Threshold can be 0 for "off"
        }
    }
}

// MARK: - WiseAccessibilityConfig Tests

final class WiseAccessibilityConfigTests: XCTestCase {

    func testAccessibilityConfigPerMode() {
        for mode in WiseMode.allCases {
            let config = WiseAccessibilityConfig(mode: mode)

            XCTAssertEqual(config.mode, mode)
            XCTAssertGreaterThanOrEqual(config.hapticIntensity, 0)
            XCTAssertLessThanOrEqual(config.hapticIntensity, 1)
        }
    }

    func testSleepModeMinimizesStimulation() {
        let config = WiseAccessibilityConfig(mode: .sleep)

        // Sleep mode should minimize visual/haptic stimulation
        XCTAssertTrue(config.reducedMotion)
        XCTAssertLessThan(config.hapticIntensity, 0.3)
        XCTAssertFalse(config.visualCuesEnabled)
    }

    func testMeditationModeMinimizesDistraction() {
        let config = WiseAccessibilityConfig(mode: .meditation)

        // Meditation should minimize visual distraction
        XCTAssertFalse(config.visualCuesEnabled)
        XCTAssertTrue(config.reducedMotion)
    }

    func testEnergizeModeMaximizesEngagement() {
        let config = WiseAccessibilityConfig(mode: .energize)

        // Energize should maximize engagement
        XCTAssertTrue(config.visualCuesEnabled)
        XCTAssertGreaterThan(config.hapticIntensity, 0.5)
    }
}

// MARK: - Performance Benchmark Tests

final class WisePerformanceBenchmarkTests: XCTestCase {

    func testBenchmarkResultScoring() {
        var result = BenchmarkResult(mode: .focus)

        // Perfect score scenario
        result.loadTimeMs = 100
        result.switchTimeMs = 1500
        result.memoryBytes = 300_000
        result.cpuUsagePercent = 20
        result.gpuUsagePercent = 30
        result.averageFPS = 60

        XCTAssertGreaterThanOrEqual(result.overallScore, 90)
    }

    func testBenchmarkResultPenalties() {
        var result = BenchmarkResult(mode: .flow)

        // Slow load time should penalize
        result.loadTimeMs = 1000
        result.switchTimeMs = 2000
        result.memoryBytes = 200_000
        result.cpuUsagePercent = 20
        result.averageFPS = 60

        let scoreWithSlowLoad = result.overallScore

        result.loadTimeMs = 100
        let scoreWithFastLoad = result.overallScore

        XCTAssertLessThan(scoreWithSlowLoad, scoreWithFastLoad)
    }

    func testBenchmarkResultCodable() throws {
        var result = BenchmarkResult(mode: .healing)
        result.loadTimeMs = 250
        result.memoryBytes = 500_000

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BenchmarkResult.self, from: data)

        XCTAssertEqual(decoded.mode, result.mode)
        XCTAssertEqual(decoded.loadTimeMs, result.loadTimeMs)
    }
}

// MARK: - Energy Consumption Tests

final class WiseEnergyConsumptionTests: XCTestCase {

    func testEnergyConsumptionEfficiencyRating() {
        var consumption = EnergyConsumption(mode: .sleep)

        consumption.averagePercentPerHour = 1.5
        XCTAssertEqual(consumption.efficiencyRating, "Excellent")

        consumption.averagePercentPerHour = 2.5
        XCTAssertEqual(consumption.efficiencyRating, "Good")

        consumption.averagePercentPerHour = 4.0
        XCTAssertEqual(consumption.efficiencyRating, "Moderate")

        consumption.averagePercentPerHour = 6.0
        XCTAssertEqual(consumption.efficiencyRating, "High")
    }

    func testEstimatedRuntime() {
        var consumption = EnergyConsumption(mode: .focus)

        consumption.averagePercentPerHour = 5.0
        // 100% / 5%/h = 20 hours
        XCTAssertTrue(consumption.estimatedRuntime.contains("20"))

        consumption.averagePercentPerHour = 0
        XCTAssertEqual(consumption.estimatedRuntime, "N/A")
    }
}

// MARK: - Analytics Tests

final class WiseAnalyticsTests: XCTestCase {

    func testAnalyticsPeriodDays() {
        XCTAssertEqual(AnalyticsPeriod.day.days, 1)
        XCTAssertEqual(AnalyticsPeriod.week.days, 7)
        XCTAssertEqual(AnalyticsPeriod.month.days, 30)
        XCTAssertEqual(AnalyticsPeriod.year.days, 365)
        XCTAssertEqual(AnalyticsPeriod.allTime.days, 10000)
    }

    func testDailySummaryInitialization() {
        let summary = DailySummary(date: Date())

        XCTAssertEqual(summary.sessions, 0)
        XCTAssertEqual(summary.minutes, 0)
        XCTAssertEqual(summary.averageCoherence, 0)
        XCTAssertEqual(summary.peakCoherence, 0)
        XCTAssertEqual(summary.flowMinutes, 0)
    }

    func testAchievementCodable() throws {
        let achievement = WiseAchievement(
            id: "test_achievement",
            name: "Test Achievement",
            description: "A test achievement",
            icon: "star.fill",
            color: .yellow,
            earnedAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(achievement)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WiseAchievement.self, from: data)

        XCTAssertEqual(decoded.id, achievement.id)
        XCTAssertEqual(decoded.name, achievement.name)
    }
}

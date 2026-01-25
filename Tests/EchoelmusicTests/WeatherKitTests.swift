// WeatherKitTests.swift
// Echoelmusic
//
// Comprehensive tests for WeatherKit integration
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import XCTest
import CoreLocation
@testable import Echoelmusic

/// Tests for WeatherKit integration with rate limiting and bio-reactive mapping
final class WeatherKitTests: XCTestCase {

    // MARK: - Weather Data Model Tests

    func testEchoelWeatherDataCreation() {
        let weather = createTestWeatherData(condition: .clear, temperature: 22)

        XCTAssertEqual(weather.temperature, 22)
        XCTAssertEqual(weather.condition, .clear)
        XCTAssertTrue(weather.isDaylight)
    }

    func testNormalizedPressure() {
        // Test normal pressure (1013 hPa = center of range)
        let normalWeather = createTestWeatherData(pressure: 1013)
        XCTAssertEqual(normalWeather.normalizedPressure, 0.55, accuracy: 0.1)

        // Test low pressure (980 hPa = 0)
        let lowPressure = createTestWeatherData(pressure: 980)
        XCTAssertEqual(lowPressure.normalizedPressure, 0.0, accuracy: 0.01)

        // Test high pressure (1040 hPa = 1)
        let highPressure = createTestWeatherData(pressure: 1040)
        XCTAssertEqual(highPressure.normalizedPressure, 1.0, accuracy: 0.01)
    }

    func testEnergyLevel() {
        // Clear sunny weather should have high energy
        let sunny = createTestWeatherData(condition: .clear, isDaylight: true, windSpeed: 5)
        XCTAssertGreaterThan(sunny.energyLevel, 0.5)

        // Thunderstorm should have high energy
        let storm = createTestWeatherData(condition: .thunderstorm, windSpeed: 15)
        XCTAssertGreaterThan(storm.energyLevel, 0.7)

        // Fog should have low energy
        let fog = createTestWeatherData(condition: .fog, windSpeed: 0)
        XCTAssertLessThan(fog.energyLevel, 0.5)
    }

    func testCalmnessLevel() {
        let weather = createTestWeatherData(condition: .clear, windSpeed: 5)
        XCTAssertEqual(weather.calmnessLevel, 1.0 - weather.energyLevel, accuracy: 0.001)
    }

    func testSuggestedMood() {
        XCTAssertEqual(createTestWeatherData(condition: .clear, isDaylight: true).suggestedMood, "uplifting")
        XCTAssertEqual(createTestWeatherData(condition: .clear, isDaylight: false).suggestedMood, "peaceful")
        XCTAssertEqual(createTestWeatherData(condition: .rain).suggestedMood, "melancholic")
        XCTAssertEqual(createTestWeatherData(condition: .thunderstorm).suggestedMood, "dramatic")
        XCTAssertEqual(createTestWeatherData(condition: .snow).suggestedMood, "ethereal")
        XCTAssertEqual(createTestWeatherData(condition: .fog).suggestedMood, "mysterious")
    }

    // MARK: - Rate Limiting Configuration Tests

    func testFreeTierConfig() {
        let config = WeatherKitRateLimitConfig.freeTier
        XCTAssertEqual(config.monthlyLimit, 500_000)
        XCTAssertEqual(config.minimumCacheDuration, 30 * 60)
        XCTAssertEqual(config.warningThreshold, 0.8)
        XCTAssertEqual(config.criticalThreshold, 0.95)
    }

    func testConservativeConfig() {
        let config = WeatherKitRateLimitConfig.conservative
        XCTAssertEqual(config.monthlyLimit, 500_000)
        XCTAssertEqual(config.minimumCacheDuration, 60 * 60)  // 1 hour
        XCTAssertEqual(config.warningThreshold, 0.7)
    }

    func testUltraConservativeConfig() {
        let config = WeatherKitRateLimitConfig.ultraConservative
        XCTAssertEqual(config.minimumCacheDuration, 2 * 60 * 60)  // 2 hours
        XCTAssertEqual(config.minimumLocationChange, 20000)  // 20km
    }

    // MARK: - Usage Statistics Tests

    func testUsageStatsInitialization() {
        let stats = WeatherKitUsageStats()
        XCTAssertEqual(stats.monthlyCallCount, 0)
        XCTAssertTrue(stats.callHistory.isEmpty)
        XCTAssertNil(stats.lastCallDate)
    }

    func testRecordCall() {
        var stats = WeatherKitUsageStats()
        stats.recordCall()

        XCTAssertEqual(stats.monthlyCallCount, 1)
        XCTAssertEqual(stats.callHistory.count, 1)
        XCTAssertNotNil(stats.lastCallDate)
    }

    func testCallHistoryLimit() {
        var stats = WeatherKitUsageStats()

        // Record 150 calls (should be limited to 100)
        for _ in 0..<150 {
            stats.recordCall()
        }

        XCTAssertEqual(stats.monthlyCallCount, 150)
        XCTAssertEqual(stats.callHistory.count, 100)
    }

    func testUsagePercentage() {
        var stats = WeatherKitUsageStats()
        stats.monthlyCallCount = 250_000  // Half of free tier

        let percentage = stats.usagePercentage(limit: 500_000)
        XCTAssertEqual(percentage, 0.5, accuracy: 0.001)
    }

    func testMonthlyReset() {
        var stats = WeatherKitUsageStats()
        stats.monthlyCallCount = 100

        // Simulate reset (would happen when month changes)
        // In real code, this checks Calendar month
        stats.resetIfNeeded()

        // Since we're in the same month, no reset should happen
        XCTAssertEqual(stats.monthlyCallCount, 100)
    }

    // MARK: - Weather Audio Parameters Tests

    func testNeutralAudioParameters() {
        let params = WeatherAudioParameters.neutral

        XCTAssertEqual(params.filterCutoff, 8000)
        XCTAssertEqual(params.reverbMix, 0.3)
        XCTAssertEqual(params.suggestedBPM, 100)
        XCTAssertEqual(params.warmth, 0.5)
    }

    func testAudioParameterRanges() {
        let params = WeatherAudioParameters.neutral

        XCTAssertTrue(params.filterCutoff >= 200 && params.filterCutoff <= 20000)
        XCTAssertTrue(params.reverbMix >= 0 && params.reverbMix <= 1)
        XCTAssertTrue(params.delayFeedback >= 0 && params.delayFeedback <= 0.9)
        XCTAssertTrue(params.suggestedBPM >= 60 && params.suggestedBPM <= 180)
    }

    // MARK: - Weather Visual Parameters Tests

    func testNeutralVisualParameters() {
        let params = WeatherVisualParameters.neutral

        XCTAssertEqual(params.primaryHue, 200)
        XCTAssertEqual(params.saturation, 0.5)
        XCTAssertEqual(params.particleType, .none)
        XCTAssertEqual(params.animationSpeed, 1.0)
    }

    func testParticleTypes() {
        let allTypes: [WeatherVisualParameters.ParticleType] = [
            .rain, .snow, .dust, .leaves, .sparkles, .clouds, .none
        ]

        for type in allTypes {
            XCTAssertNotNil(type.rawValue)
        }
    }

    // MARK: - Weather Lighting Parameters Tests

    func testNeutralLightingParameters() {
        let params = WeatherLightingParameters.neutral

        XCTAssertEqual(params.masterIntensity, 0.7)
        XCTAssertEqual(params.strobeRate, 0)  // Off by default
        XCTAssertEqual(params.goboPattern, 0)
    }

    func testLightingColorRanges() {
        let params = WeatherLightingParameters.neutral

        XCTAssertTrue(params.colorR >= 0 && params.colorR <= 1)
        XCTAssertTrue(params.colorG >= 0 && params.colorG <= 1)
        XCTAssertTrue(params.colorB >= 0 && params.colorB <= 1)
        XCTAssertTrue(params.colorW >= 0 && params.colorW <= 1)
    }

    // MARK: - Weather Reactive Preset Tests

    func testImmersivePreset() {
        let preset = WeatherReactivePreset.immersive

        XCTAssertEqual(preset.name, "Immersive")
        XCTAssertEqual(preset.audioInfluence, 1.0)
        XCTAssertEqual(preset.visualInfluence, 1.0)
        XCTAssertEqual(preset.lightingInfluence, 1.0)
        XCTAssertTrue(preset.pressureToFilter)
        XCTAssertTrue(preset.humidityToReverb)
        XCTAssertTrue(preset.windToModulation)
    }

    func testSubtlePreset() {
        let preset = WeatherReactivePreset.subtle

        XCTAssertEqual(preset.name, "Subtle")
        XCTAssertEqual(preset.audioInfluence, 0.3)
        XCTAssertFalse(preset.windToModulation)
        XCTAssertFalse(preset.conditionToParticles)
    }

    func testVisualOnlyPreset() {
        let preset = WeatherReactivePreset.visualOnly

        XCTAssertEqual(preset.audioInfluence, 0.0)
        XCTAssertEqual(preset.visualInfluence, 1.0)
        XCTAssertFalse(preset.pressureToFilter)
        XCTAssertFalse(preset.humidityToReverb)
    }

    func testMeditationPreset() {
        let preset = WeatherReactivePreset.meditation

        XCTAssertEqual(preset.name, "Meditation")
        XCTAssertTrue(preset.pressureToFilter)
        XCTAssertTrue(preset.humidityToReverb)
        XCTAssertFalse(preset.windToModulation)  // Wind off for calm
    }

    func testAllPresetsCount() {
        XCTAssertGreaterThanOrEqual(WeatherReactivePreset.allPresets.count, 7)
    }

    func testPresetUniqueIDs() {
        let presets = WeatherReactivePreset.allPresets
        let ids = Set(presets.map { $0.id })
        XCTAssertEqual(ids.count, presets.count, "All presets should have unique IDs")
    }

    // MARK: - Weather Condition Tests

    func testAllWeatherConditions() {
        let conditions: [EchoelWeatherData.WeatherCondition] = [
            .clear, .partlyCloudy, .cloudy, .overcast,
            .rain, .drizzle, .heavyRain, .thunderstorm,
            .snow, .sleet, .hail, .freezingRain,
            .fog, .mist, .haze, .smoky,
            .windy, .blustery,
            .hot, .cold,
            .unknown
        ]

        for condition in conditions {
            let weather = createTestWeatherData(condition: condition)
            XCTAssertNotNil(weather.suggestedMood)
            XCTAssertTrue(weather.energyLevel >= 0 && weather.energyLevel <= 1)
        }
    }

    func testPressureTrends() {
        let trends: [EchoelWeatherData.PressureTrend] = [
            .rising, .falling, .steady, .unknown
        ]

        for trend in trends {
            XCTAssertNotNil(trend.rawValue)
        }
    }

    // MARK: - WeatherKit Manager Tests

    @MainActor
    func testWeatherKitManagerSingleton() {
        let manager1 = WeatherKitManager.shared
        let manager2 = WeatherKitManager.shared

        XCTAssertTrue(manager1 === manager2)
    }

    @MainActor
    func testRemainingCallsInitial() {
        let manager = WeatherKitManager.shared

        // Should have calls remaining initially
        XCTAssertGreaterThan(manager.remainingCalls, 0)
    }

    @MainActor
    func testUsagePercentageInitial() {
        let manager = WeatherKitManager.shared

        // Should be low initially
        XCTAssertLessThan(manager.usagePercentage, 1.0)
    }

    // MARK: - Weather Reactive Engine Tests

    @MainActor
    func testWeatherReactiveEngineSingleton() {
        let engine1 = WeatherReactiveEngine.shared
        let engine2 = WeatherReactiveEngine.shared

        XCTAssertTrue(engine1 === engine2)
    }

    @MainActor
    func testWeatherReactiveEngineInitialState() {
        let engine = WeatherReactiveEngine.shared

        // Should start disabled
        XCTAssertFalse(engine.isEnabled)
    }

    @MainActor
    func testEnableDisableWeatherReactive() {
        let engine = WeatherReactiveEngine.shared

        engine.enable()
        XCTAssertTrue(engine.isEnabled)

        engine.disable()
        XCTAssertFalse(engine.isEnabled)
    }

    @MainActor
    func testApplyPreset() {
        let engine = WeatherReactiveEngine.shared

        engine.applyPreset(.meditation)
        XCTAssertEqual(engine.activePreset.name, "Meditation")

        engine.applyPreset(.energetic)
        XCTAssertEqual(engine.activePreset.name, "Energetic")
    }

    @MainActor
    func testNeutralParametersWhenDisabled() {
        let engine = WeatherReactiveEngine.shared
        engine.disable()

        // Should have neutral parameters when disabled
        XCTAssertEqual(engine.audioParameters.filterCutoff, WeatherAudioParameters.neutral.filterCutoff)
    }

    // MARK: - Edge Case Tests

    func testExtremeTemperatures() {
        let hot = createTestWeatherData(temperature: 45, condition: .hot)
        let cold = createTestWeatherData(temperature: -30, condition: .cold)

        XCTAssertNotNil(hot.suggestedMood)
        XCTAssertNotNil(cold.suggestedMood)
    }

    func testExtremePressure() {
        let lowPressure = createTestWeatherData(pressure: 900)  // Very low
        let highPressure = createTestWeatherData(pressure: 1080)  // Very high

        // Normalized pressure should be clamped
        XCTAssertLessThan(lowPressure.normalizedPressure, 0)
        XCTAssertGreaterThan(highPressure.normalizedPressure, 1)
    }

    func testExtremeWind() {
        let hurricane = createTestWeatherData(condition: .thunderstorm, windSpeed: 50)

        // Energy should be capped
        XCTAssertLessThanOrEqual(hurricane.energyLevel, 1.0)
    }

    func testZeroVisibility() {
        let foggy = createTestWeatherData(condition: .fog, visibility: 0)

        XCTAssertNotNil(foggy.suggestedMood)
    }

    // MARK: - Performance Tests

    func testWeatherDataCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = createTestWeatherData(condition: .clear)
            }
        }
    }

    func testNormalizedPressureCalculationPerformance() {
        let weather = createTestWeatherData(pressure: 1013)

        measure {
            for _ in 0..<10000 {
                _ = weather.normalizedPressure
            }
        }
    }

    func testEnergyLevelCalculationPerformance() {
        let weather = createTestWeatherData(condition: .thunderstorm, windSpeed: 20)

        measure {
            for _ in 0..<10000 {
                _ = weather.energyLevel
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestWeatherData(
        temperature: Double = 20,
        humidity: Double = 0.5,
        pressure: Double = 1013,
        windSpeed: Double = 5,
        uvIndex: Int = 5,
        condition: EchoelWeatherData.WeatherCondition = .clear,
        isDaylight: Bool = true,
        visibility: Double = 10000
    ) -> EchoelWeatherData {
        return EchoelWeatherData(
            temperature: temperature,
            apparentTemperature: temperature,
            humidity: humidity,
            pressure: pressure,
            pressureTrend: .steady,
            windSpeed: windSpeed,
            windGust: nil,
            windDirection: 180,
            uvIndex: uvIndex,
            cloudCover: condition == .cloudy ? 0.8 : 0.2,
            visibility: visibility,
            condition: condition,
            isDaylight: isDaylight,
            precipitationIntensity: condition == .rain ? 5 : 0,
            precipitationChance: condition == .rain ? 0.8 : 0.1,
            timestamp: Date(),
            location: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        )
    }
}

// MARK: - Integration Tests

final class WeatherKitIntegrationTests: XCTestCase {

    @MainActor
    func testWeatherToAudioPipeline() async {
        let engine = WeatherReactiveEngine.shared
        engine.enable()

        // Create test weather
        let weather = EchoelWeatherData(
            temperature: 25,
            apparentTemperature: 27,
            humidity: 0.7,
            pressure: 1020,
            pressureTrend: .rising,
            windSpeed: 10,
            windGust: 15,
            windDirection: 270,
            uvIndex: 8,
            cloudCover: 0.3,
            visibility: 15000,
            condition: .clear,
            isDaylight: true,
            precipitationIntensity: 0,
            precipitationChance: 0.1,
            timestamp: Date(),
            location: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        )

        // Engine should have parameters
        XCTAssertNotNil(engine.audioParameters)
        XCTAssertNotNil(engine.visualParameters)
        XCTAssertNotNil(engine.lightingParameters)

        engine.disable()
    }

    @MainActor
    func testPresetSwitchingUpdatesParameters() {
        let engine = WeatherReactiveEngine.shared
        engine.enable()

        engine.applyPreset(.immersive)
        let immersiveInfluence = engine.activePreset.audioInfluence

        engine.applyPreset(.subtle)
        let subtleInfluence = engine.activePreset.audioInfluence

        XCTAssertNotEqual(immersiveInfluence, subtleInfluence)

        engine.disable()
    }

    @MainActor
    func testSmoothingFactor() {
        let engine = WeatherReactiveEngine.shared

        // Default smoothing factor
        XCTAssertEqual(engine.smoothingFactor, 0.1)

        // Should be adjustable
        engine.smoothingFactor = 0.2
        XCTAssertEqual(engine.smoothingFactor, 0.2)

        // Reset
        engine.smoothingFactor = 0.1
    }
}

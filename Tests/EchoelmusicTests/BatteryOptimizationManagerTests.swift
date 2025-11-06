import XCTest
@testable import Echoelmusic

/// Unit tests for BatteryOptimizationManager
@MainActor
final class BatteryOptimizationManagerTests: XCTestCase {

    var sut: BatteryOptimizationManager!

    override func setUp() async throws {
        sut = BatteryOptimizationManager()
    }

    override func tearDown() async throws {
        sut = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut, "BatteryOptimizationManager should initialize")
    }

    func testInitialOptimizationLevel() {
        // Initial level should be .none (no optimization)
        XCTAssertEqual(sut.optimizationLevel, .none, "Initial optimization level should be none")
    }

    // MARK: - Optimization Level Tests

    func testOptimizationLevelNone() {
        sut.setOptimizationLevel(.none)

        XCTAssertEqual(sut.optimizationLevel, .none)
        XCTAssertEqual(sut.targetFPS, 60)
        XCTAssertEqual(sut.qualityPreset, .high)
    }

    func testOptimizationLevelModerate() {
        sut.setOptimizationLevel(.moderate)

        XCTAssertEqual(sut.optimizationLevel, .moderate)
        XCTAssertEqual(sut.targetFPS, 30)
        XCTAssertEqual(sut.qualityPreset, .medium)
    }

    func testOptimizationLevelAggressive() {
        sut.setOptimizationLevel(.aggressive)

        XCTAssertEqual(sut.optimizationLevel, .aggressive)
        XCTAssertEqual(sut.targetFPS, 15)
        XCTAssertEqual(sut.qualityPreset, .low)
    }

    // MARK: - Battery Level Tests

    func testHighBatteryLevel() {
        // Simulate high battery level (>50%)
        sut.updateBatteryLevel(0.8)

        let recommendedLevel = sut.getRecommendedOptimizationLevel(
            batteryLevel: 0.8,
            isLowPowerMode: false
        )

        XCTAssertEqual(recommendedLevel, .none, "High battery should recommend no optimization")
    }

    func testMediumBatteryLevel() {
        // Simulate medium battery level (20-50%)
        sut.updateBatteryLevel(0.35)

        let recommendedLevel = sut.getRecommendedOptimizationLevel(
            batteryLevel: 0.35,
            isLowPowerMode: false
        )

        XCTAssertEqual(recommendedLevel, .moderate, "Medium battery should recommend moderate optimization")
    }

    func testLowBatteryLevel() {
        // Simulate low battery level (<20%)
        sut.updateBatteryLevel(0.15)

        let recommendedLevel = sut.getRecommendedOptimizationLevel(
            batteryLevel: 0.15,
            isLowPowerMode: false
        )

        XCTAssertEqual(recommendedLevel, .aggressive, "Low battery should recommend aggressive optimization")
    }

    func testLowPowerModeEnabled() {
        // Low Power Mode should trigger aggressive optimization regardless of battery level
        sut.updateBatteryLevel(0.8)

        let recommendedLevel = sut.getRecommendedOptimizationLevel(
            batteryLevel: 0.8,
            isLowPowerMode: true
        )

        XCTAssertEqual(recommendedLevel, .aggressive, "Low Power Mode should always recommend aggressive optimization")
    }

    // MARK: - Estimated Savings Tests

    func testEstimatedSavingsNone() {
        sut.setOptimizationLevel(.none)

        XCTAssertEqual(sut.estimatedBatterySavingsPercentage, 0, "No optimization should have 0% savings")
    }

    func testEstimatedSavingsModerate() {
        sut.setOptimizationLevel(.moderate)

        XCTAssertEqual(sut.estimatedBatterySavingsPercentage, 10, "Moderate optimization should have ~10% savings")
    }

    func testEstimatedSavingsAggressive() {
        sut.setOptimizationLevel(.aggressive)

        XCTAssertEqual(sut.estimatedBatterySavingsPercentage, 25, "Aggressive optimization should have ~25% savings")
    }

    // MARK: - Quality Preset Tests

    func testQualityPresetForOptimizationLevel() {
        let testCases: [(OptimizationLevel, AdaptiveQuality)] = [
            (.none, .high),
            (.moderate, .medium),
            (.aggressive, .low)
        ]

        for (level, expectedQuality) in testCases {
            sut.setOptimizationLevel(level)
            XCTAssertEqual(
                sut.qualityPreset,
                expectedQuality,
                "Optimization level \(level) should map to quality preset \(expectedQuality)"
            )
        }
    }

    // MARK: - Target FPS Tests

    func testTargetFPSForOptimizationLevel() {
        let testCases: [(OptimizationLevel, Int)] = [
            (.none, 60),
            (.moderate, 30),
            (.aggressive, 15)
        ]

        for (level, expectedFPS) in testCases {
            sut.setOptimizationLevel(level)
            XCTAssertEqual(
                sut.targetFPS,
                expectedFPS,
                "Optimization level \(level) should map to target FPS \(expectedFPS)"
            )
        }
    }

    // MARK: - Automatic Optimization Tests

    func testAutomaticOptimizationEnabled() {
        sut.setAutomaticOptimization(enabled: true)

        XCTAssertTrue(sut.isAutomaticOptimizationEnabled, "Automatic optimization should be enabled")
    }

    func testAutomaticOptimizationDisabled() {
        sut.setAutomaticOptimization(enabled: false)

        XCTAssertFalse(sut.isAutomaticOptimizationEnabled, "Automatic optimization should be disabled")
    }

    func testAutomaticOptimizationAppliesRecommendedLevel() {
        sut.setAutomaticOptimization(enabled: true)

        // Simulate low battery
        sut.updateBatteryLevel(0.15)

        // With automatic optimization enabled, it should apply aggressive level
        // (This would happen automatically in production via monitoring)
        sut.applyRecommendedOptimization(batteryLevel: 0.15, isLowPowerMode: false)

        XCTAssertEqual(sut.optimizationLevel, .aggressive, "Automatic optimization should apply aggressive level for low battery")
    }

    // MARK: - Performance Tests

    func testSetOptimizationLevelPerformance() {
        measure {
            for _ in 0..<1000 {
                sut.setOptimizationLevel(.moderate)
                sut.setOptimizationLevel(.none)
            }
        }
    }

    func testGetRecommendedOptimizationLevelPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = sut.getRecommendedOptimizationLevel(batteryLevel: 0.5, isLowPowerMode: false)
            }
        }
    }
}

// MARK: - Test Helpers

extension BatteryOptimizationManager {
    /// Update battery level (test helper)
    func updateBatteryLevel(_ level: Float) {
        // In production, this would be called by UIDevice battery monitoring
        self.batteryLevel = level
    }

    /// Apply recommended optimization based on current state (test helper)
    func applyRecommendedOptimization(batteryLevel: Float, isLowPowerMode: Bool) {
        let recommended = getRecommendedOptimizationLevel(
            batteryLevel: batteryLevel,
            isLowPowerMode: isLowPowerMode
        )
        setOptimizationLevel(recommended)
    }
}

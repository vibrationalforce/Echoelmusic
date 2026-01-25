// CostBrakeTests.swift
// EchoelmusicTests
//
// Tests for the CostBrake (Kostenbremse) system
// Ensures cost limits of 500,000 EUR are properly enforced
//
// Created: 2026-01-25

import XCTest
@testable import Echoelmusic

@MainActor
final class CostBrakeTests: XCTestCase {

    var costBrake: CostBrake!

    override func setUp() async throws {
        try await super.setUp()
        // Create a fresh CostBrake with test configuration
        costBrake = CostBrake(configuration: .default)
        costBrake.reset(confirmationCode: "RESET_COSTS")
    }

    override func tearDown() async throws {
        costBrake.reset(confirmationCode: "RESET_COSTS")
        costBrake = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        XCTAssertEqual(costBrake.configuration.maxTotalCost, 500_000)
        XCTAssertTrue(costBrake.configuration.isEnabled)
        XCTAssertEqual(costBrake.configuration.blockingThreshold, 0.95)
    }

    func testStrictConfiguration() {
        let strictBrake = CostBrake(configuration: .strict)
        XCTAssertEqual(strictBrake.configuration.maxTotalCost, 500_000)
        XCTAssertEqual(strictBrake.configuration.blockingThreshold, 0.90)
        XCTAssertEqual(strictBrake.configuration.dailyLimit, 5_000)
        XCTAssertEqual(strictBrake.configuration.monthlyLimit, 100_000)
        XCTAssertNotNil(strictBrake.configuration.categoryLimits[.ai])
    }

    func testLenientConfiguration() {
        let lenientBrake = CostBrake(configuration: .lenient)
        XCTAssertEqual(lenientBrake.configuration.blockingThreshold, 0.99)
    }

    func testCustomConfiguration() {
        let customConfig = CostBrakeConfiguration(
            maxTotalCost: 100_000,
            isEnabled: true,
            blockingThreshold: 0.80,
            warningThresholds: [0.5, 0.7],
            categoryLimits: [.streaming: 10_000],
            dailyLimit: 1_000,
            monthlyLimit: 20_000
        )
        let customBrake = CostBrake(configuration: customConfig)

        XCTAssertEqual(customBrake.configuration.maxTotalCost, 100_000)
        XCTAssertEqual(customBrake.configuration.blockingThreshold, 0.80)
        XCTAssertEqual(customBrake.configuration.dailyLimit, 1_000)
    }

    // MARK: - Basic Cost Recording Tests

    func testRecordSingleCost() throws {
        try costBrake.recordCost(1000, category: .compute, description: "Test cost")

        XCTAssertEqual(costBrake.totalCost, 1000)
        XCTAssertEqual(costBrake.costByCategory[.compute], 1000)
        XCTAssertEqual(costBrake.costHistory.count, 1)
    }

    func testRecordMultipleCosts() throws {
        try costBrake.recordCost(1000, category: .compute, description: "Compute")
        try costBrake.recordCost(500, category: .storage, description: "Storage")
        try costBrake.recordCost(200, category: .network, description: "Network")

        XCTAssertEqual(costBrake.totalCost, 1700)
        XCTAssertEqual(costBrake.costByCategory[.compute], 1000)
        XCTAssertEqual(costBrake.costByCategory[.storage], 500)
        XCTAssertEqual(costBrake.costByCategory[.network], 200)
        XCTAssertEqual(costBrake.costHistory.count, 3)
    }

    func testRecordZeroCost() throws {
        try costBrake.recordCost(0, category: .compute, description: "Zero cost")

        // Zero cost should not be recorded
        XCTAssertEqual(costBrake.totalCost, 0)
        XCTAssertEqual(costBrake.costHistory.count, 0)
    }

    func testRecordNegativeCostIgnored() throws {
        try costBrake.recordCost(-100, category: .compute, description: "Negative cost")

        // Negative cost should not be recorded
        XCTAssertEqual(costBrake.totalCost, 0)
        XCTAssertEqual(costBrake.costHistory.count, 0)
    }

    // MARK: - Cost Limit Tests

    func testCanAffordUnderLimit() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Initial")

        XCTAssertTrue(costBrake.canAfford(estimatedCost: 1000, category: .compute))
    }

    func testCannotAffordAtBlockingThreshold() throws {
        // Record 95% of limit (blocking threshold)
        try costBrake.recordCost(475_000, category: .compute, description: "Near limit")

        // Should not be able to afford more than the remaining 5%
        XCTAssertFalse(costBrake.canAfford(estimatedCost: 30_000, category: .compute))
    }

    func testBlockedAtThreshold() throws {
        // Record exactly at blocking threshold (95%)
        try costBrake.recordCost(475_000, category: .compute, description: "At threshold")

        XCTAssertTrue(costBrake.isBlocked)
        XCTAssertEqual(costBrake.warningLevel, .blocked)
    }

    func testRecordCostThrowsWhenBlocked() throws {
        // Record to blocking threshold
        try costBrake.recordCost(475_000, category: .compute, description: "Near limit")

        // Try to record more than remaining budget
        XCTAssertThrowsError(try costBrake.recordCost(50_000, category: .compute, description: "Over limit")) { error in
            guard let costError = error as? CostBrakeError else {
                XCTFail("Expected CostBrakeError")
                return
            }
            if case .insufficientBudget = costError {
                // Expected
            } else {
                XCTFail("Expected insufficientBudget error")
            }
        }
    }

    func testMaximum500kEnforced() throws {
        // Try to record exactly 500k
        try costBrake.recordCost(470_000, category: .compute, description: "Large cost")

        // At 94%, should still be able to afford small amounts
        XCTAssertTrue(costBrake.canAfford(estimatedCost: 1000, category: .compute))

        // Record to 95%
        try costBrake.recordCost(5_000, category: .compute, description: "To threshold")

        // Now blocked
        XCTAssertTrue(costBrake.isBlocked)
        XCTAssertFalse(costBrake.canAfford(estimatedCost: 100_000, category: .compute))
    }

    // MARK: - Warning Level Tests

    func testWarningLevelNormal() {
        XCTAssertEqual(costBrake.warningLevel, .normal)
    }

    func testWarningLevelElevated() throws {
        // Record 50% of limit
        try costBrake.recordCost(250_000, category: .compute, description: "Half way")

        XCTAssertEqual(costBrake.warningLevel, .elevated)
    }

    func testWarningLevelWarning() throws {
        // Record 80% of limit
        try costBrake.recordCost(400_000, category: .compute, description: "80%")

        XCTAssertEqual(costBrake.warningLevel, .warning)
    }

    func testWarningLevelCritical() throws {
        // Record 90% of limit
        try costBrake.recordCost(450_000, category: .compute, description: "90%")

        XCTAssertEqual(costBrake.warningLevel, .critical)
    }

    func testWarningLevelBlocked() throws {
        // Record 95% of limit
        try costBrake.recordCost(475_000, category: .compute, description: "95%")

        XCTAssertEqual(costBrake.warningLevel, .blocked)
    }

    // MARK: - Budget Calculation Tests

    func testRemainingBudget() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Initial")

        XCTAssertEqual(costBrake.remainingBudget, 400_000)
    }

    func testUsagePercentage() throws {
        try costBrake.recordCost(250_000, category: .compute, description: "Half")

        XCTAssertEqual(costBrake.usagePercentage, 0.5, accuracy: 0.001)
    }

    func testAvailableBeforeBlocking() throws {
        try costBrake.recordCost(400_000, category: .compute, description: "80%")

        // Available before 95% threshold
        let available = costBrake.availableBeforeBlocking
        XCTAssertEqual(available, 75_000, accuracy: 1)
    }

    // MARK: - Category Limit Tests

    func testCategoryLimits() {
        let config = CostBrakeConfiguration(
            maxTotalCost: 500_000,
            categoryLimits: [.ai: 50_000]
        )
        let brake = CostBrake(configuration: config)
        brake.reset(confirmationCode: "RESET_COSTS")

        // Can afford within category limit
        XCTAssertTrue(brake.canAfford(estimatedCost: 40_000, category: .ai))

        // Cannot afford over category limit
        XCTAssertFalse(brake.canAfford(estimatedCost: 60_000, category: .ai))

        // Other categories not limited
        XCTAssertTrue(brake.canAfford(estimatedCost: 60_000, category: .compute))
    }

    // MARK: - Daily/Monthly Limit Tests

    func testDailyLimit() {
        let config = CostBrakeConfiguration(
            maxTotalCost: 500_000,
            dailyLimit: 10_000
        )
        let brake = CostBrake(configuration: config)
        brake.reset(confirmationCode: "RESET_COSTS")

        // Can afford within daily limit
        XCTAssertTrue(brake.canAfford(estimatedCost: 5_000, category: .compute))

        // Cannot afford over daily limit
        XCTAssertFalse(brake.canAfford(estimatedCost: 15_000, category: .compute))
    }

    func testMonthlyLimit() {
        let config = CostBrakeConfiguration(
            maxTotalCost: 500_000,
            monthlyLimit: 50_000
        )
        let brake = CostBrake(configuration: config)
        brake.reset(confirmationCode: "RESET_COSTS")

        // Can afford within monthly limit
        XCTAssertTrue(brake.canAfford(estimatedCost: 40_000, category: .compute))

        // Cannot afford over monthly limit
        XCTAssertFalse(brake.canAfford(estimatedCost: 60_000, category: .compute))
    }

    // MARK: - Status Tests

    func testGetStatus() throws {
        try costBrake.recordCost(250_000, category: .compute, description: "Half")

        let status = costBrake.getStatus()

        XCTAssertEqual(status.totalCost, 250_000)
        XCTAssertEqual(status.remainingBudget, 250_000)
        XCTAssertEqual(status.usagePercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(status.warningLevel, .elevated)
        XCTAssertFalse(status.isBlocked)
        XCTAssertEqual(status.costByCategory[.compute], 250_000)
    }

    func testStatusFormatting() throws {
        try costBrake.recordCost(123_456.78, category: .compute, description: "Test")

        let status = costBrake.getStatus()

        XCTAssertTrue(status.formattedTotalCost.contains("123"))
        XCTAssertTrue(status.formattedUsagePercentage.contains("%"))
    }

    // MARK: - Reset Tests

    func testResetWithCorrectCode() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Before reset")

        costBrake.reset(confirmationCode: "RESET_COSTS")

        XCTAssertEqual(costBrake.totalCost, 0)
        XCTAssertEqual(costBrake.costHistory.count, 0)
        XCTAssertEqual(costBrake.warningLevel, .normal)
        XCTAssertFalse(costBrake.isBlocked)
    }

    func testResetWithWrongCode() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Before reset")

        costBrake.reset(confirmationCode: "WRONG_CODE")

        // Should NOT reset
        XCTAssertEqual(costBrake.totalCost, 100_000)
    }

    // MARK: - Configuration Update Tests

    func testUpdateMaxCost() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Initial")

        costBrake.setMaxCost(200_000)

        XCTAssertEqual(costBrake.configuration.maxTotalCost, 200_000)
        // 100k is now 50% of 200k
        XCTAssertEqual(costBrake.usagePercentage, 0.5)
    }

    func testSetEnabled() {
        costBrake.setEnabled(false)

        XCTAssertFalse(costBrake.configuration.isEnabled)

        // When disabled, everything is affordable
        XCTAssertTrue(costBrake.canAfford(estimatedCost: 1_000_000, category: .compute))
    }

    // MARK: - History Tests

    func testGetHistoryByCategory() throws {
        try costBrake.recordCost(1000, category: .compute, description: "Compute 1")
        try costBrake.recordCost(500, category: .storage, description: "Storage 1")
        try costBrake.recordCost(2000, category: .compute, description: "Compute 2")

        let computeHistory = costBrake.getHistory(for: .compute)

        XCTAssertEqual(computeHistory.count, 2)
        XCTAssertTrue(computeHistory.allSatisfy { $0.category == .compute })
    }

    func testCostSummary() throws {
        try costBrake.recordCost(1000, category: .compute, description: "Compute")
        try costBrake.recordCost(500, category: .storage, description: "Storage")
        try costBrake.recordCost(200, category: .ai, description: "AI")

        let summary = costBrake.getCostSummary()

        XCTAssertEqual(summary[.compute], 1000)
        XCTAssertEqual(summary[.storage], 500)
        XCTAssertEqual(summary[.ai], 200)
    }

    // MARK: - Async Operation Tests

    func testExecuteIfAffordable() async throws {
        var operationExecuted = false

        let result = try await costBrake.executeIfAffordable(
            estimatedCost: 1000,
            category: .compute,
            description: "Async operation"
        ) {
            operationExecuted = true
            return "success"
        }

        XCTAssertTrue(operationExecuted)
        XCTAssertEqual(result, "success")
        XCTAssertEqual(costBrake.totalCost, 1000)
    }

    func testExecuteIfAffordableThrowsWhenBlocked() async throws {
        try costBrake.recordCost(490_000, category: .compute, description: "Near limit")

        do {
            _ = try await costBrake.executeIfAffordable(
                estimatedCost: 50_000,
                category: .compute,
                description: "Over budget"
            ) {
                return "should not execute"
            }
            XCTFail("Should have thrown")
        } catch {
            guard let costError = error as? CostBrakeError else {
                XCTFail("Expected CostBrakeError")
                return
            }
            if case .insufficientBudget = costError {
                // Expected
            } else {
                XCTFail("Expected insufficientBudget error")
            }
        }
    }

    // MARK: - Convenience Property Tests

    func testCanIncurCosts() throws {
        XCTAssertTrue(costBrake.canIncurCosts)

        try costBrake.recordCost(475_000, category: .compute, description: "To threshold")

        XCTAssertFalse(costBrake.canIncurCosts)
    }

    func testStatusDisplay() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Test")

        let display = costBrake.statusDisplay

        XCTAssertTrue(display.contains("Kostenstatus"))
        XCTAssertTrue(display.contains("Gesamt"))
        XCTAssertTrue(display.contains("Verbleibend"))
    }

    func testIsAboveThreshold() throws {
        XCTAssertFalse(costBrake.isAboveThreshold(0.5))

        try costBrake.recordCost(300_000, category: .compute, description: "60%")

        XCTAssertTrue(costBrake.isAboveThreshold(0.5))
        XCTAssertFalse(costBrake.isAboveThreshold(0.8))
    }

    // MARK: - Error Tests

    func testCostBrakeErrorDescriptions() {
        let limitError = CostBrakeError.limitExceeded(current: 600_000, limit: 500_000)
        XCTAssertTrue(limitError.localizedDescription.contains("Kostenlimit"))

        let blockedError = CostBrakeError.operationBlocked(reason: "Test")
        XCTAssertTrue(blockedError.localizedDescription.contains("blockiert"))

        let budgetError = CostBrakeError.insufficientBudget(required: 1000, available: 500)
        XCTAssertTrue(budgetError.localizedDescription.contains("Unzureichendes"))

        let activeError = CostBrakeError.costBrakeActive
        XCTAssertTrue(activeError.localizedDescription.contains("Kostenbremse"))
    }

    // MARK: - Category Tests

    func testAllCostCategories() {
        let categories = CostCategory.allCases

        XCTAssertEqual(categories.count, 9)
        XCTAssertTrue(categories.contains(.compute))
        XCTAssertTrue(categories.contains(.storage))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertTrue(categories.contains(.streaming))
        XCTAssertTrue(categories.contains(.api))
        XCTAssertTrue(categories.contains(.ai))
        XCTAssertTrue(categories.contains(.licensing))
        XCTAssertTrue(categories.contains(.infrastructure))
        XCTAssertTrue(categories.contains(.other))
    }

    func testCategoryDisplayNames() {
        XCTAssertEqual(CostCategory.compute.displayName, "Compute")
        XCTAssertEqual(CostCategory.storage.displayName, "Speicher")
        XCTAssertEqual(CostCategory.network.displayName, "Netzwerk")
        XCTAssertEqual(CostCategory.ai.displayName, "KI/ML")
    }

    // MARK: - Warning Level Tests

    func testWarningLevelProperties() {
        XCTAssertEqual(CostWarningLevel.normal.threshold, 0.0)
        XCTAssertEqual(CostWarningLevel.elevated.threshold, 0.5)
        XCTAssertEqual(CostWarningLevel.warning.threshold, 0.8)
        XCTAssertEqual(CostWarningLevel.critical.threshold, 0.9)
        XCTAssertEqual(CostWarningLevel.blocked.threshold, 0.95)

        XCTAssertEqual(CostWarningLevel.normal.emoji, "✅")
        XCTAssertEqual(CostWarningLevel.blocked.emoji, "🛑")

        XCTAssertEqual(CostWarningLevel.warning.displayName, "Warnung")
        XCTAssertEqual(CostWarningLevel.critical.displayName, "Kritisch")
    }

    // MARK: - Edge Case Tests

    func testVerySmallCosts() throws {
        try costBrake.recordCost(0.01, category: .compute, description: "Tiny")

        XCTAssertEqual(costBrake.totalCost, 0.01, accuracy: 0.001)
    }

    func testManySmallCosts() throws {
        for i in 0..<1000 {
            try costBrake.recordCost(1, category: .compute, description: "Small \(i)")
        }

        XCTAssertEqual(costBrake.totalCost, 1000)
    }

    func testExactlyAtLimit() throws {
        // Record to exactly 94.9% (just under blocking)
        try costBrake.recordCost(474_500, category: .compute, description: "Just under")

        XCTAssertFalse(costBrake.isBlocked)
        XCTAssertEqual(costBrake.warningLevel, .critical)
    }

    // MARK: - Integration Tests

    func testResourceManagerIntegration() async throws {
        // Test that ResourceManager can use CostBrake
        let resourceManager = ResourceManager()

        // Check if can afford
        let canAfford = await resourceManager.canAfford(estimatedCost: 1000)
        XCTAssertTrue(canAfford)
    }
}

// MARK: - Performance Tests

extension CostBrakeTests {

    func testPerformanceRecordingCosts() throws {
        measure {
            for i in 0..<100 {
                try? costBrake.recordCost(1, category: .compute, description: "Perf \(i)")
            }
        }
    }

    func testPerformanceCanAfford() {
        measure {
            for _ in 0..<1000 {
                _ = costBrake.canAfford(estimatedCost: 100, category: .compute)
            }
        }
    }

    func testPerformanceGetStatus() throws {
        try costBrake.recordCost(100_000, category: .compute, description: "Setup")

        measure {
            for _ in 0..<1000 {
                _ = costBrake.getStatus()
            }
        }
    }
}

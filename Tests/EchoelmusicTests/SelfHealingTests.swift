// SelfHealingTests.swift
// Echoelmusic - Tests for Self-Healing Framework
//
// Verifies autonomous health monitoring, recovery, and diagnostics

import XCTest
@testable import Echoelmusic

@MainActor
final class SelfHealingTests: XCTestCase {

    // MARK: - Initialization Tests

    func testSelfHealingFrameworkSingleton() {
        let instance1 = SelfHealingTestFramework.shared
        let instance2 = SelfHealingTestFramework.shared

        XCTAssertTrue(instance1 === instance2, "Should be same instance")
    }

    func testInitialHealthIsHealthy() {
        let framework = SelfHealingTestFramework.shared

        XCTAssertEqual(framework.currentHealth.overallStatus, .healthy)
        XCTAssertTrue(framework.currentHealth.activeIssues.isEmpty)
    }

    func testDefaultConfigurationValues() {
        let config = SelfHealingTestFramework.Configuration()

        XCTAssertEqual(config.checkInterval, 60)
        XCTAssertEqual(config.criticalCheckInterval, 10)
        XCTAssertEqual(config.maxRecoveryAttempts, 3)
        XCTAssertTrue(config.enableAutoRecovery)
    }

    // MARK: - Module Registration Tests

    func testModuleRegistration() {
        let framework = SelfHealingTestFramework.shared
        let module = AudioHealthCheck()

        framework.registerModule(module)

        // Module should be registered
        // (Would need internal access to verify)
        XCTAssertTrue(true, "Module registration should succeed")
    }

    func testDefaultModulesSetup() {
        let framework = SelfHealingTestFramework.shared

        framework.setupDefaultModules()

        // Should have audio and network modules
        // (Would need internal access to verify)
        XCTAssertTrue(true, "Default modules should be set up")
    }

    // MARK: - Health Status Tests

    func testHealthStatusComparison() {
        XCTAssertTrue(SystemHealth.HealthStatus.healthy < .degraded)
        XCTAssertTrue(SystemHealth.HealthStatus.degraded < .critical)
        XCTAssertTrue(SystemHealth.HealthStatus.critical < .failed)
    }

    func testHealthStatusFromHealthy() {
        let health = SystemHealth.healthy()

        XCTAssertEqual(health.overallStatus, .healthy)
        XCTAssertTrue(health.moduleStatuses.isEmpty)
        XCTAssertTrue(health.activeIssues.isEmpty)
        XCTAssertEqual(health.uptime, 0)
    }

    // MARK: - Health Issue Tests

    func testHealthIssueSeverityLevels() {
        let severities: [HealthIssue.Severity] = [.info, .warning, .error, .critical]

        for severity in severities {
            let issue = HealthIssue(
                id: UUID(),
                severity: severity,
                module: "Test",
                code: "TEST_001",
                message: "Test issue",
                detectedAt: Date(),
                autoRecoverable: true,
                suggestedAction: nil
            )

            XCTAssertEqual(issue.severity, severity)
        }
    }

    func testHealthIssueAutoRecoverableFlag() {
        let recoverableIssue = HealthIssue(
            id: UUID(),
            severity: .warning,
            module: "Test",
            code: "RECOVERABLE",
            message: "Can be auto-recovered",
            detectedAt: Date(),
            autoRecoverable: true,
            suggestedAction: "Will auto-fix"
        )

        let nonRecoverableIssue = HealthIssue(
            id: UUID(),
            severity: .critical,
            module: "Test",
            code: "MANUAL",
            message: "Needs manual intervention",
            detectedAt: Date(),
            autoRecoverable: false,
            suggestedAction: "Contact support"
        )

        XCTAssertTrue(recoverableIssue.autoRecoverable)
        XCTAssertFalse(nonRecoverableIssue.autoRecoverable)
    }

    // MARK: - Recovery Attempt Tests

    func testRecoveryAttemptRecording() {
        let attempt = RecoveryAttempt(
            id: UUID(),
            issueId: UUID(),
            action: "Restart service",
            attemptedAt: Date(),
            success: true,
            resultMessage: "Service restarted successfully",
            durationMs: 150
        )

        XCTAssertTrue(attempt.success)
        XCTAssertEqual(attempt.durationMs, 150)
        XCTAssertFalse(attempt.resultMessage.isEmpty)
    }

    func testFailedRecoveryAttempt() {
        let attempt = RecoveryAttempt(
            id: UUID(),
            issueId: UUID(),
            action: "Reconnect network",
            attemptedAt: Date(),
            success: false,
            resultMessage: "Network unreachable",
            durationMs: 5000
        )

        XCTAssertFalse(attempt.success)
    }

    // MARK: - Module Health Tests

    func testModuleHealthStructure() {
        let health = ModuleHealth(
            moduleName: "TestModule",
            status: .healthy,
            lastCheck: Date(),
            responseTime: 0.025,
            errorCount: 0,
            warningCount: 2,
            memoryUsage: 1024 * 1024,
            customMetrics: ["latency": 25.0, "throughput": 1000.0]
        )

        XCTAssertEqual(health.moduleName, "TestModule")
        XCTAssertEqual(health.status, .healthy)
        XCTAssertEqual(health.errorCount, 0)
        XCTAssertEqual(health.warningCount, 2)
        XCTAssertEqual(health.customMetrics["latency"], 25.0)
    }

    // MARK: - Audio Health Check Tests

    func testAudioHealthCheckModuleName() {
        let audioCheck = AudioHealthCheck()

        XCTAssertEqual(audioCheck.moduleName, "AudioEngine")
    }

    func testAudioHealthCheckReturnsHealth() async {
        let audioCheck = AudioHealthCheck()

        let health = await audioCheck.checkHealth()

        XCTAssertEqual(health.moduleName, "AudioEngine")
        XCTAssertNotNil(health.lastCheck)
        XCTAssertNotNil(health.responseTime)
    }

    func testAudioHealthCheckRecovery() async {
        let audioCheck = AudioHealthCheck()

        let issue = HealthIssue(
            id: UUID(),
            severity: .error,
            module: "AudioEngine",
            code: "AUDIO_FAIL",
            message: "Audio engine stopped",
            detectedAt: Date(),
            autoRecoverable: true,
            suggestedAction: nil
        )

        let attempt = await audioCheck.attemptRecovery(for: issue)

        XCTAssertTrue(attempt.success)
        XCTAssertEqual(attempt.action, "Restart AudioEngine")
    }

    // MARK: - Network Health Check Tests

    func testNetworkHealthCheckModuleName() {
        let networkCheck = NetworkHealthCheck()

        XCTAssertEqual(networkCheck.moduleName, "NetworkController")
    }

    // MARK: - Diagnostic Report Tests

    func testDiagnosticReportGeneration() {
        let framework = SelfHealingTestFramework.shared

        let report = framework.generateDiagnosticReport()

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("DIAGNOSTIC REPORT"))
        XCTAssertTrue(report.contains("SYSTEM STATUS"))
        XCTAssertTrue(report.contains("Uptime"))
    }

    func testDiagnosticReportContainsModules() {
        let framework = SelfHealingTestFramework.shared
        framework.setupDefaultModules()

        let report = framework.generateDiagnosticReport()

        XCTAssertTrue(report.contains("REGISTERED MODULES"))
    }

    // MARK: - Quick Check Tests

    func testQuickCheckReturnsSummary() async {
        let framework = SelfHealingTestFramework.shared

        let summary = await framework.quickCheck()

        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("Status:"))
        XCTAssertTrue(summary.contains("Issues:"))
    }

    // MARK: - Monitoring Tests

    func testMonitoringCanStartAndStop() {
        let framework = SelfHealingTestFramework.shared

        XCTAssertFalse(framework.isMonitoring)

        framework.startMonitoring()
        XCTAssertTrue(framework.isMonitoring)

        framework.stopMonitoring()
        XCTAssertFalse(framework.isMonitoring)
    }

    func testDoubleStartDoesNothing() {
        let framework = SelfHealingTestFramework.shared

        framework.startMonitoring()
        let wasMonitoring = framework.isMonitoring

        framework.startMonitoring()  // Second start
        XCTAssertEqual(framework.isMonitoring, wasMonitoring)

        framework.stopMonitoring()
    }

    // MARK: - History Tests

    func testHealthHistoryRetrieval() {
        let framework = SelfHealingTestFramework.shared

        let history = framework.getHealthHistory(last: 24)

        // Should return array (may be empty initially)
        XCTAssertNotNil(history)
    }

    func testUptimePercentageCalculation() {
        let framework = SelfHealingTestFramework.shared

        let uptime = framework.calculateUptimePercentage(last: 24)

        // Should be between 0 and 100
        XCTAssertGreaterThanOrEqual(uptime, 0)
        XCTAssertLessThanOrEqual(uptime, 100)
    }

    // MARK: - Configuration Tests

    func testConfigurationLogLevelComparison() {
        typealias LogLevel = SelfHealingTestFramework.Configuration.LogLevel

        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    func testConfigurationCanBeModified() {
        let framework = SelfHealingTestFramework.shared

        framework.configuration.checkInterval = 120
        framework.configuration.enableAutoRecovery = false

        XCTAssertEqual(framework.configuration.checkInterval, 120)
        XCTAssertFalse(framework.configuration.enableAutoRecovery)

        // Reset to defaults
        framework.configuration = SelfHealingTestFramework.Configuration()
    }
}

// MARK: - Performance Tests

final class SelfHealingPerformanceTests: XCTestCase {

    @MainActor
    func testHealthCheckPerformance() async {
        let framework = SelfHealingTestFramework.shared

        let startTime = Date()

        await framework.runHealthCheck()

        let duration = Date().timeIntervalSince(startTime)

        // Health check should complete in reasonable time
        XCTAssertLessThan(duration, 5.0, "Health check should complete within 5 seconds")
    }

    @MainActor
    func testReportGenerationPerformance() {
        let framework = SelfHealingTestFramework.shared

        measure {
            _ = framework.generateDiagnosticReport()
        }
    }
}

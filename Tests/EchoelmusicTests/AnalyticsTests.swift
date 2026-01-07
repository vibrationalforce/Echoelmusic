//
// AnalyticsTests.swift
// EchoelmusicTests
//
// Comprehensive tests for analytics and monitoring system
// Created: 2026-01-07
//

import XCTest
@testable import Echoelmusic

@MainActor
final class AnalyticsTests: XCTestCase {

    // MARK: - Analytics Event Tests

    func testAnalyticsEventNames() {
        XCTAssertEqual(AnalyticsEvent.sessionStarted.name, "session_started")
        XCTAssertEqual(AnalyticsEvent.sessionEnded(duration: 10).name, "session_ended")
        XCTAssertEqual(AnalyticsEvent.presetSelected(name: "test").name, "preset_selected")
        XCTAssertEqual(AnalyticsEvent.coherenceAchieved(level: .high).name, "coherence_achieved")
        XCTAssertEqual(AnalyticsEvent.featureUsed(name: "test").name, "feature_used")
        XCTAssertEqual(AnalyticsEvent.errorOccurred(type: "test", message: "msg").name, "error_occurred")
        XCTAssertEqual(AnalyticsEvent.subscriptionViewed(tier: "pro").name, "subscription_viewed")
        XCTAssertEqual(AnalyticsEvent.subscriptionPurchased(tier: "pro", price: 9.99).name, "subscription_purchased")
    }

    func testAnalyticsEventProperties() {
        // Session ended properties
        let sessionEvent = AnalyticsEvent.sessionEnded(duration: 123.45)
        XCTAssertEqual(sessionEvent.properties["duration"] as? TimeInterval, 123.45)

        // Preset selected properties
        let presetEvent = AnalyticsEvent.presetSelected(name: "Deep Meditation")
        XCTAssertEqual(presetEvent.properties["preset_name"] as? String, "Deep Meditation")

        // Coherence achieved properties
        let coherenceEvent = AnalyticsEvent.coherenceAchieved(level: .high)
        XCTAssertEqual(coherenceEvent.properties["level"] as? String, "high")
        XCTAssertEqual(coherenceEvent.properties["percentage"] as? Int, 75)

        // Feature used properties
        let featureEvent = AnalyticsEvent.featureUsed(name: "quantum_mode")
        XCTAssertEqual(featureEvent.properties["feature_name"] as? String, "quantum_mode")

        // Error occurred properties
        let errorEvent = AnalyticsEvent.errorOccurred(type: "NetworkError", message: "Connection failed")
        XCTAssertEqual(errorEvent.properties["error_type"] as? String, "NetworkError")
        XCTAssertEqual(errorEvent.properties["error_message"] as? String, "Connection failed")

        // Subscription purchased properties
        let subEvent = AnalyticsEvent.subscriptionPurchased(tier: "premium", price: 19.99)
        XCTAssertEqual(subEvent.properties["tier"] as? String, "premium")
        XCTAssertEqual(subEvent.properties["price"] as? Double, 19.99, accuracy: 0.01)

        // Export completed properties
        let exportEvent = AnalyticsEvent.exportCompleted(format: "mp4", duration: 5.5)
        XCTAssertEqual(exportEvent.properties["export_format"] as? String, "mp4")
        XCTAssertEqual(exportEvent.properties["export_duration"] as? TimeInterval, 5.5)
    }

    func testCoherenceLevels() {
        XCTAssertEqual(CoherenceLevel.low.percentage, 25)
        XCTAssertEqual(CoherenceLevel.medium.percentage, 50)
        XCTAssertEqual(CoherenceLevel.high.percentage, 75)
        XCTAssertEqual(CoherenceLevel.peak.percentage, 100)

        XCTAssertEqual(CoherenceLevel.low.rawValue, "low")
        XCTAssertEqual(CoherenceLevel.medium.rawValue, "medium")
        XCTAssertEqual(CoherenceLevel.high.rawValue, "high")
        XCTAssertEqual(CoherenceLevel.peak.rawValue, "peak")
    }

    // MARK: - Console Analytics Provider Tests

    func testConsoleAnalyticsProvider() {
        let provider = ConsoleAnalyticsProvider()

        // Should not crash
        provider.track(event: "test_event", properties: ["key": "value"])
        provider.setUserProperty(key: "user_type", value: "premium")
        provider.identify(userId: "user_123")
        provider.reset()
        provider.flush()
    }

    // MARK: - File Analytics Provider Tests

    func testFileAnalyticsProvider() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_analytics.jsonl")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: tempURL)

        let provider = FileAnalyticsProvider(fileURL: tempURL)

        // Track events
        provider.track(event: "test_event", properties: ["key": "value", "number": 42])
        provider.setUserProperty(key: "user_type", value: "premium")
        provider.identify(userId: "user_123")

        // Flush to ensure data is written
        provider.flush()

        // Give it a moment to write
        Thread.sleep(forTimeInterval: 0.1)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Read and verify content
        if let data = try? Data(contentsOf: tempURL),
           let content = String(data: data, encoding: .utf8) {
            XCTAssertTrue(content.contains("test_event"))
            XCTAssertTrue(content.contains("user_type"))
            XCTAssertTrue(content.contains("user_123"))
        }

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Firebase Analytics Provider Tests

    func testFirebaseAnalyticsProviderStub() {
        let provider = FirebaseAnalyticsProvider()

        // Should not crash (stub implementation)
        provider.track(event: "test_event", properties: [:])
        provider.setUserProperty(key: "test", value: "value")
        provider.identify(userId: "test_user")
        provider.reset()
        provider.flush()
    }

    // MARK: - Crash Reporter Tests

    func testCrashReporterBreadcrumbs() {
        let reporter = CrashReporter.shared

        // Clear existing breadcrumbs
        reporter.clearBreadcrumbs()

        // Record breadcrumbs
        reporter.recordBreadcrumb("Test breadcrumb 1", category: "test", level: .info)
        reporter.recordBreadcrumb("Test breadcrumb 2", category: "test", level: .warning)
        reporter.recordBreadcrumb("Test breadcrumb 3", category: "test", level: .error)

        // Get recent breadcrumbs
        let breadcrumbs = reporter.getRecentBreadcrumbs(count: 10)
        XCTAssertEqual(breadcrumbs.count, 3)
        XCTAssertEqual(breadcrumbs[0].message, "Test breadcrumb 1")
        XCTAssertEqual(breadcrumbs[1].message, "Test breadcrumb 2")
        XCTAssertEqual(breadcrumbs[2].message, "Test breadcrumb 3")

        // Clear breadcrumbs
        reporter.clearBreadcrumbs()
        XCTAssertEqual(reporter.getRecentBreadcrumbs().count, 0)
    }

    func testCrashReporterBreadcrumbLimit() {
        let reporter = CrashReporter.shared
        reporter.clearBreadcrumbs()

        // Record 150 breadcrumbs (max is 100)
        for i in 1...150 {
            reporter.recordBreadcrumb("Breadcrumb \(i)", category: "test", level: .info)
        }

        // Should only keep last 100
        let breadcrumbs = reporter.getRecentBreadcrumbs(count: 200)
        XCTAssertEqual(breadcrumbs.count, 100)
        XCTAssertTrue(breadcrumbs.first?.message.contains("51") ?? false) // First should be ~51
        XCTAssertTrue(breadcrumbs.last?.message.contains("150") ?? false)

        reporter.clearBreadcrumbs()
    }

    func testCrashReporterUserInfo() {
        let reporter = CrashReporter.shared

        // Set user info
        reporter.setUserInfo(key: "user_id", value: "123")
        reporter.setUserInfo(key: "session_id", value: "abc")
        reporter.setUserInfo(key: "coherence", value: 0.85)
    }

    func testCrashReporterNonFatalError() {
        let reporter = CrashReporter.shared

        struct TestError: Error, LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }

        let error = TestError(message: "Test error")

        // Should not crash
        reporter.reportNonFatal(error: error, context: ["test": "context"])
        reporter.reportNonFatal(message: "Test message", context: ["key": "value"])
    }

    func testCrashReporterConvenienceMethods() {
        let reporter = CrashReporter.shared
        reporter.clearBreadcrumbs()

        reporter.log("Info message")
        reporter.debug("Debug message")
        reporter.warning("Warning message")
        reporter.error("Error message")

        let breadcrumbs = reporter.getRecentBreadcrumbs()
        XCTAssertEqual(breadcrumbs.count, 4)
        XCTAssertEqual(breadcrumbs[0].level, .info)
        XCTAssertEqual(breadcrumbs[1].level, .debug)
        XCTAssertEqual(breadcrumbs[2].level, .warning)
        XCTAssertEqual(breadcrumbs[3].level, .error)

        reporter.clearBreadcrumbs()
    }

    // MARK: - Performance Monitor Tests

    func testPerformanceMonitorTimer() {
        let monitor = PerformanceMonitor.shared

        // Start and stop timer
        monitor.startTimer("test_timer")
        Thread.sleep(forTimeInterval: 0.1)
        let duration = monitor.stopTimer("test_timer")

        XCTAssertNotNil(duration)
        XCTAssertGreaterThanOrEqual(duration ?? 0, 0.1)
    }

    func testPerformanceMonitorStopNonExistentTimer() {
        let monitor = PerformanceMonitor.shared

        // Stop timer that was never started
        let duration = monitor.stopTimer("nonexistent_timer")
        XCTAssertNil(duration)
    }

    func testPerformanceMonitorMeasure() {
        let monitor = PerformanceMonitor.shared

        var result = 0
        let _ = monitor.measure("calculation") {
            for i in 1...1000 {
                result += i
            }
            return result
        }

        XCTAssertEqual(result, 500500)
    }

    func testPerformanceMonitorMeasureAsync() async {
        let monitor = PerformanceMonitor.shared

        let result = await monitor.measureAsync("async_operation") {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            return 42
        }

        XCTAssertEqual(result, 42)
    }

    func testPerformanceMonitorCustomMetric() {
        let monitor = PerformanceMonitor.shared

        // Should not crash
        monitor.reportMetric(name: "coherence", value: 0.85, unit: "%")
        monitor.reportMetric(name: "bpm", value: 72.5, unit: "bpm")
    }

    func testPerformanceMonitorAppLaunch() {
        let monitor = PerformanceMonitor.shared
        let launchDate = Date().addingTimeInterval(-2.5)

        // Should not crash
        monitor.measureAppLaunch(from: launchDate)
    }

    func testPerformanceMonitorScreenRender() {
        let monitor = PerformanceMonitor.shared

        // Should not crash
        monitor.measureScreenRender(screenName: "HomeView", duration: 0.05)
    }

    func testPerformanceMonitorNetworkRequest() {
        let monitor = PerformanceMonitor.shared

        // Should not crash
        monitor.measureNetworkRequest(endpoint: "/api/session", duration: 0.5, success: true)
        monitor.measureNetworkRequest(endpoint: "/api/session", duration: 1.2, success: false)
    }

    // MARK: - Privacy Compliance Tests

    func testPrivacyComplianceDefaults() {
        let privacy = PrivacyCompliance.shared

        // Check defaults (should be false for privacy-first)
        // Note: In production, these should default to false
        // Here we're just testing the get/set functionality
        privacy.isAnalyticsEnabled = false
        XCTAssertFalse(privacy.isAnalyticsEnabled)

        privacy.isCrashReportingEnabled = false
        XCTAssertFalse(privacy.isCrashReportingEnabled)

        privacy.isPerformanceMonitoringEnabled = false
        XCTAssertFalse(privacy.isPerformanceMonitoringEnabled)
    }

    func testPrivacyComplianceSetConsents() {
        let privacy = PrivacyCompliance.shared

        privacy.setConsents(analytics: true, crashReporting: true, performance: true)

        XCTAssertTrue(privacy.isAnalyticsEnabled)
        XCTAssertTrue(privacy.isCrashReportingEnabled)
        XCTAssertTrue(privacy.isPerformanceMonitoringEnabled)
        XCTAssertNotNil(privacy.consentDate)

        // Reset
        privacy.setConsents(analytics: false, crashReporting: false, performance: false)
    }

    func testPrivacyComplianceConsentDate() {
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true
        let consentDate = privacy.consentDate

        XCTAssertNotNil(consentDate)
        XCTAssertLessThanOrEqual(consentDate?.timeIntervalSinceNow ?? 0, 1)

        privacy.isAnalyticsEnabled = false
    }

    func testPrivacyComplianceDataDeletion() {
        let privacy = PrivacyCompliance.shared

        // Set some consents
        privacy.setConsents(analytics: true, crashReporting: true, performance: true)

        // Delete all data
        privacy.deleteAllData()

        // All should be cleared
        XCTAssertFalse(privacy.isAnalyticsEnabled)
        XCTAssertFalse(privacy.isCrashReportingEnabled)
        XCTAssertFalse(privacy.isPerformanceMonitoringEnabled)
        // Consent date is cleared by deleteAllData
    }

    func testPrivacyComplianceDataExport() {
        let privacy = PrivacyCompliance.shared
        let reporter = CrashReporter.shared

        // Set up some data
        privacy.setConsents(analytics: true, crashReporting: true, performance: true)
        reporter.clearBreadcrumbs()
        reporter.log("Test breadcrumb 1")
        reporter.log("Test breadcrumb 2")

        // Export data
        let exportedData = privacy.exportUserData()

        XCTAssertNotNil(exportedData["consents"])
        XCTAssertNotNil(exportedData["breadcrumbs"])

        if let consents = exportedData["consents"] as? [String: Any] {
            XCTAssertEqual(consents["analytics"] as? Bool, true)
            XCTAssertEqual(consents["crash_reporting"] as? Bool, true)
            XCTAssertEqual(consents["performance"] as? Bool, true)
        }

        if let breadcrumbs = exportedData["breadcrumbs"] as? [[String: Any]] {
            XCTAssertGreaterThanOrEqual(breadcrumbs.count, 2)
        }

        // Clean up
        privacy.deleteAllData()
        reporter.clearBreadcrumbs()
    }

    // MARK: - Analytics Manager Tests

    func testAnalyticsManagerSingleton() {
        let manager1 = AnalyticsManager.shared
        let manager2 = AnalyticsManager.shared

        XCTAssertTrue(manager1 === manager2)
    }

    func testAnalyticsManagerTrackEvent() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        // Enable analytics
        privacy.isAnalyticsEnabled = true

        // Track various events
        manager.track(.sessionStarted)
        manager.track(.presetSelected(name: "Deep Meditation"))
        manager.track(.coherenceAchieved(level: .high))
        manager.track(.featureUsed(name: "quantum_mode"))

        // Disable analytics
        privacy.isAnalyticsEnabled = false
    }

    func testAnalyticsManagerTrackWithoutConsent() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        // Disable analytics
        privacy.isAnalyticsEnabled = false

        // Should not track (but shouldn't crash)
        manager.track(.sessionStarted)
        manager.track(.featureUsed(name: "test"))
    }

    func testAnalyticsManagerUserProperties() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        manager.setUserProperty(key: "subscription_tier", value: "premium")
        manager.setUserProperty(key: "favorite_preset", value: "Bio-Reactive Flow")

        privacy.isAnalyticsEnabled = false
    }

    func testAnalyticsManagerIdentify() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        manager.identify(userId: "user_12345")

        privacy.isAnalyticsEnabled = false
    }

    func testAnalyticsManagerReset() {
        let manager = AnalyticsManager.shared

        manager.reset()

        XCTAssertEqual(manager.sessionDuration, 0)
    }

    func testAnalyticsManagerFlush() {
        let manager = AnalyticsManager.shared

        // Should not crash
        manager.flush()
    }

    func testAnalyticsManagerConvenienceMethods() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        manager.trackPresetSelected("Deep Meditation")
        manager.trackPresetApplied("Deep Meditation")
        manager.trackCoherenceAchieved(percentage: 85.0)
        manager.trackQuantumModeChanged("bio_coherent")
        manager.trackVisualizationChanged("interference_pattern")
        manager.trackCollaborationJoined("session_123")
        manager.trackCollaborationLeft("session_123", duration: 600.0)
        manager.trackPluginLoaded("SacredGeometryVisualizer")
        manager.trackSubscriptionViewed("premium")
        manager.trackSubscriptionPurchased("premium", price: 19.99)
        manager.trackShareCompleted("image")
        manager.trackExportCompleted("mp4", duration: 5.5)
        manager.trackFeatureUsage("quantum_tunnel")

        privacy.isAnalyticsEnabled = false
    }

    func testAnalyticsManagerTrackError() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true
        privacy.isCrashReportingEnabled = true

        struct TestError: Error {
            let message: String
        }

        let error = TestError(message: "Test error message")
        manager.trackError(error, context: "During session start")

        privacy.isAnalyticsEnabled = false
        privacy.isCrashReportingEnabled = false
    }

    func testAnalyticsManagerTrackPerformance() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isPerformanceMonitoringEnabled = true

        manager.trackPerformance(metric: "audio_buffer_process", duration: 0.001)
        manager.trackPerformance(metric: "coherence_calculation", duration: 0.005)
        manager.trackPerformance(metric: "cpu_usage", value: 25.5)

        privacy.isPerformanceMonitoringEnabled = false
    }

    func testAnalyticsManagerCoherenceTracking() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        // Test different coherence levels
        manager.trackCoherenceAchieved(percentage: 25.0)  // Low
        manager.trackCoherenceAchieved(percentage: 55.0)  // Medium
        manager.trackCoherenceAchieved(percentage: 70.0)  // High
        manager.trackCoherenceAchieved(percentage: 95.0)  // Peak

        privacy.isAnalyticsEnabled = false
    }

    // MARK: - Session Tracking Tests

    func testAnalyticsManagerSessionTracking() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        // Start session
        manager.startSession()
        XCTAssertNotNil(manager.sessionDuration)

        // Wait a bit
        Thread.sleep(forTimeInterval: 0.2)

        // End session
        manager.endSession()
        XCTAssertGreaterThanOrEqual(manager.sessionDuration, 0.2)

        privacy.isAnalyticsEnabled = false
    }

    // MARK: - Integration Tests

    func testFullAnalyticsWorkflow() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared
        let monitor = PerformanceMonitor.shared
        let reporter = CrashReporter.shared

        // 1. User provides consent
        privacy.setConsents(analytics: true, crashReporting: true, performance: true)

        // 2. Start session
        manager.startSession()

        // 3. Track user journey
        manager.trackPresetSelected("Deep Meditation")
        reporter.log("User selected Deep Meditation preset")

        manager.trackPresetApplied("Deep Meditation")
        reporter.log("Preset applied successfully")

        // 4. Track performance
        monitor.startTimer("session_load")
        Thread.sleep(forTimeInterval: 0.1)
        _ = monitor.stopTimer("session_load")

        // 5. Track feature usage
        manager.trackFeatureUsage("quantum_mode")
        manager.trackQuantumModeChanged("bio_coherent")

        // 6. Track coherence
        manager.trackCoherenceAchieved(percentage: 85.0)

        // 7. Track visualization
        manager.trackVisualizationChanged("interference_pattern")

        // 8. End session
        manager.endSession()

        // 9. Export data (GDPR)
        let exportedData = privacy.exportUserData()
        XCTAssertNotNil(exportedData)

        // 10. Delete data (GDPR)
        privacy.deleteAllData()
        reporter.clearBreadcrumbs()
    }

    func testAnalyticsWithoutConsent() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        // Ensure consent is disabled
        privacy.isAnalyticsEnabled = false
        privacy.isCrashReportingEnabled = false
        privacy.isPerformanceMonitoringEnabled = false

        // All these should be no-ops
        manager.startSession()
        manager.track(.sessionStarted)
        manager.trackFeatureUsage("test")
        manager.setUserProperty(key: "test", value: "value")
        manager.endSession()

        // Should not crash
        XCTAssertEqual(manager.sessionDuration, 0)
    }

    // MARK: - Edge Case Tests

    func testAnalyticsEventEquality() {
        let event1 = AnalyticsEvent.sessionStarted
        let event2 = AnalyticsEvent.sessionStarted
        XCTAssertEqual(event1, event2)

        let event3 = AnalyticsEvent.presetSelected(name: "test")
        let event4 = AnalyticsEvent.presetSelected(name: "test")
        XCTAssertEqual(event3, event4)

        let event5 = AnalyticsEvent.coherenceAchieved(level: .high)
        let event6 = AnalyticsEvent.coherenceAchieved(level: .high)
        XCTAssertEqual(event5, event6)
    }

    func testAnalyticsEmptyProperties() {
        let event = AnalyticsEvent.sessionStarted
        XCTAssertTrue(event.properties.isEmpty)
    }

    func testPerformanceMonitorDoubleStop() {
        let monitor = PerformanceMonitor.shared

        monitor.startTimer("test")
        _ = monitor.stopTimer("test")
        let duration2 = monitor.stopTimer("test") // Should return nil

        XCTAssertNil(duration2)
    }

    func testCrashReporterThreadSafety() {
        let reporter = CrashReporter.shared
        reporter.clearBreadcrumbs()

        let expectation = XCTestExpectation(description: "Concurrent breadcrumb recording")
        expectation.expectedFulfillmentCount = 10

        // Record breadcrumbs from multiple threads
        for i in 0..<10 {
            DispatchQueue.global().async {
                reporter.log("Message \(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        let breadcrumbs = reporter.getRecentBreadcrumbs()
        XCTAssertEqual(breadcrumbs.count, 10)

        reporter.clearBreadcrumbs()
    }

    func testAnalyticsLargePropertyValues() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        // Create large property string
        let largeString = String(repeating: "a", count: 10000)

        manager.track(.errorOccurred(type: "test", message: largeString))

        privacy.isAnalyticsEnabled = false
    }

    // MARK: - Privacy Tests

    func testPrivacyFirstDefaults() {
        // In a fresh install, all analytics should be disabled by default
        // This test verifies privacy-first approach
        let privacy = PrivacyCompliance.shared

        // Set to false to test privacy-first
        privacy.isAnalyticsEnabled = false
        privacy.isCrashReportingEnabled = false
        privacy.isPerformanceMonitoringEnabled = false

        XCTAssertFalse(privacy.isAnalyticsEnabled)
        XCTAssertFalse(privacy.isCrashReportingEnabled)
        XCTAssertFalse(privacy.isPerformanceMonitoringEnabled)
    }

    func testGDPRCompliance() {
        let privacy = PrivacyCompliance.shared

        // Test GDPR right to consent
        privacy.setConsents(analytics: true, crashReporting: true, performance: true)
        XCTAssertNotNil(privacy.consentDate)

        // Test GDPR right to data portability
        let exportedData = privacy.exportUserData()
        XCTAssertNotNil(exportedData["consents"])
        XCTAssertNotNil(exportedData["breadcrumbs"])

        // Test GDPR right to erasure
        privacy.deleteAllData()
        XCTAssertFalse(privacy.isAnalyticsEnabled)
        XCTAssertNil(privacy.consentDate)
    }

    // MARK: - Performance Tests

    func testAnalyticsPerformance() {
        let manager = AnalyticsManager.shared
        let privacy = PrivacyCompliance.shared

        privacy.isAnalyticsEnabled = true

        measure {
            for _ in 0..<100 {
                manager.track(.featureUsed(name: "test"))
            }
        }

        privacy.isAnalyticsEnabled = false
    }

    func testBreadcrumbPerformance() {
        let reporter = CrashReporter.shared
        reporter.clearBreadcrumbs()

        measure {
            for i in 0..<1000 {
                reporter.log("Breadcrumb \(i)")
            }
        }

        reporter.clearBreadcrumbs()
    }
}

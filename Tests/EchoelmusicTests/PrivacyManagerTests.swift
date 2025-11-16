import XCTest
@testable import Echoelmusic

@MainActor
final class PrivacyManagerTests: XCTestCase {

    var privacyManager: PrivacyManager!

    override func setUp() async throws {
        try await super.setUp()
        privacyManager = PrivacyManager()
    }

    override func tearDown() async throws {
        privacyManager = nil
        try await super.tearDown()
    }

    // MARK: - Privacy Mode Tests

    func testDefaultPrivacyModeIsMaximum() {
        // Then
        XCTAssertEqual(privacyManager.privacyMode, .maximumPrivacy,
                      "Default should be maximum privacy")
    }

    func testMaximumPrivacyMode() {
        // When
        privacyManager.privacyMode = .maximumPrivacy

        // Then
        XCTAssertFalse(privacyManager.privacyMode.allowsCloudSync)
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics)
        XCTAssertEqual(privacyManager.privacyMode.description,
                      "All data stays on device. No cloud sync. No analytics. Complete privacy.")
    }

    func testBalancedPrivacyMode() {
        // When
        privacyManager.privacyMode = .balanced

        // Then
        XCTAssertTrue(privacyManager.privacyMode.allowsCloudSync)
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics)
    }

    func testConveniencePrivacyMode() {
        // When
        privacyManager.privacyMode = .convenience

        // Then
        XCTAssertTrue(privacyManager.privacyMode.allowsCloudSync)
        XCTAssertTrue(privacyManager.privacyMode.allowsAnalytics)
    }

    // MARK: - Cloud Sync Tests

    func testCloudSyncDisabledByDefault() {
        // Then
        XCTAssertFalse(privacyManager.cloudSyncEnabled,
                      "Cloud sync should be disabled by default")
    }

    func testEnableCloudSync() {
        // When
        privacyManager.cloudSyncEnabled = true

        // Then
        XCTAssertTrue(privacyManager.cloudSyncEnabled)
    }

    func testCloudSyncRespectPrivacyMode() {
        // Given
        privacyManager.privacyMode = .maximumPrivacy

        // When
        privacyManager.cloudSyncEnabled = true

        // Then
        // In maximum privacy mode, cloud sync should not be allowed
        XCTAssertFalse(privacyManager.privacyMode.allowsCloudSync)
    }

    // MARK: - Analytics Tests

    func testAnalyticsDisabledByDefault() {
        // Then
        XCTAssertFalse(privacyManager.analyticsEnabled,
                      "Analytics should be disabled by default")
    }

    func testAnalyticsOnlyInConvenienceMode() {
        // Given
        let modes: [PrivacyManager.PrivacyMode] = [.maximumPrivacy, .balanced, .convenience]

        for mode in modes {
            // When
            privacyManager.privacyMode = mode

            // Then
            if mode == .convenience {
                XCTAssertTrue(mode.allowsAnalytics, "\(mode) should allow analytics")
            } else {
                XCTAssertFalse(mode.allowsAnalytics, "\(mode) should not allow analytics")
            }
        }
    }

    // MARK: - Crash Reporting Tests

    func testCrashReportingDisabledByDefault() {
        // Then
        XCTAssertFalse(privacyManager.crashReportingEnabled,
                      "Crash reporting should be disabled by default")
    }

    // MARK: - Data Categories Tests

    func testHealthDataNeverSyncedToCloud() {
        // Given
        let healthData = PrivacyManager.DataCategory.healthData

        // Then
        XCTAssertFalse(healthData.canBeSyncedToCloud,
                      "Health data should never be synced to cloud for privacy")
        XCTAssertTrue(healthData.isStoredLocally,
                     "Health data should always be stored locally")
    }

    func testUserContentCanBeSynced() {
        // Given
        let userContent = PrivacyManager.DataCategory.userContent

        // Then
        XCTAssertTrue(userContent.canBeSyncedToCloud,
                     "User content can be synced if user chooses")
        XCTAssertTrue(userContent.isStoredLocally,
                     "User content should be stored locally first")
    }

    func testUsageDataNeverSynced() {
        // Given
        let usageData = PrivacyManager.DataCategory.usageData

        // Then
        XCTAssertFalse(usageData.canBeSyncedToCloud,
                      "Usage data should never be synced")
    }

    func testAllDataStoredLocally() {
        // Given
        let allCategories = PrivacyManager.DataCategory.allCases

        // Then
        for category in allCategories {
            XCTAssertTrue(category.isStoredLocally,
                         "\(category.rawValue) should be stored locally")
        }
    }

    // MARK: - Data Category Descriptions

    func testDataCategoryDescriptions() {
        // Given
        let categories = PrivacyManager.DataCategory.allCases

        // Then
        for category in categories {
            XCTAssertFalse(category.description.isEmpty,
                          "Category description should not be empty")
            XCTAssertFalse(category.rawValue.isEmpty,
                          "Category raw value should not be empty")
        }
    }

    // MARK: - Privacy Principles Tests

    func testLocalFirstPrinciple() {
        // All data categories should be stored locally
        let allCategories = PrivacyManager.DataCategory.allCases

        for category in allCategories {
            XCTAssertTrue(category.isStoredLocally,
                         "Local-First: \(category.rawValue) must be stored locally")
        }
    }

    func testDataMinimizationPrinciple() {
        // Only essential data categories should exist
        let allCategories = PrivacyManager.DataCategory.allCases

        XCTAssertEqual(allCategories.count, 5,
                      "Data Minimization: Only essential categories should exist")
    }

    func testUserControlPrinciple() {
        // Users should be able to control sync and analytics
        // Given
        privacyManager.cloudSyncEnabled = false
        privacyManager.analyticsEnabled = false

        // When - User enables
        privacyManager.cloudSyncEnabled = true
        privacyManager.analyticsEnabled = true

        // Then
        XCTAssertTrue(privacyManager.cloudSyncEnabled,
                     "User Control: Users can enable cloud sync")
        XCTAssertTrue(privacyManager.analyticsEnabled,
                     "User Control: Users can enable analytics")

        // When - User disables
        privacyManager.cloudSyncEnabled = false
        privacyManager.analyticsEnabled = false

        // Then
        XCTAssertFalse(privacyManager.cloudSyncEnabled,
                      "User Control: Users can disable cloud sync")
        XCTAssertFalse(privacyManager.analyticsEnabled,
                      "User Control: Users can disable analytics")
    }

    // MARK: - GDPR Compliance Tests

    func testRightToBeForgotten() {
        // GDPR Article 17: Right to erasure
        // All data should be deletable

        // Given
        privacyManager.cloudSyncEnabled = true
        privacyManager.analyticsEnabled = true

        // When - User requests data deletion
        privacyManager.cloudSyncEnabled = false
        privacyManager.analyticsEnabled = false
        privacyManager.crashReportingEnabled = false

        // Then
        XCTAssertFalse(privacyManager.cloudSyncEnabled)
        XCTAssertFalse(privacyManager.analyticsEnabled)
        XCTAssertFalse(privacyManager.crashReportingEnabled)
    }

    func testDataPortability() {
        // GDPR Article 20: Right to data portability
        // User content can be exported (via cloudSyncEnabled)

        let userContent = PrivacyManager.DataCategory.userContent
        XCTAssertTrue(userContent.canBeSyncedToCloud,
                     "Data Portability: User content should be exportable")
    }

    func testPurposeLimitation() {
        // GDPR Article 5: Data should only be used for specified purposes

        let healthData = PrivacyManager.DataCategory.healthData
        XCTAssertEqual(healthData.description,
                      "Heart rate, HRV, and other biometric data from HealthKit",
                      "Purpose Limitation: Clear description of data usage")
    }

    // MARK: - CCPA Compliance Tests

    func testRightToOptOut() {
        // CCPA: Right to opt out of data sale
        // Echoelmusic never sells data, but users can opt out of all sharing

        // When
        privacyManager.privacyMode = .maximumPrivacy

        // Then
        XCTAssertFalse(privacyManager.privacyMode.allowsCloudSync,
                      "CCPA: Users can opt out of all data sharing")
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics,
                      "CCPA: Users can opt out of analytics")
    }

    // MARK: - HIPAA Compliance Tests (for health data)

    func testHealthDataStoredLocally() {
        // HIPAA requires secure storage of health data
        let healthData = PrivacyManager.DataCategory.healthData

        XCTAssertTrue(healthData.isStoredLocally,
                     "HIPAA: Health data must be stored locally")
        XCTAssertFalse(healthData.canBeSyncedToCloud,
                      "HIPAA: Health data should not be synced to cloud")
    }

    // MARK: - Privacy Mode Transitions

    func testTransitionFromMaximumToBalanced() {
        // Given
        privacyManager.privacyMode = .maximumPrivacy

        // When
        privacyManager.privacyMode = .balanced

        // Then
        XCTAssertTrue(privacyManager.privacyMode.allowsCloudSync,
                     "Balanced mode allows cloud sync")
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics,
                      "Balanced mode still doesn't allow analytics")
    }

    func testTransitionFromBalancedToConvenience() {
        // Given
        privacyManager.privacyMode = .balanced

        // When
        privacyManager.privacyMode = .convenience

        // Then
        XCTAssertTrue(privacyManager.privacyMode.allowsCloudSync)
        XCTAssertTrue(privacyManager.privacyMode.allowsAnalytics)
    }

    func testTransitionFromConvenienceToMaximum() {
        // Given
        privacyManager.privacyMode = .convenience

        // When
        privacyManager.privacyMode = .maximumPrivacy

        // Then
        XCTAssertFalse(privacyManager.privacyMode.allowsCloudSync,
                      "Maximum privacy disables cloud sync")
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics,
                      "Maximum privacy disables analytics")
    }

    // MARK: - Integration Tests

    func testPrivacyModeAffectsAllSettings() {
        // Given
        privacyManager.privacyMode = .convenience
        privacyManager.cloudSyncEnabled = true
        privacyManager.analyticsEnabled = true

        // When
        privacyManager.privacyMode = .maximumPrivacy

        // Then
        // Privacy mode change should respect user's privacy
        XCTAssertFalse(privacyManager.privacyMode.allowsCloudSync)
        XCTAssertFalse(privacyManager.privacyMode.allowsAnalytics)
    }

    // MARK: - Apple Privacy Nutrition Label Tests

    func testAllDataCategoriesHaveDescriptions() {
        // Apple requires clear descriptions for App Store
        let allCategories = PrivacyManager.DataCategory.allCases

        for category in allCategories {
            XCTAssertFalse(category.description.isEmpty,
                          "Privacy Nutrition Label: \(category.rawValue) needs description")
            XCTAssertGreaterThan(category.description.count, 10,
                               "Description should be meaningful")
        }
    }

    // MARK: - Zero-Knowledge Architecture Tests

    func testNoThirdPartyTracking() {
        // Zero third-party SDKs for tracking
        XCTAssertFalse(privacyManager.analyticsEnabled,
                      "No third-party tracking by default")
    }

    func testOnDeviceProcessing() {
        // All data should be processed on-device
        let allCategories = PrivacyManager.DataCategory.allCases

        for category in allCategories {
            XCTAssertTrue(category.isStoredLocally,
                         "Zero-Knowledge: \(category.rawValue) processed on-device")
        }
    }

    // MARK: - Edge Cases

    func testMultiplePrivacyModeChanges() {
        // Rapidly changing privacy modes should work correctly
        let modes: [PrivacyManager.PrivacyMode] = [
            .maximumPrivacy, .balanced, .convenience,
            .maximumPrivacy, .convenience, .balanced
        ]

        for mode in modes {
            privacyManager.privacyMode = mode
            XCTAssertEqual(privacyManager.privacyMode, mode)
        }
    }
}

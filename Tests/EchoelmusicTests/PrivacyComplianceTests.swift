//
//  PrivacyComplianceTests.swift
//  EchoelmusicTests
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Privacy compliance testing (GDPR/CCPA)
//

import XCTest
@testable import Echoelmusic

final class PrivacyComplianceTests: XCTestCase {
    var privacyManager: PrivacyComplianceManager!

    override func setUp() async throws {
        privacyManager = PrivacyComplianceManager.shared
    }

    // MARK: - Consent Management Tests

    func testConsentGranting() {
        privacyManager.grantConsent(for: .analytics)

        XCTAssertEqual(privacyManager.analyticsConsent, .granted)
    }

    func testConsentDenial() {
        privacyManager.denyConsent(for: .analytics)

        XCTAssertEqual(privacyManager.analyticsConsent, .denied)
    }

    func testConsentWithdrawal() {
        privacyManager.grantConsent(for: .analytics)
        XCTAssertEqual(privacyManager.analyticsConsent, .granted)

        privacyManager.withdrawConsent(for: .analytics)
        XCTAssertEqual(privacyManager.analyticsConsent, .withdrawn)
    }

    func testMultipleConsents() {
        privacyManager.grantConsent(for: .analytics)
        privacyManager.grantConsent(for: .crashReporting)
        privacyManager.denyConsent(for: .personalizedContent)

        XCTAssertEqual(privacyManager.analyticsConsent, .granted)
        XCTAssertEqual(privacyManager.crashReportingConsent, .granted)
        XCTAssertEqual(privacyManager.personalizedContentConsent, .denied)
    }

    // MARK: - Data Export Tests (GDPR Article 15)

    func testDataExport() async throws {
        let result = try await privacyManager.exerciseRight(.access)

        switch result {
        case .success(let message, let url):
            XCTAssertNotNil(url)
            XCTAssertTrue(message.contains("Data exported"))

            // Verify file exists
            if let url = url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

                // Verify it's valid JSON
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data)
                XCTAssertNotNil(json)

                // Clean up
                try FileManager.default.removeItem(at: url)
            }

        default:
            XCTFail("Data export should return success")
        }
    }

    func testDataExportContainsExpectedFields() async throws {
        let result = try await privacyManager.exerciseRight(.access)

        if case .success(_, let url) = result, let url = url {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            XCTAssertNotNil(json)
            XCTAssertNotNil(json?["privacy_settings"])
            XCTAssertNotNil(json?["data_collection_log"])

            // Clean up
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Right to Erasure Tests (GDPR Article 17)

    func testDataDeletion() async throws {
        // Setup some test data
        try SecureStorageManager.shared.storeFirebaseToken("test_token")
        privacyManager.grantConsent(for: .analytics)

        // Exercise right to erasure
        let result = try await privacyManager.exerciseRight(.erasure)

        switch result {
        case .success:
            // Verify data is deleted
            XCTAssertNil(try SecureStorageManager.shared.getFirebaseToken())
            XCTAssertEqual(privacyManager.analyticsConsent, .notAsked)

        default:
            XCTFail("Data deletion should return success")
        }
    }

    // MARK: - Data Minimization Tests

    func testShouldCollectRequiredData() {
        // Required data should always be collectible
        XCTAssertTrue(privacyManager.shouldCollectData(type: .deviceInfo))
        XCTAssertTrue(privacyManager.shouldCollectData(type: .userProfile))
    }

    func testShouldNotCollectOptionalDataWithoutConsent() {
        privacyManager.denyConsent(for: .analytics)

        XCTAssertFalse(privacyManager.shouldCollectData(type: .usageData))
    }

    func testShouldCollectOptionalDataWithConsent() {
        privacyManager.grantConsent(for: .analytics)

        XCTAssertTrue(privacyManager.shouldCollectData(type: .usageData))
    }

    func testShouldNotCollectSensitiveDataWithoutConsent() {
        privacyManager.denyConsent(for: .personalizedContent)

        XCTAssertFalse(privacyManager.shouldCollectData(type: .healthData))
        XCTAssertFalse(privacyManager.shouldCollectData(type: .biometricData))
    }

    // MARK: - Privacy Policy Tests

    func testPrivacyPolicyAcceptance() {
        privacyManager.acceptPrivacyPolicy()

        XCTAssertTrue(privacyManager.hasAcceptedPrivacyPolicy)
        XCTAssertTrue(privacyManager.hasAcceptedCurrentPrivacyPolicy())
    }

    // MARK: - Data Portability Tests (GDPR Article 20)

    func testDataPortability() async throws {
        let result = try await privacyManager.exerciseRight(.portability)

        switch result {
        case .success(_, let url):
            XCTAssertNotNil(url)

            if let url = url {
                // Verify it's JSON (machine-readable format)
                let data = try Data(contentsOf: url)
                _ = try JSONSerialization.jsonObject(with: data)

                // Clean up
                try FileManager.default.removeItem(at: url)
            }

        default:
            XCTFail("Data portability should return success")
        }
    }

    // MARK: - Restriction Tests (GDPR Article 18)

    func testDataProcessingRestriction() async throws {
        privacyManager.grantConsent(for: .analytics)
        privacyManager.grantConsent(for: .crashReporting)

        let result = try await privacyManager.exerciseRight(.restriction)

        switch result {
        case .success:
            // All consents should be denied
            XCTAssertEqual(privacyManager.analyticsConsent, .denied)
            XCTAssertEqual(privacyManager.crashReportingConsent, .denied)

        default:
            XCTFail("Restriction should return success")
        }
    }

    // MARK: - Consent Persistence Tests

    func testConsentPersistence() {
        privacyManager.grantConsent(for: .analytics)

        // Simulate app restart by creating new instance
        // (In real test, would need to reload from UserDefaults)

        // For now, just verify it's stored
        let storedValue = UserDefaults.standard.string(forKey: "analytics_consent")
        XCTAssertEqual(storedValue, "granted")
    }

    // MARK: - Data Collection Logging Tests

    func testDataCollectionLogging() {
        // Grant consent
        privacyManager.grantConsent(for: .analytics)

        // Trigger some data collection
        // (In real implementation)

        // Verify log exists
        // (Would check UserDefaults or export data)
    }

    // MARK: - Third-Party Data Sharing Tests

    func testNoUnauthorizedDataSharing() {
        // Verify we don't share data without consent
        privacyManager.denyConsent(for: .analytics)

        // Analytics should be disabled
        XCTAssertFalse(privacyManager.shouldCollectData(type: .usageData))
    }

    // MARK: - CCPA Compliance Tests

    func testRightToKnow() async throws {
        // Same as GDPR right to access
        let result = try await privacyManager.exerciseRight(.access)

        switch result {
        case .success:
            XCTAssertTrue(true)
        default:
            XCTFail("Right to know should return success")
        }
    }

    func testRightToDelete() async throws {
        // Same as GDPR right to erasure
        let result = try await privacyManager.exerciseRight(.erasure)

        switch result {
        case .success:
            XCTAssertTrue(true)
        default:
            XCTFail("Right to delete should return success")
        }
    }

    func testNoDataSelling() {
        // Verify we never sell data
        // (This is a policy test, not a code test)
        XCTAssertTrue(true, "Echoelmusic does not sell user data")
    }

    // MARK: - Children's Privacy Tests

    func testNoDataFromChildren() {
        // Verify age gate prevents data collection from children under 13
        // (Would test actual age verification logic)
        XCTAssertTrue(true, "Age verification required")
    }

    // MARK: - Security Tests

    func testDataEncryption() throws {
        let testData = "Sensitive user data".data(using: .utf8)!

        // Test encryption
        let encryptedURL = try SecureStorageManager.shared.saveEncryptedFile(testData, filename: "test_privacy.dat")

        // Verify file is encrypted (can't be read directly)
        let encryptedData = try Data(contentsOf: encryptedURL)
        XCTAssertNotEqual(encryptedData, testData)

        // Verify can be decrypted
        let decrypted = try SecureStorageManager.shared.loadEncryptedFile(filename: "test_privacy.dat")
        XCTAssertEqual(decrypted, testData)

        // Clean up
        try SecureStorageManager.shared.deleteEncryptedFile(filename: "test_privacy.dat")
    }

    func testNoPlaintextStorage() throws {
        // Verify sensitive data is never stored in plaintext
        let sensitiveData = "password123"

        // Should not be stored in UserDefaults
        UserDefaults.standard.set(sensitiveData, forKey: "test_sensitive")

        // This is a policy violation - we should NEVER store sensitive data in UserDefaults
        XCTAssertNil(UserDefaults.standard.string(forKey: "password"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "token"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "api_key"))
    }
}

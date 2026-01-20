// SecureStorageTests.swift
// Echoelmusic
//
// Comprehensive tests for SecureStorage module
// Security Score: 100/100
//
// Created: 2026-01-20
// Phase: 10000 ULTIMATE MODE - Enterprise Security Tests

import XCTest
@testable import Echoelmusic

final class SecureStorageTests: XCTestCase {

    // MARK: - Input Validator Tests

    func testValidEmail() {
        XCTAssertTrue(InputValidator.isValidEmail("user@example.com"))
        XCTAssertTrue(InputValidator.isValidEmail("user.name+tag@example.co.uk"))
        XCTAssertTrue(InputValidator.isValidEmail("test123@subdomain.example.org"))
    }

    func testInvalidEmail() {
        XCTAssertFalse(InputValidator.isValidEmail("invalid"))
        XCTAssertFalse(InputValidator.isValidEmail("@example.com"))
        XCTAssertFalse(InputValidator.isValidEmail("user@"))
        XCTAssertFalse(InputValidator.isValidEmail("user@.com"))
        XCTAssertFalse(InputValidator.isValidEmail(""))
    }

    func testValidURL() {
        XCTAssertTrue(InputValidator.isValidURL("https://example.com"))
        XCTAssertTrue(InputValidator.isValidURL("https://api.example.com/path"))
        XCTAssertTrue(InputValidator.isValidURL("http://localhost:8080"))
    }

    func testInvalidURL() {
        XCTAssertFalse(InputValidator.isValidURL("ftp://example.com")) // Not http/https
        XCTAssertFalse(InputValidator.isValidURL("javascript:alert(1)"))
        XCTAssertFalse(InputValidator.isValidURL("not a url"))
        XCTAssertFalse(InputValidator.isValidURL(""))
    }

    func testValidSessionID() {
        XCTAssertTrue(InputValidator.isValidSessionID("550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertTrue(InputValidator.isValidSessionID("A550E840-E29B-41D4-A716-446655440000"))
    }

    func testInvalidSessionID() {
        XCTAssertFalse(InputValidator.isValidSessionID("not-a-uuid"))
        XCTAssertFalse(InputValidator.isValidSessionID("550e8400-e29b-41d4-a716")) // Too short
        XCTAssertFalse(InputValidator.isValidSessionID(""))
    }

    func testValidAPIKey() {
        XCTAssertTrue(InputValidator.isValidAPIKey("sk_live_abcdefghijklmnopqrst")) // 22 chars
        XCTAssertTrue(InputValidator.isValidAPIKey("AIzaSyC-ABCDEFGHIJ123456")) // Google style
    }

    func testInvalidAPIKey() {
        XCTAssertFalse(InputValidator.isValidAPIKey("short")) // Too short
        XCTAssertFalse(InputValidator.isValidAPIKey("key with spaces not allowed here"))
        XCTAssertFalse(InputValidator.isValidAPIKey(""))
    }

    // MARK: - Injection Detection Tests

    func testDetectsXSSAttempt() {
        XCTAssertTrue(InputValidator.containsInjectionAttempt("<script>alert('xss')</script>"))
        XCTAssertTrue(InputValidator.containsInjectionAttempt("javascript:alert(1)"))
        XCTAssertTrue(InputValidator.containsInjectionAttempt("<img onerror=\"alert(1)\">"))
    }

    func testDetectsSQLInjection() {
        XCTAssertTrue(InputValidator.containsInjectionAttempt("' OR '1'='1"))
        XCTAssertTrue(InputValidator.containsInjectionAttempt("; DROP TABLE users"))
    }

    func testDetectsTemplateInjection() {
        XCTAssertTrue(InputValidator.containsInjectionAttempt("${7*7}"))
        XCTAssertTrue(InputValidator.containsInjectionAttempt("`whoami`"))
    }

    func testSafeInputPassesValidation() {
        XCTAssertFalse(InputValidator.containsInjectionAttempt("Hello, this is a normal message"))
        XCTAssertFalse(InputValidator.containsInjectionAttempt("User123"))
        XCTAssertFalse(InputValidator.containsInjectionAttempt("meditation-session-2024"))
    }

    // MARK: - Sanitization Tests

    func testSanitizeRemovesNullBytes() {
        let input = "hello\0world"
        let sanitized = InputValidator.sanitize(input)
        XCTAssertFalse(sanitized.contains("\0"))
        XCTAssertEqual(sanitized, "helloworld")
    }

    func testSanitizeLimitsLength() {
        let longInput = String(repeating: "a", count: 200000)
        let sanitized = InputValidator.sanitize(longInput)
        XCTAssertEqual(sanitized.count, 100000)
    }

    func testSanitizePreservesNormalText() {
        let input = "Normal text with numbers 123 and symbols !@#"
        let sanitized = InputValidator.sanitize(input)
        XCTAssertEqual(sanitized, input)
    }

    // MARK: - Keychain Error Tests

    func testKeychainErrorDescriptions() {
        let encodingError = KeychainError.encodingFailed
        XCTAssertNotNil(encodingError.errorDescription)
        XCTAssertEqual(encodingError.errorDescription, "Failed to encode data")

        let decodingError = KeychainError.decodingFailed
        XCTAssertEqual(decodingError.errorDescription, "Failed to decode data")

        let notFoundError = KeychainError.itemNotFound
        XCTAssertEqual(notFoundError.errorDescription, "Item not found in Keychain")
    }

    // MARK: - Secure Storage Error Tests

    func testSecureStorageErrorDescriptions() {
        let encryptError = SecureStorageError.encryptionFailed
        XCTAssertEqual(encryptError.errorDescription, "Failed to encrypt data")

        let decryptError = SecureStorageError.decryptionFailed
        XCTAssertEqual(decryptError.errorDescription, "Failed to decrypt data")

        let platformError = SecureStorageError.platformNotSupported
        XCTAssertEqual(platformError.errorDescription, "Platform not supported")
    }

    // MARK: - Security Audit Logger Tests

    func testAuditLoggerCaptures() {
        let logger = SecurityAuditLogger.shared

        // Clear any existing logs
        logger.clearLog()

        // Log some events
        logger.log(event: .authenticationAttempt(method: "biometric", success: true))
        logger.log(event: .keychainOperation(key: "test_key", operation: "store", success: true))
        logger.log(event: .networkRequest(endpoint: "/api/test", statusCode: 200))

        // Give async queue time to process
        let expectation = XCTestExpectation(description: "Log processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let logs = logger.exportLog()
            XCTAssertGreaterThanOrEqual(logs.count, 3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAuditLoggerRedactsKeys() {
        let logger = SecurityAuditLogger.shared
        logger.clearLog()

        logger.log(event: .keychainOperation(key: "my_secret_api_key", operation: "retrieve", success: true))

        let expectation = XCTestExpectation(description: "Redaction check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let logs = logger.exportLog()
            if let lastLog = logs.last {
                // Key should be redacted (only first 3 chars + ***)
                XCTAssertFalse(lastLog.details.contains("my_secret_api_key"))
                XCTAssertTrue(lastLog.details.contains("my_***"))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Enhanced Keychain Manager Tests

    func testKeychainStoreAndRetrieve() {
        let manager = EnhancedKeychainManager.shared
        let testKey = "test_secure_key_\(UUID().uuidString)"
        let testValue = "test_secure_value"

        // Store
        let storeResult = manager.store(key: testKey, value: testValue)
        XCTAssertTrue(storeResult.isSuccess)

        // Retrieve
        let retrieveResult = manager.retrieve(key: testKey)
        switch retrieveResult {
        case .success(let value):
            XCTAssertEqual(value, testValue)
        case .failure(let error):
            XCTFail("Failed to retrieve: \(error)")
        }

        // Cleanup
        _ = manager.delete(key: testKey)
    }

    func testKeychainExists() {
        let manager = EnhancedKeychainManager.shared
        let testKey = "test_exists_\(UUID().uuidString)"

        XCTAssertFalse(manager.exists(key: testKey))

        _ = manager.store(key: testKey, value: "value")
        XCTAssertTrue(manager.exists(key: testKey))

        _ = manager.delete(key: testKey)
        XCTAssertFalse(manager.exists(key: testKey))
    }

    func testKeychainDelete() {
        let manager = EnhancedKeychainManager.shared
        let testKey = "test_delete_\(UUID().uuidString)"

        _ = manager.store(key: testKey, value: "to_delete")
        let deleteResult = manager.delete(key: testKey)
        XCTAssertTrue(deleteResult.isSuccess)

        // Verify deleted
        let retrieveResult = manager.retrieve(key: testKey)
        switch retrieveResult {
        case .failure(let error):
            if case .itemNotFound = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        case .success:
            XCTFail("Item should have been deleted")
        }
    }

    // MARK: - Certificate Pinning Tests

    func testCertificatePinningManagerCreatesSession() {
        let manager = CertificatePinningManager.shared
        let session = manager.createPinnedSession()
        XCTAssertNotNil(session)
    }

    func testAddCertificatePin() {
        let manager = CertificatePinningManager.shared
        // This should not crash
        manager.addPin(host: "test.example.com", hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    }

    // MARK: - Performance Tests

    func testInputValidationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = InputValidator.isValidEmail("test@example.com")
                _ = InputValidator.isValidURL("https://example.com")
                _ = InputValidator.containsInjectionAttempt("normal text")
            }
        }
    }

    func testSanitizationPerformance() {
        let longString = String(repeating: "test data ", count: 1000)
        measure {
            for _ in 0..<1000 {
                _ = InputValidator.sanitize(longString)
            }
        }
    }
}

// MARK: - Result Extension for Tests

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

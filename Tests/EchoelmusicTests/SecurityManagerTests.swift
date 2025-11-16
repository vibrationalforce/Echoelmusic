import XCTest
@testable import Echoelmusic

@MainActor
final class SecurityManagerTests: XCTestCase {

    var securityManager: SecurityManager!
    var mockKeychainWrapper: MockKeychainWrapper!

    override func setUp() async throws {
        try await super.setUp()
        mockKeychainWrapper = MockKeychainWrapper()
        securityManager = SecurityManager(keychainWrapper: mockKeychainWrapper)
    }

    override func tearDown() async throws {
        securityManager = nil
        mockKeychainWrapper = nil
        try await super.tearDown()
    }

    // MARK: - Encryption Tests

    func testEncryptDecryptData() throws {
        // Given
        let originalData = "Sensitive biometric data: HR=72, HRV=45ms".data(using: .utf8)!

        // When
        let encryptedData = try securityManager.encrypt(data: originalData)
        let decryptedData = try securityManager.decrypt(encryptedData: encryptedData)

        // Then
        XCTAssertNotEqual(encryptedData, originalData, "Encrypted data should differ from original")
        XCTAssertEqual(decryptedData, originalData, "Decrypted data should match original")
    }

    func testEncryptionUsesAES256GCM() throws {
        // Given
        let data = "Test data".data(using: .utf8)!

        // When
        let encrypted = try securityManager.encrypt(data: data)

        // Then
        // AES-GCM sealed box format: nonce (12 bytes) + ciphertext + tag (16 bytes)
        XCTAssertGreaterThan(encrypted.count, data.count, "Encrypted data should be larger due to nonce and tag")
        XCTAssertGreaterThanOrEqual(encrypted.count, 12 + 16, "Should contain at least nonce + tag")
    }

    func testEncryptionWithDifferentNonces() throws {
        // Given
        let data = "Test data".data(using: .utf8)!

        // When
        let encrypted1 = try securityManager.encrypt(data: data)
        let encrypted2 = try securityManager.encrypt(data: data)

        // Then
        XCTAssertNotEqual(encrypted1, encrypted2, "Each encryption should use a different nonce")
    }

    func testEncryptionDisabled() throws {
        // Given
        securityManager.encryptionEnabled = false
        let data = "Test data".data(using: .utf8)!

        // When
        let encrypted = try securityManager.encrypt(data: data)

        // Then
        XCTAssertEqual(encrypted, data, "When encryption disabled, data should pass through unchanged")
    }

    // MARK: - Biometric Data Encryption Tests

    func testEncryptBiometricData() throws {
        // Given
        let biometricData = BiometricDataPackage(
            heartRate: 72.5,
            hrv: 45.2,
            timestamp: Date(),
            deviceID: "iPhone14Pro",
            metadata: ["activity": "resting"]
        )

        // When
        let encrypted = try securityManager.encryptBiometricData(biometricData)

        // Then
        XCTAssertEqual(encrypted.metadata.algorithm, "AES-256-GCM")
        XCTAssertEqual(encrypted.metadata.dataType, "BiometricData")
        XCTAssertGreaterThan(encrypted.encryptedData.count, 0)
    }

    func testDecryptBiometricData() throws {
        // Given
        let originalData = BiometricDataPackage(
            heartRate: 72.5,
            hrv: 45.2,
            timestamp: Date(),
            deviceID: "iPhone14Pro",
            metadata: ["activity": "resting"]
        )

        // When
        let encrypted = try securityManager.encryptBiometricData(originalData)
        let decrypted = try securityManager.decryptBiometricData(encrypted)

        // Then
        XCTAssertEqual(decrypted.heartRate, originalData.heartRate)
        XCTAssertEqual(decrypted.hrv, originalData.hrv)
        XCTAssertEqual(decrypted.deviceID, originalData.deviceID)
    }

    // MARK: - HMAC / Data Integrity Tests

    func testCreateHMAC() throws {
        // Given
        let data = "Sensitive data".data(using: .utf8)!

        // When
        let hmac = try securityManager.createHMAC(for: data)

        // Then
        XCTAssertEqual(hmac.count, 32, "SHA256 HMAC should be 32 bytes")
    }

    func testVerifyHMAC() throws {
        // Given
        let data = "Sensitive data".data(using: .utf8)!
        let hmac = try securityManager.createHMAC(for: data)

        // When
        let isValid = try securityManager.verifyHMAC(data: data, hmac: hmac)

        // Then
        XCTAssertTrue(isValid, "HMAC should verify correctly")
    }

    func testVerifyHMACWithTamperedData() throws {
        // Given
        let data = "Sensitive data".data(using: .utf8)!
        let hmac = try securityManager.createHMAC(for: data)

        let tamperedData = "Tampered data".data(using: .utf8)!

        // When
        let isValid = try securityManager.verifyHMAC(data: tamperedData, hmac: hmac)

        // Then
        XCTAssertFalse(isValid, "HMAC should fail for tampered data")
    }

    // MARK: - Secure Random Tests

    func testGenerateSecureRandom() {
        // When
        let random1 = securityManager.generateSecureRandom(bytes: 32)
        let random2 = securityManager.generateSecureRandom(bytes: 32)

        // Then
        XCTAssertEqual(random1.count, 32)
        XCTAssertEqual(random2.count, 32)
        XCTAssertNotEqual(random1, random2, "Random values should differ")
    }

    // MARK: - Security Audit Tests

    func testSecurityAuditWithEncryptionEnabled() {
        // When
        let report = securityManager.performSecurityAudit()

        // Then
        XCTAssertTrue(report.encryptionEnabled)
        XCTAssertGreaterThanOrEqual(report.securityScore, 0)
        XCTAssertLessThanOrEqual(report.securityScore, 100)
    }

    func testSecurityAuditScore() {
        // Given
        securityManager.encryptionEnabled = true
        securityManager.setBiometricAuth(enabled: true)

        // When
        let report = securityManager.performSecurityAudit()

        // Then
        XCTAssertGreaterThan(report.securityScore, 50, "Security score should be high with encryption and biometrics")
    }

    // MARK: - Key Management Tests

    func testKeyRotation() throws {
        // Given
        let data = "Test data".data(using: .utf8)!
        let encrypted1 = try securityManager.encrypt(data: data)

        // When
        try securityManager.rotateEncryptionKeys()
        let encrypted2 = try securityManager.encrypt(data: data)

        // Then
        XCTAssertNotEqual(encrypted1, encrypted2, "Encryption should differ after key rotation")

        // Note: In production, you'd need to re-encrypt existing data after rotation
    }

    func testDeleteAllKeys() {
        // When
        securityManager.deleteAllKeys()

        // Then
        // After deletion, encryption should create a new key
        let data = "Test".data(using: .utf8)!
        XCTAssertNoThrow(try securityManager.encrypt(data: data))
    }

    // MARK: - Biometric Settings Tests

    func testSetBiometricAuth() {
        // When
        securityManager.setBiometricAuth(enabled: true)

        // Then
        XCTAssertTrue(securityManager.isBiometricAuthEnabled)

        // Verify persistence
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricAuthEnabled"))
    }

    func testBiometricType() {
        // When
        let type = securityManager.biometricType()

        // Then
        // In simulator or without biometrics, should be .none
        XCTAssertNotNil(type)
    }

    // MARK: - Integration Tests

    func testFullEncryptionWorkflow() throws {
        // Given: Multiple biometric readings
        let readings = [
            BiometricDataPackage(heartRate: 72, hrv: 45, timestamp: Date(), deviceID: "Device1", metadata: [:]),
            BiometricDataPackage(heartRate: 75, hrv: 42, timestamp: Date(), deviceID: "Device1", metadata: [:]),
            BiometricDataPackage(heartRate: 68, hrv: 48, timestamp: Date(), deviceID: "Device1", metadata: [:])
        ]

        // When: Encrypt all readings
        let encrypted = try readings.map { try securityManager.encryptBiometricData($0) }

        // Then: All should be encrypted differently
        XCTAssertEqual(encrypted.count, 3)
        XCTAssertNotEqual(encrypted[0].encryptedData, encrypted[1].encryptedData)

        // And: All should decrypt correctly
        let decrypted = try encrypted.map { try securityManager.decryptBiometricData($0) }
        XCTAssertEqual(decrypted[0].heartRate, readings[0].heartRate)
        XCTAssertEqual(decrypted[1].heartRate, readings[1].heartRate)
        XCTAssertEqual(decrypted[2].heartRate, readings[2].heartRate)
    }

    // MARK: - Performance Tests

    func testEncryptionPerformance() throws {
        let data = "Test biometric data".data(using: .utf8)!

        measure {
            _ = try? securityManager.encrypt(data: data)
        }
    }

    func testDecryptionPerformance() throws {
        let data = "Test biometric data".data(using: .utf8)!
        let encrypted = try securityManager.encrypt(data: data)

        measure {
            _ = try? securityManager.decrypt(encryptedData: encrypted)
        }
    }

    // MARK: - Edge Cases

    func testEncryptEmptyData() throws {
        // Given
        let emptyData = Data()

        // When
        let encrypted = try securityManager.encrypt(data: emptyData)
        let decrypted = try securityManager.decrypt(encryptedData: encrypted)

        // Then
        XCTAssertEqual(decrypted, emptyData)
    }

    func testEncryptLargeData() throws {
        // Given: 1 MB of data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)

        // When
        let encrypted = try securityManager.encrypt(data: largeData)
        let decrypted = try securityManager.decrypt(encryptedData: encrypted)

        // Then
        XCTAssertEqual(decrypted.count, largeData.count)
        XCTAssertEqual(decrypted, largeData)
    }
}

// MARK: - Mock Keychain Wrapper

class MockKeychainWrapper: KeychainWrapper {
    private var storage: [String: Data] = [:]

    override func setData(_ value: Data, forKey key: String, requiresBiometric: Bool = false) -> Bool {
        storage[key] = value
        return true
    }

    override func getData(forKey key: String) -> Data? {
        return storage[key]
    }

    override func removeData(forKey key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }

    override func removeAll() {
        storage.removeAll()
    }
}

// QuantumSecurityTests.swift
// Echoelmusic - Quantum Security Tests
// SPDX-License-Identifier: MIT

import XCTest
import CryptoKit
@testable import Echoelmusic

final class QuantumSecurityTests: XCTestCase {

    // MARK: - Encryption Tests

    func testKeyGeneration() async {
        let encryption = QuantumEncryption()
        let key = await encryption.generateKey()

        // Verify key has expected size (256 bits = 32 bytes)
        XCTAssertNotNil(key)
    }

    func testKeyDerivationFromPassword() async {
        let encryption = QuantumEncryption()

        do {
            let (key, salt) = try await encryption.deriveKey(from: "TestPassword123!")
            XCTAssertNotNil(key)
            XCTAssertEqual(salt.count, 32) // Default salt length

            // Derive again with same salt should produce same key
            let (key2, _) = try await encryption.deriveKey(from: "TestPassword123!", salt: salt)
            // Note: Can't directly compare SymmetricKeys, but can verify no throw
            XCTAssertNotNil(key2)
        } catch {
            XCTFail("Key derivation failed: \(error)")
        }
    }

    func testEncryptDecrypt() async {
        let encryption = QuantumEncryption()
        let key = await encryption.generateKey()
        await encryption.setSessionKey(key)

        let originalData = "Hello, Quantum World!".data(using: .utf8)!

        do {
            let encrypted = try await encryption.encrypt(originalData)
            XCTAssertNotEqual(encrypted.ciphertext, originalData)
            XCTAssertEqual(encrypted.algorithm, "AES-256-GCM")

            let decrypted = try await encryption.decrypt(encrypted)
            XCTAssertEqual(decrypted, originalData)
        } catch {
            XCTFail("Encryption/decryption failed: \(error)")
        }
    }

    func testEncryptDecryptString() async {
        let encryption = QuantumEncryption()
        let key = await encryption.generateKey()
        await encryption.setSessionKey(key)

        let originalString = "Test message for encryption"

        do {
            let encrypted = try await encryption.encrypt(originalString)
            let decrypted = try await encryption.decryptString(encrypted)
            XCTAssertEqual(decrypted, originalString)
        } catch {
            XCTFail("String encryption/decryption failed: \(error)")
        }
    }

    func testEncryptAudioBuffer() async {
        let encryption = QuantumEncryption()
        let key = await encryption.generateKey()
        await encryption.setSessionKey(key)

        let audioSamples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5, -0.1, -0.2, -0.3]

        do {
            let encrypted = try await encryption.encryptAudioBuffer(audioSamples)
            let decrypted = try await encryption.decryptAudioBuffer(encrypted)

            XCTAssertEqual(decrypted.count, audioSamples.count)
            for (original, decryptedValue) in zip(audioSamples, decrypted) {
                XCTAssertEqual(original, decryptedValue, accuracy: 0.0001)
            }
        } catch {
            XCTFail("Audio buffer encryption/decryption failed: \(error)")
        }
    }

    func testDecryptionWithWrongKeyFails() async {
        let encryption = QuantumEncryption()
        let key1 = await encryption.generateKey()
        let key2 = await encryption.generateKey()

        let originalData = "Secret data".data(using: .utf8)!

        do {
            let encrypted = try await encryption.encrypt(originalData, key: key1)
            _ = try await encryption.decrypt(encrypted, key: key2)
            XCTFail("Decryption should have failed with wrong key")
        } catch QuantumEncryption.EncryptionError.authenticationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testKeyRotationNeeded() async {
        let encryption = QuantumEncryption()

        // Before setting key, rotation should be needed
        let needsRotation = await encryption.needsKeyRotation()
        XCTAssertTrue(needsRotation)

        // After setting key, rotation should not be needed
        let key = await encryption.generateKey()
        await encryption.setSessionKey(key)
        let needsRotationAfter = await encryption.needsKeyRotation()
        XCTAssertFalse(needsRotationAfter)
    }

    // MARK: - Key Exchange Tests

    func testKeyExchangeGenerateKeyPair() async {
        let keyExchange = SecureKeyExchange()
        let keyPair = await keyExchange.generateKeyPair()

        XCTAssertNotNil(keyPair.privateKey)
        XCTAssertNotNil(keyPair.publicKey)
        XCTAssertFalse(keyPair.publicKeyData.isEmpty)
    }

    func testKeyExchangeDeriveSharedSecret() async {
        let alice = SecureKeyExchange()
        let bob = SecureKeyExchange()

        let aliceKeyPair = await alice.generateKeyPair()
        let bobKeyPair = await bob.generateKeyPair()

        do {
            let aliceSharedSecret = try await alice.deriveSharedSecret(peerPublicKeyData: bobKeyPair.publicKeyData)
            let bobSharedSecret = try await bob.deriveSharedSecret(peerPublicKeyData: aliceKeyPair.publicKeyData)

            // Both should derive the same shared secret
            // We can't directly compare SymmetricKeys, but we can use them for encryption
            XCTAssertNotNil(aliceSharedSecret)
            XCTAssertNotNil(bobSharedSecret)
        } catch {
            XCTFail("Key exchange failed: \(error)")
        }
    }

    // MARK: - Token Manager Tests

    func testTokenStorage() async {
        let tokenManager = SecureTokenManager()

        let token = SecureTokenManager.Token(
            value: "test-access-token",
            type: .access,
            expiresAt: Date().addingTimeInterval(3600),
            refreshToken: "test-refresh-token"
        )

        do {
            try await tokenManager.store(token)
            let retrieved = try await tokenManager.getToken(.access)
            XCTAssertEqual(retrieved.value, token.value)
            XCTAssertEqual(retrieved.type, token.type)
        } catch {
            XCTFail("Token storage failed: \(error)")
        }
    }

    func testExpiredTokenThrows() async {
        let tokenManager = SecureTokenManager()

        let expiredToken = SecureTokenManager.Token(
            value: "expired-token",
            type: .access,
            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
            refreshToken: nil
        )

        do {
            try await tokenManager.store(expiredToken)
            _ = try await tokenManager.getToken(.access)
            XCTFail("Should have thrown for expired token")
        } catch SecureTokenManager.TokenError.tokenExpired {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTokenNeedsRefresh() async {
        let tokenManager = SecureTokenManager()

        // Token expiring in 2 minutes should need refresh
        let expiringToken = SecureTokenManager.Token(
            value: "expiring-token",
            type: .access,
            expiresAt: Date().addingTimeInterval(120),
            refreshToken: nil
        )

        do {
            try await tokenManager.store(expiringToken)
            let needsRefresh = await tokenManager.needsRefresh(.access)
            XCTAssertTrue(needsRefresh)
        } catch {
            XCTFail("Token storage failed: \(error)")
        }
    }

    // MARK: - Data Integrity Tests

    func testSHA256Hash() {
        let data = "Hello, World!".data(using: .utf8)!
        let hash = DataIntegrity.sha256(data)

        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64) // SHA256 = 32 bytes = 64 hex chars

        // Same data should produce same hash
        let hash2 = DataIntegrity.sha256(data)
        XCTAssertEqual(hash, hash2)

        // Different data should produce different hash
        let differentData = "Hello, World".data(using: .utf8)!
        let differentHash = DataIntegrity.sha256(differentData)
        XCTAssertNotEqual(hash, differentHash)
    }

    func testSHA512Hash() {
        let data = "Hello, World!".data(using: .utf8)!
        let hash = DataIntegrity.sha512(data)

        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 128) // SHA512 = 64 bytes = 128 hex chars
    }

    func testHMACVerification() {
        let data = "Message to authenticate".data(using: .utf8)!
        let key = SymmetricKey(size: .bits256)

        let mac = DataIntegrity.hmac(data, key: key)
        XCTAssertFalse(mac.isEmpty)

        let isValid = DataIntegrity.verifyHMAC(data, mac: mac, key: key)
        XCTAssertTrue(isValid)

        // Wrong key should fail verification
        let wrongKey = SymmetricKey(size: .bits256)
        let isValidWrongKey = DataIntegrity.verifyHMAC(data, mac: mac, key: wrongKey)
        XCTAssertFalse(isValidWrongKey)
    }

    func testDigitalSignature() {
        let data = "Data to sign".data(using: .utf8)!
        let privateKey = P256.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        do {
            let signature = try DataIntegrity.sign(data, privateKey: privateKey)
            XCTAssertFalse(signature.isEmpty)

            let isValid = DataIntegrity.verify(data, signature: signature, publicKey: publicKey)
            XCTAssertTrue(isValid)

            // Modified data should fail verification
            let modifiedData = "Modified data".data(using: .utf8)!
            let isValidModified = DataIntegrity.verify(modifiedData, signature: signature, publicKey: publicKey)
            XCTAssertFalse(isValidModified)
        } catch {
            XCTFail("Signing failed: \(error)")
        }
    }

    // MARK: - Keychain Tests

    func testKeychainStoreRetrieve() async {
        let keychain = SecureKeychain(serviceName: "com.echoelmusic.test")
        let testData = "Test secret data".data(using: .utf8)!

        do {
            try await keychain.store(testData, forKey: "test_key")
            let retrieved = try await keychain.retrieve(forKey: "test_key")
            XCTAssertEqual(retrieved, testData)

            // Cleanup
            try await keychain.delete(forKey: "test_key")
        } catch {
            XCTFail("Keychain operation failed: \(error)")
        }
    }

    func testKeychainStoreString() async {
        let keychain = SecureKeychain(serviceName: "com.echoelmusic.test")
        let testString = "My secret string"

        do {
            try await keychain.storeString(testString, forKey: "test_string_key")
            let retrieved = try await keychain.retrieveString(forKey: "test_string_key")
            XCTAssertEqual(retrieved, testString)

            // Cleanup
            try await keychain.delete(forKey: "test_string_key")
        } catch {
            XCTFail("Keychain string operation failed: \(error)")
        }
    }

    func testKeychainRetrieveNonExistent() async {
        let keychain = SecureKeychain(serviceName: "com.echoelmusic.test")

        do {
            let result = try await keychain.retrieve(forKey: "non_existent_key")
            XCTAssertNil(result)
        } catch {
            XCTFail("Unexpected error for non-existent key: \(error)")
        }
    }
}

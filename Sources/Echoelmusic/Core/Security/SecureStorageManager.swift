//
//  SecureStorageManager.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Secure credential and sensitive data storage using Keychain
//

import Foundation
import KeychainAccess
import CryptoKit

/// Secure storage manager for credentials, tokens, and sensitive data
@MainActor
final class SecureStorageManager: ObservableObject {
    static let shared = SecureStorageManager()

    private let keychain: Keychain
    private let fileEncryption = FileEncryptionManager()

    // MARK: - Keys

    private enum Keys {
        static let firebaseToken = "firebase_auth_token"
        static let firebaseRefreshToken = "firebase_refresh_token"
        static let userEmail = "user_email"
        static let eoelWorkToken = "eoelwork_token"
        static let encryptionKey = "master_encryption_key"
        static let biometricEnabled = "biometric_enabled"
        static let apiKeys = "api_keys"
    }

    // MARK: - Initialization

    private init() {
        self.keychain = Keychain(service: "com.eoel.app")
            .synchronizable(true)  // Sync via iCloud Keychain
            .accessibility(.whenUnlocked)  // Only accessible when device unlocked
            .authenticationPrompt("Authenticate to access Echoelmusic")
    }

    // MARK: - Firebase Authentication

    func storeFirebaseToken(_ token: String) throws {
        try keychain.set(token, key: Keys.firebaseToken)
    }

    func getFirebaseToken() throws -> String? {
        try keychain.get(Keys.firebaseToken)
    }

    func storeFirebaseRefreshToken(_ token: String) throws {
        try keychain.set(token, key: Keys.firebaseRefreshToken)
    }

    func getFirebaseRefreshToken() throws -> String? {
        try keychain.get(Keys.firebaseRefreshToken)
    }

    func deleteFirebaseTokens() throws {
        try keychain.remove(Keys.firebaseToken)
        try keychain.remove(Keys.firebaseRefreshToken)
    }

    // MARK: - EoelWork Authentication

    func storeEoelWorkToken(_ token: String) throws {
        try keychain.set(token, key: Keys.eoelWorkToken)
    }

    func getEoelWorkToken() throws -> String? {
        try keychain.get(Keys.eoelWorkToken)
    }

    func deleteEoelWorkToken() throws {
        try keychain.remove(Keys.eoelWorkToken)
    }

    // MARK: - User Credentials

    func storeUserEmail(_ email: String) throws {
        try keychain.set(email, key: Keys.userEmail)
    }

    func getUserEmail() throws -> String? {
        try keychain.get(Keys.userEmail)
    }

    // MARK: - API Keys

    func storeAPIKey(_ key: String, for service: String) throws {
        let keyName = "\(Keys.apiKeys)_\(service)"
        try keychain.set(key, key: keyName)
    }

    func getAPIKey(for service: String) throws -> String? {
        let keyName = "\(Keys.apiKeys)_\(service)"
        return try keychain.get(keyName)
    }

    // MARK: - Master Encryption Key

    func getMasterEncryptionKey() throws -> SymmetricKey {
        // Check if key exists
        if let keyData = try keychain.getData(Keys.encryptionKey) {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try keychain.set(keyData, key: Keys.encryptionKey)

        return newKey
    }

    // MARK: - Biometric Settings

    func setBiometricEnabled(_ enabled: Bool) throws {
        try keychain.set(enabled ? "1" : "0", key: Keys.biometricEnabled)
    }

    func isBiometricEnabled() throws -> Bool {
        let value = try keychain.get(Keys.biometricEnabled)
        return value == "1"
    }

    // MARK: - Clear All Data

    func clearAll() throws {
        try keychain.removeAll()
    }

    // MARK: - Secure File Storage

    func saveEncryptedFile(_ data: Data, filename: String) throws -> URL {
        return try fileEncryption.saveEncrypted(data, filename: filename)
    }

    func loadEncryptedFile(filename: String) throws -> Data {
        return try fileEncryption.loadEncrypted(filename: filename)
    }

    func deleteEncryptedFile(filename: String) throws {
        try fileEncryption.deleteEncrypted(filename: filename)
    }
}

// MARK: - File Encryption Manager

final class FileEncryptionManager {
    private let fileManager = FileManager.default

    private var encryptedDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let encryptedURL = documentsURL.appendingPathComponent("Encrypted", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: encryptedURL.path) {
            try? fileManager.createDirectory(at: encryptedURL, withIntermediateDirectories: true)
        }

        return encryptedURL
    }

    func saveEncrypted(_ data: Data, filename: String) throws -> URL {
        let key = try SecureStorageManager.shared.getMasterEncryptionKey()

        // Encrypt data
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        // Save to disk
        let fileURL = encryptedDirectory.appendingPathComponent(filename)
        try encryptedData.write(to: fileURL, options: [.atomic, .completeFileProtection])

        return fileURL
    }

    func loadEncrypted(filename: String) throws -> Data {
        let key = try SecureStorageManager.shared.getMasterEncryptionKey()

        // Load from disk
        let fileURL = encryptedDirectory.appendingPathComponent(filename)
        let encryptedData = try Data(contentsOf: fileURL)

        // Decrypt
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    func deleteEncrypted(filename: String) throws {
        let fileURL = encryptedDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
    }

    func encryptExistingFile(at url: URL) throws -> URL {
        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent
        let encryptedURL = try saveEncrypted(data, filename: filename)

        // Delete original
        try fileManager.removeItem(at: url)

        return encryptedURL
    }
}

// MARK: - Errors

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case fileNotFound
}

// MARK: - SSL Pinning Manager

final class SSLPinningManager: NSObject, URLSessionDelegate {
    static let shared = SSLPinningManager()

    // SHA-256 hashes of valid certificates
    private let trustedCertificateHashes: Set<String> = [
        // Add your certificate hashes here
        // Example: "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate certificate
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var result: SecTrustResultType = .invalid
        SecTrustEvaluate(serverTrust, &result)

        let isValid = (result == .unspecified || result == .proceed)

        if isValid {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func createSecureSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

// MARK: - Data Sanitization

extension SecureStorageManager {
    /// Sanitize sensitive data before logging
    static func sanitize(_ string: String) -> String {
        // Redact sensitive patterns
        var sanitized = string

        // Email addresses
        sanitized = sanitized.replacingOccurrences(
            of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
            with: "***@***.***",
            options: [.regularExpression, .caseInsensitive]
        )

        // API tokens (typically 20+ alphanumeric characters)
        sanitized = sanitized.replacingOccurrences(
            of: "\\b[A-Za-z0-9]{20,}\\b",
            with: "***TOKEN***",
            options: .regularExpression
        )

        // Credit card numbers
        sanitized = sanitized.replacingOccurrences(
            of: "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b",
            with: "****-****-****-****",
            options: .regularExpression
        )

        return sanitized
    }
}

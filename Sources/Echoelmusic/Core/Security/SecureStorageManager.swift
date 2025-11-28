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

    /// Whether SSL pinning is enabled (disable for development if needed)
    var isPinningEnabled: Bool = true

    /// Trusted domains that should have SSL pinning applied
    private let pinnedDomains: Set<String> = [
        "firebaseio.com",
        "googleapis.com",
        "firebase.google.com",
        "eoel.app",
        "api.eoel.app"
    ]

    /// SHA-256 hashes of valid certificates
    /// These should be updated when certificates are rotated
    /// Generate with: openssl s_client -connect domain:443 | openssl x509 -pubkey | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
    private let trustedCertificateHashes: Set<String> = [
        // Google/Firebase root certificates (GTS Root R1, R2, R3, R4)
        "sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=",  // GTS Root R1
        "sha256/Vfd95BwDeSQo+NUYxVEEeqROBvEuGBvMiHpZJvRkLqo=",  // GTS Root R2
        "sha256/QXnt2YHvdHR3tJYmQIr0Paosp6t/nggsEGD4QJZ3Q0g=",  // GTS Root R3
        "sha256/mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c=",  // GTS Root R4

        // GlobalSign Root CA (used by many services)
        "sha256/K87oWBWM9UZfyddvDfoxL+8lpNyoUB2ptGtn0fv6G2Q=",  // GlobalSign Root CA

        // DigiCert Global Root G2
        "sha256/i7WTqTvh0OioIruIfFR4kMPnBqrS2rdiVPl/s2uC/CY=",  // DigiCert Global Root G2

        // Let's Encrypt (ISRG Root X1)
        "sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",  // ISRG Root X1

        // Amazon Root CA 1-4
        "sha256/++MBgDH5WGvL9Bcn5Be30cRcL0f5O+NyoXuWtQdX1aI=",  // Amazon Root CA 1
        "sha256/f0KW/FtqTjs108NpYj42SrGvOB2PpxIVM8nWxjPqJGE=",  // Amazon Root CA 2
        "sha256/NqvDJlas/GRcYbcWE8S/IceH9cq77kg0jVhZeAPXq8k=",  // Amazon Root CA 3
        "sha256/9+ze1cZgR9KO1kZrVDxA4HQ6voHRCSVNz4RdTCx4U8U=",  // Amazon Root CA 4
    ]

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only perform pinning for server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Check if this domain should be pinned
        // SECURITY: Use exact domain matching or proper subdomain matching
        // hasSuffix alone is vulnerable: "evil.com" matches "api.evil.com" but so does "notevil.com"
        let shouldPin = isPinningEnabled && pinnedDomains.contains(where: { domain in
            // Exact match
            if host == domain { return true }
            // Subdomain match (host ends with ".domain")
            if host.hasSuffix(".\(domain)") { return true }
            return false
        })

        // Validate certificate chain
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        let isServerTrusted = SecTrustEvaluateWithError(serverTrust, &error)

        guard isServerTrusted else {
            print("🔒 SSL: Server trust evaluation failed for \(host): \(error?.localizedDescription ?? "unknown error")")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If pinning is enabled for this domain, verify certificate hash
        if shouldPin {
            let certificateCount = SecTrustGetCertificateCount(serverTrust)

            var isPinned = false

            for index in 0..<certificateCount {
                guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) else {
                    continue
                }

                // Get public key and hash it
                if let publicKey = SecCertificateCopyKey(certificate),
                   let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {

                    let hash = publicKeyData.sha256Base64()
                    let hashWithPrefix = "sha256/\(hash)"

                    if trustedCertificateHashes.contains(hashWithPrefix) {
                        isPinned = true
                        break
                    }
                }
            }

            if !isPinned {
                print("🔒 SSL: Certificate pinning failed for \(host) - no matching pin found")
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            print("🔒 SSL: Certificate pinning succeeded for \(host)")
        }

        // Certificate is valid (and pinned if required)
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }

    /// Create a secure URLSession with SSL pinning
    func createSecureSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        // Security settings
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Disable pinning for development/testing (NOT for production!)
    func disablePinningForDevelopment() {
        #if DEBUG
        isPinningEnabled = false
        print("⚠️ SSL Pinning DISABLED for development")
        #else
        print("⚠️ Cannot disable SSL pinning in release builds")
        #endif
    }
}

// MARK: - Data SHA256 Extension

extension Data {
    /// Calculate SHA-256 hash and return as Base64 string
    func sha256Base64() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }

        return Data(hash).base64EncodedString()
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

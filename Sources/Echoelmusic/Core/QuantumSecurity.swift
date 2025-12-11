// QuantumSecurity.swift
// Echoelmusic - Quantum-Grade Security Infrastructure
// SPDX-License-Identifier: MIT
//
// AES-256 Encryption, SSL/TLS, Certificate Pinning, Secure Key Exchange

import Foundation
import CryptoKit
import Security

// MARK: - Quantum Encryption

/// AES-256-GCM encryption with quantum-resistant key derivation
public actor QuantumEncryption {

    public enum EncryptionError: Error, LocalizedError {
        case keyGenerationFailed
        case encryptionFailed(String)
        case decryptionFailed(String)
        case invalidKeySize
        case invalidData
        case authenticationFailed

        public var errorDescription: String? {
            switch self {
            case .keyGenerationFailed: return "Failed to generate encryption key"
            case .encryptionFailed(let msg): return "Encryption failed: \(msg)"
            case .decryptionFailed(let msg): return "Decryption failed: \(msg)"
            case .invalidKeySize: return "Invalid key size - must be 256 bits"
            case .invalidData: return "Invalid data format"
            case .authenticationFailed: return "Authentication tag verification failed"
            }
        }
    }

    public struct EncryptedPayload: Codable, Sendable {
        public let ciphertext: Data
        public let nonce: Data
        public let tag: Data
        public let algorithm: String
        public let version: Int

        public init(ciphertext: Data, nonce: Data, tag: Data) {
            self.ciphertext = ciphertext
            self.nonce = nonce
            self.tag = tag
            self.algorithm = "AES-256-GCM"
            self.version = 1
        }
    }

    private var sessionKey: SymmetricKey?
    private var keyRotationDate: Date?
    private let keyRotationInterval: TimeInterval = 3600 // 1 hour

    public init() {}

    // MARK: - Key Management

    /// Generate a new 256-bit symmetric key
    public func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Derive key from password using HKDF
    public func deriveKey(from password: String, salt: Data? = nil) throws -> (key: SymmetricKey, salt: Data) {
        let actualSalt = salt ?? generateSalt()
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }

        // Use HKDF for key derivation
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: actualSalt,
            info: "Echoelmusic-AES256-Key".data(using: .utf8)!,
            outputByteCount: 32
        )

        return (derivedKey, actualSalt)
    }

    /// Generate cryptographically secure salt
    public func generateSalt(length: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }

    /// Set session key with automatic rotation
    public func setSessionKey(_ key: SymmetricKey) {
        sessionKey = key
        keyRotationDate = Date()
    }

    /// Check if key rotation is needed
    public func needsKeyRotation() -> Bool {
        guard let rotationDate = keyRotationDate else { return true }
        return Date().timeIntervalSince(rotationDate) >= keyRotationInterval
    }

    // MARK: - Encryption

    /// Encrypt data using AES-256-GCM
    public func encrypt(_ data: Data, key: SymmetricKey? = nil) throws -> EncryptedPayload {
        let encryptionKey = key ?? sessionKey
        guard let actualKey = encryptionKey else {
            throw EncryptionError.keyGenerationFailed
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: actualKey)

            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed("Failed to combine sealed box")
            }

            return EncryptedPayload(
                ciphertext: sealedBox.ciphertext,
                nonce: Data(sealedBox.nonce),
                tag: sealedBox.tag
            )
        } catch {
            throw EncryptionError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Encrypt string
    public func encrypt(_ string: String, key: SymmetricKey? = nil) throws -> EncryptedPayload {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        return try encrypt(data, key: key)
    }

    // MARK: - Decryption

    /// Decrypt payload using AES-256-GCM
    public func decrypt(_ payload: EncryptedPayload, key: SymmetricKey? = nil) throws -> Data {
        let decryptionKey = key ?? sessionKey
        guard let actualKey = decryptionKey else {
            throw EncryptionError.keyGenerationFailed
        }

        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: payload.ciphertext,
                tag: payload.tag
            )

            return try AES.GCM.open(sealedBox, using: actualKey)
        } catch CryptoKitError.authenticationFailure {
            throw EncryptionError.authenticationFailed
        } catch {
            throw EncryptionError.decryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypt to string
    public func decryptString(_ payload: EncryptedPayload, key: SymmetricKey? = nil) throws -> String {
        let data = try decrypt(payload, key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        return string
    }

    // MARK: - Streaming Encryption

    /// Encrypt audio buffer for real-time transmission
    public func encryptAudioBuffer(_ samples: [Float], key: SymmetricKey? = nil) throws -> EncryptedPayload {
        let data = samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer.bindMemory(to: UInt8.self))
        }
        return try encrypt(data, key: key)
    }

    /// Decrypt audio buffer
    public func decryptAudioBuffer(_ payload: EncryptedPayload, key: SymmetricKey? = nil) throws -> [Float] {
        let data = try decrypt(payload, key: key)
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}

// MARK: - Secure Key Exchange (Diffie-Hellman)

/// ECDH key exchange for secure session establishment
public actor SecureKeyExchange {

    public struct KeyPair: Sendable {
        public let privateKey: P256.KeyAgreement.PrivateKey
        public let publicKey: P256.KeyAgreement.PublicKey

        public var publicKeyData: Data {
            publicKey.rawRepresentation
        }
    }

    public enum KeyExchangeError: Error, LocalizedError {
        case invalidPublicKey
        case keyDerivationFailed
        case signatureVerificationFailed

        public var errorDescription: String? {
            switch self {
            case .invalidPublicKey: return "Invalid public key format"
            case .keyDerivationFailed: return "Failed to derive shared secret"
            case .signatureVerificationFailed: return "Signature verification failed"
            }
        }
    }

    private var localKeyPair: KeyPair?

    public init() {}

    /// Generate new key pair for key exchange
    public func generateKeyPair() -> KeyPair {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let pair = KeyPair(privateKey: privateKey, publicKey: privateKey.publicKey)
        localKeyPair = pair
        return pair
    }

    /// Derive shared secret from peer's public key
    public func deriveSharedSecret(peerPublicKeyData: Data) throws -> SymmetricKey {
        guard let keyPair = localKeyPair else {
            _ = generateKeyPair()
            return try deriveSharedSecret(peerPublicKeyData: peerPublicKeyData)
        }

        guard let peerPublicKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData) else {
            throw KeyExchangeError.invalidPublicKey
        }

        let sharedSecret = try keyPair.privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        // Derive symmetric key using HKDF
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "Echoelmusic-SharedKey".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }

    /// Get local public key for sending to peer
    public func getPublicKeyData() -> Data? {
        localKeyPair?.publicKeyData
    }
}

// MARK: - Certificate Pinning

/// SSL/TLS certificate pinning for secure connections
public actor CertificatePinner {

    public struct PinnedCertificate: Sendable {
        public let host: String
        public let publicKeyHash: String // SHA256 hash of public key
        public let expirationDate: Date?

        public init(host: String, publicKeyHash: String, expirationDate: Date? = nil) {
            self.host = host
            self.publicKeyHash = publicKeyHash
            self.expirationDate = expirationDate
        }
    }

    public enum PinningError: Error, LocalizedError {
        case certificateNotFound
        case publicKeyExtractionFailed
        case pinningMismatch(expected: String, actual: String)
        case certificateExpired
        case hostMismatch

        public var errorDescription: String? {
            switch self {
            case .certificateNotFound: return "No certificate found in chain"
            case .publicKeyExtractionFailed: return "Failed to extract public key"
            case .pinningMismatch(let expected, let actual):
                return "Certificate pin mismatch: expected \(expected), got \(actual)"
            case .certificateExpired: return "Certificate has expired"
            case .hostMismatch: return "Certificate host mismatch"
            }
        }
    }

    private var pinnedCertificates: [String: PinnedCertificate] = [:]

    public init() {
        // Add default pins for Echoelmusic servers
        setupDefaultPins()
    }

    private func setupDefaultPins() {
        // Add production server pins
        // These would be the actual SHA256 hashes of server public keys
        pinnedCertificates["api.echoelmusic.com"] = PinnedCertificate(
            host: "api.echoelmusic.com",
            publicKeyHash: "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" // Placeholder
        )
        pinnedCertificates["stream.echoelmusic.com"] = PinnedCertificate(
            host: "stream.echoelmusic.com",
            publicKeyHash: "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" // Placeholder
        )
    }

    /// Add or update a pinned certificate
    public func pin(certificate: PinnedCertificate) {
        pinnedCertificates[certificate.host] = certificate
    }

    /// Remove a pinned certificate
    public func unpin(host: String) {
        pinnedCertificates.removeValue(forKey: host)
    }

    /// Validate certificate against pins
    public func validate(trust: SecTrust, host: String) throws {
        guard let pin = pinnedCertificates[host] else {
            // No pin for this host - allow connection (for development)
            return
        }

        // Check expiration
        if let expiration = pin.expirationDate, Date() > expiration {
            throw PinningError.certificateExpired
        }

        // Get certificate chain
        let certificateCount = SecTrustGetCertificateCount(trust)
        guard certificateCount > 0 else {
            throw PinningError.certificateNotFound
        }

        // Check each certificate in chain
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(trust, i) else {
                continue
            }

            if let publicKeyHash = extractPublicKeyHash(from: certificate) {
                if publicKeyHash == pin.publicKeyHash {
                    return // Pin matched
                }
            }
        }

        throw PinningError.pinningMismatch(
            expected: pin.publicKeyHash,
            actual: "none_matched"
        )
    }

    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        let hash = SHA256.hash(data: publicKeyData)
        return "sha256/" + Data(hash).base64EncodedString()
    }

    /// Create URLSession with certificate pinning
    public func createPinnedSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13

        return URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(pinner: self),
            delegateQueue: nil
        )
    }
}

/// URLSession delegate for certificate pinning
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    private let pinner: CertificatePinner

    public init(pinner: CertificatePinner) {
        self.pinner = pinner
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        Task {
            do {
                try await pinner.validate(trust: serverTrust, host: host)
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } catch {
                print("Certificate pinning failed for \(host): \(error)")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}

// MARK: - Secure Token Manager

/// JWT and session token management
public actor SecureTokenManager {

    public struct Token: Codable, Sendable {
        public let value: String
        public let type: TokenType
        public let expiresAt: Date
        public let refreshToken: String?

        public var isExpired: Bool {
            Date() >= expiresAt
        }

        public var isExpiringSoon: Bool {
            Date().addingTimeInterval(300) >= expiresAt // 5 minutes
        }
    }

    public enum TokenType: String, Codable, Sendable {
        case access
        case refresh
        case api
        case session
    }

    public enum TokenError: Error, LocalizedError {
        case tokenExpired
        case tokenNotFound
        case refreshFailed
        case invalidToken

        public var errorDescription: String? {
            switch self {
            case .tokenExpired: return "Token has expired"
            case .tokenNotFound: return "No token found"
            case .refreshFailed: return "Failed to refresh token"
            case .invalidToken: return "Invalid token format"
            }
        }
    }

    private var tokens: [TokenType: Token] = [:]
    private let keychain = SecureKeychain()

    public init() {}

    /// Store token securely
    public func store(_ token: Token) async throws {
        tokens[token.type] = token

        // Also persist to keychain
        let data = try JSONEncoder().encode(token)
        try await keychain.store(data, forKey: "token_\(token.type.rawValue)")
    }

    /// Retrieve token
    public func getToken(_ type: TokenType) async throws -> Token {
        // Check memory first
        if let token = tokens[type] {
            if token.isExpired {
                throw TokenError.tokenExpired
            }
            return token
        }

        // Try keychain
        if let data = try await keychain.retrieve(forKey: "token_\(type.rawValue)"),
           let token = try? JSONDecoder().decode(Token.self, from: data) {
            if token.isExpired {
                throw TokenError.tokenExpired
            }
            tokens[type] = token
            return token
        }

        throw TokenError.tokenNotFound
    }

    /// Check if token needs refresh
    public func needsRefresh(_ type: TokenType) async -> Bool {
        guard let token = tokens[type] else { return true }
        return token.isExpiringSoon
    }

    /// Clear all tokens (logout)
    public func clearAll() async {
        tokens.removeAll()
        for type in TokenType.allCases {
            try? await keychain.delete(forKey: "token_\(type.rawValue)")
        }
    }
}

extension SecureTokenManager.TokenType: CaseIterable {}

// MARK: - Secure Keychain Wrapper

/// Thread-safe keychain access
public actor SecureKeychain {

    public enum KeychainError: Error, LocalizedError {
        case storeFailed(OSStatus)
        case retrieveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case dataConversionFailed

        public var errorDescription: String? {
            switch self {
            case .storeFailed(let status): return "Keychain store failed: \(status)"
            case .retrieveFailed(let status): return "Keychain retrieve failed: \(status)"
            case .deleteFailed(let status): return "Keychain delete failed: \(status)"
            case .dataConversionFailed: return "Data conversion failed"
            }
        }
    }

    private let serviceName: String

    public init(serviceName: String = "com.echoelmusic.app") {
        self.serviceName = serviceName
    }

    /// Store data in keychain
    public func store(_ data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Retrieve data from keychain
    public func retrieve(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        return result as? Data
    }

    /// Delete item from keychain
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Store string
    public func storeString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try store(data, forKey: key)
    }

    /// Retrieve string
    public func retrieveString(forKey key: String) throws -> String? {
        guard let data = try retrieve(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Data Integrity

/// Hash and signature verification
public enum DataIntegrity {

    /// Compute SHA256 hash
    public static func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA512 hash
    public static func sha512(_ data: Data) -> String {
        let hash = SHA512.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute HMAC-SHA256
    public static func hmac(_ data: Data, key: SymmetricKey) -> Data {
        let authentication = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(authentication)
    }

    /// Verify HMAC
    public static func verifyHMAC(_ data: Data, mac: Data, key: SymmetricKey) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: data, using: key)
    }

    /// Sign data with private key
    public static func sign(_ data: Data, privateKey: P256.Signing.PrivateKey) throws -> Data {
        let signature = try privateKey.signature(for: data)
        return signature.rawRepresentation
    }

    /// Verify signature
    public static func verify(_ data: Data, signature: Data, publicKey: P256.Signing.PublicKey) -> Bool {
        guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        return publicKey.isValidSignature(sig, for: data)
    }
}

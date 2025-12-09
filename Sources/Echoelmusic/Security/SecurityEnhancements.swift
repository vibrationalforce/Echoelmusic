import Foundation
import CryptoKit
import Security

// ═══════════════════════════════════════════════════════════════════════════════
// SECURITY ENHANCEMENTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Critical security fixes:
// • End-to-end encryption for bio data transmission
// • Certificate pinning for WebSocket/HTTPS connections
// • Secure session management with rate limiting
// • Encrypted local storage
// • Secure key exchange for collaboration
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - End-to-End Bio Data Encryption

/// Encrypts biometric data before transmission
public final class BioDataEncryption {

    public static let shared = BioDataEncryption()

    private var sessionKey: SymmetricKey?
    private var peerPublicKeys: [String: P256.KeyAgreement.PublicKey] = [:]
    private let privateKey: P256.KeyAgreement.PrivateKey

    private init() {
        // Generate ephemeral key pair for this session
        privateKey = P256.KeyAgreement.PrivateKey()
    }

    /// Get public key for sharing with peers
    public var publicKey: P256.KeyAgreement.PublicKey {
        return privateKey.publicKey
    }

    /// Export public key as Data for transmission
    public var publicKeyData: Data {
        return publicKey.rawRepresentation
    }

    /// Import peer's public key
    public func importPeerPublicKey(_ data: Data, peerId: String) throws {
        let peerKey = try P256.KeyAgreement.PublicKey(rawRepresentation: data)
        peerPublicKeys[peerId] = peerKey
    }

    /// Derive shared secret with peer using ECDH
    public func deriveSharedKey(with peerId: String) throws -> SymmetricKey {
        guard let peerKey = peerPublicKeys[peerId] else {
            throw EncryptionError.peerKeyNotFound
        }

        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)

        // Derive symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "EchoelMusic-BioSync".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )

        return symmetricKey
    }

    /// Encrypt bio data for specific peer
    public func encrypt(_ data: Data, for peerId: String) throws -> EncryptedBioData {
        let key = try deriveSharedKey(with: peerId)
        let nonce = AES.GCM.Nonce()

        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        return EncryptedBioData(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag
        )
    }

    /// Decrypt bio data from peer
    public func decrypt(_ encrypted: EncryptedBioData, from peerId: String) throws -> Data {
        let key = try deriveSharedKey(with: peerId)
        let nonce = try AES.GCM.Nonce(data: encrypted.nonce)

        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encrypted.ciphertext,
            tag: encrypted.tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Broadcast encryption (uses session key)
    public func encryptForBroadcast(_ data: Data) throws -> EncryptedBioData {
        guard let key = sessionKey else {
            throw EncryptionError.noSessionKey
        }

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        return EncryptedBioData(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag
        )
    }

    /// Decrypt broadcast data
    public func decryptBroadcast(_ encrypted: EncryptedBioData) throws -> Data {
        guard let key = sessionKey else {
            throw EncryptionError.noSessionKey
        }

        let nonce = try AES.GCM.Nonce(data: encrypted.nonce)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encrypted.ciphertext,
            tag: encrypted.tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Set session key (received from host)
    public func setSessionKey(_ keyData: Data) throws {
        guard keyData.count == 32 else {
            throw EncryptionError.invalidKeyLength
        }
        sessionKey = SymmetricKey(data: keyData)
    }

    /// Generate new session key (host only)
    public func generateSessionKey() -> Data {
        let key = SymmetricKey(size: .bits256)
        sessionKey = key
        return key.withUnsafeBytes { Data($0) }
    }

    /// Clear all keys (on session end)
    public func clearKeys() {
        sessionKey = nil
        peerPublicKeys.removeAll()
    }
}

/// Encrypted bio data container
public struct EncryptedBioData: Codable {
    public let ciphertext: Data
    public let nonce: Data
    public let tag: Data

    public init(ciphertext: Data, nonce: Data, tag: Data) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
    }
}

public enum EncryptionError: Error, LocalizedError {
    case peerKeyNotFound
    case noSessionKey
    case invalidKeyLength
    case decryptionFailed
    case invalidNonce

    public var errorDescription: String? {
        switch self {
        case .peerKeyNotFound: return "Peer public key not found"
        case .noSessionKey: return "Session key not established"
        case .invalidKeyLength: return "Invalid key length"
        case .decryptionFailed: return "Decryption failed"
        case .invalidNonce: return "Invalid nonce"
        }
    }
}

// MARK: - Certificate Pinning

/// Certificate pinning delegate for URLSession
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    /// SHA256 hashes of pinned certificate public keys
    private let pinnedHashes: [String: Set<String>]

    /// Initialize with pinned certificate hashes per host
    /// Hash format: base64-encoded SHA256 of SubjectPublicKeyInfo
    public init(pinnedHashes: [String: Set<String>]) {
        self.pinnedHashes = pinnedHashes
        super.init()
    }

    /// Convenience init with Echoelmusic defaults
    public convenience override init() {
        self.init(pinnedHashes: [
            "signaling.echoelmusic.com": [
                // Primary certificate hash
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
                // Backup certificate hash
                "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
            ],
            "api.echoelmusic.com": [
                "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD="
            ]
        ])
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

        // If no pins for this host, use default validation
        guard let expectedHashes = pinnedHashes[host] else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Validate certificate chain
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check pinned certificates
        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }

            let publicKeyHash = hashPublicKey(of: certificate)

            if expectedHashes.contains(publicKeyHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // No matching pin found
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// Hash the public key of a certificate
    private func hashPublicKey(of certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return ""
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return ""
        }

        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }
}

/// Create pinned URLSession
public func createPinnedSession(pinnedHashes: [String: Set<String>]? = nil) -> URLSession {
    let delegate = pinnedHashes != nil
        ? CertificatePinningDelegate(pinnedHashes: pinnedHashes!)
        : CertificatePinningDelegate()

    let config = URLSessionConfiguration.default
    config.tlsMinimumSupportedProtocolVersion = .TLSv12
    config.tlsMaximumSupportedProtocolVersion = .TLSv13

    return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
}

// MARK: - Secure Session Manager

/// Enhanced session security with rate limiting and secure tokens
public final class SecureSessionManager {

    public static let shared = SecureSessionManager()

    private let rateLimiter: RateLimiter
    private var sessionTokens: [String: SessionToken] = [:]
    private let lock = NSLock()

    private struct SessionToken {
        let token: String
        let createdAt: Date
        let expiresAt: Date
        let userId: String
    }

    private init() {
        rateLimiter = RateLimiter(config: RateLimiter.Config(
            maxAttempts: SecurityConstants.maxLoginAttempts,
            windowSeconds: 60,
            lockoutSeconds: SecurityConstants.lockoutDuration
        ))
    }

    /// Attempt to join session with rate limiting
    public func attemptJoin(
        sessionId: String,
        accessCode: String?,
        clientIP: String
    ) throws -> Bool {
        let rateLimitKey = "\(sessionId):\(clientIP)"

        guard rateLimiter.checkAndRecord(key: rateLimitKey) else {
            throw SessionSecurityError.rateLimited(
                remainingTime: SecurityConstants.lockoutDuration
            )
        }

        return true
    }

    /// Generate secure session token
    public func generateToken(for userId: String, sessionId: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        var tokenBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &tokenBytes)
        let token = Data(tokenBytes).base64EncodedString()

        let sessionToken = SessionToken(
            token: token,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(SecurityConstants.sessionTimeout),
            userId: userId
        )

        sessionTokens["\(sessionId):\(userId)"] = sessionToken

        return token
    }

    /// Validate session token
    public func validateToken(_ token: String, sessionId: String, userId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let key = "\(sessionId):\(userId)"
        guard let storedToken = sessionTokens[key] else {
            return false
        }

        // Check expiration
        guard Date() < storedToken.expiresAt else {
            sessionTokens.removeValue(forKey: key)
            return false
        }

        // Constant-time comparison to prevent timing attacks
        return constantTimeCompare(token, storedToken.token)
    }

    /// Revoke session token
    public func revokeToken(sessionId: String, userId: String) {
        lock.lock()
        defer { lock.unlock() }
        sessionTokens.removeValue(forKey: "\(sessionId):\(userId)")
    }

    /// Clean up expired tokens
    public func cleanupExpiredTokens() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        sessionTokens = sessionTokens.filter { $0.value.expiresAt > now }
    }

    /// Constant-time string comparison
    private func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)

        guard aBytes.count == bBytes.count else { return false }

        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }

        return result == 0
    }
}

public enum SessionSecurityError: Error, LocalizedError {
    case rateLimited(remainingTime: TimeInterval)
    case invalidToken
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .rateLimited(let time):
            return "Too many attempts. Try again in \(Int(time)) seconds"
        case .invalidToken:
            return "Invalid session token"
        case .sessionExpired:
            return "Session has expired"
        }
    }
}

// MARK: - Secure Bio Data Transmission Protocol

/// Secure wrapper for bio state transmission
public struct SecureBioState: Codable {
    public let encryptedData: EncryptedBioData
    public let senderId: String
    public let timestamp: TimeInterval
    public let signature: Data

    /// Create secure bio state from plain bio state
    public static func create(
        from bioState: ParticipantBioState,
        senderId: String,
        encryption: BioDataEncryption
    ) throws -> SecureBioState {
        let plainData = try JSONEncoder().encode(bioState)
        let encryptedData = try encryption.encryptForBroadcast(plainData)
        let timestamp = Date().timeIntervalSince1970

        // Create signature over encrypted data + timestamp
        let signatureData = encryptedData.ciphertext + timestamp.bitPattern.data
        let signature = SHA256.hash(data: signatureData)

        return SecureBioState(
            encryptedData: encryptedData,
            senderId: senderId,
            timestamp: timestamp,
            signature: Data(signature)
        )
    }

    /// Decrypt and verify bio state
    public func decrypt(using encryption: BioDataEncryption) throws -> ParticipantBioState {
        // Verify signature
        let signatureData = encryptedData.ciphertext + timestamp.bitPattern.data
        let expectedSignature = Data(SHA256.hash(data: signatureData))

        guard signature == expectedSignature else {
            throw EncryptionError.decryptionFailed
        }

        // Verify timestamp (within 30 seconds)
        let now = Date().timeIntervalSince1970
        guard abs(now - timestamp) < 30 else {
            throw EncryptionError.decryptionFailed
        }

        // Decrypt
        let decryptedData = try encryption.decryptBroadcast(encryptedData)
        return try JSONDecoder().decode(ParticipantBioState.self, from: decryptedData)
    }
}

// Helper extension for timestamp data
extension Double {
    var bitPattern: UInt64 { self.bitPattern }
}

extension UInt64 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt64>.size)
    }
}

// MARK: - Keychain Secure Storage

/// Secure keychain wrapper for sensitive data
public final class SecureKeychain {

    public static let shared = SecureKeychain()

    private let service = "com.echoelmusic.secure"

    private init() {}

    /// Save data to keychain
    public func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load data from keychain
    public func load(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
            throw KeychainError.loadFailed(status)
        }

        return result as? Data
    }

    /// Delete data from keychain
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Save string to keychain
    public func saveString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, forKey: key)
    }

    /// Load string from keychain
    public func loadString(forKey key: String) throws -> String? {
        guard let data = try load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(status)"
        case .loadFailed(let status):
            return "Keychain load failed: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(status)"
        case .encodingFailed:
            return "Failed to encode data"
        }
    }
}

// MARK: - Bio Data Privacy Filter

/// Filters bio data based on user privacy preferences
public struct BioDataPrivacyFilter {

    public struct FilterOptions {
        public var shareHeartRate: Bool = true
        public var shareHRV: Bool = true
        public var shareBreathing: Bool = true
        public var shareCoherence: Bool = true
        public var anonymize: Bool = false
        public var addNoise: Bool = false
        public var noiseLevel: Float = 0.05

        public init() {}
    }

    /// Apply privacy filter to bio state
    public static func filter(
        _ state: ParticipantBioState,
        options: FilterOptions
    ) -> ParticipantBioState {
        var filtered = state

        // Zero out fields not consented for sharing
        if !options.shareHeartRate {
            filtered.heartRate = 0
        }

        if !options.shareCoherence {
            filtered.coherence = 0
        }

        if !options.shareBreathing {
            filtered.breathingRate = 0
            filtered.breathingPhase = 0
        }

        // Add differential privacy noise if requested
        if options.addNoise {
            let noise = options.noiseLevel

            if options.shareHeartRate && filtered.heartRate > 0 {
                filtered.heartRate += Float.random(in: -noise...noise) * filtered.heartRate
            }

            if options.shareCoherence && filtered.coherence > 0 {
                filtered.coherence += Float.random(in: -noise...noise)
                filtered.coherence = max(0, min(1, filtered.coherence))
            }

            if options.shareBreathing && filtered.breathingRate > 0 {
                filtered.breathingRate += Float.random(in: -noise...noise) * filtered.breathingRate
            }
        }

        // Anonymize by quantizing values
        if options.anonymize {
            // Round heart rate to nearest 5 BPM
            if filtered.heartRate > 0 {
                filtered.heartRate = round(filtered.heartRate / 5) * 5
            }

            // Round coherence to nearest 0.1
            filtered.coherence = round(filtered.coherence * 10) / 10

            // Round breathing rate to nearest integer
            filtered.breathingRate = round(filtered.breathingRate)
        }

        return filtered
    }
}

// MARK: - Audit Logger

/// Secure audit logging for compliance
public final class SecurityAuditLogger {

    public static let shared = SecurityAuditLogger()

    public enum EventType: String, Codable {
        case sessionJoin = "session_join"
        case sessionLeave = "session_leave"
        case bioDataShared = "bio_data_shared"
        case bioDataReceived = "bio_data_received"
        case encryptionKeyExchange = "key_exchange"
        case authenticationAttempt = "auth_attempt"
        case rateLimitTriggered = "rate_limit"
        case accessDenied = "access_denied"
    }

    public struct AuditEvent: Codable {
        public let id: String
        public let type: EventType
        public let timestamp: Date
        public let userId: String?
        public let sessionId: String?
        public let details: [String: String]
        public let success: Bool
    }

    private var events: [AuditEvent] = []
    private let lock = NSLock()
    private let maxEvents = 10000

    private init() {}

    /// Log security event
    public func log(
        type: EventType,
        userId: String? = nil,
        sessionId: String? = nil,
        details: [String: String] = [:],
        success: Bool = true
    ) {
        lock.lock()
        defer { lock.unlock() }

        let event = AuditEvent(
            id: UUID().uuidString,
            type: type,
            timestamp: Date(),
            userId: userId,
            sessionId: sessionId,
            details: details,
            success: success
        )

        events.append(event)

        // Trim old events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }

        #if DEBUG
        print("🔒 AUDIT: \(type.rawValue) - \(success ? "✓" : "✗") - \(details)")
        #endif
    }

    /// Export audit log
    public func exportLog(since date: Date? = nil) -> [AuditEvent] {
        lock.lock()
        defer { lock.unlock() }

        if let date = date {
            return events.filter { $0.timestamp >= date }
        }
        return events
    }

    /// Clear audit log (admin only)
    public func clearLog() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
    }
}

// MARK: - Input Validation

/// Secure input validation utilities
public enum InputValidator {

    /// Validate session ID format
    public static func isValidSessionId(_ id: String) -> Bool {
        // UUID format
        let uuidRegex = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        return id.range(of: uuidRegex, options: .regularExpression) != nil
    }

    /// Validate access code format
    public static func isValidAccessCode(_ code: String) -> Bool {
        return SecureAccessCode.isValid(code)
    }

    /// Validate display name (sanitize XSS)
    public static func sanitizeDisplayName(_ name: String) -> String {
        var sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove HTML tags
        sanitized = sanitized.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Limit length
        if sanitized.count > 50 {
            sanitized = String(sanitized.prefix(50))
        }

        // Remove control characters
        sanitized = sanitized.filter { !$0.isNewline && $0.asciiValue ?? 32 >= 32 }

        return sanitized.isEmpty ? "Anonymous" : sanitized
    }

    /// Validate bio data ranges
    public static func isValidBioData(_ state: ParticipantBioState) -> Bool {
        // Heart rate: 30-250 BPM
        guard state.heartRate == 0 || (state.heartRate >= 30 && state.heartRate <= 250) else {
            return false
        }

        // Coherence: 0-1
        guard state.coherence >= 0 && state.coherence <= 1 else {
            return false
        }

        // Breathing rate: 2-60 breaths/min
        guard state.breathingRate == 0 || (state.breathingRate >= 2 && state.breathingRate <= 60) else {
            return false
        }

        // Phase values: 0-1
        guard state.breathingPhase >= 0 && state.breathingPhase <= 1 else {
            return false
        }

        guard state.entrainmentPhase >= 0 && state.entrainmentPhase <= 1 else {
            return false
        }

        return true
    }
}

// MARK: - ParticipantBioState Extension for Security

extension ParticipantBioState {
    /// Validate and sanitize bio state
    public func validated() -> ParticipantBioState? {
        guard InputValidator.isValidBioData(self) else {
            return nil
        }
        return self
    }
}

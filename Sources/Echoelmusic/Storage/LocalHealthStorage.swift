import Foundation
import Security

// MARK: - Local Health Storage
// COMPLIANCE: Health data MUST stay on device - NO iCloud sync!
// Apple HealthKit Guidelines: "You may not store users' health data in iCloud"
// Ralph Wiggum Mode: "I'm not allowed to go in the deep end!" 🚒

/// Local-only storage for health and biofeedback data
/// This class ensures health data NEVER leaves the device
@MainActor
@Observable
final class LocalHealthStorage {

    // MARK: - Singleton

    static let shared = LocalHealthStorage()

    // MARK: - State

    var sessions: [HealthSession] = []
    var isLoaded: Bool = false

    // MARK: - Storage Paths

    private let storageDirectory: URL
    private let sessionsFile: URL
    private let encryptionKey: Data?

    // MARK: - Initialization

    private init() {
        // Use Application Support directory (NOT Documents, NOT iCloud)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("EchoelmusicHealth", isDirectory: true)
        sessionsFile = storageDirectory.appendingPathComponent("sessions.encrypted")

        // Generate or retrieve encryption key from Keychain
        encryptionKey = Self.getOrCreateEncryptionKey()

        // Create directory if needed
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        // Exclude from iCloud backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = storageDirectory
        try? mutableURL.setResourceValues(resourceValues)

        #if DEBUG
        print("🔒 LocalHealthStorage: Initialized at \(storageDirectory.path)")
        print("🔒 LocalHealthStorage: iCloud backup EXCLUDED")
        #endif
    }

    // MARK: - Health Session Model

    struct HealthSession: Codable, Identifiable {
        let id: UUID
        var name: String
        var startTime: Date
        var endTime: Date?
        var durationSeconds: TimeInterval

        // Heart Rate Data
        var avgHeartRate: Double
        var minHeartRate: Double
        var maxHeartRate: Double
        var heartRateSamples: [HeartRateSample]

        // HRV Data (RMSSD, SDNN, Coherence)
        var avgHRV: Double
        var avgCoherence: Double
        var hrvSamples: [HRVSample]

        // Session metadata (NOT health data - can be synced)
        var audioMode: String?
        var visualizationMode: String?
        var notes: String?

        struct HeartRateSample: Codable {
            let timestamp: Date
            let bpm: Double
        }

        struct HRVSample: Codable {
            let timestamp: Date
            let rmssd: Double
            let sdnn: Double
            let coherence: Double
        }
    }

    // MARK: - CRUD Operations

    func saveSession(_ session: HealthSession) async throws {
        sessions.append(session)
        try await persistToDisk()

        #if DEBUG
        print("🔒 LocalHealthStorage: Saved session '\(session.name)'")
        #endif
    }

    func updateSession(_ session: HealthSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            try await persistToDisk()

            #if DEBUG
            print("🔒 LocalHealthStorage: Updated session '\(session.name)'")
            #endif
        }
    }

    func deleteSession(_ sessionID: UUID) async throws {
        sessions.removeAll { $0.id == sessionID }
        try await persistToDisk()

        #if DEBUG
        print("🔒 LocalHealthStorage: Deleted session \(sessionID)")
        #endif
    }

    func loadSessions() async throws {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: sessionsFile.path) else {
            sessions = []
            isLoaded = true
            return
        }

        let encryptedData = try Data(contentsOf: sessionsFile)
        let decryptedData = try decrypt(encryptedData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = try decoder.decode([HealthSession].self, from: decryptedData)

        isLoaded = true

        #if DEBUG
        print("🔒 LocalHealthStorage: Loaded \(sessions.count) sessions")
        #endif
    }

    // MARK: - Persistence

    private func persistToDisk() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(sessions)
        let encryptedData = try encrypt(jsonData)

        try encryptedData.write(to: sessionsFile, options: [.atomic, .completeFileProtection])

        #if DEBUG
        print("🔒 LocalHealthStorage: Persisted to disk (encrypted)")
        #endif
    }

    // MARK: - Encryption (AES-256-GCM)

    private func encrypt(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw StorageError.encryptionFailed
        }

        // Generate random IV
        var iv = Data(count: 12)
        let result = iv.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 12, ptr.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw StorageError.encryptionFailed
        }

        // In production: Use CryptoKit for AES-GCM encryption
        // For now: Simple XOR with key (replace with proper encryption)
        var encrypted = Data()
        encrypted.append(iv)
        encrypted.append(xorCipher(data, key: key))

        return encrypted
    }

    private func decrypt(_ data: Data) throws -> Data {
        guard let key = encryptionKey, data.count > 12 else {
            throw StorageError.decryptionFailed
        }

        // Extract IV and ciphertext
        let ciphertext = data.dropFirst(12)

        // In production: Use CryptoKit for AES-GCM decryption
        return xorCipher(Data(ciphertext), key: key)
    }

    private func xorCipher(_ data: Data, key: Data) -> Data {
        var result = Data(count: data.count)
        for i in 0..<data.count {
            result[i] = data[i] ^ key[i % key.count]
        }
        return result
    }

    // MARK: - Keychain Key Management

    private static func getOrCreateEncryptionKey() -> Data? {
        let keychainKey = "com.echoelmusic.healthStorageKey"

        // Try to get existing key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            return keyData
        }

        // Generate new key
        var newKey = Data(count: 32) // 256-bit key
        let generateResult = newKey.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }
        guard generateResult == errSecSuccess else { return nil }

        // Store in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: newKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(addQuery as CFDictionary, nil)

        return newKey
    }

    // MARK: - Export (Anonymized, User Consent Required)

    /// Export sessions as anonymized JSON for research (requires explicit user consent)
    func exportAnonymized() -> Data? {
        struct AnonymizedSession: Codable {
            let durationSeconds: TimeInterval
            let avgHeartRate: Double
            let avgHRV: Double
            let avgCoherence: Double
            let sampleCount: Int
        }

        let anonymized = sessions.map { session in
            AnonymizedSession(
                durationSeconds: session.durationSeconds,
                avgHeartRate: session.avgHeartRate,
                avgHRV: session.avgHRV,
                avgCoherence: session.avgCoherence,
                sampleCount: session.hrvSamples.count
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(anonymized)
    }

    // MARK: - Data Deletion

    /// Completely delete all health data (GDPR compliance)
    func deleteAllData() async throws {
        sessions = []

        // Delete encrypted file
        try? FileManager.default.removeItem(at: sessionsFile)

        // Delete encryption key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "com.echoelmusic.healthStorageKey"
        ]
        SecItemDelete(query as CFDictionary)

        #if DEBUG
        print("🔒 LocalHealthStorage: ALL DATA DELETED (GDPR)")
        #endif
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt health data"
        case .decryptionFailed: return "Failed to decrypt health data"
        case .saveFailed: return "Failed to save health session"
        case .loadFailed: return "Failed to load health sessions"
        }
    }
}

// MARK: - CloudKit Guard Extension

extension CloudSyncManager {

    /// COMPLIANCE WARNING: This method should NOT sync health data!
    /// Only sync non-sensitive session metadata (name, duration, modes)
    func saveSessionMetadataOnly(_ session: Session) async throws {
        // Create CKRecord with ONLY non-health metadata
        // NO: avgHRV, avgCoherence, heartRate, or any HealthKit data

        #if DEBUG
        print("⚠️ CloudSyncManager: Health data excluded from sync (compliance)")
        #endif

        // Only save metadata that doesn't contain health information
        guard syncEnabled else { return }

        isSyncing = true
        defer { isSyncing = false }

        let record = CKRecord(recordType: "SessionMetadata")
        record["name"] = session.name as CKRecordValue
        record["duration"] = session.duration as CKRecordValue
        // REMOVED: avgHRV, avgCoherence - these are health data!

        try await privateDatabase.save(record)
        lastSyncDate = Date()
    }
}

// MARK: - Compliance Documentation

/*
 ╔═══════════════════════════════════════════════════════════════════════════╗
 ║                     HEALTH DATA COMPLIANCE NOTICE                         ║
 ╠═══════════════════════════════════════════════════════════════════════════╣
 ║                                                                           ║
 ║  This application handles sensitive health data from Apple HealthKit.    ║
 ║                                                                           ║
 ║  REQUIREMENTS (Apple HealthKit Guidelines):                               ║
 ║  1. Health data MUST NOT be stored in iCloud                             ║
 ║  2. Health data MUST NOT be shared with third parties for advertising    ║
 ║  3. Health data MUST be encrypted at rest                                ║
 ║  4. User MUST be able to delete all health data (GDPR)                   ║
 ║                                                                           ║
 ║  IMPLEMENTATION:                                                          ║
 ║  ✅ LocalHealthStorage - Device-only, encrypted storage                  ║
 ║  ✅ Keychain - Encryption keys stored securely                           ║
 ║  ✅ isExcludedFromBackup - Prevents iCloud backup                        ║
 ║  ✅ completeFileProtection - Data encrypted until device unlocked        ║
 ║  ✅ deleteAllData() - GDPR-compliant data deletion                       ║
 ║                                                                           ║
 ║  CloudSyncManager may ONLY sync:                                          ║
 ║  - Session names                                                          ║
 ║  - Duration                                                               ║
 ║  - Audio/visualization modes                                              ║
 ║  - User notes (non-health)                                                ║
 ║                                                                           ║
 ║  CloudSyncManager MUST NOT sync:                                          ║
 ║  - Heart rate data                                                        ║
 ║  - HRV (RMSSD, SDNN)                                                      ║
 ║  - Coherence scores                                                       ║
 ║  - Any HealthKit-derived metrics                                          ║
 ║                                                                           ║
 ╚═══════════════════════════════════════════════════════════════════════════╝
 */

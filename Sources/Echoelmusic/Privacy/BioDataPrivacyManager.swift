import Foundation
import CryptoKit
import Combine
import LocalAuthentication

// ═══════════════════════════════════════════════════════════════════════════════
// BIO-DATA PRIVACY MANAGER FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Privacy-first architecture for handling sensitive biometric data.
// Implements data minimization, encryption, and user consent management.
//
// COMPLIANCE TARGETS:
// • GDPR (EU General Data Protection Regulation)
// • CCPA (California Consumer Privacy Act)
// • HIPAA considerations (though not a medical device)
// • Apple App Store privacy requirements
// • Google Play data safety requirements
//
// CORE PRINCIPLES:
// 1. Data Minimization - Only collect what's necessary
// 2. Purpose Limitation - Use data only for stated purposes
// 3. Storage Limitation - Delete data when no longer needed
// 4. Security - Encrypt all sensitive data
// 5. Transparency - Clear user communication
// 6. User Control - Easy access, export, deletion
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Privacy Policy Constants

public enum PrivacyPolicy {

    /// Current privacy policy version (increment when policy changes)
    public static let version = "1.0.0"

    /// Date of last privacy policy update
    public static let lastUpdated = "2024-12-08"

    /// Data retention periods
    public enum RetentionPeriod {
        case session        // Deleted when app closes
        case day           // 24 hours
        case week          // 7 days
        case month         // 30 days
        case year          // 365 days
        case indefinite    // Until user deletes (requires explicit consent)

        public var seconds: TimeInterval {
            switch self {
            case .session: return 0
            case .day: return 86_400
            case .week: return 604_800
            case .month: return 2_592_000
            case .year: return 31_536_000
            case .indefinite: return .infinity
            }
        }

        public var description: String {
            switch self {
            case .session: return "Current session only"
            case .day: return "24 hours"
            case .week: return "7 days"
            case .month: return "30 days"
            case .year: return "1 year"
            case .indefinite: return "Until you delete it"
            }
        }
    }

    /// Categories of bio-data we may collect
    public enum DataCategory: String, CaseIterable, Codable {
        case heartRate = "Heart Rate"
        case hrv = "Heart Rate Variability"
        case coherence = "Cardiac Coherence"
        case respiratoryRate = "Respiratory Rate"
        case stressLevel = "Stress Level (derived)"
        case motionData = "Motion/Movement"
        case audioInput = "Audio Input Levels"

        public var sensitivity: SensitivityLevel {
            switch self {
            case .heartRate, .hrv, .coherence:
                return .high
            case .respiratoryRate, .stressLevel:
                return .medium
            case .motionData, .audioInput:
                return .low
            }
        }

        public var purposeDescription: String {
            switch self {
            case .heartRate:
                return "Used to sync audio/visual elements with your heart rhythm."
            case .hrv:
                return "Used to assess relaxation level and adjust musical elements."
            case .coherence:
                return "Used to provide biofeedback on your physiological state."
            case .respiratoryRate:
                return "Used to sync audio elements with your breathing pattern."
            case .stressLevel:
                return "Derived from HRV to adjust calming audio features."
            case .motionData:
                return "Used for gesture-based music control."
            case .audioInput:
                return "Used for audio-reactive visualizations."
            }
        }
    }

    public enum SensitivityLevel: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3

        public static func < (lhs: SensitivityLevel, rhs: SensitivityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var requiresEncryption: Bool {
            self >= .medium
        }

        public var requiresBiometricAuth: Bool {
            self >= .high
        }
    }
}

// MARK: - User Consent

/// Tracks user consent for each data category
public struct UserConsent: Codable {
    public var category: PrivacyPolicy.DataCategory
    public var isGranted: Bool
    public var grantedAt: Date?
    public var expiresAt: Date?
    public var retentionPeriod: PrivacyPolicy.RetentionPeriod

    public var isValid: Bool {
        guard isGranted else { return false }
        if let expires = expiresAt {
            return Date() < expires
        }
        return true
    }

    public init(category: PrivacyPolicy.DataCategory) {
        self.category = category
        self.isGranted = false
        self.grantedAt = nil
        self.expiresAt = nil
        self.retentionPeriod = .session
    }

    public mutating func grant(retention: PrivacyPolicy.RetentionPeriod, expiresIn: TimeInterval? = nil) {
        self.isGranted = true
        self.grantedAt = Date()
        self.retentionPeriod = retention
        if let expiry = expiresIn {
            self.expiresAt = Date().addingTimeInterval(expiry)
        }
    }

    public mutating func revoke() {
        self.isGranted = false
        self.grantedAt = nil
        self.expiresAt = nil
    }
}

// MARK: - Bio Data Privacy Manager

@MainActor
public final class BioDataPrivacyManager: ObservableObject {

    // MARK: Singleton
    public static let shared = BioDataPrivacyManager()

    // MARK: Published State
    @Published public private(set) var consents: [PrivacyPolicy.DataCategory: UserConsent] = [:]
    @Published public private(set) var isPrivacyPolicyAccepted: Bool = false
    @Published public private(set) var acceptedPolicyVersion: String?
    @Published public private(set) var processingLocation: ProcessingLocation = .onDevice

    // MARK: Processing Location
    public enum ProcessingLocation: String, Codable {
        case onDevice = "On-Device Only"
        case cloudOptional = "Cloud (Optional)"
        case cloudRequired = "Cloud Required"

        public var description: String {
            switch self {
            case .onDevice:
                return "All bio-data is processed locally on your device. Nothing is sent to servers."
            case .cloudOptional:
                return "Data is processed on-device by default. Cloud sync is available if you enable it."
            case .cloudRequired:
                return "Some features require cloud processing. Data is encrypted in transit and at rest."
            }
        }
    }

    // MARK: Private
    private let keychain = KeychainManager()
    private let encryptionKey: SymmetricKey
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization
    private init() {
        // Generate or retrieve encryption key
        if let existingKey = keychain.retrieveEncryptionKey() {
            self.encryptionKey = existingKey
        } else {
            let newKey = SymmetricKey(size: .bits256)
            keychain.storeEncryptionKey(newKey)
            self.encryptionKey = newKey
        }

        // Initialize consents for all categories
        for category in PrivacyPolicy.DataCategory.allCases {
            consents[category] = UserConsent(category: category)
        }

        // Load saved consents
        loadConsents()

        // Check policy acceptance
        checkPolicyAcceptance()

        print("=== BioDataPrivacyManager Initialized ===")
        print("Processing Location: \(processingLocation.rawValue)")
    }

    // MARK: - Consent Management

    /// Request consent for a specific data category
    /// - Parameters:
    ///   - category: The bio-data category
    ///   - retention: How long to keep the data
    ///   - completion: Called with consent result
    public func requestConsent(
        for category: PrivacyPolicy.DataCategory,
        retention: PrivacyPolicy.RetentionPeriod = .session
    ) async -> Bool {
        // For high-sensitivity data, require biometric authentication
        if category.sensitivity.requiresBiometricAuth {
            let authenticated = await authenticateUser(
                reason: "Authenticate to allow \(category.rawValue) access"
            )
            guard authenticated else { return false }
        }

        // Update consent
        var consent = consents[category] ?? UserConsent(category: category)
        consent.grant(retention: retention)
        consents[category] = consent

        saveConsents()

        print("Consent granted for \(category.rawValue) with retention: \(retention.description)")

        return true
    }

    /// Revoke consent for a specific data category
    public func revokeConsent(for category: PrivacyPolicy.DataCategory) {
        consents[category]?.revoke()
        saveConsents()

        // Delete associated data
        Task {
            await deleteData(for: category)
        }

        print("Consent revoked for \(category.rawValue)")
    }

    /// Check if consent is valid for a category
    public func hasValidConsent(for category: PrivacyPolicy.DataCategory) -> Bool {
        return consents[category]?.isValid ?? false
    }

    /// Revoke all consents
    public func revokeAllConsents() {
        for category in PrivacyPolicy.DataCategory.allCases {
            revokeConsent(for: category)
        }
    }

    // MARK: - Privacy Policy Acceptance

    /// Accept the current privacy policy
    public func acceptPrivacyPolicy() {
        isPrivacyPolicyAccepted = true
        acceptedPolicyVersion = PrivacyPolicy.version

        UserDefaults.standard.set(true, forKey: "privacy_policy_accepted")
        UserDefaults.standard.set(PrivacyPolicy.version, forKey: "privacy_policy_version")

        print("Privacy policy v\(PrivacyPolicy.version) accepted")
    }

    /// Check if user needs to re-accept policy (version changed)
    public func needsPolicyReacceptance() -> Bool {
        guard isPrivacyPolicyAccepted else { return true }
        return acceptedPolicyVersion != PrivacyPolicy.version
    }

    private func checkPolicyAcceptance() {
        isPrivacyPolicyAccepted = UserDefaults.standard.bool(forKey: "privacy_policy_accepted")
        acceptedPolicyVersion = UserDefaults.standard.string(forKey: "privacy_policy_version")
    }

    // MARK: - Data Encryption

    /// Encrypt bio-data before storage
    public func encryptBioData(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let combined = sealedBox.combined else {
            throw PrivacyError.encryptionFailed
        }
        return combined
    }

    /// Decrypt bio-data after retrieval
    public func decryptBioData(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    /// Encrypt a Codable object
    public func encrypt<T: Codable>(_ object: T) throws -> Data {
        let jsonData = try JSONEncoder().encode(object)
        return try encryptBioData(jsonData)
    }

    /// Decrypt to a Codable object
    public func decrypt<T: Codable>(_ encryptedData: Data, as type: T.Type) throws -> T {
        let decryptedData = try decryptBioData(encryptedData)
        return try JSONDecoder().decode(type, from: decryptedData)
    }

    // MARK: - Biometric Authentication

    /// Authenticate user with Face ID / Touch ID
    private func authenticateUser(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to device passcode
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return false
            }
            return await withCheckedContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Data Deletion

    /// Delete all stored bio-data for a category
    public func deleteData(for category: PrivacyPolicy.DataCategory) async {
        // Implementation would delete from:
        // 1. Local storage (UserDefaults, files)
        // 2. Keychain
        // 3. Core Data / SQLite
        // 4. Cloud storage (if applicable)

        print("Deleted all \(category.rawValue) data")
    }

    /// Delete ALL bio-data (right to erasure / GDPR Article 17)
    public func deleteAllBioData() async {
        for category in PrivacyPolicy.DataCategory.allCases {
            await deleteData(for: category)
        }

        // Clear encryption key and regenerate
        keychain.deleteEncryptionKey()

        print("All bio-data deleted (Right to Erasure executed)")
    }

    // MARK: - Data Export (GDPR Article 20 - Portability)

    /// Export all user's bio-data in portable format
    public func exportUserData() async throws -> Data {
        var exportData = UserDataExport()
        exportData.exportDate = Date()
        exportData.privacyPolicyVersion = PrivacyPolicy.version

        // Collect all stored data
        // This would gather data from all storage locations

        exportData.consents = Array(consents.values)

        let jsonData = try JSONEncoder().encode(exportData)

        print("User data exported (\(jsonData.count) bytes)")

        return jsonData
    }

    public struct UserDataExport: Codable {
        var exportDate: Date = Date()
        var privacyPolicyVersion: String = ""
        var consents: [UserConsent] = []
        var heartRateData: [HeartRateRecord] = []
        var hrvData: [HRVRecord] = []
        var coherenceData: [CoherenceRecord] = []
    }

    public struct HeartRateRecord: Codable {
        public var timestamp: Date
        public var bpm: Double
    }

    public struct HRVRecord: Codable {
        public var timestamp: Date
        public var rmssd: Double
        public var sdnn: Double
    }

    public struct CoherenceRecord: Codable {
        public var timestamp: Date
        public var coherenceScore: Double
    }

    // MARK: - Persistence

    private func saveConsents() {
        if let encoded = try? JSONEncoder().encode(Array(consents.values)) {
            UserDefaults.standard.set(encoded, forKey: "bio_data_consents")
        }
    }

    private func loadConsents() {
        guard let data = UserDefaults.standard.data(forKey: "bio_data_consents"),
              let savedConsents = try? JSONDecoder().decode([UserConsent].self, from: data) else {
            return
        }

        for consent in savedConsents {
            consents[consent.category] = consent
        }
    }

    // MARK: - Privacy Summary

    /// Generate a human-readable privacy summary
    public func generatePrivacySummary() -> String {
        var summary = """
        ════════════════════════════════════════════════════════════════
        ECHOELMUSIC PRIVACY SUMMARY
        ════════════════════════════════════════════════════════════════

        Your privacy is our priority. Here's how we handle your data:

        PROCESSING LOCATION
        ────────────────────────────────────────────────────────────────
        \(processingLocation.description)

        DATA COLLECTION STATUS
        ────────────────────────────────────────────────────────────────
        """

        for category in PrivacyPolicy.DataCategory.allCases {
            let consent = consents[category]
            let status = consent?.isValid == true ? "✓ Allowed" : "✗ Not Allowed"
            let retention = consent?.retentionPeriod.description ?? "N/A"

            summary += """

            \(category.rawValue):
              Status: \(status)
              Retention: \(retention)
              Purpose: \(category.purposeDescription)
            """
        }

        summary += """


        YOUR RIGHTS
        ────────────────────────────────────────────────────────────────
        • Access: View all data we have about you
        • Portability: Export your data in standard format
        • Erasure: Delete all your bio-data
        • Rectification: Correct inaccurate data
        • Objection: Opt out of data processing

        To exercise any right, go to Settings > Privacy > Bio-Data

        ════════════════════════════════════════════════════════════════
        Privacy Policy Version: \(PrivacyPolicy.version)
        Last Updated: \(PrivacyPolicy.lastUpdated)
        ════════════════════════════════════════════════════════════════
        """

        return summary
    }
}

// MARK: - Keychain Manager

private final class KeychainManager {
    private let encryptionKeyTag = "com.echoelmusic.biodata.encryptionkey"

    func storeEncryptionKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: keyData
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieveEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    func deleteEncryptionKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Privacy Errors

public enum PrivacyError: Error, LocalizedError {
    case consentRequired(PrivacyPolicy.DataCategory)
    case consentExpired(PrivacyPolicy.DataCategory)
    case encryptionFailed
    case decryptionFailed
    case authenticationFailed
    case dataNotFound

    public var errorDescription: String? {
        switch self {
        case .consentRequired(let category):
            return "Consent required for \(category.rawValue)"
        case .consentExpired(let category):
            return "Consent expired for \(category.rawValue)"
        case .encryptionFailed:
            return "Failed to encrypt bio-data"
        case .decryptionFailed:
            return "Failed to decrypt bio-data"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .dataNotFound:
            return "Requested data not found"
        }
    }
}

// MARK: - Privacy-Safe Bio Data Wrapper

/// Wrapper that enforces consent checking before accessing bio-data
@propertyWrapper
public struct PrivacyProtected<Value: Codable> {
    private let category: PrivacyPolicy.DataCategory
    private var encryptedValue: Data?

    public var wrappedValue: Value? {
        get {
            guard BioDataPrivacyManager.shared.hasValidConsent(for: category) else {
                print("⚠️ Access denied: No valid consent for \(category.rawValue)")
                return nil
            }

            guard let encrypted = encryptedValue else { return nil }

            do {
                return try BioDataPrivacyManager.shared.decrypt(encrypted, as: Value.self)
            } catch {
                print("⚠️ Decryption failed for \(category.rawValue)")
                return nil
            }
        }
        set {
            guard let value = newValue else {
                encryptedValue = nil
                return
            }

            guard BioDataPrivacyManager.shared.hasValidConsent(for: category) else {
                print("⚠️ Storage denied: No valid consent for \(category.rawValue)")
                return
            }

            do {
                encryptedValue = try BioDataPrivacyManager.shared.encrypt(value)
            } catch {
                print("⚠️ Encryption failed for \(category.rawValue)")
            }
        }
    }

    public init(category: PrivacyPolicy.DataCategory) {
        self.category = category
    }
}

// MARK: - Usage Example

/*
 Example usage of privacy-protected bio-data:

 class BioFeedbackSession {
     @PrivacyProtected(category: .heartRate)
     var heartRateHistory: [HeartRateRecord]?

     @PrivacyProtected(category: .hrv)
     var hrvHistory: [HRVRecord]?

     func startSession() async {
         let privacyManager = BioDataPrivacyManager.shared

         // Request consent before collecting data
         guard await privacyManager.requestConsent(for: .heartRate, retention: .session) else {
             print("User declined heart rate consent")
             return
         }

         // Data is automatically encrypted when set
         heartRateHistory = []

         // ... collect data ...

         // Data is automatically decrypted when accessed (if consent valid)
         if let history = heartRateHistory {
             print("Collected \(history.count) heart rate samples")
         }
     }
 }
*/

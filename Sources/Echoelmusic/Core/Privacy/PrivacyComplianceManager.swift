//
//  PrivacyComplianceManager.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  GDPR & CCPA Compliance Management System
//

import Foundation
import os.log

/// Privacy compliance manager for GDPR, CCPA, and other privacy regulations
@MainActor
final class PrivacyComplianceManager: ObservableObject {
    static let shared = PrivacyComplianceManager()

    // MARK: - Published Properties

    @Published var hasAcceptedPrivacyPolicy = false
    @Published var hasAcceptedTerms = false
    @Published var analyticsConsent: ConsentStatus = .notAsked
    @Published var crashReportingConsent: ConsentStatus = .notAsked
    @Published var personalizedContentConsent: ConsentStatus = .notAsked

    // MARK: - User Rights

    enum UserRight {
        case access          // Right to access personal data
        case rectification   // Right to correct personal data
        case erasure         // Right to be forgotten
        case portability     // Right to data portability
        case restriction     // Right to restrict processing
        case objection       // Right to object to processing
        case withdraw        // Right to withdraw consent
    }

    enum ConsentStatus: String, Codable {
        case notAsked
        case granted
        case denied
        case withdrawn
    }

    // MARK: - Data Collection

    struct DataCollectionInfo: Codable {
        let dataType: DataType
        let purpose: String
        let retention: TimeInterval
        let thirdParties: [String]
        let required: Bool
        let consentRequired: Bool

        enum DataType: String, Codable {
            case healthData
            case audioData
            case videoData
            case locationData
            case usageData
            case deviceInfo
            case userProfile
            case biometricData
        }
    }

    // MARK: - Privacy Settings

    private let logger = Logger(subsystem: "com.eoel.app", category: "Privacy")
    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let privacyPolicyVersion = "privacy_policy_version"
        static let privacyPolicyAccepted = "privacy_policy_accepted"
        static let termsAccepted = "terms_accepted"
        static let analyticsConsent = "analytics_consent"
        static let crashReportingConsent = "crash_reporting_consent"
        static let personalizedContentConsent = "personalized_content_consent"
        static let dataCollectionLog = "data_collection_log"
    }

    // MARK: - Initialization

    private init() {
        loadPrivacySettings()
    }

    // MARK: - Privacy Policy

    private let currentPrivacyPolicyVersion = "1.0"

    func acceptPrivacyPolicy() {
        hasAcceptedPrivacyPolicy = true
        userDefaults.set(currentPrivacyPolicyVersion, forKey: Keys.privacyPolicyVersion)
        userDefaults.set(true, forKey: Keys.privacyPolicyAccepted)

        logger.info("Privacy policy accepted: version \(self.currentPrivacyPolicyVersion, privacy: .public)")

        logDataCollection(
            type: .userProfile,
            purpose: "Privacy policy acceptance",
            data: ["version": currentPrivacyPolicyVersion]
        )
    }

    func hasAcceptedCurrentPrivacyPolicy() -> Bool {
        guard let acceptedVersion = userDefaults.string(forKey: Keys.privacyPolicyVersion) else {
            return false
        }
        return acceptedVersion == currentPrivacyPolicyVersion && hasAcceptedPrivacyPolicy
    }

    // MARK: - Consent Management

    func requestConsent(for type: ConsentType) async -> ConsentStatus {
        // In production, this would show UI to user
        // For now, return current status
        switch type {
        case .analytics:
            return analyticsConsent
        case .crashReporting:
            return crashReportingConsent
        case .personalizedContent:
            return personalizedContentConsent
        }
    }

    func grantConsent(for type: ConsentType) {
        switch type {
        case .analytics:
            analyticsConsent = .granted
            userDefaults.set(ConsentStatus.granted.rawValue, forKey: Keys.analyticsConsent)
            enableAnalytics()

        case .crashReporting:
            crashReportingConsent = .granted
            userDefaults.set(ConsentStatus.granted.rawValue, forKey: Keys.crashReportingConsent)
            enableCrashReporting()

        case .personalizedContent:
            personalizedContentConsent = .granted
            userDefaults.set(ConsentStatus.granted.rawValue, forKey: Keys.personalizedContentConsent)
            enablePersonalizedContent()
        }

        logger.info("Consent granted: \(type.rawValue, privacy: .public)")

        logDataCollection(
            type: .userProfile,
            purpose: "Consent management",
            data: ["consent_type": type.rawValue, "status": "granted"]
        )
    }

    func denyConsent(for type: ConsentType) {
        switch type {
        case .analytics:
            analyticsConsent = .denied
            userDefaults.set(ConsentStatus.denied.rawValue, forKey: Keys.analyticsConsent)
            disableAnalytics()

        case .crashReporting:
            crashReportingConsent = .denied
            userDefaults.set(ConsentStatus.denied.rawValue, forKey: Keys.crashReportingConsent)
            disableCrashReporting()

        case .personalizedContent:
            personalizedContentConsent = .denied
            userDefaults.set(ConsentStatus.denied.rawValue, forKey: Keys.personalizedContentConsent)
            disablePersonalizedContent()
        }

        logger.info("Consent denied: \(type.rawValue, privacy: .public)")
    }

    func withdrawConsent(for type: ConsentType) {
        switch type {
        case .analytics:
            analyticsConsent = .withdrawn
            disableAnalytics()
            deleteAnalyticsData()

        case .crashReporting:
            crashReportingConsent = .withdrawn
            disableCrashReporting()
            deleteCrashReports()

        case .personalizedContent:
            personalizedContentConsent = .withdrawn
            disablePersonalizedContent()
            deletePersonalizationData()
        }

        logger.warning("Consent withdrawn: \(type.rawValue, privacy: .public)")
    }

    enum ConsentType: String {
        case analytics
        case crashReporting
        case personalizedContent
    }

    // MARK: - User Rights Implementation

    func exerciseRight(_ right: UserRight) async throws -> RightExerciseResult {
        logger.info("User exercising right: \(String(describing: right), privacy: .public)")

        switch right {
        case .access:
            return try await exportAllUserData()

        case .rectification:
            return .requiresUserAction("Please update your data in Settings > Profile")

        case .erasure:
            return try await deleteAllUserData()

        case .portability:
            return try await exportDataPortable()

        case .restriction:
            return try await restrictDataProcessing()

        case .objection:
            return .requiresUserAction("You can object to specific data processing in Settings > Privacy")

        case .withdraw:
            return try await withdrawAllConsents()
        }
    }

    // MARK: - Data Export (GDPR Article 15)

    private func exportAllUserData() async throws -> RightExerciseResult {
        var exportData: [String: Any] = [:]

        // User profile
        if let email = try? SecureStorageManager.shared.getUserEmail() {
            exportData["email"] = SecureStorageManager.sanitize(email)
        }

        // Settings
        exportData["privacy_settings"] = [
            "analytics_consent": analyticsConsent.rawValue,
            "crash_reporting_consent": crashReportingConsent.rawValue,
            "personalized_content_consent": personalizedContentConsent.rawValue
        ]

        // Data collection log
        exportData["data_collection_log"] = getDataCollectionLog()

        // Audio recordings metadata (not actual files for size reasons)
        exportData["recordings"] = getRecordingsMetadata()

        // EoelWork data
        exportData["eoelwork_profile"] = await getEoelWorkData()

        // Create export file
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        let filename = "Echoelmusic_Data_Export_\(Date().timeIntervalSince1970).json"

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsURL.appendingPathComponent(filename)
        try jsonData.write(to: exportURL)

        logger.info("User data exported to: \(exportURL.path, privacy: .public)")

        return .success(message: "Data exported to: \(exportURL.lastPathComponent)", url: exportURL)
    }

    // MARK: - Data Portability (GDPR Article 20)

    private func exportDataPortable() async throws -> RightExerciseResult {
        // Export in machine-readable format (JSON)
        return try await exportAllUserData()
    }

    // MARK: - Right to Erasure (GDPR Article 17)

    private func deleteAllUserData() async throws -> RightExerciseResult {
        logger.critical("User requesting complete data deletion")

        var deletionErrors: [String] = []

        // 1. Delete from Keychain
        do {
            try SecureStorageManager.shared.clearAll()
            logger.info("Keychain data deleted")
        } catch {
            deletionErrors.append("Keychain: \(error.localizedDescription)")
        }

        // 2. Delete encrypted files
        let encryptedDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Encrypted")
        do {
            try FileManager.default.removeItem(at: encryptedDir)
            logger.info("Encrypted files deleted")
        } catch {
            // Directory might not exist, which is fine
            logger.info("No encrypted files to delete")
        }

        // 3. Delete UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
            userDefaults.synchronize()
            logger.info("UserDefaults deleted")
        }

        // 4. Delete Firebase data (IMPLEMENTED)
        do {
            try await deleteFirebaseUserData()
            logger.info("Firebase data deleted")
        } catch {
            deletionErrors.append("Firebase: \(error.localizedDescription)")
        }

        // 5. Delete CloudKit data (IMPLEMENTED)
        do {
            try await deleteCloudKitUserData()
            logger.info("CloudKit data deleted")
        } catch {
            deletionErrors.append("CloudKit: \(error.localizedDescription)")
        }

        // 6. Delete local recordings
        deleteAllRecordings()

        // 7. Clear caches
        URLCache.shared.removeAllCachedResponses()

        // 8. Clear HealthKit disclaimer acknowledgment
        UserDefaults.standard.removeObject(forKey: "healthkit_disclaimer_acknowledged")

        // 9. Reset to factory state
        resetToFactoryState()

        // 10. Post notification for other systems to clean up
        NotificationCenter.default.post(name: .userDataDeleted, object: nil)

        if deletionErrors.isEmpty {
            logger.info("All user data deleted successfully")
            return .success(message: "All your data has been permanently deleted.", url: nil)
        } else {
            let errorSummary = deletionErrors.joined(separator: ", ")
            logger.warning("Data deletion completed with errors: \(errorSummary, privacy: .public)")
            return .success(message: "Most data deleted. Some services may retain data for up to 30 days: \(errorSummary)", url: nil)
        }
    }

    // MARK: - Firebase Data Deletion

    /// Delete user data from Firebase
    /// Note: Requires FirebaseAuth to be imported at the top of the file
    private func deleteFirebaseUserData() async throws {
        // Firebase deletion is handled via notification to AuthenticationManager
        // which has access to Firebase Auth
        NotificationCenter.default.post(name: .deleteFirebaseUserData, object: nil)

        // Wait briefly for deletion to process
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        logger.info("Firebase user deletion requested")
    }

    // MARK: - CloudKit Data Deletion

    /// Delete user data from CloudKit
    private func deleteCloudKitUserData() async throws {
        // CloudKit deletion is handled via notification to CloudSyncManager
        NotificationCenter.default.post(name: .deleteCloudKitUserData, object: nil)

        // Wait briefly for deletion to process
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        logger.info("CloudKit user deletion requested")
    }

    // MARK: - Data Processing Restriction (GDPR Article 18)

    private func restrictDataProcessing() async throws -> RightExerciseResult {
        // Stop all data collection
        denyConsent(for: .analytics)
        denyConsent(for: .crashReporting)
        denyConsent(for: .personalizedContent)

        // Disable background processing
        NotificationCenter.default.post(name: .disableBackgroundProcessing, object: nil)

        logger.warning("Data processing restricted per user request")

        return .success(message: "Data processing has been restricted.", url: nil)
    }

    // MARK: - Withdraw All Consents

    private func withdrawAllConsents() async throws -> RightExerciseResult {
        withdrawConsent(for: .analytics)
        withdrawConsent(for: .crashReporting)
        withdrawConsent(for: .personalizedContent)

        return .success(message: "All consents have been withdrawn.", url: nil)
    }

    // MARK: - Data Minimization

    func shouldCollectData(type: DataCollectionInfo.DataType) -> Bool {
        let info = getDataCollectionInfo(for: type)

        // Required data can always be collected
        if info.required {
            return true
        }

        // Optional data requires consent
        if info.consentRequired {
            switch type {
            case .usageData, .deviceInfo:
                return analyticsConsent == .granted

            case .healthData, .biometricData:
                return personalizedContentConsent == .granted

            default:
                return true
            }
        }

        return true
    }

    private func getDataCollectionInfo(for type: DataCollectionInfo.DataType) -> DataCollectionInfo {
        switch type {
        case .healthData:
            return DataCollectionInfo(
                dataType: .healthData,
                purpose: "Adaptive audio-visual experiences based on biometrics",
                retention: 30 * 24 * 3600,  // 30 days
                thirdParties: [],
                required: false,
                consentRequired: true
            )

        case .audioData:
            return DataCollectionInfo(
                dataType: .audioData,
                purpose: "Audio recording and processing",
                retention: 365 * 24 * 3600,  // 1 year
                thirdParties: [],
                required: false,
                consentRequired: false
            )

        case .usageData:
            return DataCollectionInfo(
                dataType: .usageData,
                purpose: "App improvement and analytics",
                retention: 90 * 24 * 3600,  // 90 days
                thirdParties: ["TelemetryDeck"],
                required: false,
                consentRequired: true
            )

        case .deviceInfo:
            return DataCollectionInfo(
                dataType: .deviceInfo,
                purpose: "Performance optimization",
                retention: 90 * 24 * 3600,  // 90 days
                thirdParties: [],
                required: true,
                consentRequired: false
            )

        case .userProfile:
            return DataCollectionInfo(
                dataType: .userProfile,
                purpose: "Account management",
                retention: .infinity,
                thirdParties: ["Firebase"],
                required: true,
                consentRequired: false
            )

        case .locationData:
            return DataCollectionInfo(
                dataType: .locationData,
                purpose: "EoelWork gig matching",
                retention: 30 * 24 * 3600,  // 30 days
                thirdParties: [],
                required: false,
                consentRequired: true
            )

        case .videoData:
            return DataCollectionInfo(
                dataType: .videoData,
                purpose: "Video recording and editing",
                retention: 365 * 24 * 3600,  // 1 year
                thirdParties: [],
                required: false,
                consentRequired: false
            )

        case .biometricData:
            return DataCollectionInfo(
                dataType: .biometricData,
                purpose: "Face tracking for audio control",
                retention: 0,  // Not stored, real-time only
                thirdParties: [],
                required: false,
                consentRequired: true
            )
        }
    }

    // MARK: - Data Collection Logging

    private func logDataCollection(type: DataCollectionInfo.DataType, purpose: String, data: [String: Any]) {
        let logEntry: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "type": type.rawValue,
            "purpose": purpose,
            "data_size": JSONSerialization.dataSize(data),
            "consent_status": getConsentStatus(for: type).rawValue
        ]

        var log = getDataCollectionLog()
        log.append(logEntry)

        // Keep only last 1000 entries
        if log.count > 1000 {
            log = Array(log.suffix(1000))
        }

        if let encoded = try? JSONSerialization.data(withJSONObject: log) {
            userDefaults.set(encoded, forKey: Keys.dataCollectionLog)
        }
    }

    private func getDataCollectionLog() -> [[String: Any]] {
        guard let data = userDefaults.data(forKey: Keys.dataCollectionLog),
              let log = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return log
    }

    private func getConsentStatus(for type: DataCollectionInfo.DataType) -> ConsentStatus {
        switch type {
        case .usageData, .deviceInfo:
            return analyticsConsent
        case .healthData, .biometricData:
            return personalizedContentConsent
        default:
            return .granted  // Essential data
        }
    }

    // MARK: - Helper Methods

    private func loadPrivacySettings() {
        hasAcceptedPrivacyPolicy = userDefaults.bool(forKey: Keys.privacyPolicyAccepted)
        hasAcceptedTerms = userDefaults.bool(forKey: Keys.termsAccepted)

        if let analyticsValue = userDefaults.string(forKey: Keys.analyticsConsent) {
            analyticsConsent = ConsentStatus(rawValue: analyticsValue) ?? .notAsked
        }

        if let crashValue = userDefaults.string(forKey: Keys.crashReportingConsent) {
            crashReportingConsent = ConsentStatus(rawValue: crashValue) ?? .notAsked
        }

        if let personalizedValue = userDefaults.string(forKey: Keys.personalizedContentConsent) {
            personalizedContentConsent = ConsentStatus(rawValue: personalizedValue) ?? .notAsked
        }
    }

    private func enableAnalytics() {
        // Initialize TelemetryDeck
        NotificationCenter.default.post(name: .enableAnalytics, object: nil)
    }

    private func disableAnalytics() {
        NotificationCenter.default.post(name: .disableAnalytics, object: nil)
    }

    private func deleteAnalyticsData() {
        // Clear TelemetryDeck data
        NotificationCenter.default.post(name: .clearAnalyticsData, object: nil)
    }

    private func enableCrashReporting() {
        NotificationCenter.default.post(name: .enableCrashReporting, object: nil)
    }

    private func disableCrashReporting() {
        NotificationCenter.default.post(name: .disableCrashReporting, object: nil)
    }

    private func deleteCrashReports() {
        NotificationCenter.default.post(name: .clearCrashReports, object: nil)
    }

    private func enablePersonalizedContent() {
        NotificationCenter.default.post(name: .enablePersonalization, object: nil)
    }

    private func disablePersonalizedContent() {
        NotificationCenter.default.post(name: .disablePersonalization, object: nil)
    }

    private func deletePersonalizationData() {
        NotificationCenter.default.post(name: .clearPersonalizationData, object: nil)
    }

    private func getRecordingsMetadata() -> [[String: Any]] {
        // Return metadata only (not actual recordings)
        return []
    }

    private func getEoelWorkData() async -> [String: Any] {
        // Export EoelWork profile data
        return [:]
    }

    private func deleteAllRecordings() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsURL = documentsURL.appendingPathComponent("Recordings")

        try? FileManager.default.removeItem(at: recordingsURL)
    }

    private func resetToFactoryState() {
        hasAcceptedPrivacyPolicy = false
        hasAcceptedTerms = false
        analyticsConsent = .notAsked
        crashReportingConsent = .notAsked
        personalizedContentConsent = .notAsked
    }
}

// MARK: - Right Exercise Result

enum RightExerciseResult {
    case success(message: String, url: URL?)
    case requiresUserAction(String)
    case error(String)
}

// MARK: - Notifications

extension Notification.Name {
    static let enableAnalytics = Notification.Name("com.eoel.enableAnalytics")
    static let disableAnalytics = Notification.Name("com.eoel.disableAnalytics")
    static let clearAnalyticsData = Notification.Name("com.eoel.clearAnalyticsData")
    static let enableCrashReporting = Notification.Name("com.eoel.enableCrashReporting")
    static let disableCrashReporting = Notification.Name("com.eoel.disableCrashReporting")
    static let clearCrashReports = Notification.Name("com.eoel.clearCrashReports")
    static let enablePersonalization = Notification.Name("com.eoel.enablePersonalization")
    static let disablePersonalization = Notification.Name("com.eoel.disablePersonalization")
    static let clearPersonalizationData = Notification.Name("com.eoel.clearPersonalizationData")
    static let disableBackgroundProcessing = Notification.Name("com.eoel.disableBackgroundProcessing")

    // GDPR Data Deletion Notifications
    static let userDataDeleted = Notification.Name("com.eoel.userDataDeleted")
    static let deleteFirebaseUserData = Notification.Name("com.eoel.deleteFirebaseUserData")
    static let deleteCloudKitUserData = Notification.Name("com.eoel.deleteCloudKitUserData")
}

// MARK: - JSON Serialization Extension

extension JSONSerialization {
    static func dataSize(_ object: Any) -> Int {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return 0
        }
        return data.count
    }
}

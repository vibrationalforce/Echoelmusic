// ParentalControls.swift
// Echoelmusic - Complete Parental Control System
//
// Created by Echoelmusic Team
// Copyright © 2024 NIA9ARA. All rights reserved.
//
// Scientific Foundation:
// - ESRB (Entertainment Software Rating Board) content guidelines
// - COPPA (Children's Online Privacy Protection Act) compliance
// - GDPR-K (GDPR for minors) requirements
// - AAP (American Academy of Pediatrics) screen time recommendations
// - Common Sense Media age-appropriateness standards

import Foundation
import SwiftUI
import CryptoKit
import LocalAuthentication

// MARK: - Content Rating System
// =============================================================================
/// Universal content rating based on ESRB, PEGI, USK, CERO standards
public enum ContentRating: String, CaseIterable, Codable, Identifiable {
    case everyone = "E"           // Everyone (3+)
    case everyone10 = "E10+"      // Everyone 10+ (10+)
    case teen = "T"               // Teen (13+)
    case mature = "M"             // Mature (17+)
    case adultsOnly = "AO"        // Adults Only (18+)

    public var id: String { rawValue }

    public var minimumAge: Int {
        switch self {
        case .everyone: return 3
        case .everyone10: return 10
        case .teen: return 13
        case .mature: return 17
        case .adultsOnly: return 18
        }
    }

    public var localizedName: String {
        switch self {
        case .everyone: return NSLocalizedString("Everyone", comment: "Rating")
        case .everyone10: return NSLocalizedString("Everyone 10+", comment: "Rating")
        case .teen: return NSLocalizedString("Teen", comment: "Rating")
        case .mature: return NSLocalizedString("Mature", comment: "Rating")
        case .adultsOnly: return NSLocalizedString("Adults Only", comment: "Rating")
        }
    }

    public var description: String {
        switch self {
        case .everyone:
            return NSLocalizedString("Suitable for all ages. No mature content.", comment: "Rating description")
        case .everyone10:
            return NSLocalizedString("May contain mild fantasy violence or minimal suggestive themes.", comment: "Rating description")
        case .teen:
            return NSLocalizedString("May contain violence, suggestive themes, crude humor.", comment: "Rating description")
        case .mature:
            return NSLocalizedString("May contain intense violence, blood, strong language, sexual content.", comment: "Rating description")
        case .adultsOnly:
            return NSLocalizedString("Adult content only. Strong sexual content or prolonged violence.", comment: "Rating description")
        }
    }

    public var icon: String {
        switch self {
        case .everyone: return "face.smiling"
        case .everyone10: return "person.fill"
        case .teen: return "person.2.fill"
        case .mature: return "exclamationmark.triangle.fill"
        case .adultsOnly: return "exclamationmark.octagon.fill"
        }
    }

    public var color: Color {
        switch self {
        case .everyone: return .green
        case .everyone10: return .mint
        case .teen: return .yellow
        case .mature: return .orange
        case .adultsOnly: return .red
        }
    }
}

// MARK: - Content Descriptors
// =============================================================================
/// Detailed content descriptors for granular control
public struct ContentDescriptors: OptionSet, Codable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // Violence
    public static let mildViolence = ContentDescriptors(rawValue: 1 << 0)
    public static let fantasyViolence = ContentDescriptors(rawValue: 1 << 1)
    public static let violence = ContentDescriptors(rawValue: 1 << 2)
    public static let intenseViolence = ContentDescriptors(rawValue: 1 << 3)
    public static let bloodGore = ContentDescriptors(rawValue: 1 << 4)

    // Language
    public static let mildLanguage = ContentDescriptors(rawValue: 1 << 5)
    public static let language = ContentDescriptors(rawValue: 1 << 6)
    public static let strongLanguage = ContentDescriptors(rawValue: 1 << 7)

    // Suggestive Content
    public static let mildSuggestiveThemes = ContentDescriptors(rawValue: 1 << 8)
    public static let suggestiveThemes = ContentDescriptors(rawValue: 1 << 9)
    public static let sexualContent = ContentDescriptors(rawValue: 1 << 10)
    public static let nudity = ContentDescriptors(rawValue: 1 << 11)

    // Substance
    public static let alcoholReference = ContentDescriptors(rawValue: 1 << 12)
    public static let drugReference = ContentDescriptors(rawValue: 1 << 13)
    public static let tobaccoReference = ContentDescriptors(rawValue: 1 << 14)
    public static let useOfSubstances = ContentDescriptors(rawValue: 1 << 15)

    // Other
    public static let gambling = ContentDescriptors(rawValue: 1 << 16)
    public static let realGambling = ContentDescriptors(rawValue: 1 << 17)
    public static let horror = ContentDescriptors(rawValue: 1 << 18)
    public static let matureHumor = ContentDescriptors(rawValue: 1 << 19)
    public static let onlineInteraction = ContentDescriptors(rawValue: 1 << 20)
    public static let userGeneratedContent = ContentDescriptors(rawValue: 1 << 21)
    public static let inAppPurchases = ContentDescriptors(rawValue: 1 << 22)

    // Music-Specific
    public static let explicitLyrics = ContentDescriptors(rawValue: 1 << 23)
    public static let violentLyrics = ContentDescriptors(rawValue: 1 << 24)
    public static let sexualLyrics = ContentDescriptors(rawValue: 1 << 25)
    public static let drugLyrics = ContentDescriptors(rawValue: 1 << 26)
    public static let politicalContent = ContentDescriptors(rawValue: 1 << 27)
    public static let religiousContent = ContentDescriptors(rawValue: 1 << 28)
    public static let flashingLights = ContentDescriptors(rawValue: 1 << 29)  // Epilepsy warning
    public static let loudSounds = ContentDescriptors(rawValue: 1 << 30)       // Hearing safety

    public static let none: ContentDescriptors = []
    public static let familyFriendly: ContentDescriptors = []
    public static let all = ContentDescriptors(rawValue: UInt32.max)

    public var descriptions: [String] {
        var result: [String] = []
        if contains(.mildViolence) { result.append("Mild Violence") }
        if contains(.fantasyViolence) { result.append("Fantasy Violence") }
        if contains(.violence) { result.append("Violence") }
        if contains(.intenseViolence) { result.append("Intense Violence") }
        if contains(.bloodGore) { result.append("Blood & Gore") }
        if contains(.mildLanguage) { result.append("Mild Language") }
        if contains(.language) { result.append("Language") }
        if contains(.strongLanguage) { result.append("Strong Language") }
        if contains(.mildSuggestiveThemes) { result.append("Mild Suggestive Themes") }
        if contains(.suggestiveThemes) { result.append("Suggestive Themes") }
        if contains(.sexualContent) { result.append("Sexual Content") }
        if contains(.nudity) { result.append("Nudity") }
        if contains(.alcoholReference) { result.append("Alcohol Reference") }
        if contains(.drugReference) { result.append("Drug Reference") }
        if contains(.tobaccoReference) { result.append("Tobacco Reference") }
        if contains(.useOfSubstances) { result.append("Use of Substances") }
        if contains(.gambling) { result.append("Simulated Gambling") }
        if contains(.realGambling) { result.append("Real Gambling") }
        if contains(.horror) { result.append("Horror") }
        if contains(.matureHumor) { result.append("Mature Humor") }
        if contains(.onlineInteraction) { result.append("Online Interaction") }
        if contains(.userGeneratedContent) { result.append("User Generated Content") }
        if contains(.inAppPurchases) { result.append("In-App Purchases") }
        if contains(.explicitLyrics) { result.append("Explicit Lyrics") }
        if contains(.violentLyrics) { result.append("Violent Lyrics") }
        if contains(.sexualLyrics) { result.append("Sexual Lyrics") }
        if contains(.drugLyrics) { result.append("Drug-Related Lyrics") }
        if contains(.politicalContent) { result.append("Political Content") }
        if contains(.religiousContent) { result.append("Religious Content") }
        if contains(.flashingLights) { result.append("Flashing Lights") }
        if contains(.loudSounds) { result.append("Potentially Loud Sounds") }
        return result
    }
}

// MARK: - Screen Time Management
// =============================================================================
/// AAP-recommended screen time limits
public struct ScreenTimeSettings: Codable {
    /// Daily time limit in minutes (AAP recommends: 2-5 years: 1hr, 6+: consistent limits)
    public var dailyLimitMinutes: Int

    /// Bedtime lockout (no use after this time)
    public var bedtime: Date?

    /// Wake time (no use before this time)
    public var wakeTime: Date?

    /// Days when limits are relaxed (e.g., weekends)
    public var relaxedDays: Set<Int>  // 1=Sunday, 7=Saturday

    /// Extended limit for relaxed days
    public var relaxedDailyLimitMinutes: Int

    /// Break reminder interval (minutes)
    public var breakReminderMinutes: Int

    /// Required break duration (minutes)
    public var breakDurationMinutes: Int

    /// Whether to allow extension requests
    public var allowExtensionRequests: Bool

    /// Maximum extensions per day
    public var maxExtensionsPerDay: Int

    /// Extension duration (minutes)
    public var extensionMinutes: Int

    public static let defaultChild = ScreenTimeSettings(
        dailyLimitMinutes: 60,
        bedtime: Calendar.current.date(from: DateComponents(hour: 20, minute: 0)),
        wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
        relaxedDays: [1, 7],  // Sunday, Saturday
        relaxedDailyLimitMinutes: 120,
        breakReminderMinutes: 30,
        breakDurationMinutes: 5,
        allowExtensionRequests: true,
        maxExtensionsPerDay: 2,
        extensionMinutes: 15
    )

    public static let defaultTeen = ScreenTimeSettings(
        dailyLimitMinutes: 120,
        bedtime: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)),
        wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 0)),
        relaxedDays: [1, 7],
        relaxedDailyLimitMinutes: 180,
        breakReminderMinutes: 45,
        breakDurationMinutes: 5,
        allowExtensionRequests: true,
        maxExtensionsPerDay: 3,
        extensionMinutes: 30
    )

    public static let unlimited = ScreenTimeSettings(
        dailyLimitMinutes: 0,  // 0 = unlimited
        bedtime: nil,
        wakeTime: nil,
        relaxedDays: [],
        relaxedDailyLimitMinutes: 0,
        breakReminderMinutes: 60,
        breakDurationMinutes: 5,
        allowExtensionRequests: false,
        maxExtensionsPerDay: 0,
        extensionMinutes: 0
    )
}

// MARK: - Purchase Controls
// =============================================================================
public struct PurchaseControls: Codable {
    /// Whether in-app purchases are allowed
    public var allowPurchases: Bool

    /// Whether to require authentication for purchases
    public var requireAuthForPurchases: Bool

    /// Maximum purchase amount without parent approval (0 = always require approval)
    public var maxPurchaseWithoutApproval: Decimal

    /// Monthly spending limit
    public var monthlySpendingLimit: Decimal

    /// Whether to allow free downloads
    public var allowFreeDownloads: Bool

    /// Whether to require approval for free downloads
    public var requireApprovalForFreeDownloads: Bool

    public static let defaultChild = PurchaseControls(
        allowPurchases: false,
        requireAuthForPurchases: true,
        maxPurchaseWithoutApproval: 0,
        monthlySpendingLimit: 0,
        allowFreeDownloads: true,
        requireApprovalForFreeDownloads: true
    )

    public static let defaultTeen = PurchaseControls(
        allowPurchases: true,
        requireAuthForPurchases: true,
        maxPurchaseWithoutApproval: 5.0,
        monthlySpendingLimit: 20.0,
        allowFreeDownloads: true,
        requireApprovalForFreeDownloads: false
    )

    public static let unrestricted = PurchaseControls(
        allowPurchases: true,
        requireAuthForPurchases: false,
        maxPurchaseWithoutApproval: Decimal.greatestFiniteMagnitude,
        monthlySpendingLimit: Decimal.greatestFiniteMagnitude,
        allowFreeDownloads: true,
        requireApprovalForFreeDownloads: false
    )
}

// MARK: - Child Profile
// =============================================================================
public struct ChildProfile: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var birthDate: Date
    public var avatarName: String

    // Content restrictions
    public var maxContentRating: ContentRating
    public var blockedDescriptors: ContentDescriptors

    // Time management
    public var screenTimeSettings: ScreenTimeSettings

    // Purchase controls
    public var purchaseControls: PurchaseControls

    // Feature restrictions
    public var allowSocialFeatures: Bool
    public var allowSharing: Bool
    public var allowExport: Bool
    public var allowCloudSync: Bool
    public var allowCollaboration: Bool
    public var allowVoiceChat: Bool
    public var allowTextChat: Bool
    public var allowLocationSharing: Bool

    // Safety features
    public var enableSafeSearch: Bool
    public var enableExplicitFilter: Bool
    public var enableVolumeLimit: Bool
    public var maxVolumePercent: Int  // 0-100
    public var enableFlashingLightWarning: Bool

    public var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    public init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        avatarName: String = "person.circle.fill"
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.avatarName = avatarName

        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        // Set age-appropriate defaults
        if age < 10 {
            self.maxContentRating = .everyone
            self.screenTimeSettings = .defaultChild
            self.purchaseControls = .defaultChild
            self.allowSocialFeatures = false
            self.allowSharing = false
            self.allowExport = false
            self.maxVolumePercent = 70
        } else if age < 13 {
            self.maxContentRating = .everyone10
            self.screenTimeSettings = .defaultChild
            self.purchaseControls = .defaultChild
            self.allowSocialFeatures = false
            self.allowSharing = true
            self.allowExport = true
            self.maxVolumePercent = 80
        } else if age < 17 {
            self.maxContentRating = .teen
            self.screenTimeSettings = .defaultTeen
            self.purchaseControls = .defaultTeen
            self.allowSocialFeatures = true
            self.allowSharing = true
            self.allowExport = true
            self.maxVolumePercent = 85
        } else {
            self.maxContentRating = .mature
            self.screenTimeSettings = .unlimited
            self.purchaseControls = .unrestricted
            self.allowSocialFeatures = true
            self.allowSharing = true
            self.allowExport = true
            self.maxVolumePercent = 100
        }

        self.blockedDescriptors = []
        self.allowCloudSync = true
        self.allowCollaboration = age >= 13
        self.allowVoiceChat = age >= 13
        self.allowTextChat = age >= 10
        self.allowLocationSharing = false
        self.enableSafeSearch = true
        self.enableExplicitFilter = true
        self.enableVolumeLimit = age < 18
        self.enableFlashingLightWarning = true
    }
}

// MARK: - PIN Security System
// =============================================================================
/// Secure PIN management with hashing and attempt limiting
@MainActor
public final class PINManager: ObservableObject {
    public static let shared = PINManager()

    @Published public private(set) var isLocked: Bool = true
    @Published public private(set) var failedAttempts: Int = 0
    @Published public private(set) var lockoutEndTime: Date?
    @Published public private(set) var isPINSet: Bool = false

    // Security settings
    private let maxFailedAttempts = 5
    private let lockoutDurations: [TimeInterval] = [30, 60, 300, 900, 3600]  // Progressive lockout
    private let pinLength = 4

    private var pinHash: Data?
    private var salt: Data?

    private init() {
        loadPINData()
    }

    // MARK: - PIN Setup

    /// Set a new PIN (requires current PIN if one exists)
    public func setPIN(_ newPIN: String, currentPIN: String? = nil) -> Result<Void, PINError> {
        // Validate new PIN
        guard newPIN.count == pinLength, newPIN.allSatisfy({ $0.isNumber }) else {
            return .failure(.invalidPINFormat)
        }

        // Check if changing existing PIN
        if isPINSet {
            guard let current = currentPIN else {
                return .failure(.currentPINRequired)
            }
            guard verifyPINInternal(current) else {
                return .failure(.incorrectPIN)
            }
        }

        // Generate new salt and hash
        salt = generateSalt()
        pinHash = hashPIN(newPIN, salt: salt!)

        // Save securely
        savePINData()

        isPINSet = true
        isLocked = false
        failedAttempts = 0

        return .success(())
    }

    /// Remove PIN (requires current PIN or biometric)
    public func removePIN(currentPIN: String) -> Result<Void, PINError> {
        guard isPINSet else { return .success(()) }

        guard verifyPINInternal(currentPIN) else {
            recordFailedAttempt()
            return .failure(.incorrectPIN)
        }

        pinHash = nil
        salt = nil
        clearPINData()

        isPINSet = false
        isLocked = false
        failedAttempts = 0

        return .success(())
    }

    // MARK: - PIN Verification

    /// Verify PIN and unlock if correct
    public func verifyPIN(_ pin: String) -> Result<Void, PINError> {
        // Check lockout
        if let lockoutEnd = lockoutEndTime, Date() < lockoutEnd {
            let remaining = lockoutEnd.timeIntervalSinceNow
            return .failure(.lockedOut(secondsRemaining: Int(remaining)))
        }

        guard isPINSet else {
            return .failure(.noPINSet)
        }

        if verifyPINInternal(pin) {
            isLocked = false
            failedAttempts = 0
            lockoutEndTime = nil
            return .success(())
        } else {
            recordFailedAttempt()

            if failedAttempts >= maxFailedAttempts {
                let lockoutIndex = min(failedAttempts - maxFailedAttempts, lockoutDurations.count - 1)
                let lockoutDuration = lockoutDurations[lockoutIndex]
                lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
                return .failure(.lockedOut(secondsRemaining: Int(lockoutDuration)))
            }

            return .failure(.incorrectPIN)
        }
    }

    /// Attempt biometric authentication
    public func authenticateWithBiometrics() async -> Result<Void, PINError> {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .failure(.biometricsUnavailable)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: NSLocalizedString("Authenticate to access parental controls", comment: "")
            )

            if success {
                isLocked = false
                failedAttempts = 0
                lockoutEndTime = nil
                return .success(())
            } else {
                return .failure(.biometricsFailed)
            }
        } catch {
            return .failure(.biometricsFailed)
        }
    }

    /// Lock parental controls
    public func lock() {
        isLocked = true
    }

    // MARK: - Internal Methods

    private func verifyPINInternal(_ pin: String) -> Bool {
        guard let storedHash = pinHash, let storedSalt = salt else {
            return false
        }

        let inputHash = hashPIN(pin, salt: storedSalt)
        return inputHash == storedHash
    }

    private func recordFailedAttempt() {
        failedAttempts += 1

        // Log security event
        logSecurityEvent(.failedPINAttempt, details: "Attempt \(failedAttempts)")
    }

    private func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private func hashPIN(_ pin: String, salt: Data) -> Data {
        // Use PBKDF2-like derivation with SHA256
        let pinData = Data(pin.utf8)
        let combined = salt + pinData

        // Multiple rounds of hashing for security
        var hash = SHA256.hash(data: combined)
        for _ in 0..<10000 {
            hash = SHA256.hash(data: Data(hash) + salt)
        }

        return Data(hash)
    }

    // MARK: - Persistence

    private func savePINData() {
        guard let hash = pinHash, let saltData = salt else { return }

        // Store in Keychain for security
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic.parental.pin",
            kSecValueData as String: hash + saltData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadPINData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic.parental.pin",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, data.count >= 64 {
            // SHA256 hash (32 bytes) + salt (32 bytes)
            pinHash = data.prefix(32)
            salt = data.suffix(32)
            isPINSet = true
        } else {
            isPINSet = false
        }
    }

    private func clearPINData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic.parental.pin"
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func logSecurityEvent(_ event: SecurityEvent, details: String) {
        // Log to secure audit trail
        let entry = SecurityLogEntry(
            timestamp: Date(),
            event: event,
            details: details,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )

        // In production, this would write to a secure log
        print("Security Event: \(entry)")
    }
}

// MARK: - PIN Errors
public enum PINError: LocalizedError {
    case invalidPINFormat
    case currentPINRequired
    case incorrectPIN
    case noPINSet
    case lockedOut(secondsRemaining: Int)
    case biometricsUnavailable
    case biometricsFailed

    public var errorDescription: String? {
        switch self {
        case .invalidPINFormat:
            return NSLocalizedString("PIN must be 4 digits", comment: "Error")
        case .currentPINRequired:
            return NSLocalizedString("Please enter your current PIN", comment: "Error")
        case .incorrectPIN:
            return NSLocalizedString("Incorrect PIN", comment: "Error")
        case .noPINSet:
            return NSLocalizedString("No PIN has been set", comment: "Error")
        case .lockedOut(let seconds):
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if minutes > 0 {
                return String(format: NSLocalizedString("Too many attempts. Try again in %d:%02d", comment: "Error"), minutes, remainingSeconds)
            } else {
                return String(format: NSLocalizedString("Too many attempts. Try again in %d seconds", comment: "Error"), seconds)
            }
        case .biometricsUnavailable:
            return NSLocalizedString("Biometric authentication is not available", comment: "Error")
        case .biometricsFailed:
            return NSLocalizedString("Biometric authentication failed", comment: "Error")
        }
    }
}

// MARK: - Security Events
public enum SecurityEvent: String, Codable {
    case failedPINAttempt
    case successfulPINEntry
    case pinChanged
    case pinRemoved
    case biometricSuccess
    case biometricFailure
    case profileCreated
    case profileModified
    case profileDeleted
    case restrictionBypassed
    case extensionRequested
    case extensionApproved
    case extensionDenied
}

public struct SecurityLogEntry: Codable {
    public let timestamp: Date
    public let event: SecurityEvent
    public let details: String
    public let deviceId: String
}

// MARK: - Parental Controls Manager
// =============================================================================
@MainActor
public final class ParentalControlsManager: ObservableObject {
    public static let shared = ParentalControlsManager()

    // State
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var childProfiles: [ChildProfile] = []
    @Published public private(set) var activeProfile: ChildProfile?
    @Published public private(set) var todayUsageMinutes: Int = 0
    @Published public private(set) var extensionsUsedToday: Int = 0

    // Usage tracking
    private var sessionStartTime: Date?
    private var usageTimer: Timer?

    // PIN Manager
    public let pinManager = PINManager.shared

    private init() {
        loadProfiles()
        loadUsageData()
        startUsageTracking()
    }

    // MARK: - Profile Management

    public func enableParentalControls() async -> Result<Void, ParentalControlError> {
        guard pinManager.isPINSet else {
            return .failure(.pinRequired)
        }

        isEnabled = true
        saveProfiles()
        return .success(())
    }

    public func disableParentalControls() -> Result<Void, ParentalControlError> {
        guard !pinManager.isLocked else {
            return .failure(.authenticationRequired)
        }

        isEnabled = false
        activeProfile = nil
        saveProfiles()
        return .success(())
    }

    public func addChildProfile(_ profile: ChildProfile) -> Result<Void, ParentalControlError> {
        guard !pinManager.isLocked else {
            return .failure(.authenticationRequired)
        }

        childProfiles.append(profile)
        saveProfiles()
        return .success(())
    }

    public func updateChildProfile(_ profile: ChildProfile) -> Result<Void, ParentalControlError> {
        guard !pinManager.isLocked else {
            return .failure(.authenticationRequired)
        }

        if let index = childProfiles.firstIndex(where: { $0.id == profile.id }) {
            childProfiles[index] = profile
            if activeProfile?.id == profile.id {
                activeProfile = profile
            }
            saveProfiles()
            return .success(())
        }

        return .failure(.profileNotFound)
    }

    public func removeChildProfile(id: UUID) -> Result<Void, ParentalControlError> {
        guard !pinManager.isLocked else {
            return .failure(.authenticationRequired)
        }

        childProfiles.removeAll { $0.id == id }
        if activeProfile?.id == id {
            activeProfile = nil
        }
        saveProfiles()
        return .success(())
    }

    public func setActiveProfile(_ profile: ChildProfile?) {
        activeProfile = profile
        resetDailyUsageIfNeeded()
        UserDefaults.standard.set(profile?.id.uuidString, forKey: "echoelmusic.parental.activeProfileId")
    }

    // MARK: - Content Filtering

    /// Check if content is allowed for the active profile
    public func isContentAllowed(rating: ContentRating, descriptors: ContentDescriptors) -> Bool {
        guard isEnabled, let profile = activeProfile else {
            return true  // No restrictions if parental controls disabled
        }

        // Check rating
        if rating.minimumAge > profile.maxContentRating.minimumAge {
            return false
        }

        // Check blocked descriptors
        if !profile.blockedDescriptors.intersection(descriptors).isEmpty {
            return false
        }

        return true
    }

    /// Get the reason content is blocked
    public func contentBlockedReason(rating: ContentRating, descriptors: ContentDescriptors) -> String? {
        guard isEnabled, let profile = activeProfile else {
            return nil
        }

        if rating.minimumAge > profile.maxContentRating.minimumAge {
            return String(format: NSLocalizedString("This content is rated %@ and requires age %d+", comment: ""),
                         rating.localizedName, rating.minimumAge)
        }

        let blocked = profile.blockedDescriptors.intersection(descriptors)
        if !blocked.isEmpty {
            let descriptions = blocked.descriptions.joined(separator: ", ")
            return String(format: NSLocalizedString("This content contains: %@", comment: ""), descriptions)
        }

        return nil
    }

    // MARK: - Feature Access

    public func isFeatureAllowed(_ feature: RestrictedFeature) -> Bool {
        guard isEnabled, let profile = activeProfile else {
            return true
        }

        switch feature {
        case .socialFeatures:
            return profile.allowSocialFeatures
        case .sharing:
            return profile.allowSharing
        case .export:
            return profile.allowExport
        case .cloudSync:
            return profile.allowCloudSync
        case .collaboration:
            return profile.allowCollaboration
        case .voiceChat:
            return profile.allowVoiceChat
        case .textChat:
            return profile.allowTextChat
        case .locationSharing:
            return profile.allowLocationSharing
        case .purchases:
            return profile.purchaseControls.allowPurchases
        case .freeDownloads:
            return profile.purchaseControls.allowFreeDownloads
        }
    }

    // MARK: - Screen Time

    public func checkScreenTime() -> ScreenTimeStatus {
        guard isEnabled, let profile = activeProfile else {
            return .allowed
        }

        let settings = profile.screenTimeSettings

        // Check unlimited
        if settings.dailyLimitMinutes == 0 {
            return .allowed
        }

        // Check bedtime/wake time
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute

        if let bedtime = settings.bedtime {
            let bedtimeHour = calendar.component(.hour, from: bedtime)
            let bedtimeMinute = calendar.component(.minute, from: bedtime)
            let bedtimeTotalMinutes = bedtimeHour * 60 + bedtimeMinute

            if currentTotalMinutes >= bedtimeTotalMinutes {
                return .bedtimeLockout
            }
        }

        if let wakeTime = settings.wakeTime {
            let wakeHour = calendar.component(.hour, from: wakeTime)
            let wakeMinute = calendar.component(.minute, from: wakeTime)
            let wakeTotalMinutes = wakeHour * 60 + wakeMinute

            if currentTotalMinutes < wakeTotalMinutes {
                return .beforeWakeTime
            }
        }

        // Check daily limit
        let isRelaxedDay = settings.relaxedDays.contains(calendar.component(.weekday, from: now))
        let dailyLimit = isRelaxedDay ? settings.relaxedDailyLimitMinutes : settings.dailyLimitMinutes

        if todayUsageMinutes >= dailyLimit {
            // Check if extensions available
            if settings.allowExtensionRequests && extensionsUsedToday < settings.maxExtensionsPerDay {
                return .limitReached(canRequestExtension: true)
            }
            return .limitReached(canRequestExtension: false)
        }

        // Check if near limit
        let remainingMinutes = dailyLimit - todayUsageMinutes
        if remainingMinutes <= 5 {
            return .nearLimit(minutesRemaining: remainingMinutes)
        }

        return .allowed
    }

    public func requestExtension() async -> Result<Void, ParentalControlError> {
        guard let profile = activeProfile else {
            return .failure(.noActiveProfile)
        }

        let settings = profile.screenTimeSettings

        guard settings.allowExtensionRequests else {
            return .failure(.extensionsNotAllowed)
        }

        guard extensionsUsedToday < settings.maxExtensionsPerDay else {
            return .failure(.maxExtensionsReached)
        }

        // In a real app, this would send a notification to the parent
        // For now, we'll require PIN authentication
        return .failure(.parentApprovalRequired)
    }

    public func approveExtension() -> Result<Void, ParentalControlError> {
        guard !pinManager.isLocked else {
            return .failure(.authenticationRequired)
        }

        guard let profile = activeProfile else {
            return .failure(.noActiveProfile)
        }

        extensionsUsedToday += 1
        todayUsageMinutes -= profile.screenTimeSettings.extensionMinutes

        saveUsageData()
        return .success(())
    }

    // MARK: - Volume Limit

    public var maxVolume: Float {
        guard isEnabled, let profile = activeProfile, profile.enableVolumeLimit else {
            return 1.0
        }
        return Float(profile.maxVolumePercent) / 100.0
    }

    // MARK: - Usage Tracking

    private func startUsageTracking() {
        sessionStartTime = Date()

        usageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordUsageMinute()
            }
        }
    }

    private func recordUsageMinute() {
        guard isEnabled, activeProfile != nil else { return }

        todayUsageMinutes += 1
        saveUsageData()

        // Check if limit reached
        let status = checkScreenTime()
        if case .limitReached = status {
            NotificationCenter.default.post(name: .screenTimeLimitReached, object: nil)
        }
    }

    private func resetDailyUsageIfNeeded() {
        let lastResetKey = "echoelmusic.parental.lastUsageReset"
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? Date.distantPast

        if !Calendar.current.isDateInToday(lastReset) {
            todayUsageMinutes = 0
            extensionsUsedToday = 0
            UserDefaults.standard.set(Date(), forKey: lastResetKey)
            saveUsageData()
        }
    }

    // MARK: - Persistence

    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(childProfiles)
            UserDefaults.standard.set(data, forKey: "echoelmusic.parental.profiles")
            UserDefaults.standard.set(isEnabled, forKey: "echoelmusic.parental.enabled")
        } catch {
            print("Failed to save parental profiles: \(error)")
        }
    }

    private func loadProfiles() {
        isEnabled = UserDefaults.standard.bool(forKey: "echoelmusic.parental.enabled")

        if let data = UserDefaults.standard.data(forKey: "echoelmusic.parental.profiles") {
            do {
                childProfiles = try JSONDecoder().decode([ChildProfile].self, from: data)
            } catch {
                print("Failed to load parental profiles: \(error)")
            }
        }

        // Restore active profile
        if let activeId = UserDefaults.standard.string(forKey: "echoelmusic.parental.activeProfileId"),
           let uuid = UUID(uuidString: activeId) {
            activeProfile = childProfiles.first { $0.id == uuid }
        }
    }

    private func saveUsageData() {
        UserDefaults.standard.set(todayUsageMinutes, forKey: "echoelmusic.parental.todayUsage")
        UserDefaults.standard.set(extensionsUsedToday, forKey: "echoelmusic.parental.extensionsToday")
    }

    private func loadUsageData() {
        todayUsageMinutes = UserDefaults.standard.integer(forKey: "echoelmusic.parental.todayUsage")
        extensionsUsedToday = UserDefaults.standard.integer(forKey: "echoelmusic.parental.extensionsToday")
        resetDailyUsageIfNeeded()
    }
}

// MARK: - Supporting Types
public enum RestrictedFeature {
    case socialFeatures
    case sharing
    case export
    case cloudSync
    case collaboration
    case voiceChat
    case textChat
    case locationSharing
    case purchases
    case freeDownloads
}

public enum ScreenTimeStatus {
    case allowed
    case nearLimit(minutesRemaining: Int)
    case limitReached(canRequestExtension: Bool)
    case bedtimeLockout
    case beforeWakeTime
}

public enum ParentalControlError: LocalizedError {
    case pinRequired
    case authenticationRequired
    case profileNotFound
    case noActiveProfile
    case extensionsNotAllowed
    case maxExtensionsReached
    case parentApprovalRequired

    public var errorDescription: String? {
        switch self {
        case .pinRequired:
            return NSLocalizedString("Please set a PIN to enable parental controls", comment: "Error")
        case .authenticationRequired:
            return NSLocalizedString("Please enter your PIN to make changes", comment: "Error")
        case .profileNotFound:
            return NSLocalizedString("Profile not found", comment: "Error")
        case .noActiveProfile:
            return NSLocalizedString("No child profile is active", comment: "Error")
        case .extensionsNotAllowed:
            return NSLocalizedString("Screen time extensions are not allowed", comment: "Error")
        case .maxExtensionsReached:
            return NSLocalizedString("Maximum extensions for today have been used", comment: "Error")
        case .parentApprovalRequired:
            return NSLocalizedString("Parent approval is required for this action", comment: "Error")
        }
    }
}

// MARK: - Notifications
public extension Notification.Name {
    static let screenTimeLimitReached = Notification.Name("echoelmusic.screenTimeLimitReached")
    static let screenTimeWarning = Notification.Name("echoelmusic.screenTimeWarning")
    static let parentalControlsChanged = Notification.Name("echoelmusic.parentalControlsChanged")
}

// MARK: - SwiftUI Views
// =============================================================================

/// PIN Entry View
public struct PINEntryView: View {
    @ObservedObject private var pinManager = PINManager.shared
    @State private var enteredPIN: String = ""
    @State private var isShaking = false
    @State private var showBiometricPrompt = false

    let onSuccess: () -> Void
    let onCancel: (() -> Void)?

    public init(onSuccess: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Enter PIN")
                    .font(.title2.bold())

                Text("Enter your 4-digit parental PIN")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // PIN dots
            HStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPIN.count ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
            }
            .modifier(ShakeEffect(shakes: isShaking ? 2 : 0))

            // Lockout message
            if let lockoutEnd = pinManager.lockoutEndTime, Date() < lockoutEnd {
                let remaining = Int(lockoutEnd.timeIntervalSinceNow)
                Text("Try again in \(remaining / 60):\(String(format: "%02d", remaining % 60))")
                    .foregroundColor(.red)
                    .font(.callout)
            }

            // Number pad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(1...9, id: \.self) { number in
                    NumberButton(number: "\(number)") {
                        appendDigit("\(number)")
                    }
                }

                // Face ID / Touch ID button
                Button(action: attemptBiometric) {
                    Image(systemName: "faceid")
                        .font(.title)
                        .frame(width: 70, height: 70)
                }
                .disabled(pinManager.lockoutEndTime != nil && Date() < pinManager.lockoutEndTime!)

                NumberButton(number: "0") {
                    appendDigit("0")
                }

                // Delete button
                Button(action: { enteredPIN = String(enteredPIN.dropLast()) }) {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
            }
            .padding(.horizontal)

            // Cancel button
            if let cancel = onCancel {
                Button("Cancel", action: cancel)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func appendDigit(_ digit: String) {
        guard enteredPIN.count < 4 else { return }

        enteredPIN += digit

        if enteredPIN.count == 4 {
            verifyPIN()
        }
    }

    private func verifyPIN() {
        switch pinManager.verifyPIN(enteredPIN) {
        case .success:
            onSuccess()
        case .failure:
            withAnimation(.default) {
                isShaking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isShaking = false
                enteredPIN = ""
            }
        }
    }

    private func attemptBiometric() {
        Task {
            let result = await pinManager.authenticateWithBiometrics()
            if case .success = result {
                onSuccess()
            }
        }
    }
}

private struct NumberButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .frame(width: 70, height: 70)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(shakes * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// Child Profile Editor View
public struct ChildProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ChildProfile

    let isNew: Bool
    let onSave: (ChildProfile) -> Void

    public init(profile: ChildProfile? = nil, onSave: @escaping (ChildProfile) -> Void) {
        self.isNew = profile == nil
        self._profile = State(initialValue: profile ?? ChildProfile(name: "", birthDate: Date()))
        self.onSave = onSave
    }

    public var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section("Profile Information") {
                    TextField("Name", text: $profile.name)
                    DatePicker("Birthday", selection: $profile.birthDate, displayedComponents: .date)

                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(profile.age) years old")
                            .foregroundColor(.secondary)
                    }
                }

                // Content Rating
                Section("Content Restrictions") {
                    Picker("Maximum Rating", selection: $profile.maxContentRating) {
                        ForEach(ContentRating.allCases) { rating in
                            HStack {
                                Image(systemName: rating.icon)
                                    .foregroundColor(rating.color)
                                Text(rating.localizedName)
                            }
                            .tag(rating)
                        }
                    }

                    NavigationLink("Content Filters") {
                        ContentDescriptorFilterView(blockedDescriptors: $profile.blockedDescriptors)
                    }
                }

                // Screen Time
                Section("Screen Time") {
                    Stepper("Daily Limit: \(profile.screenTimeSettings.dailyLimitMinutes) min",
                           value: $profile.screenTimeSettings.dailyLimitMinutes,
                           in: 0...480,
                           step: 15)

                    if profile.screenTimeSettings.dailyLimitMinutes > 0 {
                        Toggle("Allow Extension Requests", isOn: $profile.screenTimeSettings.allowExtensionRequests)
                    }
                }

                // Features
                Section("Features") {
                    Toggle("Social Features", isOn: $profile.allowSocialFeatures)
                    Toggle("Sharing", isOn: $profile.allowSharing)
                    Toggle("Export Projects", isOn: $profile.allowExport)
                    Toggle("Cloud Sync", isOn: $profile.allowCloudSync)
                    Toggle("Collaboration", isOn: $profile.allowCollaboration)
                }

                // Safety
                Section("Safety") {
                    Toggle("Safe Search", isOn: $profile.enableSafeSearch)
                    Toggle("Explicit Content Filter", isOn: $profile.enableExplicitFilter)
                    Toggle("Volume Limit", isOn: $profile.enableVolumeLimit)

                    if profile.enableVolumeLimit {
                        Stepper("Max Volume: \(profile.maxVolumePercent)%",
                               value: $profile.maxVolumePercent,
                               in: 50...100,
                               step: 5)
                    }

                    Toggle("Flashing Light Warnings", isOn: $profile.enableFlashingLightWarning)
                }
            }
            .navigationTitle(isNew ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(profile.name.isEmpty)
                }
            }
        }
    }
}

private struct ContentDescriptorFilterView: View {
    @Binding var blockedDescriptors: ContentDescriptors

    var body: some View {
        List {
            Section("Violence") {
                DescriptorToggle("Mild Violence", descriptor: .mildViolence, blocked: $blockedDescriptors)
                DescriptorToggle("Fantasy Violence", descriptor: .fantasyViolence, blocked: $blockedDescriptors)
                DescriptorToggle("Violence", descriptor: .violence, blocked: $blockedDescriptors)
                DescriptorToggle("Intense Violence", descriptor: .intenseViolence, blocked: $blockedDescriptors)
                DescriptorToggle("Blood & Gore", descriptor: .bloodGore, blocked: $blockedDescriptors)
            }

            Section("Language") {
                DescriptorToggle("Mild Language", descriptor: .mildLanguage, blocked: $blockedDescriptors)
                DescriptorToggle("Language", descriptor: .language, blocked: $blockedDescriptors)
                DescriptorToggle("Strong Language", descriptor: .strongLanguage, blocked: $blockedDescriptors)
            }

            Section("Suggestive Content") {
                DescriptorToggle("Mild Suggestive Themes", descriptor: .mildSuggestiveThemes, blocked: $blockedDescriptors)
                DescriptorToggle("Suggestive Themes", descriptor: .suggestiveThemes, blocked: $blockedDescriptors)
                DescriptorToggle("Sexual Content", descriptor: .sexualContent, blocked: $blockedDescriptors)
                DescriptorToggle("Nudity", descriptor: .nudity, blocked: $blockedDescriptors)
            }

            Section("Substances") {
                DescriptorToggle("Alcohol Reference", descriptor: .alcoholReference, blocked: $blockedDescriptors)
                DescriptorToggle("Drug Reference", descriptor: .drugReference, blocked: $blockedDescriptors)
                DescriptorToggle("Tobacco Reference", descriptor: .tobaccoReference, blocked: $blockedDescriptors)
                DescriptorToggle("Use of Substances", descriptor: .useOfSubstances, blocked: $blockedDescriptors)
            }

            Section("Music-Specific") {
                DescriptorToggle("Explicit Lyrics", descriptor: .explicitLyrics, blocked: $blockedDescriptors)
                DescriptorToggle("Violent Lyrics", descriptor: .violentLyrics, blocked: $blockedDescriptors)
                DescriptorToggle("Sexual Lyrics", descriptor: .sexualLyrics, blocked: $blockedDescriptors)
                DescriptorToggle("Drug-Related Lyrics", descriptor: .drugLyrics, blocked: $blockedDescriptors)
            }

            Section("Safety") {
                DescriptorToggle("Flashing Lights", descriptor: .flashingLights, blocked: $blockedDescriptors)
                DescriptorToggle("Potentially Loud Sounds", descriptor: .loudSounds, blocked: $blockedDescriptors)
            }
        }
        .navigationTitle("Content Filters")
    }
}

private struct DescriptorToggle: View {
    let title: String
    let descriptor: ContentDescriptors
    @Binding var blocked: ContentDescriptors

    init(_ title: String, descriptor: ContentDescriptors, blocked: Binding<ContentDescriptors>) {
        self.title = title
        self.descriptor = descriptor
        self._blocked = blocked
    }

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { blocked.contains(descriptor) },
            set: { newValue in
                if newValue {
                    blocked.insert(descriptor)
                } else {
                    blocked.remove(descriptor)
                }
            }
        ))
    }
}

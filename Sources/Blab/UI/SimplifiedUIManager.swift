import Foundation
import SwiftUI
import Combine

/// Simplified UI Manager
/// Provides age-appropriate and skill-appropriate interfaces
///
/// User Profiles:
/// - Children (4-12): Playful, visual, guided
/// - Teens (13-17): Creative, social, exploratory
/// - Adults (18-64): Full-featured, professional
/// - Seniors (65+): Large text, simple controls, clear labels
/// - Beginners: Guided tutorials, limited options
/// - Advanced: All features, shortcuts, customization

// MARK: - User Profile

public enum UserProfile: String, CaseIterable, Codable {
    case child = "Child (4-12)"
    case teen = "Teen (13-17)"
    case adult = "Adult"
    case senior = "Senior (65+)"
    case beginner = "Beginner"
    case advanced = "Advanced"

    public var displayName: String {
        return rawValue
    }

    public var ageRange: ClosedRange<Int>? {
        switch self {
        case .child: return 4...12
        case .teen: return 13...17
        case .adult: return 18...64
        case .senior: return 65...120
        case .beginner, .advanced: return nil
        }
    }

    public var description: String {
        switch self {
        case .child:
            return "Playful, visual interface with parental controls"
        case .teen:
            return "Creative tools with social features"
        case .adult:
            return "Full-featured professional interface"
        case .senior:
            return "Large text, simple controls, clear instructions"
        case .beginner:
            return "Guided experience with tutorials"
        case .advanced:
            return "All features, shortcuts, customization"
        }
    }
}

// MARK: - UI Complexity Level

public enum UIComplexityLevel: String, CaseIterable, Codable {
    case minimal = "Minimal"
    case simple = "Simple"
    case standard = "Standard"
    case advanced = "Advanced"
    case expert = "Expert"

    public var visibleFeatureCount: Int {
        switch self {
        case .minimal: return 3
        case .simple: return 5
        case .standard: return 10
        case .advanced: return 20
        case .expert: return 100
        }
    }

    public var showAdvancedSettings: Bool {
        switch self {
        case .minimal, .simple: return false
        case .standard: return false
        case .advanced, .expert: return true
        }
    }
}

// MARK: - Simplified UI Configuration

public struct SimplifiedUIConfiguration: Codable {
    public var userProfile: UserProfile
    public var complexityLevel: UIComplexityLevel
    public var showTutorials: Bool
    public var showTooltips: Bool
    public var largeButtons: Bool
    public var animatedInstructions: Bool
    public var voiceGuidance: Bool
    public var parentalControlsEnabled: Bool
    public var sessionTimeLimit: Int? // minutes
    public var contentFilteringLevel: ContentFilteringLevel

    public init(
        userProfile: UserProfile = .adult,
        complexityLevel: UIComplexityLevel = .standard,
        showTutorials: Bool = true,
        showTooltips: Bool = true,
        largeButtons: Bool = false,
        animatedInstructions: Bool = false,
        voiceGuidance: Bool = false,
        parentalControlsEnabled: Bool = false,
        sessionTimeLimit: Int? = nil,
        contentFilteringLevel: ContentFilteringLevel = .none
    ) {
        self.userProfile = userProfile
        self.complexityLevel = complexityLevel
        self.showTutorials = showTutorials
        self.showTooltips = showTooltips
        self.largeButtons = largeButtons
        self.animatedInstructions = animatedInstructions
        self.voiceGuidance = voiceGuidance
        self.parentalControlsEnabled = parentalControlsEnabled
        self.sessionTimeLimit = sessionTimeLimit
        self.contentFilteringLevel = contentFilteringLevel
    }

    /// Auto-configure based on user profile
    public static func forProfile(_ profile: UserProfile) -> SimplifiedUIConfiguration {
        switch profile {
        case .child:
            return SimplifiedUIConfiguration(
                userProfile: .child,
                complexityLevel: .simple,
                showTutorials: true,
                showTooltips: true,
                largeButtons: true,
                animatedInstructions: true,
                voiceGuidance: true,
                parentalControlsEnabled: true,
                sessionTimeLimit: 30,
                contentFilteringLevel: .strict
            )

        case .teen:
            return SimplifiedUIConfiguration(
                userProfile: .teen,
                complexityLevel: .standard,
                showTutorials: true,
                showTooltips: true,
                largeButtons: false,
                animatedInstructions: false,
                voiceGuidance: false,
                parentalControlsEnabled: false,
                sessionTimeLimit: nil,
                contentFilteringLevel: .moderate
            )

        case .adult:
            return SimplifiedUIConfiguration(
                userProfile: .adult,
                complexityLevel: .advanced,
                showTutorials: false,
                showTooltips: false,
                largeButtons: false,
                animatedInstructions: false,
                voiceGuidance: false,
                parentalControlsEnabled: false,
                sessionTimeLimit: nil,
                contentFilteringLevel: .none
            )

        case .senior:
            return SimplifiedUIConfiguration(
                userProfile: .senior,
                complexityLevel: .simple,
                showTutorials: true,
                showTooltips: true,
                largeButtons: true,
                animatedInstructions: false,
                voiceGuidance: true,
                parentalControlsEnabled: false,
                sessionTimeLimit: nil,
                contentFilteringLevel: .none
            )

        case .beginner:
            return SimplifiedUIConfiguration(
                userProfile: .beginner,
                complexityLevel: .minimal,
                showTutorials: true,
                showTooltips: true,
                largeButtons: false,
                animatedInstructions: true,
                voiceGuidance: true,
                parentalControlsEnabled: false,
                sessionTimeLimit: nil,
                contentFilteringLevel: .none
            )

        case .advanced:
            return SimplifiedUIConfiguration(
                userProfile: .advanced,
                complexityLevel: .expert,
                showTutorials: false,
                showTooltips: false,
                largeButtons: false,
                animatedInstructions: false,
                voiceGuidance: false,
                parentalControlsEnabled: false,
                sessionTimeLimit: nil,
                contentFilteringLevel: .none
            )
        }
    }
}

public enum ContentFilteringLevel: String, CaseIterable, Codable {
    case none = "None"
    case moderate = "Moderate"
    case strict = "Strict"

    public var description: String {
        switch self {
        case .none: return "All content available"
        case .moderate: return "Filter mature content"
        case .strict: return "Child-safe content only"
        }
    }
}

// MARK: - Simplified UI Manager

@MainActor
public final class SimplifiedUIManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = SimplifiedUIManager()

    // MARK: - Published Properties

    @Published public var configuration: SimplifiedUIConfiguration
    @Published public var currentSessionDuration: TimeInterval = 0
    @Published public var onboardingComplete: Bool = false
    @Published public var tutorialProgress: [String: Bool] = [:]

    // MARK: - Private Properties

    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Available features per complexity level
    private let featuresByComplexity: [UIComplexityLevel: Set<String>] = [
        .minimal: ["play", "pause", "volume"],
        .simple: ["play", "pause", "volume", "visualizations", "presets"],
        .standard: ["play", "pause", "volume", "visualizations", "presets", "effects", "recording", "export", "biofeedback", "midi"],
        .advanced: ["play", "pause", "volume", "visualizations", "presets", "effects", "recording", "export", "biofeedback", "midi", "spatial-audio", "osc", "customization", "advanced-settings"],
        .expert: [] // All features
    }

    // MARK: - Initialization

    private init() {
        // Load saved configuration
        if let savedConfig = Self.loadConfiguration() {
            configuration = savedConfig
        } else {
            configuration = SimplifiedUIConfiguration.forProfile(.adult)
        }

        onboardingComplete = UserDefaults.standard.bool(forKey: "OnboardingComplete")
        tutorialProgress = (UserDefaults.standard.dictionary(forKey: "TutorialProgress") as? [String: Bool]) ?? [:]

        print("🎨 Simplified UI Manager initialized")
        print("   Profile: \(configuration.userProfile.displayName)")
        print("   Complexity: \(configuration.complexityLevel.rawValue)")
        print("   Parental Controls: \(configuration.parentalControlsEnabled ? "✅" : "❌")")
    }

    // MARK: - Configuration Management

    public func updateConfiguration(_ config: SimplifiedUIConfiguration) {
        configuration = config
        saveConfiguration()
        print("🎨 UI configuration updated to \(config.userProfile.displayName)")
    }

    public func setUserProfile(_ profile: UserProfile) {
        configuration = SimplifiedUIConfiguration.forProfile(profile)
        saveConfiguration()
        print("🎨 User profile set to: \(profile.displayName)")
    }

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: "SimplifiedUIConfiguration")
        }
    }

    private static func loadConfiguration() -> SimplifiedUIConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "SimplifiedUIConfiguration"),
              let config = try? JSONDecoder().decode(SimplifiedUIConfiguration.self, from: data) else {
            return nil
        }
        return config
    }

    // MARK: - Feature Availability

    /// Check if a feature is available at current complexity level
    public func isFeatureAvailable(_ featureName: String) -> Bool {
        if configuration.complexityLevel == .expert {
            return true // All features available
        }

        guard let features = featuresByComplexity[configuration.complexityLevel] else {
            return false
        }

        return features.contains(featureName)
    }

    /// Get list of available features
    public func availableFeatures() -> [String] {
        if configuration.complexityLevel == .expert {
            return Array(featuresByComplexity.values.flatMap { $0 })
        }

        return Array(featuresByComplexity[configuration.complexityLevel] ?? [])
    }

    // MARK: - Session Management

    public func startSession() {
        sessionStartTime = Date()
        currentSessionDuration = 0

        // Start timer for session duration tracking
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }

        print("▶️ Session started")
    }

    public func endSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil

        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("⏹️ Session ended (Duration: \(Int(duration / 60)) minutes)")
        }

        sessionStartTime = nil
        currentSessionDuration = 0
    }

    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else { return }

        currentSessionDuration = Date().timeIntervalSince(startTime)

        // Check time limit (if enabled)
        if let limit = configuration.sessionTimeLimit {
            let limitSeconds = TimeInterval(limit * 60)

            if currentSessionDuration >= limitSeconds {
                handleSessionTimeLimit()
            } else if currentSessionDuration >= limitSeconds - 300 { // 5 min warning
                notifyTimeWarning(remainingMinutes: 5)
            }
        }
    }

    private func handleSessionTimeLimit() {
        print("⏱️ Session time limit reached!")

        // Notify user
        AccessibilityManager.shared.announce(
            "Session time limit reached. Please take a break.",
            priority: .high
        )

        // Pause playback
        NotificationCenter.default.post(name: .sessionTimeLimitReached, object: nil)
    }

    private func notifyTimeWarning(remainingMinutes: Int) {
        AccessibilityManager.shared.announce(
            "\(remainingMinutes) minutes remaining in this session",
            priority: .default
        )
    }

    // MARK: - Tutorial Management

    public func markTutorialComplete(_ tutorialID: String) {
        tutorialProgress[tutorialID] = true
        UserDefaults.standard.set(tutorialProgress, forKey: "TutorialProgress")

        print("✅ Tutorial completed: \(tutorialID)")
    }

    public func isTutorialComplete(_ tutorialID: String) -> Bool {
        return tutorialProgress[tutorialID] ?? false
    }

    public func resetTutorials() {
        tutorialProgress.removeAll()
        UserDefaults.standard.removeObject(forKey: "TutorialProgress")
        print("🔄 Tutorials reset")
    }

    public func completeOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "OnboardingComplete")
        print("✅ Onboarding complete")
    }

    public func resetOnboarding() {
        onboardingComplete = false
        UserDefaults.standard.set(false, forKey: "OnboardingComplete")
        resetTutorials()
        print("🔄 Onboarding reset")
    }

    // MARK: - Parental Controls

    public func enableParentalControls(pin: String) {
        configuration.parentalControlsEnabled = true
        saveConfiguration()
        UserDefaults.standard.set(pin, forKey: "ParentalControlPIN")
        print("🔒 Parental controls enabled")
    }

    public func disableParentalControls(pin: String) -> Bool {
        guard let savedPIN = UserDefaults.standard.string(forKey: "ParentalControlPIN"),
              savedPIN == pin else {
            print("❌ Invalid PIN")
            return false
        }

        configuration.parentalControlsEnabled = false
        saveConfiguration()
        UserDefaults.standard.removeObject(forKey: "ParentalControlPIN")
        print("🔓 Parental controls disabled")
        return true
    }

    public func verifyParentalPIN(_ pin: String) -> Bool {
        guard let savedPIN = UserDefaults.standard.string(forKey: "ParentalControlPIN") else {
            return false
        }
        return savedPIN == pin
    }

    // MARK: - Content Filtering

    public func isContentAllowed(_ contentType: ContentType) -> Bool {
        switch configuration.contentFilteringLevel {
        case .none:
            return true

        case .moderate:
            return contentType.maturityLevel != .mature

        case .strict:
            return contentType.maturityLevel == .childSafe
        }
    }

    public enum ContentType {
        case visualization
        case audioEffect
        case preset
        case tutorial
        case socialFeature
        case export
        case advanced

        var maturityLevel: MaturityLevel {
            switch self {
            case .visualization, .preset, .tutorial:
                return .childSafe
            case .audioEffect, .export:
                return .general
            case .socialFeature, .advanced:
                return .mature
            }
        }
    }

    public enum MaturityLevel {
        case childSafe
        case general
        case mature
    }

    // MARK: - UI Helpers

    /// Get button size based on configuration
    public func buttonSize() -> CGFloat {
        if configuration.largeButtons {
            return 60
        }

        switch configuration.userProfile {
        case .child: return 55
        case .teen: return 50
        case .adult: return 44
        case .senior: return 60
        case .beginner: return 50
        case .advanced: return 40
        }
    }

    /// Get font size for body text
    public func bodyFontSize() -> CGFloat {
        switch configuration.userProfile {
        case .child: return 18
        case .teen: return 16
        case .adult: return 17
        case .senior: return 20
        case .beginner: return 17
        case .advanced: return 15
        }
    }

    /// Should show feature?
    public func shouldShowFeature(_ featureName: String) -> Bool {
        return isFeatureAvailable(featureName) && isContentAllowed(mapFeatureToContentType(featureName))
    }

    private func mapFeatureToContentType(_ featureName: String) -> ContentType {
        switch featureName {
        case "visualizations": return .visualization
        case "effects": return .audioEffect
        case "presets": return .preset
        case "export": return .export
        case "osc", "advanced-settings": return .advanced
        default: return .general
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let sessionTimeLimitReached = Notification.Name("SessionTimeLimitReached")
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Apply simplified UI adaptations
    public func simplifiedUI() -> some View {
        let manager = SimplifiedUIManager.shared
        let config = manager.configuration

        return self
            .font(.system(size: manager.bodyFontSize()))
    }

    /// Conditionally show based on complexity level
    public func showIf(feature: String) -> some View {
        self.opacity(SimplifiedUIManager.shared.shouldShowFeature(feature) ? 1 : 0)
    }
}

// MARK: - Profile Selection Helper

public struct UserProfileSelectorView: View {
    @ObservedObject private var uiManager = SimplifiedUIManager.shared
    @State private var selectedProfile: UserProfile = .adult

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Choose Your Profile")
                .font(.largeTitle)
                .bold()

            ForEach(UserProfile.allCases, id: \.self) { profile in
                Button(action: {
                    selectedProfile = profile
                    uiManager.setUserProfile(profile)
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(profile.displayName)
                            .font(.headline)

                        Text(profile.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(selectedProfile == profile ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

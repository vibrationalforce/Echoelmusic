/**
 * EchoelaEngine.swift
 * Echoelmusic - Inclusive Intelligent Guide System
 *
 * Echoela is a calm, non-judgmental guide that:
 * - Adapts to user skill level and confidence
 * - Detects confusion and offers help without pressure
 * - Supports all accessibility profiles
 * - Works across all platforms
 * - Is always optional and dismissible
 *
 * Design Principles:
 * - Calm, warm, professional
 * - No dark patterns, no urgency, no gamification pressure
 * - Learning by doing
 * - Reversible actions
 * - Simple language with optional depth
 *
 * Created: 2026-01-15
 */

import Foundation
import Combine
import SwiftUI

// MARK: - Echoela Engine

/// Core engine for the Echoela inclusive guide system
@MainActor
public final class EchoelaEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaEngine()

    // MARK: - Published State

    /// Whether Echoela is currently active
    @Published public var isActive: Bool = false

    /// Current guidance context
    @Published public var currentContext: GuidanceContext?

    /// User's current skill level (0-1, adaptive)
    @Published public var skillLevel: Float = 0.5

    /// User's confidence score (0-1, adaptive)
    @Published public var confidenceScore: Float = 0.5

    /// Guidance density (0=minimal, 1=detailed)
    @Published public var guidanceDensity: Float = 0.5

    /// Current hint if any
    @Published public var currentHint: GuidanceHint?

    /// Whether user seems confused (detected)
    @Published public var userSeemsConfused: Bool = false

    /// Pending offer to help
    @Published public var pendingHelpOffer: HelpOffer?

    /// Completed topics for progress tracking
    @Published public var completedTopics: Set<GuidanceTopic> = []

    /// User preferences
    @Published public var preferences: EchoelaPreferences

    // MARK: - Private State

    private var interactionHistory: [InteractionEvent] = []
    private var hesitationTimer: Timer?
    private var lastInteractionTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private let hesitationThreshold: TimeInterval = 5.0  // Seconds before detecting hesitation
    private let confusionThreshold: Int = 3  // Repeated errors before offering help
    private let maxHistorySize: Int = 100

    // MARK: - Initialization

    private init() {
        self.preferences = EchoelaPreferences.load()
        loadProgress()
        setupObservers()

        log.info("✨ Echoela: Initialized - Ready to guide", category: .accessibility)
    }

    // MARK: - Setup

    private func setupObservers() {
        // Monitor for app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.saveProgress()
            }
            .store(in: &cancellables)
    }

    // MARK: - Activation

    /// Activate Echoela guidance
    public func activate() {
        guard preferences.isEnabled else { return }

        isActive = true
        startHesitationMonitoring()

        log.info("✨ Echoela: Activated", category: .accessibility)

        // Gentle welcome if first time
        if !preferences.hasSeenWelcome {
            showWelcome()
        }
    }

    /// Deactivate Echoela (always allowed)
    public func deactivate() {
        isActive = false
        currentHint = nil
        pendingHelpOffer = nil
        hesitationTimer?.invalidate()

        log.info("✨ Echoela: Deactivated (user choice)", category: .accessibility)
    }

    /// Temporarily pause guidance
    public func pause() {
        isActive = false
        hesitationTimer?.invalidate()
    }

    /// Resume guidance
    public func resume() {
        if preferences.isEnabled {
            isActive = true
            startHesitationMonitoring()
        }
    }

    // MARK: - Context Management

    /// Enter a new guidance context
    public func enterContext(_ context: GuidanceContext) {
        currentContext = context

        // Offer contextual hint if appropriate
        if shouldOfferHint(for: context) {
            offerContextualHint(for: context)
        }

        log.info("✨ Echoela: Entered context '\(context.id)'", category: .accessibility)
    }

    /// Exit current context
    public func exitContext() {
        currentContext = nil
        currentHint = nil
    }

    // MARK: - Interaction Tracking

    /// Record a user interaction
    public func recordInteraction(_ event: InteractionEvent) {
        lastInteractionTime = Date()
        userSeemsConfused = false

        // Add to history
        interactionHistory.append(event)
        if interactionHistory.count > maxHistorySize {
            interactionHistory.removeFirst()
        }

        // Analyze for patterns
        analyzeInteractionPatterns()

        // Update skill level based on success
        if event.wasSuccessful {
            adjustSkillLevel(by: 0.01)
            adjustConfidence(by: 0.02)
        } else {
            adjustConfidence(by: -0.01)
        }
    }

    /// Record an error
    public func recordError(_ error: UserError) {
        let event = InteractionEvent(
            type: .error,
            context: currentContext,
            wasSuccessful: false,
            errorType: error
        )
        recordInteraction(event)

        // Check if user needs help
        checkForConfusion()
    }

    // MARK: - Adaptive Guidance

    private func analyzeInteractionPatterns() {
        // Look for repeated errors
        let recentErrors = interactionHistory.suffix(10).filter { $0.errorType != nil }

        if recentErrors.count >= confusionThreshold {
            // User may be confused - offer gentle help
            userSeemsConfused = true
            offerHelp(reason: .repeatedErrors)
        }

        // Adjust guidance density based on skill
        if skillLevel > 0.7 {
            guidanceDensity = max(0.2, guidanceDensity - 0.1)
        } else if skillLevel < 0.3 {
            guidanceDensity = min(0.8, guidanceDensity + 0.1)
        }
    }

    private func adjustSkillLevel(by delta: Float) {
        skillLevel = max(0, min(1, skillLevel + delta))
    }

    private func adjustConfidence(by delta: Float) {
        confidenceScore = max(0, min(1, confidenceScore + delta))
    }

    // MARK: - Hesitation Detection

    private func startHesitationMonitoring() {
        hesitationTimer?.invalidate()
        hesitationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForHesitation()
            }
        }
    }

    private func checkForHesitation() {
        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)

        if timeSinceLastInteraction > hesitationThreshold && currentContext != nil {
            // User hasn't interacted for a while - they might be stuck
            if pendingHelpOffer == nil && !userSeemsConfused {
                offerHelp(reason: .hesitation)
            }
        }
    }

    private func checkForConfusion() {
        // Count recent errors in current context
        let recentContextErrors = interactionHistory.suffix(5).filter {
            $0.context?.id == currentContext?.id && $0.errorType != nil
        }

        if recentContextErrors.count >= 2 {
            userSeemsConfused = true
            offerHelp(reason: .repeatedErrors)
        }
    }

    // MARK: - Help Offers

    private func offerHelp(reason: HelpOfferReason) {
        guard preferences.isEnabled && isActive else { return }
        guard pendingHelpOffer == nil else { return }  // Don't stack offers

        let offer = HelpOffer(
            reason: reason,
            context: currentContext,
            message: generateHelpMessage(for: reason),
            dismissable: true,
            timestamp: Date()
        )

        pendingHelpOffer = offer

        log.info("✨ Echoela: Offering help - \(reason)", category: .accessibility)
    }

    private func generateHelpMessage(for reason: HelpOfferReason) -> String {
        switch reason {
        case .hesitation:
            return selectCalmMessage([
                "Take your time. Would you like some guidance?",
                "No rush. I'm here if you need a hint.",
                "Whenever you're ready. Need any help?"
            ])
        case .repeatedErrors:
            return selectCalmMessage([
                "That can be tricky. Would you like me to explain?",
                "Let me help clarify this for you.",
                "This part takes practice. Want some tips?"
            ])
        case .firstTime:
            return selectCalmMessage([
                "This is new. Would you like a quick overview?",
                "First time here? I can show you around.",
                "Let me introduce you to this feature."
            ])
        case .userRequested:
            return "How can I help you?"
        }
    }

    private func selectCalmMessage(_ messages: [String]) -> String {
        messages.randomElement() ?? messages[0]
    }

    /// Accept help offer
    public func acceptHelp() {
        guard let offer = pendingHelpOffer else { return }

        // Show relevant guidance
        if let context = offer.context {
            showGuidance(for: context)
        } else {
            showGeneralHelp()
        }

        pendingHelpOffer = nil

        log.info("✨ Echoela: Help accepted", category: .accessibility)
    }

    /// Dismiss help offer (always allowed, no judgment)
    public func dismissHelp() {
        pendingHelpOffer = nil
        userSeemsConfused = false
        lastInteractionTime = Date()  // Reset hesitation timer

        log.info("✨ Echoela: Help dismissed (user choice - respected)", category: .accessibility)
    }

    // MARK: - Hints

    private func shouldOfferHint(for context: GuidanceContext) -> Bool {
        // Don't offer hints if user is skilled in this area
        if completedTopics.contains(context.topic) && skillLevel > 0.6 {
            return false
        }

        // Don't overwhelm
        if guidanceDensity < 0.3 {
            return false
        }

        return preferences.showHints
    }

    private func offerContextualHint(for context: GuidanceContext) {
        guard let hint = context.hints.first else { return }

        currentHint = hint

        // Auto-dismiss after a delay if user doesn't interact
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.currentHint?.id == hint.id {
                self?.currentHint = nil
            }
        }
    }

    /// Dismiss current hint
    public func dismissHint() {
        currentHint = nil
    }

    /// Request more detail on current hint
    public func expandHint() {
        guard let hint = currentHint else { return }
        currentHint = GuidanceHint(
            id: hint.id,
            shortText: hint.shortText,
            detailedText: hint.detailedText,
            isExpanded: true,
            relatedTopics: hint.relatedTopics
        )
    }

    // MARK: - Guidance Flows

    private func showWelcome() {
        let welcomeContext = GuidanceContext(
            id: "echoela_welcome",
            topic: .welcome,
            title: "Hello, I'm Echoela",
            description: "I'm here to help you explore Echoelmusic at your own pace. I'll offer gentle guidance when you might need it, but you're always in control. You can dismiss me anytime.",
            hints: [],
            steps: [
                GuidanceStep(
                    title: "I'm Optional",
                    description: "You can turn me off in Settings anytime. No pressure.",
                    action: nil
                ),
                GuidanceStep(
                    title: "I Learn Your Style",
                    description: "I'll adapt to how you use the app. More help when you're learning, less when you're confident.",
                    action: nil
                ),
                GuidanceStep(
                    title: "I Never Rush You",
                    description: "Take all the time you need. There are no timers or scores.",
                    action: nil
                )
            ]
        )

        currentContext = welcomeContext
        preferences.hasSeenWelcome = true
        preferences.save()
    }

    private func showGuidance(for context: GuidanceContext) {
        currentContext = context

        // Mark topic as in-progress
        // Will be marked complete when user finishes
    }

    private func showGeneralHelp() {
        let helpContext = GuidanceContext(
            id: "general_help",
            topic: .generalHelp,
            title: "How Can I Help?",
            description: "Choose what you'd like to learn about.",
            hints: [],
            steps: []
        )
        currentContext = helpContext
    }

    // MARK: - Topic Completion

    /// Mark a topic as complete
    public func completeTopic(_ topic: GuidanceTopic) {
        completedTopics.insert(topic)

        // Gentle encouragement (not gamification)
        log.info("✨ Echoela: Topic '\(topic)' explored", category: .accessibility)

        saveProgress()
    }

    /// Check if topic is complete
    public func isTopicComplete(_ topic: GuidanceTopic) -> Bool {
        completedTopics.contains(topic)
    }

    // MARK: - Persistence

    private func saveProgress() {
        let data = EchoelaProgress(
            skillLevel: skillLevel,
            confidenceScore: confidenceScore,
            guidanceDensity: guidanceDensity,
            completedTopics: Array(completedTopics)
        )

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "echoela_progress")
        }
    }

    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: "echoela_progress"),
              let progress = try? JSONDecoder().decode(EchoelaProgress.self, from: data) else {
            return
        }

        skillLevel = progress.skillLevel
        confidenceScore = progress.confidenceScore
        guidanceDensity = progress.guidanceDensity
        completedTopics = Set(progress.completedTopics)
    }

    // MARK: - Accessibility Integration

    /// Announce message for VoiceOver
    public func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Get appropriate font size based on user preferences
    public var preferredFontSize: CGFloat {
        switch preferences.textSize {
        case .small: return 14
        case .medium: return 17
        case .large: return 21
        case .extraLarge: return 28
        }
    }
}

// MARK: - Data Types

/// A guidance context (where user is in the app)
public struct GuidanceContext: Identifiable, Equatable {
    public let id: String
    public let topic: GuidanceTopic
    public let title: String
    public let description: String
    public let hints: [GuidanceHint]
    public let steps: [GuidanceStep]

    public static func == (lhs: GuidanceContext, rhs: GuidanceContext) -> Bool {
        lhs.id == rhs.id
    }
}

/// A guidance topic category
public enum GuidanceTopic: String, Codable, CaseIterable {
    case welcome = "Welcome"
    case generalHelp = "General Help"
    case audioBasics = "Audio Basics"
    case biofeedback = "Biofeedback"
    case visualizer = "Visualizer"
    case presets = "Presets"
    case recording = "Recording"
    case streaming = "Streaming"
    case accessibility = "Accessibility"
    case settings = "Settings"
    case collaboration = "Collaboration"
    case wellness = "Wellness"
}

/// A hint shown in context
public struct GuidanceHint: Identifiable {
    public let id: String
    public let shortText: String
    public let detailedText: String
    public var isExpanded: Bool = false
    public let relatedTopics: [GuidanceTopic]

    public init(id: String = UUID().uuidString, shortText: String, detailedText: String, isExpanded: Bool = false, relatedTopics: [GuidanceTopic] = []) {
        self.id = id
        self.shortText = shortText
        self.detailedText = detailedText
        self.isExpanded = isExpanded
        self.relatedTopics = relatedTopics
    }
}

/// A step in a guided flow
public struct GuidanceStep: Identifiable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let action: (() -> Void)?
}

/// Help offer from Echoela
public struct HelpOffer: Identifiable {
    public let id = UUID()
    public let reason: HelpOfferReason
    public let context: GuidanceContext?
    public let message: String
    public let dismissable: Bool
    public let timestamp: Date
}

/// Reason for offering help
public enum HelpOfferReason {
    case hesitation
    case repeatedErrors
    case firstTime
    case userRequested
}

/// User error types
public enum UserError: String {
    case navigationError
    case inputError
    case permissionError
    case configurationError
    case unknown
}

/// Interaction event for analytics
public struct InteractionEvent {
    public let type: InteractionType
    public let context: GuidanceContext?
    public let wasSuccessful: Bool
    public let errorType: UserError?
    public let timestamp: Date = Date()

    public enum InteractionType {
        case tap
        case gesture
        case voice
        case navigation
        case error
        case completion
    }
}

/// Progress data for persistence
private struct EchoelaProgress: Codable {
    let skillLevel: Float
    let confidenceScore: Float
    let guidanceDensity: Float
    let completedTopics: [GuidanceTopic]
}

// MARK: - Preferences

/// User preferences for Echoela
public struct EchoelaPreferences: Codable {
    public var isEnabled: Bool = true
    public var showHints: Bool = true
    public var hasSeenWelcome: Bool = false
    public var textSize: TextSize = .medium
    public var useCalmColors: Bool = false
    public var reduceAnimations: Bool = false
    public var voiceGuidance: Bool = false

    public enum TextSize: String, Codable, CaseIterable {
        case small, medium, large, extraLarge
    }

    public static func load() -> EchoelaPreferences {
        guard let data = UserDefaults.standard.data(forKey: "echoela_preferences"),
              let prefs = try? JSONDecoder().decode(EchoelaPreferences.self, from: data) else {
            return EchoelaPreferences()
        }
        return prefs
    }

    public func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "echoela_preferences")
        }
    }
}

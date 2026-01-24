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
 * - Has an adjustable personality (warm, playful, professional)
 * - Playfully peeks from behind UI elements
 * - Auto-hides during Live Performance mode
 * - Learns user thinking patterns and adapts
 * - Collects feedback for future updates
 *
 * Design Principles:
 * - Calm, warm, professional
 * - No dark patterns, no urgency, no gamification pressure
 * - Learning by doing
 * - Reversible actions
 * - Simple language with optional depth
 * - Pleasant atmospheric voice
 * - Subtle, non-intrusive presence
 *
 * Created: 2026-01-15
 */

import Foundation
import Combine
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Echoela Personality

/// Echoela's adjustable personality traits
public struct EchoelaPersonality: Codable, Equatable {
    /// Warmth level (0 = neutral, 1 = very warm)
    public var warmth: Float = 0.7

    /// Playfulness level (0 = serious, 1 = playful/cheeky)
    public var playfulness: Float = 0.5

    /// Formality level (0 = casual, 1 = formal)
    public var formality: Float = 0.3

    /// Verbosity level (0 = brief, 1 = detailed)
    public var verbosity: Float = 0.5

    /// Encouragement level (0 = minimal, 1 = frequent)
    public var encouragement: Float = 0.6

    /// Voice pitch (0.5 = low, 1.0 = normal, 1.5 = high)
    public var voicePitch: Float = 1.0

    /// Voice speed (0.5 = slow, 1.0 = normal, 1.5 = fast)
    public var voiceSpeed: Float = 0.9

    public static let warm = EchoelaPersonality(warmth: 0.9, playfulness: 0.3, formality: 0.2, verbosity: 0.5, encouragement: 0.8, voicePitch: 1.0, voiceSpeed: 0.85)
    public static let playful = EchoelaPersonality(warmth: 0.7, playfulness: 0.9, formality: 0.1, verbosity: 0.6, encouragement: 0.7, voicePitch: 1.1, voiceSpeed: 1.0)
    public static let professional = EchoelaPersonality(warmth: 0.5, playfulness: 0.2, formality: 0.8, verbosity: 0.7, encouragement: 0.4, voicePitch: 0.95, voiceSpeed: 0.95)
    public static let minimal = EchoelaPersonality(warmth: 0.4, playfulness: 0.1, formality: 0.5, verbosity: 0.2, encouragement: 0.2, voicePitch: 1.0, voiceSpeed: 1.0)
    public static let empathetic = EchoelaPersonality(warmth: 1.0, playfulness: 0.4, formality: 0.2, verbosity: 0.6, encouragement: 0.9, voicePitch: 0.95, voiceSpeed: 0.8)
}

// MARK: - Echoela Visual State

/// Visual state for Echoela's peek animation
public struct EchoelaPeekState: Equatable {
    /// Which edge Echoela is peeking from
    public var peekEdge: PeekEdge = .bottomTrailing

    /// How much Echoela is visible (0 = hidden, 1 = fully shown)
    public var visibility: Float = 0.0

    /// Current animation phase
    public var animationPhase: PeekAnimationPhase = .hidden

    /// Subtle background tint color (soft, atmospheric)
    public var backgroundTint: Color = Color(red: 0.4, green: 0.5, blue: 0.9).opacity(0.1)

    public enum PeekEdge: String, Codable {
        case bottomLeading, bottomTrailing, topLeading, topTrailing
        case bottom, trailing, leading
    }

    public enum PeekAnimationPhase {
        case hidden
        case peeking      // Playfully peeking out
        case appearing    // Sliding in
        case visible      // Fully visible
        case explaining   // Actively helping
        case retreating   // Sliding back
    }
}

// MARK: - User Learning Profile

/// Learned patterns about how a user thinks and works
public struct UserLearningProfile: Codable {
    /// Preferred learning style
    public var learningStyle: LearningStyle = .visual

    /// Preferred pace
    public var pacePReference: Pace = .moderate

    /// Times of day user is most active
    public var activeHours: [Int] = []

    /// Features user gravitates toward
    public var favoriteFeatures: [String] = []

    /// Areas user struggles with
    public var challengeAreas: [String] = []

    /// Typical session duration (seconds)
    public var avgSessionDuration: TimeInterval = 300

    /// How user responds to help offers
    public var helpAcceptanceRate: Float = 0.5

    /// Interaction patterns (e.g., "prefers-gestures", "uses-voice")
    public var interactionPatterns: [String: Float] = [:]

    /// Last updated timestamp
    public var lastUpdated: Date = Date()

    public enum LearningStyle: String, Codable {
        case visual    // Prefers seeing/watching
        case auditory  // Prefers hearing/voice
        case kinesthetic // Prefers doing/trying
        case reading   // Prefers text/documentation
    }

    public enum Pace: String, Codable {
        case slow     // Takes time, thorough
        case moderate // Balanced
        case fast     // Quick, skips details
    }
}

// MARK: - User Feedback

/// User feedback entry for repo updates
public struct EchoelaFeedback: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let feedbackType: FeedbackType
    public let context: String
    public let message: String
    public let rating: Int?  // 1-5 stars, optional
    public let suggestion: String?
    public let systemInfo: SystemInfo

    public enum FeedbackType: String, Codable {
        case suggestion
        case issue
        case praise
        case confusion
        case featureRequest
        case accessibility
    }

    public struct SystemInfo: Codable {
        public let skillLevel: Float
        public let guidanceDensity: Float
        public let personality: String
        public let sessionCount: Int
    }

    public init(type: FeedbackType, context: String, message: String, rating: Int? = nil, suggestion: String? = nil, skillLevel: Float, guidanceDensity: Float, personality: String, sessionCount: Int) {
        self.id = UUID()
        self.timestamp = Date()
        self.feedbackType = type
        self.context = context
        self.message = message
        self.rating = rating
        self.suggestion = suggestion
        self.systemInfo = SystemInfo(skillLevel: skillLevel, guidanceDensity: guidanceDensity, personality: personality, sessionCount: sessionCount)
    }
}

// MARK: - Echoela Engine

/// Core engine for the Echoela inclusive guide system
@MainActor
public final class EchoelaEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaEngine()

    // MARK: - Localization

    /// Localization manager for multi-language support
    public let localization = EchoelaLocalizationManager.shared

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

    // MARK: - Personality & Visual State (NEW)

    /// Echoela's current personality
    @Published public var personality: EchoelaPersonality = .warm

    /// Visual peek state for playful animations
    @Published public var peekState: EchoelaPeekState = EchoelaPeekState()

    /// Whether in Live Performance mode (Echoela auto-hides)
    @Published public var isLivePerformanceMode: Bool = false

    /// Learned user profile
    @Published public var userProfile: UserLearningProfile = UserLearningProfile()

    /// Collected feedback awaiting sync
    @Published public var pendingFeedback: [EchoelaFeedback] = []

    /// Session count for learning
    @Published public var sessionCount: Int = 0

    /// Whether Echoela is currently speaking
    @Published public var isSpeaking: Bool = false

    // MARK: - Private State

    private var interactionHistory: [InteractionEvent] = []
    private var hesitationTimer: Timer?
    private var lastInteractionTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date = Date()
    private var peekAnimationTimer: Timer?
    private var voiceSynthesizer: AVSpeechSynthesizer?

    // MARK: - Privacy & Consent State

    /// User consent for learning profile storage
    @AppStorage("echoela_consent_learning") private var hasLearningConsent: Bool = false

    /// User consent for feedback collection
    @AppStorage("echoela_consent_feedback") private var hasFeedbackConsent: Bool = false

    /// User consent for voice processing
    @AppStorage("echoela_consent_voice") private var hasVoiceConsent: Bool = false

    /// User consent for analytics
    @AppStorage("echoela_consent_analytics") private var hasAnalyticsConsent: Bool = false

    /// Overall consent status
    @AppStorage("echoela_has_consented") private var hasConsented: Bool = false

    // MARK: - Constants

    private let hesitationThreshold: TimeInterval = 5.0  // Seconds before detecting hesitation
    private let confusionThreshold: Int = 3  // Repeated errors before offering help
    private let maxHistorySize: Int = 100
    private let feedbackStorageKey = "echoela_feedback_queue"
    private let userProfileKey = "echoela_user_profile"
    private let personalityKey = "echoela_personality"

    // MARK: - Initialization

    private init() {
        self.preferences = EchoelaPreferences.load()
        loadProgress()
        loadPersonality()
        loadUserProfile()
        loadPendingFeedback()
        setupObservers()
        setupVoiceSynthesizer()

        log.info("✨ Echoela: Initialized - Ready to guide with \(personality == .playful ? "playful" : "warm") personality", category: .accessibility)
    }

    private func setupVoiceSynthesizer() {
        #if canImport(AVFoundation) && !os(watchOS)
        voiceSynthesizer = AVSpeechSynthesizer()
        #endif
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
                localization.string(for: .helpHesitation1),
                localization.string(for: .helpHesitation2),
                localization.string(for: .helpHesitation3)
            ])
        case .repeatedErrors:
            return selectCalmMessage([
                localization.string(for: .helpRepeatedErrors1),
                localization.string(for: .helpRepeatedErrors2),
                localization.string(for: .helpRepeatedErrors3)
            ])
        case .firstTime:
            return selectCalmMessage([
                localization.string(for: .helpFirstTime1),
                localization.string(for: .helpFirstTime2),
                localization.string(for: .helpFirstTime3)
            ])
        case .userRequested:
            return localization.string(for: .helpUserRequested)
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
            title: localization.string(for: .welcomeTitle),
            description: localization.string(for: .welcomeDescription),
            hints: [],
            steps: [
                GuidanceStep(
                    title: localization.string(for: .welcomeOptional),
                    description: localization.string(for: .welcomeOptionalDesc),
                    action: nil
                ),
                GuidanceStep(
                    title: localization.string(for: .welcomeLearnStyle),
                    description: localization.string(for: .welcomeLearnStyleDesc),
                    action: nil
                ),
                GuidanceStep(
                    title: localization.string(for: .welcomeNoRush),
                    description: localization.string(for: .welcomeNoRushDesc),
                    action: nil
                ),
                GuidanceStep(
                    title: localization.string(for: .welcomeAskAnytime),
                    description: localization.string(for: .welcomeAskAnytimeDesc),
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

    // MARK: - Personality System

    /// Set Echoela's personality
    public func setPersonality(_ newPersonality: EchoelaPersonality) {
        personality = newPersonality
        savePersonality()

        log.info("✨ Echoela: Personality updated to warmth=\(newPersonality.warmth), playfulness=\(newPersonality.playfulness)", category: .accessibility)
    }

    /// Apply a preset personality
    public func applyPersonalityPreset(_ preset: PersonalityPreset) {
        switch preset {
        case .warm: personality = .warm
        case .playful: personality = .playful
        case .professional: personality = .professional
        case .minimal: personality = .minimal
        case .empathetic: personality = .empathetic
        }
        savePersonality()
    }

    public enum PersonalityPreset: String, CaseIterable {
        case warm = "Warm & Friendly"
        case playful = "Playful & Cheeky"
        case professional = "Professional"
        case minimal = "Minimal"
        case empathetic = "Empathetic"
    }

    private func savePersonality() {
        if let encoded = try? JSONEncoder().encode(personality) {
            UserDefaults.standard.set(encoded, forKey: personalityKey)
        }
    }

    private func loadPersonality() {
        guard let data = UserDefaults.standard.data(forKey: personalityKey),
              let loaded = try? JSONDecoder().decode(EchoelaPersonality.self, from: data) else {
            return
        }
        personality = loaded
    }

    // MARK: - Peek Animation System

    /// Trigger Echoela to playfully peek from behind a tool
    public func peekFromEdge(_ edge: EchoelaPeekState.PeekEdge, withMessage message: String? = nil) {
        guard !isLivePerformanceMode else { return }  // Never interrupt live performance

        peekState.peekEdge = edge
        peekState.animationPhase = .peeking

        // Animate visibility
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            peekState.visibility = 0.3  // Just peeking
        }

        // After a playful peek, decide whether to fully appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.peekState.animationPhase == .peeking {
                if self.shouldFullyAppear() {
                    self.fullyAppear(withMessage: message)
                } else {
                    self.retreatQuietly()
                }
            }
        }
    }

    private func shouldFullyAppear() -> Bool {
        // Appear if user seems to need help or is hesitating
        return userSeemsConfused || (Date().timeIntervalSince(lastInteractionTime) > 3.0)
    }

    private func fullyAppear(withMessage message: String?) {
        peekState.animationPhase = .appearing

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            peekState.visibility = 1.0
            peekState.animationPhase = .visible
        }

        if let message = message {
            if personality.playfulness > 0.5 {
                // Playful message with a twist
                offerHelp(reason: .userRequested)
            } else {
                // Calm, straightforward
                offerHelp(reason: .hesitation)
            }
        }
    }

    /// Retreat quietly without fanfare
    public func retreatQuietly() {
        peekState.animationPhase = .retreating

        withAnimation(.easeOut(duration: 0.5)) {
            peekState.visibility = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.peekState.animationPhase = .hidden
        }
    }

    /// Get personality-adjusted message
    public func personalizedMessage(_ baseMessage: String) -> String {
        var message = baseMessage

        // Add warmth
        if personality.warmth > 0.7 {
            let warmPrefixes = ["Hey there! ", "Hi! ", "Hello! ", ""]
            message = (warmPrefixes.randomElement() ?? "") + message
        }

        // Add playfulness
        if personality.playfulness > 0.7 {
            let playfulSuffixes = [" 😊", " ✨", " 💡", ""]
            message += playfulSuffixes.randomElement() ?? ""
        }

        // Adjust verbosity
        if personality.verbosity < 0.3 && message.count > 50 {
            // Shorten for minimal personality
            message = String(message.prefix(50)) + "..."
        }

        return message
    }

    // MARK: - Live Performance Mode

    /// Enter Live Performance mode (Echoela auto-hides)
    public func enterLivePerformanceMode() {
        isLivePerformanceMode = true

        // Gracefully retreat
        retreatQuietly()
        currentHint = nil
        pendingHelpOffer = nil

        log.info("✨ Echoela: Entering Live Performance mode - stepping back", category: .accessibility)
    }

    /// Exit Live Performance mode
    public func exitLivePerformanceMode() {
        isLivePerformanceMode = false

        // Gently return if enabled
        if preferences.isEnabled && isActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.peekFromEdge(.bottomTrailing, withMessage: nil)
            }
        }

        log.info("✨ Echoela: Exiting Live Performance mode - available again", category: .accessibility)
    }

    /// Check if should auto-hide based on context
    public func checkLivePerformanceContext(_ context: String) {
        let liveContexts = ["streaming", "recording", "performance", "concert", "live", "broadcast"]
        let shouldHide = liveContexts.contains { context.lowercased().contains($0) }

        if shouldHide && !isLivePerformanceMode {
            enterLivePerformanceMode()
        } else if !shouldHide && isLivePerformanceMode {
            exitLivePerformanceMode()
        }
    }

    // MARK: - User Learning System

    /// Update user profile based on interaction
    public func learnFromInteraction(_ event: InteractionEvent) {
        // Track interaction patterns
        let patternKey = event.type.rawValue
        let currentValue = userProfile.interactionPatterns[patternKey] ?? 0.0
        userProfile.interactionPatterns[patternKey] = min(1.0, currentValue + 0.1)

        // Detect learning style
        switch event.type {
        case .gesture:
            userProfile.learningStyle = .kinesthetic
        case .voice:
            userProfile.learningStyle = .auditory
        case .tap, .navigation:
            // Visual learners tend to explore UI
            if userProfile.interactionPatterns["navigation"] ?? 0 > 0.5 {
                userProfile.learningStyle = .visual
            }
        default:
            break
        }

        // Track feature usage
        if let contextId = event.context?.id, event.wasSuccessful {
            if !userProfile.favoriteFeatures.contains(contextId) {
                userProfile.favoriteFeatures.append(contextId)
                if userProfile.favoriteFeatures.count > 10 {
                    userProfile.favoriteFeatures.removeFirst()
                }
            }
        }

        // Track struggle areas
        if let contextId = event.context?.id, event.errorType != nil {
            if !userProfile.challengeAreas.contains(contextId) {
                userProfile.challengeAreas.append(contextId)
                if userProfile.challengeAreas.count > 5 {
                    userProfile.challengeAreas.removeFirst()
                }
            }
        }

        // Detect pace
        let avgInteractionTime = Date().timeIntervalSince(lastInteractionTime)
        if avgInteractionTime < 1.0 {
            userProfile.pacePReference = .fast
        } else if avgInteractionTime > 5.0 {
            userProfile.pacePReference = .slow
        } else {
            userProfile.pacePReference = .moderate
        }

        userProfile.lastUpdated = Date()
        saveUserProfile()
    }

    /// Track help acceptance rate
    public func trackHelpAcceptance(accepted: Bool) {
        let weight: Float = 0.1
        userProfile.helpAcceptanceRate = userProfile.helpAcceptanceRate * (1 - weight) + (accepted ? 1.0 : 0.0) * weight
        saveUserProfile()
    }

    private func saveUserProfile() {
        // Only save user profile if consent is given for learning
        guard hasLearningConsent else {
            log.info("✨ Echoela: Skipping profile save - no consent for learning", category: .accessibility)
            return
        }

        if let encoded = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encoded, forKey: userProfileKey)
        }
    }

    private func loadUserProfile() {
        guard let data = UserDefaults.standard.data(forKey: userProfileKey),
              let loaded = try? JSONDecoder().decode(UserLearningProfile.self, from: data) else {
            return
        }
        userProfile = loaded
    }

    /// Adapt to user's learning style
    public func adaptToUser() {
        // Adjust guidance density based on help acceptance
        if userProfile.helpAcceptanceRate < 0.3 {
            guidanceDensity = max(0.1, guidanceDensity - 0.1)
        } else if userProfile.helpAcceptanceRate > 0.7 {
            guidanceDensity = min(0.9, guidanceDensity + 0.1)
        }

        // Adjust personality based on interaction patterns
        if userProfile.interactionPatterns["gesture"] ?? 0 > 0.5 {
            // User prefers gestures - be more playful
            personality.playfulness = min(1.0, personality.playfulness + 0.1)
        }

        if userProfile.pacePReference == .fast {
            // User is fast - be more brief
            personality.verbosity = max(0.2, personality.verbosity - 0.1)
        }

        savePersonality()
        saveProgress()
    }

    // MARK: - Voice Guidance (Atmospheric)

    /// Speak with Echoela's atmospheric voice
    /// Respects user's voice processing consent
    public func speak(_ text: String) {
        guard preferences.voiceGuidance else { return }
        guard !isLivePerformanceMode else { return }
        guard hasVoiceConsent else {
            log.info("✨ Echoela: Voice guidance disabled - no consent for voice processing", category: .accessibility)
            return
        }

        #if canImport(AVFoundation) && !os(watchOS)
        let utterance = AVSpeechUtterance(string: personalizedMessage(text))

        // Atmospheric voice settings
        utterance.rate = personality.voiceSpeed * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = personality.voicePitch
        utterance.volume = 0.8  // Slightly softer for atmosphere
        utterance.preUtteranceDelay = 0.3  // Gentle pause before speaking

        // Use voice matching user's language preference
        let languageCode = localization.currentLanguage.speechLanguageCode
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }

        isSpeaking = true
        voiceSynthesizer?.speak(utterance)

        // Track when finished
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.06) { [weak self] in
            self?.isSpeaking = false
        }
        #endif
    }

    /// Stop speaking
    public func stopSpeaking() {
        #if canImport(AVFoundation) && !os(watchOS)
        voiceSynthesizer?.stopSpeaking(at: .immediate)
        isSpeaking = false
        #endif
    }

    // MARK: - Feedback System

    /// Submit user feedback (stored for repo updates)
    /// Requires user consent for feedback collection
    public func submitFeedback(
        type: EchoelaFeedback.FeedbackType,
        context: String,
        message: String,
        rating: Int? = nil,
        suggestion: String? = nil
    ) {
        // Check consent for feedback
        guard hasFeedbackConsent else {
            log.info("✨ Echoela: Feedback not stored - no consent for feedback collection", category: .accessibility)
            // Still thank the user but don't store
            if personality.warmth > 0.5 {
                speak("Thank you for sharing. To store feedback for improvements, please enable feedback in privacy settings.")
            }
            return
        }

        let feedback = EchoelaFeedback(
            type: type,
            context: context,
            message: message,
            rating: rating,
            suggestion: suggestion,
            skillLevel: skillLevel,
            guidanceDensity: guidanceDensity,
            personality: personality.playfulness > 0.5 ? "playful" : "warm",
            sessionCount: sessionCount
        )

        pendingFeedback.append(feedback)
        savePendingFeedback()

        // Also export to file for repo sync
        exportFeedbackToFile(feedback)

        log.info("✨ Echoela: Feedback received - \(type.rawValue): \(message.prefix(50))...", category: .accessibility)

        // Thank the user
        if personality.warmth > 0.5 {
            speak("Thank you for your feedback. It helps me improve.")
        }
    }

    private func savePendingFeedback() {
        if let encoded = try? JSONEncoder().encode(pendingFeedback) {
            UserDefaults.standard.set(encoded, forKey: feedbackStorageKey)
        }
    }

    private func loadPendingFeedback() {
        guard let data = UserDefaults.standard.data(forKey: feedbackStorageKey),
              let loaded = try? JSONDecoder().decode([EchoelaFeedback].self, from: data) else {
            return
        }
        pendingFeedback = loaded
    }

    /// Export feedback to JSON file for repo updates
    private func exportFeedbackToFile(_ feedback: EchoelaFeedback) {
        let fileManager = FileManager.default

        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let feedbackDir = documentsPath.appendingPathComponent("echoela_feedback")

        // Create directory if needed
        try? fileManager.createDirectory(at: feedbackDir, withIntermediateDirectories: true)

        // Create feedback file
        let fileName = "feedback_\(feedback.id.uuidString).json"
        let filePath = feedbackDir.appendingPathComponent(fileName)

        if let encoded = try? JSONEncoder().encode(feedback) {
            try? encoded.write(to: filePath)
        }
    }

    /// Get all pending feedback for export
    public func exportAllFeedback() -> Data? {
        return try? JSONEncoder().encode(pendingFeedback)
    }

    /// Clear feedback after sync
    public func clearSyncedFeedback() {
        pendingFeedback.removeAll()
        savePendingFeedback()
    }

    // MARK: - Privacy Management

    /// Check if user has given consent for any data storage
    public var hasAnyConsent: Bool {
        hasLearningConsent || hasFeedbackConsent || hasVoiceConsent || hasAnalyticsConsent
    }

    /// Get current privacy status for display
    public var privacyStatus: PrivacyStatus {
        if !hasConsented || !hasAnyConsent {
            return .maximum
        } else if [hasLearningConsent, hasFeedbackConsent, hasVoiceConsent, hasAnalyticsConsent].filter({ $0 }).count <= 2 {
            return .balanced
        } else {
            return .fullFeatures
        }
    }

    public enum PrivacyStatus: String {
        case maximum = "Maximum Privacy"
        case balanced = "Balanced"
        case fullFeatures = "Full Features"

        public var icon: String {
            switch self {
            case .maximum: return "lock.shield.fill"
            case .balanced: return "shield.checkered"
            case .fullFeatures: return "checkmark.shield.fill"
            }
        }
    }

    /// Delete all Echoela user data (GDPR compliance)
    public func deleteAllUserData() {
        // Clear in-memory state
        userProfile = UserLearningProfile()
        pendingFeedback.removeAll()
        completedTopics.removeAll()
        interactionHistory.removeAll()
        skillLevel = 0.5
        confidenceScore = 0.5
        guidanceDensity = 0.5

        // Clear persisted data
        let keysToDelete = [
            "echoela_progress",
            "echoela_feedback_queue",
            "echoela_user_profile",
            "echoela_personality",
            "echoela_session_count",
            "echoela_preferences"
        ]

        keysToDelete.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Clear feedback files
        let fileManager = FileManager.default
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let feedbackDir = documentsPath.appendingPathComponent("echoela_feedback")
            try? fileManager.removeItem(at: feedbackDir)
        }

        log.info("✨ Echoela: All user data deleted (GDPR request)", category: .accessibility)
    }

    /// Export all user data as JSON (GDPR compliance)
    public func exportAllUserData() -> Data? {
        let exportData: [String: Any] = [
            "exportDate": Date().ISO8601Format(),
            "consent": [
                "hasConsented": hasConsented,
                "learning": hasLearningConsent,
                "feedback": hasFeedbackConsent,
                "voice": hasVoiceConsent,
                "analytics": hasAnalyticsConsent
            ],
            "progress": [
                "skillLevel": skillLevel,
                "confidenceScore": confidenceScore,
                "guidanceDensity": guidanceDensity,
                "completedTopics": completedTopics.map { $0.rawValue }
            ],
            "userProfile": [
                "learningStyle": userProfile.learningStyle.rawValue,
                "pace": userProfile.pacePReference.rawValue,
                "activeHours": userProfile.activeHours,
                "favoriteFeatures": userProfile.favoriteFeatures,
                "challengeAreas": userProfile.challengeAreas,
                "avgSessionDuration": userProfile.avgSessionDuration,
                "helpAcceptanceRate": userProfile.helpAcceptanceRate,
                "interactionPatterns": userProfile.interactionPatterns
            ],
            "sessionCount": sessionCount,
            "personality": [
                "warmth": personality.warmth,
                "playfulness": personality.playfulness,
                "formality": personality.formality,
                "verbosity": personality.verbosity,
                "encouragement": personality.encouragement
            ],
            "feedbackCount": pendingFeedback.count
        ]

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    // MARK: - Session Tracking

    /// Start a new session
    public func startSession() {
        sessionStartTime = Date()
        sessionCount += 1
        UserDefaults.standard.set(sessionCount, forKey: "echoela_session_count")

        // Track active hour
        let hour = Calendar.current.component(.hour, from: Date())
        if !userProfile.activeHours.contains(hour) {
            userProfile.activeHours.append(hour)
            if userProfile.activeHours.count > 5 {
                userProfile.activeHours.removeFirst()
            }
            saveUserProfile()
        }
    }

    /// End session and update learning
    public func endSession() {
        let duration = Date().timeIntervalSince(sessionStartTime)

        // Update average session duration
        let weight: TimeInterval = 0.2
        userProfile.avgSessionDuration = userProfile.avgSessionDuration * (1 - weight) + duration * weight
        saveUserProfile()

        // Adapt to user
        adaptToUser()

        saveProgress()
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

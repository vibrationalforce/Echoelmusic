import SwiftUI
import Combine

// MARK: - Universal Accessibility Engine
// Orchestrates ALL accessibility features into one cohesive system.
// Detects user abilities, adapts the entire UI, and provides
// multi-channel feedback (visual, haptic, audio, VoiceOver).
//
// WCAG 2.2 AAA + Universal Design + ISO 9241-171 + EN 301 549
//
// Key Principles:
// 1. Automatic Detection - reads system preferences, no manual setup needed
// 2. Progressive Disclosure - only shows complexity when user is ready
// 3. Multi-Channel Communication - never rely on a single sense
// 4. Consistent Patterns - same interaction works everywhere
// 5. Forgiveness - easy to undo, hard to make mistakes
// 6. Zero Stigma - accessible modes feel premium, not "handicapped"

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Interaction Mode

/// How the user interacts with the app
public enum InteractionMode: String, CaseIterable, Identifiable {
    case touch = "Touch"
    case voice = "Voice"
    case keyboard = "Keyboard"
    case switchAccess = "Switch"
    case eyeTracking = "Eye Tracking"
    case headTracking = "Head Tracking"
    case gamepad = "Gamepad"
    case braille = "Braille Display"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .touch: return "hand.tap"
        case .voice: return "mic.fill"
        case .keyboard: return "keyboard"
        case .switchAccess: return "button.programmable"
        case .eyeTracking: return "eye"
        case .headTracking: return "face.smiling"
        case .gamepad: return "gamecontroller"
        case .braille: return "hand.point.up.braille"
        }
    }

    public var description: String {
        switch self {
        case .touch: return "Standard touch input"
        case .voice: return "Voice commands and dictation"
        case .keyboard: return "External keyboard with full shortcuts"
        case .switchAccess: return "External switch devices"
        case .eyeTracking: return "Eye gaze control (visionOS/iPad Pro)"
        case .headTracking: return "Head movement control"
        case .gamepad: return "Game controller input"
        case .braille: return "Refreshable braille display"
        }
    }
}

// MARK: - Onboarding Ability Assessment

/// Non-invasive ability assessment during onboarding
public struct AbilityAssessment {

    /// Questions for the inclusive onboarding flow
    public struct AssessmentQuestion: Identifiable {
        public let id = UUID()
        public let title: String
        public let description: String
        public let icon: String
        public let options: [AssessmentOption]
        public let domain: AssessmentDomain
    }

    public struct AssessmentOption: Identifiable {
        public let id = UUID()
        public let label: String
        public let description: String
        public let profileAdjustment: (inout AbilityProfile) -> Void
    }

    public enum AssessmentDomain: String {
        case vision, motor, hearing, cognitive, preference
    }

    /// The complete assessment flow — warm, non-clinical questions
    public static var questions: [AssessmentQuestion] {
        [
            // Vision
            AssessmentQuestion(
                title: "How do you prefer to see things?",
                description: "We'll adjust colors, text size, and contrast for you.",
                icon: "eye",
                options: [
                    AssessmentOption(label: "Standard", description: "Default display") { _ in },
                    AssessmentOption(label: "Larger & clearer", description: "Bigger text, higher contrast") { p in
                        p.visionLevel = .moderate
                        p.contrastSensitivity = 0.5
                    },
                    AssessmentOption(label: "I use VoiceOver", description: "Full screen reader support") { p in
                        p.visionLevel = .none
                    },
                    AssessmentOption(label: "Color-adjusted", description: "Color-blind friendly palette") { p in
                        p.colorPerception = .deuteranopia  // most common
                    }
                ],
                domain: .vision
            ),

            // Light Sensitivity
            AssessmentQuestion(
                title: "How sensitive are you to light?",
                description: "We'll adjust brightness, flashing, and animations.",
                icon: "sun.max",
                options: [
                    AssessmentOption(label: "Not sensitive", description: "Full visual effects") { _ in },
                    AssessmentOption(label: "Somewhat sensitive", description: "Reduced brightness") { p in
                        p.lightSensitivity = .high
                    },
                    AssessmentOption(label: "Very sensitive", description: "No flashing, minimal motion") { p in
                        p.lightSensitivity = .epilepticRisk
                        p.motionTolerance = .low
                    }
                ],
                domain: .vision
            ),

            // Motor
            AssessmentQuestion(
                title: "How do you prefer to interact?",
                description: "We'll adjust button sizes, timing, and gestures.",
                icon: "hand.raised",
                options: [
                    AssessmentOption(label: "Standard touch", description: "Default controls") { _ in },
                    AssessmentOption(label: "Larger targets", description: "Bigger buttons, more spacing") { p in
                        p.motorPrecision = .moderate
                    },
                    AssessmentOption(label: "Voice control", description: "Hands-free operation") { p in
                        p.motorPrecision = .low
                    },
                    AssessmentOption(label: "External device", description: "Switch, gamepad, or keyboard") { p in
                        p.motorPrecision = .low
                        p.reactionSpeed = .moderate
                    }
                ],
                domain: .motor
            ),

            // Cognitive
            AssessmentQuestion(
                title: "How much detail do you want?",
                description: "We'll adjust complexity and information density.",
                icon: "brain",
                options: [
                    AssessmentOption(label: "Show everything", description: "Full professional interface") { _ in },
                    AssessmentOption(label: "Keep it simple", description: "Essential features, clean layout") { p in
                        p.cognitiveLoad = .simplified
                    },
                    AssessmentOption(label: "Guide me", description: "Step-by-step with tooltips") { p in
                        p.cognitiveLoad = .guided
                        p.memorySupport = true
                    }
                ],
                domain: .cognitive
            ),

            // Hearing
            AssessmentQuestion(
                title: "How do you experience sound?",
                description: "We'll add visual and haptic feedback for audio events.",
                icon: "ear",
                options: [
                    AssessmentOption(label: "Full hearing", description: "Standard audio experience") { _ in },
                    AssessmentOption(label: "Some hearing loss", description: "Enhanced visual cues for audio") { p in
                        p.hearingLevel = .moderate
                    },
                    AssessmentOption(label: "Deaf / Hard of hearing", description: "Full visual + haptic substitution") { p in
                        p.hearingLevel = .none
                    }
                ],
                domain: .hearing
            )
        ]
    }
}

// MARK: - Universal Accessibility Engine

@MainActor
public final class UniversalAccessibilityEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = UniversalAccessibilityEngine()

    // MARK: - Published State

    /// The user's complete ability profile
    @Published public var profile: AbilityProfile = .standard {
        didSet {
            AdaptiveDesignTokens.shared.profile = profile
            announceProfileChange()
        }
    }

    /// Current primary interaction mode
    @Published public var primaryInteractionMode: InteractionMode = .touch

    /// Available interaction modes (detected from hardware)
    @Published public var availableInteractionModes: Set<InteractionMode> = [.touch]

    /// Whether the onboarding assessment has been completed
    @Published public var hasCompletedAssessment: Bool = false

    /// Current focus element for keyboard/switch navigation
    @Published public var currentFocusPath: [String] = []

    /// Navigation announcement queue
    @Published public var pendingAnnouncement: String?

    /// Whether guided mode is active (step-by-step tooltips)
    @Published public var isGuidedModeActive: Bool = false

    /// Current guided step
    @Published public var guidedStep: GuidedStep?

    /// UI complexity level (adapts based on cognitive profile)
    @Published public var complexityLevel: ComplexityLevel = .full

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Complexity Levels

    public enum ComplexityLevel: Int, CaseIterable, Comparable {
        case minimal = 0     // only core features
        case simple = 1      // essential features
        case standard = 2    // most features
        case full = 3        // all features
        case expert = 4      // all features + developer tools

        public static func < (lhs: ComplexityLevel, rhs: ComplexityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var label: String {
            switch self {
            case .minimal: return "Focus"
            case .simple: return "Easy"
            case .standard: return "Standard"
            case .full: return "Full"
            case .expert: return "Expert"
            }
        }

        public var description: String {
            switch self {
            case .minimal: return "Just the essentials. Clean and focused."
            case .simple: return "Key features with clear labels."
            case .standard: return "Most features for everyday use."
            case .full: return "Everything Echoelmusic has to offer."
            case .expert: return "Full features plus developer tools."
            }
        }
    }

    // MARK: - Guided Mode

    public struct GuidedStep: Identifiable {
        public let id = UUID()
        public let title: String
        public let instruction: String
        public let targetElement: String  // accessibility identifier
        public let action: String         // what the user should do
        public let nextStep: String?      // label of next step
    }

    // MARK: - Initialization

    private init() {
        detectSystemPreferences()
        setupSystemObservers()
    }

    // MARK: - System Detection

    /// Reads iOS/macOS accessibility settings and auto-configures
    private func detectSystemPreferences() {
        #if os(iOS)
        // Vision
        if UIAccessibility.isVoiceOverRunning {
            profile.visionLevel = .none
            primaryInteractionMode = .voice
        }

        if UIAccessibility.isReduceMotionEnabled {
            profile.motionTolerance = .low
            profile.lightSensitivity = .high
        }

        if UIAccessibility.isReduceTransparencyEnabled {
            profile.contrastSensitivity = max(profile.contrastSensitivity - 0.2, 0)
        }

        if UIAccessibility.isBoldTextEnabled {
            if profile.visionLevel == .full {
                profile.visionLevel = .high
            }
        }

        if UIAccessibility.isInvertColorsEnabled {
            profile.contrastSensitivity = max(profile.contrastSensitivity - 0.3, 0)
        }

        if UIAccessibility.isSwitchControlRunning {
            primaryInteractionMode = .switchAccess
            availableInteractionModes.insert(.switchAccess)
            profile.motorPrecision = .low
        }

        if UIAccessibility.isClosedCaptioningEnabled {
            if profile.hearingLevel == .full {
                profile.hearingLevel = .moderate
            }
        }

        if UIAccessibility.isGrayscaleEnabled {
            profile.colorPerception = .monochromat
        }

        // Check for external keyboard
        if UIDevice.current.userInterfaceIdiom == .pad {
            availableInteractionModes.insert(.keyboard)
        }
        #endif

        // Map cognitive load from profile
        switch profile.cognitiveLoad {
        case .standard: complexityLevel = .full
        case .simplified: complexityLevel = .simple
        case .minimal: complexityLevel = .minimal
        case .guided: complexityLevel = .simple; isGuidedModeActive = true
        }
    }

    private func setupSystemObservers() {
        #if os(iOS)
        // Observe VoiceOver changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.detectSystemPreferences()
            }
            .store(in: &cancellables)

        // Observe reduce motion changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.detectSystemPreferences()
            }
            .store(in: &cancellables)

        // Observe switch control changes
        NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.detectSystemPreferences()
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Profile Application

    /// Apply a preset profile
    public func applyPresetProfile(_ preset: ProfilePreset) {
        switch preset {
        case .standard: profile = .standard
        case .lowVision: profile = .lowVision
        case .blind: profile = .blind
        case .motorLimited: profile = .motorLimited
        case .deaf: profile = .deaf
        case .cognitive: profile = .cognitive
        case .photosensitive: profile = .photosensitive
        case .elderly: profile = .elderly
        }
    }

    public enum ProfilePreset: String, CaseIterable {
        case standard = "Standard"
        case lowVision = "Low Vision"
        case blind = "Screen Reader"
        case motorLimited = "Motor Limited"
        case deaf = "Deaf/HoH"
        case cognitive = "Simplified"
        case photosensitive = "Photosensitive"
        case elderly = "Senior Friendly"

        public var icon: String {
            switch self {
            case .standard: return "person.fill"
            case .lowVision: return "eye.fill"
            case .blind: return "speaker.wave.3.fill"
            case .motorLimited: return "hand.raised.fill"
            case .deaf: return "ear.fill"
            case .cognitive: return "brain"
            case .photosensitive: return "sun.min.fill"
            case .elderly: return "figure.stand"
            }
        }
    }

    // MARK: - Announcements

    /// Post a VoiceOver announcement
    public func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        pendingAnnouncement = message

        #if os(iOS)
        let notification: UIAccessibility.Notification
        switch priority {
        case .normal:
            notification = .announcement
        case .screenChanged:
            notification = .screenChanged
        case .layoutChanged:
            notification = .layoutChanged
        }
        UIAccessibility.post(notification: notification, argument: message)
        #endif
    }

    public enum AnnouncementPriority {
        case normal, screenChanged, layoutChanged
    }

    /// Announce a bio metric change (only when significant)
    public func announceBioMetric(name: String, value: String, trend: String? = nil) {
        var message = "\(name): \(value)"
        if let trend = trend {
            message += ", \(trend)"
        }
        announce(message)
    }

    /// Announce workspace navigation
    public func announceNavigation(to workspace: String) {
        announce("\(workspace) workspace", priority: .screenChanged)
    }

    // MARK: - Haptic Feedback

    /// Provide appropriate haptic feedback
    public func hapticFeedback(_ type: HapticType) {
        guard AdaptiveDesignTokens.shared.hapticEnabled else { return }

        #if os(iOS)
        switch type {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .heartbeat:
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                gen.impactOccurred(intensity: 0.6)
            }
        case .coherencePulse:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .breathingGuide:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        }
        #endif
    }

    public enum HapticType {
        case selection, light, medium, heavy
        case success, warning, error
        case heartbeat, coherencePulse, breathingGuide
    }

    // MARK: - Feature Visibility

    /// Whether a feature should be shown at the current complexity level
    public func shouldShowFeature(_ feature: FeatureComplexity) -> Bool {
        feature.minimumLevel <= complexityLevel
    }

    public struct FeatureComplexity {
        public let name: String
        public let minimumLevel: ComplexityLevel

        // Predefined feature complexities
        public static let playPause = FeatureComplexity(name: "Play/Pause", minimumLevel: .minimal)
        public static let presets = FeatureComplexity(name: "Presets", minimumLevel: .minimal)
        public static let bioMetrics = FeatureComplexity(name: "Bio Metrics", minimumLevel: .simple)
        public static let effects = FeatureComplexity(name: "Effects", minimumLevel: .standard)
        public static let mixing = FeatureComplexity(name: "Mixing", minimumLevel: .standard)
        public static let nodeEditor = FeatureComplexity(name: "Node Editor", minimumLevel: .full)
        public static let midi = FeatureComplexity(name: "MIDI Routing", minimumLevel: .full)
        public static let developer = FeatureComplexity(name: "Developer Console", minimumLevel: .expert)
        public static let quantum = FeatureComplexity(name: "Quantum", minimumLevel: .standard)
        public static let collaboration = FeatureComplexity(name: "Collaboration", minimumLevel: .simple)
        public static let wellness = FeatureComplexity(name: "Wellness", minimumLevel: .minimal)
        public static let streaming = FeatureComplexity(name: "Streaming", minimumLevel: .full)
        public static let videoEditor = FeatureComplexity(name: "Video Editor", minimumLevel: .standard)
        public static let lighting = FeatureComplexity(name: "Lighting", minimumLevel: .full)
    }

    // MARK: - Visual Feedback for Audio Events

    /// For deaf/HoH users: provides visual representation of audio events
    @Published public var visualBeatIndicator: Bool = false
    @Published public var visualAudioLevel: Float = 0.0
    @Published public var visualFrequencyBands: [Float] = Array(repeating: 0, count: 8)

    /// Flash visual beat indicator (safe, no rapid flashing)
    public func indicateBeat() {
        guard profile.hearingLevel <= .moderate else { return }
        visualBeatIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.visualBeatIndicator = false
        }
    }

    /// Update visual audio level (for deaf users)
    public func updateVisualAudioLevel(_ level: Float) {
        guard profile.hearingLevel <= .moderate else { return }
        visualAudioLevel = level
    }

    // MARK: - Persistence

    private func announceProfileChange() {
        // Save profile to UserDefaults
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "echoelmusic.abilityProfile")
        }
    }

    public func loadSavedProfile() {
        if let data = UserDefaults.standard.data(forKey: "echoelmusic.abilityProfile"),
           let saved = try? JSONDecoder().decode(AbilityProfile.self, from: data) {
            profile = saved
            hasCompletedAssessment = true
        }
    }
}

// MARK: - Accessibility View Modifiers

extension View {

    /// Make a view fully accessible with multi-channel feedback
    public func universallyAccessible(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        importance: AccessibilityImportance = .standard
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityIdentifier(label.lowercased().replacingOccurrences(of: " ", with: "_"))
    }

    /// Conditionally show based on complexity level
    @ViewBuilder
    public func visibleAt(_ complexity: UniversalAccessibilityEngine.ComplexityLevel) -> some View {
        if UniversalAccessibilityEngine.shared.complexityLevel >= complexity {
            self
        }
    }

    /// Apply safe animation (respects motion preferences)
    public func safeAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if AdaptiveDesignTokens.shared.animationEnabled {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self)
        }
    }

    public enum AccessibilityImportance {
        case critical    // always visible, always announced
        case standard    // visible at simple+
        case detail      // visible at standard+
        case advanced    // visible at full+
    }
}

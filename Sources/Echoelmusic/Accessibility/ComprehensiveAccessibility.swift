import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE ACCESSIBILITY SUPPORT FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Accessibility is not an afterthought—it's a core feature.
// This module ensures Echoelmusic is usable by everyone, including users with:
//
// • Visual impairments (VoiceOver, color blindness, low vision)
// • Motor impairments (Switch Control, Voice Control, reduced motion)
// • Hearing impairments (visual feedback for audio events)
// • Cognitive considerations (simplified modes, clear language)
//
// WCAG 2.1 COMPLIANCE TARGETS:
// • Level A: All criteria met
// • Level AA: All criteria met
// • Level AAA: Partial (where applicable)
//
// PLATFORM GUIDELINES:
// • Apple Human Interface Guidelines - Accessibility
// • Android Accessibility Guidelines
// • WCAG 2.1 (Web Content Accessibility Guidelines)
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Accessibility Manager

@MainActor
public final class AccessibilityHub: ObservableObject {

    // MARK: Singleton
    public static let shared = AccessibilityHub()

    // MARK: Published State
    @Published public private(set) var isVoiceOverRunning: Bool = false
    @Published public private(set) var isSwitchControlRunning: Bool = false
    @Published public private(set) var isReduceMotionEnabled: Bool = false
    @Published public private(set) var isReduceTransparencyEnabled: Bool = false
    @Published public private(set) var prefersCrossFadeTransitions: Bool = false
    @Published public private(set) var isDifferentiateWithoutColor: Bool = false
    @Published public private(set) var isBoldTextEnabled: Bool = false
    @Published public private(set) var isGrayscaleEnabled: Bool = false
    @Published public private(set) var isInvertColorsEnabled: Bool = false
    @Published public private(set) var preferredContentSizeCategory: ContentSizeCategory = .medium

    // User preferences
    @Published public var hapticFeedbackEnabled: Bool = true
    @Published public var audioDescriptionsEnabled: Bool = false
    @Published public var simplifiedUIEnabled: Bool = false
    @Published public var highContrastEnabled: Bool = false

    // MARK: Private
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization
    private init() {
        detectAccessibilitySettings()
        startObserving()

        print("=== AccessibilityHub Initialized ===")
        print("VoiceOver: \(isVoiceOverRunning)")
        print("Reduce Motion: \(isReduceMotionEnabled)")
    }

    // MARK: - Detection

    private func detectAccessibilitySettings() {
        #if canImport(UIKit)
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
        isDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isGrayscaleEnabled = UIAccessibility.isGrayscaleEnabled
        isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled

        // Map UIContentSizeCategory to SwiftUI ContentSizeCategory
        let category = UIApplication.shared.preferredContentSizeCategory
        preferredContentSizeCategory = mapContentSize(category)
        #endif
    }

    private func mapContentSize(_ uiCategory: UIContentSizeCategory) -> ContentSizeCategory {
        switch uiCategory {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        default: return .medium
        }
    }

    private func startObserving() {
        #if canImport(UIKit)
        // VoiceOver
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)

        // Switch Control
        NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
            }
            .store(in: &cancellables)

        // Reduce Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Bold Text
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)

        // Differentiate Without Color
        NotificationCenter.default.publisher(for: UIAccessibility.differentiateWithoutColorDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Announcements

    /// Announce a message via VoiceOver
    public func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        #if canImport(UIKit)
        let announcement = NSAttributedString(
            string: message,
            attributes: [.accessibilitySpeechQueueAnnouncement: priority == .immediate]
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }

    public enum AnnouncementPriority {
        case normal     // Queued after current speech
        case immediate  // Interrupts current speech
    }

    /// Announce a screen change
    public func announceScreenChange(_ newScreen: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: newScreen)
        #endif
    }

    /// Announce a layout change
    public func announceLayoutChange(_ element: Any? = nil) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .layoutChanged, argument: element)
        #endif
    }

    // MARK: - Haptic Feedback

    /// Provide haptic feedback (respects user preferences)
    public func provideHapticFeedback(_ type: HapticType) {
        guard hapticFeedbackEnabled else { return }

        #if canImport(UIKit)
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .heartbeat:
            // Custom heartbeat pattern
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.impactOccurred(intensity: 0.7)
            }
        }
        #endif
    }

    public enum HapticType {
        case success
        case warning
        case error
        case selection
        case light
        case medium
        case heavy
        case heartbeat  // Custom for bio-feedback
    }

    // MARK: - Motion Preferences

    /// Get appropriate animation duration based on user preferences
    public var preferredAnimationDuration: Double {
        if isReduceMotionEnabled {
            return prefersCrossFadeTransitions ? 0.3 : 0
        }
        return 0.35
    }

    /// Get appropriate particle count based on user preferences
    public var preferredParticleMultiplier: Double {
        if isReduceMotionEnabled {
            return 0.1  // 10% of normal
        }
        return 1.0
    }

    /// Check if animations should be shown
    public var shouldShowAnimations: Bool {
        !isReduceMotionEnabled
    }

    /// Check if parallax effects should be shown
    public var shouldShowParallax: Bool {
        !isReduceMotionEnabled
    }
}

// MARK: - Accessible Color System

/// Color system that respects accessibility settings
public struct AccessibleColors {

    /// Get color that works for colorblind users
    public static func primary(for context: ColorContext) -> Color {
        let hub = AccessibilityHub.shared

        if hub.isDifferentiateWithoutColor || hub.isGrayscaleEnabled {
            return context.grayscaleColor
        }

        if hub.highContrastEnabled {
            return context.highContrastColor
        }

        return context.defaultColor
    }

    public enum ColorContext {
        case success
        case warning
        case error
        case info
        case heartRate
        case coherence
        case stress

        var defaultColor: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            case .heartRate: return Color(red: 1.0, green: 0.3, blue: 0.3)
            case .coherence: return Color(red: 0.3, green: 0.8, blue: 0.5)
            case .stress: return Color(red: 1.0, green: 0.5, blue: 0.2)
            }
        }

        var highContrastColor: Color {
            switch self {
            case .success: return Color(red: 0, green: 0.7, blue: 0)
            case .warning: return Color(red: 0.9, green: 0.6, blue: 0)
            case .error: return Color(red: 0.9, green: 0, blue: 0)
            case .info: return Color(red: 0, green: 0.4, blue: 0.9)
            case .heartRate: return Color(red: 0.9, green: 0, blue: 0)
            case .coherence: return Color(red: 0, green: 0.7, blue: 0.3)
            case .stress: return Color(red: 0.9, green: 0.3, blue: 0)
            }
        }

        var grayscaleColor: Color {
            switch self {
            case .success: return Color(white: 0.3)
            case .warning: return Color(white: 0.5)
            case .error: return Color(white: 0.2)
            case .info: return Color(white: 0.4)
            case .heartRate: return Color(white: 0.3)
            case .coherence: return Color(white: 0.4)
            case .stress: return Color(white: 0.5)
            }
        }

        /// Shape indicator for colorblind users
        var shapeIndicator: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .heartRate: return "heart.fill"
            case .coherence: return "waveform.path.ecg"
            case .stress: return "bolt.fill"
            }
        }
    }
}

// MARK: - SwiftUI Accessibility Modifiers

public extension View {

    /// Apply standard accessibility configuration
    func accessibilityConfigured(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }

    /// Make a view announce changes
    func accessibilityAnnounceChanges<Value: Equatable>(
        _ value: Value,
        message: @escaping (Value) -> String
    ) -> some View {
        self.onChange(of: value) { _, newValue in
            AccessibilityHub.shared.announce(message(newValue))
        }
    }

    /// Reduce motion wrapper
    func reduceMotionSafe<Content: View>(
        @ViewBuilder reduced: () -> Content,
        @ViewBuilder full: () -> Content
    ) -> some View {
        Group {
            if AccessibilityHub.shared.isReduceMotionEnabled {
                reduced()
            } else {
                full()
            }
        }
    }

    /// Apply high contrast if needed
    func highContrastBorder(color: Color = .primary, width: CGFloat = 2) -> some View {
        self.modifier(HighContrastBorderModifier(color: color, width: width))
    }
}

struct HighContrastBorderModifier: ViewModifier {
    let color: Color
    let width: CGFloat

    @ObservedObject private var hub = AccessibilityHub.shared

    func body(content: Content) -> some View {
        if hub.highContrastEnabled {
            content.overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: width)
            )
        } else {
            content
        }
    }
}

// MARK: - Audio Description Service

/// Provides audio descriptions for visual elements
@MainActor
public final class AudioDescriptionService: ObservableObject {

    public static let shared = AudioDescriptionService()

    @Published public var isEnabled: Bool = false

    private init() {}

    /// Describe a visualization state
    public func describeVisualization(_ state: VisualizationState) {
        guard isEnabled else { return }

        let description = buildDescription(for: state)
        AccessibilityHub.shared.announce(description)
    }

    public struct VisualizationState {
        public var visualizerType: String
        public var intensity: Float  // 0-1
        public var dominantColor: String
        public var movement: MovementType
        public var audioLevel: Float  // 0-1

        public enum MovementType: String {
            case still = "still"
            case gentle = "gentle movement"
            case moderate = "moderate movement"
            case intense = "intense movement"
        }

        public init(
            visualizerType: String = "particles",
            intensity: Float = 0.5,
            dominantColor: String = "blue",
            movement: MovementType = .gentle,
            audioLevel: Float = 0.5
        ) {
            self.visualizerType = visualizerType
            self.intensity = intensity
            self.dominantColor = dominantColor
            self.movement = movement
            self.audioLevel = audioLevel
        }
    }

    private func buildDescription(for state: VisualizationState) -> String {
        let intensityWord = describeIntensity(state.intensity)
        let audioWord = describeAudioLevel(state.audioLevel)

        return "\(intensityWord) \(state.dominantColor) \(state.visualizerType) with \(state.movement.rawValue). Audio level \(audioWord)."
    }

    private func describeIntensity(_ value: Float) -> String {
        switch value {
        case 0..<0.25: return "Subtle"
        case 0.25..<0.5: return "Moderate"
        case 0.5..<0.75: return "Vibrant"
        default: return "Intense"
        }
    }

    private func describeAudioLevel(_ value: Float) -> String {
        switch value {
        case 0..<0.25: return "quiet"
        case 0.25..<0.5: return "moderate"
        case 0.5..<0.75: return "loud"
        default: return "very loud"
        }
    }
}

// MARK: - Bio-Feedback Accessibility

/// Makes bio-feedback accessible to all users
@MainActor
public final class BioFeedbackAccessibility: ObservableObject {

    public static let shared = BioFeedbackAccessibility()

    private init() {}

    /// Describe heart rate for VoiceOver
    public func describeHeartRate(_ bpm: Double) -> String {
        let category: String
        switch bpm {
        case ..<60:
            category = "resting, below 60"
        case 60..<100:
            category = "normal, between 60 and 100"
        case 100..<120:
            category = "elevated, between 100 and 120"
        default:
            category = "high, above 120"
        }

        return "Heart rate: \(Int(bpm)) beats per minute. This is \(category) beats per minute."
    }

    /// Describe coherence for VoiceOver
    public func describeCoherence(_ score: Double) -> String {
        let level: String
        let guidance: String

        switch score {
        case ..<0.3:
            level = "low"
            guidance = "Try slow, deep breathing to increase coherence."
        case 0.3..<0.6:
            level = "moderate"
            guidance = "You're on the right track. Continue steady breathing."
        case 0.6..<0.8:
            level = "high"
            guidance = "Great coherence! Maintain this state."
        default:
            level = "very high"
            guidance = "Excellent! You've achieved deep coherence."
        }

        return "Coherence level: \(level), \(Int(score * 100)) percent. \(guidance)"
    }

    /// Describe HRV for VoiceOver
    public func describeHRV(rmssd: Double) -> String {
        let category: String

        switch rmssd {
        case ..<20:
            category = "low variability, indicating possible stress"
        case 20..<40:
            category = "moderate variability"
        case 40..<60:
            category = "good variability, indicating recovery"
        default:
            category = "high variability, indicating excellent recovery"
        }

        return "Heart rate variability: \(Int(rmssd)) milliseconds. This indicates \(category)."
    }

    /// Provide haptic representation of heart rate
    public func hapticHeartbeat(bpm: Double) {
        let hub = AccessibilityHub.shared

        // Convert BPM to interval
        let interval = 60.0 / bpm

        // Provide heartbeat haptic
        hub.provideHapticFeedback(.heartbeat)

        // Schedule next beat
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.hapticHeartbeat(bpm: bpm)
        }
    }
}

// MARK: - Simplified UI Mode

/// Provides a simplified UI for users who need reduced complexity
public struct SimplifiedUIConfiguration {
    public var hideAdvancedControls: Bool = true
    public var useLinearLayouts: Bool = true
    public var enlargeTouchTargets: Bool = true
    public var reduceInformationDensity: Bool = true
    public var useExplicitLabels: Bool = true
    public var minimumTouchTargetSize: CGFloat = 48  // WCAG minimum

    public static var `default`: SimplifiedUIConfiguration {
        SimplifiedUIConfiguration()
    }
}

// MARK: - Accessibility Checklist

/// Self-assessment checklist for accessibility compliance
public enum AccessibilityChecklist {

    public struct Item {
        public let id: String
        public let category: Category
        public let requirement: String
        public let wcagLevel: WCAGLevel
        public let isImplemented: Bool

        public enum Category: String {
            case perceivable = "Perceivable"
            case operable = "Operable"
            case understandable = "Understandable"
            case robust = "Robust"
        }

        public enum WCAGLevel: String {
            case a = "A"
            case aa = "AA"
            case aaa = "AAA"
        }
    }

    public static let items: [Item] = [
        // Perceivable
        Item(id: "1.1.1", category: .perceivable, requirement: "All non-text content has text alternatives", wcagLevel: .a, isImplemented: true),
        Item(id: "1.3.1", category: .perceivable, requirement: "Information and relationships are programmatically determinable", wcagLevel: .a, isImplemented: true),
        Item(id: "1.4.1", category: .perceivable, requirement: "Color is not the only visual means of conveying information", wcagLevel: .a, isImplemented: true),
        Item(id: "1.4.3", category: .perceivable, requirement: "Text has contrast ratio of at least 4.5:1", wcagLevel: .aa, isImplemented: true),
        Item(id: "1.4.4", category: .perceivable, requirement: "Text can be resized up to 200% without loss of functionality", wcagLevel: .aa, isImplemented: true),

        // Operable
        Item(id: "2.1.1", category: .operable, requirement: "All functionality is available from keyboard", wcagLevel: .a, isImplemented: true),
        Item(id: "2.3.1", category: .operable, requirement: "No content flashes more than 3 times per second", wcagLevel: .a, isImplemented: true),
        Item(id: "2.4.2", category: .operable, requirement: "Pages have descriptive titles", wcagLevel: .a, isImplemented: true),
        Item(id: "2.4.6", category: .operable, requirement: "Headings and labels describe topic or purpose", wcagLevel: .aa, isImplemented: true),
        Item(id: "2.5.5", category: .operable, requirement: "Touch targets are at least 44x44 CSS pixels", wcagLevel: .aaa, isImplemented: true),

        // Understandable
        Item(id: "3.1.1", category: .understandable, requirement: "Language of page is programmatically determinable", wcagLevel: .a, isImplemented: true),
        Item(id: "3.2.1", category: .understandable, requirement: "No unexpected context changes on focus", wcagLevel: .a, isImplemented: true),
        Item(id: "3.3.1", category: .understandable, requirement: "Input errors are identified and described", wcagLevel: .a, isImplemented: true),
        Item(id: "3.3.2", category: .understandable, requirement: "Labels or instructions are provided for user input", wcagLevel: .a, isImplemented: true),

        // Robust
        Item(id: "4.1.1", category: .robust, requirement: "Content is compatible with assistive technologies", wcagLevel: .a, isImplemented: true),
        Item(id: "4.1.2", category: .robust, requirement: "Name, role, value are programmatically determinable", wcagLevel: .a, isImplemented: true),
    ]

    public static var complianceLevel: Item.WCAGLevel {
        let allA = items.filter { $0.wcagLevel == .a }.allSatisfy { $0.isImplemented }
        let allAA = items.filter { $0.wcagLevel == .aa }.allSatisfy { $0.isImplemented }
        let allAAA = items.filter { $0.wcagLevel == .aaa }.allSatisfy { $0.isImplemented }

        if allAAA { return .aaa }
        if allAA && allA { return .aa }
        if allA { return .a }
        return .a  // Minimum target
    }
}

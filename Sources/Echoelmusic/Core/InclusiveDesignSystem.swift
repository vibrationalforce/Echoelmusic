import SwiftUI
import Combine

// MARK: - Inclusive Design System
// Universal adaptive design tokens that respond to user abilities, preferences,
// and context. Every element adapts: colors, spacing, typography, interactions.
//
// Principles:
// 1. Universal Design - works for EVERYONE without special adaptation
// 2. Equitable Use - same means of use for all, identical when possible
// 3. Flexibility - accommodates wide range of preferences and abilities
// 4. Perceptible - communicates through multiple channels (visual, audio, haptic)
// 5. Tolerance for Error - minimizes hazards and adverse consequences

// MARK: - Ability Profile

/// Represents a user's combined ability profile across all dimensions
public struct AbilityProfile: Equatable, Codable {

    // Vision
    public var visionLevel: AbilityLevel = .full          // .full → .none
    public var colorPerception: ColorPerception = .full   // trichromatic → achromatic
    public var contrastSensitivity: Double = 1.0          // 0.0–1.0
    public var lightSensitivity: LightSensitivity = .normal

    // Motor
    public var motorPrecision: AbilityLevel = .full       // fine motor control
    public var reactionSpeed: AbilityLevel = .full        // timing-based interactions
    public var handedness: Handedness = .either
    public var tremorLevel: TremorLevel = .none

    // Hearing
    public var hearingLevel: AbilityLevel = .full
    public var frequencyRange: FrequencyRange = .full     // which frequencies can be heard

    // Cognitive
    public var cognitiveLoad: CognitiveCapacity = .standard
    public var attentionSpan: AbilityLevel = .full
    public var memorySupport: Bool = false

    // Vestibular
    public var motionTolerance: AbilityLevel = .full      // motion sickness sensitivity

    // Context
    public var environmentBrightness: Double = 0.5        // 0=dark, 1=bright
    public var environmentNoise: Double = 0.3             // 0=quiet, 1=loud
    public var isMoving: Bool = false                     // user in motion

    public enum AbilityLevel: Int, Codable, CaseIterable, Comparable {
        case full = 4
        case high = 3
        case moderate = 2
        case low = 1
        case none = 0

        public static func < (lhs: AbilityLevel, rhs: AbilityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum ColorPerception: String, Codable, CaseIterable {
        case full            // normal trichromatic vision
        case protanopia      // red-blind
        case deuteranopia    // green-blind
        case tritanopia      // blue-blind
        case monochromat     // achromatic
    }

    public enum LightSensitivity: String, Codable, CaseIterable {
        case low             // prefers bright
        case normal
        case high            // photosensitive
        case epilepticRisk   // must avoid flashes
    }

    public enum Handedness: String, Codable, CaseIterable {
        case left, right, either
    }

    public enum TremorLevel: String, Codable, CaseIterable {
        case none, mild, moderate, severe
    }

    public enum FrequencyRange: String, Codable, CaseIterable {
        case full            // 20Hz–20kHz
        case reducedHigh     // reduced high frequency hearing
        case reducedLow      // reduced low frequency hearing
        case narrowBand      // limited range
    }

    public enum CognitiveCapacity: String, Codable, CaseIterable {
        case standard
        case simplified      // reduce complexity
        case minimal         // only essential elements
        case guided          // step-by-step with prompts
    }

    // MARK: - Preset Profiles

    public static let standard = AbilityProfile()

    public static let lowVision: AbilityProfile = {
        var p = AbilityProfile()
        p.visionLevel = .low
        p.contrastSensitivity = 0.4
        return p
    }()

    public static let blind: AbilityProfile = {
        var p = AbilityProfile()
        p.visionLevel = .none
        return p
    }()

    public static let motorLimited: AbilityProfile = {
        var p = AbilityProfile()
        p.motorPrecision = .low
        p.reactionSpeed = .low
        p.tremorLevel = .moderate
        return p
    }()

    public static let deaf: AbilityProfile = {
        var p = AbilityProfile()
        p.hearingLevel = .none
        return p
    }()

    public static let cognitive: AbilityProfile = {
        var p = AbilityProfile()
        p.cognitiveLoad = .simplified
        p.attentionSpan = .moderate
        p.memorySupport = true
        return p
    }()

    public static let photosensitive: AbilityProfile = {
        var p = AbilityProfile()
        p.lightSensitivity = .epilepticRisk
        p.motionTolerance = .low
        return p
    }()

    public static let elderly: AbilityProfile = {
        var p = AbilityProfile()
        p.visionLevel = .moderate
        p.contrastSensitivity = 0.6
        p.motorPrecision = .moderate
        p.reactionSpeed = .moderate
        p.hearingLevel = .moderate
        p.frequencyRange = .reducedHigh
        p.cognitiveLoad = .simplified
        return p
    }()
}

// MARK: - Adaptive Design Tokens

/// Design tokens that automatically adapt to the user's ability profile
@MainActor
public final class AdaptiveDesignTokens: ObservableObject {

    // MARK: - Singleton

    static let shared = AdaptiveDesignTokens()

    // MARK: - Profile

    @Published public var profile: AbilityProfile = .standard {
        didSet { recalculateTokens() }
    }

    // MARK: - Computed Adaptive Tokens

    // Spacing
    @Published public var spacingXS: CGFloat = 4
    @Published public var spacingSM: CGFloat = 8
    @Published public var spacingMD: CGFloat = 16
    @Published public var spacingLG: CGFloat = 24
    @Published public var spacingXL: CGFloat = 32

    // Touch Targets
    @Published public var minTouchTarget: CGFloat = 44    // Apple HIG minimum
    @Published public var preferredTouchTarget: CGFloat = 48
    @Published public var comfortTouchTarget: CGFloat = 56

    // Corner Radius
    @Published public var cornerRadiusSM: CGFloat = 8
    @Published public var cornerRadiusMD: CGFloat = 12
    @Published public var cornerRadiusLG: CGFloat = 16

    // Border Width
    @Published public var borderWidth: CGFloat = 1
    @Published public var focusBorderWidth: CGFloat = 2

    // Animation
    @Published public var animationEnabled: Bool = true
    @Published public var animationDuration: Double = 0.3
    @Published public var animationSpring: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    @Published public var flashesAllowed: Bool = true
    @Published public var maxFlashFrequency: Double = 3.0  // Hz, WCAG: max 3/sec

    // Typography Scale Factor
    @Published public var typeScaleFactor: CGFloat = 1.0

    // Color Adjustments
    @Published public var minimumContrastRatio: Double = 4.5  // WCAG AA
    @Published public var useHighContrast: Bool = false
    @Published public var colorAdjustment: AbilityProfile.ColorPerception = .full

    // Interaction
    @Published public var longPressThreshold: Double = 0.5  // seconds
    @Published public var doubleTapWindow: Double = 0.3     // seconds
    @Published public var dragSensitivity: CGFloat = 1.0
    @Published public var scrollSpeed: CGFloat = 1.0

    // Feedback Channels
    @Published public var hapticEnabled: Bool = true
    @Published public var audioFeedbackEnabled: Bool = true
    @Published public var visualFeedbackEnabled: Bool = true

    // Layout
    @Published public var preferredColumns: Int = 2
    @Published public var showLabelsAlways: Bool = false
    @Published public var iconSize: CGFloat = 24

    // MARK: - Recalculate

    private func recalculateTokens() {
        let p = profile

        // Vision adaptations
        switch p.visionLevel {
        case .full:
            typeScaleFactor = 1.0
            minimumContrastRatio = 4.5
            useHighContrast = false
            iconSize = 24
        case .high:
            typeScaleFactor = 1.15
            minimumContrastRatio = 7.0
            useHighContrast = false
            iconSize = 28
        case .moderate:
            typeScaleFactor = 1.3
            minimumContrastRatio = 7.0
            useHighContrast = true
            iconSize = 32
        case .low:
            typeScaleFactor = 1.5
            minimumContrastRatio = 10.0
            useHighContrast = true
            iconSize = 40
            showLabelsAlways = true
        case .none:
            audioFeedbackEnabled = true
            hapticEnabled = true
            showLabelsAlways = true
        }

        // Motor adaptations
        switch p.motorPrecision {
        case .full:
            minTouchTarget = 44
            preferredTouchTarget = 48
            comfortTouchTarget = 56
        case .high:
            minTouchTarget = 48
            preferredTouchTarget = 56
            comfortTouchTarget = 64
        case .moderate:
            minTouchTarget = 56
            preferredTouchTarget = 64
            comfortTouchTarget = 72
        case .low, .none:
            minTouchTarget = 64
            preferredTouchTarget = 72
            comfortTouchTarget = 88
            longPressThreshold = 0.8
            doubleTapWindow = 0.5
        }

        // Tremor adaptations
        switch p.tremorLevel {
        case .none: dragSensitivity = 1.0
        case .mild: dragSensitivity = 0.7
        case .moderate: dragSensitivity = 0.5
        case .severe: dragSensitivity = 0.3
        }

        // Timing adaptations
        switch p.reactionSpeed {
        case .full: break
        case .high: animationDuration = 0.4
        case .moderate: animationDuration = 0.5; longPressThreshold = 0.7
        case .low, .none: animationDuration = 0.7; longPressThreshold = 1.0; doubleTapWindow = 0.6
        }

        // Light sensitivity
        switch p.lightSensitivity {
        case .low, .normal:
            flashesAllowed = true
            animationEnabled = true
        case .high:
            flashesAllowed = false
            maxFlashFrequency = 0
        case .epilepticRisk:
            flashesAllowed = false
            animationEnabled = false
            maxFlashFrequency = 0
        }

        // Motion tolerance
        if p.motionTolerance <= .moderate {
            animationEnabled = false
            animationSpring = .linear(duration: 0)
            scrollSpeed = 0.6
        }

        // Cognitive adaptations
        switch p.cognitiveLoad {
        case .standard:
            preferredColumns = 2
        case .simplified:
            preferredColumns = 1
            showLabelsAlways = true
        case .minimal:
            preferredColumns = 1
            showLabelsAlways = true
        case .guided:
            preferredColumns = 1
            showLabelsAlways = true
        }

        // Color perception
        colorAdjustment = p.colorPerception

        // Spacing scales with touch needs
        let spacingFactor: CGFloat = p.motorPrecision <= .moderate ? 1.5 : 1.0
        spacingXS = 4 * spacingFactor
        spacingSM = 8 * spacingFactor
        spacingMD = 16 * spacingFactor
        spacingLG = 24 * spacingFactor
        spacingXL = 32 * spacingFactor

        // Corner radius scales
        cornerRadiusSM = 8 * (p.visionLevel <= .moderate ? 1.5 : 1.0)
        cornerRadiusMD = 12 * (p.visionLevel <= .moderate ? 1.5 : 1.0)
        cornerRadiusLG = 16 * (p.visionLevel <= .moderate ? 1.5 : 1.0)

        // Border width for visibility
        borderWidth = p.visionLevel <= .moderate ? 2 : 1
        focusBorderWidth = p.visionLevel <= .moderate ? 4 : 2
    }
}

// MARK: - Adaptive Color System

/// Colors that automatically adapt to color perception and contrast needs
public struct AdaptiveColor {

    /// Safe primary accent color adjusted for color perception
    public static func primary(for profile: AbilityProfile) -> Color {
        switch profile.colorPerception {
        case .full: return VaporwaveColors.neonPink
        case .protanopia: return Color(red: 0.0, green: 0.6, blue: 1.0)  // blue instead of red
        case .deuteranopia: return Color(red: 0.0, green: 0.5, blue: 1.0)
        case .tritanopia: return Color(red: 1.0, green: 0.3, blue: 0.3)  // red instead of blue
        case .monochromat: return Color.white
        }
    }

    /// Safe secondary color
    public static func secondary(for profile: AbilityProfile) -> Color {
        switch profile.colorPerception {
        case .full: return VaporwaveColors.neonCyan
        case .protanopia: return Color(red: 1.0, green: 0.85, blue: 0.0)  // yellow
        case .deuteranopia: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .tritanopia: return Color(red: 0.0, green: 0.8, blue: 0.4)
        case .monochromat: return Color.gray
        }
    }

    /// Coherence indicator with multi-channel feedback
    public static func coherence(_ value: Double, for profile: AbilityProfile) -> Color {
        // High contrast mode uses stark differentiation
        if profile.contrastSensitivity < 0.6 {
            if value < 0.33 { return Color.red }
            if value < 0.66 { return Color.yellow }
            return Color.green
        }

        // Standard gradient
        if value < 0.33 { return VaporwaveColors.coherenceLow }
        if value < 0.66 { return VaporwaveColors.coherenceMedium }
        return VaporwaveColors.coherenceHigh
    }

    /// Background that adapts to light sensitivity
    public static func background(for profile: AbilityProfile) -> Color {
        switch profile.lightSensitivity {
        case .low: return VaporwaveColors.midnightBlue
        case .normal: return VaporwaveColors.deepBlack
        case .high: return Color(red: 0.05, green: 0.05, blue: 0.08)  // very dark, low blue
        case .epilepticRisk: return Color(red: 0.08, green: 0.08, blue: 0.08)  // neutral dark
        }
    }

    /// Text color ensuring minimum contrast ratio
    public static func text(on background: Color, for profile: AbilityProfile) -> Color {
        if profile.contrastSensitivity < 0.6 || profile.visionLevel <= .moderate {
            return Color.white
        }
        return VaporwaveColors.textPrimary
    }

    /// Status colors that work for all color perceptions
    public static func success(for profile: AbilityProfile) -> Color {
        switch profile.colorPerception {
        case .full, .tritanopia: return Color(red: 0.2, green: 0.9, blue: 0.4)
        case .protanopia, .deuteranopia: return Color(red: 0.0, green: 0.6, blue: 1.0)
        case .monochromat: return Color.white
        }
    }

    public static func warning(for profile: AbilityProfile) -> Color {
        switch profile.colorPerception {
        case .full: return VaporwaveColors.coral
        case .protanopia, .deuteranopia: return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .tritanopia: return Color(red: 1.0, green: 0.5, blue: 0.0)
        case .monochromat: return Color(white: 0.7)
        }
    }

    public static func error(for profile: AbilityProfile) -> Color {
        switch profile.colorPerception {
        case .full, .tritanopia: return Color(red: 1.0, green: 0.25, blue: 0.25)
        case .protanopia, .deuteranopia: return Color(red: 1.0, green: 0.5, blue: 0.0)
        case .monochromat: return Color(white: 0.4)
        }
    }
}

// MARK: - Adaptive View Modifiers

/// Makes any view adaptive to the user's ability profile
public struct AdaptiveTouchTarget: ViewModifier {
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    let style: TargetStyle

    public enum TargetStyle {
        case minimal, standard, comfortable
    }

    public func body(content: Content) -> some View {
        content
            .frame(
                minWidth: targetSize,
                minHeight: targetSize
            )
            .contentShape(Rectangle())
    }

    private var targetSize: CGFloat {
        switch style {
        case .minimal: return tokens.minTouchTarget
        case .standard: return tokens.preferredTouchTarget
        case .comfortable: return tokens.comfortTouchTarget
        }
    }
}

/// Adaptive card container
public struct AdaptiveCard: ViewModifier {
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    let isSelected: Bool

    public func body(content: Content) -> some View {
        content
            .padding(tokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .fill(VaporwaveColors.glassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .stroke(
                        isSelected ? VaporwaveColors.glassBorderActive : VaporwaveColors.glassBorder,
                        lineWidth: isSelected ? tokens.focusBorderWidth : tokens.borderWidth
                    )
            )
    }
}

/// Adaptive animation that respects motion preferences
public struct AdaptiveAnimation: ViewModifier {
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    let trigger: Bool

    public func body(content: Content) -> some View {
        if tokens.animationEnabled {
            content.animation(tokens.animationSpring, value: trigger)
        } else {
            content
        }
    }
}

/// Multi-channel feedback modifier (visual + haptic + audio)
public struct MultiChannelFeedback: ViewModifier {
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    let feedbackType: FeedbackType
    @State private var showVisualFeedback = false

    public enum FeedbackType {
        case selection, success, warning, error, impact
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                tokens.visualFeedbackEnabled && showVisualFeedback
                    ? RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .stroke(feedbackColor, lineWidth: 3)
                        .opacity(showVisualFeedback ? 1 : 0)
                    : nil
            )
            .onTapGesture {
                triggerFeedback()
            }
    }

    private var feedbackColor: Color {
        switch feedbackType {
        case .selection: return VaporwaveColors.neonCyan
        case .success: return VaporwaveColors.success
        case .warning: return VaporwaveColors.warning
        case .error: return VaporwaveColors.heartRate
        case .impact: return VaporwaveColors.neonPink
        }
    }

    private func triggerFeedback() {
        if tokens.visualFeedbackEnabled {
            showVisualFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showVisualFeedback = false
            }
        }

        #if os(iOS)
        if tokens.hapticEnabled {
            let generator: UIImpactFeedbackGenerator
            switch feedbackType {
            case .selection: generator = UIImpactFeedbackGenerator(style: .light)
            case .success: generator = UIImpactFeedbackGenerator(style: .medium)
            case .warning: generator = UIImpactFeedbackGenerator(style: .heavy)
            case .error: generator = UIImpactFeedbackGenerator(style: .heavy)
            case .impact: generator = UIImpactFeedbackGenerator(style: .rigid)
            }
            generator.impactOccurred()
        }
        #endif
    }
}

// MARK: - View Extensions

extension View {

    /// Apply adaptive touch target sizing
    public func adaptiveTouchTarget(_ style: AdaptiveTouchTarget.TargetStyle = .standard) -> some View {
        modifier(AdaptiveTouchTarget(style: style))
    }

    /// Apply adaptive card styling
    public func adaptiveCard(selected: Bool = false) -> some View {
        modifier(AdaptiveCard(isSelected: selected))
    }

    /// Apply animation that respects user preferences
    public func adaptiveAnimation(trigger: Bool) -> some View {
        modifier(AdaptiveAnimation(trigger: trigger))
    }

    /// Provide multi-channel accessibility labels
    public func inclusiveLabel(
        _ label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Adaptive spacing
    public func adaptivePadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, AdaptiveDesignTokens.shared.spacingMD)
    }

    /// Ensure accessible icon + label combination
    public func iconLabel(
        _ systemName: String,
        label: String,
        size: CGFloat? = nil,
        color: Color = VaporwaveColors.textPrimary
    ) -> some View {
        HStack(spacing: AdaptiveDesignTokens.shared.spacingSM) {
            Image(systemName: systemName)
                .font(.system(size: size ?? AdaptiveDesignTokens.shared.iconSize))
                .foregroundColor(color)
            if AdaptiveDesignTokens.shared.showLabelsAlways {
                Text(label)
                    .font(EchoelTypography.callout)
                    .foregroundColor(color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Adaptive Layout

/// A layout that adapts between grid and list based on ability profile
public struct AdaptiveGridLayout<Content: View>: View {
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    let items: Int
    @ViewBuilder let content: () -> Content

    public var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: tokens.spacingMD),
            count: max(1, tokens.preferredColumns)
        )

        ScrollView {
            LazyVGrid(columns: columns, spacing: tokens.spacingMD) {
                content()
            }
            .padding(tokens.spacingMD)
        }
    }
}

// MARK: - Semantic Icon System

/// Icons that convey meaning through shape, not just color
public enum SemanticIcon {

    /// Status icons with distinct shapes per state
    public static func status(_ level: StatusLevel) -> (name: String, color: Color) {
        let profile = AdaptiveDesignTokens.shared.profile
        switch level {
        case .excellent:
            return ("checkmark.circle.fill", AdaptiveColor.success(for: profile))
        case .good:
            return ("arrow.up.circle.fill", AdaptiveColor.success(for: profile))
        case .moderate:
            return ("minus.circle.fill", AdaptiveColor.warning(for: profile))
        case .low:
            return ("exclamationmark.triangle.fill", AdaptiveColor.warning(for: profile))
        case .critical:
            return ("xmark.octagon.fill", AdaptiveColor.error(for: profile))
        }
    }

    public enum StatusLevel {
        case excellent, good, moderate, low, critical
    }

    /// Bio metric icons
    public static var heartRate: String { "heart.fill" }
    public static var hrv: String { "waveform.path.ecg" }
    public static var coherence: String { "sparkles" }
    public static var breathing: String { "wind" }

    /// Workspace icons with consistent metaphors
    public static var audio: String { "waveform" }
    public static var video: String { "film" }
    public static var creative: String { "paintbrush" }
    public static var wellness: String { "leaf" }
    public static var collaboration: String { "person.3" }
    public static var settings: String { "gearshape" }
}

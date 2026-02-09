import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Echoelmusic Artist Brand Identity
// Professional audio-visual production suite brand system
// Design Philosophy: Confident • Premium • Evidence-Based • Accessible
//
// Guidelines Applied:
// - Apple Human Interface Guidelines (2024-2025)
// - Material Design 3 (Android)
// - Windows Fluent Design
// - Pro Audio Industry Standards (Ableton, Logic Pro, Native Instruments)
// - WCAG 2.2 AAA Accessibility
// - VR/AR Readability (visionOS, Quest)
//
// Typography: Atkinson Hyperlegible - Optimal VR/AR readability
// Primary Color: Bio-Green 💚 - Organic, wellness, growth

/// Echoelmusic Brand Colors - Professional Artist Identity
/// Color strategy: Bio-Green theme for organic wellness feel
/// Inspired by: HeartMath (wellness trust), Calm (green wellness), Nature (bio-reactive)
public struct EchoelBrand {

    // MARK: - Brand Tagline

    /// Primary tagline
    public static let tagline = [
        "Create from Within"
    ]

    /// Tagline joined
    public static let taglineJoined = "Create from Within"

    /// German tagline
    public static let taglineDE = [
        "Erschaffe aus dir heraus"
    ]

    /// Brand slogan
    public static let slogan = "Create from Within"

    /// Description
    public static let description = "Create music, film, visuals & light from your body's own signals — bio-reactive performance tools for artists."

    // MARK: - Primary Brand Colors (Bio-Green Theme 💚)

    /// Green - Primary brand color (life, bio-reactive, wellness)
    /// #22C55E - Vibrant bio-green
    public static let primary = Color(red: 0.133, green: 0.773, blue: 0.369)  // #22C55E

    /// Emerald - Secondary brand color (depth, growth)
    /// #10B981 - Rich emerald
    public static let secondary = Color(red: 0.063, green: 0.725, blue: 0.506)  // #10B981

    /// Mint - Accent color (freshness, clarity)
    /// #34D399 - Light mint
    public static let accent = Color(red: 0.204, green: 0.827, blue: 0.600)  // #34D399

    // MARK: - Legacy Aliases (for backward compatibility)

    /// Teal - Alias for primary (bio-green)
    public static let teal = primary

    /// Rose - Soft pink for heart visualization
    public static let rose = Color(red: 0.957, green: 0.447, blue: 0.714)  // #F472B6

    /// Violet - For creativity accents
    public static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)  // #A78BFA

    // MARK: - Extended Palette

    /// Emerald - Health, success, growth (same as secondary)
    public static let emerald = secondary

    /// Sky - Science, trust, clarity
    public static let sky = Color(red: 0.220, green: 0.741, blue: 0.973)  // #38BDF8

    /// Amber - Energy, warmth, Schumann resonance
    public static let amber = Color(red: 0.984, green: 0.749, blue: 0.141)  // #FBBF24

    /// Coral - Warning, attention
    public static let coral = Color(red: 0.984, green: 0.451, blue: 0.408)  // #FB7366

    // MARK: - Background System (Bio-Green Dark Theme)

    /// Deep background - Primary (dark with green undertone)
    public static let bgDeep = Color(red: 0.012, green: 0.027, blue: 0.071)  // #030712

    /// Surface background - Cards, panels (forest green tint)
    public static let bgSurface = Color(red: 0.020, green: 0.180, blue: 0.086)  // #052e16

    /// Elevated background - Modals, popovers
    public static let bgElevated = Color(red: 0.039, green: 0.212, blue: 0.133)  // #0a3622

    /// Glass overlay (green tint)
    public static let bgGlass = primary.opacity(0.08)

    // MARK: - Text Hierarchy

    /// Primary text - High emphasis
    public static let textPrimary = Color(red: 0.973, green: 0.980, blue: 0.988)  // #F8FAFC

    /// Secondary text - Medium emphasis
    public static let textSecondary = Color(red: 0.973, green: 0.980, blue: 0.988).opacity(0.75)

    /// Tertiary text - Low emphasis
    public static let textTertiary = Color(red: 0.973, green: 0.980, blue: 0.988).opacity(0.45)

    /// Disabled text
    public static let textDisabled = Color(red: 0.973, green: 0.980, blue: 0.988).opacity(0.25)

    // MARK: - Bio-Reactive Colors (Evidence-Based)

    /// Low coherence - Needs attention (warm, not alarming)
    public static let coherenceLow = Color(red: 0.984, green: 0.451, blue: 0.408)  // #FB7366

    /// Medium coherence - Transitioning
    public static let coherenceMedium = Color(red: 0.984, green: 0.749, blue: 0.141)  // #FBBF24

    /// High coherence - Flow state achieved (bio-green)
    public static let coherenceHigh = primary  // #22C55E

    // MARK: - Semantic Colors

    /// Success state
    public static let success = emerald

    /// Warning state
    public static let warning = amber

    /// Error state
    public static let error = coral

    /// Information
    public static let info = sky

    // MARK: - Border & Divider

    /// Default border (green tint)
    public static let border = primary.opacity(0.2)

    /// Active/focused border
    public static let borderActive = primary.opacity(0.5)

    // MARK: - Brainwave Colors (Evidence-Based Associations)
    // These colors are for UI differentiation, NOT claimed therapeutic effects

    /// Delta (0.5-4 Hz) - Deep violet (sleep association)
    public static let brainwaveDelta = Color(red: 0.545, green: 0.361, blue: 0.965)  // #8B5CF6

    /// Theta (4-8 Hz) - Sky blue (meditation association)
    public static let brainwaveTheta = Color(red: 0.220, green: 0.741, blue: 0.973)  // #38BDF8

    /// Alpha (8-12 Hz) - Emerald (relaxation association)
    public static let brainwaveAlpha = Color(red: 0.204, green: 0.827, blue: 0.600)  // #34D399

    /// Beta (12-30 Hz) - Amber (alertness association)
    public static let brainwaveBeta = Color(red: 0.984, green: 0.749, blue: 0.141)  // #FBBF24

    /// Gamma (30-100 Hz) - Rose (cognition association)
    public static let brainwaveGamma = Color(red: 0.957, green: 0.447, blue: 0.714)  // #F472B6
}

// MARK: - Brand Gradients

public struct EchoelGradients {

    /// Primary brand gradient (bio-green spectrum)
    public static let brand = LinearGradient(
        colors: [EchoelBrand.primary, EchoelBrand.secondary, EchoelBrand.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bio-reactive gradient (emerald to mint)
    public static let bioReactive = LinearGradient(
        colors: [EchoelBrand.secondary, EchoelBrand.primary, EchoelBrand.accent],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Background gradient (deep to surface)
    public static let background = LinearGradient(
        colors: [EchoelBrand.bgDeep, EchoelBrand.bgSurface],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Coherence gradient (low to high)
    public static let coherence = LinearGradient(
        colors: [
            EchoelBrand.coherenceLow,
            EchoelBrand.coherenceMedium,
            EchoelBrand.coherenceHigh
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Premium card gradient
    public static let card = LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Spectrum gradient (for visualizations)
    public static let spectrum = LinearGradient(
        colors: [
            EchoelBrand.brainwaveDelta,
            EchoelBrand.brainwaveTheta,
            EchoelBrand.brainwaveAlpha,
            EchoelBrand.brainwaveBeta,
            EchoelBrand.brainwaveGamma
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Typography Scale
// Recommended: Atkinson Hyperlegible for VR/AR readability
// Fallback: System font (SF Pro on Apple, Roboto on Android)
// Benefits: Distinguishable letterforms (I/l/1, O/0), optimal for Vision Pro & Quest

public struct EchoelBrandFont {

    /// Preferred font name for VR/AR readability
    /// Install from: https://fonts.google.com/specimen/Atkinson+Hyperlegible
    public static let preferredFontName = "AtkinsonHyperlegible-Regular"
    public static let preferredFontNameBold = "AtkinsonHyperlegible-Bold"

    /// Check if preferred font is available
    private static var fontAvailable: Bool {
        #if canImport(UIKit)
        return UIFont(name: preferredFontName, size: 16) != nil
        #else
        return false  // Use system font on macOS/watchOS
        #endif
    }

    /// Hero title (44pt bold)
    public static func heroTitle() -> Font {
        fontAvailable
            ? .custom(preferredFontNameBold, size: 44)
            : .system(size: 44, weight: .bold, design: .rounded)
    }

    /// Section title (28pt semibold)
    public static func sectionTitle() -> Font {
        fontAvailable
            ? .custom(preferredFontNameBold, size: 28)
            : .system(size: 28, weight: .semibold, design: .rounded)
    }

    /// Card title (20pt semibold)
    public static func cardTitle() -> Font {
        fontAvailable
            ? .custom(preferredFontNameBold, size: 20)
            : .system(size: 20, weight: .semibold, design: .default)
    }

    /// Body text (16pt regular)
    public static func body() -> Font {
        fontAvailable
            ? .custom(preferredFontName, size: 16)
            : .system(size: 16, weight: .regular, design: .default)
    }

    /// Caption (13pt regular)
    public static func caption() -> Font {
        fontAvailable
            ? .custom(preferredFontName, size: 13)
            : .system(size: 13, weight: .regular, design: .default)
    }

    /// Data display (24pt monospace) - Use system monospace for data
    public static func data() -> Font {
        .system(size: 24, weight: .medium, design: .monospaced)
    }

    /// Small data (14pt monospace)
    public static func dataSmall() -> Font {
        .system(size: 14, weight: .medium, design: .monospaced)
    }

    /// Label (12pt medium)
    public static func label() -> Font {
        fontAvailable
            ? .custom(preferredFontName, size: 12)
            : .system(size: 12, weight: .medium, design: .default)
    }
}

// MARK: - Spacing Scale

public struct EchoelSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius

public struct EchoelRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let full: CGFloat = 9999
}

// MARK: - Animation Timings

public struct EchoelAnimation {
    /// Quick interaction (0.15s)
    public static let quick: Double = 0.15

    /// Smooth transition (0.3s)
    public static let smooth: Double = 0.3

    /// Breathing animation (4s) - Evidence-based: 6 breaths/min = 10s cycle, inhale ~4s
    public static let breathing: Double = 4.0

    /// Pulse animation (1s)
    public static let pulse: Double = 1.0

    /// Coherence glow (2s)
    public static let coherenceGlow: Double = 2.0
}

// MARK: - View Modifiers

/// Professional glow effect (subtle, bio-green)
public struct EchoelGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: Double

    public init(color: Color = EchoelBrand.primary, radius: CGFloat = 12, intensity: Double = 0.5) {
        self.color = color
        self.radius = radius
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.5), radius: radius * 2)
    }
}

/// Glass card effect
public struct EchoelCard: ViewModifier {
    let isElevated: Bool

    public init(elevated: Bool = false) {
        self.isElevated = elevated
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.lg)
                    .fill(isElevated ? EchoelBrand.bgElevated : EchoelBrand.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.lg)
                            .stroke(EchoelBrand.border, lineWidth: 1)
                    )
            )
    }
}

/// Primary button style (bio-green)
public struct EchoelPrimaryButton: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoelBrandFont.body().weight(.semibold))
            .foregroundColor(EchoelBrand.bgDeep)
            .padding(.horizontal, EchoelSpacing.lg)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(LinearGradient(
                        colors: [EchoelBrand.primary, EchoelBrand.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: EchoelAnimation.quick), value: configuration.isPressed)
    }
}

/// Secondary button style (bio-green outline)
public struct EchoelSecondaryButton: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EchoelBrandFont.body().weight(.medium))
            .foregroundColor(EchoelBrand.primary)
            .padding(.horizontal, EchoelSpacing.lg)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .stroke(EchoelBrand.primary.opacity(0.5), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.md)
                            .fill(EchoelBrand.primary.opacity(configuration.isPressed ? 0.15 : 0.05))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: EchoelAnimation.quick), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply professional glow effect (bio-green by default)
    func echoelGlow(_ color: Color = EchoelBrand.primary, radius: CGFloat = 12, intensity: Double = 0.5) -> some View {
        modifier(EchoelGlow(color: color, radius: radius, intensity: intensity))
    }

    /// Apply glass card background
    func echoelCard(elevated: Bool = false) -> some View {
        modifier(EchoelCard(elevated: elevated))
    }
}

// MARK: - Evidence-Based Disclaimer

/// Disclaimer text for wellness features
/// CRITICAL: Must be displayed for all biofeedback/entrainment features
public struct EchoelDisclaimer {

    /// Short disclaimer for UI
    public static let short = """
    For relaxation and creative purposes only. Not a medical device.
    """

    /// Medium disclaimer for settings
    public static let medium = """
    Echoelmusic is designed for relaxation, creativity, and wellness exploration. \
    It is not a medical device and does not diagnose, treat, or cure any condition. \
    Individual results vary. Consult a healthcare provider for medical concerns.
    """

    /// Full disclaimer for legal
    public static let full = """
    IMPORTANT HEALTH INFORMATION

    Echoelmusic is a professional audio-visual production tool designed for creative \
    expression, relaxation, and wellness exploration. It is NOT a medical device.

    The biofeedback features (HRV coherence, breathing guides) are based on published \
    research but are provided for informational and creative purposes only. They do not \
    diagnose, treat, cure, or prevent any disease or medical condition.

    EVIDENCE LEVELS:
    • HRV Biofeedback: Moderate evidence for relaxation support
    • Breathing Exercises: Strong evidence for stress reduction
    • Audio Entrainment: Mixed evidence; individual results vary
    • Visual Features: For creative/aesthetic purposes

    WARNINGS:
    • Photosensitive users: Some visual effects may trigger seizures
    • Cardiac conditions: Consult physician before using HRV features
    • Mental health: Not a substitute for professional treatment
    • Children: Parental supervision recommended

    Individual results vary significantly. What works for one person may not work for another. \
    Always consult qualified healthcare professionals for medical advice.

    © Echoelmusic. All rights reserved.
    """

    /// Seizure warning
    public static let seizureWarning = """
    Warning: Some visual effects involve flashing lights that may trigger seizures \
    in photosensitive individuals. If you have epilepsy or a history of seizures, \
    consult your physician before use.
    """
}

// MARK: - Brand Assets Reference

/// App icon configuration
public struct EchoelIconConfig {
    /// Icon sizes for all Apple platforms
    public static let sizes: [(size: Int, scale: Int, platform: String)] = [
        // iOS
        (20, 2, "iphone"), (20, 3, "iphone"),
        (29, 2, "iphone"), (29, 3, "iphone"),
        (40, 2, "iphone"), (40, 3, "iphone"),
        (60, 2, "iphone"), (60, 3, "iphone"),
        // iPad
        (20, 1, "ipad"), (20, 2, "ipad"),
        (29, 1, "ipad"), (29, 2, "ipad"),
        (40, 1, "ipad"), (40, 2, "ipad"),
        (76, 1, "ipad"), (76, 2, "ipad"),
        (83, 2, "ipad"),
        // App Store
        (1024, 1, "ios-marketing"),
        // macOS
        (16, 1, "mac"), (16, 2, "mac"),
        (32, 1, "mac"), (32, 2, "mac"),
        (128, 1, "mac"), (128, 2, "mac"),
        (256, 1, "mac"), (256, 2, "mac"),
        (512, 1, "mac"), (512, 2, "mac"),
        // watchOS
        (24, 2, "watch"), (27, 2, "watch"),
        (29, 2, "watch"), (29, 3, "watch"),
        (40, 2, "watch"), (44, 2, "watch"),
        (50, 2, "watch"), (86, 2, "watch"),
        (98, 2, "watch"), (108, 2, "watch"),
        (1024, 1, "watch-marketing")
    ]
}

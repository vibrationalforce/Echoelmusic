import SwiftUI

/// Echoelmusic Design System
/// Comprehensive, authentic design language with glassmorphism, neumorphism, and fluid animations
///
/// Features:
/// - Adaptive color system (Light/Dark/Auto + Custom themes)
/// - Typography scale with dynamic type support
/// - Spacing & layout system
/// - Component library (Buttons, Cards, Forms)
/// - Glassmorphism & Neumorphism effects
/// - Fluid animations & micro-interactions
/// - Accessibility (VoiceOver, Dynamic Type, High Contrast)
/// - Responsive design for all screen sizes
@MainActor
struct DesignSystem {

    // MARK: - Colors

    struct Colors {
        // MARK: - Brand Colors

        struct Brand {
            /// Primary brand color - Deep Electric Blue
            static let primary = ColorSet(
                light: Color(hex: "#0066FF"),
                dark: Color(hex: "#3D8AFF"),
                vibrant: Color(hex: "#0052CC")
            )

            /// Secondary brand color - Neon Purple
            static let secondary = ColorSet(
                light: Color(hex: "#8B5CF6"),
                dark: Color(hex: "#A78BFA"),
                vibrant: Color(hex: "#7C3AED")
            )

            /// Accent color - Electric Cyan
            static let accent = ColorSet(
                light: Color(hex: "#06B6D4"),
                dark: Color(hex: "#22D3EE"),
                vibrant: Color(hex: "#0891B2")
            )

            /// Success - Vibrant Green
            static let success = ColorSet(
                light: Color(hex: "#10B981"),
                dark: Color(hex: "#34D399"),
                vibrant: Color(hex: "#059669")
            )

            /// Warning - Bright Yellow
            static let warning = ColorSet(
                light: Color(hex: "#F59E0B"),
                dark: Color(hex: "#FBBF24"),
                vibrant: Color(hex: "#D97706")
            )

            /// Error - Bold Red
            static let error = ColorSet(
                light: Color(hex: "#EF4444"),
                dark: Color(hex: "#F87171"),
                vibrant: Color(hex: "#DC2626")
            )
        }

        // MARK: - Neutral Colors

        struct Neutral {
            static let black = Color(hex: "#0A0A0A")
            static let white = Color(hex: "#FAFAFA")

            static let gray50 = Color(hex: "#F9FAFB")
            static let gray100 = Color(hex: "#F3F4F6")
            static let gray200 = Color(hex: "#E5E7EB")
            static let gray300 = Color(hex: "#D1D5DB")
            static let gray400 = Color(hex: "#9CA3AF")
            static let gray500 = Color(hex: "#6B7280")
            static let gray600 = Color(hex: "#4B5563")
            static let gray700 = Color(hex: "#374151")
            static let gray800 = Color(hex: "#1F2937")
            static let gray900 = Color(hex: "#111827")
        }

        // MARK: - Semantic Colors

        struct Semantic {
            static let background = ColorSet(
                light: Neutral.white,
                dark: Neutral.gray900
            )

            static let surface = ColorSet(
                light: Neutral.white,
                dark: Neutral.gray800
            )

            static let surfaceElevated = ColorSet(
                light: Neutral.gray50,
                dark: Neutral.gray700
            )

            static let text = ColorSet(
                light: Neutral.gray900,
                dark: Neutral.gray100
            )

            static let textSecondary = ColorSet(
                light: Neutral.gray600,
                dark: Neutral.gray400
            )

            static let textTertiary = ColorSet(
                light: Neutral.gray500,
                dark: Neutral.gray500
            )

            static let border = ColorSet(
                light: Neutral.gray200,
                dark: Neutral.gray700
            )

            static let divider = ColorSet(
                light: Neutral.gray100,
                dark: Neutral.gray800
            )
        }

        // MARK: - Gradient Colors

        struct Gradients {
            static let electricBlue = LinearGradient(
                colors: [
                    Color(hex: "#0066FF"),
                    Color(hex: "#00BFFF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            static let purpleHaze = LinearGradient(
                colors: [
                    Color(hex: "#8B5CF6"),
                    Color(hex: "#EC4899")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            static let sunsetGlow = LinearGradient(
                colors: [
                    Color(hex: "#F59E0B"),
                    Color(hex: "#EF4444"),
                    Color(hex: "#EC4899")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            static let oceanWave = LinearGradient(
                colors: [
                    Color(hex: "#06B6D4"),
                    Color(hex: "#0066FF"),
                    Color(hex: "#8B5CF6")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            static let neonGlow = RadialGradient(
                colors: [
                    Color(hex: "#A78BFA").opacity(0.8),
                    Color(hex: "#8B5CF6").opacity(0.4),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
        }

        // MARK: - Audio Visualization Colors

        struct Audio {
            static let waveform = Color(hex: "#06B6D4")
            static let peak = Color(hex: "#EF4444")
            static let spectrum = [
                Color(hex: "#8B5CF6"),
                Color(hex: "#06B6D4"),
                Color(hex: "#10B981"),
                Color(hex: "#F59E0B"),
                Color(hex: "#EF4444")
            ]
        }
    }

    // MARK: - Typography

    struct Typography {
        /// Display - Hero headings (64-96pt)
        static let display = FontStyle(
            size: 80,
            weight: .black,
            lineHeight: 1.1,
            letterSpacing: -2
        )

        /// H1 - Primary headings (48-56pt)
        static let h1 = FontStyle(
            size: 52,
            weight: .bold,
            lineHeight: 1.2,
            letterSpacing: -1.5
        )

        /// H2 - Section headings (36-40pt)
        static let h2 = FontStyle(
            size: 38,
            weight: .bold,
            lineHeight: 1.25,
            letterSpacing: -1
        )

        /// H3 - Sub-section headings (28-32pt)
        static let h3 = FontStyle(
            size: 30,
            weight: .semibold,
            lineHeight: 1.3,
            letterSpacing: -0.5
        )

        /// H4 - Component headings (24pt)
        static let h4 = FontStyle(
            size: 24,
            weight: .semibold,
            lineHeight: 1.4,
            letterSpacing: 0
        )

        /// H5 - Small headings (20pt)
        static let h5 = FontStyle(
            size: 20,
            weight: .medium,
            lineHeight: 1.4,
            letterSpacing: 0
        )

        /// Body Large - Primary body text (18pt)
        static let bodyLarge = FontStyle(
            size: 18,
            weight: .regular,
            lineHeight: 1.6,
            letterSpacing: 0
        )

        /// Body - Default body text (16pt)
        static let body = FontStyle(
            size: 16,
            weight: .regular,
            lineHeight: 1.5,
            letterSpacing: 0
        )

        /// Body Small - Secondary body text (14pt)
        static let bodySmall = FontStyle(
            size: 14,
            weight: .regular,
            lineHeight: 1.5,
            letterSpacing: 0
        )

        /// Caption - Labels & captions (12pt)
        static let caption = FontStyle(
            size: 12,
            weight: .medium,
            lineHeight: 1.4,
            letterSpacing: 0.5
        )

        /// Overline - Category labels (11pt)
        static let overline = FontStyle(
            size: 11,
            weight: .semibold,
            lineHeight: 1.3,
            letterSpacing: 1.5
        )

        /// Button - Button text (16pt)
        static let button = FontStyle(
            size: 16,
            weight: .semibold,
            lineHeight: 1.25,
            letterSpacing: 0.5
        )

        /// Code - Monospace text (14pt)
        static let code = FontStyle(
            size: 14,
            weight: .regular,
            lineHeight: 1.6,
            letterSpacing: 0,
            family: .monospaced
        )

        struct FontStyle {
            let size: CGFloat
            let weight: Font.Weight
            let lineHeight: CGFloat
            let letterSpacing: CGFloat
            let family: FontFamily

            init(size: CGFloat, weight: Font.Weight, lineHeight: CGFloat, letterSpacing: CGFloat, family: FontFamily = .system) {
                self.size = size
                self.weight = weight
                self.lineHeight = lineHeight
                self.letterSpacing = letterSpacing
                self.family = family
            }

            var font: Font {
                switch family {
                case .system:
                    return .system(size: size, weight: weight, design: .default)
                case .rounded:
                    return .system(size: size, weight: weight, design: .rounded)
                case .serif:
                    return .system(size: size, weight: weight, design: .serif)
                case .monospaced:
                    return .system(size: size, weight: weight, design: .monospaced)
                }
            }
        }

        enum FontFamily {
            case system, rounded, serif, monospaced
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        static let huge: CGFloat = 96
        static let massive: CGFloat = 128
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let none: CGFloat = 0
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    struct Shadows {
        static let small = Shadow(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )

        static let medium = Shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )

        static let large = Shadow(
            color: Color.black.opacity(0.2),
            radius: 16,
            x: 0,
            y: 8
        )

        static let xlarge = Shadow(
            color: Color.black.opacity(0.25),
            radius: 24,
            x: 0,
            y: 12
        )

        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }

    // MARK: - Glassmorphism

    struct Glass {
        static let light = GlassStyle(
            background: Color.white.opacity(0.7),
            blur: 20,
            border: Color.white.opacity(0.3),
            borderWidth: 1
        )

        static let dark = GlassStyle(
            background: Color.black.opacity(0.6),
            blur: 20,
            border: Color.white.opacity(0.1),
            borderWidth: 1
        )

        static let colorful = GlassStyle(
            background: LinearGradient(
                colors: [
                    Color(hex: "#8B5CF6").opacity(0.3),
                    Color(hex: "#06B6D4").opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            blur: 30,
            border: Color.white.opacity(0.2),
            borderWidth: 1.5
        )

        struct GlassStyle {
            let background: Any  // Color or Gradient
            let blur: CGFloat
            let border: Color
            let borderWidth: CGFloat
        }
    }

    // MARK: - Neumorphism

    struct Neumorphic {
        static let light = NeumorphicStyle(
            background: Color(hex: "#E0E5EC"),
            lightShadow: Color.white,
            darkShadow: Color.black.opacity(0.2),
            radius: 10
        )

        static let dark = NeumorphicStyle(
            background: Color(hex: "#2E3440"),
            lightShadow: Color.white.opacity(0.05),
            darkShadow: Color.black.opacity(0.5),
            radius: 10
        )

        struct NeumorphicStyle {
            let background: Color
            let lightShadow: Color
            let darkShadow: Color
            let radius: CGFloat
        }
    }

    // MARK: - Animations

    struct Animations {
        static let instant: Animation = .linear(duration: 0)
        static let quick: Animation = .easeOut(duration: 0.15)
        static let normal: Animation = .spring(response: 0.3, dampingFraction: 0.7)
        static let smooth: Animation = .spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy: Animation = .spring(response: 0.5, dampingFraction: 0.6)
        static let slow: Animation = .easeInOut(duration: 0.6)
        static let fluid: Animation = .interactiveSpring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.25)
    }

    // MARK: - Breakpoints (Responsive Design)

    struct Breakpoints {
        static let xs: CGFloat = 375   // iPhone SE
        static let sm: CGFloat = 428   // iPhone Pro Max
        static let md: CGFloat = 768   // iPad
        static let lg: CGFloat = 1024  // iPad Pro
        static let xl: CGFloat = 1440  // Desktop
        static let xxl: CGFloat = 1920 // Large Desktop
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ColorSet {
    let light: Color
    let dark: Color
    let vibrant: Color?

    init(light: Color, dark: Color, vibrant: Color? = nil) {
        self.light = light
        self.dark = dark
        self.vibrant = vibrant
    }

    func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark : light
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply glassmorphism effect
    func glassmorphic(style: DesignSystem.Glass.GlassStyle = DesignSystem.Glass.light) -> some View {
        self
            .background(
                ZStack {
                    if let color = style.background as? Color {
                        color
                    } else if let gradient = style.background as? LinearGradient {
                        gradient
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(style.border, lineWidth: style.borderWidth)
            )
            .background(.ultraThinMaterial)
            .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    /// Apply neumorphic effect
    func neumorphic(style: DesignSystem.Neumorphic.NeumorphicStyle = DesignSystem.Neumorphic.light) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(style.background)
                    .shadow(color: style.darkShadow, radius: style.radius, x: style.radius, y: style.radius)
                    .shadow(color: style.lightShadow, radius: style.radius, x: -style.radius / 2, y: -style.radius / 2)
            )
    }

    /// Apply fluid animation
    func fluidAnimation() -> some View {
        self.animation(DesignSystem.Animations.fluid, value: UUID())
    }

    /// Apply design system typography
    func typography(_ style: DesignSystem.Typography.FontStyle) -> some View {
        self
            .font(style.font)
            .lineSpacing(style.size * (style.lineHeight - 1))
            .kerning(style.letterSpacing)
    }

    /// Apply responsive padding
    func responsivePadding(_ size: CGFloat) -> some View {
        GeometryReader { geometry in
            self.padding(
                geometry.size.width < DesignSystem.Breakpoints.sm ? size * 0.75 :
                geometry.size.width < DesignSystem.Breakpoints.md ? size :
                size * 1.25
            )
        }
    }
}

// MARK: - Component Previews

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Colors
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Brand Colors")
                        .typography(DesignSystem.Typography.h2)

                    HStack(spacing: DesignSystem.Spacing.md) {
                        ColorSwatch(color: DesignSystem.Colors.Brand.primary.light, name: "Primary")
                        ColorSwatch(color: DesignSystem.Colors.Brand.secondary.light, name: "Secondary")
                        ColorSwatch(color: DesignSystem.Colors.Brand.accent.light, name: "Accent")
                    }
                }

                // Typography
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Typography")
                        .typography(DesignSystem.Typography.h2)

                    Text("Display Text")
                        .typography(DesignSystem.Typography.display)

                    Text("Heading 1")
                        .typography(DesignSystem.Typography.h1)

                    Text("Body text with proper line height and spacing.")
                        .typography(DesignSystem.Typography.body)
                }

                // Glassmorphism
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Glassmorphism")
                        .typography(DesignSystem.Typography.h2)

                    HStack {
                        Text("Glass Card")
                            .padding(DesignSystem.Spacing.lg)
                            .glassmorphic()
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color)
                .frame(width: 80, height: 80)

            Text(name)
                .typography(DesignSystem.Typography.caption)
        }
    }
}

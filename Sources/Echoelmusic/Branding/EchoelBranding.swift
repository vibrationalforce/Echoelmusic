//
//  EchoelBranding.swift
//  Echoelmusic
//
//  Complete Brand Identity System & Design Language
//  Created: 2025-11-20
//

import SwiftUI

/// Echoelmusic Brand Identity & Design System
/// Professional CI (Corporate Identity) guidelines
@available(iOS 15.0, *)
struct EchoelBranding {

    // MARK: - Color Palette

    /// Primary brand colors
    static let primary = Color(red: 103/255, green: 126/255, blue: 234/255)  // #677EEA
    static let primaryDark = Color(red: 80/255, green: 100/255, blue: 200/255)
    static let primaryLight = Color(red: 140/255, green: 160/255, blue: 255/255)

    /// Secondary brand colors
    static let secondary = Color(red: 118/255, green: 75/255, blue: 162/255)  // #764BA2
    static let secondaryDark = Color(red: 90/255, green: 50/255, blue: 130/255)
    static let secondaryLight = Color(red: 150/255, green: 110/255, blue: 200/255)

    /// Accent colors
    static let accent = Color(red: 255/255, green: 107/255, blue: 129/255)  // #FF6B81 (Coral)
    static let accentGreen = Color(red: 94/255, green: 229/255, blue: 170/255)  // #5EE5AA
    static let accentYellow = Color(red: 255/255, green: 195/255, blue: 18/255)  // #FFC312
    static let accentPurple = Color(red: 163/255, green: 103/255, blue: 255/255)  // #A367FF

    /// Neutral colors
    static let darkBackground = Color(red: 20/255, green: 20/255, blue: 30/255)  // #14141E
    static let darkCard = Color(red: 30/255, green: 30/255, blue: 45/255)  // #1E1E2D
    static let darkBorder = Color(red: 50/255, green: 50/255, blue: 70/255)

    static let lightBackground = Color(red: 245/255, green: 245/255, blue: 250/255)
    static let lightCard = Color.white
    static let lightBorder = Color(red: 220/255, green: 220/255, blue: 230/255)

    /// Semantic colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    // MARK: - Gradients

    /// Main brand gradient (primary)
    static let mainGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Vibrant gradient (accent)
    static let vibrantGradient = LinearGradient(
        colors: [accent, accentYellow, accentGreen],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Quantum therapy gradient
    static let quantumGradient = LinearGradient(
        colors: [
            Color(red: 30/255, green: 60/255, blue: 114/255),
            Color(red: 42/255, green: 82/255, blue: 152/255),
            Color(red: 72/255, green: 52/255, blue: 212/255),
            Color(red: 142/255, green: 45/255, blue: 226/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bio-reactive gradient
    static let bioGradient = LinearGradient(
        colors: [
            Color(red: 235/255, green: 51/255, blue: 73/255),
            Color(red: 244/255, green: 92/255, blue: 67/255),
            Color(red: 214/255, green: 48/255, blue: 49/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark mode gradient
    static let darkGradient = LinearGradient(
        colors: [darkBackground, darkCard],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Radial gradient (for effects)
    static func radialGradient(center: UnitPoint = .center) -> RadialGradient {
        RadialGradient(
            colors: [primary.opacity(0.8), secondary.opacity(0.3), Color.clear],
            center: center,
            startRadius: 10,
            endRadius: 300
        )
    }

    /// Angular gradient (for waveforms)
    static let angularGradient = AngularGradient(
        colors: [primary, accent, accentGreen, accentYellow, primary],
        center: .center
    )

    // MARK: - Typography

    struct Typography {
        // Display (Large titles)
        static func display(size: CGFloat = 48, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        // Headers
        static func h1(weight: Font.Weight = .bold) -> Font {
            .system(size: 32, weight: weight, design: .rounded)
        }

        static func h2(weight: Font.Weight = .bold) -> Font {
            .system(size: 28, weight: weight, design: .rounded)
        }

        static func h3(weight: Font.Weight = .semibold) -> Font {
            .system(size: 24, weight: weight, design: .rounded)
        }

        static func h4(weight: Font.Weight = .semibold) -> Font {
            .system(size: 20, weight: weight, design: .rounded)
        }

        // Body text
        static func body(weight: Font.Weight = .regular) -> Font {
            .system(size: 16, weight: weight, design: .rounded)
        }

        static func bodyLarge(weight: Font.Weight = .regular) -> Font {
            .system(size: 18, weight: weight, design: .rounded)
        }

        static func bodySmall(weight: Font.Weight = .regular) -> Font {
            .system(size: 14, weight: weight, design: .rounded)
        }

        // Captions
        static func caption(weight: Font.Weight = .regular) -> Font {
            .system(size: 12, weight: weight, design: .rounded)
        }

        static func captionSmall(weight: Font.Weight = .regular) -> Font {
            .system(size: 10, weight: weight, design: .rounded)
        }

        // Monospace (for technical displays)
        static func mono(size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999  // Fully rounded
    }

    // MARK: - Shadows

    struct Shadows {
        static let sm = Shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let md = Shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let lg = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        static let xl = Shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)

        static let glow = Shadow(color: primary.opacity(0.5), radius: 20, x: 0, y: 0)
        static let accentGlow = Shadow(color: accent.opacity(0.6), radius: 20, x: 0, y: 0)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation Durations

    struct Animation {
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
        static let verySlow: Double = 1.0

        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let easeOut = SwiftUI.Animation.easeOut(duration: normal)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: normal)
    }

    // MARK: - Icons

    struct Icons {
        // Main features
        static let instruments = "pianokeys"
        static let effects = "waveform.path.badge.plus"
        static let sessions = "music.note.list"
        static let export = "square.and.arrow.up"
        static let stream = "dot.radiowaves.left.and.right"
        static let bio = "heart.fill"
        static let quantum = "atom"
        static let scan = "waveform.path.ecg"

        // Instruments
        static let synth = "waveform"
        static let drums = "figure.drumming"
        static let keys = "pianokeys"
        static let strings = "music.quarternote.3"
        static let plucked = "guitars"

        // Controls
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let stop = "stop.fill"
        static let record = "record.circle"
        static let rewind = "backward.fill"
        static let forward = "forward.fill"

        // UI
        static let settings = "gear"
        static let info = "info.circle"
        static let help = "questionmark.circle"
        static let close = "xmark"
        static let menu = "line.3.horizontal"
        static let search = "magnifyingglass"
    }

    // MARK: - Component Styles

    struct ButtonStyles {
        /// Primary button style (CTA)
        struct Primary: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Typography.body(weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(mainGradient)
                    .cornerRadius(CornerRadius.md)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            }
        }

        /// Secondary button style
        struct Secondary: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Typography.body(weight: .medium))
                    .foregroundColor(primary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(primary, lineWidth: 1.5)
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            }
        }

        /// Ghost button style (minimal)
        struct Ghost: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Typography.body(weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0))
                    .cornerRadius(CornerRadius.sm)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            }
        }
    }

    struct CardStyles {
        /// Standard card background
        static func standard(darkMode: Bool = true) -> some View {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(darkMode ? darkCard : lightCard)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }

        /// Glass morphism card
        static func glass() -> some View {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        }

        /// Gradient card
        static func gradient() -> some View {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(mainGradient)
                .shadow(color: primary.opacity(0.4), radius: 16, x: 0, y: 8)
        }
    }

    // MARK: - Layout Guidelines

    struct Layout {
        static let screenPadding: CGFloat = Spacing.lg
        static let cardSpacing: CGFloat = Spacing.md
        static let sectionSpacing: CGFloat = Spacing.xl

        static let minTouchTarget: CGFloat = 44  // iOS HIG recommendation
        static let maxContentWidth: CGFloat = 600  // For readability on iPad
    }

    // MARK: - Brand Voice

    struct BrandVoice {
        static let tagline = "Your Heartbeat is the Tempo"
        static let subtitle = "Bio-Reactive Music Studio"
        static let description = "Transform your body into music with the world's first bio-reactive DAW for iOS."

        static let features = [
            "17 Professional Instruments",
            "20+ DSP Effects",
            "Bio-Reactive Music Creation",
            "Quantum Frequency Therapy",
            "32-Track Professional DAW",
            "MIDI 2.0 & MPE Support"
        ]
    }

    // MARK: - Accessibility

    struct Accessibility {
        static let minimumContrast: CGFloat = 4.5  // WCAG AA standard
        static let largeTextContrast: CGFloat = 3.0  // WCAG AA for large text

        static func accessibleColor(foreground: Color, background: Color) -> Color {
            // Would implement contrast checking here
            return foreground
        }
    }
}

// MARK: - View Extensions

@available(iOS 15.0, *)
extension View {
    /// Apply Echoelmusic brand gradient background
    func echoelBackground(style: BackgroundStyle = .main) -> some View {
        self.background(backgroundForStyle(style))
    }

    private func backgroundForStyle(_ style: BackgroundStyle) -> some View {
        ZStack {
            switch style {
            case .main:
                EchoelBranding.mainGradient
            case .quantum:
                EchoelBranding.quantumGradient
            case .bio:
                EchoelBranding.bioGradient
            case .dark:
                EchoelBranding.darkGradient
            }
        }
    }

    /// Apply Echoelmusic card style
    func echoelCard(style: CardStyle = .standard) -> some View {
        self
            .padding(EchoelBranding.Spacing.lg)
            .background(cardBackgroundForStyle(style))
    }

    private func cardBackgroundForStyle(_ style: CardStyle) -> some View {
        Group {
            switch style {
            case .standard:
                EchoelBranding.CardStyles.standard()
            case .glass:
                EchoelBranding.CardStyles.glass()
            case .gradient:
                EchoelBranding.CardStyles.gradient()
            }
        }
    }

    /// Apply Echoelmusic shadow
    func echoelShadow(_ shadow: EchoelBranding.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

enum BackgroundStyle {
    case main, quantum, bio, dark
}

enum CardStyle {
    case standard, glass, gradient
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
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

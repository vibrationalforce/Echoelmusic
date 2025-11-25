//
//  VaporwaveDesignSystem.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Vaporwave Palace Design System
//  Liquid Glass Aesthetic with Retro-Futuristic Vaporwave Styling
//  Neon colors, chrome effects, grid patterns, 80s/90s nostalgia
//

import SwiftUI

/// Complete design system for EOEL - Vaporwave Palace aesthetic
struct VaporwaveDesignSystem {

    // MARK: - Color Palettes

    /// Vaporwave Palace color palette - neon, pastel, chrome
    struct Colors {

        // MARK: - Primary Vaporwave Colors

        /// Neon Pink/Magenta - Primary accent
        static let neonPink = Color(red: 1.0, green: 0.08, blue: 0.58)  // #FF1493

        /// Neon Purple - Secondary accent
        static let neonPurple = Color(red: 0.58, green: 0.0, blue: 1.0)  // #9400FF

        /// Neon Cyan - Tertiary accent
        static let neonCyan = Color(red: 0.0, green: 0.98, blue: 1.0)  // #00FAFF

        /// Electric Blue
        static let electricBlue = Color(red: 0.0, green: 0.5, blue: 1.0)  // #0080FF

        /// Laser Green
        static let laserGreen = Color(red: 0.0, green: 1.0, blue: 0.5)  // #00FF80

        /// Sunset Orange
        static let sunsetOrange = Color(red: 1.0, green: 0.45, blue: 0.0)  // #FF7300

        // MARK: - Pastel Vaporwave Colors

        /// Pastel Pink
        static let pastelPink = Color(red: 1.0, green: 0.71, blue: 0.76)  // #FFB5C2

        /// Pastel Purple
        static let pastelPurple = Color(red: 0.8, green: 0.6, blue: 1.0)  // #CC99FF

        /// Pastel Blue
        static let pastelBlue = Color(red: 0.68, green: 0.85, blue: 1.0)  // #AED9FF

        /// Pastel Mint
        static let pastelMint = Color(red: 0.7, green: 1.0, blue: 0.85)  // #B3FFD9

        // MARK: - Dark Vaporwave Colors

        /// Deep Space - Background
        static let deepSpace = Color(red: 0.05, green: 0.05, blue: 0.15)  // #0D0D26

        /// Dark Purple - Secondary background
        static let darkPurple = Color(red: 0.15, green: 0.05, blue: 0.25)  // #260D40

        /// Midnight Blue - Card backgrounds
        static let midnightBlue = Color(red: 0.1, green: 0.1, blue: 0.3)  // #1A1A4D

        /// Dark Cyan - Accents
        static let darkCyan = Color(red: 0.0, green: 0.2, blue: 0.3)  // #00334D

        // MARK: - Chrome/Metallic Colors

        /// Chrome Silver
        static let chromeSilver = Color(red: 0.75, green: 0.75, blue: 0.75)  // #C0C0C0

        /// Chrome Gold
        static let chromeGold = Color(red: 1.0, green: 0.84, blue: 0.0)  // #FFD700

        /// Chrome Rose Gold
        static let chromeRoseGold = Color(red: 1.0, green: 0.76, blue: 0.8)  // #FFC2CC

        // MARK: - Gradient Collections

        /// Vaporwave sunset gradient
        static let sunsetGradient = LinearGradient(
            colors: [neonPink, sunsetOrange, pastelPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Cyber space gradient
        static let cyberGradient = LinearGradient(
            colors: [neonPurple, electricBlue, neonCyan],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Pastel dream gradient
        static let pastelGradient = LinearGradient(
            colors: [pastelPink, pastelPurple, pastelBlue, pastelMint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Dark space gradient
        static let spaceGradient = LinearGradient(
            colors: [deepSpace, darkPurple, midnightBlue],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Chrome gradient
        static let chromeGradient = LinearGradient(
            colors: [
                Color.white,
                chromeSilver,
                Color.white.opacity(0.8),
                chromeSilver
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Holographic gradient
        static let holographicGradient = LinearGradient(
            colors: [
                neonPink,
                neonPurple,
                neonCyan,
                laserGreen,
                sunsetOrange,
                neonPink
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography

    struct Typography {

        /// Display - Large headers (80pt)
        static let display = Font.system(size: 80, weight: .black, design: .rounded)

        /// Title - Page titles (48pt)
        static let title = Font.system(size: 48, weight: .heavy, design: .rounded)

        /// Headline - Section headers (32pt)
        static let headline = Font.system(size: 32, weight: .bold, design: .rounded)

        /// Subheadline - Subsections (24pt)
        static let subheadline = Font.system(size: 24, weight: .semibold, design: .rounded)

        /// Body - Regular text (16pt)
        static let body = Font.system(size: 16, weight: .medium, design: .rounded)

        /// Caption - Small text (12pt)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)

        /// Monospace - Code/numbers (16pt)
        static let monospace = Font.system(size: 16, weight: .medium, design: .monospaced)

        /// Display Monospace - Large numbers (48pt)
        static let displayMonospace = Font.system(size: 48, weight: .bold, design: .monospaced)

        // MARK: - Text Styles

        /// Neon glow text style
        static func neonGlow(color: Color) -> some View {
            EmptyView()
                .shadow(color: color, radius: 10)
                .shadow(color: color, radius: 20)
                .shadow(color: color, radius: 30)
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
        static let xxlarge: CGFloat = 48
        static let huge: CGFloat = 64
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
        static let pill: CGFloat = 9999  // Fully rounded
    }

    // MARK: - Shadow Styles

    struct Shadows {

        /// Soft shadow for cards
        static let soft = Shadow(
            color: Color.black.opacity(0.1),
            radius: 10,
            x: 0,
            y: 4
        )

        /// Neon glow shadow
        static func neonGlow(color: Color) -> [Shadow] {
            [
                Shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 0),
                Shadow(color: color.opacity(0.4), radius: 20, x: 0, y: 0),
                Shadow(color: color.opacity(0.2), radius: 30, x: 0, y: 0)
            ]
        }

        /// Chrome shine
        static let chrome = Shadow(
            color: Color.white.opacity(0.5),
            radius: 5,
            x: -2,
            y: -2
        )

        /// Deep depth
        static let deep = Shadow(
            color: Color.black.opacity(0.3),
            radius: 20,
            x: 0,
            y: 10
        )

        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }

    // MARK: - Blur Styles

    struct Blur {
        static let light: CGFloat = 5
        static let medium: CGFloat = 10
        static let heavy: CGFloat = 20
        static let extreme: CGFloat = 40
    }

    // MARK: - Icon Sizes

    struct IconSize {
        static let tiny: CGFloat = 16
        static let small: CGFloat = 24
        static let medium: CGFloat = 32
        static let large: CGFloat = 48
        static let xlarge: CGFloat = 64
        static let huge: CGFloat = 96
    }

    // MARK: - Animation Durations

    struct Animation {
        static let instant: Double = 0.1
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
        static let verySlow: Double = 1.0

        /// Smooth spring animation
        static let smoothSpring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.7,
            blendDuration: 0.2
        )

        /// Bouncy spring
        static let bouncySpring = SwiftUI.Animation.spring(
            response: 0.3,
            dampingFraction: 0.5,
            blendDuration: 0.1
        )

        /// Liquid animation
        static let liquid = SwiftUI.Animation.spring(
            response: 0.6,
            dampingFraction: 0.8,
            blendDuration: 0.3
        )
    }
}

// MARK: - Liquid Glass Material

/// Glassmorphism background material
struct LiquidGlassMaterial: View {
    var color: Color = VaporwaveDesignSystem.Colors.neonPurple
    var opacity: Double = 0.1
    var blur: CGFloat = VaporwaveDesignSystem.Blur.heavy

    var body: some View {
        ZStack {
            // Base glass
            color
                .opacity(opacity)

            // Blur overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        }
        .blur(radius: 0.5)  // Slight blur for smoothness
    }
}

// MARK: - Neon Border

/// Neon glowing border
struct NeonBorder: View {
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var width: CGFloat = 2
    var cornerRadius: CGFloat = VaporwaveDesignSystem.CornerRadius.medium

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(color, lineWidth: width)
            .shadow(color: color, radius: 5)
            .shadow(color: color, radius: 10)
            .shadow(color: color, radius: 15)
    }
}

// MARK: - Grid Pattern Background

/// Retro grid pattern
struct GridPatternBackground: View {
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var spacing: CGFloat = 40
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal lines
                ForEach(0..<Int(geometry.size.height / spacing), id: \.self) { i in
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(height: lineWidth)
                        .offset(y: CGFloat(i) * spacing)
                }

                // Vertical lines
                ForEach(0..<Int(geometry.size.width / spacing), id: \.self) { i in
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: lineWidth)
                        .offset(x: CGFloat(i) * spacing)
                }
            }
        }
    }
}

// MARK: - Holographic Effect

/// Animated holographic shimmer
struct HolographicEffect: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VaporwaveDesignSystem.Colors.holographicGradient
            .hueRotation(.degrees(phase))
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

// MARK: - Scanline Effect

/// Retro CRT scanline effect
struct ScanlineEffect: View {
    var spacing: CGFloat = 4
    var opacity: Double = 0.05

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: spacing) {
                ForEach(0..<Int(geometry.size.height / (spacing * 2)), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(opacity))
                        .frame(height: spacing)
                    Spacer()
                        .frame(height: spacing)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Chrome Text

/// Chrome metallic text effect
struct ChromeText: View {
    let text: String
    var font: Font = VaporwaveDesignSystem.Typography.display

    var body: some View {
        ZStack {
            // Back shadow
            Text(text)
                .font(font)
                .foregroundStyle(Color.black.opacity(0.5))
                .offset(x: 2, y: 2)

            // Chrome gradient
            Text(text)
                .font(font)
                .foregroundStyle(VaporwaveDesignSystem.Colors.chromeGradient)

            // Top highlight
            Text(text)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.8), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .mask(
                    Text(text)
                        .font(font)
                )
        }
    }
}

// MARK: - Neon Text

/// Neon glowing text
struct NeonText: View {
    let text: String
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var font: Font = VaporwaveDesignSystem.Typography.headline

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .shadow(color: color, radius: 5)
            .shadow(color: color, radius: 10)
            .shadow(color: color, radius: 20)
            .shadow(color: color, radius: 30)
    }
}

// MARK: - Wave Animation Background

/// Animated wave pattern
struct WaveBackground: View {
    @State private var phase: CGFloat = 0
    var color: Color = VaporwaveDesignSystem.Colors.neonPurple

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<5) { i in
                    WavePath(phase: phase + CGFloat(i) * 0.5, amplitude: 30, frequency: 3)
                        .stroke(
                            color.opacity(0.3 - Double(i) * 0.05),
                            lineWidth: 2
                        )
                        .offset(y: CGFloat(i) * 20)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
    }
}

struct WavePath: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midHeight = rect.height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / rect.width
            let sine = sin((relativeX * frequency * .pi * 2) + phase)
            let y = midHeight + (sine * amplitude)

            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Particle Effect

/// Floating particle effect
struct ParticleEffect: View {
    @State private var particles: [Particle] = []
    let particleCount: Int = 30
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 2)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
                startAnimation(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.5),
                speed: CGFloat.random(in: 0.5...2.0)
            )
        }
    }

    private func startAnimation(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            for i in particles.indices {
                particles[i].y -= particles[i].speed

                if particles[i].y < -10 {
                    particles[i].y = size.height + 10
                    particles[i].x = CGFloat.random(in: 0...size.width)
                }
            }
        }
    }
}

// MARK: - Vaporwave Card

/// Pre-styled vaporwave card component
struct VaporwaveCard<Content: View>: View {
    let content: Content
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(VaporwaveDesignSystem.Spacing.large)
            .background(
                ZStack {
                    LiquidGlassMaterial(color: glowColor, opacity: 0.15)
                    NeonBorder(color: glowColor, width: 1)
                }
            )
            .cornerRadius(VaporwaveDesignSystem.CornerRadius.large)
    }
}

// MARK: - Preview

#Preview("Vaporwave Design System") {
    ZStack {
        // Background
        VaporwaveDesignSystem.Colors.spaceGradient
            .ignoresSafeArea()

        // Grid pattern
        GridPatternBackground()
            .opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
            // Chrome title
            ChromeText(text: "EOEL", font: VaporwaveDesignSystem.Typography.display)

            // Neon subtitle
            NeonText(
                text: "VAPORWAVE PALACE",
                color: VaporwaveDesignSystem.Colors.neonCyan,
                font: VaporwaveDesignSystem.Typography.headline
            )

            // Sample cards
            HStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                VaporwaveCard(content: {
                    VStack {
                        NeonText(text: "TRACK", color: VaporwaveDesignSystem.Colors.neonPink)
                        Text("120 BPM")
                            .foregroundColor(.white)
                    }
                })

                VaporwaveCard(content: {
                    VStack {
                        NeonText(text: "SYNTH", color: VaporwaveDesignSystem.Colors.laserGreen)
                        Text("A Minor")
                            .foregroundColor(.white)
                    }
                })
            }
        }
    }
}

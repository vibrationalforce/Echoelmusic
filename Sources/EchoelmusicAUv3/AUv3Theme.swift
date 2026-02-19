//
//  AUv3Theme.swift
//  EchoelmusicAUv3
//
//  Vaporwave Palace theme for Audio Unit plugin UIs.
//  Mirrors VaporwaveTheme.swift from the main app to keep
//  a consistent look in third-party hosts (GarageBand, AUM, etc.).
//

import SwiftUI

// MARK: - AUv3 Colors (synced with echoelmusic.com + VaporwaveTheme)

enum AUv3Colors {

    // Primary Neon
    static let neonPink    = Color(red: 1.0, green: 0.08, blue: 0.58)  // #FF1494
    static let neonCyan    = Color(red: 0.0, green: 1.0, blue: 1.0)    // #00FFFF
    static let neonPurple  = Color(red: 0.6, green: 0.2, blue: 1.0)    // #9933FF
    static let lavender    = Color(red: 0.8, green: 0.6, blue: 1.0)    // #CC99FF
    static let coral       = Color(red: 1.0, green: 0.5, blue: 0.4)    // #FF7F66

    // Backgrounds
    static let deepBlack   = Color(red: 0.02, green: 0.02, blue: 0.0625)  // #050510
    static let midnightBlue = Color(red: 0.05, green: 0.05, blue: 0.15)   // #0D0D26
    static let darkPurple  = Color(red: 0.1, green: 0.05, blue: 0.2)      // #1A0D33

    // Glass
    static let glassBg     = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.15)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.85)
    static let textTertiary  = Color.white.opacity(0.5)

    // Bio-Reactive (coherence)
    static let coherenceLow    = Color(red: 1.0, green: 0.3, blue: 0.3)   // #FF4D4D
    static let coherenceMedium = Color(red: 1.0, green: 0.8, blue: 0.2)   // #FFCC33
    static let coherenceHigh   = Color(red: 0.2, green: 1.0, blue: 0.8)   // #33FFCC
}

// MARK: - AUv3 Gradients

enum AUv3Gradients {

    /// Deep space background
    static let background = LinearGradient(
        colors: [AUv3Colors.midnightBlue, AUv3Colors.darkPurple],
        startPoint: .top, endPoint: .bottom
    )

    /// Neon accent bar
    static let neon = LinearGradient(
        colors: [AUv3Colors.neonPink, AUv3Colors.neonPurple, AUv3Colors.neonCyan],
        startPoint: .leading, endPoint: .trailing
    )

    /// Sunset hero
    static let sunset = LinearGradient(
        colors: [AUv3Colors.neonPurple, AUv3Colors.neonPink, AUv3Colors.coral],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Glass Card Modifier

struct AUv3GlassCard: ViewModifier {
    var accentColor: Color = AUv3Colors.neonPink
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AUv3Colors.glassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? accentColor.opacity(0.5) : AUv3Colors.glassBorder,
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func auv3GlassCard(accent: Color = AUv3Colors.neonPink, isActive: Bool = false) -> some View {
        modifier(AUv3GlassCard(accentColor: accent, isActive: isActive))
    }
}

// MARK: - Plugin Header

struct AUv3PluginHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accentColor)
            }
            .shadow(color: accentColor.opacity(0.4), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AUv3Colors.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AUv3Colors.textTertiary)
            }

            Spacer()

            // Brand mark
            Text("echoel")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(AUv3Colors.textTertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Neon Divider

struct NeonDivider: View {
    var body: some View {
        Rectangle()
            .fill(AUv3Gradients.neon)
            .frame(height: 1)
            .opacity(0.6)
    }
}

// MARK: - Themed Parameter Section

struct AUv3Section<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .tracking(2)

            content()
        }
        .auv3GlassCard(accent: color)
    }
}

// MARK: - Themed Parameter Slider

struct AUv3Slider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    var multiplier: Float = 1
    let accentColor: Color
    let address: EchoelmusicParameterAddress
    let audioUnit: EchoelmusicAudioUnit

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AUv3Colors.textSecondary)
                .frame(width: 56, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(accentColor)
                .onChange(of: value) { _, newValue in
                    audioUnit.parameterTree?.parameter(withAddress: address.rawValue)?.value = newValue
                }

            Text(String(format: format, value * multiplier))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(accentColor)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - Deep Space Background

struct DeepSpaceBackground: View {
    var body: some View {
        ZStack {
            AUv3Gradients.background
                .ignoresSafeArea()

            // Subtle grid (vaporwave signature)
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 40
                    for x in stride(from: CGFloat(0), through: geo.size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: CGFloat(0), through: geo.size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(AUv3Colors.neonPink.opacity(0.03), lineWidth: 0.5)
            }
        }
    }
}

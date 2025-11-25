//
//  EOELThemeManager.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  EOEL Theme Manager
//  Dynamic theming with vaporwave presets
//  Hot-swappable themes for entire app
//

import SwiftUI
import Combine

/// Central theme manager for EOEL
@MainActor
class EOELThemeManager: ObservableObject {
    static let shared = EOELThemeManager()

    @Published var currentTheme: Theme = .vaporwavePalace
    @Published var customTheme: CustomTheme?

    // MARK: - Theme Definition

    enum Theme: String, CaseIterable, Identifiable {
        case vaporwavePalace = "Vaporwave Palace"
        case cyberNeon = "Cyber Neon"
        case retroSunset = "Retro Sunset"
        case pastelDream = "Pastel Dream"
        case darkChrome = "Dark Chrome"
        case oceanWave = "Ocean Wave"
        case custom = "Custom"

        var id: String { rawValue }

        var primary: Color {
            switch self {
            case .vaporwavePalace: return VaporwaveDesignSystem.Colors.neonCyan
            case .cyberNeon: return VaporwaveDesignSystem.Colors.neonPurple
            case .retroSunset: return VaporwaveDesignSystem.Colors.sunsetOrange
            case .pastelDream: return VaporwaveDesignSystem.Colors.pastelPink
            case .darkChrome: return VaporwaveDesignSystem.Colors.chromeSilver
            case .oceanWave: return VaporwaveDesignSystem.Colors.electricBlue
            case .custom: return .blue
            }
        }

        var secondary: Color {
            switch self {
            case .vaporwavePalace: return VaporwaveDesignSystem.Colors.neonPink
            case .cyberNeon: return VaporwaveDesignSystem.Colors.neonCyan
            case .retroSunset: return VaporwaveDesignSystem.Colors.neonPink
            case .pastelDream: return VaporwaveDesignSystem.Colors.pastelPurple
            case .darkChrome: return VaporwaveDesignSystem.Colors.chromeGold
            case .oceanWave: return VaporwaveDesignSystem.Colors.neonCyan
            case .custom: return .purple
            }
        }

        var accent: Color {
            switch self {
            case .vaporwavePalace: return VaporwaveDesignSystem.Colors.laserGreen
            case .cyberNeon: return VaporwaveDesignSystem.Colors.neonPink
            case .retroSunset: return VaporwaveDesignSystem.Colors.pastelPurple
            case .pastelDream: return VaporwaveDesignSystem.Colors.pastelMint
            case .darkChrome: return VaporwaveDesignSystem.Colors.chromeRoseGold
            case .oceanWave: return VaporwaveDesignSystem.Colors.laserGreen
            case .custom: return .green
            }
        }

        var background: LinearGradient {
            switch self {
            case .vaporwavePalace:
                return LinearGradient(
                    colors: [
                        VaporwaveDesignSystem.Colors.deepSpace,
                        VaporwaveDesignSystem.Colors.darkPurple,
                        VaporwaveDesignSystem.Colors.midnightBlue
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .cyberNeon:
                return LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.0, blue: 0.2),
                        Color(red: 0.2, green: 0.0, blue: 0.3),
                        Color(red: 0.1, green: 0.0, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .retroSunset:
                return LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.1, blue: 0.3),
                        Color(red: 0.6, green: 0.2, blue: 0.4),
                        Color(red: 0.4, green: 0.1, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .pastelDream:
                return LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.9, blue: 1.0),
                        Color(red: 1.0, green: 0.95, blue: 0.98),
                        Color(red: 0.98, green: 0.9, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .darkChrome:
                return LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.05),
                        Color(red: 0.1, green: 0.1, blue: 0.1),
                        Color(red: 0.05, green: 0.05, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .oceanWave:
                return LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.1, blue: 0.3),
                        Color(red: 0.0, green: 0.2, blue: 0.4),
                        Color(red: 0.0, green: 0.15, blue: 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .custom:
                return LinearGradient(
                    colors: [.black, .gray, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }

        var gridColor: Color {
            switch self {
            case .vaporwavePalace, .cyberNeon, .retroSunset:
                return primary.opacity(0.3)
            case .pastelDream:
                return primary.opacity(0.2)
            case .darkChrome:
                return chromeSilver.opacity(0.3)
            case .oceanWave:
                return neonCyan.opacity(0.3)
            case .custom:
                return .blue.opacity(0.3)
            }
        }

        private var neonCyan: Color { VaporwaveDesignSystem.Colors.neonCyan }
        private var chromeSilver: Color { VaporwaveDesignSystem.Colors.chromeSilver }
    }

    // MARK: - Custom Theme

    struct CustomTheme {
        var name: String
        var primary: Color
        var secondary: Color
        var accent: Color
        var backgroundStart: Color
        var backgroundEnd: Color

        var background: LinearGradient {
            LinearGradient(
                colors: [backgroundStart, backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Theme Switching

    func setTheme(_ theme: Theme) {
        withAnimation(VaporwaveDesignSystem.Animation.liquid) {
            currentTheme = theme
        }
        print("🎨 Theme changed to: \(theme.rawValue)")
    }

    func setCustomTheme(_ theme: CustomTheme) {
        customTheme = theme
        withAnimation(VaporwaveDesignSystem.Animation.liquid) {
            currentTheme = .custom
        }
        print("🎨 Custom theme applied: \(theme.name)")
    }

    // MARK: - Theme Access

    var primary: Color {
        currentTheme == .custom ? customTheme?.primary ?? .blue : currentTheme.primary
    }

    var secondary: Color {
        currentTheme == .custom ? customTheme?.secondary ?? .purple : currentTheme.secondary
    }

    var accent: Color {
        currentTheme == .custom ? customTheme?.accent ?? .green : currentTheme.accent
    }

    var background: LinearGradient {
        currentTheme == .custom ? customTheme?.background ?? defaultGradient : currentTheme.background
    }

    private var defaultGradient: LinearGradient {
        LinearGradient(
            colors: [.black, .gray],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Initialization

    private init() {}
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: EOELThemeManager.Theme
    @ObservedObject var themeManager = EOELThemeManager.shared

    var body: some View {
        Button {
            themeManager.setTheme(theme)
        } label: {
            VStack(spacing: VaporwaveDesignSystem.Spacing.small) {
                // Preview
                ZStack {
                    theme.background

                    VStack(spacing: 8) {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 20, height: 20)
                            .shadow(color: theme.primary, radius: 5)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(theme.secondary)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .frame(height: 100)
                .cornerRadius(VaporwaveDesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: VaporwaveDesignSystem.CornerRadius.medium)
                        .strokeBorder(
                            themeManager.currentTheme == theme ? theme.primary : Color.white.opacity(0.2),
                            lineWidth: themeManager.currentTheme == theme ? 3 : 1
                        )
                        .shadow(
                            color: themeManager.currentTheme == theme ? theme.primary.opacity(0.6) : .clear,
                            radius: 10
                        )
                )

                // Label
                Text(theme.rawValue)
                    .font(VaporwaveDesignSystem.Typography.caption)
                    .fontWeight(themeManager.currentTheme == theme ? .bold : .medium)
                    .foregroundColor(themeManager.currentTheme == theme ? theme.primary : .white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Selector View

struct ThemeSelectorView: View {
    @ObservedObject var themeManager = EOELThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveDesignSystem.Spacing.large) {
            NeonText(
                text: "THEME SELECTOR",
                color: themeManager.primary,
                font: VaporwaveDesignSystem.Typography.headline
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 3),
                spacing: VaporwaveDesignSystem.Spacing.medium
            ) {
                ForEach(EOELThemeManager.Theme.allCases.filter { $0 != .custom }) { theme in
                    ThemePreviewCard(theme: theme)
                }
            }
        }
        .padding(VaporwaveDesignSystem.Spacing.large)
        .background(
            LiquidGlassCard(glowColor: themeManager.primary) {
                EmptyView()
            }
        )
    }
}

// MARK: - Preview

#Preview("Theme Manager") {
    ZStack {
        EOELThemeManager.shared.background
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                ChromeText(text: "EOEL", font: VaporwaveDesignSystem.Typography.display)

                ThemeSelectorView()

                // Example components with current theme
                LiquidGlassCard(glowColor: EOELThemeManager.shared.primary) {
                    VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                        HStack {
                            NeonIcon(
                                systemName: EOELIcon.Music.waveformCircle,
                                color: EOELThemeManager.shared.primary,
                                size: 48
                            )

                            NeonIcon(
                                systemName: EOELIcon.Transport.playCircle,
                                color: EOELThemeManager.shared.secondary,
                                size: 48
                            )

                            NeonIcon(
                                systemName: EOELIcon.Transport.recordFill,
                                color: EOELThemeManager.shared.accent,
                                size: 48
                            )
                        }

                        LiquidGlassButton(
                            title: "PLAY",
                            icon: EOELIcon.Transport.play,
                            action: {},
                            glowColor: EOELThemeManager.shared.primary
                        )
                    }
                }
            }
            .padding()
        }
    }
}

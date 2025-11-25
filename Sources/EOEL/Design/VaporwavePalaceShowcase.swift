//
//  VaporwavePalaceShowcase.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Vaporwave Palace Design System Showcase
//  Complete demonstration of liquid glass UI with vaporwave aesthetic
//  The ultimate EOEL interface experience
//

import SwiftUI

/// Complete showcase of EOEL design system
struct VaporwavePalaceShowcase: View {
    @StateObject private var themeManager = EOELThemeManager.shared
    @State private var selectedTab = 0
    @State private var volume: Double = 0.75
    @State private var tempo: Double = 120
    @State private var cutoff: Double = 50
    @State private var resonance: Double = 75
    @State private var isPlaying = false
    @State private var isRecording = false
    @State private var showThemeSelector = false

    var body: some View {
        ZStack {
            // Animated background
            themeManager.background
                .ignoresSafeArea()

            // Grid pattern
            GridPatternBackground(color: themeManager.primary)
                .opacity(0.2)
                .ignoresSafeArea()

            // Particles
            ParticleEffect(color: themeManager.primary.opacity(0.4))
                .ignoresSafeArea()

            // Scanlines
            ScanlineOverlay(opacity: 0.05)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                headerView

                // Tab Bar
                tabBarView

                // Content
                ScrollView {
                    VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                        switch selectedTab {
                        case 0: dashboardView
                        case 1: controlsView
                        case 2: mixerView
                        case 3: effectsView
                        default: dashboardView
                        }
                    }
                    .padding()
                }
            }

            // Theme selector overlay
            if showThemeSelector {
                themeSelectorOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Logo
            VStack(alignment: .leading, spacing: 4) {
                ChromeText(
                    text: "EOEL",
                    font: VaporwaveDesignSystem.Typography.title
                )
                .glowPulse(color: themeManager.primary)

                NeonText(
                    text: "VAPORWAVE PALACE",
                    color: themeManager.primary,
                    font: VaporwaveDesignSystem.Typography.caption
                )
            }

            Spacer()

            // Status badges
            HStack(spacing: VaporwaveDesignSystem.Spacing.small) {
                if isRecording {
                    PulsingIcon(
                        systemName: EOELIcon.Transport.recordFill,
                        color: VaporwaveDesignSystem.Colors.neonPink,
                        size: 24
                    )
                    LiquidGlassBadge(text: "REC", glowColor: VaporwaveDesignSystem.Colors.neonPink)
                }

                if isPlaying {
                    LiquidGlassBadge(text: "PLAYING", glowColor: themeManager.secondary)
                }

                LiquidGlassBadge(text: "SYNC", glowColor: themeManager.accent)
            }

            // Theme selector button
            Button {
                withAnimation(VaporwaveDesignSystem.Animation.smoothSpring) {
                    showThemeSelector.toggle()
                }
            } label: {
                NeonIcon(
                    systemName: "paintpalette.fill",
                    color: themeManager.primary,
                    size: 28
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LiquidGlassMaterial(color: themeManager.primary, opacity: 0.1)
        )
    }

    // MARK: - Tab Bar

    private var tabBarView: some View {
        LiquidGlassTabBar(
            selectedTab: $selectedTab,
            tabs: [
                (EOELIcon.Studio.project, "Dashboard"),
                (EOELIcon.Mixing.mixer, "Controls"),
                (EOELIcon.Mixing.fader, "Mixer"),
                (EOELIcon.Effects.eq, "Effects")
            ],
            glowColor: themeManager.primary
        )
    }

    // MARK: - Dashboard View

    private var dashboardView: some View {
        VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
            // Welcome card
            LiquidGlassCard(glowColor: themeManager.primary) {
                VStack(alignment: .leading, spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "DESIGN SYSTEM SHOWCASE",
                        color: themeManager.primary,
                        font: VaporwaveDesignSystem.Typography.headline
                    )

                    Text("Complete liquid glass interface with vaporwave aesthetic")
                        .font(VaporwaveDesignSystem.Typography.body)
                        .foregroundColor(.white.opacity(0.8))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Components")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                            NeonText(text: "25+", color: themeManager.primary)
                        }

                        Divider().frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Themes")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                            NeonText(text: "6", color: themeManager.secondary)
                        }

                        Divider().frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Animations")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                            NeonText(text: "12+", color: themeManager.accent)
                        }
                    }
                }
            }

            // Transport controls
            LiquidGlassCard(glowColor: themeManager.secondary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.large) {
                    NeonText(
                        text: "TRANSPORT",
                        color: themeManager.secondary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    HStack(spacing: VaporwaveDesignSystem.Spacing.large) {
                        TransportButton(
                            icon: EOELIcon.Transport.backward,
                            action: {},
                            color: themeManager.primary,
                            size: 56
                        )

                        TransportButton(
                            icon: isPlaying ? EOELIcon.Transport.pause : EOELIcon.Transport.play,
                            action: { isPlaying.toggle() },
                            isActive: isPlaying,
                            color: themeManager.secondary,
                            size: 80
                        )

                        TransportButton(
                            icon: EOELIcon.Transport.recordFill,
                            action: { isRecording.toggle() },
                            isActive: isRecording,
                            color: VaporwaveDesignSystem.Colors.neonPink,
                            size: 64
                        )

                        TransportButton(
                            icon: EOELIcon.Transport.forward,
                            action: {},
                            color: themeManager.primary,
                            size: 56
                        )
                    }
                }
            }

            // Visual meters
            LiquidGlassCard(glowColor: themeManager.accent) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "LEVEL METERS",
                        color: themeManager.accent,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    HStack(spacing: 8) {
                        ForEach(0..<16) { i in
                            LiquidGlassLevelMeter(
                                level: Double.random(in: 0.2...0.9),
                                peakLevel: 0.95,
                                glowColor: themeManager.accent
                            )
                            .frame(width: 12)
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Controls View

    private var controlsView: some View {
        VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
            // Buttons
            LiquidGlassCard(glowColor: themeManager.primary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "BUTTONS",
                        color: themeManager.primary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    VStack(spacing: VaporwaveDesignSystem.Spacing.small) {
                        LiquidGlassButton(
                            title: "Primary Button",
                            icon: "star.fill",
                            action: {},
                            glowColor: themeManager.primary,
                            size: .large
                        )

                        LiquidGlassButton(
                            title: "Secondary Button",
                            icon: "heart.fill",
                            action: {},
                            glowColor: themeManager.secondary,
                            size: .medium
                        )

                        LiquidGlassButton(
                            title: "Small Button",
                            icon: "bolt.fill",
                            action: {},
                            glowColor: themeManager.accent,
                            size: .small
                        )
                    }
                }
            }

            // Sliders
            LiquidGlassCard(glowColor: themeManager.secondary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.large) {
                    NeonText(
                        text: "SLIDERS",
                        color: themeManager.secondary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    LiquidGlassSlider(
                        value: $volume,
                        range: 0...1,
                        label: "Volume",
                        glowColor: themeManager.primary
                    )

                    LiquidGlassSlider(
                        value: $tempo,
                        range: 60...200,
                        label: "Tempo (BPM)",
                        glowColor: themeManager.secondary
                    )

                    LiquidGlassProgressBar(
                        progress: volume,
                        label: "Progress",
                        glowColor: themeManager.accent
                    )
                }
            }

            // Toggles & Segments
            LiquidGlassCard(glowColor: themeManager.accent) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "TOGGLES & SEGMENTS",
                        color: themeManager.accent,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    LiquidGlassToggle(
                        isOn: .constant(true),
                        label: "Direct Monitoring",
                        glowColor: themeManager.primary
                    )

                    LiquidGlassToggle(
                        isOn: .constant(false),
                        label: "MIDI Clock Sync",
                        glowColor: themeManager.secondary
                    )

                    LiquidGlassSegmentControl(
                        selection: .constant(1),
                        options: ["Mono", "Stereo", "Surround"],
                        glowColor: themeManager.accent
                    )
                }
            }
        }
    }

    // MARK: - Mixer View

    private var mixerView: some View {
        VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
            // Knobs
            LiquidGlassCard(glowColor: themeManager.primary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "PARAMETER KNOBS",
                        color: themeManager.primary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    HStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                        LiquidGlassKnob(
                            value: $cutoff,
                            range: 0...100,
                            label: "Cutoff",
                            glowColor: themeManager.primary,
                            size: 100
                        )

                        LiquidGlassKnob(
                            value: $resonance,
                            range: 0...100,
                            label: "Resonance",
                            glowColor: themeManager.secondary,
                            size: 100
                        )

                        LiquidGlassKnob(
                            value: .constant(60),
                            range: 0...100,
                            label: "Drive",
                            glowColor: themeManager.accent,
                            size: 100
                        )
                    }
                }
            }

            // Channel strip
            LiquidGlassCard(glowColor: themeManager.secondary) {
                HStack(spacing: VaporwaveDesignSystem.Spacing.large) {
                    ForEach(0..<4) { i in
                        VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                            NeonText(
                                text: "CH \(i + 1)",
                                color: [themeManager.primary, themeManager.secondary, themeManager.accent, themeManager.primary][i],
                                font: VaporwaveDesignSystem.Typography.caption
                            )

                            LiquidGlassLevelMeter(
                                level: Double.random(in: 0.3...0.8),
                                glowColor: [themeManager.primary, themeManager.secondary, themeManager.accent, themeManager.primary][i]
                            )
                            .frame(width: 24, height: 150)

                            HStack(spacing: 4) {
                                Button("M") {}
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.orange.opacity(0.3))
                                    .cornerRadius(4)

                                Button("S") {}
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.yellow.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Effects View

    private var effectsView: some View {
        VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
            // Icons
            LiquidGlassCard(glowColor: themeManager.primary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "ICON LIBRARY",
                        color: themeManager.primary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 20) {
                        NeonIcon(systemName: EOELIcon.Music.waveformCircle, color: themeManager.primary, size: 32)
                        NeonIcon(systemName: EOELIcon.Transport.playCircle, color: themeManager.secondary, size: 32)
                        NeonIcon(systemName: EOELIcon.MIDI.piano, color: themeManager.accent, size: 32)
                        ChromeIcon(systemName: EOELIcon.Effects.eq, size: 32)
                        ChromeIcon(systemName: EOELIcon.Effects.reverb, size: 32)
                        ChromeIcon(systemName: EOELIcon.Vaporwave.cube, size: 32)
                    }
                }
            }

            // Animations
            LiquidGlassCard(glowColor: themeManager.secondary) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "ANIMATIONS",
                        color: themeManager.secondary,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    HStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                        // Loading
                        VStack {
                            LiquidLoadingIndicator(color: themeManager.primary, size: 50)
                            Text("Loading")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Floating
                        VStack {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 40))
                                .foregroundColor(themeManager.secondary)
                                .floating()
                            Text("Floating")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Rotating
                        VStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 40))
                                .foregroundColor(themeManager.accent)
                                .rotatesContinuously()
                            Text("Rotating")
                                .font(VaporwaveDesignSystem.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }

            // Wave effect
            LiquidGlassCard(glowColor: themeManager.accent) {
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "LIQUID WAVES",
                        color: themeManager.accent,
                        font: VaporwaveDesignSystem.Typography.subheadline
                    )

                    LiquidWaveEffect(color: themeManager.accent)
                        .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Theme Selector Overlay

    private var themeSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(VaporwaveDesignSystem.Animation.smoothSpring) {
                        showThemeSelector = false
                    }
                }

            ThemeSelectorView()
                .frame(maxWidth: 800)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview("Vaporwave Palace Showcase") {
    VaporwavePalaceShowcase()
        .frame(minWidth: 1200, minHeight: 900)
}

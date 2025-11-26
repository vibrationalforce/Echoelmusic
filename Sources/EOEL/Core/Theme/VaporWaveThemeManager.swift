//
//  VaporWaveThemeManager.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  COMPLETE VAPORWAVE AESTHETIC SYSTEM
//  80s/90s retro aesthetic with glitch, neon, chrome, and grid effects
//

import SwiftUI
import Combine

/// VaporWave aesthetic theme manager
///
/// **Classic VaporWave Elements:**
/// - Neon cyan/magenta/purple color palette
/// - Retro grid patterns (wireframe floors)
/// - Glitch effects (digital distortion)
/// - Chrome/metallic textures
/// - Scan lines (CRT monitor aesthetic)
/// - Japanese text (Katakana aesthetic)
/// - Greco-Roman statues (classical + modern)
/// - Sunsets/gradients (pink/purple/cyan)
///
/// **Intensity Levels:**
/// - 0%: Disabled (modern dark theme only)
/// - 25%: Subtle (neon colors, minimal effects)
/// - 50%: Moderate (colors + grid patterns)
/// - 75%: Strong (colors + grid + glitch effects)
/// - 100%: Maximum (all effects, chromatic aberration, scan lines)
@MainActor
class VaporWaveThemeManager: ObservableObject {
    static let shared = VaporWaveThemeManager()

    // MARK: - Published Properties

    /// VaporWave intensity (0.0 = off, 1.0 = maximum)
    @Published var intensity: Double = 0.75

    /// Whether VaporWave theme is enabled
    @Published var isEnabled: Bool = true

    /// Show retro grid patterns
    @Published var showGrid: Bool = true

    /// Enable glitch effects
    @Published var enableGlitchEffects: Bool = true

    /// Enable scan lines (CRT effect)
    @Published var enableScanLines: Bool = false

    /// Enable chromatic aberration
    @Published var enableChromaticAberration: Bool = false

    /// Bio-reactive intensity (0-1, driven by biofeedback)
    @Published var bioReactiveIntensity: Double = 0.5

    // MARK: - Color Palette

    /// VaporWave neon cyan
    var neonCyan: Color {
        Color(red: 0.0, green: 0.9, blue: 0.9).opacity(effectiveIntensity)
    }

    /// VaporWave neon magenta
    var neonMagenta: Color {
        Color(red: 1.0, green: 0.0, blue: 0.8).opacity(effectiveIntensity)
    }

    /// VaporWave neon purple
    var neonPurple: Color {
        Color(red: 0.8, green: 0.0, blue: 1.0).opacity(effectiveIntensity)
    }

    /// VaporWave neon pink
    var neonPink: Color {
        Color(red: 1.0, green: 0.4, blue: 0.7).opacity(effectiveIntensity)
    }

    /// VaporWave sunset orange
    var sunsetOrange: Color {
        Color(red: 1.0, green: 0.5, blue: 0.2).opacity(effectiveIntensity)
    }

    /// VaporWave electric blue
    var electricBlue: Color {
        Color(red: 0.2, green: 0.5, blue: 1.0).opacity(effectiveIntensity)
    }

    // MARK: - Gradients

    /// Classic VaporWave sunset gradient
    var sunsetGradient: LinearGradient {
        LinearGradient(
            colors: [neonPink, neonPurple, neonCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Neon grid gradient
    var gridGradient: LinearGradient {
        LinearGradient(
            colors: [neonCyan, neonMagenta],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Chrome metallic gradient
    var chromeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.9),
                Color.gray.opacity(0.7),
                Color.white.opacity(0.9),
                Color.gray.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Computed Properties

    /// Effective intensity (base * bio-reactive)
    private var effectiveIntensity: Double {
        guard isEnabled else { return 0 }
        return intensity * (0.5 + bioReactiveIntensity * 0.5)
    }

    /// Whether grid should be shown (intensity > 50%)
    var shouldShowGrid: Bool {
        isEnabled && showGrid && intensity >= 0.5
    }

    /// Whether glitch effects should be active (intensity > 75%)
    var shouldEnableGlitchEffects: Bool {
        isEnabled && enableGlitchEffects && intensity >= 0.75
    }

    /// Whether scan lines should be visible (intensity = 100%)
    var shouldEnableScanLines: Bool {
        isEnabled && enableScanLines && intensity >= 0.9
    }

    /// Whether chromatic aberration should be active (intensity = 100%)
    var shouldEnableChromaticAberration: Bool {
        isEnabled && enableChromaticAberration && intensity >= 0.9
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        intensity = UserDefaults.standard.double(forKey: "vaporwave_intensity")
        if intensity == 0 {
            intensity = 0.75  // Default
        }

        isEnabled = UserDefaults.standard.bool(forKey: "vaporwave_enabled")
        if !UserDefaults.standard.bool(forKey: "vaporwave_settings_saved") {
            isEnabled = true  // Default enabled
        }

        showGrid = UserDefaults.standard.bool(forKey: "vaporwave_show_grid")
        if !UserDefaults.standard.bool(forKey: "vaporwave_settings_saved") {
            showGrid = true
        }

        enableGlitchEffects = UserDefaults.standard.bool(forKey: "vaporwave_glitch_effects")
        enableScanLines = UserDefaults.standard.bool(forKey: "vaporwave_scan_lines")
        enableChromaticAberration = UserDefaults.standard.bool(forKey: "vaporwave_chromatic_aberration")
    }

    func saveSettings() {
        UserDefaults.standard.set(intensity, forKey: "vaporwave_intensity")
        UserDefaults.standard.set(isEnabled, forKey: "vaporwave_enabled")
        UserDefaults.standard.set(showGrid, forKey: "vaporwave_show_grid")
        UserDefaults.standard.set(enableGlitchEffects, forKey: "vaporwave_glitch_effects")
        UserDefaults.standard.set(enableScanLines, forKey: "vaporwave_scan_lines")
        UserDefaults.standard.set(enableChromaticAberration, forKey: "vaporwave_chromatic_aberration")
        UserDefaults.standard.set(true, forKey: "vaporwave_settings_saved")
    }

    // MARK: - Bio-Reactive

    /// Update bio-reactive intensity based on biofeedback
    func updateBioReactiveIntensity(coherence: Double) {
        bioReactiveIntensity = coherence
    }

    // MARK: - Presets

    func applyPreset(_ preset: VaporWavePreset) {
        switch preset {
        case .off:
            isEnabled = false
            intensity = 0.0
            showGrid = false
            enableGlitchEffects = false
            enableScanLines = false
            enableChromaticAberration = false

        case .subtle:
            isEnabled = true
            intensity = 0.25
            showGrid = false
            enableGlitchEffects = false
            enableScanLines = false
            enableChromaticAberration = false

        case .moderate:
            isEnabled = true
            intensity = 0.5
            showGrid = true
            enableGlitchEffects = false
            enableScanLines = false
            enableChromaticAberration = false

        case .strong:
            isEnabled = true
            intensity = 0.75
            showGrid = true
            enableGlitchEffects = true
            enableScanLines = false
            enableChromaticAberration = false

        case .maximum:
            isEnabled = true
            intensity = 1.0
            showGrid = true
            enableGlitchEffects = true
            enableScanLines = true
            enableChromaticAberration = true
        }

        saveSettings()
    }

    enum VaporWavePreset {
        case off
        case subtle
        case moderate
        case strong
        case maximum
    }
}

// MARK: - VaporWave View Modifiers

/// Apply VaporWave neon glow effect
struct NeonGlowModifier: ViewModifier {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(theme.effectiveIntensity * 0.8), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(theme.effectiveIntensity * 0.6), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(theme.effectiveIntensity * 0.4), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color = .cyan, radius: CGFloat = 10) -> some View {
        self.modifier(NeonGlowModifier(color: color, radius: radius))
    }
}

/// Apply VaporWave glitch effect
struct GlitchEffectModifier: ViewModifier {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?

    func body(content: Content) -> some View {
        ZStack {
            if theme.shouldEnableGlitchEffects {
                // Red channel offset
                content
                    .foregroundColor(.red)
                    .opacity(0.3)
                    .offset(x: offset * 3, y: 0)
                    .blendMode(.screen)

                // Blue channel offset
                content
                    .foregroundColor(.blue)
                    .opacity(0.3)
                    .offset(x: -offset * 3, y: 0)
                    .blendMode(.screen)

                // Original content
                content
            } else {
                content
            }
        }
        .onAppear {
            startGlitching()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startGlitching() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                offset = Bool.random() ? CGFloat.random(in: -2...2) : 0
            }
        }
    }
}

extension View {
    func glitchEffect() -> some View {
        self.modifier(GlitchEffectModifier())
    }
}

/// Apply VaporWave retro grid background
struct RetroGridBackground: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared

    var body: some View {
        ZStack {
            // Background gradient
            theme.sunsetGradient
                .ignoresSafeArea()

            if theme.shouldShowGrid {
                // Horizontal lines
                GeometryReader { geometry in
                    Path { path in
                        let spacing: CGFloat = 30
                        let lineCount = Int(geometry.size.height / spacing)

                        for i in 0..<lineCount {
                            let y = CGFloat(i) * spacing
                            // Perspective effect
                            let scale = 1.0 - (y / geometry.size.height) * 0.5
                            let width = geometry.size.width * scale
                            let xOffset = (geometry.size.width - width) / 2

                            path.move(to: CGPoint(x: xOffset, y: y))
                            path.addLine(to: CGPoint(x: xOffset + width, y: y))
                        }
                    }
                    .stroke(theme.neonCyan, lineWidth: 1)
                    .opacity(0.3)

                    // Vertical lines
                    Path { path in
                        let spacing: CGFloat = 30
                        let lineCount = 20

                        for i in 0..<lineCount {
                            let x = geometry.size.width * (CGFloat(i) / CGFloat(lineCount))

                            // Perspective convergence
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height))
                        }
                    }
                    .stroke(theme.neonMagenta, lineWidth: 1)
                    .opacity(0.2)
                }
            }
        }
    }
}

/// Apply VaporWave scan lines (CRT effect)
struct ScanLinesOverlay: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared

    var body: some View {
        if theme.shouldEnableScanLines {
            GeometryReader { geometry in
                Path { path in
                    let spacing: CGFloat = 2
                    let lineCount = Int(geometry.size.height / spacing)

                    for i in 0..<lineCount {
                        let y = CGFloat(i) * spacing
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.black, lineWidth: 1)
                .opacity(0.1)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Apply VaporWave chromatic aberration
struct ChromaticAberrationModifier: ViewModifier {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    let offset: CGFloat

    func body(content: Content) -> some View {
        if theme.shouldEnableChromaticAberration {
            ZStack {
                // Red channel
                content
                    .colorMultiply(.red)
                    .opacity(0.5)
                    .offset(x: -offset, y: 0)
                    .blendMode(.screen)

                // Green channel
                content
                    .colorMultiply(.green)
                    .opacity(0.5)

                // Blue channel
                content
                    .colorMultiply(.blue)
                    .opacity(0.5)
                    .offset(x: offset, y: 0)
                    .blendMode(.screen)
            }
        } else {
            content
        }
    }
}

extension View {
    func chromaticAberration(offset: CGFloat = 2) -> some View {
        self.modifier(ChromaticAberrationModifier(offset: offset))
    }
}

/// Complete VaporWave container
struct VaporWaveContainer<Content: View>: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background
            RetroGridBackground()

            // Content
            content

            // Scan lines overlay
            ScanLinesOverlay()
        }
    }
}

// MARK: - VaporWave Text Styles

extension View {
    /// Apply VaporWave neon text style
    func vaporWaveText(color: Color? = nil) -> some View {
        let theme = VaporWaveThemeManager.shared
        let effectiveColor = color ?? theme.neonCyan

        return self
            .foregroundColor(effectiveColor)
            .neonGlow(color: effectiveColor, radius: 8)
    }

    /// Apply VaporWave title style
    func vaporWaveTitle() -> some View {
        let theme = VaporWaveThemeManager.shared

        return self
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundStyle(theme.sunsetGradient)
            .neonGlow(color: theme.neonCyan, radius: 12)
            .glitchEffect()
    }

    /// Apply VaporWave subtitle style
    func vaporWaveSubtitle() -> some View {
        let theme = VaporWaveThemeManager.shared

        return self
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .foregroundColor(theme.neonMagenta)
            .neonGlow(color: theme.neonMagenta, radius: 6)
    }
}

// MARK: - VaporWave Button Styles

struct VaporWaveButtonStyle: ButtonStyle {
    @ObservedObject var theme = VaporWaveThemeManager.shared

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.gridGradient)
                    .opacity(configuration.isPressed ? 0.6 : 0.8)
            )
            .foregroundColor(.white)
            .neonGlow(color: theme.neonCyan, radius: 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == VaporWaveButtonStyle {
    static var vaporWave: VaporWaveButtonStyle {
        VaporWaveButtonStyle()
    }
}

// MARK: - VaporWave Card Style

struct VaporWaveCard<Content: View>: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.gridGradient, lineWidth: 2)
                    )
            )
            .neonGlow(color: theme.neonCyan, radius: 8)
    }
}

// MARK: - VaporWave Divider

struct VaporWaveDivider: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared

    var body: some View {
        Rectangle()
            .fill(theme.gridGradient)
            .frame(height: 2)
            .neonGlow(color: theme.neonCyan, radius: 4)
    }
}

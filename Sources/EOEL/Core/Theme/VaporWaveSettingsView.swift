//
//  VaporWaveSettingsView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  User-facing VaporWave theme configuration
//

import SwiftUI

/// VaporWave aesthetic settings view
struct VaporWaveSettingsView: View {
    @ObservedObject var theme = VaporWaveThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Preview section
                Section {
                    VStack(spacing: 16) {
                        Text("ＶＡＰＯＲＷＡＶＥ")
                            .vaporWaveTitle()

                        Text("エコール音楽")
                            .vaporWaveSubtitle()

                        HStack(spacing: 20) {
                            Circle()
                                .fill(theme.neonCyan)
                                .frame(width: 40, height: 40)
                                .neonGlow(color: theme.neonCyan, radius: 8)

                            Circle()
                                .fill(theme.neonMagenta)
                                .frame(width: 40, height: 40)
                                .neonGlow(color: theme.neonMagenta, radius: 8)

                            Circle()
                                .fill(theme.neonPurple)
                                .frame(width: 40, height: 40)
                                .neonGlow(color: theme.neonPurple, radius: 8)
                        }

                        Button("Test Button") {
                            PlatformHaptics.impact(.medium)
                        }
                        .buttonStyle(.vaporWave)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        ZStack {
                            // Mini grid preview
                            if theme.shouldShowGrid {
                                LinearGradient(
                                    colors: [theme.neonPink.opacity(0.3), theme.neonCyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color.black.opacity(0.6)
                            }
                        }
                        .cornerRadius(12)
                    )
                } header: {
                    Text("Preview")
                }

                // Main settings
                Section {
                    Toggle("Enable VaporWave Theme", isOn: $theme.isEnabled)
                        .onChange(of: theme.isEnabled) { _, _ in
                            theme.saveSettings()
                        }

                    if theme.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Intensity")
                                Spacer()
                                Text("\(Int(theme.intensity * 100))%")
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $theme.intensity, in: 0...1, step: 0.25)
                                .onChange(of: theme.intensity) { _, _ in
                                    theme.saveSettings()
                                }

                            HStack(spacing: 8) {
                                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                                    Text("\(Int(value * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        Text("Intensity affects all VaporWave effects. Higher values increase visual impact.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Theme Settings")
                } footer: {
                    if !theme.isEnabled {
                        Text("VaporWave theme is disabled. Enable it to access additional settings.")
                    }
                }

                // Presets
                if theme.isEnabled {
                    Section {
                        Button(action: {
                            theme.applyPreset(.subtle)
                            PlatformHaptics.impact(.light)
                        }) {
                            HStack {
                                Text("Subtle")
                                Spacer()
                                Text("25%")
                                    .foregroundColor(.secondary)
                                if theme.intensity == 0.25 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Button(action: {
                            theme.applyPreset(.moderate)
                            PlatformHaptics.impact(.light)
                        }) {
                            HStack {
                                Text("Moderate")
                                Spacer()
                                Text("50%")
                                    .foregroundColor(.secondary)
                                if theme.intensity == 0.5 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Button(action: {
                            theme.applyPreset(.strong)
                            PlatformHaptics.impact(.light)
                        }) {
                            HStack {
                                Text("Strong (Recommended)")
                                Spacer()
                                Text("75%")
                                    .foregroundColor(.secondary)
                                if theme.intensity == 0.75 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Button(action: {
                            theme.applyPreset(.maximum)
                            PlatformHaptics.impact(.light)
                        }) {
                            HStack {
                                Text("Maximum")
                                Spacer()
                                Text("100%")
                                    .foregroundColor(.secondary)
                                if theme.intensity == 1.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    } header: {
                        Text("Quick Presets")
                    } footer: {
                        Text("Strong (75%) provides the best balance of aesthetic and performance.")
                    }

                    // Advanced effects
                    Section {
                        Toggle("Retro Grid Background", isOn: $theme.showGrid)
                            .onChange(of: theme.showGrid) { _, _ in
                                theme.saveSettings()
                            }
                            .disabled(theme.intensity < 0.5)

                        Toggle("Glitch Effects", isOn: $theme.enableGlitchEffects)
                            .onChange(of: theme.enableGlitchEffects) { _, _ in
                                theme.saveSettings()
                            }
                            .disabled(theme.intensity < 0.75)

                        Toggle("Scan Lines (CRT Effect)", isOn: $theme.enableScanLines)
                            .onChange(of: theme.enableScanLines) { _, _ in
                                theme.saveSettings()
                            }
                            .disabled(theme.intensity < 0.9)

                        Toggle("Chromatic Aberration", isOn: $theme.enableChromaticAberration)
                            .onChange(of: theme.enableChromaticAberration) { _, _ in
                                theme.saveSettings()
                            }
                            .disabled(theme.intensity < 0.9)
                    } header: {
                        Text("Advanced Effects")
                    } footer: {
                        Text("Some effects require higher intensity levels. Increase intensity slider to enable.")
                    }

                    // Bio-reactive
                    Section {
                        HStack {
                            Text("Bio-Reactive Intensity")
                            Spacer()
                            Text("\(Int(theme.bioReactiveIntensity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Text("VaporWave effects respond to your heart rate coherence. Higher coherence = more intense effects.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Bio-Reactive Mode")
                    }
                }

                // About
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About VaporWave Aesthetic")
                            .font(.headline)

                        Text("VaporWave is a microgenre of electronic music and an Internet aesthetic characterized by:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("•")
                                Text("1980s/90s retro nostalgia")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Neon cyan, magenta, and purple colors")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Greco-Roman statues and Japanese text")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Digital glitch and distortion effects")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Wireframe grids and CRT scan lines")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("VaporWave Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VaporWaveSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VaporWaveSettingsView()
    }
}
#endif

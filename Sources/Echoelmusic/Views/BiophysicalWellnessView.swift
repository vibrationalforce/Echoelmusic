// BiophysicalWellnessView.swift
// Echoelmusic
//
// SwiftUI interface for biophysical wellness tool.
// Combines measurement (EVM, IMU) with stimulation (haptics, audio, visuals).
//
// DISCLAIMER: Wellness and informational use only. Not a medical device.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import SwiftUI

// MARK: - Biophysical Wellness View

/// Main view for biophysical wellness tool
public struct BiophysicalWellnessView: View {
    @StateObject private var engine = BiophysicalWellnessEngine()
    @StateObject private var cymaticsVisualizer = CymaticsVisualizer()

    @State private var showDisclaimer = true
    @State private var selectedPreset: BiophysicalPreset = .boneHarmony
    @State private var showSettings = false
    @State private var customFrequency: Double = 40.0

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if showDisclaimer {
                DisclaimerOverlay(onAcknowledge: {
                    engine.acknowledgeDisclaimer()
                    showDisclaimer = false
                })
            } else {
                mainContent
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Cymatics Visualization
            cymaticsSection
                .frame(height: 280)

            // Controls
            controlsSection

            // Session Info
            if engine.state.isActive {
                sessionInfoSection
            }

            Spacer()

            // Action Button
            actionButton
                .padding(.bottom, 32)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine, selectedPreset: $selectedPreset, customFrequency: $customFrequency)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Biophysical Resonance")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Wellness & Exploration Tool")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens biophysical wellness settings")
        }
        .padding()
    }

    // MARK: - Cymatics Section

    private var cymaticsSection: some View {
        VStack(spacing: 12) {
            // Cymatics visualization
            CymaticsView(visualizer: cymaticsVisualizer, coherence: engine.currentCoherence)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(presetColor.opacity(0.5), lineWidth: 2)
                )

            // Frequency display
            HStack {
                Label("\(engine.currentFrequency, specifier: "%.1f") Hz", systemImage: "waveform")
                    .foregroundColor(presetColor)
                    .accessibilityLabel("Frequency: \(engine.currentFrequency, specifier: "%.1f") Hertz")

                Spacer()

                Label("\(Int(engine.currentCoherence * 100))% Coherence", systemImage: "heart.fill")
                    .foregroundColor(coherenceColor)
                    .accessibilityLabel("Coherence level: \(Int(engine.currentCoherence * 100)) percent")
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cymatics visualization")
        .padding(.horizontal)
        .onChange(of: engine.currentFrequency) { newFreq in
            cymaticsVisualizer.update(
                frequency: newFreq,
                amplitude: engine.state.preset.vibrationIntensity,
                pattern: engine.state.preset.cymaticsPattern
            )
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Preset Selection
            presetSelector

            // Modality Toggles
            modalityToggles

            // Custom Frequency (if custom preset)
            if selectedPreset == .custom {
                customFrequencySlider
            }
        }
        .padding()
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wellness Preset")
                .font(.subheadline)
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BiophysicalPreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: selectedPreset == preset,
                            action: {
                                selectedPreset = preset
                            }
                        )
                    }
                }
            }
        }
    }

    private var modalityToggles: some View {
        HStack(spacing: 20) {
            ModalityToggle(
                icon: "waveform.path",
                label: "Vibration",
                isOn: Binding(
                    get: { engine.state.vibrationEnabled },
                    set: { engine.setVibrationEnabled($0) }
                )
            )

            ModalityToggle(
                icon: "speaker.wave.2.fill",
                label: "Sound",
                isOn: Binding(
                    get: { engine.state.soundEnabled },
                    set: { engine.setSoundEnabled($0) }
                )
            )

            ModalityToggle(
                icon: "sparkles",
                label: "Visuals",
                isOn: Binding(
                    get: { engine.state.visualsEnabled },
                    set: { engine.setVisualsEnabled($0) }
                )
            )
        }
    }

    private var customFrequencySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom Frequency")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(customFrequency, specifier: "%.1f") Hz")
                    .font(.subheadline)
                    .foregroundColor(presetColor)
            }

            Slider(value: $customFrequency, in: 1...60, step: 0.5)
                .tint(presetColor)
                .onChange(of: customFrequency) { newValue in
                    engine.setCustomFrequency(newValue)
                }
        }
    }

    // MARK: - Session Info

    private var sessionInfoSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                // Duration
                VStack(alignment: .leading) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatDuration(engine.state.duration))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Spacer()

                // Remaining
                VStack(alignment: .center) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatDuration(engine.remainingTime))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(engine.remainingTime < 60 ? .orange : .white)
                }

                Spacer()

                // Progress
                VStack(alignment: .trailing) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.gray)
                    CircularProgress(progress: engine.state.progress, color: presetColor)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            Task {
                if engine.state.isActive {
                    await engine.stopSession()
                } else {
                    try? await engine.startSession(preset: selectedPreset)
                }
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: engine.state.isActive ? "stop.fill" : "play.fill")
                    .font(.title3)

                Text(engine.state.isActive ? "Stop Session" : "Start Session")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(engine.state.isActive ? Color.red : presetColor)
            )
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private var presetColor: Color {
        switch selectedPreset {
        case .boneHarmony: return .orange
        case .muscleFlow: return .red
        case .neuralFocus: return .purple
        case .relaxation: return .blue
        case .circulation: return .green
        case .custom: return .cyan
        }
    }

    private var coherenceColor: Color {
        if engine.currentCoherence < 0.33 {
            return .blue
        } else if engine.currentCoherence < 0.66 {
            return .green
        } else {
            return .yellow
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Disclaimer Overlay

struct DisclaimerOverlay: View {
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.cyan)

            // Title
            Text("Biophysical Resonance Tool")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Disclaimer
            VStack(spacing: 16) {
                DisclaimerItem(icon: "info.circle.fill", text: "Informational & Wellness Use Only")
                DisclaimerItem(icon: "xmark.shield.fill", text: "No Medical Claims Made")
                DisclaimerItem(icon: "heart.text.square.fill", text: "Consult Healthcare Professionals")
                DisclaimerItem(icon: "timer", text: "15 Minute Session Limit")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )

            // Full disclaimer text
            Text("This tool explores frequency-based biofeedback for wellness purposes. It is NOT a medical device and makes no medical claims. Results vary by individual.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Acknowledge Button
            Button(action: onAcknowledge) {
                Text("I Understand - Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cyan)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct DisclaimerItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 24)

            Text(text)
                .foregroundColor(.white)

            Spacer()
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: BiophysicalPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconForPreset)
                    .font(.title2)

                Text(preset.rawValue)
                    .font(.caption)
                    .lineLimit(1)

                Text("\(Int(preset.primaryFrequency)) Hz")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? colorForPreset.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? colorForPreset : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(preset.rawValue) preset, \(Int(preset.primaryFrequency)) Hertz")
        .accessibilityHint("Double tap to select this wellness preset")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var iconForPreset: String {
        switch preset {
        case .boneHarmony: return "figure.stand"
        case .muscleFlow: return "figure.run"
        case .neuralFocus: return "brain.head.profile"
        case .relaxation: return "leaf.fill"
        case .circulation: return "heart.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    private var colorForPreset: Color {
        switch preset {
        case .boneHarmony: return .orange
        case .muscleFlow: return .red
        case .neuralFocus: return .purple
        case .relaxation: return .blue
        case .circulation: return .green
        case .custom: return .cyan
        }
    }
}

// MARK: - Modality Toggle

struct ModalityToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .cyan : .gray)

                Text(label)
                    .font(.caption)
                    .foregroundColor(isOn ? .white : .gray)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            )
        }
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var engine: BiophysicalWellnessEngine
    @Binding var selectedPreset: BiophysicalPreset
    @Binding var customFrequency: Double
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Preset Info Section
                Section("Preset Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPreset.rawValue)
                            .font(.headline)

                        Text("Frequency Range: \(Int(selectedPreset.frequencyRange.min))-\(Int(selectedPreset.frequencyRange.max)) Hz")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("Recommended Duration: \(Int(selectedPreset.recommendedDuration / 60)) minutes")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                // Educational Reference
                Section("Educational Reference") {
                    Text(selectedPreset.educationalReference)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Safety Section
                Section("Safety Information") {
                    HStack {
                        Image(systemName: "timer")
                        Text("Max Session: 15 minutes")
                    }

                    HStack {
                        Image(systemName: "waveform.path")
                        Text("Max Intensity: 80%")
                    }

                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Not a medical device")
                    }
                }

                // Disclaimer Section
                Section("Full Disclaimer") {
                    Text(BiophysicalWellnessDisclaimer.shortDisclaimer)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
#Preview {
    BiophysicalWellnessView()
}
#endif

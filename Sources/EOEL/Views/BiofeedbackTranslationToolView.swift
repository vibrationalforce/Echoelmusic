//
//  BiofeedbackTranslationToolView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  UNIFIED BIOFEEDBACK TRANSLATION TOOL UI
//  Real-time translation: Biofeedback → Audio + Visual + BPM + Modulation
//

import SwiftUI

/// Complete UI for biofeedback translation tool
struct BiofeedbackTranslationToolView: View {
    @StateObject private var tool = BiofeedbackTranslationTool.shared
    @State private var selectedPreset: BiofeedbackTranslationTool.TranslationPreset?
    @State private var showPresetInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                headerSection

                // MARK: - Output Display (Main Visual Feedback)
                outputDisplaySection

                // MARK: - Input Controls
                inputControlsSection

                // MARK: - Translation Settings
                translationSettingsSection

                // MARK: - Modulation Settings
                modulationSettingsSection

                // MARK: - Presets
                presetsSection

                // MARK: - Controls
                controlButtonsSection
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)
        .onChange(of: tool.inputHRV) { _ in tool.updateTranslation() }
        .onChange(of: tool.inputHeartRate) { _ in tool.updateTranslation() }
        .onChange(of: tool.inputCoherence) { _ in tool.updateTranslation() }
        .onChange(of: tool.inputHRVFrequency) { _ in tool.updateTranslation() }
        .onChange(of: tool.translationMode) { _ in tool.updateTranslation() }
        .onChange(of: tool.visualMapping) { _ in tool.updateTranslation() }
        .onChange(of: tool.bpmSource) { _ in tool.updateTranslation() }
        .onChange(of: tool.modulationType) { _ in tool.updateTranslation() }
        .onChange(of: tool.audioMultiplier) { _ in tool.updateTranslation() }
        .onChange(of: tool.bpmMultiplier) { _ in tool.updateTranslation() }
        .onChange(of: tool.bpmOffset) { _ in tool.updateTranslation() }
        .onAppear {
            tool.updateTranslation()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Biofeedback Translation Tool")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Direct Real-Time Translation: Biofeedback → Audio + Visual + BPM")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Status indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(tool.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(tool.isEnabled ? "ACTIVE" : "INACTIVE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(tool.isEnabled ? .green : .gray)

                if tool.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("RECORDING")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Output Display Section

    private var outputDisplaySection: some View {
        VStack(spacing: 16) {
            Text("LIVE OUTPUT")
                .font(.headline)
                .foregroundColor(.cyan)

            HStack(spacing: 16) {
                // Visual Color Display
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tool.outputVisualColor)
                            .frame(width: 120, height: 120)
                            .shadow(color: tool.outputVisualColor.opacity(0.6), radius: 20)

                        // Animated pulse
                        if tool.isEnabled {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulseScale)
                                .opacity(2 - pulseScale)
                        }
                    }

                    Text("Visual")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(tool.visualMapping.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Audio Frequency Display
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        VStack(spacing: 4) {
                            Text("\(Int(tool.outputAudioFrequency))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text("Hz")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Text("Audio")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(tool.translationMode.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // BPM Display
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        VStack(spacing: 4) {
                            Text("\(Int(tool.outputBPM))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text("BPM")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // Heart beat animation
                        if tool.isEnabled {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: heartbeatScale, height: heartbeatScale)
                        }
                    }

                    Text("Rhythm")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(tool.bpmSource.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Waveform visualization
            WaveformVisualization(
                frequency: tool.outputAudioFrequency,
                modulation: tool.modulationType,
                isAnimating: tool.isEnabled
            )
            .frame(height: 80)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Input Controls Section

    private var inputControlsSection: some View {
        VStack(spacing: 16) {
            Text("INPUT (Biofeedback)")
                .font(.headline)
                .foregroundColor(.cyan)

            // HRV
            ParameterSlider(
                title: "HRV (RMSSD)",
                value: $tool.inputHRV,
                range: 10...100,
                unit: "ms",
                color: .green
            )

            // Heart Rate
            ParameterSlider(
                title: "Heart Rate",
                value: $tool.inputHeartRate,
                range: 40...180,
                unit: "BPM",
                color: .red
            )

            // Coherence
            ParameterSlider(
                title: "Coherence",
                value: $tool.inputCoherence,
                range: 0...100,
                unit: "%",
                color: .blue
            )

            // HRV Frequency
            ParameterSlider(
                title: "HRV Frequency",
                value: $tool.inputHRVFrequency,
                range: 0.04...0.4,
                unit: "Hz",
                color: .purple,
                step: 0.01
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Translation Settings Section

    private var translationSettingsSection: some View {
        VStack(spacing: 16) {
            Text("TRANSLATION SETTINGS")
                .font(.headline)
                .foregroundColor(.cyan)

            // Translation Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Translation Mode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Translation Mode", selection: $tool.translationMode) {
                    ForEach(BiofeedbackTranslationTool.TranslationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(tool.translationMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Audio Multiplier
            if tool.translationMode == .direct || tool.translationMode == .custom {
                ParameterSlider(
                    title: "Audio Multiplier",
                    value: $tool.audioMultiplier,
                    range: 100...2000,
                    unit: "×",
                    color: .orange,
                    step: 100
                )
            }

            // Visual Mapping
            VStack(alignment: .leading, spacing: 8) {
                Text("Visual Color Mapping")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Visual Mapping", selection: $tool.visualMapping) {
                    ForEach(BiofeedbackTranslationTool.VisualMapping.allCases, id: \.self) { mapping in
                        Text(mapping.rawValue).tag(mapping)
                    }
                }
                .pickerStyle(.menu)

                Text(tool.visualMapping.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // BPM Source
            VStack(alignment: .leading, spacing: 8) {
                Text("BPM Source")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("BPM Source", selection: $tool.bpmSource) {
                    ForEach(BiofeedbackTranslationTool.BPMSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.menu)

                Text(tool.bpmSource.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // BPM Multiplier & Offset
            HStack(spacing: 12) {
                ParameterSlider(
                    title: "BPM ×",
                    value: $tool.bpmMultiplier,
                    range: 0.25...4.0,
                    unit: "×",
                    color: .pink,
                    step: 0.25
                )

                ParameterSlider(
                    title: "BPM +",
                    value: $tool.bpmOffset,
                    range: -60...60,
                    unit: "",
                    color: .pink,
                    step: 1
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Modulation Settings Section

    private var modulationSettingsSection: some View {
        VStack(spacing: 16) {
            Text("MODULATION")
                .font(.headline)
                .foregroundColor(.cyan)

            // Modulation Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Modulation Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Modulation Type", selection: $tool.modulationType) {
                    ForEach(BiofeedbackTranslationTool.ModulationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)

                Text(tool.modulationType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if tool.modulationType != .none {
                // Modulation Depth
                ParameterSlider(
                    title: "Modulation Depth",
                    value: $tool.modulationDepth,
                    range: 0...1,
                    unit: "",
                    color: .cyan,
                    step: 0.05
                )

                // Modulation Rate
                ParameterSlider(
                    title: "Modulation Rate",
                    value: $tool.modulationRate,
                    range: 0.1...10,
                    unit: "Hz",
                    color: .cyan,
                    step: 0.1
                )
            }

            // Volume
            ParameterSlider(
                title: "Volume",
                value: Binding(
                    get: { Double(tool.volume) },
                    set: { tool.setVolume(Float($0)) }
                ),
                range: 0...1,
                unit: "",
                color: .gray,
                step: 0.05
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("PRESETS")
                    .font(.headline)
                    .foregroundColor(.cyan)

                Spacer()

                Button(action: { showPresetInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.cyan)
                }
            }

            if showPresetInfo {
                Text("Quick configurations for common use cases")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BiofeedbackTranslationTool.TranslationPreset.presets, id: \.name) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: selectedPreset?.name == preset.name,
                            action: {
                                tool.applyPreset(preset)
                                selectedPreset = preset
                            }
                        )
                    }
                }
            }

            if let preset = selectedPreset {
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Control Buttons Section

    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            // Start/Stop
            Button(action: {
                if tool.isEnabled {
                    tool.stop()
                } else {
                    tool.start()
                }
            }) {
                HStack {
                    Image(systemName: tool.isEnabled ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)

                    Text(tool.isEnabled ? "Stop Translation" : "Start Translation")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(tool.isEnabled ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Recording
            HStack(spacing: 12) {
                Button(action: {
                    if tool.isRecording {
                        _ = tool.stopRecording()
                    } else {
                        tool.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: tool.isRecording ? "stop.fill" : "record.circle")
                        Text(tool.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tool.isRecording ? Color.red : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                #if DEBUG
                Button(action: {
                    tool.testTranslation()
                }) {
                    HStack {
                        Image(systemName: "hammer.circle")
                        Text("Test")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                #endif
            }
        }
    }

    // MARK: - Animations

    @State private var pulseScale: Double = 1.0
    @State private var heartbeatScale: CGFloat = 60.0

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }

        let bpm = tool.outputBPM
        let interval = 60.0 / bpm
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard tool.isEnabled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                heartbeatScale = 80.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    heartbeatScale = 60.0
                }
            }
        }
    }
}

// MARK: - Parameter Slider Component

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let color: Color
    var step: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(formatValue(value))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if step >= 1.0 {
            return String(format: "%.0f", value)
        } else if step >= 0.1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Preset Button Component

struct PresetButton: View {
    let preset: BiofeedbackTranslationTool.TranslationPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)

                    Image(systemName: "paintpalette")
                        .font(.caption2)

                    Image(systemName: "metronome")
                        .font(.caption2)
                }
                .font(.caption)
            }
            .frame(width: 140, height: 70)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                    LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Waveform Visualization Component

struct WaveformVisualization: View {
    let frequency: Double
    let modulation: BiofeedbackTranslationTool.ModulationType
    let isAnimating: Bool

    @State private var phase: Double = 0

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let midY = height / 2

            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            let points = 200
            for i in 0..<points {
                let x = (CGFloat(i) / CGFloat(points)) * width
                let normalizedFreq = frequency / 1000.0  // Normalize to 0-1 range
                let cycles = normalizedFreq * 10.0  // Scale for visibility

                var y: CGFloat
                switch modulation {
                case .none, .amplitudeModulation, .tremolo:
                    // Simple sine wave
                    y = midY + sin((Double(i) / Double(points)) * 2.0 * .pi * cycles + phase) * (height * 0.3)

                case .frequencyModulation, .vibrato:
                    // FM: varying frequency
                    let modFreq = 0.5
                    let freqDeviation = sin(Double(i) / Double(points) * 2.0 * .pi * modFreq + phase) * 2.0
                    y = midY + sin((Double(i) / Double(points)) * 2.0 * .pi * (cycles + freqDeviation) + phase) * (height * 0.3)

                case .ringModulation:
                    // Ring mod: multiple frequencies
                    let carrier = sin((Double(i) / Double(points)) * 2.0 * .pi * cycles + phase)
                    let modulator = sin((Double(i) / Double(points)) * 2.0 * .pi * 0.5 + phase)
                    y = midY + (carrier * modulator) * (height * 0.3)

                case .phaseModulation:
                    // Phase mod: phase shifts
                    let phaseShift = sin(Double(i) / Double(points) * 2.0 * .pi * 0.5 + phase) * .pi
                    y = midY + sin((Double(i) / Double(points)) * 2.0 * .pi * cycles + phase + phaseShift) * (height * 0.3)
                }

                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.cyan, .blue, .purple]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: width, y: midY)
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard isAnimating else {
                timer.invalidate()
                return
            }
            phase += 0.1
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BiofeedbackTranslationToolView_Previews: PreviewProvider {
    static var previews: some View {
        BiofeedbackTranslationToolView()
            .preferredColorScheme(.dark)
    }
}
#endif

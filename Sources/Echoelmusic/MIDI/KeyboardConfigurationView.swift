import SwiftUI

// MARK: - Keyboard Configuration View
/// Comprehensive settings UI for all keyboard parameters
/// Professional music production interface with bio-reactive and neuro-quantum controls

struct KeyboardConfigurationView: View {

    @ObservedObject var config: KeyboardConfigurationHub
    @State private var selectedTab: ConfigTab = .touch
    @Environment(\.dismiss) private var dismiss

    enum ConfigTab: String, CaseIterable, Identifiable {
        case touch = "Touch"
        case expression = "Expression"
        case mpe = "MPE"
        case visual = "Visual"
        case automation = "Automation"
        case bio = "Bio"
        case neuro = "Neuro"
        case presets = "Presets"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .touch: return "hand.tap"
            case .expression: return "waveform"
            case .mpe: return "pianokeys"
            case .visual: return "paintpalette"
            case .automation: return "gearshape.2"
            case .bio: return "heart.fill"
            case .neuro: return "brain.head.profile"
            case .presets: return "square.stack.3d.up"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ConfigTab.allCases) { tab in
                            TabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                action: { selectedTab = tab }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .touch:
                            TouchConfigSection(config: config)
                        case .expression:
                            ExpressionConfigSection(config: config)
                        case .mpe:
                            MPEConfigSection(config: config)
                        case .visual:
                            VisualConfigSection(config: config)
                        case .automation:
                            AutomationConfigSection(config: config)
                        case .bio:
                            BioConfigSection(config: config)
                        case .neuro:
                            NeuroConfigSection(config: config)
                        case .presets:
                            PresetsSection(config: config)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Keyboard Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: KeyboardConfigurationView.ConfigTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Touch Configuration Section

struct TouchConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Key Dimensions", icon: "rectangle.3.group")

            ConfigSlider(
                title: "Key Width",
                value: $config.touchConfig.keyWidthMultiplier,
                range: 0.5...2.0,
                format: "%.1fx"
            )

            ConfigSlider(
                title: "Key Height",
                value: $config.touchConfig.keyHeightMultiplier,
                range: 0.5...2.0,
                format: "%.1fx"
            )

            ConfigSlider(
                title: "Black Key Ratio",
                value: $config.touchConfig.blackKeyRatio,
                range: 0.4...0.8,
                format: "%.0f%%",
                multiplier: 100
            )

            Divider()

            SectionHeader(title: "Velocity", icon: "speedometer")

            ConfigSlider(
                title: "Sensitivity",
                value: $config.touchConfig.velocitySensitivity,
                range: 0...1,
                format: "%.0f%%",
                multiplier: 100
            )

            Picker("Velocity Curve", selection: $config.touchConfig.velocityCurve) {
                ForEach(TouchConfiguration.VelocityCurveType.allCases) { curve in
                    Text(curve.rawValue).tag(curve)
                }
            }
            .pickerStyle(.segmented)

            VelocityCurvePreview(curve: config.touchConfig.velocityCurve)
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            ConfigSlider(
                title: "Min Velocity",
                value: $config.touchConfig.velocityMin,
                range: 0...0.5,
                format: "%.0f%%",
                multiplier: 100
            )

            ConfigSlider(
                title: "Max Velocity",
                value: $config.touchConfig.velocityMax,
                range: 0.5...1,
                format: "%.0f%%",
                multiplier: 100
            )

            Divider()

            SectionHeader(title: "Haptics", icon: "iphone.radiowaves.left.and.right")

            Toggle("Enable Haptics", isOn: $config.touchConfig.hapticEnabled)

            if config.touchConfig.hapticEnabled {
                ConfigSlider(
                    title: "Haptic Intensity",
                    value: $config.touchConfig.hapticIntensity,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                ConfigSlider(
                    title: "Haptic Sharpness",
                    value: $config.touchConfig.hapticSharpness,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )
            }

            Divider()

            SectionHeader(title: "Multi-Touch", icon: "hand.point.up.braille")

            Toggle("Multi-Touch Enabled", isOn: $config.touchConfig.multiTouchEnabled)

            Stepper(
                "Max Touches: \(config.touchConfig.maxSimultaneousTouches)",
                value: $config.touchConfig.maxSimultaneousTouches,
                in: 1...15
            )
        }
    }
}

// MARK: - Expression Configuration Section

struct ExpressionConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Pitch Bend", icon: "waveform.path")

            Toggle("Enable Pitch Bend", isOn: $config.expressionConfig.pitchBendEnabled)

            if config.expressionConfig.pitchBendEnabled {
                Stepper(
                    "Range: ±\(config.expressionConfig.pitchBendRange) semitones",
                    value: $config.expressionConfig.pitchBendRange,
                    in: 1...48
                )

                ConfigSlider(
                    title: "Sensitivity",
                    value: $config.expressionConfig.pitchBendSensitivity,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                ConfigSlider(
                    title: "Smoothing",
                    value: $config.expressionConfig.pitchBendSmoothing,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                Picker("Curve", selection: $config.expressionConfig.pitchBendCurve) {
                    ForEach(ExpressionConfiguration.CurveType.allCases) { curve in
                        Text(curve.rawValue).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            SectionHeader(title: "Aftertouch", icon: "hand.point.down")

            Toggle("Enable Aftertouch", isOn: $config.expressionConfig.aftertouchEnabled)

            if config.expressionConfig.aftertouchEnabled {
                ConfigSlider(
                    title: "Sensitivity",
                    value: $config.expressionConfig.aftertouchSensitivity,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                ConfigSlider(
                    title: "Threshold",
                    value: $config.expressionConfig.aftertouchThreshold,
                    range: 0...0.5,
                    format: "%.0f%%",
                    multiplier: 100
                )
            }

            Divider()

            SectionHeader(title: "Brightness (CC74)", icon: "sun.max")

            Toggle("Enable Brightness", isOn: $config.expressionConfig.brightnessEnabled)

            ConfigSlider(
                title: "Default Value",
                value: $config.expressionConfig.defaultBrightness,
                range: 0...1,
                format: "%.0f%%",
                multiplier: 100
            )

            Divider()

            SectionHeader(title: "Expression Mapping", icon: "arrow.up.and.down.and.arrow.left.and.right")

            Picker("Vertical Axis", selection: $config.expressionConfig.verticalExpressionAxis) {
                ForEach(ExpressionConfiguration.ExpressionAxis.allCases) { axis in
                    Text(axis.rawValue).tag(axis)
                }
            }

            Picker("Horizontal Axis", selection: $config.expressionConfig.horizontalExpressionAxis) {
                ForEach(ExpressionConfiguration.ExpressionAxis.allCases) { axis in
                    Text(axis.rawValue).tag(axis)
                }
            }
        }
    }
}

// MARK: - MPE Configuration Section

struct MPEConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "MPE Mode", icon: "pianokeys")

            Toggle("Enable MPE", isOn: $config.mpeConfig.mpeEnabled)

            if config.mpeConfig.mpeEnabled {
                Stepper(
                    "Member Channels: \(config.mpeConfig.memberChannels)",
                    value: $config.mpeConfig.memberChannels,
                    in: 1...15
                )

                Stepper(
                    "Pitch Bend Range: ±\(config.mpeConfig.pitchBendRange)",
                    value: $config.mpeConfig.pitchBendRange,
                    in: 1...96
                )

                Divider()

                SectionHeader(title: "Voice Allocation", icon: "person.3")

                Picker("Mode", selection: $config.mpeConfig.voiceAllocationMode) {
                    ForEach(MPEConfiguration.VoiceAllocationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Voice Stealing", isOn: $config.mpeConfig.voiceStealingEnabled)

                if config.mpeConfig.voiceStealingEnabled {
                    Picker("Stealing Mode", selection: $config.mpeConfig.voiceStealingMode) {
                        ForEach(MPEConfiguration.VoiceStealingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                SectionHeader(title: "Per-Note Expression", icon: "music.note")

                Toggle("Per-Note Pitch Bend", isOn: $config.mpeConfig.perNotePitchBendEnabled)
                Toggle("Per-Note Pressure", isOn: $config.mpeConfig.perNotePressureEnabled)
                Toggle("Per-Note Brightness", isOn: $config.mpeConfig.perNoteBrightnessEnabled)
            }
        }
    }
}

// MARK: - Visual Configuration Section

struct VisualConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Theme", icon: "paintpalette")

            Picker("Theme", selection: $config.visualConfig.theme) {
                ForEach(VisualConfiguration.KeyboardTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.menu)

            Divider()

            SectionHeader(title: "Feedback", icon: "eye")

            ConfigSlider(
                title: "Feedback Intensity",
                value: $config.visualConfig.feedbackIntensity,
                range: 0...1,
                format: "%.0f%%",
                multiplier: 100
            )

            Toggle("Show Pitch Bend Indicator", isOn: $config.visualConfig.showPitchBendIndicator)
            Toggle("Show Pressure Indicator", isOn: $config.visualConfig.showPressureIndicator)
            Toggle("Show Note Names", isOn: $config.visualConfig.showNoteNames)
            Toggle("Show Octave Indicator", isOn: $config.visualConfig.showOctaveIndicator)
            Toggle("Show Velocity Feedback", isOn: $config.visualConfig.showVelocityFeedback)

            Divider()

            SectionHeader(title: "Animation", icon: "sparkles")

            Toggle("Key Press Animation", isOn: $config.visualConfig.keyPressAnimation)

            if config.visualConfig.keyPressAnimation {
                ConfigSlider(
                    title: "Press Scale",
                    value: $config.visualConfig.keyPressScale,
                    range: 0.8...1.0,
                    format: "%.2f"
                )

                ConfigSlider(
                    title: "Animation Duration",
                    value: $config.visualConfig.animationDuration,
                    range: 0.01...0.3,
                    format: "%.2fs"
                )
            }
        }
    }
}

// MARK: - Automation Configuration Section

struct AutomationConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Automation", icon: "gearshape.2")

            Toggle("Enable Automation", isOn: $config.automationConfig.automationEnabled)
            Toggle("MIDI Learn", isOn: $config.automationConfig.midiLearnEnabled)

            Divider()

            SectionHeader(title: "LFO", icon: "waveform")

            Toggle("Enable LFO", isOn: $config.automationConfig.lfoEnabled)

            if config.automationConfig.lfoEnabled {
                Picker("Waveform", selection: $config.automationConfig.lfoWaveform) {
                    ForEach(AutomationConfiguration.LFOWaveform.allCases) { wave in
                        Text(wave.rawValue).tag(wave)
                    }
                }
                .pickerStyle(.segmented)

                ConfigSlider(
                    title: "Rate",
                    value: $config.automationConfig.lfoRate,
                    range: 0.1...20,
                    format: "%.1f Hz"
                )

                ConfigSlider(
                    title: "Depth",
                    value: $config.automationConfig.lfoDepth,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                LFOPreview(
                    waveform: config.automationConfig.lfoWaveform,
                    rate: config.automationConfig.lfoRate
                )
                .frame(height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Divider()

            SectionHeader(title: "Envelope", icon: "chart.line.uptrend.xyaxis")

            Toggle("Enable Envelope", isOn: $config.automationConfig.envelopeEnabled)

            if config.automationConfig.envelopeEnabled {
                ConfigSlider(
                    title: "Attack",
                    value: $config.automationConfig.attack,
                    range: 0...2,
                    format: "%.2fs"
                )

                ConfigSlider(
                    title: "Decay",
                    value: $config.automationConfig.decay,
                    range: 0...2,
                    format: "%.2fs"
                )

                ConfigSlider(
                    title: "Sustain",
                    value: $config.automationConfig.sustain,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                ConfigSlider(
                    title: "Release",
                    value: $config.automationConfig.release,
                    range: 0...5,
                    format: "%.2fs"
                )

                EnvelopePreview(
                    attack: config.automationConfig.attack,
                    decay: config.automationConfig.decay,
                    sustain: config.automationConfig.sustain,
                    release: config.automationConfig.release
                )
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Bio Configuration Section

struct BioConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Bio-Reactive Mode", icon: "heart.fill")

            Toggle("Enable Bio-Reactive", isOn: $config.bioConfig.bioReactiveEnabled)

            if config.bioConfig.bioReactiveEnabled {
                // Current bio readings
                GroupBox("Current Readings") {
                    VStack(spacing: 8) {
                        BioReadingRow(
                            icon: "heart.fill",
                            label: "Heart Rate",
                            value: "\(Int(config.currentHeartRate)) BPM",
                            color: .red
                        )
                        BioReadingRow(
                            icon: "waveform.path.ecg",
                            label: "HRV",
                            value: "\(Int(config.currentHRV)) ms",
                            color: .green
                        )
                        BioReadingRow(
                            icon: "circle.hexagongrid.fill",
                            label: "Coherence",
                            value: String(format: "%.0f%%", config.currentCoherence * 100),
                            color: .blue
                        )
                        BioReadingRow(
                            icon: "wind",
                            label: "Breath Rate",
                            value: "\(Int(config.currentBreathRate))/min",
                            color: .cyan
                        )
                    }
                }

                Divider()

                SectionHeader(title: "HRV Mapping", icon: "waveform.path.ecg")

                Toggle("HRV → Expression Sensitivity", isOn: $config.bioConfig.hrvToExpressionEnabled)

                ConfigSlider(
                    title: "HRV Sensitivity",
                    value: $config.bioConfig.hrvSensitivity,
                    range: 0...2,
                    format: "%.1fx"
                )

                ConfigSlider(
                    title: "HRV Smoothing",
                    value: $config.bioConfig.hrvSmoothing,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                Divider()

                SectionHeader(title: "Heart Rate Mapping", icon: "heart")

                Toggle("Heart Rate → Tempo", isOn: $config.bioConfig.heartRateToTempoEnabled)
                Toggle("Heart Rate → Velocity", isOn: $config.bioConfig.heartRateToVelocityEnabled)

                if config.bioConfig.heartRateToTempoEnabled {
                    Text("Suggested Tempo: \(Int(config.bioConfig.suggestedTempo)) BPM")
                        .foregroundColor(.secondary)
                }

                Divider()

                SectionHeader(title: "Coherence Mapping", icon: "circle.hexagongrid")

                Toggle("Coherence → Visuals", isOn: $config.bioConfig.coherenceToVisualsEnabled)
                Toggle("Coherence → Harmonics", isOn: $config.bioConfig.coherenceToHarmonicsEnabled)

                ConfigSlider(
                    title: "Coherence Threshold",
                    value: $config.bioConfig.coherenceThreshold,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                Divider()

                SectionHeader(title: "Healing Mode", icon: "cross.circle")

                Toggle("Enable Healing Mode", isOn: $config.bioConfig.healingModeEnabled)

                if config.bioConfig.healingModeEnabled {
                    Picker("Healing Frequency", selection: $config.bioConfig.healingFrequency) {
                        ForEach(BioReactiveConfiguration.HealingFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

// MARK: - Neuro Configuration Section

struct NeuroConfigSection: View {
    @ObservedObject var config: KeyboardConfigurationHub

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Neuro-Quantum Mode", icon: "brain.head.profile")

            Toggle("Enable Neuro Mode", isOn: $config.neuroConfig.neuroModeEnabled)

            if config.neuroConfig.neuroModeEnabled {
                // Current state
                GroupBox("Current State") {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "brain")
                            Text("Brainwave: \(config.brainwaveState.rawValue.components(separatedBy: " ").first ?? "")")
                            Spacer()
                        }
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Consciousness: \(Int(config.consciousnessLevel * 100))%")
                            Spacer()
                        }
                        HStack {
                            Image(systemName: "water.waves")
                            Text("Flow State: \(Int(config.flowState * 100))%")
                            Spacer()
                        }
                    }
                }

                Divider()

                SectionHeader(title: "Brainwave Entrainment", icon: "waveform")

                Toggle("Enable Entrainment", isOn: $config.neuroConfig.brainwaveEntrainmentEnabled)

                Picker("Target Brainwave", selection: $config.neuroConfig.targetBrainwave) {
                    ForEach(BrainwaveState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .pickerStyle(.menu)

                if let suggestedTempo = config.neuroConfig.targetBrainwave.suggestedTempo as Double? {
                    Text("Suggested Tempo: \(Int(suggestedTempo)) BPM")
                        .foregroundColor(.secondary)
                    Text("Suggested Scale: \(config.neuroConfig.targetBrainwave.suggestedScale)")
                        .foregroundColor(.secondary)
                }

                Divider()

                SectionHeader(title: "Consciousness Mapping", icon: "sparkles")

                Toggle("Consciousness → Scale", isOn: $config.neuroConfig.consciousnessToScaleEnabled)
                Toggle("Consciousness → Harmony", isOn: $config.neuroConfig.consciousnessToHarmonyEnabled)

                Divider()

                SectionHeader(title: "Flow State", icon: "water.waves")

                Toggle("Flow State Detection", isOn: $config.neuroConfig.flowStateDetectionEnabled)

                ConfigSlider(
                    title: "Flow Threshold",
                    value: $config.neuroConfig.flowStateThreshold,
                    range: 0...1,
                    format: "%.0f%%",
                    multiplier: 100
                )

                Divider()

                SectionHeader(title: "Intention Setting", icon: "target")

                Toggle("Enable Intention Mode", isOn: $config.neuroConfig.intentionModeEnabled)

                if config.neuroConfig.intentionModeEnabled {
                    Picker("Current Intention", selection: $config.neuroConfig.currentIntention) {
                        ForEach(MusicalIntention.allCases) { intention in
                            Text(intention.rawValue).tag(intention)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Suggested Mode: \(config.neuroConfig.currentIntention.suggestedMode)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Presets Section

struct PresetsSection: View {
    @ObservedObject var config: KeyboardConfigurationHub
    @State private var newPresetName: String = ""
    @State private var showingSaveSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Presets", icon: "square.stack.3d.up")

            // Preset list
            ForEach(config.presets) { preset in
                PresetRow(
                    preset: preset,
                    isActive: config.activePreset?.id == preset.id,
                    onSelect: { config.loadPreset(preset) }
                )
            }

            Divider()

            // Save current
            Button(action: { showingSaveSheet = true }) {
                Label("Save Current Settings", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showingSaveSheet) {
                SavePresetSheet(
                    name: $newPresetName,
                    onSave: {
                        if !newPresetName.isEmpty {
                            _ = config.saveCurrentAsPreset(name: newPresetName)
                            newPresetName = ""
                            showingSaveSheet = false
                        }
                    },
                    onCancel: { showingSaveSheet = false }
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
        }
    }
}

struct ConfigSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    var multiplier: Float = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value * multiplier))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct ConfigSlider_Int: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Slider(value: Binding(
                get: { Float(value) },
                set: { value = Int($0) }
            ), in: Float(range.lowerBound)...Float(range.upperBound), step: 1)
        }
    }
}

struct BioReadingRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PresetRow: View {
    let preset: KeyboardPreset
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isActive ? .green : .gray)
                Text(preset.name)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

struct SavePresetSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Preset Name", text: $name)
            }
            .navigationTitle("Save Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - Preview Components

struct VelocityCurvePreview: View {
    let curve: TouchConfiguration.VelocityCurveType

    var body: some View {
        Canvas { context, size in
            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, to: size.width, by: 2) {
                    let input = Float(x / size.width)
                    let output = curve.apply(input)
                    let y = size.height - CGFloat(output) * size.height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(.blue), lineWidth: 2)

            // Draw linear reference
            let linearPath = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: 0))
            }
            context.stroke(linearPath, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
        .padding(8)
    }
}

struct LFOPreview: View {
    let waveform: AutomationConfiguration.LFOWaveform
    let rate: Float

    @State private var phase: CGFloat = 0
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                for x in stride(from: 0, to: size.width, by: 2) {
                    let normalizedX = CGFloat(x / size.width) * 2 * .pi + phase
                    let y = waveformValue(normalizedX) * size.height / 2 + size.height / 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(.green), lineWidth: 2)
        }
        .onReceive(timer) { _ in
            phase += CGFloat(rate) * 0.1
            if phase > 2 * .pi { phase -= 2 * .pi }
        }
        .padding(8)
    }

    private func waveformValue(_ x: CGFloat) -> CGFloat {
        switch waveform {
        case .sine: return -sin(x)
        case .triangle: return 2 * abs(x.truncatingRemainder(dividingBy: 2 * .pi) / .pi - 1) - 1
        case .square: return x.truncatingRemainder(dividingBy: 2 * .pi) < .pi ? -1 : 1
        case .sawtooth: return x.truncatingRemainder(dividingBy: 2 * .pi) / .pi - 1
        case .random: return CGFloat.random(in: -1...1)
        }
    }
}

struct EnvelopePreview: View {
    let attack: Float
    let decay: Float
    let sustain: Float
    let release: Float

    var body: some View {
        Canvas { context, size in
            let totalTime = attack + decay + 0.5 + release // 0.5 for sustain display
            let attackEnd = CGFloat(attack / totalTime) * size.width
            let decayEnd = attackEnd + CGFloat(decay / totalTime) * size.width
            let sustainEnd = decayEnd + 0.5 / CGFloat(totalTime) * size.width
            let sustainY = size.height - CGFloat(sustain) * size.height

            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: attackEnd, y: 0))
                path.addLine(to: CGPoint(x: decayEnd, y: sustainY))
                path.addLine(to: CGPoint(x: sustainEnd, y: sustainY))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
            }
            context.stroke(path, with: .color(.orange), lineWidth: 2)

            // Labels
            let labels = [("A", attackEnd/2), ("D", (attackEnd + decayEnd)/2), ("S", (decayEnd + sustainEnd)/2), ("R", (sustainEnd + size.width)/2)]
            for (label, x) in labels {
                let text = Text(label).font(.caption2)
                context.draw(text, at: CGPoint(x: x, y: size.height - 10))
            }
        }
        .padding(8)
    }
}

// MARK: - Preview

#if DEBUG
struct KeyboardConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardConfigurationView(config: KeyboardConfigurationHub.shared)
    }
}
#endif

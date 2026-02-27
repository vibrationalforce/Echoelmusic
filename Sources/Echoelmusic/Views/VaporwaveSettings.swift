import SwiftUI

// MARK: - Echoel Settings View
// Einstellungen im monochrome Echoelmusic Brand Design

struct VaporwaveSettings: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var oscEnabled = true
    @State private var oscHost = "127.0.0.1"
    @State private var oscPort = "9000"
    @State private var midiEnabled = false
    @State private var selectedMidiDevice = 0

    @State private var hrvToFilter = true
    @State private var coherenceToReverb = true
    @State private var heartRateToTempo = true
    @State private var stressToCompression = false

    @State private var visualQuality: VisualQuality = .high
    @State private var hapticFeedback = true

    enum VisualQuality: String, CaseIterable {
        case low = "Battery Saver"
        case medium = "Balanced"
        case high = "Maximum"
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                EchoelBrand.bgDeep
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EchoelSpacing.lg) {

                        // Bio-Reactive Mappings
                        settingsSection(title: "BIO-REACTIVE", icon: "heart.circle") {
                            bioReactiveSettings
                        }

                        // OSC Output
                        settingsSection(title: "OSC OUTPUT", icon: "antenna.radiowaves.left.and.right") {
                            oscSettings
                        }

                        // MIDI
                        settingsSection(title: "MIDI", icon: "pianokeys") {
                            midiSettings
                        }

                        // Visual
                        settingsSection(title: "VISUALS", icon: "sparkles") {
                            visualSettings
                        }

                        // About
                        settingsSection(title: "ABOUT", icon: "info.circle") {
                            aboutSection
                        }
                    }
                    .padding(EchoelSpacing.lg)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SETTINGS")
                        .font(EchoelBrandFont.sectionTitle())
                        .foregroundColor(EchoelBrand.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                    .accessibilityLabel("Close settings")
                }
            }
        }
    }

    // MARK: - Settings Section Container

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            // Header
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(EchoelBrand.primary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EchoelBrand.primary)
                    .tracking(2)

                Spacer()
            }

            // Content
            VStack(spacing: EchoelSpacing.sm) {
                content()
            }
            .padding(EchoelSpacing.md)
            .echoelCard()
        }
    }

    // MARK: - Bio-Reactive Settings

    private var bioReactiveSettings: some View {
        VStack(spacing: EchoelSpacing.md) {
            settingsToggle(
                title: "HRV → Filter",
                subtitle: "Heart rate variability controls filter brightness",
                isOn: $hrvToFilter,
                color: EchoelBrand.emerald
            )

            settingsToggle(
                title: "Coherence → Reverb",
                subtitle: "Flow state opens up the space",
                isOn: $coherenceToReverb,
                color: EchoelBrand.coherenceHigh
            )

            settingsToggle(
                title: "Heart Rate → Tempo",
                subtitle: "Sync delay time to your heartbeat",
                isOn: $heartRateToTempo,
                color: EchoelBrand.rose
            )

            settingsToggle(
                title: "Stress → Compression",
                subtitle: "Tension increases audio compression",
                isOn: $stressToCompression,
                color: EchoelBrand.coherenceLow
            )
        }
    }

    // MARK: - OSC Settings

    private var oscSettings: some View {
        VStack(spacing: EchoelSpacing.md) {
            settingsToggle(
                title: "Enable OSC Output",
                subtitle: "Send bio-data to external software",
                isOn: $oscEnabled,
                color: EchoelBrand.violet
            )

            if oscEnabled {
                HStack(spacing: EchoelSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOST")
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textTertiary)

                        TextField("127.0.0.1", text: $oscHost)
                            .font(EchoelBrandFont.body())
                            .foregroundColor(EchoelBrand.textPrimary)
                            .padding(EchoelSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(EchoelBrand.bgElevated)
                            )
                            .keyboardType(.numbersAndPunctuation)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PORT")
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textTertiary)

                        TextField("9000", text: $oscPort)
                            .font(EchoelBrandFont.body())
                            .foregroundColor(EchoelBrand.textPrimary)
                            .padding(EchoelSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(EchoelBrand.bgElevated)
                            )
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }

                // Presets
                VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                    Text("PRESETS")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textTertiary)

                    HStack(spacing: EchoelSpacing.sm) {
                        presetButton("TouchDesigner", port: "9000")
                        presetButton("Resolume", port: "7000")
                        presetButton("Ableton", port: "9001")
                    }
                }
            }
        }
    }

    private func presetButton(_ name: String, port: String) -> some View {
        Button(action: { oscPort = port }) {
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(oscPort == port ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(oscPort == port ? EchoelBrand.bgElevated : EchoelBrand.bgSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(oscPort == port ? EchoelBrand.borderActive : EchoelBrand.border, lineWidth: 1)
                )
        }
    }

    // MARK: - MIDI Settings

    private var midiSettings: some View {
        VStack(spacing: EchoelSpacing.md) {
            settingsToggle(
                title: "Enable MIDI Output",
                subtitle: "Send CC messages to hardware/software",
                isOn: $midiEnabled,
                color: EchoelBrand.amber
            )

            if midiEnabled {
                HStack {
                    Text("MIDI Device")
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.textSecondary)

                    Spacer()

                    Picker("Device", selection: $selectedMidiDevice) {
                        Text("IAC Driver").tag(0)
                        Text("USB MIDI").tag(1)
                        Text("Bluetooth").tag(2)
                    }
                    .pickerStyle(.menu)
                    .tint(EchoelBrand.primary)
                }
            }
        }
    }

    // MARK: - Visual Settings

    @ObservedObject private var themeManager = ThemeManager.shared

    private var visualSettings: some View {
        VStack(spacing: EchoelSpacing.md) {
            // Appearance Mode (Dark/Light/System)
            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                Text("APPEARANCE")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textTertiary)

                ThemeModePicker(themeManager: themeManager)
            }

            HStack {
                Text("Visual Quality")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textSecondary)

                Spacer()

                Picker("Quality", selection: $visualQuality) {
                    ForEach(VisualQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .tint(EchoelBrand.primary)
            }

            settingsToggle(
                title: "Haptic Feedback",
                subtitle: "Vibrate on heartbeat and triggers",
                isOn: $hapticFeedback,
                color: EchoelBrand.primary
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: EchoelSpacing.md) {
            HStack {
                Text("Version")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textSecondary)
                Spacer()
                Text("1.0.0")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            HStack {
                Text("Build")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textSecondary)
                Spacer()
                Text("Echoel Studio")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.primary)
            }

            Divider()
                .background(EchoelBrand.border)

            VStack(spacing: EchoelSpacing.sm) {
                // E Logo
                ELetterShape()
                    .stroke(
                        EchoelBrand.primary,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 24, height: 32)

                Text("ECHOELMUSIC")
                    .font(EchoelBrandFont.sectionTitle())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .tracking(4)

                Text("Create from Within")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
                    .tracking(2)

                Text("© 2024-2026")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textDisabled)
                    .padding(.top, EchoelSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.md)
        }
    }

    // MARK: - Toggle Component

    private func settingsToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        color: Color
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text(subtitle)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
    }
}

#if DEBUG
#Preview {
    VaporwaveSettings()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
}
#endif

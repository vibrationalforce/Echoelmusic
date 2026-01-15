import SwiftUI

// MARK: - Vaporwave Settings View
// Einstellungen im Vaporwave Palace Style

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
                VaporwaveGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {

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
                    .padding(VaporwaveSpacing.lg)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SETTINGS")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaporwaveColors.textSecondary)
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
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .tracking(2)

                Spacer()
            }

            // Content
            VStack(spacing: VaporwaveSpacing.sm) {
                content()
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    // MARK: - Bio-Reactive Settings

    private var bioReactiveSettings: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            settingsToggle(
                title: "HRV → Filter",
                subtitle: "Heart rate variability controls filter brightness",
                isOn: $hrvToFilter,
                color: VaporwaveColors.hrv
            )

            settingsToggle(
                title: "Coherence → Reverb",
                subtitle: "Flow state opens up the space",
                isOn: $coherenceToReverb,
                color: VaporwaveColors.coherenceHigh
            )

            settingsToggle(
                title: "Heart Rate → Tempo",
                subtitle: "Sync delay time to your heartbeat",
                isOn: $heartRateToTempo,
                color: VaporwaveColors.heartRate
            )

            settingsToggle(
                title: "Stress → Compression",
                subtitle: "Tension increases audio compression",
                isOn: $stressToCompression,
                color: VaporwaveColors.coherenceLow
            )
        }
    }

    // MARK: - OSC Settings

    private var oscSettings: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            settingsToggle(
                title: "Enable OSC Output",
                subtitle: "Send bio-data to external software",
                isOn: $oscEnabled,
                color: VaporwaveColors.neonPurple
            )

            if oscEnabled {
                HStack(spacing: VaporwaveSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOST")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)

                        TextField("127.0.0.1", text: $oscHost)
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.textPrimary)
                            .padding(VaporwaveSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .keyboardType(.numbersAndPunctuation)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PORT")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)

                        TextField("9000", text: $oscPort)
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.textPrimary)
                            .padding(VaporwaveSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }

                // Presets
                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("PRESETS")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    HStack(spacing: VaporwaveSpacing.sm) {
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
                .foregroundColor(oscPort == port ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(oscPort == port ? VaporwaveColors.neonPurple.opacity(0.2) : Color.white.opacity(0.05))
                )
        }
    }

    // MARK: - MIDI Settings

    private var midiSettings: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            settingsToggle(
                title: "Enable MIDI Output",
                subtitle: "Send CC messages to hardware/software",
                isOn: $midiEnabled,
                color: VaporwaveColors.neonPink
            )

            if midiEnabled {
                HStack {
                    Text("MIDI Device")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textSecondary)

                    Spacer()

                    Picker("Device", selection: $selectedMidiDevice) {
                        Text("IAC Driver").tag(0)
                        Text("USB MIDI").tag(1)
                        Text("Bluetooth").tag(2)
                    }
                    .pickerStyle(.menu)
                    .tint(VaporwaveColors.neonPink)
                }
            }
        }
    }

    // MARK: - Visual Settings

    private var visualSettings: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                Text("Visual Quality")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Picker("Quality", selection: $visualQuality) {
                    ForEach(VisualQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .tint(VaporwaveColors.neonCyan)
            }

            settingsToggle(
                title: "Haptic Feedback",
                subtitle: "Vibrate on heartbeat and triggers",
                isOn: $hapticFeedback,
                color: VaporwaveColors.neonCyan
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                Text("Version")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)
                Spacer()
                Text("1.0.0")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            HStack {
                Text("Build")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)
                Spacer()
                Text("Vaporwave Palace")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.neonPink)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(spacing: VaporwaveSpacing.sm) {
                Text("ECHOELMUSIC")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: VaporwaveColors.neonPink, radius: 10)

                Text("Flüssiges Licht für deine Musik")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .tracking(2)

                Text("© 2024-2025")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .padding(.top, VaporwaveSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaporwaveSpacing.md)
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
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(subtitle)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
    }
}

#Preview {
    VaporwaveSettings()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
}

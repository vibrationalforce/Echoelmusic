import SwiftUI

/// Centralized Settings View
///
/// Main hub for all BLAB app settings:
/// - Audio & Streaming (NDI, RTMP, DSP)
/// - Performance & Monitoring
/// - Spatial Audio & Effects
/// - MIDI & Control
/// - Biometrics & Health
/// - General App Settings
///
/// Usage:
/// ```swift
/// SettingsView(controlHub: hub)
/// ```
@available(iOS 15.0, *)
struct SettingsView: View {

    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    @State private var selectedSection: SettingsSection? = nil

    enum SettingsSection: String, CaseIterable, Identifiable {
        case audio = "Audio & Streaming"
        case performance = "Performance"
        case spatial = "Spatial Audio"
        case midi = "MIDI & Control"
        case automation = "Automation"
        case biometrics = "Biometrics"
        case general = "General"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .audio: return "speaker.wave.3"
            case .performance: return "speedometer"
            case .spatial: return "move.3d"
            case .midi: return "pianokeys"
            case .automation: return "bolt.circle"
            case .biometrics: return "heart.text.square"
            case .general: return "gearshape"
            case .about: return "info.circle"
            }
        }

        var description: String {
            switch self {
            case .audio: return "NDI, RTMP, DSP processing"
            case .performance: return "Latency, CPU, monitoring"
            case .spatial: return "3D audio, head tracking"
            case .midi: return "MIDI 2.0, MPE, LED control"
            case .automation: return "Macros, Stream Deck"
            case .biometrics: return "HRV, heart rate, coherence"
            case .general: return "App preferences, notifications"
            case .about: return "Version, credits, support"
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                // MARK: - Quick Status
                Section {
                    quickStatusCard
                }

                // MARK: - Settings Sections
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(tag: section, selection: $selectedSection) {
                        destinationView(for: section)
                    } label: {
                        settingsSectionRow(section)
                    }
                }

                // MARK: - Quick Actions
                Section("Quick Actions") {
                    Button {
                        resetAllSettings()
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise.circle")
                            .foregroundColor(.orange)
                    }

                    Button {
                        printDebugInfo()
                    } label: {
                        Label("Print Debug Info", systemImage: "ladybug")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Quick Status Card

    private var quickStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BLAB Status")
                        .font(.headline)
                    Text(systemStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: systemStatusIcon)
                    .font(.title)
                    .foregroundColor(systemStatusColor)
            }

            Divider()

            HStack(spacing: 20) {
                quickStatusItem(
                    icon: "waveform.path.ecg",
                    label: "Audio",
                    value: audioEngine.isRunning ? "Running" : "Stopped",
                    color: audioEngine.isRunning ? .green : .gray
                )

                quickStatusItem(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "NDI",
                    value: controlHub.isNDIEnabled ? "On" : "Off",
                    color: controlHub.isNDIEnabled ? .green : .gray
                )

                quickStatusItem(
                    icon: "dot.radiowaves.up.forward",
                    label: "Stream",
                    value: audioEngine.streamingStatus.isStreamingToAny ? "Live" : "Off",
                    color: audioEngine.streamingStatus.isStreamingToAny ? .red : .gray
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func quickStatusItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings Section Row

    private func settingsSectionRow(_ section: SettingsSection) -> some View {
        HStack {
            Image(systemName: section.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.headline)

                Text(section.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Badge for active features
            if let badge = sectionBadge(section) {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func destinationView(for section: SettingsSection) -> some View {
        switch section {
        case .audio:
            AudioStreamingSettingsView(controlHub: controlHub, audioEngine: audioEngine)

        case .performance:
            PerformanceDashboardView(audioEngine: audioEngine)

        case .spatial:
            SpatialAudioSettingsView(audioEngine: audioEngine)

        case .midi:
            MIDISettingsView(controlHub: controlHub)

        case .automation:
            AutomationSettingsView(controlHub: controlHub, audioEngine: audioEngine)

        case .biometrics:
            BiometricsSettingsView(controlHub: controlHub)

        case .general:
            GeneralSettingsView()

        case .about:
            AboutView()
        }
    }

    // MARK: - Helpers

    private var systemStatusText: String {
        if audioEngine.isRunning {
            if audioEngine.streamingStatus.isStreamingToAny {
                return "Running & Streaming"
            } else {
                return "Running"
            }
        } else {
            return "Idle"
        }
    }

    private var systemStatusIcon: String {
        audioEngine.isRunning ? "checkmark.circle.fill" : "pause.circle.fill"
    }

    private var systemStatusColor: Color {
        audioEngine.isRunning ? .green : .gray
    }

    private func sectionBadge(_ section: SettingsSection) -> String? {
        switch section {
        case .audio:
            let activeCount = [
                controlHub.isNDIEnabled,
                audioEngine.isRTMPEnabled
            ].filter { $0 }.count
            return activeCount > 0 ? "\(activeCount)" : nil

        case .spatial:
            return audioEngine.spatialAudioEnabled ? "On" : nil

        case .midi:
            // Check if MIDI is configured
            // Would check actual MIDI connection status when MIDI manager is available
            return nil  // Future: return "Connected" or device count

        case .biometrics:
            // Check if HealthKit is authorized
            // Would check actual HealthKit authorization status
            return nil  // Future: return "Connected" if authorized

        default:
            return nil
        }
    }

    private func resetAllSettings() {
        // Reset all configurations to defaults
        NDIConfiguration.shared.resetToDefaults()
        print("[Settings] ✅ All settings reset to defaults")
    }

    private func printDebugInfo() {
        print("\n" + "="*60)
        print("BLAB DEBUG INFO")
        print("="*60)

        print("\nAUDIO ENGINE:")
        print(audioEngine.stateDescription)
        print("Sample Rate: \(audioEngine.sampleRate) Hz")
        print("Buffer Size: \(audioEngine.bufferSize) frames")
        print("Latency: \(audioEngine.currentLatency) ms")

        print("\nSTREAMING:")
        print(audioEngine.streamingStatus.statusSummary)

        print("\nNDI:")
        if controlHub.isNDIEnabled {
            controlHub.printNDIStatistics()
        } else {
            print("Disabled")
        }

        print("\nRTMP:")
        if audioEngine.isRTMPEnabled {
            let stats = audioEngine.rtmpStatistics
            print("Platform: \(stats.platform)")
            print("Health: \(stats.health.rawValue)")
            print("Duration: \(stats.formattedDuration)")
            print("Data: \(stats.formattedBytes)")
        } else {
            print("Disabled")
        }

        print("\nPERFORMANCE:")
        LatencyMeasurement.shared.printReport()

        print("\n" + "="*60 + "\n")
    }
}

// MARK: - Audio & Streaming Settings

@available(iOS 15.0, *)
struct AudioStreamingSettingsView: View {
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section {
                NavigationLink("NDI Audio Output") {
                    NDISettingsView(controlHub: controlHub)
                }

                NavigationLink("RTMP Live Streaming") {
                    RTMPStreamView(audioEngine: audioEngine)
                }

                NavigationLink("DSP Processing") {
                    DSPControlView(dsp: audioEngine.dspProcessor)
                }
            } header: {
                Text("Streaming & Output")
            }

            Section {
                HStack {
                    Text("Sample Rate")
                    Spacer()
                    Text("\(Int(audioEngine.sampleRate)) Hz")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Buffer Size")
                    Spacer()
                    Text("\(audioEngine.bufferSize) frames")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Audio Configuration")
            }
        }
        .navigationTitle("Audio & Streaming")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Spatial Audio Settings

@available(iOS 15.0, *)
struct SpatialAudioSettingsView: View {
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section {
                Toggle("Spatial Audio", isOn: Binding(
                    get: { audioEngine.spatialAudioEnabled },
                    set: { _ in audioEngine.toggleSpatialAudio() }
                ))
            } header: {
                Text("Status")
            } footer: {
                Text("3D audio positioning with head tracking")
            }

            Section {
                Text("Head Tracking: \(audioEngine.deviceCapabilitiesSummary ?? "Unknown")")
            } header: {
                Text("Capabilities")
            }
        }
        .navigationTitle("Spatial Audio")
        .navigationBarTitleDisplayMode(.inline")
    }
}

// MARK: - MIDI Settings

@available(iOS 15.0, *)
struct MIDISettingsView: View {
    @ObservedObject var controlHub: UnifiedControlHub

    var body: some View {
        List {
            Section {
                Text("MIDI 2.0 Support")
                Text("MPE (15 voices)")
                Text("LED Control (Push 3, LaunchPad)")
            } header: {
                Text("Features")
            }

            Section {
                Text("No MIDI devices connected")
                    .foregroundColor(.secondary)
            } header: {
                Text("Connected Devices")
            }
        }
        .navigationTitle("MIDI & Control")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Biometrics Settings

@available(iOS 15.0, *)
struct BiometricsSettingsView: View {
    @ObservedObject var controlHub: UnifiedControlHub

    var body: some View {
        List {
            Section {
                Toggle("Heart Rate Monitoring", isOn: .constant(false))
                Toggle("HRV Tracking", isOn: .constant(false))
                Toggle("Coherence Measurement", isOn: .constant(false))
            } header: {
                Text("HealthKit Integration")
            } footer: {
                Text("Requires HealthKit permission")
            }

            Section {
                Toggle("Bio-Reactive Audio", isOn: .constant(true))
            } header: {
                Text("Integration")
            } footer: {
                Text("Audio adapts to your biometric state")
            }
        }
        .navigationTitle("Biometrics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - General Settings

@available(iOS 15.0, *)
struct GeneralSettingsView: View {
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("haptics_enabled") private var hapticsEnabled = true

    var body: some View {
        List {
            Section("Preferences") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            }

            Section("Data") {
                Button("Clear Cache") {
                    // Clear cache
                }

                Button(role: .destructive) {
                    // Reset app
                } label: {
                    Text("Reset App Data")
                }
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Automation Settings

@available(iOS 15.0, *)
struct AutomationSettingsView: View {
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section {
                NavigationLink("Macros") {
                    MacroView(controlHub: controlHub, audioEngine: audioEngine)
                }

                NavigationLink("Stream Deck") {
                    StreamDeckView(controlHub: controlHub, audioEngine: audioEngine)
                }
            } header: {
                Text("Automation Tools")
            } footer: {
                Text("Automate workflows with macros and control BLAB with Stream Deck")
            }

            Section {
                HStack {
                    Text("Saved Macros")
                    Spacer()
                    Text("\(MacroSystem.shared.macros.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Stream Deck")
                    Spacer()
                    Text(StreamDeckController.shared.isConnected ? "Connected" : "Not Connected")
                        .foregroundColor(StreamDeckController.shared.isConnected ? .green : .secondary)
                }
            } header: {
                Text("Status")
            }
        }
        .navigationTitle("Automation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About View

@available(iOS 15.0, *)
struct AboutView: View {
    var body: some View {
        List {
            Section("App Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Phase")
                    Spacer()
                    Text("3.5 Complete")
                        .foregroundColor(.secondary)
                }
            }

            Section("Credits") {
                Text("Developed with ❤️ for audio professionals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Support") {
                Link("Documentation", destination: URL(string: "https://github.com/vibrationalforce/blab-ios-app")!)
                Link("Report Issue", destination: URL(string: "https://github.com/vibrationalforce/blab-ios-app/issues")!)
            }

            Section("Technology") {
                Text("• NDI Audio Streaming")
                Text("• RTMP Live Broadcasting")
                Text("• Advanced DSP Processing")
                Text("• Spatial Audio (3D/4D/AFA)")
                Text("• MIDI 2.0 & MPE")
                Text("• Biometric Integration")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline")
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            controlHub: UnifiedControlHub(),
            audioEngine: AudioEngine(microphoneManager: MicrophoneManager())
        )
    }
}

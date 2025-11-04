import SwiftUI

/// Main Content View - Primary app interface
///
/// Integrated features:
/// - Control Hub (60 Hz unified control)
/// - Audio Engine management
/// - Real-time performance monitoring
/// - Streaming controls (NDI, RTMP)
/// - DSP processing
/// - Settings access
///
/// Tab-based navigation:
/// - Home: Quick controls & status
/// - Perform: Live performance tools
/// - Stream: Streaming controls
/// - Settings: Full configuration
///
/// Usage:
/// ```swift
/// MainContentView(controlHub: hub, audioEngine: engine)
/// ```
@available(iOS 15.0, *)
struct MainContentView: View {

    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case perform = "Perform"
        case stream = "Stream"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .perform: return "waveform.path"
            case .stream: return "dot.radiowaves.up.forward"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Home Tab
            NavigationView {
                HomeView(controlHub: controlHub, audioEngine: audioEngine)
            }
            .tabItem {
                Label(Tab.home.rawValue, systemImage: Tab.home.icon)
            }
            .tag(Tab.home)

            // MARK: - Perform Tab
            NavigationView {
                PerformView(controlHub: controlHub, audioEngine: audioEngine)
            }
            .tabItem {
                Label(Tab.perform.rawValue, systemImage: Tab.perform.icon)
            }
            .tag(Tab.perform)

            // MARK: - Stream Tab
            NavigationView {
                StreamView(controlHub: controlHub, audioEngine: audioEngine)
            }
            .tabItem {
                Label(Tab.stream.rawValue, systemImage: Tab.stream.icon)
            }
            .tag(Tab.stream)

            // MARK: - Settings Tab
            NavigationView {
                SettingsView(controlHub: controlHub, audioEngine: audioEngine)
            }
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
    }
}

// MARK: - Home View

@available(iOS 15.0, *)
struct HomeView: View {
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                headerSection

                // MARK: - Quick Controls
                quickControlsSection

                // MARK: - Status Cards
                statusCardsSection

                // MARK: - Performance Widget
                performanceSection

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("BLAB")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                PerformanceWidget()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("BLAB")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(systemStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                systemStatusIndicator
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }

    private var systemStatusIndicator: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(systemStatusColor)
                .frame(width: 12, height: 12)

            Text(audioEngine.isRunning ? "Running" : "Idle")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Quick Controls

    private var quickControlsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                quickControlButton(
                    icon: audioEngine.isRunning ? "stop.circle.fill" : "play.circle.fill",
                    title: audioEngine.isRunning ? "Stop" : "Start",
                    color: audioEngine.isRunning ? .red : .green
                ) {
                    toggleAudioEngine()
                }

                quickControlButton(
                    icon: "move.3d",
                    title: "Spatial",
                    color: audioEngine.spatialAudioEnabled ? .blue : .gray
                ) {
                    audioEngine.toggleSpatialAudio()
                }

                quickControlButton(
                    icon: "waveform",
                    title: "Binaural",
                    color: audioEngine.binauralBeatsEnabled ? .purple : .gray
                ) {
                    audioEngine.toggleBinauralBeats()
                }
            }
        }
    }

    private func quickControlButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }

    // MARK: - Status Cards

    private var statusCardsSection: some View {
        VStack(spacing: 12) {
            Text("Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // NDI Status
            statusCard(
                icon: "antenna.radiowaves.left.and.right",
                title: "NDI Audio",
                status: controlHub.isNDIEnabled ? "Streaming" : "Disabled",
                detail: controlHub.isNDIEnabled ? "\(controlHub.ndiConnectionCount) receivers" : "Tap to enable",
                color: controlHub.isNDIEnabled ? .green : .gray
            ) {
                // Navigate to NDI settings
            }

            // RTMP Status
            statusCard(
                icon: "dot.radiowaves.up.forward",
                title: "Live Stream",
                status: audioEngine.isRTMPEnabled ? "Live" : "Offline",
                detail: audioEngine.isRTMPEnabled ? audioEngine.rtmpStreamHealth.rawValue : "Tap to configure",
                color: audioEngine.isRTMPEnabled ? .red : .gray
            ) {
                // Navigate to RTMP settings
            }
        }
    }

    private func statusCard(icon: String, title: String, status: String, detail: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(status)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)

                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Performance")
                    .font(.headline)

                Spacer()

                NavigationLink("Details") {
                    PerformanceDashboardView(audioEngine: audioEngine)
                }
                .font(.caption)
            }

            HStack(spacing: 12) {
                performanceMetric(
                    label: "Latency",
                    value: String(format: "%.1f ms", audioEngine.currentLatency),
                    color: audioEngine.meetsLatencyTarget ? .green : .orange
                )

                performanceMetric(
                    label: "Sample Rate",
                    value: "\(Int(audioEngine.sampleRate / 1000))k",
                    color: .blue
                )

                performanceMetric(
                    label: "Buffer",
                    value: "\(audioEngine.bufferSize)",
                    color: .purple
                )
            }
        }
    }

    private func performanceMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Actions

    private func toggleAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        } else {
            audioEngine.start()
        }
    }

    // MARK: - Helpers

    private var systemStatusText: String {
        if audioEngine.isRunning {
            return audioEngine.streamingStatus.statusSummary
        } else {
            return "Ready to start"
        }
    }

    private var systemStatusColor: Color {
        audioEngine.isRunning ? .green : .gray
    }
}

// MARK: - Perform View

@available(iOS 15.0, *)
struct PerformView: View {
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section("Audio Processing") {
                NavigationLink("DSP Controls") {
                    DSPControlView(dsp: audioEngine.dspProcessor)
                }

                NavigationLink("Spatial Audio") {
                    SpatialAudioSettingsView(audioEngine: audioEngine)
                }
            }

            Section("Effects") {
                Toggle("Binaural Beats", isOn: Binding(
                    get: { audioEngine.binauralBeatsEnabled },
                    set: { _ in audioEngine.toggleBinauralBeats() }
                ))

                if audioEngine.binauralBeatsEnabled {
                    Picker("Brainwave State", selection: Binding(
                        get: { audioEngine.currentBrainwaveState },
                        set: { audioEngine.setBrainwaveState($0) }
                    )) {
                        ForEach(BinauralBeatGenerator.BrainwaveState.allCases, id: \.self) { state in
                            Text(state.displayName).tag(state)
                        }
                    }
                }
            }

            Section("MIDI") {
                NavigationLink("MIDI Settings") {
                    MIDISettingsView(controlHub: controlHub)
                }
            }
        }
        .navigationTitle("Perform")
    }
}

// MARK: - Stream View

@available(iOS 15.0, *)
struct StreamView: View {
    @ObservedObject var controlHub: UnifiedControlHub
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section("Network Audio") {
                NavigationLink("NDI Audio Output") {
                    NDISettingsView(controlHub: controlHub)
                }

                if controlHub.isNDIEnabled {
                    HStack {
                        Text("Connections")
                        Spacer()
                        Text("\(controlHub.ndiConnectionCount)")
                            .foregroundColor(controlHub.hasNDIConnections ? .green : .secondary)
                    }
                }
            }

            Section("Live Streaming") {
                NavigationLink("RTMP Streaming") {
                    RTMPStreamView(audioEngine: audioEngine)
                }

                if audioEngine.isRTMPEnabled {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(audioEngine.rtmpStreamHealth.emoji)
                            Text(audioEngine.rtmpStreamHealth.rawValue)
                        }
                        .foregroundColor(.red)
                    }
                }
            }

            Section("Quick Setup") {
                Button {
                    quickEnableNDI()
                } label: {
                    Label("Quick Enable NDI", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(controlHub.isNDIEnabled)
            }
        }
        .navigationTitle("Stream")
    }

    private func quickEnableNDI() {
        controlHub.quickEnableNDI()
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct MainContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainContentView(
            controlHub: UnifiedControlHub(),
            audioEngine: AudioEngine(microphoneManager: MicrophoneManager())
        )
    }
}

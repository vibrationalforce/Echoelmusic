import SwiftUI

// MARK: - Live Stream View
// Control panel for streaming to multiple platforms simultaneously

public struct LiveStreamView: View {
    @StateObject private var streamEngine = LiveStreamingEngine.shared

    @State private var showPlatformSetup = false
    @State private var showStreamSettings = false
    @State private var selectedPlatform: StreamPlatform?

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stream status
                    streamStatusCard

                    // Platform toggles
                    platformsSection

                    // Video preview
                    if streamEngine.isStreaming {
                        videoPreviewSection
                    }

                    // Stream stats
                    if streamEngine.isStreaming {
                        statsSection
                    }

                    // Quick settings
                    quickSettingsSection

                    // Start/Stop button
                    streamControlButton
                }
                .padding()
            }
            .navigationTitle("Live Stream")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showStreamSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showPlatformSetup) {
                if let platform = selectedPlatform {
                    PlatformSetupView(platform: platform)
                }
            }
            .sheet(isPresented: $showStreamSettings) {
                StreamSettingsView()
            }
        }
    }

    // MARK: - Stream Status Card

    private var streamStatusCard: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(streamEngine.isStreaming ? Color.red : Color.gray)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(streamEngine.isStreaming ? 1.5 : 1)
                        .opacity(streamEngine.isStreaming ? 0 : 1)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: streamEngine.isStreaming)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(streamEngine.isStreaming ? "LIVE" : "Offline")
                    .font(.headline)
                    .foregroundStyle(streamEngine.isStreaming ? .red : .secondary)

                if streamEngine.isStreaming {
                    Text(formatDuration(streamEngine.streamDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if streamEngine.isStreaming {
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(streamEngine.viewerCount)")
                            .font(.headline)
                        Text("viewers")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(streamEngine.bitrate) kbps")
                            .font(.headline)
                        Text("bitrate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(streamEngine.isStreaming ? Color.red.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Platforms Section

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Platforms")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(StreamPlatform.allCases) { platform in
                    PlatformCard(
                        platform: platform,
                        isActive: streamEngine.activePlatforms.contains(platform),
                        isConfigured: true // Check if configured
                    ) {
                        selectedPlatform = platform
                        showPlatformSetup = true
                    }
                }
            }
        }
    }

    // MARK: - Video Preview

    private var videoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.black)

                    // Video preview would go here
                    Text("Live Preview")
                        .foregroundStyle(.white.opacity(0.5))

                    // Overlay info
                    VStack {
                        HStack {
                            Spacer()

                            NetworkHealthBadge(health: streamEngine.networkHealth)
                                .padding(8)
                        }

                        Spacer()

                        HStack {
                            ForEach(Array(streamEngine.activePlatforms), id: \.self) { platform in
                                PlatformBadge(platform: platform)
                            }

                            Spacer()

                            Text("REC")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .padding(8)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stream Health")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                StatCard(
                    title: "Bitrate",
                    value: "\(streamEngine.bitrate)",
                    unit: "kbps",
                    color: .blue
                )

                StatCard(
                    title: "Dropped",
                    value: "\(streamEngine.droppedFrames)",
                    unit: "frames",
                    color: streamEngine.droppedFrames > 10 ? .red : .green
                )

                StatCard(
                    title: "Network",
                    value: streamEngine.networkHealth.rawValue,
                    unit: "",
                    color: networkHealthColor(streamEngine.networkHealth)
                )

                StatCard(
                    title: "Duration",
                    value: formatDuration(streamEngine.streamDuration),
                    unit: "",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Quick Settings

    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Settings")
                .font(.headline)

            HStack(spacing: 16) {
                QuickSettingToggle(
                    title: "Mic",
                    icon: "mic.fill",
                    isOn: .constant(true)
                )

                QuickSettingToggle(
                    title: "Audio",
                    icon: "speaker.wave.2.fill",
                    isOn: .constant(true)
                )

                QuickSettingToggle(
                    title: "Camera",
                    icon: "video.fill",
                    isOn: .constant(false)
                )

                QuickSettingToggle(
                    title: "Visuals",
                    icon: "sparkles",
                    isOn: .constant(true)
                )
            }
        }
    }

    // MARK: - Control Button

    private var streamControlButton: some View {
        Button(action: toggleStream) {
            HStack {
                Image(systemName: streamEngine.isStreaming ? "stop.fill" : "play.fill")
                Text(streamEngine.isStreaming ? "End Stream" : "Go Live")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(streamEngine.isStreaming ? Color.red : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func toggleStream() {
        Task {
            if streamEngine.isStreaming {
                await streamEngine.stopStreaming()
            } else {
                try? await streamEngine.startStreaming()
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func networkHealthColor(_ health: NetworkHealth) -> Color {
        switch health {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Supporting Views

struct PlatformCard: View {
    let platform: StreamPlatform
    let isActive: Bool
    let isConfigured: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? platformColor : Color(.systemGray5))
                        .frame(width: 50, height: 50)

                    Image(systemName: platform.icon)
                        .font(.title2)
                        .foregroundStyle(isActive ? .white : .secondary)
                }

                Text(platform.rawValue)
                    .font(.caption)
                    .foregroundStyle(isConfigured ? .primary : .secondary)

                if !isConfigured {
                    Text("Setup")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var platformColor: Color {
        switch platform {
        case .youtube: return .red
        case .twitch: return .purple
        case .facebook: return .blue
        case .instagram: return .pink
        case .tiktok: return .black
        case .custom: return .gray
        }
    }
}

struct NetworkHealthBadge: View {
    let health: NetworkHealth

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi")
            Text(health.rawValue)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(healthColor.opacity(0.8))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    private var healthColor: Color {
        switch health {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }
}

struct PlatformBadge: View {
    let platform: StreamPlatform

    var body: some View {
        Image(systemName: platform.icon)
            .font(.caption)
            .padding(6)
            .background(platformColor)
            .foregroundStyle(.white)
            .clipShape(Circle())
    }

    private var platformColor: Color {
        switch platform {
        case .youtube: return .red
        case .twitch: return .purple
        case .facebook: return .blue
        case .instagram: return .pink
        case .tiktok: return .black
        case .custom: return .gray
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)

            HStack(spacing: 2) {
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickSettingToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isOn ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .foregroundStyle(isOn ? .accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct PlatformSetupView: View {
    let platform: StreamPlatform
    @Environment(\.dismiss) private var dismiss

    @State private var streamKey = ""
    @State private var serverURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Stream Key", text: $streamKey)

                    if platform == .custom {
                        TextField("Server URL", text: $serverURL)
                    }
                } header: {
                    Text("Credentials")
                } footer: {
                    Text("Get your stream key from \(platform.rawValue)")
                }

                Section("Tips") {
                    Text("1. Go to \(platform.rawValue) Studio")
                    Text("2. Find Stream Key in settings")
                    Text("3. Copy and paste here")
                }
            }
            .navigationTitle("\(platform.rawValue) Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCredentials()
                        dismiss()
                    }
                    .disabled(streamKey.isEmpty)
                }
            }
        }
    }

    private func saveCredentials() {
        let credentials = StreamCredentials(streamKey: streamKey, serverURL: serverURL.isEmpty ? nil : serverURL)
        LiveStreamingEngine.shared.configure(platform: platform, credentials: credentials)
    }
}

struct StreamSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var resolution = "1080p"
    @State private var frameRate = 60
    @State private var bitrate = 6000
    @State private var latencyMode = "Ultra Low"

    var body: some View {
        NavigationStack {
            Form {
                Section("Video") {
                    Picker("Resolution", selection: $resolution) {
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                        Text("1440p").tag("1440p")
                        Text("4K").tag("4K")
                    }

                    Picker("Frame Rate", selection: $frameRate) {
                        Text("30 fps").tag(30)
                        Text("60 fps").tag(60)
                    }

                    Stepper("Bitrate: \(bitrate) kbps", value: $bitrate, in: 1000...20000, step: 500)
                }

                Section("Latency") {
                    Picker("Mode", selection: $latencyMode) {
                        Text("Ultra Low (< 1s)").tag("Ultra Low")
                        Text("Low (1-3s)").tag("Low")
                        Text("Normal (3-5s)").tag("Normal")
                        Text("High Quality (5-10s)").tag("High Quality")
                    }
                }

                Section("Audio") {
                    Toggle("Include Echoelmusic Output", isOn: .constant(true))
                    Toggle("Include Microphone", isOn: .constant(false))
                }
            }
            .navigationTitle("Stream Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LiveStreamView()
}

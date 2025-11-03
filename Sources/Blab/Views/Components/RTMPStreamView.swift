import SwiftUI

/// RTMP Stream Control View
///
/// Features:
/// - Platform selection (YouTube, Twitch, Facebook, Custom)
/// - Stream key configuration
/// - Stream quality settings
/// - Live stream controls
/// - Real-time statistics
/// - Stream health monitoring
///
/// Usage:
/// ```swift
/// RTMPStreamView(audioEngine: engine)
/// ```
@available(iOS 15.0, *)
struct RTMPStreamView: View {

    @ObservedObject var streamer = RTMPStreamer.shared
    @ObservedObject var audioEngine: AudioEngine

    @State private var selectedPlatform: RTMPStreamer.Platform = .youtube
    @State private var streamKey: String = ""
    @State private var customURL: String = ""
    @State private var showingSettings = false
    @State private var showingStreamKeyHelp = false

    @State private var audioBitrate: Int = 128
    @State private var enableVideo: Bool = false

    // Stats refresh
    @State private var statsTimer: Timer?
    @State private var stats: RTMPStreamer.StreamStatistics?

    var body: some View {
        Form {
            // MARK: - Status Section
            if streamer.isStreaming {
                Section {
                    streamStatusCard
                } header: {
                    Text("Live Stream")
                }
            }

            // MARK: - Platform Selection
            Section {
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(RTMPStreamer.Platform.allCases, id: \.self) { platform in
                        Label(platform.rawValue, systemImage: platform.icon)
                            .tag(platform)
                    }
                }
                .disabled(streamer.isStreaming)

            } header: {
                Text("Platform")
            }

            // MARK: - Stream Key
            Section {
                if selectedPlatform == .custom {
                    TextField("RTMP URL", text: $customURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(streamer.isStreaming)
                }

                SecureField("Stream Key", text: $streamKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(streamer.isStreaming)

                Button {
                    showingStreamKeyHelp.toggle()
                } label: {
                    Label("Where do I find my stream key?", systemImage: "questionmark.circle")
                        .font(.caption)
                }
                .foregroundColor(.blue)

            } header: {
                Text("Authentication")
            } footer: {
                Text(streamKeyFooter)
            }

            // MARK: - Quality Settings
            Section {
                HStack {
                    Text("Audio Bitrate")
                    Spacer()
                    Text("\(audioBitrate) kbps")
                        .foregroundColor(.secondary)
                }

                Picker("Quality", selection: $audioBitrate) {
                    Text("96 kbps (Low)").tag(96)
                    Text("128 kbps (Standard)").tag(128)
                    Text("160 kbps (High)").tag(160)
                    Text("192 kbps (Premium)").tag(192)
                    Text("256 kbps (Studio)").tag(256)
                }
                .pickerStyle(.segmented)
                .disabled(streamer.isStreaming)

                Toggle("Enable Video", isOn: $enableVideo)
                    .disabled(streamer.isStreaming)

            } header: {
                Text("Quality")
            } footer: {
                Text("Higher bitrate = better quality but requires faster internet")
            }

            // MARK: - Stream Control
            Section {
                if streamer.isStreaming {
                    Button(role: .destructive) {
                        stopStream()
                    } label: {
                        Label("Stop Streaming", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                } else {
                    Button {
                        startStream()
                    } label: {
                        Label("Start Streaming", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(streamKey.isEmpty || (selectedPlatform == .custom && customURL.isEmpty))
                }

            } header: {
                Text("Control")
            }

            // MARK: - Statistics
            if streamer.isStreaming, let stats = stats {
                Section {
                    streamStatistics(stats)
                } header: {
                    Text("Statistics")
                }
            }

            // MARK: - Help
            Section {
                Button {
                    showingStreamKeyHelp.toggle()
                } label: {
                    Label("How to get stream keys", systemImage: "info.circle")
                }
                .foregroundColor(.primary)

                Button {
                    showingSettings.toggle()
                } label: {
                    Label("Advanced Settings", systemImage: "gearshape")
                }
                .foregroundColor(.primary)

            } header: {
                Text("Help")
            }
        }
        .navigationTitle("Live Streaming")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStreamKeyHelp) {
            StreamKeyHelpView(platform: selectedPlatform)
        }
        .sheet(isPresented: $showingSettings) {
            RTMPAdvancedSettingsView()
        }
        .onAppear {
            startStatsTimer()
        }
        .onDisappear {
            stopStatsTimer()
        }
    }

    // MARK: - Stream Status Card

    private var streamStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)

                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .scaleEffect(liveIndicatorScale)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: liveIndicatorScale)
                }

                Text("LIVE")
                    .font(.headline)
                    .foregroundColor(.red)

                Spacer()

                Text(streamer.streamHealth.emoji)
                Text(streamer.streamHealth.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Platform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedPlatform.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats?.formattedDuration ?? "00:00:00")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    private var liveIndicatorScale: CGFloat {
        streamer.isStreaming ? 1.5 : 1.0
    }

    // MARK: - Stream Statistics

    private func streamStatistics(_ stats: RTMPStreamer.StreamStatistics) -> some View {
        Group {
            HStack {
                Label("Data Sent", systemImage: "arrow.up.circle")
                Spacer()
                Text(stats.formattedBytes)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Current Bitrate", systemImage: "waveform")
                Spacer()
                Text("\(stats.currentBitrate / 1000) kbps")
                    .foregroundColor(bitrateColor(current: stats.currentBitrate, target: stats.targetBitrate))
            }

            HStack {
                Label("Target Bitrate", systemImage: "target")
                Spacer()
                Text("\(stats.targetBitrate / 1000) kbps")
                    .foregroundColor(.secondary)
            }

            if stats.reconnectAttempts > 0 {
                HStack {
                    Label("Reconnections", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(stats.reconnectAttempts)")
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private func bitrateColor(current: Int, target: Int) -> Color {
        let ratio = Double(current) / Double(target)
        if ratio >= 0.9 {
            return .green
        } else if ratio >= 0.7 {
            return .yellow
        } else {
            return .orange
        }
    }

    // MARK: - Stream Control Actions

    private func startStream() {
        Task {
            do {
                // Configure streamer
                var config = RTMPStreamer.StreamConfiguration(
                    platform: selectedPlatform,
                    streamKey: streamKey
                )
                config.audioBitrate = audioBitrate * 1000  // Convert to bps
                config.enableVideo = enableVideo

                if selectedPlatform == .custom {
                    config.customURL = customURL
                }

                try streamer.configure(config: config)

                // Start streaming
                try await streamer.startStreaming()

                print("[Stream] ✅ Stream started successfully")

            } catch {
                print("[Stream] ❌ Failed to start stream: \(error.localizedDescription)")
                // TODO: Show error alert
            }
        }
    }

    private func stopStream() {
        streamer.stopStreaming()
    }

    // MARK: - Statistics Timer

    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            stats = streamer.getStatistics()
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    // MARK: - Helpers

    private var streamKeyFooter: String {
        switch selectedPlatform {
        case .youtube:
            return "Find in YouTube Studio → Go Live → Stream Key"
        case .twitch:
            return "Find in Twitch Dashboard → Settings → Stream → Primary Stream Key"
        case .facebook:
            return "Find in Facebook Creator Studio → Go Live → Stream Key"
        case .custom:
            return "Enter your custom RTMP server URL and stream key"
        }
    }
}

// MARK: - Stream Key Help View

@available(iOS 15.0, *)
struct StreamKeyHelpView: View {
    let platform: RTMPStreamer.Platform
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("YouTube Live") {
                    instructionRow(number: 1, text: "Go to YouTube Studio")
                    instructionRow(number: 2, text: "Click 'Go Live' in the top right")
                    instructionRow(number: 3, text: "Select 'Stream' tab")
                    instructionRow(number: 4, text: "Copy your 'Stream Key'")
                }

                Section("Twitch") {
                    instructionRow(number: 1, text: "Go to Twitch Dashboard")
                    instructionRow(number: 2, text: "Click Settings → Stream")
                    instructionRow(number: 3, text: "Copy 'Primary Stream Key'")
                    instructionRow(number: 4, text: "Keep it secret!")
                }

                Section("Facebook Live") {
                    instructionRow(number: 1, text: "Go to Creator Studio")
                    instructionRow(number: 2, text: "Click 'Go Live'")
                    instructionRow(number: 3, text: "Select 'Live Producer'")
                    instructionRow(number: 4, text: "Copy 'Stream Key'")
                }

                Section("Important") {
                    Text("⚠️ Never share your stream key publicly")
                        .foregroundColor(.orange)
                    Text("🔒 Anyone with your key can stream to your account")
                        .foregroundColor(.red)
                    Text("🔄 Reset your key if it's been compromised")
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Stream Key Help")
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

    private func instructionRow(number: Int, text: String) -> some View {
        HStack {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Advanced Settings

@available(iOS 15.0, *)
struct RTMPAdvancedSettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Audio Settings") {
                    Text("Sample Rate: 48 kHz")
                    Text("Channels: Stereo (2)")
                    Text("Codec: AAC")
                }

                Section("Network") {
                    Toggle("Auto Reconnect", isOn: .constant(true))
                    Text("Max Reconnect Attempts: 5")
                }

                Section("Performance") {
                    Toggle("Hardware Encoding", isOn: .constant(true))
                    Toggle("Adaptive Bitrate", isOn: .constant(false))
                }
            }
            .navigationTitle("Advanced Settings")
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

@available(iOS 15.0, *)
struct RTMPStreamView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RTMPStreamView(audioEngine: AudioEngine(microphoneManager: MicrophoneManager()))
        }
    }
}

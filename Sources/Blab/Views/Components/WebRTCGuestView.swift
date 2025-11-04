import SwiftUI

/// WebRTC Remote Guest Control View
///
/// Manage browser-based remote guests via WebRTC.
///
/// Features:
/// - Start/stop WebRTC server
/// - Display server URL with QR code
/// - List connected guests
/// - Control individual guest audio (mute, volume)
/// - Monitor connection quality
/// - Real-time statistics
///
/// Usage:
/// ```swift
/// WebRTCGuestView()
/// ```
@available(iOS 15.0, *)
struct WebRTCGuestView: View {

    @ObservedObject var webrtc = WebRTCManager.shared

    @State private var showingServerURL = false
    @State private var showingSettings = false
    @State private var showingQRCode = false

    var body: some View {
        Form {
            // MARK: - Server Status
            Section {
                serverStatusCard
            } header: {
                Text("Server Status")
            }

            // MARK: - Server Control
            if !webrtc.isServerRunning {
                Section {
                    Button(action: startServer) {
                        Label("Start WebRTC Server", systemImage: "play.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Control")
                } footer: {
                    Text("Guests will be able to join via browser at the server URL")
                }
            } else {
                Section {
                    Button(action: stopServer) {
                        Label("Stop Server", systemImage: "stop.circle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                    }

                    Button(action: { showingServerURL = true }) {
                        Label("Show Connection URL", systemImage: "link")
                    }

                    Button(action: { showingQRCode = true }) {
                        Label("Show QR Code", systemImage: "qrcode")
                    }
                } header: {
                    Text("Control")
                }
            }

            // MARK: - Connected Guests
            if webrtc.isServerRunning {
                Section {
                    if webrtc.connectedGuests.isEmpty {
                        HStack {
                            Image(systemName: "person.2.slash")
                                .foregroundColor(.secondary)
                            Text("No guests connected")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(webrtc.connectedGuests) { guest in
                            guestRow(guest)
                        }
                    }
                } header: {
                    HStack {
                        Text("Connected Guests")
                        Spacer()
                        Text("\(webrtc.connectedGuests.count)/\(webrtc.configuration.maxGuests)")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - Statistics
            if webrtc.isServerRunning {
                Section {
                    statisticsView
                } header: {
                    Text("Statistics")
                }
            }

            // MARK: - Settings
            Section {
                NavigationLink(destination: WebRTCSettingsView()) {
                    Label("WebRTC Settings", systemImage: "gear")
                }
            }

            // MARK: - Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "person.2.fill", title: "Max Guests", detail: "\(webrtc.configuration.maxGuests)")
                    infoRow(icon: "waveform", title: "Audio Bitrate", detail: "\(webrtc.configuration.audioBitrate / 1000) kbps")
                    infoRow(icon: "music.note", title: "Sample Rate", detail: "\(Int(webrtc.configuration.audioSampleRate)) Hz")
                }
            } header: {
                Text("Configuration")
            }
        }
        .navigationTitle("Remote Guests")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingServerURL) {
            ServerURLSheet(url: webrtc.serverURL)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeSheet(url: webrtc.serverURL)
        }
    }

    // MARK: - Server Status Card

    private var serverStatusCard: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(webrtc.isServerRunning ? Color.green : Color.gray)
                    .frame(width: 50, height: 50)

                Image(systemName: webrtc.isServerRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(webrtc.isServerRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)

                if webrtc.isServerRunning {
                    Text(webrtc.serverURL)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(webrtc.connectedGuests.count) guest(s) connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Guest Row

    private func guestRow(_ guest: WebRTCManager.RemoteGuest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Guest name
                VStack(alignment: .leading) {
                    Text(guest.name)
                        .font(.headline)

                    Text("Connected \(formatConnectionTime(guest.connectedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Connection quality
                connectionQualityBadge(guest.connectionQuality)
            }

            // Audio controls
            HStack {
                Button(action: { toggleGuestAudio(guest.id) }) {
                    Label(
                        guest.isAudioEnabled ? "Mute" : "Unmute",
                        systemImage: guest.isAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(guest.isAudioEnabled ? .blue : .red)

                Spacer()

                Button(action: { disconnectGuest(guest.id) }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            // Audio level meter
            if guest.isAudioEnabled {
                audioLevelMeter(guest.audioLevel)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func connectionQualityBadge(_ quality: WebRTCManager.RemoteGuest.ConnectionQuality) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(qualityColor(quality))
                .frame(width: 8, height: 8)

            Text(quality.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(qualityColor(quality).opacity(0.2))
        .cornerRadius(8)
    }

    private func qualityColor(_ quality: WebRTCManager.RemoteGuest.ConnectionQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .disconnected: return .gray
        }
    }

    private func audioLevelMeter(_ level: Float) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }

    // MARK: - Statistics

    private var statisticsView: some View {
        let stats = webrtc.getStatistics()

        return Group {
            HStack {
                Label("Active Guests", systemImage: "person.2")
                Spacer()
                Text("\(stats.activeGuests)/\(stats.totalGuests)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Total Bandwidth", systemImage: "arrow.up.arrow.down")
                Spacer()
                Text(stats.formattedBandwidth)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Avg Latency", systemImage: "timer")
                Spacer()
                Text("\(Int(stats.averageLatency)) ms")
                    .foregroundColor(latencyColor(stats.averageLatency))
            }

            HStack {
                Label("Packets Lost", systemImage: "exclamationmark.triangle")
                Spacer()
                Text("\(stats.packetsLost)")
                    .foregroundColor(stats.packetsLost > 0 ? .red : .secondary)
            }
        }
    }

    private func latencyColor(_ latency: Double) -> Color {
        if latency < 50 { return .green }
        if latency < 100 { return .orange }
        return .red
    }

    // MARK: - Helpers

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatConnectionTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes == 0 {
            return "just now"
        } else if minutes == 1 {
            return "1 min ago"
        } else {
            return "\(minutes) mins ago"
        }
    }

    // MARK: - Actions

    private func startServer() {
        webrtc.startServer()
    }

    private func stopServer() {
        webrtc.stopServer()
    }

    private func toggleGuestAudio(_ guestID: UUID) {
        if let guest = webrtc.connectedGuests.first(where: { $0.id == guestID }) {
            webrtc.setGuestAudioEnabled(guestID, enabled: !guest.isAudioEnabled)
        }
    }

    private func disconnectGuest(_ guestID: UUID) {
        webrtc.disconnectGuest(guestID)
    }
}

// MARK: - Server URL Sheet

@available(iOS 15.0, *)
struct ServerURLSheet: View {
    let url: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Share this URL with guests")
                    .font(.headline)

                Text(url)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)

                Text("Guests can join by opening this URL in their browser (Chrome, Firefox, Safari)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Button("Copy URL") {
                    UIPasteboard.general.string = url
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("Connection URL")
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

// MARK: - QR Code Sheet

@available(iOS 15.0, *)
struct QRCodeSheet: View {
    let url: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Scan QR Code to Join")
                    .font(.headline)

                // Placeholder for QR code
                // In a real implementation, use Core Image to generate QR code
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 250, height: 250)

                    VStack {
                        Image(systemName: "qrcode")
                            .font(.system(size: 150))
                            .foregroundColor(.black)

                        Text(url)
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }
                .cornerRadius(12)
                .shadow(radius: 5)

                Text("Guests can scan this QR code with their mobile device")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
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

// MARK: - Settings View

@available(iOS 15.0, *)
struct WebRTCSettingsView: View {
    @ObservedObject var webrtc = WebRTCManager.shared

    var body: some View {
        Form {
            Section {
                Stepper("Max Guests: \(webrtc.configuration.maxGuests)", value: .constant(webrtc.configuration.maxGuests), in: 1...16)

                HStack {
                    Text("Audio Bitrate")
                    Spacer()
                    Text("\(webrtc.configuration.audioBitrate / 1000) kbps")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Capacity")
            }

            Section {
                Toggle("Echo Cancellation", isOn: .constant(webrtc.configuration.enableEchoCancellation))
                Toggle("Noise Suppression", isOn: .constant(webrtc.configuration.enableNoiseSuppression))
                Toggle("Auto Gain Control", isOn: .constant(webrtc.configuration.enableAutomaticGainControl))
            } header: {
                Text("Audio Processing")
            } footer: {
                Text("Audio enhancements for remote guests")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WebRTC requires:")
                        .font(.caption)
                        .fontWeight(.bold)

                    Text("• Modern web browser (Chrome, Firefox, Safari)")
                        .font(.caption2)
                    Text("• Same network (local) or port forwarding (remote)")
                        .font(.caption2)
                    Text("• HTTPS for remote connections")
                        .font(.caption2)
                }
            } header: {
                Text("Requirements")
            }
        }
        .navigationTitle("WebRTC Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct WebRTCGuestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WebRTCGuestView()
        }
    }
}

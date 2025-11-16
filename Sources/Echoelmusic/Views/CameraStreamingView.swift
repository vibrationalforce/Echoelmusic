import SwiftUI
import AVFoundation

/// Camera and Live Streaming View
/// Supports multi-camera recording, live streaming, and biometric overlays
struct CameraStreamingView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - State

    @State private var selectedCamera: CameraPosition = .front
    @State private var isStreaming = false
    @State private var isRecordingVideo = false
    @State private var showBiometricOverlay = true
    @State private var showStreamSettings = false
    @State private var selectedStreamTarget: StreamTarget = .none
    @State private var streamQuality: StreamQuality = .hd1080p

    // MARK: - Camera Position

    enum CameraPosition: String, CaseIterable {
        case front = "Front Camera"
        case back = "Back Camera"
        case external = "External Camera"

        var icon: String {
            switch self {
            case .front: return "camera.fill"
            case .back: return "camera.rotate.fill"
            case .external: return "camera.on.rectangle.fill"
            }
        }
    }

    // MARK: - Stream Target

    enum StreamTarget: String, CaseIterable {
        case none = "Not Streaming"
        case twitch = "Twitch"
        case youtube = "YouTube Live"
        case instagram = "Instagram Live"
        case multistream = "Multi-Stream"

        var icon: String {
            switch self {
            case .none: return "wifi.slash"
            case .twitch: return "video.fill"
            case .youtube: return "play.rectangle.fill"
            case .instagram: return "camera.circle.fill"
            case .multistream: return "antenna.radiowaves.left.and.right"
            }
        }

        var color: Color {
            switch self {
            case .none: return .gray
            case .twitch: return .purple
            case .youtube: return .red
            case .instagram: return Color(hue: 0.85, saturation: 0.8, brightness: 0.9)
            case .multistream: return .cyan
            }
        }
    }

    // MARK: - Stream Quality

    enum StreamQuality: String, CaseIterable {
        case sd480p = "480p SD"
        case hd720p = "720p HD"
        case hd1080p = "1080p Full HD"
        case uhd4k = "4K Ultra HD"

        var resolution: CGSize {
            switch self {
            case .sd480p: return CGSize(width: 854, height: 480)
            case .hd720p: return CGSize(width: 1280, height: 720)
            case .hd1080p: return CGSize(width: 1920, height: 1080)
            case .uhd4k: return CGSize(width: 3840, height: 2160)
            }
        }

        var bitrate: Int {
            switch self {
            case .sd480p: return 1_500_000  // 1.5 Mbps
            case .hd720p: return 3_000_000  // 3 Mbps
            case .hd1080p: return 6_000_000 // 6 Mbps
            case .uhd4k: return 25_000_000  // 25 Mbps
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Camera Preview
                cameraPreviewArea

                // MARK: - Controls
                controlPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showStreamSettings) {
            streamSettingsSheet
        }
    }

    // MARK: - Camera Preview Area

    private var cameraPreviewArea: some View {
        ZStack {
            // Camera Preview (placeholder)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack {
                Spacer()

                // Camera placeholder icon
                Image(systemName: selectedCamera.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))

                Text(selectedCamera.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }

            // MARK: - Biometric Overlay
            if showBiometricOverlay && healthKitManager.isAuthorized {
                VStack {
                    HStack {
                        // Heart Rate
                        biometricPill(
                            icon: "heart.fill",
                            value: "\(Int(healthKitManager.heartRate))",
                            unit: "BPM",
                            color: .red
                        )

                        Spacer()

                        // HRV Coherence
                        biometricPill(
                            icon: "waveform.path.ecg",
                            value: "\(Int(healthKitManager.hrvCoherence))",
                            unit: "COH",
                            color: coherenceColor(healthKitManager.hrvCoherence)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()

                    // Audio Level Visualizer
                    if microphoneManager.isRecording {
                        HStack(spacing: 4) {
                            ForEach(0..<30, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(for: index))
                                    .frame(width: 4, height: barHeight(for: index))
                            }
                        }
                        .padding(.bottom, 150)
                    }
                }
            }

            // MARK: - Recording/Streaming Indicator
            VStack {
                HStack {
                    if isStreaming {
                        streamingIndicator
                    }

                    Spacer()

                    if isRecordingVideo {
                        recordingIndicator
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 20) {

            // Camera Selector
            Picker("Camera", selection: $selectedCamera) {
                ForEach(CameraPosition.allCases, id: \.self) { position in
                    Label(position.rawValue, systemImage: position.icon)
                        .tag(position)
                }
            }
            .pickerStyle(.segmented)

            // Main Controls
            HStack(spacing: 30) {

                // Stream Button
                Button(action: toggleStreaming) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isStreaming ? selectedStreamTarget.color : Color.gray.opacity(0.3))
                                .frame(width: 70, height: 70)
                                .shadow(
                                    color: isStreaming ? selectedStreamTarget.color.opacity(0.5) : .clear,
                                    radius: 15
                                )

                            Image(systemName: selectedStreamTarget.icon)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }

                        Text(isStreaming ? "LIVE" : "Stream")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isStreaming ? selectedStreamTarget.color : .white.opacity(0.7))
                    }
                }

                // Record Video Button
                Button(action: toggleVideoRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecordingVideo ? Color.red : Color.white.opacity(0.3))
                            .frame(width: 90, height: 90)
                            .shadow(
                                color: isRecordingVideo ? .red.opacity(0.5) : .clear,
                                radius: 20
                            )

                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 90, height: 90)

                        if isRecordingVideo {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                        }
                    }
                }

                // Settings Button
                Button(action: { showStreamSettings.toggle() }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 70, height: 70)

                            Image(systemName: "gear")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }

                        Text("Settings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // Biometric Overlay Toggle
            Toggle(isOn: $showBiometricOverlay) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    Text("Show Biometric Overlay")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.1).opacity(0.8))
        )
    }

    // MARK: - Stream Settings Sheet

    private var streamSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Stream Target") {
                    Picker("Platform", selection: $selectedStreamTarget) {
                        ForEach(StreamTarget.allCases, id: \.self) { target in
                            Label(target.rawValue, systemImage: target.icon)
                                .tag(target)
                        }
                    }
                }

                Section("Stream Quality") {
                    Picker("Resolution & Bitrate", selection: $streamQuality) {
                        ForEach(StreamQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }

                    if selectedStreamTarget != .none {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resolution: \(Int(streamQuality.resolution.width))×\(Int(streamQuality.resolution.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Bitrate: \(streamQuality.bitrate / 1_000_000) Mbps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Platform Keys") {
                    if selectedStreamTarget == .twitch || selectedStreamTarget == .multistream {
                        TextField("Twitch Stream Key", text: .constant(""))
                            .textContentType(.password)
                    }

                    if selectedStreamTarget == .youtube || selectedStreamTarget == .multistream {
                        TextField("YouTube Stream Key", text: .constant(""))
                            .textContentType(.password)
                    }

                    if selectedStreamTarget == .instagram || selectedStreamTarget == .multistream {
                        TextField("Instagram Stream Key", text: .constant(""))
                            .textContentType(.password)
                    }
                }

                Section("Advanced") {
                    Toggle("Enable Audio Reactivity", isOn: .constant(true))
                    Toggle("Record Locally", isOn: .constant(true))
                    Toggle("Auto-Highlight Detection", isOn: .constant(true))
                }
            }
            .navigationTitle("Stream Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showStreamSettings = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func biometricPill(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(isStreaming ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isStreaming)

            Text("LIVE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical: 6)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.8))
        )
    }

    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)

            Text("REC")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
    }

    // MARK: - Helper Functions

    private func toggleStreaming() {
        if selectedStreamTarget == .none {
            // Show settings to select target
            showStreamSettings = true
        } else {
            isStreaming.toggle()

            if isStreaming {
                // TODO: Start streaming
                print("📡 Started streaming to \(selectedStreamTarget.rawValue)")
            } else {
                // TODO: Stop streaming
                print("📡 Stopped streaming")
            }
        }
    }

    private func toggleVideoRecording() {
        isRecordingVideo.toggle()

        if isRecordingVideo {
            // TODO: Start video recording
            print("🎥 Started video recording")
        } else {
            // TODO: Stop video recording
            print("🎥 Stopped video recording")
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / 30.0
        let active = microphoneManager.audioLevel > threshold
        return active ? CGFloat.random(in: 20...60) : 4
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / 30.0
        let active = microphoneManager.audioLevel > threshold
        return active ? Color.cyan : Color.gray.opacity(0.3)
    }

    private func coherenceColor(_ score: Double) -> Color {
        if score < 40 {
            return .red
        } else if score < 60 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    CameraStreamingView()
        .environmentObject(MicrophoneManager())
        .environmentObject(AudioEngine(microphoneManager: MicrophoneManager()))
        .environmentObject(HealthKitManager())
        .environmentObject(RecordingEngine())
}

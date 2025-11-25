//
//  StreamControlsView.swift
//  EOEL
//
//  Created: 2025-11-25
//
//  STREAM CONTROLS - Go Live, Stop, Record buttons
//

import SwiftUI

struct StreamControlsView: View {
    @StateObject private var liveEngine = LiveStreamingEngine.shared
    @State private var showPlatformSelector: Bool = false
    @State private var isRecording: Bool = false

    var body: some View {
        HStack(spacing: 30) {
            // Go Live / Stop button
            Button(action: toggleStream) {
                HStack(spacing: 12) {
                    Image(systemName: liveEngine.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                    Text(liveEngine.isStreaming ? "Stop Stream" : "Go Live")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(width: 200, height: 60)
                .background(liveEngine.isStreaming ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Divider()

            // Record button
            Button(action: toggleRecording) {
                VStack(spacing: 4) {
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .font(.title)
                        .foregroundColor(isRecording ? .red : .primary)
                    Text(isRecording ? "Recording" : "Record")
                        .font(.caption)
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)

            // Platform selector
            Button(action: { showPlatformSelector.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title)
                    Text("Platforms")
                        .font(.caption)
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPlatformSelector) {
                PlatformSelectorView()
            }

            // Settings shortcut
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title)
                    Text("Settings")
                        .font(.caption)
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)

            Spacer()

            // Viewer count (when live)
            if liveEngine.isStreaming {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.accentColor)
                    Text("\(liveEngine.viewerCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("viewers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.1))
    }

    private func toggleStream() {
        Task {
            if liveEngine.isStreaming {
                await liveEngine.stopStreaming()
            } else {
                // Start streaming
                let destinations = [
                    LiveStreamingEngine.StreamDestination(
                        platform: .youtube,
                        streamKey: "test-key",
                        serverURL: "rtmp://a.rtmp.youtube.com/live2"
                    )
                ]
                do {
                    try await liveEngine.startStreaming(
                        destinations: destinations,
                        settings: .high
                    )
                } catch {
                    print("Failed to start stream: \(error)")
                }
            }
        }
    }

    private func toggleRecording() {
        Task {
            if isRecording {
                _ = try? await liveEngine.stopRecording()
                isRecording = false
            } else {
                try? await liveEngine.startRecording(outputURL: URL(fileURLWithPath: "/tmp/stream.mp4"))
                isRecording = true
            }
        }
    }
}

struct PlatformSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlatforms: Set<LiveStreamingEngine.StreamDestination.Platform> = [.youtube]

    var body: some View {
        NavigationView {
            List {
                ForEach(LiveStreamingEngine.StreamDestination.Platform.allCases, id: \.self) { platform in
                    HStack {
                        Image(systemName: platformIcon(platform))
                            .foregroundColor(platformColor(platform))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(platform.rawValue)
                                .font(.headline)
                            Text(platform.defaultServer)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedPlatforms.contains(platform) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedPlatforms.contains(platform) {
                            selectedPlatforms.remove(platform)
                        } else {
                            selectedPlatforms.insert(platform)
                        }
                    }
                }
            }
            .navigationTitle("Stream Destinations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func platformIcon(_ platform: LiveStreamingEngine.StreamDestination.Platform) -> String {
        switch platform {
        case .youtube: return "play.rectangle.fill"
        case .twitch: return "gamecontroller.fill"
        case .facebook: return "person.2.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .twitter: return "bird.fill"
        case .linkedin: return "briefcase.fill"
        case .custom: return "server.rack"
        }
    }

    private func platformColor(_ platform: LiveStreamingEngine.StreamDestination.Platform) -> Color {
        switch platform {
        case .youtube: return .red
        case .twitch: return .purple
        case .facebook: return .blue
        case .instagram: return .pink
        case .tiktok: return .cyan
        case .twitter: return .blue
        case .linkedin: return .blue
        case .custom: return .gray
        }
    }
}

#if DEBUG
struct StreamControlsView_Previews: PreviewProvider {
    static var previews: some View {
        StreamControlsView()
            .frame(width: 1200, height: 120)
    }
}
#endif

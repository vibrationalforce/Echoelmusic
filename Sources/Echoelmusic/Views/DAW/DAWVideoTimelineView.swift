//
//  DAWVideoTimelineView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  VIDEO TIMELINE - Professional video editing in DAW context
//  Sync audio with video, frame-accurate editing, multi-track video
//

import SwiftUI
import AVKit
import AVFoundation

struct DAWVideoTimelineView: View {
    @StateObject private var videoSync = DAWVideoSync.shared
    @StateObject private var videoEngine = VideoEditingEngine.shared
    @Binding var selectedTrack: UUID?
    @Binding var zoomLevel: CGFloat

    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 60.0
    @State private var isPlaying: Bool = false
    @State private var showVideoImporter: Bool = false
    @State private var videoTracks: [VideoTrack] = []
    @State private var selectedVideoTrack: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Video preview area
            ZStack {
                Color.black

                if let player = videoEngine.player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))

                        Button {
                            showVideoImporter = true
                        } label: {
                            Label("Import Video", systemImage: "plus.circle")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Timecode overlay
                VStack {
                    HStack {
                        Spacer()
                        TimecodeDisplay(time: currentTime, frameRate: videoSync.frameRate)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                    }
                    .padding(12)
                    Spacer()
                }
            }
            .frame(height: 300)

            Divider()

            // Transport controls
            VideoTransportBar(
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: duration,
                onPlay: { videoEngine.play() },
                onPause: { videoEngine.pause() },
                onSeek: { time in videoEngine.seek(to: time) }
            )

            Divider()

            // Video timeline
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    // Time ruler
                    TimeRuler(
                        duration: duration,
                        zoomLevel: zoomLevel,
                        currentTime: currentTime,
                        frameRate: videoSync.frameRate
                    )
                    .frame(height: 30)

                    // Video tracks
                    ForEach(videoTracks) { track in
                        VideoTrackRow(
                            track: track,
                            isSelected: selectedVideoTrack == track.id,
                            zoomLevel: zoomLevel,
                            duration: duration
                        )
                        .onTapGesture {
                            selectedVideoTrack = track.id
                        }
                    }

                    // Add track button
                    Button {
                        addVideoTrack()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Video Track")
                        }
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            setupDefaultTracks()
        }
        .sheet(isPresented: $showVideoImporter) {
            VideoImporterView { url in
                loadVideo(from: url)
            }
        }
    }

    private func setupDefaultTracks() {
        if videoTracks.isEmpty {
            videoTracks = [
                VideoTrack(id: UUID(), name: "V1 - Main", clips: [], isEnabled: true),
                VideoTrack(id: UUID(), name: "V2 - B-Roll", clips: [], isEnabled: true),
                VideoTrack(id: UUID(), name: "V3 - Graphics", clips: [], isEnabled: true)
            ]
        }
    }

    private func addVideoTrack() {
        let newTrack = VideoTrack(
            id: UUID(),
            name: "V\(videoTracks.count + 1)",
            clips: [],
            isEnabled: true
        )
        videoTracks.append(newTrack)
    }

    private func loadVideo(from url: URL) {
        videoEngine.loadVideo(url: url)
        duration = videoEngine.duration
    }
}

// MARK: - Video Track Model

struct VideoTrack: Identifiable {
    let id: UUID
    var name: String
    var clips: [VideoClip]
    var isEnabled: Bool
    var opacity: Double = 1.0
    var blendMode: VideoBlendMode = .normal

    enum VideoBlendMode: String, CaseIterable {
        case normal, add, multiply, screen, overlay
    }
}

struct VideoClip: Identifiable {
    let id: UUID
    var name: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var inPoint: TimeInterval
    var outPoint: TimeInterval
    var thumbnailURL: URL?
    var speed: Double = 1.0
    var opacity: Double = 1.0
}

// MARK: - Timecode Display

struct TimecodeDisplay: View {
    let time: TimeInterval
    let frameRate: Double

    var body: some View {
        Text(formatTimecode(time))
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.white)
    }

    private func formatTimecode(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * frameRate)

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }
}

// MARK: - Video Transport Bar

struct VideoTransportBar: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let onPlay: () -> Void
    let onPause: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Jump to start
            Button { onSeek(0) } label: {
                Image(systemName: "backward.end.fill")
            }

            // Previous frame
            Button { onSeek(max(0, currentTime - 1/24)) } label: {
                Image(systemName: "backward.frame.fill")
            }

            // Play/Pause
            Button {
                if isPlaying {
                    onPause()
                } else {
                    onPlay()
                }
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }

            // Next frame
            Button { onSeek(min(duration, currentTime + 1/24)) } label: {
                Image(systemName: "forward.frame.fill")
            }

            // Jump to end
            Button { onSeek(duration) } label: {
                Image(systemName: "forward.end.fill")
            }

            Spacer()

            // Time display
            Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            // Loop toggle
            Toggle(isOn: .constant(false)) {
                Image(systemName: "repeat")
            }
            .toggleStyle(.button)

            // Snap toggle
            Toggle(isOn: .constant(true)) {
                Image(systemName: "arrow.down.to.line")
            }
            .toggleStyle(.button)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 24)
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }
}

// MARK: - Time Ruler

struct TimeRuler: View {
    let duration: TimeInterval
    let zoomLevel: CGFloat
    let currentTime: TimeInterval
    let frameRate: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Color(.systemGray6)

                // Time markers
                Canvas { context, size in
                    let secondWidth = size.width / CGFloat(max(duration, 1)) * zoomLevel
                    let markerInterval = calculateMarkerInterval(secondWidth: secondWidth)

                    var time: TimeInterval = 0
                    while time <= duration {
                        let x = CGFloat(time / duration) * size.width
                        let isMajor = Int(time) % Int(markerInterval * 5) == 0

                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: isMajor ? 0 : size.height / 2))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(.gray.opacity(isMajor ? 0.8 : 0.4)),
                            lineWidth: isMajor ? 1 : 0.5
                        )

                        if isMajor {
                            let timeText = formatRulerTime(time)
                            context.draw(
                                Text(timeText)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary),
                                at: CGPoint(x: x + 4, y: 8)
                            )
                        }

                        time += markerInterval
                    }
                }

                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: CGFloat(currentTime / max(duration, 1)) * geometry.size.width)
            }
        }
    }

    private func calculateMarkerInterval(secondWidth: CGFloat) -> TimeInterval {
        if secondWidth > 100 { return 0.1 }
        if secondWidth > 50 { return 0.5 }
        if secondWidth > 20 { return 1 }
        if secondWidth > 5 { return 5 }
        return 10
    }

    private func formatRulerTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Track Row

struct VideoTrackRow: View {
    let track: VideoTrack
    let isSelected: Bool
    let zoomLevel: CGFloat
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: 0) {
            // Track header
            HStack {
                Button { } label: {
                    Image(systemName: track.isEnabled ? "eye.fill" : "eye.slash")
                        .foregroundColor(track.isEnabled ? .primary : .secondary)
                }

                Text(track.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Menu {
                    Button("Rename") { }
                    Button("Duplicate") { }
                    Divider()
                    Button("Delete", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                }
            }
            .frame(width: 120)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.orange.opacity(0.2) : Color(.systemGray6))

            // Track content
            ZStack(alignment: .leading) {
                Color(.systemGray5)

                // Clips
                ForEach(track.clips) { clip in
                    VideoClipView(clip: clip, zoomLevel: zoomLevel, duration: duration)
                }
            }
        }
        .frame(height: 60)
    }
}

struct VideoClipView: View {
    let clip: VideoClip
    let zoomLevel: CGFloat
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let clipWidth = CGFloat(clip.duration / max(duration, 1)) * geometry.size.width * zoomLevel
            let clipOffset = CGFloat(clip.startTime / max(duration, 1)) * geometry.size.width

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.8))
                .frame(width: clipWidth)
                .offset(x: clipOffset)
                .overlay(
                    Text(clip.name)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4),
                    alignment: .leading
                )
        }
    }
}

// MARK: - Video Importer

struct VideoImporterView: View {
    @Environment(\.dismiss) var dismiss
    let onImport: (URL) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Import Video")
                    .font(.title2)

                Text("Select a video file to add to your project")
                    .foregroundColor(.secondary)

                Button {
                    dismiss()
                } label: {
                    Label("Choose File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 40)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct DAWVideoTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        DAWVideoTimelineView(
            selectedTrack: .constant(nil),
            zoomLevel: .constant(1.0)
        )
        .frame(width: 1200, height: 700)
    }
}
#endif

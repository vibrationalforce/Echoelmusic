//
//  DAWTimelineView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  TIMELINE VIEW - Multi-track timeline with unlimited tracks
//  Visual representation of project timeline
//

import SwiftUI

// MARK: - DAW Timeline View

struct DAWTimelineView: View {
    @StateObject private var timeline = DAWTimelineEngine.shared
    @StateObject private var multiTrack = DAWMultiTrack.shared
    @StateObject private var tempoMap = DAWTempoMap.shared

    @Binding var selectedTrack: UUID?
    @Binding var zoomLevel: CGFloat

    @State private var playheadPosition: TimeInterval = 0.0
    @State private var scrollOffset: CGFloat = 0.0
    @State private var isDragging: Bool = false

    // Dimensions
    private let trackHeight: CGFloat = 100
    private let rulerHeight: CGFloat = 40
    private let trackHeaderWidth: CGFloat = 200

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Timeline ruler
                TimelineRuler(
                    duration: timeline.duration,
                    zoomLevel: zoomLevel,
                    playheadPosition: $playheadPosition,
                    headerWidth: trackHeaderWidth
                )
                .frame(height: rulerHeight)

                Divider()

                // Tracks area
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(spacing: 0) {
                        // Track headers (sticky left)
                        VStack(spacing: 0) {
                            ForEach(multiTrack.tracks) { track in
                                TrackHeader(
                                    track: track,
                                    isSelected: selectedTrack == track.id,
                                    onSelect: { selectedTrack = track.id }
                                )
                                .frame(height: trackHeight)
                            }

                            // Add track button
                            Button(action: addTrack) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add Track")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor.opacity(0.1))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: trackHeaderWidth)
                        .background(Color.gray.opacity(0.05))

                        // Track lanes
                        VStack(spacing: 0) {
                            ForEach(multiTrack.tracks) { track in
                                TrackLane(
                                    track: track,
                                    zoomLevel: zoomLevel,
                                    playheadPosition: $playheadPosition,
                                    isSelected: selectedTrack == track.id
                                )
                                .frame(height: trackHeight)
                            }

                            // Empty space for new tracks
                            Color.clear
                                .frame(height: 50)
                        }
                        .frame(width: max(geometry.size.width - trackHeaderWidth, timelineWidth))
                        .overlay(
                            // Playhead
                            Playhead(position: playheadPosition, zoomLevel: zoomLevel)
                        )
                    }
                }
            }
        }
    }

    private var timelineWidth: CGFloat {
        CGFloat(timeline.duration) * 100 * zoomLevel
    }

    private func addTrack() {
        let newTrack = DAWMultiTrack.Track(
            name: "Audio \(multiTrack.tracks.count + 1)",
            type: .audio
        )
        multiTrack.addTrack(newTrack)
    }
}

// MARK: - Timeline Ruler

struct TimelineRuler: View {
    let duration: TimeInterval
    let zoomLevel: CGFloat
    let headerWidth: CGFloat

    @Binding var playheadPosition: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Header spacer
                Color.clear
                    .frame(width: headerWidth)

                // Ruler marks
                Canvas { context, size in
                    let totalWidth = CGFloat(duration) * 100 * zoomLevel
                    let visibleWidth = size.width - headerWidth

                    // Draw time markers
                    let interval: TimeInterval = 1.0 / zoomLevel // Adaptive interval
                    var time: TimeInterval = 0

                    while time <= duration {
                        let x = CGFloat(time) * 100 * zoomLevel

                        if x >= 0 && x <= totalWidth {
                            // Draw tick
                            let tickHeight: CGFloat = time.truncatingRemainder(dividingBy: 5) == 0 ? 20 : 10
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                                    path.addLine(to: CGPoint(x: x, y: size.height))
                                },
                                with: .color(.primary),
                                lineWidth: 1
                            )

                            // Draw label every 5 seconds
                            if time.truncatingRemainder(dividingBy: 5) == 0 {
                                let timeString = formatTime(time)
                                context.draw(
                                    Text(timeString)
                                        .font(.caption)
                                        .foregroundColor(.primary),
                                    at: CGPoint(x: x + 2, y: 10)
                                )
                            }
                        }

                        time += interval
                    }

                    // Draw beat grid
                    drawBeatGrid(context: context, size: size, duration: duration, zoomLevel: zoomLevel)
                }
                .frame(width: max(geometry.size.width - headerWidth, CGFloat(duration) * 100 * zoomLevel))
            }
        }
        .background(Color.gray.opacity(0.1))
    }

    private func drawBeatGrid(context: GraphicsContext, size: CGSize, duration: TimeInterval, zoomLevel: CGFloat) {
        let bpm: Double = 120.0
        let beatDuration = 60.0 / bpm
        var beat: TimeInterval = 0

        while beat <= duration {
            let x = CGFloat(beat) * 100 * zoomLevel

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x, y: size.height - 5))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                },
                with: .color(.blue.opacity(0.3)),
                lineWidth: 1
            )

            beat += beatDuration
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let fraction = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, fraction)
    }
}

// MARK: - Track Header

struct TrackHeader: View {
    let track: DAWMultiTrack.Track
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var showMenu: Bool = false

    var body: some View {
        HStack {
            // Track icon
            Image(systemName: track.type == .audio ? "waveform" : "music.note")
                .font(.title3)
                .foregroundColor(track.color)

            VStack(alignment: .leading, spacing: 4) {
                // Track name
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)

                // Track info
                HStack(spacing: 8) {
                    Image(systemName: track.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .foregroundColor(track.isMuted ? .red : .primary)

                    Image(systemName: track.isSoloed ? "s.circle.fill" : "s.circle")
                        .foregroundColor(track.isSoloed ? .yellow : .primary)

                    Image(systemName: track.isArmed ? "record.circle.fill" : "record.circle")
                        .foregroundColor(track.isArmed ? .red : .primary)
                }
                .font(.caption)
            }

            Spacer()

            // Menu button
            Button(action: { showMenu.toggle() }) {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Track Lane

struct TrackLane: View {
    let track: DAWMultiTrack.Track
    let zoomLevel: CGFloat
    @Binding var playheadPosition: TimeInterval
    let isSelected: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Color.gray.opacity(isSelected ? 0.1 : 0.05)

                // Grid lines (beats)
                Canvas { context, size in
                    let bpm: Double = 120.0
                    let beatDuration = 60.0 / bpm
                    var beat: TimeInterval = 0
                    let maxTime = size.width / (100 * zoomLevel)

                    while beat <= maxTime {
                        let x = CGFloat(beat) * 100 * zoomLevel

                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(.white.opacity(0.1)),
                            lineWidth: 1
                        )

                        beat += beatDuration
                    }
                }

                // Clips/regions (placeholder)
                // Would render actual audio/MIDI clips here
            }
        }
    }
}

// MARK: - Playhead

struct Playhead: View {
    let position: TimeInterval
    let zoomLevel: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let xPosition = CGFloat(position) * 100 * zoomLevel

            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .offset(x: xPosition)
                .overlay(
                    // Playhead handle
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 14, height: 10)
                        .offset(x: xPosition - 6, y: -10)
                )
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DAWTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        DAWTimelineView(
            selectedTrack: .constant(nil),
            zoomLevel: .constant(1.0)
        )
        .frame(width: 1200, height: 600)
    }
}
#endif

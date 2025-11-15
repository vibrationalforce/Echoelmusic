// TimelineView.swift
// Timeline UI View
//
// Complete Timeline/Arrangement View (Reaper + Ableton + FL Studio style)

import SwiftUI
import AVFoundation

/// Timeline/Arrangement View
struct TimelineView: View {

    @ObservedObject var timeline: Timeline
    @ObservedObject var playbackEngine: PlaybackEngine

    // Zoom level (pixels per second)
    @State private var zoomLevel: CGFloat = 100.0
    @State private var minZoom: CGFloat = 20.0
    @State private var maxZoom: CGFloat = 500.0

    // Scroll offset
    @State private var scrollOffset: CGFloat = 0.0

    // Selection
    @State private var selectedClips: Set<UUID> = []
    @State private var selectedTracks: Set<UUID> = []

    // Dragging
    @State private var isDraggingClip: Bool = false
    @State private var draggedClipID: UUID?

    // Grid settings
    @State private var showGrid: Bool = true
    @State private var snapToGrid: Bool = true
    @State private var gridDivision: GridDivision = .quarter

    var body: some View {
        VStack(spacing: 0) {
            // Transport controls
            TransportControlsView(playbackEngine: playbackEngine)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))

            // Timeline ruler
            TimelineRulerView(
                timeline: timeline,
                playbackEngine: playbackEngine,
                zoomLevel: zoomLevel,
                scrollOffset: scrollOffset
            )
            .frame(height: 40)
            .background(Color.black.opacity(0.2))

            // Main timeline area
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Grid background
                    if showGrid {
                        GridView(
                            timeline: timeline,
                            zoomLevel: zoomLevel,
                            gridDivision: gridDivision
                        )
                    }

                    // Tracks and clips
                    VStack(spacing: 0) {
                        ForEach(timeline.tracks) { track in
                            TrackRowView(
                                track: track,
                                timeline: timeline,
                                zoomLevel: zoomLevel,
                                selectedClips: $selectedClips,
                                snapToGrid: snapToGrid
                            )
                            .frame(height: track.height)
                        }
                    }

                    // Playhead
                    PlayheadView(
                        position: playbackEngine.playheadPosition,
                        sampleRate: timeline.sampleRate,
                        zoomLevel: zoomLevel
                    )

                    // Loop region (if enabled)
                    if playbackEngine.isLooping {
                        LoopRegionView(
                            start: playbackEngine.loopStart,
                            end: playbackEngine.loopEnd,
                            sampleRate: timeline.sampleRate,
                            zoomLevel: zoomLevel
                        )
                    }
                }
                .frame(
                    width: timelineWidth,
                    height: totalTracksHeight,
                    alignment: .topLeading
                )
            }
            .coordinateSpace(name: "timeline")

            // Bottom toolbar
            TimelineToolbarView(
                zoomLevel: $zoomLevel,
                showGrid: $showGrid,
                snapToGrid: $snapToGrid,
                gridDivision: $gridDivision
            )
            .frame(height: 50)
            .background(Color.black.opacity(0.3))
        }
        .background(Color.black.opacity(0.8))
    }


    // MARK: - Computed Properties

    /// Total timeline width in points
    private var timelineWidth: CGFloat {
        let durationSeconds = timeline.durationSeconds
        return CGFloat(durationSeconds) * zoomLevel
    }

    /// Total tracks height
    private var totalTracksHeight: CGFloat {
        timeline.tracks.reduce(0) { $0 + $1.height }
    }
}


// MARK: - Transport Controls

struct TransportControlsView: View {
    @ObservedObject var playbackEngine: PlaybackEngine

    var body: some View {
        HStack(spacing: 20) {
            // Play/Pause
            Button(action: { playbackEngine.togglePlayPause() }) {
                Image(systemName: playbackEngine.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // Stop
            Button(action: { playbackEngine.stop() }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // Record
            Button(action: {
                if playbackEngine.state == .recording {
                    _ = playbackEngine.stopRecording()
                } else {
                    playbackEngine.record()
                }
            }) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(playbackEngine.state == .recording ? .red : .white)
            }

            Spacer()

            // Time display
            VStack(alignment: .trailing, spacing: 4) {
                Text(playbackEngine.timeString)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(playbackEngine.barBeatString)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.gray)
            }

            // Loop toggle
            Button(action: {
                if playbackEngine.isLooping {
                    playbackEngine.clearLoop()
                } else {
                    // Set loop to 4 bars
                    playbackEngine.setLoop(start: 0, end: 4 * 48000 * 4)
                }
            }) {
                Image(systemName: "repeat")
                    .font(.system(size: 24))
                    .foregroundColor(playbackEngine.isLooping ? .blue : .white)
            }
        }
    }
}


// MARK: - Timeline Ruler

struct TimelineRulerView: View {
    let timeline: Timeline
    @ObservedObject var playbackEngine: PlaybackEngine
    let zoomLevel: CGFloat
    let scrollOffset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(Color.black.opacity(0.2))

                // Bar markers
                Canvas { context, size in
                    let visibleStart = scrollOffset / zoomLevel
                    let visibleEnd = (scrollOffset + geometry.size.width) / zoomLevel

                    for bar in 1...100 {
                        let barTime = timeline.barToSeconds(bar)
                        guard barTime >= visibleStart && barTime <= visibleEnd else { continue }

                        let x = CGFloat(barTime) * zoomLevel - scrollOffset

                        // Bar line
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)

                        // Bar number
                        let text = Text("\(bar)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)

                        context.draw(text, at: CGPoint(x: x + 5, y: 10))
                    }
                }
            }
        }
    }
}


// MARK: - Grid View

struct GridView: View {
    let timeline: Timeline
    let zoomLevel: CGFloat
    let gridDivision: GridDivision

    var body: some View {
        Canvas { context, size in
            // Draw vertical grid lines (beats)
            for bar in 1...100 {
                for beat in 1...4 {
                    let time = timeline.barBeatToSeconds(BarBeat(bar: bar, beat: beat, subdivision: 0))
                    let x = CGFloat(time) * zoomLevel

                    guard x < size.width else { break }

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))

                    let opacity: CGFloat = beat == 1 ? 0.3 : 0.1
                    context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1)
                }
            }
        }
    }
}


// MARK: - Track Row

struct TrackRowView: View {
    @ObservedObject var track: Track
    let timeline: Timeline
    let zoomLevel: CGFloat
    @Binding var selectedClips: Set<UUID>
    let snapToGrid: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Track background
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .border(Color.white.opacity(0.1), width: 1)

            // Track header (left side, fixed)
            TrackHeaderView(track: track)
                .frame(width: 200)
                .background(Color.black.opacity(0.5))

            // Clips
            ForEach(track.clips) { clip in
                ClipView(
                    clip: clip,
                    sampleRate: timeline.sampleRate,
                    zoomLevel: zoomLevel,
                    isSelected: selectedClips.contains(clip.id)
                )
                .offset(x: clipOffset(for: clip))
                .onTapGesture {
                    toggleSelection(clip.id)
                }
            }
        }
    }

    private func clipOffset(for clip: Clip) -> CGFloat {
        let seconds = Double(clip.startPosition) / timeline.sampleRate
        return CGFloat(seconds) * zoomLevel
    }

    private func toggleSelection(_ clipID: UUID) {
        if selectedClips.contains(clipID) {
            selectedClips.remove(clipID)
        } else {
            selectedClips.insert(clipID)
        }
    }
}


// MARK: - Track Header

struct TrackHeaderView: View {
    @ObservedObject var track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Track name
            Text(track.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                // Mute button
                Button(action: { track.isMuted.toggle() }) {
                    Text("M")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(track.isMuted ? .white : .black)
                        .frame(width: 30, height: 24)
                        .background(track.isMuted ? Color.orange : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                // Solo button
                Button(action: { track.isSoloed.toggle() }) {
                    Text("S")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(track.isSoloed ? .white : .black)
                        .frame(width: 30, height: 24)
                        .background(track.isSoloed ? Color.yellow : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                // Record arm button
                Button(action: { track.isArmed.toggle() }) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 16))
                        .foregroundColor(track.isArmed ? .red : .gray)
                }
            }

            // Volume slider
            HStack {
                Image(systemName: "speaker.wave.1")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Slider(value: Binding(
                    get: { Double(track.volume) },
                    set: { track.volume = Float($0) }
                ), in: 0...1)
                .accentColor(.blue)

                Text("\(Int(track.volume * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .frame(width: 40)
            }
        }
        .padding(8)
    }
}


// MARK: - Clip View

struct ClipView: View {
    @ObservedObject var clip: Clip
    let sampleRate: Double
    let zoomLevel: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Clip background
            RoundedRectangle(cornerRadius: 4)
                .fill(clipColor.opacity(clip.isMuted ? 0.3 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            // Clip name
            Text(clip.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.leading, 8)
                .lineLimit(1)

            // Waveform (TODO: implement waveform rendering)
        }
        .frame(width: clipWidth, height: 100)
    }

    private var clipWidth: CGFloat {
        let seconds = Double(clip.duration) / sampleRate
        return CGFloat(seconds) * zoomLevel
    }

    private var clipColor: Color {
        switch clip.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        case .brown: return .brown
        }
    }
}


// MARK: - Playhead View

struct PlayheadView: View {
    let position: Int64
    let sampleRate: Double
    let zoomLevel: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.red.opacity(0.8))
            .frame(width: 2)
            .offset(x: playheadOffset)
    }

    private var playheadOffset: CGFloat {
        let seconds = Double(position) / sampleRate
        return CGFloat(seconds) * zoomLevel
    }
}


// MARK: - Loop Region View

struct LoopRegionView: View {
    let start: Int64
    let end: Int64
    let sampleRate: Double
    let zoomLevel: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.yellow.opacity(0.2))
            .frame(width: loopWidth)
            .offset(x: loopOffset)
    }

    private var loopOffset: CGFloat {
        let seconds = Double(start) / sampleRate
        return CGFloat(seconds) * zoomLevel
    }

    private var loopWidth: CGFloat {
        let durationSeconds = Double(end - start) / sampleRate
        return CGFloat(durationSeconds) * zoomLevel
    }
}


// MARK: - Timeline Toolbar

struct TimelineToolbarView: View {
    @Binding var zoomLevel: CGFloat
    @Binding var showGrid: Bool
    @Binding var snapToGrid: Bool
    @Binding var gridDivision: GridDivision

    var body: some View {
        HStack(spacing: 20) {
            // Zoom controls
            HStack(spacing: 8) {
                Button(action: { zoomLevel = max(20, zoomLevel - 20) }) {
                    Image(systemName: "minus.magnifyingglass")
                }

                Text("Zoom: \(Int(zoomLevel))px/s")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 120)

                Button(action: { zoomLevel = min(500, zoomLevel + 20) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }

            Spacer()

            // Grid toggle
            Toggle("Grid", isOn: $showGrid)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .font(.system(size: 12))

            // Snap toggle
            Toggle("Snap", isOn: $snapToGrid)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .font(.system(size: 12))

            // Grid division
            Picker("Division", selection: $gridDivision) {
                ForEach(GridDivision.allCases) { division in
                    Text(division.rawValue).tag(division)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .font(.system(size: 12))
        }
        .padding(.horizontal)
        .foregroundColor(.white)
    }
}


// MARK: - Supporting Types

enum GridDivision: String, CaseIterable, Identifiable {
    case bar = "Bar"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"

    var id: String { rawValue }
}


// MARK: - Timeline Extensions

extension Timeline {
    /// Convert bar number to seconds
    func barToSeconds(_ bar: Int) -> Double {
        let beats = (bar - 1) * timeSignature.beats
        return Double(beats) * (60.0 / tempo)
    }

    /// Convert bar/beat to seconds
    func barBeatToSeconds(_ barBeat: BarBeat) -> Double {
        let totalBeats = (barBeat.bar - 1) * timeSignature.beats + (barBeat.beat - 1)
        return Double(totalBeats) * (60.0 / tempo)
    }

    /// Total duration in seconds
    var durationSeconds: Double {
        guard let lastTrack = tracks.last,
              let lastClip = lastTrack.clips.last else {
            return 60.0  // Default 1 minute
        }

        return Double(lastClip.endPosition) / sampleRate
    }
}


// MARK: - Preview

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let timeline = Timeline()
        let playbackEngine = PlaybackEngine(timeline: timeline)

        // Add sample track
        let track = Track(name: "Audio 1", type: .audio, color: .blue)
        timeline.addTrack(track)

        return TimelineView(timeline: timeline, playbackEngine: playbackEngine)
            .preferredColorScheme(.dark)
    }
}

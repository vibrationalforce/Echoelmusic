// ArrangementView.swift
// Echoelmusic - Professional DAW Arrangement View
// Rivals: Ableton Live, Logic Pro, FL Studio, Reaper

import SwiftUI
import AVFoundation
import Combine

// MARK: - Data Models

/// Represents a single clip in the arrangement
struct ArrangementClip: Identifiable, Codable {
    let id: UUID
    var name: String
    var trackId: UUID
    var startBeat: Double
    var lengthBeats: Double
    var color: ClipColor
    var type: ClipType
    var audioURL: URL?
    var midiData: MIDIClipData?
    var isSelected: Bool = false
    var isMuted: Bool = false
    var gain: Float = 1.0
    var fadeInBeats: Double = 0
    var fadeOutBeats: Double = 0

    enum ClipType: String, Codable {
        case audio
        case midi
        case automation
        case video
    }

    enum ClipColor: String, Codable, CaseIterable {
        case red, orange, yellow, green, cyan, blue, purple, pink, gray

        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .gray: return .gray
            }
        }
    }
}

/// MIDI clip data structure
struct MIDIClipData: Codable {
    var notes: [MIDINote]
    var controlChanges: [MIDIControlChange]

    struct MIDINote: Codable, Identifiable {
        let id: UUID
        var pitch: Int // 0-127
        var velocity: Int // 0-127
        var startBeat: Double
        var lengthBeats: Double
        var channel: Int
    }

    struct MIDIControlChange: Codable, Identifiable {
        let id: UUID
        var controller: Int
        var value: Int
        var beat: Double
        var channel: Int
    }
}

/// Represents a track in the arrangement
struct ArrangementTrack: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: TrackType
    var color: ArrangementClip.ClipColor
    var height: CGFloat = 80
    var isMuted: Bool = false
    var isSolo: Bool = false
    var isArmed: Bool = false
    var isFrozen: Bool = false
    var volume: Float = 0.0 // dB
    var pan: Float = 0.0 // -1 to 1
    var clips: [ArrangementClip] = []
    var automationLanes: [AutomationLane] = []
    var inputSource: InputSource = .none
    var outputDestination: OutputDestination = .master
    var sends: [SendLevel] = []

    enum TrackType: String, Codable {
        case audio
        case midi
        case instrument
        case aux
        case master
        case folder
        case video
    }

    struct SendLevel: Codable, Identifiable {
        let id: UUID
        var destinationId: UUID
        var level: Float // dB
        var isPreFader: Bool
    }

    enum InputSource: Codable {
        case none
        case microphone(Int)
        case instrument(Int)
        case resampling
        case external(String)
    }

    enum OutputDestination: Codable {
        case master
        case aux(UUID)
        case external(String)
    }
}

/// Automation lane for parameter automation
struct AutomationLane: Identifiable, Codable {
    let id: UUID
    var parameterName: String
    var parameterPath: String
    var points: [AutomationPoint]
    var isVisible: Bool = true
    var color: ArrangementClip.ClipColor = .cyan

    struct AutomationPoint: Codable, Identifiable {
        let id: UUID
        var beat: Double
        var value: Float // 0-1 normalized
        var curveType: CurveType

        enum CurveType: String, Codable {
            case linear
            case bezier
            case step
            case sCurve
            case exponential
            case logarithmic
        }
    }
}

/// Time signature representation
struct TimeSignature: Codable, Equatable {
    var numerator: Int
    var denominator: Int
    var beat: Double // Where this time signature starts

    static let common = TimeSignature(numerator: 4, denominator: 4, beat: 0)
}

/// Marker in the arrangement
struct ArrangementMarker: Identifiable, Codable {
    let id: UUID
    var name: String
    var beat: Double
    var color: ArrangementClip.ClipColor
    var type: MarkerType

    enum MarkerType: String, Codable {
        case standard
        case loopStart
        case loopEnd
        case cuePoint
        case section
    }
}

// MARK: - Arrangement Engine

@MainActor
class ArrangementEngine: ObservableObject {
    // Transport
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var currentBeat: Double = 0
    @Published var tempo: Double = 120
    @Published var timeSignatures: [TimeSignature] = [.common]

    // Arrangement Data
    @Published var tracks: [ArrangementTrack] = []
    @Published var markers: [ArrangementMarker] = []
    @Published var loopStart: Double = 0
    @Published var loopEnd: Double = 16
    @Published var isLooping: Bool = false

    // Selection
    @Published var selectedClipIds: Set<UUID> = []
    @Published var selectedTrackIds: Set<UUID> = []

    // View State
    @Published var horizontalZoom: Double = 50 // pixels per beat
    @Published var verticalZoom: Double = 1.0
    @Published var scrollPosition: CGPoint = .zero
    @Published var gridSnap: GridSnap = .beat
    @Published var isSnapEnabled: Bool = true

    // Undo/Redo
    private var undoStack: [ArrangementState] = []
    private var redoStack: [ArrangementState] = []
    private let maxUndoLevels = 100

    // Audio Engine Connection
    private var displayLink: CADisplayLink?
    private var audioEngine: AVAudioEngine?

    enum GridSnap: String, CaseIterable {
        case off = "Off"
        case bar = "Bar"
        case beat = "Beat"
        case halfBeat = "1/2"
        case quarterBeat = "1/4"
        case eighthBeat = "1/8"
        case sixteenthBeat = "1/16"
        case thirtySecondBeat = "1/32"
        case triplet = "Triplet"

        var beatsValue: Double {
            switch self {
            case .off: return 0
            case .bar: return 4 // Assuming 4/4
            case .beat: return 1
            case .halfBeat: return 0.5
            case .quarterBeat: return 0.25
            case .eighthBeat: return 0.125
            case .sixteenthBeat: return 0.0625
            case .thirtySecondBeat: return 0.03125
            case .triplet: return 1.0/3.0
            }
        }
    }

    struct ArrangementState: Codable {
        var tracks: [ArrangementTrack]
        var markers: [ArrangementMarker]
        var tempo: Double
        var timeSignatures: [TimeSignature]
    }

    init() {
        setupDefaultTracks()
    }

    private func setupDefaultTracks() {
        // Create default tracks
        tracks = [
            ArrangementTrack(id: UUID(), name: "Master", type: .master, color: .gray),
            ArrangementTrack(id: UUID(), name: "Drums", type: .midi, color: .red),
            ArrangementTrack(id: UUID(), name: "Bass", type: .midi, color: .orange),
            ArrangementTrack(id: UUID(), name: "Synth Lead", type: .instrument, color: .cyan),
            ArrangementTrack(id: UUID(), name: "Vocals", type: .audio, color: .purple),
        ]
    }

    // MARK: - Transport Controls

    func play() {
        isPlaying = true
        startPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        isRecording = false
        stopPlaybackTimer()
    }

    func pause() {
        isPlaying = false
        stopPlaybackTimer()
    }

    func record() {
        isRecording = true
        isPlaying = true
        startPlaybackTimer()
    }

    func goToStart() {
        currentBeat = 0
    }

    func goToEnd() {
        currentBeat = getArrangementLength()
    }

    func jumpToBeat(_ beat: Double) {
        currentBeat = max(0, beat)
    }

    private func startPlaybackTimer() {
        // Use CADisplayLink for smooth playback
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlayhead))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopPlaybackTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlayhead() {
        guard isPlaying else { return }

        let beatsPerSecond = tempo / 60.0
        let deltaTime = 1.0 / 60.0 // Assuming 60 FPS
        currentBeat += beatsPerSecond * deltaTime

        // Handle looping
        if isLooping && currentBeat >= loopEnd {
            currentBeat = loopStart
        }
    }

    // MARK: - Track Management

    func addTrack(type: ArrangementTrack.TrackType, name: String? = nil) {
        saveUndoState()
        let trackName = name ?? "\(type.rawValue.capitalized) \(tracks.count + 1)"
        let newTrack = ArrangementTrack(
            id: UUID(),
            name: trackName,
            type: type,
            color: ArrangementClip.ClipColor.allCases.randomElement() ?? .blue
        )
        tracks.append(newTrack)
    }

    func deleteTrack(_ trackId: UUID) {
        saveUndoState()
        tracks.removeAll { $0.id == trackId }
    }

    func duplicateTrack(_ trackId: UUID) {
        saveUndoState()
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        var newTrack = tracks[index]
        newTrack.id = UUID()
        newTrack.name += " (Copy)"
        newTrack.clips = newTrack.clips.map { clip in
            var newClip = clip
            newClip.id = UUID()
            return newClip
        }
        tracks.insert(newTrack, at: index + 1)
    }

    // MARK: - Clip Management

    func addClip(to trackId: UUID, at beat: Double, clip: ArrangementClip) {
        saveUndoState()
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        var newClip = clip
        newClip.trackId = trackId
        newClip.startBeat = snapToGrid(beat)
        tracks[trackIndex].clips.append(newClip)
    }

    func moveClip(_ clipId: UUID, toBeat: Double, toTrackId: UUID? = nil) {
        saveUndoState()

        // Find and remove clip from current track
        var movedClip: ArrangementClip?
        for trackIndex in tracks.indices {
            if let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                movedClip = tracks[trackIndex].clips.remove(at: clipIndex)
                break
            }
        }

        guard var clip = movedClip else { return }

        // Update clip position
        clip.startBeat = snapToGrid(toBeat)

        // Add to target track
        let targetTrackId = toTrackId ?? clip.trackId
        if let trackIndex = tracks.firstIndex(where: { $0.id == targetTrackId }) {
            clip.trackId = targetTrackId
            tracks[trackIndex].clips.append(clip)
        }
    }

    func resizeClip(_ clipId: UUID, newLength: Double) {
        saveUndoState()
        for trackIndex in tracks.indices {
            if let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                tracks[trackIndex].clips[clipIndex].lengthBeats = snapToGrid(newLength)
                break
            }
        }
    }

    func splitClip(_ clipId: UUID, at beat: Double) {
        saveUndoState()
        for trackIndex in tracks.indices {
            if let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                let originalClip = tracks[trackIndex].clips[clipIndex]
                let splitPoint = snapToGrid(beat)

                guard splitPoint > originalClip.startBeat &&
                      splitPoint < originalClip.startBeat + originalClip.lengthBeats else { return }

                // Resize original clip
                let originalLength = splitPoint - originalClip.startBeat
                tracks[trackIndex].clips[clipIndex].lengthBeats = originalLength

                // Create new clip
                var newClip = originalClip
                newClip.id = UUID()
                newClip.startBeat = splitPoint
                newClip.lengthBeats = originalClip.lengthBeats - originalLength
                newClip.name += " (Split)"

                tracks[trackIndex].clips.append(newClip)
                break
            }
        }
    }

    func deleteSelectedClips() {
        saveUndoState()
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips.removeAll { selectedClipIds.contains($0.id) }
        }
        selectedClipIds.removeAll()
    }

    func duplicateSelectedClips() {
        saveUndoState()
        var newClips: [(UUID, ArrangementClip)] = []

        for track in tracks {
            for clip in track.clips where selectedClipIds.contains(clip.id) {
                var newClip = clip
                newClip.id = UUID()
                newClip.startBeat += clip.lengthBeats // Place after original
                newClips.append((track.id, newClip))
            }
        }

        for (trackId, clip) in newClips {
            if let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) {
                tracks[trackIndex].clips.append(clip)
            }
        }
    }

    // MARK: - Grid & Snapping

    func snapToGrid(_ beat: Double) -> Double {
        guard isSnapEnabled, gridSnap != .off else { return beat }
        let snapValue = gridSnap.beatsValue
        return round(beat / snapValue) * snapValue
    }

    // MARK: - Markers

    func addMarker(at beat: Double, name: String, type: ArrangementMarker.MarkerType = .standard) {
        saveUndoState()
        let marker = ArrangementMarker(
            id: UUID(),
            name: name,
            beat: snapToGrid(beat),
            color: .yellow,
            type: type
        )
        markers.append(marker)
        markers.sort { $0.beat < $1.beat }
    }

    func deleteMarker(_ markerId: UUID) {
        saveUndoState()
        markers.removeAll { $0.id == markerId }
    }

    // MARK: - Undo/Redo

    private func saveUndoState() {
        let state = ArrangementState(
            tracks: tracks,
            markers: markers,
            tempo: tempo,
            timeSignatures: timeSignatures
        )
        undoStack.append(state)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }

        let currentState = ArrangementState(
            tracks: tracks,
            markers: markers,
            tempo: tempo,
            timeSignatures: timeSignatures
        )
        redoStack.append(currentState)

        tracks = previousState.tracks
        markers = previousState.markers
        tempo = previousState.tempo
        timeSignatures = previousState.timeSignatures
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }

        let currentState = ArrangementState(
            tracks: tracks,
            markers: markers,
            tempo: tempo,
            timeSignatures: timeSignatures
        )
        undoStack.append(currentState)

        tracks = nextState.tracks
        markers = nextState.markers
        tempo = nextState.tempo
        timeSignatures = nextState.timeSignatures
    }

    // MARK: - Utilities

    func getArrangementLength() -> Double {
        var maxBeat: Double = 0
        for track in tracks {
            for clip in track.clips {
                let clipEnd = clip.startBeat + clip.lengthBeats
                maxBeat = max(maxBeat, clipEnd)
            }
        }
        return max(maxBeat, 16) // Minimum 16 beats
    }

    func beatToTime(_ beat: Double) -> TimeInterval {
        return beat * 60.0 / tempo
    }

    func timeToBeat(_ time: TimeInterval) -> Double {
        return time * tempo / 60.0
    }

    func formatBeatAsBarBeat(_ beat: Double) -> String {
        let bar = Int(beat / 4) + 1
        let beatInBar = Int(beat.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar).\(beatInBar)"
    }
}

// MARK: - Arrangement View

struct ArrangementView: View {
    @StateObject private var engine = ArrangementEngine()
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingAddTrackSheet = false
    @State private var showingTempoSheet = false

    private let trackHeaderWidth: CGFloat = 200
    private let rulerHeight: CGFloat = 30
    private let minimumTrackHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            // Transport Bar
            transportBar

            // Main Content
            HStack(spacing: 0) {
                // Track Headers
                trackHeadersView

                // Timeline & Clips
                timelineView
            }

            // Bottom Tool Bar
            bottomToolBar
        }
        .background(Color.black)
        .sheet(isPresented: $showingAddTrackSheet) {
            AddTrackSheet(engine: engine)
        }
        .sheet(isPresented: $showingTempoSheet) {
            TempoSheet(engine: engine)
        }
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Logo/Title
            Text("ECHOELMUSIC")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Divider().frame(height: 30)

            // Transport Controls
            HStack(spacing: 8) {
                Button(action: engine.goToStart) {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(TransportButtonStyle())

                Button(action: { engine.isPlaying ? engine.pause() : engine.play() }) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(TransportButtonStyle(isActive: engine.isPlaying))

                Button(action: engine.stop) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(TransportButtonStyle())

                Button(action: engine.record) {
                    Image(systemName: "record.circle")
                }
                .buttonStyle(TransportButtonStyle(isActive: engine.isRecording, activeColor: .red))

                Button(action: { engine.isLooping.toggle() }) {
                    Image(systemName: "repeat")
                }
                .buttonStyle(TransportButtonStyle(isActive: engine.isLooping, activeColor: .yellow))
            }

            Divider().frame(height: 30)

            // Position Display
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.formatBeatAsBarBeat(engine.currentBeat))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(formatTime(engine.beatToTime(engine.currentBeat)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .frame(width: 80)

            Divider().frame(height: 30)

            // Tempo
            Button(action: { showingTempoSheet = true }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(engine.tempo)) BPM")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("4/4")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Zoom Controls
            HStack(spacing: 8) {
                Button(action: { engine.horizontalZoom = max(10, engine.horizontalZoom - 10) }) {
                    Image(systemName: "minus.magnifyingglass")
                }

                Text("\(Int(engine.horizontalZoom))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 50)

                Button(action: { engine.horizontalZoom = min(200, engine.horizontalZoom + 10) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
            .foregroundColor(.white)

            // Grid Snap
            Picker("Snap", selection: $engine.gridSnap) {
                ForEach(ArrangementEngine.GridSnap.allCases, id: \.self) { snap in
                    Text(snap.rawValue).tag(snap)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }

    // MARK: - Track Headers

    private var trackHeadersView: some View {
        VStack(spacing: 0) {
            // Ruler spacer
            Rectangle()
                .fill(Color(white: 0.1))
                .frame(height: rulerHeight)

            // Track Headers
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(engine.tracks) { track in
                        TrackHeaderView(track: track, engine: engine)
                            .frame(height: track.height * engine.verticalZoom)
                    }
                }
            }

            // Add Track Button
            Button(action: { showingAddTrackSheet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Track")
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .background(Color(white: 0.1))
        }
        .frame(width: trackHeaderWidth)
        .background(Color(white: 0.12))
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Grid Background
                    gridBackground(width: max(geometry.size.width, engine.getArrangementLength() * engine.horizontalZoom))

                    // Clips
                    clipsView

                    // Playhead
                    playheadView

                    // Loop Region
                    if engine.isLooping {
                        loopRegionView
                    }
                }
                .frame(
                    width: max(geometry.size.width, engine.getArrangementLength() * engine.horizontalZoom + 200),
                    height: totalTracksHeight + rulerHeight
                )
            }

            // Ruler overlay (fixed at top)
            VStack {
                rulerView(width: geometry.size.width)
                Spacer()
            }
        }
    }

    private var totalTracksHeight: CGFloat {
        engine.tracks.reduce(0) { $0 + $1.height * engine.verticalZoom }
    }

    // MARK: - Grid Background

    private func gridBackground(width: CGFloat) -> some View {
        Canvas { context, size in
            let beatWidth = engine.horizontalZoom
            let totalBeats = Int(width / beatWidth) + 1

            // Draw beat lines
            for beat in 0..<totalBeats {
                let x = CGFloat(beat) * beatWidth
                let isBar = beat % 4 == 0

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: rulerHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isBar ? Color(white: 0.3) : Color(white: 0.15)),
                    lineWidth: isBar ? 1 : 0.5
                )
            }

            // Draw track separators
            var yOffset = rulerHeight
            for track in engine.tracks {
                yOffset += track.height * engine.verticalZoom
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: size.width, y: yOffset))
                    },
                    with: .color(Color(white: 0.2)),
                    lineWidth: 1
                )
            }
        }
        .background(Color(white: 0.08))
    }

    // MARK: - Clips View

    private var clipsView: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.clear).frame(height: rulerHeight)

            ForEach(engine.tracks) { track in
                ZStack(alignment: .leading) {
                    ForEach(track.clips) { clip in
                        ClipView(clip: clip, engine: engine, trackHeight: track.height * engine.verticalZoom)
                            .offset(x: clip.startBeat * engine.horizontalZoom)
                    }
                }
                .frame(height: track.height * engine.verticalZoom)
            }
        }
    }

    // MARK: - Playhead

    private var playheadView: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2)
            .offset(x: engine.currentBeat * engine.horizontalZoom - 1)
            .allowsHitTesting(false)
    }

    // MARK: - Loop Region

    private var loopRegionView: some View {
        Rectangle()
            .fill(Color.yellow.opacity(0.1))
            .frame(width: (engine.loopEnd - engine.loopStart) * engine.horizontalZoom)
            .offset(x: engine.loopStart * engine.horizontalZoom, y: rulerHeight)
            .allowsHitTesting(false)
    }

    // MARK: - Ruler

    private func rulerView(width: CGFloat) -> some View {
        Canvas { context, size in
            let beatWidth = engine.horizontalZoom
            let totalBeats = Int((width + engine.scrollPosition.x) / beatWidth) + 1

            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(white: 0.15))
            )

            // Beat markers
            for beat in 0..<totalBeats {
                let x = CGFloat(beat) * beatWidth - engine.scrollPosition.x
                guard x >= 0 && x <= size.width else { continue }

                let isBar = beat % 4 == 0

                if isBar {
                    let bar = beat / 4 + 1
                    context.draw(
                        Text("\(bar)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white),
                        at: CGPoint(x: x + 4, y: size.height / 2),
                        anchor: .leading
                    )
                }

                // Tick mark
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: isBar ? 0 : size.height * 0.6))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isBar ? .white : Color(white: 0.5)),
                    lineWidth: isBar ? 1 : 0.5
                )
            }
        }
        .frame(height: rulerHeight)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let beat = value.location.x / engine.horizontalZoom
                    engine.jumpToBeat(engine.snapToGrid(beat))
                }
        )
    }

    // MARK: - Bottom Tool Bar

    private var bottomToolBar: some View {
        HStack {
            // Selection Info
            if !engine.selectedClipIds.isEmpty {
                Text("\(engine.selectedClipIds.count) clip(s) selected")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Button("Delete") {
                    engine.deleteSelectedClips()
                }
                .foregroundColor(.red)

                Button("Duplicate") {
                    engine.duplicateSelectedClips()
                }
                .foregroundColor(.cyan)
            }

            Spacer()

            // Undo/Redo
            Button(action: engine.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(true) // TODO: Check undo stack

            Button(action: engine.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(true) // TODO: Check redo stack
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - Supporting Views

struct TrackHeaderView: View {
    let track: ArrangementTrack
    @ObservedObject var engine: ArrangementEngine

    var body: some View {
        HStack(spacing: 8) {
            // Track Color
            Rectangle()
                .fill(track.color.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                // Track Name
                Text(track.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Track Type Badge
                Text(track.type.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Track Controls
            HStack(spacing: 4) {
                // Mute
                Button(action: { toggleMute(track) }) {
                    Text("M")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isMuted ? .yellow : .gray)
                }
                .frame(width: 20, height: 20)
                .background(track.isMuted ? Color.yellow.opacity(0.3) : Color(white: 0.2))
                .cornerRadius(3)

                // Solo
                Button(action: { toggleSolo(track) }) {
                    Text("S")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isSolo ? .cyan : .gray)
                }
                .frame(width: 20, height: 20)
                .background(track.isSolo ? Color.cyan.opacity(0.3) : Color(white: 0.2))
                .cornerRadius(3)

                // Arm
                if track.type != .master {
                    Button(action: { toggleArm(track) }) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 10))
                            .foregroundColor(track.isArmed ? .red : .gray)
                    }
                    .frame(width: 20, height: 20)
                    .background(track.isArmed ? Color.red.opacity(0.3) : Color(white: 0.2))
                    .cornerRadius(3)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(
            engine.selectedTrackIds.contains(track.id)
                ? Color.white.opacity(0.1)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if engine.selectedTrackIds.contains(track.id) {
                engine.selectedTrackIds.remove(track.id)
            } else {
                engine.selectedTrackIds.insert(track.id)
            }
        }
    }

    private func toggleMute(_ track: ArrangementTrack) {
        if let index = engine.tracks.firstIndex(where: { $0.id == track.id }) {
            engine.tracks[index].isMuted.toggle()
        }
    }

    private func toggleSolo(_ track: ArrangementTrack) {
        if let index = engine.tracks.firstIndex(where: { $0.id == track.id }) {
            engine.tracks[index].isSolo.toggle()
        }
    }

    private func toggleArm(_ track: ArrangementTrack) {
        if let index = engine.tracks.firstIndex(where: { $0.id == track.id }) {
            engine.tracks[index].isArmed.toggle()
        }
    }
}

struct ClipView: View {
    let clip: ArrangementClip
    @ObservedObject var engine: ArrangementEngine
    let trackHeight: CGFloat

    @State private var isDragging = false
    @State private var isResizing = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Clip Background
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.color.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            engine.selectedClipIds.contains(clip.id)
                                ? Color.white
                                : clip.color.color,
                            lineWidth: engine.selectedClipIds.contains(clip.id) ? 2 : 1
                        )
                )

            // Clip Content
            VStack(alignment: .leading, spacing: 2) {
                // Clip Name
                Text(clip.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                // Waveform or MIDI preview would go here
                if clip.type == .audio {
                    WaveformPreview()
                        .padding(.horizontal, 2)
                } else if clip.type == .midi {
                    MIDIPreview(midiData: clip.midiData)
                        .padding(.horizontal, 2)
                }

                Spacer()
            }

            // Resize Handle
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 6)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLength = clip.lengthBeats + value.translation.width / engine.horizontalZoom
                                engine.resizeClip(clip.id, newLength: max(0.25, newLength))
                            }
                    )
            }
        }
        .frame(width: clip.lengthBeats * engine.horizontalZoom, height: trackHeight - 4)
        .opacity(clip.isMuted ? 0.5 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newBeat = clip.startBeat + value.translation.width / engine.horizontalZoom
                    engine.moveClip(clip.id, toBeat: newBeat)
                }
        )
        .onTapGesture {
            if engine.selectedClipIds.contains(clip.id) {
                engine.selectedClipIds.remove(clip.id)
            } else {
                engine.selectedClipIds.insert(clip.id)
            }
        }
    }
}

struct WaveformPreview: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2

                path.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0, to: width, by: 2) {
                    let amplitude = CGFloat.random(in: 0.2...0.8) * height / 2
                    path.addLine(to: CGPoint(x: x, y: midY - amplitude))
                    path.addLine(to: CGPoint(x: x + 1, y: midY + amplitude))
                }
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
    }
}

struct MIDIPreview: View {
    let midiData: MIDIClipData?

    var body: some View {
        GeometryReader { geometry in
            if let data = midiData {
                ForEach(data.notes) { note in
                    let noteHeight = geometry.size.height / 127
                    let y = geometry.size.height - CGFloat(note.pitch) * noteHeight

                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(
                            width: max(2, note.lengthBeats * 10),
                            height: max(2, noteHeight)
                        )
                        .offset(x: note.startBeat * 10, y: y)
                }
            } else {
                // Placeholder pattern
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 4, height: 3)
                        .offset(
                            x: CGFloat(i) * 8 + CGFloat.random(in: 0...4),
                            y: CGFloat.random(in: 0...geometry.size.height - 3)
                        )
                }
            }
        }
    }
}

struct TransportButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundColor(isActive ? activeColor : .white)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color(white: 0.3) : Color(white: 0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct AddTrackSheet: View {
    @ObservedObject var engine: ArrangementEngine
    @Environment(\.dismiss) var dismiss
    @State private var trackName = ""
    @State private var selectedType: ArrangementTrack.TrackType = .audio

    var body: some View {
        NavigationView {
            Form {
                TextField("Track Name", text: $trackName)

                Picker("Track Type", selection: $selectedType) {
                    Text("Audio").tag(ArrangementTrack.TrackType.audio)
                    Text("MIDI").tag(ArrangementTrack.TrackType.midi)
                    Text("Instrument").tag(ArrangementTrack.TrackType.instrument)
                    Text("Aux/Bus").tag(ArrangementTrack.TrackType.aux)
                    Text("Folder").tag(ArrangementTrack.TrackType.folder)
                    Text("Video").tag(ArrangementTrack.TrackType.video)
                }
            }
            .navigationTitle("Add Track")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        engine.addTrack(type: selectedType, name: trackName.isEmpty ? nil : trackName)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TempoSheet: View {
    @ObservedObject var engine: ArrangementEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Tempo") {
                    HStack {
                        Text("BPM")
                        Spacer()
                        TextField("BPM", value: $engine.tempo, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Slider(value: $engine.tempo, in: 20...300, step: 1)
                }

                Section("Time Signature") {
                    Text("4/4") // TODO: Make editable
                }
            }
            .navigationTitle("Tempo Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ArrangementView()
        .preferredColorScheme(.dark)
}

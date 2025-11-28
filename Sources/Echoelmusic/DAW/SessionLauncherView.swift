// SessionLauncherView.swift
// Echoelmusic - Ableton Live Style Session/Clip Launcher
// Rivals: Ableton Live Session View, Bitwig Scene Launcher

import SwiftUI
import AVFoundation
import Combine

// MARK: - Data Models

/// Represents a launchable clip
struct LaunchClip: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: ClipColor
    var state: ClipState
    var type: ClipType
    var lengthBars: Int
    var audioURL: URL?
    var midiData: Data?
    var isLooping: Bool
    var launchMode: LaunchMode
    var quantization: LaunchQuantization
    var followAction: FollowAction?
    var warpMode: WarpMode
    var gain: Float
    var pitch: Int // semitones

    enum ClipColor: String, Codable, CaseIterable {
        case red, orange, yellow, lime, green, cyan, blue, purple, magenta, pink, white, gray

        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .lime: return Color(red: 0.5, green: 1, blue: 0)
            case .green: return .green
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .magenta: return Color(red: 1, green: 0, blue: 1)
            case .pink: return .pink
            case .white: return .white
            case .gray: return .gray
            }
        }
    }

    enum ClipState: String, Codable {
        case stopped
        case playing
        case recording
        case triggered // Will play on next quantization point
        case stopping  // Will stop on next quantization point
    }

    enum ClipType: String, Codable {
        case audio
        case midi
        case empty
    }

    enum LaunchMode: String, Codable, CaseIterable {
        case trigger = "Trigger"
        case gate = "Gate"
        case toggle = "Toggle"
        case repeat_ = "Repeat"
    }

    enum LaunchQuantization: String, Codable, CaseIterable {
        case none = "None"
        case global = "Global"
        case oneBar = "1 Bar"
        case twoBar = "2 Bar"
        case fourBar = "4 Bar"
        case eightBar = "8 Bar"
        case oneBeat = "1 Beat"
        case halfBeat = "1/2 Beat"
        case quarterBeat = "1/4 Beat"

        var beats: Double? {
            switch self {
            case .none: return nil
            case .global: return nil // Use global setting
            case .oneBar: return 4
            case .twoBar: return 8
            case .fourBar: return 16
            case .eightBar: return 32
            case .oneBeat: return 1
            case .halfBeat: return 0.5
            case .quarterBeat: return 0.25
            }
        }
    }

    enum WarpMode: String, Codable, CaseIterable {
        case beats = "Beats"
        case tones = "Tones"
        case texture = "Texture"
        case repitch = "Re-Pitch"
        case complex = "Complex"
        case complexPro = "Complex Pro"
    }

    struct FollowAction: Codable {
        var actionA: Action
        var actionB: Action
        var chanceA: Int // 0-100
        var time: Double // bars
        var isLinked: Bool

        enum Action: String, Codable, CaseIterable {
            case stop = "Stop"
            case playAgain = "Play Again"
            case previous = "Previous"
            case next = "Next"
            case first = "First"
            case last = "Last"
            case any = "Any"
            case other = "Other"
            case jump = "Jump"
        }
    }

    static func empty() -> LaunchClip {
        LaunchClip(
            id: UUID(),
            name: "",
            color: .gray,
            state: .stopped,
            type: .empty,
            lengthBars: 4,
            audioURL: nil,
            midiData: nil,
            isLooping: true,
            launchMode: .trigger,
            quantization: .global,
            followAction: nil,
            warpMode: .beats,
            gain: 1.0,
            pitch: 0
        )
    }
}

/// Represents a session track (column in the grid)
struct SessionTrack: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: LaunchClip.ClipColor
    var clips: [LaunchClip]
    var volume: Float // dB
    var pan: Float // -1 to 1
    var isMuted: Bool
    var isSolo: Bool
    var isArmed: Bool
    var trackStop: Bool // Stop all clips in track
}

/// Represents a scene (row in the grid)
struct Scene: Identifiable, Codable {
    let id: UUID
    var name: String
    var tempo: Double?
    var timeSignatureNumerator: Int?
    var timeSignatureDenominator: Int?
}

// MARK: - Session Engine

@MainActor
class SessionEngine: ObservableObject {
    // Grid Configuration
    @Published var tracks: [SessionTrack] = []
    @Published var scenes: [Scene] = []
    @Published var numSlots: Int = 8 // Clips per track

    // Transport
    @Published var isPlaying: Bool = false
    @Published var tempo: Double = 120
    @Published var currentBeat: Double = 0
    @Published var globalQuantization: LaunchClip.LaunchQuantization = .oneBar

    // Selection
    @Published var selectedClipId: UUID?
    @Published var selectedTrackId: UUID?
    @Published var selectedSceneIndex: Int?

    // Recording
    @Published var isRecordingArmed: Bool = false
    @Published var recordingClipId: UUID?

    // Playing clips tracking
    @Published var playingClipIds: Set<UUID> = []
    @Published var triggeredClipIds: Set<UUID> = []

    // Metronome
    @Published var isMetronomeEnabled: Bool = false
    @Published var metronomeVolume: Float = 0.5

    // Audio Players
    private var audioPlayers: [UUID: AVAudioPlayer] = [:]
    private var displayLink: CADisplayLink?

    init() {
        setupDefaultSession()
    }

    private func setupDefaultSession() {
        // Create default tracks
        tracks = [
            createTrack(name: "Drums", color: .red, clipNames: ["Kick", "Snare", "HiHat", "Fill"]),
            createTrack(name: "Bass", color: .orange, clipNames: ["Groove 1", "Groove 2", "Drop", "Outro"]),
            createTrack(name: "Synth", color: .cyan, clipNames: ["Pad", "Lead", "Arp", "FX"]),
            createTrack(name: "Vocals", color: .purple, clipNames: ["Verse", "Chorus", "Bridge", ""]),
        ]

        // Create default scenes
        scenes = [
            Scene(id: UUID(), name: "Intro", tempo: 120, timeSignatureNumerator: 4, timeSignatureDenominator: 4),
            Scene(id: UUID(), name: "Verse", tempo: nil, timeSignatureNumerator: nil, timeSignatureDenominator: nil),
            Scene(id: UUID(), name: "Build", tempo: nil, timeSignatureNumerator: nil, timeSignatureDenominator: nil),
            Scene(id: UUID(), name: "Drop", tempo: 128, timeSignatureNumerator: nil, timeSignatureDenominator: nil),
            Scene(id: UUID(), name: "Breakdown", tempo: nil, timeSignatureNumerator: nil, timeSignatureDenominator: nil),
            Scene(id: UUID(), name: "Outro", tempo: 120, timeSignatureNumerator: nil, timeSignatureDenominator: nil),
        ]
    }

    private func createTrack(name: String, color: LaunchClip.ClipColor, clipNames: [String]) -> SessionTrack {
        var clips: [LaunchClip] = []
        for (index, clipName) in clipNames.enumerated() {
            if clipName.isEmpty {
                clips.append(.empty())
            } else {
                clips.append(LaunchClip(
                    id: UUID(),
                    name: clipName,
                    color: color,
                    state: .stopped,
                    type: index % 2 == 0 ? .audio : .midi,
                    lengthBars: [1, 2, 4, 8].randomElement()!,
                    audioURL: nil,
                    midiData: nil,
                    isLooping: true,
                    launchMode: .trigger,
                    quantization: .global,
                    followAction: nil,
                    warpMode: .beats,
                    gain: 1.0,
                    pitch: 0
                ))
            }
        }

        // Fill remaining slots with empty clips
        while clips.count < numSlots {
            clips.append(.empty())
        }

        return SessionTrack(
            id: UUID(),
            name: name,
            color: color,
            clips: clips,
            volume: 0,
            pan: 0,
            isMuted: false,
            isSolo: false,
            isArmed: false,
            trackStop: false
        )
    }

    // MARK: - Transport

    func play() {
        isPlaying = true
        startPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        stopPlaybackTimer()
        stopAllClips()
    }

    func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    private func startPlaybackTimer() {
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
        let deltaTime = 1.0 / 60.0
        currentBeat += beatsPerSecond * deltaTime

        // Check quantization points for triggered clips
        checkTriggeredClips()
    }

    private func checkTriggeredClips() {
        // Get next quantization point
        guard let quantBeats = globalQuantization.beats else { return }
        let nextQuantPoint = ceil(currentBeat / quantBeats) * quantBeats

        // If we just passed a quantization point
        if currentBeat >= nextQuantPoint - 0.05 && currentBeat < nextQuantPoint + 0.05 {
            for clipId in triggeredClipIds {
                launchClipNow(clipId)
            }
            triggeredClipIds.removeAll()
        }
    }

    // MARK: - Clip Control

    func launchClip(_ clipId: UUID) {
        guard let (trackIndex, clipIndex) = findClip(clipId) else { return }
        let clip = tracks[trackIndex].clips[clipIndex]

        guard clip.type != .empty else { return }

        // Determine quantization
        let quantization = clip.quantization == .global ? globalQuantization : clip.quantization

        if quantization == .none || !isPlaying {
            launchClipNow(clipId)
        } else {
            // Mark as triggered - will launch at next quantization point
            tracks[trackIndex].clips[clipIndex].state = .triggered
            triggeredClipIds.insert(clipId)

            // Stop other clips in the same track (exclusive mode)
            stopOtherClipsInTrack(trackIndex, except: clipId)
        }
    }

    private func launchClipNow(_ clipId: UUID) {
        guard let (trackIndex, clipIndex) = findClip(clipId) else { return }

        // Stop other clips in the same track
        stopOtherClipsInTrack(trackIndex, except: clipId)

        // Start playing
        tracks[trackIndex].clips[clipIndex].state = .playing
        playingClipIds.insert(clipId)

        // Start audio if available
        if let url = tracks[trackIndex].clips[clipIndex].audioURL {
            playAudio(url: url, clipId: clipId)
        }
    }

    func stopClip(_ clipId: UUID) {
        guard let (trackIndex, clipIndex) = findClip(clipId) else { return }

        tracks[trackIndex].clips[clipIndex].state = .stopped
        playingClipIds.remove(clipId)
        triggeredClipIds.remove(clipId)

        // Stop audio
        audioPlayers[clipId]?.stop()
        audioPlayers.removeValue(forKey: clipId)
    }

    func stopAllClips() {
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices {
                tracks[trackIndex].clips[clipIndex].state = .stopped
            }
        }
        playingClipIds.removeAll()
        triggeredClipIds.removeAll()

        // Stop all audio
        for player in audioPlayers.values {
            player.stop()
        }
        audioPlayers.removeAll()
    }

    private func stopOtherClipsInTrack(_ trackIndex: Int, except clipId: UUID) {
        for clipIndex in tracks[trackIndex].clips.indices {
            let clip = tracks[trackIndex].clips[clipIndex]
            if clip.id != clipId && (clip.state == .playing || clip.state == .triggered) {
                tracks[trackIndex].clips[clipIndex].state = .stopped
                playingClipIds.remove(clip.id)
                triggeredClipIds.remove(clip.id)
            }
        }
    }

    func stopTrack(_ trackId: UUID) {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }

        for clipIndex in tracks[trackIndex].clips.indices {
            tracks[trackIndex].clips[clipIndex].state = .stopped
            playingClipIds.remove(tracks[trackIndex].clips[clipIndex].id)
        }
    }

    // MARK: - Scene Control

    func launchScene(_ sceneIndex: Int) {
        guard sceneIndex < scenes.count else { return }

        // Apply scene tempo if specified
        if let sceneTempo = scenes[sceneIndex].tempo {
            tempo = sceneTempo
        }

        // Launch clip at sceneIndex for each track
        for trackIndex in tracks.indices {
            guard sceneIndex < tracks[trackIndex].clips.count else { continue }
            let clip = tracks[trackIndex].clips[sceneIndex]
            if clip.type != .empty {
                launchClip(clip.id)
            }
        }

        selectedSceneIndex = sceneIndex
    }

    func stopScene(_ sceneIndex: Int) {
        for trackIndex in tracks.indices {
            guard sceneIndex < tracks[trackIndex].clips.count else { continue }
            let clip = tracks[trackIndex].clips[sceneIndex]
            stopClip(clip.id)
        }
    }

    // MARK: - Recording

    func armRecording(trackId: UUID) {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[trackIndex].isArmed = true
        isRecordingArmed = true
    }

    func disarmRecording(trackId: UUID) {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[trackIndex].isArmed = false
        isRecordingArmed = tracks.contains { $0.isArmed }
    }

    func recordIntoSlot(trackId: UUID, slotIndex: Int) {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        guard slotIndex < tracks[trackIndex].clips.count else { return }

        // Create new clip for recording
        let newClip = LaunchClip(
            id: UUID(),
            name: "Recording...",
            color: tracks[trackIndex].color,
            state: .recording,
            type: .audio,
            lengthBars: 4,
            audioURL: nil,
            midiData: nil,
            isLooping: true,
            launchMode: .trigger,
            quantization: .global,
            followAction: nil,
            warpMode: .beats,
            gain: 1.0,
            pitch: 0
        )

        tracks[trackIndex].clips[slotIndex] = newClip
        recordingClipId = newClip.id
    }

    // MARK: - Track Control

    func setTrackVolume(_ trackId: UUID, volume: Float) {
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[index].volume = volume
    }

    func setTrackPan(_ trackId: UUID, pan: Float) {
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[index].pan = pan
    }

    func toggleTrackMute(_ trackId: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[index].isMuted.toggle()
    }

    func toggleTrackSolo(_ trackId: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[index].isSolo.toggle()
    }

    // MARK: - Audio Playback

    private func playAudio(url: URL, clipId: UUID) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // Loop forever
            player.play()
            audioPlayers[clipId] = player
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    // MARK: - Utilities

    private func findClip(_ clipId: UUID) -> (trackIndex: Int, clipIndex: Int)? {
        for trackIndex in tracks.indices {
            if let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                return (trackIndex, clipIndex)
            }
        }
        return nil
    }

    func getClipState(_ clipId: UUID) -> LaunchClip.ClipState {
        guard let (trackIndex, clipIndex) = findClip(clipId) else { return .stopped }
        return tracks[trackIndex].clips[clipIndex].state
    }

    func formatBeat(_ beat: Double) -> String {
        let bar = Int(beat / 4) + 1
        let beatInBar = Int(beat.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar).\(beatInBar)"
    }
}

// MARK: - Session Launcher View

struct SessionLauncherView: View {
    @StateObject private var engine = SessionEngine()
    @State private var showingClipEditor = false
    @State private var editingClipId: UUID?

    private let slotSize: CGFloat = 80
    private let trackHeaderHeight: CGFloat = 100
    private let sceneButtonWidth: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Main Grid
            HStack(spacing: 0) {
                // Track Headers + Clip Grid
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Track Headers Row
                        HStack(spacing: 1) {
                            // Corner spacer
                            Rectangle()
                                .fill(Color(white: 0.1))
                                .frame(width: sceneButtonWidth, height: trackHeaderHeight)

                            ForEach(engine.tracks) { track in
                                TrackHeaderCell(track: track, engine: engine)
                                    .frame(width: slotSize, height: trackHeaderHeight)
                            }
                        }

                        // Clip Grid + Scene Buttons
                        ForEach(0..<engine.numSlots, id: \.self) { slotIndex in
                            HStack(spacing: 1) {
                                // Scene Button
                                SceneButton(
                                    scene: slotIndex < engine.scenes.count ? engine.scenes[slotIndex] : nil,
                                    index: slotIndex,
                                    engine: engine
                                )
                                .frame(width: sceneButtonWidth, height: slotSize)

                                // Clips for this row
                                ForEach(engine.tracks) { track in
                                    if slotIndex < track.clips.count {
                                        ClipSlotView(
                                            clip: track.clips[slotIndex],
                                            track: track,
                                            engine: engine,
                                            onEdit: {
                                                editingClipId = track.clips[slotIndex].id
                                                showingClipEditor = true
                                            }
                                        )
                                        .frame(width: slotSize, height: slotSize)
                                    }
                                }
                            }
                        }

                        // Track Stop Buttons Row
                        HStack(spacing: 1) {
                            // Spacer for scene column
                            Rectangle()
                                .fill(Color(white: 0.1))
                                .frame(width: sceneButtonWidth, height: 40)

                            ForEach(engine.tracks) { track in
                                TrackStopButton(track: track, engine: engine)
                                    .frame(width: slotSize, height: 40)
                            }
                        }
                    }
                }

                // Master Section
                masterSection
            }

            // Bottom Transport Bar
            transportBar
        }
        .background(Color.black)
        .sheet(isPresented: $showingClipEditor) {
            if let clipId = editingClipId {
                ClipEditorSheet(clipId: clipId, engine: engine)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Text("SESSION")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Divider().frame(height: 30)

            // Global Quantization
            HStack(spacing: 8) {
                Text("QUANT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)

                Picker("", selection: $engine.globalQuantization) {
                    ForEach(LaunchClip.LaunchQuantization.allCases, id: \.self) { quant in
                        Text(quant.rawValue).tag(quant)
                    }
                }
                .frame(width: 80)
            }

            Divider().frame(height: 30)

            // Tempo
            HStack(spacing: 8) {
                Text("BPM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(Int(engine.tempo))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }

            Spacer()

            // Position
            Text(engine.formatBeat(engine.currentBeat))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
    }

    // MARK: - Master Section

    private var masterSection: some View {
        VStack(spacing: 8) {
            Text("MASTER")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            // Master Meter
            VStack(spacing: 2) {
                ForEach(0..<20) { i in
                    Rectangle()
                        .fill(meterColor(index: i))
                        .frame(width: 30, height: 4)
                }
            }
            .padding(.vertical, 8)

            // Master Volume
            Text("0.0 dB")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)

            Spacer()
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }

    private func meterColor(index: Int) -> Color {
        if index < 3 {
            return .red.opacity(0.3)
        } else if index < 6 {
            return .orange.opacity(0.3)
        } else if index < 14 {
            return .green.opacity(0.3)
        } else {
            return .green.opacity(0.2)
        }
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Transport Controls
            HStack(spacing: 8) {
                Button(action: { engine.currentBeat = 0 }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)

                Button(action: engine.togglePlayback) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(engine.isPlaying ? .green : .white)

                Button(action: engine.stop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)

                Button(action: { engine.stopAllClips() }) {
                    Text("STOP ALL")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(4)
                }
                .foregroundColor(.red)
            }

            Divider().frame(height: 30)

            // Metronome
            Toggle(isOn: $engine.isMetronomeEnabled) {
                Image(systemName: "metronome")
            }
            .toggleStyle(.button)
            .foregroundColor(engine.isMetronomeEnabled ? .orange : .gray)

            Divider().frame(height: 30)

            // Recording Arm Status
            if engine.isRecordingArmed {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("REC ARMED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Playing clips count
            Text("\(engine.playingClipIds.count) clips playing")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(white: 0.08))
    }
}

// MARK: - Supporting Views

struct TrackHeaderCell: View {
    let track: SessionTrack
    @ObservedObject var engine: SessionEngine

    var body: some View {
        VStack(spacing: 4) {
            // Track Color Bar
            Rectangle()
                .fill(track.color.color)
                .frame(height: 4)

            // Track Name
            Text(track.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Track Controls
            HStack(spacing: 4) {
                // Arm
                Button(action: {
                    if track.isArmed {
                        engine.disarmRecording(trackId: track.id)
                    } else {
                        engine.armRecording(trackId: track.id)
                    }
                }) {
                    Circle()
                        .fill(track.isArmed ? Color.red : Color(white: 0.3))
                        .frame(width: 16, height: 16)
                }

                // Solo
                Button(action: { engine.toggleTrackSolo(track.id) }) {
                    Text("S")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(track.isSolo ? .blue : .gray)
                }
                .frame(width: 18, height: 18)
                .background(track.isSolo ? Color.blue.opacity(0.3) : Color(white: 0.2))
                .cornerRadius(3)

                // Mute
                Button(action: { engine.toggleTrackMute(track.id) }) {
                    Text("M")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(track.isMuted ? .orange : .gray)
                }
                .frame(width: 18, height: 18)
                .background(track.isMuted ? Color.orange.opacity(0.3) : Color(white: 0.2))
                .cornerRadius(3)
            }

            // Volume Slider (mini)
            Slider(value: .constant(0.75), in: 0...1)
                .frame(height: 20)
        }
        .padding(4)
        .background(Color(white: 0.15))
    }
}

struct SceneButton: View {
    let scene: Scene?
    let index: Int
    @ObservedObject var engine: SessionEngine

    var body: some View {
        Button(action: {
            engine.launchScene(index)
        }) {
            VStack(spacing: 2) {
                if let scene = scene {
                    Text(scene.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let tempo = scene.tempo {
                        Text("\(Int(tempo))")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                // Play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(engine.selectedSceneIndex == index ? .green : .gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                engine.selectedSceneIndex == index
                    ? Color.green.opacity(0.2)
                    : Color(white: 0.12)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ClipSlotView: View {
    let clip: LaunchClip
    let track: SessionTrack
    @ObservedObject var engine: SessionEngine
    var onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            if clip.type == .empty {
                // TODO: Create new clip or record
            } else {
                if clip.state == .playing {
                    engine.stopClip(clip.id)
                } else {
                    engine.launchClip(clip.id)
                }
            }
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(clipBackgroundColor)

                if clip.type != .empty {
                    VStack(spacing: 2) {
                        // Clip Name
                        Text(clip.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Length indicator
                        Text("\(clip.lengthBars) bar\(clip.lengthBars > 1 ? "s" : "")")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)

                        Spacer()

                        // State indicator
                        stateIndicator
                    }
                    .padding(4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        clip.state == .playing ? Color.green :
                        clip.state == .triggered ? Color.yellow :
                        Color(white: 0.3),
                        lineWidth: clip.state == .playing || clip.state == .triggered ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            if clip.type != .empty {
                onEdit()
            }
        }
    }

    private var clipBackgroundColor: Color {
        if clip.type == .empty {
            return Color(white: 0.08)
        }

        switch clip.state {
        case .playing:
            return clip.color.color.opacity(0.6)
        case .triggered:
            return clip.color.color.opacity(0.4)
        case .recording:
            return Color.red.opacity(0.6)
        default:
            return clip.color.color.opacity(0.3)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch clip.state {
        case .playing:
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 3, height: CGFloat.random(in: 4...12))
                }
            }
        case .triggered:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
        case .recording:
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
        default:
            Image(systemName: "play.fill")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct TrackStopButton: View {
    let track: SessionTrack
    @ObservedObject var engine: SessionEngine

    var body: some View {
        Button(action: {
            engine.stopTrack(track.id)
        }) {
            Rectangle()
                .fill(Color(white: 0.2))
                .overlay(
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ClipEditorSheet: View {
    let clipId: UUID
    @ObservedObject var engine: SessionEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Clip Settings") {
                    Text("Clip Editor coming soon...")
                }

                Section("Launch") {
                    // Launch mode, quantization, etc.
                }

                Section("Follow Actions") {
                    // Follow action configuration
                }
            }
            .navigationTitle("Edit Clip")
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
    SessionLauncherView()
        .preferredColorScheme(.dark)
}

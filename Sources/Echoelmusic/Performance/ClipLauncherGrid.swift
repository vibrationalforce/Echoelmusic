// ClipLauncherGrid.swift
// Echoelmusic - Ableton Live-Style Clip Launcher
//
// Session view with grid-based clip launching, scene triggering,
// and bio-reactive performance features.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine
import AVFoundation

// MARK: - Clip Model

/// Audio/MIDI clip for the launcher grid
public struct LauncherClip: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var color: ClipColor
    public var type: ClipType
    public var state: ClipState
    public var loopEnabled: Bool
    public var audioFileURL: URL?
    public var midiData: Data?
    public var duration: TimeInterval
    public var warpMode: WarpMode
    public var quantization: Quantization
    public var velocity: Float
    public var followAction: FollowAction?

    public enum ClipType: String, Codable, CaseIterable {
        case audio = "Audio"
        case midi = "MIDI"
        case empty = "Empty"
    }

    public enum ClipState: String, Codable {
        case stopped = "Stopped"
        case queued = "Queued"
        case playing = "Playing"
        case recording = "Recording"
    }

    public enum ClipColor: String, Codable, CaseIterable {
        case red, orange, yellow, green, cyan, blue, purple, pink, white, gray

        public var swiftUIColor: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .white: return .white
            case .gray: return .gray
            }
        }
    }

    public enum WarpMode: String, Codable, CaseIterable {
        case beats = "Beats"
        case tones = "Tones"
        case texture = "Texture"
        case repitch = "Re-Pitch"
        case complex = "Complex"
        case complexPro = "Complex Pro"
    }

    public enum Quantization: String, Codable, CaseIterable {
        case none = "None"
        case bar1 = "1 Bar"
        case bar2 = "2 Bars"
        case bar4 = "4 Bars"
        case bar8 = "8 Bars"
        case beat1 = "1 Beat"
        case beat1_2 = "1/2 Beat"
        case beat1_4 = "1/4 Beat"

        public var beats: Double {
            switch self {
            case .none: return 0
            case .bar1: return 4
            case .bar2: return 8
            case .bar4: return 16
            case .bar8: return 32
            case .beat1: return 1
            case .beat1_2: return 0.5
            case .beat1_4: return 0.25
            }
        }
    }

    public struct FollowAction: Codable {
        public var actionA: Action
        public var actionB: Action
        public var chanceA: Float  // 0-1
        public var time: Double    // Bars

        public enum Action: String, Codable, CaseIterable {
            case none = "None"
            case stop = "Stop"
            case playAgain = "Play Again"
            case previous = "Previous"
            case next = "Next"
            case first = "First"
            case last = "Last"
            case any = "Any"
            case other = "Other"
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "New Clip",
        color: ClipColor = .blue,
        type: ClipType = .empty,
        duration: TimeInterval = 4.0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.type = type
        self.state = .stopped
        self.loopEnabled = true
        self.duration = duration
        self.warpMode = .beats
        self.quantization = .bar1
        self.velocity = 1.0
    }
}

// MARK: - Track Model

/// Track in the clip launcher (column)
public struct LauncherTrack: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: TrackType
    public var clips: [LauncherClip]
    public var volume: Float       // 0-1
    public var pan: Float          // -1 to 1
    public var isMuted: Bool
    public var isSoloed: Bool
    public var isArmed: Bool       // For recording
    public var color: LauncherClip.ClipColor
    public var sendLevels: [Float] // Send amounts

    public enum TrackType: String, Codable, CaseIterable {
        case audio = "Audio"
        case midi = "MIDI"
        case group = "Group"
        case return_ = "Return"
        case master = "Master"
    }

    public init(
        id: UUID = UUID(),
        name: String = "Track",
        type: TrackType = .audio,
        clipCount: Int = 8,
        color: LauncherClip.ClipColor = .blue
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.clips = (0..<clipCount).map { _ in LauncherClip() }
        self.volume = 0.8
        self.pan = 0
        self.isMuted = false
        self.isSoloed = false
        self.isArmed = false
        self.color = color
        self.sendLevels = [0, 0]
    }
}

// MARK: - Scene Model

/// Scene (row) in the clip launcher
public struct LauncherScene: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var tempo: Double?      // Optional tempo change
    public var timeSignature: TimeSignature?
    public var color: LauncherClip.ClipColor

    public struct TimeSignature: Codable {
        public var numerator: Int
        public var denominator: Int
    }

    public init(id: UUID = UUID(), name: String = "Scene", color: LauncherClip.ClipColor = .gray) {
        self.id = id
        self.name = name
        self.color = color
    }
}

// MARK: - Clip Launcher Engine

/// Main clip launcher controller with bio-reactive features
@MainActor
public final class ClipLauncherGrid: ObservableObject {

    // MARK: - Published State

    @Published public var tracks: [LauncherTrack] = []
    @Published public var scenes: [LauncherScene] = []
    @Published public private(set) var isPlaying: Bool = false
    @Published public var tempo: Double = 120.0
    @Published public var globalQuantization: LauncherClip.Quantization = .bar1
    @Published public private(set) var currentBeat: Double = 0
    @Published public private(set) var currentBar: Int = 1

    // Bio-reactive
    @Published public var bioReactiveEnabled: Bool = true
    @Published public var coherenceThreshold: Float = 0.7  // Auto-launch threshold
    @Published public private(set) var currentCoherence: Float = 0.5

    // Selection
    @Published public var selectedClipID: UUID?
    @Published public var selectedTrackID: UUID?
    @Published public var selectedSceneIndex: Int?

    // MARK: - Audio

    private var audioEngine: AVAudioEngine?
    private var players: [UUID: AVAudioPlayerNode] = [:]
    private var playbackTimer: Timer?

    // MARK: - Initialization

    public init(trackCount: Int = 8, sceneCount: Int = 8) {
        setupDefaultGrid(trackCount: trackCount, sceneCount: sceneCount)
        setupAudioEngine()
    }

    private func setupDefaultGrid(trackCount: Int, sceneCount: Int) {
        let colors: [LauncherClip.ClipColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]

        tracks = (0..<trackCount).map { i in
            var track = LauncherTrack(
                name: "Track \(i + 1)",
                type: i < trackCount - 2 ? .audio : .midi,
                clipCount: sceneCount,
                color: colors[i % colors.count]
            )
            return track
        }

        scenes = (0..<sceneCount).map { i in
            LauncherScene(name: "Scene \(i + 1)")
        }
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }

    // MARK: - Playback Control

    /// Start global playback
    public func play() {
        isPlaying = true
        startPlaybackTimer()

        do {
            try audioEngine?.start()
        } catch {
            log.audio("Audio engine start failed: \(error)", level: .error)
        }
    }

    /// Stop global playback
    public func stop() {
        isPlaying = false
        stopPlaybackTimer()
        stopAllClips()
        currentBeat = 0
        currentBar = 1
        audioEngine?.stop()
    }

    /// Toggle playback
    public func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    private func startPlaybackTimer() {
        let interval = 60.0 / tempo / 4.0  // 16th note resolution
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advancePlayhead()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func advancePlayhead() {
        currentBeat += 0.25
        if currentBeat >= 4 {
            currentBeat = 0
            currentBar += 1
        }

        // Check for queued clips that should start
        processQueuedClips()
    }

    // MARK: - Clip Control

    /// Launch a clip at the specified position
    public func launchClip(trackIndex: Int, clipIndex: Int) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        var clip = tracks[trackIndex].clips[clipIndex]

        // Stop other clips in the same track
        stopTrackClips(trackIndex: trackIndex, except: clip.id)

        // Queue or play based on quantization
        if clip.quantization == .none || !isPlaying {
            clip.state = .playing
            playClip(clip, trackIndex: trackIndex)
        } else {
            clip.state = .queued
        }

        tracks[trackIndex].clips[clipIndex] = clip
    }

    /// Stop a specific clip
    public func stopClip(trackIndex: Int, clipIndex: Int) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        tracks[trackIndex].clips[clipIndex].state = .stopped
        if let player = players[tracks[trackIndex].clips[clipIndex].id] {
            player.stop()
        }
    }

    /// Stop all clips in a track
    public func stopTrackClips(trackIndex: Int, except clipID: UUID? = nil) {
        guard trackIndex < tracks.count else { return }

        for i in 0..<tracks[trackIndex].clips.count {
            if tracks[trackIndex].clips[i].id != clipID {
                tracks[trackIndex].clips[i].state = .stopped
                if let player = players[tracks[trackIndex].clips[i].id] {
                    player.stop()
                }
            }
        }
    }

    /// Stop all clips globally
    public func stopAllClips() {
        for trackIndex in 0..<tracks.count {
            stopTrackClips(trackIndex: trackIndex)
        }
    }

    private func playClip(_ clip: LauncherClip, trackIndex: Int) {
        guard clip.type != .empty else { return }

        // Audio playback would happen here
        // For now, we just update the state
    }

    private func processQueuedClips() {
        // Check if we're at a quantization boundary
        let isBarBoundary = currentBeat == 0

        for trackIndex in 0..<tracks.count {
            for clipIndex in 0..<tracks[trackIndex].clips.count {
                var clip = tracks[trackIndex].clips[clipIndex]
                if clip.state == .queued {
                    let shouldLaunch: Bool
                    switch clip.quantization {
                    case .bar1, .bar2, .bar4, .bar8:
                        shouldLaunch = isBarBoundary
                    case .beat1:
                        shouldLaunch = currentBeat.truncatingRemainder(dividingBy: 1) == 0
                    case .beat1_2:
                        shouldLaunch = currentBeat.truncatingRemainder(dividingBy: 0.5) == 0
                    case .beat1_4:
                        shouldLaunch = true  // Every 16th note
                    case .none:
                        shouldLaunch = true
                    }

                    if shouldLaunch {
                        clip.state = .playing
                        tracks[trackIndex].clips[clipIndex] = clip
                        playClip(clip, trackIndex: trackIndex)
                    }
                }
            }
        }
    }

    // MARK: - Scene Control

    /// Launch all clips in a scene (row)
    public func launchScene(index: Int) {
        guard index < scenes.count else { return }

        selectedSceneIndex = index

        // Apply scene tempo if set
        if let sceneTempo = scenes[index].tempo {
            tempo = sceneTempo
        }

        // Launch clip in each track at this scene index
        for trackIndex in 0..<tracks.count {
            if index < tracks[trackIndex].clips.count {
                launchClip(trackIndex: trackIndex, clipIndex: index)
            }
        }
    }

    /// Stop all clips in a scene
    public func stopScene(index: Int) {
        guard index < scenes.count else { return }

        for trackIndex in 0..<tracks.count {
            if index < tracks[trackIndex].clips.count {
                stopClip(trackIndex: trackIndex, clipIndex: index)
            }
        }
    }

    // MARK: - Track Control

    /// Toggle track mute
    public func toggleMute(trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].isMuted.toggle()
    }

    /// Toggle track solo
    public func toggleSolo(trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].isSoloed.toggle()
    }

    /// Toggle track arm (for recording)
    public func toggleArm(trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].isArmed.toggle()
    }

    /// Set track volume
    public func setVolume(trackIndex: Int, volume: Float) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].volume = max(0, min(1, volume))
    }

    /// Set track pan
    public func setPan(trackIndex: Int, pan: Float) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].pan = max(-1, min(1, pan))
    }

    // MARK: - Clip Editing

    /// Add a new clip to a slot
    public func addClip(trackIndex: Int, clipIndex: Int, name: String, type: LauncherClip.ClipType) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        var clip = LauncherClip(name: name, color: tracks[trackIndex].color, type: type)
        tracks[trackIndex].clips[clipIndex] = clip
    }

    /// Delete a clip
    public func deleteClip(trackIndex: Int, clipIndex: Int) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        tracks[trackIndex].clips[clipIndex] = LauncherClip()
    }

    /// Duplicate a clip
    public func duplicateClip(trackIndex: Int, clipIndex: Int, toClipIndex: Int) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count,
              toClipIndex < tracks[trackIndex].clips.count else { return }

        var newClip = tracks[trackIndex].clips[clipIndex]
        newClip.id = UUID()
        newClip.state = .stopped
        tracks[trackIndex].clips[toClipIndex] = newClip
    }

    /// Set clip color
    public func setClipColor(trackIndex: Int, clipIndex: Int, color: LauncherClip.ClipColor) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        tracks[trackIndex].clips[clipIndex].color = color
    }

    /// Rename clip
    public func renameClip(trackIndex: Int, clipIndex: Int, name: String) {
        guard trackIndex < tracks.count,
              clipIndex < tracks[trackIndex].clips.count else { return }

        tracks[trackIndex].clips[clipIndex].name = name
    }

    // MARK: - Bio-Reactive Features

    /// Update coherence value from biofeedback
    public func updateCoherence(_ coherence: Float) {
        currentCoherence = coherence

        guard bioReactiveEnabled else { return }

        // Auto-launch next scene when coherence threshold is reached
        if coherence > coherenceThreshold {
            if let currentScene = selectedSceneIndex, currentScene + 1 < scenes.count {
                // Queue next scene for launch
                launchScene(index: currentScene + 1)
            }
        }

        // Modulate tempo based on coherence
        let baseTempoModulation = (coherence - 0.5) * 10  // ±5 BPM
        // tempo = baseTempo + baseTempoModulation (if enabled)
    }

    /// Bio-reactive clip velocity modulation
    public func applyBioVelocity(heartRate: Float) {
        let normalizedHR = (heartRate - 60) / 60  // Normalize around 60-120 BPM
        let velocityModulation = 0.8 + normalizedHR * 0.4  // 0.6 - 1.2 range

        for trackIndex in 0..<tracks.count {
            for clipIndex in 0..<tracks[trackIndex].clips.count {
                if tracks[trackIndex].clips[clipIndex].state == .playing {
                    tracks[trackIndex].clips[clipIndex].velocity = velocityModulation
                }
            }
        }
    }

    // MARK: - Grid Management

    /// Add a new track
    public func addTrack(type: LauncherTrack.TrackType = .audio) {
        let colors: [LauncherClip.ClipColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]
        let newTrack = LauncherTrack(
            name: "Track \(tracks.count + 1)",
            type: type,
            clipCount: scenes.count,
            color: colors[tracks.count % colors.count]
        )
        tracks.append(newTrack)
    }

    /// Remove a track
    public func removeTrack(at index: Int) {
        guard index < tracks.count, tracks.count > 1 else { return }
        tracks.remove(at: index)
    }

    /// Add a new scene
    public func addScene() {
        let newScene = LauncherScene(name: "Scene \(scenes.count + 1)")
        scenes.append(newScene)

        // Add empty clip to each track for the new scene
        for i in 0..<tracks.count {
            tracks[i].clips.append(LauncherClip())
        }
    }

    /// Remove a scene
    public func removeScene(at index: Int) {
        guard index < scenes.count, scenes.count > 1 else { return }
        scenes.remove(at: index)

        // Remove clip from each track at this index
        for i in 0..<tracks.count {
            if index < tracks[i].clips.count {
                tracks[i].clips.remove(at: index)
            }
        }
    }

    // MARK: - Presets

    /// Load a preset configuration
    public func loadPreset(_ preset: GridPreset) {
        tempo = preset.tempo
        globalQuantization = preset.quantization

        // Apply preset clips
        for (trackIndex, trackData) in preset.tracks.enumerated() {
            guard trackIndex < tracks.count else { break }
            tracks[trackIndex].name = trackData.name
            tracks[trackIndex].color = trackData.color
        }
    }

    public struct GridPreset: Codable {
        public let name: String
        public let tempo: Double
        public let quantization: LauncherClip.Quantization
        public let tracks: [TrackPreset]

        public struct TrackPreset: Codable {
            public let name: String
            public let color: LauncherClip.ClipColor
        }
    }
}

// MARK: - SwiftUI Views

/// Main clip launcher grid view
public struct ClipLauncherGridView: View {
    @StateObject private var launcher: ClipLauncherGrid
    @State private var showingSettings = false

    public init(launcher: ClipLauncherGrid? = nil) {
        _launcher = StateObject(wrappedValue: launcher ?? ClipLauncherGrid())
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Transport bar
            transportBar

            // Main grid
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 1) {
                    // Track headers
                    trackHeaderRow

                    // Clip grid with scene launchers
                    ForEach(Array(launcher.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                        HStack(spacing: 1) {
                            // Scene launcher button
                            sceneLauncherButton(index: sceneIndex, scene: scene)

                            // Clip cells for this scene
                            ForEach(Array(launcher.tracks.enumerated()), id: \.element.id) { trackIndex, track in
                                if sceneIndex < track.clips.count {
                                    clipCell(
                                        clip: track.clips[sceneIndex],
                                        trackIndex: trackIndex,
                                        clipIndex: sceneIndex
                                    )
                                }
                            }
                        }
                    }

                    // Stop all row
                    stopAllRow
                }
            }

            // Track mixer strip
            trackMixerStrip
        }
        .background(Color.black)
        .sheet(isPresented: $showingSettings) {
            settingsView
        }
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack {
            // Play/Stop
            Button(action: { launcher.togglePlayback() }) {
                Image(systemName: launcher.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(launcher.isPlaying ? .red : .green)
            }

            Divider().frame(height: 30)

            // Tempo
            HStack {
                Text("BPM")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("", value: $launcher.tempo, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }

            Divider().frame(height: 30)

            // Position
            Text("\(launcher.currentBar).\(Int(launcher.currentBeat) + 1)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 60)

            Divider().frame(height: 30)

            // Quantization
            Picker("Q", selection: $launcher.globalQuantization) {
                ForEach(LauncherClip.Quantization.allCases, id: \.self) { q in
                    Text(q.rawValue).tag(q)
                }
            }
            .frame(width: 100)

            Spacer()

            // Bio indicator
            if launcher.bioReactiveEnabled {
                HStack {
                    Circle()
                        .fill(coherenceColor)
                        .frame(width: 10, height: 10)
                    Text("\(Int(launcher.currentCoherence * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }

            // Settings
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gear")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }

    private var coherenceColor: Color {
        if launcher.currentCoherence > 0.7 { return .green }
        if launcher.currentCoherence > 0.4 { return .yellow }
        return .red
    }

    // MARK: - Track Headers

    private var trackHeaderRow: some View {
        HStack(spacing: 1) {
            // Empty corner
            Rectangle()
                .fill(Color.clear)
                .frame(width: 60, height: 40)

            // Track headers
            ForEach(Array(launcher.tracks.enumerated()), id: \.element.id) { index, track in
                VStack(spacing: 2) {
                    Text(track.name)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        // Mute
                        Button(action: { launcher.toggleMute(trackIndex: index) }) {
                            Text("M")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(track.isMuted ? .orange : .gray)
                        }
                        .frame(width: 20, height: 16)
                        .background(track.isMuted ? Color.orange.opacity(0.3) : Color.clear)
                        .cornerRadius(2)

                        // Solo
                        Button(action: { launcher.toggleSolo(trackIndex: index) }) {
                            Text("S")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(track.isSoloed ? .yellow : .gray)
                        }
                        .frame(width: 20, height: 16)
                        .background(track.isSoloed ? Color.yellow.opacity(0.3) : Color.clear)
                        .cornerRadius(2)
                    }
                }
                .frame(width: 80, height: 40)
                .background(track.color.swiftUIColor.opacity(0.3))
            }
        }
    }

    // MARK: - Scene Launcher

    private func sceneLauncherButton(index: Int, scene: LauncherScene) -> some View {
        Button(action: { launcher.launchScene(index: index) }) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                Text(scene.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(launcher.selectedSceneIndex == index ? .white : .gray)
            .frame(width: 60, height: 50)
            .background(launcher.selectedSceneIndex == index ? Color.green.opacity(0.5) : Color(white: 0.2))
        }
    }

    // MARK: - Clip Cell

    private func clipCell(clip: LauncherClip, trackIndex: Int, clipIndex: Int) -> some View {
        Button(action: {
            if clip.state == .playing {
                launcher.stopClip(trackIndex: trackIndex, clipIndex: clipIndex)
            } else {
                launcher.launchClip(trackIndex: trackIndex, clipIndex: clipIndex)
            }
        }) {
            VStack(spacing: 2) {
                if clip.type != .empty {
                    // Clip name
                    Text(clip.name)
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // State indicator
                    HStack(spacing: 2) {
                        Circle()
                            .fill(clipStateColor(clip.state))
                            .frame(width: 6, height: 6)

                        if clip.loopEnabled {
                            Image(systemName: "repeat")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    // Empty slot
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .frame(width: 80, height: 50)
            .background(clipBackground(clip))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(clip.state == .playing ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .cornerRadius(4)
    }

    private func clipStateColor(_ state: LauncherClip.ClipState) -> Color {
        switch state {
        case .stopped: return .gray
        case .queued: return .yellow
        case .playing: return .green
        case .recording: return .red
        }
    }

    private func clipBackground(_ clip: LauncherClip) -> Color {
        if clip.type == .empty {
            return Color(white: 0.1)
        }
        return clip.color.swiftUIColor.opacity(0.4)
    }

    // MARK: - Stop All Row

    private var stopAllRow: some View {
        HStack(spacing: 1) {
            // Stop all scenes
            Button(action: { launcher.stopAllClips() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
                    .frame(width: 60, height: 30)
                    .background(Color(white: 0.15))
            }

            // Stop buttons for each track
            ForEach(Array(launcher.tracks.enumerated()), id: \.element.id) { index, _ in
                Button(action: { launcher.stopTrackClips(trackIndex: index) }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: 80, height: 30)
                        .background(Color(white: 0.15))
                }
            }
        }
    }

    // MARK: - Track Mixer Strip

    private var trackMixerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(Array(launcher.tracks.enumerated()), id: \.element.id) { index, track in
                    VStack(spacing: 4) {
                        // Volume slider (vertical)
                        Slider(
                            value: Binding(
                                get: { Double(track.volume) },
                                set: { launcher.setVolume(trackIndex: index, volume: Float($0)) }
                            ),
                            in: 0...1
                        )
                        .frame(height: 60)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 80)

                        // Volume value
                        Text("\(Int(track.volume * 100))")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        // Pan knob representation
                        Text("◀ \(Int(track.pan * 50)) ▶")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 80)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.1))
                }
            }
        }
        .frame(height: 120)
        .background(Color(white: 0.05))
    }

    // MARK: - Settings View

    private var settingsView: some View {
        EchoelNavigationStack {
            Form {
                Section("Bio-Reactive") {
                    Toggle("Enable Bio-Reactive", isOn: $launcher.bioReactiveEnabled)

                    VStack(alignment: .leading) {
                        Text("Coherence Threshold: \(Int(launcher.coherenceThreshold * 100))%")
                        Slider(value: $launcher.coherenceThreshold, in: 0.3...0.95)
                    }
                }

                Section("Grid") {
                    Stepper("Tracks: \(launcher.tracks.count)", onIncrement: {
                        launcher.addTrack()
                    }, onDecrement: {
                        if launcher.tracks.count > 1 {
                            launcher.removeTrack(at: launcher.tracks.count - 1)
                        }
                    })

                    Stepper("Scenes: \(launcher.scenes.count)", onIncrement: {
                        launcher.addScene()
                    }, onDecrement: {
                        if launcher.scenes.count > 1 {
                            launcher.removeScene(at: launcher.scenes.count - 1)
                        }
                    })
                }

                Section("Quantization") {
                    Picker("Global Quantization", selection: $launcher.globalQuantization) {
                        ForEach(LauncherClip.Quantization.allCases, id: \.self) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                }
            }
            .navigationTitle("Clip Launcher Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClipLauncherGridView_Previews: PreviewProvider {
    static var previews: some View {
        ClipLauncherGridView()
            .preferredColorScheme(.dark)
    }
}
#endif

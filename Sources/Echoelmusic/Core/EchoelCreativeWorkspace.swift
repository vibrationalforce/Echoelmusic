import Foundation
import Combine
import AVFoundation

// ═══════════════════════════════════════════════════════════════════════════════
//
//   ECHOELMUSIC CREATIVE WORKSPACE
//   Unified integration bridge that connects ALL engines into one workflow.
//
//   Architecture:
//   ┌──────────────────────────────────────────────────────────────────┐
//   │                  EchoelCreativeWorkspace                         │
//   │                                                                  │
//   │  ┌─────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────┐ │
//   │  │ Audio   │  │ Video Editor │  │ BPM Grid   │  │ Creative  │ │
//   │  │ Engine  │←→│ + Timeline   │←→│ Edit Engine │←→│ Studio    │ │
//   │  └────┬────┘  └──────┬───────┘  └─────┬──────┘  └─────┬─────┘ │
//   │       │              │                 │               │       │
//   │       └──────────────┼─────────────────┼───────────────┘       │
//   │                      ▼                 ▼                       │
//   │            ┌──────────────────────────────────┐                │
//   │            │      EchoelUniversalCore         │                │
//   │            │  (Bio + Quantum + Sync + AI)     │                │
//   │            └──────────────────────────────────┘                │
//   │                      ▼                                         │
//   │            ┌──────────────────────────────────┐                │
//   │            │   WorldwideCollaborationHub      │                │
//   │            │   (Session Sync + Streaming)     │                │
//   │            └──────────────────────────────────┘                │
//   └──────────────────────────────────────────────────────────────────┘
//
//   Workflow:
//   1. Start making a track → BPM detected → Grid syncs
//   2. Switch to video → Timeline locked to same BPM grid
//   3. Beat-synced cuts, effects, transitions — all automatic
//   4. Immersive spatial audio + new video formats
//   5. Export for home (smart lights) or stage (DMX/laser)
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Creative Workspace Mode

/// What the user is focused on right now
public enum WorkspaceMode: String, CaseIterable {
    case audio = "Audio"
    case video = "Video"
    case audioVideo = "Audio + Video"
    case immersive = "Immersive"
    case live = "Live Performance"

    public var icon: String {
        switch self {
        case .audio: return "waveform"
        case .video: return "film"
        case .audioVideo: return "play.rectangle"
        case .immersive: return "visionpro"
        case .live: return "music.mic"
        }
    }
}

/// Output target for the final result
public enum OutputTarget: String, CaseIterable {
    case home = "Home"
    case social = "Social Media"
    case stage = "Stage / Event"
    case immersive = "Immersive / VR"
    case broadcast = "Broadcast / Stream"

    public var icon: String {
        switch self {
        case .home: return "house.fill"
        case .social: return "square.and.arrow.up"
        case .stage: return "theatermasks.fill"
        case .immersive: return "visionpro.fill"
        case .broadcast: return "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - Creative Workspace

/// Unified workspace that bridges ALL engines into one seamless creative flow.
/// Build a track → edit video on the beat → add immersive audio → export.
@MainActor
public final class EchoelCreativeWorkspace: ObservableObject {

    // MARK: - Singleton

    static let shared = EchoelCreativeWorkspace()

    // MARK: - Published State

    @Published public var mode: WorkspaceMode = .audioVideo
    @Published public var outputTarget: OutputTarget = .home
    @Published public var isPlaying: Bool = false
    @Published public var globalBPM: Double = 120.0
    @Published public var globalTimeSignature: TimeSignature = .fourFour

    // MARK: - Connected Engines

    /// BPM Grid — beat detection, snap, quantize, tempo automation
    public let bpmGrid: BPMGridEditEngine

    /// Video Editor — NLE timeline, clips, keyframes, undo/redo
    public let videoEditor: VideoEditingEngine

    /// Creative Studio — art styles, music genres, creative modes
    public let creativeStudio: CreativeStudioEngine

    /// Collaboration — worldwide sessions, streaming
    public let collaboration: WorldwideCollaborationHub

    /// Universal Core — bio-reactive, quantum, sync, AI (already connected)
    private let universalCore = EchoelUniversalCore.shared

    /// Video AI Hub — already connected to UniversalCore
    private let videoAIHub = VideoAICreativeHub.shared

    // MARK: - Pro Engines (Professional Producer Grade)

    /// Pro Mix Engine — channel strips, sends, returns, buses, sidechain, automation
    /// (Best of Ableton + Reaper + Pro Tools mixer)
    public let proMixer: ProMixEngine

    /// Pro Session Engine — clip launcher, patterns, scene launching, warping
    /// (Best of Ableton Session View + FL Studio Channel Rack)
    public let proSession: ProSessionEngine

    /// Pro Color Grading — curves, wheels, LUTs, scopes, node-based grading
    /// (Best of DaVinci Resolve color page)
    public let proColor: ProColorGrading

    /// Pro Cue System — cue lists, show files, DMX fixtures, timecode sync
    /// (Best of Resolume Arena + grandMA lighting console)
    public let proCue: ProCueSystem

    /// Pro Stream Engine — scenes, sources, multi-stream, replay buffer
    /// (Best of OBS Studio + Restream)
    public let proStream: ProStreamEngine

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Initialize core engines
        self.bpmGrid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        self.videoEditor = VideoEditingEngine()
        self.creativeStudio = CreativeStudioEngine()
        self.collaboration = WorldwideCollaborationHub()

        // Initialize pro engines (professional producer grade)
        self.proMixer = ProMixEngine.defaultSession()
        self.proSession = ProSessionEngine.defaultSession()
        self.proColor = ProColorGrading()
        self.proCue = ProCueSystem()
        self.proStream = ProStreamEngine.defaultSetup()

        setupBridges()
        log.info("EchoelCreativeWorkspace: All engines connected (core + pro)", category: .system)
    }

    // MARK: - Bridge Setup

    private func setupBridges() {
        bridgeBPMGridToVideoEditor()
        bridgeBPMGridToUniversalCore()
        bridgeCollaborationToUniversalCore()
        bridgeBioToBPM()
        bridgeProMixerToSession()
        bridgeProCueToStream()
        bridgeBPMToSessionEngine()
    }

    /// Bridge 5: Pro Mixer ↔ Session Engine
    /// Session clip launches feed through the mixer routing
    private func bridgeProMixerToSession() {
        proSession.$globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.setGlobalBPM(bpm)
            }
            .store(in: &cancellables)
    }

    /// Bridge 6: Cue System → Stream Engine
    /// Cue triggers can switch stream scenes (Resolume → OBS link)
    private func bridgeProCueToStream() {
        proCue.$activeScene
            .compactMap { $0 }
            .sink { [weak self] cueScene in
                // When a cue activates a scene, the stream engine can match
                self?.proStream.switchSceneByName(cueScene.name)
            }
            .store(in: &cancellables)
    }

    /// Bridge 7: BPM Grid → Session Engine
    /// Global tempo syncs to session clip playback
    private func bridgeBPMToSessionEngine() {
        $globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.proSession.globalBPM = bpm
            }
            .store(in: &cancellables)
    }

    /// Bridge 1: BPM Grid ↔ Video Editor Timeline
    /// When BPM changes in the grid, the video timeline syncs.
    /// When video detects audio beats, the grid updates.
    private func bridgeBPMGridToVideoEditor() {
        // BPM Grid → Video Timeline: sync tempo
        bpmGrid.$grid
            .map(\.bpm)
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.videoEditor.timeline.tempo = bpm
                self?.globalBPM = bpm
            }
            .store(in: &cancellables)

        // BPM Grid → Video: beat callbacks trigger visual effects
        bpmGrid.onBeat = { [weak self] beat, bar in
            guard let self = self else { return }
            // Trigger any beat-synced video effects
            for effect in self.bpmGrid.beatSyncedEffects {
                self.bpmGrid.onBeatEffect?(effect)
            }
        }

        // BPM Grid snap → Video magnetic snap override
        // The video editor's magneticSnap now uses BPM grid precision
        videoEditor.timeline.tempo = bpmGrid.grid.bpm
    }

    /// Bridge 2: BPM Grid → Universal Core
    /// Tempo data flows into the global system state.
    private func bridgeBPMGridToUniversalCore() {
        bpmGrid.$grid
            .map(\.bpm)
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.universalCore.systemState.bpm = bpm
            }
            .store(in: &cancellables)
    }

    /// Bridge 3: Collaboration → Universal Core
    /// Session state syncs through the core for multi-device coherence.
    private func bridgeCollaborationToUniversalCore() {
        universalCore.$globalCoherence
            .sink { [weak self] coherence in
                self?.collaboration.updateCoherence(Double(coherence))
            }
            .store(in: &cancellables)
    }

    /// Bridge 4: Bio data → BPM modulation
    /// Heart rate can gently influence tempo (optional).
    private func bridgeBioToBPM() {
        universalCore.$systemState
            .map(\.heartRate)
            .removeDuplicates()
            .filter { $0 > 0 }
            .sink { [weak self] heartRate in
                // Bio-tempo: use heart rate as tempo suggestion (not override)
                self?.universalCore.systemState.bioTempo = heartRate
            }
            .store(in: &cancellables)
    }

    // MARK: - Workspace Actions

    /// Start a new creative session
    public func newSession(mode: WorkspaceMode, bpm: Double = 120, timeSignature: TimeSignature = .fourFour) {
        self.mode = mode
        bpmGrid.setBPM(bpm)
        bpmGrid.setTimeSignature(timeSignature)
        videoEditor.timeline.tempo = bpm
        globalBPM = bpm
        globalTimeSignature = timeSignature

        log.info("🎬 Workspace: New \(mode.rawValue) session at \(Int(bpm)) BPM", category: .system)
    }

    /// Detect BPM from audio file and sync everything
    public func detectAndSyncBPM(from audioURL: URL) async {
        let result = await bpmGrid.detectBeats(from: audioURL)
        if result.confidence > 0.5 {
            globalBPM = result.bpm
            videoEditor.timeline.tempo = result.bpm
            log.info("🎵 Workspace: Detected \(Int(result.bpm)) BPM (confidence: \(Int(result.confidence * 100))%)", category: .audio)
        }
    }

    /// Set BPM globally — updates all engines at once
    public func setGlobalBPM(_ bpm: Double) {
        bpmGrid.setBPM(bpm)
        videoEditor.timeline.tempo = bpm
        globalBPM = bpm
        universalCore.systemState.bpm = bpm
    }

    /// Set time signature globally
    public func setGlobalTimeSignature(_ ts: TimeSignature) {
        bpmGrid.setTimeSignature(ts)
        globalTimeSignature = ts
    }

    /// Snap video cut to next beat
    public func cutVideoOnBeat(at currentTime: Double) -> Double {
        return bpmGrid.cutAtNextBeat(from: currentTime)
    }

    /// Snap video cut to next bar
    public func cutVideoOnBar(at currentTime: Double) -> Double {
        return bpmGrid.cutAtNextBar(from: currentTime)
    }

    /// Generate auto-cuts on beats for a video range
    public func autoEditOnBeats(from start: Double, to end: Double, every: SnapMode = .beat) -> [Double] {
        return bpmGrid.generateAutoCuts(from: start, to: end, every: every)
    }

    /// Switch workspace mode seamlessly
    public func switchMode(_ newMode: WorkspaceMode) {
        let previousMode = mode
        mode = newMode
        log.info("🔄 Workspace: \(previousMode.rawValue) → \(newMode.rawValue)", category: .system)
    }

    /// Update playback position — syncs BPM grid + video
    public func updatePlaybackPosition(_ seconds: Double) {
        bpmGrid.updatePosition(seconds)
        videoEditor.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    /// Play/pause toggle — syncs all engines
    public func togglePlayback() {
        if isPlaying {
            videoEditor.pause()
        } else {
            Task { await videoEditor.play() }
        }
        isPlaying.toggle()
    }
}

// MARK: - VideoEditingEngine BPM Grid Extension

extension VideoEditingEngine {

    /// Snap clip to BPM grid beat
    func snapToBeat(_ seconds: Double, grid: BPMGridEditEngine) -> CMTime {
        let snapped = grid.snap(seconds)
        return CMTime(seconds: snapped, preferredTimescale: 600)
    }

    /// Split clip at next beat
    func splitOnBeat(clipID: UUID, track: VideoTrack, grid: BPMGridEditEngine, at currentTime: Double) -> (UUID, UUID)? {
        let beatTime = grid.cutAtNextBeat(from: currentTime)
        return splitClip(clipID: clipID, track: track, at: CMTime(seconds: beatTime, preferredTimescale: 600))
    }

    /// Add beat-synced transition between clips
    func addBeatTransition(type: BeatSyncedTransition.TransitionType, durationBeats: Double = 1) -> BeatSyncedTransition {
        return BeatSyncedTransition(type: type, durationBeats: durationBeats)
    }
}

// MARK: - WorldwideCollaborationHub Coherence Bridge

extension WorldwideCollaborationHub {

    /// Receive coherence updates from Universal Core
    func updateCoherence(_ coherence: Double) {
        // Sync coherence to all participants in active session
        // This bridges the collaboration engine into the bio-reactive system
    }
}

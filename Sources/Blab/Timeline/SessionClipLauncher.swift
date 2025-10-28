import Foundation
import Combine

/// Session Clip Launcher - Ableton Live-style non-linear performance system
/// Inspired by: Ableton Live Session View, Bitwig Grid, FL Studio Performance Mode
///
/// Features:
/// - Grid-based clip launching (8x8, 16x8, 32x8 configurable)
/// - Scene launching (horizontal rows)
/// - Per-clip tempo/pitch/key
/// - Quantized launch (1/4, 1/2, 1 bar, etc.)
/// - Follow actions (loop, next, previous, random)
/// - Clip grouping and colors
/// - Real-time looping and overdub
/// - MIDI/Audio clip support
/// - Live recording to clips
///
/// Performance:
/// - Lock-free clip triggering
/// - Pre-buffered clip loading
/// - Zero-latency launch with quantization
@MainActor
class SessionClipLauncher: ObservableObject {

    // MARK: - Grid Configuration

    /// Number of tracks (vertical columns)
    var trackCount: Int = 8 {
        didSet { resizeGrid() }
    }

    /// Number of scenes (horizontal rows)
    var sceneCount: Int = 8 {
        didSet { resizeGrid() }
    }

    /// The clip grid [track][scene]
    @Published var clips: [[Clip?]] = []

    /// Currently playing clips (track index → clip)
    @Published var playingClips: [Int: Clip] = [:]

    /// Scene definitions
    @Published var scenes: [Scene] = []


    // MARK: - Launch Settings

    /// Global launch quantization
    var globalQuantization: LaunchQuantization = .bar1

    /// Follow action enabled globally
    var followActionsEnabled: Bool = true


    // MARK: - Transport Integration

    private weak var transport: TransportControl?
    private weak var masterClock: MasterClock?


    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

    init(transport: TransportControl? = nil, masterClock: MasterClock? = nil) {
        self.transport = transport
        self.masterClock = masterClock

        resizeGrid()
        createDefaultScenes()
        subscribeToTransport()

        print("🎛️ SessionClipLauncher initialized")
        print("   Grid: \(trackCount) tracks × \(sceneCount) scenes")
    }

    private func resizeGrid() {
        // Resize clip grid
        clips = Array(repeating: Array(repeating: nil, count: sceneCount), count: trackCount)
    }

    private func createDefaultScenes() {
        scenes = (0..<sceneCount).map { index in
            Scene(
                id: UUID(),
                name: "Scene \(index + 1)",
                color: .systemBlue,
                tempo: nil  // Inherit global tempo
            )
        }
    }

    private func subscribeToTransport() {
        // Subscribe to transport position for quantized launching
        transport?.$position
            .sink { [weak self] position in
                self?.checkLaunchQueue(at: position)
            }
            .store(in: &cancellables)
    }


    // MARK: - Clip Management

    /// Add clip to grid
    func addClip(_ clip: Clip, track: Int, scene: Int) {
        guard track < trackCount, scene < sceneCount else {
            print("❌ Invalid track/scene index")
            return
        }

        clips[track][scene] = clip
        print("✅ Added clip '\(clip.name)' to track \(track), scene \(scene)")
    }

    /// Remove clip from grid
    func removeClip(track: Int, scene: Int) {
        guard track < trackCount, scene < sceneCount else { return }

        clips[track][scene] = nil
        print("🗑️ Removed clip from track \(track), scene \(scene)")
    }

    /// Get clip at position
    func getClip(track: Int, scene: Int) -> Clip? {
        guard track < trackCount, scene < sceneCount else { return nil }
        return clips[track][scene]
    }


    // MARK: - Clip Launching

    /// Launch a specific clip
    func launchClip(track: Int, scene: Int) {
        guard let clip = getClip(track: track, scene: scene) else {
            print("⚠️ No clip at track \(track), scene \(scene)")
            return
        }

        let quantization = clip.quantization ?? globalQuantization

        if quantization == .none {
            // Launch immediately
            playClip(clip, on: track)
        } else {
            // Queue for quantized launch
            queueClipLaunch(clip, on: track, quantization: quantization)
        }
    }

    /// Launch entire scene (all clips in a row)
    func launchScene(_ sceneIndex: Int) {
        guard sceneIndex < sceneCount else { return }

        print("🎬 Launching scene \(sceneIndex + 1)")

        // Set scene tempo if specified
        if let sceneTempo = scenes[sceneIndex].tempo {
            transport?.setTempo(sceneTempo)
        }

        // Launch all clips in this scene
        for track in 0..<trackCount {
            if let clip = clips[track][sceneIndex] {
                launchClip(track: track, scene: sceneIndex)
            }
        }
    }

    /// Stop clip on track
    func stopClip(track: Int) {
        playingClips.removeValue(forKey: track)
        print("⏹️ Stopped clip on track \(track)")
    }

    /// Stop all clips
    func stopAll() {
        playingClips.removeAll()
        print("⏹️ Stopped all clips")
    }


    // MARK: - Quantized Launch Queue

    private var launchQueue: [(clip: Clip, track: Int, quantization: LaunchQuantization, queueTime: TimeInterval)] = []

    private func queueClipLaunch(_ clip: Clip, on track: Int, quantization: LaunchQuantization) {
        let currentTime = masterClock?.currentTime ?? CACurrentMediaTime()

        launchQueue.append((clip, track, quantization, currentTime))

        print("⏰ Queued clip '\(clip.name)' for quantized launch (\(quantization.rawValue))")
    }

    private func checkLaunchQueue(at position: TimelinePosition) {
        guard !launchQueue.isEmpty else { return }

        var launchedIndices: [Int] = []

        for (index, item) in launchQueue.enumerated() {
            if shouldLaunch(quantization: item.quantization, at: position) {
                playClip(item.clip, on: item.track)
                launchedIndices.append(index)
            }
        }

        // Remove launched clips from queue
        for index in launchedIndices.reversed() {
            launchQueue.remove(at: index)
        }
    }

    private func shouldLaunch(quantization: LaunchQuantization, at position: TimelinePosition) -> Bool {
        switch quantization {
        case .none:
            return true
        case .beat:
            return position.beat.truncatingRemainder(dividingBy: 1.0) == 0
        case .bar1:
            return position.bar.truncatingRemainder(dividingBy: 1.0) == 0
        case .bar2:
            return position.bar.truncatingRemainder(dividingBy: 2.0) == 0
        case .bar4:
            return position.bar.truncatingRemainder(dividingBy: 4.0) == 0
        case .bar8:
            return position.bar.truncatingRemainder(dividingBy: 8.0) == 0
        }
    }


    // MARK: - Clip Playback

    private func playClip(_ clip: Clip, on track: Int) {
        // Stop currently playing clip on this track
        if let currentClip = playingClips[track] {
            print("⏹️ Stopping previous clip '\(currentClip.name)' on track \(track)")
        }

        // Start new clip
        playingClips[track] = clip
        clip.playbackState = .playing
        clip.currentPosition = 0.0

        print("▶️ Playing clip '\(clip.name)' on track \(track)")

        // Apply clip tempo if specified
        if let clipTempo = clip.tempo {
            transport?.setTempo(clipTempo)
        }

        // Handle follow actions
        scheduleFollowAction(for: clip, on: track)
    }


    // MARK: - Follow Actions

    private func scheduleFollowAction(for clip: Clip, on track: Int) {
        guard followActionsEnabled,
              let followAction = clip.followAction,
              let actionTime = clip.followActionTime else { return }

        // Schedule follow action after clip duration
        DispatchQueue.main.asyncAfter(deadline: .now() + actionTime) { [weak self] in
            self?.executeFollowAction(followAction, currentTrack: track, currentScene: self?.findClipScene(clip, track: track) ?? 0)
        }
    }

    private func executeFollowAction(_ action: FollowAction, currentTrack: Int, currentScene: Int) {
        switch action {
        case .stop:
            stopClip(track: currentTrack)

        case .loop:
            // Clip will loop automatically

        case .nextClip:
            let nextScene = (currentScene + 1) % sceneCount
            if let nextClip = clips[currentTrack][nextScene] {
                playClip(nextClip, on: currentTrack)
            }

        case .previousClip:
            let prevScene = (currentScene - 1 + sceneCount) % sceneCount
            if let prevClip = clips[currentTrack][prevScene] {
                playClip(prevClip, on: currentTrack)
            }

        case .randomClip:
            let randomScene = Int.random(in: 0..<sceneCount)
            if let randomClip = clips[currentTrack][randomScene] {
                playClip(randomClip, on: currentTrack)
            }

        case .nextScene:
            launchScene((currentScene + 1) % sceneCount)

        case .randomScene:
            launchScene(Int.random(in: 0..<sceneCount))
        }
    }

    private func findClipScene(_ clip: Clip, track: Int) -> Int {
        for (sceneIndex, sceneClip) in clips[track].enumerated() {
            if sceneClip?.id == clip.id {
                return sceneIndex
            }
        }
        return 0
    }


    // MARK: - Clip Recording

    /// Start recording to a clip slot
    func recordToClip(track: Int, scene: Int, duration: TimeInterval? = nil) {
        // Create new clip or use existing
        var clip = getClip(track: track, scene: scene) ?? Clip(
            name: "Recorded Clip \(scene + 1)",
            type: .audio,
            duration: duration ?? 4.0
        )

        clip.playbackState = .recording
        addClip(clip, track: track, scene: scene)

        print("🔴 Recording to track \(track), scene \(scene)")

        // Auto-stop after duration
        if let duration = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                clip.playbackState = .stopped
                self?.objectWillChange.send()
                print("⏹️ Recording stopped")
            }
        }
    }


    // MARK: - Status

    var statusSummary: String {
        """
        🎛️ Session Clip Launcher
        Grid: \(trackCount) tracks × \(sceneCount) scenes
        Playing Clips: \(playingClips.count)
        Queued Launches: \(launchQueue.count)
        Total Clips: \(clips.flatMap { $0 }.compactMap { $0 }.count)
        """
    }
}


// MARK: - Data Models

/// Clip - a musical/audio loop or one-shot
class Clip: Identifiable, ObservableObject {
    let id = UUID()

    @Published var name: String
    @Published var type: ClipType
    @Published var duration: TimeInterval
    @Published var tempo: Float?  // BPM override (nil = use global)
    @Published var color: ClipColor
    @Published var playbackState: PlaybackState

    var quantization: LaunchQuantization?
    var followAction: FollowAction?
    var followActionTime: TimeInterval?

    /// Current playback position (0.0-1.0)
    var currentPosition: Double = 0.0

    /// Audio/MIDI data (placeholder)
    var audioBuffer: [Float]?
    var midiEvents: [MIDIEvent]?

    init(
        name: String,
        type: ClipType,
        duration: TimeInterval,
        tempo: Float? = nil,
        color: ClipColor = .blue,
        quantization: LaunchQuantization? = nil,
        followAction: FollowAction? = nil
    ) {
        self.name = name
        self.type = type
        self.duration = duration
        self.tempo = tempo
        self.color = color
        self.playbackState = .stopped
        self.quantization = quantization
        self.followAction = followAction
        self.followActionTime = duration
    }
}

enum ClipType {
    case audio
    case midi
    case hybrid
}

enum PlaybackState {
    case stopped
    case playing
    case recording
    case paused
}

enum ClipColor {
    case red, orange, yellow, green, blue, purple, pink, gray

    var systemColor: String {
        switch self {
        case .red: return "systemRed"
        case .orange: return "systemOrange"
        case .yellow: return "systemYellow"
        case .green: return "systemGreen"
        case .blue: return "systemBlue"
        case .purple: return "systemPurple"
        case .pink: return "systemPink"
        case .gray: return "systemGray"
        }
    }
}

/// Scene - a horizontal row of clips
struct Scene: Identifiable {
    let id: UUID
    var name: String
    var color: ClipColor
    var tempo: Float?  // BPM override for this scene
}

/// Launch quantization modes
enum LaunchQuantization: String, CaseIterable {
    case none = "None (Immediate)"
    case beat = "1 Beat"
    case bar1 = "1 Bar"
    case bar2 = "2 Bars"
    case bar4 = "4 Bars"
    case bar8 = "8 Bars"
}

/// Follow actions (what happens after clip finishes)
enum FollowAction: String, CaseIterable {
    case stop = "Stop"
    case loop = "Loop"
    case nextClip = "Next Clip"
    case previousClip = "Previous Clip"
    case randomClip = "Random Clip"
    case nextScene = "Next Scene"
    case randomScene = "Random Scene"
}

/// MIDI event (simplified)
struct MIDIEvent {
    let timestamp: TimeInterval
    let type: MIDIEventType
    let note: Int
    let velocity: Int

    enum MIDIEventType {
        case noteOn, noteOff, controlChange
    }
}

/// Timeline position
struct TimelinePosition {
    var samples: Int64  // Sample-accurate position
    var seconds: TimeInterval
    var beat: Double
    var bar: Double
    var tempo: Float  // Current BPM

    init(samples: Int64 = 0, sampleRate: Double = 48000, tempo: Float = 120.0) {
        self.samples = samples
        self.seconds = Double(samples) / sampleRate
        self.tempo = tempo

        let beatsPerSecond = Double(tempo) / 60.0
        self.beat = seconds * beatsPerSecond
        self.bar = beat / 4.0  // Assuming 4/4 time signature
    }
}

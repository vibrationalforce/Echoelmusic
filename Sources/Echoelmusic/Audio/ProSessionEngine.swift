import Foundation
import AVFoundation
import Combine

// MARK: - MIDINoteEvent

/// A single MIDI note event within a clip
public struct MIDINoteEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// MIDI note number (0-127)
    public var note: UInt8
    /// Velocity (0-127)
    public var velocity: UInt8
    /// Start position in beats from clip start
    public var startBeat: Double
    /// Duration in beats
    public var duration: Double
    /// MIDI channel (0-15)
    public var channel: UInt8

    public init(
        id: UUID = UUID(),
        note: UInt8,
        velocity: UInt8 = 100,
        startBeat: Double,
        duration: Double = 0.25,
        channel: UInt8 = 0
    ) {
        self.id = id
        self.note = note
        self.velocity = velocity
        self.startBeat = startBeat
        self.duration = duration
        self.channel = channel
    }
}

// MARK: - PatternStep

/// A single step in an FL Studio-style step sequencer pattern
public struct PatternStep: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// Step index (0-63 for up to 64 steps)
    public var stepIndex: Int
    /// Whether this step is active (triggers a note)
    public var isActive: Bool
    /// Velocity (0.0 to 1.0)
    public var velocity: Float
    /// Pan position (-1.0 left to 1.0 right)
    public var pan: Float
    /// Pitch offset in semitones (-24 to +24)
    public var pitch: Float
    /// Gate / note length as percentage of step (0.0 to 1.0)
    public var gate: Float
    /// Probability of playing (0.0 to 1.0)
    public var probability: Float
    /// Legato slide into next step
    public var slide: Bool

    public init(
        id: UUID = UUID(),
        stepIndex: Int,
        isActive: Bool = false,
        velocity: Float = 0.8,
        pan: Float = 0.0,
        pitch: Float = 0.0,
        gate: Float = 0.75,
        probability: Float = 1.0,
        slide: Bool = false
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.isActive = isActive
        self.velocity = velocity.clamped(to: 0...1)
        self.pan = pan.clamped(to: -1...1)
        self.pitch = pitch.clamped(to: -24...24)
        self.gate = gate.clamped(to: 0...1)
        self.probability = probability.clamped(to: 0...1)
        self.slide = slide
    }
}

// MARK: - WarpMarker

/// A time-stretch anchor point that maps source audio position to timeline beat position
public struct WarpMarker: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// Position in the source audio file (seconds)
    public var samplePosition: Double
    /// Position on the timeline (beats)
    public var beatPosition: Double

    public init(id: UUID = UUID(), samplePosition: Double, beatPosition: Double) {
        self.id = id
        self.samplePosition = samplePosition
        self.beatPosition = beatPosition
    }
}

// MARK: - ClipType

/// The content type of a session clip
public enum ClipType: String, Codable, CaseIterable, Sendable {
    case audio
    case midi
    case pattern
    case automation
    case video
}

// MARK: - ClipState

/// Playback state of a clip in session view
public enum ClipState: String, Codable, CaseIterable, Sendable {
    case empty
    case stopped
    case queued
    case playing
    case recording
}

// MARK: - ClipColor

/// 16 clip colors matching Ableton Live's palette
public enum ClipColor: Int, Codable, CaseIterable, Sendable {
    case rose = 0
    case red
    case orange
    case amber
    case yellow
    case lime
    case green
    case mint
    case cyan
    case sky
    case blue
    case indigo
    case purple
    case magenta
    case pink
    case sand
}

// MARK: - LaunchMode

/// Determines how a clip responds to launch triggers
public enum LaunchMode: String, Codable, CaseIterable, Sendable {
    /// Fire once on press
    case trigger
    /// Play while held, stop on release
    case gate
    /// Toggle play/stop on each press
    case toggle
    /// Re-trigger from start on each press
    case repeating
}

// MARK: - LaunchQuantize

/// Quantization grid for clip launch timing
public enum LaunchQuantize: String, Codable, CaseIterable, Sendable {
    case none
    case nextBeat
    case nextBar
    case next2Bars
    case next4Bars
    case next8Bars

    /// Number of beats to wait (at 4/4)
    public var beatCount: Double {
        switch self {
        case .none: return 0
        case .nextBeat: return 1
        case .nextBar: return 4
        case .next2Bars: return 8
        case .next4Bars: return 16
        case .next8Bars: return 32
        }
    }
}

// MARK: - FollowActionType

/// What to do after a clip finishes playing
public enum FollowActionType: String, Codable, CaseIterable, Sendable {
    case stop
    case playAgain
    case playPrevious
    case playNext
    case playFirst
    case playLast
    case playRandom
    case playAny
}

// MARK: - FollowAction

/// Ableton-style follow action with A/B probability split
public struct FollowAction: Codable, Equatable, Sendable {
    /// Primary action
    public var action: FollowActionType
    /// Probability of primary action (0.0 to 1.0)
    public var chance: Float
    /// Secondary (linked) action
    public var linkedAction: FollowActionType?
    /// Probability of secondary action (0.0 to 1.0)
    public var linkedChance: Float

    public init(
        action: FollowActionType = .playNext,
        chance: Float = 1.0,
        linkedAction: FollowActionType? = nil,
        linkedChance: Float = 0.0
    ) {
        self.action = action
        self.chance = chance.clamped(to: 0...1)
        self.linkedAction = linkedAction
        self.linkedChance = linkedChance.clamped(to: 0...1)
    }

    /// Resolve which action to execute based on weighted random
    public func resolve() -> FollowActionType {
        let totalWeight = chance + linkedChance
        guard totalWeight > 0 else { return action }
        let roll = Float.random(in: 0..<totalWeight)
        if roll < chance {
            return action
        }
        return linkedAction ?? action
    }
}

// MARK: - WarpMode

/// Time-stretching algorithm (Ableton-style)
public enum WarpMode: String, Codable, CaseIterable, Sendable {
    /// No warping, original speed
    case off
    /// Best for rhythmic material
    case beats
    /// Best for melodic/tonal material
    case tones
    /// Best for atmospheric/textural material
    case texture
    /// Simple repitch (speeds up/slows down)
    case rePitch
    /// High-quality general purpose
    case complex
    /// Highest quality, most CPU
    case complexPro
}

// MARK: - SessionClip

/// A launchable clip in session view, combining Ableton clips with FL Studio patterns
public struct SessionClip: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var type: ClipType
    public var state: ClipState
    public var color: ClipColor

    // MARK: Timing

    /// Length of the clip in seconds
    public var length: TimeInterval
    /// Whether the clip loops
    public var loopEnabled: Bool

    // MARK: Launch Behavior

    /// How the clip responds to triggers
    public var launchMode: LaunchMode
    /// Quantization for launch timing
    public var quantization: LaunchQuantize

    // MARK: Follow Actions

    /// Optional follow action when clip finishes
    public var followAction: FollowAction?
    /// Time after which follow action fires (seconds)
    public var followActionTime: TimeInterval

    // MARK: Warping

    /// Time-stretch algorithm
    public var warpMode: WarpMode
    /// Warp markers for audio alignment
    public var warpMarkers: [WarpMarker]
    /// Playback speed multiplier (0.5x to 2.0x)
    public var playbackSpeed: Double

    // MARK: Offsets

    /// Start offset within the clip (seconds)
    public var startOffset: TimeInterval
    /// End offset within the clip (seconds)
    public var endOffset: TimeInterval

    // MARK: Audio-specific

    /// URL of the audio file
    public var audioURL: URL?
    /// Gain in decibels
    public var gain: Float

    // MARK: MIDI-specific

    /// MIDI note events
    public var midiNotes: [MIDINoteEvent]

    // MARK: Pattern-specific (FL Studio)

    /// Step sequencer pattern
    public var patternSteps: [PatternStep]

    public init(
        id: UUID = UUID(),
        name: String = "Clip",
        type: ClipType = .midi,
        state: ClipState = .stopped,
        color: ClipColor = .blue,
        length: TimeInterval = 4.0,
        loopEnabled: Bool = true,
        launchMode: LaunchMode = .trigger,
        quantization: LaunchQuantize = .nextBar,
        followAction: FollowAction? = nil,
        followActionTime: TimeInterval = 4.0,
        warpMode: WarpMode = .off,
        warpMarkers: [WarpMarker] = [],
        playbackSpeed: Double = 1.0,
        startOffset: TimeInterval = 0.0,
        endOffset: TimeInterval = 0.0,
        audioURL: URL? = nil,
        gain: Float = 0.0,
        midiNotes: [MIDINoteEvent] = [],
        patternSteps: [PatternStep] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.color = color
        self.length = length
        self.loopEnabled = loopEnabled
        self.launchMode = launchMode
        self.quantization = quantization
        self.followAction = followAction
        self.followActionTime = followActionTime
        self.warpMode = warpMode
        self.warpMarkers = warpMarkers
        self.playbackSpeed = playbackSpeed.clamped(to: 0.5...2.0)
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.audioURL = audioURL
        self.gain = gain
        self.midiNotes = midiNotes
        self.patternSteps = patternSteps
    }

    public static func == (lhs: SessionClip, rhs: SessionClip) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.state == rhs.state &&
        lhs.color == rhs.color &&
        lhs.length == rhs.length &&
        lhs.loopEnabled == rhs.loopEnabled &&
        lhs.launchMode == rhs.launchMode &&
        lhs.quantization == rhs.quantization &&
        lhs.followAction == rhs.followAction &&
        lhs.followActionTime == rhs.followActionTime &&
        lhs.warpMode == rhs.warpMode &&
        lhs.warpMarkers == rhs.warpMarkers &&
        lhs.playbackSpeed == rhs.playbackSpeed &&
        lhs.startOffset == rhs.startOffset &&
        lhs.endOffset == rhs.endOffset &&
        lhs.audioURL == rhs.audioURL &&
        lhs.gain == rhs.gain &&
        lhs.midiNotes == rhs.midiNotes &&
        lhs.patternSteps == rhs.patternSteps
    }
}

// MARK: - SessionTrackType

/// The kind of session track (Reaper-style: any track can be anything)
public enum SessionTrackType: String, Codable, CaseIterable, Sendable {
    case audio
    case midi
    case instrument
    case returnBus
    case master
}

// MARK: - TrackColor

/// Track header color
public typealias TrackColor = ClipColor

// MARK: - SceneColor

/// Scene trigger color
public typealias SceneColor = ClipColor

// MARK: - SessionMonitorMode

/// Input monitoring mode
public enum SessionMonitorMode: String, Codable, CaseIterable, Sendable {
    /// Monitor only when track is armed and not playing
    case auto
    /// Always monitor input
    case always
    /// Never monitor input
    case off
}

// MARK: - TrackInput

/// Input routing source for a track
public enum TrackInput: Codable, Equatable, Sendable {
    /// No input
    case none
    /// External hardware input by index
    case extInput(index: Int)
    /// Resample master output
    case resampling
    /// Receive from another track's output (Reaper-style flexible routing)
    case trackOutput(UUID)
}

// MARK: - CrossfadeAssign

/// Crossfader assignment for DJ-style mixing
public enum CrossfadeAssign: String, Codable, CaseIterable, Sendable {
    case a
    case none
    case b
}

// MARK: - SessionTrackSend

/// A send from one track to a return/bus track
public struct SessionTrackSend: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// Destination return track
    public var returnTrackID: UUID
    /// Send level (0.0 to 1.0)
    public var level: Float
    /// Whether the send is pre-fader (true) or post-fader (false)
    public var isPreFader: Bool

    public init(
        id: UUID = UUID(),
        returnTrackID: UUID,
        level: Float = 0.0,
        isPreFader: Bool = false
    ) {
        self.id = id
        self.returnTrackID = returnTrackID
        self.level = level.clamped(to: 0...1)
        self.isPreFader = isPreFader
    }
}

// MARK: - SessionTrack

/// A track in the session view with clips, routing, and mixing
public struct SessionTrack: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var color: TrackColor

    /// Clip slots indexed by scene. nil means the slot is empty.
    public var clips: [SessionClip?]

    /// Track type (audio, midi, instrument, return, master)
    public var type: SessionTrackType

    // MARK: Recording

    /// Whether the track is armed for recording
    public var isArmed: Bool
    /// Input monitoring mode
    public var monitorMode: SessionMonitorMode

    // MARK: Mixer

    /// Volume (0.0 to 1.0)
    public var volume: Float
    /// Pan (-1.0 left to 1.0 right)
    public var pan: Float
    /// Mute state
    public var mute: Bool
    /// Solo state
    public var solo: Bool

    // MARK: Routing (Reaper-style flexibility)

    /// Input routing source
    public var inputRouting: TrackInput
    /// Output routing destination (nil = master)
    public var outputRouting: UUID?
    /// Sends to return tracks
    public var sends: [SessionTrackSend]

    // MARK: Session View Controls

    /// Whether the track stop button is active (stops all clips on this track)
    public var stopButton: Bool

    /// DJ crossfader assignment
    public var crossfadeAssign: CrossfadeAssign

    public init(
        id: UUID = UUID(),
        name: String = "Track",
        color: TrackColor = .blue,
        clips: [SessionClip?] = [],
        type: SessionTrackType = .audio,
        isArmed: Bool = false,
        monitorMode: SessionMonitorMode = .auto,
        volume: Float = 0.85,
        pan: Float = 0.0,
        mute: Bool = false,
        solo: Bool = false,
        inputRouting: TrackInput = .none,
        outputRouting: UUID? = nil,
        sends: [SessionTrackSend] = [],
        stopButton: Bool = true,
        crossfadeAssign: CrossfadeAssign = .none
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.clips = clips
        self.type = type
        self.isArmed = isArmed
        self.monitorMode = monitorMode
        self.volume = volume.clamped(to: 0...1)
        self.pan = pan.clamped(to: -1...1)
        self.mute = mute
        self.solo = solo
        self.inputRouting = inputRouting
        self.outputRouting = outputRouting
        self.sends = sends
        self.stopButton = stopButton
        self.crossfadeAssign = crossfadeAssign
    }

    /// Ensure the track has enough clip slots for the given scene count
    public mutating func ensureSlots(count: Int) {
        while clips.count < count {
            clips.append(nil)
        }
    }

    public static func == (lhs: SessionTrack, rhs: SessionTrack) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.color == rhs.color &&
        lhs.clips == rhs.clips &&
        lhs.type == rhs.type &&
        lhs.isArmed == rhs.isArmed &&
        lhs.monitorMode == rhs.monitorMode &&
        lhs.volume == rhs.volume &&
        lhs.pan == rhs.pan &&
        lhs.mute == rhs.mute &&
        lhs.solo == rhs.solo &&
        lhs.inputRouting == rhs.inputRouting &&
        lhs.outputRouting == rhs.outputRouting &&
        lhs.sends == rhs.sends &&
        lhs.stopButton == rhs.stopButton &&
        lhs.crossfadeAssign == rhs.crossfadeAssign
    }
}

// MARK: - SessionScene

/// A horizontal row of clips across all tracks (Ableton Scene)
public struct SessionScene: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    /// Scene number (1-based display index)
    public var number: Int
    /// Optional tempo change when this scene launches
    public var tempo: Double?
    /// Optional time signature change (e.g. "4/4", "7/8")
    public var timeSignature: String?
    /// Scene trigger button color
    public var color: SceneColor

    public init(
        id: UUID = UUID(),
        name: String = "Scene",
        number: Int = 1,
        tempo: Double? = nil,
        timeSignature: String? = nil,
        color: SceneColor = .amber
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.color = color
    }

    public static func == (lhs: SessionScene, rhs: SessionScene) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.number == rhs.number &&
        lhs.tempo == rhs.tempo &&
        lhs.timeSignature == rhs.timeSignature &&
        lhs.color == rhs.color
    }
}

// MARK: - ProSessionEngine

/// Professional session/clip engine combining the best of
/// Ableton Live (Session View, clip launching, follow actions),
/// FL Studio (pattern step sequencer, channel rack),
/// and Reaper (flexible routing, any-track-to-any-track sends).
///
/// Manages tracks, scenes, clip launching with quantization,
/// DJ crossfader, tap tempo, and pattern editing.
@MainActor
public class ProSessionEngine: ObservableObject {

    // MARK: - Published Properties

    /// All session tracks (columns in session view)
    @Published public var tracks: [SessionTrack] = []

    /// All scenes (rows in session view)
    @Published public var scenes: [SessionScene] = []

    /// Return / bus tracks (e.g. Reverb, Delay sends)
    @Published public var returnTracks: [SessionTrack] = []

    /// The master track
    @Published public var masterTrack: SessionTrack

    /// Global session tempo in BPM
    @Published public var globalBPM: Double = 120.0

    /// Whether the transport is playing
    @Published public var isPlaying: Bool = false

    /// Current playback position in beats
    @Published public var currentBeat: Double = 0.0

    /// DJ crossfader position (-1.0 = A, 0 = center, 1.0 = B)
    @Published public var crossfaderPosition: Float = 0.0

    /// Whether the metronome click is audible
    @Published public var metronomeEnabled: Bool = false

    /// Quantization applied to recorded clips
    @Published public var recordQuantization: LaunchQuantize = .nextBeat

    /// Global quantization for clip launching
    @Published public var clipLaunchQuantize: LaunchQuantize = .nextBar

    /// Default recording length in bars
    @Published public var loopLength: Int = 4

    // MARK: - Private Properties

    private let log = ProfessionalLogger.shared
    private var cancellables = Set<AnyCancellable>()
    private var transportTimer: Timer?
    private var tapTempoTimestamps: [Date] = []

    /// Queued clip launches waiting for the next quantize boundary
    private var pendingLaunches: [(trackIndex: Int, sceneIndex: Int, atBeat: Double)] = []

    /// Queued clip stops waiting for the next quantize boundary
    private var pendingStops: [(trackIndex: Int, sceneIndex: Int, atBeat: Double)] = []

    // MARK: - Initialization

    public init() {
        self.masterTrack = SessionTrack(
            name: "Master",
            color: ClipColor.sand,
            type: SessionTrackType.master,
            volume: 1.0
        )
        log.info("ProSessionEngine initialized", category: .audio)
    }

    // MARK: - Transport

    /// Start the session transport
    public func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startTransportTimer()
        log.info("Transport started at \(globalBPM) BPM", category: .audio)
    }

    /// Stop the session transport and reset position
    public func stop() {
        isPlaying = false
        stopTransportTimer()
        currentBeat = 0.0
        pendingLaunches.removeAll()
        pendingStops.removeAll()
        log.info("Transport stopped", category: .audio)
    }

    /// Pause the transport without resetting position
    public func pause() {
        isPlaying = false
        stopTransportTimer()
        log.info("Transport paused at beat \(currentBeat)", category: .audio)
    }

    private func startTransportTimer() {
        stopTransportTimer()
        // Tick at ~240 Hz for tight timing resolution
        let tickInterval: TimeInterval = 1.0 / 240.0
        transportTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.transportTick(tickInterval)
            }
        }
    }

    private func stopTransportTimer() {
        transportTimer?.invalidate()
        transportTimer = nil
    }

    /// Advance the transport by one tick and process queued events
    private func transportTick(_ deltaTime: TimeInterval) {
        guard isPlaying else { return }

        let beatsPerSecond = globalBPM / 60.0
        let previousBeat = currentBeat
        currentBeat += beatsPerSecond * deltaTime

        // Process pending launches
        processPendingLaunches(previousBeat: previousBeat, currentBeat: currentBeat)

        // Process pending stops
        processPendingStops(previousBeat: previousBeat, currentBeat: currentBeat)

        // Process follow actions
        processFollowActions()
    }

    private func processPendingLaunches(previousBeat: Double, currentBeat: Double) {
        let readyLaunches = pendingLaunches.filter { $0.atBeat <= currentBeat && $0.atBeat > previousBeat }
        for launch in readyLaunches {
            executeLaunch(trackIndex: launch.trackIndex, sceneIndex: launch.sceneIndex)
        }
        pendingLaunches.removeAll { $0.atBeat <= currentBeat }
    }

    private func processPendingStops(previousBeat: Double, currentBeat: Double) {
        let readyStops = pendingStops.filter { $0.atBeat <= currentBeat && $0.atBeat > previousBeat }
        for stopEvent in readyStops {
            executeStop(trackIndex: stopEvent.trackIndex, sceneIndex: stopEvent.sceneIndex)
        }
        pendingStops.removeAll { $0.atBeat <= currentBeat }
    }

    private func processFollowActions() {
        for trackIndex in tracks.indices {
            for sceneIndex in tracks[trackIndex].clips.indices {
                guard var clip = tracks[trackIndex].clips[sceneIndex],
                      clip.state == ClipState.playing,
                      let followAction = clip.followAction else { continue }

                // Check if follow action time has elapsed
                let clipBeatsLength = clip.length * (globalBPM / 60.0)
                let followBeats = followAction.action == .stop ? clipBeatsLength : clip.followActionTime * (globalBPM / 60.0)

                // Simplified: check on loop boundaries
                if clip.loopEnabled && followBeats > 0 {
                    let resolvedAction = followAction.resolve()
                    executeFollowAction(resolvedAction, trackIndex: trackIndex, currentScene: sceneIndex)
                }
            }
        }
    }

    private func executeFollowAction(_ action: FollowActionType, trackIndex: Int, currentScene: Int) {
        switch action {
        case .stop:
            executeStop(trackIndex: trackIndex, sceneIndex: currentScene)
        case .playAgain:
            executeLaunch(trackIndex: trackIndex, sceneIndex: currentScene)
        case .playNext:
            let nextScene = currentScene + 1
            if nextScene < scenes.count {
                executeLaunch(trackIndex: trackIndex, sceneIndex: nextScene)
            }
        case .playPrevious:
            let prevScene = currentScene - 1
            if prevScene >= 0 {
                executeLaunch(trackIndex: trackIndex, sceneIndex: prevScene)
            }
        case .playFirst:
            if !scenes.isEmpty {
                executeLaunch(trackIndex: trackIndex, sceneIndex: 0)
            }
        case .playLast:
            let lastScene = scenes.count - 1
            if lastScene >= 0 {
                executeLaunch(trackIndex: trackIndex, sceneIndex: lastScene)
            }
        case .playRandom:
            if !scenes.isEmpty {
                let randomScene = Int.random(in: 0..<scenes.count)
                executeLaunch(trackIndex: trackIndex, sceneIndex: randomScene)
            }
        case .playAny:
            // Play any non-empty clip slot on this track
            let nonEmptySlots = tracks[trackIndex].clips.indices.filter {
                tracks[trackIndex].clips[$0] != nil
            }
            if let slot = nonEmptySlots.randomElement() {
                executeLaunch(trackIndex: trackIndex, sceneIndex: slot)
            }
        }
    }

    // MARK: - Clip Launching

    /// Launch a single clip at the given track and scene index.
    /// The clip is queued and will fire at the next quantization boundary.
    public func launchClip(trackIndex: Int, sceneIndex: Int) {
        guard trackIndex < tracks.count else {
            log.warning("launchClip: trackIndex \(trackIndex) out of range", category: .audio)
            return
        }
        tracks[trackIndex].ensureSlots(count: sceneIndex + 1)
        guard tracks[trackIndex].clips[sceneIndex] != nil else {
            log.warning("launchClip: empty slot at [\(trackIndex)][\(sceneIndex)]", category: .audio)
            return
        }

        let quantize = tracks[trackIndex].clips[sceneIndex]?.quantization ?? clipLaunchQuantize
        if quantize == LaunchQuantize.none || !isPlaying {
            executeLaunch(trackIndex: trackIndex, sceneIndex: sceneIndex)
        } else {
            // Queue for next quantize boundary
            let nextBoundary = nextQuantizeBeat(for: quantize)
            tracks[trackIndex].clips[sceneIndex]?.state = ClipState.queued
            pendingLaunches.append((trackIndex: trackIndex, sceneIndex: sceneIndex, atBeat: nextBoundary))
            log.info("Clip queued: \(tracks[trackIndex].clips[sceneIndex]?.name ?? "?") at beat \(nextBoundary)", category: .audio)
        }
    }

    /// Launch all clips in a scene row (Ableton-style scene launch)
    public func launchScene(sceneIndex: Int) {
        guard sceneIndex < scenes.count else {
            log.warning("launchScene: sceneIndex \(sceneIndex) out of range", category: .audio)
            return
        }

        // Apply scene tempo if set
        if let sceneTempo = scenes[sceneIndex].tempo {
            globalBPM = sceneTempo
        }

        for trackIndex in tracks.indices {
            tracks[trackIndex].ensureSlots(count: sceneIndex + 1)
            if tracks[trackIndex].clips[sceneIndex] != nil {
                launchClip(trackIndex: trackIndex, sceneIndex: sceneIndex)
            }
        }
        log.info("Scene launched: \(scenes[sceneIndex].name)", category: .audio)
    }

    /// Stop a specific clip
    public func stopClip(trackIndex: Int, sceneIndex: Int) {
        guard trackIndex < tracks.count,
              sceneIndex < tracks[trackIndex].clips.count,
              tracks[trackIndex].clips[sceneIndex] != nil else { return }

        let quantize = clipLaunchQuantize
        if quantize == LaunchQuantize.none || !isPlaying {
            executeStop(trackIndex: trackIndex, sceneIndex: sceneIndex)
        } else {
            let nextBoundary = nextQuantizeBeat(for: quantize)
            pendingStops.append((trackIndex: trackIndex, sceneIndex: sceneIndex, atBeat: nextBoundary))
        }
    }

    /// Stop all clips on a track
    public func stopTrack(trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        for sceneIndex in tracks[trackIndex].clips.indices {
            if tracks[trackIndex].clips[sceneIndex]?.state == ClipState.playing ||
               tracks[trackIndex].clips[sceneIndex]?.state == ClipState.queued {
                stopClip(trackIndex: trackIndex, sceneIndex: sceneIndex)
            }
        }
        log.info("Track stopped: \(tracks[trackIndex].name)", category: .audio)
    }

    /// Panic: stop every clip on every track immediately
    public func stopAllClips() {
        pendingLaunches.removeAll()
        pendingStops.removeAll()
        for trackIndex in tracks.indices {
            for sceneIndex in tracks[trackIndex].clips.indices {
                if tracks[trackIndex].clips[sceneIndex] != nil {
                    tracks[trackIndex].clips[sceneIndex]?.state = ClipState.stopped
                }
            }
        }
        log.info("All clips stopped (panic)", category: .audio)
    }

    // MARK: - Internal Launch/Stop Execution

    private func executeLaunch(trackIndex: Int, sceneIndex: Int) {
        guard trackIndex < tracks.count,
              sceneIndex < tracks[trackIndex].clips.count,
              tracks[trackIndex].clips[sceneIndex] != nil else { return }

        // Stop any other playing clip on this track (exclusive)
        for i in tracks[trackIndex].clips.indices {
            if i != sceneIndex, tracks[trackIndex].clips[i]?.state == ClipState.playing {
                tracks[trackIndex].clips[i]?.state = ClipState.stopped
            }
        }

        tracks[trackIndex].clips[sceneIndex]?.state = ClipState.playing
        log.info("Clip playing: \(tracks[trackIndex].clips[sceneIndex]?.name ?? "?")", category: .audio)
    }

    private func executeStop(trackIndex: Int, sceneIndex: Int) {
        guard trackIndex < tracks.count,
              sceneIndex < tracks[trackIndex].clips.count else { return }
        tracks[trackIndex].clips[sceneIndex]?.state = ClipState.stopped
    }

    /// Calculate the next beat boundary for a given quantization
    private func nextQuantizeBeat(for quantize: LaunchQuantize) -> Double {
        let gridBeats = quantize.beatCount
        guard gridBeats > 0 else { return currentBeat }
        let nextBoundary = (floor(currentBeat / gridBeats) + 1.0) * gridBeats
        return nextBoundary
    }

    // MARK: - Track Management

    /// Add a new track to the session
    @discardableResult
    public func addTrack(type: SessionTrackType, name: String) -> SessionTrack {
        var track = SessionTrack(
            name: name,
            type: type
        )
        // Pre-fill clip slots to match scene count
        track.ensureSlots(count: scenes.count)

        // Auto-assign sends for each return track
        for returnTrack in returnTracks {
            track.sends.append(SessionTrackSend(returnTrackID: returnTrack.id, level: 0.0))
        }

        tracks.append(track)
        log.info("Track added: \(name) (\(type.rawValue))", category: .audio)
        return track
    }

    /// Add a new scene row
    @discardableResult
    public func addScene(name: String) -> SessionScene {
        let sceneNumber = scenes.count + 1
        let scene = SessionScene(
            name: name.isEmpty ? "Scene \(sceneNumber)" : name,
            number: sceneNumber
        )
        scenes.append(scene)

        // Ensure all tracks have enough clip slots
        for i in tracks.indices {
            tracks[i].ensureSlots(count: scenes.count)
        }
        for i in returnTracks.indices {
            returnTracks[i].ensureSlots(count: scenes.count)
        }

        log.info("Scene added: \(scene.name)", category: .audio)
        return scene
    }

    /// Add a return/bus track (e.g. Reverb, Delay)
    @discardableResult
    public func addReturnTrack(name: String) -> SessionTrack {
        var returnTrack = SessionTrack(
            name: name,
            color: TrackColor.purple,
            type: SessionTrackType.returnBus,
            volume: 0.7
        )
        returnTrack.ensureSlots(count: scenes.count)
        returnTracks.append(returnTrack)

        // Add a default send to all existing tracks pointing at this return
        for i in tracks.indices {
            tracks[i].sends.append(SessionTrackSend(returnTrackID: returnTrack.id, level: 0.0))
        }

        log.info("Return track added: \(name)", category: .audio)
        return returnTrack
    }

    // MARK: - Clip Operations

    /// Duplicate a clip from one slot to another
    public func duplicateClip(from source: (trackIndex: Int, sceneIndex: Int),
                              to destination: (trackIndex: Int, sceneIndex: Int)) {
        guard source.trackIndex < tracks.count,
              source.sceneIndex < tracks[source.trackIndex].clips.count,
              let sourceClip = tracks[source.trackIndex].clips[source.sceneIndex] else {
            log.warning("duplicateClip: source slot is empty or out of range", category: .audio)
            return
        }
        guard destination.trackIndex < tracks.count else {
            log.warning("duplicateClip: destination track out of range", category: .audio)
            return
        }

        tracks[destination.trackIndex].ensureSlots(count: destination.sceneIndex + 1)

        var newClip = sourceClip
        newClip = SessionClip(
            id: UUID(),
            name: sourceClip.name + " (copy)",
            type: sourceClip.type,
            state: ClipState.stopped,
            color: sourceClip.color,
            length: sourceClip.length,
            loopEnabled: sourceClip.loopEnabled,
            launchMode: sourceClip.launchMode,
            quantization: sourceClip.quantization,
            followAction: sourceClip.followAction,
            followActionTime: sourceClip.followActionTime,
            warpMode: sourceClip.warpMode,
            warpMarkers: sourceClip.warpMarkers,
            playbackSpeed: sourceClip.playbackSpeed,
            startOffset: sourceClip.startOffset,
            endOffset: sourceClip.endOffset,
            audioURL: sourceClip.audioURL,
            gain: sourceClip.gain,
            midiNotes: sourceClip.midiNotes,
            patternSteps: sourceClip.patternSteps
        )
        tracks[destination.trackIndex].clips[destination.sceneIndex] = newClip
        log.info("Clip duplicated: \(sourceClip.name) -> [\(destination.trackIndex)][\(destination.sceneIndex)]", category: .audio)
    }

    /// Arm recording into a specific clip slot
    public func recordClip(trackIndex: Int, sceneIndex: Int) {
        guard trackIndex < tracks.count else {
            log.warning("recordClip: trackIndex out of range", category: .audio)
            return
        }

        tracks[trackIndex].ensureSlots(count: sceneIndex + 1)
        tracks[trackIndex].isArmed = true

        let recordLength = Double(loopLength) * 4.0 * (60.0 / globalBPM)
        let clipType: ClipType = tracks[trackIndex].type == SessionTrackType.audio ? ClipType.audio : ClipType.midi

        let newClip = SessionClip(
            name: "\(tracks[trackIndex].name) Rec \(sceneIndex + 1)",
            type: clipType,
            state: ClipState.recording,
            color: ClipColor.red,
            length: recordLength,
            loopEnabled: true,
            quantization: recordQuantization
        )
        tracks[trackIndex].clips[sceneIndex] = newClip
        log.info("Recording armed: [\(trackIndex)][\(sceneIndex)] for \(loopLength) bars", category: .audio)
    }

    /// Capture the current playing state as a new scene
    @discardableResult
    public func captureScene() -> SessionScene {
        let scene = addScene(name: "Captured \(scenes.count)")

        let newSceneIndex = scenes.count - 1
        for trackIndex in tracks.indices {
            // Find the currently playing clip on this track
            let playingClip = tracks[trackIndex].clips.first(where: { $0?.state == ClipState.playing })
            if let clip = playingClip, let unwrapped = clip {
                tracks[trackIndex].ensureSlots(count: newSceneIndex + 1)
                var captured = unwrapped
                // Give the captured clip a new ID and reset state
                captured = SessionClip(
                    id: UUID(),
                    name: unwrapped.name,
                    type: unwrapped.type,
                    state: ClipState.stopped,
                    color: unwrapped.color,
                    length: unwrapped.length,
                    loopEnabled: unwrapped.loopEnabled,
                    launchMode: unwrapped.launchMode,
                    quantization: unwrapped.quantization,
                    followAction: unwrapped.followAction,
                    followActionTime: unwrapped.followActionTime,
                    warpMode: unwrapped.warpMode,
                    warpMarkers: unwrapped.warpMarkers,
                    playbackSpeed: unwrapped.playbackSpeed,
                    startOffset: unwrapped.startOffset,
                    endOffset: unwrapped.endOffset,
                    audioURL: unwrapped.audioURL,
                    gain: unwrapped.gain,
                    midiNotes: unwrapped.midiNotes,
                    patternSteps: unwrapped.patternSteps
                )
                tracks[trackIndex].clips[newSceneIndex] = captured
            }
        }
        log.info("Scene captured with \(tracks.count) tracks", category: .audio)
        return scene
    }

    // MARK: - DJ Crossfader

    /// Set the DJ crossfader position
    /// - Parameter position: -1.0 (full A) to 1.0 (full B)
    public func setCrossfader(position: Float) {
        crossfaderPosition = position.clamped(to: -1...1)

        // Apply crossfade volumes to assigned tracks
        let aMix = max(0.0, 1.0 - max(0.0, crossfaderPosition))
        let bMix = max(0.0, 1.0 + min(0.0, crossfaderPosition))

        for i in tracks.indices {
            switch tracks[i].crossfadeAssign {
            case .a:
                tracks[i].volume = aMix
            case .b:
                tracks[i].volume = bMix
            case .none:
                break
            }
        }
    }

    // MARK: - Tempo

    /// Tap tempo detection. Call repeatedly to set BPM from tap rhythm.
    public func tapTempo() {
        let now = Date()
        tapTempoTimestamps.append(now)

        // Keep only the last 8 taps
        if tapTempoTimestamps.count > 8 {
            tapTempoTimestamps.removeFirst(tapTempoTimestamps.count - 8)
        }

        guard tapTempoTimestamps.count >= 2 else { return }

        // Calculate average interval between taps
        var totalInterval: TimeInterval = 0
        for i in 1..<tapTempoTimestamps.count {
            totalInterval += tapTempoTimestamps[i].timeIntervalSince(tapTempoTimestamps[i - 1])
        }
        let averageInterval = totalInterval / Double(tapTempoTimestamps.count - 1)

        guard averageInterval > 0 else { return }
        let detectedBPM = 60.0 / averageInterval
        globalBPM = detectedBPM.clamped(to: 20...300)
        log.info("Tap tempo: \(String(format: "%.1f", globalBPM)) BPM", category: .audio)
    }

    /// Nudge the global tempo up or down
    /// - Parameter amount: BPM change (positive = faster, negative = slower)
    public func nudgeTempo(amount: Double) {
        globalBPM = (globalBPM + amount).clamped(to: 20...300)
    }

    // MARK: - Pattern (FL Studio Style)

    /// Create a new pattern clip with the specified number of steps
    /// - Parameters:
    ///   - name: Pattern name
    ///   - steps: Number of steps (default 16, max 64)
    /// - Returns: A new pattern clip
    public func createPattern(name: String, steps: Int = 16) -> SessionClip {
        let stepCount = min(max(1, steps), 64)
        let patternSteps = (0..<stepCount).map { PatternStep(stepIndex: $0) }
        let beatsLength = Double(stepCount) / 4.0
        let lengthSeconds = beatsLength * (60.0 / globalBPM)

        let clip = SessionClip(
            name: name,
            type: ClipType.pattern,
            state: ClipState.stopped,
            color: ClipColor.orange,
            length: lengthSeconds,
            loopEnabled: true,
            patternSteps: patternSteps
        )
        log.info("Pattern created: \(name) (\(stepCount) steps)", category: .audio)
        return clip
    }

    /// Toggle a step on/off in a pattern clip
    public func toggleStep(clipID: UUID, step: Int) {
        guard let (trackIndex, sceneIndex) = findClip(by: clipID) else {
            log.warning("toggleStep: clip \(clipID) not found", category: .audio)
            return
        }
        guard var clip = tracks[trackIndex].clips[sceneIndex],
              step >= 0, step < clip.patternSteps.count else { return }

        clip.patternSteps[step].isActive.toggle()
        tracks[trackIndex].clips[sceneIndex] = clip
    }

    /// Set the velocity of a specific step in a pattern clip
    public func setStepVelocity(clipID: UUID, step: Int, velocity: Float) {
        guard let (trackIndex, sceneIndex) = findClip(by: clipID) else {
            log.warning("setStepVelocity: clip \(clipID) not found", category: .audio)
            return
        }
        guard var clip = tracks[trackIndex].clips[sceneIndex],
              step >= 0, step < clip.patternSteps.count else { return }

        clip.patternSteps[step].velocity = velocity.clamped(to: 0...1)
        tracks[trackIndex].clips[sceneIndex] = clip
    }

    /// Randomize a pattern with a given density (probability of each step being active)
    /// - Parameters:
    ///   - clipID: The clip to randomize
    ///   - density: Probability of each step being active (0.0 to 1.0)
    public func randomizePattern(clipID: UUID, density: Float = 0.5) {
        guard let (trackIndex, sceneIndex) = findClip(by: clipID) else {
            log.warning("randomizePattern: clip \(clipID) not found", category: .audio)
            return
        }
        guard var clip = tracks[trackIndex].clips[sceneIndex] else { return }

        let clampedDensity = density.clamped(to: 0...1)
        for i in clip.patternSteps.indices {
            clip.patternSteps[i].isActive = Float.random(in: 0...1) < clampedDensity
            clip.patternSteps[i].velocity = Float.random(in: 0.5...1.0)
            clip.patternSteps[i].probability = Float.random(in: 0.7...1.0)
        }
        tracks[trackIndex].clips[sceneIndex] = clip
        log.info("Pattern randomized: density \(clampedDensity)", category: .audio)
    }

    // MARK: - Clip Lookup

    /// Find a clip's location by its UUID
    private func findClip(by id: UUID) -> (trackIndex: Int, sceneIndex: Int)? {
        for trackIndex in tracks.indices {
            for sceneIndex in tracks[trackIndex].clips.indices {
                if tracks[trackIndex].clips[sceneIndex]?.id == id {
                    return (trackIndex, sceneIndex)
                }
            }
        }
        return nil
    }

    // MARK: - Static Factory Methods

    /// Create a default session with 8 tracks, 2 return tracks, and 8 scenes
    public static func defaultSession() -> ProSessionEngine {
        let engine = ProSessionEngine()

        // Return tracks
        let reverbReturn = engine.addReturnTrack(name: "A - Reverb")
        let delayReturn = engine.addReturnTrack(name: "B - Delay")

        // 8 scenes
        for i in 1...8 {
            engine.addScene(name: "Scene \(i)")
        }

        // 8 tracks with varied types
        let trackConfigs: [(SessionTrackType, String, TrackColor)] = [
            (.audio, "1 - Drums", .orange),
            (.audio, "2 - Bass", .blue),
            (.midi, "3 - Synth Lead", .green),
            (.midi, "4 - Synth Pad", .cyan),
            (.instrument, "5 - Keys", .purple),
            (.instrument, "6 - Strings", .magenta),
            (.audio, "7 - Vocals", .yellow),
            (.audio, "8 - FX", .red),
        ]

        for (type, name, color) in trackConfigs {
            var track = engine.addTrack(type: type, name: name)
            // Update color after creation
            if let idx = engine.tracks.firstIndex(where: { $0.id == track.id }) {
                engine.tracks[idx].color = color
                // Set default send levels
                for sendIdx in engine.tracks[idx].sends.indices {
                    if engine.tracks[idx].sends[sendIdx].returnTrackID == reverbReturn.id {
                        engine.tracks[idx].sends[sendIdx].level = 0.2
                    }
                    if engine.tracks[idx].sends[sendIdx].returnTrackID == delayReturn.id {
                        engine.tracks[idx].sends[sendIdx].level = 0.1
                    }
                }
            }
        }

        engine.log.info("Default session created: 8 tracks, 2 returns, 8 scenes", category: .audio)
        return engine
    }

    /// Create a DJ session with 2 decks, crossfader, and effects returns
    public static func djSession() -> ProSessionEngine {
        let engine = ProSessionEngine()
        engine.globalBPM = 128.0

        // Returns
        _ = engine.addReturnTrack(name: "FX 1 - Filter")
        _ = engine.addReturnTrack(name: "FX 2 - Echo")

        // 8 scenes for pre-loaded tracks
        for i in 1...8 {
            engine.addScene(name: "Deck \(i)")
        }

        // Deck A
        var deckA = engine.addTrack(type: SessionTrackType.audio, name: "Deck A")
        if let idx = engine.tracks.firstIndex(where: { $0.id == deckA.id }) {
            engine.tracks[idx].color = TrackColor.cyan
            engine.tracks[idx].crossfadeAssign = CrossfadeAssign.a
        }

        // Deck B
        var deckB = engine.addTrack(type: SessionTrackType.audio, name: "Deck B")
        if let idx = engine.tracks.firstIndex(where: { $0.id == deckB.id }) {
            engine.tracks[idx].color = TrackColor.magenta
            engine.tracks[idx].crossfadeAssign = CrossfadeAssign.b
        }

        engine.crossfaderPosition = 0.0
        engine.metronomeEnabled = false

        engine.log.info("DJ session created: 2 decks, crossfader, 2 FX returns", category: .audio)
        return engine
    }

    /// Create a live performance session with instruments, clips, and bio-reactive mapping
    public static func livePerformance() -> ProSessionEngine {
        let engine = ProSessionEngine()
        engine.globalBPM = 100.0

        // Returns
        _ = engine.addReturnTrack(name: "A - Space Reverb")
        _ = engine.addReturnTrack(name: "B - Tape Delay")

        // 8 scenes
        let sceneNames = [
            "Intro", "Build", "Drop", "Breakdown",
            "Variation", "Climax", "Outro", "Ambient"
        ]
        for name in sceneNames {
            engine.addScene(name: name)
        }

        // Instrument tracks
        let trackConfigs: [(SessionTrackType, String, TrackColor)] = [
            (.instrument, "Bio Synth", .green),
            (.instrument, "Pad Layer", .cyan),
            (.midi, "Arpeggio", .purple),
            (.audio, "Drums", .orange),
            (.audio, "Bass", .blue),
            (.instrument, "Lead", .magenta),
        ]

        for (type, name, color) in trackConfigs {
            let track = engine.addTrack(type: type, name: name)
            if let idx = engine.tracks.firstIndex(where: { $0.id == track.id }) {
                engine.tracks[idx].color = color
                engine.tracks[idx].monitorMode = type == SessionTrackType.instrument ? SessionMonitorMode.always : SessionMonitorMode.auto
            }
        }

        // Pre-fill the Drums track with a pattern in scene 0
        if let drumsIdx = engine.tracks.firstIndex(where: { $0.name == "Drums" }) {
            var pattern = engine.createPattern(name: "4/4 Beat", steps: 16)
            // Kick on 1, 5, 9, 13
            for step in [0, 4, 8, 12] {
                pattern.patternSteps[step].isActive = true
                pattern.patternSteps[step].velocity = 1.0
            }
            // Hi-hat on even steps
            for step in stride(from: 2, to: 16, by: 2) {
                pattern.patternSteps[step].isActive = true
                pattern.patternSteps[step].velocity = 0.6
            }
            engine.tracks[drumsIdx].clips[0] = pattern
        }

        engine.log.info("Live performance session created: 6 tracks, bio-reactive ready", category: .audio)
        return engine
    }
}

// NOTE: clamped(to:) is defined in NumericExtensions.swift

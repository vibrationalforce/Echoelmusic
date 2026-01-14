import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - DAW Timeline Engine
/// Professional DAW Timeline with integrated Video, Audio, MIDI, and Automation
/// Supports both Arrangement View (linear) and Session/Live View (clip-based)

@MainActor
class DAWTimelineEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentView: DAWView = .arrangement
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var currentPosition: TimeInterval = 0  // seconds
    @Published var loopStart: TimeInterval = 0
    @Published var loopEnd: TimeInterval = 16
    @Published var isLooping: Bool = false
    @Published var tempo: Double = 120.0
    @Published var timeSignature: TimeSignature = TimeSignature(numerator: 4, denominator: 4)
    @Published var zoomLevel: Double = 1.0
    @Published var selectedTrackId: UUID?
    @Published var selectedClipIds: Set<UUID> = []

    // MARK: - Tracks

    @Published var tracks: [DAWTrack] = []
    @Published var masterTrack: MasterTrack = MasterTrack()

    // MARK: - Arrangement Timeline

    @Published var arrangementClips: [ArrangementClip] = []
    @Published var markers: [TimelineMarker] = []
    @Published var automationLanes: [AutomationLane] = []

    // MARK: - Session/Live View

    @Published var scenes: [Scene] = []
    @Published var sessionClips: [[SessionClip?]] = []  // [trackIndex][sceneIndex]

    // MARK: - Video Integration

    @Published var videoTracks: [VideoTrack] = []
    @Published var masterVideoOutput: VideoOutputSettings = VideoOutputSettings()
    @Published var videoPreviewEnabled: Bool = true

    // MARK: - Transport

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var audioEngine: AVAudioEngine?

    // MARK: - View Types

    enum DAWView: String, CaseIterable {
        case arrangement = "Arrangement"
        case session = "Session"
        case hybrid = "Hybrid"
        case video = "Video Edit"
    }

    // MARK: - Initialization

    init() {
        setupDefaultTracks()
        setupDefaultScenes()
        log.audio("DAWTimelineEngine: Initialized")
    }

    private func setupDefaultTracks() {
        // Create default track layout
        tracks = [
            DAWTrack(name: "Master Video", type: .video, color: .purple),
            DAWTrack(name: "Video Overlay", type: .video, color: .pink),
            DAWTrack(name: "Drums", type: .audio, color: .red),
            DAWTrack(name: "Bass", type: .audio, color: .orange),
            DAWTrack(name: "Synth", type: .midi, color: .blue),
            DAWTrack(name: "Lead", type: .midi, color: .cyan),
            DAWTrack(name: "FX", type: .audio, color: .green),
            DAWTrack(name: "Vocal", type: .audio, color: .yellow),
            DAWTrack(name: "Automation", type: .automation, color: .gray)
        ]

        // Initialize session clip grid
        sessionClips = Array(repeating: Array(repeating: nil, count: 8), count: tracks.count)
    }

    private func setupDefaultScenes() {
        scenes = [
            Scene(name: "Intro", tempo: 120, color: .blue),
            Scene(name: "Verse 1", tempo: 120, color: .green),
            Scene(name: "Chorus", tempo: 125, color: .orange),
            Scene(name: "Verse 2", tempo: 120, color: .green),
            Scene(name: "Bridge", tempo: 110, color: .purple),
            Scene(name: "Chorus 2", tempo: 125, color: .orange),
            Scene(name: "Breakdown", tempo: 100, color: .cyan),
            Scene(name: "Outro", tempo: 120, color: .gray)
        ]
    }

    // MARK: - Transport Control

    func play() {
        isPlaying = true
        startDisplayLink()
        log.audio("DAWTimelineEngine: Play")
    }

    func pause() {
        isPlaying = false
        stopDisplayLink()
        log.audio("DAWTimelineEngine: Pause")
    }

    func stop() {
        isPlaying = false
        isRecording = false
        currentPosition = 0
        stopDisplayLink()
        log.audio("DAWTimelineEngine: Stop")
    }

    func record() {
        isRecording = true
        isPlaying = true
        startDisplayLink()
        log.audio("DAWTimelineEngine: Record")
    }

    func seek(to position: TimeInterval) {
        currentPosition = max(0, position)
        log.audio("DAWTimelineEngine: Seek to \(position)")
    }

    func setLoop(start: TimeInterval, end: TimeInterval) {
        loopStart = start
        loopEnd = end
        log.audio("DAWTimelineEngine: Loop \(start) - \(end)")
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlayhead))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlayhead() {
        guard isPlaying else { return }

        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        currentPosition += deltaTime

        // Handle looping
        if isLooping && currentPosition >= loopEnd {
            currentPosition = loopStart
        }
    }

    // MARK: - Track Management

    func addTrack(type: DAWTrack.TrackType, name: String? = nil) {
        let trackName = name ?? "\(type.rawValue.capitalized) \(tracks.count + 1)"
        let track = DAWTrack(name: trackName, type: type, color: type.defaultColor)
        tracks.append(track)

        // Expand session grid
        sessionClips.append(Array(repeating: nil, count: scenes.count))

        log.audio("DAWTimelineEngine: Added track \(trackName)")
    }

    func removeTrack(_ id: UUID) {
        if let index = tracks.firstIndex(where: { $0.id == id }) {
            tracks.remove(at: index)
            sessionClips.remove(at: index)
        }
    }

    func moveTrack(from: Int, to: Int) {
        guard from != to, from >= 0, to >= 0, from < tracks.count, to < tracks.count else { return }
        let track = tracks.remove(at: from)
        tracks.insert(track, at: to)

        let clips = sessionClips.remove(at: from)
        sessionClips.insert(clips, at: to)
    }

    // MARK: - Clip Management

    func addClipToArrangement(_ clip: ArrangementClip) {
        arrangementClips.append(clip)
    }

    func addClipToSession(trackIndex: Int, sceneIndex: Int, clip: SessionClip) {
        guard trackIndex < sessionClips.count, sceneIndex < scenes.count else { return }
        sessionClips[trackIndex][sceneIndex] = clip
    }

    func triggerScene(_ sceneIndex: Int) {
        guard sceneIndex < scenes.count else { return }

        // Trigger all clips in the scene
        for trackIndex in 0..<tracks.count {
            if let clip = sessionClips[trackIndex][sceneIndex] {
                triggerClip(clip)
            }
        }

        // Update tempo if scene has different tempo
        let scene = scenes[sceneIndex]
        if scene.tempo != tempo {
            // Smooth tempo transition
            withAnimation(.easeInOut(duration: scene.tempoTransitionTime)) {
                tempo = scene.tempo
            }
        }

        log.audio("DAWTimelineEngine: Triggered scene \(scene.name)")
    }

    func triggerClip(_ clip: SessionClip) {
        // Queue clip for playback
        log.audio("DAWTimelineEngine: Triggered clip \(clip.name)")
    }

    // MARK: - Time Utilities

    func beatsToSeconds(_ beats: Double) -> TimeInterval {
        return beats * 60.0 / tempo
    }

    func secondsToBeats(_ seconds: TimeInterval) -> Double {
        return seconds * tempo / 60.0
    }

    func barsToSeconds(_ bars: Double) -> TimeInterval {
        let beatsPerBar = Double(timeSignature.numerator)
        return beatsToSeconds(bars * beatsPerBar)
    }

    func secondsToBars(_ seconds: TimeInterval) -> Double {
        let beatsPerBar = Double(timeSignature.numerator)
        return secondsToBeats(seconds) / beatsPerBar
    }

    var currentBar: Int {
        return Int(secondsToBars(currentPosition)) + 1
    }

    var currentBeat: Int {
        let totalBeats = secondsToBeats(currentPosition)
        return Int(totalBeats.truncatingRemainder(dividingBy: Double(timeSignature.numerator))) + 1
    }

    // MARK: - Quantization

    func quantize(_ position: TimeInterval, to grid: QuantizeGrid) -> TimeInterval {
        let gridSize = grid.sizeInBeats(timeSignature: timeSignature)
        let gridSeconds = beatsToSeconds(gridSize)
        return round(position / gridSeconds) * gridSeconds
    }

    enum QuantizeGrid: String, CaseIterable {
        case bar = "1 Bar"
        case halfBar = "1/2 Bar"
        case beat = "1 Beat"
        case halfBeat = "1/2 Beat"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtySecond = "1/32"
        case triplet = "Triplet"
        case off = "Off"

        func sizeInBeats(timeSignature: TimeSignature) -> Double {
            switch self {
            case .bar: return Double(timeSignature.numerator)
            case .halfBar: return Double(timeSignature.numerator) / 2.0
            case .beat: return 1.0
            case .halfBeat: return 0.5
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtySecond: return 0.125
            case .triplet: return 1.0 / 3.0
            case .off: return 0.001
            }
        }
    }
}

// MARK: - Time Signature

struct TimeSignature: Equatable {
    var numerator: Int  // beats per bar
    var denominator: Int  // note value (4 = quarter note)

    static let common = TimeSignature(numerator: 4, denominator: 4)
    static let waltz = TimeSignature(numerator: 3, denominator: 4)
    static let sixEight = TimeSignature(numerator: 6, denominator: 8)
}

// MARK: - DAW Track

struct DAWTrack: Identifiable {
    let id = UUID()
    var name: String
    var type: TrackType
    var color: Color
    var volume: Float = 0.8
    var pan: Float = 0.0
    var isMuted: Bool = false
    var isSolo: Bool = false
    var isArmed: Bool = false
    var isVisible: Bool = true
    var height: CGFloat = 80

    // Effects chain
    var effects: [TrackEffect] = []

    // Sends
    var sends: [TrackSend] = []

    // Input/Output routing
    var inputSource: InputSource = .none
    var outputDestination: OutputDestination = .master

    enum TrackType: String, CaseIterable {
        case audio = "Audio"
        case midi = "MIDI"
        case video = "Video"
        case automation = "Automation"
        case group = "Group"
        case return_ = "Return"

        var defaultColor: Color {
            switch self {
            case .audio: return .blue
            case .midi: return .green
            case .video: return .purple
            case .automation: return .gray
            case .group: return .orange
            case .return_: return .cyan
            }
        }
    }

    enum InputSource {
        case none
        case audioInput(channel: Int)
        case midiInput(device: String, channel: Int)
        case videoInput(source: String)
        case internal_(track: UUID)
    }

    enum OutputDestination {
        case master
        case track(UUID)
        case external(channel: Int)
    }
}

// MARK: - Track Effect

struct TrackEffect: Identifiable {
    let id = UUID()
    var name: String
    var type: EffectType
    var isEnabled: Bool = true
    var parameters: [String: Float] = [:]

    enum EffectType: String, CaseIterable {
        case eq = "EQ"
        case compressor = "Compressor"
        case reverb = "Reverb"
        case delay = "Delay"
        case chorus = "Chorus"
        case distortion = "Distortion"
        case filter = "Filter"
        case gate = "Gate"
        case limiter = "Limiter"
        case saturator = "Saturator"
        case videoEffect = "Video Effect"
    }
}

// MARK: - Track Send

struct TrackSend: Identifiable {
    let id = UUID()
    var destinationTrackId: UUID
    var level: Float = 0.0  // -inf to +6 dB
    var isPreFader: Bool = false
}

// MARK: - Master Track

struct MasterTrack {
    var volume: Float = 0.8
    var effects: [TrackEffect] = []
    var limiterEnabled: Bool = true
    var limiterThreshold: Float = -0.3  // dB

    // Metering
    var peakLeft: Float = 0.0
    var peakRight: Float = 0.0
    var rmsLeft: Float = 0.0
    var rmsRight: Float = 0.0
}

// MARK: - Arrangement Clip

struct ArrangementClip: Identifiable {
    let id = UUID()
    var trackId: UUID
    var name: String
    var type: ClipType
    var startTime: TimeInterval  // position on timeline
    var duration: TimeInterval
    var offset: TimeInterval = 0  // start offset within source
    var color: Color

    // Clip properties
    var gain: Float = 1.0
    var fadeInDuration: TimeInterval = 0
    var fadeOutDuration: TimeInterval = 0
    var isLooping: Bool = false
    var loopLength: TimeInterval?
    var isMuted: Bool = false
    var isLocked: Bool = false

    // Content reference
    var contentId: UUID?  // Reference to audio/video/MIDI content

    // Warp/stretch
    var warpEnabled: Bool = false
    var warpMarkers: [WarpMarker] = []

    // Video-specific
    var videoOpacity: Float = 1.0
    var videoBlendMode: BlendMode = .normal
    var videoTransform: VideoTransform = VideoTransform()

    enum ClipType: String {
        case audio
        case midi
        case video
        case automation
    }

    enum BlendMode: String, CaseIterable {
        case normal, additive, multiply, screen, overlay
        case softLight, hardLight, colorDodge, colorBurn
        case difference, exclusion
    }
}

// MARK: - Warp Marker

struct WarpMarker: Identifiable {
    let id = UUID()
    var beatPosition: Double  // position in beats
    var samplePosition: TimeInterval  // position in source
}

// MARK: - Video Transform

struct VideoTransform {
    var positionX: Float = 0
    var positionY: Float = 0
    var scaleX: Float = 1.0
    var scaleY: Float = 1.0
    var rotation: Float = 0  // degrees
    var anchorX: Float = 0.5
    var anchorY: Float = 0.5
    var opacity: Float = 1.0
}

// MARK: - Session Clip

struct SessionClip: Identifiable {
    let id = UUID()
    var name: String
    var type: ArrangementClip.ClipType
    var color: Color
    var duration: TimeInterval

    // Launch properties
    var launchMode: LaunchMode = .trigger
    var launchQuantize: DAWTimelineEngine.QuantizeGrid = .bar
    var legato: Bool = false
    var followAction: FollowAction?
    var followActionTime: TimeInterval = 4.0

    // Loop settings
    var loopStart: TimeInterval = 0
    var loopEnd: TimeInterval?
    var isLooping: Bool = true

    // Content
    var contentId: UUID?

    // State
    var isPlaying: Bool = false
    var isQueued: Bool = false
    var playbackPosition: TimeInterval = 0

    enum LaunchMode: String, CaseIterable {
        case trigger = "Trigger"
        case gate = "Gate"
        case toggle = "Toggle"
        case repeat_ = "Repeat"
    }

    struct FollowAction {
        var actionA: Action
        var actionB: Action
        var chanceA: Int  // 0-100
        var chanceB: Int { 100 - chanceA }

        enum Action: String, CaseIterable {
            case stop = "Stop"
            case playAgain = "Play Again"
            case previous = "Previous"
            case next = "Next"
            case first = "First"
            case last = "Last"
            case random = "Random"
            case randomOther = "Random Other"
        }
    }
}

// MARK: - Scene

struct Scene: Identifiable {
    let id = UUID()
    var name: String
    var tempo: Double
    var color: Color
    var tempoTransitionTime: TimeInterval = 1.0  // seconds
    var launchQuantize: DAWTimelineEngine.QuantizeGrid = .bar
}

// MARK: - Timeline Marker

struct TimelineMarker: Identifiable {
    let id = UUID()
    var name: String
    var position: TimeInterval
    var color: Color
    var type: MarkerType

    enum MarkerType: String, CaseIterable {
        case cue = "Cue"
        case loop = "Loop"
        case section = "Section"
        case verse = "Verse"
        case chorus = "Chorus"
        case bridge = "Bridge"
        case drop = "Drop"
        case breakdown = "Breakdown"
        case custom = "Custom"
    }
}

// MARK: - Automation Lane

struct AutomationLane: Identifiable {
    let id = UUID()
    var trackId: UUID
    var parameter: String
    var points: [AutomationPoint] = []
    var curveType: CurveType = .linear
    var isVisible: Bool = true
    var color: Color = .yellow

    enum CurveType: String, CaseIterable {
        case linear = "Linear"
        case bezier = "Bezier"
        case step = "Step"
        case smooth = "Smooth"
    }
}

// MARK: - Automation Point

struct AutomationPoint: Identifiable {
    let id = UUID()
    var time: TimeInterval
    var value: Float  // 0-1 normalized
    var curve: Float = 0  // -1 to 1 (curve tension)
}

// MARK: - Video Track

struct VideoTrack: Identifiable {
    let id = UUID()
    var name: String
    var clips: [ArrangementClip] = []
    var opacity: Float = 1.0
    var blendMode: ArrangementClip.BlendMode = .normal
    var effects: [VideoEffect] = []
    var isMuted: Bool = false
    var isLocked: Bool = false
}

// MARK: - Video Effect

struct VideoEffect: Identifiable {
    let id = UUID()
    var name: String
    var type: EffectType
    var isEnabled: Bool = true
    var parameters: [String: Float] = [:]

    enum EffectType: String, CaseIterable {
        // Color
        case colorCorrection = "Color Correction"
        case colorGrading = "Color Grading"
        case lut = "LUT"
        case exposure = "Exposure"
        case contrast = "Contrast"
        case saturation = "Saturation"
        case hueShift = "Hue Shift"

        // Blur/Sharpen
        case blur = "Blur"
        case gaussianBlur = "Gaussian Blur"
        case motionBlur = "Motion Blur"
        case sharpen = "Sharpen"

        // Distortion
        case chromaKey = "Chroma Key"
        case lumaKey = "Luma Key"
        case cornerPin = "Corner Pin"
        case warp = "Warp"
        case mirror = "Mirror"
        case kaleidoscope = "Kaleidoscope"

        // Stylize
        case vignette = "Vignette"
        case filmGrain = "Film Grain"
        case glitch = "Glitch"
        case pixelate = "Pixelate"
        case posterize = "Posterize"
        case halftone = "Halftone"

        // Generate
        case solidColor = "Solid Color"
        case gradient = "Gradient"
        case noise = "Noise"
        case fractal = "Fractal"

        // Bio-Reactive
        case bioReactiveGlow = "Bio-Reactive Glow"
        case heartbeatPulse = "Heartbeat Pulse"
        case coherenceField = "Coherence Field"
        case breathingWave = "Breathing Wave"

        // AI
        case aiStyleTransfer = "AI Style Transfer"
        case aiUpscale = "AI Upscale"
        case aiBackgroundRemoval = "AI Background Removal"
        case aiFaceTracking = "AI Face Tracking"
        case aiObjectTracking = "AI Object Tracking"
    }
}

// MARK: - Video Output Settings

struct VideoOutputSettings {
    var resolution: VideoResolution = .fullHD1080
    var frameRate: Double = 30.0
    var codec: VideoCodec = .h264
    var bitrate: Int = 10_000_000  // bits per second

    enum VideoResolution: String, CaseIterable {
        case sd480 = "480p"
        case hd720 = "720p"
        case fullHD1080 = "1080p"
        case qhd1440 = "1440p"
        case uhd4k = "4K"
        case uhd8k = "8K"
        case cinema4k = "Cinema 4K"
        case cinema8k = "Cinema 8K"

        var size: CGSize {
            switch self {
            case .sd480: return CGSize(width: 854, height: 480)
            case .hd720: return CGSize(width: 1280, height: 720)
            case .fullHD1080: return CGSize(width: 1920, height: 1080)
            case .qhd1440: return CGSize(width: 2560, height: 1440)
            case .uhd4k: return CGSize(width: 3840, height: 2160)
            case .uhd8k: return CGSize(width: 7680, height: 4320)
            case .cinema4k: return CGSize(width: 4096, height: 2160)
            case .cinema8k: return CGSize(width: 8192, height: 4320)
            }
        }
    }

    enum VideoCodec: String, CaseIterable {
        case h264 = "H.264"
        case h265 = "H.265/HEVC"
        case prores422 = "ProRes 422"
        case prores4444 = "ProRes 4444"
        case proresRAW = "ProRes RAW"
        case av1 = "AV1"
        case vp9 = "VP9"
    }
}

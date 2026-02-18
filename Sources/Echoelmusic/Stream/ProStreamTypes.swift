// ProStreamTypes.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Type definitions for the professional streaming engine
// Scenes, sources, transitions, encoding, hotkeys, audio mixing

import Foundation
import AVFoundation

// MARK: - Scene Color

/// Color label for organizing scenes in the scene list
public enum SceneColor: String, CaseIterable, Sendable, Codable {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case pink
    case white
    case gray
}

// MARK: - Stream Source Type

/// The type of media source within a scene
public enum StreamSourceType: Sendable {
    case camera(index: Int)
    case screenCapture
    case windowCapture
    case mediaFile(URL)
    case imageFile(URL)
    case imageSlideshow
    case textGDI
    case colorSource(color: String)
    case browserSource(url: String)
    case audioInput(device: String)
    case audioOutput(device: String)
    case videoCapture(device: String)
    case ndiInput(name: String)
    case deckLink(device: String)
    case visualizer
    case bioMetrics
    case vjLayer
    case dmxPreview
}

// MARK: - Source Transform

/// Position, size, rotation, and crop for a source layer
public struct SourceTransform: Sendable {
    public var position: CGPoint
    public var size: CGSize
    public var rotation: Float
    public var cropTop: Float
    public var cropBottom: Float
    public var cropLeft: Float
    public var cropRight: Float
    public var flipH: Bool
    public var flipV: Bool

    public init(
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 1920, height: 1080),
        rotation: Float = 0,
        cropTop: Float = 0,
        cropBottom: Float = 0,
        cropLeft: Float = 0,
        cropRight: Float = 0,
        flipH: Bool = false,
        flipV: Bool = false
    ) {
        self.position = position
        self.size = size
        self.rotation = rotation
        self.cropTop = cropTop
        self.cropBottom = cropBottom
        self.cropLeft = cropLeft
        self.cropRight = cropRight
        self.flipH = flipH
        self.flipV = flipV
    }
}

// MARK: - Blend Mode

/// Compositing blend mode for layering sources
public enum SourceBlendMode: String, CaseIterable, Sendable {
    case normal
    case additive
    case multiply
    case screen
    case overlay
}

// MARK: - Filter Type

/// Audio/video filter applied to a source or globally
public enum FilterType: Sendable {
    // Video filters
    case chromaKey(similarity: Float, smoothness: Float, keyColor: String)
    case colorCorrection(brightness: Float, contrast: Float, saturation: Float, hue: Float)
    case lumaKey(threshold: Float, smoothness: Float)
    case sharpen(amount: Float)
    case blur(type: BlurType, amount: Float)
    case crop
    case colorGrade(lut: String)
    case scrollText(speed: Float, direction: ScrollDirection)
    case imageOverlay(url: URL, opacity: Float)

    // Audio filters
    case compressor(threshold: Float, ratio: Float, attack: Float, release: Float)
    case noiseSuppression(level: Float)
    case noiseGate(threshold: Float)
    case gain(dB: Float)
    case limiter(threshold: Float)
    case expander(threshold: Float, ratio: Float)
    case eq3Band(low: Float, mid: Float, high: Float)
    case deEsser(threshold: Float)
    case sidechain(source: UUID)

    public enum BlurType: String, Sendable {
        case gaussian
        case box
        case motion
    }

    public enum ScrollDirection: String, Sendable {
        case left
        case right
        case up
        case down
    }
}

// MARK: - Source Filter

/// A named, toggleable filter instance attached to a source
public struct StreamSourceFilter: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var type: FilterType

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        type: FilterType
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.type = type
    }
}

// MARK: - Scene Audio Mix

/// Per-scene audio routing configuration
public struct SceneAudioMix: Sendable {
    public var enabledSourceIDs: Set<UUID>
    public var masterVolume: Float

    public init(enabledSourceIDs: Set<UUID> = [], masterVolume: Float = 1.0) {
        self.enabledSourceIDs = enabledSourceIDs
        self.masterVolume = masterVolume
    }
}

// MARK: - Transition Type

/// The visual transition used when switching between scenes
public enum StreamTransitionType: Sendable {
    case cut
    case fade
    case swipe(direction: SwipeDirection)
    case slide(direction: SwipeDirection)
    case stinger(media: URL, point: TimeInterval)
    case fadeToColor(color: String)
    case luma(media: URL)
    case zoom
    case iris

    public enum SwipeDirection: String, Sendable {
        case left
        case right
        case up
        case down
    }
}

// MARK: - Scene Transition

/// A transition configuration with type, duration, and audio crossfade
public struct StreamSceneTransition: Sendable {
    public var type: StreamTransitionType
    public var duration: TimeInterval
    public var audioFade: Bool

    public init(
        type: StreamTransitionType = .fade,
        duration: TimeInterval = 0.3,
        audioFade: Bool = true
    ) {
        self.type = type
        self.duration = duration
        self.audioFade = audioFade
    }
}

// MARK: - Stream Source

/// A single media source (layer) within a scene
public struct StreamSource: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: StreamSourceType
    public var transform: SourceTransform
    public var opacity: Float
    public var isVisible: Bool
    public var isLocked: Bool
    public var blendMode: SourceBlendMode
    public var filters: [StreamSourceFilter]
    public var groupID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        type: StreamSourceType,
        transform: SourceTransform = SourceTransform(),
        opacity: Float = 1.0,
        isVisible: Bool = true,
        isLocked: Bool = false,
        blendMode: SourceBlendMode = .normal,
        filters: [StreamSourceFilter] = [],
        groupID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.transform = transform
        self.opacity = opacity
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.blendMode = blendMode
        self.filters = filters
        self.groupID = groupID
    }
}

// MARK: - Stream Scene

/// An OBS-style scene containing an ordered list of sources (bottom to top)
public struct ProStreamScene: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var color: SceneColor
    public var sources: [StreamSource]
    public var isActive: Bool
    public var isPreview: Bool
    public var transition: StreamSceneTransition
    public var audioMix: SceneAudioMix

    public init(
        id: UUID = UUID(),
        name: String,
        color: SceneColor = .blue,
        sources: [StreamSource] = [],
        isActive: Bool = false,
        isPreview: Bool = false,
        transition: StreamSceneTransition = StreamSceneTransition(),
        audioMix: SceneAudioMix = SceneAudioMix()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.sources = sources
        self.isActive = isActive
        self.isPreview = isPreview
        self.transition = transition
        self.audioMix = audioMix
    }
}

// MARK: - Encoder Type

/// Hardware or software encoder selection
public enum EncoderType: String, CaseIterable, Sendable {
    case h264Hardware = "H.264 (Hardware)"
    case h264Software = "H.264 (Software)"
    case h265Hardware = "H.265 (Hardware)"
    case h265Software = "H.265 (Software)"
    case av1 = "AV1"
    case prores = "ProRes"
}

// MARK: - Record Format

/// Container format for local recordings
public enum RecordFormat: String, CaseIterable, Sendable {
    case mkv = "MKV"
    case mp4 = "MP4"
    case mov = "MOV"
    case flv = "FLV"
    case ts = "MPEG-TS"
}

// MARK: - Stream Resolution

/// Common resolution + frame rate presets and a custom option
public enum StreamResolution: Sendable {
    case _720p30
    case _720p60
    case _1080p30
    case _1080p60
    case _1440p30
    case _1440p60
    case _4k30
    case _4k60
    case custom(width: Int, height: Int, fps: Int)

    public var width: Int {
        switch self {
        case ._720p30, ._720p60: return 1280
        case ._1080p30, ._1080p60: return 1920
        case ._1440p30, ._1440p60: return 2560
        case ._4k30, ._4k60: return 3840
        case .custom(let w, _, _): return w
        }
    }

    public var height: Int {
        switch self {
        case ._720p30, ._720p60: return 720
        case ._1080p30, ._1080p60: return 1080
        case ._1440p30, ._1440p60: return 1440
        case ._4k30, ._4k60: return 2160
        case .custom(_, let h, _): return h
        }
    }

    public var fps: Int {
        switch self {
        case ._720p30, ._1080p30, ._1440p30, ._4k30: return 30
        case ._720p60, ._1080p60, ._1440p60, ._4k60: return 60
        case .custom(_, _, let fps): return fps
        }
    }

    public var label: String {
        switch self {
        case ._720p30: return "720p30"
        case ._720p60: return "720p60"
        case ._1080p30: return "1080p30"
        case ._1080p60: return "1080p60"
        case ._1440p30: return "1440p30"
        case ._1440p60: return "1440p60"
        case ._4k30: return "4K30"
        case ._4k60: return "4K60"
        case .custom(let w, let h, let fps): return "\(w)x\(h)@\(fps)"
        }
    }
}

// MARK: - Stream Platform

/// Supported streaming platforms with preset configurations
public enum StreamPlatform: String, CaseIterable, Sendable {
    case youtube = "YouTube"
    case twitch = "Twitch"
    case kick = "Kick"
    case tiktokLive = "TikTok Live"
    case instagramLive = "Instagram Live"
    case facebookLive = "Facebook Live"
    case custom = "Custom"

    public var defaultIngestURL: String {
        switch self {
        case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch: return "rtmp://live.twitch.tv/app"
        case .kick: return "rtmps://fa723fc1b171.global-contribute.live-video.net/app"
        case .tiktokLive: return "rtmp://push.tiktok.com/live"
        case .instagramLive: return "rtmps://live-upload.instagram.com/rtmp"
        case .facebookLive: return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .custom: return ""
        }
    }

    public var recommendedResolution: StreamResolution {
        switch self {
        case .youtube: return ._1080p60
        case .twitch: return ._1080p60
        case .kick: return ._1080p60
        case .tiktokLive: return ._1080p30
        case .instagramLive: return ._720p30
        case .facebookLive: return ._1080p30
        case .custom: return ._1080p30
        }
    }

    public var recommendedBitrate: Int {
        switch self {
        case .youtube: return 6_000_000
        case .twitch: return 6_000_000
        case .kick: return 8_000_000
        case .tiktokLive: return 4_000_000
        case .instagramLive: return 3_500_000
        case .facebookLive: return 4_000_000
        case .custom: return 6_000_000
        }
    }

    public var recommendedKeyframeInterval: Int {
        switch self {
        case .youtube: return 2
        case .twitch: return 2
        case .kick: return 2
        case .tiktokLive: return 2
        case .instagramLive: return 2
        case .facebookLive: return 2
        case .custom: return 2
        }
    }

    public var recommendedEncoder: EncoderType {
        switch self {
        case .youtube, .twitch, .kick, .tiktokLive, .instagramLive, .facebookLive:
            return .h264Hardware
        case .custom:
            return .h264Hardware
        }
    }

    public var maxAudioBitrate: Int {
        switch self {
        case .youtube: return 320
        case .twitch: return 320
        case .kick: return 320
        case .tiktokLive: return 128
        case .instagramLive: return 128
        case .facebookLive: return 256
        case .custom: return 320
        }
    }
}

// MARK: - Stream Preset

/// A complete, pre-configured streaming setup for a specific platform
public struct StreamPreset: Sendable {
    public let platform: StreamPlatform
    public let resolution: StreamResolution
    public let videoBitrate: Int
    public let audioBitrate: Int
    public let keyframeInterval: Int
    public let encoder: EncoderType

    public init(
        platform: StreamPlatform,
        resolution: StreamResolution,
        videoBitrate: Int,
        audioBitrate: Int,
        keyframeInterval: Int,
        encoder: EncoderType
    ) {
        self.platform = platform
        self.resolution = resolution
        self.videoBitrate = videoBitrate
        self.audioBitrate = audioBitrate
        self.keyframeInterval = keyframeInterval
        self.encoder = encoder
    }

    // MARK: Platform Presets

    public static func youtube() -> StreamPreset {
        StreamPreset(
            platform: .youtube,
            resolution: ._1080p60,
            videoBitrate: 6_000_000,
            audioBitrate: 320,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func twitch() -> StreamPreset {
        StreamPreset(
            platform: .twitch,
            resolution: ._1080p60,
            videoBitrate: 6_000_000,
            audioBitrate: 320,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func kick() -> StreamPreset {
        StreamPreset(
            platform: .kick,
            resolution: ._1080p60,
            videoBitrate: 8_000_000,
            audioBitrate: 320,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func tiktokLive() -> StreamPreset {
        StreamPreset(
            platform: .tiktokLive,
            resolution: ._1080p30,
            videoBitrate: 4_000_000,
            audioBitrate: 128,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func instagramLive() -> StreamPreset {
        StreamPreset(
            platform: .instagramLive,
            resolution: ._720p30,
            videoBitrate: 3_500_000,
            audioBitrate: 128,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func facebookLive() -> StreamPreset {
        StreamPreset(
            platform: .facebookLive,
            resolution: ._1080p30,
            videoBitrate: 4_000_000,
            audioBitrate: 256,
            keyframeInterval: 2,
            encoder: .h264Hardware
        )
    }

    public static func custom(
        resolution: StreamResolution = ._1080p30,
        videoBitrate: Int = 6_000_000,
        audioBitrate: Int = 256,
        keyframeInterval: Int = 2,
        encoder: EncoderType = .h264Hardware
    ) -> StreamPreset {
        StreamPreset(
            platform: .custom,
            resolution: resolution,
            videoBitrate: videoBitrate,
            audioBitrate: audioBitrate,
            keyframeInterval: keyframeInterval,
            encoder: encoder
        )
    }
}

// MARK: - Output Config

/// Full encoder and destination configuration for a stream or recording output
public struct OutputConfig: Sendable {
    // Stream
    public var url: String
    public var streamKey: String

    // Encoder
    public var encoder: EncoderType
    public var videoBitrate: Int
    public var keyframeInterval: Int

    // Video
    public var resolution: StreamResolution

    // Audio
    public var audioSampleRate: Int
    public var audioBitrate: Int
    public var audioChannels: Int

    // Recording
    public var recordingPath: String
    public var recordFormat: RecordFormat

    // Preset
    public var preset: StreamPreset?

    public init(
        url: String = "",
        streamKey: String = "",
        encoder: EncoderType = .h264Hardware,
        videoBitrate: Int = 6_000_000,
        keyframeInterval: Int = 2,
        resolution: StreamResolution = ._1080p60,
        audioSampleRate: Int = 48000,
        audioBitrate: Int = 256,
        audioChannels: Int = 2,
        recordingPath: String = "",
        recordFormat: RecordFormat = .mkv,
        preset: StreamPreset? = nil
    ) {
        self.url = url
        self.streamKey = streamKey
        self.encoder = encoder
        self.videoBitrate = videoBitrate
        self.keyframeInterval = keyframeInterval
        self.resolution = resolution
        self.audioSampleRate = audioSampleRate
        self.audioBitrate = audioBitrate
        self.audioChannels = audioChannels
        self.recordingPath = recordingPath
        self.recordFormat = recordFormat
        self.preset = preset
    }

    /// Create an OutputConfig from a platform preset
    public static func from(preset: StreamPreset, streamKey: String = "") -> OutputConfig {
        OutputConfig(
            url: preset.platform.defaultIngestURL,
            streamKey: streamKey,
            encoder: preset.encoder,
            videoBitrate: preset.videoBitrate,
            keyframeInterval: preset.keyframeInterval,
            resolution: preset.resolution,
            audioBitrate: preset.audioBitrate,
            preset: preset
        )
    }
}

// MARK: - Output Type

/// The kind of output destination
public enum OutputType: String, CaseIterable, Sendable {
    case rtmpStream = "RTMP Stream"
    case srtStream = "SRT Stream"
    case ristStream = "RIST Stream"
    case hlsStream = "HLS Stream"
    case webRTCStream = "WebRTC Stream"
    case recording = "Recording"
    case virtualCamera = "Virtual Camera"
    case ndiOutput = "NDI Output"
    case deckLinkOutput = "DeckLink Output"
    case replayBuffer = "Replay Buffer"
}

// MARK: - Output State

/// The live state of a stream output
public enum OutputState: Sendable, Equatable {
    case idle
    case connecting
    case active
    case reconnecting
    case error(String)
}

// MARK: - Output Stats

/// Real-time statistics for a single output
public struct OutputStats: Sendable {
    public var bitrate: Int
    public var fps: Double
    public var droppedFrames: Int
    public var totalFrames: Int
    public var duration: TimeInterval
    public var bytesSent: Int64

    public init(
        bitrate: Int = 0,
        fps: Double = 0,
        droppedFrames: Int = 0,
        totalFrames: Int = 0,
        duration: TimeInterval = 0,
        bytesSent: Int64 = 0
    ) {
        self.bitrate = bitrate
        self.fps = fps
        self.droppedFrames = droppedFrames
        self.totalFrames = totalFrames
        self.duration = duration
        self.bytesSent = bytesSent
    }

    /// Frame drop percentage (0-100)
    public var dropPercentage: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(droppedFrames) / Double(totalFrames) * 100.0
    }
}

// MARK: - Stream Output

/// A single output destination (stream, recording, virtual camera, etc.)
public struct StreamOutput: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: OutputType
    public var config: OutputConfig
    public var state: OutputState
    public var stats: OutputStats

    public init(
        id: UUID = UUID(),
        name: String,
        type: OutputType,
        config: OutputConfig = OutputConfig(),
        state: OutputState = .idle,
        stats: OutputStats = OutputStats()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.config = config
        self.state = state
        self.stats = stats
    }
}

// MARK: - Multi-Stream Config

/// Configuration for streaming to multiple destinations simultaneously
public struct MultiStreamConfig: Sendable {
    public var destinations: [StreamOutput]
    public var masterEncoder: Bool

    public static let maxDestinations = 8

    public init(
        destinations: [StreamOutput] = [],
        masterEncoder: Bool = true
    ) {
        self.destinations = Array(destinations.prefix(Self.maxDestinations))
        self.masterEncoder = masterEncoder
    }

    /// Add a destination (up to 8)
    public mutating func addDestination(_ output: StreamOutput) {
        guard destinations.count < Self.maxDestinations else { return }
        destinations.append(output)
    }

    /// Remove a destination by ID
    public mutating func removeDestination(id: UUID) {
        destinations.removeAll { $0.id == id }
    }
}

// MARK: - Replay Buffer

/// Continuous circular buffer that can save the last N seconds on demand
public struct ReplayBuffer: Sendable {
    public var bufferDuration: TimeInterval
    public var isActive: Bool
    public var outputPath: String
    public var format: RecordFormat
    public var lastSavedURL: URL?

    public init(
        bufferDuration: TimeInterval = 30,
        isActive: Bool = false,
        outputPath: String = NSTemporaryDirectory(),
        format: RecordFormat = .mp4,
        lastSavedURL: URL? = nil
    ) {
        self.bufferDuration = bufferDuration
        self.isActive = isActive
        self.outputPath = outputPath
        self.format = format
        self.lastSavedURL = lastSavedURL
    }

    /// Save the current replay buffer to disk and return the file URL
    public mutating func saveReplay() -> URL? {
        guard isActive else { return nil }
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "Replay_\(timestamp).\(format.rawValue.lowercased())"
        let url = URL(fileURLWithPath: outputPath).appendingPathComponent(fileName)
        lastSavedURL = url
        ProfessionalLogger.shared.log(
            .info,
            category: .streaming,
            "Replay saved to \(url.lastPathComponent)"
        )
        return url
    }
}

// MARK: - Studio Mode

/// OBS Studio Mode: prepare scenes in preview before sending them live
public struct StudioMode: Sendable {
    public var isEnabled: Bool
    public var previewSceneID: UUID?
    public var programSceneID: UUID?

    public init(
        isEnabled: Bool = false,
        previewSceneID: UUID? = nil,
        programSceneID: UUID? = nil
    ) {
        self.isEnabled = isEnabled
        self.previewSceneID = previewSceneID
        self.programSceneID = programSceneID
    }
}

// MARK: - Hotkey Trigger

/// The input event that fires a hotkey action
public enum HotkeyTrigger: Sendable {
    case keyboard(key: String, modifiers: [String])
    case midiNote(note: Int, channel: Int)
    case midiCC(cc: Int, channel: Int, threshold: Int)
    case oscMessage(address: String)
}

// MARK: - Hotkey Action

/// The command executed when a hotkey is triggered
public enum HotkeyAction: Sendable {
    case switchScene(id: UUID)
    case toggleSource(id: UUID)
    case startStream
    case stopStream
    case startRecording
    case stopRecording
    case saveReplay
    case toggleMute(sourceID: UUID)
    case pushToTalk(sourceID: UUID)
    case transition
    case toggleStudioMode
}

// MARK: - Stream Hotkey

/// A named mapping from a trigger event to a streaming action
public struct StreamHotkey: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var trigger: HotkeyTrigger
    public var action: HotkeyAction

    public init(
        id: UUID = UUID(),
        name: String,
        trigger: HotkeyTrigger,
        action: HotkeyAction
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.action = action
    }
}

// MARK: - Monitor Mode

/// Audio monitoring mode per mixer channel
public enum StreamMonitorMode: String, CaseIterable, Sendable {
    case off = "Off"
    case monitorOnly = "Monitor Only"
    case monitorAndOutput = "Monitor and Output"
}

// MARK: - Audio Mixer Channel

/// A single channel strip in the audio mixer
public struct AudioMixerChannel: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var sourceID: UUID
    public var volume: Float
    public var mute: Bool
    public var monitorMode: StreamMonitorMode
    public var filters: [StreamSourceFilter]

    public init(
        id: UUID = UUID(),
        name: String,
        sourceID: UUID,
        volume: Float = 1.0,
        mute: Bool = false,
        monitorMode: StreamMonitorMode = .off,
        filters: [StreamSourceFilter] = []
    ) {
        self.id = id
        self.name = name
        self.sourceID = sourceID
        self.volume = volume
        self.mute = mute
        self.monitorMode = monitorMode
        self.filters = filters
    }
}

// MARK: - Stream Audio Mixer

/// Global audio mixer with per-source channel strips
public struct StreamAudioMixer: Sendable {
    public var channels: [AudioMixerChannel]
    public var monitorVolume: Float
    public var audioFilters: [StreamSourceFilter]

    public init(
        channels: [AudioMixerChannel] = [],
        monitorVolume: Float = 1.0,
        audioFilters: [StreamSourceFilter] = []
    ) {
        self.channels = channels
        self.monitorVolume = monitorVolume
        self.audioFilters = audioFilters
    }

    /// Find the mixer channel for a given source
    public func channel(for sourceID: UUID) -> AudioMixerChannel? {
        channels.first { $0.sourceID == sourceID }
    }

    /// Set volume for a specific source (0-1)
    public mutating func setVolume(for sourceID: UUID, volume: Float) {
        guard let index = channels.firstIndex(where: { $0.sourceID == sourceID }) else { return }
        channels[index].volume = max(0, min(1, volume))
    }

    /// Toggle mute for a specific source
    public mutating func toggleMute(for sourceID: UUID) {
        guard let index = channels.firstIndex(where: { $0.sourceID == sourceID }) else { return }
        channels[index].mute.toggle()
    }
}

// MARK: - Stream Quality Level

/// Overall stream health indicator for stats overlay
public enum StreamQualityLevel: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
}

// MARK: - Stream Stats

/// Aggregate statistics across all active outputs
public struct StreamStats: Sendable {
    public var totalBitrate: Int
    public var videoFPS: Double
    public var cpuUsage: Double
    public var droppedFrames: Int
    public var totalFrames: Int
    public var uptime: TimeInterval
    public var bandwidthUsed: Int64
    public var quality: StreamQualityLevel

    public init(
        totalBitrate: Int = 0,
        videoFPS: Double = 0,
        cpuUsage: Double = 0,
        droppedFrames: Int = 0,
        totalFrames: Int = 0,
        uptime: TimeInterval = 0,
        bandwidthUsed: Int64 = 0,
        quality: StreamQualityLevel = .excellent
    ) {
        self.totalBitrate = totalBitrate
        self.videoFPS = videoFPS
        self.cpuUsage = cpuUsage
        self.droppedFrames = droppedFrames
        self.totalFrames = totalFrames
        self.uptime = uptime
        self.bandwidthUsed = bandwidthUsed
        self.quality = quality
    }

    /// Human-readable bitrate string
    public var bitrateString: String {
        if totalBitrate >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(totalBitrate) / 1_000_000.0)
        } else {
            return "\(totalBitrate / 1000) kbps"
        }
    }

    /// Drop percentage across all outputs
    public var dropPercentage: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(droppedFrames) / Double(totalFrames) * 100.0
    }
}

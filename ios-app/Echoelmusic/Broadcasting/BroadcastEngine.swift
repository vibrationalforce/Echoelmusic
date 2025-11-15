import Foundation
import AVFoundation
import VideoToolbox
import Combine

// MARK: - Broadcasting System (OBS-style)
// Live streaming to Twitch, YouTube, Facebook, TikTok, Instagram

/// Broadcast Engine - Manages live streaming and recording
@MainActor
class BroadcastEngine: ObservableObject {

    // MARK: - Published Properties
    @Published var isStreaming = false
    @Published var isRecording = false
    @Published var currentScene: BroadcastScene?
    @Published var scenes: [BroadcastScene] = []
    @Published var streamHealth: StreamHealth = StreamHealth()
    @Published var destinations: [StreamDestination] = []

    // MARK: - Stream Health
    struct StreamHealth {
        var bitrate: Int = 0  // kbps
        var fps: Int = 0
        var droppedFrames: Int = 0
        var totalFrames: Int = 0
        var cpuUsage: Double = 0
        var uploadSpeed: Int = 0  // kbps
        var connectionStable: Bool = false

        var dropRate: Double {
            guard totalFrames > 0 else { return 0 }
            return Double(droppedFrames) / Double(totalFrames)
        }
    }

    // MARK: - Stream Destinations
    enum StreamDestination {
        case twitch(streamKey: String, server: String)
        case youtube(streamKey: String, server: String)
        case facebook(streamKey: String, server: String)
        case tiktok(streamKey: String, server: String)
        case instagram(streamKey: String, server: String)
        case custom(rtmpURL: String, streamKey: String)

        var rtmpURL: String {
            switch self {
            case .twitch(let key, let server):
                return "\(server)/\(key)"
            case .youtube(let key, let server):
                return "\(server)/\(key)"
            case .facebook(let key, let server):
                return "\(server)/\(key)"
            case .tiktok(let key, let server):
                return "\(server)/\(key)"
            case .instagram(let key, let server):
                return "\(server)/\(key)"
            case .custom(let url, let key):
                return "\(url)/\(key)"
            }
        }
    }

    // MARK: - Encoding Settings
    struct EncodingSettings {
        var videoCodec: VideoCodec
        var videoBitrate: Int  // kbps
        var resolution: CGSize
        var fps: Int

        var audioCodec: AudioCodec
        var audioBitrate: Int  // kbps
        var audioSampleRate: Double

        var keyframeInterval: Int  // seconds
        var preset: EncodingPreset
        var profile: VideoProfile

        enum VideoCodec: String {
            case h264, h265, vp9, av1
        }

        enum AudioCodec: String {
            case aac, opus, mp3
        }

        enum EncodingPreset: String {
            case ultrafast, superfast, veryfast, faster, fast
            case medium, slow, slower, veryslow
        }

        enum VideoProfile: String {
            case baseline, main, high
        }

        // Quality presets
        static let low = EncodingSettings(
            videoCodec: .h264, videoBitrate: 1500, resolution: CGSize(width: 1280, height: 720), fps: 30,
            audioCodec: .aac, audioBitrate: 128, audioSampleRate: 44100,
            keyframeInterval: 2, preset: .veryfast, profile: .main
        )

        static let medium = EncodingSettings(
            videoCodec: .h264, videoBitrate: 3000, resolution: CGSize(width: 1920, height: 1080), fps: 30,
            audioCodec: .aac, audioBitrate: 192, audioSampleRate: 48000,
            keyframeInterval: 2, preset: .fast, profile: .high
        )

        static let high = EncodingSettings(
            videoCodec: .h264, videoBitrate: 6000, resolution: CGSize(width: 1920, height: 1080), fps: 60,
            audioCodec: .aac, audioBitrate: 256, audioSampleRate: 48000,
            keyframeInterval: 2, preset: .medium, profile: .high
        )

        static let ultra = EncodingSettings(
            videoCodec: .h265, videoBitrate: 10000, resolution: CGSize(width: 3840, height: 2160), fps: 60,
            audioCodec: .aac, audioBitrate: 320, audioSampleRate: 48000,
            keyframeInterval: 2, preset: .slow, profile: .main
        )
    }

    var settings = EncodingSettings.medium

    // MARK: - Encoder
    private var videoEncoder: BroadcastVideoEncoder?
    private var audioEncoder: BroadcastAudioEncoder?
    private var rtmpClient: RTMPClient?

    // MARK: - Streaming
    func startStreaming(to destination: StreamDestination) async throws {
        guard !isStreaming else {
            throw BroadcastError.alreadyStreaming
        }

        // Initialize encoders
        videoEncoder = try BroadcastVideoEncoder(settings: settings)
        audioEncoder = try BroadcastAudioEncoder(settings: settings)

        // Connect to RTMP server
        rtmpClient = RTMPClient(url: destination.rtmpURL)
        try await rtmpClient?.connect()

        // Start encoding and streaming
        isStreaming = true

        // Start monitoring
        startHealthMonitoring()
    }

    func stopStreaming() async {
        isStreaming = false

        await rtmpClient?.disconnect()
        rtmpClient = nil

        videoEncoder = nil
        audioEncoder = nil
    }

    // MARK: - Recording
    func startRecording(to url: URL) async throws {
        guard !isRecording else {
            throw BroadcastError.alreadyRecording
        }

        // In production, would use AVAssetWriter for recording
        isRecording = true
    }

    func stopRecording() async {
        isRecording = false
    }

    // MARK: - Scene Management
    func createScene(name: String) -> BroadcastScene {
        let scene = BroadcastScene(
            id: UUID(),
            name: name,
            sources: [],
            layout: .single,
            transition: .cut,
            audioMix: AudioMixConfiguration()
        )

        scenes.append(scene)
        return scene
    }

    func deleteScene(_ sceneID: UUID) {
        scenes.removeAll { $0.id == sceneID }
        if currentScene?.id == sceneID {
            currentScene = scenes.first
        }
    }

    func switchToScene(_ sceneID: UUID, transition: SceneTransition = .fade(duration: 0.5)) async {
        guard let scene = scenes.first(where: { $0.id == sceneID }) else { return }

        // Apply transition
        await applyTransition(from: currentScene, to: scene, transition: transition)

        currentScene = scene
    }

    private func applyTransition(from: BroadcastScene?, to: BroadcastScene, transition: SceneTransition) async {
        // Animate transition
        switch transition {
        case .cut:
            // Instant switch
            break

        case .fade(let duration):
            // Crossfade
            await crossfade(duration: duration)

        case .slide(let direction, let duration):
            // Slide transition
            await slide(direction: direction, duration: duration)

        case .wipe(let direction, let duration):
            // Wipe transition
            await wipe(direction: direction, duration: duration)
        }
    }

    private func crossfade(duration: TimeInterval) async {
        // Implement crossfade
    }

    private func slide(direction: SlideDirection, duration: TimeInterval) async {
        // Implement slide
    }

    private func wipe(direction: WipeDirection, duration: TimeInterval) async {
        // Implement wipe
    }

    enum SlideDirection {
        case left, right, up, down
    }

    enum WipeDirection {
        case leftToRight, rightToLeft, topToBottom, bottomToTop
    }

    // MARK: - Health Monitoring
    private var healthTimer: Timer?

    private func startHealthMonitoring() {
        healthTimer?.invalidate()

        healthTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStreamHealth()
            }
        }
    }

    private func updateStreamHealth() {
        // Update metrics
        streamHealth.bitrate = settings.videoBitrate + settings.audioBitrate
        streamHealth.fps = settings.fps
        streamHealth.connectionStable = streamHealth.dropRate < 0.05

        // In production, would gather real metrics from encoders and network
    }

    // MARK: - Platform Integration
    func connectToTwitch(streamKey: String) {
        let destination = StreamDestination.twitch(
            streamKey: streamKey,
            server: "rtmp://live.twitch.tv/app"
        )
        destinations.append(destination)
    }

    func connectToYouTube(streamKey: String) {
        let destination = StreamDestination.youtube(
            streamKey: streamKey,
            server: "rtmp://a.rtmp.youtube.com/live2"
        )
        destinations.append(destination)
    }

    func connectToFacebook(streamKey: String) {
        let destination = StreamDestination.facebook(
            streamKey: streamKey,
            server: "rtmps://live-api-s.facebook.com:443/rtmp"
        )
        destinations.append(destination)
    }

    // MARK: - Chat Integration
    func fetchTwitchChat(channel: String) async throws -> [ChatMessage] {
        // In production, would connect to Twitch IRC
        return []
    }

    func sendChatMessage(_ message: String, to platform: String) async throws {
        // Send message via platform API
    }

    struct ChatMessage {
        var username: String
        var message: String
        var timestamp: Date
        var badges: [String]
        var emotes: [String]
    }

    // MARK: - Alerts & Overlays
    func showAlert(_ alert: Alert) {
        // Display on-stream alert
    }

    struct Alert {
        var type: AlertType
        var message: String
        var duration: TimeInterval
        var sound: String?
        var animation: AlertAnimation

        enum AlertType {
            case follower, subscriber, donation, raid, host
        }

        enum AlertAnimation {
            case slideIn, fadeIn, bounce, confetti
        }
    }
}

// MARK: - Broadcast Scene
struct BroadcastScene: Identifiable {
    var id: UUID
    var name: String
    var sources: [BroadcastSource]
    var layout: SceneLayout
    var transition: SceneTransition
    var audioMix: AudioMixConfiguration

    enum SceneLayout {
        case single
        case split(ratio: Float)  // 0-1
        case grid(columns: Int, rows: Int)
        case pictureInPicture(size: CGSize, position: CGPoint)
        case custom(positions: [CGRect])
    }

    enum SceneTransition {
        case cut
        case fade(duration: TimeInterval)
        case slide(direction: BroadcastEngine.SlideDirection, duration: TimeInterval)
        case wipe(direction: BroadcastEngine.WipeDirection, duration: TimeInterval)
    }
}

// MARK: - Broadcast Source
enum BroadcastSource: Identifiable {
    case camera(device: AVCaptureDevice, transform: SourceTransform)
    case screenCapture(display: Int, transform: SourceTransform)
    case audioMix(tracks: [UUID], transform: SourceTransform)
    case visualOutput(node: UUID, transform: SourceTransform)
    case image(url: URL, transform: SourceTransform)
    case video(url: URL, transform: SourceTransform)
    case text(content: String, style: TextStyle, transform: SourceTransform)
    case browser(url: URL, transform: SourceTransform)

    var id: UUID {
        switch self {
        case .camera(_, let t), .screenCapture(_, let t), .audioMix(_, let t),
             .visualOutput(_, let t), .image(_, let t), .video(_, let t),
             .text(_, _, let t), .browser(_, let t):
            return t.id
        }
    }

    struct SourceTransform {
        var id: UUID = UUID()
        var position: CGPoint
        var size: CGSize
        var rotation: Float  // degrees
        var opacity: Float  // 0-1
        var cropRect: CGRect?
    }

    struct TextStyle {
        var font: String
        var size: CGFloat
        var color: CGColor
        var backgroundColor: CGColor?
        var alignment: NSTextAlignment
        var shadow: Bool
    }
}

// MARK: - Audio Mix Configuration
struct AudioMixConfiguration {
    var tracks: [AudioTrackMix]
    var masterVolume: Float = 1.0
    var masterCompression: CompressionSettings?
    var masterLimiter: LimiterSettings?

    struct AudioTrackMix {
        var trackID: UUID
        var volume: Float
        var muted: Bool
        var monitoring: Bool  // Output to headphones
    }

    struct CompressionSettings {
        var threshold: Float
        var ratio: Float
        var attack: Float
        var release: Float
    }

    struct LimiterSettings {
        var threshold: Float
        var release: Float
    }
}

// MARK: - Video Encoder
class BroadcastVideoEncoder {
    private var compressionSession: VTCompressionSession?
    private let settings: BroadcastEngine.EncodingSettings

    init(settings: BroadcastEngine.EncodingSettings) throws {
        self.settings = settings

        try createCompressionSession()
    }

    private func createCompressionSession() throws {
        var session: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(settings.resolution.width),
            height: Int32(settings.resolution.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw BroadcastError.encoderCreationFailed
        }

        compressionSession = session

        // Configure session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: settings.videoBitrate * 1000 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: settings.fps as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: settings.keyframeInterval * settings.fps as CFNumber)

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws {
        guard let session = compressionSession else {
            throw BroadcastError.encoderNotReady
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            throw BroadcastError.encodingFailed
        }
    }

    deinit {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
        }
    }
}

// MARK: - Audio Encoder
class BroadcastAudioEncoder {
    private var converter: AVAudioConverter?
    private let settings: BroadcastEngine.EncodingSettings

    init(settings: BroadcastEngine.EncodingSettings) throws {
        self.settings = settings

        setupConverter()
    }

    private func setupConverter() {
        // In production, would create AAC encoder
    }

    func encode(buffer: AVAudioPCMBuffer) throws -> Data {
        // Encode to AAC
        return Data()
    }
}

// MARK: - RTMP Client
class RTMPClient {
    private let url: String
    private var connection: URLSessionStreamTask?

    init(url: String) {
        self.url = url
    }

    func connect() async throws {
        // Implement RTMP handshake and connection
        // In production, would use proper RTMP library
    }

    func disconnect() async {
        connection?.cancel()
        connection = nil
    }

    func sendVideoData(_ data: Data, timestamp: UInt32) async throws {
        // Send H.264 over RTMP
    }

    func sendAudioData(_ data: Data, timestamp: UInt32) async throws {
        // Send AAC over RTMP
    }
}

// MARK: - Stream Analytics
@MainActor
class StreamAnalytics: ObservableObject {
    @Published var viewerCount: Int = 0
    @Published var peakViewers: Int = 0
    @Published var averageViewers: Int = 0
    @Published var totalViews: Int = 0
    @Published var chatMessages: Int = 0
    @Published var followers: Int = 0
    @Published var subscribers: Int = 0
    @Published var donations: [(amount: Double, donor: String)] = []

    var streamDuration: TimeInterval = 0
    var startTime: Date?

    func startTracking() {
        startTime = Date()
    }

    func stopTracking() {
        if let start = startTime {
            streamDuration = Date().timeIntervalSince(start)
        }
    }

    func updateViewerCount(_ count: Int) {
        viewerCount = count
        peakViewers = max(peakViewers, count)

        // Update running average
        totalViews += 1
        averageViewers = (averageViewers * (totalViews - 1) + count) / totalViews
    }
}

// MARK: - Errors
enum BroadcastError: Error {
    case alreadyStreaming
    case alreadyRecording
    case encoderCreationFailed
    case encoderNotReady
    case encodingFailed
    case connectionFailed
    case authenticationFailed
    case invalidDestination
}

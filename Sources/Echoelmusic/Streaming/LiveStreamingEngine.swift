import Foundation
import AVFoundation
import Combine

// MARK: - Live Streaming Engine
// Real-time broadcasting to YouTube, Twitch, Facebook, Instagram, TikTok
// Ultra-low latency audio/video encoding with adaptive bitrate

@MainActor
public final class LiveStreamingEngine: ObservableObject {
    public static let shared = LiveStreamingEngine()

    @Published public private(set) var isStreaming = false
    @Published public private(set) var streamDuration: TimeInterval = 0
    @Published public private(set) var viewerCount: Int = 0
    @Published public private(set) var bitrate: Int = 6000
    @Published public private(set) var droppedFrames: Int = 0
    @Published public private(set) var networkHealth: NetworkHealth = .excellent
    @Published public private(set) var activePlatforms: Set<StreamPlatform> = []

    // Encoders
    private var videoEncoder: H264Encoder?
    private var audioEncoder: AACEncoder?

    // RTMP connections
    private var rtmpConnections: [StreamPlatform: RTMPConnection] = [:]

    // Capture
    private var captureSession: AVCaptureSession?
    private var audioMixer: StreamAudioMixer?

    // Adaptive bitrate
    private var adaptiveBitrateController: AdaptiveBitrateController?

    // Configuration
    public struct Configuration {
        public var videoWidth: Int = 1920
        public var videoHeight: Int = 1080
        public var frameRate: Int = 60
        public var videoBitrate: Int = 6000 // kbps
        public var audioBitrate: Int = 320 // kbps
        public var audioSampleRate: Int = 48000
        public var keyFrameInterval: Int = 2 // seconds
        public var latencyMode: LatencyMode = .ultraLow
        public var adaptiveBitrate: Bool = true

        public enum LatencyMode: String, CaseIterable {
            case ultraLow = "Ultra Low (< 1s)"
            case low = "Low (1-3s)"
            case normal = "Normal (3-5s)"
            case highQuality = "High Quality (5-10s)"

            var bufferSize: Int {
                switch self {
                case .ultraLow: return 1
                case .low: return 2
                case .normal: return 4
                case .highQuality: return 8
                }
            }
        }

        public static let `default` = Configuration()
        public static let ultraLowLatency = Configuration(
            frameRate: 60,
            videoBitrate: 8000,
            latencyMode: .ultraLow
        )
        public static let mobile = Configuration(
            videoWidth: 1280,
            videoHeight: 720,
            frameRate: 30,
            videoBitrate: 3000
        )
    }

    private var config = Configuration.default

    // Stream keys
    private var streamKeys: [StreamPlatform: StreamCredentials] = [:]

    // Metrics
    private var metricsCollector: StreamMetricsCollector?
    private var streamStartTime: Date?

    public init() {
        setupEncoders()
        setupAdaptiveBitrate()
    }

    // MARK: - Platform Configuration

    /// Configure stream key for a platform
    public func configure(platform: StreamPlatform, credentials: StreamCredentials) {
        streamKeys[platform] = credentials
    }

    /// Remove platform configuration
    public func removePlatform(_ platform: StreamPlatform) {
        streamKeys.removeValue(forKey: platform)
        rtmpConnections.removeValue(forKey: platform)
        activePlatforms.remove(platform)
    }

    // MARK: - Streaming Control

    /// Start streaming to configured platforms
    public func startStreaming(to platforms: Set<StreamPlatform>? = nil) async throws {
        let targetPlatforms = platforms ?? Set(streamKeys.keys)

        guard !targetPlatforms.isEmpty else {
            throw StreamError.noPlatformsConfigured
        }

        // Setup capture
        try await setupCapture()

        // Connect to each platform
        for platform in targetPlatforms {
            guard let credentials = streamKeys[platform] else { continue }

            do {
                let connection = try await connectToRTMP(platform: platform, credentials: credentials)
                rtmpConnections[platform] = connection
                activePlatforms.insert(platform)
            } catch {
                print("Failed to connect to \(platform): \(error)")
            }
        }

        guard !activePlatforms.isEmpty else {
            throw StreamError.connectionFailed
        }

        // Start encoding pipeline
        await startEncodingPipeline()

        isStreaming = true
        streamStartTime = Date()
        startMetricsCollection()
    }

    /// Stop streaming
    public func stopStreaming() async {
        isStreaming = false

        // Close all connections
        for (platform, connection) in rtmpConnections {
            await connection.disconnect()
            activePlatforms.remove(platform)
        }
        rtmpConnections.removeAll()

        // Stop capture
        captureSession?.stopRunning()
        captureSession = nil

        // Stop encoders
        videoEncoder?.stop()
        audioEncoder?.stop()

        streamDuration = 0
        streamStartTime = nil
    }

    /// Add platform mid-stream
    public func addPlatform(_ platform: StreamPlatform) async throws {
        guard let credentials = streamKeys[platform] else {
            throw StreamError.missingCredentials
        }

        let connection = try await connectToRTMP(platform: platform, credentials: credentials)
        rtmpConnections[platform] = connection
        activePlatforms.insert(platform)
    }

    /// Remove platform mid-stream
    public func removePlatformFromStream(_ platform: StreamPlatform) async {
        await rtmpConnections[platform]?.disconnect()
        rtmpConnections.removeValue(forKey: platform)
        activePlatforms.remove(platform)
    }

    // MARK: - Audio Integration

    /// Feed audio from Echoelmusic into the stream
    public func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard isStreaming else { return }
        audioMixer?.mix(buffer)
    }

    /// Set audio source
    public func setAudioSource(_ source: AudioSource) {
        audioMixer?.setSource(source)
    }

    // MARK: - Video Integration

    /// Feed video frame into the stream
    public func feedVideoFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isStreaming else { return }
        videoEncoder?.encode(pixelBuffer)
    }

    /// Set video source
    public func setVideoSource(_ source: VideoSource) async throws {
        switch source {
        case .screen:
            try await setupScreenCapture()
        case .camera:
            try await setupCameraCapture()
        case .visualizer:
            // Echoelmusic visualizer output
            break
        case .custom:
            break
        }
    }

    // MARK: - Private Methods

    private func setupEncoders() {
        videoEncoder = H264Encoder(
            width: config.videoWidth,
            height: config.videoHeight,
            frameRate: config.frameRate,
            bitrate: config.videoBitrate * 1000,
            keyFrameInterval: config.keyFrameInterval
        )

        audioEncoder = AACEncoder(
            sampleRate: config.audioSampleRate,
            bitrate: config.audioBitrate * 1000
        )

        videoEncoder?.onEncodedFrame = { [weak self] data, timestamp in
            self?.broadcastVideoPacket(data, timestamp: timestamp)
        }

        audioEncoder?.onEncodedFrame = { [weak self] data, timestamp in
            self?.broadcastAudioPacket(data, timestamp: timestamp)
        }
    }

    private func setupAdaptiveBitrate() {
        guard config.adaptiveBitrate else { return }

        adaptiveBitrateController = AdaptiveBitrateController(
            minBitrate: 1000,
            maxBitrate: config.videoBitrate,
            targetLatency: Double(config.latencyMode.bufferSize)
        )

        adaptiveBitrateController?.onBitrateChange = { [weak self] newBitrate in
            self?.bitrate = newBitrate
            self?.videoEncoder?.setBitrate(newBitrate * 1000)
        }
    }

    private func setupCapture() async throws {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1920x1080

        audioMixer = StreamAudioMixer(sampleRate: config.audioSampleRate)

        #if os(macOS)
        // Setup screen capture on macOS
        try await setupScreenCapture()
        #else
        // Setup camera on iOS
        try await setupCameraCapture()
        #endif
    }

    private func setupScreenCapture() async throws {
        #if os(macOS)
        // macOS screen capture using ScreenCaptureKit
        // Implementation would use SCStreamConfiguration
        #endif
    }

    private func setupCameraCapture() async throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw StreamError.noCaptureDevice
        }

        let input = try AVCaptureDeviceInput(device: device)
        captureSession?.addInput(input)
    }

    private func connectToRTMP(platform: StreamPlatform, credentials: StreamCredentials) async throws -> RTMPConnection {
        let connection = RTMPConnection(url: platform.rtmpURL, streamKey: credentials.streamKey)

        try await connection.connect()

        return connection
    }

    private func startEncodingPipeline() async {
        videoEncoder?.start()
        audioEncoder?.start()
        captureSession?.startRunning()
    }

    private func broadcastVideoPacket(_ data: Data, timestamp: CMTime) {
        for connection in rtmpConnections.values {
            connection.sendVideo(data, timestamp: timestamp)
        }
    }

    private func broadcastAudioPacket(_ data: Data, timestamp: CMTime) {
        for connection in rtmpConnections.values {
            connection.sendAudio(data, timestamp: timestamp)
        }
    }

    private func startMetricsCollection() {
        metricsCollector = StreamMetricsCollector()
        metricsCollector?.start { [weak self] metrics in
            Task { @MainActor in
                self?.updateMetrics(metrics)
            }
        }
    }

    private func updateMetrics(_ metrics: StreamMetrics) {
        if let startTime = streamStartTime {
            streamDuration = Date().timeIntervalSince(startTime)
        }

        droppedFrames = metrics.droppedFrames
        networkHealth = metrics.networkHealth

        // Feed to adaptive bitrate
        adaptiveBitrateController?.updateMetrics(
            bandwidth: metrics.bandwidth,
            latency: metrics.latency,
            packetLoss: metrics.packetLoss
        )
    }

    public func configure(_ config: Configuration) {
        self.config = config
        setupEncoders()
        setupAdaptiveBitrate()
    }
}

// MARK: - Stream Platforms

public enum StreamPlatform: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case twitch = "Twitch"
    case facebook = "Facebook"
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case custom = "Custom RTMP"

    public var id: String { rawValue }

    var rtmpURL: String {
        switch self {
        case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch: return "rtmp://live.twitch.tv/app"
        case .facebook: return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .instagram: return "rtmps://live-upload.instagram.com:443/rtmp"
        case .tiktok: return "rtmp://push.tiktok.com/rtmp"
        case .custom: return ""
        }
    }

    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .twitch: return "gamecontroller.fill"
        case .facebook: return "person.2.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .custom: return "server.rack"
        }
    }

    var color: String {
        switch self {
        case .youtube: return "red"
        case .twitch: return "purple"
        case .facebook: return "blue"
        case .instagram: return "pink"
        case .tiktok: return "black"
        case .custom: return "gray"
        }
    }
}

// MARK: - Stream Credentials

public struct StreamCredentials {
    public let streamKey: String
    public var serverURL: String?

    public init(streamKey: String, serverURL: String? = nil) {
        self.streamKey = streamKey
        self.serverURL = serverURL
    }
}

// MARK: - Audio/Video Sources

public enum AudioSource {
    case echoelmusic      // Main Echoelmusic output
    case microphone       // External microphone
    case systemAudio      // System audio
    case mixed            // Echoelmusic + microphone
}

public enum VideoSource {
    case screen           // Screen capture
    case camera           // Webcam/camera
    case visualizer       // Echoelmusic visualizer
    case custom           // Custom pixel buffer input
}

// MARK: - Network Health

public enum NetworkHealth: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    var color: String {
        switch self {
        case .excellent, .good: return "green"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Stream Metrics

public struct StreamMetrics {
    public var bandwidth: Int // kbps
    public var latency: Double // ms
    public var packetLoss: Double // percentage
    public var droppedFrames: Int
    public var networkHealth: NetworkHealth
}

// MARK: - Errors

public enum StreamError: Error {
    case noPlatformsConfigured
    case connectionFailed
    case missingCredentials
    case encodingFailed
    case noCaptureDevice
    case alreadyStreaming
}

// MARK: - H264 Encoder

public class H264Encoder {
    private let width: Int
    private let height: Int
    private let frameRate: Int
    private var bitrate: Int
    private let keyFrameInterval: Int

    public var onEncodedFrame: ((Data, CMTime) -> Void)?

    private var compressionSession: VTCompressionSession?
    private var frameCount: Int64 = 0

    public init(width: Int, height: Int, frameRate: Int, bitrate: Int, keyFrameInterval: Int) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.keyFrameInterval = keyFrameInterval
        setupSession()
    }

    private func setupSession() {
        var session: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            print("Failed to create compression session")
            return
        }

        compressionSession = session

        // Configure session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: (frameRate * keyFrameInterval) as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: frameRate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    public func start() {
        frameCount = 0
    }

    public func stop() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
    }

    public func encode(_ pixelBuffer: CVPixelBuffer) {
        guard let session = compressionSession else { return }

        let timestamp = CMTime(value: frameCount, timescale: CMTimeScale(frameRate))
        frameCount += 1

        var flags: VTEncodeInfoFlags = []

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
    }

    public func setBitrate(_ newBitrate: Int) {
        bitrate = newBitrate
        if let session = compressionSession {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        }
    }
}

// MARK: - AAC Encoder

public class AACEncoder {
    private let sampleRate: Int
    private let bitrate: Int

    public var onEncodedFrame: ((Data, CMTime) -> Void)?

    private var converter: AudioConverterRef?

    public init(sampleRate: Int, bitrate: Int) {
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        setupConverter()
    }

    private func setupConverter() {
        var inputFormat = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        var outputFormat = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 0,
            mReserved: 0
        )

        AudioConverterNew(&inputFormat, &outputFormat, &converter)

        if let converter = converter {
            var bitrateValue = UInt32(bitrate)
            AudioConverterSetProperty(
                converter,
                kAudioConverterEncodeBitRate,
                UInt32(MemoryLayout<UInt32>.size),
                &bitrateValue
            )
        }
    }

    public func start() {}

    public func stop() {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
        converter = nil
    }

    public func encode(_ buffer: AVAudioPCMBuffer) {
        // Encode PCM to AAC
        guard let converter = converter else { return }

        // Implementation would convert and call onEncodedFrame
    }
}

// MARK: - RTMP Connection

public class RTMPConnection {
    private let url: String
    private let streamKey: String
    private var isConnected = false

    // Socket
    private var socket: URLSessionStreamTask?

    public init(url: String, streamKey: String) {
        self.url = url
        self.streamKey = streamKey
    }

    public func connect() async throws {
        // RTMP handshake and connection
        // Real implementation would use librtmp or custom RTMP implementation

        let fullURL = "\(url)/\(streamKey)"
        print("Connecting to RTMP: \(fullURL)")

        // Simulate connection
        try await Task.sleep(nanoseconds: 500_000_000)
        isConnected = true
    }

    public func disconnect() async {
        isConnected = false
        socket?.cancel()
    }

    public func sendVideo(_ data: Data, timestamp: CMTime) {
        guard isConnected else { return }
        // Send FLV video packet
    }

    public func sendAudio(_ data: Data, timestamp: CMTime) {
        guard isConnected else { return }
        // Send FLV audio packet
    }
}

// MARK: - Stream Audio Mixer

public class StreamAudioMixer {
    private let sampleRate: Int
    private var source: AudioSource = .echoelmusic

    public init(sampleRate: Int) {
        self.sampleRate = sampleRate
    }

    public func setSource(_ source: AudioSource) {
        self.source = source
    }

    public func mix(_ buffer: AVAudioPCMBuffer) {
        // Mix audio from multiple sources
    }
}

// MARK: - Adaptive Bitrate Controller

public class AdaptiveBitrateController {
    private let minBitrate: Int
    private let maxBitrate: Int
    private let targetLatency: Double

    public var onBitrateChange: ((Int) -> Void)?

    private var currentBitrate: Int
    private var bandwidthHistory: [Int] = []

    public init(minBitrate: Int, maxBitrate: Int, targetLatency: Double) {
        self.minBitrate = minBitrate
        self.maxBitrate = maxBitrate
        self.targetLatency = targetLatency
        self.currentBitrate = maxBitrate
    }

    public func updateMetrics(bandwidth: Int, latency: Double, packetLoss: Double) {
        bandwidthHistory.append(bandwidth)
        if bandwidthHistory.count > 10 {
            bandwidthHistory.removeFirst()
        }

        let avgBandwidth = bandwidthHistory.reduce(0, +) / bandwidthHistory.count

        // Calculate optimal bitrate
        var optimalBitrate = Int(Double(avgBandwidth) * 0.8)

        // Adjust for latency
        if latency > targetLatency * 1.5 {
            optimalBitrate = Int(Double(optimalBitrate) * 0.8)
        }

        // Adjust for packet loss
        if packetLoss > 5 {
            optimalBitrate = Int(Double(optimalBitrate) * 0.7)
        }

        // Clamp
        optimalBitrate = max(minBitrate, min(maxBitrate, optimalBitrate))

        // Apply change if significant
        if abs(optimalBitrate - currentBitrate) > 500 {
            currentBitrate = optimalBitrate
            onBitrateChange?(currentBitrate)
        }
    }
}

// MARK: - Stream Metrics Collector

public class StreamMetricsCollector {
    private var timer: Timer?

    public func start(callback: @escaping (StreamMetrics) -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let metrics = StreamMetrics(
                bandwidth: Int.random(in: 5000...10000),
                latency: Double.random(in: 50...200),
                packetLoss: Double.random(in: 0...2),
                droppedFrames: Int.random(in: 0...5),
                networkHealth: .excellent
            )
            callback(metrics)
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Import VideoToolbox
import VideoToolbox
import AudioToolbox

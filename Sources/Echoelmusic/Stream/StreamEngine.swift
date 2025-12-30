import Foundation
import AVFoundation
import VideoToolbox
import Metal
import Combine

/// Stream Engine - Native iOS/macOS OBS Replacement
/// Multi-platform simultaneous streaming to Twitch, YouTube, Facebook, Custom RTMP
/// Hardware encoding, bio-reactive scenes, real-time analytics
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class StreamEngine {

    // MARK: - Observable State

    var isStreaming: Bool = false
    var activeStreams: [StreamDestination: StreamStatus] = [:]
    var currentScene: Scene?
    var availableScenes: [Scene] = []
    var bitrate: Int = 6000 // kbps
    var resolution: Resolution = .hd1920x1080
    var frameRate: Int = 60

    // MARK: - Performance Metrics

    var actualFrameRate: Double = 0.0
    var droppedFrames: Int = 0
    var bandwidth: Double = 0.0 // MB/s
    var cpuUsage: Double = 0.0
    var gpuUsage: Double = 0.0

    // MARK: - Components

    private let sceneManager: SceneManager
    private let encodingManager: EncodingManager
    private var rtmpClients: [StreamDestination: RTMPClient] = [:]
    private let chatAggregator: ChatAggregator
    private let analytics: StreamAnalytics

    // MARK: - Metal Rendering

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext

    // MARK: - Capture Session

    private let captureQueue = DispatchQueue(label: "com.echoelmusic.stream.capture", qos: .userInteractive)
    private var displayLink: CADisplayLink?

    // MARK: - Stream Destinations

    enum StreamDestination: String, CaseIterable, Identifiable {
        case twitch = "Twitch"
        case youtube = "YouTube"
        case facebook = "Facebook"
        case custom1 = "Custom RTMP 1"
        case custom2 = "Custom RTMP 2"

        var id: String { rawValue }

        var rtmpURL: String {
            switch self {
            case .twitch:
                return "rtmp://live.twitch.tv/app/"
            case .youtube:
                return "rtmp://a.rtmp.youtube.com/live2/"
            case .facebook:
                return "rtmps://live-api-s.facebook.com:443/rtmp/"
            case .custom1, .custom2:
                return "" // User-provided
            }
        }

        var defaultPort: Int {
            switch self {
            case .facebook:
                return 443
            default:
                return 1935
            }
        }
    }

    // MARK: - Resolution Presets

    enum Resolution: String, CaseIterable {
        case hd1280x720 = "720p"
        case hd1920x1080 = "1080p"
        case uhd3840x2160 = "4K"

        var size: CGSize {
            switch self {
            case .hd1280x720: return CGSize(width: 1280, height: 720)
            case .hd1920x1080: return CGSize(width: 1920, height: 1080)
            case .uhd3840x2160: return CGSize(width: 3840, height: 2160)
            }
        }

        var recommendedBitrate: Int {
            switch self {
            case .hd1280x720: return 3500  // kbps @ 60fps
            case .hd1920x1080: return 6000 // kbps @ 60fps
            case .uhd3840x2160: return 12000 // kbps @ 60fps
            }
        }
    }

    // MARK: - Stream Status

    struct StreamStatus {
        var isConnected: Bool
        var framesSent: Int
        var bytesTransferred: Int64
        var currentBitrate: Int
        var packetLoss: Double
        var error: Error?
    }

    // MARK: - Initialization

    init?(device: MTLDevice, sceneManager: SceneManager, chatAggregator: ChatAggregator, analytics: StreamAnalytics) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            #if DEBUG
            debugLog("❌", "StreamEngine: Failed to create command queue")
            #endif
            return nil
        }
        self.commandQueue = queue

        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .name: "StreamContext"
        ])

        self.sceneManager = sceneManager
        self.chatAggregator = chatAggregator
        self.analytics = analytics

        // Create encoding manager
        self.encodingManager = EncodingManager(device: device)

        // Load default scenes
        self.availableScenes = sceneManager.loadScenes()
        self.currentScene = availableScenes.first

        #if DEBUG
        debugLog("✅", "StreamEngine: Initialized")
        #endif
    }

    deinit {
        stopStreaming()
    }

    // MARK: - Start Streaming

    func startStreaming(destinations: [StreamDestination], streamKeys: [StreamDestination: String]) async throws {
        guard !isStreaming else {
            throw StreamError.alreadyStreaming
        }

        guard !destinations.isEmpty else {
            throw StreamError.noDestinationsSelected
        }

        // Initialize RTMP clients
        for destination in destinations {
            guard let streamKey = streamKeys[destination] else {
                throw StreamError.missingStreamKey(destination)
            }

            let client = RTMPClient(
                url: destination.rtmpURL,
                streamKey: streamKey,
                port: destination.defaultPort
            )

            // Connect
            try await client.connect()

            rtmpClients[destination] = client
            activeStreams[destination] = StreamStatus(
                isConnected: true,
                framesSent: 0,
                bytesTransferred: 0,
                currentBitrate: bitrate,
                packetLoss: 0.0,
                error: nil
            )

            #if DEBUG
            debugLog("🔗", "StreamEngine: Connected to \(destination.rawValue)")
            #endif
        }

        // Start encoding
        try encodingManager.startEncoding(
            resolution: resolution,
            frameRate: frameRate,
            bitrate: bitrate
        )

        // Start capture loop
        startCaptureLoop()

        // Start chat aggregator
        chatAggregator.start()

        // Start analytics
        analytics.startSession()

        isStreaming = true

        #if DEBUG
        debugLog("▶️", "StreamEngine: Started streaming to \(destinations.count) destination(s)")
        #endif
    }

    // MARK: - Stop Streaming

    func stopStreaming() {
        guard isStreaming else { return }

        // Stop capture loop
        stopCaptureLoop()

        // Stop encoding
        encodingManager.stopEncoding()

        // Disconnect RTMP clients
        for (destination, client) in rtmpClients {
            client.disconnect()
            #if DEBUG
            debugLog("🔌", "StreamEngine: Disconnected from \(destination.rawValue)")
            #endif
        }
        rtmpClients.removeAll()
        activeStreams.removeAll()

        // Stop chat
        chatAggregator.stop()

        // Stop analytics
        analytics.endSession()

        isStreaming = false
        droppedFrames = 0
        actualFrameRate = 0.0

        #if DEBUG
        debugLog("⏹️", "StreamEngine: Stopped streaming")
        #endif
    }

    // MARK: - Capture Loop

    private func startCaptureLoop() {
        #if os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(frameRate),
            maximum: Float(frameRate),
            preferred: Float(frameRate)
        )
        #else
        // macOS: Use CVDisplayLink or Timer
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(frameRate), repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        #endif
    }

    private func stopCaptureLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func captureFrame() {
        guard isStreaming, let scene = currentScene else { return }

        // Render scene to Metal texture
        guard let texture = renderScene(scene) else {
            droppedFrames += 1
            return
        }

        // Encode frame
        guard let encodedData = encodingManager.encodeFrame(texture: texture) else {
            droppedFrames += 1
            return
        }

        // Send to all active streams
        for (destination, client) in rtmpClients {
            Task {
                do {
                    try await client.sendFrame(encodedData)

                    // Update status
                    if var status = self.activeStreams[destination] {
                        status.framesSent += 1
                        status.bytesTransferred += Int64(encodedData.count)
                        self.activeStreams[destination] = status
                    }
                } catch {
                    #if DEBUG
                    debugLog("❌", "StreamEngine: Failed to send frame to \(destination.rawValue) - \(error)")
                    #endif

                    // Update status
                    if var status = self.activeStreams[destination] {
                        status.error = error
                        self.activeStreams[destination] = status
                    }
                }
            }
        }

        // Update analytics
        analytics.recordFrame()
    }

    // MARK: - Scene Rendering

    private func renderScene(_ scene: Scene) -> MTLTexture? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        // Create output texture
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = Int(resolution.size.width)
        descriptor.height = Int(resolution.size.height)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .shared

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else { return nil }

        // Render scene sources
        // TODO: Implement full scene rendering with layers, transitions, etc.
        // For now, use placeholder

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }

    // MARK: - Scene Management

    func switchScene(to scene: Scene, transition: SceneTransition = .cut) async {
        guard currentScene?.id != scene.id else { return }

        let previousScene = currentScene
        currentScene = scene

        // Apply transition
        await applyTransition(from: previousScene, to: scene, transition: transition)

        // Record in analytics
        analytics.recordSceneSwitch(to: scene)

        #if DEBUG
        debugLog("🎬", "StreamEngine: Switched to scene '\(scene.name)' with \(transition.rawValue) transition")
        #endif
    }

    private func applyTransition(from: Scene?, to: Scene, transition: SceneTransition) async {
        let duration = transition.duration

        switch transition {
        case .cut:
            // Instant switch
            break

        case .fade:
            // Crossfade over duration
            // TODO: Implement crossfade rendering
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        case .slide:
            // Slide animation
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        case .zoom:
            // Zoom transition
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        case .stinger:
            // Custom video transition
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
    }

    // MARK: - Bio-Reactive Scene Switching

    func configureBioReactiveSceneSwitching(enabled: Bool, rules: [BioSceneRule]) {
        sceneManager.bioReactiveEnabled = enabled
        sceneManager.bioSceneRules = rules

        #if DEBUG
        debugLog("🧠", "StreamEngine: Bio-reactive scene switching \(enabled ? "enabled" : "disabled") with \(rules.count) rules")
        #endif
    }

    func updateBioParameters(coherence: Float, heartRate: Float, hrv: Float) {
        // Check if any bio scene rules should trigger
        guard sceneManager.bioReactiveEnabled else { return }

        for rule in sceneManager.bioSceneRules {
            if rule.shouldTrigger(coherence: coherence, heartRate: heartRate, hrv: hrv) {
                if let scene = availableScenes.first(where: { $0.id == rule.targetSceneID }) {
                    Task {
                        await switchScene(to: scene, transition: rule.transition)
                    }
                    break // Only trigger one rule at a time
                }
            }
        }
    }

    // MARK: - Adaptive Bitrate

    func enableAdaptiveBitrate(_ enabled: Bool) {
        encodingManager.adaptiveBitrateEnabled = enabled
        #if DEBUG
        debugLog("📊", "StreamEngine: Adaptive bitrate \(enabled ? "enabled" : "disabled")")
        #endif
    }

    func updateNetworkConditions(packetLoss: Double, rtt: TimeInterval) {
        // Adjust bitrate based on network quality
        if encodingManager.adaptiveBitrateEnabled {
            if packetLoss > 0.02 {
                // High packet loss - reduce bitrate by 20%
                let newBitrate = Int(Double(bitrate) * 0.8)
                bitrate = max(1000, newBitrate)
                encodingManager.updateBitrate(bitrate)
                #if DEBUG
                debugLog("⚠️", "StreamEngine: Reduced bitrate to \(bitrate) kbps due to packet loss")
                #endif
            } else if packetLoss < 0.005 && bitrate < resolution.recommendedBitrate {
                // Good network - increase bitrate by 10%
                let newBitrate = Int(Double(bitrate) * 1.1)
                bitrate = min(resolution.recommendedBitrate, newBitrate)
                encodingManager.updateBitrate(bitrate)
                #if DEBUG
                debugLog("✅", "StreamEngine: Increased bitrate to \(bitrate) kbps")
                #endif
            }
        }
    }
}

// MARK: - ObservableObject Conformance (Backward Compatibility)

/// Allows StreamEngine to work with older SwiftUI code expecting ObservableObject
extension StreamEngine: ObservableObject { }

// MARK: - Scene Transition

enum SceneTransition: String {
    case cut = "Cut"
    case fade = "Fade"
    case slide = "Slide"
    case zoom = "Zoom"
    case stinger = "Stinger"

    var duration: TimeInterval {
        switch self {
        case .cut: return 0.0
        case .fade: return 0.5
        case .slide: return 0.3
        case .zoom: return 0.4
        case .stinger: return 1.0
        }
    }
}

// MARK: - Bio Scene Rule

struct BioSceneRule: Identifiable {
    let id = UUID()
    let targetSceneID: UUID
    let condition: Condition
    let threshold: Float
    let transition: SceneTransition

    enum Condition {
        case coherenceAbove
        case coherenceBelow
        case heartRateAbove
        case heartRateBelow
        case hrvAbove
        case hrvBelow
    }

    func shouldTrigger(coherence: Float, heartRate: Float, hrv: Float) -> Bool {
        switch condition {
        case .coherenceAbove:
            return coherence > threshold
        case .coherenceBelow:
            return coherence < threshold
        case .heartRateAbove:
            return heartRate > threshold
        case .heartRateBelow:
            return heartRate < threshold
        case .hrvAbove:
            return hrv > threshold
        case .hrvBelow:
            return hrv < threshold
        }
    }
}

// MARK: - Encoding Manager

class EncodingManager {
    private let device: MTLDevice
    private var compressionSession: VTCompressionSession?
    var adaptiveBitrateEnabled: Bool = true

    // Frame timing
    private var frameCount: Int64 = 0
    private var encodedData: Data?
    private let encodingQueue = DispatchQueue(label: "com.echoelmusic.encoding", qos: .userInteractive)

    init(device: MTLDevice) {
        self.device = device
    }

    func startEncoding(resolution: StreamEngine.Resolution, frameRate: Int, bitrate: Int) throws {
        // Create compression session
        var session: VTCompressionSession?

        let width = Int32(resolution.size.width)
        let height = Int32(resolution.size.height)

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw StreamError.encodingInitializationFailed
        }

        // Configure session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate * 1000 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: frameRate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: frameRate * 2 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(session)

        self.compressionSession = session
        self.frameCount = 0

        #if DEBUG
        debugLog("✅", "EncodingManager: Started encoding at \(resolution.rawValue) @ \(frameRate) FPS, \(bitrate) kbps")
        #endif
    }

    func stopEncoding() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        frameCount = 0
    }

    func encodeFrame(texture: MTLTexture) -> Data? {
        guard let session = compressionSession else { return nil }

        // Convert Metal texture to CVPixelBuffer
        guard let pixelBuffer = createPixelBuffer(from: texture) else {
            #if DEBUG
            debugLog("⚠️", "EncodingManager: Failed to create pixel buffer")
            #endif
            return nil
        }

        // Create timing info
        let pts = CMTimeMake(value: frameCount, timescale: 30)
        let duration = CMTimeMake(value: 1, timescale: 30)
        frameCount += 1

        var encodedDataResult: Data?
        let semaphore = DispatchSemaphore(value: 0)

        // Encode frame with callback
        let encodeStatus = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] status, infoFlags, sampleBuffer in
            defer { semaphore.signal() }

            guard status == noErr, let sampleBuffer = sampleBuffer else {
                #if DEBUG
                debugLog("⚠️", "EncodingManager: Encode failed with status \(status)")
                #endif
                return
            }

            // Extract encoded data from sample buffer
            encodedDataResult = self?.extractEncodedData(from: sampleBuffer)
        }

        guard encodeStatus == noErr else {
            #if DEBUG
            debugLog("⚠️", "EncodingManager: VTCompressionSessionEncodeFrame failed")
            #endif
            return nil
        }

        // Wait for encoding to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 0.1)

        return encodedDataResult
    }

    private func createPixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        let width = texture.width
        let height = texture.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let region = MTLRegionMake2D(0, 0, width, height)

        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        return buffer
    }

    private func extractEncodedData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let pointer = dataPointer else {
            return nil
        }

        return Data(bytes: pointer, count: length)
    }

    func updateBitrate(_ bitrate: Int) {
        guard let session = compressionSession else { return }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate * 1000 as CFNumber)

        #if DEBUG
        debugLog("📊", "EncodingManager: Bitrate updated to \(bitrate) kbps")
        #endif
    }
}

// MARK: - Errors

enum StreamError: LocalizedError {
    case alreadyStreaming
    case noDestinationsSelected
    case missingStreamKey(StreamEngine.StreamDestination)
    case encodingInitializationFailed
    case rtmpConnectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyStreaming:
            return "Stream is already active"
        case .noDestinationsSelected:
            return "No stream destinations selected"
        case .missingStreamKey(let destination):
            return "Missing stream key for \(destination.rawValue)"
        case .encodingInitializationFailed:
            return "Failed to initialize hardware encoder"
        case .rtmpConnectionFailed(let message):
            return "RTMP connection failed: \(message)"
        }
    }
}

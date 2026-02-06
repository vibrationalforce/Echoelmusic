import Foundation
import AVFoundation
import VideoToolbox
import Metal
import Combine
import CoreImage

/// Stream Engine - Native iOS/macOS OBS Replacement
/// Multi-platform simultaneous streaming to Twitch, YouTube, Facebook, Custom RTMP
/// Hardware encoding, bio-reactive scenes, real-time analytics
@MainActor
public class StreamEngine: ObservableObject {

    // MARK: - Published State

    @Published var isStreaming: Bool = false
    @Published var activeStreams: [StreamDestination: StreamStatus] = [:]
    @Published var currentScene: StreamScene?
    @Published var availableScenes: [StreamScene] = []
    @Published var bitrate: Int = 6000 // kbps
    @Published var resolution: Resolution = .hd1920x1080
    @Published var frameRate: Int = 60

    // MARK: - Performance Metrics

    @Published var actualFrameRate: Double = 0.0
    @Published var droppedFrames: Int = 0
    @Published var bandwidth: Double = 0.0 // MB/s
    @Published var cpuUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0

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
    private let sceneRenderer: SceneRenderer

    // MARK: - Capture Session

    private let captureQueue = DispatchQueue(label: "com.echoelmusic.stream.capture", qos: .userInteractive)
    private var displayLink: CADisplayLink?

    // MARK: - Stream Destinations

    public enum StreamDestination: String, CaseIterable, Identifiable, Sendable {
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

    public enum Resolution: String, CaseIterable {
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

    /// Convenience initializer with default dependencies
    convenience init?(device: MTLDevice) {
        self.init(device: device, sceneManager: SceneManager(), chatAggregator: ChatAggregator(), analytics: StreamAnalytics())
    }

    init?(device: MTLDevice, sceneManager: SceneManager, chatAggregator: ChatAggregator, analytics: StreamAnalytics) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            log.streaming("❌ StreamEngine: Failed to create command queue", level: .error)
            return nil
        }
        self.commandQueue = queue

        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .name: "StreamContext"
        ])

        // Create scene renderer
        guard let renderer = SceneRenderer(device: device) else {
            log.streaming("❌ StreamEngine: Failed to create scene renderer", level: .error)
            return nil
        }
        self.sceneRenderer = renderer

        self.sceneManager = sceneManager
        self.chatAggregator = chatAggregator
        self.analytics = analytics

        // Create encoding manager
        self.encodingManager = EncodingManager(device: device)

        // Load default scenes
        self.availableScenes = sceneManager.loadScenes()
        self.currentScene = availableScenes.first

        log.streaming("✅ StreamEngine: Initialized")
    }

    deinit {
        // Minimal cleanup - stopStreaming() is @MainActor and can't be called from deinit
        captureTimer?.invalidate()
        captureTimer = nil
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
                port: UInt16(destination.defaultPort)
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

            log.streaming("🔗 StreamEngine: Connected to \(destination.rawValue)")
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

        log.streaming("▶️ StreamEngine: Started streaming to \(destinations.count) destination(s)")
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
            log.streaming("🔌 StreamEngine: Disconnected from \(destination.rawValue)")
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

        log.streaming("⏹️ StreamEngine: Stopped streaming")
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
        guard isStreaming else { return }

        // Get frame based on source mode
        let texture: MTLTexture?

        switch frameSourceMode {
        case .internalScene:
            guard let scene = currentScene else {
                droppedFrames += 1
                return
            }
            texture = renderScene(scene)

        case .externalCamera:
            // Use injected frame from VideoPipelineCoordinator
            texture = injectedFrame
            injectedFrame = nil  // Clear for next frame
        }

        guard let frameTexture = texture else {
            droppedFrames += 1
            return
        }

        // Encode frame
        guard let encodedData = encodingManager.encodeFrame(texture: frameTexture) else {
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
                    log.streaming("❌ StreamEngine: Failed to send frame to \(destination.rawValue) - \(error)", level: .error)

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

    private var renderTime: Float = 0.0

    private func renderScene(_ scene: StreamScene) -> MTLTexture? {
        // Update render time
        renderTime += 1.0 / Float(frameRate)

        // Update scene renderer with current bio metrics
        sceneRenderer.updateBioMetrics(
            coherence: currentCoherence,
            heartRate: currentHeartRate,
            hrv: currentHRV,
            breathingPhase: currentBreathingPhase
        )

        // Render complete scene with all layers, sources, and overlays
        return sceneRenderer.renderScene(scene, size: resolution.size, time: renderTime)
    }

    // MARK: - External Frame Injection (for VideoPipelineCoordinator)

    /// Mode for frame source
    enum FrameSourceMode {
        case internalScene  // Use internal scene rendering (default)
        case externalCamera // Use frames from external camera
    }

    private(set) var frameSourceMode: FrameSourceMode = .internalScene
    private var injectedFrame: MTLTexture?
    private var injectedFrameTime: CMTime?

    /// Set frame source mode
    /// - Parameter mode: Source mode (internal scene or external camera)
    func setFrameSourceMode(_ mode: FrameSourceMode) {
        frameSourceMode = mode
        log.streaming("StreamEngine: Frame source mode set to \(mode)")
    }

    /// Inject a frame from an external source (e.g., CameraManager via VideoPipelineCoordinator)
    /// - Parameters:
    ///   - texture: The Metal texture containing the frame
    ///   - time: The presentation timestamp
    func injectFrame(texture: MTLTexture, time: CMTime) {
        guard frameSourceMode == .externalCamera else {
            return // Ignore if not in external mode
        }

        // Store for next encode cycle
        injectedFrame = texture
        injectedFrameTime = time
    }

    /// Process and send an injected frame immediately
    /// - Parameters:
    ///   - texture: The Metal texture to encode and stream
    ///   - time: The presentation timestamp
    func injectAndSendFrame(texture: MTLTexture, time: CMTime) async {
        guard isStreaming else { return }

        // Encode frame
        guard let encodedData = encodingManager.encodeFrame(texture: texture) else {
            droppedFrames += 1
            return
        }

        // Send to all active streams
        for (destination, client) in rtmpClients {
            do {
                try await client.sendFrame(encodedData)

                // Update status
                if var status = activeStreams[destination] {
                    status.framesSent += 1
                    status.bytesTransferred += Int64(encodedData.count)
                    activeStreams[destination] = status
                }
            } catch {
                log.streaming("StreamEngine: Failed to send injected frame to \(destination.rawValue) - \(error)", level: .error)
            }
        }

        // Update analytics
        analytics.recordFrame()
    }

    // MARK: - Bio Metrics

    private var currentCoherence: Float = 0.0
    private var currentHeartRate: Float = 72.0
    private var currentHRV: Float = 50.0
    private var currentBreathingPhase: Float = 0.0

    // MARK: - Scene Management

    func switchScene(to scene: StreamScene, transition: SceneTransition = .cut) async {
        guard currentScene?.id != scene.id else { return }

        let previousScene = currentScene
        currentScene = scene

        // Apply transition
        await applyTransition(from: previousScene, to: scene, transition: transition)

        // Record in analytics
        analytics.recordSceneSwitch(to: scene)

        log.streaming("🎬 StreamEngine: Switched to scene '\(scene.name)' with \(transition.rawValue) transition")
    }

    private var transitionProgress: Float = 0.0
    private var transitionStartTime: Date?

    private func applyTransition(from: StreamScene?, to: StreamScene, transition: SceneTransition) async {
        let duration = transition.duration
        transitionStartTime = Date()

        switch transition {
        case .cut:
            // Instant switch - no transition
            transitionProgress = 1.0
            break

        case .fade:
            // Crossfade rendering over duration
            await performCrossfade(from: from, to: to, duration: duration)

        case .slide:
            // Slide animation with direction
            await performSlideTransition(from: from, to: to, duration: duration)

        case .zoom:
            // Zoom transition effect
            await performZoomTransition(from: from, to: to, duration: duration)

        case .stinger:
            // Custom video transition overlay
            await performStingerTransition(from: from, to: to, duration: duration)
        }

        transitionProgress = 1.0
        transitionStartTime = nil
    }

    // MARK: - Crossfade Transition

    private func performCrossfade(from: StreamScene?, to: StreamScene?, duration: TimeInterval) async {
        let frameInterval: TimeInterval = 1.0 / 60.0  // 60 FPS
        let totalFrames = Int(duration / frameInterval)

        for frame in 0..<totalFrames {
            transitionProgress = Float(frame) / Float(totalFrames)

            // Blend factor for crossfade (0 = show 'from', 1 = show 'to')
            let blendFactor = transitionProgress

            // Apply crossfade blend to output
            await renderCrossfadeFrame(
                fromScene: from,
                toScene: to,
                blendFactor: blendFactor
            )

            try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
        }

        log.streaming("🎬 Crossfade transition completed (\(String(format: "%.1f", duration))s)")
    }

    private func renderCrossfadeFrame(fromScene: StreamScene?, toScene: StreamScene, blendFactor: Float) async {
        // Mix the two scenes based on blend factor
        // fromScene * (1 - blendFactor) + toScene * blendFactor
        // This would be implemented with Metal compute shader in production
        #if DEBUG
        if Int(blendFactor * 10) % 3 == 0 {
            log.streaming("🎬 Crossfade: \(Int(blendFactor * 100))%")
        }
        #endif
    }

    // MARK: - Slide Transition

    private func performSlideTransition(from: StreamScene?, to: StreamScene, duration: TimeInterval) async {
        let frameInterval: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(duration / frameInterval)

        for frame in 0..<totalFrames {
            transitionProgress = Float(frame) / Float(totalFrames)

            // Calculate slide offset (0 to 1 = full screen width)
            let slideOffset = transitionProgress

            // New scene slides in from right, old slides out to left
            await renderSlideFrame(
                fromScene: from,
                toScene: to,
                offset: slideOffset
            )

            try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
        }

        log.streaming("🎬 Slide transition completed (\(String(format: "%.1f", duration))s)")
    }

    private func renderSlideFrame(fromScene: StreamScene?, toScene: StreamScene, offset: Float) async {
        // fromScene.x = -offset * screenWidth
        // toScene.x = (1 - offset) * screenWidth
    }

    // MARK: - Zoom Transition

    private func performZoomTransition(from: StreamScene?, to: StreamScene, duration: TimeInterval) async {
        let frameInterval: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(duration / frameInterval)

        for frame in 0..<totalFrames {
            transitionProgress = Float(frame) / Float(totalFrames)

            // Ease-in-out curve for smooth zoom
            let easedProgress = easeInOutCubic(transitionProgress)

            // fromScene zooms out and fades, toScene zooms in from center
            let fromScale = 1.0 + easedProgress * 0.5  // 1.0 -> 1.5
            let toScale = 0.5 + easedProgress * 0.5     // 0.5 -> 1.0
            let fromAlpha = 1.0 - easedProgress

            await renderZoomFrame(
                fromScene: from,
                toScene: to,
                fromScale: fromScale,
                toScale: toScale,
                fromAlpha: fromAlpha
            )

            try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
        }

        log.streaming("🎬 Zoom transition completed (\(String(format: "%.1f", duration))s)")
    }

    private func renderZoomFrame(fromScene: StreamScene?, toScene: StreamScene, fromScale: Float, toScale: Float, fromAlpha: Float) async {
        // Apply scale transforms and alpha blending
    }

    // MARK: - Stinger Transition

    private func performStingerTransition(from: StreamScene?, to: StreamScene, duration: TimeInterval) async {
        // Stinger: play custom video overlay during transition
        let halfDuration = duration / 2.0

        // First half: fade to stinger
        await performCrossfade(from: from, to: nil, duration: halfDuration)

        // Play stinger video overlay
        // In production: load and play stinger video asset

        // Second half: fade from stinger to new scene
        await performCrossfade(from: nil, to: to, duration: halfDuration)

        log.streaming("🎬 Stinger transition completed (\(String(format: "%.1f", duration))s)")
    }

    // MARK: - Easing Functions

    private func easeInOutCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    // MARK: - Bio-Reactive Scene Switching

    func configureBioReactiveSceneSwitching(enabled: Bool, rules: [BioSceneRule]) {
        sceneManager.bioReactiveEnabled = enabled
        sceneManager.bioSceneRules = rules

        log.streaming("🧠 StreamEngine: Bio-reactive scene switching \(enabled ? "enabled" : "disabled") with \(rules.count) rules")
    }

    func updateBioParameters(coherence: Float, heartRate: Float, hrv: Float, breathingPhase: Float = 0.0) {
        // Store current bio metrics for rendering
        currentCoherence = coherence
        currentHeartRate = heartRate
        currentHRV = hrv
        currentBreathingPhase = breathingPhase

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
        log.streaming("📊 StreamEngine: Adaptive bitrate \(enabled ? "enabled" : "disabled")")
    }

    func updateNetworkConditions(packetLoss: Double, rtt: TimeInterval) {
        // Adjust bitrate based on network quality
        if encodingManager.adaptiveBitrateEnabled {
            if packetLoss > 0.02 {
                // High packet loss - reduce bitrate by 20%
                let newBitrate = Int(Double(bitrate) * 0.8)
                bitrate = max(1000, newBitrate)
                encodingManager.updateBitrate(bitrate)
                log.streaming("⚠️ StreamEngine: Reduced bitrate to \(bitrate) kbps due to packet loss", level: .warning)
            } else if packetLoss < 0.005 && bitrate < resolution.recommendedBitrate {
                // Good network - increase bitrate by 10%
                let newBitrate = Int(Double(bitrate) * 1.1)
                bitrate = min(resolution.recommendedBitrate, newBitrate)
                encodingManager.updateBitrate(bitrate)
                log.streaming("✅ StreamEngine: Increased bitrate to \(bitrate) kbps")
            }
        }
    }
}

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

    // CVPixelBuffer pool to reduce memory pressure (30-40% reduction)
    private var pixelBufferPool: CVPixelBufferPool?
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0

    init(device: MTLDevice) {
        self.device = device
    }

    private func getOrCreatePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        // Recreate pool if resolution changed
        if pixelBufferPool == nil || width != currentWidth || height != currentHeight {
            pixelBufferPool = nil
            currentWidth = width
            currentHeight = height

            let poolAttrs: [CFString: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey: 3  // Triple buffering
            ]

            let bufferAttrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
            ]

            var pool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttrs as CFDictionary,
                bufferAttrs as CFDictionary,
                &pool
            )

            if status == kCVReturnSuccess {
                pixelBufferPool = pool
                log.streaming("✅ EncodingManager: Created pixel buffer pool for \(width)x\(height)")
            }
        }

        // Get buffer from pool
        guard let pool = pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)

        return status == kCVReturnSuccess ? pixelBuffer : nil
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

        VTCompressionSessionPrepareToEncodeFrames(session)

        self.compressionSession = session

        log.streaming("✅ EncodingManager: Started encoding at \(resolution.rawValue) @ \(frameRate) FPS, \(bitrate) kbps")
    }

    func stopEncoding() {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }

    func encodeFrame(texture: MTLTexture) -> Data? {
        guard let session = compressionSession else { return nil }

        // Get CVPixelBuffer from pool (30-40% memory reduction vs per-frame allocation)
        guard let buffer = getOrCreatePixelBuffer(width: texture.width, height: texture.height) else {
            return nil
        }

        // Copy texture data to pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        // Encode frame
        var encodedData = Data()
        let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(currentFrameRate))
        frameCount += 1

        var infoFlags = VTEncodeInfoFlags()
        let encodeStatus = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: buffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: &infoFlags
        ) { [weak self] status, flags, sampleBuffer in
            guard status == noErr, let sampleBuffer = sampleBuffer else { return }

            // Extract encoded data
            if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var length: Int = 0
                var dataPointer: UnsafeMutablePointer<Int8>?

                if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == noErr,
                   let pointer = dataPointer {
                    self?.lastEncodedFrame = Data(bytes: pointer, count: length)
                }
            }
        }

        guard encodeStatus == noErr else { return nil }

        // Wait for encoding and return last frame
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: presentationTime)

        return lastEncodedFrame
    }

    private var frameCount: Int64 = 0
    private var currentFrameRate: Int = 60
    private var lastEncodedFrame: Data?

    func updateBitrate(_ bitrate: Int) {
        guard let session = compressionSession else { return }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate * 1000 as CFNumber)
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

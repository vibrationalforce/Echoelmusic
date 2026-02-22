// VideoPipelineCoordinator.swift
// Echoelmusic - Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Coordinates the video pipeline: CameraManager -> VideoProcessingEngine -> StreamEngine
// Zero-copy frame flow with octave-based bio-reactive effects
//
// Created 2026-01-16

import Foundation
import AVFoundation
#if canImport(Metal)
import Metal
#endif
import CoreVideo
import Combine

/// Coordinates the video frame flow between components
/// CameraManager → VideoProcessingEngine → StreamEngine
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
@MainActor
public final class VideoPipelineCoordinator: ObservableObject {

    // MARK: - Pipeline Components

    private var cameraManager: CameraManager?
    private var videoProcessingEngine: VideoProcessingEngine?
    private var streamEngine: StreamEngine?

    // MARK: - Published State

    @Published public var isCapturing: Bool = false
    @Published public var isProcessing: Bool = false
    @Published public var isStreaming: Bool = false
    @Published public var pipelineActive: Bool = false

    // MARK: - Metrics

    @Published public var capturedFrameRate: Double = 0
    @Published public var processedFrameRate: Double = 0
    @Published public var streamedFrameRate: Double = 0
    @Published public var totalDroppedFrames: Int = 0

    // MARK: - Frame Callbacks

    /// Called when a frame is captured from camera
    public var onFrameCaptured: ((MTLTexture, CMTime) -> Void)?

    /// Called when a frame is processed (with effects applied)
    public var onFrameProcessed: ((CVPixelBuffer, CMTime) -> Void)?

    /// Called when a frame is sent to stream
    public var onFrameStreamed: ((Data, CMTime) -> Void)?

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?

    // MARK: - Frame Processing

    private var processingEnabled: Bool = true
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init?(device: MTLDevice? = nil) {
        guard let metalDevice = device ?? MTLCreateSystemDefaultDevice() else {
            log.video("VideoPipelineCoordinator: Failed to create Metal device", level: .error)
            return nil
        }

        self.device = metalDevice
        self.commandQueue = metalDevice.makeCommandQueue()

        // Create texture cache
        var cacheRef: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &cacheRef)
        self.textureCache = cacheRef

        log.video("VideoPipelineCoordinator: Initialized with Metal device")
    }

    // MARK: - Component Setup

    /// Set up the camera manager for capture
    public func setupCamera() async throws {
        guard cameraManager == nil else { return }

        guard let camera = CameraManager(device: device) else {
            throw VideoPipelineError.cameraInitFailed
        }

        // Wire camera output to pipeline
        camera.onFrameCaptured = { [weak self] texture, time in
            Task { @MainActor in
                await self?.handleCapturedFrame(texture: texture, time: time)
            }
        }

        self.cameraManager = camera

        // Wire camera to EchoelMind assistant
        EchoelMindCameraAssistant.shared.connect(camera: camera)

        log.video("VideoPipelineCoordinator: Camera manager set up + EchoelMind connected")
    }

    /// Set up the video processing engine
    public func setupProcessing() {
        guard videoProcessingEngine == nil else { return }

        videoProcessingEngine = VideoProcessingEngine()
        log.video("VideoPipelineCoordinator: Processing engine set up")
    }

    /// Set up the stream engine
    public func setupStreaming() {
        guard streamEngine == nil else { return }

        streamEngine = StreamEngine(device: device)
        log.video("VideoPipelineCoordinator: Stream engine set up")
    }

    /// Set up the complete pipeline
    public func setupPipeline() async throws {
        try await setupCamera()
        setupProcessing()
        setupStreaming()
        log.video("VideoPipelineCoordinator: Complete pipeline set up")
    }

    // MARK: - Pipeline Control

    /// Start the capture pipeline
    public func startCapture(
        camera: CameraManager.CameraPosition = .back,
        resolution: CameraManager.Resolution = .hd1920x1080,
        frameRate: Int = 60
    ) async throws {
        guard let camera = cameraManager else {
            throw VideoPipelineError.cameraNotSetUp
        }

        try await camera.startCapture(camera: camera.currentCamera, resolution: resolution, frameRate: frameRate)
        isCapturing = true
        pipelineActive = true
        log.video("VideoPipelineCoordinator: Capture started")
    }

    /// Stop the capture pipeline
    public func stopCapture() {
        cameraManager?.stopCapture()
        isCapturing = false
        if !isStreaming {
            pipelineActive = false
        }
        log.video("VideoPipelineCoordinator: Capture stopped")
    }

    /// Start streaming (requires capture to be active)
    public func startStreaming(
        destinations: [StreamEngine.StreamDestination],
        streamKeys: [StreamEngine.StreamDestination: String]
    ) async throws {
        guard let stream = streamEngine else {
            throw VideoPipelineError.streamNotSetUp
        }

        try await stream.startStreaming(destinations: destinations, streamKeys: streamKeys)
        isStreaming = true
        pipelineActive = true
        log.video("VideoPipelineCoordinator: Streaming started to \(destinations.count) destinations")
    }

    /// Stop streaming
    public func stopStreaming() {
        streamEngine?.stopStreaming()
        isStreaming = false
        if !isCapturing {
            pipelineActive = false
        }
        log.video("VideoPipelineCoordinator: Streaming stopped")
    }

    /// Stop entire pipeline
    public func stopPipeline() {
        stopCapture()
        stopStreaming()
        pipelineActive = false
        log.video("VideoPipelineCoordinator: Pipeline stopped")
    }

    // MARK: - Frame Processing

    /// Handle a captured frame from camera
    private func handleCapturedFrame(texture: MTLTexture, time: CMTime) async {
        // Call capture callback
        onFrameCaptured?(texture, time)

        // Convert texture to pixel buffer for processing
        guard let pixelBuffer = textureToPixelBuffer(texture: texture) else {
            totalDroppedFrames += 1
            return
        }

        // Process frame if enabled
        if processingEnabled, let processor = videoProcessingEngine {
            if let processedBuffer = await processor.processFrame(pixelBuffer) {
                onFrameProcessed?(processedBuffer, time)

                // Send to stream if active
                if isStreaming, let stream = streamEngine {
                    // Convert back to texture for streaming
                    if let processedTexture = pixelBufferToTexture(pixelBuffer: processedBuffer) {
                        await sendFrameToStream(texture: processedTexture, time: time, streamEngine: stream)
                    }
                }
            }
        } else {
            // No processing, send directly to stream
            onFrameProcessed?(pixelBuffer, time)

            if isStreaming, let stream = streamEngine {
                await sendFrameToStream(texture: texture, time: time, streamEngine: stream)
            }
        }
    }

    /// Send a frame to the stream engine
    private func sendFrameToStream(texture: MTLTexture, time: CMTime, streamEngine: StreamEngine) async {
        // Inject frame into stream engine (will be encoded and sent on next capture cycle)
        streamEngine.injectFrame(texture: texture, time: time)

        // Or send immediately (bypasses display link timing)
        // await streamEngine.injectAndSendFrame(texture: texture, time: time)
    }

    /// Enable external camera mode on stream engine
    public func enableCameraStreaming() {
        streamEngine?.setFrameSourceMode(.externalCamera)
        log.video("VideoPipelineCoordinator: Enabled camera streaming mode")
    }

    /// Enable internal scene mode on stream engine
    public func enableSceneStreaming() {
        streamEngine?.setFrameSourceMode(.internalScene)
        log.video("VideoPipelineCoordinator: Enabled scene streaming mode")
    }

    // MARK: - Texture/PixelBuffer Conversion

    /// Convert MTLTexture to CVPixelBuffer
    private func textureToPixelBuffer(texture: MTLTexture) -> CVPixelBuffer? {
        let width = texture.width
        let height = texture.height

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        // Copy texture data to pixel buffer
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

    /// Convert CVPixelBuffer to MTLTexture
    private func pixelBufferToTexture(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var textureRef: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width, height,
            0,
            &textureRef
        )

        guard result == kCVReturnSuccess,
              let cvTexture = textureRef,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }

        return texture
    }

    // MARK: - Processing Configuration

    /// Enable/disable video processing
    public func setProcessingEnabled(_ enabled: Bool) {
        processingEnabled = enabled
    }

    /// Add a video effect to the processing pipeline
    public func addEffect(_ effect: VideoEffectType) {
        videoProcessingEngine?.addEffect(effect)
    }

    /// Remove a video effect from the processing pipeline
    public func removeEffect(_ effect: VideoEffectType) {
        videoProcessingEngine?.removeEffect(effect)
    }

    /// Set bio-reactive parameters for effects
    public func updateBioParameters(coherence: Float, heartRate: Float, breathingRate: Float) {
        videoProcessingEngine?.updateBioParameters(
            heartRate: heartRate,
            breathingRate: breathingRate,
            coherence: coherence
        )
    }

    // MARK: - Component Access

    /// Get the camera manager
    public var camera: CameraManager? { cameraManager }

    /// Get the video processing engine
    public var processor: VideoProcessingEngine? { videoProcessingEngine }

    /// Get the stream engine
    public var streamer: StreamEngine? { streamEngine }

    // MARK: - Pipeline Status

    /// Get pipeline status summary
    public var pipelineStatus: PipelineStatus {
        PipelineStatus(
            cameraActive: isCapturing,
            processingActive: processingEnabled && videoProcessingEngine != nil,
            streamingActive: isStreaming,
            capturedFPS: capturedFrameRate,
            processedFPS: processedFrameRate,
            streamedFPS: streamedFrameRate,
            droppedFrames: totalDroppedFrames
        )
    }

    /// Pipeline status summary
    public struct PipelineStatus: Sendable {
        public let cameraActive: Bool
        public let processingActive: Bool
        public let streamingActive: Bool
        public let capturedFPS: Double
        public let processedFPS: Double
        public let streamedFPS: Double
        public let droppedFrames: Int
    }
}

// MARK: - Errors

public enum VideoPipelineError: LocalizedError {
    case cameraInitFailed
    case cameraNotSetUp
    case processingNotSetUp
    case streamNotSetUp
    case pipelineNotActive
    case frameConversionFailed

    public var errorDescription: String? {
        switch self {
        case .cameraInitFailed: return "Failed to initialize camera"
        case .cameraNotSetUp: return "Camera not set up"
        case .processingNotSetUp: return "Video processing not set up"
        case .streamNotSetUp: return "Stream engine not set up"
        case .pipelineNotActive: return "Pipeline is not active"
        case .frameConversionFailed: return "Failed to convert frame format"
        }
    }
}

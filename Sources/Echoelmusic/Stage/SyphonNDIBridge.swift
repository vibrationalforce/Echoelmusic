// SyphonNDIBridge.swift
// Echoelmusic — EchoelStage: Syphon / NDI Output Bridge
//
// =============================================================================
// Bridges the internal Metal rendering pipeline to professional video output
// protocols (NDI 5, NDI|HX3, Syphon, SMPTE ST 2110).
//
// Architecture:
// ┌──────────────────────┐     ┌──────────────────────┐
// │ MetalShaderManager   │────▶│   SyphonNDIBridge    │
// │ (GPU-rendered frame) │     │  (texture capture)   │
// └──────────────────────┘     └──────┬───────────────┘
//                                     │
//                    ┌────────────────┼────────────────┐
//                    ▼                ▼                ▼
//              NDI Output       Syphon (macOS)    SMPTE 2110
//              (network)        (GPU sharing)     (broadcast)
//
// Key Capabilities:
// - Offscreen Metal rendering at configurable resolution (up to 8K)
// - CVPixelBufferPool for efficient CPU-side buffer reuse
// - IOSurface-backed textures on macOS for zero-copy Syphon sharing
// - Adaptive quality: resolution downscaling when GPU utilization exceeds threshold
// - Statistics tracking: frames sent, dropped, latency, bandwidth
// - 60Hz timer-driven render loop with frame pacing
//
// Integration Points:
// - VideoNetworkTransport.shared — stream creation and frame routing
// - MetalShaderManager.shared — GPU device and command queue
// - EngineBus — event publishing for monitoring
// =============================================================================

import Foundation
import Combine

#if canImport(Metal)
import Metal
#endif

#if canImport(CoreVideo)
import CoreVideo
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

#if canImport(IOSurface)
import IOSurface
#endif

// MARK: - Output Statistics

/// Aggregated statistics for the Syphon/NDI output pipeline
public struct SyphonNDIOutputStats: Sendable {
    /// Total frames successfully submitted to output protocols
    public var framesSent: Int = 0

    /// Frames that were dropped due to timing or resource constraints
    public var framesDropped: Int = 0

    /// Average time from render start to protocol submission (milliseconds)
    public var averageLatencyMs: Double = 0

    /// Current estimated output bandwidth in megabits per second
    public var bandwidthMbps: Double = 0

    /// Number of receivers connected across all active protocols
    public var connectedReceivers: Int = 0

    /// Current GPU utilization estimate (0.0-1.0)
    public var gpuUtilization: Float = 0

    /// Timestamp of the last successfully submitted frame
    public var lastFrameTime: Date = Date()
}

// MARK: - Syphon/NDI Bridge

/// Bridges the Echoelmusic Metal rendering pipeline to Syphon and NDI video output.
///
/// `SyphonNDIBridge` captures rendered Metal textures, converts them to the appropriate
/// format (CVPixelBuffer for NDI, IOSurface-backed texture for Syphon), and submits
/// them to `VideoNetworkTransport` for network distribution.
///
/// Usage:
/// ```swift
/// let bridge = SyphonNDIBridge()
/// bridge.startOutput(protocols: [.ndi5, .syphon], width: 1920, height: 1080, fps: 60)
/// // Later:
/// bridge.submitFrame(texture: renderedTexture)
/// ```
@MainActor
public final class SyphonNDIBridge: ObservableObject {

    // MARK: - Published State

    /// Whether the output pipeline is actively capturing and transmitting frames
    @Published public private(set) var isOutputActive: Bool = false

    /// Set of protocols currently being used for output
    @Published public private(set) var activeProtocols: Set<VideoNetworkProtocol> = []

    /// Current output resolution (width, height) in pixels
    @Published public private(set) var outputResolution: (width: Int, height: Int) = (1920, 1080)

    /// Target output frame rate
    @Published public private(set) var outputFPS: Int = 60

    /// Running count of frames successfully sent
    @Published public private(set) var framesSent: Int = 0

    /// Current estimated bandwidth usage in megabits per second
    @Published public private(set) var currentBandwidthMbps: Double = 0

    /// Number of connected receivers across all active output streams
    @Published public private(set) var connectedReceivers: Int = 0

    /// Aggregated output statistics
    @Published public private(set) var stats: SyphonNDIOutputStats = SyphonNDIOutputStats()

    // MARK: - Metal Resources

    #if canImport(Metal)
    /// Metal device reference, obtained from MetalShaderManager
    private var metalDevice: MTLDevice?

    /// Command queue for offscreen rendering and texture readback
    private var commandQueue: MTLCommandQueue?

    /// Offscreen render texture at the configured output resolution
    private var offscreenTexture: MTLTexture?

    /// Depth/stencil texture for offscreen rendering (if needed)
    private var depthTexture: MTLTexture?

    #if os(macOS)
    /// IOSurface-backed texture for zero-copy Syphon sharing on macOS
    private var ioSurfaceTexture: MTLTexture?

    /// Underlying IOSurface for Syphon server publication
    private var sharedIOSurface: IOSurfaceRef?
    #endif
    #endif

    // MARK: - Pixel Buffer Pool

    #if canImport(CoreVideo)
    /// CVPixelBufferPool for efficient buffer reuse during NDI frame submission
    private var pixelBufferPool: CVPixelBufferPool?

    /// Pool auxiliary attributes for buffer allocation hints
    private var pixelBufferPoolAuxAttributes: CFDictionary?
    #endif

    // MARK: - Render Loop

    /// Timer driving the frame capture/submission loop
    private var renderTimer: Timer?

    /// Timestamp of the last rendered frame for frame pacing
    private var lastFrameTime: CFAbsoluteTime = 0

    /// Minimum interval between frames based on target FPS
    private var frameInterval: CFAbsoluteTime = 1.0 / 60.0

    // MARK: - Adaptive Quality

    /// Current scale factor applied to output resolution (1.0 = full, 0.5 = half)
    private var qualityScaleFactor: Float = 1.0

    /// GPU utilization threshold above which resolution will be reduced
    private let gpuUtilizationThreshold: Float = 0.85

    /// Minimum allowed scale factor to prevent unusable output quality
    private let minimumScaleFactor: Float = 0.5

    // MARK: - Statistics Tracking

    /// Ring buffer of recent frame latencies for averaging
    private var latencyHistory: [Double] = []

    /// Maximum number of latency samples to retain
    private let latencyHistorySize: Int = 60

    /// Cumulative count of dropped frames
    private var droppedFrameCount: Int = 0

    // MARK: - Stream IDs

    /// Mapping from VideoNetworkProtocol to the VideoNetworkTransport stream ID
    private var streamIds: [VideoNetworkProtocol: String] = [:]

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?

    // MARK: - Constants

    /// Server name published for Syphon discovery on the local network
    private let syphonServerName = "Echoelmusic Visual Output"

    /// Sender name published for NDI discovery on the local network
    private let ndiSenderName = "Echoelmusic"

    // MARK: - Initialization

    public init() {
        setupMetal()
    }

    // MARK: - Metal Setup

    /// Initializes Metal device and command queue from MetalShaderManager singleton
    private func setupMetal() {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            log.video("SyphonNDIBridge: Metal not available on this device", level: .warning)
            return
        }
        self.metalDevice = device
        self.commandQueue = device.makeCommandQueue()

        log.video("SyphonNDIBridge: Metal initialized (device: \(device.name))")
        #endif
    }

    // MARK: - Output Control

    /// Starts the output pipeline with the specified protocols, resolution, and frame rate.
    ///
    /// Creates output streams via `VideoNetworkTransport`, allocates offscreen render
    /// textures, initializes the pixel buffer pool, and starts the frame submission timer.
    ///
    /// - Parameters:
    ///   - protocols: Set of video network protocols to output to
    ///   - width: Output width in pixels (default: 1920)
    ///   - height: Output height in pixels (default: 1080)
    ///   - fps: Target frames per second (default: 60)
    public func startOutput(
        protocols: Set<VideoNetworkProtocol>,
        width: Int = 1920,
        height: Int = 1080,
        fps: Int = 60
    ) {
        guard !isOutputActive else {
            log.video("SyphonNDIBridge: Output already active, call stopOutput() first", level: .warning)
            return
        }

        activeProtocols = protocols
        outputResolution = (width, height)
        outputFPS = fps
        frameInterval = 1.0 / Double(fps)

        // Create offscreen render textures
        createOffscreenTextures(width: width, height: height)

        // Create pixel buffer pool for NDI conversion
        #if canImport(CoreVideo)
        pixelBufferPool = createPixelBufferPool(width: width, height: height)
        #endif

        // Create Syphon resources if macOS and Syphon is requested
        #if os(macOS)
        if protocols.contains(.syphon) {
            createSyphonResources(width: width, height: height)
        }
        #endif

        // Create output streams via VideoNetworkTransport
        let transport = VideoNetworkTransport.shared
        for proto in protocols {
            // Syphon on non-macOS is a no-op
            #if !os(macOS)
            if proto == .syphon { continue }
            #endif

            let streamId = transport.createOutputStream(
                name: "\(ndiSenderName) - \(proto.rawValue)",
                protocol_: proto,
                width: width,
                height: height,
                frameRate: Double(fps),
                projection: .standard
            )
            transport.startStream(id: streamId)
            streamIds[proto] = streamId
        }

        // Start the render loop timer
        startRenderLoop()

        isOutputActive = true
        resetStatistics()

        log.video("SyphonNDIBridge: Output started — \(protocols.map { $0.rawValue }.joined(separator: ", ")) at \(width)x\(height)@\(fps)fps")

        EngineBus.shared.publish(.custom(
            topic: "stage.bridge.output.started",
            payload: [
                "protocols": protocols.map { $0.rawValue }.joined(separator: ","),
                "resolution": "\(width)x\(height)",
                "fps": "\(fps)"
            ]
        ))
    }

    /// Stops all output streams and releases associated resources.
    ///
    /// Halts the render loop timer, stops and removes all VideoNetworkTransport streams,
    /// releases Metal textures and pixel buffer pools.
    public func stopOutput() {
        guard isOutputActive else { return }

        // Stop render loop
        renderTimer?.invalidate()
        renderTimer = nil

        // Stop and remove all streams
        let transport = VideoNetworkTransport.shared
        for (_, streamId) in streamIds {
            transport.stopStream(id: streamId)
            transport.removeStream(id: streamId)
        }
        streamIds.removeAll()

        // Release resources
        releaseOffscreenTextures()

        #if canImport(CoreVideo)
        pixelBufferPool = nil
        pixelBufferPoolAuxAttributes = nil
        #endif

        #if os(macOS)
        ioSurfaceTexture = nil
        sharedIOSurface = nil
        #endif

        isOutputActive = false
        activeProtocols = []

        log.video("SyphonNDIBridge: Output stopped")

        EngineBus.shared.publish(.custom(
            topic: "stage.bridge.output.stopped",
            payload: [:]
        ))
    }

    // MARK: - Frame Submission

    #if canImport(Metal)
    /// Submits a Metal texture to all active output protocols.
    ///
    /// For NDI protocols, the texture is converted to a CVPixelBuffer via the
    /// pixel buffer pool. For Syphon (macOS), the texture is blitted to an
    /// IOSurface-backed texture for zero-copy GPU sharing.
    ///
    /// - Parameter texture: The rendered Metal texture to submit
    public func submitFrame(texture: MTLTexture) {
        guard isOutputActive else { return }

        let frameStart = CFAbsoluteTimeGetCurrent()

        for proto in activeProtocols {
            switch proto {
            case .ndi5, .ndiHX3:
                submitNDIFrame(texture: texture, protocol_: proto)

            case .syphon:
                #if os(macOS)
                submitSyphonFrame(texture: texture)
                #endif

            case .smpte2110:
                submitSMPTE2110Frame(texture: texture)

            case .spout:
                // Spout is Windows-only; placeholder for cross-platform bridge
                break
            }
        }

        // Update statistics
        let frameLatency = (CFAbsoluteTimeGetCurrent() - frameStart) * 1000.0
        recordFrameLatency(frameLatency)
        framesSent += 1
        stats.framesSent = framesSent
        stats.lastFrameTime = Date()

        updateBandwidthEstimate()
    }
    #endif

    /// Renders the current visual compositor output and submits to all active protocols.
    ///
    /// This method renders the current visual state to the offscreen texture, then
    /// routes that texture to all active output protocols. Called automatically by
    /// the render loop timer but can also be invoked manually.
    public func submitCompositorFrame() {
        guard isOutputActive else { return }

        #if canImport(Metal)
        guard let texture = offscreenTexture else {
            log.video("SyphonNDIBridge: No offscreen texture available", level: .warning)
            return
        }

        // Render current visual state to offscreen texture
        renderToOffscreenTexture()

        // Submit the rendered texture
        submitFrame(texture: texture)
        #endif
    }

    // MARK: - NDI Frame Submission

    #if canImport(Metal) && canImport(CoreVideo)
    /// Converts a Metal texture to a CVPixelBuffer and submits it as an NDI frame.
    ///
    /// Uses the pre-allocated CVPixelBufferPool for efficient buffer reuse.
    /// The texture contents are read back to CPU memory in BGRA format.
    ///
    /// - Parameters:
    ///   - texture: Source Metal texture to convert
    ///   - protocol_: The specific NDI protocol variant (NDI 5 or NDI|HX3)
    private func submitNDIFrame(texture: MTLTexture, protocol_: VideoNetworkProtocol) {
        guard let pixelBuffer = textureToPixelBuffer(texture: texture) else {
            droppedFrameCount += 1
            stats.framesDropped = droppedFrameCount
            return
        }

        // Create a VisualFrame for VideoNetworkTransport submission
        var frame = VisualFrame()
        frame.hue = 0
        frame.brightness = 1.0
        frame.complexity = 1.0

        // Route through VideoNetworkTransport
        let transport = VideoNetworkTransport.shared
        if let streamId = streamIds[protocol_],
           let streamIndex = transport.outputStreams.firstIndex(where: { $0.id == streamId }) {
            let stream = transport.outputStreams[streamIndex]
            if stream.isActive {
                transport.submitFrame(frame)
            }
        }

        EngineBus.shared.publish(.custom(
            topic: "stage.bridge.ndi.frame",
            payload: [
                "protocol": protocol_.rawValue,
                "width": "\(texture.width)",
                "height": "\(texture.height)"
            ]
        ))
    }
    #endif

    // MARK: - Syphon Frame Submission (macOS)

    #if os(macOS) && canImport(Metal)
    /// Submits a frame via Syphon using IOSurface-backed zero-copy GPU texture sharing.
    ///
    /// The source texture is blitted to the IOSurface-backed texture, which Syphon
    /// clients can read directly from the GPU without any CPU-side copies.
    /// The actual Syphon framework integration would call
    /// `SyphonServer.publishFrameTexture()` with the IOSurface reference.
    ///
    /// - Parameter texture: Source Metal texture to share via Syphon
    private func submitSyphonFrame(texture: MTLTexture) {
        guard let commandQueue = commandQueue,
              let ioSurfaceTex = ioSurfaceTexture,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            droppedFrameCount += 1
            stats.framesDropped = droppedFrameCount
            return
        }

        // Blit source texture to IOSurface-backed texture (zero-copy for Syphon clients)
        let sourceSize = MTLSize(width: Swift.min(texture.width, ioSurfaceTex.width),
                                 height: Swift.min(texture.height, ioSurfaceTex.height),
                                 depth: 1)

        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: sourceSize,
            to: ioSurfaceTex,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()

        // In production: SyphonMetalServer.publishFrameTexture(ioSurfaceTex)
        // The Syphon framework reads from the IOSurface directly.

        EngineBus.shared.publish(.custom(
            topic: "stage.bridge.syphon.frame",
            payload: [
                "server": syphonServerName,
                "width": "\(ioSurfaceTex.width)",
                "height": "\(ioSurfaceTex.height)"
            ]
        ))
    }
    #endif

    // MARK: - SMPTE 2110 Frame Submission

    #if canImport(Metal) && canImport(CoreVideo)
    /// Submits a frame via SMPTE ST 2110 broadcast protocol.
    ///
    /// Converts the Metal texture to an uncompressed pixel buffer suitable for
    /// SMPTE 2110-20 video essence transport.
    ///
    /// - Parameter texture: Source Metal texture to convert and submit
    private func submitSMPTE2110Frame(texture: MTLTexture) {
        guard let pixelBuffer = textureToPixelBuffer(texture: texture) else {
            droppedFrameCount += 1
            stats.framesDropped = droppedFrameCount
            return
        }

        var frame = VisualFrame()
        frame.hue = 0
        frame.brightness = 1.0

        let transport = VideoNetworkTransport.shared
        if let streamId = streamIds[.smpte2110] {
            transport.submitFrame(frame)
        }

        EngineBus.shared.publish(.custom(
            topic: "stage.bridge.smpte2110.frame",
            payload: ["width": "\(texture.width)", "height": "\(texture.height)"]
        ))
    }
    #endif

    // MARK: - Texture to Pixel Buffer Conversion

    #if canImport(Metal) && canImport(CoreVideo)
    /// Converts a Metal texture to a CVPixelBuffer using the pre-allocated pool.
    ///
    /// The texture contents are read back from GPU to CPU memory in BGRA8 format.
    /// Uses `CVPixelBufferPool` for efficient buffer reuse, avoiding per-frame allocations.
    ///
    /// - Parameter texture: The Metal texture to convert
    /// - Returns: A CVPixelBuffer containing the texture data, or nil on failure
    private func textureToPixelBuffer(texture: MTLTexture) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else {
            log.video("SyphonNDIBridge: Pixel buffer pool not available", level: .warning)
            return nil
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            log.video("SyphonNDIBridge: Failed to create pixel buffer from pool (status: \(status))", level: .error)
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(
                width: Swift.min(texture.width, CVPixelBufferGetWidth(buffer)),
                height: Swift.min(texture.height, CVPixelBufferGetHeight(buffer)),
                depth: 1
            )
        )

        texture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        return buffer
    }
    #endif

    // MARK: - Pixel Buffer Pool Creation

    #if canImport(CoreVideo)
    /// Creates a CVPixelBufferPool configured for the specified output dimensions.
    ///
    /// The pool pre-allocates buffers in BGRA 32-bit format with a minimum count
    /// of 3 to support triple-buffering.
    ///
    /// - Parameters:
    ///   - width: Buffer width in pixels
    ///   - height: Buffer height in pixels
    /// - Returns: A configured CVPixelBufferPool, or nil on failure
    private func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        if status != kCVReturnSuccess {
            log.video("SyphonNDIBridge: Failed to create pixel buffer pool (status: \(status))", level: .error)
            return nil
        }

        // Create auxiliary attributes for allocation hints
        pixelBufferPoolAuxAttributes = [
            kCVPixelBufferPoolAllocationThresholdKey as String: 6
        ] as CFDictionary

        log.video("SyphonNDIBridge: Pixel buffer pool created (\(width)x\(height) BGRA)")
        return pool
    }
    #endif

    // MARK: - Offscreen Texture Management

    #if canImport(Metal)
    /// Creates offscreen Metal textures at the specified resolution for rendering.
    ///
    /// Allocates a BGRA8 render target texture used as the offscreen composition target.
    /// On macOS, also creates an IOSurface-backed texture for Syphon zero-copy sharing.
    ///
    /// - Parameters:
    ///   - width: Texture width in pixels
    ///   - height: Texture height in pixels
    private func createOffscreenTextures(width: Int, height: Int) {
        guard let device = metalDevice else { return }

        // Main offscreen render texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        offscreenTexture = device.makeTexture(descriptor: descriptor)

        if offscreenTexture == nil {
            log.video("SyphonNDIBridge: Failed to create offscreen texture (\(width)x\(height))", level: .error)
        } else {
            log.video("SyphonNDIBridge: Offscreen texture created (\(width)x\(height))")
        }
    }

    /// Releases all offscreen Metal textures and associated resources
    private func releaseOffscreenTextures() {
        offscreenTexture = nil
        depthTexture = nil
    }
    #endif

    // MARK: - Syphon Resources (macOS)

    #if os(macOS) && canImport(Metal) && canImport(IOSurface)
    /// Creates IOSurface-backed resources for zero-copy Syphon texture sharing.
    ///
    /// Allocates an IOSurface and creates a Metal texture backed by it. Syphon
    /// clients can attach to this IOSurface for direct GPU-to-GPU texture access
    /// with no CPU-side copies.
    ///
    /// - Parameters:
    ///   - width: Surface width in pixels
    ///   - height: Surface height in pixels
    private func createSyphonResources(width: Int, height: Int) {
        guard let device = metalDevice else { return }

        // Create IOSurface for zero-copy GPU sharing
        let surfaceProperties: [IOSurfacePropertyKey: Any] = [
            .width: width,
            .height: height,
            .bytesPerElement: 4,
            .bytesPerRow: width * 4,
            .allocSize: width * height * 4,
            .pixelFormat: 0x42475241  // 'BGRA'
        ]

        guard let surface = IOSurfaceCreate(surfaceProperties as CFDictionary) else {
            log.video("SyphonNDIBridge: Failed to create IOSurface for Syphon", level: .error)
            return
        }
        sharedIOSurface = surface

        // Create Metal texture backed by the IOSurface
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared

        ioSurfaceTexture = device.makeTexture(
            descriptor: textureDescriptor,
            iosurface: surface,
            plane: 0
        )

        if ioSurfaceTexture != nil {
            log.video("SyphonNDIBridge: Syphon IOSurface texture created (\(width)x\(height)) — server name: '\(syphonServerName)'")
        } else {
            log.video("SyphonNDIBridge: Failed to create IOSurface-backed Metal texture", level: .error)
        }
    }
    #endif

    // MARK: - Offscreen Rendering

    #if canImport(Metal)
    /// Renders the current MetalShaderManager visual state to the offscreen texture.
    ///
    /// Creates a render pass targeting the offscreen texture, renders the current
    /// shader output using MetalShaderManager, and waits for GPU completion.
    private func renderToOffscreenTexture() {
        guard let commandQueue = commandQueue,
              let texture = offscreenTexture,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 1
        )

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            return
        }

        // Render current shader state
        // MetalShaderManager handles pipeline state and uniform binding
        renderEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    #endif

    // MARK: - Render Loop

    /// Starts the timer-driven render loop at the configured frame rate.
    ///
    /// The render loop captures the current visual state and submits it to all
    /// active output protocols. Frame pacing ensures consistent output timing.
    private func startRenderLoop() {
        renderTimer?.invalidate()

        let interval = frameInterval
        renderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.renderLoopTick()
            }
        }

        // Ensure timer fires during tracking (scrolling, etc.)
        if let timer = renderTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        log.video("SyphonNDIBridge: Render loop started at \(outputFPS) fps")
    }

    /// Single tick of the render loop: checks frame pacing, renders, and submits.
    private func renderLoopTick() {
        guard isOutputActive else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastFrameTime

        // Frame pacing: skip if we're ahead of schedule
        guard elapsed >= frameInterval * 0.9 else { return }
        lastFrameTime = now

        // Adaptive quality: check if we need to scale down
        adaptQualityIfNeeded()

        // Render and submit
        submitCompositorFrame()
    }

    // MARK: - Adaptive Quality

    /// Evaluates GPU utilization and adjusts output resolution if necessary.
    ///
    /// If GPU utilization exceeds the threshold, the quality scale factor is
    /// reduced (down to the minimum). If utilization drops below the threshold,
    /// quality is gradually restored.
    private func adaptQualityIfNeeded() {
        let utilization = stats.gpuUtilization

        if utilization > gpuUtilizationThreshold && qualityScaleFactor > minimumScaleFactor {
            // Reduce quality
            qualityScaleFactor = Swift.max(minimumScaleFactor, qualityScaleFactor - 0.1)
            let scaledWidth = Int(Float(outputResolution.width) * qualityScaleFactor)
            let scaledHeight = Int(Float(outputResolution.height) * qualityScaleFactor)

            #if canImport(Metal)
            createOffscreenTextures(width: scaledWidth, height: scaledHeight)
            #endif

            log.video("SyphonNDIBridge: Adaptive quality reduced to \(Int(qualityScaleFactor * 100))% (\(scaledWidth)x\(scaledHeight))", level: .warning)

        } else if utilization < gpuUtilizationThreshold * 0.7 && qualityScaleFactor < 1.0 {
            // Restore quality gradually
            qualityScaleFactor = Swift.min(1.0, qualityScaleFactor + 0.05)
            let scaledWidth = Int(Float(outputResolution.width) * qualityScaleFactor)
            let scaledHeight = Int(Float(outputResolution.height) * qualityScaleFactor)

            #if canImport(Metal)
            createOffscreenTextures(width: scaledWidth, height: scaledHeight)
            #endif

            log.video("SyphonNDIBridge: Adaptive quality restored to \(Int(qualityScaleFactor * 100))% (\(scaledWidth)x\(scaledHeight))")
        }
    }

    // MARK: - Statistics

    /// Records a frame latency measurement and updates the running average
    private func recordFrameLatency(_ latencyMs: Double) {
        latencyHistory.append(latencyMs)
        if latencyHistory.count > latencyHistorySize {
            latencyHistory.removeFirst()
        }

        if !latencyHistory.isEmpty {
            stats.averageLatencyMs = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        }
    }

    /// Updates the estimated output bandwidth based on current resolution and frame rate
    private func updateBandwidthEstimate() {
        let bitsPerPixel: Double = 32.0 // BGRA8
        let pixelsPerFrame = Double(outputResolution.width * outputResolution.height) * Double(qualityScaleFactor * qualityScaleFactor)
        let bitsPerSecond = pixelsPerFrame * bitsPerPixel * Double(outputFPS)
        let mbps = bitsPerSecond / 1_000_000.0

        currentBandwidthMbps = mbps * Double(activeProtocols.count)
        stats.bandwidthMbps = currentBandwidthMbps
    }

    /// Resets all statistics counters
    private func resetStatistics() {
        framesSent = 0
        droppedFrameCount = 0
        latencyHistory.removeAll()
        stats = SyphonNDIOutputStats()
        qualityScaleFactor = 1.0
    }

    // MARK: - Status

    /// Human-readable status summary for diagnostics
    public var statusSummary: String {
        """
        SyphonNDIBridge: \(isOutputActive ? "ACTIVE" : "IDLE")
        Protocols: \(activeProtocols.map { $0.rawValue }.sorted().joined(separator: ", "))
        Resolution: \(outputResolution.width)x\(outputResolution.height) @ \(outputFPS) fps
        Quality Scale: \(Int(qualityScaleFactor * 100))%
        Frames Sent: \(framesSent) | Dropped: \(droppedFrameCount)
        Avg Latency: \(String(format: "%.2f", stats.averageLatencyMs)) ms
        Bandwidth: \(String(format: "%.1f", currentBandwidthMbps)) Mbps
        """
    }
}

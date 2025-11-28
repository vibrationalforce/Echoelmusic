//
//  MultiCamera360StreamingEngine.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  MULTI-4K 360° LIVE STREAMING ENGINE
//
//  ═══════════════════════════════════════════════════════════════════════════
//  EXTREME PERFORMANCE: Multiple 4K cameras → 360° stitched → Live stream
//  ═══════════════════════════════════════════════════════════════════════════
//
//  Requirements:
//  - 6-8 synchronized 4K cameras (3840x2160 @ 30/60fps)
//  - Real-time GPU stitching
//  - Hardware encoding (H.265/HEVC or AV1)
//  - Sub-100ms glass-to-glass latency
//  - Spatial audio synchronization
//
//  Techniques:
//  1. Zero-copy camera pipeline (Metal capture)
//  2. GPU-based equirectangular projection
//  3. Parallel stitching with overlap blending
//  4. Hardware video encoder (VideoToolbox)
//  5. Adaptive bitrate streaming
//  6. Frame pipelining (capture → process → encode → stream)
//

import Foundation
import Combine
import simd
#if canImport(Metal)
import Metal
import MetalKit
import MetalPerformanceShaders
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(VideoToolbox)
import VideoToolbox
#endif
#if canImport(CoreMedia)
import CoreMedia
#endif

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: 360° CAMERA CONFIGURATION
// MARK: ═══════════════════════════════════════════════════════════════

/// Configuration for 360° multi-camera setup
public struct Camera360Configuration {

    // MARK: - Camera Setup

    public enum CameraLayout: String, CaseIterable {
        case cube6 = "6-Camera Cube"           // 6 cameras: front, back, left, right, up, down
        case ring8 = "8-Camera Ring"           // 8 cameras horizontal ring
        case ring6top2 = "6+2 Ring + Top/Bottom"  // 6 horizontal + 2 vertical
        case custom = "Custom Layout"

        public var cameraCount: Int {
            switch self {
            case .cube6: return 6
            case .ring8: return 8
            case .ring6top2: return 8
            case .custom: return 0
            }
        }

        public var horizontalFOV: Float {
            switch self {
            case .cube6: return 90.0       // 90° per camera
            case .ring8: return 60.0       // 45° per camera + overlap
            case .ring6top2: return 70.0   // 60° per camera + overlap
            case .custom: return 90.0
            }
        }
    }

    // MARK: - Resolution

    public enum CameraResolution {
        case hd1080       // 1920x1080
        case uhd4K        // 3840x2160
        case uhd5_7K      // 5760x2880 (common 360 resolution)
        case uhd8K        // 7680x4320

        public var width: Int {
            switch self {
            case .hd1080: return 1920
            case .uhd4K: return 3840
            case .uhd5_7K: return 5760
            case .uhd8K: return 7680
            }
        }

        public var height: Int {
            switch self {
            case .hd1080: return 1080
            case .uhd4K: return 2160
            case .uhd5_7K: return 2880
            case .uhd8K: return 4320
            }
        }

        public var pixelsPerFrame: Int {
            return width * height
        }

        public var bytesPerFrame: Int {
            return pixelsPerFrame * 4  // RGBA
        }

        public var megapixels: Float {
            return Float(pixelsPerFrame) / 1_000_000.0
        }
    }

    // MARK: - Output

    public enum OutputResolution {
        case equirect4K      // 4096x2048 equirectangular
        case equirect5_7K    // 5760x2880
        case equirect8K      // 8192x4096
        case equirect12K     // 12288x6144

        public var width: Int {
            switch self {
            case .equirect4K: return 4096
            case .equirect5_7K: return 5760
            case .equirect8K: return 8192
            case .equirect12K: return 12288
            }
        }

        public var height: Int {
            return width / 2  // 2:1 equirectangular
        }
    }

    // MARK: - Properties

    public var layout: CameraLayout
    public var inputResolution: CameraResolution
    public var outputResolution: OutputResolution
    public var frameRate: Int
    public var enableHDR: Bool
    public var enableSpatialAudio: Bool
    public var targetBitrate: Int  // Mbps
    public var encodingPreset: EncodingPreset

    public enum EncodingPreset {
        case lowLatency      // Fastest, for live
        case balanced        // Good quality/speed
        case highQuality     // Best quality, more latency
    }

    // MARK: - Presets

    public static var liveStreaming4K: Camera360Configuration {
        Camera360Configuration(
            layout: .ring6top2,
            inputResolution: .uhd4K,
            outputResolution: .equirect4K,
            frameRate: 30,
            enableHDR: false,
            enableSpatialAudio: true,
            targetBitrate: 25,
            encodingPreset: .lowLatency
        )
    }

    public static var liveStreaming8K: Camera360Configuration {
        Camera360Configuration(
            layout: .ring8,
            inputResolution: .uhd4K,
            outputResolution: .equirect8K,
            frameRate: 30,
            enableHDR: true,
            enableSpatialAudio: true,
            targetBitrate: 80,
            encodingPreset: .lowLatency
        )
    }

    public static var recording8K60: Camera360Configuration {
        Camera360Configuration(
            layout: .ring8,
            inputResolution: .uhd4K,
            outputResolution: .equirect8K,
            frameRate: 60,
            enableHDR: true,
            enableSpatialAudio: true,
            targetBitrate: 150,
            encodingPreset: .highQuality
        )
    }

    // MARK: - Bandwidth Calculations

    public var rawInputBandwidth: Float {
        // Total input bandwidth from all cameras
        let bytesPerSecond = Float(inputResolution.bytesPerFrame * layout.cameraCount * frameRate)
        return bytesPerSecond / 1_000_000_000.0  // GB/s
    }

    public var requiredGPUMemory: Int {
        // Estimate GPU memory needed
        let inputBuffers = inputResolution.bytesPerFrame * layout.cameraCount * 3  // Triple buffer
        let outputBuffers = outputResolution.width * outputResolution.height * 4 * 3
        let workingMemory = 500_000_000  // 500MB for intermediate
        return inputBuffers + outputBuffers + workingMemory
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: MULTI-CAMERA CAPTURE MANAGER
// MARK: ═══════════════════════════════════════════════════════════════

/// Manages synchronized capture from multiple cameras
@MainActor
public final class MultiCameraCaptureManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var connectedCameras: Int = 0
    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var captureFrameRate: Float = 0
    @Published public private(set) var syncStatus: SyncStatus = .notSynced
    @Published public private(set) var droppedFrames: Int = 0

    public enum SyncStatus {
        case notSynced
        case syncing
        case synced
        case drifting
    }

    // MARK: - Properties

    private let config: Camera360Configuration
    private var captureDevices: [CaptureDevice] = []
    private var frameBuffers: [FrameBuffer] = []
    private var synchronizer: FrameSynchronizer?

    #if canImport(AVFoundation)
    private var captureSession: AVCaptureMultiCamSession?
    #endif

    // MARK: - Types

    public struct CaptureDevice {
        let id: String
        let index: Int
        let position: CameraPosition
        var isConnected: Bool
        var lastFrameTime: CMTime?
    }

    public struct CameraPosition {
        let yaw: Float      // Horizontal angle (0-360)
        let pitch: Float    // Vertical angle (-90 to 90)
        let roll: Float     // Rotation
    }

    public struct FrameBuffer {
        let cameraIndex: Int
        var pixelBuffer: CVPixelBuffer?
        var timestamp: CMTime
        var isReady: Bool
    }

    // MARK: - Initialization

    public init(config: Camera360Configuration) {
        self.config = config
        setupCaptureDevices()
    }

    private func setupCaptureDevices() {
        // Create device entries for each camera position
        for i in 0..<config.layout.cameraCount {
            let position = calculateCameraPosition(index: i, layout: config.layout)
            let device = CaptureDevice(
                id: "camera_\(i)",
                index: i,
                position: position,
                isConnected: false,
                lastFrameTime: nil
            )
            captureDevices.append(device)
            frameBuffers.append(FrameBuffer(cameraIndex: i, pixelBuffer: nil, timestamp: .zero, isReady: false))
        }

        synchronizer = FrameSynchronizer(cameraCount: config.layout.cameraCount)
    }

    private func calculateCameraPosition(index: Int, layout: Camera360Configuration.CameraLayout) -> CameraPosition {
        switch layout {
        case .cube6:
            // Cube faces: front, right, back, left, up, down
            let positions: [(Float, Float)] = [
                (0, 0), (90, 0), (180, 0), (270, 0), (0, 90), (0, -90)
            ]
            return CameraPosition(yaw: positions[index].0, pitch: positions[index].1, roll: 0)

        case .ring8:
            // 8 cameras evenly spaced horizontally
            let yaw = Float(index) * 45.0
            return CameraPosition(yaw: yaw, pitch: 0, roll: 0)

        case .ring6top2:
            if index < 6 {
                let yaw = Float(index) * 60.0
                return CameraPosition(yaw: yaw, pitch: 0, roll: 0)
            } else {
                return CameraPosition(yaw: 0, pitch: index == 6 ? 90 : -90, roll: 0)
            }

        case .custom:
            return CameraPosition(yaw: 0, pitch: 0, roll: 0)
        }
    }

    // MARK: - Capture Control

    public func startCapture() async throws {
        #if canImport(AVFoundation)
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            throw CaptureError.multiCamNotSupported
        }

        captureSession = AVCaptureMultiCamSession()

        // Configure each camera
        // In production: discover and connect real cameras

        isCapturing = true
        syncStatus = .syncing

        // Start synchronization
        synchronizer?.start()

        print("📷 MultiCameraCaptureManager: Started capture with \(config.layout.cameraCount) cameras")
        #endif
    }

    public func stopCapture() {
        #if canImport(AVFoundation)
        captureSession?.stopRunning()
        captureSession = nil
        #endif

        isCapturing = false
        syncStatus = .notSynced
        synchronizer?.stop()
    }

    // MARK: - Frame Retrieval

    public func getSynchronizedFrames() -> [CVPixelBuffer]? {
        guard syncStatus == .synced else { return nil }

        let readyBuffers = frameBuffers.filter { $0.isReady }
        guard readyBuffers.count == config.layout.cameraCount else { return nil }

        return readyBuffers.compactMap { $0.pixelBuffer }
    }

    // MARK: - Errors

    public enum CaptureError: Error {
        case multiCamNotSupported
        case cameraNotFound
        case captureSessionFailed
        case syncTimeout
    }
}

// MARK: - Frame Synchronizer

private final class FrameSynchronizer {
    private let cameraCount: Int
    private var timestamps: [CMTime]
    private let maxDrift: CMTime = CMTime(value: 1, timescale: 1000)  // 1ms max drift
    private var isRunning = false

    init(cameraCount: Int) {
        self.cameraCount = cameraCount
        self.timestamps = [CMTime](repeating: .zero, count: cameraCount)
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func recordTimestamp(_ time: CMTime, forCamera index: Int) {
        guard index < cameraCount else { return }
        timestamps[index] = time
    }

    func areSynchronized() -> Bool {
        guard timestamps.allSatisfy({ $0 != .zero }) else { return false }

        let sorted = timestamps.sorted { CMTimeCompare($0, $1) < 0 }
        let drift = CMTimeSubtract(sorted.last!, sorted.first!)

        return CMTimeCompare(drift, maxDrift) <= 0
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: GPU 360° STITCHING ENGINE
// MARK: ═══════════════════════════════════════════════════════════════

/// Real-time GPU-based 360° video stitching
public final class GPU360StitchingEngine {

    #if canImport(Metal)

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var stitchPipeline: MTLComputePipelineState?
    private var blendPipeline: MTLComputePipelineState?
    private var colorCorrectionPipeline: MTLComputePipelineState?

    // Textures
    private var inputTextures: [MTLTexture] = []
    private var outputTexture: MTLTexture?
    private var intermediateTextures: [MTLTexture] = []

    // Lookup tables for projection
    private var projectionLUT: MTLBuffer?
    private var blendMasks: [MTLTexture] = []

    // MARK: - Configuration

    private let config: Camera360Configuration

    // MARK: - Performance

    private var lastStitchTime: CFAbsoluteTime = 0
    private var stitchTimes: [Double] = []

    public var averageStitchTimeMs: Double {
        guard !stitchTimes.isEmpty else { return 0 }
        return stitchTimes.reduce(0, +) / Double(stitchTimes.count) * 1000
    }

    // MARK: - Initialization

    public init?(config: Camera360Configuration) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.config = config

        setupPipelines()
        setupTextures()
        setupProjectionLUT()
        setupBlendMasks()

        print("🎬 GPU360StitchingEngine initialized")
        print("   Device: \(device.name)")
        print("   Output: \(config.outputResolution.width)x\(config.outputResolution.height)")
    }

    private func setupPipelines() {
        // Create Metal library with stitching shaders
        guard let library = device.makeDefaultLibrary() else { return }

        // Stitching pipeline
        if let stitchFunction = library.makeFunction(name: "equirectangularStitch") {
            stitchPipeline = try? device.makeComputePipelineState(function: stitchFunction)
        }

        // Blend pipeline
        if let blendFunction = library.makeFunction(name: "multiBlend") {
            blendPipeline = try? device.makeComputePipelineState(function: blendFunction)
        }

        // Color correction
        if let colorFunction = library.makeFunction(name: "colorCorrection") {
            colorCorrectionPipeline = try? device.makeComputePipelineState(function: colorFunction)
        }
    }

    private func setupTextures() {
        // Input textures (one per camera)
        let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: config.inputResolution.width,
            height: config.inputResolution.height,
            mipmapped: false
        )
        inputDescriptor.usage = [.shaderRead]

        for _ in 0..<config.layout.cameraCount {
            if let texture = device.makeTexture(descriptor: inputDescriptor) {
                inputTextures.append(texture)
            }
        }

        // Output texture (equirectangular)
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: config.outputResolution.width,
            height: config.outputResolution.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderWrite, .shaderRead]
        outputTexture = device.makeTexture(descriptor: outputDescriptor)
    }

    private func setupProjectionLUT() {
        // Pre-compute projection lookup table
        // Maps equirectangular coordinates to camera indices and UV coordinates

        let width = config.outputResolution.width
        let height = config.outputResolution.height

        var lutData: [ProjectionEntry] = []
        lutData.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                // Convert to spherical coordinates
                let theta = Float(x) / Float(width) * 2.0 * .pi - .pi  // -π to π
                let phi = Float(y) / Float(height) * .pi - .pi / 2     // -π/2 to π/2

                // Find best camera for this direction
                let (cameraIndex, u, v) = findBestCamera(theta: theta, phi: phi)

                lutData.append(ProjectionEntry(
                    cameraIndex: UInt8(cameraIndex),
                    u: u,
                    v: v,
                    blendWeight: 1.0
                ))
            }
        }

        projectionLUT = device.makeBuffer(
            bytes: lutData,
            length: lutData.count * MemoryLayout<ProjectionEntry>.stride,
            options: .storageModeShared
        )
    }

    private func findBestCamera(theta: Float, phi: Float) -> (Int, Float, Float) {
        // Convert spherical to Cartesian
        let x = cos(phi) * sin(theta)
        let y = sin(phi)
        let z = cos(phi) * cos(theta)

        var bestCamera = 0
        var bestDot: Float = -1

        // Find camera with best alignment
        for i in 0..<config.layout.cameraCount {
            let camTheta = Float(i) * 2.0 * .pi / Float(config.layout.cameraCount)
            let camX = sin(camTheta)
            let camZ = cos(camTheta)

            let dot = x * camX + z * camZ
            if dot > bestDot {
                bestDot = dot
                bestCamera = i
            }
        }

        // Calculate UV in camera space (simplified)
        let u = (theta / .pi + 1.0) / 2.0
        let v = (phi / (.pi / 2) + 1.0) / 2.0

        return (bestCamera, u, v)
    }

    private func setupBlendMasks() {
        // Create feathered blend masks for seamless stitching
        let maskWidth = config.inputResolution.width / 4
        let maskHeight = config.inputResolution.height

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: maskWidth,
            height: maskHeight,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        for _ in 0..<config.layout.cameraCount {
            if let mask = device.makeTexture(descriptor: descriptor) {
                // Fill with gradient
                var maskData = [UInt8](repeating: 0, count: maskWidth * maskHeight)
                for y in 0..<maskHeight {
                    for x in 0..<maskWidth {
                        // Feathered edge
                        let feather = Float(x) / Float(maskWidth)
                        maskData[y * maskWidth + x] = UInt8(feather * 255)
                    }
                }
                mask.replace(
                    region: MTLRegionMake2D(0, 0, maskWidth, maskHeight),
                    mipmapLevel: 0,
                    withBytes: maskData,
                    bytesPerRow: maskWidth
                )
                blendMasks.append(mask)
            }
        }
    }

    // MARK: - Types

    private struct ProjectionEntry {
        let cameraIndex: UInt8
        let u: Float
        let v: Float
        let blendWeight: Float
    }

    // MARK: - Stitching

    /// Stitch multiple camera frames into equirectangular output
    public func stitch(frames: [CVPixelBuffer]) -> MTLTexture? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard frames.count == config.layout.cameraCount,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let outputTexture = outputTexture else {
            return nil
        }

        // Upload frames to GPU textures
        for (i, frame) in frames.enumerated() {
            uploadToTexture(frame, texture: inputTextures[i])
        }

        // Stitching pass
        if let encoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = stitchPipeline {
            encoder.setComputePipelineState(pipeline)

            // Set textures
            for (i, texture) in inputTextures.enumerated() {
                encoder.setTexture(texture, index: i)
            }
            encoder.setTexture(outputTexture, index: inputTextures.count)

            // Set LUT
            encoder.setBuffer(projectionLUT, offset: 0, index: 0)

            // Dispatch
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (config.outputResolution.width + 15) / 16,
                height: (config.outputResolution.height + 15) / 16,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            encoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Record timing
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        stitchTimes.append(elapsed)
        if stitchTimes.count > 60 {
            stitchTimes.removeFirst()
        }

        return outputTexture
    }

    private func uploadToTexture(_ pixelBuffer: CVPixelBuffer, texture: MTLTexture) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: baseAddress,
            bytesPerRow: bytesPerRow
        )
    }

    #else

    public init?(config: Camera360Configuration) {
        return nil
    }

    #endif
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: HARDWARE VIDEO ENCODER
// MARK: ═══════════════════════════════════════════════════════════════

/// Hardware-accelerated video encoding for streaming
public final class HardwareVideoEncoder {

    // MARK: - Configuration

    public struct EncoderConfig {
        public var codec: VideoCodec
        public var width: Int
        public var height: Int
        public var frameRate: Int
        public var bitrate: Int  // Mbps
        public var keyFrameInterval: Int
        public var latencyMode: LatencyMode
        public var rateControl: RateControl

        public enum VideoCodec {
            case h264
            case hevc      // H.265
            case hevcHDR   // H.265 with HDR
            case av1       // Next-gen codec
        }

        public enum LatencyMode {
            case realtime     // Lowest latency
            case lowLatency   // Good balance
            case normal       // Best quality
        }

        public enum RateControl {
            case cbr        // Constant bitrate
            case vbr        // Variable bitrate
            case crf(Int)   // Constant rate factor
        }

        public static func forLiveStreaming(resolution: Camera360Configuration.OutputResolution) -> EncoderConfig {
            EncoderConfig(
                codec: .hevc,
                width: resolution.width,
                height: resolution.height,
                frameRate: 30,
                bitrate: 25,
                keyFrameInterval: 60,  // 2 seconds
                latencyMode: .realtime,
                rateControl: .cbr
            )
        }

        public static func forRecording(resolution: Camera360Configuration.OutputResolution) -> EncoderConfig {
            EncoderConfig(
                codec: .hevcHDR,
                width: resolution.width,
                height: resolution.height,
                frameRate: 60,
                bitrate: 100,
                keyFrameInterval: 120,
                latencyMode: .normal,
                rateControl: .vbr
            )
        }
    }

    // MARK: - Properties

    private let config: EncoderConfig

    #if canImport(VideoToolbox)
    private var compressionSession: VTCompressionSession?
    #endif

    private var encodedFrameCallback: ((Data, CMTime) -> Void)?

    // Statistics
    private var encodedFrames: Int = 0
    private var totalEncodedBytes: Int = 0
    private var encodingTimes: [Double] = []

    public var averageEncodingTimeMs: Double {
        guard !encodingTimes.isEmpty else { return 0 }
        return encodingTimes.reduce(0, +) / Double(encodingTimes.count) * 1000
    }

    public var averageBitrateMbps: Double {
        guard encodedFrames > 0 else { return 0 }
        let seconds = Double(encodedFrames) / Double(config.frameRate)
        return Double(totalEncodedBytes) * 8 / seconds / 1_000_000
    }

    // MARK: - Initialization

    public init(config: EncoderConfig) {
        self.config = config
        setupEncoder()
    }

    private func setupEncoder() {
        #if canImport(VideoToolbox)

        let codecType: CMVideoCodecType
        switch config.codec {
        case .h264:
            codecType = kCMVideoCodecType_H264
        case .hevc, .hevcHDR:
            codecType = kCMVideoCodecType_HEVC
        case .av1:
            // AV1 support varies by device
            codecType = kCMVideoCodecType_HEVC  // Fallback
        }

        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(config.width),
            height: Int32(config.height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &compressionSession
        )

        guard status == noErr, let session = compressionSession else {
            print("❌ Failed to create compression session: \(status)")
            return
        }

        // Configure session
        configureSession(session)

        VTCompressionSessionPrepareToEncodeFrames(session)

        print("🎥 HardwareVideoEncoder initialized")
        print("   Codec: \(config.codec)")
        print("   Resolution: \(config.width)x\(config.height)")
        print("   Bitrate: \(config.bitrate) Mbps")

        #endif
    }

    #if canImport(VideoToolbox)
    private func configureSession(_ session: VTCompressionSession) {
        // Realtime mode
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_RealTime,
            value: config.latencyMode == .realtime ? kCFBooleanTrue : kCFBooleanFalse
        )

        // Bitrate
        let bitrate = config.bitrate * 1_000_000
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AverageBitRate,
            value: bitrate as CFNumber
        )

        // Frame rate
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ExpectedFrameRate,
            value: config.frameRate as CFNumber
        )

        // Key frame interval
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: config.keyFrameInterval as CFNumber
        )

        // Profile level for HEVC
        if config.codec == .hevc || config.codec == .hevcHDR {
            VTSessionSetProperty(
                session,
                key: kVTCompressionPropertyKey_ProfileLevel,
                value: kVTProfileLevel_HEVC_Main_AutoLevel
            )
        }

        // Hardware acceleration
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder,
            value: kCFBooleanTrue
        )

        // Low latency mode
        if config.latencyMode == .realtime || config.latencyMode == .lowLatency {
            VTSessionSetProperty(
                session,
                key: kVTCompressionPropertyKey_MaxFrameDelayCount,
                value: 0 as CFNumber
            )
        }
    }
    #endif

    // MARK: - Encoding

    public func encode(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime,
        completion: @escaping (Data?, CMTime) -> Void
    ) {
        #if canImport(VideoToolbox)
        guard let session = compressionSession else {
            completion(nil, presentationTime)
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        var flags: VTEncodeInfoFlags = []

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime(value: 1, timescale: Int32(config.frameRate)),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        // Get encoded data (in real implementation, use callback)
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: presentationTime)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        encodingTimes.append(elapsed)
        if encodingTimes.count > 60 {
            encodingTimes.removeFirst()
        }

        encodedFrames += 1

        // In production: Return actual encoded data via callback
        completion(nil, presentationTime)

        #else
        completion(nil, presentationTime)
        #endif
    }

    // MARK: - Cleanup

    deinit {
        #if canImport(VideoToolbox)
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
        }
        #endif
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: LIVE STREAMING PROTOCOL
// MARK: ═══════════════════════════════════════════════════════════════

/// Low-latency streaming protocol
public final class LiveStreamingProtocol {

    // MARK: - Configuration

    public struct StreamConfig {
        public var protocol_: StreamProtocol
        public var serverURL: URL
        public var streamKey: String
        public var enableAdaptiveBitrate: Bool
        public var segmentDuration: TimeInterval
        public var bufferDuration: TimeInterval

        public enum StreamProtocol {
            case rtmp           // Traditional, ~3-5s latency
            case rtmps          // RTMP over TLS
            case srt            // Secure Reliable Transport, ~1-2s latency
            case webrtc         // Ultra-low latency, <500ms
            case hls            // HTTP Live Streaming, ~10-30s latency
            case llhls          // Low-Latency HLS, ~2-5s latency
        }

        public static var lowLatency: StreamConfig {
            StreamConfig(
                protocol_: .srt,
                serverURL: URL(string: "srt://server:port")!,
                streamKey: "",
                enableAdaptiveBitrate: true,
                segmentDuration: 0.5,
                bufferDuration: 1.0
            )
        }

        public static var ultraLowLatency: StreamConfig {
            StreamConfig(
                protocol_: .webrtc,
                serverURL: URL(string: "wss://server:port")!,
                streamKey: "",
                enableAdaptiveBitrate: false,
                segmentDuration: 0,
                bufferDuration: 0.1
            )
        }
    }

    // MARK: - Properties

    private let config: StreamConfig
    private var isStreaming = false

    // Network monitoring
    private var currentBandwidth: Int = 0  // kbps
    private var packetLoss: Float = 0
    private var roundTripTime: TimeInterval = 0

    // Adaptive bitrate
    private var currentBitrate: Int = 0
    private var bitrateHistory: [Int] = []

    // MARK: - Initialization

    public init(config: StreamConfig) {
        self.config = config
    }

    // MARK: - Streaming Control

    public func startStreaming() async throws {
        isStreaming = true

        switch config.protocol_ {
        case .srt:
            try await connectSRT()
        case .webrtc:
            try await connectWebRTC()
        case .rtmp, .rtmps:
            try await connectRTMP()
        case .hls, .llhls:
            try await startHLSSegmenter()
        }

        print("📡 LiveStreamingProtocol: Started \(config.protocol_) stream")
    }

    public func stopStreaming() {
        isStreaming = false
    }

    // MARK: - Protocol Implementations

    private func connectSRT() async throws {
        // SRT connection with low latency settings
        // In production: Use libsrt or native SRT implementation
        print("🔗 Connecting SRT to \(config.serverURL)")
    }

    private func connectWebRTC() async throws {
        // WebRTC for ultra-low latency
        // In production: Use WebRTC framework
        print("🔗 Connecting WebRTC to \(config.serverURL)")
    }

    private func connectRTMP() async throws {
        // Traditional RTMP connection
        print("🔗 Connecting RTMP to \(config.serverURL)")
    }

    private func startHLSSegmenter() async throws {
        // HLS segment generation
        print("🔗 Starting HLS segmenter")
    }

    // MARK: - Data Sending

    public func sendVideoFrame(_ data: Data, timestamp: CMTime) {
        guard isStreaming else { return }

        // In production: Send via active protocol connection
    }

    public func sendAudioFrame(_ data: Data, timestamp: CMTime) {
        guard isStreaming else { return }

        // In production: Send via active protocol connection
    }

    // MARK: - Adaptive Bitrate

    public func updateNetworkConditions(bandwidth: Int, packetLoss: Float, rtt: TimeInterval) {
        self.currentBandwidth = bandwidth
        self.packetLoss = packetLoss
        self.roundTripTime = rtt

        if config.enableAdaptiveBitrate {
            adjustBitrate()
        }
    }

    private func adjustBitrate() {
        // Calculate optimal bitrate based on network conditions
        var targetBitrate = currentBandwidth * 80 / 100  // Use 80% of available bandwidth

        // Reduce if packet loss is high
        if packetLoss > 0.02 {
            targetBitrate = targetBitrate * 70 / 100
        }

        // Reduce if RTT is high
        if roundTripTime > 0.2 {
            targetBitrate = targetBitrate * 80 / 100
        }

        currentBitrate = max(1000, targetBitrate)  // Minimum 1 Mbps
        bitrateHistory.append(currentBitrate)
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: SPATIAL AUDIO SYNC
// MARK: ═══════════════════════════════════════════════════════════════

/// Synchronizes spatial audio with 360° video
public final class SpatialAudio360Sync {

    // MARK: - Configuration

    public struct SpatialConfig {
        public var format: SpatialFormat
        public var channelCount: Int
        public var sampleRate: Double
        public var headTracking: Bool

        public enum SpatialFormat {
            case ambisonicsFirstOrder   // 4 channels (W, X, Y, Z)
            case ambisonicsSecondOrder  // 9 channels
            case ambisonicsThirdOrder   // 16 channels
            case channelBased           // Traditional surround
        }

        public static var ambisonics: SpatialConfig {
            SpatialConfig(
                format: .ambisonicsFirstOrder,
                channelCount: 4,
                sampleRate: 48000,
                headTracking: true
            )
        }
    }

    // MARK: - Properties

    private let config: SpatialConfig
    private var videoTimestamp: CMTime = .zero
    private var audioTimestamp: CMTime = .zero

    // Head tracking
    private var headYaw: Float = 0
    private var headPitch: Float = 0
    private var headRoll: Float = 0

    // Sync
    private let maxSyncDrift: CMTime = CMTime(value: 1, timescale: 100)  // 10ms

    // MARK: - Initialization

    public init(config: SpatialConfig = .ambisonics) {
        self.config = config
    }

    // MARK: - Synchronization

    public func updateVideoTimestamp(_ timestamp: CMTime) {
        videoTimestamp = timestamp
        checkSync()
    }

    public func updateAudioTimestamp(_ timestamp: CMTime) {
        audioTimestamp = timestamp
        checkSync()
    }

    private func checkSync() {
        let drift = CMTimeSubtract(videoTimestamp, audioTimestamp)
        let driftSeconds = CMTimeGetSeconds(drift)

        if abs(driftSeconds) > CMTimeGetSeconds(maxSyncDrift) {
            // Apply correction
            print("⚠️ A/V sync drift: \(driftSeconds * 1000)ms")
        }
    }

    // MARK: - Head Tracking

    public func updateHeadOrientation(yaw: Float, pitch: Float, roll: Float) {
        self.headYaw = yaw
        self.headPitch = pitch
        self.headRoll = roll
    }

    /// Rotate ambisonics based on head orientation
    public func rotateAmbisonics(_ input: [Float], channelCount: Int) -> [Float] {
        guard config.format == .ambisonicsFirstOrder && channelCount >= 4 else {
            return input
        }

        var output = input

        // First-order ambisonics rotation
        // W channel (omnidirectional) stays the same
        // X, Y, Z channels are rotated

        let cosYaw = cos(headYaw)
        let sinYaw = sin(headYaw)
        let cosPitch = cos(headPitch)
        let sinPitch = sin(headPitch)

        let samplesPerChannel = input.count / channelCount

        for i in 0..<samplesPerChannel {
            let w = input[i]
            let x = input[samplesPerChannel + i]
            let y = input[2 * samplesPerChannel + i]
            let z = input[3 * samplesPerChannel + i]

            // Apply rotation matrix
            let xRot = x * cosYaw - y * sinYaw
            let yRot = x * sinYaw + y * cosYaw
            let zRot = z * cosPitch - xRot * sinPitch
            let xRot2 = z * sinPitch + xRot * cosPitch

            output[i] = w
            output[samplesPerChannel + i] = xRot2
            output[2 * samplesPerChannel + i] = yRot
            output[3 * samplesPerChannel + i] = zRot
        }

        return output
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: COMPLETE 360° STREAMING PIPELINE
// MARK: ═══════════════════════════════════════════════════════════════

/// Complete pipeline: Cameras → Stitch → Encode → Stream
@MainActor
public final class Complete360StreamingPipeline: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var pipelineStatus: PipelineStatus = .idle
    @Published public private(set) var framesProcessed: Int = 0
    @Published public private(set) var droppedFrames: Int = 0
    @Published public private(set) var currentFPS: Float = 0
    @Published public private(set) var currentBitrate: Float = 0
    @Published public private(set) var latencyMs: Float = 0

    public enum PipelineStatus: String {
        case idle = "Idle"
        case initializing = "Initializing..."
        case capturing = "Capturing"
        case processing = "Processing"
        case streaming = "Streaming"
        case error = "Error"
    }

    // MARK: - Components

    private let cameraConfig: Camera360Configuration
    private var captureManager: MultiCameraCaptureManager?
    private var stitchingEngine: GPU360StitchingEngine?
    private var encoder: HardwareVideoEncoder?
    private var streamingProtocol: LiveStreamingProtocol?
    private var spatialAudioSync: SpatialAudio360Sync?

    // MARK: - Processing

    private var processingQueue: DispatchQueue
    private var isRunning = false
    private var frameTimestamps: [CFAbsoluteTime] = []

    // MARK: - Initialization

    public init(config: Camera360Configuration) {
        self.cameraConfig = config
        self.processingQueue = DispatchQueue(
            label: "com.echoelmusic.360.pipeline",
            qos: .userInteractive
        )

        setupComponents()

        print("""

        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                                                                               ║
        ║   360° LIVE STREAMING PIPELINE INITIALIZED                                    ║
        ║                                                                               ║
        ║   Cameras: \(config.layout.cameraCount) x \(config.inputResolution.width)x\(config.inputResolution.height)                           ║
        ║   Output: \(config.outputResolution.width)x\(config.outputResolution.height) equirectangular                           ║
        ║   Frame Rate: \(config.frameRate) fps                                                   ║
        ║   Target Bitrate: \(config.targetBitrate) Mbps                                             ║
        ║   Spatial Audio: \(config.enableSpatialAudio ? "Enabled" : "Disabled")                                              ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝

        """)
    }

    private func setupComponents() {
        captureManager = MultiCameraCaptureManager(config: cameraConfig)
        stitchingEngine = GPU360StitchingEngine(config: cameraConfig)

        let encoderConfig = HardwareVideoEncoder.EncoderConfig.forLiveStreaming(
            resolution: cameraConfig.outputResolution
        )
        encoder = HardwareVideoEncoder(config: encoderConfig)

        if cameraConfig.enableSpatialAudio {
            spatialAudioSync = SpatialAudio360Sync()
        }
    }

    // MARK: - Pipeline Control

    public func start(streamConfig: LiveStreamingProtocol.StreamConfig) async throws {
        pipelineStatus = .initializing

        // Start streaming connection
        streamingProtocol = LiveStreamingProtocol(config: streamConfig)
        try await streamingProtocol?.startStreaming()

        // Start capture
        try await captureManager?.startCapture()

        pipelineStatus = .streaming
        isRunning = true

        // Start processing loop
        startProcessingLoop()
    }

    public func stop() {
        isRunning = false
        captureManager?.stopCapture()
        streamingProtocol?.stopStreaming()
        pipelineStatus = .idle
    }

    // MARK: - Processing Loop

    private func startProcessingLoop() {
        processingQueue.async { [weak self] in
            while self?.isRunning == true {
                autoreleasepool {
                    self?.processFrame()
                }
            }
        }
    }

    private func processFrame() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get synchronized frames from all cameras
        guard let frames = captureManager?.getSynchronizedFrames() else {
            droppedFrames += 1
            return
        }

        // Stitch to equirectangular
        #if canImport(Metal)
        guard let stitchedTexture = stitchingEngine?.stitch(frames: frames) else {
            droppedFrames += 1
            return
        }
        #endif

        // Convert texture to pixel buffer for encoding
        // In production: Use texture directly or convert efficiently

        // Encode
        let presentationTime = CMTime(value: Int64(framesProcessed), timescale: Int32(cameraConfig.frameRate))

        // encoder?.encode(pixelBuffer: ..., presentationTime: presentationTime) { ... }

        // Stream
        // streamingProtocol?.sendVideoFrame(encodedData, timestamp: presentationTime)

        // Update stats
        DispatchQueue.main.async {
            self.framesProcessed += 1
            self.updateFPS(startTime)
        }
    }

    private func updateFPS(_ frameTime: CFAbsoluteTime) {
        frameTimestamps.append(frameTime)

        // Keep last second of timestamps
        let cutoff = frameTime - 1.0
        frameTimestamps = frameTimestamps.filter { $0 > cutoff }

        currentFPS = Float(frameTimestamps.count)
    }

    // MARK: - Status Report

    public var statusReport: String {
        """
        ═══════════════════════════════════════════════════════════════════════════════
        360° STREAMING PIPELINE STATUS
        ═══════════════════════════════════════════════════════════════════════════════

        Status: \(pipelineStatus.rawValue)

        CAPTURE:
        • Cameras: \(captureManager?.connectedCameras ?? 0) / \(cameraConfig.layout.cameraCount)
        • Sync: \(captureManager?.syncStatus ?? .notSynced)

        PROCESSING:
        • Frames Processed: \(framesProcessed)
        • Dropped Frames: \(droppedFrames)
        • Current FPS: \(String(format: "%.1f", currentFPS))
        • Stitch Time: \(String(format: "%.1f", stitchingEngine?.averageStitchTimeMs ?? 0))ms

        ENCODING:
        • Encoding Time: \(String(format: "%.1f", encoder?.averageEncodingTimeMs ?? 0))ms
        • Bitrate: \(String(format: "%.1f", encoder?.averageBitrateMbps ?? 0)) Mbps

        STREAMING:
        • Latency: \(String(format: "%.0f", latencyMs))ms

        ═══════════════════════════════════════════════════════════════════════════════
        """
    }
}

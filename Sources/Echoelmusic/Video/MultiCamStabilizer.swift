import Foundation
import AVFoundation
import Metal
import CoreImage
import Vision
import Combine
import Accelerate

// MARK: - Multi-Camera Manager
/// Professional multi-camera recording with synchronization
/// Supports simultaneous capture from multiple cameras (iPhone 11+, iPad Pro)
/// Features: Angle switching, timeline sync, live preview grid

@MainActor
class MultiCamManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isMultiCamSupported: Bool = false
    @Published var isCapturing: Bool = false
    @Published var activeAngles: [CameraAngle] = []
    @Published var primaryAngle: CameraAngle?
    @Published var syncStatus: SyncStatus = .notSynced

    // MARK: - Camera Angles

    struct CameraAngle: Identifiable, Equatable {
        let id = UUID()
        var camera: CameraManager.CameraPosition
        var label: String
        var isRecording: Bool = false
        var texture: MTLTexture?
        var lastTimestamp: CMTime = .zero

        static func == (lhs: CameraAngle, rhs: CameraAngle) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum SyncStatus: String {
        case notSynced = "Not Synced"
        case syncing = "Syncing"
        case synced = "Synced"
        case syncFailed = "Sync Failed"
    }

    // MARK: - Multi-Cam Session

    private var multiCamSession: AVCaptureMultiCamSession?
    private var cameraInputs: [CameraManager.CameraPosition: AVCaptureDeviceInput] = [:]
    private var videoOutputs: [CameraManager.CameraPosition: AVCaptureVideoDataOutput] = [:]
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.multicam", qos: .userInteractive)

    // MARK: - Metal

    private let device: MTLDevice
    private let textureCache: CVMetalTextureCache

    // MARK: - Recording

    private var assetWriters: [CameraManager.CameraPosition: AVAssetWriter] = [:]
    private var writerInputs: [CameraManager.CameraPosition: AVAssetWriterInput] = [:]
    private var pixelBufferAdaptors: [CameraManager.CameraPosition: AVAssetWriterInputPixelBufferAdaptor] = [:]
    private var recordingStartTime: CMTime?
    private var outputDirectory: URL?

    // MARK: - Callbacks

    var onFrameCaptured: ((CameraManager.CameraPosition, MTLTexture, CMTime) -> Void)?

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device

        // Create texture cache
        var textureCacheRef: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCacheRef)

        guard result == kCVReturnSuccess, let cache = textureCacheRef else {
            log.video("MultiCamManager: Failed to create texture cache", level: .error)
            return nil
        }
        self.textureCache = cache

        super.init()

        // Check multi-cam support
        isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported

        log.video("MultiCamManager: Initialized (Multi-Cam supported: \(isMultiCamSupported))")
    }

    // MARK: - Configure Multi-Cam Session

    func configureSession(cameras: [CameraManager.CameraPosition]) async throws {
        guard isMultiCamSupported else {
            throw MultiCamError.notSupported
        }

        // Request permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw MultiCamError.permissionDenied
            }
        } else if status != .authorized {
            throw MultiCamError.permissionDenied
        }

        // Create multi-cam session
        let session = AVCaptureMultiCamSession()
        session.beginConfiguration()

        // Add cameras
        activeAngles.removeAll()

        for camera in cameras {
            do {
                try addCamera(camera, to: session)

                let angle = CameraAngle(
                    camera: camera,
                    label: camera.rawValue
                )
                activeAngles.append(angle)

            } catch {
                log.video("MultiCamManager: Failed to add \(camera.rawValue): \(error)", level: .error)
            }
        }

        session.commitConfiguration()

        multiCamSession = session

        // Set primary angle
        if let first = activeAngles.first {
            primaryAngle = first
        }

        log.video("MultiCamManager: Configured \(activeAngles.count) cameras")
    }

    private func addCamera(_ camera: CameraManager.CameraPosition, to session: AVCaptureMultiCamSession) throws {
        // Find device
        guard let device = AVCaptureDevice.default(camera.deviceType, for: .video, position: camera.avPosition) else {
            throw MultiCamError.cameraNotFound(camera)
        }

        // Create input
        let input = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(input) else {
            throw MultiCamError.configurationFailed("Cannot add input for \(camera.rawValue)")
        }

        session.addInputWithNoConnections(input)
        cameraInputs[camera] = input

        // Create output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            throw MultiCamError.configurationFailed("Cannot add output for \(camera.rawValue)")
        }

        session.addOutputWithNoConnections(output)
        videoOutputs[camera] = output

        // Create connection
        guard let port = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: device.position).first else {
            throw MultiCamError.configurationFailed("No port for \(camera.rawValue)")
        }

        let connection = AVCaptureConnection(inputPorts: [port], output: output)

        guard session.canAddConnection(connection) else {
            throw MultiCamError.configurationFailed("Cannot add connection for \(camera.rawValue)")
        }

        session.addConnection(connection)

        // Configure connection
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported && camera == .front {
            connection.isVideoMirrored = true
        }
    }

    // MARK: - Start/Stop Capture

    func startCapture() {
        guard let session = multiCamSession, !isCapturing else { return }

        session.startRunning()
        isCapturing = true

        log.video("MultiCamManager: Started capture with \(activeAngles.count) cameras")
    }

    func stopCapture() {
        guard let session = multiCamSession, isCapturing else { return }

        session.stopRunning()
        isCapturing = false

        log.video("MultiCamManager: Stopped capture")
    }

    // MARK: - Recording

    func startRecording(to directory: URL) async throws {
        outputDirectory = directory

        // Create directory if needed
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        recordingStartTime = nil

        // Setup asset writer for each camera
        for angle in activeAngles {
            let outputURL = directory.appendingPathComponent("\(angle.camera.rawValue)_\(UUID().uuidString).mov")

            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: 1920,
                    kCVPixelBufferHeightKey as String: 1080
                ]
            )

            writer.add(writerInput)
            writer.startWriting()

            assetWriters[angle.camera] = writer
            writerInputs[angle.camera] = writerInput
            pixelBufferAdaptors[angle.camera] = adaptor

            // Update angle state
            if let index = activeAngles.firstIndex(where: { $0.id == angle.id }) {
                activeAngles[index].isRecording = true
            }
        }

        log.video("MultiCamManager: Started recording \(activeAngles.count) angles")
    }

    func stopRecording() async throws -> [URL] {
        var outputURLs: [URL] = []

        for (camera, writer) in assetWriters {
            writerInputs[camera]?.markAsFinished()

            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume()
                }
            }

            outputURLs.append(writer.outputURL)

            // Update angle state
            if let index = activeAngles.firstIndex(where: { $0.camera == camera }) {
                activeAngles[index].isRecording = false
            }
        }

        // Cleanup
        assetWriters.removeAll()
        writerInputs.removeAll()
        pixelBufferAdaptors.removeAll()
        recordingStartTime = nil

        log.video("MultiCamManager: Stopped recording, saved \(outputURLs.count) files")

        return outputURLs
    }

    // MARK: - Angle Switching

    func setPrimaryAngle(_ angle: CameraAngle) {
        primaryAngle = angle
        log.video("MultiCamManager: Switched primary to \(angle.camera.rawValue)")
    }

    func getPrimaryTexture() -> MTLTexture? {
        return primaryAngle?.texture
    }

    // MARK: - Texture Creation

    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var textureRef: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
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
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MultiCamManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Determine which camera this is from
        Task { @MainActor in
            for (camera, videoOutput) in self.videoOutputs {
                if videoOutput === output {
                    // Create texture
                    if let texture = self.createTexture(from: pixelBuffer) {
                        // Update angle
                        if let index = self.activeAngles.firstIndex(where: { $0.camera == camera }) {
                            self.activeAngles[index].texture = texture
                            self.activeAngles[index].lastTimestamp = timestamp
                        }

                        // Callback
                        self.onFrameCaptured?(camera, texture, timestamp)
                    }

                    // Write to file if recording
                    if let writerInput = self.writerInputs[camera],
                       let adaptor = self.pixelBufferAdaptors[camera] {

                        // Set start time on first frame
                        if self.recordingStartTime == nil {
                            self.recordingStartTime = timestamp
                            for writer in self.assetWriters.values {
                                writer.startSession(atSourceTime: timestamp)
                            }
                        }

                        if writerInput.isReadyForMoreMediaData {
                            adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                        }
                    }

                    break
                }
            }
        }
    }
}

// MARK: - Video Stabilizer
/// Professional video stabilization using Vision framework
/// Modes: Standard, Cinematic (smooth), Locked (tripod-like)
/// Real-time and post-processing capable

@MainActor
class VideoStabilizer: ObservableObject {

    // MARK: - Published State

    @Published var isStabilizing: Bool = false
    @Published var stabilizationMode: StabilizationMode = .standard
    @Published var stabilizationStrength: Float = 0.8 // 0-1
    @Published var progress: Double = 0.0

    // MARK: - Stabilization Modes

    enum StabilizationMode: String, CaseIterable {
        case off = "Off"
        case standard = "Standard"
        case cinematic = "Cinematic"
        case locked = "Locked"

        var description: String {
            switch self {
            case .off: return "No stabilization"
            case .standard: return "Smooth handheld motion"
            case .cinematic: return "Ultra-smooth, film-like"
            case .locked: return "Tripod simulation"
            }
        }
    }

    // MARK: - Motion Data

    struct FrameMotion {
        var timestamp: CMTime
        var translation: CGPoint
        var rotation: CGFloat
        var scale: CGFloat
    }

    // MARK: - Internal State

    private var motionHistory: [FrameMotion] = []
    private var smoothedPath: [FrameMotion] = []
    private let historyLength: Int = 30 // Frames to analyze

    // MARK: - Vision

    private let sequenceHandler = VNSequenceRequestHandler()
    private var previousObservation: VNFeaturePrintObservation?
    private var referenceFrame: CVPixelBuffer?

    // MARK: - Real-Time Stabilization

    /// Apply real-time stabilization to incoming frame
    func stabilizeFrame(pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> CIImage? {
        guard stabilizationMode != .off else {
            return CIImage(cvPixelBuffer: pixelBuffer)
        }

        // Track motion
        let motion = analyzeMotion(pixelBuffer: pixelBuffer, timestamp: timestamp)
        motionHistory.append(motion)

        // Keep history limited
        if motionHistory.count > historyLength {
            motionHistory.removeFirst()
        }

        // Calculate smoothed correction
        let correction = calculateCorrection()

        // Apply transform
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: -correction.translation.x * CGFloat(stabilizationStrength),
                                           y: -correction.translation.y * CGFloat(stabilizationStrength))
        transform = transform.rotated(by: -correction.rotation * CGFloat(stabilizationStrength))

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciImage.transformed(by: transform)
    }

    /// Analyze motion between current and previous frame
    private func analyzeMotion(pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> FrameMotion {
        var translation = CGPoint.zero
        var rotation: CGFloat = 0
        var scale: CGFloat = 1.0

        // Use Vision for optical flow
        let request = VNGenerateOpticalFlowRequest()

        if let reference = referenceFrame {
            do {
                try sequenceHandler.perform([request], on: pixelBuffer, against: reference)

                if let result = request.results?.first as? VNPixelBufferObservation {
                    // Analyze flow field
                    let flowData = analyzeFlowField(result.pixelBuffer)
                    translation = flowData.translation
                    rotation = flowData.rotation
                    scale = flowData.scale
                }
            } catch {
                // Motion analysis failed, use zero motion
            }
        }

        referenceFrame = pixelBuffer

        return FrameMotion(
            timestamp: timestamp,
            translation: translation,
            rotation: rotation,
            scale: scale
        )
    }

    /// Analyze optical flow field to extract motion
    private func analyzeFlowField(_ flowBuffer: CVPixelBuffer) -> (translation: CGPoint, rotation: CGFloat, scale: CGFloat) {
        CVPixelBufferLockBaseAddress(flowBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(flowBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(flowBuffer)
        let height = CVPixelBufferGetHeight(flowBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(flowBuffer) else {
            return (.zero, 0, 1)
        }

        let floatPointer = baseAddress.assumingMemoryBound(to: Float.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(flowBuffer)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float>.size

        // Sample flow at grid points
        var totalDx: Float = 0
        var totalDy: Float = 0
        var sampleCount = 0

        let step = 32 // Sample every 32 pixels
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = y * floatsPerRow + x * 2
                let dx = floatPointer[index]
                let dy = floatPointer[index + 1]

                if dx.isFinite && dy.isFinite {
                    totalDx += dx
                    totalDy += dy
                    sampleCount += 1
                }
            }
        }

        guard sampleCount > 0 else {
            return (.zero, 0, 1)
        }

        let avgDx = CGFloat(totalDx / Float(sampleCount))
        let avgDy = CGFloat(totalDy / Float(sampleCount))

        return (CGPoint(x: avgDx, y: avgDy), 0, 1)
    }

    /// Calculate smoothed correction based on mode
    private func calculateCorrection() -> FrameMotion {
        guard !motionHistory.isEmpty else {
            return FrameMotion(timestamp: .zero, translation: .zero, rotation: 0, scale: 1)
        }

        switch stabilizationMode {
        case .off:
            return FrameMotion(timestamp: .zero, translation: .zero, rotation: 0, scale: 1)

        case .standard:
            // Moving average
            return movingAverageCorrection(windowSize: 5)

        case .cinematic:
            // Gaussian smoothing for ultra-smooth motion
            return gaussianSmoothedCorrection(sigma: 10)

        case .locked:
            // Full correction to reference frame
            return fullCorrection()
        }
    }

    private func movingAverageCorrection(windowSize: Int) -> FrameMotion {
        let window = motionHistory.suffix(windowSize)

        var avgX: CGFloat = 0
        var avgY: CGFloat = 0
        var avgRot: CGFloat = 0

        for motion in window {
            avgX += motion.translation.x
            avgY += motion.translation.y
            avgRot += motion.rotation
        }

        let count = CGFloat(window.count)
        return FrameMotion(
            timestamp: motionHistory.last?.timestamp ?? .zero,
            translation: CGPoint(x: avgX / count, y: avgY / count),
            rotation: avgRot / count,
            scale: 1
        )
    }

    private func gaussianSmoothedCorrection(sigma: Double) -> FrameMotion {
        guard motionHistory.count >= 3 else {
            return movingAverageCorrection(windowSize: 3)
        }

        // Gaussian kernel
        let kernelSize = min(motionHistory.count, Int(sigma * 3))
        var weights: [Double] = []
        var totalWeight: Double = 0

        for i in 0..<kernelSize {
            let x = Double(i - kernelSize / 2)
            let weight = exp(-x * x / (2 * sigma * sigma))
            weights.append(weight)
            totalWeight += weight
        }

        // Normalize weights
        weights = weights.map { $0 / totalWeight }

        // Apply kernel
        var smoothedX: CGFloat = 0
        var smoothedY: CGFloat = 0
        var smoothedRot: CGFloat = 0

        let startIndex = max(0, motionHistory.count - kernelSize)

        for (i, motion) in motionHistory.suffix(kernelSize).enumerated() {
            let weight = CGFloat(weights[i])
            smoothedX += motion.translation.x * weight
            smoothedY += motion.translation.y * weight
            smoothedRot += motion.rotation * weight
        }

        return FrameMotion(
            timestamp: motionHistory.last?.timestamp ?? .zero,
            translation: CGPoint(x: smoothedX, y: smoothedY),
            rotation: smoothedRot,
            scale: 1
        )
    }

    private func fullCorrection() -> FrameMotion {
        // Sum all motion to get total displacement from start
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        var totalRot: CGFloat = 0

        for motion in motionHistory {
            totalX += motion.translation.x
            totalY += motion.translation.y
            totalRot += motion.rotation
        }

        return FrameMotion(
            timestamp: motionHistory.last?.timestamp ?? .zero,
            translation: CGPoint(x: totalX, y: totalY),
            rotation: totalRot,
            scale: 1
        )
    }

    // MARK: - Post-Processing Stabilization

    /// Stabilize entire video file (offline processing)
    func stabilizeVideo(inputURL: URL, outputURL: URL, mode: StabilizationMode) async throws {
        isStabilizing = true
        progress = 0

        defer {
            isStabilizing = false
            progress = 1.0
        }

        // Load asset
        let asset = AVURLAsset(url: inputURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw StabilizationError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let transform = try await videoTrack.load(.preferredTransform)
        let naturalSize = try await videoTrack.load(.naturalSize)

        // Setup reader
        let reader = try AVAssetReader(asset: asset)
        let readerSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        reader.add(readerOutput)

        // First pass: Analyze motion
        reader.startReading()
        motionHistory.removeAll()

        var frameIndex = 0
        let totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let motion = analyzeMotion(pixelBuffer: pixelBuffer, timestamp: timestamp)
                motionHistory.append(motion)

                frameIndex += 1
                Task { @MainActor in
                    self.progress = Double(frameIndex) / Double(totalFrames) / 2.0 // First 50%
                }
            }
        }

        reader.cancelReading()

        // Calculate smoothed path
        calculateSmoothedPath(mode: mode)

        // Second pass: Apply stabilization
        let reader2 = try AVAssetReader(asset: asset)
        let readerOutput2 = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        reader2.add(readerOutput2)

        // Setup writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.transform = transform

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )

        writer.add(writerInput)
        reader2.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        frameIndex = 0
        let ciContext = CIContext()

        while let sampleBuffer = readerOutput2.copyNextSampleBuffer() {
            autoreleasepool {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // Apply stabilization
                let stabilized = applyStabilization(
                    to: pixelBuffer,
                    frameIndex: frameIndex,
                    context: ciContext
                )

                // Wait for writer
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }

                // Append frame
                if let outputBuffer = stabilized {
                    adaptor.append(outputBuffer, withPresentationTime: timestamp)
                }

                frameIndex += 1
                Task { @MainActor in
                    self.progress = 0.5 + Double(frameIndex) / Double(totalFrames) / 2.0 // Second 50%
                }
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        log.video("VideoStabilizer: Completed stabilization of \(totalFrames) frames")
    }

    private func calculateSmoothedPath(mode: StabilizationMode) {
        smoothedPath.removeAll()

        // Calculate cumulative motion
        var cumulative: [FrameMotion] = []
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        var totalRot: CGFloat = 0

        for motion in motionHistory {
            totalX += motion.translation.x
            totalY += motion.translation.y
            totalRot += motion.rotation

            cumulative.append(FrameMotion(
                timestamp: motion.timestamp,
                translation: CGPoint(x: totalX, y: totalY),
                rotation: totalRot,
                scale: 1
            ))
        }

        // Smooth the cumulative path based on mode
        let windowSize: Int
        switch mode {
        case .off:
            smoothedPath = cumulative
            return
        case .standard:
            windowSize = 15
        case .cinematic:
            windowSize = 60
        case .locked:
            // For locked, target is the average position
            let avgX = cumulative.map { $0.translation.x }.reduce(0, +) / CGFloat(cumulative.count)
            let avgY = cumulative.map { $0.translation.y }.reduce(0, +) / CGFloat(cumulative.count)
            let avgRot = cumulative.map { $0.rotation }.reduce(0, +) / CGFloat(cumulative.count)

            smoothedPath = cumulative.map { motion in
                FrameMotion(
                    timestamp: motion.timestamp,
                    translation: CGPoint(x: avgX, y: avgY),
                    rotation: avgRot,
                    scale: 1
                )
            }
            return
        }

        // Apply moving average smoothing
        for i in 0..<cumulative.count {
            let start = max(0, i - windowSize / 2)
            let end = min(cumulative.count, i + windowSize / 2 + 1)

            var avgX: CGFloat = 0
            var avgY: CGFloat = 0
            var avgRot: CGFloat = 0

            for j in start..<end {
                avgX += cumulative[j].translation.x
                avgY += cumulative[j].translation.y
                avgRot += cumulative[j].rotation
            }

            let count = CGFloat(end - start)
            smoothedPath.append(FrameMotion(
                timestamp: cumulative[i].timestamp,
                translation: CGPoint(x: avgX / count, y: avgY / count),
                rotation: avgRot / count,
                scale: 1
            ))
        }
    }

    private func applyStabilization(to pixelBuffer: CVPixelBuffer, frameIndex: Int, context: CIContext) -> CVPixelBuffer? {
        guard frameIndex < motionHistory.count && frameIndex < smoothedPath.count else {
            return pixelBuffer
        }

        // Calculate correction
        let original = motionHistory.prefix(frameIndex + 1).reduce(CGPoint.zero) { result, motion in
            CGPoint(x: result.x + motion.translation.x, y: result.y + motion.translation.y)
        }

        let smoothed = smoothedPath[frameIndex].translation

        let correctionX = (smoothed.x - original.x) * CGFloat(stabilizationStrength)
        let correctionY = (smoothed.y - original.y) * CGFloat(stabilizationStrength)

        // Apply transform
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Scale up slightly to hide edges
        let scaleUp: CGFloat = 1.0 + CGFloat(stabilizationStrength) * 0.1
        let centerX = ciImage.extent.midX
        let centerY = ciImage.extent.midY

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerX, y: centerY)
        transform = transform.scaledBy(x: scaleUp, y: scaleUp)
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        transform = transform.translatedBy(x: correctionX, y: correctionY)

        ciImage = ciImage.transformed(by: transform)

        // Crop to original size
        ciImage = ciImage.cropped(to: CGRect(
            x: ciImage.extent.origin.x + (ciImage.extent.width - CGFloat(CVPixelBufferGetWidth(pixelBuffer))) / 2,
            y: ciImage.extent.origin.y + (ciImage.extent.height - CGFloat(CVPixelBufferGetHeight(pixelBuffer))) / 2,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        ))

        // Render to new pixel buffer
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            kCVPixelFormatType_32BGRA,
            nil,
            &newPixelBuffer
        )

        if let buffer = newPixelBuffer {
            context.render(ciImage, to: buffer)
        }

        return newPixelBuffer
    }

    // MARK: - Reset

    func reset() {
        motionHistory.removeAll()
        smoothedPath.removeAll()
        referenceFrame = nil
        previousObservation = nil
    }
}

// MARK: - Multi-Cam Timeline Integration
/// Integrates multi-cam with VideoEditingEngine

struct MultiCamClip: Identifiable {
    let id = UUID()
    var angleURLs: [CameraManager.CameraPosition: URL]
    var activeAngle: CameraManager.CameraPosition
    var angleSwitches: [AngleSwitch] = []
    var startTime: CMTime
    var duration: CMTime

    struct AngleSwitch {
        var time: CMTime
        var toAngle: CameraManager.CameraPosition
    }
}

extension VideoEditingEngine {

    /// Add multi-cam clip to timeline
    func addMultiCamClip(_ clip: MultiCamClip) {
        // Create video track from active angle
        guard let url = clip.angleURLs[clip.activeAngle] else { return }

        let asset = AVURLAsset(url: url)
        let track = VideoTrack(
            asset: asset,
            startTime: clip.startTime,
            duration: clip.duration
        )

        videoTracks.append(track)

        log.video("VideoEditingEngine: Added multi-cam clip with \(clip.angleURLs.count) angles")
    }

    /// Switch angle at specific time
    func switchMultiCamAngle(clipID: UUID, at time: CMTime, to angle: CameraManager.CameraPosition) {
        // In production: Handle angle switch in timeline
        log.video("VideoEditingEngine: Switching to \(angle.rawValue) at \(CMTimeGetSeconds(time))s")
    }
}

// MARK: - Errors

enum MultiCamError: LocalizedError {
    case notSupported
    case permissionDenied
    case cameraNotFound(CameraManager.CameraPosition)
    case configurationFailed(String)
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Multi-camera not supported on this device"
        case .permissionDenied:
            return "Camera permission denied"
        case .cameraNotFound(let camera):
            return "Camera '\(camera.rawValue)' not found"
        case .configurationFailed(let reason):
            return "Configuration failed: \(reason)"
        case .recordingFailed:
            return "Multi-cam recording failed"
        }
    }
}

enum StabilizationError: LocalizedError {
    case noVideoTrack
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found in file"
        case .processingFailed:
            return "Stabilization processing failed"
        }
    }
}

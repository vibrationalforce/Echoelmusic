import Foundation
import AVFoundation
#if canImport(Metal)
import Metal
#endif
import CoreImage
import Combine

/// Camera Manager for Real-Time Video Capture
/// Optimized for 120 FPS @ 1080p on iPhone 16 Pro
/// Zero-copy texture pipeline from camera to Metal
@MainActor
public class CameraManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published public var isCapturing: Bool = false
    @Published public var currentCamera: CameraPosition = .back
    @Published public var currentResolution: Resolution = .hd1920x1080
    @Published public var currentFrameRate: Int = 60
    @Published public var availableCameras: [CameraPosition] = []

    // MARK: - Performance Metrics

    @Published public var actualFrameRate: Double = 0.0
    @Published public var droppedFrames: Int = 0

    // MARK: - Camera Positions

    public enum CameraPosition: String, CaseIterable {
        case front = "Front"
        case back = "Back"
        case ultraWide = "Ultra Wide"
        case telephoto = "Telephoto"
        case trueDepth = "TrueDepth"

        var avPosition: AVCaptureDevice.Position {
            switch self {
            case .front, .trueDepth:
                return .front
            case .back, .ultraWide, .telephoto:
                return .back
            }
        }

        var deviceType: AVCaptureDevice.DeviceType {
            switch self {
            case .front, .back:
                return .builtInWideAngleCamera
            case .ultraWide:
                return .builtInUltraWideCamera
            case .telephoto:
                return .builtInTelephotoCamera
            case .trueDepth:
                return .builtInTrueDepthCamera
            }
        }
    }

    // MARK: - Resolution Presets

    public enum Resolution: String, CaseIterable {
        case hd1280x720 = "720p"
        case hd1920x1080 = "1080p"
        case uhd3840x2160 = "4K"

        var preset: AVCaptureSession.Preset {
            switch self {
            case .hd1280x720: return .hd1280x720
            case .hd1920x1080: return .hd1920x1080
            case .uhd3840x2160: return .hd4K3840x2160
            }
        }

        var size: CGSize {
            switch self {
            case .hd1280x720: return CGSize(width: 1280, height: 720)
            case .hd1920x1080: return CGSize(width: 1920, height: 1080)
            case .uhd3840x2160: return CGSize(width: 3840, height: 2160)
            }
        }
    }

    // MARK: - AVCapture Components

    private let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.camera.capture", qos: .userInteractive)

    // MARK: - Metal Integration

    private let device: MTLDevice
    private let ciContext: CIContext
    private let textureCache: CVMetalTextureCache

    // MARK: - Frame Callback

    var onFrameCaptured: ((MTLTexture, CMTime) -> Void)?

    // MARK: - Performance Tracking

    private var lastFrameTime: CMTime?
    private var frameCount: Int = 0
    private var fpsTimer: Timer?

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device

        // Create Core Image context
        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .name: "CameraContext"
        ])

        // Create texture cache for zero-copy pipeline
        var textureCacheRef: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCacheRef
        )

        guard result == kCVReturnSuccess, let textureCache = textureCacheRef else {
            log.video("❌ CameraManager: Failed to create texture cache", level: .error)
            return nil
        }
        self.textureCache = textureCache

        super.init()

        // Discover available cameras
        discoverCameras()

        log.video("✅ CameraManager: Initialized")
    }

    deinit {
        // stopCapture() is @MainActor-isolated, cannot call from deinit
    }

    // MARK: - Discover Cameras

    private func discoverCameras() {
        availableCameras.removeAll()

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        )

        for device in discoverySession.devices {
            switch device.deviceType {
            case .builtInWideAngleCamera:
                if device.position == .front {
                    availableCameras.append(.front)
                } else {
                    availableCameras.append(.back)
                }
            case .builtInUltraWideCamera:
                availableCameras.append(.ultraWide)
            case .builtInTelephotoCamera:
                availableCameras.append(.telephoto)
            case .builtInTrueDepthCamera:
                availableCameras.append(.trueDepth)
            default:
                break
            }
        }

        log.video("📷 CameraManager: Found \(availableCameras.count) cameras: \(availableCameras.map { $0.rawValue }.joined(separator: ", "))")
    }

    // MARK: - Start Capture

    func startCapture(camera: CameraPosition? = nil, resolution: Resolution? = nil, frameRate: Int? = nil) async throws {
        guard !isCapturing else { return }

        // Update settings
        if let camera = camera {
            currentCamera = camera
        }
        if let resolution = resolution {
            currentResolution = resolution
        }
        if let frameRate = frameRate {
            currentFrameRate = frameRate
        }

        // Request camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        case .authorized:
            break
        @unknown default:
            throw CameraError.permissionDenied
        }

        // Configure capture session
        captureSession.beginConfiguration()

        // Set session preset
        if captureSession.canSetSessionPreset(currentResolution.preset) {
            captureSession.sessionPreset = currentResolution.preset
        } else {
            captureSession.sessionPreset = .high
        }

        // Find device
        guard let device = AVCaptureDevice.default(
            currentCamera.deviceType,
            for: .video,
            position: currentCamera.avPosition
        ) else {
            captureSession.commitConfiguration()
            throw CameraError.cameraNotFound(currentCamera)
        }

        // Configure device
        try device.lockForConfiguration()

        // Set frame rate
        let targetFrameRate = Double(currentFrameRate)
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if CGFloat(dimensions.width) == currentResolution.size.width &&
               CGFloat(dimensions.height) == currentResolution.size.height {

                for range in format.videoSupportedFrameRateRanges {
                    if range.minFrameRate <= targetFrameRate && targetFrameRate <= range.maxFrameRate {
                        bestFormat = format
                        bestFrameRateRange = range
                        break
                    }
                }
            }
        }

        if let format = bestFormat, let range = bestFrameRateRange {
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
            log.video("📷 CameraManager: Set format to \(currentResolution.rawValue) @ \(targetFrameRate) FPS")
        } else {
            log.video("⚠️ CameraManager: Could not set target frame rate, using default", level: .warning)
        }

        device.unlockForConfiguration()

        // Create input
        let input = try AVCaptureDeviceInput(device: device)

        // Remove old input
        if let oldInput = videoInput {
            captureSession.removeInput(oldInput)
        }

        // Add new input
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            videoInput = input
            videoDevice = device
        } else {
            captureSession.commitConfiguration()
            throw CameraError.inputConfigurationFailed
        }

        // Configure output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        // Remove old output
        if let oldOutput = videoOutput {
            captureSession.removeOutput(oldOutput)
        }

        // Add new output
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        } else {
            captureSession.commitConfiguration()
            throw CameraError.outputConfigurationFailed
        }

        // Set video orientation
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported && currentCamera == .front {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()

        // Start session
        captureSession.startRunning()

        isCapturing = true
        droppedFrames = 0
        frameCount = 0

        // Start FPS monitoring
        startFPSMonitoring()

        log.video("▶️ CameraManager: Started capture with \(currentCamera.rawValue) camera at \(currentResolution.rawValue) @ \(currentFrameRate) FPS")
    }

    // MARK: - Stop Capture

    func stopCapture() {
        guard isCapturing else { return }

        captureSession.stopRunning()
        isCapturing = false

        stopFPSMonitoring()

        log.video("⏹️ CameraManager: Stopped capture")
    }

    // MARK: - Switch Camera

    func switchCamera(to camera: CameraPosition) async throws {
        let wasCapturing = isCapturing

        if wasCapturing {
            stopCapture()
        }

        currentCamera = camera

        if wasCapturing {
            try await startCapture()
        }
    }

    // MARK: - FPS Monitoring

    private func startFPSMonitoring() {
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.actualFrameRate = Double(self.frameCount)
                self.frameCount = 0
            }
        }
    }

    private func stopFPSMonitoring() {
        fpsTimer?.invalidate()
        fpsTimer = nil
    }

    // MARK: - Create Texture from Pixel Buffer (Zero-Copy)

    private nonisolated func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
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

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Create Metal texture (zero-copy)
        guard let texture = createTexture(from: pixelBuffer) else {
            Task { @MainActor in
                self.droppedFrames += 1
            }
            return
        }

        // Get presentation time
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Update frame count
        Task { @MainActor in
            self.frameCount += 1
            self.lastFrameTime = presentationTime
        }

        // Call callback
        Task { @MainActor in
            self.onFrameCaptured?(texture, presentationTime)
        }
    }

    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor in
            self.droppedFrames += 1
        }
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case permissionDenied
    case cameraNotFound(CameraManager.CameraPosition)
    case inputConfigurationFailed
    case outputConfigurationFailed
    case captureSessionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .cameraNotFound(let position):
            return "Camera '\(position.rawValue)' not found"
        case .inputConfigurationFailed:
            return "Failed to configure camera input"
        case .outputConfigurationFailed:
            return "Failed to configure camera output"
        case .captureSessionFailed:
            return "Camera capture session failed"
        }
    }
}

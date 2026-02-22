import Foundation
import AVFoundation
#if canImport(Metal)
import Metal
#endif
import CoreImage
import Combine
#if canImport(Photos)
import Photos
#endif

/// Professional Camera Manager for Real-Time Video Capture
/// Optimized for 120 FPS @ 1080p on iPhone 16 Pro
/// Zero-copy texture pipeline from camera to Metal
/// Full manual exposure, focus, white balance, zoom, stabilization, HDR, depth, photo & ProRes
@MainActor
public class CameraManager: NSObject, ObservableObject {

    // MARK: - Published State — Basic

    @Published public var isCapturing: Bool = false
    @Published public var currentCamera: CameraPosition = .back
    @Published public var currentResolution: Resolution = .hd1920x1080
    @Published public var currentFrameRate: Int = 60
    @Published public var availableCameras: [CameraPosition] = []

    // MARK: - Published State — Professional Exposure

    @Published public var exposureMode: ExposureMode = .auto
    @Published public var currentISO: Float = 100
    @Published public var currentShutterSpeed: CMTime = CMTime(value: 1, timescale: 60)
    @Published public var exposureCompensation: Float = 0.0
    @Published public var isoRange: ClosedRange<Float> = 32...3200
    @Published public var shutterSpeedRange: ClosedRange<Double> = (1.0/8000)...(1.0/2)

    // MARK: - Published State — Professional Focus

    @Published public var focusMode: FocusMode = .continuousAuto
    @Published public var focusPosition: Float = 0.5
    @Published public var isFocusLocked: Bool = false
    @Published public var focusPointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5)

    // MARK: - Published State — White Balance

    @Published public var whiteBalanceMode: WhiteBalanceMode = .auto
    @Published public var colorTemperature: Float = 5500
    @Published public var tint: Float = 0.0

    // MARK: - Published State — Zoom

    @Published public var zoomFactor: CGFloat = 1.0
    @Published public var maxZoomFactor: CGFloat = 1.0
    @Published public var minZoomFactor: CGFloat = 1.0

    // MARK: - Published State — Torch / Flash

    @Published public var torchMode: TorchMode = .off
    @Published public var torchLevel: Float = 1.0

    // MARK: - Published State — Stabilization

    @Published public var stabilizationMode: StabilizationMode = .auto
    @Published public var activeStabilizationMode: String = "Off"

    // MARK: - Published State — HDR & Color

    @Published public var isHDREnabled: Bool = false
    @Published public var isHDRSupported: Bool = false

    // MARK: - Published State — Depth

    @Published public var isDepthEnabled: Bool = false
    @Published public var isDepthSupported: Bool = false

    // MARK: - Published State — Recording

    @Published public var isRecording: Bool = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var isProResSupported: Bool = false

    // MARK: - Published State — Photo

    @Published public var isCapturingPhoto: Bool = false
    @Published public var isRAWSupported: Bool = false
    @Published public var lastCapturedPhotoData: Data?

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

    // MARK: - Exposure Mode

    public enum ExposureMode: String, CaseIterable {
        case auto = "Auto"
        case locked = "Locked"
        case custom = "Manual"
    }

    // MARK: - Focus Mode

    public enum FocusMode: String, CaseIterable {
        case auto = "Auto"
        case continuousAuto = "Continuous"
        case locked = "Locked"
        case manual = "Manual"
    }

    // MARK: - White Balance Mode

    public enum WhiteBalanceMode: String, CaseIterable {
        case auto = "Auto"
        case locked = "Locked"
        case custom = "Custom"
    }

    // MARK: - Torch Mode

    public enum TorchMode: String, CaseIterable {
        case off = "Off"
        case on = "On"
        case auto = "Auto"
    }

    // MARK: - Stabilization Mode

    public enum StabilizationMode: String, CaseIterable {
        case off = "Off"
        case standard = "Standard"
        case cinematic = "Cinematic"
        case cinematicExtended = "Cinematic Extended"
        case auto = "Auto"
    }

    // MARK: - Photo Format

    public enum PhotoFormat: String, CaseIterable {
        case heif = "HEIF"
        case jpeg = "JPEG"
        case raw = "RAW (DNG)"
    }

    // MARK: - AVCapture Components

    private let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var depthOutput: AVCaptureDepthDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.camera.capture", qos: .userInteractive)
    private let photoQueue = DispatchQueue(label: "com.echoelmusic.camera.photo", qos: .userInitiated)

    // MARK: - Metal Integration

    private let mtlDevice: MTLDevice
    private let ciContext: CIContext
    private let textureCache: CVMetalTextureCache

    // MARK: - Frame Callback

    var onFrameCaptured: ((MTLTexture, CMTime) -> Void)?
    var onDepthDataCaptured: ((AVDepthData) -> Void)?

    // MARK: - Performance Tracking

    private var lastFrameTime: CMTime?
    private var frameCount: Int = 0
    private var fpsTimer: Timer?

    // MARK: - Recording State

    private var recordingTimer: Timer?
    private var photoContinuation: CheckedContinuation<Data, Error>?

    // MARK: - KVO Observers

    private var exposureObserver: NSKeyValueObservation?
    private var focusObserver: NSKeyValueObservation?
    private var whiteBalanceObserver: NSKeyValueObservation?
    private var zoomObserver: NSKeyValueObservation?

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.mtlDevice = device

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
            log.video("CameraManager: Failed to create texture cache", level: .error)
            return nil
        }
        self.textureCache = textureCache

        super.init()

        // Discover available cameras
        discoverCameras()

        log.video("CameraManager: Initialized with pro controls")
    }

    deinit {
        exposureObserver?.invalidate()
        focusObserver?.invalidate()
        whiteBalanceObserver?.invalidate()
        zoomObserver?.invalidate()
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

        log.video("CameraManager: Found \(availableCameras.count) cameras: \(availableCameras.map { $0.rawValue }.joined(separator: ", "))")
    }

    // MARK: - Start Capture

    func startCapture(camera: CameraPosition? = nil, resolution: Resolution? = nil, frameRate: Int? = nil) async throws {
        guard !isCapturing else { return }

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

        if let format = bestFormat, bestFrameRateRange != nil {
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
        }

        device.unlockForConfiguration()

        // Create input
        let input = try AVCaptureDeviceInput(device: device)

        // Remove old inputs/outputs
        if let oldInput = videoInput {
            captureSession.removeInput(oldInput)
        }
        if let oldOutput = videoOutput {
            captureSession.removeOutput(oldOutput)
        }
        if let oldPhoto = photoOutput {
            captureSession.removeOutput(oldPhoto)
        }
        if let oldMovie = movieOutput {
            captureSession.removeOutput(oldMovie)
        }
        if let oldDepth = depthOutput {
            captureSession.removeOutput(oldDepth)
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

        // Configure video data output (Metal texture pipeline)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        } else {
            captureSession.commitConfiguration()
            throw CameraError.outputConfigurationFailed
        }

        // Configure photo output
        let photo = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photo) {
            captureSession.addOutput(photo)
            photoOutput = photo
            photo.isHighResolutionCaptureEnabled = true
            if #available(iOS 16.0, *) {
                photo.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last
                    ?? CMVideoDimensions(width: 4032, height: 3024)
            }
            isRAWSupported = !photo.availableRawPhotoPixelFormatTypes.isEmpty
        }

        // Configure movie file output for recording
        let movie = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movie) {
            captureSession.addOutput(movie)
            movieOutput = movie
        }

        // Configure depth output if supported
        let depth = AVCaptureDepthDataOutput()
        if captureSession.canAddOutput(depth) {
            captureSession.addOutput(depth)
            depthOutput = depth
            depth.isFilteringEnabled = true
            isDepthSupported = true
        }

        // Set video orientation and stabilization
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported && currentCamera == .front {
                connection.isVideoMirrored = true
            }
            applyStabilization(to: connection)
        }

        captureSession.commitConfiguration()

        // Read device capabilities
        readDeviceCapabilities(device)

        // Start KVO observers
        setupDeviceObservers(device)

        // Start session
        captureSession.startRunning()

        isCapturing = true
        droppedFrames = 0
        frameCount = 0

        startFPSMonitoring()

        log.video("CameraManager: Started pro capture — \(currentCamera.rawValue) \(currentResolution.rawValue) @ \(currentFrameRate) FPS")
    }

    // MARK: - Stop Capture

    func stopCapture() {
        guard isCapturing else { return }

        if isRecording {
            stopRecording()
        }

        captureSession.stopRunning()
        isCapturing = false

        invalidateObservers()
        stopFPSMonitoring()

        log.video("CameraManager: Stopped capture")
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

    // =========================================================================
    // MARK: - Professional Exposure Control
    // =========================================================================

    /// Set exposure mode (auto, locked, full manual)
    func setExposureMode(_ mode: ExposureMode) {
        guard let device = videoDevice else { return }

        do {
            try device.lockForConfiguration()

            switch mode {
            case .auto:
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            case .locked:
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
            case .custom:
                if device.isExposureModeSupported(.custom) {
                    device.exposureMode = .custom
                }
            }

            device.unlockForConfiguration()
            exposureMode = mode
        } catch {
            log.video("CameraManager: Failed to set exposure mode: \(error)", level: .error)
        }
    }

    /// Set manual ISO (only in .custom exposure mode)
    func setISO(_ iso: Float) {
        guard let device = videoDevice else { return }

        let clampedISO = Swift.min(Swift.max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)

        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(
                duration: device.exposureDuration,
                iso: clampedISO,
                completionHandler: nil
            )
            device.unlockForConfiguration()
            currentISO = clampedISO
        } catch {
            log.video("CameraManager: Failed to set ISO: \(error)", level: .error)
        }
    }

    /// Set manual shutter speed (exposure duration) — e.g. CMTime(1, 120) = 1/120s
    func setShutterSpeed(_ duration: CMTime) {
        guard let device = videoDevice else { return }

        let format = device.activeFormat
        let minDuration = format.minExposureDuration
        let maxDuration = format.maxExposureDuration

        let clampedSeconds = Swift.min(Swift.max(duration.seconds, minDuration.seconds), maxDuration.seconds)
        let clamped = CMTime(seconds: clampedSeconds, preferredTimescale: 1_000_000)

        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(
                duration: clamped,
                iso: device.iso,
                completionHandler: nil
            )
            device.unlockForConfiguration()
            currentShutterSpeed = clamped
        } catch {
            log.video("CameraManager: Failed to set shutter speed: \(error)", level: .error)
        }
    }

    /// Set exposure compensation (EV bias, typically -8..+8)
    func setExposureCompensation(_ ev: Float) {
        guard let device = videoDevice else { return }

        let clamped = Swift.min(Swift.max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)

        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped, completionHandler: nil)
            device.unlockForConfiguration()
            exposureCompensation = clamped
        } catch {
            log.video("CameraManager: Failed to set EV: \(error)", level: .error)
        }
    }

    /// Set exposure point of interest (tap-to-meter, normalized 0..1 coordinates)
    func setExposurePointOfInterest(_ point: CGPoint) {
        guard let device = videoDevice, device.isExposurePointOfInterestSupported else { return }

        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            log.video("CameraManager: Failed to set exposure POI: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Professional Focus Control
    // =========================================================================

    /// Set focus mode
    func setFocusMode(_ mode: FocusMode) {
        guard let device = videoDevice else { return }

        do {
            try device.lockForConfiguration()

            switch mode {
            case .auto:
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            case .continuousAuto:
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            case .locked:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            case .manual:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            }

            device.unlockForConfiguration()
            focusMode = mode
            isFocusLocked = (mode == .locked || mode == .manual)
        } catch {
            log.video("CameraManager: Failed to set focus mode: \(error)", level: .error)
        }
    }

    /// Set manual lens focus position (0.0 = near, 1.0 = far)
    func setFocusPosition(_ position: Float) {
        guard let device = videoDevice else { return }

        let clamped = Swift.min(Swift.max(position, 0.0), 1.0)

        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
            device.unlockForConfiguration()
            focusPosition = clamped
        } catch {
            log.video("CameraManager: Failed to set focus position: \(error)", level: .error)
        }
    }

    /// Tap-to-focus at normalized point (0..1 coordinates)
    func tapToFocus(at point: CGPoint) {
        guard let device = videoDevice, device.isFocusPointOfInterestSupported else { return }

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
            device.unlockForConfiguration()
            focusPointOfInterest = point
        } catch {
            log.video("CameraManager: Failed to tap-to-focus: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Professional White Balance Control
    // =========================================================================

    /// Set white balance mode
    func setWhiteBalanceMode(_ mode: WhiteBalanceMode) {
        guard let device = videoDevice else { return }

        do {
            try device.lockForConfiguration()

            switch mode {
            case .auto:
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
            case .locked:
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
            case .custom:
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
            }

            device.unlockForConfiguration()
            whiteBalanceMode = mode
        } catch {
            log.video("CameraManager: Failed to set WB mode: \(error)", level: .error)
        }
    }

    /// Set custom white balance temperature (2000K..10000K) and tint (-150..+150)
    func setWhiteBalance(temperature: Float, tint: Float) {
        guard let device = videoDevice else { return }

        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature,
            tint: tint
        )
        var gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)

        // Clamp gains to valid range
        let maxGain = device.maxWhiteBalanceGain
        gains.redGain = Swift.min(Swift.max(gains.redGain, 1.0), maxGain)
        gains.greenGain = Swift.min(Swift.max(gains.greenGain, 1.0), maxGain)
        gains.blueGain = Swift.min(Swift.max(gains.blueGain, 1.0), maxGain)

        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            device.unlockForConfiguration()
            self.colorTemperature = temperature
            self.tint = tint
            self.whiteBalanceMode = .custom
        } catch {
            log.video("CameraManager: Failed to set WB: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Zoom Control
    // =========================================================================

    /// Set zoom factor with optional animation ramp
    func setZoom(_ factor: CGFloat, animated: Bool = false, rate: Float = 5.0) {
        guard let device = videoDevice else { return }

        let clamped = Swift.min(Swift.max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)

        do {
            try device.lockForConfiguration()
            if animated {
                device.ramp(toVideoZoomFactor: clamped, withRate: rate)
            } else {
                device.videoZoomFactor = clamped
            }
            device.unlockForConfiguration()
            zoomFactor = clamped
        } catch {
            log.video("CameraManager: Failed to set zoom: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Torch / Flash Control
    // =========================================================================

    /// Set torch mode (continuous light for video)
    func setTorchMode(_ mode: TorchMode, level: Float = 1.0) {
        guard let device = videoDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            switch mode {
            case .off:
                device.torchMode = .off
            case .on:
                try device.setTorchModeOn(level: Swift.min(Swift.max(level, 0.0), 1.0))
            case .auto:
                device.torchMode = .auto
            }

            device.unlockForConfiguration()
            torchMode = mode
            torchLevel = level
        } catch {
            log.video("CameraManager: Failed to set torch: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Video Stabilization
    // =========================================================================

    /// Set preferred stabilization mode
    func setStabilizationMode(_ mode: StabilizationMode) {
        stabilizationMode = mode

        // Apply to active connection
        if let connection = videoOutput?.connection(with: .video) {
            applyStabilization(to: connection)
        }
        if let connection = movieOutput?.connection(with: .video) {
            applyStabilization(to: connection)
        }
    }

    private func applyStabilization(to connection: AVCaptureConnection) {
        guard connection.isVideoStabilizationSupported else { return }

        let preferred: AVCaptureVideoStabilizationMode
        switch stabilizationMode {
        case .off:
            preferred = .off
        case .standard:
            preferred = .standard
        case .cinematic:
            preferred = .cinematic
        case .cinematicExtended:
            if #available(iOS 13.0, *) {
                preferred = .cinematicExtended
            } else {
                preferred = .cinematic
            }
        case .auto:
            preferred = .auto
        }

        connection.preferredVideoStabilizationMode = preferred

        let active = connection.activeVideoStabilizationMode
        switch active {
        case .off: activeStabilizationMode = "Off"
        case .standard: activeStabilizationMode = "Standard"
        case .cinematic: activeStabilizationMode = "Cinematic"
        case .cinematicExtended: activeStabilizationMode = "Cinematic Extended"
        case .auto: activeStabilizationMode = "Auto"
        @unknown default: activeStabilizationMode = "Unknown"
        }
    }

    // =========================================================================
    // MARK: - HDR Control
    // =========================================================================

    /// Enable or disable HDR video
    func setHDR(enabled: Bool) {
        guard let device = videoDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = false
                device.isVideoHDREnabled = enabled
                isHDREnabled = enabled
            }

            device.unlockForConfiguration()
        } catch {
            log.video("CameraManager: Failed to set HDR: \(error)", level: .error)
        }
    }

    // =========================================================================
    // MARK: - Depth Data
    // =========================================================================

    /// Enable or disable depth data capture (LiDAR / TrueDepth)
    func setDepthEnabled(_ enabled: Bool) {
        guard isDepthSupported else { return }

        if enabled {
            if let depth = depthOutput {
                depth.isFilteringEnabled = true
                depth.setDelegate(self, callbackQueue: captureQueue)
            }
        } else {
            depthOutput?.setDelegate(nil, callbackQueue: nil)
        }

        isDepthEnabled = enabled
    }

    // =========================================================================
    // MARK: - Photo Capture
    // =========================================================================

    /// Capture a still photo with the specified format
    func capturePhoto(format: PhotoFormat = .heif, flashMode: AVCaptureDevice.FlashMode = .off) async throws -> Data {
        guard let photoOutput = photoOutput else {
            throw CameraError.outputConfigurationFailed
        }

        isCapturingPhoto = true
        defer { isCapturingPhoto = false }

        let settings: AVCapturePhotoSettings

        switch format {
        case .heif:
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
        case .jpeg:
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        case .raw:
            guard let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first else {
                throw CameraError.rawNotSupported
            }
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawType)
        }

        settings.flashMode = flashMode
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // =========================================================================
    // MARK: - Video Recording (ProRes / HDR / Standard)
    // =========================================================================

    /// Start recording video to file
    func startRecording(proRes: Bool = false) throws -> URL {
        guard let movieOutput = movieOutput else {
            throw CameraError.outputConfigurationFailed
        }
        guard !isRecording else {
            throw CameraError.alreadyRecording
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "echoelvideo_\(Int(Date().timeIntervalSince1970)).mov"
        let url = documentsPath.appendingPathComponent(fileName)

        // Configure ProRes if supported and requested
        if proRes, let connection = movieOutput.connection(with: .video) {
            if #available(iOS 15.4, *) {
                let proResCodecs: [AVVideoCodecType] = [.proRes422HQ, .proRes422, .proRes422LT, .proRes422Proxy]
                for codec in proResCodecs {
                    if movieOutput.availableVideoCodecTypes.contains(codec) {
                        movieOutput.setOutputSettings(
                            [AVVideoCodecKey: codec],
                            for: connection
                        )
                        break
                    }
                }
            }
        }

        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration += 0.1
            }
        }

        log.video("CameraManager: Started recording to \(url.lastPathComponent)")
        return url
    }

    /// Stop recording
    func stopRecording() {
        guard isRecording else { return }

        movieOutput?.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        log.video("CameraManager: Stopped recording (\(String(format: "%.1f", recordingDuration))s)")
    }

    // =========================================================================
    // MARK: - Device Capabilities Reader
    // =========================================================================

    private func readDeviceCapabilities(_ device: AVCaptureDevice) {
        let format = device.activeFormat

        // ISO range
        isoRange = format.minISO...format.maxISO
        currentISO = device.iso

        // Shutter speed range
        let minSeconds = format.minExposureDuration.seconds
        let maxSeconds = format.maxExposureDuration.seconds
        if minSeconds < maxSeconds {
            shutterSpeedRange = minSeconds...maxSeconds
        }

        // Zoom
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = device.maxAvailableVideoZoomFactor
        zoomFactor = device.videoZoomFactor

        // HDR
        isHDRSupported = format.isVideoHDRSupported
        isHDREnabled = device.isVideoHDREnabled

        // Depth
        isDepthSupported = depthOutput != nil

        // ProRes
        if let movie = movieOutput {
            if #available(iOS 15.4, *) {
                isProResSupported = movie.availableVideoCodecTypes.contains(.proRes422)
                    || movie.availableVideoCodecTypes.contains(.proRes422HQ)
            }
        }

        // RAW
        if let photo = photoOutput {
            isRAWSupported = !photo.availableRawPhotoPixelFormatTypes.isEmpty
        }

        log.video("CameraManager: ISO \(format.minISO)-\(format.maxISO), Zoom \(String(format: "%.1f", minZoomFactor))x-\(String(format: "%.1f", maxZoomFactor))x, HDR=\(isHDRSupported), Depth=\(isDepthSupported), ProRes=\(isProResSupported), RAW=\(isRAWSupported)")
    }

    // MARK: - KVO Device Observers

    private func setupDeviceObservers(_ device: AVCaptureDevice) {
        invalidateObservers()

        exposureObserver = device.observe(\.iso, options: .new) { [weak self] dev, _ in
            Task { @MainActor in
                self?.currentISO = dev.iso
            }
        }

        focusObserver = device.observe(\.lensPosition, options: .new) { [weak self] dev, _ in
            Task { @MainActor in
                self?.focusPosition = dev.lensPosition
            }
        }

        whiteBalanceObserver = device.observe(\.deviceWhiteBalanceGains, options: .new) { [weak self] dev, _ in
            let tempTint = dev.temperatureAndTintValues(for: dev.deviceWhiteBalanceGains)
            Task { @MainActor in
                self?.colorTemperature = tempTint.temperature
                self?.tint = tempTint.tint
            }
        }

        zoomObserver = device.observe(\.videoZoomFactor, options: .new) { [weak self] dev, _ in
            Task { @MainActor in
                self?.zoomFactor = dev.videoZoomFactor
            }
        }
    }

    private func invalidateObservers() {
        exposureObserver?.invalidate()
        exposureObserver = nil
        focusObserver?.invalidate()
        focusObserver = nil
        whiteBalanceObserver?.invalidate()
        whiteBalanceObserver = nil
        zoomObserver?.invalidate()
        zoomObserver = nil
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

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        Task { @MainActor in
            guard let texture = self.createTexture(from: pixelBuffer) else {
                self.droppedFrames += 1
                return
            }
            self.frameCount += 1
            self.lastFrameTime = presentationTime
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

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

    public nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.photoContinuation?.resume(throwing: error)
                self.photoContinuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation() else {
                self.photoContinuation?.resume(throwing: CameraError.photoCaptureFailed)
                self.photoContinuation = nil
                return
            }

            self.lastCapturedPhotoData = data
            self.photoContinuation?.resume(returning: data)
            self.photoContinuation = nil
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {

    public nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                log.video("CameraManager: Recording error: \(error.localizedDescription)", level: .error)
            } else {
                log.video("CameraManager: Recording saved to \(outputFileURL.lastPathComponent)")
            }
            self.isRecording = false
        }
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

extension CameraManager: AVCaptureDepthDataOutputDelegate {

    public nonisolated func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        Task { @MainActor in
            self.onDepthDataCaptured?(depthData)
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
    case rawNotSupported
    case photoCaptureFailed
    case alreadyRecording

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
        case .rawNotSupported:
            return "RAW photo capture not supported on this device"
        case .photoCaptureFailed:
            return "Failed to capture photo"
        case .alreadyRecording:
            return "Already recording"
        }
    }
}

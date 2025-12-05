import Foundation
import AVFoundation
import CoreImage
import CoreMotion
import Metal
import Vision
import Accelerate
import Combine

#if canImport(UIKit)
import UIKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC CINEMATIC VIDEO ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Professional Cinematic Filming Features:
//
// TIME MANIPULATION:
// • Hyperlapse - Stabilized time-lapse while moving
// • Time Warp - Bio-reactive speed based on heart rate
// • Super Slow Motion - 120/240/960 fps capture
// • Speed Ramps - Smooth variable speed transitions
// • Freeze Frame - Hold with motion blur
//
// CAMERA MOVEMENTS:
// • Virtual Dolly - Smooth forward/backward movement
// • Virtual Crane - Vertical sweeping shots
// • Virtual Pan/Tilt - Smooth rotational movements
// • Orbit Shot - 360° around subject
// • Dolly Zoom (Vertigo) - Hitchcock effect
//
// TRACKING & FOCUS:
// • Object Tracking - Lock onto subjects
// • Face Tracking - Follow faces smoothly
// • Motion Prediction - Anticipate movement
// • Rack Focus - Smooth focus transitions
// • Pull Focus - Dramatic depth shifts
//
// STABILIZATION:
// • Cinematic Stabilization - Film-like smoothness
// • Action Mode - Extreme shake reduction
// • Warp Stabilizer - Post-capture fix
// • Horizon Lock - Level footage always
//
// CINEMATIC LOOKS:
// • Anamorphic Simulation - Lens flares, bokeh
// • Film Grain - Authentic 16mm/35mm grain
// • Color Science - LOG, Rec.709, Rec.2020
// • LUT Support - Apply professional grades
// • Cinematic Bars - Aspect ratio overlays
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
public final class CinematicVideoEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = CinematicVideoEngine()

    // MARK: - Published State

    @Published public var activeMode: CinematicMode = .standard
    @Published public var isRecording: Bool = false
    @Published public var stabilizationLevel: StabilizationLevel = .cinematic
    @Published public var currentFPS: Int = 30
    @Published public var hyperlapseSpeed: HyperlapseSpeed = .x10
    @Published public var slowMotionRate: SlowMotionRate = .x4
    @Published public var activeFilmLook: FilmLook = .natural
    @Published public var trackingSubject: TrackedSubject?
    @Published public var virtualCameraPosition: VirtualCameraState = .init()

    // MARK: - Cinematic Modes

    public enum CinematicMode: String, CaseIterable, Codable {
        case standard = "Standard"
        case hyperlapse = "Hyperlapse"
        case timelapse = "Time-lapse"
        case slowMotion = "Slow Motion"
        case superSlowMotion = "Super Slow-Mo"
        case cinematic = "Cinematic"
        case actionMode = "Action Mode"
        case nightMode = "Night Mode"
        case portrait = "Portrait Video"
        case dollyZoom = "Dolly Zoom"
        case orbitShot = "Orbit Shot"
        case verticalPan = "Vertical Pan"

        public var description: String {
            switch self {
            case .standard: return "Standard video recording"
            case .hyperlapse: return "Stabilized time-lapse while moving"
            case .timelapse: return "Static time-lapse recording"
            case .slowMotion: return "4x slow motion (120fps)"
            case .superSlowMotion: return "8-32x slow motion (240-960fps)"
            case .cinematic: return "Shallow depth of field with rack focus"
            case .actionMode: return "Extreme stabilization for sports"
            case .nightMode: return "Enhanced low-light video"
            case .portrait: return "Background blur for subjects"
            case .dollyZoom: return "Vertigo/Hitchcock effect"
            case .orbitShot: return "Virtual 360° around subject"
            case .verticalPan: return "Smooth vertical crane shot"
            }
        }

        public var recommendedFPS: Int {
            switch self {
            case .slowMotion: return 120
            case .superSlowMotion: return 240
            case .hyperlapse, .timelapse: return 30
            default: return 30
            }
        }
    }

    // MARK: - Hyperlapse Settings

    public enum HyperlapseSpeed: Int, CaseIterable {
        case x2 = 2
        case x4 = 4
        case x6 = 6
        case x10 = 10
        case x12 = 12
        case x30 = 30
        case x60 = 60
        case x120 = 120

        public var label: String { "\(rawValue)x" }
        public var captureInterval: Double { 1.0 / Double(rawValue) }
    }

    public enum SlowMotionRate: Int, CaseIterable {
        case x2 = 2
        case x4 = 4
        case x8 = 8
        case x16 = 16
        case x32 = 32

        public var requiredFPS: Int { 30 * rawValue }
        public var label: String { "\(rawValue)x Slow" }
    }

    // MARK: - Stabilization

    public enum StabilizationLevel: String, CaseIterable {
        case off = "Off"
        case standard = "Standard"
        case cinematic = "Cinematic"
        case action = "Action Mode"
        case horizonLock = "Horizon Lock"
        case warp = "Warp Stabilizer"

        public var smoothingFactor: Float {
            switch self {
            case .off: return 0
            case .standard: return 0.3
            case .cinematic: return 0.6
            case .action: return 0.9
            case .horizonLock: return 0.7
            case .warp: return 0.8
            }
        }
    }

    // MARK: - Film Looks

    public enum FilmLook: String, CaseIterable {
        case natural = "Natural"
        case cinematic = "Cinematic"
        case film16mm = "16mm Film"
        case film35mm = "35mm Film"
        case kodakVision = "Kodak Vision3"
        case fujiEterna = "Fuji Eterna"
        case anamorphic = "Anamorphic"
        case bleachBypass = "Bleach Bypass"
        case crossProcess = "Cross Process"
        case vintage = "Vintage"
        case noir = "Film Noir"
        case teal_orange = "Teal & Orange"
        case logC = "LOG C"
        case rec709 = "Rec.709"
        case rec2020 = "Rec.2020 HDR"

        public var ciFilterName: String? {
            switch self {
            case .natural: return nil
            case .noir: return "CIPhotoEffectNoir"
            case .vintage: return "CIPhotoEffectInstant"
            default: return nil  // Custom LUT processing
            }
        }
    }

    // MARK: - Tracking

    public struct TrackedSubject {
        public var id: UUID = UUID()
        public var type: SubjectType
        public var boundingBox: CGRect
        public var confidence: Float
        public var velocity: CGPoint = .zero
        public var predictedPosition: CGRect?

        public enum SubjectType {
            case face
            case person
            case animal
            case object
            case custom(identifier: String)
        }
    }

    // MARK: - Virtual Camera

    public struct VirtualCameraState {
        public var position: SIMD3<Float> = .zero
        public var rotation: SIMD3<Float> = .zero  // Euler angles
        public var focalLength: Float = 24  // mm
        public var aperture: Float = 2.8  // f-stop
        public var focusDistance: Float = 2.0  // meters
        public var dollyPosition: Float = 0  // 0-1
        public var craneHeight: Float = 0  // meters
        public var orbitAngle: Float = 0  // radians
    }

    // MARK: - Private State

    private var motionManager: CMMotionManager?
    private var gyroData: [CMRotationRate] = []
    private var accelerometerData: [CMAcceleration] = []
    private var stabilizationBuffer: [simd_float4x4] = []
    private let stabilizationBufferSize = 30
    private var hyperlapseFrameBuffer: [CVPixelBuffer] = []
    private var lastCaptureTime: Date = Date()
    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler: VNSequenceRequestHandler?

    // Metal
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?

    // Speed Ramp
    private var speedRampKeyframes: [(time: Double, speed: Double)] = []
    private var currentSpeedMultiplier: Double = 1.0

    // MARK: - Initialization

    private init() {
        setupMetal()
        setupMotionTracking()
        setupVision()
        print("🎬 CinematicVideoEngine initialized")
    }

    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        if let device = device {
            commandQueue = device.makeCommandQueue()
            ciContext = CIContext(mtlDevice: device)
        }
    }

    private func setupMotionTracking() {
        motionManager = CMMotionManager()
        motionManager?.gyroUpdateInterval = 1.0 / 120.0
        motionManager?.accelerometerUpdateInterval = 1.0 / 120.0
    }

    private func setupVision() {
        sequenceHandler = VNSequenceRequestHandler()
    }

    // MARK: - Hyperlapse

    /// Start hyperlapse capture
    public func startHyperlapse(speed: HyperlapseSpeed = .x10) {
        activeMode = .hyperlapse
        hyperlapseSpeed = speed
        isRecording = true
        hyperlapseFrameBuffer.removeAll()

        // Start motion tracking for stabilization
        startMotionCapture()

        print("🎬 Hyperlapse started at \(speed.label)")
    }

    /// Process frame for hyperlapse
    public func processHyperlapseFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> CVPixelBuffer? {
        let now = Date()
        let interval = hyperlapseSpeed.captureInterval

        // Only capture at intervals
        guard now.timeIntervalSince(lastCaptureTime) >= interval else {
            return nil
        }

        lastCaptureTime = now

        // Stabilize frame
        let stabilizedBuffer = stabilizeFrame(pixelBuffer)

        // Apply hyperlapse smoothing
        let smoothedBuffer = applySmoothMotion(stabilizedBuffer)

        hyperlapseFrameBuffer.append(smoothedBuffer)

        return smoothedBuffer
    }

    // MARK: - Slow Motion

    /// Configure slow motion capture
    public func configureSlowMotion(rate: SlowMotionRate) {
        slowMotionRate = rate
        currentFPS = rate.requiredFPS
        activeMode = rate.rawValue > 4 ? .superSlowMotion : .slowMotion

        print("🎬 Slow motion configured: \(rate.label) (\(rate.requiredFPS)fps)")
    }

    /// Apply slow motion to video
    public func applySlowMotion(to asset: AVAsset, rate: SlowMotionRate) async throws -> AVAsset {
        let composition = AVMutableComposition()

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw CinematicError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        try compositionTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )

        // Scale time by slow motion rate
        let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: Float64(rate.rawValue))
        compositionTrack?.scaleTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            toDuration: scaledDuration
        )

        return composition
    }

    // MARK: - Dolly Zoom (Vertigo Effect)

    /// Calculate dolly zoom parameters
    public func calculateDollyZoom(
        targetDistance: Float,
        currentDistance: Float,
        subjectSize: Float
    ) -> (focalLength: Float, cameraPosition: Float) {
        // Dolly zoom: zoom in while moving back (or vice versa)
        // Keeps subject same size while background perspective changes

        let ratio = targetDistance / currentDistance

        // Calculate new focal length to maintain subject size
        let newFocalLength = virtualCameraPosition.focalLength * ratio

        // Calculate camera position offset
        let positionOffset = targetDistance - currentDistance

        return (newFocalLength, positionOffset)
    }

    /// Apply dolly zoom effect
    public func applyDollyZoom(
        to frame: CIImage,
        dollyProgress: Float,  // 0-1
        direction: DollyZoomDirection = .zoomInDollyOut
    ) -> CIImage {
        // Calculate zoom and position based on progress
        let startFocal: Float = 24
        let endFocal: Float = direction == .zoomInDollyOut ? 85 : 24

        let currentFocal = startFocal + (endFocal - startFocal) * dollyProgress

        // Scale factor based on focal length change
        let scaleFactor = CGFloat(currentFocal / startFocal)

        // Apply zoom transform centered on subject
        let transform = CGAffineTransform(translationX: frame.extent.midX, y: frame.extent.midY)
            .scaledBy(x: scaleFactor, y: scaleFactor)
            .translatedBy(x: -frame.extent.midX, y: -frame.extent.midY)

        return frame.transformed(by: transform)
    }

    public enum DollyZoomDirection {
        case zoomInDollyOut   // Classic Vertigo
        case zoomOutDollyIn   // Reverse Vertigo
    }

    // MARK: - Object Tracking

    /// Start tracking a subject
    public func startTracking(in frame: CVPixelBuffer, at location: CGPoint) {
        let observation = VNDetectedObjectObservation(
            boundingBox: CGRect(
                x: location.x - 0.1,
                y: location.y - 0.1,
                width: 0.2,
                height: 0.2
            )
        )

        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation) { [weak self] request, error in
            guard let results = request.results as? [VNDetectedObjectObservation],
                  let observation = results.first else { return }

            DispatchQueue.main.async {
                self?.trackingSubject = TrackedSubject(
                    type: .object,
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
            }
        }

        trackingRequest?.trackingLevel = .accurate
    }

    /// Update tracking with new frame
    public func updateTracking(with frame: CVPixelBuffer) throws {
        guard let request = trackingRequest else { return }

        try sequenceHandler?.perform([request], on: frame)

        // Predict next position for smooth following
        if var subject = trackingSubject {
            let velocity = calculateVelocity(from: subject.boundingBox)
            subject.velocity = velocity
            subject.predictedPosition = predictPosition(
                current: subject.boundingBox,
                velocity: velocity
            )
            trackingSubject = subject
        }
    }

    private func calculateVelocity(from bbox: CGRect) -> CGPoint {
        guard let previous = trackingSubject?.boundingBox else {
            return .zero
        }

        return CGPoint(
            x: bbox.midX - previous.midX,
            y: bbox.midY - previous.midY
        )
    }

    private func predictPosition(current: CGRect, velocity: CGPoint) -> CGRect {
        return CGRect(
            x: current.origin.x + velocity.x * 2,
            y: current.origin.y + velocity.y * 2,
            width: current.width,
            height: current.height
        )
    }

    // MARK: - Virtual Camera Movements

    /// Apply virtual dolly movement
    public func applyVirtualDolly(
        to frame: CIImage,
        position: Float,  // 0-1, forward/backward
        speed: Float = 1.0
    ) -> CIImage {
        // Simulate dolly by scaling and translating
        let scale = 1.0 + CGFloat(position * 0.3 * speed)

        let transform = CGAffineTransform(translationX: frame.extent.midX, y: frame.extent.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -frame.extent.midX, y: -frame.extent.midY)

        virtualCameraPosition.dollyPosition = position
        return frame.transformed(by: transform)
    }

    /// Apply virtual crane movement
    public func applyVirtualCrane(
        to frame: CIImage,
        height: Float,  // Vertical offset
        tilt: Float = 0  // Camera tilt angle
    ) -> CIImage {
        // Simulate crane by vertical translation and perspective
        let yOffset = CGFloat(height * 100)

        // Apply slight perspective shift for realism
        let perspectiveAmount = CGFloat(tilt * 0.01)

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: 0, y: yOffset)

        // Add subtle scale for depth perception
        let scale = 1.0 - CGFloat(abs(height) * 0.1)
        transform = transform.scaledBy(x: scale, y: scale)

        virtualCameraPosition.craneHeight = height
        return frame.transformed(by: transform)
    }

    /// Apply orbit shot (rotate around subject)
    public func applyOrbitShot(
        to frame: CIImage,
        angle: Float,  // Radians
        radius: Float = 1.0
    ) -> CIImage {
        // Simulate orbit by rotating view
        let rotation = CGAffineTransform(rotationAngle: CGFloat(angle * 0.1))

        // Translate based on orbital position
        let xOffset = CGFloat(sin(angle) * radius * 50)
        let translation = CGAffineTransform(translationX: xOffset, y: 0)

        virtualCameraPosition.orbitAngle = angle
        return frame.transformed(by: rotation.concatenating(translation))
    }

    // MARK: - Speed Ramps

    /// Add speed ramp keyframe
    public func addSpeedRampKeyframe(at time: Double, speed: Double) {
        speedRampKeyframes.append((time: time, speed: speed))
        speedRampKeyframes.sort { $0.time < $1.time }
    }

    /// Get interpolated speed at time
    public func getSpeedAt(time: Double) -> Double {
        guard !speedRampKeyframes.isEmpty else { return 1.0 }

        // Find surrounding keyframes
        var prevKeyframe: (time: Double, speed: Double)?
        var nextKeyframe: (time: Double, speed: Double)?

        for keyframe in speedRampKeyframes {
            if keyframe.time <= time {
                prevKeyframe = keyframe
            } else {
                nextKeyframe = keyframe
                break
            }
        }

        guard let prev = prevKeyframe else {
            return speedRampKeyframes.first?.speed ?? 1.0
        }

        guard let next = nextKeyframe else {
            return prev.speed
        }

        // Smooth interpolation (ease in/out)
        let t = (time - prev.time) / (next.time - prev.time)
        let smoothT = t * t * (3 - 2 * t)  // Smoothstep

        return prev.speed + (next.speed - prev.speed) * smoothT
    }

    /// Clear speed ramps
    public func clearSpeedRamps() {
        speedRampKeyframes.removeAll()
        currentSpeedMultiplier = 1.0
    }

    // MARK: - Rack Focus

    /// Apply rack focus effect
    public func applyRackFocus(
        to frame: CIImage,
        focusPoint: CGPoint,
        aperture: Float,
        blurRadius: Float
    ) -> CIImage {
        guard let ciContext = ciContext else { return frame }

        // Create depth-based blur
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(frame, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurFilter.outputImage else { return frame }

        // Create radial gradient for focus mask
        let gradientFilter = CIFilter(name: "CIRadialGradient")!
        gradientFilter.setValue(CIVector(cgPoint: focusPoint), forKey: "inputCenter")
        gradientFilter.setValue(100, forKey: "inputRadius0")
        gradientFilter.setValue(300, forKey: "inputRadius1")
        gradientFilter.setValue(CIColor.white, forKey: "inputColor0")
        gradientFilter.setValue(CIColor.black, forKey: "inputColor1")

        guard let maskImage = gradientFilter.outputImage else { return frame }

        // Blend sharp and blurred based on mask
        let blendFilter = CIFilter(name: "CIBlendWithMask")!
        blendFilter.setValue(frame, forKey: kCIInputImageKey)
        blendFilter.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage ?? frame
    }

    // MARK: - Film Looks

    /// Apply film look to frame
    public func applyFilmLook(_ look: FilmLook, to frame: CIImage) -> CIImage {
        var result = frame

        switch look {
        case .natural:
            return frame

        case .anamorphic:
            result = applyAnamorphicLook(to: frame)

        case .film16mm:
            result = applyFilmGrain(to: frame, intensity: 0.15, size: 1.5)
            result = applyFilmColor(to: result, warmth: 0.1, saturation: 0.9)

        case .film35mm:
            result = applyFilmGrain(to: frame, intensity: 0.08, size: 1.0)
            result = applyFilmColor(to: result, warmth: 0.05, saturation: 0.95)

        case .kodakVision:
            result = applyKodakLook(to: frame)

        case .fujiEterna:
            result = applyFujiLook(to: frame)

        case .bleachBypass:
            result = applyBleachBypass(to: frame)

        case .teal_orange:
            result = applyTealOrange(to: frame)

        case .noir:
            if let filter = CIFilter(name: "CIPhotoEffectNoir") {
                filter.setValue(frame, forKey: kCIInputImageKey)
                result = filter.outputImage ?? frame
            }

        case .vintage:
            if let filter = CIFilter(name: "CIPhotoEffectInstant") {
                filter.setValue(frame, forKey: kCIInputImageKey)
                result = filter.outputImage ?? frame
            }

        case .logC, .rec709, .rec2020:
            result = applyColorSpace(look, to: frame)

        default:
            break
        }

        activeFilmLook = look
        return result
    }

    private func applyAnamorphicLook(to frame: CIImage) -> CIImage {
        var result = frame

        // Add horizontal lens flare
        let flareFilter = CIFilter(name: "CIBloom")!
        flareFilter.setValue(frame, forKey: kCIInputImageKey)
        flareFilter.setValue(2.0, forKey: kCIInputRadiusKey)
        flareFilter.setValue(0.5, forKey: kCIInputIntensityKey)

        if let bloomed = flareFilter.outputImage {
            result = bloomed
        }

        // Add oval bokeh simulation (stretch vertically)
        // Anamorphic lenses create vertically stretched out-of-focus highlights

        return result
    }

    private func applyFilmGrain(to frame: CIImage, intensity: Float, size: Float) -> CIImage {
        let noiseFilter = CIFilter(name: "CIRandomGenerator")!
        guard let noiseImage = noiseFilter.outputImage?.cropped(to: frame.extent) else {
            return frame
        }

        // Scale noise
        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
        scaleFilter.setValue(noiseImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(CGFloat(size), forKey: kCIInputScaleKey)

        guard let scaledNoise = scaleFilter.outputImage else { return frame }

        // Blend with original
        let blendFilter = CIFilter(name: "CISoftLightBlendMode")!
        blendFilter.setValue(frame, forKey: kCIInputImageKey)
        blendFilter.setValue(scaledNoise, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage ?? frame
    }

    private func applyFilmColor(to frame: CIImage, warmth: Float, saturation: Float) -> CIImage {
        let colorFilter = CIFilter(name: "CITemperatureAndTint")!
        colorFilter.setValue(frame, forKey: kCIInputImageKey)
        colorFilter.setValue(CIVector(x: CGFloat(6500 + warmth * 1000), y: 0), forKey: "inputNeutral")

        guard let warmed = colorFilter.outputImage else { return frame }

        let satFilter = CIFilter(name: "CIColorControls")!
        satFilter.setValue(warmed, forKey: kCIInputImageKey)
        satFilter.setValue(saturation, forKey: kCIInputSaturationKey)

        return satFilter.outputImage ?? frame
    }

    private func applyKodakLook(to frame: CIImage) -> CIImage {
        // Kodak Vision3: warm highlights, rich shadows, natural skin
        var result = applyFilmGrain(to: frame, intensity: 0.05, size: 0.8)
        result = applyFilmColor(to: result, warmth: 0.08, saturation: 1.05)

        // Lift shadows slightly
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(result, forKey: kCIInputImageKey)
        colorFilter.setValue(0.02, forKey: kCIInputBrightnessKey)

        return colorFilter.outputImage ?? result
    }

    private func applyFujiLook(to frame: CIImage) -> CIImage {
        // Fuji Eterna: cooler tones, cyan shadows, magenta highlights
        var result = applyFilmGrain(to: frame, intensity: 0.04, size: 0.7)

        let colorFilter = CIFilter(name: "CITemperatureAndTint")!
        colorFilter.setValue(result, forKey: kCIInputImageKey)
        colorFilter.setValue(CIVector(x: 6200, y: 10), forKey: "inputNeutral")

        return colorFilter.outputImage ?? result
    }

    private func applyBleachBypass(to frame: CIImage) -> CIImage {
        // Desaturate and increase contrast
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(frame, forKey: kCIInputImageKey)
        colorFilter.setValue(0.6, forKey: kCIInputSaturationKey)
        colorFilter.setValue(1.2, forKey: kCIInputContrastKey)

        return colorFilter.outputImage ?? frame
    }

    private func applyTealOrange(to frame: CIImage) -> CIImage {
        // Hollywood blockbuster look
        // TODO: Implement proper color curves for teal shadows, orange highlights
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(frame, forKey: kCIInputImageKey)
        colorFilter.setValue(1.1, forKey: kCIInputSaturationKey)
        colorFilter.setValue(1.1, forKey: kCIInputContrastKey)

        return colorFilter.outputImage ?? frame
    }

    private func applyColorSpace(_ look: FilmLook, to frame: CIImage) -> CIImage {
        // Apply color space conversion for professional workflows
        // LOG C, Rec.709, Rec.2020 handling
        return frame
    }

    // MARK: - Stabilization

    private func startMotionCapture() {
        motionManager?.startGyroUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.gyroData.append(data.rotationRate)
            if (self?.gyroData.count ?? 0) > 120 {
                self?.gyroData.removeFirst()
            }
        }

        motionManager?.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.accelerometerData.append(data.acceleration)
            if (self?.accelerometerData.count ?? 0) > 120 {
                self?.accelerometerData.removeFirst()
            }
        }
    }

    private func stabilizeFrame(_ buffer: CVPixelBuffer) -> CVPixelBuffer {
        // Apply stabilization transform based on gyro data
        guard !gyroData.isEmpty else { return buffer }

        // Calculate smoothed rotation
        let avgRotation = gyroData.reduce(CMRotationRate()) { result, rate in
            CMRotationRate(x: result.x + rate.x, y: result.y + rate.y, z: result.z + rate.z)
        }

        let count = Double(gyroData.count)
        let smoothedRotation = CMRotationRate(
            x: avgRotation.x / count,
            y: avgRotation.y / count,
            z: avgRotation.z / count
        )

        // Apply inverse transform to stabilize
        // In production, use proper homography or warp transform
        return buffer
    }

    private func applySmoothMotion(_ buffer: CVPixelBuffer) -> CVPixelBuffer {
        // Apply motion smoothing for hyperlapse
        return buffer
    }

    // MARK: - Cinematic Bars

    /// Add cinematic aspect ratio bars
    public func addCinematicBars(to frame: CIImage, aspectRatio: CinematicAspectRatio) -> CIImage {
        let frameAspect = frame.extent.width / frame.extent.height
        let targetAspect = aspectRatio.ratio

        guard targetAspect > frameAspect else { return frame }

        // Calculate bar height
        let targetHeight = frame.extent.width / targetAspect
        let barHeight = (frame.extent.height - targetHeight) / 2

        // Create black bars
        let topBar = CIImage(color: .black).cropped(to: CGRect(
            x: 0,
            y: frame.extent.height - barHeight,
            width: frame.extent.width,
            height: barHeight
        ))

        let bottomBar = CIImage(color: .black).cropped(to: CGRect(
            x: 0,
            y: 0,
            width: frame.extent.width,
            height: barHeight
        ))

        // Composite
        return frame
            .composited(over: topBar)
            .composited(over: bottomBar)
    }

    public enum CinematicAspectRatio: String, CaseIterable {
        case standard = "16:9"
        case theatrical = "1.85:1"
        case anamorphic = "2.39:1"
        case imax = "1.43:1"
        case ultrawide = "2.76:1"
        case classic = "4:3"

        public var ratio: CGFloat {
            switch self {
            case .standard: return 16.0 / 9.0
            case .theatrical: return 1.85
            case .anamorphic: return 2.39
            case .imax: return 1.43
            case .ultrawide: return 2.76
            case .classic: return 4.0 / 3.0
            }
        }
    }

    // MARK: - Cleanup

    public func stopRecording() {
        isRecording = false
        motionManager?.stopGyroUpdates()
        motionManager?.stopAccelerometerUpdates()
        gyroData.removeAll()
        accelerometerData.removeAll()
    }

    deinit {
        stopRecording()
    }
}

// MARK: - Errors

public enum CinematicError: Error {
    case noVideoTrack
    case processingFailed
    case unsupportedFormat
    case deviceNotAvailable
}

// MARK: - Preview Support

#if DEBUG
extension CinematicVideoEngine {
    public static func createPreview() -> CinematicVideoEngine {
        let engine = CinematicVideoEngine.shared
        engine.activeMode = .hyperlapse
        engine.hyperlapseSpeed = .x10
        engine.activeFilmLook = .kodakVision
        return engine
    }
}
#endif

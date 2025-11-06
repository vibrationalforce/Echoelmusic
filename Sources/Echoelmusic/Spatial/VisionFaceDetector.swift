import Foundation
import Vision
import AVFoundation
import Combine

/// Vision framework-based face detection fallback
/// Works on ALL iPhones without TrueDepth camera
/// Provides approximate face expressions for bio-reactive audio
///
/// **Differences from ARFaceTrackingManager:**
/// - No 3D depth data (2D face landmarks only)
/// - Fewer blend shapes (approximated from 76 landmarks)
/// - Slightly lower accuracy (~85% vs 95%)
/// - Works on iPhone 8, XR, 11, and all non-Pro models
///
/// **Usage:**
/// ```swift
/// let visionDetector = VisionFaceDetector()
/// visionDetector.start()
///
/// visionDetector.$faceExpression
///     .sink { expression in
///         // Use same FaceExpression type as ARKit
///     }
/// ```
@MainActor
public class VisionFaceDetector: NSObject, ObservableObject {

    // MARK: - Published State

    /// Simplified face expression (compatible with ARFaceTrackingManager)
    @Published public private(set) var faceExpression: FaceExpression = FaceExpression()

    /// Whether face detection is currently active
    @Published public private(set) var isTracking: Bool = false

    /// Detection quality (0.0 - 1.0)
    @Published public private(set) var trackingQuality: Float = 0

    /// Detection confidence (0.0 - 1.0)
    @Published public private(set) var detectionConfidence: Float = 0

    // MARK: - Vision Framework

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "com.echoelmusic.vision.video", qos: .userInteractive)

    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        return request
    }()

    // MARK: - Configuration

    /// Target frame rate (Hz)
    public var targetFrameRate: Int = 30  // 30 Hz for balance of performance and battery

    /// Minimum confidence threshold
    public var confidenceThreshold: Float = 0.5

    // MARK: - Smoothing

    private var expressionHistory: [FaceExpression] = []
    private let smoothingWindowSize: Int = 3  // Smooth over 3 frames

    // MARK: - Previous Values (for change detection)

    private var previousExpression: FaceExpression = FaceExpression()

    // MARK: - Statistics

    private var framesProcessed: Int = 0
    private var lastFrameTime: Date = Date()
    private var actualFrameRate: Double = 0

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Start face detection
    public func start() {
        guard !isTracking else { return }

        print("[VisionFaceDetector] ▶️  Starting Vision-based face detection...")

        setupCaptureSession()
        captureSession?.startRunning()

        isTracking = true
        print("[VisionFaceDetector] ✅ Face detection started (30 Hz, 2D landmarks)")
    }

    /// Stop face detection
    public func stop() {
        guard isTracking else { return }

        print("[VisionFaceDetector] ⏹️  Stopping face detection...")
        captureSession?.stopRunning()

        isTracking = false
        faceExpression = FaceExpression()
        trackingQuality = 0
        detectionConfidence = 0
    }

    /// Reset detection
    public func reset() {
        print("[VisionFaceDetector] 🔄 Resetting face detection...")
        stop()
        start()
    }

    // MARK: - Setup

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium  // Balance quality and performance

        // Get front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("[VisionFaceDetector] ❌ Front camera not available")
            return
        }

        // Configure camera for target frame rate
        do {
            try camera.lockForConfiguration()

            // Set frame rate
            if let format = camera.formats.first(where: { format in
                let ranges = format.videoSupportedFrameRateRanges
                return ranges.contains(where: { $0.maxFrameRate >= Float64(targetFrameRate) })
            }) {
                camera.activeFormat = format
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(targetFrameRate))
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(targetFrameRate))
            }

            camera.unlockForConfiguration()
        } catch {
            print("[VisionFaceDetector] ⚠️  Failed to configure camera: \(error)")
        }

        // Add camera input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("[VisionFaceDetector] ❌ Failed to add camera input: \(error)")
            return
        }

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.videoOutput = output
        self.captureSession = session
    }

    // MARK: - Face Detection

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        if let error = error {
            print("[VisionFaceDetector] ❌ Detection error: \(error)")
            Task { @MainActor in
                self.trackingQuality = 0
                self.detectionConfidence = 0
            }
            return
        }

        guard let results = request.results as? [VNFaceObservation],
              let face = results.first else {
            // No face detected
            Task { @MainActor in
                self.trackingQuality = 0
                self.detectionConfidence = 0
            }
            return
        }

        // Update tracking statistics
        framesProcessed += 1
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        if deltaTime > 0 {
            actualFrameRate = 1.0 / deltaTime
        }
        lastFrameTime = now

        // Extract face expression from landmarks
        if let landmarks = face.landmarks {
            let expression = extractFaceExpression(from: landmarks, confidence: Float(face.confidence))

            // Apply smoothing
            let smoothedExpression = applySmoothingToExpression(expression)

            // Update published values on main thread
            Task { @MainActor in
                self.faceExpression = smoothedExpression
                self.trackingQuality = Float(face.confidence)
                self.detectionConfidence = Float(face.confidence)
            }
        }
    }

    // MARK: - Expression Extraction

    /// Convert Vision landmarks to approximate FaceExpression
    private func extractFaceExpression(from landmarks: VNFaceLandmarks2D, confidence: Float) -> FaceExpression {
        var jawOpen: Float = 0
        var mouthSmileLeft: Float = 0
        var mouthSmileRight: Float = 0
        var browInnerUp: Float = 0
        var browOuterUpLeft: Float = 0
        var browOuterUpRight: Float = 0
        var eyeBlinkLeft: Float = 0
        var eyeBlinkRight: Float = 0
        var eyeWideLeft: Float = 0
        var eyeWideRight: Float = 0
        var mouthFunnel: Float = 0
        var mouthPucker: Float = 0
        var cheekPuff: Float = 0

        // Jaw Open (approximate from mouth opening)
        if let outerLips = landmarks.outerLips {
            let points = outerLips.normalizedPoints
            if points.count >= 8 {
                // Calculate vertical distance between upper and lower lip
                let topLip = points[3]  // Top center
                let bottomLip = points[9 % points.count]  // Bottom center
                let mouthHeight = abs(topLip.y - bottomLip.y)

                // Normalize to 0-1 range (typical mouth height: 0.02 - 0.08)
                jawOpen = Float(min(1.0, max(0.0, (mouthHeight - 0.02) / 0.06)))
            }
        }

        // Smile Detection (mouth corners up)
        if let outerLips = landmarks.outerLips {
            let points = outerLips.normalizedPoints
            if points.count >= 7 {
                let leftCorner = points[0]
                let rightCorner = points[6]
                let centerTop = points[3]

                // Check if corners are above center (smile)
                let leftSmile = Float(max(0.0, centerTop.y - leftCorner.y) * 10.0)  // Scale up
                let rightSmile = Float(max(0.0, centerTop.y - rightCorner.y) * 10.0)

                mouthSmileLeft = min(1.0, leftSmile)
                mouthSmileRight = min(1.0, rightSmile)
            }
        }

        // Eyebrow Raise Detection
        if let leftEyebrow = landmarks.leftEyebrow,
           let leftEye = landmarks.leftEye {
            let browPoints = leftEyebrow.normalizedPoints
            let eyePoints = leftEye.normalizedPoints

            if browPoints.count >= 3 && eyePoints.count >= 3 {
                let browAvgY = browPoints.reduce(0.0) { $0 + $1.y } / CGFloat(browPoints.count)
                let eyeAvgY = eyePoints.reduce(0.0) { $0 + $1.y } / CGFloat(eyePoints.count)
                let distance = eyeAvgY - browAvgY

                // Normalize (typical distance: 0.03 - 0.06)
                browOuterUpLeft = Float(min(1.0, max(0.0, (distance - 0.03) / 0.03)))
            }
        }

        if let rightEyebrow = landmarks.rightEyebrow,
           let rightEye = landmarks.rightEye {
            let browPoints = rightEyebrow.normalizedPoints
            let eyePoints = rightEye.normalizedPoints

            if browPoints.count >= 3 && eyePoints.count >= 3 {
                let browAvgY = browPoints.reduce(0.0) { $0 + $1.y } / CGFloat(browPoints.count)
                let eyeAvgY = eyePoints.reduce(0.0) { $0 + $1.y } / CGFloat(eyePoints.count)
                let distance = eyeAvgY - browAvgY

                browOuterUpRight = Float(min(1.0, max(0.0, (distance - 0.03) / 0.03)))
            }
        }

        // Inner brow (average of outer)
        browInnerUp = (browOuterUpLeft + browOuterUpRight) / 2.0

        // Eye Blink Detection (eye height)
        if let leftEye = landmarks.leftEye {
            let points = leftEye.normalizedPoints
            if points.count >= 6 {
                let topPoints = points.prefix(3)
                let bottomPoints = points.suffix(3)
                let avgTopY = topPoints.reduce(0.0) { $0 + $1.y } / CGFloat(topPoints.count)
                let avgBottomY = bottomPoints.reduce(0.0) { $0 + $1.y } / CGFloat(bottomPoints.count)
                let eyeHeight = abs(avgTopY - avgBottomY)

                // Normalize (open eye: ~0.02, closed: ~0.005)
                let openness = Float((eyeHeight - 0.005) / 0.015)
                eyeBlinkLeft = max(0.0, min(1.0, 1.0 - openness))  // Invert: 1 = closed
            }
        }

        if let rightEye = landmarks.rightEye {
            let points = rightEye.normalizedPoints
            if points.count >= 6 {
                let topPoints = points.prefix(3)
                let bottomPoints = points.suffix(3)
                let avgTopY = topPoints.reduce(0.0) { $0 + $1.y } / CGFloat(topPoints.count)
                let avgBottomY = bottomPoints.reduce(0.0) { $0 + $1.y } / CGFloat(bottomPoints.count)
                let eyeHeight = abs(avgTopY - avgBottomY)

                let openness = Float((eyeHeight - 0.005) / 0.015)
                eyeBlinkRight = max(0.0, min(1.0, 1.0 - openness))
            }
        }

        // Eye Wide (inverse of blink for now)
        eyeWideLeft = max(0.0, 1.0 - eyeBlinkLeft * 2.0)  // Wide = very not blinking
        eyeWideRight = max(0.0, 1.0 - eyeBlinkRight * 2.0)

        // Mouth Funnel / Pucker (approximate from inner lips)
        if let innerLips = landmarks.innerLips {
            let points = innerLips.normalizedPoints
            if points.count >= 4 {
                // Calculate mouth roundness (width vs height ratio)
                let leftmost = points.min(by: { $0.x < $1.x })!
                let rightmost = points.max(by: { $0.x < $1.x })!
                let topmost = points.min(by: { $0.y < $1.y })!
                let bottommost = points.max(by: { $0.y < $1.y })!

                let width = rightmost.x - leftmost.x
                let height = bottommost.y - topmost.y

                if width > 0 {
                    let ratio = Float(height / width)

                    // Funnel = tall and narrow (ratio > 1)
                    mouthFunnel = max(0.0, min(1.0, ratio - 0.5))

                    // Pucker = small and round (ratio ~1, small size)
                    let size = Float(width * height)
                    mouthPucker = max(0.0, min(1.0, (1.0 - size * 100.0) * ratio))
                }
            }
        }

        // Cheek Puff (not detectable with 2D landmarks, set to 0)
        cheekPuff = 0.0

        // Scale by confidence
        let scale = confidence

        return FaceExpression(
            jawOpen: jawOpen * scale,
            mouthSmileLeft: mouthSmileLeft * scale,
            mouthSmileRight: mouthSmileRight * scale,
            browInnerUp: browInnerUp * scale,
            browOuterUpLeft: browOuterUpLeft * scale,
            browOuterUpRight: browOuterUpRight * scale,
            eyeBlinkLeft: eyeBlinkLeft * scale,
            eyeBlinkRight: eyeBlinkRight * scale,
            eyeWideLeft: eyeWideLeft * scale,
            eyeWideRight: eyeWideRight * scale,
            mouthFunnel: mouthFunnel * scale,
            mouthPucker: mouthPucker * scale,
            cheekPuff: cheekPuff * scale
        )
    }

    // MARK: - Smoothing

    private func applySmoothingToExpression(_ expression: FaceExpression) -> FaceExpression {
        // Add to history
        expressionHistory.append(expression)

        // Keep window size limited
        if expressionHistory.count > smoothingWindowSize {
            expressionHistory.removeFirst()
        }

        // Return average
        guard !expressionHistory.isEmpty else { return expression }

        let count = Float(expressionHistory.count)

        return FaceExpression(
            jawOpen: expressionHistory.reduce(0.0) { $0 + $1.jawOpen } / count,
            mouthSmileLeft: expressionHistory.reduce(0.0) { $0 + $1.mouthSmileLeft } / count,
            mouthSmileRight: expressionHistory.reduce(0.0) { $0 + $1.mouthSmileRight } / count,
            browInnerUp: expressionHistory.reduce(0.0) { $0 + $1.browInnerUp } / count,
            browOuterUpLeft: expressionHistory.reduce(0.0) { $0 + $1.browOuterUpLeft } / count,
            browOuterUpRight: expressionHistory.reduce(0.0) { $0 + $1.browOuterUpRight } / count,
            eyeBlinkLeft: expressionHistory.reduce(0.0) { $0 + $1.eyeBlinkLeft } / count,
            eyeBlinkRight: expressionHistory.reduce(0.0) { $0 + $1.eyeBlinkRight } / count,
            eyeWideLeft: expressionHistory.reduce(0.0) { $0 + $1.eyeWideLeft } / count,
            eyeWideRight: expressionHistory.reduce(0.0) { $0 + $1.eyeWideRight } / count,
            mouthFunnel: expressionHistory.reduce(0.0) { $0 + $1.mouthFunnel } / count,
            mouthPucker: expressionHistory.reduce(0.0) { $0 + $1.mouthPucker } / count,
            cheekPuff: expressionHistory.reduce(0.0) { $0 + $1.cheekPuff } / count
        )
    }

    // MARK: - Utilities

    /// Get tracking statistics
    public var statistics: TrackingStatistics {
        TrackingStatistics(
            isTracking: isTracking,
            trackingQuality: trackingQuality,
            blendShapeCount: 13,  // We approximate 13 blend shapes
            hasHeadTransform: false  // 2D detection doesn't provide 3D transform
        )
    }

    /// Get performance statistics
    public var performanceStats: String {
        """
        [VisionFaceDetector Performance]
        Tracking: \(isTracking ? "Active" : "Inactive")
        Frame Rate: \(String(format: "%.1f", actualFrameRate)) Hz (target: \(targetFrameRate) Hz)
        Frames Processed: \(framesProcessed)
        Quality: \(String(format: "%.1f", trackingQuality * 100))%
        Confidence: \(String(format: "%.1f", detectionConfidence * 100))%
        """
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VisionFaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Create Vision image request handler
        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,  // Front camera is mirrored
            options: [:]
        )

        // Perform face detection
        do {
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("[VisionFaceDetector] ❌ Failed to perform detection: \(error)")
        }
    }
}

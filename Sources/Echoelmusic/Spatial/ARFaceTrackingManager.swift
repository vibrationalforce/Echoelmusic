import Foundation
import Combine
import simd

#if canImport(ARKit)
import ARKit
#endif

/// Manages ARKit face tracking and extracts 52 blend shapes for audio/visual control
///
/// **Features:**
/// - Real-time face tracking @ 60 Hz
/// - 52 ARKit blend shapes (jaw, eyes, brows, mouth, etc.)
/// - Thread-safe published properties for SwiftUI
/// - Automatic session recovery
///
/// **Permissions Required:**
/// - NSCameraUsageDescription in Info.plist
///
/// **Usage:**
/// ```swift
/// let faceManager = ARFaceTrackingManager()
/// faceManager.start()
///
/// // Subscribe to face expression
/// faceManager.$faceExpression
///     .sink { expression in
///         let jawOpen = expression.jawOpen
///         // Map to audio parameters
///     }
/// ```

// MARK: - Supporting Types (Platform-Independent)

/// Simplified face expression for common use cases
public struct FaceExpression: Equatable, Sendable {
    // Jaw
    public let jawOpen: Float

    // Mouth
    public let mouthSmileLeft: Float
    public let mouthSmileRight: Float
    public let mouthFunnel: Float
    public let mouthPucker: Float

    // Eyebrows
    public let browInnerUp: Float
    public let browOuterUpLeft: Float
    public let browOuterUpRight: Float

    // Eyes
    public let eyeBlinkLeft: Float
    public let eyeBlinkRight: Float
    public let eyeWideLeft: Float
    public let eyeWideRight: Float

    // Cheeks
    public let cheekPuff: Float

    // Computed properties for convenience
    public var smile: Float {
        (mouthSmileLeft + mouthSmileRight) / 2.0
    }

    public var browRaise: Float {
        (browInnerUp + browOuterUpLeft + browOuterUpRight) / 3.0
    }

    public var eyeBlink: Float {
        (eyeBlinkLeft + eyeBlinkRight) / 2.0
    }

    public var eyeWide: Float {
        (eyeWideLeft + eyeWideRight) / 2.0
    }

    public init(
        jawOpen: Float = 0,
        mouthSmileLeft: Float = 0,
        mouthSmileRight: Float = 0,
        browInnerUp: Float = 0,
        browOuterUpLeft: Float = 0,
        browOuterUpRight: Float = 0,
        eyeBlinkLeft: Float = 0,
        eyeBlinkRight: Float = 0,
        eyeWideLeft: Float = 0,
        eyeWideRight: Float = 0,
        mouthFunnel: Float = 0,
        mouthPucker: Float = 0,
        cheekPuff: Float = 0
    ) {
        self.jawOpen = jawOpen
        self.mouthSmileLeft = mouthSmileLeft
        self.mouthSmileRight = mouthSmileRight
        self.browInnerUp = browInnerUp
        self.browOuterUpLeft = browOuterUpLeft
        self.browOuterUpRight = browOuterUpRight
        self.eyeBlinkLeft = eyeBlinkLeft
        self.eyeBlinkRight = eyeBlinkRight
        self.eyeWideLeft = eyeWideLeft
        self.eyeWideRight = eyeWideRight
        self.mouthFunnel = mouthFunnel
        self.mouthPucker = mouthPucker
        self.cheekPuff = cheekPuff
    }
}

/// Tracking statistics for debugging/monitoring
public struct TrackingStatistics: Sendable {
    public let isTracking: Bool
    public let trackingQuality: Float
    public let blendShapeCount: Int
    public let hasHeadTransform: Bool

    public var isHealthy: Bool {
        isTracking && trackingQuality > 0.5 && blendShapeCount > 20
    }

    public init(isTracking: Bool = false, trackingQuality: Float = 0, blendShapeCount: Int = 0, hasHeadTransform: Bool = false) {
        self.isTracking = isTracking
        self.trackingQuality = trackingQuality
        self.blendShapeCount = blendShapeCount
        self.hasHeadTransform = hasHeadTransform
    }
}

// MARK: - ARFaceTrackingManager

#if canImport(ARKit) && os(iOS)

@MainActor
public class ARFaceTrackingManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// Current blend shapes (0.0 - 1.0 for each shape)
    @Published public private(set) var blendShapes: [ARFaceAnchor.BlendShapeLocation: Float] = [:]

    /// Simplified face expression values
    @Published public private(set) var faceExpression: FaceExpression = FaceExpression()

    /// Whether face tracking is currently active
    @Published public private(set) var isTracking: Bool = false

    /// Head transform (position and rotation in world space)
    @Published public private(set) var headTransform: simd_float4x4?

    /// Face tracking quality (0.0 - 1.0)
    @Published public private(set) var trackingQuality: Float = 0

    // MARK: - Configuration

    /// Update rate in Hz (default: 60)
    public var targetFrameRate: Int = 60

    /// Minimum confidence threshold for blend shapes (0.0 - 1.0)
    public var confidenceThreshold: Float = 0.3

    // MARK: - ARKit Session

    private var arSession: ARSession?
    private var configuration: ARFaceTrackingConfiguration?

    // MARK: - Initialization

    public override init() {
        super.init()
        setupARSession()
    }

    deinit {
        // stop() is @MainActor-isolated, cannot call from deinit
        arSession?.pause()
    }

    // MARK: - Lifecycle

    /// Start face tracking (requires TrueDepth camera + camera permission)
    public func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            log.spatial("[ARFaceTrackingManager] Face tracking not supported on this device", level: .error)
            return
        }

        // Check camera permission before starting ARSession
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        AdaptiveCapabilityManager.shared.refresh(.camera)
                        AdaptiveCapabilityManager.shared.refresh(.faceTracking)
                        self?.startSession()
                    } else {
                        log.spatial("[ARFaceTrackingManager] Camera permission denied", level: .warning)
                    }
                }
            }
            return
        case .denied, .restricted:
            log.spatial("[ARFaceTrackingManager] Camera permission denied — face tracking unavailable", level: .warning)
            return
        case .authorized:
            break
        @unknown default:
            break
        }

        startSession()
    }

    private func startSession() {
        log.spatial("[ARFaceTrackingManager] Starting face tracking...")

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        config.maximumNumberOfTrackedFaces = 1

        self.configuration = config
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])

        isTracking = true
    }

    /// Stop face tracking
    public func stop() {
        log.spatial("[ARFaceTrackingManager] ⏹️ Stopping face tracking...")
        arSession?.pause()
        isTracking = false
        blendShapes = [:]
        headTransform = nil
        trackingQuality = 0
    }

    /// Reset tracking (useful if tracking is lost)
    public func reset() {
        log.spatial("[ARFaceTrackingManager] 🔄 Resetting face tracking...")
        stop()
        start()
    }

    // MARK: - Setup

    private func setupARSession() {
        let session = ARSession()
        session.delegate = self
        self.arSession = session
    }

    // MARK: - Blend Shape Processing

    private func processBlendShapes(_ shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) {
        var processedShapes: [ARFaceAnchor.BlendShapeLocation: Float] = [:]

        for (location, value) in shapes {
            let floatValue = value.floatValue
            if floatValue >= confidenceThreshold {
                processedShapes[location] = floatValue
            }
        }

        Task { @MainActor in
            self.blendShapes = processedShapes
            self.updateFaceExpression(from: processedShapes)
        }
    }

    private func updateFaceExpression(from shapes: [ARFaceAnchor.BlendShapeLocation: Float]) {
        faceExpression = FaceExpression(
            jawOpen: shapes[.jawOpen] ?? 0,
            mouthSmileLeft: shapes[.mouthSmileLeft] ?? 0,
            mouthSmileRight: shapes[.mouthSmileRight] ?? 0,
            browInnerUp: shapes[.browInnerUp] ?? 0,
            browOuterUpLeft: shapes[.browOuterUpLeft] ?? 0,
            browOuterUpRight: shapes[.browOuterUpRight] ?? 0,
            eyeBlinkLeft: shapes[.eyeBlinkLeft] ?? 0,
            eyeBlinkRight: shapes[.eyeBlinkRight] ?? 0,
            eyeWideLeft: shapes[.eyeWideLeft] ?? 0,
            eyeWideRight: shapes[.eyeWideRight] ?? 0,
            mouthFunnel: shapes[.mouthFunnel] ?? 0,
            mouthPucker: shapes[.mouthPucker] ?? 0,
            cheekPuff: shapes[.cheekPuff] ?? 0
        )
    }

    // MARK: - Utilities

    public var statistics: TrackingStatistics {
        TrackingStatistics(
            isTracking: isTracking,
            trackingQuality: trackingQuality,
            blendShapeCount: blendShapes.count,
            hasHeadTransform: headTransform != nil
        )
    }
}

// MARK: - ARSessionDelegate

extension ARFaceTrackingManager: ARSessionDelegate {

    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }

        processBlendShapes(faceAnchor.blendShapes)

        Task { @MainActor in
            self.headTransform = faceAnchor.transform
        }

        let quality: Float = switch session.currentFrame?.camera.trackingState {
        case .normal: 1.0
        case .limited: 0.5
        case .notAvailable: 0.0
        case nil: 0.0
        }

        Task { @MainActor in
            self.trackingQuality = quality
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        log.spatial("[ARFaceTrackingManager] ❌ Session failed: \(error.localizedDescription)", level: .error)
        Task { @MainActor in
            self.isTracking = false
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        log.spatial("[ARFaceTrackingManager] ⚠️ Session interrupted", level: .warning)
        Task { @MainActor in
            self.isTracking = false
        }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        log.spatial("[ARFaceTrackingManager] ✅ Session interruption ended, restarting...")
        reset()
    }
}

#else

// MARK: - Stub for Platforms without ARKit

@MainActor
public class ARFaceTrackingManager: ObservableObject {

    @Published public private(set) var faceExpression: FaceExpression = FaceExpression()
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var headTransform: simd_float4x4?
    @Published public private(set) var trackingQuality: Float = 0

    public var targetFrameRate: Int = 60
    public var confidenceThreshold: Float = 0.3

    public init() {}

    public func start() {
        log.spatial("[ARFaceTrackingManager] ⚠️ ARKit not available on this platform", level: .warning)
    }

    public func stop() {}

    public func reset() {}

    public var statistics: TrackingStatistics {
        TrackingStatistics()
    }
}

#endif

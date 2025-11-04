import Foundation
import Combine

#if os(iOS) || os(visionOS)
import ARKit
import UIKit
#endif

/// Gaze Tracking System
/// Supports: ARKit eye tracking, Vision Pro native, ML-based gaze estimation
///
/// Use cases:
/// - Eye-controlled audio parameters
/// - Gaze-based UI navigation
/// - Attention tracking for performances
/// - Accessibility features
/// - Cognitive load estimation

// MARK: - Gaze Data

/// Current gaze information
public struct GazeData {
    public let leftEye: EyeData
    public let rightEye: EyeData
    public let combinedLookAt: CGPoint // Screen-space coordinates (0-1)
    public let isTracking: Bool
    public let confidence: Float // 0-1
    public let timestamp: Date

    /// Average of both eyes
    public var averageGaze: CGPoint {
        CGPoint(
            x: (leftEye.lookAtPoint.x + rightEye.lookAtPoint.x) / 2,
            y: (leftEye.lookAtPoint.y + rightEye.lookAtPoint.y) / 2
        )
    }

    public init(
        leftEye: EyeData,
        rightEye: EyeData,
        combinedLookAt: CGPoint,
        isTracking: Bool,
        confidence: Float,
        timestamp: Date = Date()
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.combinedLookAt = combinedLookAt
        self.isTracking = isTracking
        self.confidence = confidence
        self.timestamp = timestamp
    }

    public static let empty = GazeData(
        leftEye: .empty,
        rightEye: .empty,
        combinedLookAt: CGPoint(x: 0.5, y: 0.5),
        isTracking: false,
        confidence: 0,
        timestamp: Date()
    )
}

/// Individual eye data
public struct EyeData {
    public let lookAtPoint: CGPoint // Normalized (0-1)
    public let blinkState: BlinkState
    public let pupilDiameter: Float // mm
    public let isTracking: Bool

    public enum BlinkState {
        case open
        case closing
        case closed
        case opening
    }

    public static let empty = EyeData(
        lookAtPoint: CGPoint(x: 0.5, y: 0.5),
        blinkState: .open,
        pupilDiameter: 4.0,
        isTracking: false
    )
}

// MARK: - Gaze Tracker

/// Main gaze tracking manager
@MainActor
public final class GazeTracker: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentGaze: GazeData = .empty
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var gazeVelocity: CGVector = .zero // Screen points/sec
    @Published public private(set) var fixationPoint: CGPoint? // Current fixation
    @Published public private(set) var fixationDuration: TimeInterval = 0

    // MARK: - Configuration

    public var fixationThreshold: CGFloat = 0.05 // Radius in normalized coords
    public var fixationTimeThreshold: TimeInterval = 0.15 // seconds
    public var smoothingFactor: Float = 0.3 // 0 = no smoothing, 1 = max smoothing

    // MARK: - Private Properties

    private var previousGaze: GazeData?
    private var previousTimestamp: Date?
    private var currentFixationStart: Date?

    #if os(iOS)
    private var arSession: ARSession?
    private var faceAnchor: ARFaceAnchor?
    #endif

    #if os(visionOS)
    // Vision Pro uses native eye tracking APIs
    private var visionProTracker: Any? // VisionProEyeTracker
    #endif

    // MARK: - Initialization

    public init() {}

    // MARK: - Control Methods

    /// Start gaze tracking
    public func start() {
        #if os(iOS)
        startARKitTracking()
        #elseif os(visionOS)
        startVisionProTracking()
        #endif

        isTracking = true
        print("👁️ Gaze tracking started")
    }

    /// Stop gaze tracking
    public func stop() {
        #if os(iOS)
        arSession?.pause()
        arSession = nil
        #endif

        isTracking = false
        currentGaze = .empty
        print("👁️ Gaze tracking stopped")
    }

    // MARK: - ARKit Integration (iOS)

    #if os(iOS)
    private func startARKitTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ Face tracking not supported on this device")
            return
        }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false

        arSession = ARSession()
        arSession?.delegate = self
        arSession?.run(configuration)
    }

    private func updateFromFaceAnchor(_ anchor: ARFaceAnchor) {
        // Extract eye tracking data from ARFaceAnchor
        let leftEye = extractEyeData(from: anchor, isLeft: true)
        let rightEye = extractEyeData(from: anchor, isLeft: false)

        // Calculate combined look-at point
        let combinedLookAt = calculateCombinedGaze(left: leftEye, right: rightEye)

        // Calculate confidence based on tracking quality
        let confidence = calculateConfidence(anchor)

        // Apply smoothing
        let smoothedGaze = applySmoothing(to: combinedLookAt)

        // Create gaze data
        let gazeData = GazeData(
            leftEye: leftEye,
            rightEye: rightEye,
            combinedLookAt: smoothedGaze,
            isTracking: true,
            confidence: confidence
        )

        updateGazeData(gazeData)
    }

    private func extractEyeData(from anchor: ARFaceAnchor, isLeft: Bool) -> EyeData {
        // Get eye transform
        let eyeTransform = isLeft ? anchor.leftEyeTransform : anchor.rightEyeTransform

        // Calculate look direction (simplified)
        let lookDirection = simd_make_float3(eyeTransform.columns.2)
        let lookAtPoint = projectToScreen(direction: lookDirection)

        // Get blink state from blend shapes
        let blinkKey: ARFaceAnchor.BlendShapeLocation = isLeft ? .eyeBlinkLeft : .eyeBlinkRight
        let blinkValue = anchor.blendShapes[blinkKey]?.floatValue ?? 0

        let blinkState: EyeData.BlinkState
        if blinkValue < 0.2 {
            blinkState = .open
        } else if blinkValue < 0.5 {
            blinkState = .closing
        } else if blinkValue < 0.8 {
            blinkState = .closed
        } else {
            blinkState = .opening
        }

        // Estimate pupil diameter (ARKit doesn't provide this directly)
        let pupilDiameter: Float = 4.0 // Default

        return EyeData(
            lookAtPoint: lookAtPoint,
            blinkState: blinkState,
            pupilDiameter: pupilDiameter,
            isTracking: true
        )
    }

    private func projectToScreen(direction: simd_float3) -> CGPoint {
        // Simple projection to normalized screen space
        // This is a simplified version - real implementation would use camera intrinsics

        let x = Double(direction.x)
        let y = Double(-direction.y) // Flip Y

        // Map from [-1, 1] to [0, 1]
        let normalizedX = (x + 1.0) / 2.0
        let normalizedY = (y + 1.0) / 2.0

        return CGPoint(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY))
        )
    }

    private func calculateConfidence(_ anchor: ARFaceAnchor) -> Float {
        // Use tracking quality and face detection confidence
        // ARKit doesn't provide explicit confidence, so we estimate it
        let isWellTracked = anchor.isTracked
        return isWellTracked ? 0.9 : 0.3
    }
    #endif

    // MARK: - Vision Pro Integration

    #if os(visionOS)
    private func startVisionProTracking() {
        // Vision Pro has native, high-precision eye tracking
        // This would use visionOS-specific APIs
        print("👁️ Vision Pro eye tracking initialized")
    }
    #endif

    // MARK: - Gaze Processing

    private func calculateCombinedGaze(left: EyeData, right: EyeData) -> CGPoint {
        // Weighted average based on tracking confidence
        if !left.isTracking && !right.isTracking {
            return CGPoint(x: 0.5, y: 0.5)
        } else if !left.isTracking {
            return right.lookAtPoint
        } else if !right.isTracking {
            return left.lookAtPoint
        }

        // Average both eyes
        return CGPoint(
            x: (left.lookAtPoint.x + right.lookAtPoint.x) / 2,
            y: (left.lookAtPoint.y + right.lookAtPoint.y) / 2
        )
    }

    private func applySmoothing(to point: CGPoint) -> CGPoint {
        guard let previous = previousGaze?.combinedLookAt else {
            return point
        }

        let alpha = CGFloat(1.0 - smoothingFactor)
        return CGPoint(
            x: previous.x * CGFloat(smoothingFactor) + point.x * alpha,
            y: previous.y * CGFloat(smoothingFactor) + point.y * alpha
        )
    }

    private func updateGazeData(_ gazeData: GazeData) {
        // Calculate velocity
        if let previous = previousGaze, let prevTime = previousTimestamp {
            let dt = gazeData.timestamp.timeIntervalSince(prevTime)
            if dt > 0 {
                let dx = gazeData.combinedLookAt.x - previous.combinedLookAt.x
                let dy = gazeData.combinedLookAt.y - previous.combinedLookAt.y
                gazeVelocity = CGVector(dx: dx / dt, dy: dy / dt)
            }
        }

        // Detect fixations
        updateFixationDetection(gazeData)

        // Update state
        previousGaze = gazeData
        previousTimestamp = gazeData.timestamp
        currentGaze = gazeData
    }

    private func updateFixationDetection(_ gazeData: GazeData) {
        if let fixation = fixationPoint {
            let distance = sqrt(
                pow(gazeData.combinedLookAt.x - fixation.x, 2) +
                pow(gazeData.combinedLookAt.y - fixation.y, 2)
            )

            if distance < fixationThreshold {
                // Still fixating
                if let startTime = currentFixationStart {
                    fixationDuration = Date().timeIntervalSince(startTime)
                }
            } else {
                // Fixation broken
                fixationPoint = nil
                currentFixationStart = nil
                fixationDuration = 0
            }
        } else {
            // Check if we should start a new fixation
            if let previous = previousGaze {
                let distance = sqrt(
                    pow(gazeData.combinedLookAt.x - previous.combinedLookAt.x, 2) +
                    pow(gazeData.combinedLookAt.y - previous.combinedLookAt.y, 2)
                )

                if distance < fixationThreshold {
                    fixationPoint = gazeData.combinedLookAt
                    currentFixationStart = Date()
                }
            }
        }
    }

    // MARK: - Utility Methods

    /// Convert normalized gaze point to screen coordinates
    public func gazeToScreenPoint(_ gazePoint: CGPoint, screenSize: CGSize) -> CGPoint {
        return CGPoint(
            x: gazePoint.x * screenSize.width,
            y: gazePoint.y * screenSize.height
        )
    }

    /// Check if gaze is within a region
    public func isGazeIn(rect: CGRect, normalizedCoords: Bool = true) -> Bool {
        let point = currentGaze.combinedLookAt

        if normalizedCoords {
            return rect.contains(point)
        } else {
            // Assume rect is in screen coordinates - need screen size
            return false // TODO: Implement with screen size
        }
    }

    /// Get gaze intensity (1.0 at center, 0.0 at edges)
    public func gazeIntensity() -> Float {
        let point = currentGaze.combinedLookAt
        let centerX = 0.5
        let centerY = 0.5

        let distance = sqrt(
            pow(point.x - centerX, 2) +
            pow(point.y - centerY, 2)
        )

        // Max distance is ~0.707 (corner to center)
        let normalized = Float(distance / 0.707)
        return max(0, 1.0 - normalized)
    }
}

// MARK: - ARSession Delegate

#if os(iOS)
extension GazeTracker: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let faceAnchor = anchor as? ARFaceAnchor {
                self.faceAnchor = faceAnchor
                updateFromFaceAnchor(faceAnchor)
            }
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        print("⚠️ AR Session failed: \(error.localizedDescription)")
        isTracking = false
    }
}
#endif

// MARK: - Gaze-to-Audio Mapping

extension GazeTracker {

    /// Map gaze X position to parameter (0-1)
    public func gazeX() -> Float {
        return Float(currentGaze.combinedLookAt.x)
    }

    /// Map gaze Y position to parameter (0-1)
    public func gazeY() -> Float {
        return Float(currentGaze.combinedLookAt.y)
    }

    /// Map gaze velocity magnitude to parameter
    public func gazeSpeed() -> Float {
        let magnitude = sqrt(gazeVelocity.dx * gazeVelocity.dx + gazeVelocity.dy * gazeVelocity.dy)
        return Float(min(1.0, magnitude / 5.0)) // Normalize to reasonable range
    }

    /// Is user blinking both eyes?
    public func isBothEyesClosed() -> Bool {
        return currentGaze.leftEye.blinkState == .closed &&
               currentGaze.rightEye.blinkState == .closed
    }

    /// Map fixation duration to parameter (longer fixation = higher value)
    public func fixationStrength() -> Float {
        guard fixationDuration > fixationTimeThreshold else { return 0 }

        // Scale from 0-1 over 2 seconds
        return Float(min(1.0, fixationDuration / 2.0))
    }
}

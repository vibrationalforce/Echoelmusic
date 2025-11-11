import Foundation
import ARKit
import Combine

/// Gaze Tracking Manager using ARKit
/// Tracks where the user is looking to control audio parameters
/// Requires ARFaceTrackingConfiguration (iPhone X+, iPad Pro 2018+)
@MainActor
class GazeTrackingManager: ObservableObject {

    // MARK: - Published State

    /// Current gaze direction (normalized vector)
    @Published var gazeDirection: SIMD3<Float> = .zero

    /// Gaze target point in 3D space (meters from user)
    @Published var gazeTargetPoint: SIMD3<Float> = SIMD3(0, 0, -1)

    /// Left eye direction
    @Published var leftEyeDirection: SIMD3<Float> = .zero

    /// Right eye direction
    @Published var rightEyeDirection: SIMD3<Float> = .zero

    /// Whether gaze tracking is available on this device
    @Published var isAvailable: Bool = false

    /// Whether gaze tracking is currently active
    @Published var isTracking: Bool = false

    /// Gaze fixation confidence (0-1)
    @Published var fixationConfidence: Float = 0.0

    // MARK: - AR Session

    private var arSession: ARSession?
    private var arConfiguration: ARFaceTrackingConfiguration?

    // MARK: - Smoothing

    private var gazeHistory: [SIMD3<Float>] = []
    private let smoothingWindowSize = 5

    // MARK: - Initialization

    init() {
        checkAvailability()
    }

    deinit {
        stop()
    }

    // MARK: - Availability Check

    private func checkAvailability() {
        #if targetEnvironment(simulator)
        isAvailable = false
        print("[GazeTracker] ⚠️ Gaze tracking not available in simulator")
        #else
        isAvailable = ARFaceTrackingConfiguration.isSupported
        if !isAvailable {
            print("[GazeTracker] ⚠️ Gaze tracking requires iPhone X or later")
        }
        #endif
    }

    // MARK: - Tracking Control

    /// Start gaze tracking
    func start() {
        guard isAvailable else {
            print("[GazeTracker] ❌ Gaze tracking not available on this device")
            return
        }

        guard !isTracking else {
            print("[GazeTracker] ⚠️ Already tracking")
            return
        }

        // Create AR session
        let session = ARSession()
        self.arSession = session

        // Configure face tracking
        let configuration = ARFaceTrackingConfiguration()
        configuration.isWorldTrackingEnabled = false // Only need face tracking
        self.arConfiguration = configuration

        // Start session
        session.run(configuration)
        isTracking = true

        print("[GazeTracker] ✅ Gaze tracking started")
    }

    /// Stop gaze tracking
    func stop() {
        arSession?.pause()
        arSession = nil
        isTracking = false
        print("[GazeTracker] ⏹️ Gaze tracking stopped")
    }

    // MARK: - AR Session Delegate (would be implemented in real app)

    /// Process AR frame (called by AR session delegate)
    func processARFrame(_ frame: ARFrame) {
        #if !targetEnvironment(simulator)
        // Extract face anchor
        guard let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }

        // Extract eye tracking data
        if let lookAtPoint = faceAnchor.lookAtPoint {
            // Get gaze target point
            gazeTargetPoint = lookAtPoint

            // Calculate gaze direction (normalized)
            let direction = normalize(lookAtPoint)
            gazeDirection = smoothGaze(direction)
        }

        // Extract left eye direction
        if let leftEye = faceAnchor.leftEyeTransform {
            leftEyeDirection = normalize(SIMD3(leftEye.columns.2.x, leftEye.columns.2.y, leftEye.columns.2.z))
        }

        // Extract right eye direction
        if let rightEye = faceAnchor.rightEyeTransform {
            rightEyeDirection = normalize(SIMD3(rightEye.columns.2.x, rightEye.columns.2.y, rightEye.columns.2.z))
        }

        // Calculate fixation confidence (how stable is gaze)
        updateFixationConfidence()
        #endif
    }

    // MARK: - Gaze Smoothing

    private func smoothGaze(_ direction: SIMD3<Float>) -> SIMD3<Float> {
        // Add to history
        gazeHistory.append(direction)

        // Keep only recent history
        if gazeHistory.count > smoothingWindowSize {
            gazeHistory.removeFirst()
        }

        // Calculate smoothed average
        var sum = SIMD3<Float>.zero
        for gaze in gazeHistory {
            sum += gaze
        }
        return sum / Float(gazeHistory.count)
    }

    private func updateFixationConfidence() {
        guard gazeHistory.count >= 2 else {
            fixationConfidence = 0.0
            return
        }

        // Calculate variance of recent gaze directions
        var variance: Float = 0.0
        for i in 1..<gazeHistory.count {
            let diff = gazeHistory[i] - gazeHistory[i-1]
            variance += length(diff)
        }
        variance /= Float(gazeHistory.count - 1)

        // Convert variance to confidence (lower variance = higher confidence)
        // Variance 0.0-0.1 maps to confidence 1.0-0.0
        fixationConfidence = max(0.0, min(1.0, 1.0 - variance * 10.0))
    }

    // MARK: - Gaze Utilities

    /// Get gaze direction as angles (horizontal, vertical) in radians
    func getGazeAngles() -> (horizontal: Float, vertical: Float) {
        let horizontal = atan2(gazeDirection.x, -gazeDirection.z)
        let vertical = atan2(gazeDirection.y, -gazeDirection.z)
        return (horizontal, vertical)
    }

    /// Check if gaze is pointing at a specific region
    func isGazingAt(region: GazeRegion) -> Bool {
        let angles = getGazeAngles()

        switch region {
        case .center:
            return abs(angles.horizontal) < 0.2 && abs(angles.vertical) < 0.2
        case .left:
            return angles.horizontal < -0.3
        case .right:
            return angles.horizontal > 0.3
        case .up:
            return angles.vertical > 0.3
        case .down:
            return angles.vertical < -0.3
        }
    }

    /// Gaze regions for simplified interaction
    enum GazeRegion {
        case center
        case left
        case right
        case up
        case down
    }
}

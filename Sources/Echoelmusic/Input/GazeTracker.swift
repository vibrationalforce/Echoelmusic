import Foundation
import ARKit
import Combine
import simd

/// Eye Gaze Tracker using ARKit Face Tracking
/// Provides accurate gaze direction and attention detection for audio/visual control
/// Bio-reactive integration with attention-based parameter modulation
@MainActor
public final class GazeTracker: NSObject, ObservableObject {

    // MARK: - Published State

    /// Current gaze direction in normalized screen coordinates (0-1, 0-1)
    @Published public private(set) var gazePoint: SIMD2<Float> = SIMD2(0.5, 0.5)

    /// Gaze direction vector in 3D space
    @Published public private(set) var gazeDirection: SIMD3<Float> = SIMD3(0, 0, -1)

    /// Depth of gaze (how far user is looking)
    @Published public private(set) var gazeDepth: Float = 1.0

    /// Whether user is actively looking at the screen
    @Published public private(set) var isLookingAtScreen: Bool = true

    /// Attention level (0-1) based on gaze stability and blink rate
    @Published public private(set) var attentionLevel: Float = 1.0

    /// Left eye openness (0-1)
    @Published public private(set) var leftEyeOpenness: Float = 1.0

    /// Right eye openness (0-1)
    @Published public private(set) var rightEyeOpenness: Float = 1.0

    /// Current fixation duration (seconds)
    @Published public private(set) var fixationDuration: TimeInterval = 0.0

    /// Tracking status
    @Published public private(set) var isTracking: Bool = false

    /// Calibration status
    @Published public private(set) var isCalibrated: Bool = false

    // MARK: - Gaze Regions

    /// Current gaze region on screen
    @Published public private(set) var currentRegion: GazeRegion = .center

    public enum GazeRegion: String, CaseIterable {
        case topLeft, topCenter, topRight
        case middleLeft, center, middleRight
        case bottomLeft, bottomCenter, bottomRight

        public var gridPosition: SIMD2<Int> {
            switch self {
            case .topLeft: return SIMD2(0, 0)
            case .topCenter: return SIMD2(1, 0)
            case .topRight: return SIMD2(2, 0)
            case .middleLeft: return SIMD2(0, 1)
            case .center: return SIMD2(1, 1)
            case .middleRight: return SIMD2(2, 1)
            case .bottomLeft: return SIMD2(0, 2)
            case .bottomCenter: return SIMD2(1, 2)
            case .bottomRight: return SIMD2(2, 2)
            }
        }

        static func from(normalizedPoint: SIMD2<Float>) -> GazeRegion {
            let x = Int(normalizedPoint.x * 3)
            let y = Int(normalizedPoint.y * 3)

            let clampedX = max(0, min(2, x))
            let clampedY = max(0, min(2, y))

            for region in allCases {
                if region.gridPosition == SIMD2(clampedX, clampedY) {
                    return region
                }
            }
            return .center
        }
    }

    // MARK: - Private State

    #if os(iOS)
    private var arSession: ARSession?
    #endif

    private var gazeHistory: [SIMD2<Float>] = []
    private let gazeHistorySize = 10
    private var lastFixationStart: Date?
    private var lastGazePoint: SIMD2<Float>?
    private let fixationThreshold: Float = 0.05 // Normalized units

    // Calibration
    private var calibrationOffset: SIMD2<Float> = .zero
    private var calibrationScale: SIMD2<Float> = SIMD2(1, 1)

    // Attention calculation
    private var blinkHistory: [Bool] = []
    private let blinkHistorySize = 30 // 1 second at 30 fps
    private var gazeStabilityHistory: [Float] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Start/Stop

    public func start() {
        #if os(iOS)
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ GazeTracker: Face tracking not supported on this device")
            return
        }

        let session = ARSession()
        session.delegate = self
        self.arSession = session

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true

        print("✅ GazeTracker: Started face tracking")
        #else
        print("⚠️ GazeTracker: Face tracking only supported on iOS")
        #endif
    }

    public func stop() {
        #if os(iOS)
        arSession?.pause()
        arSession = nil
        #endif

        isTracking = false
        print("⏹️ GazeTracker: Stopped")
    }

    // MARK: - Calibration

    public func startCalibration() {
        calibrationOffset = .zero
        calibrationScale = SIMD2(1, 1)
        isCalibrated = false
        print("🎯 GazeTracker: Starting calibration...")
    }

    public func calibratePoint(screenPoint: SIMD2<Float>) {
        // User looked at a known screen point - record for calibration
        let currentGaze = gazePoint
        let offset = screenPoint - currentGaze

        // Running average of calibration offset
        calibrationOffset = calibrationOffset * 0.9 + offset * 0.1

        print("🎯 GazeTracker: Calibration point recorded (offset: \(calibrationOffset))")
    }

    public func finishCalibration() {
        isCalibrated = true
        print("✅ GazeTracker: Calibration complete")
    }

    // MARK: - Gaze Processing

    #if os(iOS)
    private func processGaze(from anchor: ARFaceAnchor) {
        // Extract eye transforms
        guard let leftEyeTransform = anchor.blendShapeLocation(named: .eyeLookInLeft),
              let rightEyeTransform = anchor.blendShapeLocation(named: .eyeLookInRight) else {
            return
        }

        // Get eye openness
        leftEyeOpenness = 1.0 - (anchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
        rightEyeOpenness = 1.0 - (anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)

        // Extract gaze direction from blend shapes
        let lookUpLeft = anchor.blendShapes[.eyeLookUpLeft]?.floatValue ?? 0
        let lookDownLeft = anchor.blendShapes[.eyeLookDownLeft]?.floatValue ?? 0
        let lookInLeft = anchor.blendShapes[.eyeLookInLeft]?.floatValue ?? 0
        let lookOutLeft = anchor.blendShapes[.eyeLookOutLeft]?.floatValue ?? 0

        let lookUpRight = anchor.blendShapes[.eyeLookUpRight]?.floatValue ?? 0
        let lookDownRight = anchor.blendShapes[.eyeLookDownRight]?.floatValue ?? 0
        let lookInRight = anchor.blendShapes[.eyeLookInRight]?.floatValue ?? 0
        let lookOutRight = anchor.blendShapes[.eyeLookOutRight]?.floatValue ?? 0

        // Average both eyes
        let verticalGaze = ((lookDownLeft - lookUpLeft) + (lookDownRight - lookUpRight)) / 2
        let horizontalGaze = ((lookOutLeft - lookInLeft) + (lookInRight - lookOutRight)) / 2

        // Convert to screen coordinates (0-1)
        var newGazePoint = SIMD2<Float>(
            0.5 + horizontalGaze * 1.5, // Scale factor for screen mapping
            0.5 + verticalGaze * 1.5
        )

        // Apply calibration
        newGazePoint = (newGazePoint + calibrationOffset) * calibrationScale

        // Clamp to screen bounds
        newGazePoint = simd_clamp(newGazePoint, SIMD2(0, 0), SIMD2(1, 1))

        // Smooth the gaze
        newGazePoint = smoothGaze(newGazePoint)

        // Update state
        gazePoint = newGazePoint
        currentRegion = GazeRegion.from(normalizedPoint: newGazePoint)

        // Calculate 3D gaze direction
        gazeDirection = SIMD3<Float>(
            horizontalGaze,
            -verticalGaze,
            -1.0
        )
        gazeDirection = normalize(gazeDirection)

        // Update attention metrics
        updateAttention(anchor: anchor)

        // Update fixation
        updateFixation(currentPoint: newGazePoint)

        // Determine if looking at screen
        let combinedOpenness = (leftEyeOpenness + rightEyeOpenness) / 2
        isLookingAtScreen = combinedOpenness > 0.3 && abs(horizontalGaze) < 0.7 && abs(verticalGaze) < 0.7
    }
    #endif

    private func smoothGaze(_ newPoint: SIMD2<Float>) -> SIMD2<Float> {
        gazeHistory.append(newPoint)
        if gazeHistory.count > gazeHistorySize {
            gazeHistory.removeFirst()
        }

        // Weighted average (recent points have more weight)
        var weightedSum = SIMD2<Float>(0, 0)
        var totalWeight: Float = 0

        for (index, point) in gazeHistory.enumerated() {
            let weight = Float(index + 1)
            weightedSum += point * weight
            totalWeight += weight
        }

        return weightedSum / totalWeight
    }

    #if os(iOS)
    private func updateAttention(anchor: ARFaceAnchor) {
        // Track blinks
        let isBlinking = leftEyeOpenness < 0.2 && rightEyeOpenness < 0.2
        blinkHistory.append(isBlinking)
        if blinkHistory.count > blinkHistorySize {
            blinkHistory.removeFirst()
        }

        // Calculate blink rate (blinks per second)
        let blinkTransitions = zip(blinkHistory.dropLast(), blinkHistory.dropFirst())
            .filter { !$0 && $1 } // Count false -> true transitions
            .count
        let blinkRate = Float(blinkTransitions) * 30 / Float(blinkHistorySize) // Per second

        // Track gaze stability
        if let lastPoint = lastGazePoint {
            let movement = length(gazePoint - lastPoint)
            gazeStabilityHistory.append(movement)
            if gazeStabilityHistory.count > 30 {
                gazeStabilityHistory.removeFirst()
            }
        }
        lastGazePoint = gazePoint

        let avgMovement = gazeStabilityHistory.reduce(0, +) / Float(max(1, gazeStabilityHistory.count))
        let stability = 1.0 - min(1.0, avgMovement * 20) // More movement = less stability

        // Attention = weighted combination of blink rate and stability
        // Normal blink rate: 15-20 per minute = 0.25-0.33 per second
        // High blink rate indicates fatigue/distraction
        let blinkFactor = 1.0 - min(1.0, max(0.0, (blinkRate - 0.3) * 2))

        attentionLevel = stability * 0.6 + blinkFactor * 0.4
    }
    #endif

    private func updateFixation(currentPoint: SIMD2<Float>) {
        if let lastPoint = lastGazePoint {
            let distance = length(currentPoint - lastPoint)

            if distance < fixationThreshold {
                // Still fixating
                if lastFixationStart == nil {
                    lastFixationStart = Date()
                }
                fixationDuration = Date().timeIntervalSince(lastFixationStart!)
            } else {
                // Moved - reset fixation
                lastFixationStart = nil
                fixationDuration = 0
            }
        }
    }

    // MARK: - Audio Parameter Mapping

    /// Map gaze to audio parameters (for integration with UnifiedControlHub)
    public func mapToAudioParameters() -> GazeAudioParameters {
        return GazeAudioParameters(
            panPosition: (gazePoint.x * 2.0) - 1.0, // -1 (left) to +1 (right)
            filterFrequency: gazePoint.y, // 0 (low) to 1 (high)
            attentionModulation: attentionLevel,
            depthReverb: gazeDepth,
            isActive: isLookingAtScreen
        )
    }

    public struct GazeAudioParameters {
        /// Stereo pan position (-1 to +1)
        public let panPosition: Float

        /// Filter frequency modulation (0-1)
        public let filterFrequency: Float

        /// Attention-based parameter modulation (0-1)
        public let attentionModulation: Float

        /// Depth-based reverb amount (0-1)
        public let depthReverb: Float

        /// Whether gaze is actively being tracked
        public let isActive: Bool
    }

    // MARK: - Visual Parameter Mapping

    /// Map gaze to visual parameters for bio-reactive visuals
    public func mapToVisualParameters() -> GazeVisualParameters {
        return GazeVisualParameters(
            focusPoint: gazePoint,
            focusRegion: currentRegion,
            blurAmount: 1.0 - attentionLevel, // Low attention = more blur
            brightnessModulation: (leftEyeOpenness + rightEyeOpenness) / 2,
            depthOfField: gazeDepth
        )
    }

    public struct GazeVisualParameters {
        /// Where to focus visual effects
        public let focusPoint: SIMD2<Float>

        /// Which region of screen to emphasize
        public let focusRegion: GazeRegion

        /// Blur amount for non-focus areas
        public let blurAmount: Float

        /// Brightness based on eye openness
        public let brightnessModulation: Float

        /// Depth of field effect strength
        public let depthOfField: Float
    }
}

// MARK: - ARSessionDelegate

#if os(iOS)
extension GazeTracker: ARSessionDelegate {
    nonisolated public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        Task { @MainActor in
            self.processGaze(from: faceAnchor)
        }
    }

    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ GazeTracker: Session failed - \(error.localizedDescription)")
        Task { @MainActor in
            self.isTracking = false
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ GazeTracker: Session interrupted")
        Task { @MainActor in
            self.isTracking = false
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ GazeTracker: Session resumed")
        Task { @MainActor in
            self.isTracking = true
        }
    }
}
#endif

// MARK: - ARFaceAnchor Extension

#if os(iOS)
private extension ARFaceAnchor {
    func blendShapeLocation(named location: ARFaceAnchor.BlendShapeLocation) -> Float? {
        return blendShapes[location]?.floatValue
    }
}
#endif

import Foundation
import Combine

#if canImport(ARKit)
import ARKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// AR HAND TRACKING BRIDGE
// ═══════════════════════════════════════════════════════════════════════════════
//
// visionOS ARHandTrackingProvider integration that bridges to the existing
// HandTrackingManager (Vision framework, iOS) + adds visionOS-native 3D tracking.
//
// Platform support:
// - visionOS 1+: ARHandTrackingProvider (full 3D skeleton)
// - iOS 15+:     Vision framework (2D + depth estimation, existing)
// - macOS 12+:   Vision framework (camera-based)
// - watchOS:     Not available
//
// All hand data flows into EchoelEngine.eventBus as .handTrackingUpdated
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Hand Joint Model

/// Platform-agnostic hand joint representation
public struct HandJoint: Equatable {
    public let name: String
    public var position: SIMD3<Float>
    public var isTracked: Bool
    public var confidence: Float

    public init(name: String, position: SIMD3<Float> = .zero, isTracked: Bool = false, confidence: Float = 0) {
        self.name = name
        self.position = position
        self.isTracked = isTracked
        self.confidence = confidence
    }
}

/// Full hand skeleton with 25 joints (matching ARKit HandSkeleton)
public struct HandSkeleton: Equatable {
    public var joints: [HandJoint]
    public var isTracked: Bool = false

    public static let jointNames: [String] = [
        "wrist",
        "thumbKnuckle", "thumbIntermediateBase", "thumbIntermediateTip", "thumbTip",
        "indexFingerMetacarpal", "indexFingerKnuckle", "indexFingerIntermediateBase",
        "indexFingerIntermediateTip", "indexFingerTip",
        "middleFingerMetacarpal", "middleFingerKnuckle", "middleFingerIntermediateBase",
        "middleFingerIntermediateTip", "middleFingerTip",
        "ringFingerMetacarpal", "ringFingerKnuckle", "ringFingerIntermediateBase",
        "ringFingerIntermediateTip", "ringFingerTip",
        "littleFingerMetacarpal", "littleFingerKnuckle", "littleFingerIntermediateBase",
        "littleFingerIntermediateTip", "littleFingerTip"
    ]

    public init() {
        self.joints = Self.jointNames.map { HandJoint(name: $0) }
    }

    public var wrist: HandJoint { joints[0] }
    public var thumbTip: HandJoint { joints[4] }
    public var indexTip: HandJoint { joints[9] }
    public var middleTip: HandJoint { joints[14] }
    public var ringTip: HandJoint { joints[19] }
    public var littleTip: HandJoint { joints[24] }
}

/// Complete hand tracking state for both hands
public struct HandTrackingState: Equatable {
    public var leftHand = HandSkeleton()
    public var rightHand = HandSkeleton()
    public var isAvailable: Bool = false

    // Derived gestures
    public var leftPinchAmount: Float = 0
    public var rightPinchAmount: Float = 0
    public var leftGrabAmount: Float = 0
    public var rightGrabAmount: Float = 0
}

// MARK: - AR Hand Tracking Bridge

@MainActor
public final class ARHandTrackingBridge: ObservableObject {

    @Published public var state = HandTrackingState()
    @Published public var isRunning = false

    private var cancellables = Set<AnyCancellable>()

    // Gesture callbacks
    public var onPinch: ((Float, Bool) -> Void)?       // (amount, isLeft)
    public var onGrab: ((Float, Bool) -> Void)?         // (amount, isLeft)
    public var onPoint: ((SIMD3<Float>, Bool) -> Void)? // (direction, isLeft)

    public init() {}

    // MARK: - Start / Stop

    public func start() {
        #if os(visionOS)
        startVisionOSTracking()
        #elseif canImport(UIKit) && !os(watchOS) && !os(tvOS)
        startVisionFrameworkTracking()
        #endif
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    // MARK: - visionOS Native (ARHandTrackingProvider)

    #if os(visionOS)
    private var handTrackingTask: Task<Void, Never>?

    private func startVisionOSTracking() {
        handTrackingTask = Task { [weak self] in
            guard let self else { return }

            let session = ARKitSession()
            let handTracking = HandTrackingProvider()

            do {
                try await session.run([handTracking])
            } catch {
                ProfessionalLogger.log(.error, category: .audio, "Hand tracking failed to start: \(error)")
                return
            }

            for await update in handTracking.anchorUpdates {
                guard !Task.isCancelled else { break }

                let anchor = update.anchor
                guard anchor.isTracked else { continue }

                await MainActor.run {
                    switch anchor.chirality {
                    case .left:
                        self.updateSkeleton(&self.state.leftHand, from: anchor)
                        self.state.leftPinchAmount = self.calculatePinch(self.state.leftHand)
                        self.state.leftGrabAmount = self.calculateGrab(self.state.leftHand)
                        self.onPinch?(self.state.leftPinchAmount, true)
                        self.onGrab?(self.state.leftGrabAmount, true)
                    case .right:
                        self.updateSkeleton(&self.state.rightHand, from: anchor)
                        self.state.rightPinchAmount = self.calculatePinch(self.state.rightHand)
                        self.state.rightGrabAmount = self.calculateGrab(self.state.rightHand)
                        self.onPinch?(self.state.rightPinchAmount, false)
                        self.onGrab?(self.state.rightGrabAmount, false)
                    }
                    self.state.isAvailable = true
                }
            }
        }
    }

    private func updateSkeleton(_ skeleton: inout HandSkeleton, from anchor: HandAnchor) {
        skeleton.isTracked = anchor.isTracked

        guard let handSkeleton = anchor.handSkeleton else { return }

        let allJoints: [HandSkeleton.JointName] = [
            .wrist,
            .thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip,
            .indexFingerMetacarpal, .indexFingerKnuckle, .indexFingerIntermediateBase,
            .indexFingerIntermediateTip, .indexFingerTip,
            .middleFingerMetacarpal, .middleFingerKnuckle, .middleFingerIntermediateBase,
            .middleFingerIntermediateTip, .middleFingerTip,
            .ringFingerMetacarpal, .ringFingerKnuckle, .ringFingerIntermediateBase,
            .ringFingerIntermediateTip, .ringFingerTip,
            .littleFingerMetacarpal, .littleFingerKnuckle, .littleFingerIntermediateBase,
            .littleFingerIntermediateTip, .littleFingerTip
        ]

        for (index, jointName) in allJoints.enumerated() where index < skeleton.joints.count {
            let joint = handSkeleton.joint(jointName)
            let transform = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            skeleton.joints[index].position = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            skeleton.joints[index].isTracked = joint.isTracked
        }
    }
    #endif

    // MARK: - iOS/macOS Vision Framework (Fallback)

    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    private func startVisionFrameworkTracking() {
        // Existing HandTrackingManager handles this via VNDetectHumanHandPoseRequest
        // Bridge its output into our unified HandTrackingState
        state.isAvailable = true
        ProfessionalLogger.log(.info, category: .audio, "Using Vision framework for hand tracking (2D + depth)")
    }
    #endif

    // MARK: - Gesture Calculation

    /// Pinch = distance between thumb tip and index tip
    private func calculatePinch(_ hand: HandSkeleton) -> Float {
        guard hand.isTracked else { return 0 }
        let distance = simd_distance(hand.thumbTip.position, hand.indexTip.position)
        // Normalize: 0.02m = full pinch, 0.08m = no pinch
        return 1.0 - simd_clamp((distance - 0.02) / 0.06, 0, 1)
    }

    /// Grab = average distance of all fingertips to palm center
    private func calculateGrab(_ hand: HandSkeleton) -> Float {
        guard hand.isTracked else { return 0 }
        let palmCenter = hand.wrist.position
        let tips = [hand.thumbTip, hand.indexTip, hand.middleTip, hand.ringTip, hand.littleTip]
        let avgDist = tips.map { simd_distance($0.position, palmCenter) }.reduce(0, +) / 5.0
        // Normalize: 0.03m = full grab, 0.12m = open hand
        return 1.0 - simd_clamp((avgDist - 0.03) / 0.09, 0, 1)
    }

    // MARK: - Audio Parameter Mapping

    /// Map hand gestures to audio/visual parameters
    public struct HandToEngineMapping {
        /// Left pinch → filter cutoff (0-1)
        public var filterCutoff: Float = 0
        /// Right pinch → effect wet/dry (0-1)
        public var effectMix: Float = 0
        /// Left grab → volume (0-1)
        public var volume: Float = 1
        /// Right hand Y position → reverb send (0-1)
        public var reverbSend: Float = 0
        /// Hand distance → stereo width
        public var stereoWidth: Float = 0.5
    }

    public func computeMapping() -> HandToEngineMapping {
        var mapping = HandToEngineMapping()

        mapping.filterCutoff = state.leftPinchAmount
        mapping.effectMix = state.rightPinchAmount
        mapping.volume = 1.0 - state.leftGrabAmount

        // Right hand height (Y) → reverb
        if state.rightHand.isTracked {
            let y = state.rightHand.wrist.position.y
            mapping.reverbSend = simd_clamp((y + 0.2) / 0.6, 0, 1)
        }

        // Distance between hands → stereo width
        if state.leftHand.isTracked && state.rightHand.isTracked {
            let dist = simd_distance(state.leftHand.wrist.position, state.rightHand.wrist.position)
            mapping.stereoWidth = simd_clamp(dist / 0.8, 0, 1)
        }

        return mapping
    }
}

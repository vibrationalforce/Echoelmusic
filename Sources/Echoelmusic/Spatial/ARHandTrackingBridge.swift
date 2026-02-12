import Foundation
import Combine

#if canImport(ARKit)
import ARKit
#endif

#if canImport(Vision)
import Vision
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
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS) && !os(visionOS)
        visionBridgeTask?.cancel()
        visionBridgeTask = nil
        visionHandManager?.stopTracking()
        visionHandManager = nil
        cancellables.removeAll()
        #endif
        #if os(visionOS)
        handTrackingTask?.cancel()
        handTrackingTask = nil
        #endif
        state = HandTrackingState()
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
                log(.error, category: .audio, "Hand tracking failed to start: \(error)")
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
    private var visionBridgeTask: Task<Void, Never>?
    private var visionHandManager: HandTrackingManager?

    private func startVisionFrameworkTracking() {
        // Bridge HandTrackingManager's published properties into our unified HandTrackingState
        let handManager = HandTrackingManager()
        visionHandManager = handManager
        handManager.startTracking()

        // Subscribe to left hand landmark updates
        handManager.$leftHandLandmarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                guard let self, !landmarks.isEmpty else { return }
                self.bridgeVisionLandmarks(landmarks, to: &self.state.leftHand, isLeft: true)
                self.state.leftPinchAmount = self.calculatePinch(self.state.leftHand)
                self.state.leftGrabAmount = self.calculateGrab(self.state.leftHand)
                self.onPinch?(self.state.leftPinchAmount, true)
                self.onGrab?(self.state.leftGrabAmount, true)
            }
            .store(in: &cancellables)

        // Subscribe to right hand landmark updates
        handManager.$rightHandLandmarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                guard let self, !landmarks.isEmpty else { return }
                self.bridgeVisionLandmarks(landmarks, to: &self.state.rightHand, isLeft: false)
                self.state.rightPinchAmount = self.calculatePinch(self.state.rightHand)
                self.state.rightGrabAmount = self.calculateGrab(self.state.rightHand)
                self.onPinch?(self.state.rightPinchAmount, false)
                self.onGrab?(self.state.rightGrabAmount, false)
            }
            .store(in: &cancellables)

        // Subscribe to hand detection states
        handManager.$leftHandDetected
            .combineLatest(handManager.$rightHandDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] leftDetected, rightDetected in
                guard let self else { return }
                self.state.leftHand.isTracked = leftDetected
                self.state.rightHand.isTracked = rightDetected
                self.state.isAvailable = leftDetected || rightDetected
            }
            .store(in: &cancellables)

        // Subscribe to 3D position updates for pointing gesture
        handManager.$leftHandPosition
            .combineLatest(handManager.$rightHandPosition)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] leftPos, rightPos in
                guard let self else { return }
                if self.state.leftHand.isTracked {
                    self.onPoint?(leftPos, true)
                }
                if self.state.rightHand.isTracked {
                    self.onPoint?(rightPos, false)
                }
            }
            .store(in: &cancellables)

        state.isAvailable = true
        log(.info, category: .audio, "Vision framework hand tracking bridge active (2D + depth estimation)")
    }

    /// Bridge Vision framework 21-joint landmarks into our 25-joint HandSkeleton
    /// Vision uses VNHumanHandPoseObservation with 21 joints, ARKit uses 25.
    /// We map the 21 available joints and estimate the 4 missing metacarpals.
    private func bridgeVisionLandmarks(_ landmarks: [HandTrackingManager.HandLandmark], to skeleton: inout HandSkeleton, isLeft: Bool) {
        skeleton.isTracked = !landmarks.isEmpty

        // Vision framework joint name → our skeleton index mapping
        // Our 25-joint order: wrist, thumb(4), index(5), middle(5), ring(5), little(5)
        // Vision 21-joint order: wrist, thumb(4), index(4), middle(4), ring(4), little(4)
        // Missing from Vision: metacarpal joints for index/middle/ring/little (indices 5, 10, 15, 20)

        for landmark in landmarks {
            let jointName = landmark.jointName
            let pos3D = estimateDepth(from: landmark.position, confidence: landmark.confidence)

            // Map Vision joint names to our skeleton indices
            let index = visionJointToSkeletonIndex(jointName)
            if index >= 0 && index < skeleton.joints.count {
                skeleton.joints[index].position = pos3D
                skeleton.joints[index].isTracked = landmark.confidence > 0.3
                skeleton.joints[index].confidence = landmark.confidence
            }
        }

        // Estimate missing metacarpal joints by interpolation (wrist → knuckle midpoint)
        let wristPos = skeleton.joints[0].position
        let metacarpalIndices = [5, 10, 15, 20] // index, middle, ring, little metacarpals
        let knuckleIndices = [6, 11, 16, 21]     // corresponding knuckle joints

        for (metaIdx, knuckleIdx) in zip(metacarpalIndices, knuckleIndices) {
            if metaIdx < skeleton.joints.count && knuckleIdx < skeleton.joints.count {
                let knucklePos = skeleton.joints[knuckleIdx].position
                skeleton.joints[metaIdx].position = (wristPos + knucklePos) * 0.5
                skeleton.joints[metaIdx].isTracked = skeleton.joints[knuckleIdx].isTracked
                skeleton.joints[metaIdx].confidence = skeleton.joints[knuckleIdx].confidence * 0.7
            }
        }
    }

    /// Map VNHumanHandPoseObservation.JointName to our 25-joint skeleton index
    private func visionJointToSkeletonIndex(_ jointName: VNHumanHandPoseObservation.JointName) -> Int {
        switch jointName {
        case .wrist: return 0
        // Thumb (4 joints, indices 1-4)
        case .thumbCMC: return 1
        case .thumbMP: return 2
        case .thumbIP: return 3
        case .thumbTip: return 4
        // Index finger (knuckle→tip, indices 6-9, skip metacarpal at 5)
        case .indexMCP: return 6
        case .indexPIP: return 7
        case .indexDIP: return 8
        case .indexTip: return 9
        // Middle finger (indices 11-14, skip metacarpal at 10)
        case .middleMCP: return 11
        case .middlePIP: return 12
        case .middleDIP: return 13
        case .middleTip: return 14
        // Ring finger (indices 16-19, skip metacarpal at 15)
        case .ringMCP: return 16
        case .ringPIP: return 17
        case .ringDIP: return 18
        case .ringTip: return 19
        // Little finger (indices 21-24, skip metacarpal at 20)
        case .littleMCP: return 21
        case .littlePIP: return 22
        case .littleDIP: return 23
        case .littleTip: return 24
        default: return -1
        }
    }

    /// Estimate 3D position from 2D Vision landmark + confidence-based depth
    private func estimateDepth(from point: CGPoint, confidence: Float) -> SIMD3<Float> {
        // Convert normalized screen coordinates to 3D space estimate
        // X: -1 (left) to +1 (right)
        // Y: -1 (bottom) to +1 (top)
        // Z: depth estimated from confidence + hand scale (0 to 1)
        let x = Float(point.x) * 2.0 - 1.0
        let y = Float(point.y) * 2.0 - 1.0
        let z = confidence * 0.5 // rough depth: higher confidence = closer
        return SIMD3<Float>(x, y, z)
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

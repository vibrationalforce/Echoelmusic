import Foundation
import simd
import Accelerate

// MARK: - Gesture & Mimic Controller
// Touch, gesture, and facial expression to audio mapping
// For spatial multimedia production with embodied interaction

/// GestureMimicController: Maps physical gestures and facial expressions to audio parameters
/// Enables intuitive, embodied control of sound through movement and expression
///
/// Input modalities:
/// - Multi-touch gestures (iOS/iPadOS)
/// - Device motion (accelerometer, gyroscope)
/// - Facial expressions (ARKit)
/// - Hand tracking (visionOS)
/// - Body pose (Vision framework)
public final class GestureMimicController {

    // MARK: - Touch Gesture Types

    /// Multi-touch gesture state
    public struct TouchState {
        public var touches: [Touch] = []
        public var gestureType: GestureType = .none
        public var centroid: SIMD2<Float> = .zero
        public var spread: Float = 0              // Distance between touches
        public var rotation: Float = 0            // Two-finger rotation
        public var velocity: SIMD2<Float> = .zero
        public var pressure: Float = 0            // Average pressure (if available)

        public struct Touch {
            public var id: Int
            public var position: SIMD2<Float>     // Normalized 0-1
            public var pressure: Float            // 0-1
            public var radius: Float              // Touch radius
            public var velocity: SIMD2<Float>
            public var phase: TouchPhase

            public enum TouchPhase {
                case began, moved, stationary, ended, cancelled
            }
        }

        public enum GestureType: String {
            case none = "None"
            case tap = "Tap"
            case doubleTap = "Double Tap"
            case longPress = "Long Press"
            case pan = "Pan"
            case pinch = "Pinch"
            case rotate = "Rotate"
            case swipe = "Swipe"
            case multiTouch = "Multi-Touch"
        }

        public init() {}
    }

    /// Device motion state
    public struct MotionState {
        // Attitude (rotation)
        public var pitch: Float = 0      // Rotation around X (-π to π)
        public var roll: Float = 0       // Rotation around Y (-π to π)
        public var yaw: Float = 0        // Rotation around Z (-π to π)

        // Acceleration (gravity removed)
        public var userAcceleration: SIMD3<Float> = .zero

        // Gravity vector
        public var gravity: SIMD3<Float> = SIMD3(0, -1, 0)

        // Rotation rate
        public var rotationRate: SIMD3<Float> = .zero

        // Derived
        public var tilt: Float = 0       // Overall tilt amount
        public var shake: Float = 0      // Shake intensity
        public var isStable: Bool = true

        public init() {}
    }

    // MARK: - Facial Expression Types

    /// Facial expression state (ARKit blendshapes mapping)
    public struct FacialState {
        // Brows
        public var browInnerUp: Float = 0
        public var browDownLeft: Float = 0
        public var browDownRight: Float = 0
        public var browOuterUpLeft: Float = 0
        public var browOuterUpRight: Float = 0

        // Eyes
        public var eyeBlinkLeft: Float = 0
        public var eyeBlinkRight: Float = 0
        public var eyeLookDownLeft: Float = 0
        public var eyeLookDownRight: Float = 0
        public var eyeLookInLeft: Float = 0
        public var eyeLookInRight: Float = 0
        public var eyeLookOutLeft: Float = 0
        public var eyeLookOutRight: Float = 0
        public var eyeLookUpLeft: Float = 0
        public var eyeLookUpRight: Float = 0
        public var eyeSquintLeft: Float = 0
        public var eyeSquintRight: Float = 0
        public var eyeWideLeft: Float = 0
        public var eyeWideRight: Float = 0

        // Mouth
        public var mouthSmileLeft: Float = 0
        public var mouthSmileRight: Float = 0
        public var mouthFrownLeft: Float = 0
        public var mouthFrownRight: Float = 0
        public var mouthOpen: Float = 0
        public var mouthPucker: Float = 0
        public var mouthLeft: Float = 0
        public var mouthRight: Float = 0
        public var jawOpen: Float = 0
        public var jawLeft: Float = 0
        public var jawRight: Float = 0

        // Cheeks
        public var cheekPuff: Float = 0
        public var cheekSquintLeft: Float = 0
        public var cheekSquintRight: Float = 0

        // Nose
        public var noseSneerLeft: Float = 0
        public var noseSneerRight: Float = 0

        // Tongue
        public var tongueOut: Float = 0

        // Derived expressions
        public var happiness: Float = 0
        public var sadness: Float = 0
        public var surprise: Float = 0
        public var anger: Float = 0
        public var fear: Float = 0
        public var disgust: Float = 0
        public var neutral: Float = 1

        public init() {}

        /// Calculate derived emotions from blendshapes
        public mutating func calculateDerivedEmotions() {
            // Happiness: smiling
            happiness = (mouthSmileLeft + mouthSmileRight) / 2

            // Sadness: frown + inner brow up
            sadness = ((mouthFrownLeft + mouthFrownRight) / 2 + browInnerUp) / 2

            // Surprise: eye wide + brow up + jaw open
            let browUp = (browOuterUpLeft + browOuterUpRight + browInnerUp) / 3
            let eyeWide = (eyeWideLeft + eyeWideRight) / 2
            surprise = (browUp + eyeWide + jawOpen) / 3

            // Anger: brow down + mouth tension
            let browDown = (browDownLeft + browDownRight) / 2
            anger = (browDown + (mouthLeft + mouthRight) / 2) / 2

            // Fear: brow up + eye wide + mouth open
            fear = (browInnerUp + eyeWide * 0.5 + mouthOpen * 0.5) / 2

            // Disgust: nose sneer + upper lip raise
            disgust = (noseSneerLeft + noseSneerRight) / 2

            // Neutral: inverse of other emotions
            let emotionSum = happiness + sadness + surprise + anger + fear + disgust
            neutral = max(0, 1 - emotionSum)
        }
    }

    // MARK: - Hand Tracking (visionOS)

    /// Hand tracking state
    public struct HandState {
        public var isTracked: Bool = false
        public var handedness: Handedness = .unknown

        // Joint positions (normalized)
        public var wrist: SIMD3<Float> = .zero
        public var thumbTip: SIMD3<Float> = .zero
        public var indexTip: SIMD3<Float> = .zero
        public var middleTip: SIMD3<Float> = .zero
        public var ringTip: SIMD3<Float> = .zero
        public var pinkyTip: SIMD3<Float> = .zero

        // Derived gestures
        public var pinchStrength: Float = 0      // Thumb to index distance
        public var grabStrength: Float = 0       // All fingers curled
        public var pointDirection: SIMD3<Float> = .zero
        public var palmNormal: SIMD3<Float> = .zero
        public var isPointing: Bool = false
        public var isGrabbing: Bool = false
        public var isPinching: Bool = false
        public var isOpen: Bool = true

        public enum Handedness {
            case left, right, unknown
        }

        public init() {}

        /// Calculate derived gestures
        public mutating func calculateGestures() {
            guard isTracked else { return }

            // Pinch: distance between thumb and index
            let thumbIndexDist = simd_length(thumbTip - indexTip)
            pinchStrength = max(0, 1 - thumbIndexDist * 10)
            isPinching = pinchStrength > 0.7

            // Grab: all fingertips close to palm
            let avgFingerDist = (
                simd_length(indexTip - wrist) +
                simd_length(middleTip - wrist) +
                simd_length(ringTip - wrist) +
                simd_length(pinkyTip - wrist)
            ) / 4
            grabStrength = max(0, 1 - avgFingerDist * 5)
            isGrabbing = grabStrength > 0.6

            // Pointing: index extended, others curled
            let indexExtended = simd_length(indexTip - wrist) > 0.15
            let othersCurled = grabStrength > 0.3
            isPointing = indexExtended && !isPinching

            // Open hand
            isOpen = grabStrength < 0.3 && !isPinching

            // Point direction
            if isPointing {
                pointDirection = simd_normalize(indexTip - wrist)
            }
        }
    }

    // MARK: - Body Pose

    /// Body pose state (simplified)
    public struct BodyPoseState {
        public var isTracked: Bool = false

        // Key points (normalized screen coordinates or 3D)
        public var head: SIMD3<Float> = .zero
        public var neck: SIMD3<Float> = .zero
        public var leftShoulder: SIMD3<Float> = .zero
        public var rightShoulder: SIMD3<Float> = .zero
        public var leftElbow: SIMD3<Float> = .zero
        public var rightElbow: SIMD3<Float> = .zero
        public var leftWrist: SIMD3<Float> = .zero
        public var rightWrist: SIMD3<Float> = .zero
        public var leftHip: SIMD3<Float> = .zero
        public var rightHip: SIMD3<Float> = .zero

        // Derived
        public var armSpread: Float = 0          // Distance between wrists
        public var armHeight: Float = 0          // Average arm Y position
        public var bodyTilt: Float = 0           // Lean left/right
        public var isArmsUp: Bool = false
        public var isArmsWide: Bool = false
        public var isCrouching: Bool = false

        public init() {}

        /// Calculate derived poses
        public mutating func calculateDerived() {
            guard isTracked else { return }

            // Arm spread
            armSpread = simd_length(leftWrist - rightWrist)
            isArmsWide = armSpread > 0.6

            // Arm height (relative to shoulders)
            let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
            armHeight = ((leftWrist.y + rightWrist.y) / 2 - shoulderY)
            isArmsUp = armHeight > 0.2

            // Body tilt
            let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2
            let hipMidX = (leftHip.x + rightHip.x) / 2
            bodyTilt = shoulderMidX - hipMidX

            // Crouching
            let hipY = (leftHip.y + rightHip.y) / 2
            isCrouching = hipY > 0.6
        }
    }

    // MARK: - Audio Mapping

    /// Mapping configuration from gestures to audio parameters
    public struct GestureAudioMapping {
        // Touch mappings
        public var touchXToParameter: AudioParameter = .pan
        public var touchYToParameter: AudioParameter = .filter
        public var pressureToParameter: AudioParameter = .volume
        public var spreadToParameter: AudioParameter = .reverb
        public var rotationToParameter: AudioParameter = .detune

        // Motion mappings
        public var pitchToParameter: AudioParameter = .pitch
        public var rollToParameter: AudioParameter = .pan
        public var yawToParameter: AudioParameter = .filter
        public var shakeToParameter: AudioParameter = .distortion

        // Facial mappings
        public var mouthOpenToParameter: AudioParameter = .filter
        public var smileToParameter: AudioParameter = .brightness
        public var browToParameter: AudioParameter = .pitch
        public var eyeBlinkToTrigger: AudioTrigger = .noteOff

        // Hand mappings
        public var pinchToParameter: AudioParameter = .volume
        public var grabToParameter: AudioParameter = .distortion
        public var handHeightToParameter: AudioParameter = .pitch
        public var handXToParameter: AudioParameter = .pan

        // Body mappings
        public var armSpreadToParameter: AudioParameter = .stereoWidth
        public var armHeightToParameter: AudioParameter = .filter
        public var bodyTiltToParameter: AudioParameter = .pan

        public init() {}
    }

    /// Audio parameters that can be controlled
    public enum AudioParameter: String, CaseIterable {
        case volume = "Volume"
        case pan = "Pan"
        case pitch = "Pitch"
        case filter = "Filter Cutoff"
        case resonance = "Resonance"
        case reverb = "Reverb"
        case delay = "Delay"
        case distortion = "Distortion"
        case detune = "Detune"
        case brightness = "Brightness"
        case stereoWidth = "Stereo Width"
        case modulation = "Modulation"
        case attack = "Attack"
        case release = "Release"
        case tempo = "Tempo"
        case density = "Grain Density"
        case position = "Position"
        case morphX = "Morph X"
        case morphY = "Morph Y"
    }

    /// Audio triggers (discrete events)
    public enum AudioTrigger: String, CaseIterable {
        case noteOn = "Note On"
        case noteOff = "Note Off"
        case effectToggle = "Effect Toggle"
        case sampleTrigger = "Sample Trigger"
        case patternNext = "Next Pattern"
        case patternPrev = "Previous Pattern"
        case freeze = "Freeze"
        case reset = "Reset"
    }

    // MARK: - Properties

    /// Current touch state
    public var touchState = TouchState()

    /// Current motion state
    public var motionState = MotionState()

    /// Current facial state
    public var facialState = FacialState()

    /// Left hand state
    public var leftHandState = HandState()

    /// Right hand state
    public var rightHandState = HandState()

    /// Body pose state
    public var bodyPoseState = BodyPoseState()

    /// Gesture-to-audio mapping
    public var mapping = GestureAudioMapping()

    /// Smoothing factor for parameter changes (0-1)
    public var smoothing: Float = 0.2

    /// Sensitivity multiplier
    public var sensitivity: Float = 1.0

    /// Dead zone for small movements
    public var deadZone: Float = 0.05

    /// Current output parameters
    private var outputParameters: [AudioParameter: Float] = [:]

    /// Pending triggers
    private var pendingTriggers: [AudioTrigger] = []

    /// Previous states for change detection
    private var previousTouchState = TouchState()
    private var previousFacialState = FacialState()

    // MARK: - Initialization

    public init() {
        // Initialize all parameters to default
        for param in AudioParameter.allCases {
            outputParameters[param] = 0.5
        }
    }

    // MARK: - State Updates

    /// Update touch state
    public func updateTouch(_ state: TouchState) {
        previousTouchState = touchState
        touchState = state
        processTouch()
    }

    /// Update motion state
    public func updateMotion(_ state: MotionState) {
        motionState = state
        processMotion()
    }

    /// Update facial state
    public func updateFacial(_ state: FacialState) {
        previousFacialState = facialState
        facialState = state
        facialState.calculateDerivedEmotions()
        processFacial()
    }

    /// Update hand states
    public func updateHands(left: HandState?, right: HandState?) {
        if var left = left {
            left.calculateGestures()
            leftHandState = left
        }
        if var right = right {
            right.calculateGestures()
            rightHandState = right
        }
        processHands()
    }

    /// Update body pose
    public func updateBodyPose(_ state: BodyPoseState) {
        bodyPoseState = state
        bodyPoseState.calculateDerived()
        processBodyPose()
    }

    // MARK: - Processing

    /// Process touch gestures
    private func processTouch() {
        guard !touchState.touches.isEmpty else { return }

        // X position → mapped parameter
        let x = touchState.centroid.x
        updateParameter(mapping.touchXToParameter, value: x)

        // Y position → mapped parameter (invert for intuitive feel)
        let y = 1 - touchState.centroid.y
        updateParameter(mapping.touchYToParameter, value: y)

        // Pressure
        if touchState.pressure > 0 {
            updateParameter(mapping.pressureToParameter, value: touchState.pressure)
        }

        // Spread (pinch gesture)
        let normalizedSpread = min(1, touchState.spread / 500)
        updateParameter(mapping.spreadToParameter, value: normalizedSpread)

        // Rotation
        let normalizedRotation = (touchState.rotation / .pi + 1) / 2
        updateParameter(mapping.rotationToParameter, value: normalizedRotation)

        // Gesture triggers
        switch touchState.gestureType {
        case .tap:
            pendingTriggers.append(.noteOn)
        case .doubleTap:
            pendingTriggers.append(.effectToggle)
        case .longPress:
            pendingTriggers.append(.freeze)
        case .swipe:
            if touchState.velocity.x > 0 {
                pendingTriggers.append(.patternNext)
            } else {
                pendingTriggers.append(.patternPrev)
            }
        default:
            break
        }
    }

    /// Process device motion
    private func processMotion() {
        // Pitch (tilt forward/back)
        let pitchNorm = (motionState.pitch / .pi + 1) / 2
        updateParameter(mapping.pitchToParameter, value: pitchNorm)

        // Roll (tilt left/right)
        let rollNorm = (motionState.roll / .pi + 1) / 2
        updateParameter(mapping.rollToParameter, value: rollNorm)

        // Yaw (rotation)
        let yawNorm = (motionState.yaw / .pi + 1) / 2
        updateParameter(mapping.yawToParameter, value: yawNorm)

        // Shake
        if motionState.shake > deadZone {
            updateParameter(mapping.shakeToParameter, value: min(1, motionState.shake * sensitivity))
        }
    }

    /// Process facial expressions
    private func processFacial() {
        // Mouth open → filter
        updateParameter(mapping.mouthOpenToParameter, value: facialState.mouthOpen)

        // Smile → brightness
        let smile = (facialState.mouthSmileLeft + facialState.mouthSmileRight) / 2
        updateParameter(mapping.smileToParameter, value: smile)

        // Brow → pitch
        let browUp = (facialState.browOuterUpLeft + facialState.browOuterUpRight + facialState.browInnerUp) / 3
        let browDown = (facialState.browDownLeft + facialState.browDownRight) / 2
        let browValue = 0.5 + (browUp - browDown) * 0.5
        updateParameter(mapping.browToParameter, value: browValue)

        // Blink trigger
        let blinkThreshold: Float = 0.7
        let wasBlinking = (previousFacialState.eyeBlinkLeft + previousFacialState.eyeBlinkRight) / 2 > blinkThreshold
        let isBlinking = (facialState.eyeBlinkLeft + facialState.eyeBlinkRight) / 2 > blinkThreshold

        if isBlinking && !wasBlinking {
            // Blink started
            pendingTriggers.append(mapping.eyeBlinkToTrigger)
        }
    }

    /// Process hand tracking
    private func processHands() {
        // Use dominant hand (right) or whichever is tracked
        let hand = rightHandState.isTracked ? rightHandState : leftHandState

        guard hand.isTracked else { return }

        // Pinch → volume/parameter
        updateParameter(mapping.pinchToParameter, value: hand.pinchStrength)

        // Grab → distortion
        updateParameter(mapping.grabToParameter, value: hand.grabStrength)

        // Hand height → filter/pitch
        let handY = (hand.indexTip.y + 1) / 2  // Normalize to 0-1
        updateParameter(mapping.handHeightToParameter, value: handY)

        // Hand X position → pan
        let handX = (hand.wrist.x + 1) / 2
        updateParameter(mapping.handXToParameter, value: handX)

        // Gestures as triggers
        if hand.isPinching && !rightHandState.isPinching {
            pendingTriggers.append(.noteOn)
        }
        if hand.isGrabbing {
            pendingTriggers.append(.freeze)
        }
    }

    /// Process body pose
    private func processBodyPose() {
        guard bodyPoseState.isTracked else { return }

        // Arm spread → stereo width
        let spreadNorm = min(1, bodyPoseState.armSpread * 2)
        updateParameter(mapping.armSpreadToParameter, value: spreadNorm)

        // Arm height → filter
        let heightNorm = (bodyPoseState.armHeight + 0.5)  // Center around 0.5
        updateParameter(mapping.armHeightToParameter, value: max(0, min(1, heightNorm)))

        // Body tilt → pan
        let tiltNorm = (bodyPoseState.bodyTilt + 0.5)
        updateParameter(mapping.bodyTiltToParameter, value: max(0, min(1, tiltNorm)))

        // Pose triggers
        if bodyPoseState.isArmsUp && bodyPoseState.isArmsWide {
            // Arms up and wide = big gesture
            pendingTriggers.append(.sampleTrigger)
        }
    }

    // MARK: - Parameter Management

    /// Update a parameter with smoothing
    private func updateParameter(_ param: AudioParameter, value: Float) {
        let current = outputParameters[param] ?? 0.5

        // Apply dead zone
        let diff = abs(value - current)
        guard diff > deadZone else { return }

        // Apply smoothing
        let smoothed = current + (value - current) * smoothing
        outputParameters[param] = max(0, min(1, smoothed))
    }

    /// Get current value for a parameter
    public func getValue(for param: AudioParameter) -> Float {
        return outputParameters[param] ?? 0.5
    }

    /// Get all current parameters
    public func getAllParameters() -> [AudioParameter: Float] {
        return outputParameters
    }

    /// Get and clear pending triggers
    public func getPendingTriggers() -> [AudioTrigger] {
        let triggers = pendingTriggers
        pendingTriggers.removeAll()
        return triggers
    }

    // MARK: - Presets

    /// Control presets for different use cases
    public enum ControlPreset: String, CaseIterable {
        case performance = "Performance"
        case meditation = "Meditation"
        case djStyle = "DJ Style"
        case theremin = "Theremin"
        case conductor = "Conductor"
        case expressive = "Expressive"

        public func apply(to controller: GestureMimicController) {
            switch self {
            case .performance:
                controller.mapping.touchXToParameter = .pan
                controller.mapping.touchYToParameter = .filter
                controller.mapping.pressureToParameter = .volume
                controller.mapping.mouthOpenToParameter = .filter
                controller.sensitivity = 1.0

            case .meditation:
                controller.mapping.touchXToParameter = .morphX
                controller.mapping.touchYToParameter = .morphY
                controller.mapping.pitchToParameter = .reverb
                controller.mapping.smileToParameter = .brightness
                controller.sensitivity = 0.5
                controller.smoothing = 0.4

            case .djStyle:
                controller.mapping.touchXToParameter = .filter
                controller.mapping.touchYToParameter = .resonance
                controller.mapping.rotationToParameter = .tempo
                controller.mapping.spreadToParameter = .reverb
                controller.sensitivity = 1.2

            case .theremin:
                controller.mapping.handHeightToParameter = .pitch
                controller.mapping.handXToParameter = .volume
                controller.mapping.pinchToParameter = .filter
                controller.sensitivity = 1.5
                controller.smoothing = 0.15

            case .conductor:
                controller.mapping.armHeightToParameter = .tempo
                controller.mapping.armSpreadToParameter = .volume
                controller.mapping.bodyTiltToParameter = .pan
                controller.sensitivity = 0.8

            case .expressive:
                controller.mapping.smileToParameter = .brightness
                controller.mapping.browToParameter = .pitch
                controller.mapping.mouthOpenToParameter = .filter
                controller.mapping.handHeightToParameter = .volume
                controller.sensitivity = 1.0
            }
        }
    }

    /// Apply control preset
    public func applyPreset(_ preset: ControlPreset) {
        preset.apply(to: self)
    }

    // MARK: - Reset

    /// Reset all states
    public func reset() {
        touchState = TouchState()
        motionState = MotionState()
        facialState = FacialState()
        leftHandState = HandState()
        rightHandState = HandState()
        bodyPoseState = BodyPoseState()

        for param in AudioParameter.allCases {
            outputParameters[param] = 0.5
        }

        pendingTriggers.removeAll()
    }
}

// MARK: - Gesture Recorder

extension GestureMimicController {

    /// Record gestures for playback
    public struct GestureRecording {
        public var frames: [GestureFrame] = []
        public var duration: TimeInterval = 0
        public var frameRate: Int = 60

        public struct GestureFrame {
            public var timestamp: TimeInterval
            public var parameters: [AudioParameter: Float]
            public var triggers: [AudioTrigger]
        }

        public init() {}
    }

    /// Gesture recording manager
    public class GestureRecorder {
        private var recording = GestureRecording()
        private var isRecording = false
        private var startTime: Date?

        public func startRecording() {
            recording = GestureRecording()
            startTime = Date()
            isRecording = true
        }

        public func recordFrame(parameters: [AudioParameter: Float], triggers: [AudioTrigger]) {
            guard isRecording, let start = startTime else { return }

            let timestamp = Date().timeIntervalSince(start)
            let frame = GestureRecording.GestureFrame(
                timestamp: timestamp,
                parameters: parameters,
                triggers: triggers
            )
            recording.frames.append(frame)
            recording.duration = timestamp
        }

        public func stopRecording() -> GestureRecording {
            isRecording = false
            return recording
        }
    }
}

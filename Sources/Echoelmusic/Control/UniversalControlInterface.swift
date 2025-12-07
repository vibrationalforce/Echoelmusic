import Foundation
import simd
import Accelerate

// MARK: - Universal Control Interface (UCI)
// Unified abstraction for ALL human-machine interfaces
// Supports: Wearables, Neural, Biometric, Gesture, Eye-Tracking, and more

/// UniversalControlInterface: Device-agnostic control abstraction layer
/// Provides unified API for any input device or sensor
///
/// Supported input types:
/// - Neural interfaces (Neuralink, OpenBCI, Emotiv)
/// - Wearables (Apple Watch, Oura Ring, Whoop, Garmin)
/// - Eye tracking (Tobii, Apple Vision Pro, Meta Quest)
/// - Motion capture (Leap Motion, MediaPipe, ARKit)
/// - Biometric sensors (HRV, EDA, EEG, EMG)
/// - Traditional inputs (touch, mouse, keyboard, gamepad)
/// - Voice commands
/// - Brain-Computer Interfaces (BCI)
public final class UniversalControlInterface {

    // MARK: - Device Categories

    /// Input device categories
    public enum DeviceCategory: String, CaseIterable {
        case neural = "Neural Interface"
        case wearable = "Wearable Device"
        case eyeTracking = "Eye Tracking"
        case motionCapture = "Motion Capture"
        case biometric = "Biometric Sensor"
        case haptic = "Haptic Device"
        case voice = "Voice Command"
        case traditional = "Traditional Input"
        case environmental = "Environmental Sensor"
        case medical = "Medical Device"

        var requiresCertification: Bool {
            switch self {
            case .neural, .medical: return true
            case .biometric: return true
            default: return false
            }
        }

        var safetyLevel: SafetyLevel {
            switch self {
            case .neural: return .critical
            case .medical: return .critical
            case .biometric: return .high
            case .eyeTracking, .motionCapture: return .medium
            default: return .standard
            }
        }
    }

    /// Safety levels for devices
    public enum SafetyLevel: Int, Comparable {
        case standard = 0
        case medium = 1
        case high = 2
        case critical = 3

        public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Device Abstraction

    /// Universal device descriptor
    public struct DeviceDescriptor: Identifiable, Hashable {
        public let id: UUID
        public var name: String
        public var category: DeviceCategory
        public var manufacturer: String
        public var modelIdentifier: String
        public var firmwareVersion: String
        public var capabilities: Set<DeviceCapability>
        public var certifications: Set<Certification>
        public var isConnected: Bool
        public var batteryLevel: Float?
        public var signalQuality: Float?

        public init(
            name: String,
            category: DeviceCategory,
            manufacturer: String = "Unknown",
            modelIdentifier: String = ""
        ) {
            self.id = UUID()
            self.name = name
            self.category = category
            self.manufacturer = manufacturer
            self.modelIdentifier = modelIdentifier
            self.firmwareVersion = "1.0"
            self.capabilities = []
            self.certifications = []
            self.isConnected = false
            self.batteryLevel = nil
            self.signalQuality = nil
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public static func == (lhs: DeviceDescriptor, rhs: DeviceDescriptor) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Device capabilities
    public enum DeviceCapability: String, CaseIterable {
        // Motion
        case position3D = "3D Position"
        case rotation3D = "3D Rotation"
        case velocity = "Velocity"
        case acceleration = "Acceleration"
        case angularVelocity = "Angular Velocity"

        // Biometric
        case heartRate = "Heart Rate"
        case heartRateVariability = "HRV"
        case bloodOxygen = "SpO2"
        case skinConductance = "Skin Conductance"
        case temperature = "Temperature"
        case bloodPressure = "Blood Pressure"
        case respiratoryRate = "Respiratory Rate"

        // Neural
        case eeg = "EEG"
        case emg = "EMG"
        case eog = "EOG"
        case neuralSpikes = "Neural Spikes"
        case brainwaveClassification = "Brainwave Classification"

        // Eye
        case gazePoint = "Gaze Point"
        case pupilDilation = "Pupil Dilation"
        case blinkDetection = "Blink Detection"
        case eyeOpenness = "Eye Openness"
        case fixation = "Fixation"
        case saccade = "Saccade"

        // Gesture
        case handTracking = "Hand Tracking"
        case fingerTracking = "Finger Tracking"
        case bodyPose = "Body Pose"
        case facialExpression = "Facial Expression"

        // Haptic
        case vibration = "Vibration"
        case forceFeedback = "Force Feedback"
        case thermalFeedback = "Thermal Feedback"

        // Voice
        case voiceCommand = "Voice Command"
        case speechToText = "Speech to Text"
        case emotionInVoice = "Voice Emotion"

        // Traditional
        case buttons = "Buttons"
        case analogStick = "Analog Stick"
        case touchSurface = "Touch Surface"
        case pressure = "Pressure Sensing"
    }

    /// Device certifications
    public enum Certification: String, CaseIterable {
        // Safety
        case tuv = "TÜV"
        case ce = "CE Mark"
        case fcc = "FCC"
        case ul = "UL Listed"

        // Medical
        case fda510k = "FDA 510(k)"
        case fdaClassII = "FDA Class II"
        case mdr = "EU MDR"
        case iso13485 = "ISO 13485"

        // Automotive
        case iso26262 = "ISO 26262 (ASIL)"
        case unece = "UN ECE"
        case saeJ3016 = "SAE J3016"

        // Aviation
        case faaApproved = "FAA Approved"
        case easa = "EASA Certified"
        case do178c = "DO-178C"
        case do254 = "DO-254"

        // Maritime
        case solas = "SOLAS"
        case imo = "IMO Compliant"

        // General
        case iso9001 = "ISO 9001"
        case iso27001 = "ISO 27001"
        case gdpr = "GDPR Compliant"
        case hipaa = "HIPAA Compliant"
    }

    // MARK: - Unified Input State

    /// Universal input state combining all modalities
    public struct UnifiedInputState {
        public var timestamp: Date = Date()

        // Spatial
        public var position: SIMD3<Float> = .zero           // Meters
        public var rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        public var velocity: SIMD3<Float> = .zero           // m/s
        public var acceleration: SIMD3<Float> = .zero       // m/s²
        public var angularVelocity: SIMD3<Float> = .zero    // rad/s

        // Gaze
        public var gazeOrigin: SIMD3<Float> = .zero
        public var gazeDirection: SIMD3<Float> = SIMD3(0, 0, -1)
        public var gazePoint: SIMD3<Float>? = nil           // World space hit point
        public var pupilDilation: Float = 0.5               // Normalized
        public var eyeOpenness: Float = 1.0                 // 0 = closed, 1 = open
        public var isBlinking: Bool = false
        public var fixationDuration: TimeInterval = 0

        // Hands
        public var leftHand: HandState?
        public var rightHand: HandState?

        // Body
        public var bodyPose: BodyPoseState?

        // Face
        public var facialExpression: FacialExpressionState?

        // Biometrics
        public var heartRate: Float?                         // BPM
        public var heartRateVariability: Float?              // RMSSD ms
        public var skinConductance: Float?                   // µS
        public var bodyTemperature: Float?                   // °C
        public var bloodOxygen: Float?                       // SpO2 %
        public var respiratoryRate: Float?                   // breaths/min
        public var bloodPressure: (systolic: Float, diastolic: Float)?

        // Neural
        public var brainwaveState: BrainwaveState?
        public var neuralIntention: NeuralIntention?
        public var mentalWorkload: Float?                    // 0-1
        public var focusLevel: Float?                        // 0-1
        public var relaxationLevel: Float?                   // 0-1

        // Voice
        public var voiceCommand: String?
        public var voiceEmotion: VoiceEmotion?
        public var isSpeaking: Bool = false

        // Control outputs (derived)
        public var primaryAxis: SIMD2<Float> = .zero         // -1 to 1
        public var secondaryAxis: SIMD2<Float> = .zero
        public var throttle: Float = 0                       // 0 to 1
        public var brake: Float = 0                          // 0 to 1
        public var trigger: Float = 0                        // 0 to 1
        public var buttons: Set<String> = []

        // Confidence
        public var overallConfidence: Float = 0              // 0-1
        public var sourceDevices: [UUID] = []

        public init() {}
    }

    /// Hand tracking state
    public struct HandState {
        public var isTracked: Bool = false
        public var confidence: Float = 0

        public var wrist: SIMD3<Float> = .zero
        public var palm: SIMD3<Float> = .zero
        public var palmNormal: SIMD3<Float> = .zero

        public var thumbTip: SIMD3<Float> = .zero
        public var indexTip: SIMD3<Float> = .zero
        public var middleTip: SIMD3<Float> = .zero
        public var ringTip: SIMD3<Float> = .zero
        public var pinkyTip: SIMD3<Float> = .zero

        public var pinchStrength: Float = 0
        public var grabStrength: Float = 0
        public var isPointing: Bool = false
        public var isPinching: Bool = false
        public var isGrabbing: Bool = false
        public var gesture: HandGesture = .open

        public enum HandGesture: String {
            case open, fist, point, pinch, thumbsUp, thumbsDown, peace, ok, custom
        }
    }

    /// Body pose state
    public struct BodyPoseState {
        public var isTracked: Bool = false
        public var confidence: Float = 0

        public var head: SIMD3<Float> = .zero
        public var neck: SIMD3<Float> = .zero
        public var spine: SIMD3<Float> = .zero
        public var hips: SIMD3<Float> = .zero

        public var leftShoulder: SIMD3<Float> = .zero
        public var rightShoulder: SIMD3<Float> = .zero
        public var leftElbow: SIMD3<Float> = .zero
        public var rightElbow: SIMD3<Float> = .zero
        public var leftWrist: SIMD3<Float> = .zero
        public var rightWrist: SIMD3<Float> = .zero

        public var leftHip: SIMD3<Float> = .zero
        public var rightHip: SIMD3<Float> = .zero
        public var leftKnee: SIMD3<Float> = .zero
        public var rightKnee: SIMD3<Float> = .zero
        public var leftAnkle: SIMD3<Float> = .zero
        public var rightAnkle: SIMD3<Float> = .zero

        public var posture: Posture = .standing

        public enum Posture: String {
            case standing, sitting, crouching, lying, walking, running, jumping
        }
    }

    /// Facial expression state
    public struct FacialExpressionState {
        public var confidence: Float = 0

        // Derived emotions (0-1)
        public var happiness: Float = 0
        public var sadness: Float = 0
        public var anger: Float = 0
        public var fear: Float = 0
        public var surprise: Float = 0
        public var disgust: Float = 0
        public var contempt: Float = 0
        public var neutral: Float = 1

        // Key expressions
        public var mouthOpen: Float = 0
        public var smile: Float = 0
        public var frown: Float = 0
        public var eyebrowRaise: Float = 0
        public var eyeSquint: Float = 0
    }

    /// Brainwave state
    public struct BrainwaveState {
        public var delta: Float = 0      // 0.5-4 Hz (deep sleep)
        public var theta: Float = 0      // 4-8 Hz (drowsy, meditation)
        public var alpha: Float = 0      // 8-13 Hz (relaxed)
        public var beta: Float = 0       // 13-30 Hz (active thinking)
        public var gamma: Float = 0      // 30-100 Hz (high cognition)

        public var dominantWave: DominantWave {
            let waves = [
                (delta, DominantWave.delta),
                (theta, DominantWave.theta),
                (alpha, DominantWave.alpha),
                (beta, DominantWave.beta),
                (gamma, DominantWave.gamma)
            ]
            return waves.max { $0.0 < $1.0 }?.1 ?? .alpha
        }

        public enum DominantWave: String {
            case delta, theta, alpha, beta, gamma
        }
    }

    /// Neural intention (BCI output)
    public struct NeuralIntention {
        public var confidence: Float = 0

        // Motor imagery
        public var leftHandMotion: Float = 0
        public var rightHandMotion: Float = 0
        public var feetMotion: Float = 0
        public var tongueMotion: Float = 0

        // Cognitive
        public var mentalCommand: MentalCommand?
        public var attentionTarget: SIMD3<Float>?

        public enum MentalCommand: String {
            case push, pull, lift, drop, rotateLeft, rotateRight
            case accelerate, decelerate, stop, neutral
        }
    }

    /// Voice emotion
    public struct VoiceEmotion {
        public var valence: Float = 0     // -1 to 1
        public var arousal: Float = 0     // -1 to 1
        public var dominance: Float = 0   // -1 to 1
        public var confidence: Float = 0
    }

    // MARK: - Properties

    /// Connected devices
    private var connectedDevices: [UUID: DeviceDescriptor] = [:]

    /// Current unified input state
    public private(set) var inputState = UnifiedInputState()

    /// Previous state for delta calculation
    private var previousState = UnifiedInputState()

    /// Input fusion weights
    public var fusionWeights: [DeviceCategory: Float] = [:]

    /// Calibration data
    private var calibrationData: [UUID: CalibrationData] = [:]

    /// Safety system reference
    public weak var safetyGuardian: SafetyGuardianSystem?

    /// Is input currently blocked by safety
    public private(set) var isInputBlocked: Bool = false

    /// Block reason
    public private(set) var blockReason: String?

    // Delegates
    public var onInputUpdate: ((UnifiedInputState) -> Void)?
    public var onDeviceConnected: ((DeviceDescriptor) -> Void)?
    public var onDeviceDisconnected: ((DeviceDescriptor) -> Void)?
    public var onSafetyAlert: ((SafetyAlert) -> Void)?

    // MARK: - Initialization

    public init() {
        // Set default fusion weights
        for category in DeviceCategory.allCases {
            fusionWeights[category] = 1.0
        }
    }

    // MARK: - Device Management

    /// Register a new device
    public func registerDevice(_ device: DeviceDescriptor) -> Bool {
        // Safety check for critical devices
        if device.category.safetyLevel >= .high {
            guard let safety = safetyGuardian else {
                print("⚠️ Cannot register \(device.category.rawValue) without SafetyGuardianSystem")
                return false
            }

            // Verify certifications
            if device.category == .neural || device.category == .medical {
                let requiredCerts: Set<Certification> = [.ce, .iso13485]
                if device.certifications.intersection(requiredCerts).isEmpty {
                    print("⚠️ Device \(device.name) lacks required medical certifications")
                    return false
                }
            }
        }

        var registeredDevice = device
        registeredDevice.isConnected = true
        connectedDevices[device.id] = registeredDevice

        onDeviceConnected?(registeredDevice)
        return true
    }

    /// Unregister a device
    public func unregisterDevice(id: UUID) {
        if let device = connectedDevices.removeValue(forKey: id) {
            onDeviceDisconnected?(device)
        }
    }

    /// Get all connected devices
    public func getConnectedDevices() -> [DeviceDescriptor] {
        return Array(connectedDevices.values)
    }

    /// Get devices by category
    public func getDevices(category: DeviceCategory) -> [DeviceDescriptor] {
        return connectedDevices.values.filter { $0.category == category }
    }

    // MARK: - Calibration

    /// Calibration data for a device
    public struct CalibrationData {
        public var deviceId: UUID
        public var timestamp: Date
        public var offsetPosition: SIMD3<Float> = .zero
        public var offsetRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        public var scale: SIMD3<Float> = SIMD3(1, 1, 1)
        public var deadzone: Float = 0.05
        public var sensitivity: Float = 1.0
        public var customData: [String: Any] = [:]

        public init(deviceId: UUID) {
            self.deviceId = deviceId
            self.timestamp = Date()
        }
    }

    /// Start calibration for device
    public func startCalibration(deviceId: UUID) -> Bool {
        guard connectedDevices[deviceId] != nil else { return false }

        var calibration = CalibrationData(deviceId: deviceId)
        calibrationData[deviceId] = calibration
        return true
    }

    /// Save calibration
    public func saveCalibration(deviceId: UUID, data: CalibrationData) {
        calibrationData[deviceId] = data
    }

    // MARK: - Input Processing

    /// Update input from a specific device
    public func updateInput(from deviceId: UUID, data: DeviceInputData) {
        guard let device = connectedDevices[deviceId] else { return }

        // Check safety
        if let safety = safetyGuardian {
            let status = safety.evaluateOperatorState()
            if !status.canOperate {
                isInputBlocked = true
                blockReason = status.reason
                onSafetyAlert?(SafetyAlert(
                    level: .critical,
                    message: status.reason ?? "Operation blocked",
                    source: device.name
                ))
                return
            }
        }

        isInputBlocked = false
        blockReason = nil

        // Apply calibration
        let calibration = calibrationData[deviceId]

        // Fuse input based on data type
        fuseInput(from: device, data: data, calibration: calibration)
    }

    /// Fuse input data into unified state
    private func fuseInput(from device: DeviceDescriptor, data: DeviceInputData, calibration: CalibrationData?) {
        previousState = inputState
        inputState.timestamp = Date()

        let weight = fusionWeights[device.category] ?? 1.0

        // Position
        if let pos = data.position {
            var calibratedPos = pos
            if let cal = calibration {
                calibratedPos = (pos - cal.offsetPosition) * cal.scale
            }
            inputState.position = simd_mix(inputState.position, calibratedPos, SIMD3(repeating: weight))
        }

        // Rotation
        if let rot = data.rotation {
            inputState.rotation = simd_slerp(inputState.rotation, rot, weight)
        }

        // Gaze
        if let gaze = data.gazeDirection {
            inputState.gazeDirection = simd_normalize(simd_mix(inputState.gazeDirection, gaze, SIMD3(repeating: weight)))
        }
        if let gazePoint = data.gazePoint {
            inputState.gazePoint = gazePoint
        }

        // Biometrics
        if let hr = data.heartRate {
            inputState.heartRate = hr
        }
        if let hrv = data.heartRateVariability {
            inputState.heartRateVariability = hrv
        }
        if let scl = data.skinConductance {
            inputState.skinConductance = scl
        }

        // Neural
        if let brain = data.brainwaveState {
            inputState.brainwaveState = brain
        }
        if let intention = data.neuralIntention {
            inputState.neuralIntention = intention
        }
        if let focus = data.focusLevel {
            inputState.focusLevel = focus
        }
        if let mental = data.mentalWorkload {
            inputState.mentalWorkload = mental
        }

        // Hands
        if let leftHand = data.leftHand {
            inputState.leftHand = leftHand
        }
        if let rightHand = data.rightHand {
            inputState.rightHand = rightHand
        }

        // Body
        if let body = data.bodyPose {
            inputState.bodyPose = body
        }

        // Face
        if let face = data.facialExpression {
            inputState.facialExpression = face
        }

        // Voice
        if let command = data.voiceCommand {
            inputState.voiceCommand = command
        }

        // Traditional controls
        if let primary = data.primaryAxis {
            inputState.primaryAxis = primary
        }
        if let throttle = data.throttle {
            inputState.throttle = throttle
        }
        if let brake = data.brake {
            inputState.brake = brake
        }

        // Track source
        if !inputState.sourceDevices.contains(device.id) {
            inputState.sourceDevices.append(device.id)
        }

        // Calculate overall confidence
        calculateConfidence()

        // Notify
        onInputUpdate?(inputState)
    }

    /// Calculate overall input confidence
    private func calculateConfidence() {
        var confidenceSum: Float = 0
        var count: Float = 0

        if inputState.leftHand?.isTracked == true {
            confidenceSum += inputState.leftHand?.confidence ?? 0
            count += 1
        }
        if inputState.rightHand?.isTracked == true {
            confidenceSum += inputState.rightHand?.confidence ?? 0
            count += 1
        }
        if inputState.bodyPose?.isTracked == true {
            confidenceSum += inputState.bodyPose?.confidence ?? 0
            count += 1
        }
        if inputState.facialExpression != nil {
            confidenceSum += inputState.facialExpression?.confidence ?? 0
            count += 1
        }
        if inputState.brainwaveState != nil {
            confidenceSum += 0.8  // Assume good if present
            count += 1
        }

        inputState.overallConfidence = count > 0 ? confidenceSum / count : 0.5
    }

    // MARK: - Input Data Type

    /// Generic input data from any device
    public struct DeviceInputData {
        // Spatial
        public var position: SIMD3<Float>?
        public var rotation: simd_quatf?
        public var velocity: SIMD3<Float>?
        public var acceleration: SIMD3<Float>?

        // Gaze
        public var gazeDirection: SIMD3<Float>?
        public var gazePoint: SIMD3<Float>?
        public var pupilDilation: Float?
        public var isBlinking: Bool?

        // Biometric
        public var heartRate: Float?
        public var heartRateVariability: Float?
        public var skinConductance: Float?
        public var bodyTemperature: Float?
        public var bloodOxygen: Float?

        // Neural
        public var brainwaveState: BrainwaveState?
        public var neuralIntention: NeuralIntention?
        public var focusLevel: Float?
        public var mentalWorkload: Float?

        // Body
        public var leftHand: HandState?
        public var rightHand: HandState?
        public var bodyPose: BodyPoseState?
        public var facialExpression: FacialExpressionState?

        // Voice
        public var voiceCommand: String?
        public var voiceEmotion: VoiceEmotion?

        // Traditional
        public var primaryAxis: SIMD2<Float>?
        public var secondaryAxis: SIMD2<Float>?
        public var throttle: Float?
        public var brake: Float?
        public var buttons: Set<String>?

        public init() {}
    }

    // MARK: - Safety Alert

    /// Safety alert from input system
    public struct SafetyAlert {
        public var level: AlertLevel
        public var message: String
        public var source: String
        public var timestamp: Date = Date()

        public enum AlertLevel: String {
            case info = "Info"
            case warning = "Warning"
            case critical = "Critical"
            case emergency = "Emergency"
        }
    }

    // MARK: - Control Mapping

    /// Map unified input to specific control scheme
    public func mapToControlScheme(_ scheme: ControlScheme) -> MappedControls {
        var controls = MappedControls()

        switch scheme {
        case .flightSimulator:
            controls = mapFlightControls()
        case .vehicleSimulator:
            controls = mapVehicleControls()
        case .droneControl:
            controls = mapDroneControls()
        case .marineSimulator:
            controls = mapMarineControls()
        case .surgical:
            controls = mapSurgicalControls()
        case .spatialDrawing:
            controls = mapDrawingControls()
        case .multimedia:
            controls = mapMultimediaControls()
        }

        return controls
    }

    /// Control schemes
    public enum ControlScheme: String, CaseIterable {
        case flightSimulator = "Flight Simulator"
        case vehicleSimulator = "Vehicle Simulator"
        case droneControl = "Drone Control"
        case marineSimulator = "Marine Simulator"
        case surgical = "Surgical/Precision"
        case spatialDrawing = "Spatial Drawing"
        case multimedia = "Multimedia"
    }

    /// Mapped controls output
    public struct MappedControls {
        // General
        public var isActive: Bool = false
        public var confidence: Float = 0

        // Axes (normalized -1 to 1)
        public var pitch: Float = 0
        public var roll: Float = 0
        public var yaw: Float = 0
        public var throttle: Float = 0

        // Vehicle specific
        public var steering: Float = 0
        public var accelerator: Float = 0
        public var brake: Float = 0

        // Precision
        public var position: SIMD3<Float> = .zero
        public var rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        public var grip: Float = 0

        // Drawing
        public var brushPosition: SIMD3<Float> = .zero
        public var brushPressure: Float = 0
        public var brushSize: Float = 1
        public var color: SIMD4<Float> = SIMD4(1, 1, 1, 1)

        // States
        public var buttons: [String: Bool] = [:]
        public var triggers: [String: Float] = [:]

        public init() {}
    }

    // MARK: - Control Mapping Implementations

    private func mapFlightControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Use hands for primary control
        if let rightHand = inputState.rightHand, rightHand.isTracked {
            // Hand position → pitch and roll
            controls.pitch = (rightHand.palm.y - 0.5) * 2
            controls.roll = rightHand.palm.x * 2

            // Pinch for trigger
            controls.triggers["trigger"] = rightHand.pinchStrength
        }

        if let leftHand = inputState.leftHand, leftHand.isTracked {
            // Left hand Y → throttle
            controls.throttle = max(0, leftHand.palm.y)

            // Pinch for brake/speed brake
            controls.brake = leftHand.pinchStrength
        }

        // Head/gaze for yaw
        let yaw = atan2(inputState.gazeDirection.x, -inputState.gazeDirection.z)
        controls.yaw = yaw / .pi

        // Neural input for fine control
        if let intention = inputState.neuralIntention {
            if intention.confidence > 0.5 {
                controls.pitch += intention.leftHandMotion * 0.2
                controls.roll += intention.rightHandMotion * 0.2
            }
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    private func mapVehicleControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Hands on virtual wheel
        if let leftHand = inputState.leftHand,
           let rightHand = inputState.rightHand,
           leftHand.isTracked && rightHand.isTracked {

            // Calculate steering from hand positions
            let handDiff = rightHand.palm.x - leftHand.palm.x
            let handRotation = atan2(rightHand.palm.y - leftHand.palm.y, handDiff)
            controls.steering = handRotation / (.pi / 4)  // ±45° = full lock
        }

        // Foot pedals from body pose or explicit input
        if let body = inputState.bodyPose, body.isTracked {
            // Right foot forward = accelerate
            controls.accelerator = max(0, body.rightAnkle.z - body.rightKnee.z) * 5
            // Left foot = brake
            controls.brake = max(0, body.leftAnkle.z - body.leftKnee.z) * 5
        }

        // Override with explicit throttle/brake if available
        if inputState.throttle > 0 {
            controls.accelerator = inputState.throttle
        }
        if inputState.brake > 0 {
            controls.brake = inputState.brake
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    private func mapDroneControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Single hand control mode
        if let hand = inputState.rightHand ?? inputState.leftHand, hand.isTracked {
            // Palm position for pitch/roll
            controls.pitch = (hand.palm.z - 0.3) * 3
            controls.roll = hand.palm.x * 2

            // Hand height for throttle
            controls.throttle = max(0, min(1, hand.palm.y))

            // Wrist rotation for yaw
            // (Simplified - would need palm normal)
            controls.yaw = hand.wrist.x * 2
        }

        // Gaze for camera control
        controls.buttons["cameraLook"] = inputState.fixationDuration > 0.5

        // Pinch to take photo
        if let hand = inputState.rightHand, hand.isPinching {
            controls.buttons["capture"] = true
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    private func mapMarineControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Throttle levers (left hand)
        if let leftHand = inputState.leftHand, leftHand.isTracked {
            controls.throttle = leftHand.palm.y
        }

        // Helm/rudder (right hand or wheel motion)
        if let rightHand = inputState.rightHand, rightHand.isTracked {
            controls.steering = rightHand.palm.x * 2
        }

        // Depth control for submarines
        if let body = inputState.bodyPose {
            // Leaning forward/back for dive planes
            let lean = body.head.z - body.hips.z
            controls.pitch = lean * 2
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    private func mapSurgicalControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Precision hand tracking
        if let rightHand = inputState.rightHand, rightHand.isTracked {
            controls.position = rightHand.indexTip
            controls.grip = rightHand.pinchStrength

            // Tremor filtering would be applied here
            controls.triggers["instrument1"] = rightHand.pinchStrength
        }

        if let leftHand = inputState.leftHand, leftHand.isTracked {
            controls.triggers["instrument2"] = leftHand.pinchStrength
        }

        // Gaze for camera control
        if let gazePoint = inputState.gazePoint {
            controls.buttons["cameraFocus"] = true
        }

        // Very high precision required
        controls.confidence = inputState.overallConfidence * (inputState.focusLevel ?? 0.5)

        return controls
    }

    private func mapDrawingControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Primary hand for brush position
        if let hand = inputState.rightHand ?? inputState.leftHand, hand.isTracked {
            controls.brushPosition = hand.indexTip
            controls.brushPressure = hand.pinchStrength
            controls.brushSize = 1 + hand.grabStrength * 4  // 1-5 range
        }

        // Gaze for color picking or tool selection
        if let face = inputState.facialExpression {
            // Happy = warm colors, sad = cool colors
            let warmth = face.happiness - face.sadness
            controls.color = SIMD4(
                0.5 + warmth * 0.5,  // R
                0.5,                  // G
                0.5 - warmth * 0.5,  // B
                1.0                   // A
            )
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    private func mapMultimediaControls() -> MappedControls {
        var controls = MappedControls()
        controls.isActive = !isInputBlocked

        // Everything! Full multi-modal
        if let hand = inputState.rightHand, hand.isTracked {
            controls.position = hand.palm
            controls.triggers["modulation"] = hand.pinchStrength
        }

        if let gaze = inputState.gazePoint {
            controls.buttons["gazeFocus"] = true
        }

        if let brain = inputState.brainwaveState {
            controls.triggers["alpha"] = brain.alpha
            controls.triggers["beta"] = brain.beta
            controls.triggers["theta"] = brain.theta
        }

        if let focus = inputState.focusLevel {
            controls.triggers["focus"] = focus
        }

        controls.confidence = inputState.overallConfidence
        return controls
    }

    // MARK: - Reset

    /// Reset interface
    public func reset() {
        inputState = UnifiedInputState()
        previousState = UnifiedInputState()
        isInputBlocked = false
        blockReason = nil
    }
}

// MARK: - Device Templates

extension UniversalControlInterface {

    /// Pre-configured device templates
    public static func createDeviceTemplate(_ template: DeviceTemplate) -> DeviceDescriptor {
        switch template {
        case .neuralinkN1:
            var device = DeviceDescriptor(name: "Neuralink N1", category: .neural, manufacturer: "Neuralink")
            device.capabilities = [.eeg, .neuralSpikes, .brainwaveClassification]
            device.certifications = [.fda510k, .iso13485, .ce]
            return device

        case .ouraRing:
            var device = DeviceDescriptor(name: "Oura Ring", category: .wearable, manufacturer: "Oura")
            device.capabilities = [.heartRate, .heartRateVariability, .temperature, .bloodOxygen]
            device.certifications = [.ce, .fcc]
            return device

        case .appleWatch:
            var device = DeviceDescriptor(name: "Apple Watch", category: .wearable, manufacturer: "Apple")
            device.capabilities = [.heartRate, .heartRateVariability, .bloodOxygen, .acceleration]
            device.certifications = [.ce, .fcc, .fda510k]
            return device

        case .tobiiEyeTracker:
            var device = DeviceDescriptor(name: "Tobii Eye Tracker", category: .eyeTracking, manufacturer: "Tobii")
            device.capabilities = [.gazePoint, .pupilDilation, .blinkDetection, .fixation, .saccade]
            device.certifications = [.ce, .fcc]
            return device

        case .visionPro:
            var device = DeviceDescriptor(name: "Apple Vision Pro", category: .motionCapture, manufacturer: "Apple")
            device.capabilities = [.handTracking, .eyeOpenness, .gazePoint, .position3D, .rotation3D]
            device.certifications = [.ce, .fcc]
            return device

        case .leapMotion:
            var device = DeviceDescriptor(name: "Leap Motion", category: .motionCapture, manufacturer: "Ultraleap")
            device.capabilities = [.handTracking, .fingerTracking]
            device.certifications = [.ce, .fcc]
            return device

        case .emotivEpoc:
            var device = DeviceDescriptor(name: "Emotiv EPOC", category: .neural, manufacturer: "Emotiv")
            device.capabilities = [.eeg, .brainwaveClassification]
            device.certifications = [.ce, .fcc]
            return device
        }
    }

    /// Device templates
    public enum DeviceTemplate: String, CaseIterable {
        case neuralinkN1 = "Neuralink N1"
        case ouraRing = "Oura Ring"
        case appleWatch = "Apple Watch"
        case tobiiEyeTracker = "Tobii Eye Tracker"
        case visionPro = "Vision Pro"
        case leapMotion = "Leap Motion"
        case emotivEpoc = "Emotiv EPOC"
    }
}

// OpenXREngine.swift
// Echoelmusic
//
// OpenXR Engine for Meta Quest, Windows Mixed Reality, SteamVR, Pico, and other OpenXR runtimes
// Provides native VR/AR support across PC and standalone headsets
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine
import simd

// MARK: - OpenXR Runtime

public enum OpenXRRuntime: String, CaseIterable, Codable {
    case metaQuest = "Meta Quest"
    case steamVR = "SteamVR"
    case windowsMR = "Windows Mixed Reality"
    case varjo = "Varjo"
    case pico = "Pico"
    case htcVive = "HTC Vive"
    case monado = "Monado (Linux)"
    case unknown = "Unknown"

    public var vendorId: String {
        switch self {
        case .metaQuest: return "oculus"
        case .steamVR: return "valve"
        case .windowsMR: return "microsoft"
        case .varjo: return "varjo"
        case .pico: return "pico"
        case .htcVive: return "htc"
        case .monado: return "monado"
        case .unknown: return "unknown"
        }
    }

    public var supportsHandTracking: Bool {
        switch self {
        case .metaQuest, .varjo, .pico: return true
        default: return false
        }
    }

    public var supportsEyeTracking: Bool {
        switch self {
        case .metaQuest, .varjo, .pico, .htcVive: return true
        default: return false
        }
    }

    public var supportsPassthrough: Bool {
        switch self {
        case .metaQuest, .varjo, .pico: return true
        default: return false
        }
    }

    public var supportsFoveatedRendering: Bool {
        switch self {
        case .metaQuest, .varjo, .pico, .htcVive: return true
        default: return false
        }
    }
}

// MARK: - OpenXR Form Factor

public enum OpenXRFormFactor: String, Codable {
    case headMounted = "XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY"
    case handheld = "XR_FORM_FACTOR_HANDHELD_DISPLAY"
}

// MARK: - OpenXR View Configuration

public enum OpenXRViewConfig: String, Codable {
    case mono = "XR_VIEW_CONFIGURATION_TYPE_PRIMARY_MONO"
    case stereo = "XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO"
    case quadVarjo = "XR_VIEW_CONFIGURATION_TYPE_PRIMARY_QUAD_VARJO"
    case secondaryMono = "XR_VIEW_CONFIGURATION_TYPE_SECONDARY_MONO_FIRST_PERSON_OBSERVER_MSFT"
}

// MARK: - OpenXR Session State

public enum OpenXRSessionState: String, Codable {
    case unknown = "XR_SESSION_STATE_UNKNOWN"
    case idle = "XR_SESSION_STATE_IDLE"
    case ready = "XR_SESSION_STATE_READY"
    case synchronized = "XR_SESSION_STATE_SYNCHRONIZED"
    case visible = "XR_SESSION_STATE_VISIBLE"
    case focused = "XR_SESSION_STATE_FOCUSED"
    case stopping = "XR_SESSION_STATE_STOPPING"
    case lossPending = "XR_SESSION_STATE_LOSS_PENDING"
    case exiting = "XR_SESSION_STATE_EXITING"
}

// MARK: - OpenXR Action

public struct OpenXRAction: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: ActionType
    public var bindings: [ActionBinding]

    public enum ActionType: String, Codable {
        case booleanInput = "XR_ACTION_TYPE_BOOLEAN_INPUT"
        case floatInput = "XR_ACTION_TYPE_FLOAT_INPUT"
        case vector2fInput = "XR_ACTION_TYPE_VECTOR2F_INPUT"
        case poseInput = "XR_ACTION_TYPE_POSE_INPUT"
        case vibrationOutput = "XR_ACTION_TYPE_VIBRATION_OUTPUT"
    }

    public struct ActionBinding: Codable {
        public var interactionProfile: String
        public var binding: String

        public static let metaQuestTouchPro = "interaction_profiles/oculus/touch_controller_pro"
        public static let metaQuestTouch = "interaction_profiles/oculus/touch_controller"
        public static let valveIndex = "interaction_profiles/valve/index_controller"
        public static let htcVive = "interaction_profiles/htc/vive_controller"
        public static let microsoftMotion = "interaction_profiles/microsoft/motion_controller"
        public static let handInteraction = "interaction_profiles/ext/hand_interaction"
    }
}

// MARK: - OpenXR Pose

public struct OpenXRPose: Codable {
    public var position: SIMD3<Float>
    public var orientation: simd_quatf
    public var velocity: SIMD3<Float>?
    public var angularVelocity: SIMD3<Float>?
    public var isValid: Bool

    public init(
        position: SIMD3<Float> = .zero,
        orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        isValid: Bool = true
    ) {
        self.position = position
        self.orientation = orientation
        self.isValid = isValid
    }

    public static let identity = OpenXRPose()
}

// MARK: - OpenXR Hand Tracking

public struct OpenXRHand: Codable {
    public var handedness: Handedness
    public var joints: [JointType: OpenXRPose]
    public var isTracked: Bool
    public var confidence: Float

    public enum Handedness: String, Codable {
        case left, right
    }

    public enum JointType: String, Codable, CaseIterable {
        case palm = "XR_HAND_JOINT_PALM_EXT"
        case wrist = "XR_HAND_JOINT_WRIST_EXT"
        case thumbMetacarpal = "XR_HAND_JOINT_THUMB_METACARPAL_EXT"
        case thumbProximal = "XR_HAND_JOINT_THUMB_PROXIMAL_EXT"
        case thumbDistal = "XR_HAND_JOINT_THUMB_DISTAL_EXT"
        case thumbTip = "XR_HAND_JOINT_THUMB_TIP_EXT"
        case indexMetacarpal = "XR_HAND_JOINT_INDEX_METACARPAL_EXT"
        case indexProximal = "XR_HAND_JOINT_INDEX_PROXIMAL_EXT"
        case indexIntermediate = "XR_HAND_JOINT_INDEX_INTERMEDIATE_EXT"
        case indexDistal = "XR_HAND_JOINT_INDEX_DISTAL_EXT"
        case indexTip = "XR_HAND_JOINT_INDEX_TIP_EXT"
        case middleMetacarpal = "XR_HAND_JOINT_MIDDLE_METACARPAL_EXT"
        case middleProximal = "XR_HAND_JOINT_MIDDLE_PROXIMAL_EXT"
        case middleIntermediate = "XR_HAND_JOINT_MIDDLE_INTERMEDIATE_EXT"
        case middleDistal = "XR_HAND_JOINT_MIDDLE_DISTAL_EXT"
        case middleTip = "XR_HAND_JOINT_MIDDLE_TIP_EXT"
        case ringMetacarpal = "XR_HAND_JOINT_RING_METACARPAL_EXT"
        case ringProximal = "XR_HAND_JOINT_RING_PROXIMAL_EXT"
        case ringIntermediate = "XR_HAND_JOINT_RING_INTERMEDIATE_EXT"
        case ringDistal = "XR_HAND_JOINT_RING_DISTAL_EXT"
        case ringTip = "XR_HAND_JOINT_RING_TIP_EXT"
        case littleMetacarpal = "XR_HAND_JOINT_LITTLE_METACARPAL_EXT"
        case littleProximal = "XR_HAND_JOINT_LITTLE_PROXIMAL_EXT"
        case littleIntermediate = "XR_HAND_JOINT_LITTLE_INTERMEDIATE_EXT"
        case littleDistal = "XR_HAND_JOINT_LITTLE_DISTAL_EXT"
        case littleTip = "XR_HAND_JOINT_LITTLE_TIP_EXT"
    }

    public init(handedness: Handedness) {
        self.handedness = handedness
        self.joints = [:]
        self.isTracked = false
        self.confidence = 0
    }

    /// Detect pinch gesture
    public var isPinching: Bool {
        guard let thumbTip = joints[.thumbTip],
              let indexTip = joints[.indexTip],
              thumbTip.isValid, indexTip.isValid else {
            return false
        }
        let distance = simd_distance(thumbTip.position, indexTip.position)
        return distance < 0.02 // 2cm threshold
    }

    /// Detect grab gesture
    public var isGrabbing: Bool {
        guard let palm = joints[.palm],
              let middleTip = joints[.middleTip],
              palm.isValid, middleTip.isValid else {
            return false
        }
        let distance = simd_distance(palm.position, middleTip.position)
        return distance < 0.06 // 6cm threshold for closed fist
    }
}

// MARK: - OpenXR Eye Tracking

public struct OpenXREyeTracking: Codable {
    public var leftEyePose: OpenXRPose
    public var rightEyePose: OpenXRPose
    public var combinedGaze: OpenXRPose
    public var leftPupilDilation: Float
    public var rightPupilDilation: Float
    public var isTracked: Bool
    public var confidence: Float

    public var gazeDirection: SIMD3<Float> {
        // Extract forward direction from combined gaze orientation
        let q = combinedGaze.orientation
        return simd_normalize(SIMD3<Float>(
            2 * (q.imag.x * q.imag.z + q.real * q.imag.y),
            2 * (q.imag.y * q.imag.z - q.real * q.imag.x),
            1 - 2 * (q.imag.x * q.imag.x + q.imag.y * q.imag.y)
        ))
    }
}

// MARK: - OpenXR Passthrough

public struct OpenXRPassthrough {
    public var isEnabled: Bool
    public var mode: PassthroughMode
    public var opacity: Float
    public var brightness: Float
    public var contrast: Float
    public var saturation: Float

    public enum PassthroughMode: String, Codable {
        case fullEnvironment = "full"
        case reconstructed = "reconstructed"
        case projected = "projected"
    }

    public static let `default` = OpenXRPassthrough(
        isEnabled: false,
        mode: .fullEnvironment,
        opacity: 1.0,
        brightness: 1.0,
        contrast: 1.0,
        saturation: 1.0
    )
}

// MARK: - OpenXR Foveated Rendering

public struct OpenXRFoveatedRendering {
    public var isEnabled: Bool
    public var level: FoveationLevel
    public var dynamic: Bool

    public enum FoveationLevel: String, Codable {
        case off = "XR_FOVEATION_LEVEL_NONE_FB"
        case low = "XR_FOVEATION_LEVEL_LOW_FB"
        case medium = "XR_FOVEATION_LEVEL_MEDIUM_FB"
        case high = "XR_FOVEATION_LEVEL_HIGH_FB"
    }

    public static let `default` = OpenXRFoveatedRendering(
        isEnabled: true,
        level: .medium,
        dynamic: true
    )
}

// MARK: - OpenXR Frame

public struct OpenXRFrame {
    public var displayTime: Int64
    public var predictedDisplayTime: Int64
    public var views: [OpenXRView]
    public var headPose: OpenXRPose
    public var leftHand: OpenXRHand?
    public var rightHand: OpenXRHand?
    public var eyeTracking: OpenXREyeTracking?
    public var actionStates: [String: ActionState]

    public struct OpenXRView {
        public var eye: Eye
        public var pose: OpenXRPose
        public var fov: FieldOfView
        public var projectionMatrix: simd_float4x4

        public enum Eye: String {
            case left, right, mono
        }

        public struct FieldOfView {
            public var angleLeft: Float
            public var angleRight: Float
            public var angleUp: Float
            public var angleDown: Float
        }
    }

    public enum ActionState {
        case boolean(Bool, changedSinceLastSync: Bool)
        case float(Float, changedSinceLastSync: Bool)
        case vector2(SIMD2<Float>, changedSinceLastSync: Bool)
        case pose(OpenXRPose)
    }
}

// MARK: - OpenXR Configuration

public struct OpenXRConfiguration {
    public var applicationName: String
    public var applicationVersion: UInt32
    public var formFactor: OpenXRFormFactor
    public var viewConfig: OpenXRViewConfig
    public var blendMode: BlendMode
    public var enableHandTracking: Bool
    public var enableEyeTracking: Bool
    public var enablePassthrough: Bool
    public var enableFoveatedRendering: Bool
    public var refreshRate: Float
    public var renderScale: Float

    public enum BlendMode: String {
        case opaque = "XR_ENVIRONMENT_BLEND_MODE_OPAQUE"
        case additive = "XR_ENVIRONMENT_BLEND_MODE_ADDITIVE"
        case alphaBlend = "XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND"
    }

    public static let `default` = OpenXRConfiguration(
        applicationName: "Echoelmusic",
        applicationVersion: 1,
        formFactor: .headMounted,
        viewConfig: .stereo,
        blendMode: .opaque,
        enableHandTracking: true,
        enableEyeTracking: true,
        enablePassthrough: false,
        enableFoveatedRendering: true,
        refreshRate: 90,
        renderScale: 1.0
    )

    public static func forQuest() -> OpenXRConfiguration {
        var config = OpenXRConfiguration.default
        config.refreshRate = 120
        config.enablePassthrough = true
        return config
    }

    public static func forSteamVR() -> OpenXRConfiguration {
        var config = OpenXRConfiguration.default
        config.refreshRate = 144
        return config
    }

    public static func forWindowsMR() -> OpenXRConfiguration {
        var config = OpenXRConfiguration.default
        config.refreshRate = 90
        return config
    }
}

// MARK: - OpenXR Engine

@MainActor
public final class OpenXREngine: ObservableObject {
    public static let shared = OpenXREngine()

    // MARK: Published State

    @Published public private(set) var isInitialized = false
    @Published public private(set) var isSessionActive = false
    @Published public private(set) var sessionState: OpenXRSessionState = .unknown
    @Published public private(set) var detectedRuntime: OpenXRRuntime = .unknown
    @Published public private(set) var currentFrame: OpenXRFrame?
    @Published public private(set) var leftHand: OpenXRHand?
    @Published public private(set) var rightHand: OpenXRHand?
    @Published public private(set) var eyeTracking: OpenXREyeTracking?
    @Published public private(set) var supportedRefreshRates: [Float] = []
    @Published public private(set) var currentRefreshRate: Float = 90
    @Published public private(set) var supportedExtensions: [String] = []

    // MARK: Configuration

    public var configuration: OpenXRConfiguration = .default
    public var passthrough: OpenXRPassthrough = .default
    public var foveatedRendering: OpenXRFoveatedRendering = .default

    // MARK: Actions

    private var actionSets: [String: [OpenXRAction]] = [:]
    private var defaultActions: [OpenXRAction] = []

    // MARK: Callbacks

    public var onSessionStateChanged: ((OpenXRSessionState) -> Void)?
    public var onFrameReady: ((OpenXRFrame) -> Void)?
    public var onHandTrackingUpdated: ((OpenXRHand, OpenXRHand) -> Void)?
    public var onEyeTrackingUpdated: ((OpenXREyeTracking) -> Void)?
    public var onActionTriggered: ((String, OpenXRFrame.ActionState) -> Void)?

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var frameTimer: Timer?

    // MARK: Initialization

    private init() {
        setupDefaultActions()
    }

    // MARK: - Initialization

    /// Initialize OpenXR runtime
    public func initialize(config: OpenXRConfiguration = .default) async throws {
        configuration = config

        // Detect runtime
        detectedRuntime = detectRuntime()

        // Get supported extensions
        supportedExtensions = getSupportedExtensions()

        // Get supported refresh rates
        supportedRefreshRates = getSupportedRefreshRates()

        isInitialized = true
    }

    /// Create OpenXR session
    public func createSession() async throws {
        guard isInitialized else {
            throw OpenXRError.notInitialized
        }

        // Create session with configuration
        try await createOpenXRSession()

        isSessionActive = true
        sessionState = .ready

        // Start frame loop
        startFrameLoop()
    }

    /// End OpenXR session
    public func endSession() async {
        stopFrameLoop()

        isSessionActive = false
        sessionState = .exiting
    }

    // MARK: - Runtime Detection

    private func detectRuntime() -> OpenXRRuntime {
        // In a real implementation, this would query the OpenXR runtime
        // For now, return based on available hints

        #if os(Windows)
        // Check for Oculus runtime first, then WMR, then SteamVR
        return .steamVR
        #elseif os(Linux)
        return .monado
        #else
        // Simulation mode
        return .metaQuest
        #endif
    }

    private func getSupportedExtensions() -> [String] {
        // Would query xrEnumerateInstanceExtensionProperties
        var extensions = [
            "XR_KHR_opengl_enable",
            "XR_KHR_vulkan_enable",
            "XR_EXT_debug_utils"
        ]

        if detectedRuntime.supportsHandTracking {
            extensions.append("XR_EXT_hand_tracking")
        }

        if detectedRuntime.supportsEyeTracking {
            extensions.append("XR_EXT_eye_gaze_interaction")
        }

        if detectedRuntime.supportsPassthrough {
            extensions.append("XR_FB_passthrough")
        }

        if detectedRuntime.supportsFoveatedRendering {
            extensions.append("XR_FB_foveation")
            extensions.append("XR_FB_foveation_configuration")
        }

        return extensions
    }

    private func getSupportedRefreshRates() -> [Float] {
        switch detectedRuntime {
        case .metaQuest:
            return [72, 80, 90, 120]
        case .steamVR:
            return [80, 90, 120, 144]
        case .varjo:
            return [90, 200]
        case .pico:
            return [72, 90]
        default:
            return [90]
        }
    }

    // MARK: - Session Management

    private func createOpenXRSession() async throws {
        // Would call xrCreateSession with appropriate graphics binding
        // This is a simulation for cross-platform compatibility
    }

    // MARK: - Frame Loop

    private func startFrameLoop() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(currentRefreshRate), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processFrame()
            }
        }
    }

    private func stopFrameLoop() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    private func processFrame() {
        guard isSessionActive else { return }

        // In real implementation:
        // 1. xrWaitFrame
        // 2. xrBeginFrame
        // 3. xrLocateViews
        // 4. Render
        // 5. xrEndFrame

        let frame = simulateFrame()
        currentFrame = frame

        // Update tracking data
        leftHand = frame.leftHand
        rightHand = frame.rightHand
        eyeTracking = frame.eyeTracking

        // Callbacks
        onFrameReady?(frame)

        if let left = frame.leftHand, let right = frame.rightHand {
            onHandTrackingUpdated?(left, right)
        }

        if let eyes = frame.eyeTracking {
            onEyeTrackingUpdated?(eyes)
        }

        // Check action states
        for (name, state) in frame.actionStates {
            onActionTriggered?(name, state)
        }
    }

    private func simulateFrame() -> OpenXRFrame {
        // Simulate frame data for testing
        let now = Int64(Date().timeIntervalSince1970 * 1_000_000_000) // nanoseconds

        var frame = OpenXRFrame(
            displayTime: now,
            predictedDisplayTime: now + 11_111_111, // ~11ms for 90Hz
            views: [
                OpenXRFrame.OpenXRView(
                    eye: .left,
                    pose: OpenXRPose(position: SIMD3<Float>(-0.032, 1.6, 0)),
                    fov: OpenXRFrame.OpenXRView.FieldOfView(
                        angleLeft: -0.785, angleRight: 0.785,
                        angleUp: 0.785, angleDown: -0.785
                    ),
                    projectionMatrix: matrix_identity_float4x4
                ),
                OpenXRFrame.OpenXRView(
                    eye: .right,
                    pose: OpenXRPose(position: SIMD3<Float>(0.032, 1.6, 0)),
                    fov: OpenXRFrame.OpenXRView.FieldOfView(
                        angleLeft: -0.785, angleRight: 0.785,
                        angleUp: 0.785, angleDown: -0.785
                    ),
                    projectionMatrix: matrix_identity_float4x4
                )
            ],
            headPose: OpenXRPose(position: SIMD3<Float>(0, 1.6, 0)),
            leftHand: configuration.enableHandTracking ? OpenXRHand(handedness: .left) : nil,
            rightHand: configuration.enableHandTracking ? OpenXRHand(handedness: .right) : nil,
            eyeTracking: nil,
            actionStates: [:]
        )

        if configuration.enableEyeTracking {
            frame.eyeTracking = OpenXREyeTracking(
                leftEyePose: OpenXRPose(),
                rightEyePose: OpenXRPose(),
                combinedGaze: OpenXRPose(),
                leftPupilDilation: 3.5,
                rightPupilDilation: 3.5,
                isTracked: true,
                confidence: 0.95
            )
        }

        return frame
    }

    // MARK: - Actions

    private func setupDefaultActions() {
        defaultActions = [
            OpenXRAction(
                id: UUID(),
                name: "trigger",
                type: .floatInput,
                bindings: [
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/left/input/trigger/value"
                    ),
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/right/input/trigger/value"
                    )
                ]
            ),
            OpenXRAction(
                id: UUID(),
                name: "grip",
                type: .floatInput,
                bindings: [
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/left/input/squeeze/value"
                    ),
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/right/input/squeeze/value"
                    )
                ]
            ),
            OpenXRAction(
                id: UUID(),
                name: "thumbstick",
                type: .vector2fInput,
                bindings: [
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/left/input/thumbstick"
                    ),
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/right/input/thumbstick"
                    )
                ]
            ),
            OpenXRAction(
                id: UUID(),
                name: "haptic",
                type: .vibrationOutput,
                bindings: [
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/left/output/haptic"
                    ),
                    OpenXRAction.ActionBinding(
                        interactionProfile: OpenXRAction.ActionBinding.metaQuestTouch,
                        binding: "/user/hand/right/output/haptic"
                    )
                ]
            )
        ]

        actionSets["default"] = defaultActions
    }

    /// Register custom action set
    public func registerActionSet(_ name: String, actions: [OpenXRAction]) {
        actionSets[name] = actions
    }

    // MARK: - Passthrough Control

    /// Enable passthrough mode
    public func enablePassthrough(_ mode: OpenXRPassthrough.PassthroughMode = .fullEnvironment) {
        guard detectedRuntime.supportsPassthrough else { return }

        passthrough.isEnabled = true
        passthrough.mode = mode
    }

    /// Disable passthrough mode
    public func disablePassthrough() {
        passthrough.isEnabled = false
    }

    /// Set passthrough parameters
    public func setPassthroughParameters(
        opacity: Float? = nil,
        brightness: Float? = nil,
        contrast: Float? = nil,
        saturation: Float? = nil
    ) {
        if let opacity = opacity { passthrough.opacity = opacity }
        if let brightness = brightness { passthrough.brightness = brightness }
        if let contrast = contrast { passthrough.contrast = contrast }
        if let saturation = saturation { passthrough.saturation = saturation }
    }

    // MARK: - Foveated Rendering

    /// Set foveated rendering level
    public func setFoveatedRendering(level: OpenXRFoveatedRendering.FoveationLevel, dynamic: Bool = true) {
        guard detectedRuntime.supportsFoveatedRendering else { return }

        foveatedRendering.isEnabled = level != .off
        foveatedRendering.level = level
        foveatedRendering.dynamic = dynamic
    }

    // MARK: - Refresh Rate

    /// Set display refresh rate
    public func setRefreshRate(_ rate: Float) {
        guard supportedRefreshRates.contains(rate) else { return }

        currentRefreshRate = rate

        // Restart frame loop with new rate
        if isSessionActive {
            stopFrameLoop()
            startFrameLoop()
        }
    }

    // MARK: - Haptics

    /// Trigger haptic feedback
    public func triggerHaptic(
        hand: OpenXRHand.Handedness,
        amplitude: Float,
        duration: TimeInterval,
        frequency: Float = 0 // 0 = default frequency
    ) {
        // Would call xrApplyHapticFeedback
        print("Haptic: \(hand) amplitude=\(amplitude) duration=\(duration)")
    }

    // MARK: - Content Loading

    /// Load immersive content for OpenXR
    public func loadContent(_ content: ImmersiveContent) async throws {
        guard isSessionActive else {
            throw OpenXRError.sessionNotActive
        }

        // Prepare content for OpenXR rendering
        // This would set up the appropriate render pipeline
    }

    /// Export content for specific OpenXR runtime
    public func exportForRuntime(_ content: ImmersiveContent, runtime: OpenXRRuntime) -> ExportedContent {
        var exported = ExportedContent(
            format: determineOptimalFormat(for: runtime),
            resolution: determineOptimalResolution(for: runtime),
            codec: determineOptimalCodec(for: runtime),
            spatialAudio: true
        )

        // Add runtime-specific metadata
        switch runtime {
        case .metaQuest:
            exported.additionalMetadata["foveation"] = "dynamic"
            exported.additionalMetadata["asw"] = "enabled"
        case .steamVR:
            exported.additionalMetadata["motionSmoothing"] = "enabled"
        case .varjo:
            exported.additionalMetadata["foveatedRendering"] = "ultra"
            exported.additionalMetadata["humanEye"] = "enabled"
        default:
            break
        }

        return exported
    }

    private func determineOptimalFormat(for runtime: OpenXRRuntime) -> String {
        switch runtime {
        case .metaQuest:
            return "equirect180_stereo"
        case .varjo:
            return "cubemap_stereo"
        default:
            return "equirect360"
        }
    }

    private func determineOptimalResolution(for runtime: OpenXRRuntime) -> (Int, Int) {
        switch runtime {
        case .metaQuest:
            return (5760, 2880) // 2880×2880 per eye
        case .varjo:
            return (7680, 4320) // 8K
        case .pico:
            return (4320, 2160)
        default:
            return (4096, 2048)
        }
    }

    private func determineOptimalCodec(for runtime: OpenXRRuntime) -> String {
        switch runtime {
        case .metaQuest:
            return "HEVC"
        default:
            return "H.264"
        }
    }
}

// MARK: - Export Types

public struct ExportedContent {
    public var format: String
    public var resolution: (Int, Int)
    public var codec: String
    public var spatialAudio: Bool
    public var additionalMetadata: [String: String] = [:]
}

// MARK: - OpenXR Errors

public enum OpenXRError: Error, LocalizedError {
    case notInitialized
    case sessionNotActive
    case runtimeNotFound
    case extensionNotSupported(String)
    case sessionCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "OpenXR has not been initialized"
        case .sessionNotActive:
            return "No active OpenXR session"
        case .runtimeNotFound:
            return "OpenXR runtime not found"
        case .extensionNotSupported(let ext):
            return "Extension not supported: \(ext)"
        case .sessionCreationFailed(let reason):
            return "Session creation failed: \(reason)"
        }
    }
}

// MARK: - OpenXR Utilities

extension OpenXREngine {
    /// Check if a specific extension is supported
    public func isExtensionSupported(_ extension: String) -> Bool {
        return supportedExtensions.contains(`extension`)
    }

    /// Get runtime-specific performance recommendations
    public func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []

        switch detectedRuntime {
        case .metaQuest:
            recommendations.append("Use Fixed Foveated Rendering at Medium or High level")
            recommendations.append("Enable Application SpaceWarp (ASW) for frame interpolation")
            recommendations.append("Target 72Hz or 90Hz for best battery life")
            recommendations.append("Use MV-HEVC for stereo video playback")

        case .steamVR:
            recommendations.append("Enable Motion Smoothing for frame interpolation")
            recommendations.append("Use per-eye rendering for best quality")
            recommendations.append("Consider VRS (Variable Rate Shading) for complex scenes")

        case .varjo:
            recommendations.append("Leverage ultra-high-resolution focus area")
            recommendations.append("Use eye tracking for gaze-contingent rendering")
            recommendations.append("Enable Human-Eye Resolution mode for text readability")

        case .pico:
            recommendations.append("Target 90Hz for smooth experience")
            recommendations.append("Use HEVC codec for efficient decoding")
            recommendations.append("Enable hand tracking for natural interaction")

        default:
            recommendations.append("Target 90Hz refresh rate")
            recommendations.append("Use stereo rendering for depth perception")
        }

        return recommendations
    }
}

#if DEBUG
extension OpenXREngine {
    /// Simulate hand tracking for testing
    public func simulateHandTracking() {
        var left = OpenXRHand(handedness: .left)
        left.isTracked = true
        left.confidence = 0.95

        // Simulate joint positions
        for joint in OpenXRHand.JointType.allCases {
            left.joints[joint] = OpenXRPose(
                position: SIMD3<Float>(-0.3, 1.0, -0.3),
                isValid: true
            )
        }

        leftHand = left

        var right = OpenXRHand(handedness: .right)
        right.isTracked = true
        right.confidence = 0.95

        for joint in OpenXRHand.JointType.allCases {
            right.joints[joint] = OpenXRPose(
                position: SIMD3<Float>(0.3, 1.0, -0.3),
                isValid: true
            )
        }

        rightHand = right
    }
}
#endif

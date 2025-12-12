import Foundation
import Combine
import CoreHaptics
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// ImmersiveExperienceHub - The Ultimate Unified Multi-Modal Experience Engine
///
/// Combines ALL input/output modalities into a single coherent experience optimized
/// for every Apple hardware device from Apple Watch to Vision Pro.
///
/// **Modalities Integrated:**
/// - Biofeedback (HRV, Heart Rate, Coherence)
/// - Touch (Multi-touch keyboard, XY pads, gesture areas)
/// - Gesture (Hand tracking, 3D gestures)
/// - Mimik/Face (Facial expressions, eye tracking)
/// - Audio (Spatial audio, synthesis, analysis)
/// - Visual (Brainwave entrainment, cymatics, particles)
/// - Haptic (CoreHaptics feedback synchronized to bio rhythms)
///
/// **Brainwave Entrainment:**
/// Uses scientifically-validated frequency translation from bio rhythms to
/// visual/audio stimuli based on the octave transposition principle:
/// - Bio frequencies (0.04-3.5 Hz) → Audio (20-20kHz) → Light (400-750 THz)
///
/// **Hardware Optimization:**
/// - iPhone: Full touch + face tracking + biofeedback
/// - iPad: Expanded touch canvas + Apple Pencil + biofeedback
/// - Apple Watch: HRV monitoring + haptic guidance + simplified visuals
/// - Vision Pro: Full 3D spatial audio + hand/eye tracking + immersive visuals
/// - Mac: Multi-display + external MIDI + DMX lighting
///
/// **Control Loop:** 120 Hz (8.33ms) for low-latency response
@MainActor
public final class ImmersiveExperienceHub: ObservableObject {

    // MARK: - Published State

    /// Current immersive experience mode
    @Published public private(set) var experienceMode: ExperienceMode = .meditation

    /// Overall system coherence (0-100) - combines all input modalities
    @Published public private(set) var systemCoherence: Double = 50.0

    /// Brainwave entrainment target frequency
    @Published public private(set) var entrainmentTargetHz: Double = 10.0  // Alpha

    /// Current dominant brainwave state
    @Published public private(set) var brainwaveState: BrainwaveState = .alpha

    /// Whether the experience is active
    @Published public private(set) var isActive: Bool = false

    /// Current device capabilities
    @Published public private(set) var deviceCapabilities: DeviceCapabilities = .current

    /// Real-time entrainment synchronization score (0-1)
    @Published public private(set) var entrainmentSync: Double = 0.0

    /// Unified visual parameters for all visualizers
    @Published public private(set) var visualParameters: UnifiedVisualParameters = .init()

    /// Unified haptic parameters
    @Published public private(set) var hapticParameters: UnifiedHapticParameters = .init()

    // MARK: - Subsystems

    private var unifiedControlHub: UnifiedControlHub?
    private var healthKitManager: HealthKitManager?
    private var scienceMode: ScienceMode?
    private var keyboardConfiguration: KeyboardConfiguration?

    // Brainwave entrainment components
    private var entrainmentEngine: BrainwaveEntrainmentEngine?
    private var octaveTransposer: OctaveTransposer?

    // Haptic engine for bio-synchronized feedback
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayers: [String: CHHapticPatternPlayer] = [:]

    // MARK: - Control Loop

    private var controlLoopTimer: AnyCancellable?
    private let targetFrequency: Double = 120.0  // 120 Hz for ultra-low latency
    private var lastUpdateTime: Date = Date()
    private var frameCount: UInt64 = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupDeviceCapabilities()
        setupHapticEngine()
        setupEntrainmentEngine()
        EchoelLogger.info("[ImmersiveHub] Initialized for device: \(deviceCapabilities.deviceType)", category: EchoelLogger.system)
    }

    // MARK: - Device Detection & Configuration

    private func setupDeviceCapabilities() {
        deviceCapabilities = DeviceCapabilities.current

        // Log capabilities
        EchoelLogger.info("[ImmersiveHub] Capabilities: Touch=\(deviceCapabilities.hasTouch), Face=\(deviceCapabilities.hasFaceTracking), Hand=\(deviceCapabilities.hasHandTracking), Spatial=\(deviceCapabilities.hasSpatialAudio)", category: EchoelLogger.system)
    }

    private func setupHapticEngine() {
        #if os(iOS) || os(watchOS)
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.playsHapticsOnly = true
            hapticEngine?.stoppedHandler = { [weak self] reason in
                EchoelLogger.warning("[ImmersiveHub] Haptic engine stopped: \(reason)", category: EchoelLogger.system)
                self?.restartHapticEngine()
            }
            try hapticEngine?.start()
            EchoelLogger.info("[ImmersiveHub] Haptic engine started", category: EchoelLogger.system)
        } catch {
            EchoelLogger.warning("[ImmersiveHub] Haptic engine unavailable: \(error.localizedDescription)", category: EchoelLogger.system)
        }
        #endif
    }

    private func restartHapticEngine() {
        #if os(iOS) || os(watchOS)
        try? hapticEngine?.start()
        #endif
    }

    private func setupEntrainmentEngine() {
        entrainmentEngine = BrainwaveEntrainmentEngine()
        octaveTransposer = OctaveTransposer()
    }

    // MARK: - Lifecycle

    /// Start the immersive experience with specified mode
    public func start(mode: ExperienceMode = .meditation) async throws {
        guard !isActive else { return }

        experienceMode = mode

        // Configure entrainment target for mode
        entrainmentTargetHz = mode.targetFrequency
        brainwaveState = mode.targetBrainwaveState

        // Initialize subsystems based on device capabilities
        try await initializeSubsystems()

        // Start control loop
        startControlLoop()

        isActive = true
        EchoelLogger.info("[ImmersiveHub] Started in \(mode) mode, target: \(entrainmentTargetHz) Hz", category: EchoelLogger.system)
    }

    /// Stop the immersive experience
    public func stop() {
        guard isActive else { return }

        controlLoopTimer?.cancel()
        controlLoopTimer = nil

        // Stop subsystems
        unifiedControlHub?.stop()
        scienceMode?.endSession()

        isActive = false
        EchoelLogger.info("[ImmersiveHub] Stopped", category: EchoelLogger.system)
    }

    private func initializeSubsystems() async throws {
        // Initialize UnifiedControlHub
        unifiedControlHub = UnifiedControlHub()

        // Initialize based on device capabilities
        if deviceCapabilities.hasBiofeedback {
            try await unifiedControlHub?.enableBiometricMonitoring()
            healthKitManager = HealthKitManager()
            scienceMode = ScienceMode()
        }

        if deviceCapabilities.hasFaceTracking {
            unifiedControlHub?.enableFaceTracking()
        }

        if deviceCapabilities.hasHandTracking {
            unifiedControlHub?.enableHandTracking()
        }

        if deviceCapabilities.hasSpatialAudio {
            try unifiedControlHub?.enableSpatialAudio()
        }

        unifiedControlHub?.enableVisualMapping()
        unifiedControlHub?.start()
    }

    // MARK: - Control Loop (120 Hz)

    private func startControlLoop() {
        let interval = 1.0 / targetFrequency

        controlLoopTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.controlLoopTick()
            }
    }

    private func controlLoopTick() {
        frameCount += 1

        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        // 1. Gather all input modalities
        let inputState = gatherInputState()

        // 2. Calculate system coherence
        calculateSystemCoherence(from: inputState)

        // 3. Process brainwave entrainment
        processEntrainment(deltaTime: deltaTime)

        // 4. Update visual parameters
        updateVisualParameters(inputState: inputState)

        // 5. Update haptic feedback (every 8th frame = 15 Hz)
        if frameCount % 8 == 0 {
            updateHapticFeedback()
        }

        // 6. Calculate entrainment synchronization
        calculateEntrainmentSync()
    }

    // MARK: - Input Gathering

    private func gatherInputState() -> InputState {
        var state = InputState()

        // Bio signals
        if let healthKit = healthKitManager {
            state.heartRate = healthKit.heartRate
            state.hrvRMSSD = healthKit.hrvRMSSD
            state.hrvCoherence = healthKit.hrvCoherence
        }

        // Science mode data
        if let science = scienceMode {
            state.lfHfRatio = science.hrvAnalysis.lfHfRatio
            state.pnn50 = science.hrvAnalysis.pnn50
        }

        // Face tracking (if available)
        // These would come from UnifiedControlHub subscriptions

        // Touch state (if keyboard is active)
        if let keyboard = keyboardConfiguration {
            state.touchCount = keyboard.configuration.mpeChannelCount
        }

        return state
    }

    // MARK: - Coherence Calculation

    private func calculateSystemCoherence(from input: InputState) {
        // Weighted combination of all coherence sources
        var coherence: Double = 50.0
        var weights: Double = 0.0

        // HRV Coherence (primary - weight 0.5)
        if input.hrvCoherence > 0 {
            coherence += input.hrvCoherence * 0.5
            weights += 0.5
        }

        // LF/HF Ratio coherence (weight 0.2)
        // Optimal LF/HF is around 1.0-2.0 for relaxed alertness
        if input.lfHfRatio > 0 {
            let lfHfCoherence = min(100, max(0, 100 - abs(input.lfHfRatio - 1.5) * 30))
            coherence += lfHfCoherence * 0.2
            weights += 0.2
        }

        // pNN50 contribution (weight 0.15)
        // Higher pNN50 indicates more parasympathetic activity
        if input.pnn50 > 0 {
            let pnn50Coherence = min(100, input.pnn50 * 2)
            coherence += pnn50Coherence * 0.15
            weights += 0.15
        }

        // Touch engagement (weight 0.15)
        if input.touchCount > 0 {
            let touchCoherence = min(100, Double(input.touchCount) * 15)
            coherence += touchCoherence * 0.15
            weights += 0.15
        }

        // Normalize
        if weights > 0 {
            coherence = coherence / weights
        }

        // Smooth transition
        systemCoherence = systemCoherence * 0.9 + coherence * 0.1
    }

    // MARK: - Brainwave Entrainment

    private func processEntrainment(deltaTime: Double) {
        guard let engine = entrainmentEngine else { return }

        // Update entrainment engine with current state
        engine.update(
            targetFrequency: entrainmentTargetHz,
            systemCoherence: systemCoherence,
            deltaTime: deltaTime
        )

        // Get entrainment visual/audio parameters
        let entrainmentOutput = engine.getOutput()

        // Update visual parameters for entrainment
        visualParameters.entrainmentPhase = entrainmentOutput.phase
        visualParameters.entrainmentIntensity = entrainmentOutput.intensity
        visualParameters.flashFrequency = entrainmentOutput.visualFrequency
        visualParameters.binauralBeatFrequency = entrainmentOutput.audioFrequency
    }

    // MARK: - Visual Parameter Updates

    private func updateVisualParameters(inputState: InputState) {
        // Map coherence to visual hue (red = stressed, green = coherent)
        visualParameters.hue = Float(systemCoherence / 100.0) * 0.33  // 0 = red, 0.33 = green

        // Map heart rate to animation speed
        let normalizedHR = (inputState.heartRate - 50) / 100  // Normalize 50-150 BPM to 0-1
        visualParameters.animationSpeed = Float(0.5 + normalizedHR * 1.0)

        // Map HRV to visual complexity
        let normalizedHRV = min(1.0, inputState.hrvRMSSD / 100.0)
        visualParameters.complexity = Float(normalizedHRV)

        // Brainwave state colors
        visualParameters.brainwaveColor = brainwaveState.color

        // Device-specific adjustments
        applyDeviceSpecificVisuals()
    }

    private func applyDeviceSpecificVisuals() {
        switch deviceCapabilities.deviceType {
        case .appleWatch:
            // Simplified visuals for small screen
            visualParameters.particleCount = 50
            visualParameters.layerCount = 2
            visualParameters.useGlow = false

        case .iPhone:
            // Balanced visuals
            visualParameters.particleCount = 200
            visualParameters.layerCount = 4
            visualParameters.useGlow = true

        case .iPad:
            // Enhanced visuals for larger screen
            visualParameters.particleCount = 500
            visualParameters.layerCount = 6
            visualParameters.useGlow = true

        case .visionPro:
            // Full 3D immersive visuals
            visualParameters.particleCount = 1000
            visualParameters.layerCount = 8
            visualParameters.useGlow = true
            visualParameters.use3D = true

        case .mac:
            // High-performance visuals for desktop
            visualParameters.particleCount = 2000
            visualParameters.layerCount = 10
            visualParameters.useGlow = true
        }
    }

    // MARK: - Haptic Feedback

    private func updateHapticFeedback() {
        #if os(iOS) || os(watchOS)
        guard let engine = hapticEngine else { return }

        // Generate haptic pattern synchronized to breathing/HRV
        let breathingPhase = visualParameters.entrainmentPhase
        let intensity = Float(systemCoherence / 100.0)

        // Create gentle pulsing haptic synchronized to entrainment
        do {
            // Intensity follows entrainment phase (like breathing)
            let hapticIntensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: intensity * Float(sin(breathingPhase * .pi * 2) * 0.5 + 0.5)
            )

            let hapticSharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: 0.3  // Gentle, not sharp
            )

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [hapticIntensity, hapticSharpness],
                relativeTime: 0,
                duration: 0.1
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptic feedback is optional, don't log errors frequently
        }
        #endif
    }

    // MARK: - Entrainment Synchronization

    private func calculateEntrainmentSync() {
        guard let engine = entrainmentEngine else { return }

        // Compare target vs actual brainwave frequency
        // This would use EEG data if available, or estimate from HRV/coherence
        let estimatedUserFrequency = estimateUserBrainwaveFrequency()
        let targetFrequency = entrainmentTargetHz

        // Calculate sync as inverse of frequency difference
        let frequencyDiff = abs(estimatedUserFrequency - targetFrequency)
        let maxDiff: Double = 10.0  // Max expected difference

        entrainmentSync = max(0, 1.0 - frequencyDiff / maxDiff)
    }

    private func estimateUserBrainwaveFrequency() -> Double {
        // Estimate dominant brainwave from HRV and coherence
        // High coherence + low HR suggests alpha/theta
        // Low coherence + high HR suggests beta

        let coherence = systemCoherence
        let heartRate = healthKitManager?.heartRate ?? 70

        if coherence > 70 && heartRate < 65 {
            return 8.0  // Alpha
        } else if coherence > 60 && heartRate < 75 {
            return 10.0  // Alpha
        } else if coherence > 50 {
            return 12.0  // Low Beta
        } else if coherence > 30 {
            return 18.0  // Beta
        } else {
            return 25.0  // High Beta (stress)
        }
    }

    // MARK: - Mode Switching

    /// Switch to a different experience mode
    public func switchMode(to mode: ExperienceMode) {
        experienceMode = mode
        entrainmentTargetHz = mode.targetFrequency
        brainwaveState = mode.targetBrainwaveState

        EchoelLogger.info("[ImmersiveHub] Switched to \(mode) mode, target: \(entrainmentTargetHz) Hz", category: EchoelLogger.system)
    }

    /// Adjust entrainment target frequency manually
    public func setEntrainmentTarget(frequency: Double) {
        entrainmentTargetHz = max(0.5, min(100, frequency))
        brainwaveState = BrainwaveState.fromFrequency(frequency)

        EchoelLogger.info("[ImmersiveHub] Manual target set: \(entrainmentTargetHz) Hz (\(brainwaveState))", category: EchoelLogger.system)
    }
}

// MARK: - Supporting Types

extension ImmersiveExperienceHub {

    /// Experience modes with scientifically-validated target frequencies
    public enum ExperienceMode: String, CaseIterable {
        case deepSleep = "Deep Sleep"          // Delta: 0.5-4 Hz
        case meditation = "Meditation"          // Theta: 4-8 Hz
        case relaxation = "Relaxation"          // Alpha: 8-12 Hz
        case focus = "Focus"                    // Low Beta: 12-15 Hz
        case performance = "Performance"        // Mid Beta: 15-20 Hz
        case creativity = "Creativity"          // Alpha-Theta: 7-10 Hz
        case healing = "Healing"                // Schumann: 7.83 Hz
        case flow = "Flow State"                // Alpha-Gamma: 10-40 Hz mixed

        var targetFrequency: Double {
            switch self {
            case .deepSleep: return 2.0
            case .meditation: return 6.0
            case .relaxation: return 10.0
            case .focus: return 14.0
            case .performance: return 18.0
            case .creativity: return 8.0
            case .healing: return 7.83
            case .flow: return 10.0
            }
        }

        var targetBrainwaveState: BrainwaveState {
            switch self {
            case .deepSleep: return .delta
            case .meditation: return .theta
            case .relaxation, .creativity, .healing, .flow: return .alpha
            case .focus, .performance: return .beta
            }
        }
    }

    /// Brainwave states with frequency ranges
    public enum BrainwaveState: String, CaseIterable {
        case delta = "Delta"    // 0.5-4 Hz
        case theta = "Theta"    // 4-8 Hz
        case alpha = "Alpha"    // 8-12 Hz
        case beta = "Beta"      // 12-30 Hz
        case gamma = "Gamma"    // 30-100 Hz

        static func fromFrequency(_ freq: Double) -> BrainwaveState {
            switch freq {
            case 0..<4: return .delta
            case 4..<8: return .theta
            case 8..<12: return .alpha
            case 12..<30: return .beta
            default: return .gamma
            }
        }

        var color: (r: Float, g: Float, b: Float) {
            switch self {
            case .delta: return (0.2, 0.2, 0.8)  // Deep blue
            case .theta: return (0.4, 0.2, 0.8)  // Purple
            case .alpha: return (0.2, 0.8, 0.4)  // Green
            case .beta: return (0.8, 0.8, 0.2)   // Yellow
            case .gamma: return (0.8, 0.2, 0.2)  // Red
            }
        }

        var frequencyRange: ClosedRange<Double> {
            switch self {
            case .delta: return 0.5...4.0
            case .theta: return 4.0...8.0
            case .alpha: return 8.0...12.0
            case .beta: return 12.0...30.0
            case .gamma: return 30.0...100.0
            }
        }
    }

    /// Device capabilities detection
    public struct DeviceCapabilities {
        public let deviceType: DeviceType
        public let hasTouch: Bool
        public let hasFaceTracking: Bool
        public let hasHandTracking: Bool
        public let hasSpatialAudio: Bool
        public let hasBiofeedback: Bool
        public let hasHaptics: Bool
        public let screenSize: CGSize
        public let maxFrameRate: Int

        public static var current: DeviceCapabilities {
            #if os(watchOS)
            return DeviceCapabilities(
                deviceType: .appleWatch,
                hasTouch: true,
                hasFaceTracking: false,
                hasHandTracking: false,
                hasSpatialAudio: false,
                hasBiofeedback: true,  // Watch has best HRV
                hasHaptics: true,
                screenSize: CGSize(width: 198, height: 242),
                maxFrameRate: 60
            )
            #elseif os(visionOS)
            return DeviceCapabilities(
                deviceType: .visionPro,
                hasTouch: false,
                hasFaceTracking: true,
                hasHandTracking: true,
                hasSpatialAudio: true,
                hasBiofeedback: false,
                hasHaptics: false,
                screenSize: CGSize(width: 3660, height: 3200),
                maxFrameRate: 90
            )
            #elseif os(macOS)
            return DeviceCapabilities(
                deviceType: .mac,
                hasTouch: false,
                hasFaceTracking: true,  // Via webcam
                hasHandTracking: true,  // Via webcam
                hasSpatialAudio: true,
                hasBiofeedback: true,   // Via Apple Watch
                hasHaptics: false,
                screenSize: CGSize(width: 2560, height: 1440),
                maxFrameRate: 120
            )
            #elseif os(iOS)
            // Detect iPhone vs iPad
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let screen = UIScreen.main.bounds.size

            return DeviceCapabilities(
                deviceType: isIPad ? .iPad : .iPhone,
                hasTouch: true,
                hasFaceTracking: true,  // TrueDepth camera
                hasHandTracking: true,  // Via Vision
                hasSpatialAudio: true,
                hasBiofeedback: true,   // Via HealthKit/Watch
                hasHaptics: true,
                screenSize: screen,
                maxFrameRate: isIPad ? 120 : 120  // ProMotion
            )
            #else
            return DeviceCapabilities(
                deviceType: .iPhone,
                hasTouch: true,
                hasFaceTracking: false,
                hasHandTracking: false,
                hasSpatialAudio: false,
                hasBiofeedback: false,
                hasHaptics: false,
                screenSize: CGSize(width: 390, height: 844),
                maxFrameRate: 60
            )
            #endif
        }
    }

    public enum DeviceType: String {
        case iPhone = "iPhone"
        case iPad = "iPad"
        case appleWatch = "Apple Watch"
        case visionPro = "Vision Pro"
        case mac = "Mac"
    }

    /// Aggregated input state from all modalities
    struct InputState {
        var heartRate: Double = 70
        var hrvRMSSD: Double = 50
        var hrvCoherence: Double = 50
        var lfHfRatio: Double = 1.0
        var pnn50: Double = 20
        var touchCount: Int = 0
        var faceJawOpen: Float = 0
        var faceSmile: Float = 0
        var gestureType: String = "none"
    }

    /// Unified visual parameters for all visualizers
    public struct UnifiedVisualParameters {
        // Colors
        public var hue: Float = 0.33
        public var saturation: Float = 0.8
        public var brightness: Float = 1.0
        public var brainwaveColor: (r: Float, g: Float, b: Float) = (0.2, 0.8, 0.4)

        // Animation
        public var animationSpeed: Float = 1.0
        public var entrainmentPhase: Double = 0.0
        public var entrainmentIntensity: Double = 0.5
        public var flashFrequency: Double = 10.0
        public var binauralBeatFrequency: Double = 10.0

        // Complexity
        public var complexity: Float = 0.5
        public var particleCount: Int = 200
        public var layerCount: Int = 4

        // Effects
        public var useGlow: Bool = true
        public var use3D: Bool = false
    }

    /// Unified haptic parameters
    public struct UnifiedHapticParameters {
        public var intensity: Float = 0.5
        public var sharpness: Float = 0.3
        public var rhythmFrequency: Double = 6.0  // Breathing rate
        public var enabled: Bool = true
    }
}

// MARK: - Brainwave Entrainment Engine

/// Physics-based brainwave entrainment using octave transposition
final class BrainwaveEntrainmentEngine {

    private var phase: Double = 0.0
    private var intensity: Double = 0.5

    struct EntrainmentOutput {
        let phase: Double
        let intensity: Double
        let visualFrequency: Double
        let audioFrequency: Double
    }

    func update(targetFrequency: Double, systemCoherence: Double, deltaTime: Double) {
        // Advance phase based on target frequency
        phase += targetFrequency * deltaTime
        phase = phase.truncatingRemainder(dividingBy: 1.0)

        // Intensity increases with coherence (user is responding to entrainment)
        intensity = intensity * 0.95 + (systemCoherence / 100.0) * 0.05
    }

    func getOutput() -> EntrainmentOutput {
        // Octave transposition: bio (0.04-3.5 Hz) → audio (20-20kHz) → light (400-750 THz)
        let octaveTransposer = OctaveTransposer()

        // For visual flashing, use the direct bio frequency (safe range 1-30 Hz)
        // Note: Frequencies 15-25 Hz should be avoided for photosensitive individuals
        let safeVisualFreq = min(14.0, max(1.0, phase * 14.0))

        // For audio, transpose to audible range
        let audioFreq = octaveTransposer.bioToAudio(bioFrequency: phase * 10.0)

        return EntrainmentOutput(
            phase: phase,
            intensity: intensity,
            visualFrequency: safeVisualFreq,
            audioFrequency: audioFreq
        )
    }
}

// MARK: - Octave Transposer

/// Translates frequencies between biological, audio, and light domains
/// Based on the physics of octave relationships
final class OctaveTransposer {

    // Constants
    private let bioMin: Double = 0.04    // 0.04 Hz (HRV lower bound)
    private let bioMax: Double = 3.5     // 3.5 Hz (breathing upper bound)
    private let audioMin: Double = 20.0  // 20 Hz (hearing lower bound)
    private let audioMax: Double = 20000.0  // 20 kHz (hearing upper bound)
    private let lightMin: Double = 400e12   // 400 THz (red light)
    private let lightMax: Double = 750e12   // 750 THz (violet light)

    /// Transpose bio frequency to audible frequency
    func bioToAudio(bioFrequency: Double) -> Double {
        // Calculate octaves needed to reach audio range
        // Each octave doubles the frequency
        let octavesNeeded = log2(audioMin / bioFrequency)
        return bioFrequency * pow(2, ceil(octavesNeeded))
    }

    /// Transpose audio frequency to light frequency
    func audioToLight(audioFrequency: Double) -> Double {
        // Map audio logarithmically to visible light spectrum
        let audioLog = log2(audioFrequency / audioMin)
        let audioRange = log2(audioMax / audioMin)
        let normalized = audioLog / audioRange

        // Map to light spectrum (logarithmic scale)
        let lightLog = log2(lightMin) + normalized * (log2(lightMax) - log2(lightMin))
        return pow(2, lightLog)
    }

    /// Convert light frequency to wavelength in nanometers
    func frequencyToWavelength(frequency: Double) -> Double {
        let speedOfLight = 299792458.0  // m/s
        return (speedOfLight / frequency) * 1e9  // Convert to nm
    }

    /// Convert wavelength to approximate RGB color
    func wavelengthToRGB(wavelength: Double) -> (r: Float, g: Float, b: Float) {
        var r: Float = 0, g: Float = 0, b: Float = 0

        switch wavelength {
        case 380..<440:
            r = Float((440 - wavelength) / (440 - 380))
            b = 1.0
        case 440..<490:
            g = Float((wavelength - 440) / (490 - 440))
            b = 1.0
        case 490..<510:
            g = 1.0
            b = Float((510 - wavelength) / (510 - 490))
        case 510..<580:
            r = Float((wavelength - 510) / (580 - 510))
            g = 1.0
        case 580..<645:
            r = 1.0
            g = Float((645 - wavelength) / (645 - 580))
        case 645...780:
            r = 1.0
        default:
            break
        }

        return (r, g, b)
    }

    /// Full pipeline: bio → audio → light → color
    func bioToColor(bioFrequency: Double) -> (r: Float, g: Float, b: Float) {
        let audioFreq = bioToAudio(bioFrequency: bioFrequency)
        let lightFreq = audioToLight(audioFrequency: audioFreq)
        let wavelength = frequencyToWavelength(frequency: lightFreq)
        return wavelengthToRGB(wavelength: wavelength)
    }
}

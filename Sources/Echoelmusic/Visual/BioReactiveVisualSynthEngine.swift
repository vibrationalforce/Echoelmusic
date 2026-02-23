// BioReactiveVisualSynthEngine.swift
// Echoelmusic — Unified Bio-Reactive Visual Synthesis Engine
//
// =============================================================================
// The crown jewel of the Echoelmusic visual pipeline. This engine is the unique
// differentiator — no competing product offers real-time biometric-driven
// visual synthesis with professional video output.
//
// Signal Flow:
// ┌─────────────────┐   ┌──────────────────┐
// │ UnifiedHealthKit │   │ UnifiedVisualSnd │
// │    Engine        │   │     Engine       │
// │  (bio signals)   │   │ (audio analysis) │
// └────────┬────────┘   └────────┬─────────┘
//          │                     │
//          └──────────┬──────────┘
//                     ▼
//          ┌──────────────────────┐
//          │ BioReactiveVisualSyn │
//          │   thEngine (60 Hz)   │
//          │                      │
//          │  ┌────────────────┐  │
//          │  │ Modulation     │  │   Bio + Audio → Visual parameters
//          │  │ Matrix         │  │
//          │  └───────┬────────┘  │
//          │          ▼           │
//          │  ┌────────────────┐  │
//          │  │ Scene Manager  │  │   Layer configs, transitions
//          │  └───────┬────────┘  │
//          │          ▼           │
//          │  ┌────────────────┐  │
//          │  │ MetalShader    │  │   GPU rendering
//          │  │ Manager        │  │
//          │  └───────┬────────┘  │
//          └──────────┼──────────┘
//                     ▼
//          ┌──────────────────────┐
//          │  SyphonNDIBridge     │   NDI / Syphon / SMPTE 2110
//          └──────────────────────┘
//
// Bio-Reactive Mapping:
// - Coherence (0-1) → color warmth, geometry, particle organization, blend
// - Heart Rate (BPM) → pulse speed, animation tempo, flash timing
// - Breath Phase (0-1) → scale oscillation, opacity, filter sweep
// - HRV (ms) → complexity/chaos, detail density
//
// Profiles:
// - .meditation   → calming, warm, slow, low complexity
// - .performance  → dynamic, beat-driven, high energy
// - .wellness     → therapeutic, guided breathing overlay
// - .creative     → full manual control, all bio sources exposed
// - .installation → audience-reactive, large-scale projections
// - .djSet        → audio-dominant, bio color accents, drop-triggered scenes
// =============================================================================

import Foundation
import Combine

#if canImport(Metal)
import Metal
#endif

// MARK: - Bio-Reactive Profile

/// Preset profiles that configure how biometric and audio data map to visual parameters.
///
/// Each profile defines the weighting of bio vs. audio sources, the mapping curves,
/// target complexity levels, and default scene configurations.
public enum BioReactiveProfile: String, CaseIterable, Identifiable, Sendable {
    /// Slow, calming visuals. Coherence drives warm colors, breathing drives pulsing scale.
    case meditation = "Meditation"

    /// Dynamic visuals. Heart rate drives speed, audio level drives intensity, beats trigger flashes.
    case performance = "Performance"

    /// Therapeutic visuals. Breathing guide overlay, coherence maps geometry (grid to fibonacci).
    case wellness = "Wellness"

    /// Full artistic control. All bio sources available, manual modulation matrix.
    case creative = "Creative"

    /// Audience-reactive installation. Bio sources from EchoelSync peers, large-scale projections.
    case installation = "Installation"

    /// Beat-driven DJ set. Audio dominant, bio-reactive color accents, scene switching on drops.
    case djSet = "DJ Set"

    public var id: String { rawValue }

    /// Human-readable description of the profile's behavior
    public var profileDescription: String {
        switch self {
        case .meditation:
            return "Slow, calming visuals synced to breathing and coherence. Warm colors emerge as coherence increases."
        case .performance:
            return "Dynamic, energetic visuals driven by heart rate and audio. Beats trigger flashes and transitions."
        case .wellness:
            return "Therapeutic visuals with breathing guide overlay. Geometry shifts from grid to fibonacci as coherence rises."
        case .creative:
            return "Full manual control with all bio sources exposed. Customize every modulation route."
        case .installation:
            return "Audience-reactive visuals for large-scale projections. Aggregates bio data from multiple EchoelSync peers."
        case .djSet:
            return "Audio-dominant visuals with bio-reactive color accents. Scenes switch automatically on beat drops."
        }
    }

    /// Relative weight of bio signals vs audio signals (0 = pure audio, 1 = pure bio)
    public var bioWeight: Float {
        switch self {
        case .meditation: return 0.8
        case .performance: return 0.3
        case .wellness: return 0.7
        case .creative: return 0.5
        case .installation: return 0.6
        case .djSet: return 0.2
        }
    }

    /// Target visual complexity (0 = minimal, 1 = maximum)
    public var targetComplexity: Float {
        switch self {
        case .meditation: return 0.3
        case .performance: return 0.8
        case .wellness: return 0.4
        case .creative: return 0.6
        case .installation: return 0.7
        case .djSet: return 0.9
        }
    }

    /// Base animation speed multiplier
    public var baseAnimationSpeed: Float {
        switch self {
        case .meditation: return 0.3
        case .performance: return 1.2
        case .wellness: return 0.5
        case .creative: return 0.8
        case .installation: return 0.7
        case .djSet: return 1.5
        }
    }
}

// MARK: - Bio State

/// Snapshot of current biometric data used by the visual engine
public struct BioReactiveState: Sendable {
    /// HeartMath-style coherence score (0.0 to 1.0)
    public var coherence: Float = 0.5

    /// Current heart rate in beats per minute
    public var heartRate: Float = 70.0

    /// Current phase of the breathing cycle (0.0 to 1.0, 0 = exhale start, 0.5 = inhale peak)
    public var breathPhase: Float = 0.0

    /// Raw HRV SDNN value in milliseconds
    public var hrvRaw: Float = 50.0

    /// Normalized HRV (0.0 to 1.0)
    public var hrvNormalized: Float = 0.5

    /// Stress index derived from coherence (0.0 = calm, 1.0 = stressed)
    public var stressLevel: Float = 0.5

    /// Coherence trend direction (-1.0 = declining, 0.0 = stable, 1.0 = rising)
    public var coherenceTrend: Float = 0.0

    public init() {}
}

// MARK: - Audio State

/// Snapshot of current audio analysis data used by the visual engine
public struct AudioReactiveState: Sendable {
    /// RMS audio level (0.0 to 1.0)
    public var level: Float = 0.0

    /// 64-band spectrum data
    public var spectrum: [Float] = Array(repeating: 0, count: 64)

    /// Detected tempo in beats per minute
    public var bpm: Float = 120.0

    /// Whether a beat was detected on the current frame
    public var beatDetected: Bool = false

    /// Dominant frequency in Hz
    public var dominantFrequency: Float = 440.0

    /// Spectral centroid (brightness) in Hz
    public var spectralCentroid: Float = 1000.0

    /// Bass energy (0.0 to 1.0)
    public var bassLevel: Float = 0.0

    /// Mid energy (0.0 to 1.0)
    public var midLevel: Float = 0.0

    /// High energy (0.0 to 1.0)
    public var highLevel: Float = 0.0

    /// Beat phase (0.0 to 1.0 within the current beat cycle)
    public var beatPhase: Float = 0.0

    public init() {}
}

// MARK: - Performance Stats

/// Real-time performance metrics for the visual synthesis pipeline
public struct VisualPerformanceStats: Sendable {
    /// Current frames per second
    public var fps: Double = 0

    /// Estimated GPU utilization (0.0 to 1.0)
    public var gpuUsage: Float = 0

    /// Estimated CPU utilization (0.0 to 1.0)
    public var cpuUsage: Float = 0

    /// Current memory usage in megabytes
    public var memoryMB: Float = 0

    /// Control loop tick count since start
    public var tickCount: UInt64 = 0

    /// Average frame time in milliseconds
    public var avgFrameTimeMs: Double = 0

    public init() {}
}

// MARK: - Visual Scene

/// A visual scene defines a complete layer configuration for the compositor.
///
/// Scenes can be triggered manually, via MIDI, by bio-reactive thresholds,
/// or on a timed schedule.
public struct VisualScene: Identifiable, Sendable {
    public let id: String

    /// Human-readable scene name
    public var name: String

    /// Shader type used by MetalShaderManager for this scene
    public var shaderType: String

    /// Base color hue (0.0 to 1.0)
    public var baseHue: Float

    /// Base brightness (0.0 to 1.0)
    public var baseBrightness: Float

    /// Base complexity (0.0 to 1.0)
    public var baseComplexity: Float

    /// Particle count for particle-based scenes
    public var particleCount: Int

    /// Whether coherence modulates geometry type (grid vs fibonacci)
    public var coherenceModulatesGeometry: Bool

    /// Whether heart rate modulates animation speed
    public var heartRateModulatesSpeed: Bool

    /// Whether breath phase modulates opacity/scale
    public var breathModulatesScale: Bool

    /// Whether audio beat triggers visual flash
    public var beatTriggersFlash: Bool

    /// Bio coherence threshold that triggers transition to this scene (nil = manual only)
    public var coherenceTriggerThreshold: Float?

    public init(
        id: String = UUID().uuidString,
        name: String,
        shaderType: String = "bioReactivePulse",
        baseHue: Float = 0.5,
        baseBrightness: Float = 0.7,
        baseComplexity: Float = 0.5,
        particleCount: Int = 5000,
        coherenceModulatesGeometry: Bool = true,
        heartRateModulatesSpeed: Bool = true,
        breathModulatesScale: Bool = true,
        beatTriggersFlash: Bool = true,
        coherenceTriggerThreshold: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.shaderType = shaderType
        self.baseHue = baseHue
        self.baseBrightness = baseBrightness
        self.baseComplexity = baseComplexity
        self.particleCount = particleCount
        self.coherenceModulatesGeometry = coherenceModulatesGeometry
        self.heartRateModulatesSpeed = heartRateModulatesSpeed
        self.breathModulatesScale = breathModulatesScale
        self.beatTriggersFlash = beatTriggersFlash
        self.coherenceTriggerThreshold = coherenceTriggerThreshold
    }
}

// MARK: - Modulation Route

/// A single modulation route that maps a source parameter to a destination parameter.
///
/// Routes define how bio and audio signals modulate visual parameters. The
/// modulation matrix evaluates all routes each frame.
public struct BioReactiveModulationRoute: Identifiable, Sendable {
    public let id: String

    /// Source signal type
    public var source: BioReactiveModulationSource

    /// Destination visual parameter
    public var destination: BioReactiveModulationDestination

    /// Modulation amount (0.0 = no modulation, 1.0 = full range)
    public var amount: Float

    /// Curve applied to the source signal before modulation
    public var curve: BioReactiveModulationCurve

    /// Whether this route is currently active
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        source: BioReactiveModulationSource,
        destination: BioReactiveModulationDestination,
        amount: Float = 1.0,
        curve: BioReactiveModulationCurve = .linear,
        isActive: Bool = true
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.amount = amount
        self.curve = curve
        self.isActive = isActive
    }
}

/// Available modulation source signals
public enum BioReactiveModulationSource: String, CaseIterable, Sendable {
    case coherence = "Coherence"
    case heartRate = "Heart Rate"
    case breathPhase = "Breath Phase"
    case hrvRaw = "HRV Raw"
    case stressLevel = "Stress Level"
    case audioLevel = "Audio Level"
    case bassLevel = "Bass Level"
    case midLevel = "Mid Level"
    case highLevel = "High Level"
    case beatPhase = "Beat Phase"
    case spectralCentroid = "Spectral Centroid"
    case bpm = "BPM"
}

/// Available modulation destination parameters
public enum BioReactiveModulationDestination: String, CaseIterable, Sendable {
    case colorHue = "Color Hue"
    case colorSaturation = "Color Saturation"
    case colorBrightness = "Color Brightness"
    case colorWarmth = "Color Warmth"
    case animationSpeed = "Animation Speed"
    case particleSize = "Particle Size"
    case particleCount = "Particle Count"
    case geometryComplexity = "Geometry Complexity"
    case blendSmoothness = "Blend Smoothness"
    case scaleOscillation = "Scale Oscillation"
    case opacityPulse = "Opacity Pulse"
    case filterSweep = "Filter Sweep"
    case flashIntensity = "Flash Intensity"
    case detailAmount = "Detail Amount"
    case chaosLevel = "Chaos Level"
}

/// Curve shapes for modulation mapping
public enum BioReactiveModulationCurve: String, CaseIterable, Sendable {
    case linear = "Linear"
    case exponential = "Exponential"
    case logarithmic = "Logarithmic"
    case sCurve = "S-Curve"
    case inverseLinear = "Inverse Linear"
    case stepped = "Stepped"

    /// Apply the curve to a normalized input value (0.0 to 1.0)
    public func apply(to value: Float) -> Float {
        let clamped = Swift.max(0, Swift.min(1, value))
        switch self {
        case .linear:
            return clamped
        case .exponential:
            return clamped * clamped
        case .logarithmic:
            // Use Foundation.log to avoid shadowing by the global `log` logger
            return clamped > 0 ? Float(Foundation.log(Double(clamped) * (M_E - 1) + 1)) : 0
        case .sCurve:
            // Hermite S-curve: 3t^2 - 2t^3
            return clamped * clamped * (3.0 - 2.0 * clamped)
        case .inverseLinear:
            return 1.0 - clamped
        case .stepped:
            // Quantize to 8 steps
            return Float(Int(clamped * 8)) / 8.0
        }
    }
}

// MARK: - Scene Transition

/// Describes a transition between two visual scenes
public struct BioReactiveSceneTransition {
    /// Target scene to transition to
    public let targetScene: VisualScene

    /// Duration of the crossfade in seconds
    public let duration: TimeInterval

    /// Progress of the transition (0.0 = source scene, 1.0 = target scene)
    public var progress: Float = 0

    /// Start time of the transition
    public let startTime: Date

    public init(targetScene: VisualScene, duration: TimeInterval) {
        self.targetScene = targetScene
        self.duration = duration
        self.startTime = Date()
    }
}

// MARK: - Modulated Visual Parameters

/// The final computed visual parameters after all modulation routes are evaluated.
/// These values are applied directly to the rendering pipeline each frame.
struct ModulatedVisualParameters {
    var colorHue: Float = 0.5
    var colorSaturation: Float = 0.8
    var colorBrightness: Float = 0.7
    var colorWarmth: Float = 0.5
    var animationSpeed: Float = 1.0
    var particleSize: Float = 1.0
    var particleCountMultiplier: Float = 1.0
    var geometryComplexity: Float = 0.5
    var blendSmoothness: Float = 0.5
    var scaleOscillation: Float = 0.0
    var opacityPulse: Float = 1.0
    var filterSweep: Float = 0.5
    var flashIntensity: Float = 0.0
    var detailAmount: Float = 0.5
    var chaosLevel: Float = 0.3
}

// MARK: - Bio-Reactive Visual Synth Engine

/// The unified Bio-Reactive Visual Synthesis engine that orchestrates biometric and
/// audio data into real-time visual output.
///
/// This is the central coordinator of the Echoelmusic visual pipeline. Each frame at
/// 60 Hz, it:
/// 1. Reads bio data from `UnifiedHealthKitEngine`
/// 2. Reads audio data from `UnifiedVisualSoundEngine`
/// 3. Evaluates modulation routes to compute visual parameter values
/// 4. Applies modulated parameters to the active scene configuration
/// 5. Triggers Metal shader rendering via `MetalShaderManager`
/// 6. Routes the rendered frame to outputs via `SyphonNDIBridge`
///
/// Usage:
/// ```swift
/// let engine = BioReactiveVisualSynthEngine()
/// engine.connectBioSource(UnifiedHealthKitEngine.shared)
/// engine.connectAudioSource(visualSoundEngine)
/// engine.loadProfile(.meditation)
/// engine.start()
/// ```
@MainActor
public final class BioReactiveVisualSynthEngine: ObservableObject {

    // MARK: - Published State

    /// Currently active bio-reactive profile
    @Published public private(set) var currentProfile: BioReactiveProfile = .creative

    /// Whether the engine is running its 60 Hz control loop
    @Published public private(set) var isRunning: Bool = false

    /// Current snapshot of biometric data
    @Published public private(set) var bioState: BioReactiveState = BioReactiveState()

    /// Current snapshot of audio analysis data
    @Published public private(set) var audioState: AudioReactiveState = AudioReactiveState()

    /// Real-time performance metrics
    @Published public private(set) var performanceStats: VisualPerformanceStats = VisualPerformanceStats()

    /// Currently active visual scene
    @Published public private(set) var currentScene: VisualScene

    /// All available scenes
    @Published public var scenes: [VisualScene] = []

    /// Active modulation routes
    @Published public var modulationRoutes: [BioReactiveModulationRoute] = []

    /// In-progress scene transition (nil if no transition is active)
    @Published public private(set) var activeTransition: BioReactiveSceneTransition?

    /// Whether output to video protocols is active
    @Published public private(set) var isOutputActive: Bool = false

    // MARK: - Engine References

    /// Connected bio data source (UnifiedHealthKitEngine)
    private weak var bioSource: UnifiedHealthKitEngine?

    /// Connected audio analysis source (UnifiedVisualSoundEngine)
    private var audioSource: UnifiedVisualSoundEngine?

    /// Syphon/NDI output bridge
    private var outputBridge: SyphonNDIBridge?

    // MARK: - Internal State

    /// Computed visual parameters after modulation
    private var modulatedParams = ModulatedVisualParameters()

    /// Animation time accumulator
    private var animationTime: Double = 0

    /// Timestamp of the last control loop tick
    private var lastTickTime: CFAbsoluteTime = 0

    /// Frame time history for FPS calculation
    private var frameTimeHistory: [Double] = []
    private let frameTimeHistorySize: Int = 60

    /// Beat flash decay counter
    private var beatFlashDecay: Float = 0

    /// Previous coherence value for trend calculation
    private var previousCoherence: Float = 0.5

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()
    private var controlLoopTimer: Timer?
    private var displayLinkToken: CrossPlatformDisplayLink.Token?
    private var busSubscription: BusSubscription?

    // MARK: - Default Scenes

    /// Creates the built-in default scene set
    private static func createDefaultScenes() -> [VisualScene] {
        [
            VisualScene(
                id: "scene-meditation-glow",
                name: "Meditation Glow",
                shaderType: "bioReactivePulse",
                baseHue: 0.08,
                baseBrightness: 0.6,
                baseComplexity: 0.2,
                particleCount: 2000,
                coherenceModulatesGeometry: true,
                heartRateModulatesSpeed: false,
                breathModulatesScale: true,
                beatTriggersFlash: false,
                coherenceTriggerThreshold: nil
            ),
            VisualScene(
                id: "scene-fibonacci-flow",
                name: "Fibonacci Flow",
                shaderType: "mandala",
                baseHue: 0.3,
                baseBrightness: 0.7,
                baseComplexity: 0.6,
                particleCount: 5000,
                coherenceModulatesGeometry: true,
                heartRateModulatesSpeed: true,
                breathModulatesScale: true,
                beatTriggersFlash: false,
                coherenceTriggerThreshold: 0.7
            ),
            VisualScene(
                id: "scene-cymatics-pulse",
                name: "Cymatics Pulse",
                shaderType: "cymatics",
                baseHue: 0.55,
                baseBrightness: 0.8,
                baseComplexity: 0.7,
                particleCount: 8000,
                coherenceModulatesGeometry: true,
                heartRateModulatesSpeed: true,
                breathModulatesScale: false,
                beatTriggersFlash: true,
                coherenceTriggerThreshold: nil
            ),
            VisualScene(
                id: "scene-starfield-deep",
                name: "Starfield Deep",
                shaderType: "starfield",
                baseHue: 0.7,
                baseBrightness: 0.5,
                baseComplexity: 0.4,
                particleCount: 10000,
                coherenceModulatesGeometry: false,
                heartRateModulatesSpeed: true,
                breathModulatesScale: true,
                beatTriggersFlash: false,
                coherenceTriggerThreshold: nil
            ),
            VisualScene(
                id: "scene-energy-burst",
                name: "Energy Burst",
                shaderType: "bioReactivePulse",
                baseHue: 0.0,
                baseBrightness: 0.9,
                baseComplexity: 0.9,
                particleCount: 10000,
                coherenceModulatesGeometry: false,
                heartRateModulatesSpeed: true,
                breathModulatesScale: false,
                beatTriggersFlash: true,
                coherenceTriggerThreshold: nil
            ),
            VisualScene(
                id: "scene-aurora-wellness",
                name: "Aurora Wellness",
                shaderType: "perlinNoise",
                baseHue: 0.4,
                baseBrightness: 0.6,
                baseComplexity: 0.3,
                particleCount: 3000,
                coherenceModulatesGeometry: true,
                heartRateModulatesSpeed: false,
                breathModulatesScale: true,
                beatTriggersFlash: false,
                coherenceTriggerThreshold: nil
            )
        ]
    }

    // MARK: - Default Modulation Routes per Profile

    /// Creates the default modulation route set for a given profile
    private static func createDefaultRoutes(for profile: BioReactiveProfile) -> [BioReactiveModulationRoute] {
        switch profile {
        case .meditation:
            return [
                BioReactiveModulationRoute(source: .coherence, destination: .colorWarmth, amount: 0.8, curve: .sCurve),
                BioReactiveModulationRoute(source: .coherence, destination: .geometryComplexity, amount: 0.6, curve: .logarithmic),
                BioReactiveModulationRoute(source: .breathPhase, destination: .scaleOscillation, amount: 0.7, curve: .linear),
                BioReactiveModulationRoute(source: .breathPhase, destination: .opacityPulse, amount: 0.4, curve: .sCurve),
                BioReactiveModulationRoute(source: .heartRate, destination: .animationSpeed, amount: 0.3, curve: .linear),
                BioReactiveModulationRoute(source: .hrvRaw, destination: .blendSmoothness, amount: 0.5, curve: .logarithmic)
            ]

        case .performance:
            return [
                BioReactiveModulationRoute(source: .heartRate, destination: .animationSpeed, amount: 0.8, curve: .linear),
                BioReactiveModulationRoute(source: .audioLevel, destination: .colorBrightness, amount: 0.9, curve: .exponential),
                BioReactiveModulationRoute(source: .beatPhase, destination: .flashIntensity, amount: 1.0, curve: .exponential),
                BioReactiveModulationRoute(source: .bassLevel, destination: .scaleOscillation, amount: 0.7, curve: .linear),
                BioReactiveModulationRoute(source: .spectralCentroid, destination: .colorHue, amount: 0.6, curve: .linear),
                BioReactiveModulationRoute(source: .coherence, destination: .colorSaturation, amount: 0.4, curve: .sCurve),
                BioReactiveModulationRoute(source: .highLevel, destination: .particleSize, amount: 0.5, curve: .exponential)
            ]

        case .wellness:
            return [
                BioReactiveModulationRoute(source: .breathPhase, destination: .scaleOscillation, amount: 0.8, curve: .sCurve),
                BioReactiveModulationRoute(source: .breathPhase, destination: .opacityPulse, amount: 0.6, curve: .sCurve),
                BioReactiveModulationRoute(source: .coherence, destination: .geometryComplexity, amount: 0.7, curve: .logarithmic),
                BioReactiveModulationRoute(source: .coherence, destination: .colorWarmth, amount: 0.8, curve: .sCurve),
                BioReactiveModulationRoute(source: .hrvRaw, destination: .detailAmount, amount: 0.4, curve: .linear),
                BioReactiveModulationRoute(source: .stressLevel, destination: .chaosLevel, amount: 0.5, curve: .inverseLinear)
            ]

        case .creative:
            return [
                BioReactiveModulationRoute(source: .coherence, destination: .colorWarmth, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .heartRate, destination: .animationSpeed, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .breathPhase, destination: .scaleOscillation, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .hrvRaw, destination: .chaosLevel, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .audioLevel, destination: .colorBrightness, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .bassLevel, destination: .flashIntensity, amount: 0.5, curve: .linear),
                BioReactiveModulationRoute(source: .spectralCentroid, destination: .filterSweep, amount: 0.5, curve: .linear)
            ]

        case .installation:
            return [
                BioReactiveModulationRoute(source: .coherence, destination: .colorWarmth, amount: 0.7, curve: .sCurve),
                BioReactiveModulationRoute(source: .coherence, destination: .geometryComplexity, amount: 0.8, curve: .logarithmic),
                BioReactiveModulationRoute(source: .heartRate, destination: .animationSpeed, amount: 0.4, curve: .linear),
                BioReactiveModulationRoute(source: .audioLevel, destination: .colorBrightness, amount: 0.6, curve: .exponential),
                BioReactiveModulationRoute(source: .breathPhase, destination: .opacityPulse, amount: 0.5, curve: .sCurve),
                BioReactiveModulationRoute(source: .hrvRaw, destination: .detailAmount, amount: 0.6, curve: .linear),
                BioReactiveModulationRoute(source: .bassLevel, destination: .scaleOscillation, amount: 0.5, curve: .linear)
            ]

        case .djSet:
            return [
                BioReactiveModulationRoute(source: .audioLevel, destination: .colorBrightness, amount: 1.0, curve: .exponential),
                BioReactiveModulationRoute(source: .bassLevel, destination: .flashIntensity, amount: 0.9, curve: .exponential),
                BioReactiveModulationRoute(source: .bassLevel, destination: .scaleOscillation, amount: 0.8, curve: .linear),
                BioReactiveModulationRoute(source: .beatPhase, destination: .animationSpeed, amount: 0.7, curve: .linear),
                BioReactiveModulationRoute(source: .spectralCentroid, destination: .colorHue, amount: 0.8, curve: .linear),
                BioReactiveModulationRoute(source: .highLevel, destination: .particleSize, amount: 0.6, curve: .exponential),
                BioReactiveModulationRoute(source: .coherence, destination: .colorSaturation, amount: 0.3, curve: .sCurve),
                BioReactiveModulationRoute(source: .midLevel, destination: .filterSweep, amount: 0.7, curve: .linear)
            ]
        }
    }

    // MARK: - Initialization

    public init() {
        let defaultScenes = Self.createDefaultScenes()
        self.scenes = defaultScenes
        self.currentScene = defaultScenes.first ?? VisualScene(name: "Default")
        self.modulationRoutes = Self.createDefaultRoutes(for: .creative)

        subscribeToBus()
    }

    // MARK: - Source Connections

    /// Connects the biometric data source.
    ///
    /// The engine will read coherence, heart rate, HRV, and breathing data from
    /// this source each frame.
    ///
    /// - Parameter source: The UnifiedHealthKitEngine instance to read bio data from
    public func connectBioSource(_ source: UnifiedHealthKitEngine) {
        self.bioSource = source

        log.log(.info, category: .video, "BioReactiveVisualSynth: Bio source connected")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.bio.connected",
            payload: [:]
        ))
    }

    /// Connects the audio analysis source.
    ///
    /// The engine will read FFT spectrum, beat detection, RMS level, and frequency
    /// data from this source each frame.
    ///
    /// - Parameter source: The UnifiedVisualSoundEngine instance to read audio data from
    public func connectAudioSource(_ source: UnifiedVisualSoundEngine) {
        self.audioSource = source

        log.log(.info, category: .video, "BioReactiveVisualSynth: Audio source connected")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.audio.connected",
            payload: [:]
        ))
    }

    // MARK: - Engine Control

    /// Starts the 60 Hz control loop.
    ///
    /// The engine begins reading bio and audio data, evaluating modulation routes,
    /// and rendering frames. Call `connectBioSource` and `connectAudioSource` before
    /// starting for full functionality.
    public func start() {
        guard !isRunning else {
            log.log(.warning, category: .video, "BioReactiveVisualSynth: Already running")
            return
        }

        isRunning = true
        lastTickTime = CFAbsoluteTimeGetCurrent()
        animationTime = 0
        performanceStats = VisualPerformanceStats()

        startControlLoop()

        log.log(.info, category: .video, "BioReactiveVisualSynth: Started with profile '\(currentProfile.rawValue)'")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.started",
            payload: ["profile": currentProfile.rawValue]
        ))
    }

    /// Stops the control loop and all rendering.
    public func stop() {
        guard isRunning else { return }

        // Unsubscribe from display link
        if let token = displayLinkToken {
            CrossPlatformDisplayLink.shared.unsubscribe(token)
            displayLinkToken = nil
        }
        controlLoopTimer?.invalidate()
        controlLoopTimer = nil
        isRunning = false

        // Stop output if active
        if isOutputActive {
            outputBridge?.stopOutput()
            isOutputActive = false
        }

        log.log(.info, category: .video, "BioReactiveVisualSynth: Stopped")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.stopped",
            payload: [:]
        ))
    }

    // MARK: - Profile Management

    /// Loads a bio-reactive profile, reconfiguring all modulation routes and scene defaults.
    ///
    /// - Parameter profile: The profile to activate
    public func loadProfile(_ profile: BioReactiveProfile) {
        currentProfile = profile
        modulationRoutes = Self.createDefaultRoutes(for: profile)

        // Select an appropriate default scene for the profile
        switch profile {
        case .meditation:
            if let scene = scenes.first(where: { $0.id == "scene-meditation-glow" }) {
                currentScene = scene
            }
        case .wellness:
            if let scene = scenes.first(where: { $0.id == "scene-aurora-wellness" }) {
                currentScene = scene
            }
        case .performance:
            if let scene = scenes.first(where: { $0.id == "scene-energy-burst" }) {
                currentScene = scene
            }
        case .djSet:
            if let scene = scenes.first(where: { $0.id == "scene-cymatics-pulse" }) {
                currentScene = scene
            }
        case .installation:
            if let scene = scenes.first(where: { $0.id == "scene-fibonacci-flow" }) {
                currentScene = scene
            }
        case .creative:
            // Keep current scene in creative mode
            break
        }

        log.log(.info, category: .video, "BioReactiveVisualSynth: Profile loaded — '\(profile.rawValue)'")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.profile.loaded",
            payload: ["profile": profile.rawValue]
        ))
    }

    // MARK: - Scene Management

    /// Sets the active visual scene immediately (no transition).
    ///
    /// - Parameter scene: The scene to activate
    public func setScene(_ scene: VisualScene) {
        activeTransition = nil
        currentScene = scene

        log.log(.info, category: .video, "BioReactiveVisualSynth: Scene set — '\(scene.name)'")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.scene.set",
            payload: ["scene": scene.name]
        ))
    }

    /// Triggers a crossfade transition to a new scene over the specified duration.
    ///
    /// - Parameters:
    ///   - scene: The target scene to transition to
    ///   - duration: Duration of the crossfade in seconds (default: 2.0)
    public func triggerTransition(to scene: VisualScene, duration: TimeInterval = 2.0) {
        activeTransition = BioReactiveSceneTransition(targetScene: scene, duration: duration)

        log.log(.info, category: .video, "BioReactiveVisualSynth: Transition started to '\(scene.name)' over \(String(format: "%.1f", duration))s")

        EngineBus.shared.publish(.custom(
            topic: "visual.synth.transition.started",
            payload: ["target": scene.name, "duration": "\(duration)"]
        ))
    }

    // MARK: - Output Control

    /// Starts video output to the specified protocols via SyphonNDIBridge.
    ///
    /// - Parameters:
    ///   - protocols: Set of video network protocols to output to
    ///   - width: Output width in pixels (default: 1920)
    ///   - height: Output height in pixels (default: 1080)
    ///   - fps: Target frames per second (default: 60)
    public func startOutput(
        protocols: Set<VideoNetworkProtocol>,
        width: Int = 1920,
        height: Int = 1080,
        fps: Int = 60
    ) {
        if outputBridge == nil {
            outputBridge = SyphonNDIBridge()
        }

        outputBridge?.startOutput(protocols: protocols, width: width, height: height, fps: fps)
        isOutputActive = true

        log.log(.info, category: .video, "BioReactiveVisualSynth: Output started — \(protocols.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Stops all video output.
    public func stopOutput() {
        outputBridge?.stopOutput()
        isOutputActive = false
    }

    // MARK: - Control Loop

    /// Starts the 60 Hz control loop using CrossPlatformDisplayLink.
    ///
    /// Replaces Timer-based loop with display-synchronized callback for:
    /// - Frame-accurate timing (no timer drift)
    /// - Automatic frame rate adaptation (ProMotion, 120Hz displays)
    /// - Battery-saving idle detection (pauses when no visual changes)
    private func startControlLoop() {
        controlLoopTimer?.invalidate()
        controlLoopTimer = nil

        displayLinkToken = CrossPlatformDisplayLink.shared.subscribe { [weak self] _, _ in
            Task { @MainActor in
                self?.controlLoopTick()
            }
        }
    }

    /// Single tick of the 60 Hz control loop.
    ///
    /// Execution order:
    /// 1. Read bio signals
    /// 2. Read audio analysis
    /// 3. Evaluate modulation matrix
    /// 4. Apply modulated parameters
    /// 5. Check for bio-triggered scene transitions
    /// 6. Update scene transitions
    /// 7. Render frame
    /// 8. Submit to output bridge
    /// 9. Update performance stats
    private func controlLoopTick() {
        guard isRunning else { return }

        let tickStart = CFAbsoluteTimeGetCurrent()
        let deltaTime = tickStart - lastTickTime
        lastTickTime = tickStart

        animationTime += deltaTime

        // 1. Read bio signals
        readBioSignals()

        // 2. Read audio analysis
        readAudioSignals()

        // 3. Evaluate modulation matrix
        evaluateModulationMatrix()

        // 4. Apply modulated parameters to shader manager
        applyModulatedParameters()

        // 5. Check for bio-triggered scene transitions
        checkBioTriggeredTransitions()

        // 6. Update active scene transition
        updateSceneTransition()

        // 7. Render frame via MetalShaderManager
        renderFrame()

        // 8. Submit to output bridge (if active)
        if isOutputActive {
            outputBridge?.submitCompositorFrame()
        }

        // 9. Update performance stats
        updatePerformanceStats(tickStart: tickStart, deltaTime: deltaTime)
    }

    // MARK: - Bio Signal Reading

    /// Reads current biometric data from the connected UnifiedHealthKitEngine
    private func readBioSignals() {
        guard let bio = bioSource else {
            // Use simulated data when no source is connected
            simulateBioSignals()
            return
        }

        previousCoherence = bioState.coherence

        bioState.coherence = Float(bio.coherence)
        bioState.heartRate = Float(bio.heartRate)
        bioState.hrvRaw = Float(bio.hrvSDNN)
        bioState.hrvNormalized = Swift.min(1.0, Float(bio.hrvSDNN) / 100.0)
        bioState.breathPhase = Float((sin(animationTime * 0.5 * Double.pi * 2.0 / 5.0) + 1.0) / 2.0)
        bioState.stressLevel = 1.0 - bioState.coherence

        // Calculate coherence trend
        let delta = bioState.coherence - previousCoherence
        bioState.coherenceTrend = Swift.max(-1.0, Swift.min(1.0, delta * 10.0))
    }

    /// Generates simulated bio data for testing when no hardware source is connected
    private func simulateBioSignals() {
        previousCoherence = bioState.coherence

        // Gentle coherence oscillation
        let coherenceBase: Float = 0.5 + 0.2 * Float(sin(animationTime * 0.1))
        bioState.coherence = Swift.max(0, Swift.min(1, coherenceBase + Float.random(in: -0.02...0.02)))

        // Heart rate around 72 BPM with slight variation
        bioState.heartRate = 72.0 + 5.0 * Float(sin(animationTime * 0.15))

        // Breathing cycle (~12 breaths per minute = 5 second cycle)
        bioState.breathPhase = Float((sin(animationTime * 2.0 * Double.pi / 5.0) + 1.0) / 2.0)

        // HRV simulation
        bioState.hrvRaw = 50.0 + 15.0 * Float(sin(animationTime * 0.08))
        bioState.hrvNormalized = Swift.min(1.0, bioState.hrvRaw / 100.0)

        bioState.stressLevel = 1.0 - bioState.coherence

        let delta = bioState.coherence - previousCoherence
        bioState.coherenceTrend = Swift.max(-1.0, Swift.min(1.0, delta * 10.0))
    }

    // MARK: - Audio Signal Reading

    /// Reads current audio analysis data from the connected UnifiedVisualSoundEngine
    private func readAudioSignals() {
        guard let audio = audioSource else {
            // Use simulated data when no source is connected
            simulateAudioSignals()
            return
        }

        let params = audio.visualParams

        audioState.level = params.audioLevel
        audioState.bassLevel = params.bassTotal
        audioState.midLevel = params.midTotal
        audioState.highLevel = params.highTotal
        audioState.bpm = params.tempo
        audioState.beatDetected = audio.beatDetected
        audioState.dominantFrequency = params.frequency
        audioState.spectralCentroid = params.spectralCentroid
        audioState.beatPhase = params.beatPhase
        audioState.spectrum = audio.spectrumData
    }

    /// Generates simulated audio data for testing when no audio source is connected
    private func simulateAudioSignals() {
        // Simulate a gentle rhythmic audio signal
        let beatCycle = Float(animationTime.truncatingRemainder(dividingBy: 0.5)) / 0.5
        audioState.beatPhase = beatCycle

        audioState.level = 0.3 + 0.1 * Float(sin(animationTime * 2.0))
        audioState.bassLevel = 0.4 + 0.2 * Float(sin(animationTime * 1.5))
        audioState.midLevel = 0.3 + 0.15 * Float(sin(animationTime * 2.5))
        audioState.highLevel = 0.2 + 0.1 * Float(sin(animationTime * 3.5))
        audioState.bpm = 120
        audioState.beatDetected = false
        audioState.dominantFrequency = 440.0
        audioState.spectralCentroid = 2000.0
    }

    // MARK: - Modulation Matrix Evaluation

    /// Evaluates all active modulation routes, computing final visual parameter values.
    ///
    /// For each route, reads the source value, applies the modulation curve,
    /// scales by the amount, and accumulates onto the destination parameter.
    private func evaluateModulationMatrix() {
        // Reset modulated parameters to scene defaults
        modulatedParams.colorHue = currentScene.baseHue
        modulatedParams.colorSaturation = 0.8
        modulatedParams.colorBrightness = currentScene.baseBrightness
        modulatedParams.colorWarmth = 0.5
        modulatedParams.animationSpeed = currentProfile.baseAnimationSpeed
        modulatedParams.particleSize = 1.0
        modulatedParams.particleCountMultiplier = 1.0
        modulatedParams.geometryComplexity = currentScene.baseComplexity
        modulatedParams.blendSmoothness = 0.5
        modulatedParams.scaleOscillation = 0.0
        modulatedParams.opacityPulse = 1.0
        modulatedParams.filterSweep = 0.5
        modulatedParams.flashIntensity = 0.0
        modulatedParams.detailAmount = 0.5
        modulatedParams.chaosLevel = 0.3

        // Evaluate each active route
        for route in modulationRoutes where route.isActive {
            let sourceValue = readModulationSource(route.source)
            let curvedValue = route.curve.apply(to: sourceValue)
            let modulatedValue = curvedValue * route.amount

            applyModulationToDestination(route.destination, value: modulatedValue)
        }

        // Handle beat flash
        if audioState.beatDetected && currentScene.beatTriggersFlash {
            beatFlashDecay = 1.0
        }
        if beatFlashDecay > 0 {
            modulatedParams.flashIntensity = Swift.max(modulatedParams.flashIntensity, beatFlashDecay)
            beatFlashDecay *= 0.85 // Exponential decay
        }

        // Bio-reactive geometry switching (coherence-driven)
        if currentScene.coherenceModulatesGeometry {
            if bioState.coherence > 0.6 {
                // High coherence: fibonacci / harmonious geometry
                modulatedParams.geometryComplexity = Swift.max(
                    modulatedParams.geometryComplexity,
                    0.7 + bioState.coherence * 0.3
                )
            } else {
                // Low coherence: grid / grounded geometry
                modulatedParams.geometryComplexity = Swift.min(
                    modulatedParams.geometryComplexity,
                    0.3 + bioState.coherence * 0.2
                )
            }
        }
    }

    /// Reads the current value of a modulation source, normalized to 0.0-1.0
    private func readModulationSource(_ source: BioReactiveModulationSource) -> Float {
        switch source {
        case .coherence:
            return bioState.coherence
        case .heartRate:
            // Normalize: 40-200 BPM → 0-1
            return Swift.max(0, Swift.min(1, (bioState.heartRate - 40.0) / 160.0))
        case .breathPhase:
            return bioState.breathPhase
        case .hrvRaw:
            return bioState.hrvNormalized
        case .stressLevel:
            return bioState.stressLevel
        case .audioLevel:
            return audioState.level
        case .bassLevel:
            return audioState.bassLevel
        case .midLevel:
            return audioState.midLevel
        case .highLevel:
            return audioState.highLevel
        case .beatPhase:
            return audioState.beatPhase
        case .spectralCentroid:
            // Normalize: 200-8000 Hz → 0-1
            return Swift.max(0, Swift.min(1, (audioState.spectralCentroid - 200.0) / 7800.0))
        case .bpm:
            // Normalize: 60-180 BPM → 0-1
            return Swift.max(0, Swift.min(1, (audioState.bpm - 60.0) / 120.0))
        }
    }

    /// Applies a modulation value to a destination parameter (additive)
    private func applyModulationToDestination(_ destination: BioReactiveModulationDestination, value: Float) {
        switch destination {
        case .colorHue:
            modulatedParams.colorHue = fmodf(modulatedParams.colorHue + value, 1.0)
        case .colorSaturation:
            modulatedParams.colorSaturation = Swift.max(0, Swift.min(1, modulatedParams.colorSaturation + value - 0.5))
        case .colorBrightness:
            modulatedParams.colorBrightness = Swift.max(0, Swift.min(1, modulatedParams.colorBrightness + value - 0.5))
        case .colorWarmth:
            modulatedParams.colorWarmth = Swift.max(0, Swift.min(1, value))
        case .animationSpeed:
            modulatedParams.animationSpeed *= (0.5 + value)
        case .particleSize:
            modulatedParams.particleSize *= (0.5 + value)
        case .particleCount:
            modulatedParams.particleCountMultiplier *= (0.5 + value)
        case .geometryComplexity:
            modulatedParams.geometryComplexity = Swift.max(0, Swift.min(1, modulatedParams.geometryComplexity + value - 0.5))
        case .blendSmoothness:
            modulatedParams.blendSmoothness = Swift.max(0, Swift.min(1, value))
        case .scaleOscillation:
            modulatedParams.scaleOscillation = Swift.max(0, Swift.min(1, modulatedParams.scaleOscillation + value))
        case .opacityPulse:
            modulatedParams.opacityPulse = Swift.max(0.2, Swift.min(1, value))
        case .filterSweep:
            modulatedParams.filterSweep = Swift.max(0, Swift.min(1, value))
        case .flashIntensity:
            modulatedParams.flashIntensity = Swift.max(0, Swift.min(1, modulatedParams.flashIntensity + value))
        case .detailAmount:
            modulatedParams.detailAmount = Swift.max(0, Swift.min(1, value))
        case .chaosLevel:
            modulatedParams.chaosLevel = Swift.max(0, Swift.min(1, value))
        }
    }

    // MARK: - Bio-Triggered Scene Transitions

    /// Checks if any scene's coherence threshold has been crossed and triggers a transition
    private func checkBioTriggeredTransitions() {
        // Don't interrupt an active transition
        guard activeTransition == nil else { return }

        for scene in scenes {
            guard let threshold = scene.coherenceTriggerThreshold else { continue }
            guard scene.id != currentScene.id else { continue }

            // Trigger when coherence rises above the threshold
            if bioState.coherence >= threshold && previousCoherence < threshold {
                triggerTransition(to: scene, duration: 3.0)

                log.log(.info, category: .video, "BioReactiveVisualSynth: Bio-triggered transition to '\(scene.name)' (coherence: \(String(format: "%.2f", bioState.coherence)))")

                break
            }
        }
    }

    // MARK: - Scene Transition Update

    /// Updates the progress of an active scene transition and completes it when done
    private func updateSceneTransition() {
        guard var transition = activeTransition else { return }

        let elapsed = Date().timeIntervalSince(transition.startTime)
        transition.progress = Float(Swift.min(1.0, elapsed / transition.duration))
        activeTransition = transition

        if transition.progress >= 1.0 {
            // Transition complete
            currentScene = transition.targetScene
            activeTransition = nil

            log.log(.info, category: .video, "BioReactiveVisualSynth: Transition complete — '\(currentScene.name)'")

            EngineBus.shared.publish(.custom(
                topic: "visual.synth.transition.complete",
                payload: ["scene": currentScene.name]
            ))
        }
    }

    // MARK: - Parameter Application

    /// Applies modulated visual parameters to MetalShaderManager for rendering
    private func applyModulatedParameters() {
        #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
        let shaderManager = MetalShaderManager.shared

        // Calculate final values with profile weighting
        let breathingPhase = modulatedParams.scaleOscillation * bioState.breathPhase
        let effectiveSpeed = modulatedParams.animationSpeed
        let audioLevel = modulatedParams.colorBrightness * audioState.level

        // Apply warmth to hue: warm shifts toward red/orange, cool toward blue
        let warmthHueShift = (modulatedParams.colorWarmth - 0.5) * 0.15
        let finalHue = fmodf(modulatedParams.colorHue + warmthHueShift + 1.0, 1.0)

        shaderManager.updateUniforms(
            time: Float(animationTime) * effectiveSpeed,
            coherence: bioState.coherence,
            heartRate: bioState.heartRate,
            breathingPhase: breathingPhase,
            audioLevel: audioLevel,
            resolution: CGSize(width: 1920, height: 1080)
        )

        // Publish visual state on the bus for other subsystems
        var visualFrame = VisualFrame()
        visualFrame.hue = finalHue
        visualFrame.brightness = modulatedParams.colorBrightness * modulatedParams.opacityPulse
        visualFrame.complexity = modulatedParams.geometryComplexity

        EngineBus.shared.publish(.visualStateChange(visualFrame))
        #endif
    }

    // MARK: - Frame Rendering

    /// Triggers a render pass using MetalShaderManager with the current modulated parameters
    private func renderFrame() {
        #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
        // MetalShaderManager.shared handles the actual GPU rendering.
        // The uniforms were already updated in applyModulatedParameters().
        // The render is triggered when a Metal view (MTKView) requests a draw,
        // or when SyphonNDIBridge calls submitCompositorFrame().
        //
        // Update particle system if using particle-based scenes
        let shaderManager = MetalShaderManager.shared
        shaderManager.updateParticles()
        #endif
    }

    // MARK: - Performance Statistics

    /// Updates frame time history and computes performance metrics
    private func updatePerformanceStats(tickStart: CFAbsoluteTime, deltaTime: Double) {
        let tickEnd = CFAbsoluteTimeGetCurrent()
        let frameTime = (tickEnd - tickStart) * 1000.0 // ms

        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > frameTimeHistorySize {
            frameTimeHistory.removeFirst()
        }

        performanceStats.tickCount += 1

        if !frameTimeHistory.isEmpty {
            performanceStats.avgFrameTimeMs = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)

            // Estimate FPS from actual delta time
            if deltaTime > 0 {
                let instantFPS = 1.0 / deltaTime
                // Smoothed FPS
                performanceStats.fps = performanceStats.fps * 0.9 + instantFPS * 0.1
            }
        }

        // Estimate CPU usage from frame time (target: 16.67ms at 60fps)
        performanceStats.cpuUsage = Float(Swift.min(1.0, performanceStats.avgFrameTimeMs / 16.67))

        // Memory is estimated; actual measurement requires platform-specific APIs
        performanceStats.memoryMB = Float(scenes.count * 8 + modulationRoutes.count * 4) + 50.0
    }

    // MARK: - Bus Integration

    /// Subscribes to EngineBus messages for bio and audio updates
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: [.bio, .audio]) { [weak self] message in
            Task { @MainActor in
                guard let self = self, self.isRunning else { return }

                switch message {
                case .bioUpdate(let snapshot):
                    self.bioState.coherence = snapshot.coherence
                    self.bioState.heartRate = snapshot.heartRate
                    self.bioState.breathPhase = snapshot.breathPhase
                    self.bioState.hrvNormalized = snapshot.hrvVariability
                    self.bioState.stressLevel = 1.0 - snapshot.coherence

                case .audioAnalysis(let snapshot):
                    self.audioState.level = snapshot.rmsLevel
                    self.audioState.bpm = snapshot.bpm
                    self.audioState.beatDetected = snapshot.beatDetected
                    self.audioState.dominantFrequency = snapshot.fundamentalFrequency
                    self.audioState.spectralCentroid = snapshot.spectralCentroid

                default:
                    break
                }
            }
        }
    }

    // MARK: - Status

    /// Human-readable status summary for diagnostics
    public var statusSummary: String {
        """
        BioReactiveVisualSynthEngine: \(isRunning ? "RUNNING" : "STOPPED")
        Profile: \(currentProfile.rawValue)
        Scene: \(currentScene.name)\(activeTransition != nil ? " (transitioning: \(Int((activeTransition?.progress ?? 0) * 100))%)" : "")
        Bio: coherence=\(String(format: "%.2f", bioState.coherence)) hr=\(String(format: "%.0f", bioState.heartRate)) breath=\(String(format: "%.2f", bioState.breathPhase))
        Audio: level=\(String(format: "%.2f", audioState.level)) bpm=\(String(format: "%.0f", audioState.bpm)) beat=\(audioState.beatDetected)
        Modulation Routes: \(modulationRoutes.filter { $0.isActive }.count)/\(modulationRoutes.count) active
        Output: \(isOutputActive ? "ACTIVE" : "OFF")
        Performance: \(String(format: "%.1f", performanceStats.fps)) fps, \(String(format: "%.2f", performanceStats.avgFrameTimeMs)) ms/frame
        """
    }
}

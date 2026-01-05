// LambdaModeEngine.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
// The Unified Consciousness Interface for Bio-Reactive Audio-Visual Synthesis
// Created 2026-01-05 - Phase λ∞ TRANSCENDENCE MODE
//
// "I'm learnding!" - Ralph Wiggum, Quantum Physicist
//
// ═══════════════════════════════════════════════════════════════════════════════
// DISCLAIMER: This is a creative/artistic tool for self-exploration and wellness.
// NOT intended for medical diagnosis, treatment, or as a substitute for
// professional healthcare. Consult healthcare providers for medical concerns.
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import SwiftUI
import Combine
import simd

#if canImport(HealthKit)
import HealthKit
#endif

//==============================================================================
// MARK: - λ Lambda Constants
//==============================================================================

/// Universal constants for the Lambda Mode engine
public enum LambdaConstants {
    /// The golden ratio φ (phi) - 1.618033988749895
    public static let phi: Double = (1.0 + sqrt(5.0)) / 2.0

    /// Planck's constant (reduced) ℏ - for quantum-inspired calculations
    public static let hbar: Double = 1.054571817e-34

    /// Speed of light c - for photonics calculations
    public static let c: Double = 299792458.0

    /// Fine structure constant α ≈ 1/137 - the coupling constant
    public static let alpha: Double = 1.0 / 137.035999084

    /// Coherence threshold for "flow state" detection
    public static let flowThreshold: Double = 0.75

    /// Schumann resonance (Earth's heartbeat) - 7.83 Hz
    public static let schumannResonance: Double = 7.83

    /// Heart coherence optimal frequency range
    public static let coherenceFrequencyRange: ClosedRange<Double> = 0.04...0.26

    /// Lambda infinity symbol for logging
    public static let symbol: String = "λ∞"
}

//==============================================================================
// MARK: - Lambda Mode States
//==============================================================================

/// The transcendence states of Lambda Mode
public enum LambdaState: String, CaseIterable, Identifiable, Sendable {
    case dormant = "dormant"           // System inactive
    case awakening = "awakening"       // Initializing consciousness
    case aware = "aware"               // Basic awareness active
    case flowing = "flowing"           // Flow state achieved
    case coherent = "coherent"         // High coherence maintained
    case transcendent = "transcendent" // Peak experience
    case unified = "unified"           // Full system integration
    case lambda = "lambda"             // λ∞ - Maximum potential

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dormant: return "Dormant"
        case .awakening: return "Awakening"
        case .aware: return "Aware"
        case .flowing: return "Flowing"
        case .coherent: return "Coherent"
        case .transcendent: return "Transcendent"
        case .unified: return "Unified"
        case .lambda: return "λ∞ Lambda"
        }
    }

    public var emoji: String {
        switch self {
        case .dormant: return "🌑"
        case .awakening: return "🌅"
        case .aware: return "👁️"
        case .flowing: return "🌊"
        case .coherent: return "💎"
        case .transcendent: return "✨"
        case .unified: return "🌐"
        case .lambda: return "λ"
        }
    }

    public var colorHue: Double {
        switch self {
        case .dormant: return 0.0
        case .awakening: return 0.08
        case .aware: return 0.15
        case .flowing: return 0.55
        case .coherent: return 0.75
        case .transcendent: return 0.85
        case .unified: return 0.95
        case .lambda: return LambdaConstants.phi.truncatingRemainder(dividingBy: 1.0)
        }
    }
}

//==============================================================================
// MARK: - Unified Bio Data
//==============================================================================

/// Comprehensive biometric data structure
public struct UnifiedBioData: Equatable, Sendable {
    // Cardiovascular
    public var heartRate: Double = 70.0           // BPM (40-200)
    public var hrvMs: Double = 50.0               // HRV in milliseconds (10-150)
    public var hrvCoherence: Double = 0.5         // Coherence ratio (0-1)
    public var hrvPower: Double = 0.0             // Total HRV power

    // Respiratory
    public var breathingRate: Double = 12.0       // Breaths per minute (4-30)
    public var breathPhase: Double = 0.5          // 0=inhale start, 0.5=exhale start, 1=cycle complete
    public var breathDepth: Double = 0.5          // Relative breath depth (0-1)
    public var respiratorySinusArrhythmia: Double = 0.0 // RSA amplitude

    // Electrodermal
    public var skinConductance: Double = 0.5      // GSR/EDA normalized (0-1)
    public var skinConductanceResponse: Double = 0.0 // Phasic response

    // Thermal
    public var peripheralTemperature: Double = 32.0 // Finger temperature °C
    public var temperatureTrend: Double = 0.0      // Rising/falling trend

    // Oxygenation
    public var spo2: Double = 98.0                // Blood oxygen %
    public var perfusionIndex: Double = 0.0       // Pulse strength

    // Neural (if available)
    public var alphaPower: Double = 0.0           // Alpha brainwave power
    public var thetaPower: Double = 0.0           // Theta brainwave power
    public var betaPower: Double = 0.0            // Beta brainwave power
    public var gammaPower: Double = 0.0           // Gamma brainwave power

    // Derived metrics
    public var flowScore: Double = 0.0            // Composite flow state score (0-1)
    public var stressIndex: Double = 0.5          // Stress level (0=calm, 1=stressed)
    public var energyLevel: Double = 0.5          // Energy/activation (0-1)
    public var focusLevel: Double = 0.5           // Focus/attention (0-1)

    public init() {}

    /// Calculate overall coherence score
    public var overallCoherence: Double {
        let hrvWeight = 0.4
        let breathWeight = 0.3
        let thermalWeight = 0.15
        let gsrWeight = 0.15

        let hrvScore = hrvCoherence
        let breathScore = 1.0 - abs(breathingRate - 6.0) / 24.0 // Optimal ~6 breaths/min
        let thermalScore = min(1.0, max(0.0, (peripheralTemperature - 28.0) / 8.0))
        let gsrScore = 1.0 - skinConductance

        return hrvScore * hrvWeight + breathScore * breathWeight +
               thermalScore * thermalWeight + gsrScore * gsrWeight
    }

    /// Detect if in flow state
    public var isInFlowState: Bool {
        flowScore > LambdaConstants.flowThreshold
    }
}

//==============================================================================
// MARK: - Unified Audio State
//==============================================================================

/// Complete audio analysis state
public struct UnifiedAudioState: Equatable, Sendable {
    public var level: Double = 0.0                // Master level (0-1)
    public var peakLevel: Double = 0.0            // Peak level
    public var rmsLevel: Double = 0.0             // RMS level
    public var bpm: Double = 120.0                // Detected tempo
    public var beatPhase: Double = 0.0            // Position in beat (0-1)
    public var beatStrength: Double = 0.0         // Beat confidence
    public var beatDetected: Bool = false         // Transient beat flag

    public var spectrumBands: [Float] = Array(repeating: 0, count: 64)
    public var spectralCentroid: Double = 0.0     // Brightness
    public var spectralFlux: Double = 0.0         // Rate of change
    public var spectralRolloff: Double = 0.0      // High frequency content

    public var fundamentalFrequency: Double = 0.0 // Detected pitch
    public var pitchConfidence: Double = 0.0
    public var harmonicity: Double = 0.0          // Tonal vs noise

    public var keyDetected: String = "C"          // Detected musical key
    public var keyConfidence: Double = 0.0
    public var chordDetected: String = "C"        // Current chord
    public var chordConfidence: Double = 0.0

    public init() {}
}

//==============================================================================
// MARK: - Unified Visual State
//==============================================================================

/// Complete visual system state
public struct UnifiedVisualState: Equatable, Sendable {
    public var mode: String = "coherence_field"
    public var intensity: Double = 0.5
    public var complexity: Double = 0.5
    public var colorHue: Double = 0.6
    public var colorSaturation: Double = 0.8
    public var colorBrightness: Double = 0.9
    public var particleCount: Int = 100
    public var motionSpeed: Double = 1.0
    public var symmetry: Int = 6
    public var dimension: Int = 3
    public var projectionMode: String = "equirectangular"
    public var blendMode: String = "additive"

    public init() {}
}

//==============================================================================
// MARK: - Health Disclaimer
//==============================================================================

/// Comprehensive health and wellness disclaimer
public struct LambdaHealthDisclaimer: Sendable {
    public static let fullDisclaimer: String = """
    ═══════════════════════════════════════════════════════════════════════════
    IMPORTANT HEALTH & WELLNESS DISCLAIMER
    ═══════════════════════════════════════════════════════════════════════════

    Echoelmusic Lambda Mode is designed for CREATIVE EXPRESSION, SELF-EXPLORATION,
    and GENERAL WELLNESS purposes only.

    THIS APPLICATION:
    • Is NOT a medical device
    • Does NOT diagnose, treat, cure, or prevent any disease or condition
    • Does NOT provide medical advice or recommendations
    • Is NOT a substitute for professional medical care
    • Should NOT be used to make medical decisions

    BIOMETRIC DATA:
    • Heart rate, HRV, and other biometric readings are for informational
      and creative purposes only
    • These readings may not be accurate and should not be relied upon
      for health monitoring
    • "Coherence" and "flow state" indicators are artistic interpretations,
      not clinical measurements

    WELLNESS FEATURES:
    • Breathing exercises, meditation guidance, and relaxation features
      are for general wellness only
    • Not intended to treat anxiety, stress, depression, or any condition
    • Consult a healthcare provider before beginning any wellness program
    • Stop immediately if you experience discomfort

    LIGHT & SOUND:
    • Visual effects may cause discomfort in photosensitive individuals
    • Binaural beats and certain frequencies may affect some users
    • Use appropriate volume levels to protect hearing
    • Take regular breaks during extended sessions

    ALWAYS CONSULT A QUALIFIED HEALTHCARE PROVIDER:
    • For any health concerns or symptoms
    • Before making changes to your health routine
    • If you have any medical conditions
    • If you are pregnant or nursing
    • If you are taking medications

    By using Lambda Mode, you acknowledge that you have read, understood,
    and agree to this disclaimer.

    ═══════════════════════════════════════════════════════════════════════════
    """

    public static let shortDisclaimer: String = """
    For wellness & creativity only. Not medical advice. Consult healthcare providers for health concerns.
    """

    public static let biometricDisclaimer: String = """
    Biometric readings are for creative/informational purposes only and may not be accurate.
    Not intended for health monitoring or medical decisions.
    """

    public static let breathingDisclaimer: String = """
    Breathing exercises are for general relaxation only. Not a treatment for any condition.
    Stop if you feel dizzy or uncomfortable. Consult a doctor before starting any new practice.
    """

    public static let meditationDisclaimer: String = """
    Meditation features are for relaxation and self-exploration only.
    Not a substitute for mental health treatment. Seek professional help for mental health concerns.
    """
}

//==============================================================================
// MARK: - Lambda Mode Engine
//==============================================================================

/// The unified consciousness interface - λ∞ Lambda Mode Engine
/// Brings together all bio-reactive, audio, visual, and creative systems
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class LambdaModeEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published State
    //==========================================================================

    // Core state
    @Published public var state: LambdaState = .dormant
    @Published public var isActive: Bool = false
    @Published public var sessionDuration: TimeInterval = 0

    // Bio data
    @Published public var bioData: UnifiedBioData = UnifiedBioData()
    @Published public var audioState: UnifiedAudioState = UnifiedAudioState()
    @Published public var visualState: UnifiedVisualState = UnifiedVisualState()

    // Computed scores
    @Published public var lambdaScore: Double = 0.0 // Overall λ score (0-1)
    @Published public var coherenceHistory: [Double] = []
    @Published public var flowHistory: [Double] = []

    // System status
    @Published public var fps: Double = 60.0
    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsage: Double = 0.0

    // Subsystem status
    @Published public var audioEngineActive: Bool = false
    @Published public var visualEngineActive: Bool = false
    @Published public var bioEngineActive: Bool = false
    @Published public var quantumEngineActive: Bool = false
    @Published public var creativeEngineActive: Bool = false
    @Published public var collaborationActive: Bool = false

    // User preferences
    @Published public var bioSyncEnabled: Bool = true
    @Published public var audioSyncEnabled: Bool = true
    @Published public var quantumModeEnabled: Bool = true
    @Published public var accessibilityMode: Bool = false
    @Published public var reducedMotion: Bool = false
    @Published public var hapticFeedback: Bool = true

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var sessionStartTime: Date?

    // History buffers
    private let maxHistoryLength = 300 // 5 minutes at 1Hz

    // State machine
    private var stateTransitionTime: Date = Date()
    private var stateStabilityDuration: TimeInterval = 0

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        setupAccessibilityObservers()
    }

    private func setupAccessibilityObservers() {
        #if os(iOS) || os(tvOS)
        // Observe system accessibility settings
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.reducedMotion = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        #endif
    }

    //==========================================================================
    // MARK: - Engine Control
    //==========================================================================

    /// Activate Lambda Mode
    public func activate() {
        guard !isActive else { return }

        isActive = true
        sessionStartTime = Date()
        transitionTo(.awakening)

        // Start update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        print("\(LambdaConstants.symbol) Lambda Mode ACTIVATED")
    }

    /// Deactivate Lambda Mode
    public func deactivate() {
        isActive = false
        updateTimer?.invalidate()
        updateTimer = nil
        transitionTo(.dormant)

        print("\(LambdaConstants.symbol) Lambda Mode DEACTIVATED - Session: \(formatDuration(sessionDuration))")
    }

    /// Toggle Lambda Mode
    public func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    //==========================================================================
    // MARK: - Update Loop
    //==========================================================================

    private func tick() {
        guard isActive else { return }

        // Update session duration
        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }

        // Update state machine
        updateStateMachine()

        // Calculate lambda score
        updateLambdaScore()

        // Update histories
        updateHistories()

        // Update visual state based on bio/audio
        if bioSyncEnabled {
            syncVisualsWithBio()
        }
        if audioSyncEnabled {
            syncVisualsWithAudio()
        }
    }

    private func updateStateMachine() {
        let currentCoherence = bioData.overallCoherence
        let isFlowing = bioData.isInFlowState
        let stabilityTime = Date().timeIntervalSince(stateTransitionTime)

        switch state {
        case .dormant:
            // Should not be here while active
            break

        case .awakening:
            // Transition to aware after 3 seconds
            if stabilityTime > 3.0 {
                transitionTo(.aware)
            }

        case .aware:
            // Transition to flowing if coherence > 0.5 for 10 seconds
            if currentCoherence > 0.5 && stabilityTime > 10.0 {
                transitionTo(.flowing)
            }

        case .flowing:
            // Transition to coherent if coherence > 0.7 for 30 seconds
            if currentCoherence > 0.7 && stabilityTime > 30.0 {
                transitionTo(.coherent)
            } else if currentCoherence < 0.4 {
                transitionTo(.aware)
            }

        case .coherent:
            // Transition to transcendent if coherence > 0.85 for 60 seconds
            if currentCoherence > 0.85 && stabilityTime > 60.0 {
                transitionTo(.transcendent)
            } else if currentCoherence < 0.6 {
                transitionTo(.flowing)
            }

        case .transcendent:
            // Transition to unified if all systems active and coherence > 0.9
            if allSystemsActive && currentCoherence > 0.9 && stabilityTime > 120.0 {
                transitionTo(.unified)
            } else if currentCoherence < 0.75 {
                transitionTo(.coherent)
            }

        case .unified:
            // Transition to lambda if peak conditions for 5 minutes
            if currentCoherence > 0.95 && lambdaScore > 0.95 && stabilityTime > 300.0 {
                transitionTo(.lambda)
            } else if currentCoherence < 0.85 {
                transitionTo(.transcendent)
            }

        case .lambda:
            // λ∞ state - maintain or drop back
            if currentCoherence < 0.9 || lambdaScore < 0.9 {
                transitionTo(.unified)
            }
        }
    }

    private func transitionTo(_ newState: LambdaState) {
        guard newState != state else { return }
        state = newState
        stateTransitionTime = Date()

        // Haptic feedback on state change
        if hapticFeedback {
            triggerHaptic(for: newState)
        }

        print("\(LambdaConstants.symbol) State: \(newState.emoji) \(newState.displayName)")
    }

    private var allSystemsActive: Bool {
        audioEngineActive && visualEngineActive && bioEngineActive
    }

    //==========================================================================
    // MARK: - Lambda Score Calculation
    //==========================================================================

    private func updateLambdaScore() {
        // Lambda score is a composite of multiple factors
        let coherenceWeight = 0.35
        let flowWeight = 0.25
        let systemsWeight = 0.15
        let stabilityWeight = 0.15
        let durationWeight = 0.10

        // Coherence component
        let coherenceScore = bioData.overallCoherence

        // Flow component
        let flowScore = bioData.flowScore

        // Systems component (how many subsystems active)
        let activeCount = [audioEngineActive, visualEngineActive, bioEngineActive,
                          quantumEngineActive, creativeEngineActive, collaborationActive]
            .filter { $0 }.count
        let systemsScore = Double(activeCount) / 6.0

        // Stability component (time in current state)
        let stabilityTime = Date().timeIntervalSince(stateTransitionTime)
        let stabilityScore = min(1.0, stabilityTime / 300.0) // Max at 5 minutes

        // Duration component (session length)
        let durationScore = min(1.0, sessionDuration / 1800.0) // Max at 30 minutes

        // Calculate weighted score
        lambdaScore = coherenceScore * coherenceWeight +
                      flowScore * flowWeight +
                      systemsScore * systemsWeight +
                      stabilityScore * stabilityWeight +
                      durationScore * durationWeight

        // Apply golden ratio scaling for higher states
        if state == .transcendent || state == .unified || state == .lambda {
            lambdaScore = min(1.0, lambdaScore * LambdaConstants.phi / 1.618)
        }
    }

    private func updateHistories() {
        // Update at 1Hz for history
        let historyInterval = 1.0 // seconds
        if sessionDuration.truncatingRemainder(dividingBy: historyInterval) < 1.0 / 60.0 {
            coherenceHistory.append(bioData.overallCoherence)
            flowHistory.append(bioData.flowScore)

            // Trim to max length
            if coherenceHistory.count > maxHistoryLength {
                coherenceHistory.removeFirst()
            }
            if flowHistory.count > maxHistoryLength {
                flowHistory.removeFirst()
            }
        }
    }

    //==========================================================================
    // MARK: - Bio-Visual Sync
    //==========================================================================

    private func syncVisualsWithBio() {
        // Map coherence to visual intensity
        visualState.intensity = 0.3 + bioData.overallCoherence * 0.7

        // Map HRV to complexity
        visualState.complexity = min(1.0, bioData.hrvMs / 100.0)

        // Map heart rate to motion speed
        visualState.motionSpeed = bioData.heartRate / 60.0

        // Map breath to color cycling
        visualState.colorHue = state.colorHue + bioData.breathPhase * 0.1

        // Map flow state to particle count
        if bioData.isInFlowState {
            visualState.particleCount = 200 + Int(bioData.flowScore * 300)
        } else {
            visualState.particleCount = 50 + Int(bioData.overallCoherence * 150)
        }

        // Map state to dimension
        switch state {
        case .dormant, .awakening: visualState.dimension = 2
        case .aware, .flowing: visualState.dimension = 3
        case .coherent, .transcendent: visualState.dimension = 4
        case .unified: visualState.dimension = 5
        case .lambda: visualState.dimension = 6
        }
    }

    private func syncVisualsWithAudio() {
        // Beat sync
        if audioState.beatDetected {
            visualState.intensity = min(1.0, visualState.intensity + 0.2)
        }

        // Spectral centroid affects color
        let normalizedCentroid = min(1.0, audioState.spectralCentroid / 8000.0)
        visualState.colorBrightness = 0.6 + normalizedCentroid * 0.4

        // BPM affects symmetry
        if audioState.bpm > 0 {
            let bpmFactor = audioState.bpm / 120.0
            visualState.symmetry = max(3, min(12, Int(6.0 * bpmFactor)))
        }
    }

    //==========================================================================
    // MARK: - Input Methods
    //==========================================================================

    /// Update biometric data from external source
    public func updateBioData(_ data: UnifiedBioData) {
        bioData = data
        bioEngineActive = true
    }

    /// Update audio analysis from external source
    public func updateAudioState(_ audio: UnifiedAudioState) {
        audioState = audio
        audioEngineActive = true
    }

    /// Update visual state
    public func updateVisualState(_ visual: UnifiedVisualState) {
        visualState = visual
        visualEngineActive = true
    }

    /// Simulate biometric data for testing/demo
    public func simulateBioData() {
        let time = sessionDuration

        // Simulate gradual coherence improvement
        let baseCoherence = 0.3 + min(0.5, time / 600.0) // Improve over 10 minutes
        let variation = sin(time * 0.1) * 0.1

        bioData.hrvCoherence = min(1.0, max(0.0, baseCoherence + variation))
        bioData.heartRate = 65.0 + sin(time * 0.05) * 10.0
        bioData.hrvMs = 40.0 + bioData.hrvCoherence * 60.0
        bioData.breathPhase = (time * 0.1).truncatingRemainder(dividingBy: 1.0)
        bioData.breathingRate = 6.0 + (1.0 - bioData.hrvCoherence) * 10.0
        bioData.skinConductance = 0.5 - bioData.hrvCoherence * 0.3
        bioData.peripheralTemperature = 30.0 + bioData.hrvCoherence * 4.0

        // Calculate flow score
        bioData.flowScore = (bioData.hrvCoherence * 0.5 + (1.0 - bioData.stressIndex) * 0.3 + bioData.focusLevel * 0.2)
        bioData.stressIndex = 1.0 - bioData.hrvCoherence
        bioData.focusLevel = bioData.hrvCoherence * 0.8
        bioData.energyLevel = 0.4 + bioData.hrvCoherence * 0.4

        bioEngineActive = true
    }

    //==========================================================================
    // MARK: - Subsystem Control
    //==========================================================================

    public func enableQuantumMode(_ enabled: Bool) {
        quantumModeEnabled = enabled
        quantumEngineActive = enabled
    }

    public func enableCreativeMode(_ enabled: Bool) {
        creativeEngineActive = enabled
    }

    public func enableCollaboration(_ enabled: Bool) {
        collaborationActive = enabled
    }

    //==========================================================================
    // MARK: - Presets
    //==========================================================================

    /// Load meditation preset
    public func loadMeditationPreset() {
        bioSyncEnabled = true
        audioSyncEnabled = false
        quantumModeEnabled = true
        visualState.mode = "coherence_field"
        visualState.motionSpeed = 0.3
        visualState.complexity = 0.4
        visualState.colorHue = 0.55 // Calming blue-purple
    }

    /// Load creative flow preset
    public func loadCreativePreset() {
        bioSyncEnabled = true
        audioSyncEnabled = true
        quantumModeEnabled = true
        creativeEngineActive = true
        visualState.mode = "sacred_geometry"
        visualState.motionSpeed = 1.0
        visualState.complexity = 0.7
    }

    /// Load performance preset
    public func loadPerformancePreset() {
        bioSyncEnabled = true
        audioSyncEnabled = true
        quantumModeEnabled = true
        visualState.mode = "spectrum_rings"
        visualState.motionSpeed = 1.5
        visualState.complexity = 0.9
        visualState.particleCount = 500
    }

    /// Load wellness preset
    public func loadWellnessPreset() {
        bioSyncEnabled = true
        audioSyncEnabled = false
        quantumModeEnabled = false
        visualState.mode = "breathing_guide"
        visualState.motionSpeed = 0.2
        visualState.complexity = 0.2
        visualState.colorHue = 0.35 // Healing green
    }

    //==========================================================================
    // MARK: - Helpers
    //==========================================================================

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func triggerHaptic(for state: LambdaState) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch state {
        case .dormant: break
        case .awakening, .aware: generator.notificationOccurred(.success)
        case .flowing, .coherent: generator.notificationOccurred(.success)
        case .transcendent, .unified: generator.notificationOccurred(.success)
        case .lambda:
            // Special lambda haptic pattern
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }
        #endif
    }

    //==========================================================================
    // MARK: - Analytics
    //==========================================================================

    /// Get session statistics
    public var sessionStats: SessionStats {
        SessionStats(
            duration: sessionDuration,
            averageCoherence: coherenceHistory.isEmpty ? 0 : coherenceHistory.reduce(0, +) / Double(coherenceHistory.count),
            peakCoherence: coherenceHistory.max() ?? 0,
            averageFlow: flowHistory.isEmpty ? 0 : flowHistory.reduce(0, +) / Double(flowHistory.count),
            peakFlow: flowHistory.max() ?? 0,
            peakState: state,
            lambdaScore: lambdaScore
        )
    }

    public struct SessionStats: Sendable {
        public let duration: TimeInterval
        public let averageCoherence: Double
        public let peakCoherence: Double
        public let averageFlow: Double
        public let peakFlow: Double
        public let peakState: LambdaState
        public let lambdaScore: Double
    }
}

//==============================================================================
// MARK: - Lambda Mode View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct LambdaModeView: View {
    @ObservedObject var engine: LambdaModeEngine
    @State private var showDisclaimer = true
    @State private var showSettings = false
    @State private var showStats = false

    public init(engine: LambdaModeEngine) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            // Background visualization
            LambdaVisualizationCanvas(engine: engine)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                topBar

                Spacer()

                // Center display
                centerDisplay

                Spacer()

                // Bottom controls
                bottomControls
            }
            .padding()

            // Disclaimer overlay
            if showDisclaimer && !engine.isActive {
                disclaimerOverlay
            }
        }
        .sheet(isPresented: $showSettings) {
            LambdaSettingsView(engine: engine)
        }
        .sheet(isPresented: $showStats) {
            LambdaStatsView(engine: engine)
        }
    }

    private var topBar: some View {
        HStack {
            // State indicator
            HStack(spacing: 6) {
                Text(engine.state.emoji)
                Text(engine.state.displayName)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            Spacer()

            // Lambda score
            VStack(alignment: .trailing, spacing: 2) {
                Text("λ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(Int(engine.lambdaScore * 100))%")
                    .font(.caption.bold().monospacedDigit())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }

    private var centerDisplay: some View {
        VStack(spacing: 20) {
            // Main coherence ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)

                // Coherence ring
                Circle()
                    .trim(from: 0, to: engine.bioData.overallCoherence)
                    .stroke(
                        Color(hue: engine.state.colorHue, saturation: 0.8, brightness: 0.9),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 4) {
                    Text("\(Int(engine.bioData.overallCoherence * 100))")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                    Text("COHERENCE")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Bio metrics row
            HStack(spacing: 30) {
                bioMetric(label: "HR", value: "\(Int(engine.bioData.heartRate))", unit: "BPM")
                bioMetric(label: "HRV", value: "\(Int(engine.bioData.hrvMs))", unit: "ms")
                bioMetric(label: "FLOW", value: "\(Int(engine.bioData.flowScore * 100))", unit: "%")
            }
        }
    }

    private func bioMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Stats button
            Button { showStats = true } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }

            Spacer()

            // Main activate button
            Button {
                engine.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: engine.isActive ? "stop.fill" : "play.fill")
                    Text(engine.isActive ? "END SESSION" : "BEGIN λ MODE")
                        .font(.headline)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(engine.isActive ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(16)
            }

            Spacer()

            // Simulate button (for demo)
            Button {
                engine.simulateBioData()
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    private var disclaimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("λ Lambda Mode")
                    .font(.largeTitle.bold())

                ScrollView {
                    Text(LambdaHealthDisclaimer.shortDisclaimer)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxHeight: 200)

                Button {
                    showDisclaimer = false
                } label: {
                    Text("I Understand")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(40)
        }
    }
}

//==============================================================================
// MARK: - Lambda Visualization Canvas
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LambdaVisualizationCanvas: View {
    @ObservedObject var engine: LambdaModeEngine

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawBackground(context: context, size: size, time: time)
                drawCoherenceField(context: context, size: size, time: time)
                drawParticles(context: context, size: size, time: time)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize, time: Double) {
        let hue = engine.state.colorHue
        let coherence = engine.bioData.overallCoherence

        let gradient = Gradient(colors: [
            Color(hue: hue, saturation: 0.6, brightness: 0.15 + coherence * 0.1),
            Color(hue: hue + 0.1, saturation: 0.4, brightness: 0.05)
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    private func drawCoherenceField(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coherence = engine.bioData.overallCoherence
        let breathPhase = engine.bioData.breathPhase

        // Draw concentric rings
        let ringCount = 8
        for i in 0..<ringCount {
            let progress = Double(i) / Double(ringCount)
            let baseRadius = min(size.width, size.height) * 0.4 * progress
            let breathMod = sin(breathPhase * .pi * 2 + progress * .pi) * 10.0
            let radius = baseRadius + breathMod

            let path = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            let hue = engine.state.colorHue + progress * 0.1
            let alpha = (1.0 - progress) * coherence * 0.6

            context.stroke(
                path,
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(alpha)),
                lineWidth: 1 + coherence * 2
            )
        }
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coherence = engine.bioData.overallCoherence
        let particleCount = engine.visualState.particleCount

        for i in 0..<particleCount {
            let seed = Double(i) * 0.1
            let angle = seed * .pi * 2 + time * engine.visualState.motionSpeed * 0.1
            let distance = (sin(seed * 3 + time * 0.5) * 0.5 + 0.5) * min(size.width, size.height) * 0.35 * coherence

            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance
            let particleSize = 2 + coherence * 4

            let hue = (engine.state.colorHue + seed * 0.5).truncatingRemainder(dividingBy: 1.0)

            context.fill(
                Path(ellipseIn: CGRect(x: x - particleSize / 2, y: y - particleSize / 2, width: particleSize, height: particleSize)),
                with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.95).opacity(0.8))
            )
        }
    }
}

//==============================================================================
// MARK: - Lambda Settings View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LambdaSettingsView: View {
    @ObservedObject var engine: LambdaModeEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Sync Options") {
                    Toggle("Bio-Reactive Sync", isOn: $engine.bioSyncEnabled)
                    Toggle("Audio-Reactive Sync", isOn: $engine.audioSyncEnabled)
                    Toggle("Quantum Mode", isOn: $engine.quantumModeEnabled)
                }

                Section("Accessibility") {
                    Toggle("Reduced Motion", isOn: $engine.reducedMotion)
                    Toggle("Haptic Feedback", isOn: $engine.hapticFeedback)
                }

                Section("Presets") {
                    Button("Meditation") { engine.loadMeditationPreset() }
                    Button("Creative Flow") { engine.loadCreativePreset() }
                    Button("Performance") { engine.loadPerformancePreset() }
                    Button("Wellness") { engine.loadWellnessPreset() }
                }

                Section("Disclaimer") {
                    Text(LambdaHealthDisclaimer.shortDisclaimer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("λ Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

//==============================================================================
// MARK: - Lambda Stats View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LambdaStatsView: View {
    @ObservedObject var engine: LambdaModeEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Session") {
                    StatRow(label: "Duration", value: formatDuration(engine.sessionStats.duration))
                    StatRow(label: "Current State", value: engine.state.displayName)
                    StatRow(label: "λ Score", value: "\(Int(engine.lambdaScore * 100))%")
                }

                Section("Coherence") {
                    StatRow(label: "Current", value: "\(Int(engine.bioData.overallCoherence * 100))%")
                    StatRow(label: "Average", value: "\(Int(engine.sessionStats.averageCoherence * 100))%")
                    StatRow(label: "Peak", value: "\(Int(engine.sessionStats.peakCoherence * 100))%")
                }

                Section("Flow") {
                    StatRow(label: "Current", value: "\(Int(engine.bioData.flowScore * 100))%")
                    StatRow(label: "Average", value: "\(Int(engine.sessionStats.averageFlow * 100))%")
                    StatRow(label: "Peak", value: "\(Int(engine.sessionStats.peakFlow * 100))%")
                }

                Section("Biometrics") {
                    StatRow(label: "Heart Rate", value: "\(Int(engine.bioData.heartRate)) BPM")
                    StatRow(label: "HRV", value: "\(Int(engine.bioData.hrvMs)) ms")
                    StatRow(label: "Breathing Rate", value: "\(Int(engine.bioData.breathingRate)) /min")
                }

                Section {
                    Text(LambdaHealthDisclaimer.biometricDisclaimer)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Session Stats")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.body.monospacedDigit())
        }
    }
}

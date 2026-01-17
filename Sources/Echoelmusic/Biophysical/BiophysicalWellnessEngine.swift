// BiophysicalWellnessEngine.swift
// Echoelmusic
//
// Main coordinator for biophysical measurement and feedback.
// Integrates EVM analysis, inertial sensing, and haptic stimulation.
//
// DISCLAIMER: This is a wellness-focused tool for informational purposes only.
// NOT a medical device. No medical claims are made. Consult healthcare professionals
// for any health concerns.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import CoreMotion
import CoreHaptics
import AVFoundation

// MARK: - Biophysical Wellness Disclaimer

/// Critical health disclaimer for biophysical features
public struct BiophysicalWellnessDisclaimer {

    public static let fullDisclaimer = """
    IMPORTANT WELLNESS DISCLAIMER

    This biophysical resonance and feedback tool is designed for WELLNESS and
    INFORMATIONAL purposes only. It is NOT a medical device and makes NO medical claims.

    KEY POINTS:
    • This tool does not diagnose, treat, cure, or prevent any disease
    • Frequency-based stimulation is for relaxation and wellness exploration only
    • Results vary by individual and are subjective
    • Not intended to replace professional medical advice
    • Consult your healthcare provider before use if you have:
      - Epilepsy or seizure disorders
      - Heart conditions or pacemakers
      - Pregnancy
      - Any chronic health conditions

    SAFETY LIMITS:
    • Automatic session timeout: 15 minutes maximum
    • Vibration intensity: Limited to safe levels (< 2.0 m/s²)
    • Duty cycle limits enforced to prevent overexposure

    By using this tool, you acknowledge that you have read and understood this disclaimer.

    References for frequency research (for educational purposes):
    • Rubin et al. (2006) - Low-magnitude mechanical signals
    • Iaccarino et al. (2016) - 40 Hz gamma entrainment
    • Judex & Rubin (2010) - Mechanical influences on bone

    These references are provided for educational context only and do not constitute
    medical endorsement.
    """

    public static let shortDisclaimer = """
    Wellness tool only. Not a medical device. No medical claims.
    Consult healthcare professionals for health concerns.
    """

    public static let startupOverlay = """
    🔬 Biophysical Resonance Tool

    ℹ️ Informational & Wellness Use Only
    ⚠️ No Medical Claims

    This tool explores frequency-based biofeedback for wellness purposes.
    It is NOT a medical device.

    Tap to acknowledge and continue.
    """
}

// MARK: - Biophysical Data Models

/// Frequency analysis result from sensors
public struct FrequencyAnalysisResult: Codable, Sendable {
    public let timestamp: Date
    public let dominantFrequency: Double  // Hz
    public let amplitude: Double          // Normalized 0-1
    public let frequencyBands: [FrequencyBand]
    public let confidenceScore: Double    // 0-1

    public struct FrequencyBand: Codable, Sendable {
        public let centerFrequency: Double
        public let bandwidth: Double
        public let power: Double
    }
}

/// EVM (Eulerian Video Magnification) analysis result
public struct EVMAnalysisResult: Codable, Sendable {
    public let timestamp: Date
    public let detectedFrequencies: [Double]  // Hz
    public let spatialAmplitudes: [Double]    // Per-region amplitudes
    public let motionVectors: [(x: Double, y: Double)]
    public let qualityScore: Double           // 0-1, based on lighting/stability

    enum CodingKeys: String, CodingKey {
        case timestamp, detectedFrequencies, spatialAmplitudes, qualityScore
    }

    public init(timestamp: Date, detectedFrequencies: [Double], spatialAmplitudes: [Double], motionVectors: [(x: Double, y: Double)], qualityScore: Double) {
        self.timestamp = timestamp
        self.detectedFrequencies = detectedFrequencies
        self.spatialAmplitudes = spatialAmplitudes
        self.motionVectors = motionVectors
        self.qualityScore = qualityScore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        detectedFrequencies = try container.decode([Double].self, forKey: .detectedFrequencies)
        spatialAmplitudes = try container.decode([Double].self, forKey: .spatialAmplitudes)
        qualityScore = try container.decode(Double.self, forKey: .qualityScore)
        motionVectors = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(detectedFrequencies, forKey: .detectedFrequencies)
        try container.encode(spatialAmplitudes, forKey: .spatialAmplitudes)
        try container.encode(qualityScore, forKey: .qualityScore)
    }
}

/// Inertial measurement result from accelerometer
public struct InertialAnalysisResult: Codable, Sendable {
    public let timestamp: Date
    public let dominantFrequency: Double      // Hz (30-50 Hz target range)
    public let frequencySpectrum: [Double]    // FFT bins
    public let peakAcceleration: Double       // m/s²
    public let rmsVibration: Double           // Root mean square
    public let isInTargetRange: Bool          // True if 30-50 Hz detected
}

/// Combined biophysical state
public struct BiophysicalState: Codable, Sendable {
    public let timestamp: Date
    public let evmResult: EVMAnalysisResult?
    public let inertialResult: InertialAnalysisResult?
    public let stimulationActive: Bool
    public let currentPreset: BiophysicalPreset
    public let sessionDuration: TimeInterval
    public let coherenceScore: Double         // 0-1
}

// MARK: - Biophysical Presets

/// Evidence-based frequency presets for wellness
public enum BiophysicalPreset: String, CaseIterable, Codable, Sendable {
    case boneHarmony = "Bone Harmony"       // 35-45 Hz
    case muscleFlow = "Muscle Flow"         // 45-50 Hz
    case neuralFocus = "Neural Focus"       // 40 Hz (Gamma)
    case relaxation = "Deep Relaxation"     // 10 Hz (Alpha)
    case circulation = "Circulation"        // 25-35 Hz
    case custom = "Custom"

    /// Primary frequency in Hz
    public var primaryFrequency: Double {
        switch self {
        case .boneHarmony: return 40.0      // Center of 35-45 Hz
        case .muscleFlow: return 47.5       // Center of 45-50 Hz
        case .neuralFocus: return 40.0      // Gamma oscillation
        case .relaxation: return 10.0       // Alpha waves
        case .circulation: return 30.0      // Center of 25-35 Hz
        case .custom: return 40.0           // Default
        }
    }

    /// Frequency range (min, max) in Hz
    public var frequencyRange: (min: Double, max: Double) {
        switch self {
        case .boneHarmony: return (35.0, 45.0)
        case .muscleFlow: return (45.0, 50.0)
        case .neuralFocus: return (38.0, 42.0)
        case .relaxation: return (8.0, 12.0)
        case .circulation: return (25.0, 35.0)
        case .custom: return (1.0, 60.0)
        }
    }

    /// Recommended session duration in seconds
    public var recommendedDuration: TimeInterval {
        switch self {
        case .boneHarmony: return 600      // 10 minutes
        case .muscleFlow: return 480       // 8 minutes
        case .neuralFocus: return 720      // 12 minutes
        case .relaxation: return 900       // 15 minutes
        case .circulation: return 600      // 10 minutes
        case .custom: return 600           // 10 minutes default
        }
    }

    /// Vibration intensity (0-1)
    public var vibrationIntensity: Double {
        switch self {
        case .boneHarmony: return 0.6
        case .muscleFlow: return 0.7
        case .neuralFocus: return 0.5
        case .relaxation: return 0.3
        case .circulation: return 0.5
        case .custom: return 0.5
        }
    }

    /// Scientific reference (educational)
    public var educationalReference: String {
        switch self {
        case .boneHarmony:
            return "Rubin et al. (2006): Low-magnitude mechanical signals and bone adaptation"
        case .muscleFlow:
            return "Judex & Rubin (2010): Mechanical influences on bone mass and morphology"
        case .neuralFocus:
            return "Iaccarino et al. (2016): 40 Hz gamma entrainment research"
        case .relaxation:
            return "Alpha wave research in relaxation response"
        case .circulation:
            return "Vibration therapy research for circulation"
        case .custom:
            return "Custom frequency exploration"
        }
    }

    /// Cymatics visual pattern type
    public var cymaticsPattern: CymaticsPattern {
        switch self {
        case .boneHarmony: return .hexagonal
        case .muscleFlow: return .muscularWave
        case .neuralFocus: return .neural
        case .relaxation: return .flowingWater
        case .circulation: return .vortex
        case .custom: return .geometric
        }
    }
}

/// Cymatics visual pattern types
public enum CymaticsPattern: String, CaseIterable, Codable, Sendable {
    case hexagonal = "Hexagonal"
    case muscularWave = "Muscular Wave"
    case neural = "Neural Network"
    case flowingWater = "Flowing Water"
    case vortex = "Vortex"
    case geometric = "Geometric"
    case mandala = "Mandala"
    case cellular = "Cellular"
}

// MARK: - Session State

/// Biophysical session state
public struct BiophysicalSessionState: Codable, Sendable {
    public var isActive: Bool = false
    public var startTime: Date?
    public var duration: TimeInterval = 0
    public var preset: BiophysicalPreset = .boneHarmony
    public var customFrequency: Double = 40.0
    public var vibrationEnabled: Bool = true
    public var soundEnabled: Bool = true
    public var visualsEnabled: Bool = true
    public var evmEnabled: Bool = false
    public var inertialEnabled: Bool = true
    public var coherenceHistory: [Double] = []
    public var frequencyHistory: [Double] = []
    public var disclaimerAcknowledged: Bool = false

    /// Session progress (0-1)
    public var progress: Double {
        guard isActive, let start = startTime else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return min(1.0, elapsed / preset.recommendedDuration)
    }

    /// Average coherence score
    public var averageCoherence: Double {
        guard !coherenceHistory.isEmpty else { return 0 }
        return coherenceHistory.reduce(0, +) / Double(coherenceHistory.count)
    }
}

// MARK: - Biophysical Wellness Engine

/// Main coordinator for biophysical measurement and feedback
@MainActor
public final class BiophysicalWellnessEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var state = BiophysicalSessionState()
    @Published public private(set) var currentEVMResult: EVMAnalysisResult?
    @Published public private(set) var currentInertialResult: InertialAnalysisResult?
    @Published public private(set) var currentCoherence: Double = 0.0
    @Published public private(set) var isStimulating: Bool = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Sub-Engines

    private var evmEngine: EVMAnalysisEngine?
    private var inertialEngine: InertialAnalysisEngine?
    private var stimulationEngine: TapticStimulationEngine?
    private var cymaticsVisualizer: CymaticsVisualizer?
    private var audioGenerator: BiophysicalAudioGenerator?

    // MARK: - Session Management

    private var sessionTimer: Timer?
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Safety Limits

    /// Maximum session duration (15 minutes)
    public static let maxSessionDuration: TimeInterval = 900

    /// Duty cycle limit for haptics (70% max)
    public static let maxDutyCycle: Double = 0.7

    /// Maximum vibration intensity
    public static let maxVibrationIntensity: Double = 0.8

    // MARK: - Initialization

    public init() {
        setupSubEngines()
    }

    private func setupSubEngines() {
        evmEngine = EVMAnalysisEngine()
        inertialEngine = InertialAnalysisEngine()
        stimulationEngine = TapticStimulationEngine()
        cymaticsVisualizer = CymaticsVisualizer()
        audioGenerator = BiophysicalAudioGenerator()
    }

    // MARK: - Public API

    /// Acknowledge disclaimer (required before use)
    public func acknowledgeDisclaimer() {
        state.disclaimerAcknowledged = true
    }

    /// Start biophysical session with preset
    public func startSession(preset: BiophysicalPreset) async throws {
        guard state.disclaimerAcknowledged else {
            throw BiophysicalError.disclaimerNotAcknowledged
        }

        guard !state.isActive else {
            throw BiophysicalError.sessionAlreadyActive
        }

        state.preset = preset
        state.startTime = Date()
        state.isActive = true
        state.coherenceHistory = []
        state.frequencyHistory = []

        // Start sub-engines
        if state.inertialEnabled {
            try await inertialEngine?.startAnalysis(sampleRate: 100)
        }

        if state.evmEnabled {
            try await evmEngine?.startAnalysis(frequencyRange: preset.frequencyRange)
        }

        // Start update loop
        startUpdateLoop()

        // Start session timer with safety limit
        startSessionTimer()

        // Begin stimulation if enabled
        if state.vibrationEnabled || state.soundEnabled {
            try await startStimulation()
        }
    }

    /// Stop current session
    public func stopSession() async {
        state.isActive = false
        state.duration = Date().timeIntervalSince(state.startTime ?? Date())

        stopUpdateLoop()
        stopSessionTimer()

        await stopStimulation()

        inertialEngine?.stopAnalysis()
        evmEngine?.stopAnalysis()
    }

    /// Set custom frequency (for custom preset)
    public func setCustomFrequency(_ frequency: Double) {
        guard frequency >= 1.0 && frequency <= 60.0 else { return }
        state.customFrequency = frequency

        if state.isActive && state.preset == .custom {
            Task {
                await updateStimulationFrequency(frequency)
            }
        }
    }

    /// Toggle individual modalities
    public func setVibrationEnabled(_ enabled: Bool) {
        state.vibrationEnabled = enabled
        if state.isActive {
            Task {
                if enabled {
                    try? await stimulationEngine?.startHapticPattern(
                        frequency: currentFrequency,
                        intensity: state.preset.vibrationIntensity
                    )
                } else {
                    stimulationEngine?.stopHaptics()
                }
            }
        }
    }

    public func setSoundEnabled(_ enabled: Bool) {
        state.soundEnabled = enabled
        if state.isActive {
            if enabled {
                audioGenerator?.startTone(frequency: currentFrequency, amplitude: 0.3)
            } else {
                audioGenerator?.stopTone()
            }
        }
    }

    public func setVisualsEnabled(_ enabled: Bool) {
        state.visualsEnabled = enabled
    }

    public func setEVMEnabled(_ enabled: Bool) async throws {
        state.evmEnabled = enabled
        if state.isActive {
            if enabled {
                try await evmEngine?.startAnalysis(frequencyRange: state.preset.frequencyRange)
            } else {
                evmEngine?.stopAnalysis()
            }
        }
    }

    // MARK: - Current Values

    /// Current stimulation frequency
    public var currentFrequency: Double {
        if state.preset == .custom {
            return state.customFrequency
        }
        return state.preset.primaryFrequency
    }

    /// Current session remaining time
    public var remainingTime: TimeInterval {
        guard state.isActive, let start = state.startTime else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        let maxDuration = min(Self.maxSessionDuration, state.preset.recommendedDuration)
        return max(0, maxDuration - elapsed)
    }

    // MARK: - Private Methods

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateLoop()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateLoop() async {
        guard state.isActive else { return }

        // Update duration
        if let start = state.startTime {
            state.duration = Date().timeIntervalSince(start)
        }

        // Get latest analysis results
        if let inertial = inertialEngine?.latestResult {
            currentInertialResult = inertial
            state.frequencyHistory.append(inertial.dominantFrequency)
        }

        if let evm = evmEngine?.latestResult {
            currentEVMResult = evm
        }

        // Calculate coherence from sensor alignment
        currentCoherence = calculateCoherence()
        state.coherenceHistory.append(currentCoherence)

        // Update cymatics visualizer
        if state.visualsEnabled {
            cymaticsVisualizer?.update(
                frequency: currentFrequency,
                amplitude: currentCoherence,
                pattern: state.preset.cymaticsPattern
            )
        }
    }

    private func calculateCoherence() -> Double {
        // Coherence based on how well detected frequencies match target
        guard let inertial = currentInertialResult else { return 0.5 }

        let targetFreq = currentFrequency
        let detectedFreq = inertial.dominantFrequency
        let range = state.preset.frequencyRange

        // Check if detected frequency is in target range
        if detectedFreq >= range.min && detectedFreq <= range.max {
            // Higher coherence the closer to center
            let center = (range.min + range.max) / 2
            let maxDistance = (range.max - range.min) / 2
            let distance = abs(detectedFreq - center)
            return 1.0 - (distance / maxDistance) * 0.5
        }

        // Outside range, lower coherence
        let distance = min(abs(detectedFreq - range.min), abs(detectedFreq - range.max))
        return max(0, 0.5 - distance * 0.02)
    }

    private func startSessionTimer() {
        let maxDuration = min(Self.maxSessionDuration, state.preset.recommendedDuration)

        sessionTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.stopSession()
                self?.errorMessage = "Session completed (time limit reached)"
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func startStimulation() async throws {
        isStimulating = true

        let frequency = currentFrequency
        let intensity = min(state.preset.vibrationIntensity, Self.maxVibrationIntensity)

        if state.vibrationEnabled {
            try await stimulationEngine?.startHapticPattern(
                frequency: frequency,
                intensity: intensity
            )
        }

        if state.soundEnabled {
            audioGenerator?.startTone(frequency: frequency, amplitude: 0.3)
        }
    }

    private func stopStimulation() async {
        isStimulating = false
        stimulationEngine?.stopHaptics()
        audioGenerator?.stopTone()
    }

    private func updateStimulationFrequency(_ frequency: Double) async {
        if state.vibrationEnabled {
            stimulationEngine?.updateFrequency(frequency)
        }

        if state.soundEnabled {
            audioGenerator?.updateFrequency(frequency)
        }

        if state.visualsEnabled {
            cymaticsVisualizer?.update(
                frequency: frequency,
                amplitude: currentCoherence,
                pattern: state.preset.cymaticsPattern
            )
        }
    }

    // MARK: - Cleanup

    deinit {
        sessionTimer?.invalidate()
        updateTimer?.invalidate()
    }
}

// MARK: - Errors

public enum BiophysicalError: Error, LocalizedError {
    case disclaimerNotAcknowledged
    case sessionAlreadyActive
    case sensorNotAvailable
    case hapticEngineNotAvailable
    case frequencyOutOfRange
    case sessionTimeout
    case cameraAccessDenied

    public var errorDescription: String? {
        switch self {
        case .disclaimerNotAcknowledged:
            return "Please acknowledge the wellness disclaimer before using this tool"
        case .sessionAlreadyActive:
            return "A session is already in progress"
        case .sensorNotAvailable:
            return "Required sensors are not available on this device"
        case .hapticEngineNotAvailable:
            return "Haptic feedback is not available on this device"
        case .frequencyOutOfRange:
            return "Frequency must be between 1-60 Hz"
        case .sessionTimeout:
            return "Session automatically stopped (15 minute safety limit)"
        case .cameraAccessDenied:
            return "Camera access is required for visual analysis"
        }
    }
}

// TapticStimulationEngine.swift
// Echoelmusic
//
// Haptic stimulation engine using CoreHaptics for precise frequency-based
// vibration patterns. Implements LMHFV (Low-Magnitude High-Frequency Vibration)
// for wellness applications.
//
// DISCLAIMER: For wellness purposes only. Not a medical therapeutic device.
// Vibration-based wellness is for relaxation and exploration only.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import CoreHaptics
import AVFoundation

// MARK: - Haptic Pattern Type

/// Types of haptic patterns for different wellness experiences
public enum TapticPatternType: String, CaseIterable, Codable, Sendable {
    case continuous = "Continuous"           // Steady vibration at target frequency
    case pulsed = "Pulsed"                   // On/off pattern
    case ramping = "Ramping"                 // Gradual intensity changes
    case binaural = "Binaural"               // Alternating left/right (if supported)
    case coherent = "Coherent"               // Synchronized with bio-signals
    case breathing = "Breathing"             // Follows breath pattern
    case heartSync = "Heart Sync"            // Follows heart rate

    /// Duration of one pattern cycle in seconds
    public var cycleDuration: TimeInterval {
        switch self {
        case .continuous: return 0.1
        case .pulsed: return 0.05
        case .ramping: return 2.0
        case .binaural: return 0.1
        case .coherent: return 1.0
        case .breathing: return 4.0
        case .heartSync: return 1.0
        }
    }
}

// MARK: - Haptic Configuration

/// Configuration for haptic stimulation
public struct HapticStimulationConfig: Codable, Sendable {
    /// Target frequency in Hz (30-50 Hz optimal range)
    public var frequency: Double

    /// Intensity (0.0 - 1.0)
    public var intensity: Double

    /// Pattern type
    public var patternType: TapticPatternType

    /// Duty cycle (0.0 - 1.0) for pulsed patterns
    public var dutyCycle: Double

    /// Ramp duration for ramping patterns
    public var rampDuration: TimeInterval

    /// Enable audio accompaniment
    public var audioEnabled: Bool

    public init(
        frequency: Double = 40.0,
        intensity: Double = 0.5,
        patternType: TapticPatternType = .continuous,
        dutyCycle: Double = 0.5,
        rampDuration: TimeInterval = 1.0,
        audioEnabled: Bool = false
    ) {
        self.frequency = frequency
        self.intensity = min(0.8, max(0.0, intensity))  // Safety limit
        self.patternType = patternType
        self.dutyCycle = min(0.7, max(0.1, dutyCycle))  // Safety limit
        self.rampDuration = rampDuration
        self.audioEnabled = audioEnabled
    }
}

// MARK: - Taptic Stimulation Engine

/// Engine for generating precise haptic patterns using CoreHaptics
/// Supports frequencies in the 30-50 Hz range for LMHFV applications
public final class TapticStimulationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentFrequency: Double = 0.0
    @Published public private(set) var currentIntensity: Double = 0.0
    @Published public private(set) var sessionDuration: TimeInterval = 0.0

    // MARK: - Private Properties

    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var config: HapticStimulationConfig

    // Session tracking
    private var sessionStartTime: Date?
    private var updateTimer: Timer?

    // Safety limits
    private let maxIntensity: Float = 0.8
    private let maxDutyCycle: Float = 0.7
    private let maxSessionDuration: TimeInterval = 900  // 15 minutes

    // MARK: - Initialization

    public init() {
        self.config = HapticStimulationConfig()
        setupHapticEngine()
    }

    // MARK: - Engine Setup

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            log.info("Haptics not supported on this device")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()

            // Configure for continuous playback
            hapticEngine?.playsHapticsOnly = true
            hapticEngine?.isMutedForAudio = true
            hapticEngine?.isAutoShutdownEnabled = false

            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                self?.handleEngineReset()
            }

            // Handle engine stopped
            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.handleEngineStopped(reason: reason)
            }

            try hapticEngine?.start()

        } catch {
            log.error("Failed to create haptic engine: \(error)")
        }
    }

    private func handleEngineReset() {
        do {
            try hapticEngine?.start()

            // Restart pattern if was playing
            if isActive {
                Task {
                    try? await startHapticPattern(
                        frequency: config.frequency,
                        intensity: config.intensity
                    )
                }
            }
        } catch {
            log.error("Failed to restart haptic engine: \(error)")
        }
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        log.info("Haptic engine stopped: \(reason)")

        Task { @MainActor in
            isActive = false
        }
    }

    // MARK: - Public API

    /// Check if haptics are supported
    public var isHapticsSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Start haptic pattern at specified frequency and intensity
    public func startHapticPattern(frequency: Double, intensity: Double) async throws {
        guard isHapticsSupported else {
            throw BiophysicalError.hapticEngineNotAvailable
        }

        guard frequency >= 1.0 && frequency <= 60.0 else {
            throw BiophysicalError.frequencyOutOfRange
        }

        // Ensure engine is started
        try hapticEngine?.start()

        config.frequency = frequency
        config.intensity = min(Double(maxIntensity), intensity)

        // Create the haptic pattern
        let pattern = try createContinuousPattern(
            frequency: frequency,
            intensity: Float(config.intensity)
        )

        // Create player
        continuousPlayer = try hapticEngine?.makeAdvancedPlayer(with: pattern)
        continuousPlayer?.loopEnabled = true

        // Start playback
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)

        // Start session tracking
        sessionStartTime = Date()
        startSessionTimer()

        await MainActor.run {
            isActive = true
            currentFrequency = frequency
            currentIntensity = config.intensity
        }
    }

    /// Stop haptic playback
    public func stopHaptics() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("Error stopping haptic playback: \(error)")
        }

        stopSessionTimer()
        continuousPlayer = nil

        Task { @MainActor in
            isActive = false
            currentFrequency = 0
            currentIntensity = 0
        }
    }

    /// Update frequency while playing
    public func updateFrequency(_ frequency: Double) {
        guard frequency >= 1.0 && frequency <= 60.0 else { return }

        config.frequency = frequency

        Task { @MainActor in
            currentFrequency = frequency
        }

        // Update dynamic parameters
        do {
            // Calculate period from frequency
            let period = 1.0 / frequency

            // Create parameter curve for frequency change
            let frequencyParam = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: Float(config.intensity),
                relativeTime: 0
            )

            try continuousPlayer?.sendParameters([frequencyParam], atTime: CHHapticTimeImmediate)

            // For true frequency changes, we need to restart with new pattern
            if isActive {
                try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
                let pattern = try createContinuousPattern(
                    frequency: frequency,
                    intensity: Float(config.intensity)
                )
                continuousPlayer = try hapticEngine?.makeAdvancedPlayer(with: pattern)
                continuousPlayer?.loopEnabled = true
                try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            }

        } catch {
            log.error("Error updating frequency: \(error)")
        }
    }

    /// Update intensity while playing
    public func updateIntensity(_ intensity: Double) {
        let safeIntensity = min(Double(maxIntensity), max(0, intensity))
        config.intensity = safeIntensity

        Task { @MainActor in
            currentIntensity = safeIntensity
        }

        do {
            let intensityParam = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: Float(safeIntensity),
                relativeTime: 0
            )

            try continuousPlayer?.sendParameters([intensityParam], atTime: CHHapticTimeImmediate)

        } catch {
            log.error("Error updating intensity: \(error)")
        }
    }

    /// Play preset pattern
    public func playPreset(_ preset: BiophysicalPreset) async throws {
        try await startHapticPattern(
            frequency: preset.primaryFrequency,
            intensity: preset.vibrationIntensity
        )
    }

    // MARK: - Pattern Creation

    /// Create continuous haptic pattern at specified frequency
    private func createContinuousPattern(frequency: Double, intensity: Float) throws -> CHHapticPattern {
        // CoreHaptics works best with event-based patterns
        // For high frequencies (30-50 Hz), we create rapid transient events

        let period = 1.0 / frequency
        let patternDuration: TimeInterval = 1.0  // 1 second pattern that loops

        var events: [CHHapticEvent] = []

        // Create events at the target frequency
        var time: TimeInterval = 0
        while time < patternDuration {
            // Transient event for each "tick"
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: time
            )
            events.append(event)

            time += period
        }

        // Add continuous component for smoother feel
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0,
            duration: patternDuration
        )
        events.append(continuousEvent)

        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Create pulsed pattern with duty cycle
    private func createPulsedPattern(frequency: Double, intensity: Float, dutyCycle: Float) throws -> CHHapticPattern {
        let safeDutyCycle = min(maxDutyCycle, dutyCycle)
        let period = 1.0 / frequency
        let onDuration = period * Double(safeDutyCycle)
        let patternDuration: TimeInterval = 1.0

        var events: [CHHapticEvent] = []
        var time: TimeInterval = 0

        while time < patternDuration {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: time,
                duration: onDuration
            )
            events.append(event)

            time += period
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    /// Create ramping pattern for gradual intensity changes
    private func createRampingPattern(frequency: Double, intensity: Float, rampDuration: TimeInterval) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var parameterCurves: [CHHapticParameterCurve] = []

        // Main continuous event
        let mainEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: rampDuration * 2
        )
        events.append(mainEvent)

        // Ramp up curve
        let rampUpCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0),
                CHHapticParameterCurve.ControlPoint(relativeTime: rampDuration, value: intensity),
                CHHapticParameterCurve.ControlPoint(relativeTime: rampDuration * 2, value: 0)
            ],
            relativeTime: 0
        )
        parameterCurves.append(rampUpCurve)

        return try CHHapticPattern(events: events, parameterCurves: parameterCurves)
    }

    // MARK: - Preset Patterns

    /// Get pattern for specific wellness preset
    public func createPresetPattern(_ preset: BiophysicalPreset) throws -> CHHapticPattern {
        let frequency = preset.primaryFrequency
        let intensity = Float(preset.vibrationIntensity)

        switch preset {
        case .boneHarmony:
            // Steady continuous pattern for bone resonance
            return try createContinuousPattern(frequency: frequency, intensity: intensity)

        case .muscleFlow:
            // Slightly pulsed for muscle activation
            return try createPulsedPattern(frequency: frequency, intensity: intensity, dutyCycle: 0.6)

        case .neuralFocus:
            // Precise 40 Hz gamma
            return try createContinuousPattern(frequency: 40.0, intensity: intensity * 0.8)

        case .relaxation:
            // Gentle ramping alpha
            return try createRampingPattern(frequency: frequency, intensity: intensity * 0.5, rampDuration: 2.0)

        case .circulation:
            // Moderate pulsing
            return try createPulsedPattern(frequency: frequency, intensity: intensity, dutyCycle: 0.5)

        case .custom:
            return try createContinuousPattern(frequency: frequency, intensity: intensity)
        }
    }

    // MARK: - Session Management

    private func startSessionTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.sessionStartTime else { return }

            let duration = Date().timeIntervalSince(startTime)

            Task { @MainActor in
                self.sessionDuration = duration
            }

            // Safety timeout
            if duration >= self.maxSessionDuration {
                self.stopHaptics()
            }
        }
    }

    private func stopSessionTimer() {
        updateTimer?.invalidate()
        updateTimer = nil

        Task { @MainActor in
            sessionDuration = 0
        }
    }

    // MARK: - Cleanup

    deinit {
        stopHaptics()
        hapticEngine?.stop()
    }
}

// MARK: - Frequency Reference

/*
 TAPTIC ENGINE FREQUENCY REFERENCE (for CLAUDE.md):

 iOS Taptic Engine Capabilities:
 - iPhone 8+: Taptic Engine supports up to ~250 Hz
 - Optimal haptic perception: 20-300 Hz
 - Best frequency range for LMHFV: 30-50 Hz

 CoreHaptics Considerations:
 - CHHapticTransient: Single "tap" events, good for high-frequency patterns
 - CHHapticContinuous: Sustained vibration, intensity/sharpness controllable
 - Dynamic parameters can modify intensity in real-time
 - Pattern duration affects memory usage

 Safety Guidelines:
 - Maximum intensity: 0.8 (80%) to prevent discomfort
 - Maximum duty cycle: 0.7 (70%) to allow rest periods
 - Session timeout: 15 minutes maximum
 - Temperature monitoring recommended for extended use

 Android VibrationEffect Comparison:
 - VibrationEffect.createOneShot(): Similar to CHHapticTransient
 - VibrationEffect.createWaveform(): Pattern-based vibration
 - PRIMITIVE_TICK at ~45 Hz (Android 12+)
 - Lower frequency resolution than iOS Taptic Engine
 - Haptic strength varies significantly by device

 Research References (Educational):
 - Rubin et al. (2006): 30-90 Hz range studied
 - Typically 30-45 Hz for bone applications
 - 40 Hz specifically studied for neural applications
 - Amplitude typically 0.3-1.0 g (low magnitude)
 */

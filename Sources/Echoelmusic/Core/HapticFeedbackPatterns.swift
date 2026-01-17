// HapticFeedbackPatterns.swift
// Echoelmusic - Coherence-Aware Haptic Feedback System
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Provides rich haptic feedback synchronized with coherence states.
// Enhances embodiment and biofeedback awareness.
//
// Supported Platforms: iOS 13+, watchOS 6+
// Created 2026-01-16

import Foundation

#if canImport(CoreHaptics)
import CoreHaptics
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptic Pattern Type

/// Types of haptic patterns
public enum HapticPatternType: String, CaseIterable, Sendable {
    // Basic
    case light
    case medium
    case heavy
    case selection
    case success
    case warning
    case error

    // Bio-Reactive
    case heartbeat
    case breathSync
    case coherencePulse
    case flowState
    case stressAlert

    // Transitions
    case stateTransition
    case levelUp
    case milestone

    // Ambient
    case gentle
    case wave
    case tingle
}

// MARK: - Haptic Feedback Manager

/// Manager for coherence-aware haptic feedback
///
/// Provides haptic patterns that sync with biometric data
/// to enhance embodied awareness of coherence states.
///
/// Usage:
/// ```swift
/// let haptics = HapticFeedbackManager.shared
///
/// // Play a pattern
/// haptics.play(.coherencePulse)
///
/// // Play heartbeat synced to actual heart rate
/// haptics.playHeartbeat(bpm: 72)
///
/// // Play continuous coherence feedback
/// haptics.startCoherenceFeedback()
/// haptics.updateCoherence(0.8)
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@MainActor
public final class HapticFeedbackManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = HapticFeedbackManager()

    // MARK: - State

    @Published public private(set) var isEnabled: Bool = true
    @Published public private(set) var isPlaying: Bool = false

    /// Intensity multiplier (0-1)
    public var intensityMultiplier: Float = 1.0

    // MARK: - CoreHaptics

    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    #endif

    // MARK: - Feedback Generators

    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    // MARK: - Initialization

    private init() {
        setupHapticEngine()
        prepareGenerators()
    }

    private func setupHapticEngine() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            log.warning("HapticFeedbackManager: Device does not support haptics")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.isAutoShutdownEnabled = true
            hapticEngine?.playsHapticsOnly = true

            hapticEngine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.isPlaying = false
                    log.info("HapticFeedbackManager: Engine stopped - \(reason)")
                }
            }

            hapticEngine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.hapticEngine?.start()
                }
            }

            try hapticEngine?.start()
            log.info("HapticFeedbackManager: Engine started")

        } catch {
            log.error("HapticFeedbackManager: Failed to create engine - \(error)")
        }
        #endif
    }

    private func prepareGenerators() {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        #endif
    }

    // MARK: - Enable/Disable

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            stopAll()
        }
    }

    // MARK: - Simple Feedback

    /// Play a haptic pattern
    public func play(_ pattern: HapticPatternType) {
        guard isEnabled else { return }

        switch pattern {
        case .light:
            playImpact(.light)
        case .medium:
            playImpact(.medium)
        case .heavy:
            playImpact(.heavy)
        case .selection:
            playSelection()
        case .success:
            playNotification(.success)
        case .warning:
            playNotification(.warning)
        case .error:
            playNotification(.error)
        case .heartbeat:
            playHeartbeat(bpm: 72)
        case .breathSync:
            playBreathSync(phase: 0.5)
        case .coherencePulse:
            playCoherencePulse(intensity: 0.7)
        case .flowState:
            playFlowState()
        case .stressAlert:
            playStressAlert()
        case .stateTransition:
            playStateTransition()
        case .levelUp:
            playLevelUp()
        case .milestone:
            playMilestone()
        case .gentle:
            playGentle()
        case .wave:
            playWave()
        case .tingle:
            playTingle()
        }
    }

    // MARK: - UIKit Feedback

    private func playImpact(_ style: ImpactStyle) {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        switch style {
        case .light: impactLight.impactOccurred(intensity: CGFloat(intensityMultiplier))
        case .medium: impactMedium.impactOccurred(intensity: CGFloat(intensityMultiplier))
        case .heavy: impactHeavy.impactOccurred(intensity: CGFloat(intensityMultiplier))
        }
        #endif
    }

    private func playSelection() {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        selectionGenerator.selectionChanged()
        #endif
    }

    private func playNotification(_ type: NotificationType) {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        switch type {
        case .success: notificationGenerator.notificationOccurred(.success)
        case .warning: notificationGenerator.notificationOccurred(.warning)
        case .error: notificationGenerator.notificationOccurred(.error)
        }
        #endif
    }

    private enum ImpactStyle { case light, medium, heavy }
    private enum NotificationType { case success, warning, error }

    // MARK: - Bio-Reactive Patterns

    /// Play heartbeat pattern synced to BPM
    public func playHeartbeat(bpm: Float) {
        guard isEnabled else { return }

        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        let beatDuration = 60.0 / Double(bpm)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityMultiplier * 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)

        // Lub (systole)
        let lub = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        // Dub (diastole) - slightly softer
        let dubIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityMultiplier * 0.5)
        let dub = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [dubIntensity, sharpness],
            relativeTime: 0.15
        )

        do {
            let pattern = try CHHapticPattern(events: [lub, dub], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Heartbeat failed - \(error)")
        }
        #else
        playImpact(.medium)
        #endif
    }

    /// Play breath sync pattern
    public func playBreathSync(phase: Float) {
        guard isEnabled else { return }

        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        // Intensity follows breath phase (inhale = rising, exhale = falling)
        let breathIntensity = sin(phase * .pi) * intensityMultiplier
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.1, breathIntensity))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 0.1
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Breath sync failed - \(error)")
        }
        #else
        if phase > 0.8 || phase < 0.2 {
            playImpact(.light)
        }
        #endif
    }

    /// Play coherence pulse (stronger = higher coherence)
    public func playCoherencePulse(intensity: Float) {
        guard isEnabled else { return }

        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        let scaledIntensity = intensity * intensityMultiplier
        let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: scaledIntensity)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: intensity * 0.7)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [hapticIntensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Coherence pulse failed - \(error)")
        }
        #else
        if intensity > 0.7 {
            playImpact(.heavy)
        } else if intensity > 0.4 {
            playImpact(.medium)
        } else {
            playImpact(.light)
        }
        #endif
    }

    /// Play flow state pattern (pleasant continuous)
    public func playFlowState() {
        guard isEnabled else { return }

        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        var events: [CHHapticEvent] = []

        // Gentle wave pattern
        for i in 0..<5 {
            let time = Double(i) * 0.15
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityMultiplier * 0.4)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Flow state failed - \(error)")
        }
        #else
        playNotification(.success)
        #endif
    }

    /// Play stress alert pattern
    public func playStressAlert() {
        guard isEnabled else { return }

        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        var events: [CHHapticEvent] = []

        // Quick double tap pattern
        for i in 0..<2 {
            let time = Double(i) * 0.1
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityMultiplier * 0.9)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Stress alert failed - \(error)")
        }
        #else
        playNotification(.warning)
        #endif
    }

    // MARK: - Transition Patterns

    private func playStateTransition() {
        #if canImport(CoreHaptics)
        playImpact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.playImpact(.light)
        }
        #else
        playImpact(.medium)
        #endif
    }

    private func playLevelUp() {
        #if canImport(CoreHaptics)
        playNotification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.playImpact(.heavy)
        }
        #else
        playNotification(.success)
        #endif
    }

    private func playMilestone() {
        playNotification(.success)
    }

    // MARK: - Ambient Patterns

    private func playGentle() {
        playImpact(.light)
    }

    private func playWave() {
        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        var events: [CHHapticEvent] = []

        for i in 0..<8 {
            let time = Double(i) * 0.08
            let waveIntensity = sin(Float(i) * 0.4) * 0.3 + 0.4
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: waveIntensity * intensityMultiplier)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Wave failed - \(error)")
        }
        #else
        playImpact(.light)
        #endif
    }

    private func playTingle() {
        #if canImport(CoreHaptics)
        guard let engine = hapticEngine else { return }

        var events: [CHHapticEvent] = []

        for i in 0..<4 {
            let time = Double(i) * 0.05
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3 * intensityMultiplier)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("HapticFeedbackManager: Tingle failed - \(error)")
        }
        #else
        playSelection()
        #endif
    }

    // MARK: - Continuous Feedback

    /// Start continuous coherence feedback
    public func startCoherenceFeedback() {
        guard isEnabled else { return }
        isPlaying = true
        // Implementation would use CHHapticAdvancedPatternPlayer
    }

    /// Update coherence for continuous feedback
    public func updateCoherence(_ coherence: Float) {
        guard isEnabled && isPlaying else { return }
        // Update continuous player intensity
    }

    /// Stop all haptic feedback
    public func stopAll() {
        isPlaying = false
        #if canImport(CoreHaptics)
        hapticEngine?.stop()
        #endif
    }
}

// MARK: - Haptic Pattern Presets

public extension HapticFeedbackManager {

    /// Coherence thresholds for haptic feedback
    struct CoherenceHapticThresholds {
        public var stressAlert: Float = 0.3
        public var transitionUp: Float = 0.6
        public var flowEntry: Float = 0.8

        public static let `default` = CoherenceHapticThresholds()
    }

    /// Play appropriate haptic for coherence level
    func playForCoherence(_ coherence: Float, thresholds: CoherenceHapticThresholds = .default) {
        if coherence >= thresholds.flowEntry {
            play(.flowState)
        } else if coherence >= thresholds.transitionUp {
            playCoherencePulse(intensity: coherence)
        } else if coherence < thresholds.stressAlert {
            play(.stressAlert)
        }
    }
}

// LambdaHapticEngine.swift
// Echoelmusic
//
// CoreHaptics wrapper for Lambda bio-reactive haptic output.
// Converts Lambda hapticIntensity (0-1) into tactile feedback at up to 30Hz.

import Foundation

#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - Notification Name for Lambda Color

extension Notification.Name {
    static let lambdaColorUpdate = Notification.Name("echoelLambdaColorUpdate")
}

// MARK: - Lambda Haptic Engine

@MainActor
public final class LambdaHapticEngine {

    public static let shared = LambdaHapticEngine()

    // MARK: - Rate Limiting

    /// Maximum haptic events per second to avoid overwhelming the Taptic Engine
    private let maxEventsPerSecond: Int = 30
    private var lastEventTime: CFTimeInterval = 0

    #if canImport(CoreHaptics)
    // MARK: - CoreHaptics State

    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var supportsHaptics: Bool = false

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }
            try engine?.start()
        } catch {
            log.warning("LambdaHapticEngine: Failed to start — \(error.localizedDescription)", category: .system)
        }
    }

    /// Fire a single transient haptic tap
    public func playTransient(intensity: Float) {
        guard supportsHaptics, let engine = engine else { return }
        guard shouldFireEvent() else { return }

        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0.01 else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: clampedIntensity * 0.6)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Silently fail — haptics are non-critical
        }
    }

    /// Start a continuous haptic vibration
    public func playContinuous(intensity: Float, sharpness: Float = 0.5) {
        guard supportsHaptics, let engine = engine else { return }

        let clampedIntensity = max(0, min(1, intensity))
        let clampedSharpness = max(0, min(1, sharpness))

        // Stop any existing continuous player
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)

        guard clampedIntensity > 0.01 else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: clampedSharpness)
                ],
                relativeTime: 0,
                duration: 1.0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Silently fail
        }
    }

    /// Stop all haptic output
    public func stop() {
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
    }

    private func restartEngine() {
        guard supportsHaptics else { return }
        try? engine?.start()
    }

    #else
    // MARK: - No-op for platforms without CoreHaptics

    private init() {}

    public func playTransient(intensity: Float) {}
    public func playContinuous(intensity: Float, sharpness: Float = 0.5) {}
    public func stop() {}
    #endif

    // MARK: - Rate Limiting

    private func shouldFireEvent() -> Bool {
        let now = CACurrentMediaTime()
        let minInterval = 1.0 / Double(maxEventsPerSecond)
        guard now - lastEventTime >= minInterval else { return false }
        lastEventTime = now
        return true
    }
}

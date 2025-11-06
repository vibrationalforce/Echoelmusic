import Foundation
import WatchKit

/// Manages haptic feedback for Apple Watch
/// Provides immersive feedback for breathing and biofeedback
@MainActor
class WatchHapticsManager: ObservableObject {

    // MARK: - Haptic Feedback

    /// Play start haptic
    func playStart() {
        WKInterfaceDevice.current().play(.start)
        print("[WatchHaptics] Start")
    }

    /// Play success haptic
    func playSuccess() {
        WKInterfaceDevice.current().play(.success)
        print("[WatchHaptics] Success")
    }

    /// Play failure haptic
    func playFailure() {
        WKInterfaceDevice.current().play(.failure)
        print("[WatchHaptics] Failure")
    }

    /// Play retry haptic
    func playRetry() {
        WKInterfaceDevice.current().play(.retry)
        print("[WatchHaptics] Retry")
    }

    /// Play click haptic
    func playClick() {
        WKInterfaceDevice.current().play(.click)
        print("[WatchHaptics] Click")
    }

    /// Play notification haptic
    func playNotification() {
        WKInterfaceDevice.current().play(.notification)
        print("[WatchHaptics] Notification")
    }

    /// Play direction up haptic
    func playDirectionUp() {
        WKInterfaceDevice.current().play(.directionUp)
        print("[WatchHaptics] Direction Up")
    }

    /// Play direction down haptic
    func playDirectionDown() {
        WKInterfaceDevice.current().play(.directionDown)
        print("[WatchHaptics] Direction Down")
    }

    // MARK: - Breathing-Specific Haptics

    /// Play haptic for breath phase
    func playBreathPhase(_ phase: BreathPhase) {
        switch phase {
        case .inhale:
            // Gentle ascending haptic
            WKInterfaceDevice.current().play(.directionUp)
            print("[WatchHaptics] Breath: Inhale")

        case .hold:
            // Single click
            WKInterfaceDevice.current().play(.click)
            print("[WatchHaptics] Breath: Hold")

        case .exhale:
            // Gentle descending haptic
            WKInterfaceDevice.current().play(.directionDown)
            print("[WatchHaptics] Breath: Exhale")
        }
    }

    /// Play haptic for coherence milestone
    func playCoherenceMilestone(coherence: Double) {
        if coherence >= 80 {
            // Excellent coherence
            WKInterfaceDevice.current().play(.success)
            print("[WatchHaptics] Coherence: Excellent (\(Int(coherence))%)")
        } else if coherence >= 60 {
            // Good coherence
            WKInterfaceDevice.current().play(.notification)
            print("[WatchHaptics] Coherence: Good (\(Int(coherence))%)")
        }
    }

    /// Play heartbeat-synced haptic
    /// Call this in rhythm with detected heart rate
    func playHeartbeat() {
        WKInterfaceDevice.current().play(.click)
        // Note: Silent print to avoid spam
    }

    // MARK: - Pattern Haptics

    /// Play custom haptic pattern (for advanced feedback)
    func playPattern(_ pattern: HapticPattern) {
        switch pattern {
        case .ascending:
            WKInterfaceDevice.current().play(.directionUp)
        case .descending:
            WKInterfaceDevice.current().play(.directionDown)
        case .pulse:
            WKInterfaceDevice.current().play(.click)
        case .alert:
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

enum HapticPattern {
    case ascending
    case descending
    case pulse
    case alert
}

enum BreathPhase {
    case inhale
    case hold
    case exhale
}

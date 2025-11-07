import Foundation
import Combine
import SwiftUI

/// Protocol for ViewModels that react to bio-signals
/// Provides standardized interface for bio-reactive UI components
@MainActor
protocol BioReactiveViewModel: ObservableObject {

    /// Current bio-signals
    var bioSignals: BioSignals { get set }

    /// Whether bio-reactivity is enabled
    var isBioReactiveEnabled: Bool { get set }

    /// Update with new bio-signals
    /// - Parameter signals: New bio-signal data
    func updateBioSignals(_ signals: BioSignals)
}

/// Default implementation for common bio-reactive behavior
extension BioReactiveViewModel {

    /// Update bio-signals and trigger reactive updates
    func updateBioSignals(_ signals: BioSignals) {
        guard isBioReactiveEnabled else { return }
        bioSignals = signals
    }

    /// Get color based on HRV coherence (bio-reactive)
    /// - Parameter coherence: HRV coherence score (0-100)
    /// - Returns: SwiftUI Color (red → yellow → green)
    func coherenceColor(for coherence: Double) -> Color {
        switch coherence {
        case 0..<40:
            // Low coherence: Red (stress)
            return Color(hue: 0.0, saturation: 0.8, brightness: 0.9)
        case 40..<60:
            // Medium coherence: Yellow (transitional)
            let normalized = (coherence - 40.0) / 20.0
            return Color(hue: 0.1 + normalized * 0.2, saturation: 0.8, brightness: 0.9)
        default:
            // High coherence: Green (flow)
            let normalized = min((coherence - 60.0) / 40.0, 1.0)
            return Color(hue: 0.3 + normalized * 0.1, saturation: 0.8, brightness: 0.9)
        }
    }

    /// Get animation speed based on heart rate
    /// - Parameter heartRate: Heart rate in BPM
    /// - Returns: Animation speed multiplier (0.5-2.0)
    func animationSpeed(for heartRate: Double) -> Double {
        // Map 40-120 BPM → 0.5-2.0 speed
        let normalized = (heartRate - 40.0) / 80.0
        return 0.5 + normalized * 1.5
    }

    /// Get breathing phase (0.0-1.0) from breathing rate
    /// - Parameter breathingRate: Breaths per minute
    /// - Returns: Current phase in breathing cycle
    func breathingPhase(for breathingRate: Double, time: TimeInterval) -> Double {
        // Calculate breathing cycle frequency
        let cycleFrequency = breathingRate / 60.0  // Convert to Hz
        let phase = (time * cycleFrequency).truncatingRemainder(dividingBy: 1.0)
        return phase
    }
}

/// SwiftUI ViewModifier for bio-reactive animations
struct BioReactiveModifier: ViewModifier {
    let bioSignals: BioSignals
    let enabled: Bool

    @State private var pulseScale: CGFloat = 1.0
    @State private var breathScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled ? pulseScale : 1.0)
            .animation(
                enabled ? breathingAnimation : .default,
                value: pulseScale
            )
            .onAppear {
                if enabled {
                    startBioReactiveAnimations()
                }
            }
    }

    /// Start bio-reactive animations based on breathing rate
    private func startBioReactiveAnimations() {
        // Calculate breathing cycle duration from rate
        let breathsPerSecond = bioSignals.breathingRate / 60.0
        let cycleDuration = 1.0 / breathsPerSecond

        // Breathing animation (subtle scale)
        withAnimation(.easeInOut(duration: cycleDuration).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + (bioSignals.hrvCoherence / 100.0) * 0.1
        }
    }

    /// Custom breathing animation curve
    private var breathingAnimation: Animation {
        let breathsPerSecond = bioSignals.breathingRate / 60.0
        let cycleDuration = 1.0 / breathsPerSecond
        return .easeInOut(duration: cycleDuration).repeatForever(autoreverses: true)
    }
}

/// SwiftUI View extension for bio-reactive modifiers
extension View {

    /// Apply bio-reactive animation
    /// - Parameters:
    ///   - bioSignals: Current bio-signals
    ///   - enabled: Whether bio-reactivity is enabled
    /// - Returns: Modified view with bio-reactive animations
    func bioReactive(_ bioSignals: BioSignals, enabled: Bool = true) -> some View {
        modifier(BioReactiveModifier(bioSignals: bioSignals, enabled: enabled))
    }

    /// Apply coherence-based color gradient
    /// - Parameter coherence: HRV coherence score (0-100)
    /// - Returns: View with gradient background
    func coherenceGradient(_ coherence: Double) -> some View {
        let startColor: Color
        let endColor: Color

        switch coherence {
        case 0..<40:
            // Stress: Red gradient
            startColor = Color(hue: 0.0, saturation: 0.6, brightness: 0.8)
            endColor = Color(hue: 0.05, saturation: 0.8, brightness: 0.6)
        case 40..<60:
            // Transitional: Yellow-orange gradient
            startColor = Color(hue: 0.1, saturation: 0.7, brightness: 0.9)
            endColor = Color(hue: 0.15, saturation: 0.8, brightness: 0.7)
        default:
            // Flow: Green-cyan gradient
            startColor = Color(hue: 0.3, saturation: 0.6, brightness: 0.9)
            endColor = Color(hue: 0.5, saturation: 0.7, brightness: 0.7)
        }

        return self.background(
            LinearGradient(
                gradient: Gradient(colors: [startColor, endColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// Apply heart rate-based pulse effect
    /// - Parameter heartRate: Heart rate in BPM
    /// - Returns: View with pulsing animation
    func heartRatePulse(_ heartRate: Double) -> some View {
        let beatsPerSecond = heartRate / 60.0
        let pulseDuration = 1.0 / beatsPerSecond

        return self.modifier(HeartRatePulseModifier(
            heartRate: heartRate,
            pulseDuration: pulseDuration
        ))
    }
}

/// Heart rate pulse modifier
struct HeartRatePulseModifier: ViewModifier {
    let heartRate: Double
    let pulseDuration: Double

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.8)
            .animation(
                .easeInOut(duration: pulseDuration / 2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

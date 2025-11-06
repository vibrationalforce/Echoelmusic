import SwiftUI

/// Breathing guidance view with haptic feedback
/// Syncs haptics to breath cycle for immersive guidance
struct BreathingGuideView: View {

    @EnvironmentObject var hapticsManager: WatchHapticsManager
    @EnvironmentObject var healthKitManager: WatchHealthKitManager

    @State private var isBreathing = false
    @State private var breathPhase: BreathPhase = .inhale
    @State private var progress: Double = 0.0

    // Breath timing (in seconds)
    private let inhaleTime: Double = 4.0
    private let holdTime: Double = 2.0
    private let exhaleTime: Double = 6.0

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Breath Guide")
                .font(.headline)
                .foregroundColor(.cyan)

            // Breath Circle Animation
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                // Animated breath circle
                Circle()
                    .fill(breathPhaseColor.gradient)
                    .frame(width: breathCircleSize, height: breathCircleSize)
                    .animation(.easeInOut, value: breathCircleSize)

                // Phase text
                VStack(spacing: 4) {
                    Text(breathPhaseText)
                        .font(.caption.bold())
                        .foregroundColor(.white)

                    Text("\(Int((1.0 - progress) * breathPhaseDuration))")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }

            // Current HRV (for context)
            VStack(spacing: 4) {
                Text("Current HRV")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(Int(healthKitManager.currentHRV)) ms")
                    .font(.title3.bold())
                    .foregroundColor(.green)
            }

            // Start/Stop Button
            Button(action: toggleBreathing) {
                Label(
                    isBreathing ? "Stop" : "Start",
                    systemImage: isBreathing ? "stop.fill" : "play.fill"
                )
                .font(.body.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(isBreathing ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .containerBackground(.black.gradient, for: .navigation)
        .onChange(of: isBreathing) { newValue in
            if newValue {
                startBreathingCycle()
            } else {
                stopBreathingCycle()
            }
        }
    }

    // MARK: - Computed Properties

    var breathCircleSize: CGFloat {
        switch breathPhase {
        case .inhale:
            return 60 + (progress * 60)  // 60 → 120
        case .hold:
            return 120  // Stay at 120
        case .exhale:
            return 120 - (progress * 60)  // 120 → 60
        }
    }

    var breathPhaseColor: Color {
        switch breathPhase {
        case .inhale:
            return .blue
        case .hold:
            return .purple
        case .exhale:
            return .green
        }
    }

    var breathPhaseText: String {
        switch breathPhase {
        case .inhale:
            return "Inhale"
        case .hold:
            return "Hold"
        case .exhale:
            return "Exhale"
        }
    }

    var breathPhaseDuration: Double {
        switch breathPhase {
        case .inhale:
            return inhaleTime
        case .hold:
            return holdTime
        case .exhale:
            return exhaleTime
        }
    }

    // MARK: - Actions

    private func toggleBreathing() {
        isBreathing.toggle()

        if isBreathing {
            // Send haptic for start
            hapticsManager.playStart()
        }
    }

    private func startBreathingCycle() {
        breathPhase = .inhale
        progress = 0.0
        animateBreathPhase()
    }

    private func stopBreathingCycle() {
        // Reset to initial state
        breathPhase = .inhale
        progress = 0.0
    }

    private func animateBreathPhase() {
        guard isBreathing else { return }

        let duration = breathPhaseDuration

        // Send haptic for phase start
        hapticsManager.playBreathPhase(breathPhase)

        // Animate progress
        withAnimation(.linear(duration: duration)) {
            progress = 1.0
        }

        // Move to next phase after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard self.isBreathing else { return }

            // Reset progress
            self.progress = 0.0

            // Move to next phase
            switch self.breathPhase {
            case .inhale:
                self.breathPhase = .hold
            case .hold:
                self.breathPhase = .exhale
            case .exhale:
                self.breathPhase = .inhale
            }

            // Continue cycle
            self.animateBreathPhase()
        }
    }
}

enum BreathPhase {
    case inhale
    case hold
    case exhale
}

#Preview {
    BreathingGuideView()
        .environmentObject(WatchHapticsManager())
        .environmentObject(WatchHealthKitManager())
}

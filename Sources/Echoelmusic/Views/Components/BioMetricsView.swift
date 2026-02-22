import SwiftUI

/// Clean, modern display of biometric data with visual indicators
/// Shows heart rate, HRV coherence, and voice pitch in an elegant layout
/// Uses VaporwaveTheme design system for consistent styling
struct BioMetricsView: View {

    // MARK: - Properties

    /// Heart rate in BPM
    let heartRate: Double

    /// HRV coherence score (0-100)
    let hrvCoherence: Double

    /// Voice pitch in Hz
    let voicePitch: Float

    /// Whether data is actively being recorded
    let isActive: Bool

    // MARK: - State

    @State private var heartScale: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Heart rate with pulsing icon
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(heartRateColor)
                    .scaleEffect(isActive ? heartScale : 1.0)
                    .animation(
                        isActive ? VaporwaveAnimation.pulse : .default,
                        value: heartScale
                    )
                    .neonGlow(color: isActive ? heartRateColor : .clear, radius: 8)

                Text("\(Int(heartRate))")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Heart rate: \(Int(heartRate)) beats per minute")
            .onAppear {
                if isActive {
                    heartScale = 1.2
                }
            }
            .onChange(of: isActive) { newValue in
                heartScale = newValue ? 1.2 : 1.0
            }

            // Coherence gauge (circular progress)
            VStack(spacing: VaporwaveSpacing.sm) {
                ZStack {
                    // Use VaporwaveProgressRing
                    VaporwaveProgressRing(
                        progress: hrvCoherence / 100.0,
                        color: coherenceColor,
                        lineWidth: 6,
                        size: 60
                    )

                    // Coherence number overlay
                    Text("\(Int(hrvCoherence))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(coherenceColor)
                }

                Text("Coherence")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)

                // Coherence state indicator
                Text(coherenceState)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(coherenceColor)
                    .padding(.horizontal, VaporwaveSpacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(coherenceColor.opacity(0.2))
                    )
            }
            .accessibilityLabel("Coherence: \(Int(hrvCoherence)) percent, \(coherenceState)")

            // Voice pitch visualization
            if voicePitch > 0 {
                VStack(spacing: VaporwaveSpacing.sm) {
                    // Pitch wave visualization
                    Canvas { context, size in
                        let path = Path { path in
                            let frequency = CGFloat(voicePitch) / 100.0
                            let amplitude: CGFloat = 15.0
                            let width = size.width

                            path.move(to: CGPoint(x: 0, y: size.height / 2))

                            for x in stride(from: 0, through: width, by: 1) {
                                let angle = (x / width) * 2.0 * .pi * frequency
                                let y = (size.height / 2) + sin(angle) * amplitude
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }

                        context.stroke(
                            path,
                            with: .color(pitchColor),
                            lineWidth: 2.5
                        )
                    }
                    .frame(width: 40, height: 30)

                    Text("\(Int(voicePitch))")
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(pitchColor)

                    Text("Hz")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Voice pitch: \(Int(voicePitch)) Hertz")
            }
        }
        .padding(VaporwaveSpacing.lg)
        .glassCard()
        .neonGlow(color: isActive ? coherenceColor : .clear, radius: 20)
        .opacity(isActive ? 1.0 : 0.6)
    }


    // MARK: - Computed Properties

    /// Heart rate color based on zones using design system
    private var heartRateColor: Color {
        if heartRate < 50 {
            return VaporwaveColors.neonCyan  // Low/resting
        } else if heartRate < 70 {
            return VaporwaveColors.coherenceHigh  // Optimal
        } else if heartRate < 100 {
            return VaporwaveColors.coherenceMedium  // Elevated
        } else {
            return VaporwaveColors.heartRate  // High
        }
    }

    /// Coherence color (HeartMath zones) using design system
    private var coherenceColor: Color {
        if hrvCoherence < 40 {
            return VaporwaveColors.coherenceLow
        } else if hrvCoherence < 60 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    /// Coherence state description
    private var coherenceState: String {
        if hrvCoherence < 40 {
            return "Low"
        } else if hrvCoherence < 60 {
            return "Medium"
        } else {
            return "High"
        }
    }

    /// Voice pitch color using design system
    private var pitchColor: Color {
        if voicePitch < 200 {
            return VaporwaveColors.neonCyan  // Bass
        } else if voicePitch < 400 {
            return VaporwaveColors.neonPurple  // Tenor/Alto
        } else {
            return VaporwaveColors.neonPink  // Soprano
        }
    }
}


// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        VaporwaveGradients.background
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveSpacing.xl) {
                VaporwaveSectionHeader("Low Coherence State", icon: "exclamationmark.triangle")

                BioMetricsView(
                    heartRate: 85,
                    hrvCoherence: 25,
                    voicePitch: 220,
                    isActive: true
                )

                VaporwaveSectionHeader("High Coherence State", icon: "checkmark.circle")

                BioMetricsView(
                    heartRate: 65,
                    hrvCoherence: 80,
                    voicePitch: 440,
                    isActive: true
                )

                VaporwaveSectionHeader("Inactive State", icon: "moon")

                BioMetricsView(
                    heartRate: 60,
                    hrvCoherence: 50,
                    voicePitch: 0,
                    isActive: false
                )
            }
            .padding()
        }
    }
}
#endif

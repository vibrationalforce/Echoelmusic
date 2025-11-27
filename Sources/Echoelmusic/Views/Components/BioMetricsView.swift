import SwiftUI

/// Clean, modern display of biometric data with visual indicators
/// Shows heart rate, HRV coherence, and voice pitch in an elegant layout
struct BioMetricsView: View {

    /// Heart rate in BPM
    let heartRate: Double

    /// HRV coherence score (0-100)
    let hrvCoherence: Double

    /// Voice pitch in Hz
    let voicePitch: Float

    /// Whether data is actively being recorded
    let isActive: Bool

    /// Animation state for pulsing heart
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 30) {
            // Heart rate with pulsing icon
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(heartRateColor)
                    .scaleEffect(isActive ? heartScale : 1.0)
                    .animation(
                        isActive ? Animation.easeInOut(duration: 60.0 / max(heartRate, 1.0)).repeatForever(autoreverses: true) : .default,
                        value: heartScale
                    )
                    .accessibilityHidden(true)

                Text("\(Int(heartRate))")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)

                Text("BPM")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heart Rate")
            .accessibilityValue("\(Int(heartRate)) beats per minute, \(heartRateZoneDescription)")
            .accessibilityHint("Your current heart rate from biometric sensors")
            .onAppear {
                if isActive {
                    heartScale = 1.2
                }
            }
            .onChange(of: isActive) { newValue in
                heartScale = newValue ? 1.2 : 1.0
            }

            // Coherence gauge (circular progress)
            VStack(spacing: 8) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(min(hrvCoherence / 100.0, 1.0)))
                        .stroke(
                            coherenceColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: hrvCoherence)

                    // Coherence number
                    Text("\(Int(hrvCoherence))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(coherenceColor)
                }
                .accessibilityHidden(true)

                Text("Coherence")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .accessibilityHidden(true)

                // Coherence state indicator
                Text(coherenceState)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(coherenceColor.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(coherenceColor.opacity(0.2))
                    )
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("HRV Coherence")
            .accessibilityValue("\(Int(hrvCoherence)) percent, \(coherenceState) coherence")
            .accessibilityHint("Heart rate variability coherence score. Higher values indicate better heart-brain synchronization.")

            // Voice pitch visualization
            if voicePitch > 0 {
                VStack(spacing: 8) {
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
                    .accessibilityHidden(true)

                    Text("\(Int(voicePitch))")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(pitchColor)
                        .accessibilityHidden(true)

                    Text("Hz")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Voice Pitch")
                .accessibilityValue("\(Int(voicePitch)) hertz, \(pitchRangeDescription)")
                .accessibilityHint("Your detected voice pitch frequency")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Biometrics Display")
        .accessibilityHint(isActive ? "Live biometric data is being recorded" : "Biometric monitoring is inactive")
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .shadow(color: isActive ? coherenceColor.opacity(0.3) : .clear, radius: 20)
        )
        .opacity(isActive ? 1.0 : 0.6)
    }


    // MARK: - Computed Properties

    /// Heart rate color based on zones
    private var heartRateColor: Color {
        if heartRate < 50 {
            return Color.blue  // Low/resting
        } else if heartRate < 70 {
            return Color.green  // Optimal
        } else if heartRate < 100 {
            return Color.orange  // Elevated
        } else {
            return Color.red  // High
        }
    }

    /// Heart rate zone description for accessibility
    private var heartRateZoneDescription: String {
        if heartRate < 50 {
            return "resting zone"
        } else if heartRate < 70 {
            return "optimal zone"
        } else if heartRate < 100 {
            return "elevated zone"
        } else {
            return "high zone"
        }
    }

    /// Coherence color (HeartMath zones)
    private var coherenceColor: Color {
        if hrvCoherence < 40 {
            return Color(hue: 0.0, saturation: 0.8, brightness: 0.9)  // Red
        } else if hrvCoherence < 60 {
            return Color(hue: 0.15, saturation: 0.9, brightness: 0.95)  // Yellow
        } else {
            return Color(hue: 0.35, saturation: 0.8, brightness: 0.9)  // Green
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

    /// Voice pitch color
    private var pitchColor: Color {
        if voicePitch < 200 {
            return Color.blue.opacity(0.8)  // Bass
        } else if voicePitch < 400 {
            return Color.purple.opacity(0.8)  // Tenor/Alto
        } else {
            return Color.pink.opacity(0.8)  // Soprano
        }
    }

    /// Voice pitch range description for accessibility
    private var pitchRangeDescription: String {
        if voicePitch < 200 {
            return "bass range"
        } else if voicePitch < 400 {
            return "mid range"
        } else {
            return "high range"
        }
    }
}


// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            Text("Low Coherence State")
                .foregroundColor(.white)
                .font(.headline)

            BioMetricsView(
                heartRate: 85,
                hrvCoherence: 25,
                voicePitch: 220,
                isActive: true
            )

            Text("High Coherence State")
                .foregroundColor(.white)
                .font(.headline)

            BioMetricsView(
                heartRate: 65,
                hrvCoherence: 80,
                voicePitch: 440,
                isActive: true
            )

            Text("Inactive State")
                .foregroundColor(.white)
                .font(.headline)

            BioMetricsView(
                heartRate: 60,
                hrvCoherence: 50,
                voicePitch: 0,
                isActive: false
            )
        }
    }
}

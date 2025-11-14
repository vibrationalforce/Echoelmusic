import SwiftUI
import EchoelmusicBio

/// Real-time bio-feedback display showing HRV, heart rate, and coherence
/// Provides visual feedback for the user's current biometric state
public struct BioFeedbackView: View {

    @ObservedObject var bioFeedbackEngine: BioFeedbackEngine

    public init(bioFeedbackEngine: BioFeedbackEngine) {
        self.bioFeedbackEngine = bioFeedbackEngine
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("🧠 Bio-Feedback")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Enable/Disable toggle
                Toggle("", isOn: Binding(
                    get: { bioFeedbackEngine.isEnabled },
                    set: { _ in bioFeedbackEngine.toggle() }
                ))
                .labelsHidden()
            }

            if bioFeedbackEngine.isEnabled {
                // Coherence state
                CoherenceIndicator(
                    coherence: bioFeedbackEngine.currentCoherence,
                    state: bioFeedbackEngine.coherenceState
                )

                Divider()
                    .background(Color.white.opacity(0.2))

                // Heart rate
                BiometricRow(
                    icon: "❤️",
                    label: "Heart Rate",
                    value: "\(Int(bioFeedbackEngine.currentHeartRate))",
                    unit: "BPM",
                    color: .red
                )

                // HRV
                BiometricRow(
                    icon: "📊",
                    label: "HRV (RMSSD)",
                    value: String(format: "%.1f", bioFeedbackEngine.currentHRV),
                    unit: "ms",
                    color: .blue
                )

                Divider()
                    .background(Color.white.opacity(0.2))

                // Mapped audio parameters
                Text("Mapped Audio Parameters")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ParameterRow(label: "Reverb", value: bioFeedbackEngine.reverbWet, unit: "%")
                ParameterRow(label: "Filter", value: bioFeedbackEngine.filterCutoff, unit: "Hz")
                ParameterRow(label: "Amplitude", value: bioFeedbackEngine.amplitude, unit: "%")
                ParameterRow(label: "Frequency", value: bioFeedbackEngine.baseFrequency, unit: "Hz")

            } else {
                Text("Bio-feedback disabled")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    bioFeedbackEngine.isEnabled
                        ? Color.green.opacity(0.5)
                        : Color.gray.opacity(0.3),
                    lineWidth: 2
                )
        )
    }
}


// MARK: - Coherence Indicator

struct CoherenceIndicator: View {
    let coherence: Double
    let state: BioFeedbackEngine.CoherenceState

    var body: some View {
        VStack(spacing: 8) {
            // Coherence percentage with animated circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                // Progress circle
                Circle()
                    .trim(from: 0, to: coherence / 100.0)
                    .stroke(
                        stateColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: coherence)

                // Coherence value
                VStack(spacing: 2) {
                    Text("\(Int(coherence))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // State label
            HStack(spacing: 4) {
                Text(state.emoji)
                    .font(.system(size: 16))
                Text(state.description)
                    .font(.subheadline)
                    .foregroundColor(stateColor)
            }
        }
    }

    private var stateColor: Color {
        switch state {
        case .low:
            return .red
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }
}


// MARK: - Biometric Row

struct BiometricRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            // Visual indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.3))
                .frame(width: 4, height: 40)
        }
    }
}


// MARK: - Parameter Row

struct ParameterRow: View {
    let label: String
    let value: Float
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    // Progress (normalized to 0-1 range)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geometry.size.width * CGFloat(normalizedValue))
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: 8)

            // Value
            Text(formattedValue)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private var normalizedValue: Float {
        switch label {
        case "Reverb", "Amplitude":
            return value  // Already 0-1
        case "Filter":
            return min(value / 2000.0, 1.0)  // 0-2000 Hz
        case "Frequency":
            return min(value / 1000.0, 1.0)  // 0-1000 Hz
        default:
            return 0
        }
    }

    private var formattedValue: String {
        switch label {
        case "Reverb", "Amplitude":
            return "\(Int(value * 100))\(unit)"
        case "Filter", "Frequency":
            return "\(Int(value))\(unit)"
        default:
            return String(format: "%.1f\(unit)", value)
        }
    }
}


// MARK: - Preview

#if DEBUG
struct BioFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            BioFeedbackView(bioFeedbackEngine: {
                let engine = BioFeedbackEngine()
                engine.isEnabled = true
                // Simulate high coherence state
                engine.currentHeartRate = 72.0
                engine.currentHRV = 65.3
                engine.currentCoherence = 75.0
                engine.reverbWet = 0.6
                engine.filterCutoff = 1200.0
                engine.amplitude = 0.7
                engine.baseFrequency = 432.0
                return engine
            }())
            .padding()
        }
    }
}
#endif

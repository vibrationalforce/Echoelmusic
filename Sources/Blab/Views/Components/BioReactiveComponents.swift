import SwiftUI

/// Reusable bio-reactive UI components for BLAB
/// Reduces code duplication and provides consistent styling

// MARK: - Audio Metrics Display

/// Displays real-time audio metrics (frequency, level, pitch)
struct AudioMetricsDisplay: View {
    let audioLevel: Float
    let frequency: Float?
    let voicePitch: Float

    var body: some View {
        HStack(spacing: 40) {
            // Frequency
            MetricCard(
                icon: "waveform",
                label: "FREQUENCY",
                value: frequency.map { "\(Int($0))" } ?? "—",
                unit: "Hz",
                color: .cyan
            )

            // Audio Level
            MetricCard(
                icon: "circle.fill",
                label: "LEVEL",
                value: String(format: "%.2f", audioLevel),
                unit: "",
                color: .green
            )

            // Voice Pitch
            MetricCard(
                icon: "music.note",
                label: "PITCH",
                value: voicePitch > 0 ? "\(Int(voicePitch))" : "—",
                unit: "Hz",
                color: .purple
            )
        }
        .padding(.horizontal, 20)
    }
}

/// Single metric card component
struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bio Metrics Display

/// Displays biometric data (HRV, HR, Breathing)
struct BioMetricsCompact: View {
    let hrvCoherence: Double
    let heartRate: Double
    let breathingRate: Double

    var body: some View {
        HStack(spacing: 20) {
            // HRV Coherence
            BioMetricBadge(
                icon: "heart.fill",
                value: Int(hrvCoherence),
                unit: "%",
                color: coherenceColor(hrvCoherence)
            )

            // Heart Rate
            BioMetricBadge(
                icon: "waveform.path.ecg",
                value: Int(heartRate),
                unit: "BPM",
                color: .red
            )

            // Breathing Rate
            BioMetricBadge(
                icon: "wind",
                value: Int(breathingRate),
                unit: "BR",
                color: .cyan
            )
        }
    }

    private func coherenceColor(_ coherence: Double) -> Color {
        switch coherence {
        case 0..<40: return .red
        case 40..<60: return .yellow
        default: return .green
        }
    }
}

/// Single bio metric badge
struct BioMetricBadge: View {
    let icon: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))

            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Text(unit)
                .font(.system(size: 8))
                .opacity(0.7)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
    }
}

// MARK: - Record Button

/// Large circular record button with pulse animation
struct RecordButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring (pulsing when recording)
                Circle()
                    .stroke(lineWidth: 3)
                    .foregroundColor(isRecording ? .red : .white.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .scaleEffect(isPulsing && isRecording ? 1.15 : 1.0)
                    .opacity(isPulsing && isRecording ? 0.5 : 1.0)
                    .animation(
                        isRecording ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                        value: isPulsing
                    )

                // Inner circle
                Circle()
                    .fill(isRecording ? Color.red : Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)

                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(isRecording ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isRecording) { newValue in
            isPulsing = newValue
        }
    }
}

// MARK: - Control Button Group

/// Horizontal row of control buttons
struct ControlButtonGroup: View {
    let buttons: [ControlButtonConfig]

    var body: some View {
        HStack(spacing: 15) {
            ForEach(buttons) { config in
                ControlButton(config: config)
            }
        }
        .padding(.horizontal, 30)
    }
}

/// Configuration for a control button
struct ControlButtonConfig: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void
}

/// Single control button
struct ControlButton: View {
    let config: ControlButtonConfig

    var body: some View {
        Button(action: config.action) {
            VStack(spacing: 6) {
                Image(systemName: config.icon)
                    .font(.system(size: 22))
                    .foregroundColor(config.isActive ? config.color : .white.opacity(0.5))

                Text(config.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(config.isActive ? config.color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(config.isActive ? config.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Header Components

/// App header with title and subtitle
struct AppHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(3)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Mode Picker Button

/// Button to show mode picker (visualization, spatial, etc.)
struct ModePickerButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
            )
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct BioReactiveComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                AppHeader(title: "BLAB", subtitle: "breath → sound")

                AudioMetricsDisplay(
                    audioLevel: 0.75,
                    frequency: 440.0,
                    voicePitch: 220.0
                )

                BioMetricsCompact(
                    hrvCoherence: 75.0,
                    heartRate: 72.0,
                    breathingRate: 6.0
                )

                RecordButton(isRecording: .constant(false), action: {})

                ControlButtonGroup(buttons: [
                    ControlButtonConfig(
                        icon: "music.note",
                        label: "BINAURAL",
                        color: .purple,
                        isActive: true,
                        action: {}
                    ),
                    ControlButtonConfig(
                        icon: "cube",
                        label: "SPATIAL",
                        color: .cyan,
                        isActive: false,
                        action: {}
                    )
                ])
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif

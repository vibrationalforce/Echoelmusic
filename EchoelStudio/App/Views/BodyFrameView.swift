import SwiftUI

/// W1-Rest: visible BodyFrame display.
/// Shows pulse, HRV and coherence. Off toggle included.
/// Accessibility complete from the start.
struct BodyFrameView: View {
    @AppStorage("bodyFrameEnabled") private var isEnabled = true
    @State private var pulseBPM: Double = 72
    @State private var hrvMs: Double = 48
    @State private var coherence: Double = 0.62

    var body: some View {
        Group {
            if isEnabled {
                HStack(spacing: 16) {
                    metric(name: "Pulse", value: pulseBPM, unit: "bpm")
                    metric(name: "HRV", value: hrvMs, unit: "ms")
                    metric(name: "Coherence", value: coherence, unit: "")
                    Spacer()
                    Toggle("Body", isOn: $isEnabled)
                        .labelsHidden()
                        .accessibilityLabel("Body source")
                        .accessibilityValue(isEnabled ? "On" : "Off")
                        .accessibilityHint("Turns the body metrics on or off")
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Body frame")
                .accessibilityAddTraits(.updatesFrequently)
            } else {
                HStack {
                    Text("Body off")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Body", isOn: $isEnabled)
                        .labelsHidden()
                        .accessibilityLabel("Body source")
                        .accessibilityValue("Off")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private func metric(name: String, value: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))")
                .font(.title3.monospacedDigit())
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue("\(Int(value.rounded())) \(unit)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    BodyFrameView()
}

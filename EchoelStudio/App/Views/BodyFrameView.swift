// BodyFrameView.swift
// W1-Rest slice: visible BodyFrame display (Puls, HRV, Coherence) + off-switch.
// Accessibility included from the start.
// Pure view for now; publisher wiring follows in a later slice.
// Foundation + SwiftUI only.

import SwiftUI

/// Displays the current BodyFrame values with an off-switch.
/// When off, shows "Body off" and publishes nothing.
struct BodyFrameView: View {
    @AppStorage("bodyFrameEnabled") private var enabled: Bool = true

    // Placeholder values until the real publisher is wired.
    // Replace with actual BodyFrame once the source is connected.
    private let heartRate: Double = 72
    private let hrvNormalized: Double = 0.45
    private let coherence: Double = 0.62

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Body")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .accessibilityLabel(enabled ? "Body on" : "Body off")
                    .accessibilityHint("Turns the body signal display on or off")
            }

            if enabled {
                HStack {
                    valueColumn(title: "Pulse", value: "\(Int(heartRate))", unit: "bpm")
                    valueColumn(title: "HRV", value: String(format: "%.2f", hrvNormalized), unit: "")
                    valueColumn(title: "Coherence", value: String(format: "%.2f", coherence), unit: "")
                }
            } else {
                Text("Body off")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Body signal is off")
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body")
        .accessibilityValue(enabled ? "Pulse \(Int(heartRate)) beats per minute, HRV \(String(format: "%.2f", hrvNormalized)), coherence \(String(format: "%.2f", coherence))" : "Body off")
        .accessibilityAddTraits(enabled ? .updatesFrequently : [])
    }

    @ViewBuilder
    private func valueColumn(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit())
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    BodyFrameView()
}
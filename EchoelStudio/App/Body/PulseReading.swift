import SwiftUI

/// The strap's pulse in the transport, as its own leaf: it changes about once a second, and only
/// this view reads it (Law 6). Shows nothing while the strap is off, the measured rate while it is
/// live, and in words what is missing otherwise — never a number that was not measured.
struct PulseReading: View {
    @Environment(HeartRateStrap.self) private var strap

    var body: some View {
        if strap.isOn {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(strap.beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.accent)
                Text(text)
                    .font(Theme.Font.value)
                    .foregroundStyle(strap.beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.text)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate strap")
            .accessibilityValue(spoken)
        }
    }

    private var text: String {
        if let bpm = strap.beatsPerMinute { return "\(bpm)" }
        return Self.words(for: strap.status)
    }

    private var spoken: String {
        if let bpm = strap.beatsPerMinute { return "\(bpm) beats per minute" }
        return Self.words(for: strap.status)
    }

    static func words(for status: HeartRateStrap.Status) -> String {
        switch status {
        case .off: "Off"
        case .unavailable: "Bluetooth off"
        case .denied: "Bluetooth not allowed"
        case .searching: "Searching…"
        case .notFound: "No strap found"
        case .connecting: "Connecting…"
        case .connected: "No pulse"
        case .lost: "Strap lost"
        }
    }
}

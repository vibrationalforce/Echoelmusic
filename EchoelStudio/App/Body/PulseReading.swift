import SwiftUI

/// The body's pulse in the transport, as its own leaf: it changes about once a second, and only
/// this view reads it (Law 6). Shows nothing while no source is on, the measured rate while one
/// is live, and in words what is missing otherwise — never a number that was not measured. The
/// strap and the camera (wave W1) read alike; the chooser keeps one of them on at a time.
struct PulseReading: View {
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera

    var body: some View {
        if strap.isOn {
            reading(beatsPerMinute: strap.beatsPerMinute, words: Self.words(for: strap.status), label: "Heart rate strap")
        } else if camera.isOn {
            reading(beatsPerMinute: camera.beatsPerMinute, words: Self.words(for: camera.status, cue: camera.cue),
                    label: "Camera pulse")
        }
    }

    private func reading(beatsPerMinute: Int?, words: String, label: String) -> some View {
        let text = beatsPerMinute.map { "\($0)" } ?? words
        let spoken = beatsPerMinute.map { "\($0) beats per minute" } ?? words
        return HStack(spacing: Theme.Space.xs) {
            Image(systemName: "heart.fill")
                .foregroundStyle(beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.accent)
            Text(text)
                .font(Theme.Font.value)
                .foregroundStyle(beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.text)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(spoken)
    }

    static func words(for status: HeartRateStrap.Status) -> String {
        switch status {
        case .off: "Off"
        case .unavailable: "Bluetooth off"
        case .denied: "Bluetooth not allowed"
        case .searching: "Searching"
        case .notFound: "No strap found"
        case .connecting: "Connecting"
        case .connected: "No pulse"
        case .lost: "Strap lost"
        }
    }

    /// While the camera measures, the cue says what the finger should do; otherwise the status.
    static func words(for status: CameraPulseSource.Status, cue: PulseCue) -> String {
        switch status {
        case .off: "Off"
        case .unavailable: "Camera unavailable"
        case .denied: "Camera not allowed"
        case .starting: "Starting camera"
        case .measuring: cue.shortLabel
        case .interrupted: "Camera paused"
        }
    }
}

import SwiftUI

/// The body's pulse in the transport, as its own leaf: it changes about once a second, and only
/// this view reads it (Law 6). Shows nothing while no source is on, the measured rate while one
/// is live, and in words what is missing otherwise — never a number that was not measured. The
/// strap and the camera (wave W1) read alike; the chooser keeps one of them on at a time.
struct PulseReading: View {
    /// Whether a source without a number shows its words ("Searching", "Hold still"). The phone's
    /// rows show "–" instead: the words need more room than a phone's top row has. VoiceOver says
    /// the words either way.
    var showsWords = true
    /// The reading keeps one width whatever it shows, so a word or a number arriving never moves
    /// the bar to another shape: the heart and three digits, or the heart and the longest word.
    @ScaledMetric(relativeTo: .headline) private var numberWidth: CGFloat = Theme.Size.pulseReading
    @ScaledMetric(relativeTo: .subheadline) private var wordsWidth: CGFloat = Theme.Size.pulseWords

    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(HealthHeartRate.self) private var health

    var body: some View {
        if strap.isOn {
            reading(beatsPerMinute: strap.beatsPerMinute, words: Self.words(for: strap.status), label: "Heart rate strap")
        } else if camera.isOn {
            reading(beatsPerMinute: camera.beatsPerMinute, words: Self.words(for: camera.status, cue: camera.cue),
                    label: "Camera pulse")
        } else if health.isOn {
            reading(beatsPerMinute: health.beatsPerMinute, words: Self.words(for: health.status), label: "Apple Health pulse")
        }
    }

    private func reading(beatsPerMinute: Int?, words: String, label: String) -> some View {
        let text = beatsPerMinute.map { "\($0)" } ?? (showsWords ? words : "–")
        let spoken = beatsPerMinute.map { "\($0) beats per minute" } ?? words
        let isWord = beatsPerMinute == nil && showsWords
        return HStack(spacing: Theme.Space.xs) {
            Image(systemName: "heart.fill")
                .font(Theme.Font.label)
                .foregroundStyle(beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.accent)
            Text(text)
                .font(isWord ? Theme.Font.label : Theme.Font.value)
                .foregroundStyle(beatsPerMinute == nil ? Theme.Color.textSecondary : Theme.Color.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(isWord ? 0.85 : 0.9)
                .truncationMode(.tail)
        }
        .frame(width: showsWords ? wordsWidth : numberWidth, alignment: .trailing)
        .padding(.leading, Theme.Space.s)
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

    /// Apple Health: a stale reading reads as not measured, never as a number.
    static func words(for status: HealthHeartRate.Status) -> String {
        switch status {
        case .off: "Off"
        case .unavailable: "Health unavailable"
        case .asking: "Asking for Health"
        case .waiting, .measuring: "No recent reading"
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

/// What VoiceOver says where the screen writes a short form: the screen keeps its few letters
/// ("C", "L20", "CC 7 · Ch 1"), the voice says words, because VoiceOver reads a short form letter
/// by letter ("L 20") and a symbol by its name ("middle dot").
public enum Spoken {
    /// A pan position: "Center", "20 percent left", "100 percent right" — rounded as the screen
    /// rounds it, so the voice never says a number the screen does not show.
    public static func pan(_ value: Double) -> String {
        guard value.isFinite else { return "Center" }
        // The bound only keeps an absurd value from trapping the conversion; a pan is -1 … 1.
        let percent = Int(Swift.min(abs(value) * 100, 1_000_000).rounded())
        if percent == 0 { return "Center" }
        return "\(percent) percent \(value < 0 ? "left" : "right")"
    }

    /// A knob or fader of a MIDI controller, numbered as the device counts it: "controller 7 on
    /// channel 1".
    public static func control(_ control: MIDIControl) -> String {
        "controller \(control.number) on channel \(Int(control.channel) + 1)"
    }
}

import Foundation

/// The musician's own rhythm as a tone (Cycle Tones, Body; founder 2026-11-15: own rhythms, the
/// heartbeat first). A pulse in beats per minute is a cycle like any other: one beat lasts 60 ÷ the
/// pulse seconds, and `CycleTone` moves its frequency by whole octaves into octave 3. Nothing here
/// measures: the pulse is the one the chosen body source shows, and the page takes it only when the
/// musician taps. The tempo never follows the pulse from here — the song's tempo changes by that
/// gesture alone (the root law's T1); following the pulse is Flow's, through `FlowTempo`.
public enum BodyTones {
    /// The pulses the page turns into a tone, in beats per minute; any other number is not taken.
    public static let pulseRange: ClosedRange<Int> = 30...220

    /// The heartbeat as a tone; nil for a pulse outside `pulseRange`.
    public static func heartbeat(beatsPerMinute: Int) -> CycleTone? {
        guard pulseRange.contains(beatsPerMinute) else { return nil }
        return CycleTone(periodSeconds: 60 / Double(beatsPerMinute))
    }

    /// The section title of the taken pulse.
    public static let heartbeatTitle = "Heartbeat"

    /// How the page's numbers are made, and what the song keeps of them.
    public static let method = "Your heartbeat is a cycle of your own: one heartbeat lasts 60 seconds divided by your "
        + "pulse. Its tone is that heartbeat's frequency doubled by whole octaves until its nearest key lies in octave 3, C3 "
        + "to B3. Its tempo is the same tone seven octaves lower, which is your pulse moved by whole octaves to between 60 "
        + "and 119 beats per minute, so a pulse in that range is its own tempo. Take Pulse holds the pulse as it is at that "
        + "moment; the tuning fork then sets the song's key, its tempo or, last, its concert pitch to it, and Undo takes it "
        + "back. What you choose is the song's own from then on and goes wherever the song goes; the song keeps no reading, "
        + "and its tempo does not follow the pulse from here; that is Flow's. A pulse from Apple Health is not taken, and "
        + "while the tempo leaves this device, a pulse is taken only with Share Body Data on. These are calculations from a "
        + "reading for making music, not a diagnosis; they claim nothing about what a tone does to a listener."

    /// Whose method, and where the pulse comes from.
    public static let credit = "Method after Hans Cousto, Die Kosmische Oktave (1984). The pulse comes from the heart "
        + "rate strap or the rear camera, whichever is chosen in the Song menu, Body Source."

    /// What the page says while no pulse source is on.
    public static let noSource = "No pulse source is on. Choose one in the Song menu, Body Source: a heart rate strap or "
        + "the rear camera with a fingertip on the lens. This page reads it and turns nothing on itself."

    /// What the page says while Apple Health is the pulse source (`BioEgressPolicy` gate 1).
    public static let healthNotTaken = "A pulse from Apple Health is not taken here: Health readings never leave this "
        + "device, and a song's tempo can. Choose the heart rate strap or the rear camera in the Song menu, Body Source."

    /// What the page says while the tempo leaves the device and Share Body Data is off (gate 2).
    public static let sharingOff = "A MIDI clock, a jam you host, OSC or the lights (Art-Net, sACN) carry the tempo off "
        + "this device, and Share Body Data is off, so no pulse is taken into the song, and one you took is put aside. Turn "
        + "on Share Body Data under Connections to take one or to bring it back."
}

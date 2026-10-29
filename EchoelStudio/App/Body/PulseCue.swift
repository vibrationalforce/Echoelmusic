import Foundation

/// What the camera pulse asks of the musician right now, as a typed state with its words — ported
/// from the earlier app's `PulseCue` for Echoel Studio 1.0, wave W1 "body". One definition of each
/// sentence, so the transport line and the pulse readout cannot say two different things.
///
/// Science first and no claims: the cues describe the SIGNAL (light, contact, motion, time), never
/// the body. A pulse that does not lock says what to change about the finger, not what to think
/// about the heart.
enum PulseCue: Equatable, Sendable {
    /// Camera access is off in Settings: no placement coaching can help.
    case cameraDenied
    /// The flash gives no light (the phone is hot, or the lamp failed): a dark lens reads nothing.
    case noLight
    /// A pulse is trusted right now.
    case locked
    /// No finger on the lens.
    case coverLens
    /// The finger is on the lens and the scene is washed out: too much light, too much pressure.
    case tooBright
    /// Large swings: the finger is moving or changing pressure.
    case holdStill
    /// The contact is so light the signal is flat.
    case pressGently
    /// A placed, steady, firm contact that has not locked yet.
    case finding
    /// `finding` has held for `stalledAfterSeconds`: say whether the lens sees a signal of the
    /// wrong shape (re-place the finger) or none at all (another finger, a warm hand).
    case stalled(hasRhythmlessSignal: Bool)

    /// A clean contact that has produced nothing for this long is a stall, not patience.
    static let stalledAfterSeconds: Double = 45

    /// The sentence for a line that may wrap.
    var fullHint: String {
        switch self {
        case .cameraDenied: "Camera access is off — enable it in Settings to read your pulse"
        case .noLight: "No light from the flash right now — the phone may be hot; let it cool, or hold your finger against a bright lamp"
        case .locked: "Locked"
        case .coverLens: "Cover the rear camera and flash with a fingertip"
        case .tooBright: "Press a little lighter"
        case .holdStill: "Hold still — keep your finger steady"
        case .pressGently: "Press gently and hold still"
        case .finding: "Hold still — finding your pulse…"
        case .stalled(let rhythmless):
            rhythmless
                ? "The signal isn't steady enough to read — lift your finger and place it again"
                : "Still nothing to read — try another finger, or warm your hand first"
        }
    }

    /// The same fact at the width of the transport readout.
    var shortLabel: String {
        switch self {
        case .cameraDenied: "Camera off"
        case .noLight: "No light"
        case .locked: "Locked"
        case .coverLens: "Cover lens"
        case .tooBright: "Too bright"
        case .holdStill: "Hold still"
        case .pressGently: "Press gently"
        case .finding: "Finding…"
        case .stalled(let rhythmless): rhythmless ? "Unsteady" : "Nothing yet"
        }
    }

    /// Whether the musician can do something about it (a locked or still-finding pulse needs no line).
    var isActionable: Bool {
        switch self {
        case .locked, .finding: false
        default: true
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

// TuningStatusBanner.swift
// Echoel — slice 2c of the interface audit (2026-09-30): the tuning warning reaches the stage a
// fresh install opens on.
//
// WHY THIS FILE EXISTS. Since slice 2a the app launches on the PIECE stage, and the piece's
// transport plays the same retuned voices as the instrument. The warning that says so — "every
// note is retuned to this" — was mounted in ONE place, the instrument's Sound plate, i.e. on the
// stage a fresh install no longer shows. That is #325 in a new place: three doorless weeks were
// paid once for exactly this banner. So the banner is now a LEAF that both stages mount, and the
// words that decide whether it shows live ONCE, in `TuningStatusText` (#416 — three call sites
// open-coding `abs(a4Hz - 440) >= 0.05` is how one of them ends up with a different tolerance).
//
// WHO RESETS. The studio owns `applyTuning()` / `applyConcertPitch(_:)` — the calls that push a
// reference into the voices. Nothing else may grow a second copy of that fan (#114: a stored
// value nobody pushes is a control that reports success and changes nothing audible). The
// piece's banner therefore POSTS the existing chrome door, `"tuningStandard"`, and the studio's
// receiver — alive on both stages, because the studio is never unmounted (`StageShell`) — calls
// `resetTuningToStandard()`. The same shape as the track inspector's "sound" door.
//
// ⭐ FREEZE LAW: `PieceTuningStatus` reads `SessionContext.a4Hz` (written on a user edit, on
// project open, on reset — never on a tick) and one `@AppStorage`. Neither is hot state. It is a
// sibling of `WorkstationView` under `ArrangeStage`, not an ancestor, so even a churn here could
// not rebuild the arrangement — but there is none to speak of.
//
// ⭐ BLACK-SCREEN LAW: no presentation modifier here.

/// The words of the tuning warning — decided once, read by both stages.
enum TuningStatusText {
    /// The id of 12-tone equal temperament, the one system that needs no warning.
    static let standardToneSystemID = StudioDefaultKeys.toneSystemID.value

    /// The tolerance under which a concert pitch counts as 440. Not `!= 440`: `a4Hz` is a
    /// `Double`, so an exact comparison would keep the banner up for a value that is 440 for every
    /// audible purpose. 0.05 Hz at A4 is 0.197 cents — roughly a twenty-fifth of the ~5 cents a
    /// trained ear resolves on a sustained tone.
    ///
    /// ⛔ The first version of this line (in `EchoelStudioView`) justified the number as "well
    /// below the ±0.005 Hz the keypad can even express". That is backwards twice over: 0.05 is
    /// TEN TIMES 0.005, and the field passes no `decimals:`, so it inherits `EchoelValueField`'s
    /// default of FOUR — the keypad expresses 0.0001 Hz, which is exactly why the founder's
    /// recording could read 483,4352. The threshold is right and unchanged; the reason given for
    /// it was not, and a wrong reason is what lets a later session "correct" a correct number.
    static let concertPitchToleranceHz = 0.05

    static func toneSystemIsNonStandard(_ tuningID: String) -> Bool {
        tuningID != standardToneSystemID
    }

    static func concertPitchIsNonStandard(_ a4Hz: Double) -> Bool {
        abs(a4Hz - SessionContext.defaultA4Hz) >= concertPitchToleranceHz
    }

    /// The banner's headline — it names only what is actually off standard, so a player working
    /// in Maqām Bayātī at 440 is not told their concert pitch is unusual. Empty when nothing is.
    ///
    /// The Hz goes through `EchoelDecimalText` like every other user-visible decimal in the app
    /// (#267): a German player reads "443,25", and a hard-coded `%.2f` here would print a point
    /// in a panel where every neighbouring number prints a comma.
    static func title(tuningID: String, a4Hz: Double) -> String {
        let systemName = TuningSystem.named(tuningID).name
        let hz = EchoelDecimalText.string(a4Hz, decimals: 2)
        switch (toneSystemIsNonStandard(tuningID), concertPitchIsNonStandard(a4Hz)) {
        case (true, true):   return "Non-standard tuning: \(systemName), A4 = \(hz) Hz"
        case (true, false):  return "Non-standard tuning: \(systemName)"
        case (false, true):  return "Non-standard concert pitch: A4 = \(hz) Hz"
        // ⛔ Written out rather than left to `default:`. The first version folded this into the
        // pitch case, so a headline read for an all-standard instrument would have said
        // "Non-standard concert pitch: A4 = 440.00 Hz" — a sentence that contradicts its own
        // number. It cannot render today (both mounts gate on this same pair), but an
        // unreachable branch that states a falsehood is exactly what a later refactor promotes
        // into a reachable one.
        case (false, false): return ""
        }
    }
}

/// The warning itself: glyph, headline, one sentence, and the ONE control that rescues a
/// wrong-sounding instrument. Pure presentation — it knows neither the session nor the voices;
/// the caller supplies the words and the reset.
struct TuningStatusBanner: View {
    let title: String
    let onStandard: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tuningfork")
                .foregroundStyle(EchoelTheme.dim)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every note is retuned to this. Sounds off? Return to standard.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // #621 (Ultraaccessible-Audit): `.combine` sits HERE, on the two-Text stack — NOT on
            // the outer HStack, where it once stood and swallowed the "Standard" recovery button
            // into one merged element, dropping its hint and its individual focus. The one
            // control that rescues a wrong-sounding instrument must be its own element for the
            // user who cannot see it. (The glyph above is hidden as decoration.)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            // "Standard", not "12-TET": the button returns BOTH dimensions, and the old label
            // named only one of them. It is also the word the sentence above it uses, so the
            // control and its explanation agree.
            Button("Standard") { onStandard() }
            .font(EchoelTheme.font(13, .semibold))
            // `EchoelTheme.onPrimary`, not a raw `.black` — the token exists for exactly this
            // shape (a label on a `.text`-filled button) and #364 fixed the same literal on the
            // keypad's OK key.
            .foregroundStyle(EchoelTheme.onPrimary)
            // `minHeight: 44`, not `height: 34`: 34 is 60 % of the HIG 44×44 floor by area
            // (`TapTargetFloorTests` pins the same number on the two preset overflow menus), and
            // a FIXED height clips the label once Dynamic Type grows it — the #353 class. A
            // minimum floors the target without capping the text.
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.text))
            .buttonStyle(.plain)
            .accessibilityHint("Returns to 12-tone equal temperament at A4 = 440 hertz")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .stroke(EchoelTheme.border, lineWidth: 1))
    }
}

/// The piece stage's mount: reads the two facts, shows the banner only while one is off standard,
/// and hands the reset to the studio through the chrome door. `ArrangeStage` mounts it above the
/// arrangement; the instrument's Sound plate mounts `TuningStatusBanner` directly, because it owns
/// the reset.
@MainActor
struct PieceTuningStatus: View {
    @Environment(SessionContext.self) private var session
    @AppStorage(StudioDefaultKeys.toneSystemID.key)
    private var tuningID = StudioDefaultKeys.toneSystemID.value

    var body: some View {
        if TuningStatusText.toneSystemIsNonStandard(tuningID)
            || TuningStatusText.concertPitchIsNonStandard(session.a4Hz) {
            TuningStatusBanner(title: TuningStatusText.title(tuningID: tuningID, a4Hz: session.a4Hz)) {
                NotificationCenter.default.post(name: .echoelChromeDoor, object: "tuningStandard")
            }
        }
    }
}
#endif

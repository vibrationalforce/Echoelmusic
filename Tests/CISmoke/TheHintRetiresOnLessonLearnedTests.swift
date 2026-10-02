// TheHintRetiresOnLessonLearnedTests.swift
// Echoel — #604 (GUI-Board Scheibe 1) → interface audit 2026-09-30, rule 7.
//
// WHAT THIS GUARDS. `InstrumentHintOverlay` — the app's ONLY statement of the core
// mechanic ("Start the music, then a finger on the back camera / Touch the image to
// play notes") — has had THREE contracts:
//   · #351: shown once for ~4.5 s, then never again (the UX audit's second-worst debt);
//   · #604: re-armed on every visible fullscreen entry, still faded after ~4.5 s, and
//     retired itself after five showings — a COUNTER and a CAP in the keystore;
//   · 2026-09-30, rule 7 of the interface audit ("Nichts verschwindet mit der Zeit —
//     Hinweise bleiben, bis man sie schließt, und lassen sich wieder öffnen"; measurable
//     as "kein Timer an Hinweisen, keine Anzeige-Obergrenze", WCAG 2.2.1): the hint is a
//     STATE. It is on while the Guide switch (`guideVisible`, the logo's ≡ menu since S1b-1) is on AND the
//     lesson is not LEARNED. No `.task`, no sleep, no counter, no cap.
// What survives from #604 and is still pinned here: the LEARNED arm — `startBioSource()`
// writes `instrumentHintSeen`, because the user found Start, step 1 of the hint's own
// first sentence. What is NEW and pinned here: the overlay reads the guide switch, so the
// ONE help control the app has (rule 8; Kopf-4's ⓘ, moved to the ≡ menu in S1b-1) both
// closes and reopens it.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN. Nothing here renders the overlay or flips the switch on a
// device. Copy truth stays owned by `FirstInstructionIsTrueTests` (#416 — this file does
// not re-scan the hint's strings), the fullscreen mount gate by
// `TheFrontDoorIsDecidedBeforeItIsAskedTests`. `SourceText.codeOnly` is LOAD-BEARING:
// the overlay's own comments still narrate the retired timer and cap by name.
//
// ⚠️ HONEST GRADING — transcribed in Python against this tree and the parent (the
// bookkeeping commit after dc81248ed). Claim 1: the LEARNED key GREEN on both, the guide
// key GREEN on both, the two ABSENCES (counter, cap) RED on the parent — born here.
// Claim 2: the guide read, the `if guideVisible, !seen {` gate and the four absences
// (`.task`, `Task.sleep`, `shows`, `withAnimation`) RED on the parent, born here;
// `allowsHitTesting(false)` GREEN on both. Claim 3 GREEN on both (unchanged since
// #604). Claim 4 — the closer in the head and the sibling guide card on the same switch —
// COUNTERWEIGHTS, GREEN on both. Retired from this file, not weakened: the needles for
// the counter, the cap-retire line, the 4.5 s hold and the 700 ms fade sleep — each
// pinned a mechanism that rule 7 removes, and a guard that keeps demanding a removed
// mechanism is a guard against the decision.

import Foundation
import XCTest

final class TheHintRetiresOnLessonLearnedTests: XCTestCase {

    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let keys = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let guide = "Sources/Echoelmusic/Studio/GuideOverlay.swift"

    // MARK: - claim 1 — the two facts that decide the hint live in the keystore; the clock does not

    func testTheHintStateLivesInTheKeystoreWithoutACounterOrACap() throws {
        let keys = try source(Self.keys)
        XCTAssertTrue(keys.contains("StudioDefault(key: \"onboard.instrumentHintSeen\", value: false)"), """
            The hint's LEARNED flag left the keystore (or its default moved). The studio \
            writes it and the overlay reads it — H15: one declaration, in Core. The key \
            STRING must stay "onboard.instrumentHintSeen": renaming it would re-show the \
            hint to every user who already learned it.
            """)
        XCTAssertTrue(keys.contains("StudioDefault(key: \"studio.guideVisible\", value: true)"), """
            The Guide switch's key left the keystore (or is no longer ON for new users). \
            The overlay follows this switch — it is the hint's close AND reopen control \
            (rule 7), and a fresh install must get the hint (rule 8: help on for new users).
            """)
        for retired in ["instrumentHintShows", "instrumentHintShowCap"] {
            XCTAssertFalse(keys.contains(retired), """
                `\(retired)` is back in the keystore. A showing counter or a cap is a \
                display ceiling on a hint — rule 7 of the 2026-09-30 interface audit \
                ("keine Anzeige-Obergrenze", WCAG 2.2.1) removed both. The nag they \
                guarded against is answered by the Guide switch, not by a count.
                """)
        }
    }

    // MARK: - claim 2 — the overlay is a state of two switches, not an event on a clock

    func testTheOverlayFollowsTheGuideSwitchAndTheLearnedFlagWithNoClock() throws {
        let code = try source(Self.window)
        let overlay = slice(code, from: "private struct InstrumentHintOverlay: View {", to: "\n#endif")
        XCTAssertFalse(overlay.isEmpty, "`InstrumentHintOverlay` moved — re-anchor this scan")
        XCTAssertTrue(overlay.contains("@AppStorage(StudioDefaultKeys.guideVisible.key)"), """
            The overlay no longer reads the Guide switch. Without it the hint has \
            no close control — `allowsHitTesting(false)` means it cannot be tapped away — \
            and rule 7 ("bleibt, bis man sie schließt, und lässt sich wieder öffnen") \
            needs exactly one: the Guide switch in the logo's ≡ menu.
            """)
        XCTAssertTrue(overlay.contains("@AppStorage(StudioDefaultKeys.instrumentHintSeen.key)"), """
            The overlay no longer reads the LEARNED flag — the #604 arm is gone and a user \
            who has started the music keeps reading how to start it.
            """)
        XCTAssertTrue(overlay.contains("if guideVisible, !seen {"), """
            The overlay's gate changed. It must be exactly the two user-owned facts — the \
            guide switch on AND the lesson not learned — and nothing else; a third term \
            here is where a clock or a count comes back in.
            """)
        for clock in [".task", "Task.sleep", "shows", "withAnimation", "Timer", "DispatchQueue"] {
            XCTAssertFalse(overlay.contains(clock), """
                `\(clock)` is back in `InstrumentHintOverlay`. The overlay had a 4.5 s hold, \
                a 700 ms fade sleep, a showing counter and a cap until 2026-09-30; rule 7 \
                removed every one of them. A hint that disappears by itself is the defect, \
                however gently it fades.
                """)
        }
        XCTAssertEqual(occurrences(of: "seen = true", in: code), 0, """
            `seen = true` is written inside FloatingVisualWindow. The overlay READS the \
            learned flag; the ONE writer is `startBioSource()` in the studio (claim 3). A \
            write here is either the cap-retire returning or a display contract nobody \
            documented.
            """)
        XCTAssertTrue(overlay.contains(".allowsHitTesting(false)"), """
            The hint overlay lost `allowsHitTesting(false)`. It sits on the touch \
            instrument; an overlay that swallowed the first play-touch would be worse now \
            that the hint STAYS instead of fading.
            """)
    }

    // MARK: - claim 3 — the LEARNED arm sits on the start path (unchanged since #604)

    func testStartingBioRetiresTheHint() throws {
        let code = try source(Self.studio)
        let body = slice(code, from: "private func startBioSource() async {", to: "\n    }")
        XCTAssertTrue(body.contains("instrumentHintSeen = true"), """
            `startBioSource()` no longer retires the instrument hint. That write IS the \
            lesson-learned arm: the user found Start (step 1 of the hint's sentence), so \
            the whisper's job is done. Without it the hint stays for exactly the users \
            who no longer need it, until they switch the guide off.
            """)
    }

    // MARK: - claim 4 (COUNTERWEIGHTS, #343) — the switch the hint follows is a real, reopenable control

    func testTheGuideSwitchIsTheOneCloserAndTheGuideCardSharesIt() throws {
        // S1b-1 (2026-10-02): the switch moved from the head's ⓘ Button into the logo's ≡ menu
        // as a `Toggle`; the claim is unchanged — one reachable control flips the key.
        let workspace = try source(Self.workspace)
        XCTAssertTrue(workspace.contains("Toggle(isOn: $guideVisible)"), """
            The ≡ menu no longer toggles `guideVisible`. That toggle is the hint's close \
            and reopen control (rule 7) — without it the overlay follows a switch nobody \
            can flip.
            """)
        let guide = try source(Self.guide)
        XCTAssertTrue(guide.contains("if guideVisible, !entries.isEmpty {"), """
            `GuideOverlay` no longer follows the same switch. The hint and the guide card \
            must be ONE help surface behind ONE control (rule 8); if they diverge, the switch \
            starts meaning two things.
            """)
    }

    // MARK: - source access

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped source (#453 — one stripper for the whole bundle). A SKIP without a
    /// checkout, a FAILURE when a named file moved (#454: a skip passes CI).
    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func slice(_ code: String, from: String, to: String) -> String {
        guard let start = code.range(of: from),
              let end = code.range(of: to, range: start.upperBound..<code.endIndex) else {
            return ""
        }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}

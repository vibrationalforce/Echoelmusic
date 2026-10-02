// OneStartControlTests.swift
// Echoel — there is ONE button that starts the instrument, and it is a labelled one.
//
// THE ASK (founder 2026-07-29, with a screenshot): *"Ich hab jetzt hier 3 Knöpfe zum Start
// drücken könnte man das zu einem zusammenfassen?"* — three controls on one screen all began
// the same bio-generative session:
//   1. the header pulse pill (tap → `.echoelToggleBio`),
//   2. the transport ▶ (posted the SAME notification whenever nothing was composed),
//   3. the full-width "Create from Within" on the front plate.
// Two of them showed a different truth while doing it: the pill renders CAMERA state
// (`cameraRPPG.isRunning`) and the ▶ renders `transport.isPlaying`, so on the same screen
// three controls for one action could disagree about whether it had happened.
//
// #234 keeps the labelled one. The pill went back to being a monitor (its tap opens the Bio
// panel, which is also the first time that panel has been reachable without a long-press),
// and ▶ is now only on screen WHILE a session runs, where it is the music transport — drop
// the music without dropping a pulse lock that costs ~20 s to re-acquire.
//
// WHY A TEST AND NOT JUST A COMMENT: this is the SECOND time the founder has asked for this
// ("zu viele Play Knöpfe, einer reicht", 2026-07-15). That round moved the duplicate instead
// of removing it, and the count grew back. A comment does not fail; this does.
//
// WHAT THIS CANNOT PROVE: that the one remaining button is reachable, legible, or works — it
// pins counts and the absence of the chrome wire, nothing about rendering.
//
// ⭐ DAW SHELL S7a (founder 2026-10-02, „Ja, so bauen" — one control bar on top): THE ONE START
// MOVED TO THE HEAD. The Instrument stage had come to show two Plays one row apart — the head's
// (`ProjectPlayStopButton`, a resume) and the plate's own ▶/■ (`EchoelStudioView.startButton`,
// start/end the session) — the shape this file was written against, re-grown by a layout
// change rather than by a new button. The plate's ▶/■ and its `toggleBiofeedback()` are
// DELETED; the head's Play starts the instrument through ONE chrome door
// (`ProjectTransport.startInstrument()` → "startInstrument" → `startBiofeedback()`). Every
// claim below was re-pointed at the new site in the same commit and none was loosened: claim 1
// now pins THREE things where it pinned one (the old toggle is gone, the door has one poster,
// the receiver has one arm), and claim 6 asserts the words at RUNTIME instead of as a literal.
// Grading against the parent (`55ef08e44`): claims 1 and 6 are red there by ANCHOR ABSENCE
// (the door and `startInstrument` do not exist) — one absence, reported twice (#486); the
// rest are counterweights, green on both trees.
//
// ⚠️ AN EARLIER VERSION OF THIS NOTE WAS WRONG, in the direction that made the guard look
// stronger than it was. It said the uncovered paths were "the Bio panel's own 'start pulse'
// row and the Siri/Shortcuts inbox", both "one level deeper than the front plate, which is
// exactly where the founder's complaint was not". There were THREE, and the omitted one —
// the header pill's long-press source picker — is the founder's own pill, one gesture from
// the surface he pointed at. The panel row is now gone and the picker is now labelled; both
// counts are pinned below instead of being described in prose.

import Foundation   // FileManager/URL. XCTest re-exports it on Darwin, but every sibling in
                    // this directory imports it explicitly and one line is cheaper than a
                    // red gate on a repo with no local toolchain.
import XCTest
@testable import Echoelmusic   // `ProjectTransport` (S7a: the ONE start's words are asserted at runtime)

final class OneStartControlTests: XCTestCase {

    /// Every `.swift` file under `Sources/`, with whole-line comments dropped. Comments are
    /// stripped because the removal is DOCUMENTED in three places by name — a naive search
    /// would find the epitaphs and fail on the very thing it is checking for.
    private func sourceLines() throws -> [(file: String, line: Int, text: String)] {
        let root = try repoRoot().appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        // Labels declared HERE, not only on the return type: `[(String, Int, String)]` and
        // `[(file: String, line: Int, text: String)]` are distinct types, and Array does not
        // convert between them — the mismatch is a compile error, not a warning.
        var out: [(file: String, line: Int, text: String)] = []
        var scanned = 0
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            for (i, raw) in text.components(separatedBy: .newlines).enumerated() {
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                out.append((url.lastPathComponent, i + 1, raw))
            }
        }
        XCTAssertGreaterThan(scanned, 250,
                             "Only \(scanned) Swift files scanned — every search below would "
                             + "pass vacuously on a tree it never read.")
        return out
    }

    /// ⛔ THE REGRESSION GUARD. Add a second control that starts the session and this goes red.
    ///
    /// Since DAW shell S7a the ONE start is the head's Play, and it reaches the studio through ONE
    /// door. Three things are pinned, because each alone could be satisfied by a second start:
    ///   1. the plate's old Start-or-End, `toggleBiofeedback()`, is GONE — not merely uncalled
    ///      (its only caller was the deleted `startButton`; a function with no caller is one line
    ///      from a fourth Start that no count below would see);
    ///   2. exactly ONE control asks for the start — one call of `ProjectTransport.startInstrument()`
    ///      outside its declaration, and it is in `ProjectHeader.swift`;
    ///   3. exactly ONE arm answers it — `case ProjectTransport.startInstrumentDoor:` in
    ///      `EchoelStudioView.swift`, and that arm refuses while a session runs.
    /// (⛔ Until S7a this method was `testExactlyOneControlInvokesTheFrontPlateSessionToggle` and
    /// pinned only half 2 — the toggle's one caller. The name described a mechanism the code no
    /// longer has (#374), so it is renamed with it.)
    func testExactlyOneControlStartsTheInstrument() throws {
        let lines = try sourceLines()
        let toggle = lines.filter { $0.text.contains("toggleBiofeedback") }
        XCTAssertTrue(toggle.isEmpty, """
        `toggleBiofeedback` is back at \(toggle.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). \
        It was the plate ▶/■'s Start-or-End and went with it (DAW shell S7a): the start is the \
        head's Play, the end is the ONE Stop. A second Start-or-End beside them is the \
        two-Plays-on-one-screen confusion the founder asked away three times.
        """)
        let askers = lines.filter {
            $0.text.contains("ProjectTransport.startInstrument()") && !$0.text.contains("func startInstrument")
        }
        XCTAssertEqual(askers.count, 1, """
        Expected exactly ONE control to ask for the instrument's start, found \(askers.count): \
        \(askers.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). The founder has asked \
        three times for one Start button (2026-07-15, 2026-07-29, 2026-07-31). If a new control \
        genuinely needs to begin a session, that is a founder decision, not a merge.
        """)
        XCTAssertEqual(askers.first?.file, "ProjectHeader.swift",
                       "the one start is the head's Play (`ProjectPlayStopButton`), not a control elsewhere")
        let arms = lines.filter { $0.text.contains("case ProjectTransport.startInstrumentDoor:") }
        XCTAssertEqual(arms.count, 1, """
        Expected exactly ONE receiver arm for the start door, found \(arms.count): \
        \(arms.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). Two arms would start the \
        session twice from one tap.
        """)
        guard let arm = arms.first else { return }
        XCTAssertEqual(arm.file, "EchoelStudioView.swift",
                       "the start stays in the studio — the only owner of the session's state")
        let next = lines.first { $0.file == arm.file && $0.line > arm.line }
        XCTAssertEqual(next?.text.trimmingCharacters(in: .whitespaces), "if !running { startBiofeedback() }", """
        the start door's arm no longer reads `if !running { startBiofeedback() }` on its first \
        line. The refusal is the point: the head shows Play over a held session only as a RESUME, \
        so a start that arrives while a session runs must not begin a second one.
        """)
    }

    /// The chrome→studio start WIRE is gone, not merely unused. `echoelToggleBio` let the
    /// header and the transport bar begin a session without owning any of its state; while
    /// the name exists, re-adding a fourth start button is one line and leaves no trace in
    /// the view that starts it. Matched on the raw notification STRING, which no epitaph
    /// comment spells out — so this stays honest even where the symbol name is discussed.
    ///
    /// ⚠️ SINCE S7a A CHROME CONTROL DOES START THE SESSION AGAIN, and it did it the way this
    /// guard's own message asked: the wire came back WITH its control, never ahead of it. It is
    /// NOT this notification — it is the "startInstrument" arm of the existing `.echoelChromeDoor`,
    /// with exactly one poster and one receiver, both pinned by
    /// `testExactlyOneControlStartsTheInstrument`. This test keeps the old, unowned wire out.
    func testNoChromeNotificationCanStartTheSession() throws {
        let posts = try sourceLines().filter { $0.text.contains("echoel.toggleBio") }
        XCTAssertTrue(posts.isEmpty, """
        `echoel.toggleBio` is back at \
        \(posts.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). Chrome that starts \
        the session is what produced three Start buttons; if a chrome control must start it \
        again, re-add the notification WITH that control, never ahead of it.
        """)
    }

    /// ⛔ THE CAPABILITY GUARD. The test above pins a SYMBOL — but every side door calls
    /// `startBiofeedback()` directly, not `toggleBiofeedback()`, so a fourth Start added that
    /// way would sail past it. This counts the thing that actually begins a session.
    ///
    /// The inventory, all three deliberate:
    ///   1. the "startInstrument" door's arm — the head's ONE Play (DAW shell S7a). ⛔ Until S7a
    ///      this was `toggleBiofeedback()`'s body, the plate's own ▶/■; the button and the toggle
    ///      are deleted and the arm replaces them one for one, so the count is unchanged.
    ///   2. `handlePendingIntent()` — Siri/Shortcuts, no on-screen control at all.
    ///   3. `selectBioSource()` — the idle branch, reached through TWO doors since #616:
    ///      the header pill's long-press and `bioPanel`'s visible "Bio source" row (one
    ///      definition, `BioSourceOption`). Still ONE call site — the row is a door, not a
    ///      new caller. The entries are labelled "Play with …" precisely because they
    ///      start the music; under bare labels ("Camera light", "Simulation") this was a
    ///      hidden Start, which is what the founder was counting.
    ///
    /// A FOURTH one was removed to get here: the Bio panel's "Read pulse" button ran
    /// `startBiofeedback()` behind a label promising a measurement — a lying control and a
    /// hidden Start two taps from the pill. If this count rises, say which of those two a new
    /// caller is, and fix it rather than raising the number.
    func testOnlyTheKnownThreePathsBeginABioSession() throws {
        let starts = try sourceLines().filter {
            $0.text.contains("startBiofeedback()") && !$0.text.contains("func startBiofeedback")
        }
        XCTAssertEqual(starts.count, 3, """
        Expected exactly 3 session-start call sites, found \(starts.count): \
        \(starts.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). Every one of them \
        must be either the one labelled button, a no-UI automation path, or a control whose \
        LABEL says the music starts.
        """)
    }

    /// ⛔ THE OTHER REGRESSION GUARD, and it exists because the claim it protects was already
    /// shipped once while FALSE.
    ///
    /// The transport ■ is kept on the argument that it stops the MUSIC without ending the
    /// bio session — the pulse lock costs ~20 s to re-acquire, so that difference is the
    /// button's entire justification. It only holds if something actually REQUESTS a
    /// playback-only stop: `TransportTransition.decide` returns `.endSession` otherwise.
    ///
    /// From 2026-07-26 (the piano roll's door removed) to 2026-07-29 nothing did, and the
    /// founder's device log 2475 shows the consequence — `stop source: transport-bar ■` at
    /// 828.182, `stopEverything(transport-stopped)` 14 ms later. A second full Stop wearing
    /// a different glyph.
    ///
    /// `PianoRollView.swift` is excluded deliberately, and since #475 the reason is SIMPLER
    /// than it was — which is exactly why the sentence is rewritten instead of left standing.
    /// It used to say the file "holds both the declaration and the roll's own pause button".
    /// The button went with the 988-line `PianoRollView` struct (#475, 2026-08-07); what is
    /// left in that file is `PianoRollModel`, and its DECLARATION line
    /// (`public func requestPlaybackOnlyStop() { … }`) still contains the searched substring.
    /// So the exclusion is now purely "don't count the declaration as its own caller" — the
    /// pre-#475 phrasing would have had the next reader looking for a button that is gone.
    /// The mechanism is unchanged and still load-bearing: counting this file would let the
    /// test go green on a producer no user can reach, which is the state it detects.
    func testThePlaybackOnlyStopHasAReachableProducer() throws {
        let producers = try sourceLines().filter {
            $0.text.contains("requestPlaybackOnlyStop()") && $0.file != "PianoRollView.swift"
        }
        XCTAssertFalse(producers.isEmpty, """
        Nothing outside `PianoRollView.swift` (which since #475 holds only the DECLARATION) \
        requests a playback-only stop, so the transport ■ (`PlaybackToggleButton`) ends the \
        whole bio session — camera included — and is a duplicate of the front plate's Stop \
        with a ~20 s pulse re-lock as its hidden price. Either restore a producer or remove the \
        button; do not leave the justification standing without the mechanism. (⛔ "the pause \
        button" of PianoRollView stood here until #1109 — the doc above already said that \
        button went with #475; the message had not followed.)
        """)
    }

    /// ⛔ #305 — THE ROW MAY CONTAIN EXACTLY ONE CLAIM OF "STOP", and for two days it contained
    /// two. The test above proves the pause button HAS a producer; this one proves it does not
    /// LOOK like the control it deliberately is not.
    ///
    /// Founder 2026-07-31, red circle around `startControlRow`: *"Einfaches start stop
    /// Recording Taster und etwas größere Anzeige für Analyse ist besser."* The screenshot shows
    /// a wide button reading "Stop" and, 8 pt to its right, a second ■ — same claim, different
    /// effect. One ends the session and costs ~20 s of pulse re-lock; the other only drops the
    /// music. `pause.fill` is now the glyph, and the VoiceOver label says "Pause the music"
    /// instead of a second "Stop the music".
    ///
    /// WHY THIS IS A TEST AND NOT A COMMENT: it is the same failure shape as
    /// `testThePlaybackOnlyStopHasAReachableProducer` above — a justification ("it drops the
    /// music without dropping the body") that the shipped artefact quietly contradicted. That
    /// one guards the MECHANISM; this one guards what the user is told about it. Both halves
    /// have now been wrong once.
    ///
    /// ⚠️ WHAT THIS DELIBERATELY DOES NOT GUARD: the other half of the same founder message,
    /// the enlarged analysis tile (`PulseMonitorMini`, 30 → 38 pt). Pinning a font size or a
    /// frame literal would fire on every restyle while proving nothing about legibility, and a
    /// guard that cries wolf gets deleted. Tile size is a device judgement; the glyph is a
    /// contradiction, and only the second kind belongs here.
    ///
    /// ⛔ THE FILE SCOPE IS A PROXY FOR A ROW, AND THE REVIEWER WAS RIGHT THAT THE FIRST
    /// VERSION SPENT IT BADLY. It scoped ALL FOUR checks to `WorkspaceView.swift`. That file is
    /// demonstrably in motion — #289 extracted `PlaybackToggleButton` out of `TransportBar` one
    /// commit before this guard existed, and #307 argues the struct no longer belongs in the
    /// chrome file at all, since it renders inside `EchoelStudioView.startControlRow`. Moving it
    /// would have turned TWO assertions red with messages asserting a regression that did not
    /// happen ("no longer draws pause.fill" — it does, one file over), while the third passed
    /// VACUOUSLY. That is precisely the shape the #132-Slice-6 Nachlese one commit earlier was
    /// written about: a guard that cries wolf at ordinary tidying gets deleted, and then it
    /// covers nothing.
    ///
    /// So: the two PRESENCE checks match repo-wide on tokens that are unique enough to carry it,
    /// and one anchor assertion says where the struct lives. A move now produces ONE unambiguous
    /// failure — "it moved, re-point the absence check" — instead of two lying ones.
    ///
    /// The ABSENCE check keeps its file scope, because `stop.fill` is CORRECT in the TWO other
    /// places it appears: `LiveColaboView` (end the live session) and — since S7a — the head's
    /// ONE Play/Stop (`ProjectPlayStopButton`), whose Stop really does end the bio session (until
    /// S7a that was `EchoelStudioView.startButton`, deleted). Count them when
    /// you edit this list; the first version said "elsewhere" and named two of three, the
    /// second said THREE the day #387 made it four, and #1304 took the two `VideoLibraryPanel`
    /// sites away with video capture — so this list has now been wrong in BOTH directions. ⛔ The count went stale
    /// WITHOUT the gate going red, because this assertion is scoped to `WorkspaceView.swift` and
    /// none of the four live there — so nothing mechanical was ever going to catch it. A prose
    /// count that no assertion can falsify is maintained by reading, or not at all. ⚠️ Note what that means: this is a FILE-scoped proxy for a ROW-scoped
    /// invariant. It cannot see the other members of `startControlRow`, which live in a different
    /// file — so it cannot actually count the claims in that row, only keep the pause button out
    /// of the argument.
    func testThePlaybackPauseDoesNotWearTheStopGlyph() throws {
        let all = try sourceLines()
        let workspaceLines = all.filter { $0.file == "WorkspaceView.swift" }
        XCTAssertTrue(workspaceLines.contains { $0.text.contains("struct PlaybackToggleButton") }, """
        `PlaybackToggleButton` is no longer declared in WorkspaceView.swift. That is allowed — by
        #307's own argument it belongs nearer `EchoelStudioView.startControlRow` — but the
        `stop.fill` absence check below is scoped to this file and would now pass vacuously. Move
        that scope to the struct's new home in the same commit.
        """)
        XCTAssertTrue(all.contains { $0.text.contains("\"pause.fill\"") }, """
        `PlaybackToggleButton` no longer draws `pause.fill`. It sits beside the ■ that ends the \
        whole bio session (labelled "Stop" until #307 made it a glyph); this one only drops the \
        music and \
        keeps the pulse lock (~20 s to re-acquire). If it goes back to a stop glyph, the row \
        presents the same claim twice with two different effects — the founder's 2026-07-31 \
        "Einfaches start stop" complaint, which was the fourth about this cluster.
        """)
        let stops = workspaceLines.filter { $0.text.contains("\"stop.fill\"") }
        XCTAssertTrue(stops.isEmpty, """
        `stop.fill` is back in WorkspaceView.swift at \
        \(stops.map { "\($0.file):\($0.line)" }.joined(separator: ", ")). The only control that \
        may claim "stop" beside it is the head's ONE Play/Stop (`ProjectPlayStopButton`), which \
        actually ends the session. If a NEW control here genuinely stops something, give \
        it a label that says what it stops and re-point this guard rather than raising it.
        """)
        XCTAssertTrue(all.contains { $0.text.contains("Pause the music") }, """
        the playback toggle's VoiceOver label no longer says "Pause the music". A VoiceOver \
        user gets the worse version of this confusion — two controls announced identically, no \
        picture to tell them apart — so the label carries the distinction, not just the glyph.
        """)
    }

    /// ⛔ #307 — THE ONE START IS NOW A GLYPH, so nothing may still tell the user to press a
    /// sentence. Founder 2026-07-31: *"Create from within can also weg, einfaches Menü mit
    /// Playbutton etc wie bei Ableton reicht."*
    ///
    /// Removing a LABEL is not like removing a view: the label was quoted as an instruction in
    /// two other places — the Bio panel's opening line and `BioStripView`'s VoiceOver hint —
    /// and both would have kept telling people to press a button that is not on screen. Stale
    /// copy that reads as help is worse than none, because the reader trusts it and hunts.
    ///
    /// ⚠️ SCOPED TO "Press", NOT TO THE PHRASE. "Create from Within" is the BRAND tagline and
    /// legitimately survives in `AppIcon.swift` (the icon artwork) and across `docs/`.
    /// ⛔ AND IT IS CASE-SENSITIVE, which is a REACH limit, not a tolerance: `TrackInstrument`'s
    /// bio-voice description writes "Create from within" with a lowercase w, so this guard cannot
    /// see it at all — if that line ever became "Press Create from within…", it would stay green.
    /// The first version of this note listed it as something the guard "allows", which reads as
    /// coverage it does not have. Banning the phrase outright would be this
    /// repo's other recurring mistake — a guard that enforces more than the decision behind it.
    /// The defect is specifically an INSTRUCTION to press it.
    func testNothingTellsTheUserToPressAButtonThatWasRemoved() throws {
        let liars = try sourceLines().filter {
            $0.text.contains("Press") && $0.text.contains("Create from Within")
        }
        XCTAssertTrue(liars.isEmpty, """
        \(liars.map { "\($0.file):\($0.line)" }.joined(separator: ", ")) still instructs the \
        user to press "Create from Within". That button was replaced by an Ableton-style play \
        triangle (#307) and no longer exists — the sentence now points at nothing. Name the \
        control that IS on screen. (The phrase itself is fine as branding; only "press it" is \
        the defect, which is why this matches the pair and not the phrase.)
        """)
    }

    /// The positive half: with no label left, the START is carried entirely by its glyph and
    /// its VoiceOver label. Both are asserted, because losing either leaves a control that
    /// cannot be found by one of the two ways people find controls.
    ///
    /// ⭐ RE-POINTED BY S7a, NOT LOOSENED. The one start is the head's `ProjectPlayStopButton`
    /// now, so the glyph pair is asserted in `ProjectHeader.swift`, and the label — which the
    /// head computes rather than spells (`ProjectTransport.buttonLabel`) — is asserted at RUNTIME,
    /// which is stronger than the literal `Text("Play")` this used to match: a literal proves the
    /// string exists somewhere in the file, the call proves what the Instrument stage's Play says.
    /// And the plate is held to having NO second Play/Stop of its own — the S7a regression.
    func testTheOneStartStillPresentsItselfAsATransport() throws {
        let all = try sourceLines()
        let head = all.filter { $0.file == "ProjectHeader.swift" }
        XCTAssertTrue(head.contains { $0.text.contains("struct ProjectPlayStopButton") }, """
        `ProjectPlayStopButton` is no longer declared in ProjectHeader.swift — renamed, moved, or \
        the file was renamed. The glyph assertion below is scoped to this file and would check \
        the wrong thing (or nothing) without it. Re-point it in the same commit.
        """)
        // ⛔ The glyph check matched the bare token `"play.fill"` in its first form, which a stray
        // preview button would have satisfied; it matches the exact EXPRESSION since #307.
        XCTAssertTrue(head.contains { $0.text.contains("running ? \"stop.fill\" : \"play.fill\"") }, """
        the one Play/Stop no longer switches between `play.fill` and `stop.fill`. That glyph pair \
        IS the start — there is nothing else on the Instrument stage that says the instrument can \
        be started, or that it is running.
        """)
        // RUNTIME: what the Instrument stage's Play says to VoiceOver, and its first word is the
        // word it draws (`TheProjectHeaderRunsOneTransportTests` claim 10 holds that for every case).
        XCTAssertEqual(ProjectTransport.buttonLabel(running: false, play: .startInstrument), "Play the instrument", """
        the Instrument stage's Play lost its VoiceOver label. A glyph-and-word button whose spoken \
        label does not say WHAT it plays is the guess #307 traded the visible sentence away against.
        """)
        XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startInstrument),
                       "Starts biofeedback; your body then composes and plays the music.",
                       "the start's hint moved with it from the plate (S7a) and still says what begins")
        XCTAssertEqual(ProjectTransport.playAction(
            .init(clockRunning: false, songPlaying: false, recording: false,
                  sessionRunning: false, songStartable: false), instrumentInFront: true), .startInstrument,
            "with nothing running, the Instrument stage's Play starts the instrument — never dimmed")
        // ABSENCE (the S7a regression): the plate carries no Play/Stop of its own any more.
        let plate = all.filter { $0.file == "EchoelStudioView.swift" }
        XCTAssertFalse(plate.contains { $0.text.contains("private var startButton") }, """
        `startButton` is declared in EchoelStudioView.swift again. The plate's own ▶/■ went with \
        DAW shell S7a: under the head's Play it made two Plays on one screen. The start is the \
        head's; if the plate needs a control, it is not a second Play.
        """)
        let pairs = plate.filter { $0.text.contains("\"stop.fill\"") && $0.text.contains("\"play.fill\"") }
        XCTAssertTrue(pairs.isEmpty, """
        EchoelStudioView.swift draws a Play/Stop glyph pair again at \
        \(pairs.map { "\($0.file):\($0.line)" }.joined(separator: ", ")) — a second transport under \
        the head's ONE Play/Stop (DAW shell S7a).
        """)
    }

    // MARK: - Locating the repo

    /// Same walk-up — and the same SKIP — as the sibling `StringCatalogIsHonestTests`:
    /// `#filePath` is inside `Tests/CISmoke/`, so the repo root is three directories up.
    /// A source-reading test that cannot find the source must skip, not pass: a green it
    /// did not earn is the failure mode this whole directory exists to avoid.
    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // repo
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("source tree not present at \(sources.path) — this test inspects "
                          + "source text, so it SKIPS rather than reporting a green it did "
                          + "not earn")
        }
        return root
    }
}

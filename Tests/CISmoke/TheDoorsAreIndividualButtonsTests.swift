// TheDoorsAreIndividualButtonsTests.swift
// Echoel — #492. The "•••" overflow is dissolved; its two entries are buttons.
//
// FOUNDER, 2026-08-07, third of four asks marked in red on the v10.79.374 (2491) screenshot:
// *"Das mit den drei Punkten als einzelnde Buttons anzeigen."*
//
// ⭐ WHAT MAKES THIS WORTH A GUARD IS NOT THE DELETION — it is that the two doors behind that
// menu are the ONLY global doors in the app that are sheets rather than panels. There is no
// chip that can reach Live Colabo or Learn (#290 says why, and its reasoning survived the menu:
// the chip strip's grammar is "this chip selects what the plate shows", so a chip that opened a
// modal would be a lying tab). With the menu gone, `quickDoorRow` is the only way in. A later
// tidy-up that folds this row away does not make the app smaller — it makes two features
// unreachable, which is the exact failure this repo's doorless-surface register exists for.
//
// ⚠️ WHAT THIS GUARD CANNOT DO, stated first so its green is not read as more than it is.
// EVERY assertion is a SOURCE-TEXT SCAN. It shows that a `Button` is written, never that it
// renders, never that a finger reaches it, never that VoiceOver speaks the label, and never
// that the two-line plate reads well on a 360 pt phone. Those are device probes and all four
// are open. The width arithmetic that forced two lines (7×44 + 6×8 = 356 pt against 361/343/328
// of usable width) is arithmetic over constants, not a measurement of a rendered layout.
//
// ⚠️ HONEST GRADING against the parent tree, MEASURED rather than assumed — every needle below
// transcribed and driven against `git show HEAD:…` as well as against this tree:
//   · SIX assertions are REGRESSIONS (red there, green here), and they split by MECHANISM,
//     which matters more than the count:
//       – TWO fail on something the parent actively CONTAINS: `TransportOverflowMenu` still
//         declared and built, and the two dead notification cases still in the receiver.
//       – THREE fail because their ANCHOR does not exist yet — `quickDoorRow` is absent, so
//         they throw `DoorAnchorMissing`. That is ONE absence reported three times, not three
//         findings, and calling it three would be the #433 defect in the flattering direction.
//       – ONE (the mount) is in between: `startControlRow` exists on the parent and simply
//         does not name the row.
//   · ONE is a COUNTERWEIGHT, green on both sides: both sheets still exist. It exists because
//     the tempting reading of "dissolve the menu" is "remove the doors", and because the
//     presentation chain the black-screen law guards (10.76.34) must be UNCHANGED by this
//     slice — this commit moves who taps the sheets, not how many sheets there are.
//
// ⚠️ `SourceText.codeOnly` (#453) IS PROPHYLACTIC HERE, NOT LOAD-BEARING — measured, because
// claiming otherwise is exactly the overclaim #484 had to retract one cycle earlier. Raw text
// against stripped text: **0 of 14 verdicts differ** (7 assertions × 2 trees). The reason is
// SCOPING, not luck: the receiver's ⛔ retraction does name the deleted cases, but it sits
// outside the brace-matched `switch`, and the one file-wide `case "learn":` in prose is 2,300
// lines away from it. It stays because #453 made ONE definition of "code, not prose" for the
// whole blocking bundle and a private exception is the defect that slice removed — and because
// the shape that WOULD make it load-bearing is one comment away: a future retraction inside
// this file that writes `TransportOverflowMenu()` verbatim turns the negative scan red on
// correct code. This repo writes down what it removed, so a negative scan meets its own
// obituary sooner or later (#486, #488).
//
// ⭐ DAW SHELL S3 (founder 2026-10-02, inbox E18 — "Ja, so bauen"): the doors moved AGAIN, and
// the #492 argument above is why this file moved with them instead of being deleted. The ask
// was a DAW shell — one control bar on top, one canvas — and a DAW keeps Open, Save and its
// collaboration/help doors in ONE project menu. So `quickDoorRow` is gone and the doors are
// entries of the ≡ menu in `WorkspaceView`'s top bar, above BOTH stages (before S3 the row
// existed only on the hidden Instrument stage, so the Piece a fresh install opens on had no
// way into Learn or Live Colabo at all). The menu POSTS a chrome door
// (`Self.postDoor`), the receiver in `EchoelStudioView` raises the SAME sheets — so the
// black-screen chain is unchanged — and each arm refuses under `panelSheetUp` (two-modals law).
// This is NOT #492's overflow coming back: that menu hid two doors behind a "•••" no one read
// as a door; this menu IS the app's logo mark, labelled "Menu" and hinted with all five
// entries, and it is the one place every DAW user looks for Open and Save.
// Grading of the rewrite (transcribed in Python, both trees): on f4b4f006d THREE claims are red
// by ONE absence (#486) — the menu's door buttons + poster, the spoken labels + hint, and the
// receiver arms all name entries that do not exist there yet. FOUR are counterweights, green on
// both: the menu is mounted in `topBar` (S1b-1 already built it), no overflow type, the action
// row's equal widths, and both sheets still exist. On this tree all seven are green.

import Foundation
import XCTest

/// Thrown when a scan's anchor is gone. NOT a skip — a skip passes CI (#454), and "the thing I
/// guard moved" is a failure, not an absence of a checkout.
private struct DoorAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheDoorsAreIndividualButtonsTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"

    // MARK: - 1. the doors are individual entries of the ONE project menu (DAW shell S3)

    /// ⛔ THIS CLAIM SAID "two buttons, NOT a menu" FROM #492 TO DAW SHELL S3 (2026-10-02), and
    /// the founder's newer decision outranks the older one rather than contradicting it. #492
    /// dissolved a "•••" OVERFLOW — a menu whose only job was to hide what did not fit. S3 builds
    /// the approved DAW shell (inbox E18 „Ja, so bauen"): a control bar whose leading ≡ is the
    /// project's ONE address for the doors that leave the piece in hand, on both stages. That is
    /// a named place with a grammar (Open · Save | Live Colabo · Learn | Guide), not an overflow,
    /// and the overflow stays dead (claim 2).
    ///
    /// What survives #492 and is pinned at least as strictly: each door is its OWN `Button`
    /// (no nested `Menu`, no combined control), both sheet doors have a producer — the reason
    /// this file exists, because no chip can reach a sheet (#290) — and the producer reaches the
    /// receiver through the chrome door the studio already owns.
    func testTheTwoDoorsAreIndividualButtons() throws {
        let menu = try projectMenu()
        for door in ["live", "learn"] {
            XCTAssertTrue(menu.contains("Button { Self.postDoor(\"\(door)\") }"), """
                The ≡ menu no longer has its own `Button` for the "\(door)" door.

                Live Colabo and Learn are sheets, so no chip can reach them (#290); since DAW \
                shell S3 this menu entry is the ONLY way in. Without it the sheet compiles, \
                presents correctly, and is unreachable.
                """)
        }
        XCTAssertFalse(menu.contains("Menu {"), """
            A `Menu` is nested inside the ≡ menu.

            The founder's #492 ask (*"Das mit den drei Punkten als einzelnde Buttons anzeigen"*) \
            still binds INSIDE the menu: every door is one tap from the ≡, never folded a \
            second level down.
            """)
        let post = try declarationBody(of: "private static func postDoor(_ door: String) {",
                                       in: Self.workspace)
        XCTAssertTrue(post.contains("NotificationCenter.default.post(name: .echoelChromeDoor, object: door)"), """
            `postDoor` no longer posts the `.echoelChromeDoor` notification with the door name.

            The ≡ menu lives in the ROOT view and must never reach into studio state (the \
            chrome/studio decoupling); the notification IS the wire. A helper that does \
            anything else leaves every menu entry a lying control.
            """)
    }

    /// The menu has to be MOUNTED in the bar. A menu nobody builds is the doorless-surface
    /// shape this repo keeps paying for, and it would leave both sheets with no producer at all.
    /// ⛔ Named `testTheDoorRowIsMounted` until S3 — the row is deleted and a name promising it
    /// would send its reader looking for code that is gone on purpose (#374).
    func testTheMenuIsMountedInTheTopBar() throws {
        let bar = try declarationBody(of: "private var topBar: some View {", in: Self.workspace)
        XCTAssertTrue(bar.contains("Menu {"), """
            `WorkspaceView.topBar` no longer builds the ≡ menu.

            Both doors then have no producer whatsoever: they are sheets, so no chip reaches \
            them, and the Instrument's door tiles were deleted with DAW shell S3. Live Colabo \
            and Learn would compile, present correctly, and be unreachable.
            """)
    }

    // MARK: - 2. the overflow is gone from the whole of Sources/

    /// Scoped to `Sources/` rather than to one file: the failure this catches is somebody
    /// re-introducing the overflow ANYWHERE, not moving it back to its old address.
    func testNoOverflowMenuSurvivesInSources() throws {
        let workspace = try source(Self.workspace)
        XCTAssertFalse(workspace.contains("struct TransportOverflowMenu"), """
            `TransportOverflowMenu` is declared again.

            #492 deleted it on the founder's ask. If a future control genuinely needs an \
            overflow, it needs its own name and its own reason — not the resurrection of the \
            one that was pointed at with a red circle.
            """)
        let studio = try source(Self.studio)
        XCTAssertFalse(studio.contains("TransportOverflowMenu()"), """
            `EchoelStudioView` builds `TransportOverflowMenu()` again — the control the founder \
            asked to be replaced by individual buttons.
            """)
    }

    // MARK: - 3. both doors speak

    /// An icon-only control must say what it is (#489). The tiles needed an
    /// `accessibilityLabel` because their whole visible content was an SF Symbol; a menu entry
    /// is a `Label` whose TITLE is the spoken name, so the requirement moves from the modifier
    /// to the title. Pinned as the title-plus-glyph pair, so an entry that lost its words
    /// (an `Image` alone) is red.
    ///
    /// ⛔ The tile labels were pinned here until S3 ("Live Colabo — play together with a nearby
    /// device", "Learn and news"). Their promise rule lives on unchanged where it always did:
    /// `TheNearbySessionPromisesNoClockTests` scans the Live Colabo copy for a clock promise.
    func testBothDoorsSpeak() throws {
        let menu = try projectMenu()
        for (door, label) in [("Live Colabo",
                               "Label(\"Live Colabo\", systemImage: \"dot.radiowaves.left.and.right\")"),
                              ("Learn", "Label(\"Learn\", systemImage: \"book\")")] {
            XCTAssertTrue(menu.contains(label), """
                The \(door) entry of the ≡ menu lost its spoken title.

                A menu row that is only a glyph is named after the glyph by VoiceOver — \
                "dot radiowaves left and right" or "book". The title is invisible as a \
                defect with VoiceOver off, so no screenshot will ever show it missing (#480).
                """)
        }
        let bar = try declarationBody(of: "private var topBar: some View {", in: Self.workspace)
        XCTAssertTrue(bar.contains(".accessibilityHint(\"Open, save, Live Colabo, Learn and the guide\")"), """
            The ≡ menu's hint no longer names what is behind it.

            The menu's own label is "Menu"; the hint is the one sentence that tells a \
            VoiceOver user Live Colabo and Learn live here — the tiles that used to say it \
            individually are gone.
            """)
    }

    // MARK: - 4. the equal-width counterweight

    /// ⭐ THIS GUARDED `quickDoorRow`'s trailing `Spacer(minLength: 0)` until S3 deleted the
    /// row, and the LAW it carried survives on the one row left: the founder's *"die sollen
    /// immer gleichgroß sein"* (#481/#482). Equal width comes from every tile being flexible —
    /// `expands` gives each flexible child of an `HStack` an equal share — so a fixed-width tile
    /// takes its share out of the equalisation and the row stops matching. Pinned on the two
    /// inline tiles AND on `KeepLastLoopButton`, which builds its tile in its own body.
    func testTheEqualWidthCounterweightIsPresent() throws {
        let row = try declarationBody(of: "private var quickActionRow: some View {",
                                      in: Self.studio)
        XCTAssertEqual(row.components(separatedBy: "expands: true").count - 1, 2, """
            `quickActionRow` no longer passes `expands: true` to exactly its two inline tiles \
            (Record and MIDI).

            Equal width comes from every tile in the row being flexible. A fixed-width tile \
            here takes its share out of the equalisation and the row stops being "gleichgroß".
            """)
        XCTAssertTrue(row.contains("KeepLastLoopButton("), """
            `quickActionRow` no longer builds `KeepLastLoopButton` — the third tile. Re-anchor \
            this claim on the row's new third member; do not let the count above shrink alone.
            """)
        let keep = try declarationBody(of: "private struct KeepLastLoopButton: View {",
                                       in: Self.studio)
        XCTAssertTrue(keep.contains("expands: true"), """
            `KeepLastLoopButton` builds its tile without `expands: true`, so it is the one \
            fixed-width member of a row whose brief is equal width.
            """)
    }

    // MARK: - 5. every door case has its producer

    /// ⛔ UNTIL S3 THIS ASSERTED THAT `case "learn"` / `case "live"` WERE ABSENT — #492 deleted
    /// them with their only poster, the "•••" overflow, on the receiver's own rule (#290): a
    /// `case` whose only poster is gone compiles silently and reads like a live hook. S3 brings
    /// both back TOGETHER with their poster, which is exactly what that rule's message asked
    /// for ("re-add the case TOGETHER with the control, never ahead of it"). So the claim is
    /// now the rule itself, stated positively and checked both ways: each case is present, it
    /// raises its sheet, and the ≡ menu posts its name.
    /// ⛔ Named `testTheDeadNotificationCasesAreGone` until S3, which brought the cases back
    /// with their poster; the name now says what the claim checks (#374).
    func testEveryReceiverArmHasItsMenuPoster() throws {
        let receiver = try switchBody(after: "publisher(for: .echoelChromeDoor)) { note in",
                                      in: Self.studio)
        let menu = try projectMenu()
        for (door, flag) in [("learn", "showLearn = true"), ("live", "showLiveColabo = true"),
                             ("open", "showOpen = true"), ("save", "showSaveDialog = true")] {
            let arm = try caseArm(door, in: receiver)
            XCTAssertTrue(arm.contains(flag), """
                The receiver's `case "\(door)":` no longer sets `\(flag)`.

                The ≡ menu posts "\(door)"; an arm that raises nothing turns that menu entry \
                into a lying control.
                """)
            XCTAssertTrue(menu.contains("Self.postDoor(\"\(door)\")"), """
                `case "\(door)":` is in the `.echoelChromeDoor` receiver but the ≡ menu no \
                longer posts it — a case with no producer, the exact shape #290 and #492 \
                deleted four times. Remove the case together with its control, or restore the \
                entry.
                """)
        }
        // ⛔ #1311 — THIS ANCHORED ON `case "video"` AND WENT RED WITH #1304. The founder
        // withdrew video capture ("Kein Video Capture"); that slice deleted the header clips
        // tile, which was this case's only producer, and the case with it — correctly, by this
        // guard's own rule that a case and its control move together. The ANCHOR was the
        // casualty: it named one of three producers, and it named the one that died.
        //
        // ⭐ Anchor a non-vacuous half on the WHOLE surviving set, not on one member of it.
        // Both remaining producers are asserted below, so the #343 trap this half exists for
        // (a receiver that quietly loses everything) is still covered, and losing EITHER one
        // now names itself.
        for live in ["case \"routing\"", "case \"bio\""] {
            XCTAssertTrue(receiver.contains(live), """
                The `.echoelChromeDoor` receiver lost `\(live)`, a case with a LIVE producer.

                The header monitor tiles still post `"routing"` and `"bio"` (`"video"` went \
                with the clips tile in #1304). #492 removed two dead cases; it did not retire \
                the notification, and a scan that only forbids things is green on a receiver \
                that lost everything (the #343 trap). If the tile that posts this really was \
                removed, drop the case AND this entry in the same commit.
                """)
        }
    }

    // MARK: - 6. counterweight: the doors themselves still open

    /// Green on both sides of #492 and of S3 on purpose. Two things could quietly undo either
    /// slice in the tidy-up direction: removing the sheets along with the control that used to
    /// open them, and "consolidating" by adding a NEW presentation modifier. The first makes two
    /// features unreachable; the second spends headroom the black-screen law (10.76.34) has none
    /// of. S3 moved who taps the sheets, not how many there are —
    /// `ResetSoundClearsWhatTheLaunchLineReportsTests` owns the count, this owns the identities.
    func testBothSheetsStillExist() throws {
        let studio = try source(Self.studio)
        for flag in ["$showLearn", "$showLiveColabo"] {
            XCTAssertTrue(studio.contains(".sheet(isPresented: \(flag))"), """
                The `\(flag)` sheet is gone.

                Moving the doors into the ≡ menu was about WHO TAPS them, not about whether the \
                door exists. Without this sheet the menu entry posts a door that raises a flag \
                nothing reads — a lying control, which is the class this repo has retracted \
                twice (#435, #480).
                """)
        }
    }

    /// The brace-matched content of the ≡ menu, found inside `topBar` so another `Menu` in the
    /// root file can never be the one scanned (#408).
    private func projectMenu() throws -> String {
        let bar = try declarationBody(of: "private var topBar: some View {", in: Self.workspace)
        return try braceBody(after: "Menu {", in: bar, file: Self.workspace)
    }

    /// The text of one `case "<door>":` arm — from its label to the first following line that
    /// opens another arm (`case …` or `default:`). This receiver's arms are flat statement
    /// lists, so the next arm label is the end of this one.
    private func caseArm(_ door: String, in receiver: String) throws -> String {
        let label = "case \"\(door)\":"
        guard let start = receiver.range(of: label) else {
            throw DoorAnchorMissing(reason: """
                `\(label)` not found in the `.echoelChromeDoor` receiver — the ≡ menu posts it, \
                so the door is dead. Restore the arm or remove the menu entry.
                """)
        }
        var arm: [Substring] = []
        for line in receiver[start.upperBound...].split(separator: "\n",
                                                         omittingEmptySubsequences: false) {
            let t = line.drop(while: { $0 == " " })
            if !arm.isEmpty, t.hasPrefix("case ") || t.hasPrefix("default:") { break }
            arm.append(line)
        }
        return arm.joined(separator: "\n")
    }

    // MARK: - source access

    /// Comment-stripped source, a SKIP when there is no checkout, and a FAILURE when the file
    /// itself moved. The distinction is #454's lesson: a skip passes CI, so "no tree" is a
    /// legitimate skip and "the thing I guard was renamed" must never be one.
    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw DoorAnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The brace-matched body that follows `key`, which must end in its opening brace.
    ///
    /// Brace-matched rather than "from here to the next declaration": this file holds ~9,900
    /// lines and several members whose text would otherwise leak into the scan. Deriving scope
    /// from FILE ORDER is a mistake this repo has already paid for more than once.
    private func declarationBody(of key: String, in relativePath: String) throws -> String {
        try braceBody(after: key, in: try source(relativePath), file: relativePath)
    }

    /// The `switch` that opens on the first line of the given closure.
    ///
    /// Anchored on the closure header and then on its `switch`, rather than on `switch note.object`
    /// directly, because more than one receiver in this file switches on a notification payload
    /// — and a scan that matches the wrong one is green on the wrong evidence (#408).
    private func switchBody(after anchor: String, in relativePath: String) throws -> String {
        let closure = try braceBody(after: anchor, in: try source(relativePath),
                                    file: relativePath)
        return try braceBody(after: "switch note.object as? String {", in: closure,
                             file: relativePath)
    }

    private func braceBody(after key: String, in text: String, file: String) throws -> String {
        guard let start = text.range(of: key) else {
            throw DoorAnchorMissing(reason: """
                `\(key)` not found in \(file) — renamed, reflowed or removed. Re-anchor this \
                scan; do not leave it silent.
                """)
        }
        // `start.upperBound` sits just past the opening brace, so the depth starts at 1.
        var depth = 1
        var body = ""
        var i = start.upperBound
        while i < text.endIndex, depth > 0 {
            let c = text[i]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            body.append(c)
            i = text.index(after: i)
        }
        XCTAssertEqual(depth, 0, "unbalanced braces after `\(key)` in \(file) — scan is unsound")
        return body
    }
}

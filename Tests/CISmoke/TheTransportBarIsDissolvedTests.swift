// TheTransportBarIsDissolvedTests.swift
// Echoel — #456. Founder screenshot, v10.79.371 (2488): the "•••" overflow and the
// `1.1.1 / loop 1/32` readout are each circled with an arrow drawn INTO the transport row
// below them. In this founder's markup grammar (established by #411's "soll dort hin wo der
// rote Pfeil hinzeigt migrieren") that means MOVE THESE THERE. Both children moved; the bar
// that held them — the last chrome transport bar — is deleted rather than left empty.
//
// ⭐ TWO LINES AND NOT ONE, and the reason is a measurement that was already written down.
// `startControlRow`'s own doc priced the one-line version: the analysis pill — which the
// founder asked to make BIGGER on 2026-07-31 (#305/#307) — already drops to roughly 150 pt
// of its 300 on a 393 pt phone with only FOUR children in the row, and the two migrants add
// a ~30 pt chip, a ~100 pt readout and two more 8 pt gaps on top of that. (⛔ The first
// version of this header said "roughly a third of its width" and credited that doc; the doc
// says 150-of-300 and says it about the four-child row. Quoting a number is where numbers
// get invented.) The same doc named the answer for exactly this case: *"the cheapest answer is to move
// `TransportPositionView` and the '•••' overflow OUT of the chrome bar as well and give this
// row a second line — NOT to send the tempo back up."* Claim 2 is the assertion that keeps
// line 1's four children together and the migrants off it.
//
// ⛔ "LINE 1 IS THEREFORE BIT-FOR-BIT WHAT IT WAS" STOOD HERE and was true until #1027
// (`fcd3d4b8`, v10.79.454): the four children now choose between one line and two via
// `ViewThatFits` in `transportLine1`, so the simulation's "Demo" tag cannot push the row past
// the right edge. Same four children, none squeezed — a second line is not a squeeze. The
// studio view struck the sentence in its own doc block in that commit; this file did not move
// with it, and claim 2 went RED there and stayed red through three deploys (454 → 458) without
// anyone seeing it: the CI/CD job log is `tail -200 test.log` (#807) and this test's line fell
// outside that window on every run until #1091's (14:34Z, 2026-09-07). #456's own lesson —
// prose moves in EVERY home at once — was applied to two Sources homes and missed the guard
// that quotes them. Repaired in #1092.
//
// ⛔ AND ON 2026-09-30 THE FOUR BECAME THREE (interface audit, "ein Kopf, der spricht", head
// leaf 2): the pulse pill moved UP to `ProjectHeader`, the head above both stages, because the
// Piece stage — the home since that day's slice 1 — showed no body at all. Claim 2 is rewritten
// as that decision, not weakened: line 1 holds ▶ ⏸ tempo+lock and MUST NOT build
// `PulseMonitorMiniLive` any more (one address, #416), and the header builds it exactly once,
// choosing one line or two with the `ViewThatFits` the studio row no longer needs. The migrants
// law is unchanged. The founder's 2026-07-31 drawing put the pill in this row when this plate
// was the app's home; that is recorded here so the next reader does not "restore" it from #289.
//
// ⛔ AND ON 2026-10-02 THE THREE BECAME TWO (DAW shell S7a, founder „Ja, so bauen" — one control
// bar on top): the ▶/■ (`startButton`) is DELETED, because under the head's Play it made two
// Plays on one screen; the head's ONE Play starts the instrument now (`OneStartControlTests`).
// Claim 2 is rewritten as that decision, again not weakened: line 1 holds ⏸ tempo+lock, and the
// declaration MUST NOT build `startButton` — the same one-address shape as the pill above.
//
// ⚠️ WHAT THIS FILE CANNOT DO, said first. Every assertion is a SOURCE SCAN. SwiftUI layout
// is not reachable from a unit test here, so "the row reads well on a 393 pt phone" and "the
// chrome is shorter now" are device looks. What is proven is that the bar is gone, that both
// children have exactly one home, that line 1 was not touched, and that the ~10 Hz playhead
// still lives in its own leaf — the freeze law's requirement for mounting it in the body that
// hosts the instrument's Pickers.

import Foundation
import XCTest
@testable import Echoelmusic

/// Thrown when a scan anchor is gone. An uncaught error in a `throws` test method FAILS,
/// which is the point — `XCTSkip` would have been green (the #454 lesson).
private struct MissingAnchor: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheTransportBarIsDissolvedTests: XCTestCase {

    // MARK: - 1. the bar is gone, not emptied

    /// RED before #456. An emptied-but-present container is the worse outcome: it reads like a
    /// place to put things back, and it keeps a third always-on ancestor above the instrument.
    func testTheTransportBarStructIsDeleted() throws {
        let workspace = try source("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertFalse(workspace.contains("struct TransportBar: View"), """
            `TransportBar` was re-declared.

            #456 dissolved it on the founder's 2026-08-07 arrows; its two children live in \
            `EchoelStudioView.startControlRow`. If a chrome transport bar is genuinely wanted \
            again, that is a founder ask and this test should be rewritten with it — not \
            deleted so the struct can quietly come back.
            """)
        XCTAssertFalse(workspace.contains("TransportBar()"), """
            Something still mounts `TransportBar()`.
            """)
    }

    // MARK: - 2. the counterweight: line 1 is untouched

    /// ⭐ THE ASSERTION THAT EARNS ITS PLACE GOING FORWARD.
    ///
    /// The obvious follow-up to #456 is "now put it all on one line after all". That is the
    /// change the measurement above rules out, and it is invisible in a diff that merely
    /// deletes a `VStack`. All four original children must still share ONE `HStack` with the
    /// two newcomers in a different one.
    ///
    /// ⛔ THE FIRST VERSION OF THIS TEST COULD NOT FAIL FOR THE REASON IT STATED — found by a
    /// reviewer, reproduced by me. It checked membership in the WHOLE row and counted
    /// `HStack(spacing: 8)` occurrences, so swapping `PulseMonitorMiniLive()` down into line 2
    /// and `TransportPositionView()` up into line 1 left every assertion green while "line 1 is
    /// bit-for-bit unchanged" — the single fact the slice rests on — was false and the pill was
    /// squeezed exactly as feared. Membership is now asserted PER LINE, in both directions.
    /// (⛔ `testTheFirstLineHoldsTheThreeTransportChildrenAndNotThePill` until S7a — the name
    /// counted a child that is gone, #374.)
    func testTheFirstLineHoldsThePauseAndTheTempoAndNotThePill() throws {
        let path = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
        let row = try declarationBody(of: "private var startControlRow: some View {", in: path)
        // ⛔ UNTIL #1092 THIS SCANNED `startControlRow` ITSELF for an inner `HStack(spacing: 8)`
        // and found ONE — the four originals. #1027 lifted that stack into its own member,
        // `transportLine1`, so the row body holds a member REFERENCE (exactly like
        // `quickActionRow`, which this file already knew was a reference and not a stack) and
        // the count fell to zero: assertion red, then `firstInnerRow` threw. The scan follows
        // the declaration now; the property it defends is unchanged.
        XCTAssertTrue(row.contains("transportLine1"), """
            `startControlRow` no longer builds `transportLine1` — line 1 (⏸ tempo+lock; \
            the ▶ went to the head with S7a, the pill on 2026-09-30) has left the transport row. If it was deliberately restructured, \
            rewrite this file with the change rather than deleting it.

            Row scanned (comments blanked by SourceText.codeOnly):
            \(row)
            """)
        let line = try declarationBody(of: "private var transportLine1: some View {", in: path)
        // ⛔ THIS COUNT WAS `>= 2` UNTIL #490 AND IT HAD TO COME DOWN, not because the law
        // weakened but because one of the two lines it counted is gone. #456 put the readout on
        // a third line of its own; the founder's 2026-08-07 arrow moved that readout into
        // `WorkspaceView.topBar`. Since #1027 the declaration holds TWO `HStack(spacing: 8)`
        // (the fitting candidate and the wrapped one) plus one under `#else`; the FIRST is
        // line 1 as it renders whenever it fits, and that is the one the membership loop reads.
        //
        // The merge this test exists to catch is still caught, and by a stronger assertion than
        // a count: the tiles of lines 2 and 3 reach line 1 only by being spelled there, and the
        // per-line membership loop below rejects `EchoelIconTile(` by name (#492 — it named the
        // deleted `TransportOverflowMenu()` until then, which would have made it vacuous). A
        // count of stacks never could distinguish "merged" from "restructured"; the membership
        // checks always did the real work.
        let hstacks = line.components(separatedBy: "HStack(spacing: 8) {").count - 1
        XCTAssertGreaterThanOrEqual(hstacks, 1, """
            `transportLine1` has \(hstacks) inner `HStack(spacing: 8)`, expected at least 1.

            Zero means line 1 itself is gone — what is left of the four originals (⏸ \
            tempo+lock) no longer shares a row. That row is the instrument's transport; if it was \
            deliberately restructured, rewrite this file with the change rather than deleting it.

            Declaration scanned (comments blanked by SourceText.codeOnly):
            \(line)
            """)

        // Since #1027 two of the four are LOCALS, bound once above the `ViewThatFits` and
        // reused by both candidates — `PulseMonitorMiniLive` is the leaf that reads the ~10 Hz
        // camera publisher (10.76.50), and building it in each candidate would put two live
        // readers in the tree where one belongs. So line 1 is checked for the four NAMES it
        // spells, and the declaration for the two constructions those names resolve to.
        let lineOne = try firstInnerRow(of: line)
        for child in ["PlaybackToggleButton()", "tempo"] {
            XCTAssertTrue(lineOne.contains(child), """
                Line 1 of `transportLine1` no longer builds `\(child)`.

                Line 1 is the transport row as it stood before #456 (wrapped by #1027, three \
                children since the pill moved to the head on 2026-09-30, two since the ▶/■ went \
                to the head's ONE Play with S7a). Its children staying \
                on ONE row is what makes "nothing that exists today can be squeezed" a fact \
                rather than a hope.

                Line 1 scanned: \(lineOne)
                """)
        }
        // ⛔ The ▶/■ is the FIRST child no more (DAW shell S7a, 2026-10-02): the start is the
        // head's ONE Play. A `startButton` back on this row is two Plays on the Instrument stage —
        // the confusion `OneStartControlTests` exists for.
        XCTAssertFalse(line.contains("startButton"), """
            `transportLine1` builds `startButton` again. Since DAW shell S7a the instrument's start \
            is the head's ONE Play (`ProjectPlayStopButton`, `.startInstrument`); a second ▶ here \
            is two Plays one row apart. Rewrite this claim with the founder's decision if that \
            changes — do not add it back.

            Declaration scanned: \(line)
            """)
        // ⛔ The pill is the FOURTH child no more (2026-09-30, head leaf 2). One address, #416:
        // a second mount here is a second ~10 Hz camera reader (10.76.50) and the same pulse
        // on screen twice. If the founder wants it back on this row, MOVE it and move this.
        XCTAssertFalse(line.contains("PulseMonitorMiniLive"), """
            `transportLine1` builds the pulse pill again. Since 2026-09-30 its ONE address is \
            `ProjectHeader`, the head above both stages. Move it, do not add it — and rewrite \
            this claim in the same commit.
            """)
        let pill = try declarationBody(of: "private var pulsePill: some View {",
                                       in: "Sources/Echoelmusic/Studio/ProjectHeader.swift")
        XCTAssertTrue(pill.contains("PulseMonitorMiniLive()"), """
            `ProjectHeader.pulsePill` no longer builds `PulseMonitorMiniLive()`. Then the pill has \
            NO mount at all — the door `TheBioPanelDoorIsThePulsePillTests` names would be gone.
            """)
        let headerBody = try declarationBody(of: "var body: some View {",
                                             in: "Sources/Echoelmusic/Studio/ProjectHeader.swift")
        XCTAssertTrue(headerBody.contains("ViewThatFits(in: .horizontal)"), """
            `ProjectHeader.body` no longer chooses one line or two with `ViewThatFits`. The pill's \
            greedy trace beside a flexing summary and two floored buttons is the #1027 shape; a \
            fixed `HStack` overflows in portrait, a fixed `VStack` wastes a line where it fits.
            """)
        // ⛔ The first draft counted the BINDING (`let pulse = PulseMonitorMiniLive()`) and said
        // "more than one means the leaf is built per candidate" — a bare second
        // `PulseMonitorMiniLive()` in the wrapped candidate left that count at one and the
        // message promising a catch it could not make (#367; caught by the mutant, not by
        // the reviewer). The CONSTRUCTOR is counted; the binding is asserted separately.
        // ⛔ `("let pulse = ", "PulseMonitorMiniLive()")` was the second pair until 2026-09-30.
        for (binding, constructor) in [("let tempo = ", "BodyTempoField(")] {
            XCTAssertTrue(line.contains(binding + constructor), """
                `transportLine1` no longer binds `\(binding + constructor)`.

                The local that line 1 spells resolves to something else, so the membership \
                check above is reading a name, not the original.

                Declaration scanned: \(line)
                """)
            XCTAssertEqual(line.components(separatedBy: constructor).count - 1, 1, """
                `\(constructor)` is constructed \(line.components(separatedBy: constructor).count - 1) \
                times in `transportLine1`, expected exactly once.

                It is bound once above the `ViewThatFits` and reused by both candidates. A \
                second construction puts a second `PulseMonitorMiniLive` — the ~10 Hz camera \
                leaf — in the tree where one belongs (10.76.50), or a second tempo field with \
                its own lock callback.

                Declaration scanned: \(line)
                """)
        }
        // The other direction, which is what the first version was missing: the two migrants
        // must NOT be on line 1. Without this, moving one up passes every check above.
        //
        // ⛔ `"TransportOverflowMenu()"` WAS THE FIRST ENTRY UNTIL #492 AND IT IS REPLACED,
        // NOT DROPPED. That type no longer exists — the founder asked for its two entries as
        // individual buttons — so the needle would have been vacuously true forever, which is
        // the #367 shape: a check that cannot fail for its stated reason. `EchoelIconTile(` is
        // the STRONGER replacement: line 1 builds none today (⏸ and tempo are their own structs;
        // until S7a the ▶ drew its own `Image`), so any action or door tile appearing
        // there is exactly the "merge it all onto one line after all" change this test exists
        // to catch — and now it catches all seven of them instead of one.
        //
        // Scanned over the WHOLE `transportLine1` declaration since #1092, not only its first
        // stack: a migrant smuggled into the wrapped candidate is the same one-line layout on
        // narrow phones, where the wrap is exactly what renders.
        for migrant in ["EchoelIconTile(", "TransportPositionView()"] {
            XCTAssertFalse(line.contains(migrant), """
                `\(migrant)` moved up into `transportLine1`.

                That is the one-line layout by another name, and it squeezes the analysis pill \
                — see the message above.

                Declaration scanned: \(line)
                """)
        }
    }

    // MARK: - 3. both migrants have exactly one home

    /// ⛔ THE "•••" MOVED ONE DECLARATION DEEPER WITH #482, then CEASED TO EXIST WITH #492,
    /// and this test moved with it both times, in the same commit each time. After #492
    /// `startControlRow` had three lines — `quickActionRow` (the take) and `quickDoorRow` (the
    /// two sheets the overflow used to hold, as tiles). DAW shell S3 (2026-10-02) moved those
    /// doors into the ≡ menu of the approved control bar, so the row is gone and this test
    /// now asserts its ABSENCE together with the menu's producer — one address per door.
    ///
    /// Asserting the rows SEPARATELY is deliberate: a single scan over `startControlRow` would
    /// see neither row's contents (both are member references), and widening the scan to the
    /// whole file would let a migrant drift back while staying green.
    func testBothMigrantsAreMountedInTheStudioRow() throws {
        let path = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
        let row = try declarationBody(of: "private var startControlRow: some View {", in: path)
        // The extraction IS the assertion: a missing anchor throws, and a thrown error fails.
        _ = try declarationBody(of: "private var quickActionRow: some View {", in: path)
        XCTAssertTrue(row.contains("quickActionRow"), """
            `startControlRow` no longer builds `quickActionRow`. That row IS the founder's \
            2026-08-07 ask — "alles … in eine Reihe unter dem Play etc zusammengefasst" — and \
            it carries the "•••" the first of his two arrows pointed at.
            """)
        // ⛔ THIS ASSERTED `actions.contains("TransportOverflowMenu()")` UNTIL #492, and then
        // that `startControlRow` built `quickDoorRow`, the third line holding the two sheet
        // doors as tiles, until DAW SHELL S3 (founder 2026-10-02, inbox E18 „Ja, so bauen").
        // The approved DAW shell gives the project ONE address for doors that leave the piece
        // in hand — the ≡ menu leading the control bar, on BOTH stages — so the founder's newer
        // decision moved them back up into the chrome, deliberately, as named menu entries
        // rather than as the dissolved overflow. The property this half now defends is the
        // one #416 asks of every migrant: ONE address. A copy of either door back on the
        // Instrument's plate would be a second way to the same sheet.
        // `TheDoorsAreIndividualButtonsTests` owns the menu's contents.
        XCTAssertFalse(row.contains("quickDoorRow"), """
            `startControlRow` builds a door row again. Since DAW shell S3 the two sheet doors \
            (Live Colabo, Learn) and Open live in the ≡ menu — a row here is a second door to \
            each sheet on the Instrument stage.
            """)
        let actions = try declarationBody(of: "private var quickActionRow: some View {", in: path)
        for setter in ["showLearn = true", "showLiveColabo = true", "showOpen = true"] {
            XCTAssertFalse(row.contains(setter) || actions.contains(setter), """
                The Instrument's start row sets `\(setter)` again — a second door next to the \
                ≡ menu, which already reaches that sheet on both stages (DAW shell S3).
                """)
        }
        let workspace = try declarationBody(of: "private var topBar: some View {",
                                            in: "Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(workspace.contains("Self.postDoor(\"learn\")"), """
            The ≡ menu no longer posts "learn". Learn is a sheet, not a panel — no chip reaches \
            it — so the menu entry is the only way in.
            """)
        // ⛔ THE SECOND MIGRANT MIGRATED AGAIN (#490) and this assertion is INVERTED rather
        // than deleted. The founder's 2026-08-07 screenshot ran an arrow from the scribbled-out
        // colour bars in the header down to the circled `1.1.1 / loop 1/8`: the readout's home
        // is `WorkspaceView.topBar` now. What must not happen is a SECOND copy appearing back
        // here — one readout, one address (#416) — and that is what this checks.
        // `TheHeaderShowsTheLoopTests` owns the positive half.
        XCTAssertFalse(row.contains("TransportPositionView()"), """
            `TransportPositionView()` is back in `startControlRow`.

            Since #490 it lives in `WorkspaceView.topBar` — the founder drew the arrow from the \
            header's colour bars to this readout. Two mounts would put the same loop position on \
            screen twice, which is the duplicate-definition shape this repo keeps paying for, \
            and the instrument would lose the ~40 pt of plate the move gave back.

            If the founder asks for it down here again, move it — do not add it.
            """)
    }

    // MARK: - 4. the freeze law, which is what makes claim 3 safe

    /// `TransportPositionView` reads `transport.position` — ~10 Hz at 120 BPM. Mounting it in
    /// `EchoelStudioView` is only legal because the read happens in ITS body, not in the host's
    /// (10.76.41/50). Inlining its two labels would be the exact shape of that ship-blocker,
    /// and it is a tempting "simplification" for a two-label view.
    func testThePlayheadReadStaysInsideItsOwnLeaf() throws {
        let leaf = try declarationBody(of: "struct TransportPositionView: View {",
                                       in: "Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(leaf.contains("@Environment(Transport.self)"), """
            `TransportPositionView` no longer reads `Transport` in its own body.

            If the read moved UP into `EchoelStudioView`, that is the freeze defect: the ~10 Hz \
            playhead would rebuild the body that hosts every `.menu` Picker in the instrument, \
            and an open Picker popover is torn down on every rebuild (10.76.41/50).
            """)
        let studio = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertFalse(studio.contains("transport.position"), """
            `EchoelStudioView` now reads `transport.position` directly.

            That is a ~10 Hz read in the Picker-hosting body — the freeze law. The playhead \
            belongs in `TransportPositionView`, its own leaf. (⛔ This sentence used to end \
            "which is why that struct is not `private`" — self-negating since #490 moved the \
            mount back into `WorkspaceView.swift`, where `private` would compile again. The \
            access level is vestigial from #456, not a law.)
            """)
    }

    // MARK: - 5. the geometry note survived its host

    /// The `fixedSize` + `minHeight` pair is a law about EVERY chrome bar, and its canonical
    /// statement used to sit on the frame of the bar #456 deleted — while two other frames in
    /// the same file point at it by name. Deleting the bar without moving the note would have
    /// left two live frames citing an explanation that no longer exists.
    ///
    /// ⛔ THE FIRST VERSION SCANNED THE WHOLE FILE and could not fail for its stated reason:
    /// `.fixedSize(horizontal: false, vertical: true)` also appears on a `Text` inside
    /// `SessionNamePreview`, which is not a bar at all — so both chrome bars could lose the pin
    /// while this stayed green on that `Text`. Scoped to the surviving bar's own declaration.
    func testTheChromeGeometryLawStillHasItsCanonicalStatement() throws {
        let strip = try declarationBody(of: "struct CompositionHeaderStrip: View {",
                                        in: "Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(strip.contains(".fixedSize(horizontal: false, vertical: true)"), """
            `CompositionHeaderStrip` no longer pins its own height.

            `.frame(minHeight:)` alone forwards the proposal downward, so a bar hosting any \
            vertically greedy child (an `EchoelValueField`'s bare scrub `Rectangle()`, for one) \
            reports ∞ and splits the screen with `SurfaceHost`. That is what the founder \
            photographed in v10.79.371 (#455).
            """)
    }

    // MARK: - source access

    /// Comment-stripped source, or a skip when the tree is not present.
    ///
    /// `SourceText.codeOnly` (#453) earns its place here for exactly ONE claim, and the
    /// measurement is stated rather than assumed.
    ///
    /// ⛔ THIS SAID "at least four of the five claims below would pass on an explanation
    /// instead of on code without it." Measured at `d8bf125` over every needle of this file and
    /// its #455 sibling, raw vs stripped: **one of ten outcomes differs**, and it is the
    /// opposite of what the sentence claimed — stripping prevents a false RED, not four false
    /// greens. `EchoelStudioView` quotes `transport.position` in a doc comment, so claim 4b
    /// ("the studio must NOT read it") fails on prose without it. The negative claims about
    /// `TransportBar` are unaffected: the replacement note says "TransportBar stood here",
    /// without the parentheses the scan looks for. An unmeasured "load-bearing" claim is the
    /// same defect as an unmeasured number, and this file family has retracted three of those.
    ///
    /// ⛔ THE SKIP IS SCOPED TO THE TREE, NOT THE FILE — the first version skipped whenever the
    /// FILE was missing, which meant renaming or moving `WorkspaceView.swift` turned every claim
    /// in this file green at once. That is the #454 lesson (a skip PASSES CI) applied one level
    /// out: "no checkout" is a legitimate skip, "the thing I guard moved" is a FAILURE.
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
            throw MissingAnchor(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The first inner `HStack(spacing: 8) { … }` of an already-extracted declaration body.
    ///
    /// Line 1 is the pre-#456 row; asserting on the WHOLE body cannot tell line 1 from
    /// line 2, which is exactly the hole the first version of claim 2 had. Since #1092 the
    /// body handed in is `transportLine1`'s, whose first stack is the fitting candidate.
    private func firstInnerRow(of row: String) throws -> String {
        let key = "HStack(spacing: 8) {"
        guard let start = row.range(of: key) else {
            throw MissingAnchor(reason: """
                No inner `\(key)` in the scanned declaration — the row was restructured. \
                Re-anchor this scan; do not leave it silent.
                """)
        }
        var depth = 1
        var body = ""
        var i = start.upperBound
        while i < row.endIndex, depth > 0 {
            let c = row[i]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            body.append(c)
            i = row.index(after: i)
        }
        XCTAssertEqual(depth, 0, "unbalanced braces inside the scanned declaration — scan is unsound")
        return body
    }

    /// The brace-matched body that follows `key`, which must end in its opening brace.
    ///
    /// Brace-matched rather than "from here to the next declaration": both files hold several
    /// members whose text would otherwise leak into the scan, and this repo has already paid
    /// for deriving scope from FILE ORDER more than once.
    private func declarationBody(of key: String, in relativePath: String) throws -> String {
        let text = try source(relativePath)
        guard let start = text.range(of: key) else {
            throw MissingAnchor(reason: """
                `\(key)` not found in \(relativePath) — renamed, reflowed or removed. \
                Re-anchor this scan; do not leave it silent.
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
        XCTAssertEqual(depth, 0, "unbalanced braces while extracting `\(key)` — scan is unsound")
        return body
    }
}

// TheTransportBarIsOneRowTests.swift
// Echoel — design slice C (founder 2026-10-01, verbatim: "Vermeide das es mehrfache Wege zu einem
// Bereich gibt und das es so unübersichtlich ist. Viele Bereiche sind zu groß und füllen den
// Bildschirm aus. Vermeide slop."). BLOCKING bundle.
//
// THE MEASUREMENT (HEAD 430b20307, 375 × 667 pt). The Piece stage's pinned transport bar
// (`WorkstationView.transportBar` → `transportRow`) stacked FOUR things: the Play row (44 pt),
// a caption line, the Record button (44 pt) and Record's own caption (one to three lines) —
// about 145–170 pt, under an arrangement viewport of about 121 pt. Two of the four were
// sentences, and most of them restated a button ("Plays the piece's parts from the top." beside
// a button that says Play) or repeated the button's VoiceOver hint word for word.
//
// THE LAW (what this file pins):
// 1. END-TO-END (pure, `RecordTake.shownReason`): under the row, the Record door draws a sentence
//    ONLY for a block the user can lift from the Workstation (arm a track · switch a stale arm
//    off · free a grid slot), and only while the piece can start. Ready, recording, "stop first"
//    and "nothing to play" draw nothing from this door.
// 2. SOURCE: Play, Click and Record are direct children of ONE switching group (`controls { … }`),
//    in that order — one row, not a row plus a second row.
// 3. SOURCE: `RecordTakeButton` draws no caption and no warning of its own; its sentence is its
//    `.accessibilityHint`, it keeps its 44 pt floor, its word is never shrunk to fit (Dynamic
//    Type grows the text, never shrinks it — a full row WRAPS the word inside the 44 pt button
//    instead of truncating it), and it reads its state through the ONE reading it shares with
//    the note (`RecordTake.current`).
// 4. SOURCE: `RecordTakeNote` is the one place the block and the dropped-recordings warning are
//    drawn, it reads nothing hot, presents nothing, and the Workstation mounts it once, under the
//    row (after the group closes).
// 5. SOURCE: the bar's own sentence stands only while the PIECE is not playing and only when it
//    says what no button can — the instrument is what Stop would end, or nothing can start.
// 6. SOURCE: the position readout is the element that yields — a `ViewThatFits` with
//    `.layoutPriority(-1)` whose fallback is the meter alone, so Play, Click and Record never
//    give up width to it. ONE construction of the meter (`let meter`).
//
// WHAT KIND OF GREEN THIS IS (§1): claim 1 is END-TO-END on a shipped, pure, nonisolated function;
// claims 2–6 are SOURCE-TEXT SCANS — the bar is a private SwiftUI body no bundle renders. They
// prove where text sits, not that the row fits on glass.
//
// HONEST GRADING (§3), against the parent 430b20307: this file names `RecordTake.shownReason`,
// which this commit creates, so it DOES NOT COMPILE there and no assertion has a verdict.
// Transcribed in Python against both trees instead:
// · claim 1 FORWARD (drives the new symbol; could never have been red).
// · claim 2 is a REGRESSION: on the parent `RecordTakeButton(` sits AFTER the group's closing
//   brace (its own row) — red there for that named reason.
// · claim 3 is a REGRESSION on its first two needles (the parent's button draws `Text(caption)`
//   and the dropped-recordings line under itself); its hint, 44-pt and no-shrink needles are
//   COUNTERWEIGHTS green on both; its `RecordTake.current(` needle belongs to the one absence below.
// · claims 4–6 are red on the parent by ONE ABSENCE — `RecordTakeNote`, the sentence's gate and
//   the yielding readout do not exist there (#486, booked once). Their no-modal, no-hot-read and
//   one-`Button {` needles are COUNTERWEIGHTS, green on both trees.
// Transcribed: patched tree, every verdict green (42 source-text checks, plus claim 1 driven per state);
// parent: 3 regressions (claim 2: one, claim 3: two) plus the one absence, which reds claims 4 and
// 6 at their first ANCHOR MISSING and turns claim 5's gate red. Stripper `SourceText.codeOnly`:
// PROPHYLAKTISCH (no source verdict flips raw vs. stripped on either tree) — kept because both
// files carry 30-line comment blocks that name these very types.
//
// NOT HERE — DEVICE PROBE, open. NEEDS-FOUNDER-VERIFY: Piece stage on a 375-pt phone, default
// text size, German: stopped with nothing armed — one row (Abspielen · Klick · Aufnehmen) plus
// one line "Schalte eine MIDI-Spur scharf …"; arm a track — the line goes, the bar is one row;
// Play — the meter joins the row, no position readout in portrait, the head counts the bar;
// rotate to landscape while playing — "Takt n · Schlag b" appears beside the meter; Record a
// take — "Aufnahme stoppen" stays on the row (it may wrap to two lines inside its button, never
// "…"); "Stopp" and "Aufnahme stoppen" now stand side by side — say whether that reads as two
// ways to one end (a founder look, docs/dev/FOUNDER_INBOX.md);
// the arrangement shows visibly more rows than before.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTransportBarIsOneRowTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let door = "Sources/Echoelmusic/Studio/RecordTakeControls.swift"
    private static let barMount = "ProjectPlayStopButton(source: \"workstation\")"
    private static let recordMount = "RecordTakeButton(playing: playing, startable: startable,"

    // MARK: 1 — END-TO-END: only a block the user can lift is drawn

    func testOnlyABlockTheUserCanLiftIsDrawnUnderTheRow() {
        let grid = 8
        XCTAssertEqual(RecordTake.shownReason(.armFirst, startable: true, gridSize: grid),
                       RecordTake.caption(.armFirst, gridSize: grid),
                       "nothing armed: the row says how to arm — the button alone cannot")
        XCTAssertEqual(RecordTake.shownReason(.gridFull, startable: true, gridSize: grid),
                       RecordTake.caption(.gridFull, gridSize: grid),
                       "a full grid is said BEFORE the performance, not after (R1 review MED-4)")
        let stale = RecordTake.shownReason(.foreignArm("Breath"), startable: true, gridSize: grid)
        XCTAssertTrue(stale?.contains("\"Breath\"") == true,
                      "a stale arm blocks Record by NAME (R1 review MED-5) — it must stay visible")
        for quiet in [RecordTake.State.ready, .recording, .stopFirst, .songCannotPlay] {
            XCTAssertNil(RecordTake.shownReason(quiet, startable: true, gridSize: grid), """
                `\(quiet)` draws a sentence under the row again. Ready and recording are said by \
                the button's word, "stop first" by the Stop beside it, "nothing to play" by the \
                bar's own line — a second sentence for one fact is the slop slice C removed.
                """)
        }
        for state in [RecordTake.State.armFirst, .foreignArm("Breath"), .gridFull, .ready] {
            XCTAssertNil(RecordTake.shownReason(state, startable: false, gridSize: grid),
                         "an unplayable piece is said ONCE, by the bar's own line — not again by the door")
        }
        // COUNTERWEIGHT: the sentence did not vanish, it is the hint.
        XCTAssertFalse(RecordTake.caption(.ready, gridSize: grid).isEmpty,
                       "the ready sentence still exists — it is the Record button's VoiceOver hint")
    }

    // MARK: 2 — Play, Click and Record are one row

    func testPlayClickAndRecordShareOneRow() throws {
        let row = try transportRow()
        let group = try member("controls {", in: row)
        guard let play = group.range(of: Self.barMount),
              let click = group.range(of: "WorkstationClickToggle()", range: play.upperBound..<group.endIndex),
              let record = group.range(of: Self.recordMount, range: click.upperBound..<group.endIndex) else {
            return XCTFail("""
                Play, Click and Record are not, in that order, inside ONE `controls { … }` group. \
                Record under the group is its own row again — the ≈ 60 pt slice C gave back to the \
                arrangement.
                """)
        }
        for (name, mount) in [("Play", play), ("Click", click), ("Record", record)] {
            let lead = group[group.startIndex..<mount.lowerBound]
            XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                           "\(name) is a direct, unconditional child of the row — never behind an `if`")
        }
        XCTAssertEqual(row.components(separatedBy: Self.recordMount).count - 1, 1, "one Record door on the bar")
    }

    // MARK: 3 — the button draws no caption of its own

    func testTheRecordButtonDrawsNoCaptionOfItsOwn() throws {
        let door = try code(Self.door)
        guard let start = door.range(of: "struct RecordTakeButton: View {"),
              let end = door.range(of: "struct TrackArmToggle: View {", range: start.upperBound..<door.endIndex) else {
            return XCTFail("ANCHOR MISSING: `RecordTakeButton` before `TrackArmToggle` (#454)")
        }
        let button = door[start.upperBound..<end.lowerBound]
        // The REGRESSION needle runs first, so on the parent it is red for its own named reason.
        let buttonOnly: Substring
        if let note = button.range(of: "struct RecordTakeNote: View {") {
            buttonOnly = button[button.startIndex..<note.lowerBound]
        } else {
            buttonOnly = button
        }
        XCTAssertFalse(buttonOnly.contains("Text(caption)"), """
            `RecordTakeButton` draws its caption again. In the Workstation it stands in ONE row \
            beside Play and Click; a caption under it is a second row. The caption is the \
            button's VoiceOver hint; a BLOCK is drawn once, under the row, by `RecordTakeNote`.
            """)
        XCTAssertFalse(buttonOnly.contains("droppedSentence("),
                       "the dropped-recordings warning is drawn by `RecordTakeNote`, not under the button")
        XCTAssertTrue(buttonOnly.contains(".accessibilityHint(caption)"),
                      "COUNTERWEIGHT: the sentence the row no longer draws is still spoken")
        XCTAssertTrue(buttonOnly.contains(".frame(minWidth: 44, minHeight: 44)"),
                      "COUNTERWEIGHT: the Record door keeps its 44 pt target in the row")
        XCTAssertFalse(buttonOnly.contains("minimumScaleFactor"), """
            COUNTERWEIGHT: the Record word shrinks to fit the row. Dynamic Type grows the text, \
            never shrinks it (the chrome's 11 pt floor, rule 12); a full row wraps the word inside \
            its 44 pt button instead — a shrunk word sits under the floor at the smaller steps.
            """)
        XCTAssertTrue(buttonOnly.contains("RecordTake.current("),
                      "the button reads the door's state through the ONE reading it shares with the note (#416)")
    }

    // MARK: 4 — the note is the one place a block is drawn, and it is cold

    func testTheNoteDrawsTheBlockOnceAndReadsNothingHot() throws {
        let door = try code(Self.door)
        let note = try member("struct RecordTakeNote: View {", in: door)
        XCTAssertTrue(note.contains("RecordTake.current("), "the note reads the same state as the button (#416)")
        XCTAssertTrue(note.contains("RecordTake.shownReason("), "the note draws only what claim 1 allows")
        XCTAssertTrue(note.contains("RecordTake.droppedSentence("), "a recording the grid had no room for is still said")
        for hot in ["currentTick", "masterLevel", "metronome", "latestBio", "TimelineView"] {
            XCTAssertFalse(note.contains(hot), """
                `RecordTakeNote` reads `\(hot)`. It sits in the transport bar under every menu of \
                the Piece stage; a hot read here is the 10.76.41/50 freeze.
                """)
        }
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(note.contains(modal), "no modal on the bar (the black-screen law): `\(modal)`")
        }
        XCTAssertEqual(door.components(separatedBy: "Button {").count - 1, 1,
                       "the door file builds ONE button — the note is a sentence, not a second control")

        let workstation = try code(Self.workstation)
        XCTAssertEqual(workstation.components(separatedBy: "RecordTakeNote(").count - 1, 1, "one note on the plate")
        let row = try transportRow()
        guard let group = row.range(of: "controls {"),
              let mount = row.range(of: "RecordTakeNote(playing: playing, startable: startable,") else {
            return XCTFail("ANCHOR MISSING: the transport row's group or its `RecordTakeNote` mount (#454)")
        }
        let groupBody = try member("controls {", in: row)
        XCTAssertFalse(groupBody.contains("RecordTakeNote("), "the note is under the row, not a member of it")
        XCTAssertLessThan(group.lowerBound, mount.lowerBound, "the note comes after the row")
    }

    // MARK: 5 — the bar's own sentence speaks only when no button can

    func testTheBarsSentenceStandsOnlyWhenNoButtonCanSayIt() throws {
        let row = try transportRow()
        let groupBody = try member("controls {", in: row)
        XCTAssertFalse(groupBody.contains("WorkstationSummary.transportCaption("),
                       "the sentence is not a member of the row (review of e1036b874, MED)")
        guard let gate = row.range(of: "if !playing && (running || !startable) {"),
              let caption = row.range(of: "WorkstationSummary.transportCaption(", range: gate.upperBound..<row.endIndex),
              let instrument = row.range(of: "ProjectTransport.instrumentRunningCaption", range: gate.upperBound..<row.endIndex) else {
            return XCTFail("""
                The bar's sentence is no longer behind `if !playing && (running || !startable) {`. \
                While the piece plays the head names its position and the button says Stop; a \
                stopped, playable piece is said by the word Play. Only "the instrument is what Stop \
                ends" and "nothing can start yet" earn a line under the row.
                """)
        }
        for (name, needle) in [("transport caption", caption), ("instrument caption", instrument)] {
            let lead = row[gate.upperBound..<needle.lowerBound]
            XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                           "the \(name) sits directly inside that gate")
        }
        XCTAssertTrue(row[gate.upperBound...].contains(".accessibilityHidden(true)"),
                      "COUNTERWEIGHT: the line stays hidden from VoiceOver — Play's own hint carries it")
    }

    // MARK: 6 — the position yields first; the controls never do

    func testThePositionReadoutYieldsBeforeAnyControl() throws {
        let row = try transportRow()
        let group = try member("controls {", in: row)
        XCTAssertTrue(group.contains("let meter = WorkstationMixMeter()"),
                      "the meter is built ONCE and placed in both candidates")
        let fits = try member("ViewThatFits(in: .horizontal) {", in: group)
        XCTAssertTrue(fits.contains("SongPositionReadout()"), "the readout lives only in the wide candidate")
        let tail = fits.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(tail.hasSuffix("meter"), """
            The `ViewThatFits`'s LAST candidate is no longer the meter alone. `ViewThatFits` falls \
            back to its last child when nothing fits, so a last child that carries the readout \
            would squeeze Play, Click and Record instead of dropping the readout.
            """)
        guard let open = group.range(of: "ViewThatFits(in: .horizontal) {") else {
            return XCTFail("ANCHOR MISSING: the readout's `ViewThatFits` (#454)")
        }
        let afterFits = group[open.upperBound...]
        XCTAssertTrue(afterFits.contains(".layoutPriority(-1)"), """
            The readout's group lost `.layoutPriority(-1)`. Without it the row splits leftover \
            width between the readout and Record, and "Aufnahme stoppen" is what gets squeezed.
            """)
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(row.contains(modal), "no modal on the transport (the black-screen law): `\(modal)`")
        }
    }

    // MARK: - helpers

    private struct AnchorMissing: Error, CustomStringConvertible {
        let description: String
    }

    /// `transportRow` up to `addTrackRow` — the two anchors every transport guard shares.
    private func transportRow() throws -> String {
        let workstation = try code(Self.workstation)
        guard let start = workstation.range(of: "private var transportRow: some View {"),
              let end = workstation.range(of: "private var addTrackRow: some View {",
                                          range: start.upperBound..<workstation.endIndex) else {
            throw AnchorMissing(description: "ANCHOR MISSING: `transportRow` before `addTrackRow` (#454)")
        }
        return String(workstation[start.upperBound..<end.lowerBound])
    }

    private func code(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            throw AnchorMissing(description: "ANCHOR MISSING: cannot read \(relativePath) (#454)")
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body after `anchor` (#408), string-literal aware so a `"{"` in a literal
    /// cannot close it early. The text is already comment-stripped by `SourceText.codeOnly`.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            throw AnchorMissing(description: "ANCHOR MISSING: `\(anchor)` (#454)")
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        throw AnchorMissing(description: "UNBALANCED: `\(anchor)` never closes (#454)")
    }
}

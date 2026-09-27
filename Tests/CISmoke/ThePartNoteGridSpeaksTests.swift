// ThePartNoteGridSpeaksTests.swift
// Echoel — modes census 2026-09-26, UX A: a VoiceOver user can step through the notes of a part.
//
// WHAT THIS PINS. The part note grid was TOUCH ONLY — its own hint said so. A VoiceOver user
// heard "Note grid: 12 notes, 0 selected" and had no way to pick one, so every control below
// (Delete, Transpose, Quantize, velocity) was unreachable without sight. The grid now carries
// two named actions, "Select next note" / "Select previous note", backed by a pure step.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.steppedPick`, pure): reading order is the DRAWN column
//    (`startStep`), then pitch low to high; forward runs from the LAST pick, backward from the FIRST; nothing picked starts
//    forward at the first note and backward at the last; both ends wrap; an empty list is nil,
//    never a trap.
// 2. SOURCE: the grid element carries both actions over the notes ON SCREEN, the hint no longer
//    says "Touch only", and `stepPick` writes the ONE selection owner (`picked = .single(id)`)
//    and announces the pick — no store write, no commit, no clock.
//
// Grading (§0, no Swift toolchain): claim 1 names `steppedPick`, which does not exist on the
// parent (`0c2e7b908`), so the file does not compile there — FORWARD guards, one absence (#486);
// the step algebra was transcribed into Python and driven on the cases below. Claim 2 transcribed
// against this tree: green; on the parent the hint reads "Touch only in this version".
// Review repair (of cf7414c72): the column order, `gridLabel` ("N of M notes shown" when the
// octave window hides some) and the hoisted `onScreen` — the column case and `gridLabel` are
// FORWARD (red on cf7414c72 by tick order / absence), transcribed and driven in Python.
// NOT covered: that VoiceOver speaks the actions and the announcement well — a device probe.
// NEEDS-FOUNDER-VERIFY: VoiceOver on, Workstation → a MIDI part → Edit notes → focus the grid,
// swipe up/down to "Select next note", double-tap: VoiceOver says e.g. "C4 at step 1, selected";
// repeat to walk the notes left to right; Delete below removes the one it named. Listen that a
// sharp is said as "sharp" (the name is `C#4`) — if VoiceOver says "pound", report it.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePartNoteGridSpeaksTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — the step, pure

    func testTheStepWalksTheNotesInReadingOrderAndWraps() {
        let low = Note(pitch: 60, startStep: 0)
        let high = Note(pitch: 67, startStep: 0)     // same start, higher pitch: after `low`
        let later = Note(pitch: 55, startStep: 4)    // later start wins over lower pitch
        let notes = [later, high, low]               // deliberately NOT in reading order

        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [], in: notes, by: 1), low.id,
                       "nothing picked: forward starts at the first note")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [], in: notes, by: -1), later.id,
                       "nothing picked: backward starts at the last note")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [low.id], in: notes, by: 1), high.id)
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [high.id], in: notes, by: 1), later.id)
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [later.id], in: notes, by: 1), low.id, "forward wraps")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [low.id], in: notes, by: -1), later.id, "backward wraps")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [low.id, high.id], in: notes, by: 1), later.id,
                       "forward runs from the LAST pick")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [high.id, later.id], in: notes, by: -1), low.id,
                       "backward runs from the FIRST pick")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [UUID()], in: notes, by: 1), low.id,
                       "a pick that is not on screen counts as nothing picked")
        XCTAssertNil(ClipNoteEdit.steppedPick(from: [], in: [], by: 1), "no notes: nil, never a trap")
        XCTAssertNil(ClipNoteEdit.steppedPick(from: [low.id], in: [], by: -1))

        // Review of cf7414c72 (LOW): the order is the DRAWN column. Two unquantized notes that
        // round into one column go low to high, as they sit — not by their exact tick.
        var earlyHigh = Note(pitch: 72, startStep: 2)
        earlyHigh.startTick -= Note.ticksPerStep / 4            // still draws in column 2
        var lateLow = Note(pitch: 48, startStep: 2)
        lateLow.startTick += Note.ticksPerStep / 4              // still draws in column 2
        XCTAssertEqual(earlyHigh.startStep, lateLow.startStep, "premise: one drawn column")
        XCTAssertLessThan(earlyHigh.startTick, lateLow.startTick, "premise: the high note is earlier by tick")
        XCTAssertEqual(ClipNoteEdit.steppedPick(from: [], in: [earlyHigh, lateLow], by: 1), lateLow.id,
                       "in one drawn column the LOW note is read first, as on screen")
    }

    func testTheLabelCountsWhatTheStepsWalk() {
        XCTAssertEqual(ClipNoteEdit.gridLabel(shown: 3, total: 3, picked: 1), "Note grid: 3 notes, 1 selected")
        XCTAssertEqual(ClipNoteEdit.gridLabel(shown: 1, total: 1, picked: 0), "Note grid: 1 note, 0 selected")
        XCTAssertEqual(ClipNoteEdit.gridLabel(shown: 8, total: 12, picked: 0), "Note grid: 8 of 12 notes shown, 0 selected",
                       "notes outside the drawn rows are named, so a listener who wraps early knows why")
        XCTAssertEqual(ClipNoteEdit.gridLabel(shown: 0, total: 1, picked: 0), "Note grid: 0 of 1 note shown, 0 selected",
                       "one note is singular in the windowed form too (review of e1036b874, LOW)")
    }

    // MARK: 2 — the grid offers it, and it only selects

    func testTheGridOffersBothStepsAndOnlySelects() throws {
        let code = try source(Self.editor)
        XCTAssertFalse(code.contains("Touch only"), "the hint still tells a VoiceOver user the grid is touch only")
        XCTAssertTrue(code.contains(".accessibilityAction(named: \"Select next note\") {"))
        XCTAssertTrue(code.contains(".accessibilityAction(named: \"Select previous note\") {"))
        XCTAssertTrue(code.contains("let onScreen = visible.filter { range.contains($0.pitch) }"),
                      "the notes on screen are the rows the grid draws")
        XCTAssertTrue(code.contains("stepPick(1, among: onScreen)") && code.contains("stepPick(-1, among: onScreen)"),
                      "both actions step over the notes ON SCREEN")
        XCTAssertTrue(code.contains("ClipNoteEdit.gridLabel(shown: onScreen.count, total: visible.count,"),
                      "the label counts the same notes the steps walk (review of cf7414c72, LOW)")
        XCTAssertFalse(code.contains("among: visible)"), "stepping over every note walks rows the grid does not draw")

        guard let head = code.range(of: "private func stepPick(_ delta: Int, among onScreen: [Note]) {"),
              let next = code.range(of: "private func ", range: head.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `stepPick` (#454)")
        }
        let step = String(code[head.upperBound..<next.lowerBound])
        XCTAssertTrue(step.contains("ClipNoteEdit.steppedPick(from: picked.ids, in: onScreen, by: delta)"))
        XCTAssertTrue(step.contains("picked = .single(id)"), "the one selection owner, as a tap writes it")
        XCTAssertTrue(step.contains("AccessibilityNotification.Announcement("),
                      "VoiceOver does not re-read a changed label — the pick is announced")
        for banned in ["setClipNotes", "timeline.", "clipStore.", "currentTick"] {
            XCTAssertFalse(step.contains(banned), "`stepPick` touches `\(banned)` — stepping selects, it never edits or reads a clock")
        }
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

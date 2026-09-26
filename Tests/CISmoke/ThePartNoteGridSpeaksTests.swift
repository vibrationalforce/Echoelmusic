// ThePartNoteGridSpeaksTests.swift
// Echoel — modes census 2026-09-26, UX A: a VoiceOver user can step through the notes of a part.
//
// WHAT THIS PINS. The part note grid was TOUCH ONLY — its own hint said so. A VoiceOver user
// heard "Note grid: 12 notes, 0 selected" and had no way to pick one, so every control below
// (Delete, Transpose, Quantize, velocity) was unreachable without sight. The grid now carries
// two named actions, "Select next note" / "Select previous note", backed by a pure step.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.steppedPick`, pure): reading order is start, then pitch
//    low to high; forward runs from the LAST pick, backward from the FIRST; nothing picked starts
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
// NOT covered: that VoiceOver speaks the actions and the announcement well — a device probe.
// NEEDS-FOUNDER-VERIFY: VoiceOver on, Workstation → a MIDI part → Edit notes → focus the grid,
// swipe up/down to "Select next note", double-tap: VoiceOver says e.g. "C4 at step 1, selected";
// repeat to walk the notes left to right; Delete below removes the one it named.

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
    }

    // MARK: 2 — the grid offers it, and it only selects

    func testTheGridOffersBothStepsAndOnlySelects() throws {
        let code = try source(Self.editor)
        XCTAssertFalse(code.contains("Touch only"), "the hint still tells a VoiceOver user the grid is touch only")
        XCTAssertTrue(code.contains(".accessibilityAction(named: \"Select next note\") {"))
        XCTAssertTrue(code.contains(".accessibilityAction(named: \"Select previous note\") {"))
        XCTAssertEqual(code.components(separatedBy: "among: visible.filter { range.contains($0.pitch) })").count - 1, 2,
                       "both actions step over the notes ON SCREEN — the rows the grid draws")

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

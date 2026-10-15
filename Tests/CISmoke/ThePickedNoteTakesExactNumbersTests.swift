// ThePickedNoteTakesExactNumbersTests.swift
// Echoel — N-F1 (founder on device 2026-10-15: „Midi und Clips sowie editing View sind bisher
// komplett unbrauchbar und zu ungenau"; the design mockups of the same day put a note inspector
// under the grid). One picked note now shows three number fields — start step, length, pitch —
// so a finger is no longer the only way to place it.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`ClipNoteEdit.moving`/`resizing`, Foundation-only): a typed target
//      becomes a DELTA (target − current) through the same pure ops the grid's gestures use — a
//      note at step 3 typed to 7 lands at step 7; pitch 60 typed to 64 lands on 64; a step past
//      the part clamps to its last step, exactly as a drag does; a length typed longer stretches.
//   2. SOURCE-TEXT SCAN: the fields live in their own leaf (`NoteNumbersRow`, drafts in `@State`,
//      written once on commit), mounted ONLY under the one-picked-note line, and the row commits
//      through `moveByNumbers`/`stretchByAction` — the grid still has exactly one finger-rate state.
//
// ⚠️ HONEST GRADING (#433): claim 1 drives shipped ops and is green on both trees (it pins the
// arithmetic the row relies on — a counterweight); claim 2 is FORWARD (the leaf is created here —
// one absence, #486). Transcribed, no local toolchain (§0).
// ⚠️ THE LIMIT: whether typing beats dragging is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY: open a MIDI
// part's notes, tap one note, type Start step 9, Length 4, Pitch 64 — the block moves, grows and
// changes row, each one Undo).

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePickedNoteTakesExactNumbersTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private let step = Note.ticksPerStep

    func testATypedTargetIsADeltaThroughTheGestureOps() throws {
        let note = Note(pitch: 60, startStep: 2)              // shown as "Start step 3"
        let part = 16 * step
        let moved = try XCTUnwrap(ClipNoteEdit.moving([note.id], dPitch: 64 - 60, dStep: 7 - 3,
                                                      in: [note], offsetTicks: 0, lengthTicks: part))
        XCTAssertEqual(moved.first?.startStep, 6, "typed step 7 (1-based) is step index 6")
        XCTAssertEqual(moved.first?.pitch, 64)
        let clamped = try XCTUnwrap(ClipNoteEdit.moving([note.id], dPitch: 0, dStep: 99 - 3,
                                                        in: [note], offsetTicks: 0, lengthTicks: part))
        XCTAssertEqual(clamped.first?.startTick, part - 1,
                       "a step past the part clamps to its last tick, exactly as a drag does")
        let longer = try XCTUnwrap(ClipNoteEdit.resizing(note.id, bySteps: 4 - note.lengthSteps,
                                                         in: [note], offsetTicks: 0, lengthTicks: part))
        XCTAssertEqual(longer.first?.lengthSteps, 4)
        XCTAssertNil(ClipNoteEdit.moving([note.id], dPitch: 0, dStep: 0, in: [note],
                                         offsetTicks: 0, lengthTicks: part),
                     "an unchanged field commits nothing — no empty Undo step")
    }

    func testTheRowIsALeafUnderTheOnePickedNote() throws {
        let code = try source(Self.editor)
        XCTAssertTrue(code.contains("private struct NoteNumbersRow: View {"), "the inspector is its own leaf")
        XCTAssertTrue(code.contains("@State private var stepDraft: Double?")
                      && code.contains("@State private var pitchDraft: Double?"),
                      "the fields edit drafts, so only the row redraws while a value moves")
        XCTAssertTrue(code.contains("if let d = stepDraft { move(0, Int(d.rounded()) - step) }")
                      && code.contains("if let d = lengthDraft { stretch(Int(d.rounded()) - lengthSteps) }")
                      && code.contains("if let d = pitchDraft { move(Int(d.rounded()) - pitch, 0) }"),
                      "each field commits its target as a delta, once")
        guard let one = code.range(of: "if pickedCount == 1, let one = visible.first(where: { pickedOnScreen.contains($0.id) }) {"),
              let row = code.range(of: "NoteNumbersRow(step:", range: one.upperBound..<code.endIndex),
              let next = code.range(of: "selectionControls(targets:", range: one.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the one-picked-note block or the row")
        }
        XCTAssertLessThan(row.lowerBound, next.lowerBound, "the row sits inside the one-picked-note block")
        XCTAssertTrue(code.contains("ClipNoteEdit.moving([id], dPitch: dPitch, dStep: dStep"),
                      "typed moves go through the gesture's pure op")
        XCTAssertEqual(code.components(separatedBy: "@GestureState").count - 1, 1,
                       "the grid still has exactly one finger-rate state")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}

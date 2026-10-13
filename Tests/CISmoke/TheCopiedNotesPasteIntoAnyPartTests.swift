//
//  TheCopiedNotesPasteIntoAnyPartTests.swift
//  Production level N4b (founder 2026-10-13: „… brauchbares Pianoroll …"). Duplicate copied notes
//  only to right after themselves, inside the same part; a phrase could not reach another part
//  without being drawn again note by note. Copy holds the picked notes; Paste puts them into the
//  open part — after the selection, or at the part's top — in ONE commit through the one writer.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `ClipNoteEdit.copying`, `.pasting` and `.pasteStep` are
//    shipped and pure. Claim 1: Copy keeps the picked notes inside the part's window, their starts
//    made relative to the first, in start order; nothing inside the window → nil (Copy greys out).
//    Claim 2: Paste places the clipboard at a step of the window with NEW ids, appended; a copy
//    past the part's end is left out, and nothing fitting or an empty clipboard → nil. The
//    COUNTERWEIGHT: the notes already in the part are untouched. Claim 3: the paste step is right
//    after the selection (rounded up to a whole step, measured from the window's start), or 0.
//  · SOURCE-TEXT SCAN (claim 4) — both buttons ask the same ops as their actions; Paste commits
//    through `setClipNotes` (the one-writer count lives in
//    `TheSelectedPartsNotesAreEditedThroughOneWriterTests`, moved to 16 in this commit, #416);
//    the clipboard is memory only — no defaults, no system pasteboard.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — the three ops
//  and `NoteClipboard` are created by this commit — so no assertion has a verdict on the parent
//  (ONE absence, #486). Claims 1–3 are forward guards transcribed by reading the three ops; claim
//  4's needles were grepped against the worktree.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCopiedNotesPasteIntoAnyPartTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let step = Note.ticksPerStep
    private static let partLength = 16 * Note.ticksPerStep

    private static func note(_ pitch: Int, at stepIndex: Int, steps: Int = 1) -> Note {
        Note(pitch: pitch, startTick: stepIndex * step, lengthTicks: steps * step)
    }

    // MARK: 1 — Copy

    func testCopyHoldsThePickedNotesFromTheirFirstStart() throws {
        let b = Self.note(64, at: 5, steps: 2), a = Self.note(60, at: 2), outside = Self.note(70, at: 20)
        let held = try XCTUnwrap(ClipNoteEdit.copying([a.id, b.id, outside.id], in: [b, a, outside],
                                                      offsetTicks: 0, lengthTicks: Self.partLength))
        XCTAssertEqual(held.map(\.pitch), [60, 64], "in start order; the note past the part is not copied")
        XCTAssertEqual(held.map(\.startTick), [0, 3 * Self.step], "starts relative to the first")
        XCTAssertEqual(held.map(\.lengthTicks), [Self.step, 2 * Self.step])
        XCTAssertNil(ClipNoteEdit.copying([outside.id], in: [a, outside], offsetTicks: 0,
                                          lengthTicks: Self.partLength),
                     "nothing inside the part → Copy greys out")
        XCTAssertNil(ClipNoteEdit.copying([], in: [a], offsetTicks: 0, lengthTicks: Self.partLength))
    }

    // MARK: 2 — Paste

    func testPastePlacesNewCopiesAndKeepsWhatFits() throws {
        let held = [Self.note(60, at: 0), Self.note(64, at: 3)]
        let existing = Self.note(55, at: 1)
        let pasted = try XCTUnwrap(ClipNoteEdit.pasting(held, atStep: 14, into: [existing],
                                                        offsetTicks: 0, lengthTicks: Self.partLength))
        XCTAssertEqual(pasted.notes.first, existing, "the part's own notes are untouched")
        let copies = pasted.notes.filter { pasted.ids.contains($0.id) }
        XCTAssertEqual(copies.map(\.pitch), [60], "the copy that would start past the part's end is left out")
        XCTAssertEqual(copies.map(\.startTick), [14 * Self.step])
        XCTAssertFalse(held.map(\.id).contains(copies[0].id), "a pasted note gets a new id")
        XCTAssertEqual(pasted.notes.count, 2)

        let shifted = try XCTUnwrap(ClipNoteEdit.pasting(held, atStep: 0, into: [], offsetTicks: 2 * Self.step,
                                                         lengthTicks: 8 * Self.step))
        XCTAssertEqual(shifted.notes.map(\.startTick), [2 * Self.step, 5 * Self.step],
                       "step 0 is the window's first step, not the clip's")

        XCTAssertNil(ClipNoteEdit.pasting(held, atStep: 16, into: [], offsetTicks: 0, lengthTicks: Self.partLength),
                     "nothing fits → Paste greys out")
        XCTAssertNil(ClipNoteEdit.pasting([], atStep: 0, into: [], offsetTicks: 0, lengthTicks: Self.partLength))
    }

    // MARK: 3 — where Paste lands

    func testPasteLandsRightAfterTheSelectionOrAtTheTop() {
        let a = Self.note(60, at: 5, steps: 2)
        XCTAssertEqual(ClipNoteEdit.pasteStep(after: [a.id], in: [a], offsetTicks: 0), 7)
        let ragged = Note(pitch: 62, startTick: 0, lengthTicks: Self.step + 10)
        XCTAssertEqual(ClipNoteEdit.pasteStep(after: [ragged.id], in: [ragged], offsetTicks: 0), 2,
                       "rounded up to a whole step, so the paste never overlaps the selection")
        let late = Self.note(60, at: 4)
        XCTAssertEqual(ClipNoteEdit.pasteStep(after: [late.id], in: [late], offsetTicks: 2 * Self.step), 3,
                       "measured from the window's start")
        XCTAssertEqual(ClipNoteEdit.pasteStep(after: [], in: [a], offsetTicks: 0), 0, "nothing picked → the top")
    }

    // MARK: 4 — the editor's buttons

    func testTheEditorCopiesAndPastesThroughTheOneWriter() throws {
        let code = SourceText.codeOnly(try source(Self.editorPath))
        XCTAssertTrue(code.contains("button(\"Copy\", \"doc.on.doc\""))
        XCTAssertTrue(code.contains("button(\"Paste\", \"doc.on.clipboard\""))
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.copying(").count - 1, 2,
                       "Copy's enablement and its action ask the same op")
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.pasting(").count - 1, 2,
                       "Paste's enablement and its action ask the same op")
        guard let action = code.range(of: "private func paste(") else {
            return XCTFail("ANCHOR MISSING: the Paste action")
        }
        XCTAssertTrue(code[action.upperBound...].prefix(800).contains("timeline.setClipNotes("),
                      "Paste commits through the one writer")
        guard let holder = code.range(of: "final class NoteClipboard {") else {
            return XCTFail("ANCHOR MISSING: the clipboard")
        }
        let body = String(code[holder.upperBound...].prefix(300))
        for banned in ["UserDefaults", "UIPasteboard", "Codable"] {
            XCTAssertFalse(body.contains(banned), "the clipboard is memory for this run only: \(banned)")
        }
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}

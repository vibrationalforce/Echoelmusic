//
//  TheGridDrawsNewNotesTests.swift
//  Production level N3, first step (founder 2026-10-13: „… brauchbares Pianoroll …"). A new note was
//  always one sixteenth long and started wherever the finger landed, whatever grid the editor showed
//  — so writing a line of quarter notes took a tap and a stretch per note. The chosen grid now draws:
//  a tap starts the note at its cell and makes it one cell long, on the same grid OF THE PART that
//  Quantize uses.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `ClipNoteEdit` is shipped and pure. Claim 1: the cell
//    start of a tap on every grid, and the pass-through of a grid below 1 and of a negative step.
//    Claim 2: `adding` makes the note the asked length, cuts it at the part's end, never shorter
//    than one step, and — the COUNTERWEIGHT — with no length still makes the one-step note every
//    older caller expects.
//  · SOURCE-TEXT SCAN (claim 3) — `PartNoteEditor` is a `View`: BOTH of its adds pass the chosen
//    grid as the length (#431: the parameter has a default, so a forgetful add would compile and
//    silently draw sixteenths), and the tap starts at the grid cell.
//  · DEVICE PROBE, OPEN — that it reads naturally under a finger: a glance, not a test.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — `gridCellStart`
//  and the `lengthSteps:` label are created by this commit — so no assertion has a verdict on the
//  parent (ONE absence, #486). Claims 1–2 are forward guards transcribed by reading
//  `gridCellStart` and `adding`; claim 3's needles were grepped against the worktree.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGridDrawsNewNotesTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let step = Note.ticksPerStep

    // MARK: 1 — a tap lands at its cell's start

    func testATapStartsAtItsGridCell() {
        XCTAssertEqual(ClipNoteEdit.gridCellStart(7, gridSteps: 1), 7, "sixteenths: where the finger is")
        XCTAssertEqual(ClipNoteEdit.gridCellStart(5, gridSteps: 2), 4)
        XCTAssertEqual(ClipNoteEdit.gridCellStart(7, gridSteps: 4), 4)
        XCTAssertEqual(ClipNoteEdit.gridCellStart(8, gridSteps: 4), 8, "a cell's own start stays put")
        XCTAssertEqual(ClipNoteEdit.gridCellStart(3, gridSteps: 0), 3, "no grid, no snap")
        XCTAssertEqual(ClipNoteEdit.gridCellStart(-1, gridSteps: 4), -1, "a negative step is left for `adding` to refuse")
    }

    // MARK: 2 — the new note is one cell long, inside the part

    func testANewNoteIsOneCellLongAndStaysInThePart() throws {
        let offset = 2 * Self.step
        let quarter = try XCTUnwrap(ClipNoteEdit.adding(pitch: 60, step: 4, to: [], offsetTicks: offset,
                                                        lengthTicks: 16 * Self.step, lengthSteps: 4))
        let note = try XCTUnwrap(quarter.notes.first)
        XCTAssertEqual(note.startTick, offset + 4 * Self.step)
        XCTAssertEqual(note.lengthTicks, 4 * Self.step, "a quarter grid draws a quarter note")

        let cut = try XCTUnwrap(ClipNoteEdit.adding(pitch: 60, step: 4, to: [], offsetTicks: 0,
                                                    lengthTicks: 6 * Self.step, lengthSteps: 4))
        XCTAssertEqual(cut.notes.first?.lengthTicks, 2 * Self.step, "cut at the part's end")

        let floor = try XCTUnwrap(ClipNoteEdit.adding(pitch: 60, step: 0, to: [], offsetTicks: 0,
                                                      lengthTicks: 16 * Self.step, lengthSteps: 0))
        XCTAssertEqual(floor.notes.first?.lengthTicks, Self.step, "never shorter than one step")

        // COUNTERWEIGHT: an older caller that names no length still gets the one-step note.
        let plain = try XCTUnwrap(ClipNoteEdit.adding(pitch: 60, step: 0, to: [], offsetTicks: 0,
                                                      lengthTicks: 16 * Self.step))
        XCTAssertEqual(plain.notes.first?.lengthTicks, Self.step)
    }

    // MARK: 3 — both of the editor's adds draw on the chosen grid

    func testBothAddsPassTheChosenGrid() throws {
        let code = SourceText.codeOnly(try source(Self.editorPath))
        let adds = code.components(separatedBy: "ClipNoteEdit.adding(").count - 1
        XCTAssertEqual(adds, 2, "premise: the tap and the VoiceOver add")
        XCTAssertEqual(code.components(separatedBy: "lengthSteps: quantizeGrid.steps").count - 1, adds,
                       "every add draws one cell of the chosen grid — a forgetful add would compile and draw sixteenths")
        XCTAssertTrue(code.contains("step: ClipNoteEdit.gridCellStart(step, gridSteps: quantizeGrid.steps)"),
                      "the tap starts the note at its grid cell")
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

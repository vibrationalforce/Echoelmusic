//
//  TheLegatoStretchesToTheNextNoteTests.swift
//  Production level N4, first step (founder 2026-10-13: „… brauchbares Pianoroll …"). Joining a line
//  of notes so each one sounds until the next took one stretch drag per note. Legato does it for the
//  selection (or the whole part) in ONE commit through the one writer.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `ClipNoteEdit.legato` is shipped and pure. Claim 1: each
//    picked note ends where the next note starts, whatever its pitch; a chord partner starting at
//    the same tick is not "the next note"; the last note runs to the part's end. Claim 2, the
//    COUNTERWEIGHTS: an unpicked note keeps its length, a note outside the part's window is left
//    alone, and a selection already legato returns nil so the button greys out.
//  · SOURCE-TEXT SCAN (claim 3) — the editor offers it as a button whose enablement and commit ask
//    the same op, and the commit goes through `setClipNotes` (the one-writer count lives in
//    `TheSelectedPartsNotesAreEditedThroughOneWriterTests`, moved to 15 in this commit, #416).
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — `legato` is
//  created by this commit — so no assertion has a verdict on the parent (ONE absence, #486).
//  Claims 1–2 are forward guards transcribed by reading `legato`; claim 3's needles were grepped
//  against the worktree.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLegatoStretchesToTheNextNoteTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let step = Note.ticksPerStep

    private static func note(_ pitch: Int, at stepIndex: Int, steps: Int = 1) -> Note {
        Note(pitch: pitch, startTick: stepIndex * step, lengthTicks: steps * step)
    }

    // MARK: 1 — each note sounds until the next one starts

    func testEachPickedNoteEndsWhereTheNextStarts() throws {
        let a = Self.note(60, at: 0), chord = Self.note(64, at: 0), b = Self.note(67, at: 4), c = Self.note(62, at: 10)
        let notes = [a, chord, b, c]
        let joined = try XCTUnwrap(ClipNoteEdit.legato([a.id, b.id, c.id], in: notes, offsetTicks: 0,
                                                       lengthTicks: 16 * Self.step))
        func length(_ n: Note) -> Int? { joined.first(where: { $0.id == n.id })?.lengthTicks }
        XCTAssertEqual(length(a), 4 * Self.step, "to the next start — the chord partner at 0 is not next")
        XCTAssertEqual(length(b), 6 * Self.step, "any pitch counts as the next note")
        XCTAssertEqual(length(c), 6 * Self.step, "the last note runs to the part's end")
        XCTAssertEqual(joined.map(\.startTick), notes.map(\.startTick), "starts never move")
        XCTAssertEqual(joined.map(\.pitch), notes.map(\.pitch), "pitches never move")
    }

    // MARK: 2 — counterweights

    func testOnlyPickedNotesInsideThePartChange() throws {
        let a = Self.note(60, at: 0), b = Self.note(62, at: 4), outside = Self.note(65, at: 20)
        let notes = [a, b, outside]
        let joined = try XCTUnwrap(ClipNoteEdit.legato([a.id, outside.id], in: notes, offsetTicks: 0,
                                                       lengthTicks: 16 * Self.step))
        XCTAssertEqual(joined.first(where: { $0.id == b.id })?.lengthTicks, Self.step, "an unpicked note keeps its length")
        XCTAssertEqual(joined.first(where: { $0.id == outside.id })?.lengthTicks, Self.step,
                       "a note past the part's window is not stretched")
        XCTAssertNil(ClipNoteEdit.legato([a.id], in: joined, offsetTicks: 0, lengthTicks: 16 * Self.step),
                     "already legato: nothing to commit, so the button greys out")
        XCTAssertNil(ClipNoteEdit.legato([], in: notes, offsetTicks: 0, lengthTicks: 16 * Self.step))
    }

    // MARK: 3 — the editor's button

    func testTheEditorOffersLegatoAsOneCommit() throws {
        let code = SourceText.codeOnly(try source(Self.editorPath))
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.legato(").count - 1, 2,
                       "the button's enablement and its commit ask the same op")
        XCTAssertTrue(code.contains("button(\"Legato\", \"arrow.right.to.line\""))
        guard let action = code.range(of: "private func legato(") else {
            return XCTFail("ANCHOR MISSING: the Legato action")
        }
        XCTAssertTrue(code[action.upperBound...].prefix(500).contains("timeline.setClipNotes("),
                      "Legato commits through the one writer")
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

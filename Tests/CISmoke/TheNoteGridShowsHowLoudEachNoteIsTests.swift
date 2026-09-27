// TheNoteGridShowsHowLoudEachNoteIsTests.swift
// Echoel — modes census 2026-09-26, design slice 12: the note grid shows each note's velocity.
//
// WHAT THIS PINS. The grid drew every note in the same full accent, so a part's dynamics were
// visible only through the velocity row of a selection. A note's fill now carries its velocity
// as opacity: a loud note is full colour, a quiet one paler — and never invisible.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.noteOpacity`, pure): full velocity draws at 1, zero at
//    `quietestNoteOpacity` (> 0, so every note stays visible and pickable), linear and strictly
//    rising between, clamped outside 0…1, and a NaN draws at the floor — never as no note.
// 2. SOURCE: the grid's note fill asks that function with the note's own velocity on the
//    unpicked branch only — a picked note keeps the full text colour (and its ring, which
//    `APickedNoteChangesShapeNotOnlyColourTests` pins), so a pick never fades with a quiet note.
//
// Grading (§0, no Swift toolchain): `noteOpacity` and `quietestNoteOpacity` do not exist on the
// parent (`c51b1645a`), so this file does not compile there — every claim is a FORWARD guard,
// one absence (#486). Claim 1 transcribed into Python over 0…1 in 1/1000 steps plus the edges;
// claim 2 transcribed against this tree, with mutants (the opacity on the picked branch, a
// constant opacity, the velocity of another note): each red.
// NOT covered: whether a 35 % accent reads on the grid's surface on glass — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part → Notes → select a note, set Velocity to 0.1
// → deselect: the note is visibly paler than its neighbours but still clear; set it to 1 → it
// is full colour again; a picked note is always the bright ringed block.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteGridShowsHowLoudEachNoteIsTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — velocity to opacity, pure

    func testALoudNoteIsFullAndAQuietOneIsPaleButVisible() {
        let floor = ClipNoteEdit.quietestNoteOpacity
        XCTAssertGreaterThan(floor, 0, "a velocity-0 note is still drawn — a note you cannot see you cannot pick")
        XCTAssertLessThan(floor, 1, "and quieter than a full one, or velocity would not show")
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: 1), 1, accuracy: 1e-12)
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: 0), floor, accuracy: 1e-12)
        var previous = -1.0
        for step in 0...1_000 {
            let velocity = Float(step) / 1_000
            let opacity = ClipNoteEdit.noteOpacity(velocity: velocity)
            XCTAssertEqual(opacity, floor + (1 - floor) * Double(velocity), accuracy: 1e-9,
                           "velocity \(velocity) draws on the straight line from the floor to full")
            XCTAssertGreaterThan(opacity, previous, "a louder note is never drawn paler")
            previous = opacity
        }
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: 7), 1, accuracy: 1e-12, "past full is full")
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: -3), floor, accuracy: 1e-12, "below silent is the floor")
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: .nan), floor, accuracy: 1e-12, "a NaN is drawn, at the floor")
        XCTAssertEqual(ClipNoteEdit.noteOpacity(velocity: .infinity), 1, accuracy: 1e-12)
    }

    // MARK: 2 — the grid asks it, for unpicked notes only

    func testTheUnpickedFillCarriesTheNotesOwnVelocity() throws {
        let code = try source(Self.editor)
        guard let head = code.range(of: "for note in shown where range.contains(note.pitch) {"),
              let tail = code.range(of: "if let box {", range: head.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the note loop of `PartNoteCanvas` (#454)")
        }
        let loop = String(code[head.upperBound..<tail.lowerBound])
        XCTAssertTrue(loop.contains("context.fill(shape, with: .color(lit.contains(note.id) ? EchoelTheme.text"),
                      "a picked note keeps the full text colour")
        XCTAssertTrue(loop.contains(": EchoelTheme.accent.opacity(ClipNoteEdit.noteOpacity(velocity: note.velocity))))"),
                      "an unpicked note's fill is the accent at ITS OWN velocity's opacity")
        XCTAssertEqual(loop.components(separatedBy: "noteOpacity(").count - 1, 1,
                       "the opacity is asked once, on the unpicked branch — never for the pick or the ring")
        XCTAssertFalse(loop.contains("EchoelTheme.text.opacity("), "the picked colour never fades")
    }

    // MARK: helpers

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

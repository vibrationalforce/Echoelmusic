// TheNoteGridShowsHowLoudEachNoteIsTests.swift
// Echoel — modes census 2026-09-26, design slice 12: the note grid shows each note's velocity.
//
// WHAT THIS PINS. The grid drew every note in the same full accent, so a part's dynamics were
// visible only through the velocity row of a selection. An unpicked note's fill now carries its
// velocity as depth of colour: an OPAQUE mix of the grid's surface and the accent — loud is full
// accent, quiet is darker, and nothing under a note ever shows through it.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.noteShade`, pure): full velocity mixes 1 (all accent),
//    zero mixes `quietestNoteShade`, which stays at or above the share that keeps 3:1 against
//    the surface (0.5 → 3.04:1 computed in OKLab; the floor is higher), linear and strictly
//    rising between, clamped outside 0…1, and a NaN draws at the floor — never as no note.
// 2. SOURCE: the grid's note fill asks that function with the note's own velocity, on the
//    unpicked branch only, through `surface.mix(with: accent, by:)` — never a translucent
//    accent; a picked note keeps the full text colour (and its ring, pinned by
//    `APickedNoteChangesShapeNotOnlyColourTests`). The canvas sets no context opacity or blend
//    mode that would fade every note, and fills each note once.
//
// Grading (§0, no Swift toolchain): `noteShade` and `quietestNoteShade` do not exist on the
// parent (`3bab7f277`, which still carries the translucent `noteOpacity` cut), so this file does
// not compile there — every claim is a FORWARD guard, one absence (#486). Claim 1 transcribed
// into Python over 0…1 in 1/1000 steps plus the edges; claim 2 transcribed against this tree,
// with mutants (the shade on the picked branch, a constant shade, another note's velocity, the
// translucent `accent.opacity(` form of aad532d33, `context.opacity =` before the loop, a second
// opaque fill after the ring): each red.
// Review of aad532d33 (MED-1/2): the translucent first cut let a picked note's ring show through
// a quiet note drawn over it, and sat at 2.24:1 — the reason for the mix and for the floor.
// NOT covered: how the darker notes read on glass and over the shaded out-of-key rows — a
// device look (the contrast numbers are computed from the theme values, not measured).
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part → Notes → select a note, set Velocity to 0.1
// → deselect: the note is visibly darker than its neighbours but still clear; set it to 1 → it
// is full colour again; a picked note is always the bright ringed block; a quiet note dragged
// over a picked one shows no ring through it.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteGridShowsHowLoudEachNoteIsTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — velocity to shade, pure

    func testALoudNoteIsFullAndAQuietOneIsDarkerButLegible() {
        let floor = ClipNoteEdit.quietestNoteShade
        XCTAssertGreaterThanOrEqual(floor, 0.5,
                                    "at 0.50 the quietest note sits at 3.04:1 against the surface — the floor may not go lower")
        XCTAssertLessThan(floor, 1, "and quieter than a full one, or velocity would not show")
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: 1), 1, accuracy: 1e-12)
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: 0), floor, accuracy: 1e-12)
        var previous = -1.0
        for step in 0...1_000 {
            let velocity = Float(step) / 1_000
            let shade = ClipNoteEdit.noteShade(velocity: velocity)
            XCTAssertEqual(shade, floor + (1 - floor) * Double(velocity), accuracy: 1e-9,
                           "velocity \(velocity) draws on the straight line from the floor to full")
            XCTAssertGreaterThan(shade, previous, "a louder note is never drawn darker")
            previous = shade
        }
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: 7), 1, accuracy: 1e-12, "past full is full")
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: -3), floor, accuracy: 1e-12, "below silent is the floor")
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: .nan), floor, accuracy: 1e-12, "a NaN is drawn, at the floor")
        XCTAssertEqual(ClipNoteEdit.noteShade(velocity: .infinity), 1, accuracy: 1e-12)
    }

    // MARK: 2 — the grid asks it, opaque, for unpicked notes only

    func testTheUnpickedFillIsAnOpaqueMixAtTheNotesOwnVelocity() throws {
        let code = try source(Self.editor)
        guard let canvas = code.range(of: "private struct PartNoteCanvas: View {"),
              let head = code.range(of: "for note in shown where range.contains(note.pitch) {",
                                    range: canvas.upperBound..<code.endIndex),
              let tail = code.range(of: "if let box {", range: head.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `PartNoteCanvas` and its note loop (#454)")
        }
        let loop = String(code[head.upperBound..<tail.lowerBound])
        XCTAssertTrue(loop.contains("context.fill(shape, with: .color(lit.contains(note.id) ? EchoelTheme.text"),
                      "a picked note keeps the full text colour")
        XCTAssertTrue(loop.contains(": EchoelTheme.surface.mix(with: EchoelTheme.accent,"),
                      "an unpicked note is an OPAQUE mix of surface and accent — nothing shows through it")
        XCTAssertTrue(loop.contains("by: ClipNoteEdit.noteShade(velocity: note.velocity))))"),
                      "at ITS OWN velocity's shade")
        XCTAssertEqual(loop.components(separatedBy: "noteShade(").count - 1, 1,
                       "the shade is asked once, on the unpicked branch — never for the pick or the ring")
        XCTAssertEqual(loop.components(separatedBy: "context.fill(").count - 1, 1,
                       "each note is filled once — a second fill would paint over the shade")
        for banned in ["accent.opacity(", "EchoelTheme.text.opacity("] {
            XCTAssertFalse(loop.contains(banned), "the note loop draws `\(banned)` — a note is never translucent")
        }
        let body = String(code[canvas.upperBound...])
        for banned in ["context.opacity", "blendMode"] {
            XCTAssertFalse(body.contains(banned), "the grid sets `\(banned)` — that would fade or blend every note, the pick included")
        }
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

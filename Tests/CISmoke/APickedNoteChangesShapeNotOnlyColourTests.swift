// APickedNoteChangesShapeNotOnlyColourTests.swift
// Echoel — modes census 2026-09-26, UX C: a picked note in the part note grid is marked by more
// than colour.
//
// WHAT THIS PINS. `PartNoteCanvas` told a picked note from an unpicked one ONLY by its fill —
// `EchoelTheme.text` against `EchoelTheme.accent`. Information carried by colour alone fails
// WCAG 1.4.1 and is exactly what a colour-vision deficiency cannot read. A picked note now also
// carries a 1 pt inner ring in the grid's surface colour, drawn in the same loop, for the same
// set (`lit` — the preview's pick set, so a marquee in progress shows it too).
//
// 1. SOURCE: inside the note loop, after the fill, a `lit.contains(note.id)` branch strokes the
//    note's own rect inset, 1 pt, in `EchoelTheme.surface`, and skips a rect too small to carry it.
// 2. COUNTERWEIGHTS (#343): the fill still separates the two states (the ring is added, not
//    substituted), and nothing in the loop adds a glow or shadow (Uncodixfy).
//
// Grading (§0, no Swift toolchain): transcribed against both trees — claim 1 red on the parent
// (`1d19bdd29`, no stroke in the loop), green here; claim 2 green on both. SOURCE-TEXT scan: how
// the ring reads on glass is a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part → Edit notes → tap a note: it turns light AND
// shows a thin dark inner ring; with Settings → Accessibility → Display → Color Filters →
// Grayscale on, the picked note is still told apart.

import Foundation
import XCTest

final class APickedNoteChangesShapeNotOnlyColourTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    private func noteLoop() throws -> String {
        let code = try source(Self.editor)
        guard let head = code.range(of: "for note in shown where range.contains(note.pitch) {"),
              let tail = code.range(of: "if let box {", range: head.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: the note loop of `PartNoteCanvas` (#454)")
            return ""
        }
        return String(code[head.upperBound..<tail.lowerBound])
    }

    func testAPickedNoteCarriesARing() throws {
        let loop = try noteLoop()
        // Review of cf7414c72 (LOW, #408): one shared `guard` blamed "colour alone" for a mere
        // re-spelling. The fill is an ANCHOR; the branch and the ring are the CLAIM, and a
        // reformat of the stroke's arguments must not read as the ring being gone.
        guard let fill = loop.range(of: "context.fill(shape,") else {
            return XCTFail("ANCHOR MISSING: the note fill `context.fill(shape,` (#454)")
        }
        guard let branch = loop.range(of: "if lit.contains(note.id)", range: fill.upperBound..<loop.endIndex),
              let ring = loop.range(of: "context.stroke(Path(roundedRect:", range: branch.upperBound..<loop.endIndex) else {
            return XCTFail("""
                a picked note is marked by colour alone again — after the fill, the loop has no                 `lit` branch that strokes a ring. WCAG 1.4.1: a state carried only by colour is                 unreadable to a colour-vision deficiency.
                """)
        }
        XCTAssertLessThan(branch.upperBound, ring.lowerBound, "the ring is drawn inside the picked branch")
        XCTAssertTrue(loop.contains("with: .color(EchoelTheme.surface), lineWidth: 1)"),
                      "a 1 pt ring in the grid's own surface token — no new colour")
    }

    func testTheFillStillSeparatesAndNothingGlows() throws {
        let loop = try noteLoop()
        XCTAssertTrue(loop.contains("lit.contains(note.id) ? EchoelTheme.text"),
                      "the ring is added to the colour change, never substituted for it")
        for banned in [".shadow(", "blur", "glow"] {
            XCTAssertFalse(loop.contains(banned), "the note loop draws `\(banned)` — Uncodixfy bans glow and soft shadows")
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

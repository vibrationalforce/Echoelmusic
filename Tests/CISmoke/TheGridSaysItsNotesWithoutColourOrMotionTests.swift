// TheGridSaysItsNotesWithoutColourOrMotionTests.swift
// Echoel — DMMW Phase 6 · slice 4 (founder 2026-09-29: "Reduce Motion und Graustufen dürfen die
// Information nicht zerstören" and "Stille oder Signalverlust braucht einen definierten
// Neutralzustand").
//
// WHY A TEST-ONLY SLICE. The inventory for this phase measured the carriers and found them
// present — nothing to build, but nothing pinned either:
//   · GREYSCALE — every grid cell NAMES its note in near-white text (the tint lives only on the
//     fill and border, "so nothing is lost"), and the root column is marked by a thicker BORDER,
//     i.e. by geometry, not by hue. Position carries pitch too (slice 1, claim 5).
//   · REDUCE MOTION — it drops the touch ripple and freezes the field's clock; it does not reach
//     the grid builder, so the fretboard survives the setting whole.
//   · SILENCE — the field has ONE fixed neutral: with no sounding note `colourOn` is 0 and the
//     cloud colour is replaced by a single literal. The data side has its own neutral,
//     `SpectralColor.neutral`, achromatic (slice 1, claim 4).
// A later "tidy" could colour the labels with the tint, gate the grid on Reduce Motion or let
// silence keep the last chord's hue, and every one of those would pass today's bundle.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END — under every shipped note-naming the twelve pitch classes get twelve distinct
//      names, so a label alone tells every column apart with the colour removed.
//   2. SOURCE-TEXT SCAN — the label text is the note's name, drawn in white (never the tint); the
//      root column is marked by border WIDTH.
//   3. SOURCE-TEXT SCAN — Reduce Motion stops the ripple and does not appear in the grid builder.
//   4. SOURCE-TEXT SCAN — silence resolves to ONE fixed neutral in the shader, reached through
//      `colourOn`, which is zero when no cloud has weight.
// GRADING against the parent: every symbol and every needle exists there, so this file compiles
// against the parent and every assertion is GREEN on it — REGRESSION PINS for shipped behaviour,
// not forward guards (§3). Transcribed against both trees.
// ⛔ HONEST LIMITS. Whether a label is legible on a device, and what the Smart Invert / Grayscale
// accessibility filters actually render, is a DEVICE PROBE. `accessibilityDifferentiateWithoutColor`
// is read nowhere in `Sources/` — nothing needs it on this surface today, and this file does not
// pretend otherwise. The two neutrals DIFFER on purpose: the field's is warm (the natural-light
// law in the shader), the data neutral is grey. Both are defined; unifying them is a look decision
// for the founder, not a correctness repair, so this slice records the pair instead of changing
// either. NEEDS-FOUNDER-VERIFY: Settings → Accessibility → Colour Filters → Greyscale, open the
// note grid: every cell still names its note.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheGridSaysItsNotesWithoutColourOrMotionTests: XCTestCase {

    private static let touch = "Sources/Echoelmusic/Studio/TouchInstrumentView.swift"
    private static let field = "Sources/Echoelmusic/Views/MetalBioView.swift"

    // MARK: 1 — a name per column, whatever the naming

    func testEveryNamingGivesTwelveDistinctNames() {
        for naming in NoteNaming.allCases {
            for flats in [false, true] {
                let names = (0..<12).map { naming.name(pitchClass: $0, preferFlats: flats) }
                XCTAssertEqual(Set(names).count, 12, """
                    \(naming) (flats: \(flats)) names two pitch classes alike — in greyscale the \
                    label is what tells the columns apart: \(names)
                    """)
                XCTAssertFalse(names.contains(""), "an empty label carries nothing")
            }
        }
    }

    // MARK: 2 — the label and the root mark do not depend on hue

    func testTheCellNamesItsNoteInWhiteAndMarksTheRootByWidth() throws {
        let grid = try member("private func rebuildGrid() {", in: try source(Self.touch))
        XCTAssertTrue(grid.contains("label.string = fit.dropsOctave ? noteName : noteName + "),
                      "the cell's text is the note's name")
        XCTAssertTrue(grid.contains("label.foregroundColor = UIColor.white.withAlphaComponent("),
                      "the name is drawn in white, never in the tint — it survives a greyscale filter")
        XCTAssertFalse(grid.contains("label.foregroundColor = tint"),
                       "a tinted label would lose the name exactly where the colour is lost")
        XCTAssertTrue(grid.contains("cell.borderWidth = isRoot ? 1.5 : 1"),
                      "the root column is marked by geometry, not only by hue")
    }

    // MARK: 3 — Reduce Motion takes the motion, not the map

    func testReduceMotionStopsTheRippleAndLeavesTheGrid() throws {
        let touch = try source(Self.touch)
        let ring = try member("private func spawnRing(at p: CGPoint, strong: Bool, pitch: Int, velocity: Float) {",
                              in: touch)
        XCTAssertTrue(ring.contains("guard !reduceMotion else { return }"), "the ripple is the motion that goes")
        let grid = try member("private func rebuildGrid() {", in: touch)
        XCTAssertFalse(grid.contains("reduceMotion"), "the fretboard does not depend on the motion setting")
    }

    // MARK: 4 — silence has one defined colour

    func testSilenceResolvesToOneFixedNeutralInTheField() throws {
        let field = try source(Self.field)
        XCTAssertEqual(field.components(separatedBy: "col = mix(float3(0.60, 0.56, 0.50), col, colourOn);").count - 1, 1,
                       "ONE neutral, mixed in by `colourOn` — no note, no hue")
        XCTAssertTrue(field.contains("float colourOn = mix(clamp(cloudGlow * 2.4, 0.0, 1.0), presence, prismW);"),
                      "`colourOn` is the clouds' density: zero with no weighted cloud")
        let neutral = SpectralColor.neutral
        XCTAssertEqual(neutral.r, neutral.g, accuracy: 1e-9, "the data neutral carries no hue")
        XCTAssertEqual(neutral.g, neutral.b, accuracy: 1e-9)
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body that starts at `anchor`, searched from the anchor's FIRST character (#408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }
}

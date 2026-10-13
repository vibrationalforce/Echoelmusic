// TheNoteGridWearsThePitchColourTests.swift
// Echoel — GMMW colour slice (founder 2026-10-13, from the deep audit: "the note editor takes
// SpectralColor's pitch-class hue — the same as the pads and the picture").
//
// THE GAP. `toneLinearRGB` is the ONE colour rule: the clouds, the touch ripple, the pad grid and
// the Art-Net/sACN fixtures all light a sounding frequency with it (`ASoundingNoteHasOneColourAnd
// OnePlaceTests`). The note editor did not — every block was the bio-green accent, with velocity as
// depth (`TheNoteGridShowsHowLoudEachNoteIsTests`). So the one surface where a user LOOKS at pitches
// told nothing by colour, while the pads beside it did.
//
// THE REPAIR. `SpectralColor.gridTint` brings the one hue to ONE OKLab lightness
// (`gridTintLightness`), scaling chroma down until the colour is in sRGB gamut — hue says the
// pitch, lightness stays free for velocity. `PianoRollModel.soundingHz` is the one Hz rule a
// written pitch sounds at (A4 + tone-system cents) — `musicalFrame` publishes it and
// `NoteGridTint.pitchTints` colours by it, so the picture and the grid cannot disagree.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR (pure): the twelve tints share one lightness, are twelve distinct hues,
//    do not change across octaves, DO change with the concert pitch, and silence is a hue-free grey.
// 2. END-TO-END BEHAVIOUR (pure, computed): at the quietest note shade the darkest of the twelve
//    mixes still clears 3:1 against the grid surface AND the shaded out-of-key row — the same
//    arithmetic that set the velocity floor (OKLab mix, sRGB-composited fill), with the theme's
//    numbers parsed from `EchoelTheme.swift`, never hand-copied.
// 3. COUNTERWEIGHT: `soundingHz` IS the frame's Hz — the published `MusicalFrame` and the grid's
//    rule agree to 1e-9 for every pitch and a retuned table; a malformed table reads as 12-TET.
// 4. SOURCE-TEXT SCAN: the frame has ONE Hz formula (through `soundingHz`); the grid asks the
//    OBSERVED session A4 and the roll model's cents; the canvas fills with the tint.
//
// HONEST GRADING (§3), against the parent tree: the file does NOT compile there — `gridTint`,
// `gridTintLightness`, `soundingHz` and `NoteGridTint` are new — so no assertion has a verdict on
// the parent; claims 1, 2 and 3 are FORWARD (one absence, #486), claim 4's scans are absent there by
// transcription. Claim 2's numbers were first computed in a Python twin of `toneLinearRGB` +
// OKLab (scratchpad `tint/twin.py`: L 0.82 → 3.07:1, L 0.85 → 3.32:1 worst case; the accent's own
// 0.55 floor reproduces the review's 3.12:1 in the same twin, which is how the twin was checked).
// DEVICE PROBE, open — NEEDS-FOUNDER-VERIFY: open a MIDI part's Notes page: each row's blocks wear
// one hue (twin at L 0.84: C mint green, F♯ pink, A salmon); set A4 to 432 on the Piece stage (the one
// concert-pitch field, `CompositionHeaderStrip`) — the blocks shift hue with the pads and the picture; a
// quiet note is darker, never washed.

import Foundation
import SwiftUI
import XCTest
@testable import Echoelmusic

/// `@MainActor`: `PianoRollModel.musicalFrame` is a static on a main-actor class (the roll model is
/// the hot publisher), the same reason `ASoundingNoteHasOneColourAndOnePlaceTests` is isolated.
@MainActor
final class TheNoteGridWearsThePitchColourTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let roll = "Sources/Echoelmusic/Studio/PianoRollView.swift"
    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    /// Directory-gated, never per-file (#475): the tree root above this file, or a SKIP for a
    /// bundle running without the sources beside it.
    private static func treeRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.treeRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func hz(_ pitch: Int, a4: Double = 440, cents: [Double] = PianoRollModel.equalTemperamentCents) -> Double {
        PianoRollModel.soundingHz(pitch: pitch, a4Hz: a4, pitchClassCents: cents)
    }

    private func hueDegrees(_ c: LinearRGB) -> Double {
        let lab = SpectralColor.linearToOKLab(c)
        let deg = atan2(lab.b, lab.a) * 180 / .pi
        return deg < 0 ? deg + 360 : deg
    }

    // MARK: 1 — twelve hues at one lightness

    func testTheTwelveTintsShareOneLightnessAndTwelveHues() {
        var hues: [Double] = []
        for pitchClass in 0..<12 {
            let tint = SpectralColor.gridTint(forToneHz: hz(60 + pitchClass))
            let lab = SpectralColor.linearToOKLab(tint)
            XCTAssertEqual(lab.L, SpectralColor.gridTintLightness, accuracy: 0.02, """
                pitch class \(pitchClass) is drawn at L \(lab.L), not the one grid lightness — \
                lightness must stay free to carry velocity (`ClipNoteEdit.noteShade`); a hue that \
                is also darker reads as a quieter note.
                """)
            XCTAssertGreaterThan((lab.a * lab.a + lab.b * lab.b).squareRoot(), 0.02,
                                 "pitch class \(pitchClass) lost its chroma entirely — the gamut fold went too far")
            hues.append(hueDegrees(tint))
        }
        for i in 0..<12 {
            for j in (i + 1)..<12 {
                var d = abs(hues[i] - hues[j]); if d > 180 { d = 360 - d }
                XCTAssertGreaterThan(d, 5, """
                    pitch classes \(i) and \(j) wear hues \(hues[i])° and \(hues[j])° — less than 5° \
                    apart, so two pitches are one colour on the grid.
                    """)
            }
        }
    }

    func testAnOctaveKeepsItsColourAndTheConcertPitchMovesIt() {
        for pitchClass in 0..<12 {
            let low = SpectralColor.gridTint(forToneHz: hz(48 + pitchClass))
            let high = SpectralColor.gridTint(forToneHz: hz(72 + pitchClass))
            XCTAssertEqual(low.r, high.r, accuracy: 1e-9); XCTAssertEqual(low.g, high.g, accuracy: 1e-9)
            XCTAssertEqual(low.b, high.b, accuracy: 1e-9, "pitch class \(pitchClass): two octaves, one colour — the fold is `toneLinearRGB`'s")
        }
        var moved = 0
        for pitchClass in 0..<12 {
            let standard = SpectralColor.gridTint(forToneHz: hz(60 + pitchClass, a4: 440))
            let low = SpectralColor.gridTint(forToneHz: hz(60 + pitchClass, a4: 432))
            if abs(standard.r - low.r) + abs(standard.g - low.g) + abs(standard.b - low.b) > 1e-4 { moved += 1 }
        }
        XCTAssertEqual(moved, 12, "a Kammerton of 432 must recolour every class — colour follows the SOUNDING frequency")
        let silent = SpectralColor.gridTint(forToneHz: 0)
        let nan = SpectralColor.gridTint(forToneHz: .nan)
        for c in [silent, nan] {
            let lab = SpectralColor.linearToOKLab(c)
            XCTAssertEqual(lab.L, SpectralColor.gridTintLightness, accuracy: 0.02)
            XCTAssertLessThan(abs(lab.a) + abs(lab.b), 1e-6, "silence and a bad frequency are the hue-free grey at the grid lightness")
        }
    }

    // MARK: 2 — the quietest note still clears 3:1, computed

    private func wcagContrast(_ a: LinearRGB, _ b: LinearRGB) -> Double {
        func lum(_ c: LinearRGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
        let la = lum(a), lb = lum(b)
        return (Swift.max(la, lb) + 0.05) / (Swift.min(la, lb) + 0.05)
    }

    private func decode(_ v: Double) -> Double { v > 0.04045 ? pow((v + 0.055) / 1.055, 2.4) : v / 12.92 }

    /// SwiftUI's `.mix(with:by:)` default is `.perceptual` — an OKLab interpolation.
    private func perceptualMix(_ a: LinearRGB, _ b: LinearRGB, by t: Double) -> LinearRGB {
        let la = SpectralColor.linearToOKLab(a), lb = SpectralColor.linearToOKLab(b)
        return SpectralColor.oklabToLinear(OKLab(L: la.L + (lb.L - la.L) * t,
                                                 a: la.a + (lb.a - la.a) * t,
                                                 b: la.b + (lb.b - la.b) * t))
    }

    /// A number parsed from the theme line, never hand-copied (#416).
    private func themeLiteral(line needle: String, label: String) throws -> Double {
        let theme = try text(Self.theme)
        let line = try XCTUnwrap(theme.components(separatedBy: "\n").first { $0.contains(needle) },
                                 "ANCHOR MISSING: `\(needle)` in EchoelTheme.swift (#454)")
        let after = try XCTUnwrap(line.range(of: label), "ANCHOR MISSING: `\(label)` on the `\(needle)` line")
        let digits = line[after.upperBound...].trimmingCharacters(in: .whitespaces)
            .prefix { $0.isNumber || $0 == "." }
        return try XCTUnwrap(Double(digits), "no number after `\(label)` on the `\(needle)` line")
    }

    func testTheQuietestNoteClearsThreeToOneOnEveryRow() throws {
        let surfaceRG = EchoelTheme.surfaceComponent
        let surfaceB = try themeLiteral(line: "static let surface = Color(", label: "blue:")
        let fillGrey = try themeLiteral(line: "static let fill    = Color(", label: "red:")
        let fillOpacity = EchoelTheme.fillOpacity
        let surface = LinearRGB(r: decode(surfaceRG), g: decode(surfaceRG), b: decode(surfaceB))
        // The shaded out-of-key row: the fill composited over the surface in sRGB (review 11).
        func over(_ s: Double) -> Double { decode(fillOpacity * fillGrey + (1 - fillOpacity) * s) }
        let shadedRow = LinearRGB(r: over(surfaceRG), g: over(surfaceRG), b: over(surfaceB))
        let floor = ClipNoteEdit.quietestNoteShade
        var worst = Double.infinity
        for pitchClass in 0..<12 {
            let tint = SpectralColor.gridTint(forToneHz: hz(60 + pitchClass))
            let quietest = perceptualMix(surface, tint, by: floor)
            for row in [surface, shadedRow] {
                let c = wcagContrast(quietest, row)
                worst = Swift.min(worst, c)
                XCTAssertGreaterThanOrEqual(c, 3.0, """
                    pitch class \(pitchClass) at velocity 0 reads \(c):1 against a grid row — below the \
                    3:1 the velocity floor was set for. Raise `SpectralColor.gridTintLightness` (the \
                    accent it replaces sat at L ≈ 0.79 and 3.12:1); do not lower the floor.
                    """)
            }
        }
        XCTAssertLessThan(worst, 5, "counterweight: the computation is not vacuous — the worst row is a real ratio, not infinity")
    }

    // MARK: 3 — the grid's Hz is the frame's Hz

    func testTheGridColoursByTheHzTheFramePublishes() throws {
        var cents = PianoRollModel.equalTemperamentCents
        cents[3] = 15.6; cents[8] = -13.7   // a retuned table, like a just or Pythagorean system
        for pitch in [36, 55, 60, 63, 68, 81] {
            let frame = PianoRollModel.musicalFrame(
                forActive: [Note(pitch: pitch, startStep: 0, velocity: 0.8)], a4Hz: 432,
                pitchClassCents: cents, rootPitchClass: 0, scaleName: "major", tempoBPM: 120, beatPhase: 0)
            let published = try XCTUnwrap(frame.notes.first?.frequencyHz)
            XCTAssertEqual(published, hz(pitch, a4: 432, cents: cents), accuracy: 1e-9,
                           "pitch \(pitch): the picture and the grid must light the same Hz")
        }
        XCTAssertEqual(hz(69), 440, accuracy: 1e-9)
        XCTAssertEqual(hz(69, cents: [0, 0]), 440, accuracy: 1e-9, "a short table is 12-TET")
        var poisoned = PianoRollModel.equalTemperamentCents; poisoned[0] = .nan
        XCTAssertEqual(hz(60, cents: poisoned), hz(60), accuracy: 1e-9, "a NaN cell makes the whole table 12-TET, never a NaN Hz")
        XCTAssertEqual(NoteGridTint.index(forPitch: -1, count: 12), 11, "a negative pitch folds to its class")
        XCTAssertEqual(NoteGridTint.index(forPitch: 73, count: 12), 1)
        XCTAssertEqual(NoteGridTint.index(forPitch: 73, count: 0), 0, "an empty table never indexes")
        XCTAssertEqual(NoteGridTint.pitchTints(a4Hz: 440, pitchClassCents: PianoRollModel.equalTemperamentCents).count, 12)
    }

    /// The text between `anchor` (which must end in `{`) and its matching `}`; nil when the anchor
    /// is missing or unbalanced. Brace-matched rather than windowed (#408).
    private func braceBody(after anchor: String, in code: String) -> String? {
        guard anchor.hasSuffix("{"), let start = code.range(of: anchor) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    // MARK: 4 — one formula, observed A4, the canvas fills with the tint

    func testTheFrameHasOneFormulaAndTheGridAsksIt() throws {
        let roll = SourceText.codeOnly(try text(Self.roll))
        XCTAssertEqual(roll.components(separatedBy: "a4Hz * pow(2.0").count - 1, 1, """
            `PianoRollView.swift` spells the written-pitch → Hz formula more than once. `soundingHz` \
            is the one definition; `musicalFrame` must call it, not restate it (#416).
            """)
        XCTAssertTrue(roll.contains("soundingHz(pitch: n.pitch, a4Hz: a4Hz, pitchClassCents: pitchClassCents)"),
                      "the published frame takes its Hz from `soundingHz`")
        let editor = SourceText.codeOnly(try text(Self.editor))
        XCTAssertTrue(editor.contains("tints: NoteGridTint.pitchTints(a4Hz: session.a4Hz,"), """
            The grid must colour by the SESSION's concert pitch — the one owner of `a4Hz`, and an \
            observed read, so a retune repaints an open grid. `pianoRoll.musicalA4Hz` is \
            `@ObservationIgnored` and would leave the grid in the old colours until its next redraw.
            """)
        XCTAssertTrue(editor.contains("pitchClassCents: pianoRoll.musicalPitchClassCents)"),
                      "and by the tone system the frame publishes with")
        XCTAssertEqual(editor.components(separatedBy: "NoteGridTint.pitchTints(").count - 1, 1,
                       "the twelve tints are computed once per grid redraw — never per note")
        // `NoteGridTint` lives in this same file, so the rule is "exactly one call, and it is inside
        // the enum" — never "no call in the file", which the enum itself would make red.
        let tintBody = try XCTUnwrap(braceBody(after: "enum NoteGridTint {", in: editor),
                                     "ANCHOR MISSING: `enum NoteGridTint` in PartNoteEditor.swift (#454)")
        XCTAssertEqual(tintBody.components(separatedBy: "gridTint(forToneHz").count - 1, 1,
                       "`NoteGridTint.pitchTints` turns each pitch class's Hz into its colour")
        XCTAssertEqual(editor.components(separatedBy: "gridTint(forToneHz").count - 1, 1, """
            The editor turns a frequency into a grid colour outside `NoteGridTint`. One place makes \
            the twelve colours; a canvas that asked the colour rule per note would redo that work \
            for every block and could drift from the tints the grid was handed.
            """)
        XCTAssertTrue(editor.contains("tints[NoteGridTint.index(forPitch: note.pitch, count: tints.count)]"),
                      "the canvas fills a block with its pitch's tint, bounded by the table it was handed")
    }
}

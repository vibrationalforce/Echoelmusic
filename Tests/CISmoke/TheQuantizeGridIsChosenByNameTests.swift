// TheQuantizeGridIsChosenByNameTests.swift
// Echoel — modes census 2026-09-26, design slice 6: Quantize snaps to a grid the musician picks.
//
// WHAT THIS PINS. Quantize snapped note starts to sixteenths and nothing else — a part played
// in eighths or quarters could only be tidied onto a grid finer than its own. The note editor
// now offers 1/16 · 1/8 · 1/4 as a segmented Picker, and Quantize snaps to the one chosen.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.quantizing(…, gridSteps:)`, pure): every snapped start
//    sits on a cell of the chosen grid, measured from the part's start; a note that would round
//    past the part's last cell lands ON it; notes outside the part and every length are
//    untouched; an already-snapped part and a grid below one step commit nothing; `gridSteps: 1`
//    is the sixteenth behaviour M3 pinned (`TheSelectionIsTransposedQuantizedAndDuplicatedInOneStepTests`).
// 2. END-TO-END BEHAVIOUR: the three grids are named, spanning 1, 2 and 4 sixteenths, and each
//    has a spoken name VoiceOver can say (no "1/16", which it reads as a fraction or a date).
// 3. SOURCE: the editor offers the choice as a SEGMENTED Picker (a named choice is a Picker, and
//    a segmented one has no popover a re-render could tear down), holds it in ONE `@State`, and
//    feeds it to BOTH quantize calls — the enablement and the commit — so the button never
//    greys on one grid and snaps on another.
//
// Grading (§0, no Swift toolchain): `QuantizeGrid` and the `gridSteps:` argument do not exist on
// the parent (`4f62d6867`), so this file does not compile there — every claim is a FORWARD guard,
// one absence (#486). Claims 1-2 transcribed into Python and driven on the cases below; claim 3
// transcribed against this tree with mutants (a `.menu` picker, the enablement left on
// sixteenths, the spoken label dropped): each red.
// NOT covered: how the three segments read on glass and with VoiceOver — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part → Notes → select a few off-grid notes → pick 1/4
// → Quantize: each start jumps to the nearest beat of the part; pick 1/8 and add a note between
// two eighths → Quantize moves only that one; VoiceOver on the segments says "sixteenth",
// "eighth", "quarter note".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheQuantizeGridIsChosenByNameTests: XCTestCase {

    private static let step = Note.ticksPerStep
    private static let bar = TimelineTime.ticksPerBar
    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — the snap, pure

    func testEveryStartLandsOnTheChosenGridInsideThePart() throws {
        let offset = Self.bar                       // the part shows the clip's second bar
        let length = Self.bar
        let a = Note(pitch: 60, startTick: offset + 3 * Self.step + 10, lengthTicks: 90)
        let b = Note(pitch: 62, startTick: offset + 700, lengthTicks: 90)
        let edge = Note(pitch: 64, startTick: offset + 1_900, lengthTicks: 5)
        let outside = Note(pitch: 65, startTick: 30, lengthTicks: 90)
        let clip = [a, b, edge, outside]
        let ids = Set(clip.map(\.id))

        let eighths = try XCTUnwrap(ClipNoteEdit.quantizing(ids, in: clip, offsetTicks: offset,
                                                            lengthTicks: length, gridSteps: 2))
        XCTAssertEqual(eighths[0].startTick, offset + 4 * Self.step, "370 ticks in → the eighth at 480")
        XCTAssertEqual(eighths[1].startTick, offset + 6 * Self.step, "700 → 720, the nearest eighth")
        XCTAssertEqual(eighths[2].startTick, offset + 14 * Self.step,
                       "1 900 would round to 1 920, past the part — it lands on the last eighth")

        let quarters = try XCTUnwrap(ClipNoteEdit.quantizing(ids, in: clip, offsetTicks: offset,
                                                             lengthTicks: length, gridSteps: 4))
        XCTAssertEqual(quarters[0].startTick, offset + 4 * Self.step, "370 → the quarter at 480")
        XCTAssertEqual(quarters[1].startTick, offset + 4 * Self.step, "700 → 480, the nearer quarter")
        XCTAssertEqual(quarters[2].startTick, offset + 12 * Self.step, "the last quarter of the part")

        for (grid, snapped) in [(2, eighths), (4, quarters)] {
            for note in snapped.prefix(3) {
                XCTAssertEqual((note.startTick - offset) % (grid * Self.step), 0,
                               "every snapped start sits on a \(grid)-sixteenth cell of the part")
            }
            XCTAssertEqual(snapped[3], outside, "a note the part does not show is never moved")
            XCTAssertEqual(snapped.map(\.lengthTicks), clip.map(\.lengthTicks), "lengths are untouched")
            XCTAssertNil(ClipNoteEdit.quantizing(ids, in: snapped, offsetTicks: offset, lengthTicks: length,
                                                 gridSteps: grid),
                         "quantizing a part already on the \(grid)-sixteenth grid commits nothing")
        }
    }

    func testAShortPartAndADegenerateGrid() {
        // A part ten sixteenths long: its last quarter cell starts at step 8, not step 12.
        let late = Note(pitch: 60, startTick: 1_150, lengthTicks: 60)
        let snapped = ClipNoteEdit.quantizing([late.id], in: [late], offsetTicks: 0,
                                              lengthTicks: 10 * Self.step, gridSteps: 4)
        XCTAssertEqual(snapped?.first?.startTick, 8 * Self.step, "the last quarter cell INSIDE a short part")
        XCTAssertNil(ClipNoteEdit.quantizing([late.id], in: [late], offsetTicks: 0,
                                             lengthTicks: 10 * Self.step, gridSteps: 0),
                     "a grid below one step snaps nothing")
        let one = Note(pitch: 60, startTick: 2 * Self.step + 50, lengthTicks: 60)
        XCTAssertEqual(ClipNoteEdit.quantizing([one.id], in: [one], offsetTicks: 0, lengthTicks: Self.bar,
                                               gridSteps: ClipNoteEdit.QuantizeGrid.sixteenth.steps)?.first?.startTick,
                       2 * Self.step, "the sixteenth grid is the M3 behaviour")
    }

    // MARK: 2 — named grids

    func testTheThreeGridsAreNamed() {
        let grids = ClipNoteEdit.QuantizeGrid.allCases
        XCTAssertEqual(grids.map(\.steps), [1, 2, 4])
        XCTAssertEqual(grids.map(\.label), ["1/16", "1/8", "1/4"])
        for grid in grids {
            XCTAssertFalse(grid.spoken.contains("/"), "`\(grid.label)` is spoken as a word, not a fraction")
            XCTAssertFalse(grid.spoken.isEmpty)
        }
    }

    // MARK: 3 — the editor offers and uses it

    func testTheEditorOffersTheGridAndUsesItForBothCalls() throws {
        let code = try source(Self.editorPath)
        XCTAssertEqual(code.components(separatedBy: "@State private var quantizeGrid: ClipNoteEdit.QuantizeGrid = .sixteenth").count - 1, 1,
                       "ONE held grid choice, starting on the sixteenths the grid draws")
        guard let picker = code.range(of: "Picker(\"Quantize grid\", selection: $quantizeGrid) {"),
              let style = code.range(of: ".pickerStyle(", range: picker.upperBound..<code.endIndex) else {
            return XCTFail("the note editor no longer offers the quantize grid as a Picker")
        }
        XCTAssertTrue(code[style.upperBound...].hasPrefix(".segmented)"),
                      "the grid Picker is segmented — a `.menu` popover is the one a re-render tears down")
        XCTAssertTrue(code[picker.upperBound..<style.lowerBound].contains("Text(grid.label).accessibilityLabel(grid.spoken).tag(grid)"),
                      "each segment shows the short name and speaks the word")
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.quantizing(").count - 1, 2,
                       "two quantize calls: the button's enablement and the commit")
        XCTAssertEqual(code.components(separatedBy: "gridSteps: quantizeGrid.steps").count - 1, 2,
                       "BOTH calls use the chosen grid — the button must not grey on one grid and snap on another")
        XCTAssertTrue(code.contains("label: \"Snap the starts of \\(what) to the nearest \\(quantizeGrid.spoken)\")"),
                      "VoiceOver hears which grid the button snaps to")
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

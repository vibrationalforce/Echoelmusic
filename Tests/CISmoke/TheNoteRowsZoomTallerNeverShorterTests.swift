// TheNoteRowsZoomTallerNeverShorterTests.swift
// Ultraplan-A3 / N2b (2026-10-16): the note grid zoomed its TIME (S9b) but every row stayed 24 pt.
// "Taller rows" / "Shorter rows" in the note tool row now step the row height through three
// scales of the touch floor (EP-1) — so the row zoom only ever makes a pitch EASIER to hit, and
// zooming out past the floor would undo EP-1.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END over `NoteGridZoom.rowScale` / `rowLevel` (pure): the first scale is
//     the floor itself, the scales grow, stepping stays inside the list for any delta.
//   · Claim 2 is a SOURCE-TEXT SCAN — `PartNoteGrid` is a private View: ONE zoomed row height, read
//     by the canvas grid, the tap hit-test and the key column; the fixed floor read nowhere else;
//     the two doors step through the one stepper and grey out where it would not move.
//   · DEVICE PROBE, open: taps land on the row aimed at at every level, and the page scrolls to
//     the taller grid.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — it names
// `NoteGridZoom.rowScale`, which this commit creates — ONE absence (#486), every claim a FORWARD
// guard. Mutants and the claim each turns red: a first scale below 1 (1, a row under the touch
// floor) · a reader left on `Self.rowHeight` — the hit test would aim at the 24-pt rows while the
// canvas draws 40 (2) · a door that writes `rowLevel += 1` past the list (2).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteRowsZoomTallerNeverShorterTests: XCTestCase {

    // MARK: 1 — the scales start at the floor and only grow

    func testTheRowScalesStartAtTheFloorAndGrow() {
        let scales = NoteGridZoom.rowScales
        XCTAssertEqual(scales.first, 1, "the shortest row IS the touch floor (EP-1), never below it")
        XCTAssertGreaterThan(scales.count, 1, "there is something to zoom to")
        XCTAssertEqual(scales, scales.sorted(), "short to tall")
        XCTAssertEqual(Set(scales).count, scales.count, "no two levels draw the same height")
        XCTAssertEqual(NoteGridZoom.rowScale(atLevel: -5), 1, "a level below the list reads as the floor")
        XCTAssertEqual(NoteGridZoom.rowScale(atLevel: 99), scales.last, "a level above reads as the tallest")
        XCTAssertEqual(NoteGridZoom.rowLevel(0, steppedBy: -1), 0, "no step below the floor")
        XCTAssertEqual(NoteGridZoom.rowLevel(0, steppedBy: 1), 1)
        XCTAssertEqual(NoteGridZoom.rowLevel(scales.count - 1, steppedBy: 1), scales.count - 1)
        for delta in [Int.min, -1_000, 1_000, Int.max] {
            let level = NoteGridZoom.rowLevel(1, steppedBy: delta)
            XCTAssertTrue((0..<scales.count).contains(level), "delta \(delta) left the list: \(level)")
        }
    }

    // MARK: 2 — one zoomed height, read by every reader; two doors through the one stepper

    func testEveryReaderTakesTheOneZoomedRowHeight() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Studio/PartNoteEditor.swift"), encoding: .utf8))
        XCTAssertEqual(code.components(separatedBy: "private var zoomedRowHeight: CGFloat { Self.rowHeight * CGFloat(NoteGridZoom.rowScale(atLevel: rowLevel)) }").count - 1, 1,
                       "ONE zoomed row height, computed from the floor and the level")
        XCTAssertEqual(code.components(separatedBy: "Self.rowHeight").count - 1, 1,
                       "the fixed floor is read only by the zoomed height — any other reader would not follow the zoom")
        for (needle, who) in [("stepWidth: Double(stepWidth), rowHeight: Double(zoomedRowHeight),", "the canvas grid"),
                              ("stepW: Double(stepWidth), rowH: Double(zoomedRowHeight),", "the tap hit-test"),
                              ("rowHeight: zoomedRowHeight)", "the key column")] {
            XCTAssertEqual(code.components(separatedBy: needle).count - 1, 1, "\(who) reads the zoomed row height")
        }
        XCTAssertTrue(code.contains("@State private var rowLevel = 0"), "a view of the open grid, opening at the floor")
        for (word, delta) in [("Shorter rows", "-1"), ("Taller rows", "1")] {
            guard let door = code.range(of: "button(\"\(word)\", ") else {
                XCTFail("`\(word)` is not a button in the note tool row"); continue
            }
            let rest = String(code[door.upperBound...].prefix(360))
            XCTAssertTrue(rest.contains("enabled: NoteGridZoom.rowLevel(rowLevel, steppedBy: \(delta)) != rowLevel"),
                          "`\(word)` greys out exactly where the one stepper would not move (#416)")
            XCTAssertTrue(rest.contains("rowLevel = NoteGridZoom.rowLevel(rowLevel, steppedBy: \(delta))"),
                          "`\(word)` writes through the one stepper")
        }
        XCTAssertTrue(code.contains("private static let rowHeight: CGFloat = "),
                      "counterweight: the floor `TheNoteRowsAreTouchableTests` pins is still the base")
    }
}

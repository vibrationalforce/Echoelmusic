// TheNoteGridHasAKeyColumnTests.swift
// Ultraplan-A2 / N2a (2026-10-16): the note grid named only its C rows, inside the canvas — so the
// names scrolled away with the part, and a row between two Cs was a pitch to count, not to read.
// A key column now stands beside the grid, OUTSIDE its horizontal scroll view: every row named,
// black keys shaded, the same row height and the same top-down order as the canvas.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END over `ClipNoteEdit.keyRows` (pure): one row per grid row, top down,
//     each named by `rowName` (the canvas's own naming, #416), black keys by pitch class.
//   · Claim 2 is a SOURCE-TEXT SCAN — `PartNoteGrid` is a private View: the column is mounted
//     BEFORE the scroll view inside one HStack (so it does not scroll), from the grid's own `range`
//     and the grid's zoomed row height, and it reads no state (no `@Environment`, no `@State`) and is hidden
//     from VoiceOver.
//   · DEVICE PROBE, open: the names line up with the rows, they stay while the part scrolls, and
//     the column fits at the largest type size.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — it names
// `ClipNoteEdit.keyRows`, which this commit creates — ONE absence (#486), every claim a FORWARD
// guard. Mutants and the claim each turns red: rows bottom-up (1, row 0 would name the lowest
// pitch beside the canvas's highest) · a black-key set off by one (1) · the column inside the scroll
// view (2) · a column that reads the bio snapshot or the playhead (2, the menu-freeze law).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteGridHasAKeyColumnTests: XCTestCase {

    // MARK: 1 — one named row per grid row, top down, keys by pitch class

    func testTheColumnNamesEveryRowTopDown() {
        let range = ClipNoteEdit.pitchRange(centre: 60, octaveShift: 0)
        let rows = ClipNoteEdit.keyRows(range, naming: .english, preferFlats: false)
        XCTAssertEqual(rows.count, range.count, "one row per grid row")
        XCTAssertEqual(rows.first?.pitch, range.upperBound, "row 0 is the top row — the canvas's `high − pitch` order")
        XCTAssertEqual(rows.last?.pitch, range.lowerBound)
        XCTAssertEqual(rows.map(\.pitch), Array(range.reversed()))
        for row in rows {
            XCTAssertEqual(row.name, ClipNoteEdit.rowName(pitch: row.pitch, naming: .english, preferFlats: false),
                           "the canvas's own row name (#416)")
            XCTAssertEqual(row.isBlackKey, [1, 3, 6, 8, 10].contains(row.pitch % 12), "pitch \(row.pitch)")
        }
        XCTAssertEqual(rows.first(where: { $0.pitch == 60 })?.name, "C4", "middle C is C4")
        XCTAssertEqual(rows.first(where: { $0.pitch == 61 })?.isBlackKey, true)
        XCTAssertEqual(rows.first(where: { $0.pitch == 64 })?.isBlackKey, false, "E is white")

        // The reader's names and the key's spelling reach the column.
        let flats = ClipNoteEdit.keyRows(range, naming: .english, preferFlats: true)
        XCTAssertEqual(flats.first(where: { $0.pitch == 61 })?.name,
                       ClipNoteEdit.rowName(pitch: 61, naming: .english, preferFlats: true))
        XCTAssertEqual(ClipNoteEdit.keyRows(range, naming: .solfege, preferFlats: false)
                        .first(where: { $0.pitch == 60 })?.name, "Do4")
        XCTAssertEqual(ClipNoteEdit.keyRows(0...0, naming: .english, preferFlats: false).map(\.name), ["C-1"],
                       "the bottom of MIDI is named too")
    }

    // MARK: 2 — mounted beside the scroll view, from the grid's own rows, reading nothing hot

    func testTheColumnStandsOutsideTheScrollViewAndReadsNoState() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Studio/PartNoteEditor.swift"), encoding: .utf8))
        guard let stack = code.range(of: "HStack(alignment: .top, spacing: .zero) {\n                    PartNoteKeyColumn(rows: ClipNoteEdit.keyRows(range, naming: naming,"),
              let scroll = code.range(of: "ScrollView(.horizontal, showsIndicators: true) {") else {
            return XCTFail("the key column's mount or the grid's scroll view moved — re-anchor")
        }
        XCTAssertLessThan(stack.upperBound, scroll.lowerBound, "the column comes first, outside the scroll view")
        let between = String(code[stack.upperBound..<scroll.lowerBound])
        XCTAssertTrue(between.contains("preferFlats: session.key.prefersFlatSpelling),"),
                      "the key's own spelling, as the picked note's line uses")
        XCTAssertTrue(between.contains("rowHeight: zoomedRowHeight)"), "the grid's one (zoomed) row height")
        XCTAssertEqual(code.components(separatedBy: "PartNoteKeyColumn(").count - 1, 1, "mounted once")

        guard let leaf = code.range(of: "private struct PartNoteKeyColumn: View {"),
              let next = code.range(of: "private struct PartNoteCanvas: View {") else {
            return XCTFail("`PartNoteKeyColumn` moved — re-anchor")
        }
        let column = String(code[leaf.upperBound..<next.lowerBound])
        for banned in ["@Environment", "@State", "@GestureState", "player.", "currentTick", "latestBio"] {
            XCTAssertFalse(column.contains(banned), "the key column reads `\(banned)` — it is drawn from its rows alone")
        }
        XCTAssertTrue(column.contains(".accessibilityHidden(true)"),
                      "the grid's label and the picked note's line say the pitch; 25 names would be noise")
        XCTAssertTrue(column.contains(".frame(width: Self.width, height: CGFloat(rows.count) * rowHeight)"),
                      "as tall as the canvas: rows × the one row height")
        XCTAssertTrue(code.contains(".frame(width: CGFloat(steps) * stepW, height: CGFloat(range.count) * rowH)"),
                      "counterweight: the canvas is rows × the same height")
    }
}

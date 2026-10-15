// TheNoteRowsAreTouchableTests.swift
// Echoel — EP-1 (founder on device, 2026-10-15: „Midi und Clips sowie editing View sind bisher
// komplett unbrauchbar und zu ungenau"). The note editor's rows were 14 pt — a third of Apple's
// 44-pt touch minimum — so a finger hit the neighbour pitch as often as the intended one.
//
// THE CLAIM. SOURCE-TEXT SCAN: `PartNoteEditor.rowHeight` is at least 22 pt, and the grid's height
// is still derived from it (rows × row height), so a taller row cannot clip the window.
// ⚠️ A FLOOR, NOT A VALUE (#364): any size from 22 pt up is a designer's call.
//
// ⚠️ HONEST GRADING (#433): RED on the parent for its named reason (14 < 22); green after.
// ⚠️ THE LIMIT: whether notes are now easy to hit is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY: open a
// MIDI part's notes, tap ten notes in neighbouring rows — each tap lands on the row you aimed at).

import Foundation
import XCTest

final class TheNoteRowsAreTouchableTests: XCTestCase {

    func testTheNoteRowIsAFingerHigh() throws {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("PartNoteEditor.swift not on disk — this run has no source tree")
        }
        let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        let needle = "private static let rowHeight: CGFloat = "
        guard let start = code.range(of: needle) else {
            return XCTFail("ANCHOR MISSING: the note editor's row height")
        }
        let literal = code[start.upperBound...].prefix { $0.isNumber || $0 == "." }
        let height = try XCTUnwrap(Double(String(literal)), "the row height is a plain number")
        XCTAssertGreaterThanOrEqual(height, 22, "a note row a finger can hit — 14 pt was a third of the touch minimum")
        XCTAssertTrue(code.contains(".frame(width: CGFloat(steps) * stepW, height: CGFloat(range.count) * rowH)"),
                      "the grid's height still follows the row height")
    }
}

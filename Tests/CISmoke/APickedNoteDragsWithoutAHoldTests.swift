// APickedNoteDragsWithoutAHoldTests.swift
// Echoel — EP-3b (founder 2026-10-15: „Ich finde kein Spaß am Testen so lange ich so einfache Sachen
// wie Midi Clips nicht entspannt bearbeiten kann"; the mockups showed direct note moves). Every
// move needed a 0.3 s hold first. A note the player has already picked now drags at once.
//
// THE CLAIMS (SOURCE-TEXT SCAN — the canvas leaf is private):
//   1. Only PICKED notes carry a direct touch target (an overlay over each picked note), so a
//      swipe anywhere else still scrolls; the handle forwards a tap to the same `onTap`.
//   2. The direct slide reports in the grid's one coordinate space and goes through the SAME
//      `resolve`, the SAME finger-rate `live` and the SAME one commit at release (`onRelease`).
//   3. COUNTERWEIGHT: the hold gesture is unchanged for unpicked notes and boxes, and the grid
//      still has exactly one `@GestureState`.
//
// ⚠️ HONEST GRADING (#433): claims 1–2 are FORWARD (created here — one absence, #486); claim 3 is a
// counterweight, green on both trees. Transcribed, no local toolchain (§0).
// ⚠️ THE LIMIT: whether the grab feels relaxed and the scroll still works is a DEVICE PROBE
// (NEEDS-FOUNDER-VERIFY: tap a note, then drag it at once — it moves; swipe on empty grid — it
// scrolls; tap the picked note — it unpicks).

import Foundation
import XCTest

final class APickedNoteDragsWithoutAHoldTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    func testOnlyPickedNotesCarryADirectHandle() throws {
        let code = try source(Self.editor)
        XCTAssertTrue(code.contains("ForEach(visible.filter { picked.contains($0.id) && range.contains($0.pitch) }) { note in"),
                      "the direct handles are the picked notes on screen, nothing else")
        XCTAssertTrue(code.contains(".onTapGesture(coordinateSpace: .named(Self.space)) { location in onTap(location) }"),
                      "a tap on a picked note still reaches the grid's tap (to unpick it)")
        XCTAssertTrue(code.contains(".gesture(direct)"), "the handle carries the direct slide")
        XCTAssertTrue(code.contains(".coordinateSpace(.named(Self.space))"), "the grid names its one coordinate space")
    }

    func testTheDirectSlideIsTheSameGestureWithoutTheHold() throws {
        let code = try source(Self.editor)
        let direct = try XCTUnwrap(body(after: "private var direct: some Gesture {", in: code),
                                   "the direct gesture is gone — re-anchor (#456)")
        XCTAssertTrue(direct.contains("DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))"),
                      "a few points of travel, so a tap still reaches the tap rule")
        XCTAssertTrue(direct.contains(".updating($live)"), "the same finger-rate state previews the slide")
        XCTAssertTrue(direct.contains("onRelease(gesture)"), "the same one commit at release")
        XCTAssertFalse(direct.contains("LongPressGesture"), "no hold on a picked note")
        XCTAssertTrue(code.contains("LongPressGesture(minimumDuration: 0.3)"), "the hold stays for unpicked notes and boxes")
        XCTAssertEqual(code.components(separatedBy: "@GestureState").count - 1, 1,
                       "the grid still has exactly one finger-rate state")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// The brace-matched body after `anchor` (§2, #408).
    private func body(after anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex, depth > 0 {
            if code[index] == "{" { depth += 1 } else if code[index] == "}" { depth -= 1 }
            index = code.index(after: index)
        }
        return String(code[start.upperBound..<index])
    }
}

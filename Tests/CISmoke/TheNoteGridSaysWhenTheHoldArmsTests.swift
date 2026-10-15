// TheNoteGridSaysWhenTheHoldArmsTests.swift
// Echoel — EP-3 (founder on device, 2026-10-15: „Midi und Clips sowie editing View sind bisher
// komplett unbrauchbar und zu ungenau"). Every move, stretch and box on the note grid waits for a
// 0.3 s hold, and nothing told the finger when that hold had armed — so a slide either scrolled or
// edited, and the player could not feel which.
//
// THE CLAIMS. SOURCE-TEXT SCAN (the canvas leaf is `private`; nothing here can be instantiated):
//   1. The hold's ARMED moment (`.second(true, nil)`: pressed long enough, no slide yet) bumps a
//      counter, and that counter is the trigger of a light impact — one tick per hold. A COUNTER,
//      not a flag: a scroll view that cancels the gesture leaves nothing to reset.
//   2. While a hold edits, the grid is framed, and the frame reads `live` — the `@GestureState`
//      SwiftUI resets itself — so no frame can outlive a cancelled gesture.
//   3. COUNTERWEIGHT: the per-sample `.updating` closure still writes nothing but its state (the
//      arm count is bumped in `.onChanged`, never there), and the hold is still 0.3 s.
//
// ⚠️ HONEST GRADING (#433): all three are FORWARD against the parent (the counter and the frame
// are created by this commit — one absence, #486); claim 3 is a counterweight, green on both.
// ⚠️ THE LIMIT: whether the tick is felt and the frame read as "now I edit" is a DEVICE PROBE
// (NEEDS-FOUNDER-VERIFY: hold a note 0.3 s — a light tick, the grid gets a thin frame; slide;
// lift — the frame goes; a quick swipe still scrolls with no tick).

import Foundation
import XCTest

final class TheNoteGridSaysWhenTheHoldArmsTests: XCTestCase {

    func testTheArmedHoldTicksAndFramesTheGrid() throws {
        let code = try source("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        guard let leaf = code.range(of: "private struct PartNoteCanvas: View {"),
              let counter = code.range(of: "@State private var armCount = 0") else {
            return XCTFail("ANCHOR MISSING: the canvas leaf or its arm counter")
        }
        XCTAssertLessThan(leaf.lowerBound, counter.lowerBound, "the counter lives in the canvas leaf")
        XCTAssertTrue(code.contains(".sensoryFeedback(.impact(weight: .light), trigger: armCount)"),
                      "the counter is the trigger of one light tick")
        let changed = try body(of: ".onChanged { value in", in: code)
        XCTAssertTrue(changed.contains("if case .second(true, nil) = value { armCount &+= 1 }"),
                      "the tick fires when the hold arms, before any slide")
        let frame = try body(of: ".overlay {", in: code)
        XCTAssertTrue(frame.contains("if live != nil {") && frame.contains(".allowsHitTesting(false)"),
                      "the frame follows the self-resetting gesture state and never catches a touch")
    }

    func testTheSlideItselfStillWritesNothing() throws {
        let code = try source("Sources/Echoelmusic/Studio/PartNoteEditor.swift")
        let updating = try body(of: ".updating($live) {", in: code)
        XCTAssertFalse(updating.contains("armCount"), "the per-sample closure writes only its own state")
        XCTAssertTrue(code.contains("LongPressGesture(minimumDuration: 0.3)"), "the hold is unchanged")
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

    private struct AnchorMissing: Error { let anchor: String }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else { throw AnchorMissing(anchor: anchor) }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex, depth > 0 {
            if code[index] == "{" { depth += 1 } else if code[index] == "}" { depth -= 1 }
            index = code.index(after: index)
        }
        return String(code[start.upperBound..<index])
    }
}

// ThePartDragTicksOnEachBarTests.swift
// Echoel — UX audit 2026-10-02, slice 13b: a part being dragged on the arrange canvas gives one
// light haptic tick each time its preview snaps to another bar.
//
// WHAT IT GUARDS. The drag moves a part by whole bars (`ArrangeCanvas.dropTick`), but the hand had
// nothing to feel: the snap was visible only. `ArrangePartBlock` now carries
// `.sensoryFeedback(.selection, trigger: landing)`, where `landing` is the SNAPPED drop tick the
// preview already draws. The trigger is the point of this file: a trigger on the raw finger
// (`dragPoints`) would fire on every frame of the drag, a buzz instead of a grid.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. It proves where the modifier sits and what
// triggers it — never that the phone's Taptic Engine plays it, or how it feels. That is a device
// probe. NEEDS-FOUNDER-VERIFY: Piece → hold a part until it lifts → slide slowly across three
// bars: three light ticks, one per bar; a small wobble inside a bar gives none.
//
// GRADING (#433, parent = the tree before this slice): claim 1 is a FORWARD guard — the parent
// has ZERO `sensoryFeedback` in `ArrangeCanvasView.swift` (measured), so it is red there by
// absence. Claims 2 and 3 are COUNTERWEIGHTS, green on both trees: `landing` is still the snapped
// drop tick, and the file still holds exactly one `@GestureState`. Stripper `SourceText.codeOnly`:
// TRAGEND on claim 3 (measured: `@GestureState` occurs 4 times raw, once stripped — three are
// prose in the file's comments), PROPHYLACTIC on claims 1 and 2 (0 of their verdicts flip).

import Foundation
import XCTest

final class ThePartDragTicksOnEachBarTests: XCTestCase {

    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    private func partBlock() throws -> String {
        let file = try source(Self.canvas)
        guard let start = file.range(of: "struct ArrangePartBlock: View {") else {
            throw AnchorMissing(reason: "`struct ArrangePartBlock: View {` is gone (#454)")
        }
        return String(file[start.upperBound...])
    }

    // MARK: - Claim 1 — one haptic, triggered by the snapped landing, never the finger

    func testTheTickFollowsTheSnappedLanding() throws {
        let block = try partBlock()
        XCTAssertEqual(block.components(separatedBy: ".sensoryFeedback(").count - 1, 1,
                       "one haptic on the part block")
        XCTAssertTrue(block.contains(".sensoryFeedback(.selection, trigger: landing)"),
                      "a light selection tick, triggered by the bar the part would land on")
        XCTAssertFalse(block.contains("trigger: dragPoints"),
                       "a trigger on the raw finger fires every frame — a buzz, not a grid")
    }

    // MARK: - Claim 2 — COUNTERWEIGHT: `landing` is the snapped drop tick the preview draws

    func testTheLandingIsTheSnappedDropTick() throws {
        let block = try partBlock()
        XCTAssertTrue(block.contains("let landing = ArrangeCanvas.dropTick(startTick: startTick, dragPoints: dragPoints,"),
                      "`landing` is grid-snapped by `dropTick` (a bar, or a beat or step once zoomed — AE-11) — the trigger only changes once per cell")
    }

    // MARK: - Claim 3 — COUNTERWEIGHT: still one finger-rate state in the file

    func testTheHapticAddsNoState() throws {
        let file = try source(Self.canvas)
        XCTAssertEqual(file.components(separatedBy: "@GestureState").count - 1, 1,
                       "the tick reads the existing landing; it adds no state of its own")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

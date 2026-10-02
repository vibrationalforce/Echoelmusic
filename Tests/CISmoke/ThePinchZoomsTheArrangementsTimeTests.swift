// ThePinchZoomsTheArrangementsTimeTests.swift
// Echoel — DAW shell S9a (founder 2026-10-02, inbox E18 „Zeit zoomen"): two fingers spread the
// song's TIME on the Arrange canvas; the text size has its buttons and no gesture.
//
// WHAT THIS PINS.
// 1. END-TO-END BEHAVIOUR (`ArrangeCanvas.zoomed`, pure, nonisolated): a pinch multiplies the
//    zoom and the result stays inside `zoomRange`; zoom 1 (the whole song in the visible width) is
//    the floor; a pinch that reports nothing usable (NaN, infinity, zero, negative) leaves the
//    zoom where it was; a zoom that is itself out of range or not finite is clamped first. The
//    VoiceOver zoom action steps through the SAME function by 2 and ½, so it is covered here too.
// 2. SOURCE (`ArrangeTimeZoom`): the pinch is `@GestureState` (it resets itself on release or
//    cancel), it is SIMULTANEOUS (a part's hold-and-slide and the plate's vertical scroll keep
//    working), the content is the visible width times the zoom, the VoiceOver zoom action exists,
//    and the leaf reads nothing but its own two values — no store, position, selection, clock or
//    persistence (the zoom is a view of the song, not an edit).
// 3. SOURCE (the canvas): the ruler, the lanes AND the playhead sit inside the ONE zoom — so the
//    numbers and the line stay on their bars at every zoom — and the names stand outside it.
//    The two-column shape itself is pinned by `TheArrangeCanvasNamesItsBarsTests` claim 3.
// 4. SOURCE (one gesture, one meaning): no ancestor of the canvas carries a magnify gesture any
//    more — until S9a the text-size pinch sat on `SurfaceHost`, the canvas's ancestor, so a time
//    pinch would have resized the text under it. That the text size's ONE writer is now its
//    three buttons is pinned by `TheTextSizeHasButtonsTests` claim 4.
//
// Grading (§0, no Swift toolchain): `ArrangeTimeZoom`, `ArrangeCanvas.zoomRange` and
// `ArrangeCanvas.zoomed` do not exist on the parent (`88058461d`), so this file does not compile
// there — no assertion has a verdict on that tree; every claim is a FORWARD guard, one absence
// (#486). Hand-transcribed into Python against the working tree: claim 1's cases driven through a
// re-implementation of `zoomed` (CGFloat `clamped(to:)` maps NaN to the lower bound,
// `Core/FloatingPointClamp.swift`); claims 2–4 with mutants — the pinch as `@State`, `.gesture(`
// for `.simultaneousGesture(`, the playhead moved out of the zoom, a `@AppStorage` zoom, a
// magnify gesture back on `SurfaceHost` — each red.
// NOT covered (DEVICE PROBE): that the bars spread under the fingers, that one finger then pans
// along the song while the names stay put, that a part's hold-and-slide still moves it by whole
// bars at every zoom, and that the plate's vertical scroll still works with the canvas zoomed.
// NEEDS-FOUNDER-VERIFY: Arrange with an 8-bar song → spread two fingers on the lanes: the bars
// widen, the numbers stay on them, the names stay put; one finger pans along; pinch back to the
// whole song; text size is unchanged throughout (Project → Text size is its one control).

import CoreGraphics
import Foundation
import XCTest
@testable import Echoelmusic

final class ThePinchZoomsTheArrangementsTimeTests: XCTestCase {

    private static let zoomPath = "Sources/Echoelmusic/Studio/ArrangeTimeZoom.swift"
    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    /// The files that hold the canvas's ancestors: the root (`WorkspaceView`, which mounts
    /// `SurfaceHost` and the text-size modifier), the shell (`StageShell`, `ArrangeStage`), the
    /// Workstation that mounts the canvas, and the studio file where `StudioZoom` lives.
    private static let ancestorPaths = [
        "Sources/Echoelmusic/Studio/WorkspaceView.swift",
        "Sources/Echoelmusic/Studio/SurfaceSwitcher.swift",
        "Sources/Echoelmusic/Studio/StageShell.swift",
        "Sources/Echoelmusic/Studio/WorkstationView.swift",
        "Sources/Echoelmusic/Studio/EchoelStudioView.swift",
    ]

    // MARK: 1 — the zoom arithmetic, pure

    func testAPinchMultipliesTheZoomInsideItsRange() {
        let range = ArrangeCanvas.zoomRange
        XCTAssertEqual(range.lowerBound, 1, "zoom 1 is the whole song in the visible width — the floor")
        XCTAssertGreaterThan(range.upperBound, range.lowerBound, "there is room to zoom in")
        XCTAssertTrue(range.upperBound.isFinite)
        XCTAssertEqual(ArrangeCanvas.zoomed(1, by: 1), 1, "no pinch, no change")
        XCTAssertEqual(ArrangeCanvas.zoomed(1, by: 2), Swift.min(2, range.upperBound), "a spread widens the bars")
        XCTAssertEqual(ArrangeCanvas.zoomed(range.upperBound, by: 0.5), range.upperBound / 2,
                       "a pinch narrows them again")
        XCTAssertEqual(ArrangeCanvas.zoomed(range.upperBound, by: 4), range.upperBound, "never past the ceiling")
        XCTAssertEqual(ArrangeCanvas.zoomed(1, by: 0.25), 1, "never narrower than the whole song")
        XCTAssertEqual(ArrangeCanvas.zoomed(1, by: 1000), range.upperBound)
    }

    func testAnUnusablePinchLeavesTheZoomWhereItWas() {
        let range = ArrangeCanvas.zoomRange
        let mid = (range.lowerBound + range.upperBound) / 2
        let factors: [CGFloat] = [.nan, .infinity, -.infinity, 0, -2]
        for factor in factors {
            XCTAssertEqual(ArrangeCanvas.zoomed(mid, by: factor), mid,
                           "a pinch reporting \(factor) must not move the zoom")
        }
    }

    func testAZoomOutOfRangeIsClampedFirst() {
        let range = ArrangeCanvas.zoomRange
        XCTAssertEqual(ArrangeCanvas.zoomed(range.upperBound * 10, by: 1), range.upperBound)
        XCTAssertEqual(ArrangeCanvas.zoomed(range.lowerBound / 10, by: 1), range.lowerBound)
        XCTAssertEqual(ArrangeCanvas.zoomed(.nan, by: 1), range.lowerBound, "a NaN zoom falls back to the whole song")
        let zooms: [CGFloat] = [.nan, .infinity, -.infinity, 0, -3]
        let factors: [CGFloat] = [.nan, 0.5, 2, .infinity]
        for zoom in zooms {
            for factor in factors {
                let result = ArrangeCanvas.zoomed(zoom, by: factor)
                XCTAssertTrue(result.isFinite && range.contains(result),
                              "zoomed(\(zoom), by: \(factor)) = \(result) — every result is a width the canvas can draw")
            }
        }
    }

    // MARK: 2 — the zoom leaf

    func testTheZoomIsALeafWithAGestureLocalPinch() throws {
        let file = try source(Self.zoomPath)
        guard let start = file.range(of: "struct ArrangeTimeZoom<Content: View>: View {") else {
            return XCTFail("ANCHOR MISSING: `ArrangeTimeZoom` (#454)")
        }
        let leaf = String(file[start.upperBound...])
        XCTAssertTrue(leaf.contains("@GestureState private var pinch: CGFloat = 1"),
                      "the live pinch resets itself when the gesture ends or a scroll view cancels it")
        XCTAssertTrue(leaf.contains("@State private var zoom: CGFloat = 1"), "the zoom at rest starts at the whole song")
        XCTAssertEqual(leaf.components(separatedBy: "@State ").count - 1, 1, "one resting value")
        XCTAssertEqual(leaf.components(separatedBy: "@GestureState ").count - 1, 1, "one live value")
        XCTAssertTrue(leaf.contains("let shown = ArrangeCanvas.zoomed(zoom, by: pinch)"),
                      "what is drawn is the resting zoom times the live pinch, through the one rule")
        XCTAssertTrue(leaf.contains(".containerRelativeFrame(.horizontal) { width, _ in width * shown }"),
                      "the content is the visible width times the zoom")
        XCTAssertTrue(leaf.contains(".simultaneousGesture("),
                      "simultaneous, so a part's hold-and-slide and the plate's scroll keep working")
        XCTAssertFalse(leaf.contains(".gesture(") || leaf.contains(".highPriorityGesture("),
                       "an exclusive pinch would take the touches the parts and the scroll need")
        XCTAssertTrue(leaf.contains("MagnifyGesture()"))
        XCTAssertTrue(leaf.contains(".updating($pinch) { value, state, _ in state = value.magnification }"))
        XCTAssertTrue(leaf.contains(".onEnded { value in zoom = ArrangeCanvas.zoomed(zoom, by: value.magnification) }"),
                      "the zoom changes ONCE, on release, through the same rule")
        XCTAssertTrue(leaf.contains(".accessibilityZoomAction { action in"),
                      "VoiceOver can zoom the time axis too — it is never pinch-only")
        XCTAssertTrue(leaf.contains("ArrangeCanvas.zoomed(zoom, by: action.direction == .zoomIn ? 2 : 0.5)"))
        for banned in ["@Environment", "@AppStorage", "UserDefaults", "currentTick", "player", "timeline",
                       "selection", "TimelineView(", "Timer", ".sheet", ".fullScreenCover", "Task {"] {
            XCTAssertFalse(leaf.contains(banned), """
                `ArrangeTimeZoom` contains `\(banned)`. The zoom is a VIEW of the song, not an edit: it \
                reads nothing but its own two values, persists nothing and presents nothing, so its \
                finger-rate churn stays in this leaf.
                """)
        }
        XCTAssertEqual(occurrencesInSources(of: "static let zoomRange"), 1, "one zoom range (#416)")
        XCTAssertEqual(occurrencesInSources(of: "static func zoomed("), 1, "one zoom rule (#416)")
    }

    // MARK: 3 — the canvas zooms the time and keeps the names

    func testTheRulerTheLanesAndThePlayheadShareTheZoom() throws {
        let file = try source(Self.canvasPath)
        guard let canvas = file.range(of: "struct ArrangeCanvasView: View {"),
              let canvasEnd = file.range(of: "struct ArrangeBarRuler: View {", range: canvas.upperBound..<file.endIndex) else {
            return XCTFail("ANCHOR MISSING: `ArrangeCanvasView` before `ArrangeBarRuler` (#454)")
        }
        let body = String(file[canvas.upperBound..<canvasEnd.lowerBound])
        XCTAssertEqual(occurrencesInSources(of: "ArrangeTimeZoom {"), 1, "one time zoom, on the canvas")
        guard let zoom = body.range(of: "ArrangeTimeZoom {") else {
            return XCTFail("the canvas no longer mounts `ArrangeTimeZoom`")
        }
        XCTAssertNotNil(sequence(["laneRow(row, selected: selected)", "}", "}",
                                  ".overlay(alignment: .leading) {", "ArrangePlayheadView(songTicks: songTicks)", "}", "}"],
                                 in: String(body[zoom.upperBound...])),
                        "the playhead overlays the zoomed stack of ruler and lanes, unpadded — it moves with the bars")
        XCTAssertEqual(body.components(separatedBy: "ArrangePlayheadView(").count - 1, 1)
        XCTAssertFalse(body.contains(".padding(.leading, Self.nameWidth"),
                       "an offset past the names belongs to the old one-column canvas; inside the zoom it would shift the line off its bar")
        XCTAssertEqual(body.components(separatedBy: "nameGutter(row)").count - 1, 1, "one name per track")
        guard let name = body.range(of: "nameGutter(row)") else { return XCTFail("the names are gone") }
        XCTAssertLessThan(name.lowerBound, zoom.lowerBound, "the names stand OUTSIDE the zoom — they stay put while the time spreads")
    }

    // MARK: 4 — one gesture, one meaning

    func testNoAncestorOfTheCanvasCarriesAPinch() throws {
        for path in Self.ancestorPaths {
            let code = try source(path)
            XCTAssertFalse(code.isEmpty, "ANCHOR MISSING: \(path) (#454)")
            for gesture in ["MagnifyGesture", "MagnificationGesture"] {
                XCTAssertFalse(code.contains(gesture), """
                    \(path) carries `\(gesture)`. It holds an ancestor of the Arrange canvas, whose \
                    two-finger spread zooms TIME — a pinch up here would fight it (until S9a the \
                    text-size pinch did, from `SurfaceHost`). The text size has its buttons.
                    """)
            }
        }
        XCTAssertTrue(try source(Self.zoomPath).contains("MagnifyGesture()"),
                      "counterweight: the pinch exists — in the time zoom")
    }

    // MARK: helpers

    /// Where `tokens` occur in order with nothing but whitespace between them, or nil.
    private func sequence(_ tokens: [String], in text: String) -> Range<String.Index>? {
        var from = text.startIndex
        while let first = text.range(of: tokens[0], range: from..<text.endIndex) {
            var end = first.upperBound
            var matched = true
            for token in tokens.dropFirst() {
                guard let next = text.range(of: token, range: end..<text.endIndex),
                      text[end..<next.lowerBound].allSatisfy(\.isWhitespace) else { matched = false; break }
                end = next.upperBound
            }
            if matched { return first.lowerBound..<end }
            from = first.upperBound
        }
        return nil
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    /// How often `needle` occurs in the CODE of every Swift file under `Sources/`.
    private func occurrencesInSources(of needle: String) -> Int {
        let sources = repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            return -1
        }
        var count = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            count += SourceText.codeOnly(text).components(separatedBy: needle).count - 1
        }
        return count
    }
}

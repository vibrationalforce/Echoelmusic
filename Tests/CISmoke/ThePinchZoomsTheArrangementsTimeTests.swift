// ThePinchZoomsTheArrangementsTimeTests.swift
// Echoel — DAW shell S9a (founder 2026-10-02, inbox E16 „Zeit zoomen"): two fingers spread the
// song's TIME on the Arrange canvas; the text size has its buttons and no gesture.
//
// WHAT THIS PINS.
// 1. END-TO-END BEHAVIOUR (`ArrangeCanvas.zoomed`, pure, nonisolated): a pinch multiplies the
//    zoom and the result stays inside `zoomRange`; zoom 1 (the whole song in the visible width) is
//    the floor; a pinch that reports nothing usable (NaN, infinity, zero, negative) leaves the
//    zoom where it was; a zoom that is itself out of range or not finite is clamped first. The
//    buttons and the assistive zoom action step through the SAME function by 2 and ½.
// 1b. END-TO-END BEHAVIOUR (`ArrangeCanvas.anchoredOffset`, pure, nonisolated — S9a review MED-1
//    and MED-2): the song position under the fingers stays under them while the zoom changes; the
//    offset never leaves what the new content can scroll; zoom 1 always lands on offset 0, so no
//    shifted view survives a return to the whole song; unusable inputs fall back to the left edge.
// 2. SOURCE (`ArrangeTimeZoom`): the pinch is `@GestureState` (it resets itself on release or
//    cancel), it is SIMULTANEOUS (a part's hold-and-slide and the plate's vertical scroll keep
//    working), the content is the visible width times the zoom, the scroll position FOLLOWS the
//    pinch through `anchoredOffset`, the pan offset is kept in an unobserved reference (the
//    offset itself rebuilds nothing), a cancelled pinch forgets its start, two 44 pt buttons zoom with one finger
//    (MED-6, WCAG 2.5.1) and are dimmed at the ends, and the leaf reads nothing but its own values
//    — no store, song position, selection, clock or persistence (the zoom is a view, not an edit).
// 3. SOURCE (the canvas): the ruler, the lanes AND the playhead sit inside the ONE zoom — so the
//    numbers and the line stay on their bars at every zoom — the names stand outside it, and no
//    modifier sits on the zoom that could shift the time column against the names (review LOW-13).
//    The two-column shape itself is pinned by `TheArrangeCanvasNamesItsBarsTests` claim 3.
// 4. SOURCE (one gesture, one meaning): no ANCESTOR of the canvas carries a magnify gesture — the
//    root (`WorkspaceView`), `SurfaceHost`, `StageShell`, `ArrangeStage` and `WorkstationView`.
//    Until S9a the text-size pinch sat on `SurfaceHost`, so a time pinch would have resized the
//    text under it. Scoped to those DECLARATIONS, not to their files (review LOW-10): a sibling
//    stage in the same file is no ancestor and may have its own pinch (#364). That `StudioZoom`
//    carries no gesture and the text size's ONE writer is its three buttons is pinned by
//    `TheTextSizeHasButtonsTests` claim 4.
//
// Grading (§0, no Swift toolchain). Parent of the review repair = `4414ad4cd`:
// `ArrangeCanvas.anchoredOffset` does not exist there, so this file does not compile against it —
// no assertion has a verdict there; claim 1b is a FORWARD guard (one absence, #486). Hand-
// transcribed into Python against both trees instead: claim 1 green on both (unchanged
// arithmetic); claim 2 RED on 4414ad4cd for its named reasons — no scroll position, no follow, no
// buttons, `@State` count 1 — one finding, the repair itself (#486); claim 3 green on both (the
// counterweight, #343); claim 4 green on both — on 4414ad4cd it was file-wide and also green, so
// it is a REGRESSION guard against the pinch's return, not a forward one (review LOW-12 corrected
// the S9a grading, which booked it FORWARD). Claim 1b's cases driven through a re-implementation
// of `anchoredOffset` (CGFloat `clamped(to:)` maps NaN to the lower bound,
// `Core/FloatingPointClamp.swift`); claims 2–4 with mutants — the pinch as `@State`, `.gesture(`
// for `.simultaneousGesture(`, `@Observable` on the viewport, the follow call dropped from
// `.onChanged`, the cancel reset dropped, a button under 44 pt, an undimmed button, the playhead
// moved out of the zoom, a magnify gesture on `SurfaceHost` or `ArrangeStage` — each red; a
// magnify gesture on a sibling declaration in `StageShell.swift` stays green, on purpose.
// NOT covered (DEVICE PROBE): that the bars spread under the fingers on glass, that one finger then
// pans along the song while the names stay put, that the buttons step the zoom around the middle,
// that a part's hold-and-slide moves it on the grid the zoom can show — bars, then beats, then
// steps (GMMW AE-11; `TheArrangeCanvasMovesAPartByDraggingTests` claim 5) — (and only as far as the
// visible bars — a stated limit in the leaf's header), that VoiceOver offers the zoom action on the
// scroll view at all, and that the plate's vertical scroll still works with the canvas zoomed.
// NEEDS-FOUNDER-VERIFY: Arrange with an 8-bar song → spread two fingers over bar 5: bar 5 stays
// under the fingers while the bars widen, the numbers stay on them, the names stay put; one finger
// pans; pinch back to the whole song and nothing stays shifted; „Zoom in" / „Zoom out" do the same
// with one finger and dim at the ends; text size is unchanged throughout (Project → Text size).

import CoreGraphics
import Foundation
import XCTest
@testable import Echoelmusic

final class ThePinchZoomsTheArrangementsTimeTests: XCTestCase {

    private static let zoomPath = "Sources/Echoelmusic/Studio/ArrangeTimeZoom.swift"
    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    /// The canvas's ANCESTORS, as (file, declaration header): the root, the surface host, the
    /// shell and the Arrange stage, and the Workstation that mounts the canvas. A declaration, not
    /// a file — a sibling stage that shares a file is no ancestor (review LOW-10, #364).
    private static let ancestors: [(path: String, header: String)] = [
        ("Sources/Echoelmusic/Studio/WorkspaceView.swift", "struct WorkspaceView: View {"),
        ("Sources/Echoelmusic/Studio/SurfaceSwitcher.swift", "struct SurfaceHost: View {"),
        ("Sources/Echoelmusic/Studio/StageShell.swift", "struct StageShell: View {"),
        ("Sources/Echoelmusic/Studio/StageShell.swift", "struct ArrangeStage: View {"),
        ("Sources/Echoelmusic/Studio/WorkstationView.swift", "struct WorkstationView: View {"),
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

    // MARK: 1b — the scroll offset follows the fingers, pure

    func testThePositionUnderTheFingersStaysUnderThem() {
        let width: CGFloat = 300
        // Zoom 1 → 2 around the middle: the middle of the song stays in the middle.
        XCTAssertEqual(ArrangeCanvas.anchoredOffset(0, anchor: 150, from: 1, to: 2, width: width), 150, accuracy: 1e-9)
        // Around the left edge nothing moves; around the right edge the right end stays.
        XCTAssertEqual(ArrangeCanvas.anchoredOffset(0, anchor: 0, from: 1, to: 4, width: width), 0, accuracy: 1e-9)
        XCTAssertEqual(ArrangeCanvas.anchoredOffset(0, anchor: width, from: 1, to: 2, width: width), width, accuracy: 1e-9,
                       "the right end of the song stays at the right edge")
        // The invariant itself: the content point under the anchor, measured in zoom-1 units, is
        // the same before and after — wherever it is not clamped by the ends of the content.
        let zooms: [CGFloat] = [1, 1.5, 2, 3, 4, 8]
        let anchors: [CGFloat] = [0, 37.5, 150, 299]
        for old in zooms {
            for new in zooms {
                for anchor in anchors {
                    for fraction: CGFloat in [0, 0.25, 0.5, 1] {
                        let offset = width * (old - 1) * fraction
                        let result = ArrangeCanvas.anchoredOffset(offset, anchor: anchor, from: old, to: new, width: width)
                        XCTAssertTrue(result >= 0 && result <= width * (new - 1) + 1e-9, """
                            anchoredOffset(\(offset), anchor: \(anchor), \(old)→\(new)) = \(result) — outside \
                            what the new content can scroll
                            """)
                        let target = (offset + anchor) * new / old - anchor
                        if target >= 0, target <= width * (new - 1) {
                            XCTAssertEqual((result + anchor) / new, (offset + anchor) / old, accuracy: 1e-9, """
                                the song position under the fingers moved: \(old)→\(new), anchor \(anchor), offset \(offset)
                                """)
                        }
                    }
                }
            }
        }
    }

    func testBackAtTheWholeSongNothingStaysShifted() {
        let width: CGFloat = 320
        let offsets: [CGFloat] = [0, 10, 160, 320, 2240]
        let anchors: [CGFloat] = [0, 100, 320]
        for offset in offsets {
            for anchor in anchors {
                XCTAssertEqual(ArrangeCanvas.anchoredOffset(offset, anchor: anchor, from: 8, to: 1, width: width), 0,
                               "zoom 1 shows the whole song — its only offset is 0 (review MED-2)")
            }
        }
        // A spread and the same pinch back return to where they started.
        let out = ArrangeCanvas.anchoredOffset(0, anchor: 80, from: 1, to: 4, width: width)
        XCTAssertEqual(ArrangeCanvas.anchoredOffset(out, anchor: 80, from: 4, to: 1, width: width), 0, accuracy: 1e-9)
    }

    func testAnUnusableViewportFallsBackToTheLeftEdge() {
        let widths: [CGFloat] = [0, -10, .nan, .infinity]
        for width in widths {
            XCTAssertEqual(ArrangeCanvas.anchoredOffset(50, anchor: 10, from: 1, to: 2, width: width), 0,
                           "no usable width (\(width)) — the offset is the left edge")
        }
        let width: CGFloat = 300
        let unusable: [CGFloat] = [.nan, .infinity, -.infinity, -40]
        for bad in unusable {
            for result in [ArrangeCanvas.anchoredOffset(bad, anchor: 150, from: 2, to: 4, width: width),
                           ArrangeCanvas.anchoredOffset(100, anchor: bad, from: 2, to: 4, width: width),
                           ArrangeCanvas.anchoredOffset(100, anchor: 150, from: bad, to: 4, width: width),
                           ArrangeCanvas.anchoredOffset(100, anchor: 150, from: 2, to: bad, width: width)] {
                XCTAssertTrue(result.isFinite && result >= 0 && result <= width * (ArrangeCanvas.zoomRange.upperBound - 1),
                              "an input of \(bad) produced \(result) — every offset is one the scroll view can take")
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
        XCTAssertTrue(leaf.contains("@State private var position = ScrollPosition(x: 0)"),
                      "the leaf owns the scroll position, so the zoom can keep the fingers' bar under them")
        XCTAssertTrue(leaf.contains("@State private var viewport = Viewport()"))
        XCTAssertEqual(leaf.components(separatedBy: "@State ").count - 1, 3, "zoom, position, viewport — nothing else")
        XCTAssertEqual(leaf.components(separatedBy: "@GestureState ").count - 1, 1, "one live value")
        XCTAssertTrue(leaf.contains("private final class Viewport {"), """
            the pan offset arrives at SCROLL rate; it lives in a plain reference SwiftUI does not \
            observe, so the offset itself rebuilds nothing
            """)
        for observed in ["@Observable", "ObservableObject", "@Published"] {
            XCTAssertFalse(leaf.contains(observed), "an observed viewport would rebuild the lanes on every scrolled point")
        }
        XCTAssertTrue(leaf.contains("let shown = ArrangeCanvas.zoomed(zoom, by: pinch)"),
                      "what is drawn is the resting zoom times the live pinch, through the one rule")
        XCTAssertTrue(leaf.contains(".containerRelativeFrame(.horizontal) { width, _ in width * shown }"),
                      "the content is the visible width times the zoom")
        XCTAssertTrue(leaf.contains(".scrollPosition($position)"))
        XCTAssertTrue(leaf.contains(".scrollBounceBehavior(.basedOnSize, axes: .horizontal)"),
                      "a song that fits does not scroll — no disabled state that could hold a stale offset")
        XCTAssertTrue(leaf.contains(".onScrollGeometryChange(for: CGRect.self)"))
        XCTAssertTrue(leaf.contains("viewport.offset = now.minX") && leaf.contains("viewport.width = now.width"),
                      "the scroll view's offset and visible width reach the zoom")
        XCTAssertTrue(leaf.contains(".simultaneousGesture("),
                      "simultaneous, so a part's hold-and-slide and the plate's scroll keep working")
        XCTAssertFalse(leaf.contains(".gesture(") || leaf.contains(".highPriorityGesture("),
                       "an exclusive pinch would take the touches the parts and the scroll need")
        XCTAssertTrue(leaf.contains("MagnifyGesture()"))
        XCTAssertTrue(leaf.contains(".updating($pinch) { value, state, _ in state = value.magnification }"))
        XCTAssertTrue(leaf.contains(".onChanged { value in follow(value.magnification, at: value.startAnchor) }"),
                      "the scroll position follows the pinch while the fingers move (review MED-1)")
        guard let ended = leaf.range(of: ".onEnded { value in"),
              let endedClose = leaf.range(of: "\n            )", range: ended.upperBound..<leaf.endIndex) else {
            return XCTFail("ANCHOR MISSING: the pinch's `.onEnded` (#454)")
        }
        let onEnded = String(leaf[ended.upperBound..<endedClose.lowerBound])
        XCTAssertTrue(onEnded.contains("zoom = ArrangeCanvas.zoomed(zoom, by: value.magnification)"),
                      "the zoom changes ONCE, on release, through the same rule")
        XCTAssertTrue(onEnded.contains("viewport.pinchStart = nil"))
        XCTAssertTrue(leaf.contains(".onChange(of: pinch) { _, now in") && leaf.contains("if now == 1 { viewport.pinchStart = nil }"), """
            a cancelled pinch never reaches `onEnded`; without the reset its start would anchor the NEXT pinch
            """)
        guard let follow = leaf.range(of: "private func follow(_ magnification: CGFloat, at anchor: UnitPoint) {"),
              let stepFn = leaf.range(of: "private func step(by factor: CGFloat) {") else {
            return XCTFail("ANCHOR MISSING: `follow` / `step` (#454)")
        }
        let followBody = String(leaf[follow.upperBound..<stepFn.lowerBound])
        XCTAssertTrue(followBody.contains("let start = viewport.pinchStart ?? (offset: viewport.offset, zoom: zoom)"),
                      "the pinch measures from where it STARTED, not from the offset it is moving")
        XCTAssertTrue(followBody.contains("ArrangeCanvas.anchoredOffset(start.offset, anchor: anchor.x * viewport.width,"))
        XCTAssertTrue(followBody.contains("position.scrollTo(x:"))
        let stepBody = String(leaf[stepFn.upperBound...].prefix(600))
        XCTAssertTrue(stepBody.contains("ArrangeCanvas.anchoredOffset(viewport.offset, anchor: viewport.width / 2,"),
                      "a button steps around the middle of the view")
        XCTAssertTrue(stepBody.contains("position.scrollTo(x: offset)"))
        XCTAssertTrue(leaf.contains(".accessibilityZoomAction { action in"))
        XCTAssertTrue(leaf.contains("step(by: action.direction == .zoomIn ? 2 : 0.5)"))
        // One finger is enough (review MED-6, WCAG 2.5.1): two buttons, word plus symbol, 44 pt,
        // dimmed where they cannot move (#164/#227).
        XCTAssertTrue(leaf.contains(#"zoomButton("Zoom out", systemImage: "minus.magnifyingglass","#))
        XCTAssertTrue(leaf.contains("enabled: zoom > ArrangeCanvas.zoomRange.lowerBound) { step(by: 0.5) }"))
        XCTAssertTrue(leaf.contains(#"zoomButton("Zoom in", systemImage: "plus.magnifyingglass","#))
        XCTAssertTrue(leaf.contains("enabled: zoom < ArrangeCanvas.zoomRange.upperBound) { step(by: 2) }"))
        XCTAssertTrue(leaf.contains("Label(word, systemImage: systemImage)"), "symbol plus word (rule 3)")
        XCTAssertTrue(leaf.contains(".frame(minWidth: 44, minHeight: 44)"), "a 44 pt target")
        XCTAssertTrue(leaf.contains(".disabled(!enabled)"))
        for banned in ["@Environment", "@AppStorage", "UserDefaults", "currentTick", "player", "timeline",
                       "selection", "TimelineView(", "Timer", ".sheet", ".fullScreenCover", "Task {"] {
            XCTAssertFalse(leaf.contains(banned), """
                `ArrangeTimeZoom` contains `\(banned)`. The zoom is a VIEW of the song, not an edit: it \
                reads nothing but its own values, persists nothing and presents nothing, so its \
                finger-rate churn stays in this leaf.
                """)
        }
        XCTAssertEqual(occurrencesInSources(of: "static let zoomRange"), 1, "one zoom range (#416)")
        XCTAssertEqual(occurrencesInSources(of: "static func zoomed("), 1, "one zoom rule (#416)")
        // ⚠️ TWO anchor rules since DAW shell S9b: `NoteGridZoom.anchoredOffset` keeps the note
        // grid's step under the fingers, in COLUMN widths over a content that may be narrower
        // than the view, where this one works in zoom factors over a content never narrower.
        // The formula is the same and the units are not, so they are a declared TWIN (its header
        // says so, `TheNoteGridZoomsItsTimeTests` drives it), not a silent copy. This count did
        // not move with S9b and stood red on a correct tree until 2026-10-08 (invisible in the
        // `tail -200` job log). It now pins the arrangement's ONE rule and the twin's ONE, so a
        // THIRD spelling still goes red. ⭐ Open: one shared pure core for both (GMMW cleanup).
        XCTAssertEqual(occurrencesInSources(of: "static func anchoredOffset("), 2,
                       "one anchor rule for the arrangement and its declared note-grid twin (#416)")
        XCTAssertEqual(occurrencesInSources(of: "static func anchoredOffset(_ offset: CGFloat"), 1,
                       "the arrangement's anchor rule is declared once (#416)")
        XCTAssertEqual(occurrencesInSources(of: "static func anchoredOffset(_ offset: Double"), 1,
                       "the note grid's twin is declared once (#416)")
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
                                  ".overlay(alignment: .leading) {", "ArrangePlayheadView(songTicks: songTicks)", "}", "}", "}"],
                                 in: String(body[zoom.upperBound...])), """
            the playhead overlays the zoomed stack of ruler and lanes, unpadded — it moves with the bars; \
            and the zoom closes straight into the column stack, so no modifier (a padding, a frame) sits \
            on `ArrangeTimeZoom` and shifts the time column against the names (review LOW-13)
            """)
        XCTAssertEqual(body.components(separatedBy: "ArrangePlayheadView(").count - 1, 1)
        XCTAssertFalse(body.contains(".padding(.leading, Self.nameWidth"),
                       "an offset past the names belongs to the old one-column canvas; inside the zoom it would shift the line off its bar")
        XCTAssertEqual(body.components(separatedBy: "nameGutter(row)").count - 1, 1, "one name per track")
        guard let name = body.range(of: "nameGutter(row)") else { return XCTFail("the names are gone") }
        XCTAssertLessThan(name.lowerBound, zoom.lowerBound, "the names stand OUTSIDE the zoom — they stay put while the time spreads")
    }

    // MARK: 4 — one gesture, one meaning

    func testNoAncestorOfTheCanvasCarriesAPinch() throws {
        for ancestor in Self.ancestors {
            let code = try source(ancestor.path)
            guard let body = declaration(ancestor.header, in: code) else {
                XCTFail("ANCHOR MISSING: `\(ancestor.header)` in \(ancestor.path) (#454)")
                continue
            }
            for gesture in ["MagnifyGesture", "MagnificationGesture"] {
                XCTAssertFalse(body.contains(gesture), """
                    `\(ancestor.header)` (\(ancestor.path)) carries `\(gesture)`. It is an ancestor of the \
                    Arrange canvas, whose two-finger spread zooms TIME — a pinch up here would fight it \
                    (until S9a the text-size pinch did, from `SurfaceHost`). The text size has its buttons.
                    """)
            }
        }
        XCTAssertTrue(try source(Self.zoomPath).contains("MagnifyGesture()"),
                      "counterweight: the pinch exists — in the time zoom")
    }

    // MARK: helpers

    /// The brace-matched body of the declaration that opens with `header`, or nil.
    private func declaration(_ header: String, in code: String) -> String? {
        guard let open = code.range(of: header) else { return nil }
        var depth = 1
        var index = open.upperBound
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[open.upperBound..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }

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

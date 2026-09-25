// TheSongIsSeenOnOneScaleTests.swift
// Echoel — WA4.5 → WA4 path 4: every track's parts on one shared scale, now selectable.
//
// WHAT THIS PINS. WA4.5 drew a read-only strip under each track row; WA4 path 4 replaced the
// strips with `Studio/ArrangeCanvasView.swift` — all tracks with parts on ONE scale, a part
// selected by tapping it, and a playhead. The pure geometry stayed in
// `Studio/ArrangementStripView.swift` (`ArrangementStrip`). The risks: rows on their own scale
// (not an arrangement), an overlap drawn differently from how it is heard (a second precedence
// rule, #1440), and a position read that turns the canvas or the Workstation body into a hot
// reader (10.76.41/50).
//
// 1. END-TO-END (pure) over `TimelineDocument`: the scale is the song's length in whole bars;
//    blocks sit at start/length fractions of it; overlapping parts are ordered start-then-
//    placement (the order `activeRegion` resolves in, so the part that plays is drawn on top);
//    an empty song draws nothing; the spoken form names bars the way the Session view does.
// 2. END-TO-END (pure): the canvas draws exactly the non-bio tracks with parts; the playhead
//    fraction is nil without a scale and pinned to 0…1 otherwise.
// 3. SOURCE: the canvas reads no player, no position and no song from the store, and has no
//    drag of its own; the playhead is its own self-driving leaf that selects nothing and
//    launches nothing; the Workstation is the one door and mounts no strip any more.
//    ⚠️ WA4 path D moved the "no drag" half: dragging a part is now real, and it lives in the
//    `ArrangePartBlock` leaf AFTER the playhead in the same file, so the playhead slice below
//    stops at that declaration. The drag's own claims are in
//    `TheArrangeCanvasMovesAPartByDraggingTests`.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 transcribed into Python over a
// model of `ArrangementStrip`, `ArrangeCanvas`, `TrackParts.parts` and
// `WorkstationSummary.lengthBars`; claim 3 driven against this tree. On the parent (f43bfe505)
// `ArrangeCanvas` does not exist, so the bundle does not build there — ONE absence (#486);
// claims 2–3 are FORWARD guards, claim 1 a COUNTERWEIGHT (unchanged, green on both trees).
// NOT covered: that the canvas renders, lines up, and a tap lands on a narrow part at every
// width — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation with two or more tracks with parts — the rows line up bar
// for bar, an overlapping later part shows on top, tapping a part outlines it and opens its
// track, and the playhead line moves while the timeline plays.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSongIsSeenOnOneScaleTests: XCTestCase {

    private static let stripPath = "Sources/Echoelmusic/Studio/ArrangementStripView.swift"
    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let bar = TimelineTime.ticksPerBar

    // One fixture VALUE per lane — never a factory (#1419).
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)

    // MARK: 1 — the scale, the blocks, the order

    func testEveryTrackIsDrawnOnTheSongsScale() {
        let clip = UUID()
        // Keys: bars 1–2. Loop: bars 3–4 and a half-bar tail — the song is 5 bars long.
        let keys = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                  startTick: 0, lengthTicks: 2 * Self.bar)
        let loop = TimelineRegion(laneID: Self.loopLane.id, clipID: clip,
                                  startTick: 2 * Self.bar, lengthTicks: 2 * Self.bar + Self.bar / 2)
        let doc = TimelineDocument(lanes: [Self.keysLane, Self.loopLane], regions: [keys, loop])
        let summary = WorkstationSummary(document: doc)
        let scale = ArrangementStrip.songTicks(summary)
        XCTAssertEqual(scale, 5 * Self.bar, "the scale is the song rounded up to whole bars")

        let keyBlocks = ArrangementStrip.blocks(onLane: Self.keysLane.id, in: doc, songTicks: scale)
        let loopBlocks = ArrangementStrip.blocks(onLane: Self.loopLane.id, in: doc, songTicks: scale)
        XCTAssertEqual(keyBlocks, [ArrangementStrip.Block(id: keys.id, start: 0, width: 0.4)])
        XCTAssertEqual(loopBlocks.count, 1)
        XCTAssertEqual(loopBlocks.first?.start ?? -1, 0.4, accuracy: 1e-12)
        XCTAssertEqual(loopBlocks.first?.width ?? -1, 0.5, accuracy: 1e-12)
    }

    func testAnOverlapIsDrawnInTheOrderItIsHeard() {
        let clip = UUID()
        let under = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                   startTick: 0, lengthTicks: 4 * Self.bar)
        let over = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                  startTick: Self.bar, lengthTicks: Self.bar)
        // Placed in reverse: `over` first in the array, but it starts later.
        let doc = TimelineDocument(lanes: [Self.keysLane], regions: [over, under])
        let blocks = ArrangementStrip.blocks(onLane: Self.keysLane.id, in: doc, songTicks: 4 * Self.bar)
        XCTAssertEqual(blocks.map(\.id), [under.id, over.id],
                       "the later-starting part is drawn last, on top — it is the one that plays")
        XCTAssertEqual(TimelineScheduling.activeRegion(in: doc, laneID: Self.keysLane.id,
                                                       at: Self.bar)?.id, over.id,
                       "premise: activeRegion gives bar 2 to the later start")
    }

    func testAnEmptySongDrawsNothingAndNothingEscapesTheScale() {
        let clip = UUID()
        let part = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                  startTick: 3 * Self.bar, lengthTicks: 4 * Self.bar)
        let doc = TimelineDocument(lanes: [Self.keysLane], regions: [part])
        XCTAssertTrue(ArrangementStrip.blocks(onLane: Self.keysLane.id, in: doc, songTicks: 0).isEmpty)
        // A scale shorter than the part (a caller's mistake) clamps rather than overflowing.
        let clamped = ArrangementStrip.blocks(onLane: Self.keysLane.id, in: doc, songTicks: 4 * Self.bar)
        XCTAssertEqual(clamped.count, 1)
        XCTAssertEqual(clamped.first?.start ?? -1, 0.75, accuracy: 1e-12)
        XCTAssertEqual(clamped.first?.width ?? -1, 0.25, accuracy: 1e-12)
        // Entirely past the scale: no sliver claiming a place it does not have.
        XCTAssertTrue(ArrangementStrip.blocks(onLane: Self.keysLane.id, in: doc,
                                              songTicks: 2 * Self.bar).isEmpty)
    }

    func testTheStripSaysWhereThePartsStart() {
        let clip = UUID()
        let regions = (0..<8).map {
            TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                           startTick: $0 * Self.bar, lengthTicks: Self.bar)
        }
        let doc = TimelineDocument(lanes: [Self.keysLane], regions: Array(regions.prefix(2)))
        XCTAssertEqual(ArrangementStrip.spoken(onLane: Self.keysLane.id, in: doc),
                       "Parts at Bar 1, Bar 2")
        let long = TimelineDocument(lanes: [Self.keysLane], regions: regions)
        XCTAssertEqual(ArrangementStrip.spoken(onLane: Self.keysLane.id, in: long),
                       "Parts at Bar 1, Bar 2, Bar 3, Bar 4, Bar 5, Bar 6, and 2 more")
        let empty = TimelineDocument(lanes: [Self.keysLane], regions: [])
        XCTAssertEqual(ArrangementStrip.spoken(onLane: Self.keysLane.id, in: empty), "No parts")
    }

    // MARK: 2 — the canvas rows and the playhead position (pure)

    func testTheCanvasDrawsTracksWithPartsAndPinsThePlayhead() {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let clip = UUID()
        let doc = TimelineDocument(
            lanes: [bio, Self.keysLane, Self.loopLane],
            regions: [TimelineRegion(laneID: bio.id, clipID: clip, startTick: 0, lengthTicks: Self.bar),
                      TimelineRegion(laneID: Self.keysLane.id, clipID: clip, startTick: 0,
                                     lengthTicks: Self.bar)])
        XCTAssertEqual(ArrangeCanvas.rows(WorkstationSummary(document: doc)).map(\.id), [Self.keysLane.id],
                       "a bio curve is not an arrangement, and an empty track has no row")

        let song = 4 * Self.bar
        XCTAssertNil(ArrangeCanvas.playheadFraction(tick: 0, songTicks: 0), "no scale, no playhead")
        XCTAssertEqual(ArrangeCanvas.playheadFraction(tick: 2 * Self.bar, songTicks: song), 0.5)
        XCTAssertEqual(ArrangeCanvas.playheadFraction(tick: -10, songTicks: song), 0)
        XCTAssertEqual(ArrangeCanvas.playheadFraction(tick: 9 * Self.bar, songTicks: song), 1,
                       "a loop running past the end pins to the end instead of leaving the canvas")
    }

    // MARK: 3 — source: a cold canvas, a self-driving playhead, one door

    func testTheCanvasIsColdAndThePlayheadIsItsOwnLeaf() throws {
        let file = try source(Self.canvasPath)
        guard let canvasStart = file.range(of: "struct ArrangeCanvasView: View {"),
              let playheadStart = file.range(of: "struct ArrangePlayheadView: View {"),
              let blockStart = file.range(of: "struct ArrangePartBlock: View {"),
              canvasStart.upperBound < playheadStart.lowerBound,
              playheadStart.upperBound < blockStart.lowerBound else {
            return XCTFail("ANCHOR MISSING: the canvas, playhead and part-block declarations (#454)")
        }
        let canvas = String(file[canvasStart.upperBound..<playheadStart.lowerBound])
        let playhead = String(file[playheadStart.upperBound..<blockStart.lowerBound])

        XCTAssertTrue(canvas.contains("ArrangementStrip.blocks(onLane: row.id, in: document, songTicks: songTicks)"),
                      "one geometry rule: the canvas places parts by the pinned pure half (#416)")
        XCTAssertTrue(canvas.contains("selection.selectRegion(block.id, in: document)"),
                      "a tap selects through the ONE selection owner")
        XCTAssertTrue(canvas.contains("ArrangePlayheadView(songTicks: songTicks)"))
        for banned in ["currentTick", "player", "timeline.", "TimelineRegion(", "TimelineDocument(",
                       "Timer", "DragGesture", "TimelineView("] {
            XCTAssertFalse(canvas.contains(banned), """
                ArrangeCanvasView contains `\(banned)`. The canvas is a cold picture of the \
                document plus the selection: no position read (the hot-state law), no read of \
                the store (it holds it only to COMMIT a drop), no clock, and no drag of its own \
                — the finger-rate state lives in `ArrangePartBlock`.
                """)
        }

        XCTAssertTrue(playhead.contains("TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing))"),
                      "the playhead self-drives, and stops redrawing while the timeline is stopped")
        XCTAssertTrue(playhead.contains("player.currentTick"))
        XCTAssertTrue(playhead.contains(".allowsHitTesting(false)"),
                      "the line over the parts must not swallow the taps that select them")
        for banned in ["selection", "timeline.", "player.play(", "player.stop()", "relocate", "launch"] {
            XCTAssertFalse(playhead.contains(banned),
                           "ArrangePlayheadView contains `\(banned)` — it shows the position and does nothing else")
        }

        let strip = try source(Self.stripPath)
        XCTAssertTrue(strip.contains("summary.lengthBars * TimelineTime.ticksPerBar"),
                      "the scale is the summary's song length — the number the song line prints")
        XCTAssertTrue(strip.contains("TrackParts.parts(onLane: laneID, in: document)"),
                      "draw order is the parts list's order — one ordering rule")
        XCTAssertTrue(strip.contains("SessionGrid.label(forTick:"),
                      "bars are named by the one label rule (#416)")
        XCTAssertFalse(strip.contains(": View"), "the strip file is the pure geometry now; the canvas draws")
    }

    func testTheWorkstationIsTheOneDoor() throws {
        let workstation = try source(Self.workstationPath)
        XCTAssertEqual(workstation.components(separatedBy: "ArrangeCanvasView(").count - 1, 1)
        XCTAssertTrue(workstation.contains("let arrangeRows = ArrangeCanvas.rows(summary)"),
                      "the rows are the pure rule's rows — never a bio curve, never an empty track")
        XCTAssertTrue(workstation.contains("songTicks: ArrangementStrip.songTicks(summary))"),
                      "every row gets the SAME scale, or the rows do not line up")
        let doors = try filesMatching { code, _ in code.contains("ArrangeCanvasView(") }
        XCTAssertEqual(doors, [Self.workstationPath])
        let strips = try filesMatching { code, _ in code.contains("ArrangementStripView(") }
        XCTAssertEqual(strips, [], "one picture of the song: the per-row strips went with the canvas")
    }

    // MARK: Source helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func filesMatching(_ matches: (String, String) -> Bool) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            let path = Self.sourcesRoot + "/" + relative
            let url = root.appendingPathComponent(relative)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text), path) { hits.append(path) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}

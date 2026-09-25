// TheSongIsSeenOnOneScaleTests.swift
// Echoel — WA4.5: every track's parts drawn across the song, on one shared scale.
//
// WHAT THIS PINS. `Studio/ArrangementStripView.swift` draws, under each Workstation track row
// with parts, where that track plays in the song. The risks: a strip on its own scale (rows
// that do not line up are not an arrangement), an overlap drawn differently from how it is
// heard (a second precedence rule, #1440), and a playhead read that turns the Workstation body
// into a hot reader (10.76.41/50).
//
// 1. END-TO-END (pure) over `TimelineDocument`: the scale is the song's length in whole bars;
//    blocks sit at start/length fractions of it; overlapping parts are ordered start-then-
//    placement (the order `activeRegion` resolves in, so the part that plays is drawn on top);
//    an empty song draws nothing; the spoken form names bars the way the Session view does.
// 2. SOURCE: the strip reads no player, no store, no environment and no playhead, and has no
//    control; the Workstation mounts it once, for non-bio tracks with parts, and is its door.
//
// Grading (§0, no Swift toolchain in a web session): claim 1 was transcribed into Python over
// a model of `ArrangementStrip`, `TrackParts.parts` and `WorkstationSummary.lengthBars`; claim
// 2 was driven against this tree. On the parent (0faea6e66) `ArrangementStrip` does not exist,
// so the bundle does not build there — ONE absence, not N findings (#486).
// NOT covered: that the strips render, line up and read well at every width — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation with two or more tracks with parts — the strips line up
// bar for bar, and an overlapping later part shows on top.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSongIsSeenOnOneScaleTests: XCTestCase {

    private static let stripPath = "Sources/Echoelmusic/Studio/ArrangementStripView.swift"
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

    // MARK: 2 — source: a cold picture with one door

    func testTheStripIsAColdPictureOfTheDocument() throws {
        let code = try source(Self.stripPath)
        XCTAssertTrue(code.contains("TrackParts.parts(onLane: laneID, in: document)"),
                      "draw order is the parts list's order — one ordering rule")
        XCTAssertTrue(code.contains("SessionGrid.label(forTick:"),
                      "bars are named by the one label rule (#416)")
        XCTAssertTrue(code.contains("summary.lengthBars * TimelineTime.ticksPerBar"),
                      "the scale is the summary's song length — the number the song line prints")
        for banned in ["@Environment", "player", "currentTick", "timeline.", "Button(",
                       "onTapGesture", "gesture(", "Timer", "TimelineRegion(", "TimelineDocument("] {
            XCTAssertFalse(code.contains(banned), """
                ArrangementStripView contains `\(banned)`. It is a read-only picture of the \
                document it is handed: no playhead (the hot-state law), no store, no control.
                """)
        }
    }

    func testTheWorkstationIsTheOneDoor() throws {
        let workstation = try source(Self.workstationPath)
        XCTAssertEqual(workstation.components(separatedBy: "ArrangementStripView(").count - 1, 1)
        XCTAssertTrue(workstation.contains("if !row.isBio && row.regionCount > 0 {"),
                      "a strip only for a track with parts to show, never for a bio curve")
        XCTAssertTrue(workstation.contains("songTicks: ArrangementStrip.songTicks(summary))"),
                      "every row gets the SAME scale, or the rows do not line up")
        let doors = try filesMatching { code, _ in code.contains("ArrangementStripView(") }
        XCTAssertEqual(doors, [Self.workstationPath])
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

// TheSessionIsAGridOfTracksAndScenesTests.swift
// P2 (founder 2026-10-16, „integrierten Performance Modus" — Ableton level): the Session view is
// Live's grid — a column per track, a row per scene, the scene's launch at the row's head, an
// empty slot where a scene leaves a track to the piece. Before, each scene was a card listing
// only the tracks that had a part in it, so a track sat in a different place in every card and
// the eye could not follow one track down the scenes.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · All three claims are SOURCE-TEXT SCANS of `SessionLaunchView` (its members are private on
//     a `View`). The launch behaviour behind the cells is pinned elsewhere and unchanged
//     (`TheSceneLaunchIsASwitchTests`, `TheSessionLaunchesWhatTheSongPlaysTests`).
//   · NOT CLAIMED (DEVICE PROBE): that the columns line up at every Dynamic Type size and that
//     the sideways scroll is found. NEEDS-FOUNDER-VERIFY (P2): Session view with three tracks
//     and four scenes — does each track stay in its column, and does the grid scroll sideways?
//
// HONEST GRADING against the parent (§3): claims 1–3 are REGRESSIONS on the parent — no
// horizontal scroll, no header row, no empty slot, and the scene card was a `VStack` — each red
// for the reason its message names. No new symbol, so the file compiles on both trees. The
// counterweight inside claim 3 (one `launchRegion` call site, the scene seam) is green on both.
// Mutants: drop the header (1) · cells only where a part exists (2) · scene launch outside the
// row (3) · a second launch call site (3).

import Foundation
import XCTest

final class TheSessionIsAGridOfTracksAndScenesTests: XCTestCase {

    // MARK: 1 — a header row names every column, and the grid scrolls sideways

    func testEveryTrackHasAColumnUnderItsName() throws {
        let view = try source()
        guard let grid = view.range(of: "ScrollView(.horizontal, showsIndicators: false) {"),
              let header = view.range(of: "ForEach(tracks) { track in\n                                Text(track.name)",
                                      range: grid.upperBound..<view.endIndex),
              let rows = view.range(of: "ForEach(scenes.prefix(SessionGrid.sceneLimit)) { scene in",
                                    range: grid.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: the sideways grid, its header or its scene rows (#408)")
        }
        XCTAssertLessThan(header.lowerBound, rows.lowerBound, "the track names head the grid, above the scenes")
        XCTAssertTrue(view.contains(".frame(width: Self.cellColumn, alignment: .leading)"),
                      "a header is exactly one column wide, so it stands over its cells")
    }

    // MARK: 2 — every scene row has a slot for every track

    func testEveryRowHasASlotForEveryTrack() throws {
        let row = try member("private func sceneBlock(", in: source())
        guard let each = row.range(of: "ForEach(tracks) { track in"),
              let cell = row.range(of: "if let regionID = scene.cells[track.id] {", range: each.upperBound..<row.endIndex),
              let slot = row.range(of: "} else {", range: cell.upperBound..<row.endIndex) else {
            return XCTFail("ANCHOR MISSING: the per-track loop, its cell or its empty slot (#408)")
        }
        let empty = String(row[slot.upperBound...])
        XCTAssertTrue(empty.contains(".frame(width: Self.cellColumn, height: 44)"),
                      "the empty slot holds the column open, so the next cell does not slide left")
        XCTAssertTrue(empty.contains(".accessibilityHidden(true)"), "an empty slot has nothing to launch")
        XCTAssertFalse(row.contains("ForEach(tracks.filter { scene.cells[$0.id] != nil })"),
                       "the old card listed only the tracks with a part — a track then moved between scenes")
    }

    // MARK: 3 — the scene's launch heads its row; the launch paths are unchanged

    func testTheSceneLaunchHeadsItsRowAndTheLaunchPathsAreUnchanged() throws {
        let view = try source()
        let row = try member("private func sceneBlock(", in: view)
        guard let head = row.range(of: "return HStack(spacing: 6) {"),
              let launch = row.range(of: "launchScene(scene)", range: head.upperBound..<row.endIndex),
              let cells = row.range(of: "ForEach(tracks) { track in", range: head.upperBound..<row.endIndex) else {
            return XCTFail("ANCHOR MISSING: the row, its scene launch or its cells (#408)")
        }
        XCTAssertLessThan(launch.lowerBound, cells.lowerBound, "the scene's launch stands at the row's head, as in Live")
        XCTAssertTrue(row.contains(".frame(width: Self.sceneColumn, alignment: .leading)"))
        XCTAssertTrue(row.contains(".frame(minHeight: 44)"), "a 44-pt scene target")
        // counterweights — the cells still launch through the one player call, the scene through its own
        XCTAssertEqual(view.components(separatedBy: "player.launchRegion(regionID, quantize: SessionGrid.quantize)").count - 1, 1)
        XCTAssertTrue(view.contains(".accessibilityLabel(String(localized: \"Launch scene at \") + title)"))
    }

    // MARK: helpers

    private struct AnchorMissing: Error {}

    private func source() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = "Sources/Echoelmusic/Studio/SessionLaunchView.swift"
        guard let text = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(path) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }
}

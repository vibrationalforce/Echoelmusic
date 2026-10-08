//
//  TheSelectedPartJoinsThroughOneUndoStepTests.swift
//  Arrangement editing, Production group of the product law (S8, 2026-10-08). `TimelineStore`
//  has carried `mergeRegionWithNext` — the lossless inverse of Split — since the clip game of
//  2026-07-15, with NO production caller since the clip menu it lived in was deleted (#121). The
//  selected-part bar now offers it as "Join next". This guard pins the three things that make
//  the verb honest: the join is the store's own `abuts` decision (lane, clip, media contiguity,
//  gain, warp), it is ONE history step, and the bar asks the same tempo Split asks.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · BEHAVIOUR (claims 1–2) — the shipped store: split → join restores one part of the original
//    length under one `undo()`; a second half whose start was trimmed and moved back is refused.
//  · SOURCE (claims 3–5) — the bar's button calls `mergeRegionWithNext` through
//    `PartSplit.mediaBPM` like Split; the enabled state is `canMergeRegionWithNext`; exactly one
//    production caller; `combineRegions` still has none, because `WorkstationSelection` holds ONE
//    region — a "Combine selected" verb needs the selection first, not a button.
//  · NOT PINNED, and said so: the row's layout at every type size, the icon, VoiceOver —
//    device (G-series ask in FOUNDER_INBOX §2 for the next build).
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): claim 5 does not forbid a multi-selection or a
//  Combine verb. It names today's fact so that whoever builds the selection flips the claim in the
//  same commit as the verb — never the verb alone over a single selection.
//
//  GRADING (#433/#464), parent tree 7bd36a4 (docs): claims 1–2 drive shipped store code that
//  exists on both trees — green on both, COUNTERWEIGHTS (the store was always able to do this;
//  what was missing was the door). Claim 3 is RED on the parent for its named reason (no
//  "Join next", no `join(`); claim 4 is RED on the parent (zero callers of
//  `mergeRegionWithNext(`); claim 5 is green on both. Claims 3–5 transcribed in Python against
//  `git show HEAD:…` and the worktree; claims 1–2 cannot run here (no toolchain) and were
//  checked by reading `split(at:bpm:)`, `abuts(_:bpm:)`, `snapshotForUndo` and `undo()`.
//  ⚠️ The first draft of claims 4–5 counted the DECLARATIONS in `TimelineStore` as callers and
//  was red on both trees for the wrong reason (#367); the needles now carry the receiver dot.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSelectedPartJoinsThroughOneUndoStepTests: XCTestCase {

    // MARK: 1 — split, join, one undo

    func testJoinIsTheInverseOfSplitUnderOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [part]))

        timeline.splitRegion(id: part.id, atTick: bar, bpm: 120)
        XCTAssertEqual(timeline.document.regions.count, 2, "ANCHOR: the split made two parts")
        XCTAssertTrue(timeline.canMergeRegionWithNext(id: part.id, bpm: 120), "the first half can join its other half")
        XCTAssertTrue(timeline.canMergeRegionWithNext(id: part.id, bpm: 97),
                      "a split keeps a tick twin, so the tempo does not decide whether the halves abut (M1b)")

        timeline.mergeRegionWithNext(id: part.id, bpm: 120)
        XCTAssertEqual(timeline.document.regions.count, 1, "joined into one part")
        XCTAssertEqual(timeline.document.regions.first?.id, part.id, "the first half keeps its identity")
        XCTAssertEqual(timeline.document.regions.first?.lengthTicks, 2 * bar, "and spans both halves again")

        timeline.undo()
        XCTAssertEqual(timeline.document.regions.count, 2, "ONE undo step brings the split back")
        XCTAssertTrue(timeline.document.regions.contains { $0.startTick == bar },
                      "the second half returns where it was")
    }

    // MARK: 2 — a half that was trimmed is refused, not joined lossily

    func testATrimmedOtherHalfIsRefused() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [part]))
        timeline.splitRegion(id: part.id, atTick: bar, bpm: 120)
        guard let second = timeline.document.regions.first(where: { $0.startTick == bar }) else {
            return XCTFail("ANCHOR: the second half exists")
        }

        // Trim the second half's start by a beat, then move it back so the TICKS abut again:
        // the media offsets no longer line up, and a join would silently drop the trim.
        timeline.trimRegionStart(id: second.id, toTick: bar + bar / 4, bpm: 120)
        timeline.moveRegion(id: second.id, toStartTick: bar)
        XCTAssertEqual(timeline.document.regions.first(where: { $0.id == second.id })?.startTick, bar,
                       "ANCHOR: the halves abut on the grid again")
        XCTAssertFalse(timeline.canMergeRegionWithNext(id: part.id, bpm: 120),
                       "abutting ticks are not enough — the media must be contiguous (lossless or nothing)")
        let before = timeline.document.regions
        timeline.mergeRegionWithNext(id: part.id, bpm: 120)
        XCTAssertEqual(timeline.document.regions, before, "a refused join changes nothing")
    }

    // MARK: 3 — the bar's verb is the store's verb, at Split's tempo

    func testTheBarOffersJoinNextThroughTheStoreAtSplitsTempo() throws {
        let bar = SourceText.codeOnly(try Self.source("Sources/Echoelmusic/Studio/SelectedPartBar.swift"))
        let editStart = try XCTUnwrap(bar.range(of: "private func editRow("), "the edit row exists")
        let editEnd = try XCTUnwrap(bar.range(of: "private func trimStartLabel(", range: editStart.upperBound..<bar.endIndex))
        let edit = String(bar[editStart.lowerBound..<editEnd.lowerBound])
        XCTAssertTrue(edit.contains("button(\"Join next\", \"arrow.triangle.merge\", enabled: joinable,"),
                      "the verb sits in the edit row, enabled by the store's own answer")
        XCTAssertTrue(edit.contains("if joinable { join(regionID) }"), "a lit button joins; a dim one does nothing")

        let joinStart = try XCTUnwrap(bar.range(of: "private func join(_ regionID: UUID) {"))
        let joinEnd = try XCTUnwrap(bar.range(of: "private func split(", range: joinStart.upperBound..<bar.endIndex))
        let join = String(bar[joinStart.lowerBound..<joinEnd.lowerBound])
        XCTAssertTrue(join.contains("PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),"),
                      "Join asks the tempo Split asks — one definition of the media tempo (#416)")
        XCTAssertTrue(join.contains("timeline.mergeRegionWithNext(id: regionID, bpm: bpm)"),
                      "and hands the decision to the store, which re-checks `abuts` before writing")

        XCTAssertTrue(bar.contains("let joinable = timeline.canMergeRegionWithNext(id: regionID, bpm: player.preflightTempo)"),
                      "the enabled state is the store's `canMergeRegionWithNext`, not a second spelling of `abuts`")
    }

    // MARK: 4 — exactly one production caller

    func testTheStoreVerbHasExactlyOneProductionCaller() throws {
        let callers = try Self.sourceFiles().filter {
            // The dotted form is a CALL; the declaration in `TimelineStore` has no receiver (#408).
            SourceText.codeOnly(try Self.source($0)).contains(".mergeRegionWithNext(id:")
        }
        XCTAssertEqual(callers, ["Sources/Echoelmusic/Studio/SelectedPartBar.swift"],
                       "the join verb has one door, the selected-part bar — found \(callers)")
    }

    // MARK: 5 — counterweight: Combine waits for a multi-selection

    func testCombineStillWaitsForAMultiSelection() throws {
        let callers = try Self.sourceFiles().filter {
            SourceText.codeOnly(try Self.source($0)).contains(".combineRegions(ids:")
        }
        let selection = SourceText.codeOnly(try Self.source("Sources/Echoelmusic/Studio/WorkstationSelection.swift"))
        XCTAssertTrue(selection.contains("public private(set) var regionID: UUID?"),
                      "the selection holds ONE part today")
        XCTAssertEqual(callers, [], """
            `combineRegions(ids:)` gained a production caller while `WorkstationSelection` still holds \
            one `regionID`. A Combine verb over a single selection is a button that can never light; \
            build the multi-selection first and move this claim with it. Found: \(callers)
            """)
    }

    // MARK: - helpers

    private static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every Swift file under `Sources/`, repo-relative, sorted.
    private static func sourceFiles() throws -> [String] {
        let root = repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var files: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append("Sources" + url.path.replacingOccurrences(of: root.path, with: ""))
        }
        return files.sorted()
    }
}

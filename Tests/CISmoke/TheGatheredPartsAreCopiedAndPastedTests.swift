// TheGatheredPartsAreCopiedAndPastedTests.swift
// A9 (founder 2026-10-16, gap list item 3 "Mehrfachauswahl + Zwischenablage"): the Arrange
// canvas has a Select mode. While it is on, a tap on a part gathers it (or lets it go); Copy keeps
// the gathered parts in memory, Paste places them at the bar Play starts from — the earliest
// there, the others at their distance, each on its own track — as ONE Undo step, and Delete
// removes them as one step. Before, the multi-part store verbs (`removeRegions`) had no door and
// no part could be copied to another place in the song.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on shipped types: the pure paste plan, the real store's
//     `pasteRegions` as one undo step, and `WorkstationSelection`'s gather / copy rules.
//   · Claim 4 is a SOURCE-TEXT SCAN: the bar is mounted over the canvas, a tap in Select mode
//     gathers, Paste reads the cue (never the playhead), and nothing persists the clipboard.
//   · NOT CLAIMED (DEVICE PROBE): how the bar reads and how the rings look. NEEDS-FOUNDER-VERIFY
//     (A9) — the probe is at `ArrangeGatherBar.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`RegionClipboard`,
// `pasteRegions`, `gathering`, `ArrangeGatherBar` are new), so no assertion has a verdict on the
// parent. Hand-transcribed: claims 1–3 are the CAPABILITY plus COUNTERWEIGHTS (a part whose track
// is gone is left out, never re-homed; the clip is shared, not copied; leaving the mode lets
// everything go; an empty paste writes no undo step); claim 4 is a FORWARD guard. Mutants:
// spacing lost (1) · a missing track re-homed (1) · two undo steps (2) · an empty paste
// snapshotted (2) · Done keeps the gathered set (3) · the clipboard persisted (4) · Paste at the
// playhead (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheGatheredPartsAreCopiedAndPastedTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — a paste keeps the spacing and the tracks

    func testAPasteKeepsTheSpacingAndTheTracks() {
        let bar = Self.bar
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let bass = TimelineLane(name: "Bass", kind: .midi)
        let gone = TimelineLane(name: "Gone", kind: .midi)
        let a = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 2 * bar, lengthTicks: 4 * bar)
        let b = TimelineRegion(laneID: bass.id, clipID: UUID(), startTick: 3 * bar, lengthTicks: 2 * bar)
        let c = TimelineRegion(laneID: gone.id, clipID: UUID(), startTick: 2 * bar, lengthTicks: bar)
        let doc = TimelineDocument(lanes: [keys, bass], regions: [a, b])
        let placed = RegionClipboard.pasted([b, a, c], atTick: 10 * bar, in: doc)
        XCTAssertEqual(placed.map(\.startTick), [10 * bar, 11 * bar], "the earliest lands on the bar, the other keeps its distance")
        XCTAssertEqual(placed.map(\.laneID), [keys.id, bass.id], "each part stays on its own track")
        XCTAssertEqual(placed.map(\.clipID), [a.clipID, b.clipID], "the copies SHARE their clips — no new clip slot")
        XCTAssertEqual(placed.map(\.lengthTicks), [4 * bar, 2 * bar])
        XCTAssertTrue(Set(placed.map(\.id)).isDisjoint(with: [a.id, b.id, c.id]), "every copy is a new part")
        XCTAssertFalse(placed.contains { $0.laneID == gone.id }, "a part whose track is gone is left out, never re-homed")
        XCTAssertEqual(RegionClipboard.pasted([b, a], atTick: -50, in: doc).first?.startTick, 0, "never before the song")
        XCTAssertEqual(RegionClipboard.pasted([c], atTick: bar, in: doc), [], "nothing left to land")
        XCTAssertEqual(RegionClipboard.pasted([], atTick: bar, in: doc), [])
    }

    // MARK: 2 — the store pastes as ONE undo step

    func testPasteRegionsIsOneUndoStep() {
        let bar = Self.bar
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let bass = TimelineLane(name: "Bass", kind: .midi)
        let a = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0, lengthTicks: bar)
        let b = TimelineRegion(laneID: bass.id, clipID: UUID(), startTick: bar, lengthTicks: bar)
        timeline.replaceDocument(TimelineDocument(lanes: [keys, bass], regions: [a, b]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        XCTAssertEqual(timeline.pasteRegions([], atTick: 4 * bar), [])
        XCTAssertFalse(timeline.canUndo, "an empty paste writes no undo step")
        let ids = timeline.pasteRegions([a, b], atTick: 4 * bar)
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(timeline.document.regions.count, 4)
        timeline.undo()
        XCTAssertEqual(timeline.document.regions.map(\.id), [a.id, b.id], "ONE Undo takes the whole paste back")
        XCTAssertFalse(timeline.canUndo)
        timeline.removeRegions(ids: [a.id, b.id])
        XCTAssertEqual(timeline.document.regions, [])
        timeline.undo()
        XCTAssertEqual(timeline.document.regions.count, 2, "COUNTERWEIGHT: Delete of the gathered parts is one step too")
    }

    // MARK: 3 — the gather rules

    func testGatheringCopiesWhatIsGatheredAndDoneLetsItGo() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let a = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        let b = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: Self.bar, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [keys], regions: [a, b])
        let selection = WorkstationSelection()
        XCTAssertFalse(selection.gathering)
        selection.setGathering(true)
        selection.toggleGathered(a.id, in: doc)
        selection.toggleGathered(b.id, in: doc)
        selection.toggleGathered(UUID(), in: doc)
        XCTAssertEqual(selection.gathered, [a.id, b.id], "an unknown id gathers nothing")
        selection.toggleGathered(b.id, in: doc)
        XCTAssertEqual(selection.gathered, [a.id], "a second tap lets a part go")
        selection.copyGathered(from: doc)
        XCTAssertEqual(selection.clipboard.map(\.id), [a.id])
        XCTAssertEqual(WorkstationSelection.resolvedGathered([a.id, UUID()], in: doc), [a.id], "stale ids resolve away on read")
        selection.setGathering(false)
        XCTAssertEqual(selection.gathered, [], "Done lets every part go")
        XCTAssertEqual(selection.clipboard.map(\.id), [a.id], "and the copy stays, so it can land anywhere")
        selection.copyGathered(from: doc)
        XCTAssertEqual(selection.clipboard.map(\.id), [a.id], "copying nothing leaves the clipboard as it was")
    }

    // MARK: 4 — the door, the tap, the cue, no persistence

    func testTheBarIsMountedOverTheCanvasAndPastesAtTheCue() throws {
        let view = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "ArrangeGatherBar()").count - 1, 1, "one mount")
        guard let mount = view.range(of: "ArrangeGatherBar()"),
              view.range(of: "ArrangeCanvasView(rows: arrangeRows", range: mount.upperBound..<view.endIndex) != nil else {
            return XCTFail("the gather bar is not mounted above the canvas (#408)")
        }
        let canvas = try source("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        XCTAssertTrue(canvas.contains("onSelect: { selection.gathering ? selection.toggleGathered(block.id, in: document)"),
                      "in Select mode a tap gathers")
        XCTAssertTrue(canvas.contains("isSelected: selection.gathering ? gathered.contains(block.id) : block.id == selected,"),
                      "in Select mode the gathered parts wear the ring, and only they (UI#4)")
        XCTAssertTrue(canvas.contains("if !selection.gathering, let selected, arrangeable, let pair = clips[selected],"),
                      "in Select mode no single part offers its edges")
        let bar = try source("Sources/Echoelmusic/Studio/ArrangeGatherBar.swift")
        XCTAssertTrue(bar.contains("TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)"),
                      "Paste lands on the ruler's bar")
        XCTAssertTrue(bar.contains("timeline.pasteRegions(selection.clipboard, atTick: start)"))
        XCTAssertTrue(bar.contains("timeline.removeRegions(ids: gathered)"))
        XCTAssertFalse(bar.contains("currentTick"), "cold: the playhead is a leaf of its own")
        XCTAssertFalse(bar.contains("EchoelTheme.accent"), "never green — green is the body's signal")
        for banned in ["UIPasteboard", "UserDefaults", "@AppStorage", ".sheet(", ".fullScreenCover("] {
            XCTAssertFalse(bar.contains(banned), "the bar does not use \(banned)")
        }
        let owner = try source("Sources/Echoelmusic/Studio/WorkstationSelection.swift")
        for banned in ["UIPasteboard", "UserDefaults", "@AppStorage"] {
            XCTAssertFalse(owner.contains(banned), "the clipboard is never persisted nor shared (\(banned))")
        }
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}

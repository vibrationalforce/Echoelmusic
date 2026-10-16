// TheAutomationIsDrawnOnTheCanvasTests.swift
// Item 7b (founder 2026-10-16, gap list item 7 "Automation direkt auf dem Canvas"), the edit half:
// "Draw automation" in the canvas's bar turns every track row into an automation row — a tap adds a
// point, a tap on a point removes it, a hold-and-slide moves it — through the Track page's own
// decisions (`SongAutomationEdit`) at the CANVAS's scale, and the one writer `setSongAutomation`.
// The display half is `TheCanvasShowsEachTracksAutomationTests`.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped types: Draw and Select mode exclude each other; a tap at
//     a canvas position becomes a point at that bar through the real store, one Undo step each, and
//     a tap on it removes it.
//   · Claim 3 is a SOURCE-TEXT SCAN: the leaf is mounted only in Draw mode, uses the shared
//     decisions and the one writer, and the canvas still holds one drag and one finger-rate state.
//   · NOT CLAIMED (DEVICE PROBE): how drawing feels under a finger. NEEDS-FOUNDER-VERIFY (7b) — the
//     probe is at `ArrangeAutomationEditLane.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`drawingAutomation`,
// `ArrangeAutomationEditLane` are new), so no assertion has a verdict on the parent. Hand-transcribed:
// claims 1–2 are the CAPABILITY plus COUNTERWEIGHTS (Select still works and still clears; a point
// lands at the canvas's scale, not the song's bare length; the Echoel track offers nothing to draw);
// claim 3 is a FORWARD guard plus the canvas's pins. Mutants: both modes on at once (1) · the bare
// song length as scale (2) · two undo steps (2) · the leaf mounted outside Draw mode (3) · a gesture
// in the canvas file (3) · a second writer (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAutomationIsDrawnOnTheCanvasTests: XCTestCase {

    // MARK: 1 — Draw and Select exclude each other

    func testDrawAndSelectModeExcludeEachOther() {
        let selection = WorkstationSelection()
        XCTAssertFalse(selection.drawingAutomation, "Draw mode is off until asked for")
        selection.setGathering(true)
        selection.setDrawingAutomation(true)
        XCTAssertTrue(selection.drawingAutomation)
        XCTAssertFalse(selection.gathering, "drawing ends Select mode — one tap never means two things")
        selection.setGathering(true)
        XCTAssertFalse(selection.drawingAutomation, "and Select ends Draw mode")
        selection.setDrawingAutomation(false)
        XCTAssertTrue(selection.gathering, "COUNTERWEIGHT: Done on Draw mode leaves Select as it was")
    }

    // MARK: 2 — a tap on the canvas row is a point at that bar, one Undo step; a tap on it removes it

    func testATapOnTheRowAddsAndRemovesAPointThroughTheOneWriter() throws {
        let bar = TimelineTime.ticksPerBar
        let canvasTicks = 12 * bar          // the canvas's length, headroom included
        let width = 1_200.0, height = 68.0  // a row: 100 pt per bar
        let laneID = UUID()
        let key = SongAutomationEdit.key(for: laneID, base: SongAutomationEdit.defaultBase)
        guard case .add(let tick, let value)? = SongAutomationEdit.resolveTap(
            x: 300, y: height * 0.25, width: width, height: height, points: [], songTicks: canvasTicks) else {
            return XCTFail("a tap on empty row space adds a point")
        }
        XCTAssertEqual(tick, 3 * bar, "x 300 of 1 200 on a 12-bar canvas is bar 3 — the canvas's scale")
        XCTAssertEqual(value, 0.75, accuracy: 1e-9, "a quarter down the row is three quarters up")
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(id: laneID, name: "Lead", kind: .midi)], regions: []))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        XCTAssertTrue(timeline.setSongAutomation(SongAutomationEdit.adding(tick: tick, value: value, key: key,
                                                                         to: timeline.document.automation,
                                                                         songTicks: canvasTicks)))
        let points = SongAutomationEdit.points(key, in: timeline.document.automation, songTicks: canvasTicks)
        XCTAssertEqual(points.map(\.tick), [3 * bar])
        guard case .pick(let id)? = SongAutomationEdit.resolveTap(
            x: 300, y: height * 0.25, width: width, height: height, points: points, songTicks: canvasTicks) else {
            return XCTFail("a tap on the point picks it")
        }
        timeline.setSongAutomation(SongAutomationEdit.removing(id, from: timeline.document.automation))
        XCTAssertTrue(timeline.document.automation.isEmpty, "a tap on the point removes it, and its emptied lane")
        timeline.undo()
        XCTAssertEqual(SongAutomationEdit.points(key, in: timeline.document.automation, songTicks: canvasTicks).count, 1,
                       "ONE Undo brings the point back")
        timeline.undo()
        XCTAssertTrue(timeline.document.automation.isEmpty)
        XCTAssertFalse(timeline.canUndo, "two touches, two Undo steps")
    }

    // MARK: 2b — 7c: the Track page's parameter choice is the canvas row's

    func testTheCanvasRowDrawsTheParameterChosenOnTheTrackPage() throws {
        let lane = UUID()
        let bases = ["mix.gain", "ddsp.osc.brightness", "ddsp.filter.cutoff"]
        XCTAssertEqual(SongAutomationEdit.shownBase(chosen: "ddsp.filter.cutoff", for: lane, in: [], among: bases),
                       "ddsp.filter.cutoff", "the chosen parameter wins")
        XCTAssertEqual(SongAutomationEdit.shownBase(chosen: "ddsp.gone", for: lane, in: [], among: bases),
                       SongAutomationEdit.openingBase(for: lane, in: [], among: bases),
                       "a choice the track no longer offers falls back to the opening one")
        XCTAssertEqual(SongAutomationEdit.shownBase(chosen: nil, for: lane, in: [], among: bases),
                       SongAutomationEdit.openingBase(for: lane, in: [], among: bases))
        let selection = WorkstationSelection()
        XCTAssertNil(selection.automationBase(for: lane))
        selection.setAutomationBase("ddsp.filter.cutoff", for: lane)
        XCTAssertEqual(selection.automationBase(for: lane), "ddsp.filter.cutoff")
        let editor = try source("Sources/Echoelmusic/Studio/SongAutomationEditor.swift")
        XCTAssertTrue(editor.contains("if let base { selection.setAutomationBase(base, for: laneID) }"),
                      "the Track page publishes its choice")
        let leaf = try source("Sources/Echoelmusic/Studio/ArrangeAutomationEditLane.swift")
        XCTAssertTrue(leaf.contains("SongAutomationEdit.shownBase(chosen: selection.automationBase(for: laneID),"),
                      "and the canvas row asks the same question")
    }

    // MARK: 3 — mounted in Draw mode only, shared decisions, the one writer, the canvas's pins

    func testTheEditLaneIsMountedInDrawModeThroughTheSharedDecisions() throws {
        let canvas = try source("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        XCTAssertEqual(canvas.components(separatedBy: "ArrangeAutomationEditLane(").count - 1, 1, "one mount")
        let gate = try XCTUnwrap(canvas.range(of: "if selection.drawingAutomation {"))
        let mount = try XCTUnwrap(canvas.range(of: "ArrangeAutomationEditLane(laneID: row.id, songTicks: songTicks)"))
        XCTAssertTrue(gate.upperBound <= mount.lowerBound
                      && canvas.distance(from: gate.upperBound, to: mount.lowerBound) < 60,
                      "the row edits automation only in Draw mode, at the canvas's song length")
        XCTAssertEqual(canvas.components(separatedBy: "@GestureState").count - 1, 1, "COUNTERWEIGHT: one finger-rate state in the canvas file")
        XCTAssertEqual(canvas.components(separatedBy: "DragGesture(").count - 1, 1, "COUNTERWEIGHT: one drag on the canvas")
        let leaf = try source("Sources/Echoelmusic/Studio/ArrangeAutomationEditLane.swift")
        for shared in ["SongAutomationEdit.parameters(on: laneID, in: document,",
                       "SongAutomationEdit.shownBase(chosen: selection.automationBase(for: laneID),",
                       "SongAutomationEdit.resolveTap(", "SongAutomationEdit.resolveMove(",
                       "SongAutomationEdit.adding(", "SongAutomationEdit.moving(", "SongAutomationEdit.removing("] {
            XCTAssertTrue(leaf.contains(shared), "the canvas decides as the Track page does: `\(shared)`")
        }
        XCTAssertEqual(leaf.components(separatedBy: "timeline.setSongAutomation(").count - 1, 3,
                       "add, remove and move — each one commit through the one writer")
        XCTAssertFalse(leaf.contains(".pickerStyle(.menu)"), "no parameter menu under the finger on the canvas")
        let bar = try source("Sources/Echoelmusic/Studio/ArrangeGatherBar.swift")
        XCTAssertTrue(bar.contains("selection.setDrawingAutomation(true)"), "the door")
        XCTAssertTrue(bar.contains("selection.setDrawingAutomation(false)"), "and its Done")
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

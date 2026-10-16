// TheCanvasShowsEachTracksAutomationTests.swift
// Item 7a (founder 2026-10-16, gap list item 7 "Automation direkt auf dem Canvas"), the display
// half: a track's automation is drawn across its own row of the arrangement canvas, at the canvas's
// scale, sampled the way playback reads it. Editing points there is item 7b.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped value types: which curves a row draws, and that a sample
//     is `AutomationLane.value(atTick:)` at the column's tick (holds before/after, the ramp between).
//   · Claim 3 is a SOURCE-TEXT SCAN: the leaf is mounted once in the lane row, takes no gesture, and
//     the canvas still holds exactly one drag and one finger-rate state.
//   · NOT CLAIMED (DEVICE PROBE): how the line reads over the parts. NEEDS-FOUNDER-VERIFY (7a) — the
//     probe is at `ArrangeAutomationTrace.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`ArrangeAutomation` is
// new), so no assertion has a verdict on the parent. Hand-transcribed: claims 1–2 are the CAPABILITY
// plus COUNTERWEIGHTS (another track's, a global and an empty curve are not drawn; no song or one
// column draws nothing; a value never leaves 0…1); claim 3 is a FORWARD guard plus the canvas's two
// existing pins as counterweights. Mutants: a global curve drawn on a row (1) · samples on the song's
// bare length instead of the given one (2) · a second interpolation (2) · a gesture on the leaf (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheCanvasShowsEachTracksAutomationTests: XCTestCase {

    // MARK: 1 — a row draws the curves that name its track

    func testARowDrawsOnlyItsOwnCurves() {
        let synth = UUID()
        let other = UUID()
        let mine = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: synth, base: "ddsp.filter.cutoff"),
                                  points: [AutomationPoint(tick: 0, value: 0.2)])
        let theirs = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: other, base: "ddsp.filter.cutoff"),
                                    points: [AutomationPoint(tick: 0, value: 0.9)])
        let global = AutomationLane(parameter: "ddsp.filter.cutoff", points: [AutomationPoint(tick: 0, value: 0.5)])
        let empty = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: synth, base: "ddsp.brightness"))
        let drawn = ArrangeAutomation.curves(for: synth, in: [mine, theirs, global, empty])
        XCTAssertEqual(drawn.map(\.parameter), [mine.parameter],
                       "a row draws its own curves — never another track's, a global one or an empty one")
    }

    // MARK: 2 — a sample is what playback reads at the column's tick

    func testASampleIsTheValuePlaybackReads() {
        let bar = TimelineTime.ticksPerBar
        let lane = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: UUID(), base: "ddsp.brightness"),
                                  points: [AutomationPoint(tick: 2 * bar, value: 0.25),
                                           AutomationPoint(tick: 6 * bar, value: 0.75)])
        let samples = ArrangeAutomation.samples(of: lane, songTicks: 8 * bar, columns: 9)   // one per bar line
        XCTAssertEqual(samples.map(\.x), (0...8).map { Double($0) / 8 })
        for (i, s) in samples.enumerated() {
            let expected = lane.value(atTick: i * bar) ?? -1
            XCTAssertEqual(s.value, expected, accuracy: 1e-9, "column \(i) is the value playback reads on bar \(i)")
        }
        XCTAssertEqual(samples.first?.value ?? -1, 0.25, accuracy: 1e-9, "it holds the first point before it")
        XCTAssertEqual(samples.last?.value ?? -1, 0.75, accuracy: 1e-9, "and the last one after it")
        XCTAssertTrue(ArrangeAutomation.samples(of: lane, songTicks: 0, columns: 9).isEmpty, "no song draws nothing")
        XCTAssertTrue(ArrangeAutomation.samples(of: lane, songTicks: 8 * bar, columns: 1).isEmpty)
        XCTAssertTrue(samples.allSatisfy { (0...1).contains($0.value) })
        XCTAssertEqual(ArrangeAutomation.columns(forWidth: .nan), 2)
        XCTAssertEqual(ArrangeAutomation.columns(forWidth: 100_000), 512, "bounded for a long, wide piece")
    }

    // MARK: 3 — mounted once in the row, no gesture, the canvas's own pins intact

    func testTheTraceIsMountedInTheRowAndTakesNoTouch() throws {
        let canvas = try source("Sources/Echoelmusic/Studio/ArrangeCanvasView.swift")
        XCTAssertEqual(canvas.components(separatedBy: "ArrangeAutomationTrace(").count - 1, 1, "one mount")
        XCTAssertTrue(canvas.contains("ArrangeAutomationTrace(curves: ArrangeAutomation.curves(for: row.id, in: document.automation),"),
                      "each row draws its own track's curves")
        let row = try XCTUnwrap(canvas.range(of: "private func laneRow("))
        let mount = try XCTUnwrap(canvas.range(of: "ArrangeAutomationTrace("))
        XCTAssertTrue(row.upperBound <= mount.lowerBound, "inside the lane row, at the canvas's song length")
        XCTAssertEqual(canvas.components(separatedBy: "@GestureState").count - 1, 1,
                       "COUNTERWEIGHT: still exactly one finger-rate state in the canvas file")
        XCTAssertEqual(canvas.components(separatedBy: "DragGesture(").count - 1, 1,
                       "COUNTERWEIGHT: still one drag gesture on the canvas")
        let leaf = try source("Sources/Echoelmusic/Studio/ArrangeAutomationTrace.swift")
        XCTAssertTrue(leaf.contains(".allowsHitTesting(false)"), "the parts under it keep their taps and holds")
        for touch in ["Gesture(", "onTapGesture", "setSongAutomation("] {
            XCTAssertFalse(leaf.contains(touch), "the trace shows the curve; it does not edit it (`\(touch)`)")
        }
        XCTAssertTrue(leaf.contains("lane.value(atTick: tick)"), "sampled the way playback reads it — no second interpolation")
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

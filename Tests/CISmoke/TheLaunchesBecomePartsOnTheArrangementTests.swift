// TheLaunchesBecomePartsOnTheArrangementTests.swift
// P4a (founder 2026-10-16, gap list item 6 "Szenen ins Arrangement aufnehmen"), the pure half: a
// log of landed launches (`LaunchTake`) becomes parts on the arrangement — each span as copies of
// the part it played, end to end, the last cut where it ended — and the store writes them as ONE
// undo step through the existing paste writer.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END on shipped value types and the real `TimelineStore`.
//   · NOT CLAIMED: that the player feeds the log — P4b wires it, nothing does today; and how it
//     sounds (DEVICE PROBE, after P4b).
//
// HONEST GRADING against the parent (§3): the file does not compile there (`LaunchTake` is new), so
// no assertion has a verdict on the parent. Hand-transcribed: every claim is the CAPABILITY plus
// COUNTERWEIGHTS (a switch closes the span; a stop writes nothing after it; an empty span, a gone
// part or a gone track writes nothing; the recording plays over the parts under it and one Undo
// takes it back). Mutants: no tiling (1) · last copy not cut (1) · switch leaves the old span open
// (2) · zero-length span written (2) · the gone part written (2) · two undo steps (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLaunchesBecomePartsOnTheArrangementTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    private struct Fixture {
        let lead: TimelineLane
        let bass: TimelineLane
        let loopA: TimelineRegion
        let loopB: TimelineRegion
        let bassLoop: TimelineRegion
        var document: TimelineDocument { TimelineDocument(lanes: [lead, bass], regions: [loopA, loopB, bassLoop]) }
        init() {
            // Built from locals: a struct init may not read `self` before every stored property is set,
            // and the class's `bar` is main-actor isolated, so the constant is named here directly.
            let bar = TimelineTime.ticksPerBar
            let lead = TimelineLane(name: "Lead", kind: .midi)
            let bass = TimelineLane(name: "Bass", kind: .midi, builtinInstrument: .polySynth)
            self.lead = lead
            self.bass = bass
            loopA = TimelineRegion(laneID: lead.id, clipID: UUID(), startTick: 0, lengthTicks: bar)
            loopB = TimelineRegion(laneID: lead.id, clipID: UUID(), startTick: bar, lengthTicks: 2 * bar,
                                   gain: 0.5, transposeSemitones: 3)
            bassLoop = TimelineRegion(laneID: bass.id, clipID: UUID(), startTick: 0, lengthTicks: bar)
        }
    }

    // MARK: 1 — a span is copies of its part, end to end, the last one cut

    func testASpanIsCopiesOfItsPartLaidEndToEnd() {
        let f = Fixture()
        let bar = Self.bar
        var take = LaunchTake()
        take.started(laneID: f.lead.id, regionID: f.loopB.id, atTick: 4 * bar)
        take.finish(atTick: 9 * bar)          // five bars of a two-bar loop
        XCTAssertFalse(take.isOpen)
        XCTAssertEqual(take.spans, [LaunchTake.Span(laneID: f.lead.id, regionID: f.loopB.id,
                                                    startTick: 4 * bar, endTick: 9 * bar)])
        let parts = LaunchTake.regions(for: take.spans, in: f.document)
        XCTAssertEqual(parts.map(\.startTick), [4 * bar, 6 * bar, 8 * bar])
        XCTAssertEqual(parts.map(\.lengthTicks), [2 * bar, 2 * bar, bar], "the last copy is cut where the span ended")
        XCTAssertTrue(parts.allSatisfy { $0.clipID == f.loopB.clipID && $0.laneID == f.lead.id },
                      "the recording points at the music it played — same clip, same track")
        XCTAssertTrue(parts.allSatisfy { $0.gain == 0.5 && $0.transposeSemitones == 3 }, "and plays it the same way")
        XCTAssertEqual(Set(parts.map(\.id)).count, 3)
        XCTAssertFalse(parts.contains { $0.id == f.loopB.id }, "every copy is a new part")
    }

    // MARK: 2 — switches, stops and what writes nothing

    func testSwitchesStopsAndGoneThingsShapeTheSpans() {
        let f = Fixture()
        let bar = Self.bar
        var take = LaunchTake()
        take.started(laneID: f.lead.id, regionID: f.loopA.id, atTick: 0)
        take.started(laneID: f.bass.id, regionID: f.bassLoop.id, atTick: 0)
        take.started(laneID: f.lead.id, regionID: f.loopB.id, atTick: 2 * bar)   // a switch
        take.stopped(laneID: f.bass.id, atTick: 3 * bar)                        // back to the song
        take.started(laneID: f.bass.id, regionID: f.bassLoop.id, atTick: 5 * bar)
        take.stopped(laneID: f.bass.id, atTick: 5 * bar)                        // nothing played
        take.finish(atTick: 4 * bar)
        XCTAssertEqual(take.spans.map(\.regionID), [f.loopA.id, f.bassLoop.id, f.loopB.id])
        XCTAssertEqual(take.spans.map(\.endTick), [2 * bar, 3 * bar, 4 * bar],
                       "a switch closes the old span; a stop closes the track's; finish closes the rest")
        let parts = LaunchTake.regions(for: take.spans, in: f.document)
        XCTAssertEqual(parts.filter { $0.laneID == f.bass.id }.map(\.startTick), [0, bar, 2 * bar],
                       "the bass played three bars, then the arrangement — nothing is written after the stop")
        var gone = f.document
        gone.regions.removeAll { $0.id == f.loopA.id }
        XCTAssertFalse(LaunchTake.regions(for: take.spans, in: gone).contains { $0.clipID == f.loopA.clipID },
                       "a part deleted since writes nothing")
        let noLead = TimelineDocument(lanes: [f.bass], regions: f.document.regions)
        XCTAssertFalse(LaunchTake.regions(for: take.spans, in: noLead).contains { $0.laneID == f.lead.id },
                       "a track deleted since writes nothing")
        XCTAssertTrue(LaunchTake.regions(for: [], in: f.document).isEmpty)
    }

    // MARK: 3 — the store writes the recording as ONE undo step, over the parts under it

    func testTheStoreWritesTheRecordingAsOneUndoStep() {
        let f = Fixture()
        let bar = Self.bar
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(f.document)
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        var take = LaunchTake()
        take.started(laneID: f.lead.id, regionID: f.loopA.id, atTick: 0)
        take.finish(atTick: 3 * bar)
        let parts = LaunchTake.regions(for: take.spans, in: timeline.document)
        let start = parts.map(\.startTick).min() ?? 0
        let ids = timeline.pasteRegions(parts, atTick: start)
        XCTAssertEqual(ids.count, 3)
        let placed = timeline.document.regions.filter { ids.contains($0.id) }
        XCTAssertEqual(placed.map(\.startTick).sorted(), [0, bar, 2 * bar], "pasted at its own ticks")
        XCTAssertEqual(TimelineScheduling.activeRegion(in: timeline.document, laneID: f.lead.id, at: bar + 10)?.id,
                       placed.first { $0.startTick == bar }?.id,
                       "the recording plays instead of the arranged part under it")
        timeline.undo()
        XCTAssertEqual(timeline.document.regions.count, 3, "ONE Undo takes the whole recording back")
        XCTAssertFalse(timeline.canUndo)
    }
}

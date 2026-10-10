// TheAgentKeepsATakeTests.swift
// Echoel — GMMW AI-6a. The agent can do what "Edit a copy" does on the part bar: keep a composer
// part as a part the person owns. Generation stays editable, and the human decides what stays.
//
// WHAT THIS GUARDS.
//   1. BEHAVIOUR: `take.keep` on a composer part adds ONE part the person owns (its clip is not
//      composer-owned, its notes are the composer's), through `TimelineStore.keepComposerTake` —
//      and the agent's Undo removes that part AND frees the grid slot it took.
//   2. BEHAVIOUR: a part the person already owns is refused by name and nothing changes.
//   3. BEHAVIOUR: a kept part a person moved since is left as it is — Undo says so.
//   4. PARSER: `take.keep` takes exactly `part`, like the copy command.
//
// ⚠️ THE LIMIT. No intent posts `take.keep` yet — the Siri phrase is AI-6b (Council copy review).
// Until then the command is reachable only through a planner, and the only shipped planner returns
// what an intent posted. This file proves the command and its Undo, not a door.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentKeepsATakeTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    private func rig(composerOwned: Bool,
                     _ body: (TimelineStore, ClipStore, EchoelCommandExecutor, TimelineRegion) async throws -> Void)
        async rethrows {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            _ = clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 60, startStep: 0), Note(pitch: 67, startStep: 4)]
        let source = Clip(name: "Composed · AI-6a", kind: .midi, melody: MelodyClip(notes: notes),
                          composerOwned: composerOwned)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = source
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "AI-6a", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: source.id, startTick: 0, lengthTicks: 4 * Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        let looks = UserDefaults(suiteName: "echoel.tests.agentKeepsATake") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, clips: clips, selection: WorkstationSelection(),
                                             voiceCapacity: { 4 }, mediaLooks: MediaLookUndo(),
                                             visualDefaults: looks)
        try await body(timeline, clips, executor, region)
    }

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor) -> EchoelActionPlan {
        EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
    }

    func testTheAgentKeepsAComposerPartAndItsUndoFreesTheSlot() async throws {
        try await rig(composerOwned: true) { timeline, clips, executor, region in
            let report = await executor.execute(plan([.keepTake(part: .id(region.id))], on: executor))
            guard case .done = report.steps.first?.outcome else { return XCTFail("the take is kept: \(report)") }
            XCTAssertEqual(timeline.document.regions.count, 2, "one part is added")
            let kept = try XCTUnwrap(timeline.document.regions.first { $0.id != region.id })
            let clip = try XCTUnwrap(clips.clip(id: kept.clipID))
            XCTAssertFalse(clip.composerOwned, "the kept part is the person's")
            XCTAssertEqual(clip.melody?.notes, clips.clip(id: region.clipID)?.melody?.notes)
            XCTAssertTrue(executor.canUndoAgentChange)

            let undo = await executor.execute(plan([.undoAgentChange], on: executor))
            guard case .done = undo.steps.first?.outcome else { return XCTFail("undo runs: \(undo)") }
            XCTAssertEqual(timeline.document.regions.map(\.id), [region.id], "the kept part is gone")
            XCTAssertNil(clips.clip(id: kept.clipID), "and its slot is free again — no orphaned notes")
        }
    }

    func testAPartThePersonOwnsIsRefusedAndNothingChanges() async throws {
        try await rig(composerOwned: false) { timeline, clips, executor, region in
            let before = (timeline.document, clips.slots)
            let report = await executor.execute(plan([.keepTake(part: .id(region.id))], on: executor))
            XCTAssertEqual(report.steps.first?.outcome, .failed(.notAComposerPart))
            XCTAssertEqual(timeline.document, before.0)
            XCTAssertEqual(clips.slots, before.1)
            XCTAssertFalse(executor.canUndoAgentChange)
        }
    }

    func testAKeptPartMovedSinceIsLeftAsItIs() async throws {
        try await rig(composerOwned: true) { timeline, clips, executor, region in
            _ = await executor.execute(plan([.keepTake(part: .id(region.id))], on: executor))
            let kept = try XCTUnwrap(timeline.document.regions.first { $0.id != region.id })
            timeline.moveRegion(id: kept.id, toStartTick: kept.startTick + Self.bar)
            let undo = await executor.execute(plan([.undoAgentChange], on: executor))
            XCTAssertEqual(undo.steps.first?.outcome, .failed(.changedSince("The kept part")))
            XCTAssertTrue(timeline.document.regions.contains { $0.id == kept.id }, "the person's move stays")
            XCTAssertNotNil(clips.clip(id: kept.clipID))
        }
    }

    func testTheParserTakesExactlyAPart() {
        func parse(_ arguments: [String: String]) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: "take.keep", arguments: arguments))
        }
        XCTAssertEqual(parse(["part": "selected"]), .success(.keepTake(part: .selected)))
        XCTAssertEqual(parse(["part": "selected", "times": "4"]), .failure(.unknownArgument("times")))
        XCTAssertEqual(parse([:]), .failure(.invalidArgument("that part")))
        XCTAssertEqual(EchoelCommandRegistry.spec(.keepTake).permission, .reversibleEdit)
    }
}

// TheLevelRequestSeparatesNumberGridAndWriteTests.swift
// Codex review of 9d479f922, point 3: "numerical representation, equality on the display grid,
// and responsibility for a later write are THREE separate questions — test them separately, no
// blanket epsilon repair." This file asks each one of the agent's level path on its own, through
// the production writer (`TrackMix.setLevel` → `TimelineStore.setLaneLevel`), and pins the three
// DIFFERENT answers the shipped code gives:
//   1. REPRESENTATION — the request is computed in Double, the store holds Float. A request whose
//      Float rounding equals the current level is "already at": nothing written, nothing journaled.
//      The Float decides, not the Double the maths produced.
//   2. DISPLAY GRID — a request that moves the Float but not the 0.1 dB the row shows IS written
//      and IS journaled, and the answer reads "0.0 dB → 0.0 dB". The agent does not compare on the
//      display grid. (The look path does, by design — `MediaSeedApplication.undo`, review 2d — and
//      that difference is recorded here on purpose rather than papered over with an epsilon: the
//      look has no write journal, the level has one.) The equal-looking answer is an OPEN wording
//      question, pinned as it is so a change to it is a decision, not a drift.
//   3. WRITE RESPONSIBILITY — the same number entered again through the production writer counts
//      as the person's decision: Undo keeps it (`laneLevelWrites`, review repair 2b). Claim 6 of
//      TheAgentActsThroughTheButtonsPathsTests drives the longer form; this is the short one beside
//      its two siblings so the three answers are read together.
//   4. OWN WRITES (review 5.2, founder 2026-09-28) — the agent's own later writes to the same lane,
//      a second change or its own Undo, are not "a person's write since": the journal's marks move
//      with them. Two changes in ONE request undo together; two requests undo one after the other;
//      and the person's same-number re-entry between them still blocks. Before 5.2 the agent's own
//      Undo write blocked its own earlier entry — the second Undo said "changed after my edit".
//
// WHAT KIND OF GREEN THIS IS (§1): END-TO-END over a real `TimelineStore` and `WorkstationSelection`.
// Expected numbers are derived from the algebra (#442), not read off a run: 1·10^(−1e−9/20) rounds
// to Float 1.0; 1·10^(−0.01/20) = 0.99885 is Float-distinct from 1.0 and shows as "0.0 dB".
//
// HONEST GRADING against the parent (fcb53dc05, §3): ZERO regressions — every claim pins behaviour
// the parent already has; the file's value is the separation. Mutants driven in transcription, each
// red for its named reason: the executor comparing the Double target with the current level
// (claim 1 writes a no-op and journals it) · the executor treating equal dB TEXT as "already at"
// (claim 2 refuses a real change) · Undo comparing the value only (claim 3 overwrites the re-entry) ·
// the marks not moved on the agent's own write (claim 4: the second change of one request is taken
// back, the first is "kept" — red; and the second of two requests blocks the first — red).
// Claim 4 was RED on the parent (33a70c329) for exactly that reason: ONE regression, named.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLevelRequestSeparatesNumberGridAndWriteTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let fixture = TimelineDocument(lanes: [keysLane], regions: [])

    private func rig() -> (TimelineStore, EchoelCommandExecutor, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        let selection = WorkstationSelection()
        selection.toggleTrack(Self.keysLane.id)
        let looks = UserDefaults(suiteName: "echoel.tests.levelThreeQuestions") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: selection, voiceCapacity: { 4 },
                                             mediaLooks: MediaLookUndo(), visualDefaults: looks)
        return (timeline, executor, original)
    }

    private func ask(_ change: EchoelLevelChange, on executor: EchoelCommandExecutor) async -> EchoelStepResult.Outcome? {
        let plan = EchoelActionPlan(requestID: UUID(), steps: [.setTrackLevel(track: .selected, change: change)],
                                    basis: executor.snapshot(), consents: [])
        return await executor.execute(plan).steps.first?.outcome
    }

    private func level(in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first(where: { $0.id == Self.keysLane.id })?.level
    }

    // MARK: 1 — representation: the Float in the store decides, not the Double the maths produced

    func testARequestBelowFloatResolutionIsAlreadyAtAndWritesNothing() async throws {
        let (timeline, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        let change = EchoelLevelChange.relativeDecibels(-1e-9)
        // Premise, from the algebra: the Double target differs from 1, its Float does not.
        guard case .success(let target) = EchoelLevelMath.target(current: 1, change: change) else {
            return XCTFail("a tiny relative change is a valid request")
        }
        XCTAssertNotEqual(target, 1, "in Double the request IS a change")
        XCTAssertEqual(Float(target), 1, "in the store's Float it is not")

        let outcome = await ask(change, on: executor)
        XCTAssertEqual(outcome, .done("Keys is already at 0.0 dB."))
        XCTAssertEqual(level(in: timeline), 1)
        XCTAssertNil(timeline.laneLevelWrites[Self.keysLane.id], "no write reached the store")
        XCTAssertFalse(executor.canUndoAgentChange, "nothing to take back — nothing was done")
    }

    // MARK: 2 — display grid: a change the row cannot show is still a change, written and journaled

    func testARequestBelowTheDisplayGridIsWrittenAndJournaled() async throws {
        let (timeline, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        let change = EchoelLevelChange.relativeDecibels(-0.01)
        guard case .success(let target) = EchoelLevelMath.target(current: 1, change: change) else {
            return XCTFail("−0.01 dB is a valid request")
        }
        XCTAssertNotEqual(Float(target), 1, "premise: Float-distinct from the current level")
        XCTAssertEqual(TrackMix.decibelText(target), "0.0 dB", "premise: the row shows the same 0.1 dB step")

        let outcome = await ask(change, on: executor)
        // Pinned AS IT IS (open wording question, header): the answer shows two equal readings.
        XCTAssertEqual(outcome, .done("Keys: 0.0 dB → 0.0 dB."))
        let after = try XCTUnwrap(level(in: timeline))
        XCTAssertEqual(after, Float(target), "the Float moved")
        XCTAssertNotEqual(after, 1)
        XCTAssertEqual(TrackMix.decibelText(Double(after)), "0.0 dB", "and the row still reads the same")
        XCTAssertEqual(timeline.laneLevelWrites[Self.keysLane.id], 1, "one write reached the store")
        XCTAssertTrue(executor.canUndoAgentChange, "and it is the agent's to take back")

        let taken = await executor.execute(EchoelActionPlan(requestID: UUID(), steps: [.undoAgentChange],
                                                            basis: executor.snapshot(), consents: []))
        XCTAssertEqual(taken.steps.first?.outcome, .done(EchoelUndoSummary.text(restored: 1, alreadyUndone: 0)))
        XCTAssertEqual(level(in: timeline), 1, "back to the number before, not to a rounding of it")
    }

    // MARK: 3 — write responsibility: the same number entered again is the person's now

    func testTheSameNumberEnteredAgainByHandIsKeptByUndo() async throws {
        let (timeline, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        let moved = await ask(.relativeDecibels(-3), on: executor)
        XCTAssertEqual(moved, .done("Keys: 0.0 dB → −3.0 dB."))
        let agents = try XCTUnwrap(level(in: timeline))
        let writes = try XCTUnwrap(timeline.laneLevelWrites[Self.keysLane.id])

        // The person types the number the inspector shows — the PRODUCTION writer, same value.
        TrackMix.setLevel(Double(agents), laneID: Self.keysLane.id, timeline: timeline)
        XCTAssertEqual(level(in: timeline), agents, "the number did not change")
        XCTAssertEqual(timeline.laneLevelWrites[Self.keysLane.id], writes + 1, "but the store counted a write")

        let taken = await executor.execute(EchoelActionPlan(requestID: UUID(), steps: [.undoAgentChange],
                                                            basis: executor.snapshot(), consents: []))
        XCTAssertEqual(taken.steps.first?.outcome, .failed(.changedSince("The level of Keys")))
        XCTAssertEqual(level(in: timeline), agents, "kept: entering it again made it the person's")
    }

    // MARK: 4 — the agent's own later writes never block its own earlier entries (review 5.2)

    func testOwnLaterWritesDoNotBlockOwnEarlierUndoEntries() async throws {
        let (timeline, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        let minus3 = Float(pow(10, -3.0 / 20))
        let minus6 = Float(pow(10, -6.0 / 20))
        func undo() async -> EchoelStepResult.Outcome? {
            await executor.execute(EchoelActionPlan(requestID: UUID(), steps: [.undoAgentChange],
                                                    basis: executor.snapshot(), consents: [])).steps.first?.outcome
        }

        // (a) Two changes of the same track in ONE request: one Undo takes both back.
        let twice = await executor.execute(EchoelActionPlan(
            requestID: UUID(),
            steps: [.setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
                    .setTrackLevel(track: .selected, change: .relativeDecibels(-3))],
            basis: executor.snapshot(), consents: []))
        XCTAssertEqual(twice.state, .done)
        XCTAssertEqual(try XCTUnwrap(level(in: timeline)), minus6, accuracy: 1e-6)
        let step1 = await undo()
        XCTAssertEqual(step1, .done(EchoelUndoSummary.text(restored: 2, alreadyUndone: 0)),
                       "the restore of the second change is the agent's own write, not a person's")
        XCTAssertEqual(level(in: timeline), 1, "both steps taken back")
        XCTAssertFalse(executor.canUndoAgentChange)

        // (b) Two requests, one change each: two Undos, newest first, each restoring exactly one.
        let step2 = await ask(.relativeDecibels(-3), on: executor)
        XCTAssertEqual(step2, .done("Keys: 0.0 dB → −3.0 dB."))
        let step3 = await ask(.relativeDecibels(-3), on: executor)
        XCTAssertEqual(step3, .done("Keys: −3.0 dB → −6.0 dB."))
        let step4 = await undo()
        XCTAssertEqual(step4, .done(EchoelUndoSummary.text(restored: 1, alreadyUndone: 0)))
        XCTAssertEqual(try XCTUnwrap(level(in: timeline)), minus3, accuracy: 1e-6, "the newer change is back")
        let step5 = await undo()
        XCTAssertEqual(step5, .done(EchoelUndoSummary.text(restored: 1, alreadyUndone: 0)),
                       "the first Undo's write was the agent's own — it does not block the older entry")
        XCTAssertEqual(level(in: timeline), 1)
        let step6 = await undo()
        XCTAssertEqual(step6, .failed(.nothingToUndo))

        // (c) The person's same-number re-entry between two of the agent's changes still blocks —
        //     the protection of 2b is untouched by 5.2.
        let step7 = await ask(.relativeDecibels(-3), on: executor)
        XCTAssertEqual(step7, .done("Keys: 0.0 dB → −3.0 dB."))
        TrackMix.setLevel(Double(minus3), laneID: Self.keysLane.id, timeline: timeline)   // the person, same number
        let step8 = await ask(.relativeDecibels(-3), on: executor)
        XCTAssertEqual(step8, .done("Keys: −3.0 dB → −6.0 dB."))
        let step9 = await undo()
        XCTAssertEqual(step9, .done(EchoelUndoSummary.text(restored: 1, alreadyUndone: 0)),
                       "the agent's newest change is its own to take back")
        XCTAssertEqual(try XCTUnwrap(level(in: timeline)), minus3, accuracy: 1e-6)
        let step10 = await undo()
        XCTAssertEqual(step10, .failed(.changedSince("The level of Keys")),
                       "but the level the person entered by hand — the same number — is theirs and stays")
        XCTAssertEqual(try XCTUnwrap(level(in: timeline)), minus3, accuracy: 1e-6)
    }
}

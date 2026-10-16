// TheAgentPansThroughTheInspectorsWriterTests.swift
// GSIDMMW D1 (2026-10-16): the agent's second mixer verb. "Pan the loop left" becomes
// `track.setPan`, which writes through the inspector's own `TrackMix.setPan`, reads the stored
// value back, and keeps its own way back — the same contract `track.setLevel` has had since
// EchoelAI step 1 (`TheAgentActsThroughTheButtonsPathsTests`).
//
// WHY THIS AND NOT A GENERIC `parameter.set` THROUGH `ParameterApplyRouter` (the plan's AI-7b,
// measured before building it): every router setter is `(Float) -> Void` and writes a LIVE voice
// mirror (`PolySynthVoice.automatableSetter`). Nothing reads that value back, and the patch the
// Sound panel shows — the persisted owner — never learns of it, so an agent write there would be
// a second truth with no Undo. A verb with a persisted owner, a read-back and a write counter is
// what "rücklesen + Undo" means; this is the next such owner after the level.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–6 are END-TO-END over a REAL `TimelineStore`, `WorkstationSelection` and
//     `EchoelCommandExecutor`, plus the shipped parser and model-answer reader. Assertions are on
//     the fixture's own ids; the store's prior document is restored after each claim.
//   · Claim 7 is a SOURCE-TEXT SCAN: the counter moves at the one pan writer and at the mixer
//     Undo's pan restore, and nowhere the agent could bump it from outside.
//   · DEVICE PROBE, open: that a real on-device model answers "pan it left" with a number, and that
//     the pan is heard (the audio lane and the rack read `pan` live — not driven here).
//
// HONEST GRADING against the parent (`e171fed`, §3): the file does not COMPILE there — it names
// `EchoelCommand.setTrackPan`, `EchoelPanText` and `TimelineStore.lanePanWrites`, which this commit
// creates — so no assertion has a verdict on the parent: ONE absence (#486), every claim a FORWARD
// guard. Hand-transcribed against the worktree. Mutants and the claim each turns red: the parser
// clamping 1.5 to 1 (2) · the executor without the `controls.pan` check, writing the Echoel
// track's pan that nothing plays (3) · Undo comparing the value only, so a pan the person set back
// by the mixer's own Undo is overwritten (4) · `EchoelProjectSnapshot.Track` without `pan`, so a
// plan made before the person moved the pan applies over it (5) · the planner without
// `setTrackPan` in `allowed` (6) · the mixer Undo restoring a pan without counting it (7, and 4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentPansThroughTheInspectorsWriterTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()

    // One fixture VALUE per lane — never a factory (#1419).
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let keysPart = TimelineRegion(laneID: keysLane.id, clipID: clip, startTick: 0, lengthTicks: bar)
    private static let fixture = TimelineDocument(lanes: [keysLane, loopLane], regions: [keysPart])

    private func rig() -> (TimelineStore, WorkstationSelection, EchoelCommandExecutor, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        let selection = WorkstationSelection()
        // No claim applies a media look, so the suite is never written.
        let looks = UserDefaults(suiteName: "echoel.tests.agentPans") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: selection,
                                             voiceCapacity: { 4 }, loopBars: { 4 },
                                             mediaLooks: MediaLookUndo(), visualDefaults: looks)
        return (timeline, selection, executor, original)
    }

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor) -> EchoelActionPlan {
        EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
    }

    private func pan(_ lane: TimelineLane, in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.pan
    }

    // MARK: 1 — the pan moves exactly that track, reads back as asked, and Undo puts it back

    func testThePanMovesOnlyTheSelectedTrackAndUndoPutsItBack() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let levelBefore = timeline.document.lanes.map(\.level)
        let report = await executor.execute(plan([.setTrackPan(track: .selected, pan: -0.5)], on: executor))
        XCTAssertEqual(report.state, .done)
        XCTAssertEqual(report.steps.first?.outcome, .done("Loop: centre → -0.50 (left)."))
        XCTAssertEqual(pan(Self.loopLane, in: timeline), -0.5, "the stored pan reads back as asked")
        XCTAssertEqual(pan(Self.keysLane, in: timeline), 0, "the neighbour is untouched")
        XCTAssertEqual(timeline.document.lanes.map(\.level), levelBefore, "a pan is not a level")
        XCTAssertEqual(timeline.lanePanWrites[Self.loopLane.id], 1, "one write reached the store")
        XCTAssertTrue(executor.canUndoAgentChange)

        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.state, .done)
        XCTAssertEqual(pan(Self.loopLane, in: timeline), 0, "Undo restores the centre")
        XCTAssertFalse(executor.canUndoAgentChange)

        let again = await executor.execute(plan([.setTrackPan(track: .selected, pan: 0)], on: executor))
        XCTAssertEqual(again.steps.first?.outcome, .done("Loop is already at centre."),
                       "asking for where it already is writes nothing")
        XCTAssertFalse(executor.canUndoAgentChange, "and leaves nothing to take back")
    }

    // MARK: 2 — a position past −1 … 1 is refused, never shortened

    func testAPositionPastTheRangeIsRefusedNotClamped() {
        func parsed(_ value: String) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: "track.setPan",
                                                           arguments: ["track": "selected", "pan": value]))
        }
        XCTAssertEqual(try parsed("-1").get(), .setTrackPan(track: .selected, pan: -1))
        XCTAssertEqual(try parsed("1").get(), .setTrackPan(track: .selected, pan: 1))
        XCTAssertEqual(try parsed("\u{2212}0.25").get(), .setTrackPan(track: .selected, pan: -0.25),
                       "the minus sign the field shows is read like a hyphen")
        guard case .failure(.outOfRange) = parsed("1.5") else { return XCTFail("1.5 is refused, not made 1") }
        guard case .failure(.outOfRange) = parsed("-2") else { return XCTFail("-2 is refused, not made -1") }
        XCTAssertEqual(parsed("nan"), .failure(.invalidArgument("that stereo position")))
        XCTAssertEqual(parsed("left"), .failure(.invalidArgument("that stereo position")),
                       "a word is not a position — the planner asks instead")
        XCTAssertEqual(EchoelCommandParser.parse(EchoelProposedAction(
            command: "track.setPan", arguments: ["track": "selected", "pan": "0.2", "by": "a bit"])),
                       .failure(.unknownArgument("by")), "an argument nobody carries out is refused")
    }

    // MARK: 3 — a track without a Pan field is refused and nothing changes

    func testATrackWithoutAPanFieldIsRefused() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.keysLane.id)
        guard let controls = TrackMix.controls(of: Self.keysLane.id, in: timeline.document, voiceCapacity: 4),
              !controls.pan else {
            return XCTFail("premise: the fixture's first MIDI track is the Echoel track, which shows no Pan field")
        }
        let report = await executor.execute(plan([.setTrackPan(track: .selected, pan: 0.4)], on: executor))
        XCTAssertEqual(report.steps.first?.outcome, .failed(.noPan(TrackMix.deviceName(controls.role))))
        XCTAssertEqual(timeline.document, Self.fixture, "nothing changed")
        XCTAssertNil(timeline.lanePanWrites[Self.keysLane.id], "no write reached the store")
    }

    // MARK: 4 — a pan the person set after the agent is kept, even when it reads the same

    func testUndoKeepsAPanThePersonSetAfterTheAgent() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        _ = await executor.execute(plan([.setTrackPan(track: .selected, pan: -0.5)], on: executor))
        // The person drags the pan on the inspector (one gesture, one mixer step) and then takes that
        // back with the song's Undo — so the pan reads exactly what the agent left, and was written twice.
        timeline.editLaneMix(id: Self.loopLane.id) {
            TrackMix.setPan(0.3, laneID: Self.loopLane.id, timeline: timeline)
        }
        timeline.commitLaneMix(id: Self.loopLane.id)
        timeline.undo()
        XCTAssertEqual(pan(Self.loopLane, in: timeline), -0.5, "premise: the song's Undo put the agent's value back")
        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .failed(.changedSince("The stereo position of Loop")),
                       "that pan is the person's decision now — the agent's Undo leaves it")
        XCTAssertEqual(pan(Self.loopLane, in: timeline), -0.5)
    }

    // MARK: 5 — a plan made before the person moved the pan is refused, never applied over it

    func testAPlanMadeBeforeThePanMovedIsRefused() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let stale = plan([.setTrackPan(track: .selected, pan: 1)], on: executor)
        TrackMix.setPan(-0.2, laneID: Self.loopLane.id, timeline: timeline)
        let report = await executor.execute(stale)
        XCTAssertEqual(report.refusal, .projectChanged)
        XCTAssertEqual(pan(Self.loopLane, in: timeline), -0.2, "the person's pan stands")
    }

    // MARK: 6 — the model may propose a pan; the proposal names track and side before Apply

    func testTheModelMayProposeAPanAndTheProposalSaysWhere() async throws {
        XCTAssertTrue(EchoelModelPlanner.allowed.contains(.setTrackPan))
        let answer = #"{"actions": [{"command": "track.setPan", "arguments": {"track": "selected", "pan": "-0.5"}}]}"#
        let actions = try EchoelModelPlanner.read(answer)
        XCTAssertEqual(actions.count, 1)
        XCTAssertThrowsError(try EchoelModelPlanner.read(
            #"{"actions": [{"command": "track.setPan", "arguments": {"track": "\#(UUID().uuidString)", "pan": "1"}}]}"#),
                             "a track named by a guessed id is refused") { error in
            XCTAssertEqual(error as? EchoelPlannerRefusal, .notTheSelection)
        }
        XCTAssertTrue(EchoelModelPlanner.prompt(request: "pan it left", facts: "").contains("track.setPan"))

        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let proposal = plan([.setTrackPan(track: .selected, pan: -0.5)], on: executor)
        XCTAssertEqual(EchoelAgentDesk.proposalSentence(proposal),
                       "Echoel would pan Loop to -0.50 (left). " + EchoelAgentDesk.proposalTail)
        XCTAssertEqual(timeline.document, Self.fixture, "proposing changes nothing")
        XCTAssertEqual(EchoelPanText.text(0), "centre")
        XCTAssertEqual(EchoelPanText.text(0.25), "0.25 (right)")
        XCTAssertTrue(EchoelStateText.describe(executor.snapshot()).contains(", pan " + EchoelPanText.text(0) + "."),
                      "the facts the model reads name where the selected track sits")
    }

    // MARK: 7 — the counter moves at the one pan writer and at the mixer Undo's pan restore

    func testThePanWriteCountMovesAtBothStoreWriters() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let store = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Core/TimelineStore.swift"), encoding: .utf8))
        guard let head = store.range(of: "public func setLanePan(id: UUID, _ pan: Float) {"),
              let tail = store.range(of: "persist()", range: head.upperBound..<store.endIndex) else {
            return XCTFail("`TimelineStore.setLanePan` or its `persist()` moved — re-anchor")
        }
        XCTAssertTrue(store[head.upperBound..<tail.lowerBound].contains("lanePanWrites[id, default: 0] += 1"),
                      "every pan write counts, the same number too")
        XCTAssertTrue(store.contains("if restored.pan != current.pan { lanePanWrites[laneID, default: 0] += 1 }"),
                      "a pan the mixer's Undo puts back is a write the agent's Undo must see")
        XCTAssertEqual(store.components(separatedBy: "lanePanWrites[").count - 1, 2, "and nowhere else")
        XCTAssertTrue(store.contains("@ObservationIgnored public private(set) var lanePanWrites: [UUID: Int]"),
                      "not observed, not writable from outside the store")
    }
}

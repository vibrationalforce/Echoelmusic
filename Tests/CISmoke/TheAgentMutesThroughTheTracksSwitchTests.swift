// TheAgentMutesThroughTheTracksSwitchTests.swift
// GSIDMMW D2 (2026-10-16): the agent's third mixer verb. "Mute the loop" becomes `track.setMute`,
// which asks for a STATE (muted / playing) and reaches it through the track's own switch
// (`TrackMix.flipMute`), reads it back, and keeps its own way back — the contract
// `track.setLevel` and `track.setPan` (D1) already have.
//
// ⭐ WHY A STATE AND NOT A TOGGLE: the switch flips. A plan read against "playing" that ran after
// the person had muted the track would un-mute it — the opposite of what was asked. Asking for
// the state makes a repeat harmless ("already muted"), and the basis check (the snapshot carries
// `isMuted`) refuses a plan read before the person switched it.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–5 are END-TO-END over a REAL `TimelineStore`, `WorkstationSelection` and
//     `EchoelCommandExecutor`, plus the shipped parser and model-answer reader.
//   · Claim 6 is a SOURCE-TEXT SCAN: the Mute write count moves at the switch and at the mixer
//     Undo's restore, and — deliberately — not at the roll slot's heal (claim 4 drives why).
//   · DEVICE PROBE, open: that a real model answers "mute the drums" with this command, and that
//     the mute is heard.
//
// HONEST GRADING against the parent (D1's commit, §3): the file does not COMPILE there — it names
// `EchoelCommand.setTrackMute` and `TimelineStore.laneMuteWrites`, which this commit creates — ONE
// absence (#486), every claim a FORWARD guard. Hand-transcribed against the worktree. Mutants and
// the claim each turns red: a toggle instead of a state, so a repeat un-mutes (1) · no
// `controls.muteSolo` check, muting a bio curve (2) · Undo flipping without the write count, so a
// Mute the person switched off and on again is overwritten (3) · Undo flipping a track the heal
// already unmuted, which MUTES it again (4) · the snapshot without `isMuted` (5).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentMutesThroughTheTracksSwitchTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()

    // One fixture VALUE per lane — never a factory (#1419).
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let keysPart = TimelineRegion(laneID: keysLane.id, clipID: clip, startTick: 0, lengthTicks: bar)
    private static let fixture = TimelineDocument(lanes: [bioLane, keysLane, loopLane], regions: [keysPart])

    private func rig() -> (TimelineStore, WorkstationSelection, EchoelCommandExecutor, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        let selection = WorkstationSelection()
        // No claim applies a media look, so the suite is never written.
        let looks = UserDefaults(suiteName: "echoel.tests.agentMutes") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: selection,
                                             voiceCapacity: { 4 }, loopBars: { 4 },
                                             mediaLooks: MediaLookUndo(), visualDefaults: looks)
        return (timeline, selection, executor, original)
    }

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor) -> EchoelActionPlan {
        EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
    }

    private func muted(_ lane: TimelineLane, in timeline: TimelineStore) -> Bool? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.isMuted
    }

    // MARK: 1 — the state is reached once, a repeat changes nothing, Undo plays it again

    func testMuteReachesTheStateOnceAndUndoPlaysItAgain() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let report = await executor.execute(plan([.setTrackMute(track: .selected, muted: true)], on: executor))
        XCTAssertEqual(report.steps.first?.outcome, .done("Loop is muted."))
        XCTAssertEqual(muted(Self.loopLane, in: timeline), true)
        XCTAssertEqual(muted(Self.keysLane, in: timeline), false, "the neighbour is untouched")
        XCTAssertEqual(timeline.laneMuteWrites[Self.loopLane.id], 1)

        let repeated = await executor.execute(plan([.setTrackMute(track: .selected, muted: true)], on: executor))
        XCTAssertEqual(repeated.steps.first?.outcome, .done("Loop is already muted."),
                       "a state, not a toggle: asking again does not un-mute")
        XCTAssertEqual(muted(Self.loopLane, in: timeline), true)

        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .done("Took back my last change."))
        XCTAssertEqual(muted(Self.loopLane, in: timeline), false, "Undo plays it again")
    }

    // MARK: 2 — a track without Mute is refused; the parser takes true/false and nothing else

    func testATrackWithoutMuteAndAVagueAnswerAreRefused() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.bioLane.id)
        let report = await executor.execute(plan([.setTrackMute(track: .selected, muted: true)], on: executor))
        XCTAssertEqual(report.steps.first?.outcome, .failed(.noMute("Bio curve — no sound")))
        XCTAssertEqual(timeline.document, Self.fixture, "nothing changed")

        func parsed(_ value: String) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: "track.setMute",
                                                           arguments: ["track": "selected", "muted": value]))
        }
        XCTAssertEqual(parsed("true"), .success(.setTrackMute(track: .selected, muted: true)))
        XCTAssertEqual(parsed("false"), .success(.setTrackMute(track: .selected, muted: false)))
        for vague in ["toggle", "yes", "1", ""] {
            XCTAssertEqual(parsed(vague), .failure(.invalidArgument("whether to mute — true or false")), vague)
        }
    }

    // MARK: 3 — a Mute the person switched since is kept, even when it reads the same

    func testUndoKeepsAMuteThePersonSwitchedSince() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        _ = await executor.execute(plan([.setTrackMute(track: .selected, muted: true)], on: executor))
        // Two taps on the M switch: off, on — back to what the agent left, written twice.
        TrackMix.tapStep(laneID: Self.loopLane.id, timeline: timeline) {
            TrackMix.flipMute(laneID: Self.loopLane.id, timeline: timeline)
        }
        TrackMix.tapStep(laneID: Self.loopLane.id, timeline: timeline) {
            TrackMix.flipMute(laneID: Self.loopLane.id, timeline: timeline)
        }
        XCTAssertEqual(muted(Self.loopLane, in: timeline), true, "premise: it reads what the agent left")
        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .failed(.changedSince("The Mute of Loop")))
        XCTAssertEqual(muted(Self.loopLane, in: timeline), true, "the person's Mute stands")
    }

    // MARK: 4 — the instrument's heal unmutes the Echoel track; Undo then does NOT mute it again

    func testUndoAfterTheHealDoesNotMuteTheInstrumentAgain() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.keysLane.id)
        _ = await executor.execute(plan([.setTrackMute(track: .selected, muted: true)], on: executor))
        XCTAssertEqual(muted(Self.keysLane, in: timeline), true, "premise: the Echoel track can be muted")
        timeline.unsilenceRollSlot()
        XCTAssertEqual(muted(Self.keysLane, in: timeline), false, "premise: the heal unmuted it")
        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .done("My last change had already been taken back."))
        XCTAssertEqual(muted(Self.keysLane, in: timeline), false, "a flip here would have muted the instrument")
    }

    // MARK: 5 — a plan read before the person switched Mute is refused; the model may propose it

    func testAStaleMutePlanIsRefusedAndTheModelMayProposeOne() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let stale = plan([.setTrackMute(track: .selected, muted: false)], on: executor)
        XCTAssertEqual(EchoelAgentDesk.proposalSentence(stale),
                       "Echoel would unmute Loop. " + EchoelAgentDesk.proposalTail)
        TrackMix.flipMute(laneID: Self.loopLane.id, timeline: timeline)
        let report = await executor.execute(stale)
        XCTAssertEqual(report.refusal, .projectChanged)
        XCTAssertEqual(muted(Self.loopLane, in: timeline), true, "the person's Mute stands")
        XCTAssertTrue(EchoelStateText.describe(executor.snapshot()).hasSuffix(", muted. The piece has 3 tracks and 1 part."),
                      "the facts the model reads say the selected track is muted")

        XCTAssertTrue(EchoelModelPlanner.allowed.contains(.setTrackMute))
        let answer = #"{"actions": [{"command": "track.setMute", "arguments": {"track": "selected", "muted": "true"}}]}"#
        XCTAssertEqual(try EchoelModelPlanner.read(answer).count, 1)
        XCTAssertTrue(EchoelModelPlanner.prompt(request: "mute it", facts: "").contains("track.setMute"))
    }

    // MARK: 6 — the Mute write count moves at the switch and at the mixer Undo, not at the heal

    func testTheMuteWriteCountMovesAtTheSwitchAndTheMixerUndo() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let store = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Core/TimelineStore.swift"), encoding: .utf8))
        guard let head = store.range(of: "public func toggleMute(id: UUID) {"),
              let tail = store.range(of: "persist()", range: head.upperBound..<store.endIndex) else {
            return XCTFail("`TimelineStore.toggleMute` or its `persist()` moved — re-anchor")
        }
        XCTAssertTrue(store[head.upperBound..<tail.lowerBound].contains("laneMuteWrites[id, default: 0] += 1"),
                      "every tap on the switch counts")
        XCTAssertTrue(store.contains("if restored.isMuted != current.isMuted { laneMuteWrites[laneID, default: 0] += 1 }"),
                      "a Mute the mixer's Undo puts back is a write the agent's Undo must see")
        XCTAssertEqual(store.components(separatedBy: "laneMuteWrites[").count - 1, 2,
                       "and nowhere else — the heal only unmutes, claim 4 drives why it needs no count")
        XCTAssertTrue(store.contains("@ObservationIgnored public private(set) var laneMuteWrites: [UUID: Int]"))
    }
}

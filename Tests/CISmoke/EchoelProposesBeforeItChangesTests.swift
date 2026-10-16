// EchoelProposesBeforeItChangesTests.swift
// Echoel — GSIDMMW package C, step C2a (2026-10-16): intent → proposal or question → Apply → the
// normal, editable piece → Undo. (Not the ultra-plan's "C2", which was Share as MIDI.)
//
// WHAT THIS GUARDS — END-TO-END BEHAVIOUR over the shipped desk, executor and `TimelineStore`, with
// a stand-in brain (CI has no Apple Intelligence):
//   1. A request the model can plan becomes a PROPOSAL: the notice says what would happen, names
//      the track and the amount, and the piece is unchanged.
//   2. Apply makes exactly that change in the normal piece; the agent's Undo takes it back.
//   3. A selection that changed between the proposal and Apply is REFUSED — the plan is never
//      applied to whatever is selected now — and the piece is unchanged.
//   4. A model question is a Question notice with no proposal; nothing changes.
//   5. Discard and Close both leave no proposal behind, and nothing changes.
//   6. The proposal is the model request the describe already is: the banner's Stop drops it.
//
// GRADING (§3). Against the parent (`81ebe64`) this file does NOT COMPILE — `proposePlan`,
// `applyProposal`, `discardProposal`, `pendingProposal` and `EchoelAgentProposal` are new — so no
// assertion has a verdict there: ONE absence (#486), every claim a FORWARD guard. Counterweights:
// the executor's basis refusal (claim 3) and the agent Undo (claim 2) are older and unchanged.
// Transcribed by reading against THIS tree (no toolchain, §0).
//
// ⛔ HONEST LIMIT: the door is `AskEchoelIntent` (C2b, pinned in `TheOnDeviceModelHasOneGateTests`).
// A real model's plan, Siri's dialog and the banner's buttons on screen are DEVICE PROBES, open.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class EchoelProposesBeforeItChangesTests: XCTestCase {

    private final class StandIn: BrainBackend, @unchecked Sendable {
        let answer: String
        var prompts: [String] = []
        init(_ answer: String) { self.answer = answer }
        var isAvailable: Bool { get async { true } }
        func respond(to prompt: String) async throws -> String {
            prompts.append(prompt)
            return answer
        }
    }

    /// A brain that suspends in `respond` until the test releases it.
    private final class Gate: BrainBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var waiting: CheckedContinuation<String, Error>?
        var isAvailable: Bool { get async { true } }
        func respond(to prompt: String) async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock(); waiting = continuation; lock.unlock()
            }
        }
        var isWaiting: Bool { lock.lock(); defer { lock.unlock() }; return waiting != nil }
        func release(_ answer: String) {
            lock.lock(); let c = waiting; waiting = nil; lock.unlock()
            c?.resume(returning: answer)
        }
    }

    private static let quieter =
        #"{"actions": [{"command": "track.setLevel", "arguments": {"track": "selected", "decibels": "-3", "mode": "relative"}}]}"#

    private struct Rig {
        let timeline: TimelineStore
        let selection: WorkstationSelection
        let desk: EchoelAgentDesk
        let keys: TimelineLane
        let lead: TimelineLane
        let original: TimelineDocument
    }

    private func rig() -> Rig {
        let timeline = TimelineStore()
        let original = timeline.document
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let lead = TimelineLane(name: "Lead", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [keys, lead], regions: []))
        let selection = WorkstationSelection()
        selection.selectTrack(keys.id)
        let looks = UserDefaults(suiteName: "echoel.tests.agentProposes") ?? UserDefaults()
        let desk = EchoelAgentDesk()
        desk.bind(EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: selection,
                                        voiceCapacity: { 4 }, loopBars: { 4 }, mediaLooks: MediaLookUndo(),
                                        visualDefaults: looks))
        return Rig(timeline: timeline, selection: selection, desk: desk, keys: keys, lead: lead, original: original)
    }

    private func level(_ id: UUID, in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first { $0.id == id }?.level
    }

    // MARK: - 1. a plan is a proposal, not a change

    func testAPlannedRequestIsAProposalAndChangesNothing() async throws {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        let before = r.timeline.document
        await r.desk.proposePlan(for: "make it 3 dB quieter", with: StandIn(Self.quieter))
        let proposal = try XCTUnwrap(r.desk.pendingProposal, "a valid plan is held, not run")
        XCTAssertEqual(proposal.plan.steps, [.setTrackLevel(track: .selected, change: .relativeDecibels(-3))])
        XCTAssertEqual(r.desk.notice?.state, .understood)
        let message = r.desk.notice?.message ?? ""
        XCTAssertTrue(message.contains("Keys") && message.contains("3.0 dB quieter"),
                      "the notice names the track and the amount before anything runs: \(message)")
        XCTAssertTrue(message.hasSuffix(EchoelAgentDesk.proposalTail))
        XCTAssertEqual(r.timeline.document, before, "a proposal changes nothing")
        XCTAssertFalse(r.desk.isWorking)
    }

    // MARK: - 2. Apply makes the change; Undo takes it back

    func testApplyMakesThatChangeAndUndoTakesItBack() async throws {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        let start = try XCTUnwrap(level(r.keys.id, in: r.timeline))
        let leadStart = level(r.lead.id, in: r.timeline)
        await r.desk.proposePlan(for: "make it 3 dB quieter", with: StandIn(Self.quieter))
        await r.desk.applyProposal()
        XCTAssertEqual(r.desk.notice?.state, .done)
        let after = try XCTUnwrap(level(r.keys.id, in: r.timeline))
        XCTAssertLessThan(after, start, "the selected track is quieter in the normal piece")
        XCTAssertEqual(level(r.lead.id, in: r.timeline), leadStart, "only the selected track changed")
        XCTAssertNil(r.desk.pendingProposal, "an applied proposal is gone — a second Apply runs nothing")
        XCTAssertTrue(r.desk.notice?.canUndo ?? false)
        await r.desk.undoLast()
        XCTAssertEqual(level(r.keys.id, in: r.timeline), start, "the agent's Undo restores the level")
    }

    // MARK: - 3. a stale proposal is refused, never re-aimed

    func testASelectionChangedBeforeApplyIsRefused() async throws {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        await r.desk.proposePlan(for: "make it 3 dB quieter", with: StandIn(Self.quieter))
        XCTAssertNotNil(r.desk.pendingProposal)
        r.selection.selectTrack(r.lead.id)
        let before = r.timeline.document
        await r.desk.applyProposal()
        XCTAssertEqual(r.timeline.document, before, "the plan read Keys; it must not land on Lead")
        guard case .needsAnswer = r.desk.notice?.state else {
            return XCTFail("a refused proposal asks again: \(String(describing: r.desk.notice))")
        }
    }

    // MARK: - 4. a question is a question

    func testAModelQuestionIsAQuestionWithNoProposal() async {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        let before = r.timeline.document
        await r.desk.proposePlan(for: "a little quieter", with: StandIn(#"{"question": "By how many decibels?"}"#))
        XCTAssertEqual(r.desk.notice?.state, .needsAnswer("By how many decibels?"))
        XCTAssertNil(r.desk.pendingProposal)
        XCTAssertEqual(r.timeline.document, before)
    }

    // MARK: - 5. Discard and Close leave nothing behind

    func testDiscardAndCloseLeaveNoProposal() async {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        let before = r.timeline.document
        await r.desk.proposePlan(for: "make it 3 dB quieter", with: StandIn(Self.quieter))
        r.desk.discardProposal()
        XCTAssertNil(r.desk.pendingProposal)
        XCTAssertEqual(r.desk.notice?.message, EchoelAgentDesk.discardedMessage)
        await r.desk.applyProposal()
        XCTAssertEqual(r.timeline.document, before, "Apply after Discard runs nothing")

        await r.desk.proposePlan(for: "make it 3 dB quieter", with: StandIn(Self.quieter))
        r.desk.dismiss()
        XCTAssertNil(r.desk.pendingProposal, "a closed notice takes its proposal with it")
        await r.desk.applyProposal()
        XCTAssertEqual(r.timeline.document, before)
    }

    // MARK: - 6. it is the same model request: Stop drops it

    func testStopDropsAPlanStillBeingMade() async {
        let r = rig()
        defer { r.timeline.replaceDocument(r.original) }
        let gate = Gate()
        let asking = Task { await r.desk.proposePlan(for: "make it 3 dB quieter", with: gate) }
        for _ in 0..<2_000 where !gate.isWaiting { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertTrue(r.desk.isDescribing, "the banner shows Stop while the plan is made")
        r.desk.stopDescribe()
        XCTAssertEqual(r.desk.notice?.message, EchoelAgentDesk.describeStoppedMessage)
        gate.release(Self.quieter)
        await asking.value
        XCTAssertNil(r.desk.pendingProposal, "a plan that arrives after Stop is dropped")
        XCTAssertFalse(r.desk.isModelBusy)
    }
}

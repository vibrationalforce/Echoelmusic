// TheAgentDescribesThePieceTests.swift
// Echoel — GMMW AI-4. "Describe this piece": one tap asks the on-device model to say what the piece
// holds. It is READ-ONLY and the answer is the banner's notice.
//
// WHAT THIS GUARDS (behaviour, with a stand-in brain — CI has no Apple Intelligence):
//   1. An unavailable model leaves a failed notice with a sentence, and the piece is unchanged.
//   2. An available model's answer becomes a Done notice; the prompt carries the piece's facts
//      between markers (`EchoelStateText`, bio-free), and the piece is unchanged.
//   3. A refusal and an overflow each say what happened; nothing is changed.
//   4. A tap before the app bound the desk says so instead of doing nothing, and asks no model.
//   5–9 (GSIDMMW audit F2/F3, 2026-10-16) — END-TO-END BEHAVIOUR with a stand-in that really
//      SUSPENDS until the test releases it: a late answer, a late error and a late availability
//      reply after another piece was opened never show in that piece; Stop drops the answer and a
//      typed request runs while the model still computes; the deadline frees the desk and the late
//      answer is dropped; a second describe while the backend still computes asks no second model.
//
// ⚠️ HONEST GRADING (#433): claims 5–9 drive `stopDescribe`, `isModelBusy`, `describeDeadline` and
// the new sentences — FORWARD guards, one absence on the parent (#486). The behaviour they pin was
// a defect there: the parent wrote the notice after `respond` with no ownership check, and held
// `isWorking` across the whole model call. Transcribed by reading, no toolchain (§0); claims 1–4
// are counterweights and keep their assertions unchanged.
//
// ⚠️ THE LIMIT. A real answer from the model is NEEDS-FOUNDER-VERIFY (family 5): an Apple
// Intelligence iPhone on iOS 26. The door (exactly one construction, from a Button) is pinned in
// `TheOnDeviceModelHasOneGateTests`.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentDescribesThePieceTests: XCTestCase {

    private final class StandIn: BrainBackend, @unchecked Sendable {
        let available: Bool
        let result: Result<String, EchoelAIError>
        var prompts: [String] = []
        init(available: Bool, result: Result<String, EchoelAIError>) {
            self.available = available
            self.result = result
        }
        var isAvailable: Bool { get async { available } }
        func respond(to prompt: String) async throws -> String {
            prompts.append(prompt)
            return try result.get()
        }
    }

    /// A brain that SUSPENDS in `isAvailable` (when asked to) and in `respond` until the test
    /// releases it — and ignores cancellation, the worst case F3 names.
    private final class Gate: BrainBackend, @unchecked Sendable {
        private let lock = NSLock()
        private let holdAvailability: Bool
        private var availability: CheckedContinuation<Bool, Never>?
        private var answer: CheckedContinuation<String, Error>?
        private var respondCalls = 0
        init(holdAvailability: Bool = false) { self.holdAvailability = holdAvailability }
        var isAvailable: Bool {
            get async {
                guard holdAvailability else { return true }
                return await withCheckedContinuation { continuation in
                    lock.lock(); availability = continuation; lock.unlock()
                }
            }
        }
        func respond(to prompt: String) async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock(); answer = continuation; respondCalls += 1; lock.unlock()
            }
        }
        var calls: Int { lock.lock(); defer { lock.unlock() }; return respondCalls }
        var isHeld: Bool { lock.lock(); defer { lock.unlock() }; return answer != nil || availability != nil }
        func releaseAvailability(_ value: Bool) {
            lock.lock(); let held = availability; availability = nil; lock.unlock()
            held?.resume(returning: value)
        }
        func release(_ result: Result<String, Error>) {
            lock.lock(); let held = answer; answer = nil; lock.unlock()
            held?.resume(with: result)
        }
    }

    /// Waits until `condition` holds — polled, never a fixed sleep; fails after ~2 s.
    private func until(_ what: String, _ condition: () -> Bool) async {
        for _ in 0..<2_000 where !condition() {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(condition(), "timed out waiting: \(what)")
    }

    private func otherPiece() -> TimelineDocument {
        TimelineDocument(lanes: [TimelineLane(name: "Strings", kind: .midi)], regions: [])
    }

    private func rig() -> (TimelineStore, EchoelAgentDesk, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        let lane = TimelineLane(name: "Keys", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: []))
        let looks = UserDefaults(suiteName: "echoel.tests.agentDescribes") ?? UserDefaults()
        let desk = EchoelAgentDesk()
        desk.bind(EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: WorkstationSelection(),
                                        voiceCapacity: { 4 }, loopBars: { 4 }, mediaLooks: MediaLookUndo(), visualDefaults: looks))
        return (timeline, desk, original)
    }

    func testAnUnavailableModelSaysSoAndChangesNothing() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let before = timeline.document
        let brain = StandIn(available: false, result: .success("unused"))
        await desk.describePiece(with: brain)
        guard case .failed = desk.notice?.state else { return XCTFail("a failed notice: \(String(describing: desk.notice))") }
        XCTAssertFalse(desk.notice?.message.isEmpty ?? true)
        XCTAssertTrue(brain.prompts.isEmpty, "the model is not asked when it is not there")
        XCTAssertEqual(timeline.document, before)
        XCTAssertFalse(desk.isWorking)
    }

    func testTheAnswerIsTheNoticeAndThePromptCarriesOnlyThePiecesFacts() async throws {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let before = timeline.document
        let brain = StandIn(available: true, result: .success("  One track called Keys, no parts yet.  "))
        await desk.describePiece(with: brain)
        XCTAssertEqual(desk.notice?.state, .done)
        XCTAssertEqual(desk.notice?.message, "One track called Keys, no parts yet.")
        let prompt = try XCTUnwrap(brain.prompts.first)
        XCTAssertTrue(prompt.contains("<facts>") && prompt.contains("</facts>"))
        XCTAssertTrue(prompt.contains("1 track"), "the facts are the piece's own description")
        XCTAssertEqual(timeline.document, before, "describing changes nothing")
    }

    func testARefusalAndAnOverflowSayWhatHappened() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        await desk.describePiece(with: StandIn(available: true, result: .failure(.refused)))
        XCTAssertEqual(desk.notice?.message, EchoelAgentDesk.describeFailure(EchoelAIError.refused))
        await desk.describePiece(with: StandIn(available: true, result: .failure(.contextOverflow)))
        XCTAssertEqual(desk.notice?.message, EchoelAgentDesk.describeFailure(EchoelAIError.contextOverflow))
        XCTAssertNotEqual(EchoelAgentDesk.describeFailure(EchoelAIError.refused),
                          EchoelAgentDesk.describeFailure(EchoelAIError.contextOverflow))
    }

    func testATapBeforeStartupFinishedSaysSo() async {
        let desk = EchoelAgentDesk()
        let brain = StandIn(available: true, result: .success("unused"))
        await desk.describePiece(with: brain)
        XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.stillStartingMessage),
                       "an unbound desk says the app is still starting — a silent tap reads as done")
        XCTAssertEqual(desk.notice?.canUndo, false)
        XCTAssertTrue(brain.prompts.isEmpty, "no model is asked before the desk is bound")
        XCTAssertFalse(desk.isWorking)
    }

    // MARK: 5–6 — a late reply never lands in another piece

    func testALateAnswerOrErrorNeverShowsInTheNextPiece() async {
        for late in [Result<String, Error>.success("About the first piece."),
                     .failure(EchoelAIError.refused)] {
            let (timeline, desk, original) = rig()
            defer { timeline.replaceDocument(original) }
            let gate = Gate()
            let asked = Task { await desk.describePiece(with: gate) }
            await until("the model is asked") { gate.isHeld }
            XCTAssertTrue(desk.isDescribing)
            XCTAssertFalse(desk.isWorking, "the model call does not hold the desk")
            timeline.replaceDocument(otherPiece())                       // the person opens another piece
            gate.release(late)
            await asked.value
            XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.pieceChangedMessage),
                           "the reply about the first piece is dropped and the drop is said")
            XCTAssertNotEqual(desk.notice?.message, "About the first piece.")
            XCTAssertFalse(desk.isDescribing)
            XCTAssertFalse(desk.isModelBusy)
        }
    }

    func testALateAvailabilityReplyAsksNoModelInTheNextPiece() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let gate = Gate(holdAvailability: true)
        let asked = Task { await desk.describePiece(with: gate) }
        await until("availability is asked") { gate.isHeld }
        timeline.replaceDocument(otherPiece())
        gate.releaseAvailability(true)
        await asked.value
        XCTAssertEqual(gate.calls, 0, "the piece changed before the model was asked — it is not asked")
        XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.pieceChangedMessage))
    }

    // MARK: 7 — Stop drops the answer; the desk stays usable meanwhile

    func testStopDropsTheAnswerAndATypedRequestRunsMeanwhile() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let gate = Gate()
        let asked = Task { await desk.describePiece(with: gate) }
        await until("the model is asked") { gate.isHeld }
        desk.stopDescribe()
        XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.describeStoppedMessage))
        XCTAssertFalse(desk.isDescribing)
        XCTAssertTrue(desk.isModelBusy, "the backend ignores cancellation and still computes")
        await desk.undoLast()                                            // a typed request, while the model computes
        let afterUndo = desk.notice
        XCTAssertNotEqual(afterUndo?.message, EchoelAgentDesk.describeStoppedMessage, "the Undo ran and said so")
        gate.release(.success("Too late."))
        await asked.value
        XCTAssertEqual(desk.notice, afterUndo, "the stopped answer never overwrites the newer notice")
        XCTAssertFalse(desk.isModelBusy)
    }

    // MARK: 8 — the deadline frees the desk; the late answer is dropped

    func testTheDeadlineSaysSoAndTheLateAnswerIsDropped() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        desk.describeDeadline = .milliseconds(20)
        let gate = Gate()
        let asked = Task { await desk.describePiece(with: gate) }
        await until("the deadline ends the describe") {
            desk.notice?.state == .failed(EchoelAgentDesk.describeTimeoutMessage)
        }
        XCTAssertFalse(desk.isWorking)
        gate.release(.success("Too late."))
        await asked.value
        XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.describeTimeoutMessage))
    }

    // MARK: 9 — no second model call on top of one still computing

    func testASecondDescribeWhileTheModelComputesAsksNoModel() async {
        let (timeline, desk, original) = rig()
        defer { timeline.replaceDocument(original) }
        let gate = Gate()
        let asked = Task { await desk.describePiece(with: gate) }
        await until("the model is asked") { gate.isHeld }
        desk.stopDescribe()
        let second = StandIn(available: true, result: .success("unused"))
        await desk.describePiece(with: second)
        XCTAssertTrue(second.prompts.isEmpty, "the second tap asks no model while the first still computes")
        XCTAssertEqual(desk.notice?.state, .failed(EchoelAgentDesk.modelBusyMessage))
        gate.release(.success("Too late."))
        await asked.value
        let third = StandIn(available: true, result: .success("Now it answers."))
        await desk.describePiece(with: third)
        XCTAssertEqual(desk.notice?.message, "Now it answers.", "once the backend returned, a describe works again")
    }
}

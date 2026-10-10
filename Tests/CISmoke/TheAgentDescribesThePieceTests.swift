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

    private func rig() -> (TimelineStore, EchoelAgentDesk, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        let lane = TimelineLane(name: "Keys", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: []))
        let looks = UserDefaults(suiteName: "echoel.tests.agentDescribes") ?? UserDefaults()
        let desk = EchoelAgentDesk()
        desk.bind(EchoelCommandExecutor(timeline: timeline, clips: ClipStore(), selection: WorkstationSelection(),
                                        voiceCapacity: { 4 }, mediaLooks: MediaLookUndo(), visualDefaults: looks))
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
}

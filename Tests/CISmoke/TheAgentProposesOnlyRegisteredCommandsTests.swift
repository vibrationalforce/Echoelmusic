// TheAgentProposesOnlyRegisteredCommandsTests.swift
// EchoelAI step 1 (founder order 2026-09-27): the typed action layer. A planner proposes DATA;
// only a registered command with valid arguments becomes a plan, and nothing a proposal says
// can grant a permission.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–5 are END-TO-END on shipped, Foundation-only values (`EchoelCommandRegistry`,
//     `EchoelCommandParser`, `EchoelLevelMath`, `EchoelPlanning`, `EchoelExecutionReport`).
//   · Nothing here proves that a language model proposes well — no model is connected, and
//     claim 4 says so by driving the seam with none.
//
// HONEST GRADING against the parent (55f0f9e0f, §3): the file does not COMPILE there — every
// type it names is created by this commit — so no assertion has a verdict on the parent: ONE
// absence (#486); all claims are FORWARD guards. Hand-transcribed in Python; mutants driven,
// each red for its named reason: an unknown command id parsed as `describeState` (claim 2), a
// level past the range clamped instead of refused (claim 3), a planner error swallowed into an
// empty plan (claim 4), a partially failed request reported as done (claim 5).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAgentProposesOnlyRegisteredCommandsTests: XCTestCase {

    private let basis = EchoelProjectSnapshot(track: nil, part: nil, trackCount: 2, partCount: 3,
                                              agentCanUndo: false)

    // MARK: 1 — the registry: stable ids, every command specified, nothing irreversible reachable

    func testEveryCommandIsSpecifiedAndNoneIsIrreversible() {
        XCTAssertEqual(EchoelCommandID.allCases.map(\.rawValue),
                       ["project.describeState", "track.setLevel", "part.duplicateAfter", "agent.undoLast"],
                       "ids are a contract with every planner and transcript — renaming one breaks them")
        for spec in EchoelCommandRegistry.all {
            XCTAssertFalse(spec.summary.isEmpty)
            XCTAssertFalse(spec.effect.isEmpty)
            XCTAssertEqual(EchoelCommandRegistry.spec(spec.id), spec)
            if spec.changesProject {
                XCTAssertEqual(spec.permission, .reversibleEdit,
                               "`\(spec.id.rawValue)` changes the song, so it must be taken back by Undo")
            } else {
                XCTAssertEqual(spec.permission, .readOnly)
            }
            if case .explicitConsent = spec.permission {
                XCTFail("no step-1 command may publish, send, delete an original or overwrite an export")
            }
        }
        XCTAssertEqual(EchoelCommandRegistry.spec(.describeState).undo, .none)
        XCTAssertEqual(EchoelCommandRegistry.spec(.setTrackLevel).undo, .agentJournal)
        XCTAssertEqual(EchoelCommandRegistry.spec(.duplicatePart).undo, .agentJournal)
        XCTAssertEqual(EchoelCommandRegistry.spec(.undoAgentChange).undo, .isTheUndo)
    }

    // MARK: 2 — a proposal becomes a command only when it is registered and well-formed

    func testOnlyAWellFormedRegisteredProposalParses() {
        func parse(_ command: String, _ arguments: [String: String] = [:]) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: command, arguments: arguments))
        }
        XCTAssertEqual(parse("track.delete"), .failure(.unregistered("track.delete")),
                       "an unknown command is refused by name, never mapped to a near one")
        XCTAssertEqual(parse(""), .failure(.unregistered("")))
        XCTAssertEqual(parse("project.describeState"), .success(.describeState))
        XCTAssertEqual(parse("agent.undoLast"), .success(.undoAgentChange))

        XCTAssertEqual(parse("part.duplicateAfter", ["part": "selected"]), .success(.duplicatePart(part: .selected)))
        let id = UUID()
        XCTAssertEqual(parse("part.duplicateAfter", ["part": id.uuidString]), .success(.duplicatePart(part: .id(id))))
        XCTAssertEqual(parse("part.duplicateAfter"), .failure(.invalidArgument("that part")))
        XCTAssertEqual(parse("part.duplicateAfter", ["part": "the last one"]), .failure(.invalidArgument("that part")))

        XCTAssertEqual(parse("track.setLevel", ["track": "selected", "decibels": "\u{2212}3", "mode": "relative"]),
                       .success(.setTrackLevel(track: .selected, change: .relativeDecibels(-3))),
                       "the typographic minus the inspector prints is read as a minus")
        XCTAssertEqual(parse("track.setLevel", ["track": "selected", "decibels": "-6", "mode": "absolute"]),
                       .success(.setTrackLevel(track: .selected, change: .absoluteDecibels(-6))))
        for bad in ["nan", "inf", "loud", ""] {
            XCTAssertEqual(parse("track.setLevel", ["track": "selected", "decibels": bad, "mode": "relative"]),
                           .failure(.invalidArgument("that number of decibels")), "`\(bad)` is no level")
        }
        XCTAssertEqual(parse("track.setLevel", ["track": "selected", "decibels": "-3"]),
                       .failure(.invalidArgument("the level mode — relative or absolute")))
        XCTAssertEqual(parse("track.setLevel", ["decibels": "-3", "mode": "relative"]),
                       .failure(.invalidArgument("that track")))
    }

    // MARK: 3 — the level arithmetic refuses instead of clamping

    func testALevelPastTheRangeIsRefusedNotShortened() throws {
        XCTAssertEqual(EchoelLevelMath.maxDecibels, 20 * log10(2.0), accuracy: 1e-12,
                       "the ceiling is the inspector's own range (#416)")
        let down = try EchoelLevelMath.target(current: 1, change: .relativeDecibels(-3)).get()
        XCTAssertEqual(down, pow(10, -3.0 / 20), accuracy: 1e-12)
        XCTAssertEqual(TrackMix.decibelText(down), "−3.0 dB")
        XCTAssertEqual(try EchoelLevelMath.target(current: 0.3, change: .absoluteDecibels(0)).get(), 1, accuracy: 1e-12)
        XCTAssertEqual(try EchoelLevelMath.target(current: 1, change: .absoluteDecibels(6)).get(),
                       pow(10, 6.0 / 20), accuracy: 1e-12, "+6.0 dB fits under the ceiling")

        guard case .failure(.outOfRange(let why)) = EchoelLevelMath.target(current: 1.5, change: .relativeDecibels(3)) else {
            return XCTFail("+3 dB from +3.5 dB passes the ceiling and must be refused")
        }
        XCTAssertTrue(why.contains("+6.0 dB") && why.contains("+3.5 dB"), "the refusal names the limit and where it is: \(why)")
        guard case .failure(.outOfRange) = EchoelLevelMath.target(current: 1, change: .absoluteDecibels(6.03)) else {
            return XCTFail("an absolute level above the ceiling is refused")
        }
        XCTAssertEqual(EchoelLevelMath.target(current: 0, change: .relativeDecibels(-3)), .failure(.levelIsSilent),
                       "a silent track has no level to step from")
        XCTAssertEqual(EchoelLevelMath.target(current: 1, change: .relativeDecibels(.nan)),
                       .failure(.invalidArgument("that number of decibels")))
        XCTAssertEqual(EchoelLevelMath.target(current: 1, change: .absoluteDecibels(-.infinity)),
                       .failure(.invalidArgument("that number of decibels")))
    }

    // MARK: 4 — no model, a failing model, a half-valid proposal: no plan, and nothing grants consent

    private struct NoAnswer: Error {}

    private struct Planner: EchoelActionPlanning {
        let answer: [EchoelProposedAction]?
        func propose(_ request: String, state: EchoelProjectSnapshot) async throws -> [EchoelProposedAction] {
            guard let answer else { throw NoAnswer() }
            return answer
        }
    }

    func testAPlanComesOnlyFromACompleteValidProposal() async {
        let id = UUID()
        let none = await EchoelPlanning.plan(requestID: id, request: "copy it", planner: nil, basis: basis)
        XCTAssertEqual(none, .failure(.modelUnavailable), "no model is connected, and the answer says so")
        let failing = await EchoelPlanning.plan(requestID: id, request: "copy it", planner: Planner(answer: nil),
                                                basis: basis)
        XCTAssertEqual(failing, .failure(.modelFailed), "a model or network failure is reported, never an empty plan")
        let empty = await EchoelPlanning.plan(requestID: id, request: "copy it", planner: Planner(answer: []),
                                              basis: basis)
        XCTAssertEqual(empty, .failure(.invalidArgument("an empty answer")))

        let copy = EchoelProposedAction(command: "part.duplicateAfter", arguments: ["part": "selected"])
        let half = await EchoelPlanning.plan(requestID: id, request: "copy it and share it",
                                             planner: Planner(answer: [copy, EchoelProposedAction(command: "song.publish", arguments: [:])]),
                                             basis: basis)
        XCTAssertEqual(half, .failure(.unregistered("song.publish")),
                       "one unknown action rejects the whole proposal — a half-understood request never half-runs")

        let smuggled = EchoelProposedAction(command: "part.duplicateAfter",
                                            arguments: ["part": "selected", "consents": "publish,deleteOriginal"])
        let plan = await EchoelPlanning.plan(requestID: id, request: "copy it", planner: Planner(answer: [smuggled]),
                                             basis: basis)
        guard case .success(let made) = plan else { return XCTFail("a valid proposal plans") }
        XCTAssertEqual(made.steps, [.duplicatePart(part: .selected)])
        XCTAssertEqual(made.basis, basis, "the plan remembers the state it was made against")
        XCTAssertTrue(made.consents.isEmpty, "a proposal's text grants nothing; only the person adds a consent")
    }

    // MARK: 5 — the report says done only when every step is done

    func testTheReportNamesPartialSuccessAndRefusals() {
        let id = UUID()
        let copy = EchoelCommand.duplicatePart(part: .selected)
        let quieter = EchoelCommand.setTrackLevel(track: .selected, change: .relativeDecibels(-3))
        let all = EchoelExecutionReport(requestID: id, steps: [.init(command: copy, outcome: .done("Copied."))],
                                        replayed: false, refusal: nil)
        XCTAssertEqual(all.state, .done)
        XCTAssertFalse(all.isPartial)

        let partial = EchoelExecutionReport(
            requestID: id,
            steps: [.init(command: copy, outcome: .done("Copied.")),
                    .init(command: quieter, outcome: .failed(.noLevel("Bio curve — no sound"))),
                    .init(command: copy, outcome: .notRun)],
            replayed: false, refusal: nil)
        XCTAssertTrue(partial.isPartial)
        XCTAssertEqual(partial.state, .failed("1 of 3 done. This track has no level to change (Bio curve — no sound)."))

        let cancelled = EchoelExecutionReport(requestID: id, steps: [.init(command: copy, outcome: .cancelled)],
                                              replayed: false, refusal: nil)
        XCTAssertEqual(cancelled.state, .failed("Cancelled."))

        let changed = EchoelExecutionReport(requestID: id, steps: [.init(command: copy, outcome: .notRun)],
                                            replayed: false, refusal: .projectChanged)
        XCTAssertEqual(changed.state, .needsAnswer(EchoelCommandError.projectChanged.message),
                       "a changed song is a question to the person, not a failure")
        XCTAssertEqual(EchoelExecutionReport(requestID: id, steps: [], replayed: false, refusal: .busy).state,
                       .failed(EchoelCommandError.busy.message))
        for state in [EchoelAgentState.understood, .running, .done, .needsAnswer("?"), .failed("x")] {
            XCTAssertFalse(state.title.isEmpty, "every state has a word — never colour alone")
        }
        for error in [EchoelCommandError.busy, .projectChanged, .levelIsSilent, .modelUnavailable, .modelFailed,
                      .nothingToUndo, .notArrangeable, .unregistered("x"), .consentRequired(.publish)] {
            XCTAssertFalse(error.message.lowercased().contains("error"), "plain words: \(error.message)")
        }
    }
}

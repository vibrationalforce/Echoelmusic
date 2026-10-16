// TheOnDeviceModelHasOneGateTests.swift
// Echoel — GMMW AI-3. "Is the on-device model there?" has ONE reader, and a model failure is
// mapped by TYPE, never by the text of the error.
//
// WHAT THIS GUARDS.
//   1. SOURCE-TEXT SCAN: exactly one `.availability` read of the system model in `Sources/`, inside
//      `Core/OnDeviceModelGate.swift`. Before AI-3 there were three (the gate and the brain twice).
//   2. SOURCE-TEXT SCAN: `FoundationModelsBrain` asks the gate, carries no `String(describing:`
//      (an error's description can echo user text into a log), no `try?`, and maps the two typed
//      cases — guardrail → `.refused`, context window → `.contextOverflow`.
//   3. BEHAVIOUR: every `OnDeviceModelStatus` has a non-empty sentence without the word "AI"
//      (that copy is founder-gated, AI-8), and `isOnDeviceLLMAvailable` agrees with `status`.
//   4. SOURCE-TEXT SCAN (lifted by AI-4, sharpened by GSIDMMW C2b 2026-10-16): exactly one
//      production `FoundationModelsBrain(`, in the banner's private `onDeviceBrain()`, and that has
//      exactly TWO callers, both started by the person: `describePiece` (only the ≡ menu's Button
//      calls it) and `ask` (only `AskEchoelIntent` calls it — a request spoken or typed, which
//      only PROPOSES; the piece changes on the Apply tap). Graded against `0c6e0de`: the old
//      claim's literal (`describePiece(with: FoundationModelsBrain())`) is gone by design, so the
//      new needles are FORWARD guards; the one-construction count is a COUNTERWEIGHT, green on both.
//
// ⚠️ THE LIMIT. The runtime VALUE of `status` is not asserted: on iOS 26 simulators it follows the
// CI host Mac's Apple Intelligence state (`BioMusicDirectorTests` skips for the same reason). The
// typed `GenerationError` cases are proven only by the Xcode Compile Check on the iOS 26 SDK; a
// real answer from the model is NEEDS-FOUNDER-VERIFY.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheOnDeviceModelHasOneGateTests: XCTestCase {

    func testTheModelsAvailabilityHasOneReader() throws {
        let hits = try Self.codeFiles().filter { $0.code.contains("SystemLanguageModel.default.availability") }
        XCTAssertEqual(hits.map(\.path), ["Sources/Echoelmusic/Core/OnDeviceModelGate.swift"],
                       "AI-3: only OnDeviceModelGate reads the model's availability; everyone else asks `OnDeviceModelGate.status`.")
        let gate = try XCTUnwrap(hits.first)
        XCTAssertEqual(gate.code.components(separatedBy: "SystemLanguageModel.default.availability").count - 1, 1,
                       "AI-3: the gate reads availability exactly once.")
    }

    func testTheBrainMapsFailuresByType() throws {
        let brain = try XCTUnwrap(try Self.codeFiles().first { $0.path.hasSuffix("EchoelAI/FoundationModelsBrain.swift") })
        XCTAssertTrue(brain.code.contains("OnDeviceModelGate.status"), "The brain must ask the gate.")
        XCTAssertFalse(brain.code.contains("String(describing:"), "Never put an error's description in a payload.")
        XCTAssertFalse(brain.code.contains("try?"), "A model failure is never swallowed.")
        XCTAssertTrue(brain.code.contains(".guardrailViolation"), "Guardrail → .refused, by type.")
        XCTAssertTrue(brain.code.contains(".exceededContextWindowSize"), "Context window → .contextOverflow, by type.")
        XCTAssertTrue(brain.code.contains("EchoelAIError.contextOverflow"))
        XCTAssertFalse(brain.code.contains("localizedCaseInsensitiveContains"), "No mapping by text.")
    }

    func testEveryStatusSaysWhyInPlainWords() {
        let all: [OnDeviceModelStatus] = [.available, .deviceNotEligible, .appleIntelligenceOff,
                                          .modelNotReady, .osTooOld, .frameworkAbsent]
        for status in all {
            XCTAssertFalse(status.sentence.isEmpty, "\(status) needs a sentence.")
            XCTAssertNil(status.sentence.range(of: #"\bAI\b"#, options: .regularExpression),
                         "\(status): no \"AI\" wording before the founder decides AI-8.")
        }
        XCTAssertEqual(OnDeviceModelGate.isOnDeviceLLMAvailable, OnDeviceModelGate.status == .available)
    }

    /// AI-4 lifted claim 4; GSIDMMW C2b sharpened it: still exactly ONE production construction,
    /// now in the banner's private factory, and exactly two callers of that — a tap and an intent.
    func testTheBrainIsConstructedOnlyWhenThePersonAsks() throws {
        let files = try Self.codeFiles()
        let hits = files.filter {
            $0.code.contains("FoundationModelsBrain(") && !$0.path.hasSuffix("EchoelAI/FoundationModelsBrain.swift")
        }
        XCTAssertEqual(hits.map(\.path), ["Sources/Echoelmusic/Studio/AgentReportBanner.swift"])
        let banner = try XCTUnwrap(hits.first?.code)
        XCTAssertEqual(banner.components(separatedBy: "FoundationModelsBrain(").count - 1, 1)
        XCTAssertTrue(banner.contains("private static func onDeviceBrain() -> any BrainBackend {"),
                      "the one construction sits in a PRIVATE factory, so nothing outside the banner can call it")
        XCTAssertEqual(banner.components(separatedBy: "onDeviceBrain()").count - 1, 3,
                       "the factory and exactly two calls — a third caller is a new way to start the model")
        XCTAssertTrue(banner.contains("Task { await EchoelAgentDesk.shared.describePiece(with: onDeviceBrain()) }"))
        XCTAssertTrue(banner.contains("await EchoelAgentDesk.shared.proposePlan(for: request, with: onDeviceBrain())"),
                      "the second call only PROPOSES — the desk changes nothing until Apply")

        let describers = files.filter { $0.code.contains("AgentReportBanner.describePiece()") }
        XCTAssertEqual(describers.map(\.path), ["Sources/Echoelmusic/Studio/WorkspaceView.swift"])
        let root = try XCTUnwrap(describers.first?.code)
        XCTAssertTrue(root.contains("Button { AgentReportBanner.describePiece() }"), "only a tap asks for a description")

        let askers = files.filter { $0.code.contains("AgentReportBanner.ask(") }
        XCTAssertEqual(askers.map(\.path), ["Sources/Echoelmusic/Studio/EchoelAppIntents.swift"])
        let intents = try XCTUnwrap(askers.first?.code)
        XCTAssertEqual(intents.components(separatedBy: "AgentReportBanner.ask(").count - 1, 1)
        let intent = try XCTUnwrap(intents.range(of: "struct AskEchoelIntent: AppIntent {"))
        let call = try XCTUnwrap(intents.range(of: "await AgentReportBanner.ask(request)"))
        XCTAssertLessThan(intent.lowerBound, call.lowerBound, "the one asker is the Ask Echoel intent")
    }

    // MARK: - helpers

    private static func codeFiles() throws -> [(path: String, code: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not reachable from the test bundle")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            out.append((String(url.path.dropFirst(root.path.count + 1)), code))
        }
        return out.sorted { $0.0 < $1.0 }
    }
}

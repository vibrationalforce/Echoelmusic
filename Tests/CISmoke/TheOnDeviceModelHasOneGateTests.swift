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
//   4. SOURCE-TEXT SCAN: no production `FoundationModelsBrain(` yet — AI-4 adds exactly one, from a
//      tap, and lifts this claim in the same commit.
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

    func testTheBrainHasNoProductionConstructionYet() throws {
        let hits = try Self.codeFiles().filter {
            $0.code.contains("FoundationModelsBrain(") && !$0.path.hasSuffix("EchoelAI/FoundationModelsBrain.swift")
        }
        XCTAssertEqual(hits.map(\.path), [],
                       "AI-4 adds exactly one construction, from a tap — lift this claim in that commit.")
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

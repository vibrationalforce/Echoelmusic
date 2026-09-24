// TheBioMirrorTakesTheWrittenValueTests.swift
// Echoel — 2026-09-24 (overnight P8i): a write to one AUv3 bio parameter moves exactly that
// parameter's render mirror, from the value the observer was handed, finite and inside the range
// the tree declares. Blocking bundle.
//
// THE DEFECT (measured before the repair). The value observer refreshed ALL FOUR bio mirrors from
// `self.coherenceParam.value` … `self.breathPhaseParam.value` on every bio write, and mirrored
// them raw:
// · Whether an `AUParameter` has stored the new value before `implementorValueObserver` runs is
//   not documented in reach. If it has not, the parameter being written is read one write behind
//   — a factory preset's single `legacyCoherenceSeed` would never reach the texture.
// · An out-of-range host value (automation is not bound by the tree's range) reached the render:
//   heart rate drives the fallback vibrato `0.004 + heartRate * 0.02` in `EchoelDDSP`, the one the
//   AUv3 runs; a non-finite one was left to `applyBioReactive`'s sanitiser.
//
// THE REPAIR. Non-finite is refused (the mirror keeps what sounds); anything else is clamped to
// `EchoelBodyVibeAUv3Mapping.legacyLiveControlRange`, the SAME constant the tree is built from
// (#416); only the addressed mirror moves.
//
// WHAT KIND OF GREEN (§1): claim 1 is a SOURCE-TEXT SCAN of the observer (the extension cannot be
// instantiated here). Claim 2 is END-TO-END BEHAVIOUR of the shipped mapping — the clamp and the
// tree share one range. HOST: whether any host writes out-of-range bio values, and Apple's store
// order, are unmeasured; the repair makes both not matter.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the range at 0…1; claim 2 reads it.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `97faa961d`: claim 1 is a
// REGRESSION — one finding (the parent reads the four `…Param.value`s and has no finite gate).
// Claim 2 is a COUNTERWEIGHT, green on both trees; it names only symbols that exist there.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBioMirrorTakesTheWrittenValueTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1 (SOURCE-TEXT SCAN)

    func testEachBioWriteMovesOnlyItsOwnMirrorFromTheWrittenValue() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let observer = try XCTUnwrap(Self.body(
            startingWith: "_parameterTree.implementorValueObserver = {", in: code),
            "the value observer is not found — re-anchor this guard (#456)")
        for stale in ["self.coherenceParam.value", "self.hrvParam.value",
                      "self.heartRateParam.value", "self.breathPhaseParam.value"] {
            XCTAssertFalse(observer.contains(stale), """
                The observer reads `\(stale)` again instead of the value it was handed — one \
                write behind if the parameter stores after notifying.
                """)
        }
        XCTAssertTrue(observer.contains("guard value.isFinite else { return }"),
                      "a non-finite bio value is no longer refused before it reaches a mirror")
        XCTAssertTrue(observer.contains("value.clamped(to: EchoelBodyVibeAUv3Mapping.legacyLiveControlRange)"),
                      "the bio value is no longer clamped to the range the tree declares")
        for mirror in ["self.bioMirror.coherence = v", "self.bioMirror.hrv = v",
                       "self.bioMirror.heartRate = v", "self.bioMirror.breathPhase = v",
                       "self.texture.coherence = v"] {
            XCTAssertEqual(observer.components(separatedBy: mirror).count - 1, 1,
                           "`\(mirror)` is not written exactly once from the admitted value")
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT, behaviour)

    func testTheClampAndTheTreeShareOneRange() throws {
        let range = EchoelBodyVibeAUv3Mapping.legacyLiveControlRange
        XCTAssertLessThanOrEqual(range.lowerBound, range.upperBound)
        var live = 0
        for r in try EchoelBodyVibeAUv3Mapping.resolve() {
            guard case .legacyLiveControl(_) = r.target else { continue }
            live += 1
            XCTAssertEqual(r.min, range.lowerBound, "\(r.identifier): the tree's minimum is not the clamp's")
            XCTAssertEqual(r.max, range.upperBound, "\(r.identifier): the tree's maximum is not the clamp's")
            XCTAssertTrue(range.contains(r.defaultValue), "\(r.identifier): the default lies outside the clamp")
        }
        XCTAssertEqual(live, 4, "the four bio parameters are no longer all live controls — re-read the observer")
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

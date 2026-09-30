// TheDarkLensSaysNoLightTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// the pulse's hardware rung: "„kein Licht“ am Puls".
//
// WHAT IT GUARDS. `CameraCapture.applyTorch` has latched "no light on the finger" into
// `torchUnavailable` since #1380 — torch absent, thermally refused, or control failed — and the
// flag had NO reader: a dark torch and a badly placed finger were indistinguishable to the
// player, who was coached "Cover lens" / "Hold still" for a finger that could not be read however
// it sat. Now `PulseCue.noLight` exists, `CameraRPPGBioPublisher.placementCue` returns it right
// after the lock test (a lamp-lit finger can lock with the torch dark, and a real lock outranks
// coaching) and before every finger cue, gated on `isRunning` so an idle publisher never carries
// last take's dark torch into the next. The header goes amber ("No light"); the wrapping slot
// shows the remedy: let it cool, or lend the lens a lamp.
//
// §1 LIMIT: claim 1 is END-TO-END BEHAVIOUR on `PulseCue` (pure, Foundation-only). Claims 2–4
// are SOURCE-TEXT SCANS: where the read sits, that the latch has a producer and a clearing site,
// that the header renders actionable cues. Whether a hot iPhone actually shows "No light" is a
// DEVICE PROBE (NEEDS-FOUNDER-VERIFY: run a long take until the thermal breadcrumb appears).
//
// §3 HONEST GRADING. This file names a NEW case (`.noLight`), so it does not compile against
// the parent (71265d0fc): NO assertion has a verdict there. Hand-transcribed in Python against
// both trees: claim 1 FORWARD (the case is new); claim 2 red on the parent by ANCHOR ABSENCE
// (no `.noLight` line in `placementCue` — one absence, reported once, #486); claims 3–4 are
// COUNTERWEIGHTS, green on both trees. Sibling guards extended in the same commit rather than
// left to rot: `TheStallRemedyReachesTheScreenTests` (warranting list, method renamed to say what
// it now proves), `PulseCueTests` (non-blocking). ZERO regressions claimed. Stripper
// `SourceText.codeOnly`: PROPHYLAKTISCH (0 of 4 verdicts flip — no comment quotes an anchor).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDarkLensSaysNoLightTests: XCTestCase {

    private static let publisher = "Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"
    private static let capture = "Sources/Echoelmusic/Video/CameraCapture.swift"
    private static let header = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    private static let inputWords: Set<String> = ["mic", "microphone", "input", "inputs"]

    // MARK: - Claim 1 — the cue's words, in every form (END-TO-END)

    func testTheNoLightCueNamesTheLightAndItsRemedy() {
        let cue = PulseCue.noLight
        XCTAssertEqual(cue.shortLabel, "No light")
        XCTAssertLessThanOrEqual(cue.shortLabel.count, 12, "the header slot law (AStalledAcquisitionSaysSoTests)")
        XCTAssertTrue(cue.isActionable, "amber in the header — a lamp is reachable, cooling is knowable")
        XCTAssertTrue(cue.warrantsFullHintOnScreen,
                      "the remedy lives only in `fullHint`; its source is a latch, so the wrapping slot is safe")
        let hint = cue.fullHint.lowercased()
        XCTAssertTrue(hint.contains("lamp"), "the remedy names another light: \(cue.fullHint)")
        XCTAssertTrue(hint.contains("cool"), "the remedy names the cause a hot phone can wait out: \(cue.fullHint)")
        XCTAssertFalse(hint.contains("finger still") || hint.contains("cover the"),
                       "no finger coaching — the finger is not the problem")
        XCTAssertNotEqual(cue.fullHint, PulseCue.coverLens.fullHint)
        for text in [cue.fullHint, cue.shortLabel] {
            let hit = words(text).intersection(Self.inputWords)
            XCTAssertTrue(hit.isEmpty, "\(text) — speaks of an input that does not exist (#1302): \(hit)")
        }
    }

    // MARK: - Claim 2 — the read sits after the lock and before every finger cue (SCAN)

    func testTheDarkTorchIsReadAfterTheLockAndBeforeTheFingerCues() throws {
        let body = try functionBody("private var placementCue: PulseCue {", in: try source(Self.publisher))
        let line = "if isRunning, capture.isTorchUnavailable { return .noLight }"
        guard let lock = body.range(of: "if isLocked { return .locked }"),
              let dark = body.range(of: line),
              let finger = body.range(of: "if !fingerDetected { return .coverLens }") else {
            return XCTFail("ANCHOR MISSING in `placementCue`: lock test, the no-light line, or the cover-lens test")
        }
        XCTAssertTrue(lock.upperBound <= dark.lowerBound && dark.upperBound <= finger.lowerBound,
                      "a real lock outranks coaching; a dark torch outranks every finger cue")
        XCTAssertEqual(occurrences(of: ".noLight", in: body), 1, "one producer of the cue in the classifier")
    }

    // MARK: - Claim 3 — COUNTERWEIGHT: the latch has producers AND a clearing site (SCAN)

    func testTheTorchLatchIsProducedAndCleared() throws {
        let code = try source(Self.capture)
        XCTAssertTrue(code.contains("var isTorchUnavailable: Bool { torchUnavailable }"),
                      "the owner-visible mirror the publisher reads")
        XCTAssertGreaterThanOrEqual(occurrences(of: "torchUnavailable = true", in: code), 3,
                                    "absent · thermal · control failed — three ways to have no light")
        XCTAssertGreaterThanOrEqual(occurrences(of: "torchUnavailable = false", in: code), 1,
                                    "a latch nothing clears would say No light for the rest of the session")
        XCTAssertTrue(code.contains("device.isTorchActive"),
                      "the clear reads what the device REPORTS, not what was asked")
    }

    // MARK: - Claim 4 — COUNTERWEIGHT: an actionable cue reaches the header as its short label (SCAN)

    func testTheHeaderRendersActionableCues() throws {
        let code = try source(Self.header)
        XCTAssertTrue(code.contains("private var showCue: Bool { !locked && (cue?.isActionable ?? false) }"),
                      "`isActionable` is what turns the tile amber and shows a label at all")
        XCTAssertTrue(code.contains("Text(cue.shortLabel)"), "the short label is what the header renders")
    }

    // MARK: - Helpers

    private func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init))
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func functionBody(_ head: String, in code: String) throws -> String {
        guard let start = code.range(of: head) else {
            throw AnchorMissing(reason: "`\(head)` is gone")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}

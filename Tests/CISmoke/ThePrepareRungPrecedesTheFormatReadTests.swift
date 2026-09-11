// ThePrepareRungPrecedesTheFormatReadTests.swift
// Echoel — #1251 (S6 of `PLAN_AUDIO_INPUT_2026-09-11.md`). Hypothesis #5 of the
// `isInputConnToConverter` crash family is BUILT: `masterEngine.prepare()` runs between the
// record-route claim and the input-format read, with its own positional rung.
//
// WHY ONE HYPOTHESIS PER SLICE. v421–v435 died on the same assert through four repairs, each
// a labelled hypothesis (#823 stop-not-pause, #831/#835 no surgery on a running render, #954
// rate substitution, #975/#976 configure-before-claim). #954b's reviewer recorded two more
// and the code said "recorded rather than built" so the next log would be decidable. This
// slice builds the cheaper one and leaves #6 (connect on the running engine) recorded.
//
// SOURCE-TEXT SCAN: order and presence in `setInputMonitoring`. Whether `prepare()` rebuilds
// the INPUT scope of the I/O unit is the hypothesis itself — a DEVICE PROBE, NEEDS-FOUNDER-
// VERIFY at the rung.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`77d41a7`) and this tree: claims
// 1–3 RED on the parent (claim 3 only by its last needle — the "#5 IS BUILT" sentence did not
// exist; its ladder and #6 halves were GREEN there), all GREEN here. Claim 3 reads the RAW
// file on purpose (the hypothesis prose IS a comment): with the stripper it would be red on
// both trees — TRAGEND, 1 of 3 verdicts flips; claims 1–2 PROPHYLAKTISCH.

import Foundation
import XCTest

final class ThePrepareRungPrecedesTheFormatReadTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    /// Claim 1 — the rung and the call exist, once, inside the ON path.
    func testThePrepareCallHasItsRung() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        XCTAssertEqual(on.components(separatedBy: "masterEngine.prepare()").count - 1, 1,
                       "`masterEngine.prepare()` must run exactly once on the monitoring ON path (#1251)")
        XCTAssertEqual(on.components(separatedBy: "on: prepared before format read (#1251)").count - 1, 1,
                       "the prepare rung is gone — a log could no longer say whether control died inside `prepare()` (#1251)")
    }

    /// Claim 2 — order: claim → prepare → format read.
    func testPrepareSitsBetweenTheClaimAndTheFormatRead() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        let claim = try XCTUnwrap(on.range(of: "claimRecordRoute(.inputMonitoring)")).lowerBound
        let prepare = try XCTUnwrap(on.range(of: "masterEngine.prepare()")).lowerBound
        let read = try XCTUnwrap(on.range(of: "var inFmt = input.inputFormat(forBus: 0)")).lowerBound
        XCTAssertLessThan(claim, prepare, "`prepare()` before the route claim builds the I/O unit against the WRONG session (#1251)")
        XCTAssertLessThan(prepare, read, "`prepare()` after the format read leaves the read a pre-rebuild guess — the hypothesis is not being tested (#1251)")
    }

    /// Claim 3 — counterweight: the numbered ladder is untouched and hypothesis #6 stays recorded.
    func testTheLadderIsUnchangedAndHypothesisSixStaysRecorded() throws {
        let raw = try text(Self.engine)
        for rung in ["on 1/5", "on 2/5", "on 3/5", "on 4/5", "on 5/5"] {
            XCTAssertTrue(raw.contains("\"\(rung)"), "rung `\(rung)` left the ladder — `scripts/diag-ladder.py` audits 1..5 (#854/#1251)")
        }
        XCTAssertTrue(raw.contains("HYPOTHESIS #6 — connect the monitor chain on the RUNNING engine"),
                      "hypothesis #6 is no longer recorded — if #5 fails on a device, the next candidate must be findable here (#1251)")
        XCTAssertTrue(raw.contains("#5 IS BUILT SINCE"), "the hypothesis list no longer says #5 is built (#425 — a note must not refute its own code)")
    }

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

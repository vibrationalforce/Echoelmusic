// TheVitalsTimerDiesWithTheUnitTests.swift
// Echoel — 2026-09-24 (overnight P8k): every path that drops the AUv3's `vitalsTimer` cancels it
// first — including the unit's own `deinit`. Blocking bundle.
//
// THE DEFECT (measured before the repair). `startVitalsPolling` resumes a 10 Hz
// `DispatchSourceTimer` at `allocateRenderResources`. Two drop paths cancelled it (re-arm in
// `startVitalsPolling`, and `deallocateRenderResources`); the THIRD did not exist: the class had
// no `deinit`, so a host that releases the unit without `deallocateRenderResources()` released a
// resumed, un-cancelled source. Found by tonight's read-only audit agent (its finding 8).
// ⚠️ CORRECTED 2026-09-25 (review 9): the outcome was neither the trap `startVitalsPolling`'s
// #1385 comment claimed nor the leak the agent guessed. libdispatch traps on release only for a
// suspended or inactive source, or a strict source with a mandatory cancel handler, and cancels a
// plain resumed source on its last release. So this guard pins a DEFENSIVE cancel (an explicit
// lifecycle that survives a future cancel handler), not the repair of a live crash.
//
// THE REPAIR. `deinit { vitalsTimer?.cancel() }` — idempotent, so the ordinary path is unchanged.
//
// WHAT KIND OF GREEN (§1): SOURCE-TEXT SCANS (comment-stripped). The extension cannot be
// instantiated here, and a teardown is not a unit-testable event. HOST: a teardown that
// skips `deallocateRenderResources` is unmeasured on any real host.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `66748c221`: claim 1 is a
// REGRESSION — one finding (no `deinit` cancels the timer there; the only `deinit` in the file is
// `RenderScratch`'s). Claim 2 is a COUNTERWEIGHT — the two existing cancel paths — green on both.
// The file names no `Sources/` symbol, so it compiles on both.

import Foundation
import XCTest

final class TheVitalsTimerDiesWithTheUnitTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    func testTheUnitsDeinitCancelsTheTimer() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let deinits = Self.bodies(startingWith: "deinit {", in: code)
        XCTAssertTrue(deinits.contains { $0.contains("vitalsTimer?.cancel()") }, """
            No `deinit` cancels `vitalsTimer`. A host that releases the unit without \
            `deallocateRenderResources()` then drops a resumed, un-cancelled DispatchSource.
            """)
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testTheOtherTwoDropPathsStillCancel() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let start = try XCTUnwrap(Self.bodies(startingWith: "private func startVitalsPolling() {", in: code).first,
                                  "`startVitalsPolling` not found — re-anchor this guard (#456)")
        let cancel = try XCTUnwrap(start.range(of: "vitalsTimer?.cancel()"),
                                   "re-arming no longer cancels the previous timer")
        let replace = try XCTUnwrap(start.range(of: "vitalsTimer = timer"),
                                    "the timer is no longer stored — re-anchor this guard (#456)")
        XCTAssertLessThan(cancel.lowerBound, replace.lowerBound, "the old timer is replaced before it is cancelled")
        let dealloc = try XCTUnwrap(Self.bodies(startingWith: "public override func deallocateRenderResources() {",
                                                in: code).first,
                                    "`deallocateRenderResources` not found — re-anchor this guard (#456)")
        XCTAssertTrue(dealloc.contains("vitalsTimer?.cancel()"), "deallocate no longer cancels the timer")
    }

    // MARK: - helpers

    /// Every brace-matched body that starts at an occurrence of `anchor`.
    private static func bodies(startingWith anchor: String, in code: String) -> [String] {
        var found: [String] = []
        var searchStart = code.startIndex
        while let start = code.range(of: anchor, range: searchStart..<code.endIndex) {
            var depth = 0
            var out = ""
            for ch in code[start.lowerBound...] {
                if ch == "{" { depth += 1 }
                if depth > 0 { out.append(ch) }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
            }
            found.append(out)
            searchStart = start.upperBound
        }
        return found
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

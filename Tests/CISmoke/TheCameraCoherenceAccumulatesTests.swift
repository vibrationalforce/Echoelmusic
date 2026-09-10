// TheCameraCoherenceAccumulatesTests.swift
// Echoel — #1220 (audit 2026-09-10 `bio-pipeline-3`). The camera's coherence is computed on a
// per-take rolling RR history, so it reaches `HRVCoherence.minIntervals` at ANY pulse.
//
// THE DEFECT. `CameraRPPGBioPublisher` handed `HRVCoherence.compute` the analyzer's
// `rrIntervals`, which `CameraAnalyzer.detectPeaks` rebuilds WHOLE from a fixed 10 s peak window
// on every call. `HRVCoherence.minIntervals` is 16, so a valid reading needed ≥17 clean peaks in
// 10 s — a sustained ≳102 bpm. At a resting pulse the camera's coherence was structurally absent
// for the whole take: the four LIVE coherence mappings (`AlwaysOnBioChannel`), the Flow servo
// (`BioComposer.tempo(for:)`), `/echoelmusic/bio/coherence` and ADM-OSC `distance` all ran on the
// neutral on the flagship source. Three source files said so; nothing changed it.
//
// WHAT THIS PINS. (1) FLOOR, by behaviour on the pure core: `HRVCoherence.tachogram` returns nil
// for the ~10 intervals a resting 10 s window holds and a series for 16 — the reason a
// rebuilt window cannot cross the floor and an accumulating history can. (2) FEED, by text: the
// history is appended INSIDE the beat-cursor loop after its plausibility guard (one cursor, one
// band, two consumers), and the coherence line reads the HISTORY, not `rrMs`. (3) CAP, by value
// and text: bounded at the strap's length and pruned from the front. (4) PER-TAKE, by text:
// cleared in `stop()` beside the cursor it shares. The publisher is `private`-fielded, camera-
// driven and behind `#if canImport(AVFoundation)`, so claims 2–4 are source scans; the limit.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`46e4f3c`) and this tree: claim 1
// GREEN on both (the core did not change; it is the counterweight that says WHY); claims 2, 3
// and 4 RED on the parent (no history exists there), GREEN here.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCameraCoherenceAccumulatesTests: XCTestCase {

    /// Claim 1 — the floor: a resting 10 s window (~10 intervals) can never cross it, 16 can.
    func testTheFloorIsACountARebuiltWindowCannotReach() {
        let restingWindow = [Double](repeating: 1000, count: 10)    // 60 bpm × 10 s
        XCTAssertNil(HRVCoherence.tachogram(rrMs: restingWindow),
                     "10 intervals produced a tachogram — the floor moved, re-read #1220's premise")
        let accumulated = [Double](repeating: 1000, count: HRVCoherence.minIntervals)
        XCTAssertNotNil(HRVCoherence.tachogram(rrMs: accumulated),
                        "16 accepted intervals no longer cross the floor (#1220)")
        XCTAssertEqual(HRVCoherence.minIntervals, 16,
                       "the floor changed — CLAUDE.md's DDSP table and the OSC header quote 16")
    }

    /// Claim 2 — the feed: appended inside the cursor loop, after the band; coherence reads it.
    func testTheHistoryIsFedByTheCursorAndReadByTheCoherenceLine() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"))
        let band = "guard ms > 250, ms < 2000 else { continue }"
        let feed = "self.coherenceRRHistory.append(ms)"
        let ingest = "self.respiration.ingest(heartRate: 60_000.0 / ms, at: t)"
        guard let bandAt = src.range(of: band), let feedAt = src.range(of: feed),
              let ingestAt = src.range(of: ingest) else {
            return XCTFail("the cursor loop, its plausibility band or the history feed is gone (#1220)")
        }
        XCTAssertTrue(bandAt.upperBound <= feedAt.lowerBound && feedAt.upperBound <= ingestAt.lowerBound,
                      "the history is no longer fed between the plausibility band and the respiration ingest — one cursor, one band, two consumers (#1220)")
        XCTAssertTrue(src.contains("HRVCoherence.compute(rrMs: self.coherenceRRHistory, blend: 1.0)"),
                      "the coherence line no longer reads the rolling history (#1220)")
        XCTAssertFalse(src.contains("HRVCoherence.compute(rrMs: rrMs"),
                       "the coherence line reads the analyzer's rebuilt 10 s window again — at rest the camera's coherence is absent for the whole take (#1220)")
        // The line must read the history AFTER the loop fed it, or a beat counts one tick late.
        if let computeAt = src.range(of: "HRVCoherence.compute(rrMs: self.coherenceRRHistory") {
            XCTAssertTrue(feedAt.upperBound <= computeAt.lowerBound,
                          "the coherence line runs before the cursor loop feeds the history (#1220)")
        }
    }

    /// Claim 3 — the cap: the strap's length, pruned from the front.
    func testTheHistoryIsCappedAtTheStrapsLength() throws {
        XCTAssertEqual(CameraRPPGBioPublisher.coherenceHistoryCapacity, 64,
                       "the camera and the strap (`PolarH10BioPublisher.maxRRIntervals`) no longer share a history length")
        XCTAssertGreaterThanOrEqual(CameraRPPGBioPublisher.coherenceHistoryCapacity, 2 * HRVCoherence.minIntervals,
                                    "a cap under twice the floor leaves no room for a breath change to show")
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"))
        XCTAssertTrue(src.contains("if self.coherenceRRHistory.count > Self.coherenceHistoryCapacity {"),
                      "the history is no longer pruned at the cap (#1220)")
        XCTAssertTrue(src.contains("self.coherenceRRHistory.removeFirst()"),
                      "the history is pruned from the wrong end, or not at all (#1220)")
    }

    /// Claim 4 — per-take: cleared in `stop()` beside the cursor it shares.
    func testTheHistoryIsClearedWithTheCursor() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"))
        let cursorReset = "lastRespirationBeatTime = 0\n"
        let historyReset = "coherenceRRHistory.removeAll(keepingCapacity: true)"
        guard let cursorAt = src.range(of: cursorReset), let historyAt = src.range(of: historyReset) else {
            return XCTFail("`stop()` no longer clears the cursor and the history together (#1220)")
        }
        XCTAssertTrue(cursorAt.upperBound <= historyAt.lowerBound,
                      "the history is cleared somewhere other than beside the cursor — the next take's first coherence would be a spectrum over the previous body's beats (#1220)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

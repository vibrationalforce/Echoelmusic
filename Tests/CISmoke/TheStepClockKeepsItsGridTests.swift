// TheStepClockKeepsItsGridTests.swift
// Echoel — #1223 (audit 2026-09-10 `sequencer-core-2`). The step clock re-arms from its IDEAL
// grid, so main-thread latency no longer accumulates into the note clock.
//
// THE DEFECT. `PatternEngine.scheduleTick` was a one-shot main-queue timer armed at
// `.now() + interval` as the LAST line of `advance()` — after `transport?.tick`, the `onStep`
// fan-out, `onTick` and the glide relay. Timer-fire latency AND the handler's own run time
// therefore landed in every next deadline as a permanent phase loss: the note clock ran at
// ≤ nominal BPM and slipped against the click (an audio-thread phase accumulator, resynced
// only at Start) and against gear following the 24-PPQN MIDI clock (a repeating timer).
// `Transport.currentTick(at:)` derives position from the late tick, so the roll never saw it.
//
// WHAT THIS PINS. (1) GRID, by behaviour on the pure helper: a late handler does not move
// the next deadline; a chain of late calls stays on the ideal grid. (2) RE-ANCHOR: more than
// one step behind restarts from `now` (a resumed app does not burst its missed steps); less
// than one step behind stays on the grid. (3) BOUNDARY: non-finite or non-positive gaps fall
// back to `now`. (4) WIRING, by text: `advance()` re-arms from `.grid`, `play()` and the
// `setTempo` re-arm from `.now`, and no `.now() + interval` deadline survives.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`1bf6530`) and this tree: claims
// 1–3 RED on the parent (the helper does not exist there), GREEN here; claim 4 RED on the
// parent (`deadline: .now() + interval`), GREEN here. Whether the click and the notes now stay
// seamed over 16 bars is a device listen — NEEDS-FOUNDER-VERIFY at the helper.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheStepClockKeepsItsGridTests: XCTestCase {

    private let gap = 0.125   // 120 BPM sixteenths

    /// Claim 1 — a late handler does not move the next deadline; a chain stays on the grid.
    func testHandlerLatencyDoesNotAccumulate() {
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: gap, now: 10.004), 10.125, accuracy: 1e-12,
                       "a 4 ms late handler moved the next deadline — latency is permanent again (#1223)")
        var ideal = 10.0
        for k in 1...400 {
            ideal = PatternEngine.nextDeadline(ideal: ideal, gap: gap, now: ideal + 0.004)
            XCTAssertEqual(ideal, 10 + Double(k) * gap, accuracy: 1e-9,
                           "after \(k) late ticks the clock left the ideal grid (#1223)")
        }
    }

    /// Claim 2 — more than one step behind re-anchors to now; less than one step stays on grid.
    func testAStalledClockRestartsInsteadOfBursting() {
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: gap, now: 12), 12, accuracy: 1e-12,
                       "a clock two seconds behind kept its old grid — a resumed app would burst 15 steps (#1223)")
        // 75 ms past the ideal 10.125 is under one gap: fire that step now, next one on time.
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: gap, now: 10.2), 10.125, accuracy: 1e-12,
                       "a clock less than one step behind re-anchored — the one-step catch-up that keeps phase is gone (#1223)")
        // Exactly one gap behind is the boundary: still the grid.
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: gap, now: 10.25), 10.125, accuracy: 1e-12)
    }

    /// Claim 3 — non-finite or non-positive gaps fall back to now, never to NaN or the past.
    func testNonFiniteInputsFallBackToNow() {
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: .nan, now: 11), 11)
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: .infinity, gap: gap, now: 11), 11)
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: 0, now: 11), 11)
        XCTAssertEqual(PatternEngine.nextDeadline(ideal: 10, gap: -1, now: 11), 11)
    }

    /// Claim 4 — wiring: advance() continues the grid; Play and a user edit start a new one.
    func testAdvanceContinuesTheGridAndPlayStartsOne() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Sequencer/PatternEngine.swift"))
        XCTAssertFalse(src.contains("deadline: .now() + interval"),
                       "`scheduleTick` arms from `.now()` again — every tick's latency is permanent (#1223)")
        XCTAssertEqual(src.components(separatedBy: ", from: .grid)").count - 1, 1,
                       "exactly one re-arm continues the grid — `advance()`; a second one would be a user edit inheriting a stale ideal, none would be the old defect (#1223)")
        XCTAssertEqual(src.components(separatedBy: ", from: .now)").count - 1, 2,
                       "`play()` and the `setTempo` re-arm each start a fresh grid from now (#1223)")
        XCTAssertTrue(src.contains("let deadline = PatternEngine.nextDeadline(ideal: ideal, gap: interval, now: now)"),
                      "`scheduleTick` no longer derives its deadline from the pure helper the claims above drive (#1223)")
        XCTAssertTrue(src.contains("nextTickUptime = deadline"),
                      "the scheduled deadline is no longer remembered as the next anchor (#1223)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

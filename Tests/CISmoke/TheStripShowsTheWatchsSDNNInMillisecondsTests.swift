// TheStripShowsTheWatchsSDNNInMillisecondsTests.swift
// Echoel — #1233 (audit 2026-09-10 `bio-pipeline-4`). The bio strip's HRV cell shows a
// measured SDNN in milliseconds when a source publishes SDNN but no RMSSD.
//
// THE DEFECT. HealthKit (the Watch) gives SDNN only; the frame carries it as `hrvSDNNms`
// and `RMSSD` stays 0. The cell's precedence was: plausible RMSSD → the unit-less
// normalized value → "—". So a Watch frame with a measured 42 ms SDNN showed `0.420` with no
// unit, although the millisecond number was on the same frame — a science-first display
// (CLAUDE.md: "legible numbers first") showing a normalisation of a number it had.
//
// WHAT THIS PINS, on the pure helper `BioStripView.hrvDisplay` (extracted for this):
// (1) SDNN-only frame → SDNN in ms; (2) RMSSD still wins when plausible (camera/strap
// unchanged); (3) neither → normalized, no unit (the pre-#1233 HealthKit look, still the
// right fallback for a source that publishes neither ms value); (4) implausible RMSSD with
// no SDNN → "—" (noisy rPPG), never the normalized number; (5) the strip's two computed
// vars read the helper (text).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`60f6f98`) and this tree, on the
// branch logic (the number formatting is `EchoelDecimalText`, not ported): claim 1 RED on
// the parent (normalized shown), GREEN here; claims 2–4 GREEN on both (counterweights);
// claim 5 RED on the parent (no helper), GREEN here.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheStripShowsTheWatchsSDNNInMillisecondsTests: XCTestCase {

    /// Claim 1 — a Watch-shaped frame (SDNN, no RMSSD) shows milliseconds.
    func testAnSDNNOnlyFrameShowsMilliseconds() {
        let cell = BioStripView.hrvDisplay(rmssdMs: 0, sdnnMs: 42, normalized: 0.42)
        XCTAssertEqual(cell.unit, "ms", "a measured SDNN of 42 ms was shown without its unit — the normalized number won again (#1233)")
        XCTAssertEqual(cell.value, EchoelDecimalText.string(Float(42), decimals: 0),
                       "the cell shows \(cell.value) for a 42 ms SDNN (#1233)")
    }

    /// Claim 2 — RMSSD still wins when it is plausible (camera / strap unchanged).
    func testAPlausibleRMSSDStillWins() {
        let cell = BioStripView.hrvDisplay(rmssdMs: 15.2, sdnnMs: 42, normalized: 0.15)
        XCTAssertEqual(cell.unit, "ms")
        XCTAssertEqual(cell.value, EchoelDecimalText.string(Float(15.2), decimals: 0),
                       "RMSSD 15.2 must still be shown as whole ms, SDNN must not overrule it (#1233)")
        let sub10 = BioStripView.hrvDisplay(rmssdMs: 8.4, sdnnMs: 0, normalized: 0.08)
        XCTAssertEqual(sub10.value, EchoelDecimalText.string(Float(8.4), decimals: 1), "sub-10 ms keeps one decimal (v173 law)")
    }

    /// Claim 3 — neither ms value → the normalized fallback, no unit.
    func testNeitherMillisecondValueFallsBackToNormalized() {
        let cell = BioStripView.hrvDisplay(rmssdMs: 0, sdnnMs: 0, normalized: 0.4)
        XCTAssertNil(cell.unit)
        XCTAssertEqual(cell.value, EchoelDecimalText.string(Float(0.4), decimals: 3))
    }

    /// Claim 4 — implausible RMSSD, no SDNN → "—", never the normalized number.
    func testAnImplausibleRMSSDStaysADash() {
        XCTAssertEqual(BioStripView.hrvDisplay(rmssdMs: 900, sdnnMs: 0, normalized: 0.9).value, "—",
                       "a physiologically impossible RMSSD must read as unmeasured, not as its normalisation (#1233)")
        XCTAssertNil(BioStripView.hrvDisplay(rmssdMs: 900, sdnnMs: 0, normalized: 0.9).unit)
        XCTAssertEqual(BioStripView.hrvDisplay(rmssdMs: 0, sdnnMs: 0, normalized: 0).value, "—")
    }

    /// Claim 5 — the strip's cell reads the helper, both halves.
    func testTheStripCellReadsTheHelper() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Studio/BioStripView.swift"))
        XCTAssertEqual(src.components(separatedBy: "Self.hrvDisplay(rmssdMs: bio.hrvRMSSDms, sdnnMs: bio.hrvSDNNms").count - 1, 2,
                       "`hrvString` and `hrvUnit` must both read `hrvDisplay` — a value and a unit from two different precedences is the defect's shape (#1233)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

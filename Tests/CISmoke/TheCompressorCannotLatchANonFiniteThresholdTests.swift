// TheCompressorCannotLatchANonFiniteThresholdTests.swift
// Echoel — 2026-09-25 (overnight P8): a non-finite compressor threshold cannot latch the gain
// reduction. Blocking bundle.
//
// THE DEFECT (measured before the repair). `EchoelCompressor.processStereo` bails on a
// non-finite SAMPLE and holds its state, but nothing held it on a non-finite CONTROL. A NaN
// `thresholdDb` made `over` NaN, both knee comparisons failed into the `else`, the target
// was NaN, and the release branch wrote `grState = NaN` for good: every later sample was NaN
// until `reset()` (toggling the stage off and on). A −inf threshold made the target −inf,
// `grState` followed it (output silent), and the first finite threshold afterwards computed
// `−inf + inf` = NaN, which is the same latch one write later. Recorded as latent candidate 3
// by tonight's read-only sticky-NaN sweep.
//
// LATENT: every writer delivers a finite value (`FXPreset.apply` from a decoded preset,
// the FX panel field, the morph, which is NaN-safe since 655194fd9). Closed on the #588
// boundary rule.
//
// THE REPAIR. The ballistics update runs only for a finite target. A non-finite one holds
// `grState`, the same hold the input bail applies to a bad sample.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped public stage
// (`gainReductionDb` is public).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `55100e584`, claim 1
// is RED on its NaN and −inf rows (`gainReductionDb` is NaN after the threshold is restored).
// That is one finding. Its +inf row is green on both trees: the target is 0, since nothing is
// over an infinite threshold. Claim 2 is a COUNTERWEIGHT (a finite threshold still compresses
// and releases) and is green on both.

import XCTest
@testable import Echoelmusic

final class TheCompressorCannotLatchANonFiniteThresholdTests: XCTestCase {

    // MARK: - claim 1

    func testANonFiniteThresholdDoesNotOutliveItsRestore() {
        for bad: Float in [.nan, -.infinity, .infinity] {
            let comp = EchoelCompressor(sampleRate: 48_000)
            comp.thresholdDb = -18
            for _ in 0..<480 { _ = comp.processStereo(0.5, 0.5) }
            comp.thresholdDb = bad
            for _ in 0..<480 { _ = comp.processStereo(0.5, 0.5) }
            comp.thresholdDb = -18
            var out: Float = 0
            for _ in 0..<4_800 { out = comp.processStereo(0.5, 0.5).0 }
            XCTAssertTrue(comp.gainReductionDb.isFinite,
                          "a \(bad) threshold latched the gain reduction past its restore")
            XCTAssertTrue(out.isFinite, "a \(bad) threshold left the stage emitting non-finite audio")
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testAFiniteThresholdStillCompressesAndReleases() {
        let comp = EchoelCompressor(sampleRate: 48_000)
        comp.thresholdDb = -30
        comp.ratio = 4
        for _ in 0..<4_800 { _ = comp.processStereo(0.9, 0.9) }
        let reduced = comp.gainReductionDb
        XCTAssertLessThan(reduced, -6, "a 0.9 burst over a −30 dB threshold no longer compresses")
        for _ in 0..<96_000 { _ = comp.processStereo(0, 0) }
        XCTAssertGreaterThan(comp.gainReductionDb, reduced + 1, "the reduction no longer releases")
    }
}

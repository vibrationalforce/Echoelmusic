// TheCompressorCannotLatchANonFiniteThresholdTests.swift
// Echoel — 2026-09-25 (overnight P8): a non-finite compressor threshold cannot latch the gain
// reduction. Blocking bundle.
//
// THE DEFECT (measured before the repair). `EchoelCompressor.processStereo` bails on a
// non-finite SAMPLE and holds its state, but nothing held it on a non-finite CONTROL. A NaN
// `thresholdDb` made `over` NaN, both knee comparisons failed into the `else`, the target
// was NaN, and the release branch wrote `grState = NaN` for good: every later sample was NaN
// until `reset()` (toggling the stage off and on). A −inf threshold made the target −inf;
// `grState` followed it for ONE sample, and the next sample's release update computed
// (−inf) − (−inf) = NaN, which latched while the bad threshold was still set. (⛔ Review 16: the
// first version said the latch came at the restore and that the output stayed silent; neither
// is true past the first sample.) Recorded as latent candidate 3 by tonight's read-only
// sticky-NaN sweep. A SECOND input reaches the same latch, and it is the more reachable one: a
// huge FINITE `kneeDb` overflows `x * x` in the knee branch to a −inf target (ratio > 1) or to
// 0·inf = NaN (ratio 1). Found by review 16; claim 3 pins it.
//
// REACH: the threshold half is LATENT. Every writer delivers a finite value (`FXPreset.apply`
// from a decoded preset, which JSON cannot give NaN/inf; the ranged FX panel field; the morph,
// NaN-safe in its amount since 655194fd9). The knee half is reachable from a hand-edited preset:
// the decoder does not clamp `compKnee` and `apply` writes it raw. Closed on the #588 boundary
// rule.
//
// THE REPAIR. The ballistics update runs only for a finite target. A non-finite one holds
// `grState`, like the input bail's hold on a bad sample (`env` keeps tracking the input).
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped public stage
// (`gainReductionDb` is public).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain; float32 simulation of
// `processStereo` on both trees. On the parent `55100e584`, claim 1 is RED on its NaN and −inf
// rows (`gainReductionDb` is NaN after the restore), and claim 3 is RED on both of its ratio rows
// (the 1e20 knee latched NaN). They are two findings, one per input, sharing one repair. Claim 1's
// +inf row is green on both trees: the target is 0, since nothing is over an infinite threshold.
// Claim 2 is a COUNTERWEIGHT (a finite threshold still compresses by −21.8 dB and releases) and is
// green on both. Claim 3 was added in a follow-up commit, so its parent is that commit's parent;
// the verdicts above are for the code before `43d3da0c6`.

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

    // MARK: - claim 3 (the knee input, review 16)

    func testAnOverflowingKneeDoesNotOutliveItsRestore() {
        for ratio: Float in [3, 1] {
            let comp = EchoelCompressor(sampleRate: 48_000)
            comp.ratio = ratio
            for _ in 0..<480 { _ = comp.processStereo(0.5, 0.5) }
            comp.kneeDb = 1e20                  // x * x overflows in the knee branch
            for _ in 0..<480 { _ = comp.processStereo(0.5, 0.5) }
            comp.kneeDb = 6
            var out: Float = 0
            for _ in 0..<4_800 { out = comp.processStereo(0.5, 0.5).0 }
            XCTAssertTrue(comp.gainReductionDb.isFinite,
                          "a 1e20 knee at ratio \(ratio) latched the gain reduction past its restore")
            XCTAssertTrue(out.isFinite, "a 1e20 knee at ratio \(ratio) left the stage emitting non-finite audio")
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

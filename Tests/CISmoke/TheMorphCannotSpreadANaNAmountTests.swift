// TheMorphCannotSpreadANaNAmountTests.swift
// Echoel — 2026-09-25 (overnight P8): a NaN morph `amount` leaves the source preset unchanged
// instead of turning every interpolated field into NaN. Blocking bundle.
//
// THE DEFECT (measured before the repair). `FXPreset.morphed(to:amount:)` computed
// `t = Swift.min(Swift.max(amount, 0), 1)`, the NaN-transparent order. With `t` NaN, `L(a, b)`
// returned NaN for EVERY continuous field, and the midpoint switches (`t < 0.5`) all picked the
// TARGET. `EchoelFXView.morph` then applies that result to every chain, from a live fader
// binding. `ANonFiniteControlCannotReachTheRenderTests` and the `EchoelModFX` helper doc both
// named this as the producer #1206 missed; both notes now say it is closed.
//
// LATENT: the fader carries a `0...1` range, so no shipped producer emits NaN. It is closed on
// the #588 boundary rule because it is the one call that can poison every FX field at once.
//
// THE REPAIR. `amount.clamped(to: 0...1)`: NaN reads as 0 (this preset); every other value,
// ±inf included, is unchanged.
//
// WHAT KIND OF GREEN (§1): BEHAVIOUR of the shipped value type. (⛔ This line gave "`morphed` is
// internal" as the reason for `@testable` until review 10: it sits in `public extension
// FXPreset`, so it is public. The import stays as the bundle's convention, not a necessity.)
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `fc116b337`, claim 1
// is RED: the fields come back as NaN and the switches pick the target. That is one finding.
// Claim 2 is a COUNTERWEIGHT and is green on both trees.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMorphCannotSpreadANaNAmountTests: XCTestCase {

    private func pair() -> (FXPreset, FXPreset) {
        let chain = EchoelFXChain(sampleRate: 48_000)
        var a = FXPreset.capture(from: chain, fxEnabled: false, name: "A")
        a.delaySpread = 0.2
        a.filterCutoff = 800
        a.tapeDepth = 0.1
        var b = FXPreset.capture(from: chain, fxEnabled: true, name: "B")
        b.delaySpread = 0.8
        b.filterCutoff = 4_000
        b.tapeDepth = 0.9
        return (a, b)
    }

    // MARK: - claim 1

    func testANaNAmountLeavesTheSourcePresetUnchanged() {
        let (a, b) = pair()
        let m = a.morphed(to: b, amount: .nan)
        XCTAssertEqual(m.delaySpread, a.delaySpread, "a NaN amount must read as 0 — delaySpread moved or went NaN")
        XCTAssertEqual(m.filterCutoff, a.filterCutoff, "a NaN amount must read as 0 — filterCutoff moved or went NaN")
        XCTAssertEqual(m.tapeDepth, a.tapeDepth, "a NaN amount must read as 0 — tapeDepth moved or went NaN")
        XCTAssertEqual(m.fxEnabled, a.fxEnabled, "a NaN amount flipped the midpoint switches to the target")
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testEveryNonNaNAmountMorphsAsBefore() {
        let (a, b) = pair()
        XCTAssertEqual(a.morphed(to: b, amount: 0.5).delaySpread, 0.5, accuracy: 1e-6)
        XCTAssertEqual(a.morphed(to: b, amount: 0).filterCutoff, 800, accuracy: 1e-3)
        XCTAssertEqual(a.morphed(to: b, amount: 1).filterCutoff, 4_000, accuracy: 1e-3)
        XCTAssertEqual(a.morphed(to: b, amount: -.infinity).tapeDepth, 0.1, accuracy: 1e-6,
                       "-inf no longer clamps to the source")
        XCTAssertEqual(a.morphed(to: b, amount: .infinity).tapeDepth, 0.9, accuracy: 1e-6,
                       "+inf no longer clamps to the target")
        XCTAssertTrue(a.morphed(to: b, amount: 1).fxEnabled, "the switches no longer reach the target")
    }
}

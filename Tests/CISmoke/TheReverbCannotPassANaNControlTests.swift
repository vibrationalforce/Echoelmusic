// TheReverbCannotPassANaNControlTests.swift
// Echoel — 2026-09-25 (overnight P8x): `EchoelReverb.processStereo` reads `mix` and `width`
// through the repo's NaN-safe `clamped(to:)`. Blocking bundle.
//
// THE DEFECT (measured before the repair). Both were clamped as `Swift.min(Swift.max(x, 0), 1)`,
// the argument order CLAUDE.md names as the one that passes NaN straight through
// (`max(NaN, 0)` is NaN). A NaN mix or width therefore put NaN on the reverb's output — in the
// AUv3's space stage and in the app's FX chain, which both own an `EchoelReverb`. Every upstream
// writer is gated today (host values are admitted, bio mirrors are finite-checked), so this is
// defence in depth at the stage itself. Found by tonight's read-only DSP review (its finding F3).
//
// THE REPAIR. `mix.clamped(to: 0...1)` and `width.clamped(to: 0...1)`: NaN reads as 0 (dry /
// narrowest), every finite value clamps exactly as before.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped DSP type (claims 1–2) and of the
// shipped clamp (claim 3). DEVICE: nothing to hear — the finite path is unchanged by construction.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `c87e6a4b6`
// (the commit before P8x): claims 1 and 2 are REGRESSIONS — the NaN control reached the output there,
// so the finiteness assertions are red (two findings, one per control). Claim 3 is a
// COUNTERWEIGHT, green on both trees: it proves the replacement changes no finite value. The file
// names only existing symbols (`EchoelReverb`, `clamped(to:)`), so it compiles on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheReverbCannotPassANaNControlTests: XCTestCase {

    // MARK: - claim 1

    func testANaNMixLeavesTheSignalDry() {
        let reverb = EchoelReverb(sampleRate: 48_000)
        reverb.mix = .nan
        for i in 0..<256 {
            let x = Float(i % 7) * 0.1 - 0.3
            let (l, r) = reverb.processStereo(x, -x)
            XCTAssertTrue(l.isFinite && r.isFinite, "a NaN mix reached the output at sample \(i)")
            XCTAssertEqual(l, x, "a NaN mix must read as 0 — the dry signal")
            XCTAssertEqual(r, -x, "a NaN mix must read as 0 — the dry signal")
        }
    }

    // MARK: - claim 2

    func testANaNWidthKeepsTheWetSignalFinite() {
        let reverb = EchoelReverb(sampleRate: 48_000)
        reverb.mix = 0.5
        reverb.width = .nan
        var sawWet = false
        for i in 0..<4_096 {
            let x: Float = i == 0 ? 1 : 0
            let (l, r) = reverb.processStereo(x, x)
            XCTAssertTrue(l.isFinite && r.isFinite, "a NaN width reached the output at sample \(i)")
            if i > 0, l != 0 || r != 0 { sawWet = true }
        }
        XCTAssertTrue(sawWet, "the tank never answered the impulse — the finiteness check above was vacuous")
    }

    // MARK: - claim 3 (COUNTERWEIGHT)

    func testTheNaNSafeClampChangesNoFiniteValue() {
        let grid: [Float] = [-.greatestFiniteMagnitude, -2, -1, -0.0, 0, 1e-30, 0.25, 0.5, 0.999, 1, 1.5, 3,
                             .greatestFiniteMagnitude, -.infinity, .infinity]
        for x in grid {
            XCTAssertEqual(x.clamped(to: 0...1), Swift.min(Swift.max(x, 0), 1),
                           "the NaN-safe clamp differs from the old spelling at \(x)")
        }
        XCTAssertEqual(Float.nan.clamped(to: 0...1), 0, "NaN no longer reads as the lower bound")
    }
}

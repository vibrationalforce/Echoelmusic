// TheBitcrushDownsampleCannotTrapTests.swift
// Echoel — 2026-09-25 (overnight P8z): a non-finite `EchoelBitcrush.downsample` cannot trap.
// Blocking bundle.
//
// THE DEFECT (measured before the repair). `downsample`'s `didSet` caches
// `Int(Swift.min(Swift.max(d, 1), 64).rounded())`. That clamp order passes NaN through
// (CLAUDE.md, API gotchas), and `Int(Float.nan)` is a Swift TRAP: a crash on the thread that set
// the knob. Latent — the FX field is 1…64 and `JSONDecoder` rejects NaN, so no producer emits one
// today — and closed on the #588 boundary rule (`ANonFiniteControlCannotReachTheRenderTests`).
// Found while sweeping `DSP/` for the NaN-passing clamp after tonight's DSP review.
//
// THE REPAIR. `Int(d.clamped(to: 1...64).rounded())`: NaN reads as 1 (full rate), every finite
// value is unchanged (`clamped(to:)` equals the old spelling for finite input — pinned by
// `TheReverbCannotPassANaNControlTests` claim 3, not restated here).
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped DSP type.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `1db624264`: claim 1 TRAPS
// on its NaN case there rather than failing an assertion — the clone dies, which
// the CI log cannot tell apart from #396 (#1174). One finding. Claim 2 is a COUNTERWEIGHT, green on
// both trees: a finite downsample still holds each input for N samples. Compiles on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBitcrushDownsampleCannotTrapTests: XCTestCase {

    // MARK: - claim 1

    func testANonFiniteDownsampleReadsAsFullRate() {
        for bad: Float in [.nan, .infinity, -.infinity] {
            let crush = EchoelBitcrush(sampleRate: 48_000)
            crush.downsample = bad          // traps on the parent for NaN
            crush.mix = 1
            var previous: Float = .nan
            for i in 0..<16 {
                let x = Float(i) / 16
                let (l, _) = crush.processStereo(x, x)
                XCTAssertTrue(l.isFinite, "downsample \(bad) made the output non-finite at \(i)")
                if bad.isNaN { XCTAssertNotEqual(l, previous, "NaN must read as full rate — no hold") }
                previous = l
            }
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testAFiniteDownsampleStillHoldsForNSamples() {
        let crush = EchoelBitcrush(sampleRate: 48_000)
        crush.downsample = 4
        crush.mix = 1
        var outs: [Float] = []
        for i in 0..<16 { outs.append(crush.processStereo(Float(i) / 16, 0).0) }
        for block in 0..<4 {
            let first = outs[block * 4]
            for k in 1..<4 {
                XCTAssertEqual(outs[block * 4 + k], first, "downsample 4 no longer holds block \(block)")
            }
        }
        XCTAssertNotEqual(outs[0], outs[4], "the hold never refreshed — the check above was vacuous")
    }
}

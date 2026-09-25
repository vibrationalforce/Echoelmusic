// TheLoFiStagesCannotPassANaNControlTests.swift
// Echoel — 2026-09-25 (overnight P8): a NaN `EchoelBitcrush.mix` or `EchoelStereoWidener.width`
// cannot turn the output into NaN. Blocking bundle.
//
// THE DEFECT (measured before the repair). Both render paths clamped with
// `Swift.min(Swift.max(x, lo), hi)`, the order CLAUDE.md names as NaN-transparent (`max(NaN, 0)`
// is NaN). A NaN mix made every bitcrush output NaN. The bitcrush sits UPSTREAM of the chain's
// chorus, delay and reverb (`EchoelFXChain`), whose stored state such a sample poisons: the
// shipped permanent-silence class. A NaN width did the same at the widener, which only the
// compressor and limiter follow; both skip their state update on a non-finite sample and pass it
// on (`EchoelDynamics`), so that NaN reached the chain's OUTPUT rather than stored state. (⛔ This
// line said "at the chain's last stage" until review 10 — two stages follow it.) The same
// file's other NaN-transparent clamps are harmless and deliberately left alone: `bits`, the
// tape's `depth`/`saturation` and its tone coefficient all fall through a `> 0` or `< 0.999` test
// that is false for NaN, so the stage goes transparent, not NaN. The mod-FX stages had this
// repair in #1206b; the lo-fi stages were never swept.
//
// LATENT: no shipped producer emits NaN into either field (UI fields carry finite ranges,
// `JSONDecoder` rejects NaN, `FXModulation.combine` guards its sum). Closed on the #588 boundary
// rule (`ANonFiniteControlCannotReachTheRenderTests`).
//
// THE REPAIR. Mix: `clamped(to: 0...1)`, where NaN maps to 0, which is dry and neutral. Width:
// NaN maps to 1 BEFORE the clamp, because width's neutral value is 1 (unchanged) while its floor,
// 0, collapses the image to mono. For every non-NaN value, ±inf included, both are identical to
// the old spelling.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped DSP types.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `3f39fae12`:
// claims 1 and 2 are RED, because the NaN reaches the output. That is two findings. Claim 3 is a
// COUNTERWEIGHT and is green on both trees: finite values and ±inf behave exactly as before.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLoFiStagesCannotPassANaNControlTests: XCTestCase {

    private let inputs: [(Float, Float)] = [(0.3, -0.1), (-0.7, 0.2), (0.05, 0.05), (0, -0.4)]

    // MARK: - claim 1

    func testANaNBitcrushMixReadsAsDry() {
        let crush = EchoelBitcrush(sampleRate: 48_000)
        crush.bits = 4
        crush.mix = .nan
        for (l, r) in inputs {
            let (ol, or) = crush.processStereo(l, r)
            XCTAssertTrue(ol.isFinite && or.isFinite, "a NaN mix made the bitcrush output non-finite")
            XCTAssertEqual(ol, l, "a NaN mix must read as fully dry")
            XCTAssertEqual(or, r, "a NaN mix must read as fully dry")
        }
    }

    // MARK: - claim 2

    func testANaNWidthReadsAsUnchanged() {
        let widener = EchoelStereoWidener(sampleRate: 48_000)
        widener.width = .nan
        for (l, r) in inputs {
            let (ol, or) = widener.processStereo(l, r)
            XCTAssertTrue(ol.isFinite && or.isFinite, "a NaN width made the widener output non-finite")
            XCTAssertEqual(ol, l, accuracy: 1e-6, "a NaN width must read as 1 (unchanged), not mono")
            XCTAssertEqual(or, r, accuracy: 1e-6, "a NaN width must read as 1 (unchanged), not mono")
        }
    }

    // MARK: - claim 3 (COUNTERWEIGHT)

    func testEveryNonNaNValueBehavesAsBefore() {
        // Width: 0 is mono, 2 doubles the side; ±inf clamp to those ends exactly as before.
        let widener = EchoelStereoWidener(sampleRate: 48_000)
        for width: Float in [0, -.infinity] {
            widener.width = width
            let (ol, or) = widener.processStereo(0.3, -0.1)
            XCTAssertEqual(ol, or, accuracy: 1e-6, "width \(width) is no longer mono")
        }
        widener.width = 2
        let wide = widener.processStereo(0.3, -0.1)
        widener.width = .infinity
        let inf = widener.processStereo(0.3, -0.1)
        XCTAssertEqual(wide.0, inf.0, "+inf width no longer clamps to 2")
        XCTAssertEqual(wide.1, inf.1, "+inf width no longer clamps to 2")
        XCTAssertEqual(wide.0 - wide.1, 0.8, accuracy: 1e-6, "width 2 no longer doubles the side")

        // Mix: 0.5 still blends dry and crushed halfway; +inf still reads as fully wet.
        let half = EchoelBitcrush(sampleRate: 48_000)
        half.bits = 1
        half.mix = 0.5
        let wet = EchoelBitcrush(sampleRate: 48_000)
        wet.bits = 1
        wet.mix = 1
        let over = EchoelBitcrush(sampleRate: 48_000)
        over.bits = 1
        over.mix = .infinity
        let dry: Float = 0.3
        let w = wet.processStereo(dry, dry).0
        XCTAssertNotEqual(w, dry, "bits 1 did not crush — the blend check below would be vacuous")
        XCTAssertEqual(half.processStereo(dry, dry).0, (dry + w) * 0.5, accuracy: 1e-6,
                       "mix 0.5 no longer blends halfway")
        XCTAssertEqual(over.processStereo(dry, dry).0, w, "+inf mix no longer reads as fully wet")
    }
}

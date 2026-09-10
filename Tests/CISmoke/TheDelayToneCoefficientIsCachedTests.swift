// TheDelayToneCoefficientIsCachedTests.swift
// Echoel — #1214 (audit 2026-09-10 `audio-dsp-2`). The delay's feedback tone is computed when
// the control moves, not on every sample.
//
// THE COST. `EchoelDelay.processStereo` called `toneCoefficient()` once per frame, and that
// function evaluates `powf(20, tone)` and `expf(-2π·fc/sr)` — two transcendentals per sample
// for a control that changes only when a finger or a preset moves it. Its sibling
// `EchoelLoFiFX.tone` has cached the identical coefficient in a `didSet` for months; this makes
// the delay do the same. The additive synth is the render budget's dominant consumer and the
// app already trades 5 ms of latency for underrun headroom (#961) — this is headroom for free.
//
// WHAT THIS PINS. (1) By text: the hot path reads the cached `toneG`, and `tone` refills it
// on assignment. (2) By behaviour: assigning `tone` still CHANGES the sound — a dark and a
// bright delay differ on the same input — which is what proves the cache is wired to the
// control and not seeded once and forgotten. (3) COUNTERWEIGHT — the NaN-safe clamp of #1208
// stays inside the cached computation, so a non-finite control still yields a finite
// coefficient (the permanent-silence class #1206b/#1208 closed).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`8fc7ceb`) and this tree: claim 1
// RED on the parent (no `toneG`, per-sample call), GREEN here; claims 2 and 3 green on both
// trees — they are the counterweights that stop a cache from silently detaching from its
// control or dropping the clamp.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDelayToneCoefficientIsCachedTests: XCTestCase {

    /// Claim 1 — the hot path reads a cached coefficient that `tone` refills on assignment.
    func testTheHotPathReadsTheCachedCoefficient() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/DSP/EchoelDelay.swift"))
        XCTAssertTrue(src.contains("let g = toneG"),
                      "processStereo no longer reads the cached toneG — two transcendentals per " +
                      "sample are back on the render path (#1214)")
        XCTAssertTrue(src.contains("didSet { toneG = Self.toneCoefficient(tone, sr) }"),
                      "`tone` no longer refills toneG on assignment — the cache is detached from " +
                      "its control (#1214)")
        XCTAssertFalse(src.contains("let g = toneCoefficient()"),
                       "the per-sample toneCoefficient() call is back (#1214)")
    }

    /// Claim 2 — assigning `tone` still changes the sound.
    func testAssigningToneStillChangesTheSound() {
        func tail(tone: Float) -> Float {
            let d = EchoelDelay(maxDelaySeconds: 0.5, sampleRate: 48_000)
            d.timeSeconds = 0.010; d.feedback = 0.7; d.mix = 1.0; d.tone = tone
            var energy: Float = 0
            for i in 0..<9_600 {
                let x: Float = (i % 48 == 0) ? 1.0 : 0.0        // 1 kHz click train, rich in highs
                let (l, r) = d.processStereo(x, x)
                if i > 4_800 { energy += l * l + r * r }        // the tail, once feedback has built
            }
            return energy
        }
        let dark = tail(tone: 0.0), bright = tail(tone: 1.0)
        XCTAssertTrue(dark.isFinite && bright.isFinite)
        XCTAssertNotEqual(dark, bright, accuracy: 1e-6,
                          "tone 0 and tone 1 produce the same tail — the cached coefficient no " +
                          "longer follows the control (#1214)")
    }

    /// Claim 3 — counterweight: the #1208 clamp still lives in the cached computation.
    func testTheClampSurvivesInsideTheCache() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/DSP/EchoelDelay.swift"))
        XCTAssertTrue(src.contains("powf(20.0, tone.clamped(to: 0...1))"),
                      "the NaN-safe clamp left the tone coefficient — a non-finite control " +
                      "poisons the feedback path again (#1208)")
        let d = EchoelDelay(maxDelaySeconds: 0.5, sampleRate: 48_000)
        d.tone = .nan
        var peak: Float = 0
        for i in 0..<4_800 {
            let (l, r) = d.processStereo(i == 0 ? 1.0 : 0.0, 0.0)
            peak = Swift.max(peak, abs(l), abs(r))
        }
        XCTAssertTrue(peak.isFinite, "a NaN tone reached the ring through the cache (#1214/#1208)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

// TheDDSPRenderIsDeterministicAndBoundedTests.swift
// Echoel — #1228 (audit 2026-09-10 `tests-guards-3`). ONE end-to-end render guard in the
// blocking bundle: the instrument's core voice renders deterministically, finitely, bounded,
// and audibly — measured on the SAMPLES, not on the source text.
//
// WHY. The audit's honest ratio: 403 of 487 files in this bundle scan text, 5 render a voice,
// none asserts a whole render end to end. A DSP regression that keeps every needle in place
// (a NaN path, a wrong gain constant, an unseeded random walk) would ship through two green
// gates. This file is the counterweight: it constructs `EchoelDDSP` the way
// `BioReactiveSynthVoice` does, applies a fixed patch and a fixed resting body, triggers a
// note and renders — then asserts properties of the audio itself.
//
// WHAT THIS PINS. (1) DETERMINISM: two voices built from the same seed render byte-identical
// 4096-frame blocks; two seeds differ (so the seed is honoured and claim 1 is not vacuous).
// (2) FINITE + BOUNDED: every sample finite; peak ≤ 2.0 — a SANITY ceiling for one un-mastered
// voice (max-normalised partials × amplitude 0.5), NOT a loudness law: the −1 dBFS true-peak
// trim lives on the master bus, downstream of this voice. Tightening it is a measurement (a
// green run prints the peak in the message), not an edit. (3) AUDIBLE: an armed voice has
// RMS > 0 over the first 4096 frames. (4) A MINUTE COMPLETES: 60 s of 192-frame blocks render
// finite — CI wall clock is not a latency measurement and none is asserted; this only proves
// the render loop has no growth or trap over a realistic take length.
//
// ⚠️ HONEST GRADING — NOT TRANSCRIBED (§0): every claim here is a property of the RENDERED
// SAMPLES, which no Python port can stand in for. It has not been driven in this session;
// the CI/CD `Run Tests` job is the first run, and its verdict grades this file. Expected on
// the parent and this tree alike: GREEN (END-TO-END, preventive) — a red is a finding about
// the voice, not about the guard, and must be read before it is "fixed".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDDSPRenderIsDeterministicAndBoundedTests: XCTestCase {

    private static let sampleRate: Float = 48_000
    private static let block = 192          // `EchoelDDSP.frameSize` default, the app's block

    /// The voice as the app builds it, on a fixed patch and a fixed resting body, one note.
    private func voice(seed: UInt32) -> EchoelDDSP {
        let dsp = EchoelDDSP(harmonicCount: 32, sampleRate: Self.sampleRate, noiseSeed: seed)
        SynthPatch(name: "render-guard", brightness: 0.5).apply(to: dsp)
        dsp.applyBioReactive(coherence: 0.5, hrvVariability: 0.5, heartRate: 0.5,
                             breathPhase: 0.5, breathDepth: 0.5, lfHfRatio: 0.5, coherenceTrend: 0)
        dsp.noteOn(frequency: 220)
        return dsp
    }

    private func render(_ dsp: EchoelDDSP, frames: Int) -> [Float] {
        var out = [Float](); out.reserveCapacity(frames)
        var buffer = [Float](repeating: 0, count: Self.block)
        var left = frames
        while left > 0 {
            let n = Swift.min(Self.block, left)
            dsp.render(buffer: &buffer, frameCount: n)
            out.append(contentsOf: buffer[0..<n])
            left -= n
        }
        return out
    }

    /// Claim 1 — same seed, same samples; different seed, different samples.
    func testTheRenderIsDeterministicForASeed() {
        let a = render(voice(seed: 0xC0FFEE), frames: 4096)
        let b = render(voice(seed: 0xC0FFEE), frames: 4096)
        XCTAssertEqual(a, b, "two voices built from the same seed rendered different samples — an unseeded source of entropy entered the render path (#1228)")
        let c = render(voice(seed: 0xBEEF), frames: 4096)
        XCTAssertNotEqual(a, c, "two different seeds rendered identical samples — the seed is ignored, and claim 1 above proves nothing (#1228)")
    }

    /// Claim 2 — finite and bounded.
    func testEverySampleIsFiniteAndTheVoiceStaysUnderTheSanityCeiling() {
        let samples = render(voice(seed: 0xC0FFEE), frames: 4096)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite }, "a non-finite sample left the voice (#1228)")
        let peak = samples.reduce(0) { Swift.max($0, abs($1)) }
        XCTAssertLessThanOrEqual(peak, 2.0, """
            peak \(peak) — one un-mastered voice at amplitude 0.5 exceeded the 2.0 sanity \
            ceiling (max-normalised partials cannot sum past ~4 × 0.5). Either a gain \
            constant changed or a stage runs open-loop; read before relaxing (#1228).
            """)
    }

    /// Claim 3 — an armed voice is audible.
    func testAnArmedVoiceHasEnergy() {
        let samples = render(voice(seed: 0xC0FFEE), frames: 4096)
        let rms = (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
        XCTAssertGreaterThan(rms, 0, "a triggered voice on a resting body rendered silence — the permanent-silence shape (#22/#29/#295) (#1228)")
    }

    /// Claim 4 — a minute of blocks completes finite. No timing is asserted (CI wall clock is
    /// not a latency measurement); this proves absence of growth or trap over a take.
    func testAMinuteOfBlocksRendersFinite() {
        let dsp = voice(seed: 0xC0FFEE)
        var buffer = [Float](repeating: 0, count: Self.block)
        let blocks = Int(60 * Self.sampleRate) / Self.block
        var allFinite = true
        for _ in 0..<blocks {
            dsp.render(buffer: &buffer, frameCount: Self.block)
            if !buffer.allSatisfy({ $0.isFinite }) { allFinite = false; break }
        }
        XCTAssertTrue(allFinite, "a non-finite sample appeared within the first minute of a take (#1228)")
    }
}

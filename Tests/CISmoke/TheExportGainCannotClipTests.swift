// TheExportGainCannotClipTests.swift
// Echoel — Export quality E1: post-normalisation SAMPLE-PEAK safety in `SingleExport`.
//
// THE DEFECT. `SingleExport.normalizeGainDB` may ask for up to +12 dB, steered by an RMS
// loudness over the whole window. A sparse take — a quiet body with one hot transient —
// measures quiet, got the full boost, and the transient landed up to ~12 dB over full scale.
// Nothing after the `vDSP_vsmul` bounded it: WAV converts to 24-bit integer PCM (hard clip),
// AAC received the same over-range floats.
//
// THE REPAIR (a gain BOUND, not a limiter): the measurement pass also takes the sample peak;
// `peakSafeGainDB` caps a positive gain so `peak × gain ≤ exportSamplePeakCeilingDBFS`
// (−1 dBFS); attenuation and "No target" (0 dB) pass unchanged. The renderer applies the
// result through `applyGain` — the ONE place the export gain touches samples.
//
// ⚠️ HONEST LIMITS (§1).
//   · Claims 1–8 are END-TO-END over shipped, nonisolated, Foundation+Accelerate statics: they
//     render synthetic buffers through the SAME `samplePeak` → `peakSafeGainDB` → `gainFactor`
//     → `applyGain` chain the export uses, and read the rendered sample values.
//   · Claims 9–10 are SOURCE-TEXT SCANS that the async AVFoundation method actually wires that
//     chain (`renderWithGain` is private and needs a real asset — no bundle drives it).
//   · SAMPLE peak only. Not true peak (no oversampling), and nothing here bounds what the AAC
//     ENCODER does after the samples are handed over. That the export sounds right is a
//     DEVICE / LISTENING probe — NEEDS-FOUNDER-VERIFY, not claimed.
//
// ⭐ GRADING (§3), transcribed in Python (float32) against both trees:
//   · parent (49c638126): the four statics do not exist — the file does not COMPILE there, so
//     no assertion has a verdict on the parent. Claims 1–8 are FORWARD guards on symbols this
//     commit creates; claims 9–10 are red there by anchor absence (one absence, #486).
//   · worktree: all green. A float32 sweep of the bound over 120 000 (peak, request) pairs
//     (peaks 1e-9…1, requests 0.5…12 dB) found 0 samples above the ceiling after a boost and
//     0 samples raised by a non-positive gain.

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: every claim below calls an internal static of `SingleExport`.
@testable import Echoelmusic

final class TheExportGainCannotClipTests: XCTestCase {

    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"
    private static let ceiling: Float = powf(10, SingleExport.exportSamplePeakCeilingDBFS / 20)

    // MARK: - the chain the export runs, on a synthetic buffer

    private struct Rendered {
        let gainDB: Float
        let samples: [Float]
        var peak: Float { samples.map { abs($0) }.max() ?? 0 }
    }

    /// Measure → bound → convert → apply, exactly as `export` / `renderWithGain` do.
    private static func render(_ source: [Float], requestedDB: Float) -> Rendered {
        let peak = source.withUnsafeBufferPointer { buf -> Float in
            guard let base = buf.baseAddress else { return 0 }
            return SingleExport.samplePeak(base, count: buf.count)
        }
        let gainDB = SingleExport.peakSafeGainDB(requestedDB: requestedDB, sourcePeak: peak)
        var out = source
        out.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            SingleExport.applyGain(base, count: buf.count,
                                   linearGain: SingleExport.gainFactor(dB: gainDB))
        }
        return Rendered(gainDB: gainDB, samples: out)
    }

    private static func sine(count: Int, amplitude: Float) -> [Float] {
        (0..<count).map { i -> Float in amplitude * sinf(Float(i) * 0.0627) }
    }

    // MARK: - behaviour

    /// 1 (case A) — normalisation still raises quiet material, by the full request.
    func testQuietMaterialIsStillRaised() {
        let source = Self.sine(count: 4_410, amplitude: 0.01)
        let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: -43)
        XCTAssertEqual(requested, 12, accuracy: 1e-6, "the +12 dB clamp is the premise here")
        let r = Self.render(source, requestedDB: requested)
        XCTAssertEqual(r.gainDB, 12, accuracy: 1e-6,
                       "a −40 dBFS take has 39 dB of headroom — the bound must not touch it. "
                       + "If this fails, normalisation was silently disabled.")
        XCTAssertGreaterThan(r.peak, 0.01 * 3.9, "the rendered level did not rise.")
        XCTAssertLessThanOrEqual(r.peak, Self.ceiling)
    }

    /// 2 (case B) — a sparse near-full-scale transient over a quiet body: the request would
    /// have clipped by ~11.6 dB; the rendered buffer stays representable and is not boosted.
    func testASparseHotTransientIsNotBoostedIntoClipping() {
        var source = Self.sine(count: 4_410, amplitude: 0.02)
        source[2_000] = 0.95
        let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: -40)
        XCTAssertEqual(requested, 12, accuracy: 1e-6)
        XCTAssertGreaterThan(0.95 * SingleExport.gainFactor(dB: requested), 1,
                             "premise: the UNBOUNDED request would exceed full scale.")
        let r = Self.render(source, requestedDB: requested)
        XCTAssertEqual(r.gainDB, 0, accuracy: 1e-6,
                       "the transient already sits above the −1 dBFS ceiling: no boost, and no "
                       + "attenuation either — its level is the performer's, not this gain's.")
        XCTAssertLessThanOrEqual(r.peak, 0.95, "a sample grew under a non-positive gain.")
        XCTAssertLessThanOrEqual(r.peak, 1, "the export would clip at the PCM converter.")
    }

    /// 2b — the same shape with a transient BELOW the ceiling: the boost is capped, not dropped.
    func testABoostIsCappedAtTheCeilingNotDisabled() {
        var source = Self.sine(count: 4_410, amplitude: 0.02)
        source[2_000] = 0.5
        let r = Self.render(source, requestedDB: 12)
        XCTAssertGreaterThan(r.gainDB, 4.9, "the headroom (~5 dB) was not used — over-cautious.")
        XCTAssertLessThan(r.gainDB, 12)
        XCTAssertLessThanOrEqual(r.peak, Self.ceiling,
                                 "a capped boost still lifted the peak above the ceiling.")
    }

    /// 3 + 4 (cases C, D) — positive and negative peaks are bounded alike.
    func testPositiveAndNegativePeaksAreBothProtected() {
        var up = Self.sine(count: 2_000, amplitude: 0.01)
        up[700] = 0.3
        var down = up
        down[700] = -0.3
        let rUp = Self.render(up, requestedDB: 12)
        let rDown = Self.render(down, requestedDB: 12)
        XCTAssertEqual(rUp.gainDB, rDown.gainDB, accuracy: 1e-6,
                       "the bound read the SIGN of the peak — it must read its magnitude.")
        XCTAssertLessThanOrEqual(rUp.samples.max() ?? 0, Self.ceiling)
        XCTAssertGreaterThanOrEqual(rDown.samples.min() ?? 0, -Self.ceiling,
                                    "a negative peak was boosted past −ceiling.")
    }

    /// 5 (case E) — interleaved stereo shares ONE gain; the hottest channel governs both.
    func testTheHottestChannelGovernsTheCommonGain() {
        var stereo = [Float](repeating: 0, count: 2_000)
        for f in 0..<1_000 {
            stereo[2 * f] = 0.1 * sinf(Float(f) * 0.05)       // L: peak ~0.1
            stereo[2 * f + 1] = 0.02 * sinf(Float(f) * 0.07) // R: quiet body …
        }
        stereo[2 * 500 + 1] = -0.4                            // … with a hot negative peak
        let r = Self.render(stereo, requestedDB: 12)
        let lin = SingleExport.gainFactor(dB: r.gainDB)
        let rightSamples: [Float] = stride(from: 1, to: r.samples.count, by: 2).map { (i: Int) -> Float in
            abs(r.samples[i])
        }
        let rightPeak: Float = rightSamples.max() ?? 0
        XCTAssertLessThanOrEqual(rightPeak, Self.ceiling, "the hot channel overshot.")
        XCTAssertEqual(r.samples[2 * 100], stereo[2 * 100] * lin, accuracy: 1e-7,
                       "the cool channel got a DIFFERENT gain — the export applies one scalar.")
        XCTAssertLessThan(r.gainDB, 12, "premise: the cool channel alone would have taken +12 dB.")
    }

    /// 6 (case F) — an already-safe source gets exactly what was requested, sample for sample.
    func testASafeSourceIsNotAttenuated() {
        let source = Self.sine(count: 2_000, amplitude: 0.1)
        let r = Self.render(source, requestedDB: 3)
        XCTAssertEqual(r.gainDB, 3, accuracy: 1e-6,
                       "0.1 + 3 dB is far under the ceiling — any cut here is unnecessary.")
        let lin = SingleExport.gainFactor(dB: 3)
        XCTAssertEqual(r.samples[123], source[123] * lin, accuracy: 1e-7)
        // Attenuation and "No target" pass untouched, whatever the peak.
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: -4, sourcePeak: 0.99), -4)
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: 0, sourcePeak: 0.99), 0,
                       "\"No target\" must stay exactly the captured level.")
    }

    /// 7 (case G) — silence and near-silence stay finite; non-finite inputs never boost.
    func testSilenceAndNonFiniteInputsStayFinite() {
        let silent = [Float](repeating: 0, count: 1_000)
        let r = Self.render(silent, requestedDB: SingleExport.normalizeGainDB(target: -14,
                                                                              measuredDB: -60))
        XCTAssertEqual(r.gainDB, 12, accuracy: 1e-6, "silence has nothing to overshoot.")
        XCTAssertTrue(r.samples.allSatisfy { $0 == 0 }, "gain on silence produced non-zero output.")

        let whisper = Self.sine(count: 1_000, amplitude: 1e-9)
        let w = Self.render(whisper, requestedDB: 12)
        XCTAssertTrue(w.gainDB.isFinite && w.samples.allSatisfy(\.isFinite))
        XCTAssertLessThanOrEqual(w.gainDB, 12, "near-silence produced an absurd gain.")

        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: 6, sourcePeak: .nan), 0)
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: 6, sourcePeak: .infinity), 0)
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: .nan, sourcePeak: 0.1), 0)
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: .infinity, sourcePeak: 0.1), 0)
    }

    /// 8 (case H) — at and around the +12 dB boundary, across a sweep of peaks: every positive
    /// gain lands at or under the ceiling, and no non-positive gain raises a sample.
    func testTheTwelveDecibelBoundaryIsPeakSafeAcrossASweep() {
        let edgePeak = Self.ceiling / SingleExport.gainFactor(dB: 12)   // +12 dB lands ON it
        for scale: Float in [0.5, 0.999, 1, 1.001, 2] {
            let buffer: [Float] = [0, edgePeak * scale, -0.001]
            let r = Self.render(buffer, requestedDB: 12)
            XCTAssertLessThanOrEqual(r.peak, Self.ceiling, "overshoot at scale \(scale)")
        }
        var peak: Float = 1e-6
        while peak <= 1 {
            for requested: Float in [0.5, 6, 11.999, 12] {
                let buffer: [Float] = [peak, -peak * 0.5]
                let r = Self.render(buffer, requestedDB: requested)
                if r.gainDB > 0 {
                    XCTAssertLessThanOrEqual(r.peak, Self.ceiling,
                                             "peak \(peak) × \(r.gainDB) dB overshot the ceiling")
                } else {
                    XCTAssertLessThanOrEqual(r.peak, peak, "a non-positive gain raised a sample")
                }
            }
            peak *= 1.37
        }
    }

    // MARK: - wiring (SOURCE-TEXT SCAN — the async AVFoundation path cannot be driven here)

    /// 9 — `export` bounds the normalisation gain BEFORE it renders, and renders THAT value.
    func testTheExportRendersTheBoundedGain() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        guard let request = code.range(of: "Self.normalizeGainDB(target: targetLUFS"),
              let bound = code.range(of: "Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.samplePeak)"),
              let render = code.range(of: "gainDB: safeGain, timeRange: timeRange)") else {
            return XCTFail("ANCHOR MISSING (#454): `export` no longer bounds the requested gain by "
                           + "the measured sample peak before rendering. That reopens E1: a sparse "
                           + "take is boosted up to +12 dB straight into the PCM converter.")
        }
        XCTAssertLessThan(request.lowerBound, bound.lowerBound)
        XCTAssertLessThan(bound.lowerBound, render.lowerBound)
    }

    /// 10 — the peak comes from the SAME read as the loudness, and the renderer touches samples
    /// ONLY through `applyGain` (one `vDSP_vsmul` in the file — a second would be a second,
    /// unbounded gain path). COUNT PIN — legal to move (#364), never silently.
    func testThePeakIsMeasuredAndTheGainHasOneApplicationSite() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        XCTAssertTrue(code.contains("let segmentPeak = Self.samplePeak(floatPtr, count: count)"),
                      "the measurement pass no longer takes the sample peak — the bound would "
                      + "be steering by a number nothing measures.")
        XCTAssertTrue(code.contains("SingleExport.applyGain(floatPtr, count: n, linearGain: linearGain)"),
                      "the render loop no longer applies the gain through `applyGain`.")
        XCTAssertTrue(code.contains("let linearGain = Self.gainFactor(dB: gainDB)"),
                      "the renderer converts dB → linear somewhere the tests do not drive.")
        XCTAssertEqual(Self.occurrences(of: "vDSP_vsmul(", in: code), 1,
                       "a second `vDSP_vsmul` in `SingleExport` is a second gain path the peak "
                       + "bound does not cover. If it is intended, say in the same commit why it "
                       + "cannot raise a sample above the ceiling.")
    }

    // MARK: - helpers

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var i = text.startIndex
        while let r = text.range(of: needle, range: i..<text.endIndex) {
            count += 1
            i = r.upperBound
        }
        return count
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

// TheExportNormalisesByIntegratedLoudnessTests.swift
// Echoel — Export quality E2: `SingleExport` normalises by gated INTEGRATED loudness (LUFS).
//
// THE DEFECT. The export steered its gain by a function named `measureLUFS` that was not LUFS:
// mean-square → RMS → dBFS − 0.1. No K-weighting, no gating. The Master panel shows real
// BS.1770 loudness from `EchoelLoudnessMeter`, so the readout and the export disagreed about
// what "−14 LUFS" means. A bass-heavy take and a bright one at the same RMS got the same gain,
// and quiet passages dragged the measurement down and bought a boost.
//
// THE REPAIR. `ExportLoudnessMeasurement` feeds the SAME `EchoelLoudnessMeter` (no second
// algorithm), one 100 ms hop per call so every 400 ms block sits on the BS.1770 grid, at 48 kHz
// — the only rate the meter's K-weighting coefficients are exact for (at 44.1 kHz they err by
// up to ~+1.1 dB at 20 Hz; that is E3 and stays out of this slice). Undefined loudness (no
// block above the −70 LUFS gate) now asks for 0 dB instead of the old floor's +12 dB. The E1
// sample-peak bound still decides the APPLIED gain; `TheExportGainCannotClipTests` owns that.
//
// ⚠️ HONEST LIMITS (§1).
//   · Claims 1–10 are END-TO-END over the shipped measurement: synthetic interleaved stereo at
//     48 kHz through `ExportLoudnessMeasurement` → `EchoelLoudnessMeter` → `normalizeGainDB` →
//     `peakSafeGainDB`, reading the numbers the export decides from. The async AVFoundation
//     decode (the 48 kHz reader pass itself) is NOT driven — it needs a real asset.
//   · Claims 11–12 are SOURCE-TEXT SCANS that the export wires that measurement.
//   · Integrated loudness per BS.1770-4 for stereo, quantised to the meter's 0.1 LU histogram
//     bins (a steady tone reads up to +0.05 LU high). Not a claim of full EBU R128 conformance,
//     not true-peak, not run against the complete EBU test-vector set. That the export SOUNDS
//     right at its target is a listening probe — NEEDS-FOUNDER-VERIFY, not claimed here.
//
// ⭐ GRADING (§3), transcribed in Python (float32 K-weighting, Double sums, 0.1 LU bins, fed in
// 4800-frame hops) against both trees:
//   · parent (d71eb2936): `ExportLoudnessMeasurement` does not exist and `normalizeGainDB` takes
//     a non-optional — the file does not COMPILE there, so no assertion has a verdict on the
//     parent. Claims 1–10 are FORWARD guards; claims 11–12 are red there by anchor absence (one
//     absence, #486).
//   · worktree: all green. Transcribed values: −23 dBFS stereo 1 kHz → −22.95 · −33 → −32.95 ·
//     L only → −26.05 · L −23 / R −29 → −25.05 · −40 → −39.95 · −65 → −64.95 · −75 → undefined ·
//     silence → undefined · 0.3 s → undefined · 1.5 s −36 / 4 s −23 / 1.5 s −36 → −23.25 (ungated
//     ≈ −25.2, retired RMS −28.38) · 1 kHz vs 60 Hz at −20 dBFS → 3.60 LU apart (retired: 0.00).
//     Segmenting the stream as [1, 1023, 4097, 3, 8192, 17] floats yields identical hops.

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `ExportLoudnessMeasurement` and the `SingleExport` statics are internal.
@testable import Echoelmusic

final class TheExportNormalisesByIntegratedLoudnessTests: XCTestCase {

    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"
    private static let meterFile = "Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift"
    private static let rate = Double(ExportLoudnessMeasurement.sampleRate)

    // MARK: - fixtures (interleaved stereo at the measurement rate)

    /// One channel of a sine at `dBFS` PEAK (EBU TECH 3341 convention: a full-scale sine is
    /// 0 dBFS); nil = digital silence. Phase in Double so long fixtures stay clean.
    private static func channel(seconds: Double, dBFS: Float?, hz: Double = 1000) -> [Float] {
        let count = Int((seconds * rate).rounded())
        guard let dBFS else { return [Float](repeating: 0, count: count) }
        let amplitude = Double(powf(10, dBFS / 20))
        return (0..<count).map { i -> Float in
            Float(amplitude * sin(2 * Double.pi * hz * Double(i) / rate))
        }
    }

    private static func interleave(_ left: [Float], _ right: [Float]) -> [Float] {
        let frames = Swift.min(left.count, right.count)
        var out = [Float](repeating: 0, count: 2 * frames)
        for i in 0..<frames {
            out[2 * i] = left[i]
            out[2 * i + 1] = right[i]
        }
        return out
    }

    private static func stereoTone(seconds: Double, dBFS: Float?, hz: Double = 1000) -> [Float] {
        let c = channel(seconds: seconds, dBFS: dBFS, hz: hz)
        return interleave(c, c)
    }

    /// Integrated loudness through the SHIPPED measurement. `segments` cycles through the
    /// given float counts, the way a reader hands over segments of arbitrary size.
    private static func measure(_ interleaved: [Float], segments: [Int]? = nil) -> Float? {
        let m = ExportLoudnessMeasurement()
        interleaved.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            guard let segments, !segments.isEmpty else {
                m.append(interleaved: base, sampleCount: buf.count)
                return
            }
            var offset = 0
            var k = 0
            while offset < buf.count {
                let n = Swift.min(Swift.max(segments[k % segments.count], 1), buf.count - offset)
                m.append(interleaved: base + offset, sampleCount: n)
                offset += n
                k += 1
            }
        }
        return m.integratedLUFS()
    }

    /// The RETIRED export measurement, reproduced here only so claim 10 can show the two
    /// disagree: whole-window RMS in dBFS minus a fixed 0.1.
    private static func retiredRMSApproximation(_ interleaved: [Float]) -> Float {
        guard !interleaved.isEmpty else { return -60 }
        let meanSquare = interleaved.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(interleaved.count)
        return Float(10 * log10(meanSquare)) - 0.1
    }

    // MARK: - behaviour

    /// 1 (case A) — a steady stereo 1 kHz tone at −23 dBFS reads −23 LUFS (EBU TECH 3341 case 1,
    /// ±0.1 LU), and the same buffer measured twice reads bit-identically (case I).
    func testASteadyToneReadsItsReferenceLoudnessRepeatably() throws {
        let tone = Self.stereoTone(seconds: 3, dBFS: -23)
        let first = try XCTUnwrap(Self.measure(tone), "a −23 LUFS tone must have a defined loudness")
        XCTAssertEqual(first, -23, accuracy: 0.1)
        let second = try XCTUnwrap(Self.measure(tone))
        XCTAssertEqual(first, second, "the measurement is not deterministic")
    }

    /// 2 (case B) — the same signal 10 dB quieter reads 10 LU quieter.
    func testTenDecibelsOfLevelIsTenLoudnessUnits() throws {
        let loud = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23)))
        let quiet = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -33)))
        XCTAssertEqual(loud - quiet, 10, accuracy: 0.12)
    }

    /// 3 (case C) — the requested gain is target − measured, from the MEASURED loudness.
    func testTheRequestedGainIsTargetMinusMeasuredLoudness() throws {
        let measured = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23)))
        let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: measured)
        XCTAssertEqual(requested, -14 - measured, accuracy: 1e-5)
        XCTAssertEqual(requested, 9, accuracy: 0.1)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: nil, measuredDB: measured), 0,
                       "\"No target\" must stay exactly the captured level.")
    }

    /// 4 (case D) — a quiet take asks for a big boost, and the E1 bound still caps what is
    /// APPLIED from the render-rate peak: a hot transient gets no boost, a moderate one gets
    /// only its headroom, and the rendered peak stays under the ceiling.
    func testTheLoudnessRequestStillPassesTheE1PeakBound() throws {
        let measured = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 4, dBFS: -40)))
        XCTAssertEqual(measured, -40, accuracy: 0.1)
        let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: measured)
        XCTAssertEqual(requested, 12, accuracy: 1e-6, "a −40 LUFS take must ask for the full +12 dB")

        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: requested, sourcePeak: 0.95), 0,
                       "a near-full-scale transient must not be boosted")

        let ceiling = powf(10, SingleExport.exportSamplePeakCeilingDBFS / 20)
        var body = Self.channel(seconds: 0.5, dBFS: -40)
        body[1000] = 0.3
        let applied = SingleExport.peakSafeGainDB(requestedDB: requested, sourcePeak: 0.3)
        XCTAssertGreaterThan(applied, 0, "the bound disabled normalisation instead of capping it")
        XCTAssertLessThan(applied, requested)
        body.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            SingleExport.applyGain(base, count: buf.count, linearGain: SingleExport.gainFactor(dB: applied))
        }
        XCTAssertLessThanOrEqual(body.map { abs($0) }.max() ?? 0, ceiling)
    }

    /// 5 (case E) — digital silence has NO integrated loudness, and that asks for 0 dB: finite,
    /// deterministic, no runaway gain (the retired floor asked for +12 dB of noise floor).
    func testSilenceHasNoLoudnessAndAsksForNoGain() {
        let silence = Self.stereoTone(seconds: 3, dBFS: nil)
        XCTAssertNil(Self.measure(silence))
        let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: Self.measure(silence))
        XCTAssertEqual(requested, 0)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: .nan), 0)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: -.infinity), 0)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: .infinity), 0)
    }

    /// 6 (case F) — the absolute gate: material under −70 LUFS throughout is undefined (0 dB),
    /// material just above it is measured (and clamped to +12 dB). A window shorter than one
    /// 400 ms block is undefined too.
    func testTheAbsoluteGateDecidesWhatIsMeasured() throws {
        XCTAssertNil(Self.measure(Self.stereoTone(seconds: 3, dBFS: -75)),
                     "a −75 LUFS take is below the −70 LUFS absolute gate")
        let quiet = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -65)))
        XCTAssertEqual(quiet, -65, accuracy: 0.1)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: quiet), 12, accuracy: 1e-6)
        XCTAssertNil(Self.measure(Self.stereoTone(seconds: 0.3, dBFS: -23)),
                     "0.3 s holds no complete 400 ms block")
    }

    /// 7 (case G) — loud + quiet sections: the relative gate drops the quiet blocks, so the
    /// result sits by the loud section (−23.25), not at the ungated mean (≈ −25.2) and far from
    /// the retired whole-window RMS (−28.4).
    func testTheRelativeGateIgnoresQuietPassages() throws {
        let section: [Float] = Self.channel(seconds: 1.5, dBFS: -36)
            + Self.channel(seconds: 4, dBFS: -23)
            + Self.channel(seconds: 1.5, dBFS: -36)
        let mixed = Self.interleave(section, section)
        let integrated = try XCTUnwrap(Self.measure(mixed))
        XCTAssertEqual(integrated, -23, accuracy: 0.4, "the relative gate did not drop the quiet blocks")
        XCTAssertGreaterThan(integrated - Self.retiredRMSApproximation(mixed), 4)
    }

    /// 8 (case H) — channel combination: L and R are summed as POWERS with weight 1.0, one
    /// silent channel reads 3 dB down, an asymmetric pair reads their power sum, and swapping
    /// the channels changes nothing.
    func testTheChannelsAreSummedAsPowers() throws {
        let both = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23)))
        let left = Self.channel(seconds: 3, dBFS: -23)
        let silent = Self.channel(seconds: 3, dBFS: nil)
        let leftOnly = try XCTUnwrap(Self.measure(Self.interleave(left, silent)))
        let rightOnly = try XCTUnwrap(Self.measure(Self.interleave(silent, left)))
        XCTAssertEqual(both - leftOnly, 3.01, accuracy: 0.12)
        XCTAssertEqual(leftOnly, rightOnly, "L and R are not weighted equally")

        let asymmetric = try XCTUnwrap(Self.measure(Self.interleave(left, Self.channel(seconds: 3, dBFS: -29))))
        let expected = 10 * log10f(powf(10, leftOnly / 10) + powf(10, (leftOnly - 6) / 10))
        XCTAssertEqual(asymmetric, expected, accuracy: 0.12)
    }

    /// 9 (case I) — the reader's segment sizes do not matter: odd float counts, one-sample
    /// segments and segments longer than a hop all yield the SAME result, bit for bit.
    func testSegmentSizesDoNotChangeTheMeasurement() throws {
        let section: [Float] = Self.channel(seconds: 1, dBFS: -30) + Self.channel(seconds: 2, dBFS: -20)
        let stream = Self.interleave(section, Self.channel(seconds: 3, dBFS: -26))
        let whole = try XCTUnwrap(Self.measure(stream))
        XCTAssertEqual(Self.measure(stream, segments: [1, 1023, 4097, 3, 8192, 17]), whole)
        XCTAssertEqual(Self.measure(stream, segments: [2 * ExportLoudnessMeasurement.hopFrames]), whole)
        XCTAssertEqual(Self.measure(stream, segments: [7]), whole)
    }

    /// 10 (case J) — REGRESSION: K-weighting is really there. A 1 kHz and a 60 Hz tone at the
    /// same level had the SAME retired RMS value; integrated loudness puts them ~3.6 LU apart.
    func testKWeightingSeparatesWhatTheRetiredRMSCouldNot() throws {
        let bright = Self.stereoTone(seconds: 3, dBFS: -20, hz: 1000)
        let bass = Self.stereoTone(seconds: 3, dBFS: -20, hz: 60)
        XCTAssertEqual(Self.retiredRMSApproximation(bright), Self.retiredRMSApproximation(bass), accuracy: 0.01,
                       "premise: the retired measurement could not tell these apart")
        let brightLUFS = try XCTUnwrap(Self.measure(bright))
        let bassLUFS = try XCTUnwrap(Self.measure(bass))
        XCTAssertEqual(brightLUFS - bassLUFS, 3.6, accuracy: 0.15)
    }

    // MARK: - wiring (SOURCE-TEXT SCAN — the async AVFoundation decode cannot be driven here)

    /// 11 — the export decides its request from the integrated loudness, measured at the
    /// meter's exact rate, then bounds it by the E1 peak; the retired RMS measurement is gone.
    func testTheExportRequestsGainFromIntegratedLoudness() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        guard let request = code.range(of: "Self.normalizeGainDB(target: targetLUFS, measuredDB: levels.integratedLUFS)"),
              let bound = code.range(of: "Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.samplePeak)") else {
            return XCTFail("ANCHOR MISSING (#454): `export` no longer requests its gain from the "
                           + "integrated loudness, or no longer bounds it by the peak.")
        }
        XCTAssertLessThan(request.lowerBound, bound.lowerBound)
        XCTAssertTrue(code.contains("sampleRate: ExportLoudnessMeasurement.sampleRate) { floatPtr, count in"),
                      "the loudness pass no longer decodes at the rate the K-weighting is exact for.")
        XCTAssertTrue(code.contains("loudness.append(interleaved: floatPtr, sampleCount: count)"),
                      "the loudness pass no longer feeds `ExportLoudnessMeasurement`.")
        XCTAssertFalse(code.contains("vDSP_measqv("), "a whole-window mean-square is back in the export.")
        XCTAssertFalse(code.contains("func measureLUFS("), "the retired RMS measurement is back under its old name.")
    }

    /// 12 — ONE meter: the measurement uses `EchoelLoudnessMeter` at 48 kHz, and its hop is the
    /// meter's own 100 ms hop — the grid claim 9 relies on.
    func testTheMeasurementFeedsTheOneMeterOnItsOwnHop() throws {
        XCTAssertEqual(ExportLoudnessMeasurement.sampleRate, 48_000)
        XCTAssertEqual(ExportLoudnessMeasurement.hopFrames,
                       Swift.max(1, Int(Float(0.1) * Float(ExportLoudnessMeasurement.sampleRate))),
                       "the export's hop and the meter's hop (`Int(0.1 * sampleRate)`) disagree")
        let code = SourceText.codeOnly(try Self.text(Self.export))
        XCTAssertTrue(code.contains("EchoelLoudnessMeter(sampleRate: Float(ExportLoudnessMeasurement.sampleRate))"),
                      "the export measures loudness with something other than the one meter.")
        let meter = SourceText.codeOnly(try Self.text(Self.meterFile))
        XCTAssertTrue(meter.contains("self.hopLen = Swift.max(1, Int(0.1 * sampleRate))"),
                      "the meter's hop formula changed — re-derive `ExportLoudnessMeasurement.hopFrames`.")
    }

    // MARK: - helpers

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

// TheExportNormalisesByIntegratedLoudnessTests.swift
// Echoel — Export quality E2 (+ E3 rate fold): `SingleExport` normalises by gated INTEGRATED
// loudness (LUFS), measured in the SAME decode that takes the E1 sample peak.
//
// THE DEFECT (E2). The export steered its gain by a function named `measureLUFS` that was not
// LUFS: mean-square → RMS → dBFS − 0.1. No K-weighting, no gating. The Master panel shows real
// BS.1770 loudness from `EchoelLoudnessMeter`, so the readout and the export disagreed about
// what "−14 LUFS" means.
//
// THE REPAIR. `ExportLoudnessMeasurement` feeds the SAME `EchoelLoudnessMeter` (no second
// algorithm), one 100 ms hop per call (`gatingHopFrames`, the meter's own) so every 400 ms
// block sits on the BS.1770 grid. Undefined loudness (no block above the −70 LUFS gate) asks
// for 0 dB. E2 decoded a separate 48 kHz pass because the meter's K-weighting was the 48 kHz
// table at every rate; E3 made the meter rate-correct (`TheLoudnessMeterIsSampleRateCorrectTests`)
// and folded loudness into the ONE analysis decode at `SingleExport.exportSampleRate`.
//
// ⚠️ HONEST LIMITS (§1).
//   · Claims 1–10 are END-TO-END over the shipped measurement, each at BOTH 44.1 and 48 kHz:
//     synthetic interleaved stereo through `ExportLoudnessMeasurement` → `EchoelLoudnessMeter`
//     → `normalizeGainDB` → `peakSafeGainDB`, reading the numbers the export decides from. The
//     async AVFoundation decode itself is NOT driven — it needs a real asset.
//   · Claims 11–13 are SOURCE-TEXT SCANS of the wiring.
//   · Integrated loudness per BS.1770-4 for stereo, quantised to the meter's 0.1 LU bins (a
//     steady tone reads up to +0.05 LU high). Not full EBU R128 conformance, not true-peak.
//     That the export SOUNDS right at its target is a listening probe — NEEDS-FOUNDER-VERIFY.
//
// ⭐ GRADING (§3), transcribed in Python (float32 K-weighting DERIVED per rate, Double sums,
// 0.1 LU bins, fed in `gatingHopFrames` hops) against both trees:
//   · parent (6358b99d0): `ExportLoudnessMeasurement(sampleRate:)` and
//     `SingleExport.exportSampleRate` do not exist — the file does not COMPILE there, so no
//     assertion has a verdict on the parent. Claims 1–10 and 13 are FORWARD guards; claims
//     11–12 are red there by anchor absence (one absence, #486).
//   · worktree: all green, and IDENTICAL at 44.1 and 48 kHz: −23 dBFS stereo 1 kHz → −22.95 ·
//     −33 → −32.95 · L only → −26.05 · L −23 / R −29 → −25.05 · −40 → −39.95 · −65 → −64.95 ·
//     −75 → undefined · silence → undefined · 0.3 s → undefined · 1.5 s −36 / 4 s −23 / 1.5 s
//     −36 → −23.25 (retired RMS −28.38) · 1 kHz vs 60 Hz at −20 dBFS → 3.60 LU apart (retired
//     0.00). Segmenting as [1, 1023, 4097, 3, 8192, 17] floats yields identical hops.

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `ExportLoudnessMeasurement` and the `SingleExport` statics are internal.
@testable import Echoelmusic

final class TheExportNormalisesByIntegratedLoudnessTests: XCTestCase {

    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"
    /// The export's own rate plus the meter's canonical one — the two the app really meets.
    private static let rates: [Int] = [SingleExport.exportSampleRate, 48_000]

    // MARK: - fixtures (interleaved stereo at `rate`)

    /// One channel of a sine at `dBFS` PEAK (EBU TECH 3341 convention: a full-scale sine is
    /// 0 dBFS); nil = digital silence. Phase in Double so long fixtures stay clean.
    private static func channel(seconds: Double, dBFS: Float?, rate: Int, hz: Double = 1000) -> [Float] {
        let sr = Double(rate)
        let count = Int((seconds * sr).rounded())
        guard let dBFS else { return [Float](repeating: 0, count: count) }
        let amplitude = Double(powf(10, dBFS / 20))
        return (0..<count).map { i -> Float in
            Float(amplitude * sin(2 * Double.pi * hz * Double(i) / sr))
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

    private static func stereoTone(seconds: Double, dBFS: Float?, rate: Int, hz: Double = 1000) -> [Float] {
        let c = channel(seconds: seconds, dBFS: dBFS, rate: rate, hz: hz)
        return interleave(c, c)
    }

    /// Integrated loudness through the SHIPPED measurement. `segments` cycles through the
    /// given float counts, the way a reader hands over segments of arbitrary size.
    private static func measure(_ interleaved: [Float], rate: Int, segments: [Int]? = nil) -> Float? {
        let m = ExportLoudnessMeasurement(sampleRate: rate)
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

    // MARK: - behaviour, at every rate

    /// 1 (case A) — a steady stereo 1 kHz tone at −23 dBFS reads −23 LUFS (EBU TECH 3341 case 1,
    /// ±0.1 LU), and the same buffer measured twice reads bit-identically (case I).
    func testASteadyToneReadsItsReferenceLoudnessRepeatably() throws {
        for rate in Self.rates {
            let tone = Self.stereoTone(seconds: 3, dBFS: -23, rate: rate)
            let first = try XCTUnwrap(Self.measure(tone, rate: rate), "@\(rate): a −23 LUFS tone must be defined")
            XCTAssertEqual(first, -23, accuracy: 0.1, "@\(rate)")
            let second = try XCTUnwrap(Self.measure(tone, rate: rate))
            XCTAssertEqual(first, second, "@\(rate): the measurement is not deterministic")
        }
    }

    /// 2 (case B) — the same signal 10 dB quieter reads 10 LU quieter.
    func testTenDecibelsOfLevelIsTenLoudnessUnits() throws {
        for rate in Self.rates {
            let loud = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23, rate: rate), rate: rate))
            let quiet = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -33, rate: rate), rate: rate))
            XCTAssertEqual(loud - quiet, 10, accuracy: 0.12, "@\(rate)")
        }
    }

    /// 3 (case C) — the requested gain is target − measured, from the MEASURED loudness.
    func testTheRequestedGainIsTargetMinusMeasuredLoudness() throws {
        for rate in Self.rates {
            let measured = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23, rate: rate), rate: rate))
            let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: measured)
            XCTAssertEqual(requested, -14 - measured, accuracy: 1e-5, "@\(rate)")
            XCTAssertEqual(requested, 9, accuracy: 0.1, "@\(rate)")
            XCTAssertEqual(SingleExport.normalizeGainDB(target: nil, measuredDB: measured), 0,
                           "\"No target\" must stay exactly the captured level.")
        }
    }

    /// 4 (case D / E3 case E) — a quiet take asks for a big boost, and the E1 bound still caps
    /// what is APPLIED: a hot transient gets no boost, a moderate one gets only its headroom,
    /// and the rendered peak stays under the ceiling.
    func testTheLoudnessRequestStillPassesTheE1PeakBound() throws {
        let ceiling = powf(10, SingleExport.exportSamplePeakCeilingDBFS / 20)
        for rate in Self.rates {
            let measured = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 4, dBFS: -40, rate: rate), rate: rate))
            XCTAssertEqual(measured, -40, accuracy: 0.1, "@\(rate)")
            let requested = SingleExport.normalizeGainDB(target: -14, measuredDB: measured)
            XCTAssertEqual(requested, 12, accuracy: 1e-6, "@\(rate): a −40 LUFS take must ask for the full +12 dB")
            XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: requested, sourcePeak: 0.95), 0,
                           "a near-full-scale transient must not be boosted")

            var body = Self.channel(seconds: 0.5, dBFS: -40, rate: rate)
            body[1000] = 0.3
            let applied = SingleExport.peakSafeGainDB(requestedDB: requested, sourcePeak: 0.3)
            XCTAssertGreaterThan(applied, 0, "the bound disabled normalisation instead of capping it")
            XCTAssertLessThan(applied, requested)
            body.withUnsafeMutableBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                SingleExport.applyGain(base, count: buf.count, linearGain: SingleExport.gainFactor(dB: applied))
            }
            XCTAssertLessThanOrEqual(body.map { abs($0) }.max() ?? 0, ceiling, "@\(rate)")
        }
    }

    /// 5 (case E) — digital silence has NO integrated loudness, and that asks for 0 dB: finite,
    /// deterministic, no runaway gain (the retired floor asked for +12 dB of noise floor).
    func testSilenceHasNoLoudnessAndAsksForNoGain() {
        for rate in Self.rates {
            let silence = Self.stereoTone(seconds: 3, dBFS: nil, rate: rate)
            XCTAssertNil(Self.measure(silence, rate: rate), "@\(rate)")
            XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: Self.measure(silence, rate: rate)), 0)
        }
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: .nan), 0)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: -.infinity), 0)
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: .infinity), 0)
    }

    /// 6 (case F) — the absolute gate: material under −70 LUFS throughout is undefined (0 dB),
    /// material just above it is measured (and clamped to +12 dB). A window shorter than one
    /// 400 ms block is undefined too.
    func testTheAbsoluteGateDecidesWhatIsMeasured() throws {
        for rate in Self.rates {
            XCTAssertNil(Self.measure(Self.stereoTone(seconds: 3, dBFS: -75, rate: rate), rate: rate),
                         "@\(rate): a −75 LUFS take is below the −70 LUFS absolute gate")
            let quiet = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -65, rate: rate), rate: rate))
            XCTAssertEqual(quiet, -65, accuracy: 0.1, "@\(rate)")
            XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: quiet), 12, accuracy: 1e-6)
            XCTAssertNil(Self.measure(Self.stereoTone(seconds: 0.3, dBFS: -23, rate: rate), rate: rate),
                         "@\(rate): 0.3 s holds no complete 400 ms block")
        }
    }

    /// 7 (case G) — loud + quiet sections: the relative gate drops the quiet blocks, so the
    /// result sits by the loud section (−23.25), not at the ungated mean (≈ −25.2) and far from
    /// the retired whole-window RMS (−28.4).
    func testTheRelativeGateIgnoresQuietPassages() throws {
        for rate in Self.rates {
            let section: [Float] = Self.channel(seconds: 1.5, dBFS: -36, rate: rate)
                + Self.channel(seconds: 4, dBFS: -23, rate: rate)
                + Self.channel(seconds: 1.5, dBFS: -36, rate: rate)
            let mixed = Self.interleave(section, section)
            let integrated = try XCTUnwrap(Self.measure(mixed, rate: rate))
            XCTAssertEqual(integrated, -23, accuracy: 0.4, "@\(rate): the relative gate did not drop the quiet blocks")
            XCTAssertGreaterThan(integrated - Self.retiredRMSApproximation(mixed), 4, "@\(rate)")
        }
    }

    /// 8 (case H) — channel combination: L and R are summed as POWERS with weight 1.0, one
    /// silent channel reads 3 dB down, an asymmetric pair reads their power sum, and swapping
    /// the channels changes nothing.
    func testTheChannelsAreSummedAsPowers() throws {
        for rate in Self.rates {
            let both = try XCTUnwrap(Self.measure(Self.stereoTone(seconds: 3, dBFS: -23, rate: rate), rate: rate))
            let left = Self.channel(seconds: 3, dBFS: -23, rate: rate)
            let silent = Self.channel(seconds: 3, dBFS: nil, rate: rate)
            let leftOnly = try XCTUnwrap(Self.measure(Self.interleave(left, silent), rate: rate))
            let rightOnly = try XCTUnwrap(Self.measure(Self.interleave(silent, left), rate: rate))
            XCTAssertEqual(both - leftOnly, 3.01, accuracy: 0.12, "@\(rate)")
            XCTAssertEqual(leftOnly, rightOnly, "@\(rate): L and R are not weighted equally")

            let right = Self.channel(seconds: 3, dBFS: -29, rate: rate)
            let asymmetric = try XCTUnwrap(Self.measure(Self.interleave(left, right), rate: rate))
            let expected = 10 * log10f(powf(10, leftOnly / 10) + powf(10, (leftOnly - 6) / 10))
            XCTAssertEqual(asymmetric, expected, accuracy: 0.12, "@\(rate)")
        }
    }

    /// 9 (case I / E3 case F) — the reader's segment sizes do not matter: odd float counts,
    /// one-sample segments and segments longer than a hop all yield the SAME result, bit for bit.
    func testSegmentSizesDoNotChangeTheMeasurement() throws {
        for rate in Self.rates {
            let section: [Float] = Self.channel(seconds: 1, dBFS: -30, rate: rate)
                + Self.channel(seconds: 2, dBFS: -20, rate: rate)
            let stream = Self.interleave(section, Self.channel(seconds: 3, dBFS: -26, rate: rate))
            let whole = try XCTUnwrap(Self.measure(stream, rate: rate))
            let hop = ExportLoudnessMeasurement(sampleRate: rate).hopFrames
            XCTAssertEqual(Self.measure(stream, rate: rate, segments: [1, 1023, 4097, 3, 8192, 17]), whole, "@\(rate)")
            XCTAssertEqual(Self.measure(stream, rate: rate, segments: [2 * hop]), whole, "@\(rate)")
            XCTAssertEqual(Self.measure(stream, rate: rate, segments: [7]), whole, "@\(rate)")
        }
    }

    /// 10 (case J) — REGRESSION: K-weighting is really there. A 1 kHz and a 60 Hz tone at the
    /// same level had the SAME retired RMS value; integrated loudness puts them ~3.6 LU apart —
    /// at 44.1 kHz too, which is where the E2-era meter read the 60 Hz tone 0.39 dB too loud.
    func testKWeightingSeparatesWhatTheRetiredRMSCouldNot() throws {
        for rate in Self.rates {
            let bright = Self.stereoTone(seconds: 3, dBFS: -20, rate: rate, hz: 1000)
            let bass = Self.stereoTone(seconds: 3, dBFS: -20, rate: rate, hz: 60)
            XCTAssertEqual(Self.retiredRMSApproximation(bright), Self.retiredRMSApproximation(bass), accuracy: 0.01,
                           "premise: the retired measurement could not tell these apart")
            let brightLUFS = try XCTUnwrap(Self.measure(bright, rate: rate))
            let bassLUFS = try XCTUnwrap(Self.measure(bass, rate: rate))
            XCTAssertEqual(brightLUFS - bassLUFS, 3.6, accuracy: 0.15, "@\(rate)")
        }
    }

    // MARK: - wiring (SOURCE-TEXT SCAN — the async AVFoundation decode cannot be driven here)

    /// 11 (E3 case H) — ONE analysis decode, at the export rate, takes BOTH numbers: the peak
    /// (E1) and the loudness (E2), from the same segments; the request comes from that
    /// loudness and is bounded by that peak before the render.
    func testOneAnalysisDecodeTakesPeakAndLoudness() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        XCTAssertEqual(Self.occurrences(of: "try await forEachDecodedSegment(", in: code), 1,
                       "the export decodes the analysis window more than once again — E3 folded the "
                       + "loudness pass into the peak pass; a second decode is the retired shape.")
        guard let pass = code.range(of: "sampleRate: Self.exportSampleRate) { floatPtr, count in"),
              let peak = code.range(of: "let segmentPeak = Self.samplePeak(floatPtr, count: count)", range: pass.upperBound..<code.endIndex),
              code.range(of: "loudness.append(interleaved: floatPtr, sampleCount: count)", range: peak.upperBound..<code.endIndex) != nil,
              let request = code.range(of: "Self.normalizeGainDB(target: targetLUFS, measuredDB: levels.integratedLUFS)"),
              let bound = code.range(of: "Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.samplePeak)") else {
            return XCTFail("ANCHOR MISSING (#454): the single analysis decode no longer takes both the "
                           + "peak and the loudness at the export rate, or the request/bound chain moved.")
        }
        XCTAssertLessThan(request.lowerBound, bound.lowerBound)
        XCTAssertTrue(code.contains("let loudness = ExportLoudnessMeasurement(sampleRate: Self.exportSampleRate)"),
                      "the loudness is measured at a rate other than the export's own.")
        XCTAssertFalse(code.contains("vDSP_measqv("), "a whole-window mean-square is back in the export.")
        XCTAssertFalse(code.contains("func measureLUFS("), "the retired RMS measurement is back under its old name.")
    }

    /// 12 (E3 case I) — the retired 48 kHz-only loudness pass is gone, and analysis, render and
    /// encoder all name the ONE export rate instead of a literal each.
    func testTheRetiredFortyEightKilohertzPassIsGone() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        XCTAssertFalse(code.contains("ExportLoudnessMeasurement.sampleRate"),
                       "the static 48 kHz measurement rate is back.")
        XCTAssertFalse(code.contains("48_000") || code.contains("48000"),
                       "a 48 kHz literal is back in the export — E3 measures at the export rate.")
        XCTAssertFalse(code.contains("AVSampleRateKey: 44100"),
                       "a reader or encoder rate is a literal again instead of `exportSampleRate`.")
        XCTAssertEqual(Self.occurrences(of: "AVSampleRateKey: Self.exportSampleRate", in: code), 3,
                       "render reader + WAV + AAC settings must name `exportSampleRate`. COUNT PIN — "
                       + "legal to move (#364), never silently.")
        XCTAssertEqual(SingleExport.exportSampleRate, 44_100)
    }

    /// 13 — ONE meter, on its OWN hop: the measurement's hop is the meter's `gatingHopFrames`
    /// (100 ms) at every rate, which is the grid claim 9 relies on.
    func testTheMeasurementFeedsTheOneMeterOnItsOwnHop() throws {
        for rate in Self.rates {
            let measurement = ExportLoudnessMeasurement(sampleRate: rate)
            XCTAssertEqual(measurement.hopFrames, EchoelLoudnessMeter(sampleRate: Float(rate)).gatingHopFrames)
            XCTAssertEqual(measurement.hopFrames, rate / 10, "@\(rate): the hop is not 100 ms")
        }
        let code = SourceText.codeOnly(try Self.text(Self.export))
        XCTAssertTrue(code.contains("let meter = EchoelLoudnessMeter(sampleRate: Float(sampleRate))"),
                      "the export measures loudness with something other than the one meter.")
        XCTAssertTrue(code.contains("self.hopFrames = meter.gatingHopFrames"),
                      "the export restates the meter's hop instead of asking it (#416).")
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

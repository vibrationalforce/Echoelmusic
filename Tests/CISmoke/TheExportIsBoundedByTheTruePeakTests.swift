// TheExportIsBoundedByTheTruePeakTests.swift
// LS-TP1 (2026-10-16, from the live-set audit's mastering item): the export's normalisation
// boost was bounded by the SAMPLE peak. A waveform whose crests fall between samples reads
// lower than it plays — a tone at a quarter of the rate, 45° off, has every sample at −3 dB
// of its crest — so a quiet take of that shape got the full +12 dB and the rendered file
// reconstructed ~2 dB OVER full scale. The bound now reads the BS.1770-4 4× true peak
// (`EchoelTruePeak`) and caps the gain against −1 dBTP.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–5 are END-TO-END over the pure `EchoelTruePeak` and the shipped
//     `SingleExport` statics (`peakSafeGainDB`, `gainFactor`, `applyGain`).
//   · Claim 6 is a SOURCE-TEXT SCAN that the async AVFoundation analysis pass feeds the
//     estimator and the bound reads it (`measureExportLevels` is private and needs a real asset).
//   · NOT CLAIMED: the 4× estimate is not the band-limited peak (~1 dB under on energy near
//     Nyquist), and nothing here bounds the AAC encoder's overshoot. A listening test of an
//     exported file stays a DEVICE PROBE.
//
// EXPECTED VALUES were derived by a float32 Python transcription of `append` (line for line,
// `Swift.max` semantics included), run three times with identical output, and checked against
// a double-precision shifting-history reference (|Δ| < 2e-7 over 120 random streams). The
// regression numbers (old bound 11.999 dB → +2.09 dBTP rendered; new bound 8.906 dB →
// −1.001 dBTP) come from the same transcription.
//
// HONEST GRADING against the parent (§3): `EchoelTruePeak` does not exist there and
// `exportTruePeakCeilingDBTP` is a new name — the file does not COMPILE on the parent, so no
// assertion has a verdict there; every claim is a FORWARD guard (one absence, #486). Claim 5's
// premise half is the REGRESSION, transcribed: on the parent's sample-peak bound the same tone
// renders at +2.09 dBTP. Mutants: |sample| dropped from the maximum (1, the impulse reads
// 0.972) · the channel counter not carried across segments (2) · one shared history for both
// channels (3) · the NaN latch removed (4) · the bound fed the sample peak again (5, 6).

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: claim 5 calls internal statics of `SingleExport`.
@testable import Echoelmusic

final class TheExportIsBoundedByTheTruePeakTests: XCTestCase {

    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"
    private static let crest: Float = 0.70710677

    /// A quarter-rate tone, 45° off: every sample is ±0.7071, the crest between them is 1.
    private static func quarterTone(frames: Int, amplitude: Float = 1, channels: Int = 1) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(frames * channels)
        let pattern: [Float] = [crest, crest, -crest, -crest]
        for n in 0..<frames {
            for _ in 0..<channels { out.append(amplitude * pattern[n % 4]) }
        }
        return out
    }

    private static func truePeak(_ samples: [Float], channels: Int) -> Float {
        var meter = EchoelTruePeak(channels: channels)
        samples.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            meter.append(interleaved: base, sampleCount: buf.count)
        }
        return meter.peak
    }

    private static func dB(_ linear: Float) -> Float { 20 * log10f(linear) }

    // MARK: 1 — the estimator sees the crest the samples miss

    func testAQuarterRateToneReadsItsCrestNotItsSamples() {
        let tone = Self.quarterTone(frames: 400)
        let reading = Self.dB(Self.truePeak(tone, channels: 1))
        XCTAssertEqual(Self.dB(Self.crest), -3.0103, accuracy: 0.001, "premise: the samples sit 3 dB under the crest")
        XCTAssertGreaterThanOrEqual(reading, 0, "the true peak of a unit-crest tone read under 0 dBTP")
        XCTAssertLessThan(reading, 0.15, "a 4× BS.1770 estimate over-reads this tone by ~0.08 dB, not more")

        // |sample| is in the maximum: a lone full-scale impulse reads exactly 1, not the 0.972
        // of the filter's largest tap.
        var impulse = [Float](repeating: 0, count: 20)
        impulse[10] = 1
        XCTAssertEqual(Self.truePeak(impulse, channels: 1), 1)
        XCTAssertEqual(Self.truePeak([Float](repeating: 0, count: 64), channels: 2), 0)
    }

    // MARK: 2 — a stream read in pieces measures like one pass

    func testSegmentsThatSplitFramesChangeNothing() {
        var stereo: [Float] = []
        let tone = Self.quarterTone(frames: 300, amplitude: 0.5)
        for n in 0..<300 {
            stereo.append(tone[n])
            stereo.append(0.25 * sinf(Float(n) * 1.3))
        }
        let whole = Self.truePeak(stereo, channels: 2)
        var pieces = EchoelTruePeak(channels: 2)
        let lengths = [1, 3, 7, 2, 5]   // odd lengths split frames between L and R
        var start = 0, k = 0
        stereo.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            while start < buf.count {
                let n = Swift.min(lengths[k % lengths.count], buf.count - start)
                pieces.append(interleaved: base + start, sampleCount: n)
                start += n
                k += 1
            }
        }
        XCTAssertEqual(pieces.peak, whole, "a segment boundary changed the reading")
    }

    // MARK: 3 — each channel is interpolated from its own history

    func testTheChannelsAreInterpolatedApart() {
        var stereo: [Float] = []
        let tone = Self.quarterTone(frames: 300, amplitude: 0.5)
        var left: [Float] = [], right: [Float] = []
        for n in 0..<300 {
            let r = 0.25 * sinf(Float(n) * 1.3)
            stereo.append(tone[n]); stereo.append(r)
            left.append(tone[n]); right.append(r)
        }
        let joint = Self.truePeak(stereo, channels: 2)
        XCTAssertEqual(joint, Swift.max(Self.truePeak(left, channels: 1), Self.truePeak(right, channels: 1)))
        XCTAssertNotEqual(Self.truePeak(stereo, channels: 1), joint,
                          "premise: reading the interleaved stream as ONE channel gives a different number")
    }

    // MARK: 4 — a NaN cannot vouch for a boost; reset clears it

    func testANaNIsKeptUntilReset() {
        var meter = EchoelTruePeak(channels: 2)
        let poisoned: [Float] = [0.1, 0.1, .nan, 0.1, 0.2, 0.2, 0.3, 0.3]
        poisoned.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            meter.append(interleaved: base, sampleCount: buf.count)
        }
        XCTAssertTrue(meter.peak.isNaN)
        let clean = Self.quarterTone(frames: 64, channels: 2)
        clean.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            meter.append(interleaved: base, sampleCount: buf.count)
        }
        XCTAssertTrue(meter.peak.isNaN, "a later clean block dropped the NaN")
        XCTAssertEqual(SingleExport.peakSafeGainDB(requestedDB: 6, sourcePeak: meter.peak), 0)
        meter.reset()
        XCTAssertEqual(meter.peak, 0)
    }

    // MARK: 5 — the regression: the boost lands the CREST, not the samples, at −1 dBTP

    func testAQuietQuarterRateToneIsNotBoostedOverFullScale() {
        // Samples at −13 dBFS, crest ~3 dB higher.
        let amplitude = powf(10, -13 / 20) / Self.crest
        let tone = Self.quarterTone(frames: 4_410, amplitude: amplitude, channels: 2)
        let samplePeak = tone.map { abs($0) }.max() ?? 0
        let truePeak = Self.truePeak(tone, channels: 2)

        // PREMISE (the parent's bound): steered by the sample peak, the full +12 dB is allowed
        // and the rendered crest sits over full scale.
        let oldGain = SingleExport.peakSafeGainDB(requestedDB: 12, sourcePeak: samplePeak)
        XCTAssertGreaterThan(oldGain, 11.99)
        XCTAssertGreaterThan(Self.dB(truePeak) + oldGain, 0, "premise: the old bound renders an inter-sample over")

        // THE BOUND: capped, not dropped, and the rendered TRUE peak is at or under the ceiling.
        let gain = SingleExport.peakSafeGainDB(requestedDB: 12, sourcePeak: truePeak)
        XCTAssertGreaterThan(gain, 8.8, "the boost was dropped instead of capped")
        XCTAssertLessThan(gain, 9.0)
        var rendered = tone
        rendered.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            SingleExport.applyGain(base, count: buf.count, linearGain: SingleExport.gainFactor(dB: gain))
        }
        let ceiling = SingleExport.gainFactor(dB: SingleExport.exportTruePeakCeilingDBTP)
        XCTAssertLessThanOrEqual(Self.truePeak(rendered, channels: 2), ceiling,
                                 "the rendered file's true peak crossed −1 dBTP")
    }

    // MARK: 6 — the analysis decode feeds the estimator, and the bound reads it

    func testTheAnalysisPassFeedsTheBoundTheTruePeak() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(Self.export), encoding: .utf8))
        XCTAssertTrue(code.contains("var truePeak = EchoelTruePeak(channels: 2)"))
        XCTAssertTrue(code.contains("truePeak.append(interleaved: floatPtr, sampleCount: count)"))
        XCTAssertTrue(code.contains("return (loudness.integratedLUFS(), truePeak.peak)"))
        XCTAssertTrue(code.contains("Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.truePeak)"))
    }
}

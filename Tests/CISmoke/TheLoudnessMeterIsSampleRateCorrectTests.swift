// TheLoudnessMeterIsSampleRateCorrectTests.swift
// Echoel — Export quality E3: `EchoelLoudnessMeter` derives its K-weighting PER SAMPLE RATE.
//
// THE DEFECT. The meter used the standard's 48 kHz coefficient table at every rate; its doc
// called that "a close approximation". Run at 44.1 kHz those coefficients read +1.13 dB at
// 20 Hz, +0.40 dB at 60 Hz and +0.33 dB at 1.5 kHz too high (claim 3 measures it) — on the
// Master readout whenever the hardware granted 44.1 kHz, and in the export if it had
// measured at the render rate (which is why E2 decoded a separate 48 kHz pass).
//
// THE REPAIR. `kWeighting(sampleRate:)` designs both sections by the bilinear transform from
// the BS.1770 prototypes (libebur128's parameters), once, in `init`. A rate outside
// `supportedSampleRates` DEGRADES EXPLICITLY (`supportsSampleRate == false`, readings stay at
// the floor) instead of filtering with another rate's coefficients. A new rate is a new meter.
//
// ⚠️ HONEST LIMITS (§1).
//   · Claims 1–4 are END-TO-END over the shipped design function, checked against an
//     INDEPENDENT reference: the standard's published 48 kHz table, typed here as literals and
//     evaluated with this file's own transfer-function arithmetic. The production filter is
//     not asked what its response is.
//   · Claims 5–8 drive the shipped meter (Float filter, 0.1 LU bins) end to end.
//   · Claims 9–10 are SOURCE-TEXT SCANS (rate immutability, derivation site, the engine's
//     rebuild-after-`removeTap` policy).
//   · BS.1770-style stereo integrated loudness for the supported rates. Not full EBU R128
//     conformance (no 3341/3342 suite here), not true peak, not every rate. Whether the Master
//     readout at a 44.1 kHz route now agrees with a 48 kHz one ON A DEVICE is a probe:
//     NEEDS-FOUNDER-VERIFY — play the same material over a 44.1 kHz route (e.g. Bluetooth)
//     and over the speaker, and read Master LUFS on both.
//
// ⭐ GRADING (§3), transcribed in Python (Double design, float32 filter, 0.1 LU bins) against
// both trees:
//   · parent (6358b99d0): `kWeighting(sampleRate:)`, `supportsSampleRate`, `gatingHopFrames`
//     and `KWeightingSection` do not exist — the file does not COMPILE there, so no assertion
//     has a verdict. Claims 1–8 are FORWARD guards (claim 3 is the premise that shows claim 2
//     can fail for its named reason: the parent's behaviour misses it by 0.40 dB at 60 Hz).
//     Claim 9 is red there by anchor absence; claim 10 is a COUNTERWEIGHT, green on both.
//   · worktree, measured: 48 kHz coefficients = the table to 8.9e-16 · 44.1 kHz response
//     within 0.005 dB of the table's at 20 Hz…21 kHz · 88.2/96/176.4/192 kHz within 0.038 dB ·
//     parity through the meter 44.1 vs 48 kHz: 0.00 LU at 20 Hz, 60 Hz, 1 kHz, 4 kHz, 10 kHz;
//     88.2–192 kHz vs 48 kHz: ≤ 0.10 LU (one bin — a ≤ 0.04 dB response difference can cross
//     one bin boundary, which is why claim 5's tolerance is one bin plus margin).

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `ExportLoudnessMeasurement` (claim 8) is internal.
@testable import Echoelmusic

final class TheLoudnessMeterIsSampleRateCorrectTests: XCTestCase {

    private static let meterPath = "Sources/Echoelmusic/DSP/EchoelLoudnessMeter.swift"
    private static let enginePath = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    /// ITU-R BS.1770-4, table 1 and table 2 — the published 48 kHz coefficients. Typed here on
    /// purpose: this is the independent reference, not a value read back from production.
    private static let standardShelf: [Double] =
        [1.53512485958697, -2.69169618940638, 1.19839281085285, -1.69065929318241, 0.73248077421585]
    private static let standardHighPass: [Double] =
        [1.0, -2.0, 1.0, -1.99004745483398, 0.99007225036621]

    private static let probeFrequencies: [Double] = [20, 60, 100, 1_000, 1_500, 4_000, 10_000, 20_000]
    private static let higherRates: [Double] = [88_200, 96_000, 176_400, 192_000]

    // MARK: - transfer-function arithmetic (this file's own, independent of the meter)

    /// |H(e^jω)| of one normalised biquad [b0, b1, b2, a1, a2].
    private static func magnitude(_ c: [Double], hz: Double, rate: Double) -> Double {
        let w = 2 * Double.pi * hz / rate
        let (c1, s1, c2, s2) = (cos(w), -sin(w), cos(2 * w), -sin(2 * w))
        let numRe = c[0] + c[1] * c1 + c[2] * c2
        let numIm = c[1] * s1 + c[2] * s2
        let denRe = 1 + c[3] * c1 + c[4] * c2
        let denIm = c[3] * s1 + c[4] * s2
        return (numRe * numRe + numIm * numIm).squareRoot() / (denRe * denRe + denIm * denIm).squareRoot()
    }

    /// K-weighting gain in dB of a (shelf, high-pass) pair at `hz`.
    private static func gainDB(shelf: [Double], highPass: [Double], hz: Double, rate: Double) -> Double {
        20 * log10(magnitude(shelf, hz: hz, rate: rate) * magnitude(highPass, hz: hz, rate: rate))
    }

    /// The standard's K-weighting response: its table, at its own rate.
    private static func standardDB(_ hz: Double) -> Double {
        gainDB(shelf: standardShelf, highPass: standardHighPass, hz: hz, rate: 48_000)
    }

    private static func coefficients(_ s: EchoelLoudnessMeter.KWeightingSection) -> [Double] {
        [s.b0, s.b1, s.b2, s.a1, s.a2]
    }

    /// The shipped design's response at `rate`.
    private static func derivedDB(_ hz: Double, rate: Double) -> Double {
        let k = EchoelLoudnessMeter.kWeighting(sampleRate: rate)
        return gainDB(shelf: coefficients(k.shelf), highPass: coefficients(k.highPass), hz: hz, rate: rate)
    }

    // MARK: - fixtures

    private static func tone(seconds: Double, dBFS: Float, rate: Int, hz: Double) -> [Float] {
        let sr = Double(rate)
        let count = Int((seconds * sr).rounded())
        let amplitude = Double(powf(10, dBFS / 20))
        return (0..<count).map { i -> Float in
            Float(amplitude * sin(2 * Double.pi * hz * Double(i) / sr))
        }
    }

    /// Feeds `channel` to both sides in `gatingHopFrames` chunks (the meter records at most
    /// one 400 ms block per call) and returns the meter.
    @discardableResult
    private static func feed(_ meter: EchoelLoudnessMeter, _ channel: [Float]) -> EchoelLoudnessMeter {
        channel.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let hop = Swift.max(1, meter.gatingHopFrames)
            var offset = 0
            while offset < buf.count {
                let n = Swift.min(hop, buf.count - offset)
                meter.processStereo(left: base + offset, right: base + offset, frameCount: n)
                offset += n
            }
        }
        return meter
    }

    private static func integrated(rate: Int, hz: Double, dBFS: Float) -> Float {
        feed(EchoelLoudnessMeter(sampleRate: Float(rate)),
             tone(seconds: 3, dBFS: dBFS, rate: rate, hz: hz)).integratedLUFS
    }

    // MARK: - design (END-TO-END against the standard's table)

    /// 1 (case B) — at 48 kHz the derivation IS the standard's published table.
    func testTheFortyEightKilohertzDesignIsTheStandardsTable() {
        let k = EchoelLoudnessMeter.kWeighting(sampleRate: 48_000)
        for (got, want) in zip(Self.coefficients(k.shelf), Self.standardShelf) {
            XCTAssertEqual(got, want, accuracy: 1e-12, "shelf coefficient drifted from BS.1770 table 1")
        }
        for (got, want) in zip(Self.coefficients(k.highPass), Self.standardHighPass) {
            XCTAssertEqual(got, want, accuracy: 1e-12, "high-pass coefficient drifted from BS.1770 table 2")
        }
    }

    /// 2 (case A) — at 44.1 kHz the derived filter has the standard's response: 20 Hz, 60 Hz,
    /// 100 Hz, 1 kHz, 1.5 kHz, 4 kHz, 10 kHz, 20 kHz and 21 kHz (1 kHz under Nyquist), each
    /// within 0.01 dB (measured ≤ 0.005). At 48 kHz, identical.
    func testTheFortyFourPointOneResponseMatchesTheStandard() {
        let frequencies: [Double] = Self.probeFrequencies + [21_000]
        for hz in frequencies {
            XCTAssertEqual(Self.derivedDB(hz, rate: 44_100), Self.standardDB(hz), accuracy: 0.01,
                           "44.1 kHz K-weighting is off the standard at \(hz) Hz")
        }
        for hz in Self.probeFrequencies {
            XCTAssertEqual(Self.derivedDB(hz, rate: 48_000), Self.standardDB(hz), accuracy: 0.01, "48 kHz at \(hz) Hz")
        }
    }

    /// 3 — PREMISE for claim 2: the retired behaviour (the 48 kHz table run at 44.1 kHz) is far
    /// outside that tolerance, so claim 2 can fail for its named reason.
    func testTheStandardsTableRunAtFortyFourPointOneIsWrong() {
        let retired60 = Self.gainDB(shelf: Self.standardShelf, highPass: Self.standardHighPass, hz: 60, rate: 44_100)
        let retired20 = Self.gainDB(shelf: Self.standardShelf, highPass: Self.standardHighPass, hz: 20, rate: 44_100)
        XCTAssertGreaterThan(retired60 - Self.standardDB(60), 0.3, "premise: the 48 kHz table at 44.1 kHz reads 60 Hz ~0.4 dB hot")
        XCTAssertGreaterThan(retired20 - Self.standardDB(20), 1.0, "premise: … and 20 Hz ~1.1 dB hot")
    }

    /// 4 — the higher rates an interface can grant (88.2 / 96 / 176.4 / 192 kHz) stay within
    /// 0.05 dB of the standard from 20 Hz to 20 kHz, and every designed section is stable
    /// (poles inside the unit circle: |a2| < 1 and |a1| < 1 + a2) at every supported rate.
    func testHigherRatesMatchAndEverySectionIsStable() {
        for rate in Self.higherRates {
            for hz in Self.probeFrequencies {
                XCTAssertEqual(Self.derivedDB(hz, rate: rate), Self.standardDB(hz), accuracy: 0.05,
                               "\(rate) Hz at \(hz) Hz")
            }
        }
        let range = EchoelLoudnessMeter.supportedSampleRates
        XCTAssertEqual(range.lowerBound, 44_100, "the lowest supported rate moved — re-measure claim 2's premise")
        let rates: [Double] = [44_100, 48_000] + Self.higherRates
        for rate in rates {
            XCTAssertTrue(range.contains(Float(rate)), "\(rate) Hz must be supported")
            let k = EchoelLoudnessMeter.kWeighting(sampleRate: rate)
            for section in [k.shelf, k.highPass] {
                XCTAssertTrue(section.b0.isFinite && section.b1.isFinite && section.b2.isFinite)
                XCTAssertLessThan(abs(section.a2), 1, "\(rate) Hz: a pole left the unit circle")
                XCTAssertLessThan(abs(section.a1), 1 + section.a2, "\(rate) Hz: a pole left the unit circle")
            }
        }
    }

    // MARK: - the meter (END-TO-END)

    /// 5 (case C) — the SAME tone reads the same integrated loudness at 44.1 and 48 kHz
    /// (within one 0.1 LU bin; measured 0.00), bass included — and at the higher rates within one
    /// bin plus margin (a ≤ 0.04 dB response difference can cross exactly one bin boundary).
    func testTheSameToneReadsTheSameLoudnessAtEveryRate() {
        let cases: [(hz: Double, dBFS: Float)] = [(20, -10), (60, -20), (1_000, -23), (4_000, -23), (10_000, -23)]
        for c in cases {
            let at48 = Self.integrated(rate: 48_000, hz: c.hz, dBFS: c.dBFS)
            XCTAssertGreaterThan(at48, -70, "\(c.hz) Hz: no reading at 48 kHz")
            XCTAssertEqual(Self.integrated(rate: 44_100, hz: c.hz, dBFS: c.dBFS), at48, accuracy: 0.1,
                           "\(c.hz) Hz reads differently at 44.1 kHz")
            for rate in [88_200, 96_000, 192_000] {
                XCTAssertEqual(Self.integrated(rate: rate, hz: c.hz, dBFS: c.dBFS), at48, accuracy: 0.15,
                               "\(c.hz) Hz reads differently at \(rate) Hz")
            }
        }
        XCTAssertEqual(Self.integrated(rate: 44_100, hz: 1_000, dBFS: -23), -23, accuracy: 0.1,
                       "EBU TECH 3341 case 1 at 44.1 kHz")
    }

    /// 6 (case G) — `reset()` returns the meter to a fresh one at the same rate, bit for bit:
    /// no filter state, window or histogram survives into the next measurement.
    func testResetLeavesNothingBehind() {
        for rate in [44_100, 48_000] {
            let first = Self.tone(seconds: 2, dBFS: -12, rate: rate, hz: 1_000)
            let second = Self.tone(seconds: 3, dBFS: -30, rate: rate, hz: 60)
            let reused = EchoelLoudnessMeter(sampleRate: Float(rate))
            Self.feed(reused, first)
            reused.reset()
            XCTAssertEqual(reused.integratedLUFS, EchoelLoudnessMeter.floorLUFS)
            Self.feed(reused, second)
            let fresh = Self.feed(EchoelLoudnessMeter(sampleRate: Float(rate)), second)
            XCTAssertEqual(reused.integratedLUFS, fresh.integratedLUFS, "@\(rate)")
            XCTAssertEqual(reused.momentaryLUFS, fresh.momentaryLUFS, "@\(rate)")
            XCTAssertEqual(reused.shortTermLUFS, fresh.shortTermLUFS, "@\(rate)")
            XCTAssertEqual(reused.loudnessRange, fresh.loudnessRange, "@\(rate)")
        }
    }

    /// 7 — an unsupported rate DEGRADES EXPLICITLY: `supportsSampleRate` is false, nothing is
    /// measured, every reading stays at the floor, and no rate (0, negative, NaN, ∞) traps.
    /// The range's own ends are supported.
    func testAnUnsupportedRateMeasuresNothingInsteadOfBorrowingCoefficients() {
        let loud = Self.tone(seconds: 3, dBFS: -10, rate: 48_000, hz: 1_000)
        let unsupported: [Float] = [22_050, 32_000, 384_000, 0, -48_000, .nan, .infinity]
        for rate in unsupported {
            let meter = EchoelLoudnessMeter(sampleRate: rate)
            XCTAssertFalse(meter.supportsSampleRate, "\(rate) Hz must not be measured")
            XCTAssertGreaterThan(meter.gatingHopFrames, 0)
            Self.feed(meter, loud)
            XCTAssertEqual(meter.integratedLUFS, EchoelLoudnessMeter.floorLUFS, "\(rate) Hz produced a reading")
            XCTAssertEqual(meter.momentaryLUFS, EchoelLoudnessMeter.floorLUFS, "\(rate) Hz produced a reading")
        }
        for rate: Float in [44_100, 48_000, 192_000] {
            XCTAssertTrue(EchoelLoudnessMeter(sampleRate: rate).supportsSampleRate, "\(rate) Hz")
        }
        XCTAssertEqual(EchoelLoudnessMeter(sampleRate: 44_100).sampleRate, 44_100)
    }

    /// 8 — the export inherits that policy: a measurement at an unsupported rate is UNDEFINED,
    /// and undefined loudness asks for 0 dB (the E2 policy), never a gain from borrowed
    /// coefficients.
    func testAnUnsupportedExportRateAsksForNoGain() {
        let channel = Self.tone(seconds: 3, dBFS: -30, rate: 48_000, hz: 1_000)
        var interleaved = [Float](repeating: 0, count: 2 * channel.count)
        for i in channel.indices {
            interleaved[2 * i] = channel[i]
            interleaved[2 * i + 1] = channel[i]
        }
        let m = ExportLoudnessMeasurement(sampleRate: 22_050)
        interleaved.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            m.append(interleaved: base, sampleCount: buf.count)
        }
        XCTAssertNil(m.integratedLUFS())
        XCTAssertEqual(SingleExport.normalizeGainDB(target: -14, measuredDB: m.integratedLUFS()), 0)
    }

    // MARK: - wiring (SOURCE-TEXT SCAN)

    /// 9 — RATE-CHANGE LAW, meter side: the rate is fixed per instance (a `let`), the design
    /// runs exactly ONCE and only in `init` (never per sample), no hard-coded 48 kHz table is
    /// left to fall back on, and all three process paths refuse an unsupported rate.
    /// ⚠️ An explicit `reconfigure(sampleRate:)` that RESETS state would also satisfy the law —
    /// whoever adds one moves this claim with it (#364).
    func testTheRateIsFixedPerInstanceAndDesignedOnceInInit() throws {
        let code = SourceText.codeOnly(try Self.text(Self.meterPath))
        XCTAssertTrue(code.contains("public let sampleRate: Float"),
                      "the meter's rate became mutable — old filter state could meet new coefficients.")
        guard let initStart = code.range(of: "public init(sampleRate: Float = 48000) {"),
              let initEnd = code.range(of: "public var gatingHopFrames: Int", range: initStart.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING (#454): the meter's init or `gatingHopFrames` moved.")
        }
        XCTAssertEqual(Self.occurrences(of: "Self.kWeighting(", in: code), 1,
                       "the K-weighting design is called outside `init` — it must stay setup-time only.")
        XCTAssertTrue(code[initStart.upperBound..<initEnd.lowerBound].contains("Self.kWeighting(sampleRate: Double(rate))"),
                      "`init` no longer designs the filter for its own rate.")
        XCTAssertFalse(code.contains("1.53512485958697") || code.contains("1.99004745483398"),
                       "a hard-coded 48 kHz coefficient table is back in the meter's code.")
        XCTAssertEqual(Self.occurrences(of: "guard supportsSampleRate else { return }", in: code), 3,
                       "a process path measures at an unsupported rate. COUNT PIN — one per process "
                       + "entry point (mono, stereo array, stereo pointer); legal to move (#364).")
    }

    /// 10 — COUNTERWEIGHT, engine side: the live meter is REBUILT at the hardware rate on every
    /// tap install, after the old tap is removed — a new rate never meets old filter state.
    func testTheEngineRebuildsTheMeterAfterRemovingTheTap() throws {
        let code = SourceText.codeOnly(try Self.text(Self.enginePath))
        guard let install = code.range(of: "func installMeterTap("),
              let remove = code.range(of: "masterMixer.removeTap(onBus: 0)", range: install.upperBound..<code.endIndex),
              let rebuild = code.range(of: "loudnessMeter = EchoelLoudnessMeter(sampleRate: Float(meterFormat.sampleRate))",
                                       range: remove.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING (#454): `installMeterTap` no longer removes the tap and then "
                           + "rebuilds the meter at the hardware rate.")
        }
        let body = code[install.upperBound..<rebuild.lowerBound]
        XCTAssertFalse(body.contains("\nfunc ") || body.contains(" func "),
                       "the rebuild left `installMeterTap` — the removeTap-then-rebuild order is no longer one body.")
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

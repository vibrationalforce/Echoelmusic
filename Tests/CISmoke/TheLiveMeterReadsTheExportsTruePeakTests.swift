// TheLiveMeterReadsTheExportsTruePeakTests.swift
// LS-TP2 (2026-10-16): the Master readout's dBTP and the export's −1 dBTP bound are now ONE
// estimator, `EchoelTruePeak` (BS.1770-4 4×). Until this slice the meter interpolated with
// Catmull-Rom at t = ¼, ½, ¾ and read a quarter-rate tone 45° off at −1.07 dBTP for a unit
// crest — emulated against a 64× band-limited reference it read up to 2.2 dB under, so the
// readout promised headroom a DAC did not have, and it disagreed with the export (#416).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END over the public `EchoelMeter` and `EchoelTruePeak`.
//   · Claim 4 is a SOURCE-TEXT SCAN: the meter holds the shared estimator and no second
//     interpolation, and the master tap still feeds the meter's pointer path.
//   · NOT CLAIMED: that the readout looks right on the device (DEVICE PROBE), or anything
//     about the cost on the tap thread beyond "no allocation by construction" (read, not run).
//
// EXPECTED VALUES: float32 Python transcription of the meter + estimator, three runs with
// identical output (quarter tone: +0.083 dBTP on a fresh meter; the old Catmull-Rom −1.07).
//
// HONEST GRADING against the parent (§3): claim 1 is a REGRESSION — on the parent the meter
// reads the tone at −1.07 dBTP, under the claim's 0 floor. Claim 2 is a FORWARD guard (the
// planar estimator path is new; the file does not COMPILE on the parent for that reason, so no
// assertion has a verdict there — one absence, #486). Claim 3 is a COUNTERWEIGHT: the meter
// has always ignored a NaN sample, and it still must. Mutants: Catmull-Rom back (1, 4) · the
// planar path advancing the ring per channel instead of per frame (2) · `reported` dropped, so
// a NaN block poisons the hold (3).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLiveMeterReadsTheExportsTruePeakTests: XCTestCase {

    private static let crest: Float = 0.70710677

    private static func quarterTone(frames: Int) -> [Float] {
        let pattern: [Float] = [crest, crest, -crest, -crest]
        return (0..<frames).map { (n: Int) -> Float in pattern[n % 4] }
    }

    // MARK: 1 — the readout sees the crest the samples miss

    func testTheMeterReadsAQuarterRateToneAtItsCrest() {
        let m = EchoelMeter()
        m.process(Self.quarterTone(frames: 2_000), frameCount: 2_000)
        XCTAssertEqual(m.peakDb, -3.0103, accuracy: 0.01, "premise: the samples sit 3 dB under the crest")
        XCTAssertGreaterThanOrEqual(m.truePeakDb, 0,
                                    "the live dBTP reads under the crest — the retired Catmull-Rom read −1.07 here")
        XCTAssertLessThan(m.truePeakDb, 0.15)
    }

    // MARK: 2 — the meter and the export read the same number

    func testTheMeterAndTheExportAgreeBitForBit() {
        var left: [Float] = [], right: [Float] = [], interleaved: [Float] = []
        for n in 0..<1_024 {
            let l = 0.4 * sinf(Float(n) * 0.2)
            let r = 0.6 * sinf(Float(n) * 0.27 + 0.5)
            left.append(l); right.append(r)
            interleaved.append(l); interleaved.append(r)
        }
        let meter = EchoelMeter()
        meter.processStereo(left: left, right: right, frameCount: left.count)

        var export = EchoelTruePeak(channels: 2)
        interleaved.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            export.append(interleaved: base, sampleCount: buf.count)
        }
        XCTAssertEqual(meter.truePeakMaxDb, EchoelMeter.db(export.peak),
                       "the readout and the export bound measure the same stereo stream differently")

        var planar = EchoelTruePeak(channels: 2)
        left.withUnsafeBufferPointer { lb in
            right.withUnsafeBufferPointer { rb in
                guard let l = lb.baseAddress, let r = rb.baseAddress else { return }
                planar.append(left: l, right: r, frameCount: lb.count)
            }
        }
        XCTAssertEqual(planar.peak, export.peak, "planar and interleaved feeding disagree")
    }

    // MARK: 3 — counterweight: a NaN sample still cannot poison the readout

    func testANaNSampleLeavesTheReadoutFinite() {
        let m = EchoelMeter()
        m.process([0.1, .nan, 0.2, 0.1], frameCount: 4)
        XCTAssertTrue(m.truePeakDb.isFinite)
        XCTAssertEqual(m.truePeakDb, EchoelMeter.db(0.2), accuracy: 0.01)
        m.process([Float](repeating: 0.1, count: 64), frameCount: 64)
        XCTAssertTrue(m.truePeakDb.isFinite && m.truePeakMaxDb.isFinite)
    }

    // MARK: 4 — one estimator, and the master tap still feeds it

    func testTheMeterHoldsTheSharedEstimatorAndTheTapFeedsIt() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let meter = try code("Sources/Echoelmusic/DSP/EchoelMeter.swift")
        XCTAssertTrue(meter.contains("private var truePeakEstimator = EchoelTruePeak(channels: 2)"))
        XCTAssertFalse(meter.contains("func catmullRom("), "a second interpolation is back in the meter")
        let engine = try code("Sources/Echoelmusic/Audio/AudioEngine.swift")
        XCTAssertTrue(engine.contains("meter.processStereo(left: channelData[0], right: right, frameCount: n)"))
    }
}

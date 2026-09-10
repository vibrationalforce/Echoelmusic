// TheCameraRefusesToStateAnUntrustedHRVTests.swift
// Echoel — #1236 (audit 2026-09-10 `bio-pipeline-6`). The camera applies the strap's honesty
// gate (`RRIntervalHygiene.canStateHRV`) before it publishes any HRV field.
//
// THE DEFECT. The strap refused to state an RMSSD when fewer than 80 % of its raw RR intervals
// survived hygiene; the camera — the LOWER-trust source — published `analyzer.rmssd` ungated.
// `CameraAnalyzer.detectPeaks` bands each interval (0.3…1.5 s) and IQR-cleans the survivors, but a
// window whose beats alternate dropped/doubled passes the band beat by beat and fails only the
// successive-difference test. The strip clamps its DISPLAY to a plausible band, so the number was
// hidden on screen and still travelled to `/echoelmusic/bio/heart/rmssd` (gated on `> 0`) and
// into `hrvForSound`. Meanwhile the analyzer's `rawIntervalsMs` doc credited "consumers" with
// running hygiene — the one consumer was `AnalysisPoincareView`, doorless by founder decision.
//
// WHAT THIS PINS. (1) THE GATE, by text: the publisher computes `trustworthy` from
// `RRIntervalHygiene.canStateHRV(rrMs: self.analyzer.rawIntervalsMs)` — the RAW array, because a
// pre-filtered one would make the fraction unknowable. (2) ALL FOUR FIELDS, by text: RMSSD,
// normalized HRV, SDNN and pNN50 each fall to the sentinel 0 on `trustworthy ? … : 0`, so a frame
// cannot say "—" for one and a number for another. (3) THE DISCRIMINATION, by behaviour on the
// pure core: an alternating series every interval of which the analyzer's band accepts is
// refused by `canStateHRV`, and a regular series is accepted — the gap the gate closes.
// (4) PARITY, by text: the strap's gate is the same function on the same kind of array.
// (5) THE HEADER, by text: `rawIntervalsMs`'s doc names the one doorless reader and the gate.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`82cbbf6`) and this tree: claims 1, 2
// and 5 RED on the parent, GREEN here; claims 3 and 4 GREEN on both (the core and the strap did
// not change; they are the counterweights that say WHY the gate belongs on the camera too).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCameraRefusesToStateAnUntrustedHRVTests: XCTestCase {

    private static let gateLine = "let trustworthy = RRIntervalHygiene.canStateHRV(rrMs: self.analyzer.rawIntervalsMs)"

    /// Claim 1 — the gate reads the RAW series, not a pre-filtered one.
    func testTheGateReadsTheRawIntervals() throws {
        let src = try text("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift")
        XCTAssertTrue(src.contains(Self.gateLine),
                      "the camera no longer gates its HRV fields on `RRIntervalHygiene.canStateHRV` over `rawIntervalsMs` (#1236)")
        XCTAssertFalse(src.contains("canStateHRV(rrMs: self.analyzer.rrIntervals)"),
                       "the gate reads the twice-filtered `rrIntervals` — the fraction would read ~1.0 on a broken contact (#1236; see `rrWindowMs`'s ⛔ paragraph)")
    }

    /// Claim 2 — one boolean, four fields.
    func testAllFourHRVFieldsFallToTheSentinelTogether() throws {
        let src = try text("Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift")
        let gated = [
            "let rmssdMs = trustworthy ? Float(self.analyzer.rmssd) : 0",
            "let hrv = trustworthy ? Float(HRVNormalization.normalize(self.analyzer.rmssd)) : 0",
            "hrvSDNNms: trustworthy ? Float(HRVMetrics.sdnn(rrMs: rrMs)) : 0",
            "hrvPNN50: trustworthy ? Float(HRVMetrics.pnn50(segments: self.analyzer.rrSegments)) : 0",
        ]
        for line in gated {
            XCTAssertTrue(src.contains(line),
                          "`\(line)` is gone — an HRV field leaves the camera ungated while its siblings read \"—\" (#1236)")
        }
    }

    /// Claim 3 — the gap the gate closes: the band accepts every beat, hygiene refuses the series.
    func testHygieneRefusesWhatTheBandAccepts() {
        // Alternating 600/900 ms: every interval inside the analyzer's 300…1500 ms band, every
        // successive step 50 % (Malik threshold 20 %). The strap would say "—"; the camera did not.
        let alternating: [Double] = (0..<20).map { $0 % 2 == 0 ? 600 : 900 }
        XCTAssertTrue(alternating.allSatisfy { $0 > 300 && $0 < 1500 },
                      "the fixture stopped being band-passing — the claim would then test the band, not the gate (#1236)")
        XCTAssertFalse(RRIntervalHygiene.canStateHRV(rrMs: alternating),
                       "an alternating dropped/doubled series is stated as HRV — the gate no longer discriminates the case it exists for (#1236)")
        let regular: [Double] = (0..<20).map { 1000 + Double($0 % 3) * 20 }
        XCTAssertTrue(RRIntervalHygiene.canStateHRV(rrMs: regular),
                      "a regular series is refused — the gate would silence a good contact (#1236)")
    }

    /// Claim 4 — parity: the strap's gate is the same function.
    func testTheStrapUsesTheSameGate() throws {
        let strap = try text("Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift")
        XCTAssertTrue(strap.contains("let trustworthy = RRIntervalHygiene.canStateHRV(rrMs: rawMs)"),
                      "the strap's gate moved or changed — re-read #1236's parity argument before touching the camera's (#1236)")
    }

    /// Claim 5 — the header no longer credits a consumer that does not exist on a reachable path.
    func testTheAnalyzerHeaderNamesTheDoorlessReaderAndTheGate() throws {
        let analyzer = try text("Sources/Echoelmusic/Video/CameraAnalyzer.swift")
        XCTAssertTrue(analyzer.contains("\"CONSUMERS\" WAS ONE, AND IT IS DOORLESS (#1236"),
                      "`rawIntervalsMs`'s doc again says consumers run hygiene without naming that the one reader is doorless (#1236)")
        XCTAssertTrue(analyzer.contains("reads this array itself for `RRIntervalHygiene.canStateHRV`"),
                      "the header does not name the publisher's own gate as the reachable reader (#1236)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

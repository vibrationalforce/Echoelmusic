// TheSlicerCutsWhereTheHitsAreTests.swift
// Echoel — GMMW GA-6 ("Onset slicer, pure"). `SampleSlicer.slicePoints(samples:sampleRate:)` turns a
// sample into the frames where its hits start, from the tempo detector's own onset envelope
// (`TempoOnsetEnvelope`, #416) — the step every sampler workstation offers before a loop can be
// played hit by hit. No caller yet: where slice points are kept and what a slice plays is GA-7, a
// founder gate (`docs/dev/FEATURE_STATUS.md` §2c registers the core).
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END: clicks at known frames are cut exactly there; a click at frame 0 does not add a
//    second start; decaying noise bursts are cut within 1 ms of where they begin.
// 2. END-TO-END COUNTERWEIGHTS (#343): silence and an empty sample are ONE slice; a steady tone is
//    never cut (its onset strength stays far under the floor — measured 0.002…0.075 against 0.5 for
//    55 Hz…3 kHz); a tone entering after silence is cut once, within 1 ms of its entry.
// 3. END-TO-END: non-finite samples count as silence; a non-finite, non-positive or absurd rate is
//    nil (an absurd one would overflow a hop or a gap in frames — refused, never trapped).
// 4. END-TO-END: the count is bounded (`maxSlices`, the strongest — on a tie, the earliest — win),
//    the points are sorted and unique, and two hits 5 ms apart are one cut.
// 5. SOURCE: the slicer reads onsets through `TempoOnsetEnvelope` and computes no energy or log of
//    its own (one onset rule), and imports Foundation only.
//
// Grading (§0, no Swift toolchain): the file does NOT compile on its parent (`6ac95c9`) — it names
// `SampleSlicer`, created by this commit — so no assertion has a verdict there (ONE absence, #486);
// claims 1–4 are FORWARD guards. They were transcribed into Python (a line-by-line port of
// `TempoOnsetEnvelope` and the slicer, Float rounding kept where Swift rounds) and every expectation
// below was driven through it: all green. Claim 5 was grepped against the worktree.
// NOT covered: how the cuts fall on real loops and phrases — the floors are chosen on synthetic
// material. NEEDS-FOUNDER-VERIFY once GA-7 gives the slicer a caller.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSlicerCutsWhereTheHitsAreTests: XCTestCase {

    private static let rate: Double = 48_000
    /// 1 ms — how far a cut may sit from where a non-click hit begins.
    private static let tolerance = 48

    // MARK: 1 — the cuts sit at the hits

    func testClicksAreCutExactlyWhereTheyAre() throws {
        var samples = [Float](repeating: 0, count: 96_000)
        let clicks: [Int] = [12_000, 36_000, 62_400]
        for frame in clicks { samples[frame] = 1 }
        XCTAssertEqual(SampleSlicer.slicePoints(samples: samples, sampleRate: Self.rate), [0] + clicks)

        var startsLoud = [Float](repeating: 0, count: 48_000)
        startsLoud[0] = 1
        startsLoud[24_000] = 1
        XCTAssertEqual(SampleSlicer.slicePoints(samples: startsLoud, sampleRate: Self.rate), [0, 24_000],
                       "a hit on the first frame is the start slice, not a second one")
    }

    func testDecayingBurstsAreCutWhereTheyBegin() throws {
        var samples = [Float](repeating: 0, count: 96_000)
        let bursts: [Int] = [9_000, 30_000, 55_555, 80_000]
        var state: UInt64 = 12_345
        for start in bursts {
            for k in 0..<2_400 {
                state = (state &* 1_103_515_245 &+ 12_345) % (1 << 31)
                let noise = Double(state) / Double(1 << 31) * 2 - 1
                samples[start + k] = Float(noise * Foundation.exp(-Double(k) / 600))
            }
        }
        let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: samples, sampleRate: Self.rate))
        XCTAssertEqual(points.count, bursts.count + 1, "one cut per burst, plus the start: \(points)")
        XCTAssertEqual(points.first, 0)
        for (cut, start) in zip(points.dropFirst(), bursts) {
            XCTAssertLessThanOrEqual(abs(cut - start), Self.tolerance, "a burst at \(start) was cut at \(cut)")
        }
    }

    // MARK: 2 — counterweights: nothing to cut is one slice

    func testSilenceAndSteadyMaterialAreOneSlice() throws {
        XCTAssertEqual(SampleSlicer.slicePoints(samples: [Float](repeating: 0, count: 48_000), sampleRate: Self.rate), [0])
        XCTAssertEqual(SampleSlicer.slicePoints(samples: [], sampleRate: Self.rate), [0])
        let tone: [Float] = (0..<96_000).map { i in
            Float(0.5 * Foundation.sin(2 * Double.pi * 220 * Double(i) / Self.rate))
        }
        XCTAssertEqual(SampleSlicer.slicePoints(samples: tone, sampleRate: Self.rate), [0],
                       "a steady tone has no hit after its first frame")

        let entering = [Float](repeating: 0, count: 48_000) + tone.prefix(48_000)
        let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: entering, sampleRate: Self.rate))
        XCTAssertEqual(points.count, 2, "a tone entering after silence is ONE cut: \(points)")
        XCTAssertLessThanOrEqual(abs((points.last ?? 0) - 48_000), Self.tolerance)
    }

    // MARK: 3 — non-finite input

    func testNonFiniteSamplesAreSilenceAndABadRateIsNil() {
        var samples = [Float](repeating: 0, count: 48_000)
        samples[24_000] = 1
        for frame in [5_000, 5_001, 9_000, 30_000, 40_000] { samples[frame] = .nan }
        samples[7_000] = .infinity
        samples[8_000] = -.infinity
        XCTAssertEqual(SampleSlicer.slicePoints(samples: samples, sampleRate: Self.rate), [0, 24_000],
                       "NaN and infinity are not hits")
        let badRates: [Double] = [0, -1, .nan, .infinity, 1e12]
        for bad in badRates {
            XCTAssertNil(SampleSlicer.slicePoints(samples: [0], sampleRate: bad), "rate \(bad)")
        }
    }

    // MARK: 4 — bounded, ordered, one cut per hit

    func testTheCountIsBoundedAndCloseHitsAreOneCut() throws {
        let length = Int(4 * Self.rate)
        var dense = [Float](repeating: 0, count: length)
        for frame in stride(from: 100, to: length, by: 2_880) { dense[frame] = 1 }   // every 60 ms
        let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: dense, sampleRate: Self.rate))
        XCTAssertEqual(points.count, SampleSlicer.maxSlices, "more hits than slices: the strongest win, bounded")
        XCTAssertEqual(points, Array(Set(points)).sorted(), "sorted and unique")
        XCTAssertEqual(points.first, 0)
        XCTAssertLessThan(points.last ?? length, length)

        var flam = [Float](repeating: 0, count: 48_000)
        flam[24_000] = 1
        flam[24_240] = 1   // 5 ms later
        XCTAssertEqual(SampleSlicer.slicePoints(samples: flam, sampleRate: Self.rate), [0, 24_000],
                       "two hits closer than the minimum gap are one cut")
    }

    // MARK: 5 — one onset rule

    func testTheSlicerAsksTheTempoDetectorsOnsetRule() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let file = root.appendingPathComponent("Sources/Echoelmusic/Sequencer/SampleSlicer.swift")
        let code = SourceText.codeOnly(try String(contentsOf: file, encoding: .utf8))
        XCTAssertTrue(code.contains("TempoOnsetEnvelope(sampleRate: sampleRate, maxSeconds: maxSeconds)"),
                      "the slicer's onsets are the tempo detector's (#416)")
        for second in ["log10", "energyFloor", "closeHop"] {
            XCTAssertFalse(code.contains(second), "`\(second)` in the slicer — a second onset rule")
        }
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }.map(String.init)
        XCTAssertEqual(imports, ["import Foundation"], "pure value math")
    }
}

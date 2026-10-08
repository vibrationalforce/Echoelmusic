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
// 6–9. END-TO-END, the GA-6 review (dsp-reviewer, every input below is one it reported failing):
//    6. close hits are decided strongest-first over FRAMES, not greedily among peaks — a rising
//       roll 0.3 / 0.6 / 1.0 at 45 ms keeps its first and last hit; at 44.1 kHz two hits 52 ms apart
//       are two cuts; COUNTERWEIGHTS: of two equal hits 30 ms apart the earlier is the cut, of two
//       unequal ones the stronger.
//    7. five ms of digital silence before a loop does not lift the floor over its hits — a chord
//       pad with four soft noise hits is cut at all four, with and without the lead-in.
//    8. the attack is read in the rise, not the level — a click over a DC offset is cut exactly
//       there, and a snare 51 ms after a kick's body is its own cut.
//    9. a tonal attack (100 Hz, 10 ms ramp) is cut within 2 ms of where it starts, not a cycle late.
//
// Grading (§0, no Swift toolchain): the file does NOT compile on its parent (`6ac95c9`) — it names
// `SampleSlicer`, created by this commit — so no assertion has a verdict there (ONE absence, #486);
// claims 1–4 are FORWARD guards. They were transcribed into Python (a line-by-line port of
// `TempoOnsetEnvelope` and the slicer, Float rounding kept where Swift rounds) and every expectation
// below was driven through it: all green. Claim 5 was grepped against the worktree.
// The review fix, graded against ITS parent (`367c8c5`): the file compiles there. REGRESSIONS, red
// there for their named reason: claim 6's roll ([0, 14320]) and 44.1 kHz pair ([0, 11000]); claim 7
// with the lead-in ([0]) and without it (cuts 240 / 182 / … frames early); claim 8's DC click
// (23760) and kick + snare ([0, 24011]); claim 9 (252 frames late). COUNTERWEIGHTS, green on both:
// claim 6's tie and strength pair, claims 1–5. MUTATIONS driven in the port, each caught by the
// claim that names it: no minimum gap (6, 7), no cap (7), no step-back (9), the level instead of
// the rise (7, 8, 9), the greedy peak gap (6, 7). NOT caught by any claim, said rather than hidden:
// narrowing the window to the hit's own hop changes no verdict here (it moves a hit that starts
// late in a hop 10 frames later), and `relativeFloor` is not pinned on its own.
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

    // MARK: 6 — close hits: strongest first, over frames

    func testCloseHitsAreDecidedStrongestFirst() {
        var roll = [Float](repeating: 0, count: 48_000)
        roll[10_000] = 0.3
        roll[12_160] = 0.6
        roll[14_320] = 1
        XCTAssertEqual(SampleSlicer.slicePoints(samples: roll, sampleRate: Self.rate), [0, 10_000, 14_320],
                       "a rising roll keeps every hit that is a minimum gap from a stronger one")

        var pair = [Float](repeating: 0, count: 44_100)
        pair[11_000] = 1
        pair[13_300] = 1   // 52 ms at 44.1 kHz
        XCTAssertEqual(SampleSlicer.slicePoints(samples: pair, sampleRate: 44_100), [0, 11_000, 13_300],
                       "the minimum gap is 50 ms in frames, not a whole number of hops")

        var tie = [Float](repeating: 0, count: 48_000)
        tie[24_000] = 1
        tie[25_440] = 1    // 30 ms
        XCTAssertEqual(SampleSlicer.slicePoints(samples: tie, sampleRate: Self.rate), [0, 24_000],
                       "COUNTERWEIGHT: two equal hits closer than the gap — the earlier is the cut")
        tie[24_000] = 0.5
        XCTAssertEqual(SampleSlicer.slicePoints(samples: tie, sampleRate: Self.rate), [0, 25_440],
                       "COUNTERWEIGHT: two unequal ones — the stronger is the cut")
    }

    // MARK: 7 — a lead-in of silence does not lift the floor

    func testALeadInOfSilenceDoesNotHideTheHits() throws {
        for lead in [0, 240] {
            let (samples, hits) = Self.padWithSoftHits(lead: lead)
            let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: samples, sampleRate: Self.rate))
            XCTAssertEqual(points.count, hits.count + 1, "lead-in \(lead): one cut per hit — \(points)")
            for (cut, hit) in zip(points.dropFirst(), hits) {
                XCTAssertLessThanOrEqual(abs(cut - hit), Self.tolerance, "lead-in \(lead): a hit at \(hit) was cut at \(cut)")
            }
        }
    }

    // MARK: 8 — the attack is read in the rise, not the level

    func testTheAttackIsFoundOverMaterialThatHoldsALevel() throws {
        var offset = [Float](repeating: 0.3, count: 48_000)
        offset[24_100] = 1
        XCTAssertEqual(SampleSlicer.slicePoints(samples: offset, sampleRate: Self.rate), [0, 24_100],
                       "a DC offset is a level, not an attack")

        var kit = [Double](repeating: 0, count: 72_000)
        for k in 0..<48_000 {
            let body: Double = 0.9 * Foundation.exp(-Double(k) / 9_600)
            kit[24_000 + k] += body * Foundation.sin(2 * Double.pi * 70 * Double(k) / Self.rate)
        }
        let snare = 26_450   // 51 ms after the kick
        var noise = LCG(seed: 4_242)
        for k in 0..<4_800 { kit[snare + k] += 0.6 * noise.next() * Foundation.exp(-Double(k) / 1_200) }
        let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: kit.map { Float($0) }, sampleRate: Self.rate))
        XCTAssertEqual(points.count, 3, "the kick and the snare are two cuts: \(points)")
        if points.count == 3 {
            XCTAssertLessThanOrEqual(abs(points[1] - 24_000), Self.tolerance, "the kick at \(points[1])")
            XCTAssertLessThanOrEqual(abs(points[2] - snare), Self.tolerance, "the snare at \(points[2])")
        }
    }

    // MARK: 9 — a tonal attack is cut where it starts

    func testATonalAttackIsCutWhereItStarts() throws {
        var samples = [Float](repeating: 0, count: 72_000)
        let ramp = 480   // 10 ms
        for k in 0..<30_000 {
            let attack: Double = Swift.min(1, Double(k) / Double(ramp))
            let envelope: Double = attack * Foundation.exp(-Double(Swift.max(0, k - ramp)) / 9_600)
            samples[24_000 + k] = Float(0.9 * envelope * Foundation.sin(2 * Double.pi * 100 * Double(k) / Self.rate))
        }
        let points = try XCTUnwrap(SampleSlicer.slicePoints(samples: samples, sampleRate: Self.rate))
        XCTAssertEqual(points.count, 2, "\(points)")
        let late = (points.last ?? 0) - 24_000
        XCTAssertTrue((0...96).contains(late), "a 100 Hz attack was cut \(late) frames after it starts — not within 2 ms")
    }

    // MARK: - fixtures

    /// The tests' noise: the same 31-bit LCG as claim 1's bursts, seeded per fixture.
    private struct LCG {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state = (state &* 1_103_515_245 &+ 12_345) % (1 << 31)
            return Double(state) / Double(1 << 31) * 2 - 1
        }
    }

    /// A three-note pad (220 · 277.2 · 329.6 Hz) for two seconds after `lead` zero frames, with a
    /// soft decaying noise hit (peak 0.2, 25 ms) every half second from 0.25 s in.
    private static func padWithSoftHits(lead: Int) -> (samples: [Float], hits: [Int]) {
        var mix = [Double](repeating: 0, count: lead + 96_000)
        for i in 0..<96_000 {
            let t: Double = Double(i) / rate
            let root: Double = Foundation.sin(2 * Double.pi * 220 * t)
            let third: Double = 0.6 * Foundation.sin(2 * Double.pi * 277.2 * t)
            let fifth: Double = 0.5 * Foundation.sin(2 * Double.pi * 329.6 * t)
            mix[lead + i] = 0.25 * (root + third + fifth)
        }
        let hits: [Int] = (0..<4).map { lead + 12_000 + 24_000 * $0 }
        var noise = LCG(seed: 777)
        for hit in hits {
            for k in 0..<4_800 { mix[hit + k] += 0.2 * noise.next() * Foundation.exp(-Double(k) / 1_200) }
        }
        return (mix.map { Float($0) }, hits)
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

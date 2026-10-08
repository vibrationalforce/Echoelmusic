// TheVideoMotionDoesNotDependOnLengthTests.swift
// Echoel — GMMW VV-1a ("motion is measured where it is linear"). `VideoSeedAnalysis.analyze` read the
// motion of a clip as the mean picture change per second over EVERY pair of neighbouring samples.
// Change saturates once two frames are seconds apart, so the same moving footage read 0.39 as a 6 s
// clip and 0.24 as a 600 s one — the 48 samples of a long clip sit 12.5 s apart. Motion is now the
// mean over CLOSE pairs only, and the close and the far pairs are each judged against their own
// usual change when cuts are looked for.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — all END-TO-END on synthetic frame summaries (the
// shipped, public, Foundation-only `VideoSeedAnalysis`; no decoder, no file):
// 1. The same footage — a pattern drifting sideways at 0.05 cycles/s, read as 24 pairs of frames
//    0.1 s apart — reads the same motion at 6 s, 60 s and 600 s, each within 5 % of the value the
//    algebra gives (below) and the long reading within 5 % of the short one.
// 2. Paired moving footage has NO cut. The far pairs of a long clip all changed a lot; judged
//    against one median with the close pairs, every one of them stood out (23 false cuts).
// 3. A cut in a STILL scene that falls between two pairs is still found, and is not motion.
// 4. COUNTERWEIGHTS (#343): a clip read at an even 0.25 s keeps its exact motion (every pair is
//    close — today's readings), and a clip with no close pair at all falls back to every pair,
//    exactly as before, rather than reading zero.
// 5. END-TO-END over the READER'S GRID (VV-1b): the times `VideoSeedReader.sampleTimes` asks for,
//    fed with the same drifting pattern, read the same motion at 6 s and 600 s; a long clip is 24
//    close pairs, ascending, inside the clip, within the 48-frame budget. COUNTERWEIGHTS: a short
//    clip keeps the even grid bit for bit, and a 2 fps clip is read evenly (its pairs could not be
//    close, and mixed with the gaps between them every pair read as a cut — 23 in the port).
//
// THE ALGEBRA (#442). A pixel of the pattern is 128 + 100·sin θ, and the pattern moves by
// δ = 2π · speed · dt between two frames. For a small δ the change is 100 · |cos θ| · δ, and the
// mean of |cos θ| over a period is 2/π — so the mean change is 400 · speed · dt luma steps, i.e.
// 400 · speed / 255 of the luma range per second. Over `fullScaleChangePerSecond` that is the
// expected motion. Rounding each pixel to a byte moves it a little; measured 0.06 % at 6 s and
// 2.3 % at 60 s and 600 s.
//
// Grading (§3, no Swift toolchain): the file compiles on its parent (`54398be`) — it names only
// symbols that exist there. Transcribed into Python (luma rounding as Swift's `.rounded()`, the
// pair split and the group medians as written) and driven on both rules:
// · REGRESSIONS, red on the parent for their named reason: claim 1 at 600 s (0.239, 39 % off the
//   algebra; the long/short ratio 0.61), claim 2 at 60 s and 600 s (23 false cuts each), claim 3's
//   motion (0.0015 — the cut leaked into the motion).
// · COUNTERWEIGHTS, green on both: claim 1 at 6 s and 60 s, claim 2 at 6 s, claim 3's cut
//   (312.5 s on both rules), all of claim 4.
// Claim 5 (VV-1b) names `VideoSeedReader.sampleTimes`, created by its commit, so from then on the
// file does not compile on that commit's parent (`06ee283`) — claims 1–4 were graded at `c1bc3dd`
// above; claim 5 is a FORWARD guard, transcribed (the grid and the analysis) and driven: 0.392 at
// 6 s, 0.401 at 600 s, no cut; the even reading at 600 s that it replaces read 0.239.
// NOT covered: decoding — that the generator returns the frame each time asks for is pinned by
// `AVideoShapesTheVisualFromBoundedFramesTests` (zero tolerance), not here.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheVideoMotionDoesNotDependOnLengthTests: XCTestCase {

    private static let side = VideoSeedAnalysis.gridSide
    /// Cycles per second the pattern drifts — slow enough that 0.1 s apart is linear.
    private static let speed = 0.05
    /// The motion the algebra in the header gives for that drift.
    private static let algebraic = 400 * speed / 255 / VideoSeedAnalysis.fullScaleChangePerSecond

    /// A 16 × 16 luma pattern drifting sideways at `speed` cycles per second.
    private static func movingLuma(at time: Double) -> [UInt8] {
        var luma: [UInt8] = []
        luma.reserveCapacity(side * side)
        for y in 0..<side {
            for x in 0..<side {
                let phase = 2 * Double.pi * (Double(x) / Double(side) + speed * time) + Double(y) * 0.3
                let value: Double = (128 + 100 * Foundation.sin(phase)).rounded()
                luma.append(UInt8(Swift.min(255, Swift.max(0, value))))
            }
        }
        return luma
    }

    private static func sample(_ time: Double, _ luma: [UInt8]) -> VideoFrameSample {
        VideoFrameSample(time: time, luma: luma, meanRed: 0.3, meanGreen: 0.3, meanBlue: 0.3)
    }

    /// What a reader that samples close pairs hands over: `pairs` pairs spread evenly over
    /// `duration`, the two frames of a pair 0.1 s apart.
    private static func paired(duration: Double, pairs: Int = 24,
                               luma: (Double) -> [UInt8]) -> [VideoFrameSample] {
        var samples: [VideoFrameSample] = []
        for i in 0..<pairs {
            let first = duration * (Double(i) + 0.5) / Double(pairs)
            let second = Swift.min(first + 0.1, duration)
            samples.append(sample(first, luma(first)))
            samples.append(sample(second, luma(second)))
        }
        return samples
    }

    private func seed(_ samples: [VideoFrameSample], duration: Double) throws -> VideoSeed {
        try XCTUnwrap(VideoSeedAnalysis.analyze(samples: samples, durationSeconds: duration, frameRate: 30),
                      "a valid reading of \(duration) s")
    }

    // MARK: 1 — the same footage reads the same motion at any length

    func testTheSameFootageReadsTheSameMotionAtAnyLength() throws {
        var motions: [Double] = []
        for duration: Double in [6, 60, 600] {
            let motion = try seed(Self.paired(duration: duration, luma: Self.movingLuma), duration: duration).motionEnergy
            XCTAssertEqual(motion, Self.algebraic, accuracy: Self.algebraic * 0.05,
                           "\(duration) s: \(motion), the algebra says \(Self.algebraic)")
            motions.append(motion)
        }
        let short = try XCTUnwrap(motions.first)
        let long = try XCTUnwrap(motions.last)
        XCTAssertEqual(long / short, 1, accuracy: 0.05,
                       "600 s read \(long), 6 s read \(short) — the length must not be the motion")
    }

    // MARK: 2 — far pairs of moving footage are not cuts

    func testPairedMovingFootageHasNoFalseCut() throws {
        for duration: Double in [6, 60, 600] {
            let cuts = try seed(Self.paired(duration: duration, luma: Self.movingLuma), duration: duration).transientTimes
            XCTAssertEqual(cuts, [], "\(duration) s of one moving shot: \(cuts.count) cuts")
        }
    }

    // MARK: 3 — a cut between two pairs is found, and is not motion

    func testAStillSceneCutIsFoundAndIsNotMotion() throws {
        let still: (Double) -> [UInt8] = { time in
            [UInt8](repeating: time < 300 ? 128 : 40, count: Self.side * Self.side)
        }
        let reading = try seed(Self.paired(duration: 600, luma: still), duration: 600)
        XCTAssertEqual(reading.transientTimes, [312.5], "the first frame after the cut, between pairs 12 and 13")
        XCTAssertEqual(reading.motionEnergy, 0, "nothing moved — a cut is a transient, not motion")
    }

    // MARK: 5 — VV-1b: the reader's own grid

    #if canImport(AVFoundation) && canImport(CoreGraphics)
    func testTheReadersGridReadsTheSameMotionAtAnyLength() throws {
        var motions: [Double] = []
        for duration: Double in [6, 600] {
            let times = VideoSeedReader.sampleTimes(seconds: duration, frameRate: 30)
            XCTAssertLessThanOrEqual(times.count, VideoSeedReader.sampleCount, "the frame budget is unchanged")
            XCTAssertTrue(zip(times, times.dropFirst()).allSatisfy { $0 < $1 }, "ascending")
            XCTAssertTrue((times.first ?? 0) > 0 && (times.last ?? .infinity) <= duration, "inside the clip")
            let reading = try seed(times.map { Self.sample($0, Self.movingLuma(at: $0)) }, duration: duration)
            XCTAssertEqual(reading.motionEnergy, Self.algebraic, accuracy: Self.algebraic * 0.05,
                           "\(duration) s through the reader's grid")
            XCTAssertEqual(reading.transientTimes, [], "one moving shot, no cut")
            motions.append(reading.motionEnergy)
        }
        let short = try XCTUnwrap(motions.first)
        let long = try XCTUnwrap(motions.last)
        XCTAssertEqual(long / short, 1, accuracy: 0.05, "the reader no longer turns length into motion")

        let paired = VideoSeedReader.sampleTimes(seconds: 600, frameRate: 30)
        XCTAssertEqual(paired.count, VideoSeedReader.sampleCount)
        for first in stride(from: 0, to: paired.count - 1, by: 2) {
            XCTAssertLessThanOrEqual(paired[first + 1] - paired[first], VideoSeedAnalysis.motionPairMaxSeconds,
                                     "pair \(first / 2) is close")
        }

        let evenShort: [Double] = (0..<32).map { 8 * (Double($0) + 0.5) / 32 }
        XCTAssertEqual(VideoSeedReader.sampleTimes(seconds: 8, frameRate: 30), evenShort,
                       "COUNTERWEIGHT: a short clip is read on the grid it always had")
        let evenSlow: [Double] = (0..<48).map { 600 * (Double($0) + 0.5) / 48 }
        XCTAssertEqual(VideoSeedReader.sampleTimes(seconds: 600, frameRate: 2), evenSlow,
                       "COUNTERWEIGHT: at 2 fps no pair can be close, so the clip is read evenly")
    }
    #endif

    // MARK: 4 — counterweights: today's readings keep their numbers

    func testEvenReadingsKeepTheirMotion() throws {
        let step: Double = 10 / 255
        let dense = (0..<24).map { i in Self.sample(0.25 * Double(i), [UInt8](repeating: UInt8(10 * i), count: Self.side * Self.side)) }
        XCTAssertEqual(try seed(dense, duration: 6).motionEnergy,
                       step / 0.25 / VideoSeedAnalysis.fullScaleChangePerSecond, accuracy: 1e-9,
                       "every pair close: the rate over every pair, as before")

        let sparse = (0..<24).map { i in
            Self.sample(600 * (Double(i) + 0.5) / 48, [UInt8](repeating: UInt8(10 * i), count: Self.side * Self.side))
        }
        XCTAssertEqual(try seed(sparse, duration: 600).motionEnergy,
                       step / 12.5 / VideoSeedAnalysis.fullScaleChangePerSecond, accuracy: 1e-9,
                       "no close pair: the fallback is every pair, not zero")
    }
}

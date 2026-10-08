// AVideoIsMeasuredNotGuessedTests.swift
// MV1 (founder order 2026-09-27): the pure core that turns a bounded set of sampled video frames
// into a `VideoSeed` — brightness, colour, motion energy, simple picture transients — and the
// quantisation of a clip's length to whole bars.
//
// WHAT KIND OF GREEN THIS IS (§1): END-TO-END on a shipped, Foundation-only function
// (`VideoSeedAnalysis.analyze`) with synthetic frame summaries. No video file, no AVFoundation.
// The expectations come from the SHAPE of the input, not from the implementation's numbers:
// a still clip has no motion and no transient, a single hard cut is exactly one transient at the
// cut, a slow fade is change without a transient.
// DEVICE PROBE, open: that a real clip read by AVFoundation gives numbers a person would agree
// with.
//
// HONEST GRADING against the parent (68f9d9a01, §3): the file does not COMPILE there — every
// claim names `VideoSeedAnalysis`, which this commit creates — so no assertion has a verdict on
// the parent. All claims are FORWARD guards (one absence, #486). Hand-transcribed in Python;
// mutants driven, each red for its named reason: the spacing rule removed (claim 3), the
// transient floor removed (claim 2, the flicker), the backwards-time check removed (claim 5), the
// plausibility order check removed (claim 6), `bars` allowed to reach 0 (claim 7).
// ⚠️ Claim 3's motion line FLIPPED with the review of VV-4 (2026-10-08): it asserted that the hard
// cut reads as motion > 0, which was the defect — every pair of that clip is close (0.25 s), the cut
// pair was the only change, and it read 1.0 motion. A pair the transient rule flags is now left out
// of the motion mean, so the clip reads 0; on the parent the new line is red (1.0), the old one
// would be red here. The fade beside it keeps motion > 0 on both (nothing in it stands out).

import Foundation
import XCTest
@testable import Echoelmusic

final class AVideoIsMeasuredNotGuessedTests: XCTestCase {

    private static let cells = VideoSeedAnalysis.gridSide * VideoSeedAnalysis.gridSide

    private func frame(_ time: Double, _ value: UInt8) -> VideoFrameSample {
        let level = Double(value) / 255
        return VideoFrameSample(time: time, luma: [UInt8](repeating: value, count: Self.cells),
                                meanRed: level, meanGreen: level, meanBlue: level)
    }

    /// `count` samples every `step` seconds, the luma given by `value(i)`.
    private func clip(_ count: Int, step: Double = 0.25, _ value: (Int) -> UInt8) -> [VideoFrameSample] {
        (0..<count).map { frame(Double($0) * step, value($0)) }
    }

    // MARK: 1 — determinism

    func testTheSameFramesGiveTheSameSeed() throws {
        var state: UInt32 = 3
        let frames: [VideoFrameSample] = (0..<40).map { i in
            let luma: [UInt8] = (0..<Self.cells).map { _ in
                state = state &* 1_664_525 &+ 1_013_904_223
                return UInt8(truncatingIfNeeded: state >> 24)
            }
            return VideoFrameSample(time: Double(i) * 0.25, luma: luma, meanRed: 0.2, meanGreen: 0.5, meanBlue: 0.7)
        }
        let a = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: frames, durationSeconds: 10, frameRate: 30))
        let b = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: frames, durationSeconds: 10, frameRate: 30))
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.isPlausible, "whatever the frames, the analysis produces a seed its own check accepts")
        XCTAssertTrue(a.motionEnergy >= 0 && a.motionEnergy <= 1)
    }

    // MARK: 2 — a still clip moves nothing

    func testAStillClipHasNoMotionAndNoTransient() throws {
        let seed = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: clip(20) { _ in 128 },
                                                           durationSeconds: 5, frameRate: 25))
        XCTAssertEqual(seed.motionEnergy, 0)
        XCTAssertEqual(seed.transientTimes, [])
        XCTAssertEqual(seed.brightness, 128.0 / 255.0, accuracy: 1e-9)
        XCTAssertFalse(seed.hasDominantColour, "grey frames have no colour")
        XCTAssertEqual(seed.sampledFrames, 20)
        // A still clip with a flicker of two luma levels in one frame: a change, never a transient.
        let flicker = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: clip(20) { $0 == 10 ? 130 : 128 },
                                                              durationSeconds: 5, frameRate: 25))
        XCTAssertEqual(flicker.transientTimes, [], "sensor noise over a still picture is not a cut")
    }

    // MARK: 3 — a cut is a transient; a fade is not; two cuts too close are one

    func testOneHardCutIsOneTransientAtTheCut() throws {
        let seed = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: clip(20) { $0 < 8 ? 0 : 255 },
                                                           durationSeconds: 5, frameRate: 30))
        XCTAssertEqual(seed.transientTimes, [2.0], "the cut lands on the first white sample, 8 × 0.25 s")
        XCTAssertEqual(seed.motionEnergy, 0, """
            a cut between two still pictures is a transient, not motion (review of VV-4 — this line \
            asserted motion > 0 until then; `TheVideoMotionDoesNotDependOnLengthTests` claim 6 owns why)
            """)
    }

    func testASlowFadeIsChangeWithoutATransient() throws {
        let seed = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: clip(40) { UInt8($0 * 5) },
                                                           durationSeconds: 10, frameRate: 30))
        XCTAssertEqual(seed.transientTimes, [], "an even change never stands out from itself")
        XCTAssertGreaterThan(seed.motionEnergy, 0, "but the picture did change")
    }

    func testTwoCutsCloserThanTheSpacingCountOnce() throws {
        // Samples every 0.1 s; black → white at 1.0 s, white → black at 1.1 s.
        let frames = clip(30, step: 0.1) { ($0 == 10) ? 255 : 0 }
        let seed = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: frames, durationSeconds: 3, frameRate: 30))
        XCTAssertLessThan(0.1, VideoSeedAnalysis.transientSpacing, "the fixture's gap is inside the spacing")
        XCTAssertEqual(seed.transientTimes, [1.0], "a one-sample flash is ONE event, not two")
    }

    // MARK: 4 — colour follows the frames' colour

    func testAColouredClipHasItsHue() throws {
        let frames = (0..<10).map {
            VideoFrameSample(time: Double($0) * 0.5, luma: [UInt8](repeating: 60, count: Self.cells),
                             meanRed: 0, meanGreen: 0, meanBlue: 1)
        }
        let seed = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: frames, durationSeconds: 5, frameRate: 24))
        XCTAssertTrue(seed.hasDominantColour)
        XCTAssertEqual(seed.hue, 2.0 / 3.0, accuracy: 1e-9, "blue is two thirds of a turn")
    }

    // MARK: 5 — input that cannot be a video is refused

    func testImpossibleInputGivesNoSeed() {
        let good = clip(10) { _ in 100 }
        XCTAssertNotNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: 5, frameRate: 30))

        var wrongGrid = good; wrongGrid[3].luma = [1, 2, 3]
        var backwards = good; backwards[5].time = backwards[4].time
        var pastTheEnd = good; pastTheEnd[9].time = 6
        var nanColour = good; nanColour[2].meanRed = .nan
        var overColour = good; overColour[2].meanBlue = 1.5
        for (name, frames) in [("wrong grid", wrongGrid), ("time does not advance", backwards),
                               ("time past the end", pastTheEnd), ("NaN colour", nanColour),
                               ("colour over 1", overColour)] {
            XCTAssertNil(VideoSeedAnalysis.analyze(samples: frames, durationSeconds: 5, frameRate: 30), name)
        }
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: 0, frameRate: 30))
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: .nan, frameRate: 30))
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: VideoSeedAnalysis.maxDurationSeconds + 1,
                                               frameRate: 30), "a long video is refused, not half-read")
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: 5, frameRate: 0))
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: good, durationSeconds: 5, frameRate: .infinity))
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: Array(good.prefix(1)), durationSeconds: 5, frameRate: 30))
        let tooMany = clip(VideoSeedAnalysis.maxSamples + 1, step: 0.01) { _ in 1 }
        XCTAssertNil(VideoSeedAnalysis.analyze(samples: tooMany, durationSeconds: 5, frameRate: 30),
                     "the sample count is bounded — the work is bounded")
    }

    // MARK: 6 — a stored seed with wrong motion or transients is caught before it is used

    func testAWrongStoredSeedIsNotPlausible() throws {
        let good = try XCTUnwrap(VideoSeedAnalysis.analyze(samples: clip(20) { $0 < 8 ? 0 : 255 },
                                                           durationSeconds: 5, frameRate: 30))
        XCTAssertTrue(good.isPlausible)
        var tooMuchMotion = good; tooMuchMotion.motionEnergy = 1.5
        var nanBrightness = good; nanBrightness.brightness = .nan
        var outside = good; outside.transientTimes = [7]
        var unordered = good; unordered.transientTimes = [3, 1]
        var fullTurn = good; fullTurn.hue = 1
        var noFrames = good; noFrames.sampledFrames = 1
        for (name, seed) in [("motion over 1", tooMuchMotion), ("NaN brightness", nanBrightness),
                             ("transient outside the clip", outside), ("transients out of order", unordered),
                             ("hue of a full turn", fullTurn), ("one frame", noFrames)] {
            XCTAssertFalse(seed.isPlausible, name)
        }
    }

    // MARK: 7 — a clip's length becomes whole bars

    func testTheLengthIsQuantisedToWholeBars() {
        XCTAssertEqual(VideoSeedAnalysis.bars(forSeconds: 8, bpm: 120), 4, "a 4/4 bar at 120 bpm is 2 s")
        XCTAssertEqual(VideoSeedAnalysis.bars(forSeconds: 8.9, bpm: 120), 4, "rounded to the nearest bar")
        XCTAssertEqual(VideoSeedAnalysis.bars(forSeconds: 0.1, bpm: 120), 1, "never less than one bar")
        XCTAssertEqual(VideoSeedAnalysis.bars(forSeconds: 6, bpm: 90, beatsPerBar: 3), 3)
        XCTAssertNil(VideoSeedAnalysis.bars(forSeconds: .nan, bpm: 120))
        XCTAssertNil(VideoSeedAnalysis.bars(forSeconds: 4, bpm: 0))
        XCTAssertEqual(VideoSeedAnalysis.seconds(forBars: 4, bpm: 120), 8)
        XCTAssertNil(VideoSeedAnalysis.seconds(forBars: 0, bpm: 120))
    }

    // MARK: 8 — pure, and never near the audio path

    func testTheCoreImportsOnlyFoundation() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Core/VideoSeed.swift"),
                                                  encoding: .utf8))
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }.map(String.init)
        XCTAssertEqual(imports, ["import Foundation"])
        for engine in ["AudioEngine", "EngineBus", "PatternEngine", "AVAsset", "DispatchQueue"] {
            XCTAssertFalse(code.contains(engine), "the pure core names `\(engine)`")
        }
    }
}

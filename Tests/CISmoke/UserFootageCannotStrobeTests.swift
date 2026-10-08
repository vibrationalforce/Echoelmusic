// UserFootageCannotStrobeTests.swift
// Echoel — GMMW VV-4, the law gate before any door shows a person's own video in the visuals.
// `FlashGuard` budgets the generated looks; footage is not ours and can hold a 10 Hz strobe. The
// limiter watches the frames actually shown and caps the layer's gain (see its header for the
// arithmetic); this file drives it.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–5 END-TO-END on the shipped, public,
// Foundation-only `VideoFlashLimiter` and `VideoLayerMath`, claim 6 a SOURCE-TEXT scan:
// 1. Strobes at 10, 4, 3.5 and 3 Hz, full frame, 0 ↔ 1, starting bright AND starting dark, shown
//    at 60 frames a second for 5 s: the
//    layer's output (gain × the brightest region, over black — the worst contrast) holds at most
//    five transitions of a WCAG step in any one second, i.e. two and a half flashes, under
//    `FlashGuard.maxFlashHz`. The 10 Hz cap engages within the first half second.
// 2. COUNTERWEIGHTS (#343): steady footage, a three-second fade, a 2 Hz flash and a 0.02 shimmer at
//    10 Hz pass with the gain exactly 1 on every frame — the limiter does not dim ordinary video.
// 3. A strobe in ONE region of sixteen (0.3 ↔ 0.6, the rest steady) engages it.
// 4. Release: after a strobe stops the gain holds for at least one whole second, then climbs
//    no faster than `releasePerSecond` per frame interval, and is back at 1 by ten seconds.
// 5. Hostile input: NaN, infinities, time running backwards, empty and changing region layouts and
//    5 000 fuzzed frames leave the gain finite and in `engagedGain…1`; a backwards clock (a seek in
//    media time) and a new layout do not reset an engaged cap.
// 6. The limiter's numbers are `FlashGuard`'s (#416) — no second 3 Hz, no second WCAG step.
// 7. `VideoLayerMath`: WCAG relative luminance with the BT.709 weights, block means, a portrait
//    clip's quarter-turn transform shown upright and fitted into a phone-sized visual.
//
// THE NUMBERS (#442). Transcribed into Python (the limiter as written, the output counter below) and
// driven: worst output transitions per second = 5 starting bright and 4 starting dark at 10/4/3.5/3 Hz,
// 4 at 2 Hz (no engagement);
// the 10 Hz cap engages on frame 15 (0.25 s); after a 2 s strobe the first rise is at 3.817 s (the
// fifth-latest transition leaves the window at 2.75 s, plus the 1 s hold) and the largest rise per
// frame is 0.25/60. The sRGB value 0.5 is 0.21404 in linear light; a 1920 × 1080 clip with a quarter
// turn shows as 1080 × 1920 and fits 390 × 844 at (0, 75.33, 390, 693.33).
//
// HONEST GRADING (§3). The file does not COMPILE on its parent (`2c07b51`): both types are created by
// this commit, so no assertion has a verdict there; claims 1–7 are FORWARD guards (one absence,
// #486). MUTANTS driven on the transcription, each red for its named reason: engaging at the WCAG
// count (6) instead of 5 → claim 1, but ONLY on a strobe that starts dark (six transitions in a
// window; starting bright the cap lands on a rising edge and hides it — hence both phases); an
// engaged gain of 0.2 → claim 1 (the steps after engagement reach the WCAG step); no hold before
// release → claim 4 (the climb starts 0.77 s after the strobe); a full reset on a backwards clock →
// claim 5; a hand-written `3.0` → claim 6.
// NOT covered: what the screen shows — the field under the layer has its own budget, and the sum is
// a DEVICE PROBE, open until a door exists (VV-6).

import Foundation
import XCTest
@testable import Echoelmusic

final class UserFootageCannotStrobeTests: XCTestCase {

    private static let fps = 60.0
    private static let regionCount = 16
    private static let step = FlashGuard.luminanceDeltaThreshold

    /// A square wave between `low` and `high` at `hertz`, the same value in every region, starting
    /// on `high` or on `low`. Both phases matter: which edge the cap lands on decides whether that
    /// edge still shows (a cap landing on a falling edge cannot hide it).
    private static func strobe(_ hertz: Double, low: Double = 0, high: Double = 1,
                               startsHigh: Bool = true) -> (Double) -> [Double] {
        { time in
            let even = Int((2 * hertz * time).rounded(.down)) % 2 == 0
            let value: Double = even == startsHigh ? high : low
            return [Double](repeating: value, count: regionCount)
        }
    }

    private struct Run {
        var times: [Double] = []
        var gains: [Double] = []
        var outputs: [Double] = []
    }

    /// Shows `source` for `seconds` at 60 frames a second; the output is the layer over black.
    private static func run(_ source: (Double) -> [Double], seconds: Double = 5) -> Run {
        var limiter = VideoFlashLimiter()
        var run = Run()
        let frames = Int(seconds * fps)
        for frame in 0..<frames {
            let time = Double(frame) / fps
            let regions = source(time)
            let gain = limiter.step(time: time, regions: regions)
            run.times.append(time)
            run.gains.append(gain)
            run.outputs.append(gain * (regions.max() ?? 0))
        }
        return run
    }

    /// The most output transitions of a WCAG step inside any one second — the WCAG measurement,
    /// written here independently of the limiter (hysteresis on the step, a window of (t − 1, t]).
    private static func worstTransitionsPerSecond(_ run: Run) -> Int {
        var extreme: Double?
        var direction = 0
        var at: [Double] = []
        for (time, value) in zip(run.times, run.outputs) {
            guard let last = extreme else { extreme = value; continue }
            switch direction {
            case 1:
                if value > last {
                    extreme = value
                } else if value <= last - step {
                    direction = -1; extreme = value; at.append(time)
                }
            case -1:
                if value < last {
                    extreme = value
                } else if value >= last + step {
                    direction = 1; extreme = value; at.append(time)
                }
            default:
                if value >= last + step {
                    direction = 1; extreme = value; at.append(time)
                } else if value <= last - step {
                    direction = -1; extreme = value; at.append(time)
                }
            }
        }
        var worst = 0
        for end in at {
            let inside = at.filter { $0 > end - 1 && $0 <= end }.count
            worst = Swift.max(worst, inside)
        }
        return worst
    }

    // MARK: 1 — a strobe is held under the WCAG count

    func testAStrobeCannotFlashThreeTimesASecond() throws {
        for hertz in [10.0, 4, 3.5, 3] {
            for startsHigh in [true, false] {
                let run = Self.run(Self.strobe(hertz, startsHigh: startsHigh))
                let worst = Self.worstTransitionsPerSecond(run)
                let label = "\(hertz) Hz, starting \(startsHigh ? "bright" : "dark")"
                XCTAssertLessThanOrEqual(worst, 5, "\(label): \(worst) transitions in one second")
                XCTAssertLessThan(Double(worst) / 2, FlashGuard.maxFlashHz, "\(label): under the WCAG count")
                XCTAssertEqual(run.gains.last, VideoFlashLimiter.engagedGain, "\(label): still capped at the end")
            }
        }
        let ten = Self.run(Self.strobe(10))
        let engaged = try XCTUnwrap(ten.gains.firstIndex { $0 < 1 }, "a 10 Hz strobe is capped")
        XCTAssertLessThanOrEqual(engaged, Int(Self.fps / 2), "a 10 Hz strobe is capped within half a second")
        for index in stride(from: engaged + 1, to: ten.outputs.count, by: 1) {
            XCTAssertLessThan(Swift.abs(ten.outputs[index] - ten.outputs[index - 1]), Self.step,
                              "frame \(index): once capped, no step of the layer is a WCAG step")
        }
    }

    // MARK: 2 — ordinary footage is untouched

    func testOrdinaryFootageKeepsItsFullGain() {
        let sources: [(String, (Double) -> [Double])] = [
            ("steady", { _ in [Double](repeating: 0.5, count: Self.regionCount) }),
            ("three-second fade", { time in [Double](repeating: Swift.min(1, time / 3), count: Self.regionCount) }),
            ("2 Hz flash", Self.strobe(2)),
            ("0.02 shimmer at 10 Hz", Self.strobe(10, low: 0.5, high: 0.52)),
        ]
        for (name, source) in sources {
            let run = Self.run(source)
            XCTAssertEqual(run.gains.filter { $0 != 1 }.count, 0, "\(name): the gain left 1")
        }
    }

    // MARK: 3 — one region is enough

    func testAStrobeInOneRegionEngagesTheCap() {
        let corner: (Double) -> [Double] = { time in
            var regions = [Double](repeating: 0.3, count: Self.regionCount)
            regions[5] = Int((20 * time).rounded(.down)) % 2 == 0 ? 0.6 : 0.3
            return regions
        }
        XCTAssertEqual(Self.run(corner).gains.last, VideoFlashLimiter.engagedGain)
    }

    // MARK: 4 — it lets go slowly, and only after a quiet second

    func testTheCapReleasesAfterTheHoldAndClimbsSlowly() throws {
        let strobeThenStill: (Double) -> [Double] = { time in
            time < 2 ? Self.strobe(10)(time) : [Double](repeating: 0.5, count: Self.regionCount)
        }
        let run = Self.run(strobeThenStill, seconds: 10)
        let firstRise = try XCTUnwrap(run.gains.indices.dropFirst().first { run.gains[$0] > run.gains[$0 - 1] })
        XCTAssertGreaterThanOrEqual(run.times[firstRise], 3,
                                    "the layer stays capped for at least one whole second after the last strobe edge")
        let largestRise: Double = run.gains.indices.dropFirst().map { run.gains[$0] - run.gains[$0 - 1] }.max() ?? 0
        XCTAssertLessThanOrEqual(largestRise, VideoFlashLimiter.releasePerSecond / Self.fps + 1e-12)
        XCTAssertEqual(run.gains.last, 1, "back at full gain by ten seconds")
    }

    // MARK: 5 — hostile input

    func testHostileInputKeepsTheGainFiniteAndTheCapHeld() {
        var limiter = VideoFlashLimiter()
        let bounds = VideoFlashLimiter.engagedGain...1
        for frame in 0..<60 {
            let value: Double = frame % 2 == 0 ? 1 : 0
            limiter.step(time: Double(frame) / Self.fps, regions: [Double](repeating: value, count: 16))
        }
        XCTAssertEqual(limiter.gain, VideoFlashLimiter.engagedGain)
        XCTAssertEqual(limiter.step(time: 0.2, regions: [Double](repeating: 0.5, count: 16)), VideoFlashLimiter.engagedGain,
                       "a clock running backwards (a seek in media time) does not reset the cap")
        XCTAssertEqual(limiter.step(time: 1.1, regions: [0.5, 0.5]), VideoFlashLimiter.engagedGain,
                       "a new region layout restarts the counting, not the gain")
        let hostile: [(Double, [Double])] = [(.nan, [0.5]), (.infinity, [0.5]), (1.2, []),
                                             (1.3, [.nan, .infinity, -.infinity, -4, 9])]
        for (time, regions) in hostile {
            XCTAssertTrue(bounds.contains(limiter.step(time: time, regions: regions)))
        }

        var fuzzed = VideoFlashLimiter()
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var time = 0.0
        for _ in 0..<5_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let pick = Int(state >> 59)
            time += pick == 0 ? -0.5 : Double(pick % 7) / 120
            var regions: [Double] = []
            for cell in 0..<(1 + pick % 16) {
                let raw = Double((state >> UInt64(cell % 32)) & 0xFFFF) / 65_535
                regions.append(cell == 3 && pick % 5 == 0 ? .nan : raw)
            }
            let gain = fuzzed.step(time: time, regions: regions)
            XCTAssertTrue(gain.isFinite && bounds.contains(gain))
        }
    }

    // MARK: 6 — one definition of the law

    func testTheLimiterTakesItsNumbersFromFlashGuard() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let path = "Sources/Echoelmusic/Core/VideoFlashLimiter.swift"
        let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        for derived in ["FlashGuard.luminanceDeltaThreshold * regionCoverage", "Int(2 * FlashGuard.maxFlashHz) - 1",
                        "FlashGuard.luminanceDeltaThreshold / 2", "FlashGuard.maxDelta(perSecond: Self.releasePerSecond, dt: dt)"] {
            XCTAssertTrue(code.contains(derived), "the limiter derives `\(derived)` from FlashGuard")
        }
        for copy in ["3.0", "= 0.1\n", "0.10", "= 3\n"] {
            XCTAssertFalse(code.contains(copy), "a second copy of the WCAG law: `\(copy)` (#416)")
        }
        XCTAssertEqual(VideoFlashLimiter.engageTransitions, 5)
        XCTAssertEqual(VideoFlashLimiter.transitionThreshold, 0.025, accuracy: 1e-12)
    }

    // MARK: 7 — the layer's arithmetic

    func testTheLayerMathIsWCAGLuminanceAndAnUprightFit() throws {
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 1, green: 1, blue: 1), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0, green: 0, blue: 0), 0)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0, green: 1, blue: 0), 0.7152, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0.5, green: 0.5, blue: 0.5), 0.21404, accuracy: 1e-4)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: .nan, green: 2, blue: -1), 0.7152, accuracy: 1e-12,
                       "NaN reads as 0 and every component is clamped")

        var grid = [Double](repeating: 0, count: 256)
        grid[0] = 1
        let means = try XCTUnwrap(VideoLayerMath.regionMeans(grid, side: 16, blocks: VideoLayerMath.flashBlocksPerSide))
        XCTAssertEqual(means.count, 16)
        XCTAssertEqual(means.first ?? 0, 1.0 / 16, accuracy: 1e-12)
        XCTAssertEqual(means.dropFirst().filter { $0 != 0 }.count, 0)
        XCTAssertNil(VideoLayerMath.regionMeans(grid, side: 16, blocks: 5), "16 does not divide into 5")
        XCTAssertNil(VideoLayerMath.regionMeans([1, 2, 3], side: 16, blocks: 4))
        grid[7] = .nan
        XCTAssertNil(VideoLayerMath.regionMeans(grid, side: 16, blocks: 4))

        let portrait = try XCTUnwrap(VideoLayerMath.displaySize(width: 1920, height: 1080, a: 0, b: 1, c: -1, d: 0))
        XCTAssertEqual(portrait.width, 1080)
        XCTAssertEqual(portrait.height, 1920)
        let plain = try XCTUnwrap(VideoLayerMath.displaySize(width: 1920, height: 1080, a: 1, b: 0, c: 0, d: 1))
        XCTAssertEqual(plain.width, 1920)
        XCTAssertEqual(plain.height, 1080)
        XCTAssertNil(VideoLayerMath.displaySize(width: 0, height: 1080, a: 1, b: 0, c: 0, d: 1))
        XCTAssertEqual(VideoLayerMath.orientation(a: 0, b: 1, c: -1, d: 0),
                       VideoLayerMath.Orientation(quarterTurns: 1, mirrored: false))
        XCTAssertEqual(VideoLayerMath.orientation(a: -1, b: 0, c: 0, d: 1),
                       VideoLayerMath.Orientation(quarterTurns: 2, mirrored: true))
        XCTAssertNil(VideoLayerMath.orientation(a: 1, b: 2, c: 2, d: 4), "a singular transform")
        XCTAssertNil(VideoLayerMath.orientation(a: .nan, b: 0, c: 0, d: 1))

        let fit = try XCTUnwrap(VideoLayerMath.aspectFit(contentWidth: portrait.width, contentHeight: portrait.height,
                                                         containerWidth: 390, containerHeight: 844))
        XCTAssertEqual(fit.x, 0, accuracy: 1e-9)
        XCTAssertEqual(fit.width, 390, accuracy: 1e-9)
        let fittedHeight: Double = 1920.0 * 390.0 / 1080.0
        XCTAssertEqual(fit.height, fittedHeight, accuracy: 1e-9)
        XCTAssertEqual(fit.y, (844 - fittedHeight) / 2, accuracy: 1e-9)
        XCTAssertNil(VideoLayerMath.aspectFit(contentWidth: .infinity, contentHeight: 1,
                                              containerWidth: 390, containerHeight: 844))
    }
}

// UserFootageCannotStrobeTests.swift
// Echoel — GMMW VV-4, the law gate before any door shows a person's own video in the visuals.
// `FlashGuard` budgets the generated looks; footage is not ours and can hold a 10 Hz strobe. The
// limiter watches the frames actually shown and caps the layer's gain (see its header for the
// arithmetic); this file drives it. Reworked by the review of VV-4 (2026-10-08): claims 3–6 are the
// review's inputs, each one a way the first version let a flash through.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–6 and 8 END-TO-END on the shipped, public,
// Foundation-only `VideoFlashLimiter` and `VideoLayerMath`, claim 7 a SOURCE-TEXT scan:
// 1. Strobes at 10, 4, 3.5 and 3 Hz, full frame, 0 ↔ 1, starting bright AND starting dark, shown at
//    60 frames a second for 5 s: the layer's output (gain × the brightest cell, over black — the
//    worst contrast) holds at most five transitions of a WCAG step in any one second, i.e. two and a
//    half flashes, under `FlashGuard.maxFlashHz`. The 10 Hz cap engages within the first half second.
// 2. COUNTERWEIGHTS (#343): steady footage, a three-second fade and a 0.02 shimmer at 10 Hz keep the
//    gain exactly 1 on every frame, and so does a steady 1.9 Hz flash on four clock offsets, each
//    also jittered — the limiter does not dim ordinary video.
// 3. Part of the picture is enough: a strobe in one cell; a flash centred on the corner where four of
//    the first version's blocks meet (each of them moves by less than the threshold — premise); two
//    neighbouring blocks taking turns (either one alone keeps the gain at 1 — premise); a chase
//    across five blocks.
// 4. A strobe whose first shown frame sits halfway between its two levels still counts.
// 5. Release: after a strobe stops the gain holds for at least one whole second, then climbs no
//    faster than `releasePerSecond` per frame interval and is back at 1 by ten seconds; a strobe that
//    resumes during the climb still shows at most five transitions in a second.
// 6. Its own clock: a media clock that loops back into a strobe counts the second pass (capped) and
//    holds the output at five; a grid that changes size every frame, and a grid finer than
//    `maxCellsPerSide`, still engage on a full-frame strobe; a seek and a new layout keep an engaged
//    cap; hostile values and 5 000 fuzzed frames leave the gain finite and in `engagedGain…1`.
// 7. The limiter's numbers are `FlashGuard`'s (#416) — no second 3 Hz, no second WCAG step.
// 8. `VideoLayerMath`: WCAG relative luminance with the BT.709 weights, cell means (a side too large
//    to square is refused, not a trap), a portrait clip's quarter-turn transform shown upright and
//    fitted into a phone-sized visual.
//
// THE NUMBERS (#442). Transcribed into Python (the limiter as written, every input below, the output
// counter) and driven: worst output transitions per second = 5 for every strobe in claim 1, 0 dimmed
// frames for every source in claim 2; the 10 Hz cap engages on frame 15 (0.25 s); after a 2 s strobe
// the first rise is at 3.85 s and the largest rise per frame is 0.25/60; the resumed strobe shows 5;
// the looped clock shows 5 and its second pass sits at 0.05. The corner flash is 14 × 14 pixels of a
// 64 × 64 picture at a step of 0.10, which moves each fixed block by 49/256 × 0.10 ≈ 0.019 and the
// overlapping window on the corner by 196/256 × 0.10 ≈ 0.077 (threshold 0.025). The mid-swing strobe
// is one cell 0.30 ↔ 0.42 starting at 0.36: its 2 × 2 window swings 0.03, but only 0.015 either side
// of the first frame. The sRGB value 0.5 is 0.21404 in linear light; a 1920 × 1080 clip with a quarter
// turn shows as 1080 × 1920 and fits 390 × 844 at (0, 75.33, 390, 693.33).
//
// HONEST GRADING (§3). The file does not COMPILE on its parent (`dc7e9bc`): `step(time:cells:
// cellsPerSide:)`, `flashCellsPerSide` and `maxCellsPerSide` are created by this commit, so no
// assertion has a verdict there. Transcribed against the parent's limiter (fed the first version's
// 4 × 4 block means): claims 3, 4, 5 and 6 are REGRESSIONS, red for their named reasons — the corner,
// the alternation and the chase never engage it; the mid-swing strobe never registers; the resumed
// strobe shows SIX transitions in a second; the looped clock shows TWENTY and plays its second pass at
// full gain, and the changing grid never engages it. Claims 1, 2 and 7 are COUNTERWEIGHTS, green on
// both; claim 8's overflow assertion TRAPS on the parent (`side * side`) rather than failing — a trap
// kills the test process, so it would show as #396-shaped silence, not as a named failure (#1174).
// MUTANTS driven on the transcription of this commit, each red for its named reason: fixed blocks
// instead of overlapping windows → claim 3 (corner, alternation, chase); a non-increasing time
// ignored → claim 6 (twenty, full gain); the first frame as the reference → claim 4; the full engage
// count while climbing → claim 5 (six); a new layout restarting the whole-frame window → claim 6; no
// whole-frame window → claim 6 (changing and finer grids); engaging at the WCAG count (six) → claim 1,
// but ONLY on strobes that start dark, and claim 5; an engaged gain of 0.2 → claim 1; no hold before
// release → claim 5 (the climb starts at 2.85 s).
// NOT covered: what the screen shows — the field under the layer has its own budget, and the sum is
// a DEVICE PROBE, open until a door exists (VV-6).

import Foundation
import XCTest
@testable import Echoelmusic

final class UserFootageCannotStrobeTests: XCTestCase {

    private static let fps = 60.0
    private static let side = VideoLayerMath.flashCellsPerSide
    private static let step = FlashGuard.luminanceDeltaThreshold
    /// The cell just up and left of the picture's centre.
    private static let centreCell = (side / 2 - 1) * side + (side / 2 - 1)

    private static func frame(_ value: Double) -> [Double] {
        [Double](repeating: value, count: side * side)
    }

    /// A square wave between `low` and `high` at `hertz` from `start`, the same value in every cell,
    /// starting on `high` or on `low`. Both phases matter: which edge the cap lands on decides whether
    /// that edge still shows (a cap landing on a falling edge cannot hide it).
    private static func strobe(_ hertz: Double, low: Double = 0, high: Double = 1,
                               startsHigh: Bool = true, start: Double = 0) -> (Double) -> [Double] {
        { time in
            let even = Int((2 * hertz * (time - start)).rounded(.down)) % 2 == 0
            let value: Double = even == startsHigh ? high : low
            return Self.frame(value)
        }
    }

    /// Which of the first version's 4 × 4 blocks (row-major, 0…15) a cell lies in.
    private static func blockIndex(_ cell: Int) -> Int {
        let row = cell / side
        let column = cell % side
        return (row * 4 / side) * 4 + column * 4 / side
    }

    /// A frame in which the blocks named in `values` hold their value and every other cell `base`.
    private static func blocks(_ values: [Int: Double], base: Double) -> [Double] {
        var cells = frame(base)
        for cell in cells.indices {
            if let value = values[blockIndex(cell)] { cells[cell] = value }
        }
        return cells
    }

    /// Review input A: blocks 5 and 6, side by side, each flash twice per 1.1 s cycle, taking turns.
    private static func alternating(_ time: Double, blocks which: Set<Int>) -> [Double] {
        let phase = time.truncatingRemainder(dividingBy: 1.1)
        let edges: [Int: [Double]] = [5: [0, 0.1, 0.2, 0.3], 6: [0.55, 0.65, 0.75, 0.85]]
        var values: [Int: Double] = [:]
        for block in which {
            let passed = (edges[block] ?? []).filter { phase >= $0 }.count
            values[block] = passed % 2 == 1 ? 0.5 : 0.2
        }
        return blocks(values, base: 0.2)
    }

    /// Review input B: a chase — five neighbouring blocks each flash twice, one after the other.
    private static func chase(_ time: Double) -> [Double] {
        let phase = time.truncatingRemainder(dividingBy: 1.25)
        var values: [Int: Double] = [:]
        for (order, block) in [4, 5, 6, 7, 11].enumerated() {
            let start = Double(order) * 0.25
            let edges: [Double] = [start, start + 0.05, start + 0.1, start + 0.15]
            values[block] = edges.filter { phase >= $0 }.count % 2 == 1 ? 0.5 : 0.2
        }
        return blocks(values, base: 0.2)
    }

    /// The picture behind review input R4, in pixels (eight per cell): a square three quarters the
    /// area of one of the first version's blocks, centred where four of them meet, a WCAG step
    /// brighter than the rest when `lit`.
    private static func cornerImage(lit: Bool) -> [Double] {
        let pixels = 8 * side
        let quarter = Double(pixels) / 4
        let half: Double = (0.75 * quarter * quarter).squareRoot() / 2
        let centre = Double(pixels) / 2
        var image = [Double](repeating: 0.3, count: pixels * pixels)
        guard lit else { return image }
        let covered: [Int] = (0..<pixels).filter { Swift.abs(Double($0) + 0.5 - centre) < half }
        for y in covered {
            for x in covered { image[y * pixels + x] = 0.3 + 0.1 }
        }
        return image
    }

    private struct Run {
        var times: [Double] = []
        var gains: [Double] = []
        var outputs: [Double] = []
    }

    /// Shows `source` for `seconds` at 60 frames a second; the output is the layer over black. The
    /// limiter is handed `clock(frame)` when given, the shown time otherwise.
    private static func run(_ source: (Double) -> [Double], seconds: Double = 5,
                            clock: ((Int) -> Double)? = nil) -> Run {
        var limiter = VideoFlashLimiter()
        var run = Run()
        for index in 0..<Int(seconds * fps) {
            let shown = Double(index) / fps
            let cells = source(shown)
            let gain = limiter.step(time: clock?(index) ?? shown, cells: cells, cellsPerSide: side)
            run.times.append(shown)
            run.gains.append(gain)
            run.outputs.append(gain * (cells.max() ?? 0))
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
            ("steady", { _ in Self.frame(0.5) }),
            ("three-second fade", { time in Self.frame(Swift.min(1, time / 3)) }),
            ("0.02 shimmer at 10 Hz", Self.strobe(10, low: 0.5, high: 0.52)),
        ]
        for (name, source) in sources {
            let run = Self.run(source)
            XCTAssertEqual(run.gains.filter { $0 != 1 }.count, 0, "\(name): the gain left 1")
        }
        for offset in [0.0, 0.0037, 0.01, 0.0123] {
            for jitter in [0, 1] {
                let clock: (Int) -> Double = { index in
                    let wobble = Double(jitter * ((index * 7919) % 5 - 2))
                    return offset + Double(index) / Self.fps + wobble / Self.fps / 4
                }
                let run = Self.run(Self.strobe(1.9), seconds: 8, clock: clock)
                XCTAssertEqual(run.gains.filter { $0 != 1 }.count, 0, """
                    a steady 1.9 Hz flash (clock offset \(offset) s, jitter \(jitter)) was dimmed — \
                    the cap engages at two and a half flashes a second, never below two
                    """)
            }
        }
    }

    // MARK: 3 — part of the picture is enough, wherever it sits

    func testAFlashInPartOfThePictureEngagesTheCap() throws {
        let oneCell: (Double) -> [Double] = { time in
            var cells = Self.frame(0.3)
            cells[Self.centreCell] = Int((20 * time).rounded(.down)) % 2 == 0 ? 0.6 : 0.3
            return cells
        }
        XCTAssertEqual(Self.run(oneCell).gains.last, VideoFlashLimiter.engagedGain, "a strobe in one cell")

        let pixels = 8 * Self.side
        let dark = try XCTUnwrap(VideoLayerMath.regionMeans(Self.cornerImage(lit: false), side: pixels, blocks: Self.side))
        let lit = try XCTUnwrap(VideoLayerMath.regionMeans(Self.cornerImage(lit: true), side: pixels, blocks: Self.side))
        for block in 0..<16 {
            var moved = 0.0
            var members = 0.0
            for cell in lit.indices where Self.blockIndex(cell) == block {
                moved += lit[cell] - dark[cell]
                members += 1
            }
            XCTAssertLessThan(moved / members, VideoFlashLimiter.transitionThreshold, """
                premise: on the first version's fixed blocks the corner flash splits four ways under \
                the threshold (block \(block)) — without that this claim would prove nothing new
                """)
        }
        let corner: (Double) -> [Double] = { time in Int((20 * time).rounded(.down)) % 2 == 0 ? lit : dark }
        XCTAssertEqual(Self.run(corner, seconds: 3).gains.last, VideoFlashLimiter.engagedGain,
                       "a flash centred on the corner of four blocks")

        for alone in [5, 6] {
            let run = Self.run({ Self.alternating($0, blocks: [alone]) }, seconds: 6)
            XCTAssertEqual(run.gains.filter { $0 != 1 }.count, 0, """
                premise: block \(alone) alone flashes too slowly to engage the cap — it is the two \
                together that must
                """)
        }
        XCTAssertLessThan(Self.run({ Self.alternating($0, blocks: [5, 6]) }, seconds: 6).gains.last ?? 1, 1,
                          "two neighbouring blocks taking turns are counted together")
        XCTAssertLessThan(Self.run(Self.chase, seconds: 6).gains.last ?? 1, 1,
                          "a chase across five neighbouring blocks is counted")
    }

    // MARK: 4 — a strobe that starts mid-swing

    func testAStrobeThatStartsMidSwingStillCounts() {
        let midSwing: (Double) -> [Double] = { time in
            var cells = Self.frame(0.3)
            let strobing: Double = Int((20 * time).rounded(.down)) % 2 == 0 ? 0.42 : 0.30
            cells[Self.centreCell] = time == 0 ? 0.36 : strobing
            return cells
        }
        XCTAssertEqual(Self.run(midSwing).gains.last, VideoFlashLimiter.engagedGain, """
            a strobe whose first frame sits between its two levels — measured against that frame, \
            neither half-swing reaches the threshold; measured against its own lowest and highest, \
            every swing does
            """)
    }

    // MARK: 5 — it lets go slowly, only after a quiet second, and catches a strobe that comes back

    func testTheCapReleasesAfterTheHoldAndClimbsSlowly() throws {
        let strobeThenStill: (Double) -> [Double] = { time in
            time < 2 ? Self.strobe(10)(time) : Self.frame(0.5)
        }
        let run = Self.run(strobeThenStill, seconds: 10)
        let firstRise = try XCTUnwrap(run.gains.indices.dropFirst().first { run.gains[$0] > run.gains[$0 - 1] })
        XCTAssertGreaterThanOrEqual(run.times[firstRise], 3,
                                    "the layer stays capped for at least one whole second after the last strobe edge")
        let largestRise: Double = run.gains.indices.dropFirst().map { run.gains[$0] - run.gains[$0 - 1] }.max() ?? 0
        XCTAssertLessThanOrEqual(largestRise, VideoFlashLimiter.releasePerSecond / Self.fps + 1e-12)
        XCTAssertEqual(run.gains.last, 1, "back at full gain by ten seconds")

        let resumes: (Double) -> [Double] = { time in
            if time < 2 { return Self.strobe(10)(time) }
            if time < 4.017 { return Self.frame(1) }
            return Self.strobe(10, startsHigh: false, start: 4.017)(time)
        }
        let worst = Self.worstTransitionsPerSecond(Self.run(resumes, seconds: 8))
        XCTAssertLessThanOrEqual(worst, 5, """
            a strobe that resumes while the gain climbs: the climb's own rise plus the strobe made \
            \(worst) transitions in one second
            """)
    }

    // MARK: 6 — its own clock, and grids it was not built for

    func testTheCapKeepsCountingThroughSeeksLoopsAndLayouts() {
        let looped: (Double) -> [Double] = { time in
            let media = time.truncatingRemainder(dividingBy: 10)
            return media < 2 ? Self.strobe(10)(media) : Self.frame(0.5)
        }
        let loop = Self.run(looped, seconds: 20, clock: { index in
            (Double(index) / Self.fps).truncatingRemainder(dividingBy: 10)
        })
        XCTAssertLessThanOrEqual(Self.worstTransitionsPerSecond(loop), 5, "a media clock that loops back into a strobe")
        var secondPassLowest = 1.0
        for (time, gain) in zip(loop.times, loop.gains) where time >= 10 && time < 12 {
            secondPassLowest = Swift.min(secondPassLowest, gain)
        }
        XCTAssertEqual(secondPassLowest, VideoFlashLimiter.engagedGain, "the second pass of the loop is capped too")

        var changingGrid = VideoFlashLimiter()
        var fineGrid = VideoFlashLimiter()
        let fineSide = 2 * VideoFlashLimiter.maxCellsPerSide
        for index in 0..<600 {
            let time = Double(index) / Self.fps
            let value: Double = Int((20 * time).rounded(.down)) % 2 == 0 ? 1 : 0
            let side = index % 2 == 0 ? Self.side : Self.side - 1
            changingGrid.step(time: time, cells: [Double](repeating: value, count: side * side), cellsPerSide: side)
            fineGrid.step(time: time, cells: [Double](repeating: value, count: fineSide * fineSide), cellsPerSide: fineSide)
        }
        XCTAssertEqual(changingGrid.gain, VideoFlashLimiter.engagedGain, "a grid that changes size every frame")
        XCTAssertEqual(fineGrid.gain, VideoFlashLimiter.engagedGain, "a grid finer than the windows are built for")

        var limiter = VideoFlashLimiter()
        let bounds = VideoFlashLimiter.engagedGain...1
        for index in 0..<60 {
            let value: Double = index % 2 == 0 ? 1 : 0
            limiter.step(time: Double(index) / Self.fps, cells: Self.frame(value), cellsPerSide: Self.side)
        }
        XCTAssertEqual(limiter.gain, VideoFlashLimiter.engagedGain)
        XCTAssertEqual(limiter.step(time: 0.2, cells: Self.frame(0.5), cellsPerSide: Self.side), VideoFlashLimiter.engagedGain,
                       "a clock running backwards (a seek in media time) does not reset the cap")
        XCTAssertEqual(limiter.step(time: 1.1, cells: [0.5, 0.5, 0.5, 0.5], cellsPerSide: 2), VideoFlashLimiter.engagedGain,
                       "a new grid layout restarts the windows, not the gain")
        let hostile: [(Double, [Double], Int)] = [(.nan, [0.5], 1), (.infinity, [0.5], 1), (1.2, [], 0), (1.25, [0.5], -3),
                                                  (1.3, [.nan, .infinity, -.infinity, -4], 2), (1.4, [0.5, 0.5], 2),
                                                  (1.5, [], Int.max)]
        for (time, cells, side) in hostile {
            XCTAssertTrue(bounds.contains(limiter.step(time: time, cells: cells, cellsPerSide: side)))
        }

        var fuzzed = VideoFlashLimiter()
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var time = 0.0
        for _ in 0..<5_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let pick = Int(state >> 59)
            time += pick == 0 ? -0.5 : Double(pick % 7) / 120
            let side = pick % 9
            let count = pick % 11 == 0 ? side * side + 1 : side * side
            var cells: [Double] = []
            for cell in 0..<count {
                let raw = Double((state >> UInt64(cell % 32)) & 0xFFFF) / 65_535
                cells.append(cell == 3 && pick % 5 == 0 ? .nan : raw)
            }
            let gain = fuzzed.step(time: time, cells: cells, cellsPerSide: side)
            XCTAssertTrue(gain.isFinite && bounds.contains(gain))
        }
    }

    // MARK: 7 — one definition of the law

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

    // MARK: 8 — the layer's arithmetic

    func testTheLayerMathIsWCAGLuminanceAndAnUprightFit() throws {
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 1, green: 1, blue: 1), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0, green: 0, blue: 0), 0)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0, green: 1, blue: 0), 0.7152, accuracy: 1e-12)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: 0.5, green: 0.5, blue: 0.5), 0.21404, accuracy: 1e-4)
        XCTAssertEqual(VideoLayerMath.relativeLuminance(red: .nan, green: 2, blue: -1), 0.7152, accuracy: 1e-12,
                       "NaN reads as 0 and every component is clamped")

        let cells = VideoLayerMath.flashCellsPerSide
        let side = 4 * cells
        var grid = [Double](repeating: 0, count: side * side)
        grid[0] = 1
        let means = try XCTUnwrap(VideoLayerMath.regionMeans(grid, side: side, blocks: cells))
        XCTAssertEqual(means.count, cells * cells)
        XCTAssertEqual(means.first ?? 0, 1.0 / 16, accuracy: 1e-12)
        XCTAssertEqual(means.dropFirst().filter { $0 != 0 }.count, 0)
        XCTAssertNil(VideoLayerMath.regionMeans(grid, side: side, blocks: side + 1), "the side does not divide into the blocks")
        XCTAssertNil(VideoLayerMath.regionMeans([1, 2, 3], side: side, blocks: cells))
        XCTAssertNil(VideoLayerMath.regionMeans([], side: Int.max, blocks: 1), "a side too large to square is refused, not a trap")
        grid[7] = .nan
        XCTAssertNil(VideoLayerMath.regionMeans(grid, side: side, blocks: cells))

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

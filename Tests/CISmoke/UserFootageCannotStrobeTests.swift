// UserFootageCannotStrobeTests.swift
// Echoel — GMMW VV-4, the law gate before any door shows a person's own video in the visuals.
// `FlashGuard` budgets the generated looks; footage is not ours and can hold a 10 Hz strobe. The
// limiter watches the frames actually shown and caps the layer's gain (see its header for the
// arithmetic); this file drives it. Reworked twice by review (2026-10-08): claims 3–6 hold the first
// review's inputs, claim 3b and the later parts of claims 3, 5 and 6 the second review's — each one a
// way an earlier version let a flash through.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–6 and 8 END-TO-END on the shipped, public,
// Foundation-only `VideoFlashLimiter` and `VideoLayerMath`, claim 7 a SOURCE-TEXT scan:
// 1. Strobes at 10, 4, 3.5 and 3 Hz, full frame, 0 ↔ 1, starting bright AND starting dark, shown at
//    60 frames a second for 5 s: the layer's output (gain × the brightest cell, over black — the
//    worst contrast) holds at most five transitions of a WCAG step in any one second, i.e. two and a
//    half flashes, under `FlashGuard.maxFlashHz`. The 10 Hz cap engages within the first half second.
// 2. COUNTERWEIGHTS (#343): steady footage, a three-second fade, a 0.02 shimmer at 10 Hz and a
//    high-contrast edge panning across at two widths a second keep the gain exactly 1 on every frame,
//    and so does a steady 1.9 Hz flash on four clock offsets, each also jittered.
// 3. Part of the picture is enough: a strobe in one cell; a flash centred on the corner where four of
//    the first version's blocks meet (each of them moves by less than the threshold — premise); two
//    neighbouring blocks taking turns (either one alone keeps the gain at 1 — premise); a chase
//    across five blocks; and one cell of a 2 × 2 grid flashing by EXACTLY one WCAG step, on every
//    level from 0.00 to 0.90 (no windows there to cover a channel's rounding).
// 3b. Cells swinging AGAINST each other — a checkerboard, one-cell stripes, one cell against its
//    eight neighbours — move every 2 × 2, 4 × 4 and whole-grid square at every offset by less than
//    the window threshold (premise); each is capped, and the cap holds for the whole last second.
// 4. A strobe whose first shown frame sits halfway between its two levels still counts, and one that
//    starts with a step off a level settled 1.7 s before shows at most five in a second.
// 5. Release: after a strobe stops the gain holds for at least one whole second, then climbs no
//    faster than `releasePerSecond` per frame interval and is back at 1 by ten seconds; a strobe that
//    resumes during the climb, footage that falls in two steps while the gain climbs and then
//    strobes, and a drift of half a step into a strobe each show at most five transitions in a
//    second; a 1.9 Hz flash after a short strobe lets the cap go.
// 6. Its own clock: a media clock that loops back into a strobe counts the second pass (capped) and
//    holds the output at five; a 24 fps clip on a 120 Hz display, handed its repeating media time,
//    caps a 2.6 Hz flash at five and climbs one clip frame's step per new frame; a grid that changes
//    size every frame, and a grid finer than `maxCellsPerSide`, still engage on a full-frame strobe;
//    a seek and a new layout keep an engaged cap; hostile values and 5 000 fuzzed frames leave the
//    gain finite and in `engagedGain…1`.
// 7. The limiter's numbers are `FlashGuard`'s (#416) — no second 3 Hz, no second WCAG step.
// 8. `VideoLayerMath`: WCAG relative luminance with the BT.709 weights, cell means (a side too large
//    to square is refused, not a trap), a portrait clip's quarter-turn transform shown upright and
//    fitted into a phone-sized visual.
//
// THE NUMBERS (#442). Transcribed into Python (the limiter as written, every input below, the output
// counter) and driven: worst output transitions per second in claim 1 = 5 for every strobe starting
// bright and 4 for every one starting dark; 0 dimmed frames for every source in claim 2; the 10 Hz
// cap engages on frame 15 (0.25 s); after a 2 s strobe the first rise is at 3.82 s and the largest
// rise per frame is 0.25/60; the step off a settled level shows 4; the resumed strobe shows 5, the
// two-step fall 5, the drift 4; the 1.9 Hz flash ends at gain 1; the repeated media time shows 5 at
// 2.6 Hz and its largest climb step is 0.25/24; the looped clock shows 5 and its second pass sits at
// 0.05. The corner flash is 14 × 14
// pixels of a 64 × 64 picture at a step of 0.10, which moves each fixed block by 49/256 × 0.10 ≈
// 0.019 and the overlapping window on the corner by 196/256 × 0.10 ≈ 0.077 (threshold 0.025). The
// mid-swing strobe is one cell 0.30 ↔ 0.42 starting at 0.36: its 2 × 2 window swings 0.03, but only
// 0.015 either side of the first frame. The sRGB value 0.5 is 0.21404 in linear light; a 1920 × 1080
// clip with a quarter turn shows as 1080 × 1920 and fits 390 × 844 at (0, 75.33, 390, 693.33).
//
// HONEST GRADING (§3), second review. The file does not COMPILE on its parent (`e1ba842`):
// `cellTransitionThreshold` is created by this commit. Transcribed against the parent's limiter:
// claim 3's exact step is RED (31 of 91 levels never engage), claim 3b RED (none of the three
// patterns is ever capped), claim 4's settled step RED (6), claim 5 RED three ways (the two-step
// fall shows 6, the drift 6, the 1.9 Hz flash is held at 0.05 for good), claim 6 RED (the repeated
// media time shows 6 and never caps); claims 1, 2, the mid-swing half of 4 and the first review's
// parts of 3, 5 and 6 are COUNTERWEIGHTS, green on both. MUTANTS driven on the transcription of
// this commit, each red for its named reason: no shown channels → claim 5 (the two-step fall and
// the resumed strobe show 6); no footage cell channels → claim 3b (the cap lets go and re-engages);
// no rounding allowance → claim 3 (14 levels missed); a repeated time advancing 1/240 s → claim 6
// (6, uncapped); a climb on a repeated frame → claim 6 (a step of 0.025); the first version's
// lowered count while the gain is below 1 → claim 5 (the 1.9 Hz flash held at 0.05); no expiry of a
// stale direction → claim 4 (the step off a settled level shows 6); the review's own proposed fix
// (footage cells, a lowered count and a one-second memory of it, no shown channels) → claims 4 and
// 5 (6, 6, and 0.05). Over 2 700 random and directed scenarios beyond these (drifts, steps,
// strobes, counter-phase and partial masks, jittered clocks) the transcription found at most five;
// without the expiry it found six twice.
// The first review's mutants were driven on `d944d2a` and are recorded in its commit.
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

    /// A source in which the cells `inPhase` picks swing 0 ↔ 1 at 10 Hz and every other cell swings
    /// the opposite way.
    private static func counterPhase(_ time: Double, inPhase: (Int, Int) -> Bool) -> [Double] {
        let bright = Int((20 * time).rounded(.down)) % 2 == 0
        var cells = frame(0)
        for cell in cells.indices {
            cells[cell] = inPhase(cell / side, cell % side) == bright ? 1 : 0
        }
        return cells
    }

    /// Review input D: one cell 0.3 ↔ 0.5 at 10 Hz, its eight neighbours 0.3 ↔ 0.26 against it.
    private static func ring(_ time: Double) -> [Double] {
        let bright = Int((20 * time).rounded(.down)) % 2 == 0
        var cells = frame(0.3)
        let row = side / 2 - 1
        let column = side / 2 - 1
        for dr in -1...1 {
            for dc in -1...1 {
                let value: Double = dr == 0 && dc == 0 ? (bright ? 0.5 : 0.3) : (bright ? 0.26 : 0.3)
                cells[(row + dr) * side + column + dc] = value
            }
        }
        return cells
    }

    /// Whether every 2 × 2, 4 × 4 and whole-grid square of cells, at EVERY offset (not only the
    /// limiter's own), moves by less than the window threshold between `a` and `b`.
    private static func everySquareMovesLessThanTheThreshold(_ a: [Double], _ b: [Double]) -> Bool {
        for size in [2, 4, side] {
            for row in 0...(side - size) {
                for column in 0...(side - size) {
                    var moved = 0.0
                    for r in row..<(row + size) {
                        for c in column..<(column + size) { moved += b[r * side + c] - a[r * side + c] }
                    }
                    if Swift.abs(moved) / Double(size * size) >= VideoFlashLimiter.transitionThreshold { return false }
                }
            }
        }
        return true
    }

    /// A vertical edge (0.05 left of `x`, 0.85 right of it) in a picture eight pixels to a cell.
    private static func edge(at x: Double) -> [Double] {
        var cells = frame(0)
        for cell in cells.indices {
            let left = Double(cell % side * 8)
            let dark: Double = Swift.max(0, Swift.min(left + 8, x) - left)
            cells[cell] = (dark * 0.05 + (8 - dark) * 0.85) / 8
        }
        return cells
    }

    private static let clipFPS = 24.0
    private static let displayHz = 120.0

    /// A clip at `clipFPS` shown on a `displayHz` display, the limiter handed the clip's MEDIA time
    /// (so each time repeats): a full-frame flash at `flashHertz` until `until`, then still at 0.5.
    private static func runOnDisplay(flashHertz: Double, until: Double = .infinity, seconds: Double) -> Run {
        var limiter = VideoFlashLimiter()
        var run = Run()
        for index in 0..<Int(seconds * displayHz) {
            let shown = Double(index) / displayHz
            let media = (shown * clipFPS + 1e-9).rounded(.down) / clipFPS
            let value: Double = media >= until ? 0.5 : (Int((2 * flashHertz * media).rounded(.down)) % 2 == 0 ? 1 : 0)
            let gain = limiter.step(time: media, cells: frame(value), cellsPerSide: side)
            run.times.append(shown)
            run.gains.append(gain)
            run.outputs.append(gain * value)
        }
        return run
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
        // A high-contrast edge crossing the picture at two widths a second: each cell darkens once,
        // one transition per cell however fast — the cell channels must not read movement as flashing.
        let pan = Self.run({ time in Self.edge(at: Double(8 * Self.side) * Swift.min(1, 2 * time)) })
        XCTAssertEqual(pan.gains.filter { $0 != 1 }.count, 0, "a single edge panning across: the gain left 1")
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

        // A move of EXACTLY one step is a transition, whatever the rounding. A 2 × 2 grid has no
        // windows to catch what one channel's arithmetic drops, so each channel stands alone there.
        for hundredths in 0...90 {
            let base = Double(hundredths) / 100
            var limiter = VideoFlashLimiter()
            for index in 0..<Int(2 * Self.fps) {
                let time = Double(index) / Self.fps
                var cells = [Double](repeating: base, count: 4)
                cells[0] = Int((20 * time).rounded(.down)) % 2 == 0 ? base + Self.step : base
                limiter.step(time: time, cells: cells, cellsPerSide: 2)
            }
            XCTAssertEqual(limiter.gain, VideoFlashLimiter.engagedGain,
                           "one cell of a 2 × 2 grid flashing by exactly one WCAG step on \(base)")
        }
    }

    // MARK: 3b — cells swinging against each other

    func testCellsSwingingAgainstEachOtherEngageTheCap() {
        let patterns: [(String, (Double) -> [Double])] = [
            ("a checkerboard of cells", { Self.counterPhase($0) { row, column in (row + column) % 2 == 0 } }),
            ("stripes one cell wide", { Self.counterPhase($0) { _, column in column % 2 == 0 } }),
            ("one cell against its eight neighbours", Self.ring),
        ]
        for (name, source) in patterns {
            XCTAssertTrue(Self.everySquareMovesLessThanTheThreshold(source(0), source(0.05)), """
                premise: \(name) moves every square of cells, at every offset, by less than the window \
                threshold — without that this claim would prove nothing the windows do not
                """)
            let run = Self.run(source)
            XCTAssertEqual(run.gains.last, VideoFlashLimiter.engagedGain, "\(name), reversing at 10 Hz, is capped")
            XCTAssertEqual(run.gains.suffix(Int(Self.fps)).filter { $0 != VideoFlashLimiter.engagedGain }.count, 0,
                           "\(name): the cap holds while it goes on — no release and re-engage")
        }
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

        // A strobe that starts with a step off a level SETTLED long ago: the rise that led to the
        // level ended 1.7 s before, and the step is a change of its own, not the rest of that rise.
        let afterSettling: (Double) -> [Double] = { time in
            if time < 0.25 { return Self.frame(0.24) }
            if time < 0.3 { return Self.frame(0.19) }
            if time < 2 { return Self.frame(0.31) }
            return Self.strobe(3.3, low: 0.25, high: 0.43, start: 2)(time)
        }
        let settled = Self.worstTransitionsPerSecond(Self.run(afterSettling))
        XCTAssertLessThanOrEqual(settled, 5, "a strobe stepping off a level settled 1.7 s before: \(settled) in one second")
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

        // Footage that keeps FALLING while the gain climbs: to the footage it is one movement, on the
        // screen the climb lifts it in between — a fall, a rise and a fall (second review: six).
        let fallsWhileClimbing: (Double) -> [Double] = { time in
            if time < 2 { return Self.strobe(10)(time) }
            if time < 3.5 { return Self.frame(1) }
            if time < 4.1 { return Self.frame(0.75) }
            if time < 4.7 { return Self.frame(0.5) }
            return Self.strobe(10, low: 0.1, high: 0.6, startsHigh: false, start: 4.7)(time)
        }
        let falling = Self.worstTransitionsPerSecond(Self.run(fallsWhileClimbing, seconds: 10))
        XCTAssertLessThanOrEqual(falling, 5, "footage falling in two steps while the gain climbs: \(falling) in one second")

        // A slow drift commits the windows' direction before a strobe starts the same way.
        let driftThenStrobe: (Double) -> [Double] = { time in
            time < 2 ? Self.frame(0.30 + 0.05 * time / 2) : Self.strobe(10, start: 2)(time)
        }
        let drift = Self.worstTransitionsPerSecond(Self.run(driftThenStrobe))
        XCTAssertLessThanOrEqual(drift, 5, "a drift of half a step, then a strobe: \(drift) in one second")

        // After a strobe, a SLOWER flash lets the cap go: the first version engaged at four while the
        // gain was below 1, which a 1.9 Hz flash always reaches, and held it at 0.05 for good.
        let slowAfterStrobe: (Double) -> [Double] = { time in
            time < 0.5 ? Self.strobe(10)(time) : Self.strobe(1.9, start: 0.5)(time)
        }
        let slow = Self.run(slowAfterStrobe, seconds: 20)
        XCTAssertLessThan(slow.gains.first(where: { $0 < 1 }) ?? 1, 1, "premise: the strobe engages the cap")
        XCTAssertEqual(slow.gains.last, 1, "a 1.9 Hz flash after a strobe: back at full gain by twenty seconds")
        XCTAssertLessThanOrEqual(Self.worstTransitionsPerSecond(slow), 5)
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

        // A 24 fps clip on a 120 Hz display, handed its media time: each time arrives five times. The
        // first version advanced its clock 1/240 s for each repeat, ran 40 % fast, and read a 2.6 Hz
        // flash as under the count.
        let repeated = Self.runOnDisplay(flashHertz: 2.6, seconds: 8)
        XCTAssertLessThanOrEqual(Self.worstTransitionsPerSecond(repeated), 5, "a 2.6 Hz flash at 24 fps on a 120 Hz display")
        XCTAssertEqual(repeated.gains.last, VideoFlashLimiter.engagedGain, "a 2.6 Hz flash at 24 fps on a 120 Hz display is capped")
        let stillAfter = Self.runOnDisplay(flashHertz: 10, until: 2, seconds: 10)
        let largestStep: Double = stillAfter.gains.indices.dropFirst()
            .map { stillAfter.gains[$0] - stillAfter.gains[$0 - 1] }.max() ?? 0
        XCTAssertLessThanOrEqual(largestStep, VideoFlashLimiter.releasePerSecond / Self.clipFPS + 1e-12, """
            the climb takes one clip frame's step per new frame and none on a repeated one — a repeated \
            frame advances the clock by nothing
            """)
        XCTAssertEqual(stillAfter.gains.last, 1, "and it does climb back")

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
                        "cellTransitionThreshold = FlashGuard.luminanceDeltaThreshold\n",
                        "FlashGuard.luminanceDeltaThreshold / 2", "FlashGuard.maxDelta(perSecond: Self.releasePerSecond, dt: dt)"] {
            XCTAssertTrue(code.contains(derived), "the limiter derives `\(derived)` from FlashGuard")
        }
        for copy in ["3.0", "= 0.1\n", "0.10", "= 3\n"] {
            XCTAssertFalse(code.contains(copy), "a second copy of the WCAG law: `\(copy)` (#416)")
        }
        XCTAssertEqual(VideoFlashLimiter.engageTransitions, 5)
        XCTAssertEqual(VideoFlashLimiter.transitionThreshold, 0.025, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimiter.cellTransitionThreshold, FlashGuard.luminanceDeltaThreshold)
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

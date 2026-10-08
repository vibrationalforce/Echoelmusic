// VideoFlashLimiter.swift
// Echoel — GMMW VV-4 (founder 2026-10-08, "own footage inside own engine"): the law gate that comes
// BEFORE any door shows a person's own video in the visuals. `FlashGuard` budgets the GENERATED
// looks — each one's flash rate is derived from its shader — but footage is not ours: a clip can
// hold a strobe, a lightning storm or a club light at 10 Hz, and no budget written in advance can
// cover it. The seed reader samples at most four frames a second, so it cannot certify a strobe
// either. This type watches the frames that are actually SHOWN and caps the layer's gain.
//
// ⭐ WHAT IT WATCHES. The caller hands a grid of CELL luminances (`VideoLayerMath.regionMeans`,
// 8 × 8 by `VideoLayerMath.flashCellsPerSide`). The limiter reads them through WINDOWS: every
// 2 × 2 and 4 × 4 square of cells at half its own stride (so they overlap), plus the whole frame.
// A WCAG flash counts when the flashing area within any one 10° field is large enough, and a 10°
// field can sit anywhere on the picture — on a block corner, across two blocks — so fixed blocks
// are not enough (review of VV-4: a flash centred on a corner was diluted four times; two
// neighbouring blocks taking turns were never added up). The whole-frame window also carries a
// small picture (the floating card), where the 10° field is larger than the layer.
//
// ⭐ WHAT IT GUARANTEES, and the arithmetic behind it (WCAG 2.3.1, the numbers are `FlashGuard`'s):
// · A TRANSITION is a window's mean luminance moving `transitionThreshold` against its last
//   extreme (hysteresis, so a slow fade is one transition, not many). Before a window's first
//   transition it tracks its own lowest and highest value, so a strobe that starts mid-swing
//   counts from its first full swing. Two opposing transitions are a flash.
// · The threshold is the WCAG step over the share of a window a counted flash covers
//   (`regionCoverage`). A flash of the WCAG step that covers a quarter of some 2 × 2 window moves
//   it by at least that much, and a rectangle at least one cell wide and tall has such a window at
//   any offset (along each side some window takes in a whole cell's length of it).
// · When any one window holds `engageTransitions` (5) transitions inside one second, the gain
//   drops to `engagedGain` (0.05) on that frame. While engaged, no pixel the layer adds can move
//   by 0.05, which is half the WCAG step — so nothing it shows can be a flash at all.
// · Before it engages at most four transitions have passed, and the gain drop is ONE edge: five
//   transitions, two and a half flashes, in any second. Under the three WCAG allows.
// · While the gain is below 1 (engaged, or climbing back) it engages at one transition fewer, so
//   the climb's own rise plus a strobe that resumes during it still stays at five.
// · It climbs back only after `holdSeconds` with no window over the count, at `releasePerSecond`,
//   stepped through `FlashGuard.maxDelta` so a stall cannot turn the climb into one jump. A source
//   that goes on strobing never releases it.
//
// ⭐ IT KEEPS ITS OWN CLOCK. Each frame advances it by the source's elapsed time, clamped to
// `shortestFrameSeconds…longestFrameSeconds`; a time that does not increase — a seek or a loop on
// a media clock, a duplicate, NaN — advances it by the shortest frame. So a frame is never dropped
// from counting and the gain is never reset: a loop back into a strobe is counted as it plays
// (review of VV-4: the first version ignored such frames and played the second pass at full gain).
// Pass the DISPLAY clock when there is one; the clamp is what makes any other clock safe, in the
// direction of counting too much.
//
// ⚠️ WHAT IT IS NOT, so nobody reads more into it:
// · It caps the LAYER, not the screen. The generated field under it has its own budget
//   (`FlashGuard.fieldBudgets`); the sum of the two is a device probe, not a claim here.
// · It engages at two and a half flashes a second ON PURPOSE, below the three WCAG allows, to
//   leave room for its own edge. So legal footage flashing between about 2 and 3 Hz (beat lighting
//   at 120–180 BPM) is dimmed, and a pulse near 2 Hz can be, depending on frame timing and on how
//   unevenly it swings. That is the safe side; a steady flash at 1.9 Hz is never touched.
// · It ignores WCAG's dark-state exemption (two states both above 0.80 are not a flash): counting
//   them too is the safe direction, and a cap on a bright shimmer costs little.
// · It sees cell MEANS, not shapes: a flash spread thinner than a quarter of every window — a line
//   an eighth of a cell wide, a scatter of specks — counts only once its share of some window
//   reaches the threshold, where WCAG would count its area.
// · A grid finer than `maxCellsPerSide` is read through the whole-frame window only.
// · A new grid layout restarts every window but the whole frame; the gain is kept.
//
// Pure value type, Foundation only. One instance per playing layer; not on the audio thread.
// Guard: `UserFootageCannotStrobeTests`.

import Foundation

/// Caps the gain of a footage layer so what it adds cannot flash faster than WCAG allows.
public struct VideoFlashLimiter: Sendable {

    /// The share of one window a counted flash is assumed to cover (see the header).
    public static let regionCoverage = 0.25
    /// A window's move against its last extreme that counts as a transition: the WCAG step over
    /// the share of the window a counted flash covers.
    public static let transitionThreshold = FlashGuard.luminanceDeltaThreshold * regionCoverage
    /// Transitions inside one window of time, in any one window of the picture, that engage the
    /// cap. One fewer than the two-per-flash a WCAG-limit second holds, so the edge the cap
    /// itself makes still fits.
    public static let engageTransitions = Int(2 * FlashGuard.maxFlashHz) - 1
    /// The window transitions are counted in, in seconds.
    public static let windowSeconds = 1.0
    /// The gain while engaged: half the WCAG step, so no pixel the layer adds can move by a step.
    public static let engagedGain = FlashGuard.luminanceDeltaThreshold / 2
    /// Quiet time before the gain climbs back, in seconds.
    public static let holdSeconds = 1.0
    /// How fast the gain climbs back, per second (0.05 → 1 in about four seconds).
    public static let releasePerSecond = 0.25
    /// The least and the most one frame advances the limiter's own clock (see the header).
    public static let shortestFrameSeconds = 1.0 / 240
    public static let longestFrameSeconds = 0.25
    /// The finest grid read through the overlapping windows; a finer one is read whole-frame.
    public static let maxCellsPerSide = 16

    /// The gain to apply to the layer now, `engagedGain`…1.
    public private(set) var gain: Double = 1

    /// One window's hysteresis and the times of its last `engageTransitions` transitions.
    private struct Channel: Sendable {
        var seeded = false
        var extreme = 0.0
        var lowest = 0.0
        var highest = 0.0
        var direction = 0
        var times = [Double](repeating: -Double.infinity, count: VideoFlashLimiter.engageTransitions)
        var next = 0

        /// Whether `value` completes a transition (hysteresis against the extreme since the last
        /// one; before the first, against the lowest and highest seen).
        mutating func registers(_ value: Double) -> Bool {
            guard seeded else {
                seeded = true
                extreme = value
                lowest = value
                highest = value
                return false
            }
            let threshold = VideoFlashLimiter.transitionThreshold
            switch direction {
            case 1:
                if value > extreme { extreme = value; return false }
                guard value <= extreme - threshold else { return false }
                direction = -1
            case -1:
                if value < extreme { extreme = value; return false }
                guard value >= extreme + threshold else { return false }
                direction = 1
            default:
                lowest = Swift.min(lowest, value)
                highest = Swift.max(highest, value)
                guard highest - lowest >= threshold else { return false }
                direction = value >= highest ? 1 : -1
            }
            extreme = value
            return true
        }

        mutating func mark(_ time: Double) {
            times[next] = time
            next = (next + 1) % VideoFlashLimiter.engageTransitions
        }

        /// Transitions after `start` — counted in place, this runs on every drawn frame.
        func count(after start: Double) -> Int {
            times.reduce(0) { total, at in at > start ? total + 1 : total }
        }
    }

    private var side = 0
    private var windowCells: [[Int]] = []
    private var channels: [Channel] = []
    private var wholeFrame = Channel()
    private var started = false
    private var lastSourceTime: Double?
    private var clock = 0.0
    private var quietSince: Double?

    public init() {}

    /// Feeds one shown frame — `cells` are its cell luminances, 0…1, row-major in a
    /// `cellsPerSide × cellsPerSide` grid — and returns the gain. A grid of the wrong size changes
    /// nothing; a non-finite cell leaves out the windows it belongs to.
    @discardableResult
    public mutating func step(time: Double, cells: [Double], cellsPerSide: Int) -> Double {
        guard cellsPerSide > 0 else { return gain }
        let (cellCount, overflow) = cellsPerSide.multipliedReportingOverflow(by: cellsPerSide)
        guard !overflow, cells.count == cellCount else { return gain }
        let dt = advanceClock(to: time)
        if cellsPerSide != side { layOut(cellsPerSide) }

        let windowStart = clock - Self.windowSeconds
        let needed = gain < 1 ? Self.engageTransitions - 1 : Self.engageTransitions
        var busiest = 0

        var frameSum = 0.0
        var finiteCells = 0
        for value in cells where value.isFinite {
            frameSum += Swift.min(1, Swift.max(0, value))
            finiteCells += 1
        }
        if finiteCells > 0 {
            if wholeFrame.registers(frameSum / Double(finiteCells)) { wholeFrame.mark(clock) }
            busiest = Swift.max(busiest, wholeFrame.count(after: windowStart))
        }
        for index in channels.indices {
            var windowSum = 0.0
            var usable = true
            for cell in windowCells[index] {
                let value = cells[cell]
                guard value.isFinite else { usable = false; break }
                windowSum += Swift.min(1, Swift.max(0, value))
            }
            guard usable else { continue }
            if channels[index].registers(windowSum / Double(windowCells[index].count)) {
                channels[index].mark(clock)
            }
            busiest = Swift.max(busiest, channels[index].count(after: windowStart))
        }

        if busiest >= needed {
            gain = Self.engagedGain
            quietSince = nil
        } else {
            let since = quietSince ?? clock
            quietSince = since
            if clock - since >= Self.holdSeconds, gain < 1 {
                gain = Swift.min(1, gain + FlashGuard.maxDelta(perSecond: Self.releasePerSecond, dt: dt))
            }
        }
        return gain
    }

    /// Advances the limiter's own clock for one frame and returns by how much (see the header).
    private mutating func advanceClock(to time: Double) -> Double {
        guard started else {
            started = true
            if time.isFinite { lastSourceTime = time }
            return 0
        }
        var dt = Self.shortestFrameSeconds
        if time.isFinite, let last = lastSourceTime, time > last {
            dt = Swift.min(Swift.max(time - last, Self.shortestFrameSeconds), Self.longestFrameSeconds)
        }
        if time.isFinite { lastSourceTime = time }
        clock += dt
        return dt
    }

    /// Builds the overlapping windows for a new grid. The whole-frame window is kept.
    private mutating func layOut(_ cellsPerSide: Int) {
        side = cellsPerSide
        var windows: [[Int]] = []
        var size = 2
        while size < cellsPerSide, cellsPerSide <= Self.maxCellsPerSide {
            let hop = size / 2
            var origins = Array(Swift.stride(from: 0, through: cellsPerSide - size, by: hop))
            if let last = origins.last, last != cellsPerSide - size { origins.append(cellsPerSide - size) }
            for row in origins {
                for column in origins {
                    var members: [Int] = []
                    members.reserveCapacity(size * size)
                    for r in row..<(row + size) {
                        for c in column..<(column + size) { members.append(r * cellsPerSide + c) }
                    }
                    windows.append(members)
                }
            }
            size *= 2
        }
        windowCells = windows
        channels = Array(repeating: Channel(), count: windows.count)
    }
}

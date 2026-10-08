// VideoFlashLimiter.swift
// Echoel — GMMW VV-4 (founder 2026-10-08, "own footage inside own engine"): the law gate that comes
// BEFORE any door shows a person's own video in the visuals. `FlashGuard` budgets the GENERATED
// looks — each one's flash rate is derived from its shader — but footage is not ours: a clip can
// hold a strobe, a lightning storm or a club light at 10 Hz, and no budget written in advance can
// cover it. The seed reader samples at most four frames a second, so it cannot certify a strobe
// either. This type watches the frames that are actually SHOWN and caps the layer's gain.
//
// ⭐ WHAT IT WATCHES. The caller hands a grid of CELL luminances (`VideoLayerMath.regionMeans`,
// 8 × 8 by `VideoLayerMath.flashCellsPerSide`). Every channel below is a hysteresis on one signal,
// and the cap engages when any one of them holds `engageTransitions` (5) inside one second:
// · WINDOWS on the footage: every 2 × 2 and 4 × 4 square of cells at half its own stride (so they
//   overlap) and the whole frame, at a quarter of the WCAG step. A WCAG flash counts when the
//   flashing area within any one 10° field is large enough, and that field can sit anywhere — on a
//   block corner, across two blocks (review of VV-4: fixed blocks diluted a corner flash four times
//   and never added up two neighbours taking turns). The whole frame also carries a small picture
//   (the floating card), where the 10° field is larger than the layer.
// · CELLS on the footage, each at the whole step. A window adds its cells up, so cells swinging
//   AGAINST each other cancel in it — a checkerboard or one-cell stripes reversing at 10 Hz never
//   moved a single window (second review of VV-4). A cell alone cannot cancel.
// · CELLS as SHOWN — the gain the layer has now times the cell — at the whole step: the viewer's own
//   count. The gain moves too, and only these channels see what that does: the climb back is a rise
//   of its own, and it turns footage that keeps falling (one movement to every footage channel) into
//   a fall, a rise and a fall on the screen (second review: six transitions in a second, which no
//   lowered count on the footage could catch — the first draft of this fix had one and still showed
//   six).
//
// ⭐ WHAT IT GUARANTEES, and the arithmetic behind it (WCAG 2.3.1, the numbers are `FlashGuard`'s):
// · A TRANSITION is a channel's signal moving its step against its last extreme (hysteresis, so a
//   slow fade is one transition, not many); before its first, against its own lowest and highest, so
//   a strobe that starts mid-swing counts from its first full swing. Two opposing ones are a flash.
//   Every step carries `roundingAllowance`, so a move of exactly the step counts. A direction whose
//   last transition is a whole second old is forgotten, its extreme kept as the reference: a step off
//   a level settled long ago is a change of its own, not the rest of a rise that ended before the
//   counting window (second review: such a step started a strobe uncounted, and six showed).
// · When any channel holds five transitions inside one second, the gain drops to `engagedGain`
//   (0.05) on that frame. While engaged no pixel the layer adds can move by 0.05, half the WCAG
//   step — nothing it shows can be a flash at all.
// · A flash covering any rectangle at least two cells wide and tall covers some cell completely, and
//   that cell's shown channel counts what is shown there — with the gain of the frame before, so at
//   most one climb step behind. So at most five transitions show in any second, two and a half
//   flashes, under the three WCAG allows — the cap's own edge included. That is the argument; the
//   transcription measured it too, at five, over the review's inputs and random and directed ones.
//   A smaller flash is counted on the footage only (a quarter of a 2 × 2 window at a quarter step:
//   over-counted, the safe side), not on the shown signal.
// · It climbs back only after `holdSeconds` with no channel at the count, at `releasePerSecond`,
//   stepped through `FlashGuard.maxDelta` and only on a frame that advanced its clock, so neither a
//   stall nor a repeated frame turns the climb into a jump. A source that goes on strobing never
//   releases it; a slower flash after a strobe does (the first version held a 1.9 Hz flash at 0.05
//   for good, because it engaged at four while the gain was below 1).
//
// ⭐ IT KEEPS ITS OWN CLOCK. Each frame advances it by the source's elapsed time, clamped to
// `shortestFrameSeconds…longestFrameSeconds`. A REPEATED time advances it by nothing — a 24 fps clip
// on a 120 Hz display passes each media time five times, and the first version's 1/240 s for each
// repeat ran its clock 40 % fast, so a 2.6 Hz flash read as under the count and played uncapped
// (second review). A time that goes BACK — a seek or a loop on a media clock — or NaN advances it by
// the shortest frame: a frame is never dropped from counting and the gain is never reset, so a loop
// back into a strobe is counted as it plays.
// ⚠️ PASS THE DISPLAY CLOCK. A media clock is read at rate 1: at a faster playback rate every
// frequency looks slower by that rate and the limiter counts too little. The door (VV-6) inherits
// this as a requirement, not a preference.
//
// ⚠️ WHAT IT IS NOT, so nobody reads more into it:
// · It caps the LAYER, not the screen. The generated field under it has its own budget
//   (`FlashGuard.fieldBudgets`); the sum of the two is a device probe, not a claim here.
// · It engages at two and a half flashes a second ON PURPOSE, below the three WCAG allows, to
//   leave room for its own edge. So legal footage flashing between about 2 and 3 Hz (beat lighting
//   at 120–180 BPM) is dimmed, and a pulse near 2 Hz can be, depending on frame timing and on how
//   unevenly it swings. That is the safe side; a steady flash at 1.9 Hz is never touched.
// · The windows' quarter step dims some LEGAL footage on the same side: a whole-picture flicker of
//   a quarter step or more at 2.5 Hz and faster (measured: 0.02 untouched, 0.025 capped), a
//   high-contrast edge shaken by a fraction of a cell, a textured pan of about half a picture width a
//   second. A single edge panning across is one transition per cell at any speed and is never
//   touched.
// · It ignores WCAG's dark-state exemption (two states both above 0.80 are not a flash): counting
//   them too is the safe direction, and a cap on a bright shimmer costs little.
// · It sees cell MEANS, not shapes: a pattern with a period of two cells set half a cell off the
//   grid keeps every cell mean flat while it reverses, and the grid cannot see it at all; a line an
//   eighth of a cell wide counts only once its share of some window reaches the quarter step.
// · A grid finer than `maxCellsPerSide` is read through the whole-frame window only.
// · A new grid layout restarts every channel but the whole frame; the gain is kept.
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
    /// A cell's move that counts as a transition, on the footage and as shown: the whole WCAG step.
    public static let cellTransitionThreshold = FlashGuard.luminanceDeltaThreshold
    /// Taken off every step so a move of exactly the step counts: `0.4 - 0.3` is a hair under the
    /// step in binary floating point, and the first version missed such a flash on some levels.
    public static let roundingAllowance = 1e-9
    /// Transitions inside one window of time, in any one channel, that engage the cap. One fewer
    /// than the two-per-flash a WCAG-limit second holds, so the edge the cap itself makes still fits.
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

    /// One signal's hysteresis and the times of its last `engageTransitions` transitions.
    private struct Channel: Sendable {
        let threshold: Double
        var seeded = false
        var extreme = 0.0
        var lowest = 0.0
        var highest = 0.0
        var direction = 0
        var times = [Double](repeating: -Double.infinity, count: VideoFlashLimiter.engageTransitions)
        var next = 0

        init(step: Double) {
            threshold = step * (1 - VideoFlashLimiter.roundingAllowance)
        }

        /// Whether `value`, seen at `now`, completes a transition (hysteresis against the extreme
        /// since the last one; before the first, against the lowest and highest seen). A direction
        /// whose last transition is a whole counting window old is forgotten, its extreme kept as
        /// the reference — so a step off a level settled long ago is a change of its own.
        mutating func registers(_ value: Double, at now: Double) -> Bool {
            let last = times[(next + VideoFlashLimiter.engageTransitions - 1) % VideoFlashLimiter.engageTransitions]
            if direction != 0, last <= now - VideoFlashLimiter.windowSeconds {
                direction = 0
                lowest = extreme
                highest = extreme
            }
            guard seeded else {
                seeded = true
                extreme = value
                lowest = value
                highest = value
                return false
            }
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
    private var cellChannels: [Channel] = []
    private var shownChannels: [Channel] = []
    private var wholeFrame = Channel(step: VideoFlashLimiter.transitionThreshold)
    private var started = false
    private var lastSourceTime: Double?
    private var clock = 0.0
    private var quietSince: Double?

    public init() {}

    /// Feeds one shown frame — `cells` are its cell luminances, 0…1, row-major in a
    /// `cellsPerSide × cellsPerSide` grid — and returns the gain. A grid of the wrong size changes
    /// nothing; a non-finite cell leaves out its own two channels and the windows it belongs to.
    @discardableResult
    public mutating func step(time: Double, cells: [Double], cellsPerSide: Int) -> Double {
        guard cellsPerSide > 0 else { return gain }
        let (cellCount, overflow) = cellsPerSide.multipliedReportingOverflow(by: cellsPerSide)
        guard !overflow, cells.count == cellCount else { return gain }
        let dt = advanceClock(to: time)
        if cellsPerSide != side { layOut(cellsPerSide) }

        let windowStart = clock - Self.windowSeconds
        var busiest = 0

        var frameSum = 0.0
        var finiteCells = 0
        for value in cells where value.isFinite {
            frameSum += Swift.min(1, Swift.max(0, value))
            finiteCells += 1
        }
        if finiteCells > 0 {
            if wholeFrame.registers(frameSum / Double(finiteCells), at: clock) { wholeFrame.mark(clock) }
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
            if channels[index].registers(windowSum / Double(windowCells[index].count), at: clock) {
                channels[index].mark(clock)
            }
            busiest = Swift.max(busiest, channels[index].count(after: windowStart))
        }
        for cell in cellChannels.indices {
            let value = cells[cell]
            guard value.isFinite else { continue }
            let level = Swift.min(1, Swift.max(0, value))
            if cellChannels[cell].registers(level, at: clock) { cellChannels[cell].mark(clock) }
            // What this cell shows with the gain the layer has now — before this frame decides.
            if shownChannels[cell].registers(gain * level, at: clock) { shownChannels[cell].mark(clock) }
            busiest = Swift.max(busiest, cellChannels[cell].count(after: windowStart),
                                shownChannels[cell].count(after: windowStart))
        }

        if busiest >= Self.engageTransitions {
            gain = Self.engagedGain
            quietSince = nil
        } else {
            let since = quietSince ?? clock
            quietSince = since
            if clock - since >= Self.holdSeconds, gain < 1, dt > 0 {
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
        if time.isFinite, let last = lastSourceTime {
            if time > last {
                dt = Swift.min(Swift.max(time - last, Self.shortestFrameSeconds), Self.longestFrameSeconds)
            } else if time == last {
                dt = 0
            }
        }
        if time.isFinite { lastSourceTime = time }
        clock += dt
        return dt
    }

    /// Builds the overlapping windows and the cell channels for a new grid. The whole frame is kept.
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
        channels = Array(repeating: Channel(step: Self.transitionThreshold), count: windows.count)
        let cellCount = cellsPerSide <= Self.maxCellsPerSide ? cellsPerSide * cellsPerSide : 0
        cellChannels = Array(repeating: Channel(step: Self.cellTransitionThreshold), count: cellCount)
        shownChannels = cellChannels
    }
}

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
// · RED, on the same windows and cells (VV-4c, Mistral 2026-10-12, verified 6/6): WCAG 2.3.1 counts
//   a second kind of flash, saturated red, that a luminance count cannot see — a swing between a
//   saturated red and a grey of nearly the same luminance moves the luminance by under a tenth of
//   the step. The caller also hands each cell's `VideoLayerMath.redFlashSignal` (linear R − G − B,
//   floored at 0); every channel above runs again on it, at WCAG's red step (20/320) where the
//   luminance has its own, and the windows at a quarter of it. The red signal is 0 wherever red does
//   not exceed green plus blue, so a grey, a white or a green never moves it.
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
//   (a quarter of the red step) on that frame. The shader composites the layer as a SCREEN,
//   F + gain·L·(1 − F) per channel: the shown luminance moves by at most the gain, the shown
//   R − G − B (three channels, unfloored over a reddish field) by at most 3·gain − 2·gain², and the
//   last quarter of the step is room for the drawable's 8-bit rounding. While engaged nothing it
//   shows can be a flash at all. (VV-4d: at the first engaged gain, 0.05, a capped red/cyan strobe
//   over a dark-red field still showed a red swing of 0.145 — 46 against WCAG's 20.)
// · A flash covering any rectangle at least two cells wide and tall covers some cell completely, and
//   that cell's shown channel counts what is shown there (its red shown channel too, which counts
//   gain × the footage's OWN red signal — see WHAT IT IS NOT for the field under it) — with the gain of the frame before, so at
//   most one climb step behind. So at most five transitions show in any second, two and a half
//   flashes, under the three WCAG allows — the cap's own edge included. That is the argument; the
//   transcription measured it too, at five, over the review's inputs and random and directed ones.
//   A smaller flash is counted on the footage only (a quarter of a 2 × 2 window at a quarter step:
//   over-counted, the safe side), not on the shown signal.
// · It climbs back only after `holdSeconds` with no channel at the count, at `releasePerSecond`,
//   stepped through `FlashGuard.maxDelta` and only on a frame that advanced its clock, so neither a
//   stall nor a repeated frame turns the climb into a jump. A source that goes on strobing never
//   releases it; a slower flash after a strobe does (the first version held a 1.9 Hz flash at its then
//   engaged gain, 0.05, for good, because it engaged at four while the gain was below 1).
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
// · ⚠️ OPEN (VV-4e): the red count reads the footage's own R − G − B. Over a reddish field the
//   layer's GREEN and BLUE swings show as red swings too — a footage flicker between black and a
//   dim blue moves neither its luminance windows nor its red signal, so the gain stays at 1, while
//   the shown R − G − B over the field swings by the blue's full amount. Lowering the engaged gain
//   does not touch this; the cap never engages. Closed only by counting the field's colour or a
//   per-channel bound.
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
// · It ignores the red flash's saturation test (one state at R/(R+G+B) ≥ 0.8): every move of R − G − B
//   by the red step counts, a strong orange or pink one too — the safe direction again.
// · It sees cell MEANS, not shapes: a pattern with a period of two cells set half a cell off the
//   grid keeps every cell mean flat while it reverses, and the grid cannot see it at all; a line an
//   eighth of a cell wide counts only once its share of some window reaches the quarter step.
// · It trusts the cells it is handed. `VideoLayerSlot` (VV-5b) estimates each from 2 × 2 point
//   samples half a cell apart, not the true mean: a flash smaller than about half a cell can fall
//   between the points, and a fine texture can alias either way.
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
    /// WCAG 2.3.1's red flash: a change of `(R − G − B) × 320` above 20, in linear RGB — so a
    /// change of 20/320 in `VideoLayerMath.redFlashSignal`. Counted on cells and as shown.
    public static let redCellTransitionThreshold = 20.0 / 320.0
    /// The red step over the share of a window a counted flash covers, as for the luminance.
    public static let redTransitionThreshold = redCellTransitionThreshold * regionCoverage
    /// Taken off every step so a move of exactly the step counts: `0.4 - 0.3` is a hair under the
    /// step in binary floating point, and the first version missed such a flash on some levels.
    public static let roundingAllowance = 1e-9
    /// Transitions inside one window of time, in any one channel, that engage the cap. One fewer
    /// than the two-per-flash a WCAG-limit second holds, so the edge the cap itself makes still fits.
    public static let engageTransitions = Int(2 * FlashGuard.maxFlashHz) - 1
    /// The window transitions are counted in, in seconds.
    public static let windowSeconds = 1.0
    /// The gain while engaged: a quarter of the red step. The shader composites the layer as a
    /// SCREEN, so the shown red signal (three channels summed) can swing 3·gain − 2·gain²; the
    /// fourth share is room for the drawable's 8-bit sRGB rounding. Luminance moves by at most gain.
    public static let engagedGain = redCellTransitionThreshold / 4
    /// Quiet time before the gain climbs back, in seconds.
    public static let holdSeconds = 1.0
    /// How fast the gain climbs back, per second (`engagedGain` → 1 in about four seconds).
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

    /// Every channel one signal needs: the whole frame and the windows at their step, the cells on
    /// the footage and as shown at theirs. The luminance and the red signal each own one.
    private struct Signal: Sendable {
        let windowStep: Double
        let cellStep: Double
        var wholeFrame: Channel
        var windows: [Channel] = []
        var cells: [Channel] = []
        var shown: [Channel] = []

        init(windowStep: Double, cellStep: Double) {
            self.windowStep = windowStep
            self.cellStep = cellStep
            wholeFrame = Channel(step: windowStep)
        }

        /// A new grid restarts every channel but the whole frame.
        mutating func layOut(windowCount: Int, cellCount: Int) {
            windows = Array(repeating: Channel(step: windowStep), count: windowCount)
            cells = Array(repeating: Channel(step: cellStep), count: cellCount)
            shown = cells
        }

        /// Feeds one frame's cells (already the right count) and returns the most transitions any of
        /// this signal's channels holds after `windowStart`. `gain` is the layer's gain before this
        /// frame decides: the shown channels count what the screen shows with it.
        mutating func feed(_ values: [Double], windowCells: [[Int]], gain: Double,
                           at clock: Double, after windowStart: Double) -> Int {
            var busiest = 0
            var frameSum = 0.0
            var finiteCells = 0
            for value in values where value.isFinite {
                frameSum += Swift.min(1, Swift.max(0, value))
                finiteCells += 1
            }
            if finiteCells > 0 {
                if wholeFrame.registers(frameSum / Double(finiteCells), at: clock) { wholeFrame.mark(clock) }
                busiest = Swift.max(busiest, wholeFrame.count(after: windowStart))
            }
            for index in windows.indices {
                var windowSum = 0.0
                var usable = true
                for cell in windowCells[index] {
                    let value = values[cell]
                    guard value.isFinite else { usable = false; break }
                    windowSum += Swift.min(1, Swift.max(0, value))
                }
                guard usable else { continue }
                if windows[index].registers(windowSum / Double(windowCells[index].count), at: clock) {
                    windows[index].mark(clock)
                }
                busiest = Swift.max(busiest, windows[index].count(after: windowStart))
            }
            for cell in cells.indices {
                let value = values[cell]
                guard value.isFinite else { continue }
                let level = Swift.min(1, Swift.max(0, value))
                if cells[cell].registers(level, at: clock) { cells[cell].mark(clock) }
                // What this cell shows with the gain the layer has now — before this frame decides.
                if shown[cell].registers(gain * level, at: clock) { shown[cell].mark(clock) }
                busiest = Swift.max(busiest, cells[cell].count(after: windowStart),
                                    shown[cell].count(after: windowStart))
            }
            return busiest
        }
    }

    private var side = 0
    private var windowCells: [[Int]] = []
    private var luminance = Signal(windowStep: VideoFlashLimiter.transitionThreshold,
                                   cellStep: VideoFlashLimiter.cellTransitionThreshold)
    private var red = Signal(windowStep: VideoFlashLimiter.redTransitionThreshold,
                             cellStep: VideoFlashLimiter.redCellTransitionThreshold)
    private var started = false
    private var lastSourceTime: Double?
    private var clock = 0.0
    private var quietSince: Double?

    public init() {}

    /// Feeds one shown frame and returns the gain. `cells` are its cell luminances, 0…1, row-major in
    /// a `cellsPerSide × cellsPerSide` grid; `redCells` the same cells' red signal
    /// (`VideoLayerMath.redFlashSignal`), or nil where the caller has no colour — then only the
    /// luminance counts, and a footage door must never pass nil (`UserFootageCannotStrobeTests`).
    /// A luminance grid of the wrong size changes nothing; a red grid of the wrong size is left out
    /// and the luminance still counts. A non-finite cell leaves out its own channels and the windows
    /// it belongs to.
    @discardableResult
    public mutating func step(time: Double, cells: [Double], redCells: [Double]?, cellsPerSide: Int) -> Double {
        guard cellsPerSide > 0 else { return gain }
        let (cellCount, overflow) = cellsPerSide.multipliedReportingOverflow(by: cellsPerSide)
        guard !overflow, cells.count == cellCount else { return gain }
        let dt = advanceClock(to: time)
        if cellsPerSide != side { layOut(cellsPerSide) }

        let windowStart = clock - Self.windowSeconds
        var busiest = luminance.feed(cells, windowCells: windowCells, gain: gain,
                                     at: clock, after: windowStart)
        if let redCells, redCells.count == cellCount {
            busiest = Swift.max(busiest, red.feed(redCells, windowCells: windowCells, gain: gain,
                                                  at: clock, after: windowStart))
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

    /// Builds the overlapping windows and both signals' cell channels for a new grid. Both whole
    /// frames are kept.
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
        let cellCount = cellsPerSide <= Self.maxCellsPerSide ? cellsPerSide * cellsPerSide : 0
        luminance.layOut(windowCount: windows.count, cellCount: cellCount)
        red.layOut(windowCount: windows.count, cellCount: cellCount)
    }
}

import Foundation

/// The guard against flashing for footage (WCAG 2.3.1: no more than three flashes a second).
/// `FlashLimit` bounds what Echoel draws itself, because it knows how fast its own pictures can
/// move. Footage is not ours: a clip can hold a strobe, lightning or a club light at 10 Hz, and no
/// rate written in advance covers it. This type watches the frames that are actually shown and
/// answers the gain the footage may be shown at — 1 while nothing flashes, `engagedGain` while
/// something does. Ported from the earlier app's limiter with its arithmetic unchanged.
///
/// **What it watches.** The caller hands one frame as a grid of cell means (`cellsPerSide` a
/// side, row by row): the relative luminance, and — where it has them — the red signal and the
/// linear red, green and blue. Every channel below is a hysteresis on one signal, and the cap
/// engages when any one of them holds `engageTransitions` (5) inside one second:
/// - **Windows** on the footage: every 2 × 2 and 4 × 4 square of cells at half its own stride, so
///   they overlap, and the whole frame — at a quarter of the WCAG step, because a flash counts
///   when it fills a quarter of some field of view, and that field can sit anywhere.
/// - **Cells** on the footage, each at the whole step. A window adds its cells up, so cells
///   swinging against each other cancel in it (a checkerboard reversing); a cell alone cannot.
/// - **Cells as shown** — the gain the footage has now times the cell: the viewer's own count,
///   which also sees what the moving gain itself does.
/// - **Red**, on the same windows and cells: WCAG counts a second kind of flash, saturated red,
///   that luminance cannot see. It runs on the red signal at WCAG's red step (20/320).
/// - **Color**, on the same windows and cells at the red steps, and only where the caller hands
///   the color cells over — while another picture is drawn with the footage. Over a reddish
///   picture a blue or green swing moves the shown red signal while the footage's own stays 0.
///   This type never sees that picture, so it bounds every such picture at once with the seven
///   sums in `colorCombinations`. They count every color, grey too, at the red steps: a whole
///   frame moving by one stored level is a transition to them. That is the safe side over a
///   picture nobody measured, and wrong for footage shown by itself.
///
/// **What it guarantees.** A transition is a signal moving its step against its last extreme, so a
/// slow fade is one transition, not many. Five inside one second drop the gain to `engagedGain`
/// on that frame, which is so low that nothing shown through it can be a flash at all. So at most
/// five transitions show in any second — two and a half flashes, under the three WCAG allows, the
/// cap's own edge included. The gain climbs back only after `holdSeconds` with no channel at the
/// count, at `releasePerSecond`, and only on a frame that advanced the clock; footage that goes on
/// strobing never releases it.
///
/// **Its own clock.** Each frame advances it by the source's elapsed time, held between
/// `shortestFrameSeconds` and `longestFrameSeconds`. A repeated time advances it by nothing (a
/// 24-frame clip on a 120 Hz display passes each time five times). A time that goes back — a seek,
/// a loop — or is no number advances it by the shortest frame: no frame is dropped from the count
/// and the gain is never reset, so a loop back into a strobe is counted as it plays. Hand it the
/// display's clock: at a faster playback rate a media clock makes every flash look slower.
///
/// **What it is not.** It caps the footage, not the screen; the Field over it has `FlashLimit`.
/// It engages at two and a half flashes a second on purpose, so legal footage flashing between
/// about 2 and 3 Hz is dimmed too — the safe side; a steady flash at 1.9 Hz is never touched. It
/// sees cell means, not shapes: a flash much smaller than a cell can pass. Without color cells
/// only the luminance and the footage's own red count.
///
/// A value type with no clock and no allocation after the first frame of a grid; one per shown
/// picture, never on the render thread.
public struct VideoFlashLimit: Sendable {
    /// The grid a caller measures a frame in, cells a side.
    public static let cellsPerSide = 8
    /// The share of one window a counted flash is assumed to cover.
    public static let regionCoverage = 0.25
    /// A window's move against its last extreme that counts as a transition.
    public static let windowStep = FlashLimit.generalFlashThreshold * regionCoverage
    /// A cell's move that counts as a transition, on the footage and as shown: the WCAG step.
    public static let cellStep = FlashLimit.generalFlashThreshold
    /// WCAG's red flash: a change of (R − G − B) × 320 above 20, in linear light.
    public static let redCellStep = 20.0 / 320.0
    /// The red step over the share of a window a counted flash covers.
    public static let redWindowStep = redCellStep * regionCoverage
    /// Taken off every step, so a move of exactly the step counts in binary floating point.
    public static let roundingAllowance = 1e-9
    /// Transitions inside one second, in any one channel, that engage the cap: one fewer than a
    /// second at WCAG's limit holds, so the edge the cap itself makes still fits.
    public static let engageTransitions = Int(2 * FlashLimit.flashesPerSecond) - 1
    /// The time transitions are counted in, in seconds.
    public static let windowSeconds = 1.0
    /// The gain while engaged: a quarter of the red step. Footage blended over a picture as a
    /// screen can swing the shown red signal by 3·gain − 2·gain², which stays under the red step
    /// with room for a display's rounding; the luminance moves by at most the gain.
    public static let engagedGain = redCellStep / 4
    /// Quiet time before the gain climbs back, in seconds.
    public static let holdSeconds = 1.0
    /// How fast the gain climbs back, per second: about four seconds from engaged to 1.
    public static let releasePerSecond = 0.25
    /// The least and the most one frame advances the clock.
    public static let shortestFrameSeconds = 1.0 / 240
    public static let longestFrameSeconds = 0.25
    /// The finest grid read through the overlapping windows; a finer one is read whole-frame only.
    public static let maxCellsPerSide = 16

    /// The gain to show the footage at now, `engagedGain` … 1.
    public private(set) var gain: Double = 1

    /// One frame's cell means of linear red, green and blue, each 0 … 1, in the luminance's grid.
    public struct ColorCells: Sendable {
        public var red: [Double]
        public var green: [Double]
        public var blue: [Double]

        public init(red: [Double], green: [Double], blue: [Double]) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// One way footage can move the shown red signal over a picture under it: the weights of
    /// linear red, green and blue, and the range the sum can take.
    public struct ColorCombination: Sendable, Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let lowest: Double
        public let span: Double
    }

    /// The seven sums that bound what footage adds to the shown red signal over any picture.
    public static let colorCombinations: [ColorCombination] = [
        ColorCombination(red: 1, green: 0, blue: 0, lowest: 0, span: 1),
        ColorCombination(red: 0, green: -1, blue: 0, lowest: -1, span: 1),
        ColorCombination(red: 0, green: 0, blue: -1, lowest: -1, span: 1),
        ColorCombination(red: 1, green: -1, blue: 0, lowest: -1, span: 2),
        ColorCombination(red: 1, green: 0, blue: -1, lowest: -1, span: 2),
        ColorCombination(red: 0, green: -1, blue: -1, lowest: -2, span: 2),
        ColorCombination(red: 1, green: -1, blue: -1, lowest: -2, span: 3),
    ]

    // MARK: A frame's measures

    /// One sRGB component, 0 … 1, as linear light. A value that is no number reads as 0.
    public static func linear(_ component: Double) -> Double {
        let bounded = component.isFinite ? Swift.min(1, Swift.max(0, component)) : 0
        return bounded <= 0.04045 ? bounded / 12.92 : Foundation.pow((bounded + 0.055) / 1.055, 2.4)
    }

    /// WCAG's relative luminance of an sRGB color whose components are 0 … 1.
    public static func luminance(red: Double, green: Double, blue: Double) -> Double {
        let redPart: Double = 0.2126 * linear(red)
        let greenPart: Double = 0.7152 * linear(green)
        let bluePart: Double = 0.0722 * linear(blue)
        return Swift.min(1, redPart + greenPart + bluePart)
    }

    /// WCAG's red signal of an sRGB color: linear R − G − B, never under 0.
    public static func redSignal(red: Double, green: Double, blue: Double) -> Double {
        Swift.max(0, linear(red) - linear(green) - linear(blue))
    }

    // MARK: Channels

    /// One signal's hysteresis and the times of its last `engageTransitions` transitions.
    private struct Channel: Sendable {
        let threshold: Double
        var seeded = false
        var extreme = 0.0
        var lowest = 0.0
        var highest = 0.0
        var direction = 0
        var times = [Double](repeating: -Double.infinity, count: VideoFlashLimit.engageTransitions)
        var next = 0

        init(step: Double) {
            threshold = step * (1 - VideoFlashLimit.roundingAllowance)
        }

        /// Whether `value`, seen at `now`, completes a transition: a move of the step against the
        /// extreme since the last one; before the first, against the lowest and highest seen. A
        /// direction whose last transition is a whole second old is forgotten, its extreme kept as
        /// the reference — a step off a level settled long ago is a change of its own.
        mutating func registers(_ value: Double, at now: Double) -> Bool {
            let capacity = VideoFlashLimit.engageTransitions
            let last = times[(next + capacity - 1) % capacity]
            if direction != 0, last <= now - VideoFlashLimit.windowSeconds {
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
                if value > extreme {
                    extreme = value
                    return false
                }
                guard value <= extreme - threshold else { return false }
                direction = -1
            case -1:
                if value < extreme {
                    extreme = value
                    return false
                }
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
            next = (next + 1) % VideoFlashLimit.engageTransitions
        }

        /// Transitions after `start`, counted in place.
        func count(after start: Double) -> Int {
            var total = 0
            for time in times where time > start { total += 1 }
            return total
        }
    }

    /// Every channel one signal needs: the whole frame and the windows at their step, the cells on
    /// the footage and as shown at theirs. A value is held to `lowest … lowest + span` and read as
    /// its share of the span, so every step is divided by the span too.
    private struct Signal: Sendable {
        let windowStep: Double
        let cellStep: Double
        let lowest: Double
        let span: Double
        var wholeFrame: Channel
        var windows: [Channel] = []
        var cells: [Channel] = []
        var shown: [Channel] = []

        init(windowStep: Double, cellStep: Double, lowest: Double, span: Double) {
            self.windowStep = windowStep / span
            self.cellStep = cellStep / span
            self.lowest = lowest
            self.span = span
            wholeFrame = Channel(step: windowStep / span)
        }

        private func bounded(_ value: Double) -> Double {
            Swift.min(lowest + span, Swift.max(lowest, value))
        }

        private func share(_ value: Double) -> Double {
            (value - lowest) / span
        }

        /// A new grid starts every channel again but the whole frame's.
        mutating func layOut(windowCount: Int, cellCount: Int) {
            windows = Array(repeating: Channel(step: windowStep), count: windowCount)
            cells = Array(repeating: Channel(step: cellStep), count: cellCount)
            shown = cells
        }

        /// Takes one frame's cells and answers the most transitions any of this signal's channels
        /// holds after `windowStart`. `gain` is the footage's gain before this frame decides: the
        /// shown channels count what the screen shows with it.
        mutating func feed(_ values: [Double], windowCells: [[Int]], gain: Double,
                           at clock: Double, after windowStart: Double) -> Int {
            var busiest = 0
            var frameSum = 0.0
            var finiteCells = 0
            for value in values where value.isFinite {
                frameSum += share(bounded(value))
                finiteCells += 1
            }
            if finiteCells > 0 {
                if wholeFrame.registers(frameSum / Double(finiteCells), at: clock) { wholeFrame.mark(clock) }
                busiest = Swift.max(busiest, wholeFrame.count(after: windowStart))
            }
            for index in windows.indices {
                let members = windowCells[index]
                var windowSum = 0.0
                var usable = !members.isEmpty
                for cell in members {
                    let value = values[cell]
                    guard value.isFinite else {
                        usable = false
                        break
                    }
                    windowSum += share(bounded(value))
                }
                guard usable else { continue }
                if windows[index].registers(windowSum / Double(members.count), at: clock) {
                    windows[index].mark(clock)
                }
                busiest = Swift.max(busiest, windows[index].count(after: windowStart))
            }
            for cell in cells.indices {
                let value = values[cell]
                guard value.isFinite else { continue }
                let level = bounded(value)
                if cells[cell].registers(share(level), at: clock) { cells[cell].mark(clock) }
                // What this cell shows with the gain the footage has now. The gain scales the
                // value, not its share: every span holds 0, so `gain * level` stays inside it.
                if shown[cell].registers(share(gain * level), at: clock) { shown[cell].mark(clock) }
                let cellCount = cells[cell].count(after: windowStart)
                let shownCount = shown[cell].count(after: windowStart)
                busiest = Swift.max(busiest, Swift.max(cellCount, shownCount))
            }
            return busiest
        }
    }

    private var side = 0
    private var windowCells: [[Int]] = []
    private var luminance = Signal(windowStep: VideoFlashLimit.windowStep,
                                   cellStep: VideoFlashLimit.cellStep, lowest: 0, span: 1)
    private var red = Signal(windowStep: VideoFlashLimit.redWindowStep,
                             cellStep: VideoFlashLimit.redCellStep, lowest: 0, span: 1)
    private var color: [Signal] = VideoFlashLimit.colorCombinations.map { (combination: ColorCombination) -> Signal in
        Signal(windowStep: VideoFlashLimit.redWindowStep, cellStep: VideoFlashLimit.redCellStep,
               lowest: combination.lowest, span: combination.span)
    }
    /// One color sum's cells, reused by every frame.
    private var colorSum: [Double] = []
    private var started = false
    private var lastSourceTime: Double?
    private var clock = 0.0
    private var quietSince: Double?

    public init() {}

    // MARK: A frame

    /// Takes one shown frame and answers the gain. `cells` are its cell luminances, 0 … 1, row by
    /// row in a `cellsPerSide × cellsPerSide` grid; `redCells` the same cells' red signal and
    /// `colorCells` their linear red, green and blue, or nil where the caller has none — then only
    /// the luminance counts. A luminance grid of the wrong size changes nothing; a red or color
    /// grid of the wrong size is left out and the luminance still counts. A cell that is no number
    /// leaves out its own channels and the windows it belongs to.
    @discardableResult
    public mutating func next(time: Double, cells: [Double], redCells: [Double]? = nil,
                              colorCells: ColorCells? = nil, cellsPerSide: Int) -> Double {
        guard cellsPerSide > 0 else { return gain }
        let (cellCount, overflow) = cellsPerSide.multipliedReportingOverflow(by: cellsPerSide)
        guard !overflow, cells.count == cellCount else { return gain }
        let elapsed = advanceClock(to: time)
        if cellsPerSide != side { layOut(cellsPerSide) }

        let windowStart = clock - Self.windowSeconds
        var busiest = luminance.feed(cells, windowCells: windowCells, gain: gain, at: clock, after: windowStart)
        if let redCells, redCells.count == cellCount {
            let reds = red.feed(redCells, windowCells: windowCells, gain: gain, at: clock, after: windowStart)
            busiest = Swift.max(busiest, reds)
        }
        if let colorCells, colorCells.red.count == cellCount, colorCells.green.count == cellCount,
           colorCells.blue.count == cellCount {
            if colorSum.count != cellCount { colorSum = [Double](repeating: 0, count: cellCount) }
            for index in Self.colorCombinations.indices {
                let combination = Self.colorCombinations[index]
                for cell in 0..<cellCount {
                    let redPart = combination.red * colorCells.red[cell]
                    let greenPart = combination.green * colorCells.green[cell]
                    let bluePart = combination.blue * colorCells.blue[cell]
                    colorSum[cell] = redPart + greenPart + bluePart
                }
                let moved = color[index].feed(colorSum, windowCells: windowCells, gain: gain,
                                              at: clock, after: windowStart)
                busiest = Swift.max(busiest, moved)
            }
        }

        if busiest >= Self.engageTransitions {
            gain = Self.engagedGain
            quietSince = nil
        } else {
            let since = quietSince ?? clock
            quietSince = since
            if clock - since >= Self.holdSeconds, gain < 1, elapsed > 0 {
                // A stalled or repeated frame never turns the climb into a jump.
                gain = Swift.min(1, gain + Self.releasePerSecond * Swift.min(elapsed, 1))
            }
        }
        return gain
    }

    /// Advances the clock for one frame and answers by how much.
    private mutating func advanceClock(to time: Double) -> Double {
        guard started else {
            started = true
            if time.isFinite { lastSourceTime = time }
            return 0
        }
        var elapsed = Self.shortestFrameSeconds
        if time.isFinite, let last = lastSourceTime {
            if time > last {
                elapsed = Swift.min(Swift.max(time - last, Self.shortestFrameSeconds), Self.longestFrameSeconds)
            } else if time == last {
                elapsed = 0
            }
        }
        if time.isFinite { lastSourceTime = time }
        clock += elapsed
        return elapsed
    }

    /// Builds the overlapping windows and every signal's cell channels for a new grid. The gain
    /// and every whole frame are kept.
    private mutating func layOut(_ cellsPerSide: Int) {
        side = cellsPerSide
        var windows: [[Int]] = []
        var size = 2
        while size < cellsPerSide, cellsPerSide <= Self.maxCellsPerSide {
            let hop = size / 2
            var origins: [Int] = Array(Swift.stride(from: 0, through: cellsPerSide - size, by: hop))
            if let last = origins.last, last != cellsPerSide - size { origins.append(cellsPerSide - size) }
            for row in origins {
                for column in origins {
                    var members: [Int] = []
                    members.reserveCapacity(size * size)
                    for memberRow in row..<(row + size) {
                        for memberColumn in column..<(column + size) {
                            members.append(memberRow * cellsPerSide + memberColumn)
                        }
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
        for index in color.indices { color[index].layOut(windowCount: windows.count, cellCount: cellCount) }
    }
}

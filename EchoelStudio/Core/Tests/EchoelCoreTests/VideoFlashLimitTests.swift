import XCTest
@testable import EchoelCore

/// The flash guard for footage, frame by frame: a strobe is held under WCAG's count wherever it
/// sits in the picture and whatever its color, ordinary footage keeps its full gain, the cap lets
/// go slowly, and no trick of the clock or the grid gets a flash past it.
final class VideoFlashLimitTests: XCTestCase {
    private static let side = VideoFlashLimit.cellsPerSide
    private static let framesPerSecond = 60.0
    private static let step = FlashLimit.generalFlashThreshold

    private static func frame(_ value: Double) -> [Double] {
        [Double](repeating: value, count: side * side)
    }

    /// Whether a square wave at `hertz` is in its first half at `time`.
    private static func isUp(_ hertz: Double, at time: Double) -> Bool {
        let halves = Int((2 * hertz * time).rounded(.down))
        return halves % 2 == 0
    }

    /// A square wave between `low` and `high` at `hertz`, the same value in every cell.
    private static func strobe(_ hertz: Double, low: Double = 0, high: Double = 1,
                               startsHigh: Bool = true) -> (Double) -> [Double] {
        { (time: Double) -> [Double] in
            let value: Double = Self.isUp(hertz, at: time) == startsHigh ? high : low
            return Self.frame(value)
        }
    }

    private struct Shown {
        var times: [Double] = []
        var gains: [Double] = []
        var outputs: [Double] = []

        var isUntouched: Bool { gains.allSatisfy { (gain: Double) -> Bool in gain == 1 } }
        var firstCapped: Int? { gains.firstIndex { (gain: Double) -> Bool in gain < 1 } }
    }

    /// Shows `source` for `seconds` at 60 frames a second; the output is the footage over black.
    /// The limit is handed `clock(frame)` when given, the shown time otherwise.
    private static func show(_ source: (Double) -> [Double], seconds: Double = 5,
                             clock: ((Int) -> Double)? = nil,
                             red: ((Double) -> [Double])? = nil,
                             color: ((Double) -> VideoFlashLimit.ColorCells)? = nil) -> Shown {
        var limit = VideoFlashLimit()
        var result = Shown()
        let frames = Int(seconds * framesPerSecond)
        for index in 0..<frames {
            let shown = Double(index) / framesPerSecond
            let cells: [Double] = source(shown)
            let time: Double = clock?(index) ?? shown
            let gain = limit.next(time: time, cells: cells, redCells: red?(shown), colorCells: color?(shown),
                                  cellsPerSide: side)
            result.times.append(shown)
            result.gains.append(gain)
            result.outputs.append(gain * (cells.max() ?? 0))
        }
        return result
    }

    /// The most output transitions of a WCAG step inside any one second — WCAG's measurement,
    /// written here apart from the limit: hysteresis on the step, a second ending at each one.
    private static func worstTransitionsPerSecond(_ shown: Shown) -> Int {
        var extreme: Double?
        var direction = 0
        var moments: [Double] = []
        for index in shown.times.indices {
            let time = shown.times[index]
            let value = shown.outputs[index]
            guard let last = extreme else {
                extreme = value
                continue
            }
            let rose = value >= last + step
            let fell = value <= last - step
            if direction == 1 {
                if value > last {
                    extreme = value
                } else if fell {
                    direction = -1
                    extreme = value
                    moments.append(time)
                }
            } else if direction == -1 {
                if value < last {
                    extreme = value
                } else if rose {
                    direction = 1
                    extreme = value
                    moments.append(time)
                }
            } else if rose {
                direction = 1
                extreme = value
                moments.append(time)
            } else if fell {
                direction = -1
                extreme = value
                moments.append(time)
            }
        }
        var worst = 0
        for end in moments {
            let inside = moments.filter { (moment: Double) -> Bool in moment > end - 1 && moment <= end }
            worst = Swift.max(worst, inside.count)
        }
        return worst
    }

    // MARK: A strobe

    /// A strobe at 3 Hz or faster, whichever edge it starts on, shows at most five transitions in
    /// any second — two and a half flashes — and is still capped at the end.
    func testAStrobeShowsFewerThanThreeFlashesASecond() {
        let rates: [Double] = [10, 4, 3.5, 3]
        for hertz in rates {
            for startsHigh in [true, false] {
                let shown = Self.show(Self.strobe(hertz, startsHigh: startsHigh))
                let worst = Self.worstTransitionsPerSecond(shown)
                let label = "\(hertz) Hz, starting \(startsHigh ? "bright" : "dark")"
                XCTAssertLessThanOrEqual(worst, 5, "\(label): \(worst) transitions in one second")
                XCTAssertLessThan(Double(worst) / 2, FlashLimit.flashesPerSecond, label)
                XCTAssertEqual(shown.gains.last, VideoFlashLimit.engagedGain, "\(label): still capped at the end")
            }
        }
    }

    /// A 10 Hz strobe is capped within half a second, and once capped no step it shows is a WCAG step.
    func testAFastStrobeIsCappedWithinHalfASecond() throws {
        let shown = Self.show(Self.strobe(10))
        let capped = try XCTUnwrap(shown.firstCapped, "a 10 Hz strobe is capped")
        XCTAssertLessThanOrEqual(capped, Int(Self.framesPerSecond / 2))
        for index in (capped + 1)..<shown.outputs.count {
            let moved = Swift.abs(shown.outputs[index] - shown.outputs[index - 1])
            XCTAssertLessThan(moved, Self.step, "frame \(index)")
        }
    }

    /// The same frames give the same gains.
    func testTheSameFramesGiveTheSameGains() {
        let first = Self.show(Self.strobe(4))
        let second = Self.show(Self.strobe(4))
        XCTAssertEqual(first.gains, second.gains)
    }

    // MARK: Ordinary footage

    /// A still picture, a fade, a faint shimmer and a slow flash keep their full gain throughout.
    func testOrdinaryFootageKeepsItsFullGain() {
        let steady = Self.show({ (_: Double) -> [Double] in Self.frame(0.5) }, seconds: 10)
        XCTAssertTrue(steady.isUntouched, "a still picture")
        let fade = Self.show({ (time: Double) -> [Double] in Self.frame(Swift.min(1, time / 3)) }, seconds: 10)
        XCTAssertTrue(fade.isUntouched, "a three-second fade")
        let shimmer = Self.show(Self.strobe(10, low: 0.5, high: 0.52), seconds: 10)
        XCTAssertTrue(shimmer.isUntouched, "a shimmer of 0.02 at 10 Hz is no flash, however fast")
        let slow = Self.show(Self.strobe(1.9), seconds: 10)
        XCTAssertTrue(slow.isUntouched, "a steady flash at 1.9 Hz is legal and untouched")
    }

    // MARK: Part of the picture

    /// One cell flashing by the whole step engages the cap; a hair under the step does not.
    func testOneCellFlashingByTheStepEngagesTheCap() {
        func oneCell(_ swing: Double) -> (Double) -> [Double] {
            { (time: Double) -> [Double] in
                var cells = Self.frame(0.3)
                cells[3 * Self.side + 3] = 0.3 + (Self.isUp(10, at: time) ? swing : 0)
                return cells
            }
        }
        XCTAssertEqual(Self.show(oneCell(0.1)).gains.last, VideoFlashLimit.engagedGain)
        XCTAssertTrue(Self.show(oneCell(0.09)).isUntouched, "under the step in one cell: no flash")
    }

    /// A square of four cells flashing together counts at a quarter of the step: no cell of it
    /// moves a whole step, the square as a whole does.
    func testASquareOfCellsCountsAtAQuarterOfTheStep() {
        func square(_ swing: Double) -> (Double) -> [Double] {
            { (time: Double) -> [Double] in
                var cells = Self.frame(0.3)
                let lift: Double = Self.isUp(10, at: time) ? swing : 0
                for row in 2...3 {
                    for column in 2...3 { cells[row * Self.side + column] = 0.3 + lift }
                }
                return cells
            }
        }
        XCTAssertEqual(Self.show(square(0.03)).gains.last, VideoFlashLimit.engagedGain)
        XCTAssertTrue(Self.show(square(0.02)).isUntouched, "under a quarter of the step: no flash")
    }

    /// A checkerboard reversing at 10 Hz leaves every square's mean where it was — and is capped
    /// all the same, because each cell counts on its own.
    func testCellsSwingingAgainstEachOtherEngageTheCap() throws {
        let checker = { (time: Double) -> [Double] in
            let bright = Self.isUp(10, at: time)
            var cells = Self.frame(0)
            for cell in cells.indices {
                let onEven = (cell / Self.side + cell % Self.side) % 2 == 0
                cells[cell] = onEven == bright ? 1 : 0
            }
            return cells
        }
        let shown = Self.show(checker)
        let capped = try XCTUnwrap(shown.firstCapped, "a reversing checkerboard is capped")
        XCTAssertLessThanOrEqual(capped, Int(Self.framesPerSecond / 2))
        XCTAssertEqual(shown.gains.last, VideoFlashLimit.engagedGain)
    }

    // MARK: Letting go

    /// After a strobe ends the cap holds, then climbs back no faster than its rate, never falls
    /// on the way, and is fully open again some seconds later.
    func testTheCapLetsGoAfterTheHoldAndClimbsSlowly() {
        let strobeEnds = 2.0
        let source = { (time: Double) -> [Double] in
            time < strobeEnds ? Self.strobe(10)(time) : Self.frame(0.5)
        }
        let shown = Self.show(source, seconds: 12)
        let rate = Self.framesPerSecond
        let held = Int((strobeEnds + 1.5) * rate)
        XCTAssertEqual(shown.gains[held], VideoFlashLimit.engagedGain, "still held a second and a half later")
        let climbing = Int((strobeEnds + 2.5) * rate)
        XCTAssertGreaterThan(shown.gains[climbing], VideoFlashLimit.engagedGain)
        XCTAssertLessThan(shown.gains[climbing], 1, "the climb takes seconds")
        XCTAssertEqual(shown.gains.last, 1, "fully open again in the end")
        let mostPerFrame = VideoFlashLimit.releasePerSecond / rate + 1e-9
        for index in (Int(strobeEnds * rate) + 1)..<shown.gains.count {
            let moved = shown.gains[index] - shown.gains[index - 1]
            XCTAssertGreaterThanOrEqual(moved, 0, "frame \(index): the gain never falls on the way back")
            XCTAssertLessThanOrEqual(moved, mostPerFrame, "frame \(index): no jump")
        }
    }

    // MARK: The clock

    /// A 24-frame clip on a 120 Hz display hands each media time five times. A repeated time does
    /// not run the clock: 2.6 Hz is still counted as 2.6 Hz and capped, 1.9 Hz stays untouched.
    func testARepeatedTimeDoesNotRunTheClock() {
        func onDisplay(_ hertz: Double) -> [Double] {
            var limit = VideoFlashLimit()
            var gains: [Double] = []
            for index in 0..<1200 {
                let shown = Double(index) / 120
                let media: Double = (shown * 24 + 1e-9).rounded(.down) / 24
                let value: Double = Self.isUp(hertz, at: media) ? 1 : 0
                gains.append(limit.next(time: media, cells: Self.frame(value), cellsPerSide: Self.side))
            }
            return gains
        }
        XCTAssertEqual(onDisplay(2.6).last, VideoFlashLimit.engagedGain)
        XCTAssertTrue(onDisplay(1.9).allSatisfy { (gain: Double) -> Bool in gain == 1 })
    }

    /// A clock that loops, runs backwards or is no number drops no frame from the count.
    func testALoopASeekOrATimeThatIsNoNumberIsStillCounted() throws {
        let looping = Self.show(Self.strobe(10), clock: { (index: Int) -> Double in Double(index % 30) / 60 })
        XCTAssertLessThanOrEqual(try XCTUnwrap(looping.firstCapped), 30, "a clip looping every half second")
        XCTAssertEqual(looping.gains.last, VideoFlashLimit.engagedGain)
        let backwards = Self.show(Self.strobe(10), clock: { (index: Int) -> Double in 5 - Double(index) / 60 })
        XCTAssertEqual(backwards.gains.last, VideoFlashLimit.engagedGain, "a clock running backwards")
        let noNumber = Self.show(Self.strobe(10), clock: { (_: Int) -> Double in Double.nan })
        XCTAssertEqual(noNumber.gains.last, VideoFlashLimit.engagedGain, "a time that is no number")
    }

    // MARK: Red and color

    /// A red flash whose luminance does not move is capped by its red signal — and only when the
    /// red cells are handed in.
    func testARedFlashIsCappedThoughItsLuminanceDoesNotMove() {
        let still = { (_: Double) -> [Double] in Self.frame(0.2) }
        let redSwing = { (time: Double) -> [Double] in Self.frame(Self.isUp(10, at: time) ? 0.5 : 0) }
        XCTAssertEqual(Self.show(still, red: redSwing).gains.last, VideoFlashLimit.engagedGain)
        XCTAssertTrue(Self.show(still).isUntouched, "the luminance alone shows nothing")
    }

    /// A blue swing moves neither the luminance cells handed in nor the footage's red signal; over
    /// a reddish picture it would still flash red, so the color cells count it.
    func testAColorSwingIsCappedWhenTheColorsAreHandedIn() {
        let still = { (_: Double) -> [Double] in Self.frame(0.2) }
        let noRed = { (_: Double) -> [Double] in Self.frame(0) }
        let blueSwing = { (time: Double) -> VideoFlashLimit.ColorCells in
            let blue: Double = Self.isUp(10, at: time) ? 0.5 : 0
            return VideoFlashLimit.ColorCells(red: Self.frame(0), green: Self.frame(0.2), blue: Self.frame(blue))
        }
        XCTAssertEqual(Self.show(still, red: noRed, color: blueSwing).gains.last, VideoFlashLimit.engagedGain)
        XCTAssertTrue(Self.show(still, red: noRed).isUntouched, "without the colors nothing counts it")
    }

    /// While engaged, footage blended over any picture as a screen cannot make a red flash, nor a
    /// luminance one; and the count that engages sits under WCAG's three flashes.
    func testTheEngagedGainIsUnderEveryStep() {
        let gain = VideoFlashLimit.engagedGain
        let redSwing: Double = 3 * gain - 2 * gain * gain
        XCTAssertLessThan(redSwing, VideoFlashLimit.redCellStep)
        XCTAssertLessThan(gain, VideoFlashLimit.cellStep)
        XCTAssertLessThan(Double(VideoFlashLimit.engageTransitions) / 2, FlashLimit.flashesPerSecond)
    }

    // MARK: The grid

    /// A grid that does not fit its side changes nothing, and the limit works on afterwards.
    func testAGridThatDoesNotFitChangesNothing() {
        var limit = VideoFlashLimit()
        let short = [Double](repeating: 0.5, count: Self.side * Self.side - 1)
        XCTAssertEqual(limit.next(time: 0, cells: short, cellsPerSide: Self.side), 1)
        XCTAssertEqual(limit.next(time: 0, cells: Self.frame(0.5), cellsPerSide: 0), 1)
        XCTAssertEqual(limit.next(time: 0, cells: Self.frame(0.5), cellsPerSide: -8), 1)
        var last = 1.0
        for index in 0..<300 {
            let time = Double(index) / Self.framesPerSecond
            last = limit.next(time: time, cells: Self.strobe(10)(time), cellsPerSide: Self.side)
        }
        XCTAssertEqual(last, VideoFlashLimit.engagedGain)
    }

    /// A cell that is no number is left out and the others still count; a frame of nothing but
    /// such cells counts nothing.
    func testACellThatIsNoNumberIsLeftOut() {
        let holed = { (time: Double) -> [Double] in
            var cells = Self.strobe(10)(time)
            cells[0] = Double.nan
            return cells
        }
        var limit = VideoFlashLimit()
        var empty = VideoFlashLimit()
        var last = 1.0
        var lastEmpty = 1.0
        for index in 0..<300 {
            let time = Double(index) / Self.framesPerSecond
            last = limit.next(time: time, cells: holed(time), cellsPerSide: Self.side)
            lastEmpty = empty.next(time: time, cells: Self.frame(Double.nan), cellsPerSide: Self.side)
        }
        XCTAssertEqual(last, VideoFlashLimit.engagedGain)
        XCTAssertEqual(lastEmpty, 1)
    }

    /// A coarser grid, a finer one, and one finer than the windows read (whole frame only) all
    /// cap a strobe; and a new grid keeps the gain the old one reached.
    func testEveryGridCapsAStrobeAndANewGridKeepsTheGain() {
        let sides: [Int] = [4, 16, 32]
        for cellsPerSide in sides {
            var limit = VideoFlashLimit()
            var last = 1.0
            for index in 0..<300 {
                let time = Double(index) / Self.framesPerSecond
                let value: Double = Self.isUp(10, at: time) ? 1 : 0
                let cells = [Double](repeating: value, count: cellsPerSide * cellsPerSide)
                last = limit.next(time: time, cells: cells, cellsPerSide: cellsPerSide)
            }
            XCTAssertEqual(last, VideoFlashLimit.engagedGain, "\(cellsPerSide) cells a side")
        }
        var limit = VideoFlashLimit()
        for index in 0..<120 {
            let time = Double(index) / Self.framesPerSecond
            limit.next(time: time, cells: Self.strobe(10)(time), cellsPerSide: Self.side)
        }
        XCTAssertEqual(limit.gain, VideoFlashLimit.engagedGain)
        let coarse = [Double](repeating: 0.5, count: 16)
        XCTAssertEqual(limit.next(time: 2, cells: coarse, cellsPerSide: 4), VideoFlashLimit.engagedGain)
    }

    // MARK: A frame's measures

    /// The luminance and the red signal are WCAG's, on linear light.
    func testAFramesMeasuresAreWCAGs() {
        XCTAssertEqual(VideoFlashLimit.luminance(red: 1, green: 1, blue: 1), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimit.luminance(red: 0, green: 0, blue: 0), 0)
        XCTAssertEqual(VideoFlashLimit.luminance(red: 1, green: 0, blue: 0), 0.2126, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimit.luminance(red: 0, green: 1, blue: 0), 0.7152, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimit.redSignal(red: 1, green: 0, blue: 0), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimit.redSignal(red: 0.5, green: 0.5, blue: 0.5), 0, "a grey is not red")
        XCTAssertEqual(VideoFlashLimit.redSignal(red: 0, green: 1, blue: 1), 0, "never under 0")
        XCTAssertEqual(VideoFlashLimit.linear(0.04045), 0.04045 / 12.92, accuracy: 1e-15)
        XCTAssertEqual(VideoFlashLimit.linear(1), 1, accuracy: 1e-12)
        XCTAssertEqual(VideoFlashLimit.linear(2), 1, accuracy: 1e-12, "held to 0 … 1")
        XCTAssertEqual(VideoFlashLimit.linear(-1), 0)
        XCTAssertEqual(VideoFlashLimit.linear(Double.nan), 0, "no number reads as dark")
    }
}

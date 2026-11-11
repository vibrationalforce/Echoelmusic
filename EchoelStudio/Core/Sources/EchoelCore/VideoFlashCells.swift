import Foundation

/// One shown frame of footage, measured for `VideoFlashLimit`: the means of a grid of cells
/// (`VideoFlashLimit.cellsPerSide` a side, row by row) — the relative luminance, WCAG's red signal,
/// and linear red, green and blue. It reads the picture as plain bytes, four to a pixel in the
/// order blue, green, red, alpha, which is how a video output hands a frame over; it knows no
/// video framework, so the same arithmetic runs in a test on a picture made by hand.
///
/// A small picture is enough and is what the caller should ask for (64 pixels a side: eight to a
/// cell): the limit counts cell means, and a mean does not get better with more pixels. The five
/// lists are kept between frames, so measuring allocates nothing after the first.
public struct VideoFlashCells: Sendable {
    /// The cells' relative luminance, 0 … 1.
    public private(set) var luminance: [Double]
    /// The cells' red signal: the mean of linear R − G − B, each pixel never under 0.
    public private(set) var red: [Double]
    /// The cells' linear red, green and blue.
    public private(set) var color: VideoFlashLimit.ColorCells

    /// The pixels a side a caller should ask a video output for.
    public static let pixelsPerSide = 64
    /// Bytes to a pixel: blue, green, red, alpha.
    public static let bytesPerPixel = 4

    /// Every 8-bit level as linear light, so a pixel costs three look-ups and no power function.
    private static let linearLevels: [Double] = (0..<256).map { (level: Int) -> Double in
        VideoFlashLimit.linear(Double(level) / 255)
    }

    public init() {
        let count = VideoFlashLimit.cellsPerSide * VideoFlashLimit.cellsPerSide
        let empty = [Double](repeating: 0, count: count)
        luminance = empty
        red = empty
        color = VideoFlashLimit.ColorCells(red: empty, green: empty, blue: empty)
    }

    /// Measures a picture `width` by `height` pixels whose rows are `bytesPerRow` bytes apart.
    /// False, with the cells left as they were, when the picture is smaller than the grid, a row
    /// is shorter than its pixels, or the bytes do not hold every row — a frame that cannot be
    /// read is not counted as a dark one.
    @discardableResult
    public mutating func measure(bgra bytes: UnsafeRawBufferPointer, width: Int, height: Int, bytesPerRow: Int) -> Bool {
        let side = VideoFlashLimit.cellsPerSide
        guard width >= side, height >= side, width <= 16_384, height <= 16_384,
              bytesPerRow >= width * Self.bytesPerPixel else { return false }
        let needed = (height - 1) * bytesPerRow + width * Self.bytesPerPixel
        guard bytes.count >= needed else { return false }
        let levels = Self.linearLevels
        for row in 0..<side {
            let top = row * height / side
            let bottom = (row + 1) * height / side
            for column in 0..<side {
                let left = column * width / side
                let right = (column + 1) * width / side
                var redSum = 0.0
                var greenSum = 0.0
                var blueSum = 0.0
                var signalSum = 0.0
                for y in top..<bottom {
                    var offset = y * bytesPerRow + left * Self.bytesPerPixel
                    for _ in left..<right {
                        let blue = levels[Int(bytes[offset])]
                        let green = levels[Int(bytes[offset + 1])]
                        let redLevel = levels[Int(bytes[offset + 2])]
                        redSum += redLevel
                        greenSum += green
                        blueSum += blue
                        signalSum += Swift.max(0, redLevel - green - blue)
                        offset += Self.bytesPerPixel
                    }
                }
                // Each cell holds at least one pixel: the picture is at least the grid's size.
                let pixels = Double((bottom - top) * (right - left))
                let cell = row * side + column
                let redMean = redSum / pixels
                let greenMean = greenSum / pixels
                let blueMean = blueSum / pixels
                color.red[cell] = redMean
                color.green[cell] = greenMean
                color.blue[cell] = blueMean
                red[cell] = signalSum / pixels
                // A sum of linear light commutes with the mean, so this is the cell's own luminance.
                let weighted: Double = 0.2126 * redMean + 0.7152 * greenMean + 0.0722 * blueMean
                luminance[cell] = Swift.min(1, weighted)
            }
        }
        return true
    }
}

extension VideoFlashLimit {
    /// Takes one measured frame and answers the gain. `blended` says that another picture is drawn
    /// with the footage — the Field layer over it. Only then can a swing of the footage's green or
    /// blue move a red signal that is not its own, and only then do the seven color sums count
    /// (`colorCombinations`). Footage shown by itself, on black, is counted by its luminance and its
    /// own red, WCAG's two measures. The sums run at the red steps on every color, grey too: handed
    /// over always, they took a whole picture flickering by one stored level for a flash, and
    /// ordinary footage went dark.
    @discardableResult
    public mutating func next(time: Double, frame: VideoFlashCells, blended: Bool) -> Double {
        next(time: time, cells: frame.luminance, redCells: frame.red, colorCells: blended ? frame.color : nil,
             cellsPerSide: VideoFlashLimit.cellsPerSide)
    }
}

/// The flash limit as a shown picture uses it, look by look: a new frame is measured and counted;
/// a frame that is only held on screen is counted while the gain is lowered — so a picture that was
/// dimmed comes back after the film stops instead of staying dark — and otherwise only lets time
/// pass, so what changed before a long still is over when the picture changes again.
/// The caller says the time on the display's clock; a media clock would make a strobe look slower
/// at a faster playback rate.
public struct VideoFlashWatch: Sendable {
    private var cells = VideoFlashCells()
    private var limit = VideoFlashLimit()
    private var hasMeasured = false
    /// Another picture is drawn with the footage now (the Field layer); the caller keeps it
    /// current. See `VideoFlashLimit.next(time:frame:blended:)`.
    public var isBlended = false

    public init() {}

    /// The gain the picture may be shown at now.
    public var gain: Double { limit.gain }

    /// A new frame is on screen at `time`. Answers the gain; a frame that cannot be read is not
    /// counted and leaves the gain where it is.
    @discardableResult
    public mutating func show(bgra bytes: UnsafeRawBufferPointer, width: Int, height: Int, bytesPerRow: Int,
                              at time: Double) -> Double {
        guard cells.measure(bgra: bytes, width: width, height: height, bytesPerRow: bytesPerRow) else { return limit.gain }
        hasMeasured = true
        return limit.next(time: time, frame: cells, blended: isBlended)
    }

    /// No new frame at `time`: the last one is still on screen, or nothing is. Answers the gain.
    @discardableResult
    public mutating func hold(at time: Double) -> Double {
        guard hasMeasured else { return limit.gain }
        guard limit.gain < 1 else {
            limit.rest(time: time)
            return limit.gain
        }
        return limit.next(time: time, frame: cells, blended: isBlended)
    }
}

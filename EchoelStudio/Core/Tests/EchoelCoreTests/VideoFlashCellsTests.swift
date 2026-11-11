import XCTest
@testable import EchoelCore

/// A frame's cells, measured from bytes: the colors land in the right cells with WCAG's measures,
/// a picture that cannot be read changes nothing, and a strobe handed over as pictures is capped.
final class VideoFlashCellsTests: XCTestCase {
    private static let cells = VideoFlashLimit.cellsPerSide * VideoFlashLimit.cellsPerSide

    /// A picture of one color; `rowPadding` extra bytes after each row, filled with 255.
    private static func picture(width: Int, height: Int, rowPadding: Int = 0,
                                color: (Int, Int) -> (red: UInt8, green: UInt8, blue: UInt8)) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(height * (width * 4 + rowPadding))
        for y in 0..<height {
            for x in 0..<width {
                let pixel = color(x, y)
                bytes.append(pixel.blue)
                bytes.append(pixel.green)
                bytes.append(pixel.red)
                bytes.append(255)
            }
            for _ in 0..<rowPadding { bytes.append(255) }
        }
        return bytes
    }

    private static func measured(_ bytes: [UInt8], width: Int, height: Int, rowPadding: Int = 0) -> VideoFlashCells? {
        var frame = VideoFlashCells()
        let read = bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            frame.measure(bgra: raw, width: width, height: height, bytesPerRow: width * 4 + rowPadding)
        }
        return read ? frame : nil
    }

    func testAWhitePictureIsFullLuminanceAndNoRed() throws {
        let white = Self.picture(width: 16, height: 16) { (_: Int, _: Int) in (red: 255, green: 255, blue: 255) }
        let frame = try XCTUnwrap(Self.measured(white, width: 16, height: 16))
        XCTAssertEqual(frame.luminance.count, Self.cells)
        for cell in 0..<Self.cells {
            XCTAssertEqual(frame.luminance[cell], 1, accuracy: 1e-9, "cell \(cell)")
            XCTAssertEqual(frame.red[cell], 0, "white is not red, cell \(cell)")
            XCTAssertEqual(frame.color.red[cell], 1, accuracy: 1e-9)
            XCTAssertEqual(frame.color.green[cell], 1, accuracy: 1e-9)
            XCTAssertEqual(frame.color.blue[cell], 1, accuracy: 1e-9)
        }
    }

    func testAPureRedPictureHasWCAGsRedLuminanceAndFullRedSignal() throws {
        let red = Self.picture(width: 16, height: 16) { (_: Int, _: Int) in (red: 255, green: 0, blue: 0) }
        let frame = try XCTUnwrap(Self.measured(red, width: 16, height: 16))
        XCTAssertEqual(frame.luminance[0], 0.2126, accuracy: 1e-9)
        XCTAssertEqual(frame.red[0], 1, accuracy: 1e-9)
        XCTAssertEqual(frame.color.green[0], 0)
        XCTAssertEqual(frame.color.blue[0], 0)
    }

    /// The left half black, the right half white: the four left columns of cells are dark, the
    /// four right ones bright, in every row.
    func testEachCellReadsItsOwnPartOfThePicture() throws {
        let halves = Self.picture(width: 32, height: 16) { (x: Int, _: Int) in
            x < 16 ? (red: 0, green: 0, blue: 0) : (red: 255, green: 255, blue: 255)
        }
        let frame = try XCTUnwrap(Self.measured(halves, width: 32, height: 16))
        let side = VideoFlashLimit.cellsPerSide
        for row in 0..<side {
            for column in 0..<side {
                let expected: Double = column < side / 2 ? 0 : 1
                XCTAssertEqual(frame.luminance[row * side + column], expected, accuracy: 1e-9, "row \(row), column \(column)")
            }
        }
    }

    /// One white pixel among the four of a cell is a quarter of its light — the mean is taken in
    /// linear light, not on the stored levels.
    func testACellIsTheMeanOfItsPixelsInLinearLight() throws {
        let dotted = Self.picture(width: 16, height: 16) { (x: Int, y: Int) in
            x == 0 && y == 0 ? (red: 255, green: 255, blue: 255) : (red: 0, green: 0, blue: 0)
        }
        let frame = try XCTUnwrap(Self.measured(dotted, width: 16, height: 16))
        XCTAssertEqual(frame.luminance[0], 0.25, accuracy: 1e-9)
        XCTAssertEqual(frame.luminance[1], 0)
        let grey = Self.picture(width: 16, height: 16) { (_: Int, _: Int) in (red: 128, green: 128, blue: 128) }
        let greyFrame = try XCTUnwrap(Self.measured(grey, width: 16, height: 16))
        XCTAssertEqual(greyFrame.luminance[0], VideoFlashLimit.linear(128.0 / 255), accuracy: 1e-9)
        XCTAssertLessThan(greyFrame.luminance[0], 0.25, "a stored 128 is about a fifth of the light, not half")
    }

    /// Bytes after the end of a row belong to no pixel.
    func testRowPaddingIsNotRead() throws {
        let black = Self.picture(width: 16, height: 16, rowPadding: 12) { (_: Int, _: Int) in (red: 0, green: 0, blue: 0) }
        let frame = try XCTUnwrap(Self.measured(black, width: 16, height: 16, rowPadding: 12))
        XCTAssertEqual(frame.luminance.max(), 0)
    }

    /// A picture smaller than the grid, a row shorter than its pixels, or too few bytes: nothing
    /// is read and the cells stay as they were.
    func testAPictureThatCannotBeReadChangesNothing() {
        var frame = VideoFlashCells()
        let white = Self.picture(width: 16, height: 16) { (_: Int, _: Int) in (red: 255, green: 255, blue: 255) }
        white.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            XCTAssertTrue(frame.measure(bgra: raw, width: 16, height: 16, bytesPerRow: 64))
            XCTAssertFalse(frame.measure(bgra: raw, width: 7, height: 16, bytesPerRow: 64), "narrower than the grid")
            XCTAssertFalse(frame.measure(bgra: raw, width: 16, height: 16, bytesPerRow: 60), "a row shorter than its pixels")
            XCTAssertFalse(frame.measure(bgra: raw, width: 16, height: 17, bytesPerRow: 64), "more rows than bytes")
            XCTAssertFalse(frame.measure(bgra: raw, width: 0, height: 0, bytesPerRow: 0))
        }
        XCTAssertEqual(frame.luminance[0], 1, accuracy: 1e-9, "the last picture that was read still stands")
    }

    /// Pictures alternating black and white at 10 Hz, handed over as bytes, engage the limit; a
    /// steady grey picture leaves the gain at 1.
    func testAStrobeHandedOverAsPicturesIsCapped() throws {
        let side = VideoFlashCells.pixelsPerSide
        let white = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 255, green: 255, blue: 255) }
        let black = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 0, green: 0, blue: 0) }
        let grey = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 128, green: 128, blue: 128) }
        var strobing = VideoFlashLimit()
        var steady = VideoFlashLimit()
        var frame = VideoFlashCells()
        var steadyGains: [Double] = []
        for index in 0..<180 {
            let time = Double(index) / 60
            let bright = Int((20 * time).rounded(.down)) % 2 == 0
            let shown = bright ? white : black
            _ = shown.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
                frame.measure(bgra: raw, width: side, height: side, bytesPerRow: side * 4)
            }
            strobing.next(time: time, frame: frame, blended: false)
            _ = grey.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
                frame.measure(bgra: raw, width: side, height: side, bytesPerRow: side * 4)
            }
            steadyGains.append(steady.next(time: time, frame: frame, blended: false))
        }
        XCTAssertEqual(strobing.gain, VideoFlashLimit.engagedGain)
        XCTAssertTrue(steadyGains.allSatisfy { (gain: Double) -> Bool in gain == 1 })
    }

    /// A red picture and a grey of the same luminance, taking turns at 10 Hz: the luminance cells
    /// do not move, the red signal does, and the limit engages.
    func testARedFlashOfEqualLuminanceIsCappedFromPictures() throws {
        let side = VideoFlashCells.pixelsPerSide
        let red = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 255, green: 0, blue: 0) }
        // A grey whose linear light is 0.2126 of white: the stored level nearest to it.
        let level = UInt8(127)
        let grey = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: level, green: level, blue: level) }
        var redFrame = VideoFlashCells()
        var greyFrame = VideoFlashCells()
        _ = red.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            redFrame.measure(bgra: raw, width: side, height: side, bytesPerRow: side * 4)
        }
        _ = grey.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            greyFrame.measure(bgra: raw, width: side, height: side, bytesPerRow: side * 4)
        }
        let moved = Swift.abs(redFrame.luminance[0] - greyFrame.luminance[0])
        XCTAssertLessThan(moved, VideoFlashLimit.windowStep, "the luminance moves less than any step the limit counts")
        var limit = VideoFlashLimit()
        for index in 0..<180 {
            let time = Double(index) / 60
            let isRed = Int((20 * time).rounded(.down)) % 2 == 0
            limit.next(time: time, frame: isRed ? redFrame : greyFrame, blended: false)
        }
        XCTAssertEqual(limit.gain, VideoFlashLimit.engagedGain)
    }

    // MARK: Footage by itself, and footage with another picture

    /// A whole picture flickering between two neighbouring stored levels, twenty changes a second
    /// (a lamp, a codec): its luminance moves by under one hundredth, far from WCAG's tenth, and
    /// nothing in it is red. `blended` says whether another picture is drawn with it.
    private static func gainsOfAOneLevelFlicker(blended: Bool) -> [Double] {
        let side = VideoFlashCells.pixelsPerSide
        let lower = picture(width: side, height: side) { (_: Int, _: Int) in (red: 240, green: 240, blue: 240) }
        let upper = picture(width: side, height: side) { (_: Int, _: Int) in (red: 241, green: 241, blue: 241) }
        var watch = VideoFlashWatch()
        watch.isBlended = blended
        var gains: [Double] = []
        for index in 0..<180 {
            let time = Double(index) / 60
            let isLower = Int((20 * time).rounded(.down)) % 2 == 0
            let shown = isLower ? lower : upper
            let gain = shown.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
                watch.show(bgra: raw, width: side, height: side, bytesPerRow: side * 4, at: time)
            }
            gains.append(gain)
        }
        return gains
    }

    /// Shown by itself, ordinary footage is not dimmed for a flicker of one stored level: only the
    /// luminance and the footage's own red count.
    func testAOneLevelFlickerIsNoFlashForFootageShownByItself() {
        let gains = Self.gainsOfAOneLevelFlicker(blended: false)
        XCTAssertEqual(gains.count, 180)
        XCTAssertTrue(gains.allSatisfy { (gain: Double) -> Bool in gain == 1 }, "the picture keeps its full gain for three seconds")
    }

    /// With another picture drawn over it, the same flicker is counted: over a red picture nobody
    /// measured it could be a red flash. The safe side, until the shown picture itself is measured.
    func testTheSameFlickerIsCountedWhileAnotherPictureIsDrawnWithIt() {
        let gains = Self.gainsOfAOneLevelFlicker(blended: true)
        XCTAssertEqual(gains.last, VideoFlashLimit.engagedGain)
        XCTAssertEqual(gains[14], 1, "the fifth change comes with the sixteenth frame")
        XCTAssertEqual(gains[15], VideoFlashLimit.engagedGain)
    }

    // MARK: A picture on screen, look by look

    /// A strobe shown as pictures is dimmed; once the film stops on one frame, the held frame lets
    /// the picture come back — not at once, never jumping, and fully in the end.
    func testADimmedPictureComesBackWhileTheFilmStands() {
        let side = VideoFlashCells.pixelsPerSide
        let white = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 255, green: 255, blue: 255) }
        let black = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 0, green: 0, blue: 0) }
        var watch = VideoFlashWatch()
        for index in 0..<120 {
            let time = Double(index) / 60
            let bright = Int((20 * time).rounded(.down)) % 2 == 0
            let shown = bright ? white : black
            _ = shown.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
                watch.show(bgra: raw, width: side, height: side, bytesPerRow: side * 4, at: time)
            }
        }
        XCTAssertEqual(watch.gain, VideoFlashLimit.engagedGain, "the strobe is dimmed")
        // The film stops: the same frame stays on screen, looked at 125 times a second.
        var gains: [Double] = []
        for look in 1...1000 {
            gains.append(watch.hold(at: 2 + Double(look) * 0.008))
        }
        XCTAssertEqual(gains[186], VideoFlashLimit.engagedGain, "a second and a half later it is still held")
        XCTAssertEqual(gains.last, 1, "eight seconds later the picture is fully back")
        for index in 1..<gains.count {
            let moved = gains[index] - gains[index - 1]
            XCTAssertGreaterThanOrEqual(moved, 0, "look \(index): it never dims again on a still frame")
            XCTAssertLessThanOrEqual(moved, VideoFlashLimit.releasePerSecond * 0.008 + 1e-9, "look \(index): no jump")
        }
    }

    /// Four changes between a dark and a bright picture, a minute on the last one — the song is
    /// stopped — and one more change: the picture keeps its gain. Held looks at full gain let the
    /// minute pass; counted as no time, the fifth change dimmed a picture that had not flashed.
    func testChangesBeforeAndAfterALongStillAreNotOneBurst() {
        let side = VideoFlashCells.pixelsPerSide
        let dark = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 40, green: 40, blue: 40) }
        let bright = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 230, green: 230, blue: 230) }
        var watch = VideoFlashWatch()
        let pictures: [[UInt8]] = [dark, bright, dark, bright, dark]
        for (index, shown) in pictures.enumerated() {
            _ = shown.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
                watch.show(bgra: raw, width: side, height: side, bytesPerRow: side * 4, at: Double(index) * 0.1)
            }
        }
        XCTAssertEqual(watch.gain, 1, "four changes do not engage")
        var time = 0.4
        for _ in 0..<600 {
            time += 0.1
            XCTAssertEqual(watch.hold(at: time), 1)
        }
        let after = bright.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
            watch.show(bgra: raw, width: side, height: side, bytesPerRow: side * 4, at: time + 0.1)
        }
        XCTAssertEqual(after, 1, "the changes of a minute ago are over")
    }

    /// Before any picture was read, and while nothing is dimmed, a held frame is not counted at all.
    func testAHeldFrameCostsNothingWhileNothingIsDimmed() {
        var watch = VideoFlashWatch()
        XCTAssertEqual(watch.hold(at: 0), 1)
        XCTAssertEqual(watch.hold(at: 100), 1)
        let side = VideoFlashCells.pixelsPerSide
        let grey = Self.picture(width: side, height: side) { (_: Int, _: Int) in (red: 128, green: 128, blue: 128) }
        let first = grey.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
            watch.show(bgra: raw, width: side, height: side, bytesPerRow: side * 4, at: 0)
        }
        XCTAssertEqual(first, 1)
        XCTAssertEqual(watch.hold(at: 0.5), 1)
    }

    /// A frame that cannot be read is not counted: the gain stays where it is.
    func testAFrameThatCannotBeReadLeavesTheGain() {
        var watch = VideoFlashWatch()
        let tooFew: [UInt8] = [0, 0, 0, 255]
        let gain = tooFew.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Double in
            watch.show(bgra: raw, width: 64, height: 64, bytesPerRow: 256, at: 0)
        }
        XCTAssertEqual(gain, 1)
        XCTAssertEqual(watch.hold(at: 1), 1, "and nothing was measured, so a held frame is not counted either")
    }
}

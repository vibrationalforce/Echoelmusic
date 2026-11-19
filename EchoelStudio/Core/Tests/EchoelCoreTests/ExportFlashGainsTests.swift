import XCTest
@testable import EchoelCore

final class ExportFlashGainsTests: XCTestCase {
    /// One frame of a single level, measured as the export measures it.
    private func frame(_ level: UInt8) -> VideoFlashCells {
        let side = VideoFlashCells.pixelsPerSide
        var bytes = [UInt8](repeating: 255, count: side * side * VideoFlashCells.bytesPerPixel)
        for pixel in 0..<(side * side) {
            for channel in 0..<3 { bytes[pixel * VideoFlashCells.bytesPerPixel + channel] = level }
        }
        var cells = VideoFlashCells()
        bytes.withUnsafeBytes { raw in
            _ = cells.measure(bgra: raw, width: side, height: side, bytesPerRow: side * VideoFlashCells.bytesPerPixel)
        }
        return cells
    }

    /// A strobe cut into the film — black and white, a frame each, at 30 frames a second — is
    /// drawn dark within its first second and stays dark while it strobes.
    func testAStrobeInTheFilmIsDrawnDark() {
        var film = ExportFlashGains(framesPerSecond: 30, blended: false)
        for index in 0..<90 { film.add(frame(index % 2 == 0 ? 0 : 255)) }
        XCTAssertTrue(film.dims)
        let firstDark = film.gains.firstIndex { $0 < 1 }
        XCTAssertNotNil(firstDark)
        XCTAssertLessThan(firstDark ?? 99, 30, "dark inside the first second")
        XCTAssertTrue(film.gains[30...].allSatisfy { $0 <= VideoFlashLimit.engagedGain + 1e-9 }, "and dark while it strobes")
        XCTAssertEqual(film.gain(at: 2), film.gains[60])
    }

    /// Footage that does not flash keeps every frame at full, and the export then draws nothing.
    func testSteadyFootageIsLeftAlone() {
        var film = ExportFlashGains(framesPerSecond: 30, blended: true)
        for index in 0..<90 { film.add(frame(UInt8(100 + index / 30))) }
        XCTAssertFalse(film.dims)
        XCTAssertEqual(film.gain(at: 1.5), 1)
    }

    /// A gain is found by the frame's time; past the end it keeps the last one.
    func testAGainIsLookedUpByTime() {
        var film = ExportFlashGains(framesPerSecond: 30, blended: false)
        XCTAssertEqual(film.gain(at: 0), 1, "an empty film")
        for index in 0..<45 { film.add(frame(index % 2 == 0 ? 0 : 255)) }
        XCTAssertEqual(film.gain(at: Double(10) / 30), film.gains[10])
        XCTAssertEqual(film.gain(at: 100), film.gains[44])
        XCTAssertEqual(film.gain(at: -1), film.gains[0])
        XCTAssertEqual(film.gain(at: .nan), film.gains[0])
    }
}

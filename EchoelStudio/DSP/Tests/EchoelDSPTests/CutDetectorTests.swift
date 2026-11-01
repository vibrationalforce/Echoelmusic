import Foundation
import XCTest
@testable import EchoelDSP

final class CutDetectorTests: XCTestCase {
    private let framesPerSecond = 30.0

    /// A picture of 16 × 9 cells from a seed: a fixed texture, 0 … 1.
    private func picture(_ seed: UInt32) -> [Float] {
        var state = seed
        return (0..<144).map { _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 24)
        }
    }

    /// Frames one after another at 30 fps, each with a little sensor noise.
    private func cuts(_ frames: [[Float]], noise: Float = 0.005) -> [Double] {
        var detector = CutDetector()
        var state: UInt32 = 99
        for (index, frame) in frames.enumerated() {
            let noisy = frame.map { (cell: Float) -> Float in
                state = state &* 1_664_525 &+ 1_013_904_223
                return cell + noise * (Float(state >> 8) / Float(1 << 24) - 0.5)
            }
            detector.add(noisy, at: Double(index) / framesPerSecond)
        }
        return detector.cuts
    }

    private func shot(_ seed: UInt32, seconds: Double) -> [[Float]] {
        Array(repeating: picture(seed), count: Int(seconds * framesPerSecond))
    }

    /// Two hard cuts: each found on the first frame of the new shot.
    func testHardCutsAreFoundOnTheFirstFrameOfTheNewShot() {
        let found = cuts(shot(1, seconds: 2) + shot(2, seconds: 1) + shot(3, seconds: 1))
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found.first ?? 0, 2, accuracy: 1e-9)
        XCTAssertEqual(found.last ?? 0, 3, accuracy: 1e-9)
    }

    /// A picture that moves every frame changes a lot every frame — a pan — and is no cut.
    func testAPictureMovingEveryFrameIsNoCut() {
        let moving = (0..<90).map { picture(UInt32(1_000 + $0)) }
        XCTAssertEqual(cuts(moving), [])
    }

    /// A one-second fade from one shot into another changes little in each frame: no cut.
    func testAFadeIsNoCut() {
        let from = picture(5), to = picture(6)
        let fade = (0..<30).map { (step: Int) -> [Float] in
            let share = Float(step) / 29
            return zip(from, to).map { $0 * (1 - share) + $1 * share }
        }
        XCTAssertEqual(cuts(shot(5, seconds: 1) + fade + shot(6, seconds: 1)), [])
    }

    /// A single white frame jumps there and back: two equal changes side by side, not a cut.
    func testASingleFlashFrameIsNoCut() {
        let flash = [[Float](repeating: 1, count: 144)]
        XCTAssertEqual(cuts(shot(7, seconds: 1) + flash + shot(7, seconds: 1)), [])
    }

    /// Two cuts a few frames apart are one: the larger stays.
    func testCutsCloserThanTheShortestShotCountOnce() {
        let found = cuts(shot(1, seconds: 1) + shot(2, seconds: 0.1) + shot(3, seconds: 1))
        XCTAssertEqual(found.count, 1)
    }

    /// A still shot with sensor noise has no cut, and neither does a frame of another size.
    func testNoiseAndAChangeOfSizeAreNoCut() {
        XCTAssertEqual(cuts(shot(4, seconds: 2), noise: 0.02), [])
        var detector = CutDetector()
        detector.add(picture(1), at: 0)
        detector.add(Array(picture(2).prefix(64)), at: 1 / framesPerSecond)
        detector.add(Array(picture(2).prefix(64)), at: 2 / framesPerSecond)
        XCTAssertEqual(detector.cuts, [])
    }

    /// Cells that are not numbers count as no change.
    func testNonFiniteCellsCountAsNoChange() {
        var detector = CutDetector()
        for index in 0..<30 {
            var cells = picture(1)
            if index % 2 == 0 { cells[3] = .nan }
            detector.add(cells, at: Double(index) / framesPerSecond)
        }
        XCTAssertEqual(detector.cuts, [])
    }
}

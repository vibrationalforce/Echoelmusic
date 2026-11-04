import XCTest
@testable import EchoelDSP

final class HeadphoneSpatializerTests: XCTestCase {
    private let rate = 48_000.0

    /// Deterministic white noise, −0.5 … 0.5.
    private func noise(_ count: Int, seed: UInt32 = 12_345) -> [Float] {
        var state = seed
        return (0..<count).map { (_: Int) -> Float in
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 24) - 0.5
        }
    }

    /// The source rendered at `position`, in blocks of `block`.
    private func render(_ input: [Float], at position: HeadphoneSpatializer.Position, block: Int = 512,
                        spatializer: HeadphoneSpatializer? = nil) -> (left: [Float], right: [Float]) {
        let unit = spatializer ?? HeadphoneSpatializer(sampleRate: rate)
        unit.setPosition(position)
        var left = [Float](repeating: 0, count: input.count), right = left
        input.withUnsafeBufferPointer { source in
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let s = source.baseAddress, let lb = l.baseAddress, let rb = r.baseAddress else { return }
                    var done = 0
                    while done < input.count {
                        let count = Swift.min(block, input.count - done)
                        unit.process(left: s + done, right: s + done, outLeft: lb + done, outRight: rb + done, frames: count)
                        done += count
                    }
                }
            }
        }
        return (left, right)
    }

    private func rms(_ x: ArraySlice<Float>) -> Double {
        let sum = x.reduce(0.0) { (total: Double, value: Float) -> Double in total + Double(value) * Double(value) }
        return (sum / Double(Swift.max(x.count, 1))).squareRoot()
    }

    /// The lag (samples) by which `late` follows `early`, by cross-correlation within ±`reach`.
    private func lag(of late: [Float], behind early: [Float], reach: Int = 60) -> Int {
        var best = 0, bestValue = -Double.infinity
        let start = reach, end = early.count - reach
        for shift in -reach...reach {
            var sum = 0.0
            for i in start..<end { sum += Double(early[i]) * Double(late[i + shift]) }
            if sum > bestValue { bestValue = sum; best = shift }
        }
        return best
    }

    func testTheArrivalTimeAtNinetyDegreesIsAHeadsWidth() {
        let right = HeadphoneSpatializer.interauralDelay(HeadphoneSpatializer.Position(azimuth: -90))
        XCTAssertLessThan(right, 0, "a source on the right reaches the right ear first")
        XCTAssertTrue((0.000_6...0.000_7).contains(-right), "\(right)")
        XCTAssertEqual(HeadphoneSpatializer.interauralDelay(HeadphoneSpatializer.Position(azimuth: 90)), -right, accuracy: 1e-12)
        XCTAssertEqual(HeadphoneSpatializer.interauralDelay(HeadphoneSpatializer.Position()), 0, accuracy: 1e-12)
        XCTAssertEqual(HeadphoneSpatializer.interauralDelay(HeadphoneSpatializer.Position(azimuth: -90, elevation: 90)), 0,
                       accuracy: 1e-9, "straight above, both ears alike")
    }

    /// 90° to the right (ADM azimuth −90°): the right ear hears it louder and 0.6–0.7 ms sooner.
    func testASourceOnTheRightIsLouderAndEarlierInTheRightEar() {
        let input = noise(24_000)
        let out = render(input, at: HeadphoneSpatializer.Position(azimuth: -90))
        XCTAssertGreaterThan(rms(out.right[2_000...]), rms(out.left[2_000...]) * 1.5, "louder on the right")
        let samples = lag(of: out.left, behind: out.right)
        let seconds = Double(samples) / rate
        XCTAssertTrue((0.000_58...0.000_72).contains(seconds), "left ear late by \(samples) samples")
    }

    func testASourceAheadIsTheSameInBothEars() {
        let out = render(noise(12_000), at: HeadphoneSpatializer.Position(azimuth: 0))
        XCTAssertEqual(out.left, out.right)
        let behind = render(noise(12_000), at: HeadphoneSpatializer.Position(azimuth: 180))
        XCTAssertEqual(behind.left, behind.right)
    }

    func testTheSidesAreMirrors() {
        let input = noise(12_000)
        let left = render(input, at: HeadphoneSpatializer.Position(azimuth: 60, elevation: 20))
        let right = render(input, at: HeadphoneSpatializer.Position(azimuth: -60, elevation: 20))
        XCTAssertEqual(left.left, right.right)
        XCTAssertEqual(left.right, right.left)
    }

    /// A source swept round the head and snapped back halfway glides: no sample of a steady
    /// tone steps further than the tone itself moves between two samples, plus a hair.
    func testAMovementGlidesWithoutAStep() {
        let hz = 500.0
        let input = (0..<48_128).map { (index: Int) -> Float in Float(0.5 * sin(2 * .pi * hz * Double(index) / 48_000)) }
        let unit = HeadphoneSpatializer(sampleRate: rate)
        var left = [Float](repeating: 0, count: input.count), right = left
        let positions: [HeadphoneSpatializer.Position] = [.init(azimuth: 90), .init(azimuth: -90, elevation: 40, distance: 6),
                                                          .init(azimuth: 170), .init(azimuth: -30, elevation: -60)]
        input.withUnsafeBufferPointer { source in
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let s = source.baseAddress, let lb = l.baseAddress, let rb = r.baseAddress else { return }
                    for block in 0..<(input.count / 256) {
                        // A jump of position every 3 000 samples.
                        if block % 12 == 0 { unit.setPosition(positions[(block / 12) % positions.count]) }
                        let at = block * 256
                        unit.process(left: s + at, right: s + at, outLeft: lb + at, outRight: rb + at, frames: 256)
                    }
                }
            }
        }
        // A 500 Hz sine at 0.5 moves at most 0.033 per sample.
        let limit: Float = 0.045
        for ear in [left, right] {
            let steps = zip(ear, ear.dropFirst()).map { Swift.abs($1 - $0) }
            let worst = steps.indices.max { steps[$0] < steps[$1] } ?? 0
            XCTAssertLessThan(steps.isEmpty ? 0 : steps[worst], limit, "at sample \(worst)")
        }
    }

    func testDistanceLowersTheLevelMonotonically() {
        let input = noise(24_000)
        var last = Double.infinity
        for distance in [1.0, 2, 4, 8, 16, 50, 100] {
            let out = render(input, at: HeadphoneSpatializer.Position(azimuth: 30, distance: distance))
            let level = rms(out.left[4_000...]) + rms(out.right[4_000...])
            XCTAssertLessThan(level, last, "distance \(distance)")
            last = level
        }
    }

    func testTheBlockSizeChangesNothing() {
        let input = noise(20_000)
        let position = HeadphoneSpatializer.Position(azimuth: 45, elevation: 30, distance: 3)
        let reference = render(input, at: position, block: 64)
        for block in [1, 256, 4_096, 777] {
            let out = render(input, at: position, block: block)
            XCTAssertEqual(out.left, reference.left, "block \(block)")
            XCTAssertEqual(out.right, reference.right, "block \(block)")
        }
    }

    func testNonFiniteInputAndPositionsStayFinite() {
        var input = noise(4_096)
        input[100] = .nan
        input[200] = .infinity
        input[300] = -.infinity
        let unit = HeadphoneSpatializer(sampleRate: rate)
        let bad = HeadphoneSpatializer.Position(azimuth: .nan, elevation: .infinity, distance: -.infinity)
        XCTAssertEqual(bad, HeadphoneSpatializer.Position(), "a non-finite position is the default one")
        let out = render(input, at: bad, spatializer: unit)
        XCTAssertTrue(out.left.allSatisfy(\.isFinite))
        XCTAssertTrue(out.right.allSatisfy(\.isFinite))
        let after = render(noise(2_048), at: HeadphoneSpatializer.Position(azimuth: -20), spatializer: unit)
        XCTAssertTrue(after.left.allSatisfy(\.isFinite) && after.right.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(rms(after.left[...]), 0.01, "it plays on after the bad samples")
        XCTAssertTrue(HeadphoneSpatializer(sampleRate: .nan).sampleRate == 48_000)
    }

    func testAPanIsTheADMObjectsPlace() {
        XCTAssertEqual(HeadphoneSpatializer.Position.pan(-1).azimuth, 90)
        XCTAssertEqual(HeadphoneSpatializer.Position.pan(1).azimuth, -90)
        XCTAssertEqual(HeadphoneSpatializer.Position.pan(0).azimuth, 0)
        XCTAssertEqual(HeadphoneSpatializer.Position.pan(.nan).azimuth, 0)
    }
}

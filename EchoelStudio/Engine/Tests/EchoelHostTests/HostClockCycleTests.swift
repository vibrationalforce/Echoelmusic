import AudioToolbox
import AVFoundation
import EchoelKernels
import XCTest
@testable import EchoelHost

/// The song loop as the cycle a hosted unit reads through its transport block.
final class HostClockCycleTests: XCTestCase {
    private func transport(cycleStart: Double = 0, cycleEnd: Double = 0) -> HostTransport {
        HostTransport(isPlaying: true, changed: false, tempo: 120, numerator: 4, denominator: 4, beat: 5,
                      downbeat: 4, samplesToNextBeat: 0, sample: 120_000, cycleStart: cycleStart, cycleEnd: cycleEnd)
    }

    private struct Reading {
        var flags: AUHostTransportStateFlags
        var start: Double
        var end: Double
    }

    private func read(_ clock: HostClock) -> Reading {
        var flags = AUHostTransportStateFlags()
        var sample = 0.0, start = -1.0, end = -1.0
        _ = clock.transportStateBlock(&flags, &sample, &start, &end)
        return Reading(flags: flags, start: start, end: end)
    }

    /// A loop over beats 4 to 8 is reported as cycling from 4 to 8; without one there is no cycle.
    func testALoopFromBeatFourToEightIsReportedAsTheCycle() {
        let clock = HostClock()
        clock.update(transport(cycleStart: 4, cycleEnd: 8))
        let looping = read(clock)
        XCTAssertTrue(looping.flags.contains(.cycling))
        XCTAssertTrue(looping.flags.contains(.moving))
        XCTAssertEqual(looping.start, 4)
        XCTAssertEqual(looping.end, 8)

        clock.update(transport())
        let free = read(clock)
        XCTAssertFalse(free.flags.contains(.cycling))
        XCTAssertEqual(free.start, 0)
        XCTAssertEqual(free.end, 0)
    }

    /// A cycle without a length, backwards or not a number is no cycle.
    func testABrokenCycleIsNotReported() {
        let clock = HostClock()
        for (start, end) in [(8.0, 4.0), (4.0, 4.0), (Double.nan, 8.0), (4.0, Double.infinity), (-1.0, 4.0)] {
            clock.update(transport(cycleStart: start, cycleEnd: end))
            let reading = read(clock)
            XCTAssertFalse(reading.flags.contains(.cycling), "\(start)…\(end)")
            XCTAssertEqual(reading.start, 0)
            XCTAssertEqual(reading.end, 0)
        }
    }
}

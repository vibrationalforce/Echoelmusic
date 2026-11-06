import XCTest
@testable import EchoelCore

/// A queued clip's countdown: the boundary it waits for and the bars until it.
final class LaunchCountdownTests: XCTestCase {
    private let meter = MeterMap(signature: .common)
    private let bar = Double(MusicalTime.ticksPerBar(.common))

    func testAClipQueuedAtBarThreeAndAQuarterShowsOneBarUntilLaunch() {
        // Bar 3 is the third bar, from tick 2 bars; a quarter of the way into it.
        let playhead = 2.25 * bar
        let launch = LaunchCountdown.launchTick(after: playhead, quantum: nil, meter: meter)
        XCTAssertEqual(launch, MusicalTime.ticksPerBar(.common) * 3, "it starts on bar 4")
        let bars = LaunchCountdown.barsUntil(launch, from: playhead, meter: meter)
        XCTAssertEqual(bars, 1)
        XCTAssertEqual(LaunchCountdown.text(bars: bars), "1 bar")
    }

    func testOnABarLineTheLaunchIsTheNextBarAndADueLaunchShowsNothing() {
        let launch = LaunchCountdown.launchTick(after: 2 * bar, quantum: nil, meter: meter)
        XCTAssertEqual(Double(launch), 3 * bar)
        XCTAssertEqual(LaunchCountdown.barsUntil(launch, from: 2 * bar, meter: meter), 1)
        XCTAssertEqual(LaunchCountdown.barsUntil(launch, from: Double(launch), meter: meter), 0)
        XCTAssertNil(LaunchCountdown.text(bars: 0))
        XCTAssertEqual(LaunchCountdown.text(bars: 2), "2 bars")
    }

    func testAShorterQuantumWaitsForItsNextMultipleAndNoneStartsAtOnce() {
        let quarter = MusicalTime.ticksPerQuarter
        let playhead = Double(quarter) * 1.5
        XCTAssertEqual(LaunchCountdown.launchTick(after: playhead, quantum: quarter, meter: meter), 2 * quarter)
        XCTAssertEqual(LaunchCountdown.launchTick(after: playhead, quantum: 0, meter: meter), quarter + quarter / 2)
        XCTAssertEqual(LaunchCountdown.barsUntil(2 * quarter, from: playhead, meter: meter), 1)
    }

    func testANonFinitePlayheadShowsNothingAndNeverTraps() {
        XCTAssertEqual(LaunchCountdown.barsUntil(MusicalTime.ticksPerBar(.common), from: .nan, meter: meter), 0)
        XCTAssertEqual(LaunchCountdown.launchTick(after: .infinity, quantum: nil, meter: meter),
                       MusicalTime.ticksPerBar(.common), "a playhead that is no number counts as bar 1")
        XCTAssertEqual(LaunchCountdown.launchTick(after: -480, quantum: nil, meter: meter),
                       MusicalTime.ticksPerBar(.common), "just after Play the heard tick can be a little negative")
    }
}

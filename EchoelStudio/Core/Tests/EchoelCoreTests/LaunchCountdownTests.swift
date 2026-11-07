import XCTest
@testable import EchoelCore

/// A queued clip's countdown: from the moving playhead to the one tick its launch was fixed on.
final class LaunchCountdownTests: XCTestCase {
    private let meter = MeterMap(signature: .common)
    private let bar = Double(MusicalTime.ticksPerBar(.common))
    private let beat = Double(MusicalTime.ticksPerQuarter)

    func testAClipQueuedForTheNextBarCountsDownItsBeatsAsTheSongPlays() {
        // Queued at bar 3 and a quarter: the engine fixed its launch on bar 4.
        let launch = MusicalTime.ticksPerBar(.common) * 3
        var shown: [String] = []
        var playhead = 2.25 * bar
        while playhead < Double(launch) {
            if let text = LaunchCountdown.text(LaunchCountdown.remaining(until: launch, from: playhead, meter: meter)),
               shown.last != text { shown.append(text) }
            playhead += 37.3
        }
        XCTAssertEqual(shown, ["3 beats", "2 beats", "1 beat"], "the label steps down while the clip waits")
        XCTAssertNil(LaunchCountdown.remaining(until: launch, from: Double(launch), meter: meter), "due: nothing")
    }

    func testALaunchMoreThanABarAwayCountsBarsThenBeats() {
        let launch = MusicalTime.ticksPerBar(.common) * 4
        XCTAssertEqual(LaunchCountdown.remaining(until: launch, from: 1.5 * bar, meter: meter), .bars(3))
        XCTAssertEqual(LaunchCountdown.remaining(until: launch, from: 2.5 * bar, meter: meter), .bars(2))
        XCTAssertEqual(LaunchCountdown.remaining(until: launch, from: 3 * bar, meter: meter), .beats(4),
                       "one bar left is counted in its beats")
        XCTAssertEqual(LaunchCountdown.text(.bars(2)), "2 bars")
        XCTAssertEqual(LaunchCountdown.text(.bars(1)), "1 bar")
        XCTAssertEqual(LaunchCountdown.text(.beats(4)), "4 beats")
        XCTAssertNil(LaunchCountdown.text(nil))
    }

    func testTheBeatIsTheMetersOwn() {
        // 6/8: a bar of six eighths.
        let six = MeterMap(signature: TimeSignature(6, 8))
        let eighth = MusicalTime.ticksPerBar(TimeSignature(6, 8)) / 6
        XCTAssertEqual(LaunchCountdown.remaining(until: 6 * eighth, from: Double(eighth), meter: six), .beats(5))
        XCTAssertEqual(LaunchCountdown.remaining(until: Tick(2 * beat), from: 1.5 * beat, meter: meter), .beats(1))
    }

    func testANonFinitePlayheadShowsNothingAndNeverTraps() {
        let launch = MusicalTime.ticksPerBar(.common)
        XCTAssertNil(LaunchCountdown.remaining(until: launch, from: .nan, meter: meter))
        XCTAssertNil(LaunchCountdown.remaining(until: launch, from: .infinity, meter: meter))
        XCTAssertEqual(LaunchCountdown.remaining(until: launch, from: -480, meter: meter), .bars(2),
                       "just after Play the heard tick can be a little negative")
    }
}

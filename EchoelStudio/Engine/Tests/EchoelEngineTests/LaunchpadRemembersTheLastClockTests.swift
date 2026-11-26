import XCTest
@testable import EchoelEngine

/// A Launchpad that no longer gets our clock does not fall back to its own 120 BPM: its flashing
/// and pulsing keep "the last clock if no clock is provided" (Novation programmer's reference for
/// Launchpad X, Mini MK3 and Pro MK3). The light loop keeps the fastest tempo the device may hold
/// from our clock, and the pads animate only while that tempo keeps them at three a second or less.
final class LaunchpadRemembersTheLastClockTests: XCTestCase {
    /// One look of the light loop: the tempo it keeps for the device and whether the pads animate.
    private func look(_ previous: Double?, chosen: Bool, running: Bool, song: Double) -> (kept: Double?, animates: Bool) {
        let kept = Launchpad.keptClockBPM(previous: previous, clockChosen: chosen, clockRunning: running, fastestBPM: song)
        return (kept, Launchpad.animates(keptClockBPM: kept))
    }

    func testADeviceOurClockNeverReachedFlashesOnItsOwnTempo() {
        let never = look(nil, chosen: false, running: true, song: 999)
        XCTAssertNil(never.kept)
        XCTAssertTrue(never.animates, "never clocked by us: the device flashes at its own 120 BPM")
    }

    func testAFastClockStaysKeptAfterItStopsUntilASlowerOneRuns() {
        // Play a 200 BPM song with the clock, stop, open a 120 BPM song without playing it, turn
        // the clock off, press a pad: the device still runs the 200 it heard last.
        let played = look(nil, chosen: true, running: true, song: 200)
        XCTAssertEqual(played.kept, 200)
        XCTAssertFalse(played.animates)
        let stopped = look(played.kept, chosen: true, running: false, song: 120)
        XCTAssertEqual(stopped.kept, 200, "no pulse left while stopped, so nothing lowers it")
        let unchosen = look(stopped.kept, chosen: false, running: true, song: 120)
        XCTAssertEqual(unchosen.kept, 200)
        XCTAssertFalse(unchosen.animates, "the device still runs 200 BPM: the pads stay steady")
        // Only a slower clock whose pulses leave brings the device down again.
        let slower = look(unchosen.kept, chosen: true, running: true, song: 120)
        XCTAssertEqual(slower.kept, 120)
        XCTAssertTrue(slower.animates)
        XCTAssertTrue(look(slower.kept, chosen: false, running: true, song: 200).animates,
                      "the song's tempo does not reach a device the clock is not sent to")
    }

    func testAChosenClockCoversTheSongBeforeItRuns() {
        // Play brings the song's tempo, and a start and stop between two looks would go unseen.
        let fast = look(nil, chosen: true, running: false, song: 200)
        XCTAssertEqual(fast.kept, 200)
        XCTAssertFalse(fast.animates)
        XCTAssertEqual(look(150, chosen: true, running: false, song: 120).kept, 150, "never lowered while no pulse leaves")
        XCTAssertTrue(look(nil, chosen: true, running: false, song: 120).animates)
    }

    func testAnUnknownTempoCountsAsTooFast() {
        XCTAssertFalse(look(nil, chosen: true, running: true, song: .nan).animates)
        XCTAssertFalse(look(.nan, chosen: true, running: false, song: 120).animates, "an unknown kept tempo stays unknown")
        XCTAssertFalse(look(120, chosen: true, running: false, song: .nan).animates)
        XCTAssertFalse(look(.nan, chosen: false, running: false, song: 120).animates)
        XCTAssertFalse(look(120, chosen: true, running: false, song: .infinity).animates)
    }
}

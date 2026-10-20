import XCTest
@testable import EchoelCore

final class SongQuarantineTests: XCTestCase {
    /// What the app keeps across a launch: the two values, read back into a new value.
    private func relaunch(_ quarantine: SongQuarantine) -> SongQuarantine {
        SongQuarantine(opening: quarantine.opening, held: quarantine.held)
    }

    func testTheSongALaunchWasOpeningWhenItDiedIsHeld() {
        var first = SongQuarantine()
        XCTAssertNil(first.launchBegan(previousDied: false))
        first.willOpen("Crash.echoel")
        var next = relaunch(first)
        XCTAssertEqual(next.launchBegan(previousDied: true), "Crash.echoel")
        XCTAssertTrue(next.holds("Crash.echoel"))
        XCTAssertNil(next.opening, "the new launch has opened nothing yet")
    }

    /// The cycle the review found: crash, new song, the same song again, crash. A held song stays
    /// held through any number of healthy launches until it is chosen.
    func testAHeldSongStaysHeldThroughHealthyLaunchesUntilItIsChosen() {
        var quarantine = SongQuarantine()
        _ = quarantine.launchBegan(previousDied: false)
        quarantine.willOpen("Crash.echoel")
        quarantine = relaunch(quarantine)
        _ = quarantine.launchBegan(previousDied: true)
        for _ in 0..<3 {
            quarantine.willOpen("Other.echoel")
            quarantine.launchConfirmed()
            quarantine = relaunch(quarantine)
            XCTAssertNil(quarantine.launchBegan(previousDied: false))
            XCTAssertTrue(quarantine.holds("Crash.echoel"))
        }
        quarantine.chosen("Crash.echoel")
        XCTAssertFalse(quarantine.holds("Crash.echoel"))
    }

    func testAConfirmedLaunchHoldsNothing() {
        var quarantine = SongQuarantine()
        _ = quarantine.launchBegan(previousDied: false)
        quarantine.willOpen("Fine.echoel")
        quarantine.launchConfirmed()
        var next = relaunch(quarantine)
        XCTAssertNil(next.launchBegan(previousDied: true), "a death after the confirmation names no song")
        XCTAssertEqual(next.held, [])
    }

    func testANewSongClearsTheSongBeingOpened() {
        var quarantine = SongQuarantine()
        _ = quarantine.launchBegan(previousDied: false)
        quarantine.willOpen("Old.echoel")
        quarantine.willOpen(nil)
        var next = relaunch(quarantine)
        XCTAssertNil(next.launchBegan(previousDied: true))
    }

    func testHoldingIsBoundedAndKeepsTheMostRecent() {
        var quarantine = SongQuarantine()
        for index in 0..<(SongQuarantine.capacity + 3) {
            quarantine.willOpen("Song \(index).echoel")
            quarantine = relaunch(quarantine)
            _ = quarantine.launchBegan(previousDied: true)
        }
        XCTAssertEqual(quarantine.held.count, SongQuarantine.capacity)
        XCTAssertTrue(quarantine.holds("Song \(SongQuarantine.capacity + 2).echoel"))
        XCTAssertFalse(quarantine.holds("Song 0.echoel"))
    }

    func testEmptyAndRepeatedNamesFromTheDefaultsAreDropped() {
        let quarantine = SongQuarantine(opening: "", held: ["", "B.echoel", "B.echoel"])
        XCTAssertNil(quarantine.opening)
        XCTAssertEqual(quarantine.held, ["B.echoel"])
    }
}

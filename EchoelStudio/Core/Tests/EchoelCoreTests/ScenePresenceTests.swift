import Foundation
import XCTest
@testable import EchoelCore

/// The lights are let go only when the LAST window leaves the foreground (Q2): one of two iPad
/// windows closing, going inactive or to the background while the other stays in front leaves
/// the rig as it is.
final class ScenePresenceTests: XCTestCase {
    func testTheDecisionLooksAtEveryWindow() {
        XCTAssertFalse(ScenePresence.isAway([.active]))
        XCTAssertFalse(ScenePresence.isAway([.inactive]), "an inactive window is still on screen")
        XCTAssertTrue(ScenePresence.isAway([.background]))
        XCTAssertFalse(ScenePresence.isAway([.background, .active]), "one window in front keeps the rig")
        XCTAssertFalse(ScenePresence.isAway([.background, .inactive]))
        XCTAssertTrue(ScenePresence.isAway([.background, .background]))
        XCTAssertTrue(ScenePresence.isAway([]), "no window left: nothing holds the app in front")
    }

    func testTheAppInTheBackgroundOutranksAWindowThatNeverSaidGoodbye() {
        var presence = ScenePresence()
        let silent = UUID()
        let other = UUID()
        presence.report(.active, for: silent)
        presence.report(.background, for: other)
        XCTAssertFalse(presence.isAway, "the silent window still counts as in front")
        presence.appEnteredBackground()
        XCTAssertTrue(presence.isAway, "the app's own background says no window is in front")
        XCTAssertEqual(presence.count, 2, "the windows stay known and can report again")
        presence.report(.active, for: other)
        XCTAssertFalse(presence.isAway)
    }

    func testOneOfTwoWindowsGoingToTheBackgroundKeepsTheRig() {
        let first = UUID()
        let second = UUID()
        var presence = ScenePresence()
        presence.report(.active, for: first)
        presence.report(.active, for: second)
        XCTAssertFalse(presence.isAway)
        presence.report(.inactive, for: first)
        XCTAssertFalse(presence.isAway, "a window that loses the focus is not the app leaving")
        presence.report(.background, for: first)
        XCTAssertFalse(presence.isAway, "the other window is still in front")
        presence.report(.background, for: second)
        XCTAssertTrue(presence.isAway, "the last window went to the background")
        presence.report(.active, for: first)
        XCTAssertFalse(presence.isAway, "a window back in front takes the rig back")
    }

    func testOneOfTwoWindowsClosingKeepsTheRig() {
        let first = UUID()
        let second = UUID()
        var presence = ScenePresence()
        presence.report(.active, for: first)
        presence.report(.active, for: second)
        presence.remove(first)
        XCTAssertFalse(presence.isAway)
        XCTAssertEqual(presence.count, 1)
        presence.remove(second)
        XCTAssertTrue(presence.isAway, "the last window closed")
        XCTAssertEqual(presence.count, 0)
    }

    func testAClosedWindowNoLongerCounts() {
        let gone = UUID()
        let staying = UUID()
        var presence = ScenePresence()
        presence.report(.active, for: gone)
        presence.report(.background, for: staying)
        XCTAssertFalse(presence.isAway)
        presence.remove(gone)
        XCTAssertTrue(presence.isAway, "the window in front closed; the one left is in the background")
        presence.remove(UUID())
        XCTAssertEqual(presence.count, 1, "removing a window never seen changes nothing")
    }
}

import Foundation
import XCTest
@testable import EchoelCore

/// A destination that is opened, closed and opened again in every order Go Live, Stop and a slow
/// server allow (wave W14).
final class StreamOpeningsTests: XCTestCase {
    private let first = UUID()
    private let second = UUID()

    func testAnOpenIsUnderWayUntilItFinishes() {
        var openings = StreamOpenings()
        let attempt = openings.begin(first)
        XCTAssertTrue(openings.isUnderWay(attempt, for: first))
        openings.finish(attempt, for: first)
        XCTAssertFalse(openings.isUnderWay(attempt, for: first), "live or failed, it is no longer being opened")
    }

    /// Stop before the session is kept: the open must find out, or it connects after the Stop.
    func testACloseEndsTheOpenUnderWay() {
        var openings = StreamOpenings()
        let attempt = openings.begin(first)
        openings.close(first)
        XCTAssertFalse(openings.isUnderWay(attempt, for: first))
    }

    func testStopEndsEveryOpenUnderWay() {
        var openings = StreamOpenings()
        let one = openings.begin(first)
        let other = openings.begin(second)
        openings.closeAll()
        XCTAssertFalse(openings.isUnderWay(one, for: first))
        XCTAssertFalse(openings.isUnderWay(other, for: second))
    }

    func testClosingOneDestinationLeavesTheOtherBeingOpened() {
        var openings = StreamOpenings()
        let one = openings.begin(first)
        let other = openings.begin(second)
        openings.close(first)
        XCTAssertFalse(openings.isUnderWay(one, for: first))
        XCTAssertTrue(openings.isUnderWay(other, for: second))
    }

    /// Stop while a destination connects, then Go Live again before that connection answers: the
    /// first attempt must not go on as if it were the new one.
    func testAnAttemptEndedByACloseStaysEndedWhenTheDestinationOpensAgain() {
        var openings = StreamOpenings()
        let stopped = openings.begin(first)
        openings.close(first)
        let again = openings.begin(first)
        XCTAssertNotEqual(stopped, again, "a number is never used twice")
        XCTAssertFalse(openings.isUnderWay(stopped, for: first))
        XCTAssertTrue(openings.isUnderWay(again, for: first))
    }

    func testANewerOpenOfTheSameDestinationReplacesTheOlder() {
        var openings = StreamOpenings()
        let older = openings.begin(first)
        let newer = openings.begin(first)
        XCTAssertFalse(openings.isUnderWay(older, for: first))
        XCTAssertTrue(openings.isUnderWay(newer, for: first))
    }

    /// The older attempt ends late — its server answered at last — and tidies up after itself:
    /// the newer attempt for the same destination is still the one being opened.
    func testAnOlderAttemptThatFinishesLateLeavesTheNewerUnderWay() {
        var openings = StreamOpenings()
        let older = openings.begin(first)
        let newer = openings.begin(first)
        openings.finish(older, for: first)
        XCTAssertTrue(openings.isUnderWay(newer, for: first))
    }

    func testAnAttemptIsOnlyUnderWayForItsOwnDestination() {
        var openings = StreamOpenings()
        let attempt = openings.begin(first)
        XCTAssertFalse(openings.isUnderWay(attempt, for: second))
        openings.finish(attempt, for: second)
        XCTAssertTrue(openings.isUnderWay(attempt, for: first), "finishing under another destination's name ends nothing")
    }
}

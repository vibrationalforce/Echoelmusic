import Foundation
import XCTest
@testable import EchoelCore

/// Go Live, Stop and a second Go Live in every order the buttons and iOS allow (wave W14).
final class StreamLifecycleTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)

    func testAStreamGoesLiveAndStopsCleanly() throws {
        var life = StreamLifecycle()
        XCTAssertFalse(life.isOn)
        let attempt = try XCTUnwrap(life.begin())
        XCTAssertEqual(life.phase, .starting)
        XCTAssertTrue(life.isOn)
        XCTAssertNil(life.startedAt, "connecting is not on air")
        XCTAssertTrue(life.wentLive(attempt, at: noon))
        XCTAssertEqual(life.startedAt, noon)
        XCTAssertTrue(life.isLive)
        XCTAssertTrue(life.beginStopping())
        XCTAssertEqual(life.phase, .stopping)
        XCTAssertTrue(life.isOn, "the list stays locked until everything is closed")
        XCTAssertNil(life.startedAt)
        life.stopped()
        XCTAssertEqual(life.phase, .off)
    }

    func testGoLiveIsRefusedWhileAStreamIsOnOrStillClosing() throws {
        var life = StreamLifecycle()
        let attempt = try XCTUnwrap(life.begin())
        XCTAssertNil(life.begin(), "a second Go Live while connecting")
        life.wentLive(attempt, at: noon)
        XCTAssertNil(life.begin(), "a second Go Live while live")
        life.beginStopping()
        XCTAssertNil(life.begin(), "Go Live while the last stream still closes")
        life.stopped()
        XCTAssertNotNil(life.begin())
    }

    /// The race the two flags allowed: Stop while a destination connects, then Go Live again
    /// before that connection answers. The first attempt must not continue as if it were the new one.
    func testAnAttemptStoppedWhileConnectingNeverBecomesLiveLater() throws {
        var life = StreamLifecycle()
        let first = try XCTUnwrap(life.begin())
        XCTAssertTrue(life.beginStopping())
        life.stopped()
        let second = try XCTUnwrap(life.begin())
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(life.isStarting(first), "the stopped attempt sees that it is over")
        XCTAssertTrue(life.isStarting(second))
        XCTAssertFalse(life.wentLive(first, at: noon))
        XCTAssertEqual(life.phase, .starting, "the stale attempt changed nothing")
        XCTAssertTrue(life.wentLive(second, at: noon))
    }

    func testStopMeansNothingWhenOffOrAlreadyClosing() throws {
        var life = StreamLifecycle()
        XCTAssertFalse(life.canStop)
        XCTAssertFalse(life.beginStopping())
        XCTAssertEqual(life.phase, .off)
        let attempt = try XCTUnwrap(life.begin())
        XCTAssertTrue(life.beginStopping(), "a start nobody accepted closes too")
        XCTAssertFalse(life.canStop)
        XCTAssertFalse(life.beginStopping(), "a second end while closing")
        XCTAssertFalse(life.wentLive(attempt, at: noon), "a closing attempt never goes live")
        life.stopped()
        life.stopped()
        XCTAssertEqual(life.phase, .off)
    }
}

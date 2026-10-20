import EchoelCore
import XCTest

final class LaunchRecordTests: XCTestCase {
    func testALaunchThatIsNeverConfirmedIsReportedByTheNextOne() {
        var record = LaunchRecord()
        XCTAssertFalse(record.begin(), "a first launch has no previous one")
        XCTAssertTrue(record.isPending)
        // The app dies here; the next launch reads the stored flag.
        var next = LaunchRecord(isPending: record.isPending)
        XCTAssertTrue(next.begin(), "the previous launch never confirmed")
        XCTAssertTrue(next.isPending, "and this one is pending until it confirms")
    }

    func testALaunchConfirmsAfterTheSteadyTimeOrWhenItLeavesAfterTheFloor() {
        var record = LaunchRecord()
        _ = record.begin()
        XCTAssertFalse(record.confirm(after: LaunchRecord.steadySeconds - 0.5, leaving: false))
        XCTAssertTrue(record.confirm(after: LaunchRecord.steadySeconds, leaving: false))
        XCTAssertFalse(record.isPending)
        XCTAssertFalse(record.confirm(after: 60, leaving: false), "already confirmed")

        var leaving = LaunchRecord()
        _ = leaving.begin()
        XCTAssertFalse(leaving.confirm(after: LaunchRecord.leaveFloorSeconds - 0.5, leaving: true),
                       "a quick exit is not told apart from a crash")
        XCTAssertTrue(leaving.confirm(after: LaunchRecord.leaveFloorSeconds, leaving: true))
        XCTAssertFalse(LaunchRecord(isPending: leaving.isPending).isPending)

        var broken = LaunchRecord()
        _ = broken.begin()
        XCTAssertFalse(broken.confirm(after: .nan, leaving: false))
        XCTAssertFalse(broken.confirm(after: .infinity, leaving: true))
        XCTAssertTrue(broken.isPending)
    }

    func testAConfirmedLaunchLetsTheNextOpenAsUsual() {
        var record = LaunchRecord()
        _ = record.begin()
        record.confirm(after: LaunchRecord.steadySeconds, leaving: false)
        var next = LaunchRecord(isPending: record.isPending)
        XCTAssertFalse(next.begin())
    }
}

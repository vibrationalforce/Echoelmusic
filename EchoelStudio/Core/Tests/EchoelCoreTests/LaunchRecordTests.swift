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

    func testALaunchConfirmsAfterTheSteadyTimeOrWhenItLeaves() {
        var record = LaunchRecord()
        _ = record.begin()
        XCTAssertFalse(record.confirm(after: LaunchRecord.steadySeconds - 0.5, leaving: false))
        XCTAssertTrue(record.confirm(after: LaunchRecord.steadySeconds, leaving: false))
        XCTAssertFalse(record.isPending)
        XCTAssertFalse(record.confirm(after: 60, leaving: false), "already confirmed")

        // A song opened and left at once: the launch got to the background alive, and a system
        // that ends the app there later is no reason to hold the song (review 2026-10-22).
        var leaving = LaunchRecord()
        _ = leaving.begin()
        XCTAssertTrue(leaving.confirm(after: 0.8, leaving: true))
        XCTAssertFalse(LaunchRecord(isPending: leaving.isPending).isPending)
        var next = LaunchRecord(isPending: leaving.isPending)
        XCTAssertFalse(next.begin(), "the next launch opens the song as usual")

        var broken = LaunchRecord()
        _ = broken.begin()
        XCTAssertFalse(broken.confirm(after: .nan, leaving: false))
        XCTAssertFalse(broken.confirm(after: .infinity, leaving: true))
        XCTAssertFalse(broken.confirm(after: -1, leaving: true), "a clock that went back says nothing")
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

import XCTest
@testable import EchoelEngine

final class PhaseLockTests: XCTestCase {
    func testJitterIsLeftAloneADriftIsTakenOutGentlyAndAJumpRelocks() {
        var lock = PhaseLock()
        XCTAssertEqual(lock.correct(error: 0.0015), .none, "inside the deadband")
        lock.reset()
        // A steady 10 ms lead: every correction pulls back, never more than the ceiling, and
        // the sum of corrections closes the gap.
        var error = 0.010
        var moved = 0.0
        for _ in 0..<200 {
            guard case .nudge(let seconds) = lock.correct(error: error) else { continue }
            XCTAssertLessThan(seconds, 0, "back, since the song is ahead")
            XCTAssertLessThanOrEqual(abs(seconds), PhaseLock.maximumNudge + 1e-12)
            error += seconds
            moved += seconds
        }
        XCTAssertLessThan(abs(error), PhaseLock.deadband + 1e-9, "locked")
        XCTAssertEqual(moved, -0.010, accuracy: PhaseLock.deadband)
        XCTAssertEqual(lock.correct(error: 0.5), .relock, "too far to nudge")
        XCTAssertEqual(lock.correct(error: .nan), .none)
    }
}

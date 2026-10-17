import XCTest
@testable import EchoelEngine

final class ClockFollowerTests: XCTestCase {
    func testTheTempoComesFromAQuarterOfPulsesAndIgnoresJitterAndPauses() {
        var follower = ClockFollower()
        let spacing = 0.5 / 24                         // 120 BPM
        var time = 0.0
        for n in 0..<24 {
            _ = follower.receive(status: 0xF8, at: time)
            time += spacing + (n % 2 == 0 ? 0.0004 : -0.0004)
        }
        XCTAssertNil(follower.tempo, "not before a full quarter of intervals")
        _ = follower.receive(status: 0xF8, at: time)
        XCTAssertEqual(follower.tempo ?? 0, 120, accuracy: 0.05)

        time += 3                                      // the sender paused
        _ = follower.receive(status: 0xF8, at: time)
        XCTAssertEqual(follower.tempo ?? 0, 120, accuracy: 0.05, "a pause is not a slow beat")
    }

    func testTransportMessagesBecomeActions() {
        var follower = ClockFollower()
        XCTAssertEqual(follower.receive(status: 0xFA, at: 0), .start)
        XCTAssertEqual(follower.receive(status: 0xFC, at: 1), .stop)
        XCTAssertEqual(follower.receive(status: 0xF2, 16, 1, at: 1), .position(16 + 128))
        XCTAssertEqual(follower.receive(status: 0xFB, at: 2), .resume)
        XCTAssertNil(follower.receive(status: 0xFE, at: 2), "active sensing is not transport")
    }
}

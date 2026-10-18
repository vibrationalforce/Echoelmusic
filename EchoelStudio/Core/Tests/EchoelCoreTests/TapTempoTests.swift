import XCTest
@testable import EchoelCore

final class TapTempoTests: XCTestCase {
    func testTapsInTimeGiveTheTempoAndOneStrayTapDoesNotPullIt() {
        var taps = TapTempo()
        XCTAssertNil(taps.tap(at: 10), "one tap is no tempo")
        XCTAssertEqual(taps.tap(at: 10.5), 120)
        XCTAssertEqual(taps.tap(at: 11.0), 120)
        XCTAssertEqual(taps.tap(at: 11.62), 120, "a late tap")
        XCTAssertEqual(taps.tap(at: 12.0), 120)
        XCTAssertEqual(taps.tap(at: 12.5), 120)
    }

    func testAPauseStartsAgainAndTheResultStaysInRange() {
        var taps = TapTempo()
        _ = taps.tap(at: 0)
        _ = taps.tap(at: 0.5)
        XCTAssertFalse(taps.startsOver(at: 1))
        XCTAssertTrue(taps.startsOver(at: 3))
        XCTAssertNil(taps.tap(at: 3), "after a pause the first tap starts a new measurement")
        XCTAssertEqual(taps.tap(at: 3.75), 80)
        var fast = TapTempo()
        _ = fast.tap(at: 0)
        XCTAssertEqual(fast.tap(at: 0.01), Tempo.range.upperBound)
        XCTAssertNil(fast.tap(at: .nan))
        XCTAssertTrue(fast.startsOver(at: 0.005), "time running backwards starts over")
    }
}

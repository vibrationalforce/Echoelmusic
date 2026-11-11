import XCTest
@testable import EchoelCore

/// A touch on a screen key plays softer at its far end and harder at its foot.
final class TouchVelocityTests: XCTestCase {
    func testTheEndsOfAKeyAreTheSoftestAndTheHardest() {
        XCTAssertEqual(TouchVelocity.velocity(at: 0), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(at: 1), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.hardest, 127)
        XCTAssertGreaterThan(TouchVelocity.softest, 0, "a touch is never a note-off")
    }

    func testFurtherDownTheKeyIsNeverSofter() {
        var last = TouchVelocity.velocity(at: 0)
        for step in 1...100 {
            let now = TouchVelocity.velocity(at: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(now, last, "step \(step)")
            last = now
        }
    }

    /// The middle of a key plays within a few steps of what every screen key played before.
    func testTheMiddlePlaysAboutWhatAKeyPlayedBefore() {
        let middle = Int(TouchVelocity.velocity(at: 0.5))
        XCTAssertEqual(middle, 94)
        XCTAssertLessThanOrEqual(Swift.abs(middle - Int(TouchVelocity.unplaced)), 8)
    }

    func testAPlaceOutsideTheKeyCountsAsItsNearerEnd() {
        XCTAssertEqual(TouchVelocity.velocity(at: -3), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(at: 7), TouchVelocity.hardest)
    }

    func testAPlaceThatIsNoNumberPlaysTheUnplacedLoudness() {
        XCTAssertEqual(TouchVelocity.velocity(at: Double.nan), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(at: Double.infinity), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: 0), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: -5), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: Double.nan, length: 100), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.unplaced, 100)
    }

    func testAnOffsetDownAKeyIsItsShareOfTheLength() {
        XCTAssertEqual(TouchVelocity.velocity(offset: 0, length: 132), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(offset: 132, length: 132), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.velocity(offset: 66, length: 132), TouchVelocity.velocity(at: 0.5))
        XCTAssertEqual(TouchVelocity.velocity(offset: 33, length: 132), 77, "a quarter down: 60 + 67 × 0.25 = 76.75")
    }
}

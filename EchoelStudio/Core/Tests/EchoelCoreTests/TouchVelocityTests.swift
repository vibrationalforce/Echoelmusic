import XCTest
@testable import EchoelCore

/// A touch on a screen key plays softer at its far end and harder at its foot, and exactly as it
/// always did in its middle.
final class TouchVelocityTests: XCTestCase {
    func testTheEndsOfAKeyAreTheSoftestAndTheHardest() {
        XCTAssertEqual(TouchVelocity.velocity(at: 0), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(at: 1), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.softest, 60)
        XCTAssertEqual(TouchVelocity.hardest, 127)
    }

    /// The middle of a key plays the loudness every screen key had before, so a synth's Accent
    /// (from velocity 100) answers to a tap in the middle as it did.
    func testTheMiddlePlaysWhatAKeyAlwaysPlayed() {
        XCTAssertEqual(TouchVelocity.velocity(at: 0.5), 100)
        XCTAssertEqual(TouchVelocity.middle, 100)
        XCTAssertEqual(TouchVelocity.unplaced, TouchVelocity.middle)
        XCTAssertLessThan(TouchVelocity.velocity(at: 0.49), 100, "above the middle is softer")
        XCTAssertGreaterThan(TouchVelocity.velocity(at: 0.51), 100, "below it harder")
    }

    func testEachHalfIsAStraightLine() {
        XCTAssertEqual(TouchVelocity.velocity(at: 0.25), 80, "60 + 40 × 0.5")
        XCTAssertEqual(TouchVelocity.velocity(at: 0.75), 114, "100 + 27 × 0.5 = 113.5, rounded away from zero")
    }

    func testFurtherDownTheKeyIsNeverSofter() {
        var last = TouchVelocity.velocity(at: 0)
        for step in 1...100 {
            let now = TouchVelocity.velocity(at: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(now, last, "step \(step)")
            last = now
        }
    }

    func testAPlaceOutsideTheKeyCountsAsItsNearerEnd() {
        XCTAssertEqual(TouchVelocity.velocity(at: -3), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(at: 7), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.velocity(at: -Double.infinity), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(at: Double.infinity), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.velocity(offset: -20, length: 132), TouchVelocity.softest,
                       "a touch above where the key's own part starts plays its top")
    }

    func testAPlaceThatIsNoNumberPlaysTheUnplacedLoudness() {
        XCTAssertEqual(TouchVelocity.velocity(at: Double.nan), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: Double.nan, length: 100), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: 0), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: -5), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: Double.infinity), TouchVelocity.unplaced)
        XCTAssertEqual(TouchVelocity.velocity(offset: 10, length: Double.nan), TouchVelocity.unplaced)
    }

    func testAnOffsetDownAKeyIsItsShareOfTheLength() {
        XCTAssertEqual(TouchVelocity.velocity(offset: 0, length: 132), TouchVelocity.softest)
        XCTAssertEqual(TouchVelocity.velocity(offset: 132, length: 132), TouchVelocity.hardest)
        XCTAssertEqual(TouchVelocity.velocity(offset: 66, length: 132), 100)
        XCTAssertEqual(TouchVelocity.velocity(offset: 33, length: 132), 80)
    }
}

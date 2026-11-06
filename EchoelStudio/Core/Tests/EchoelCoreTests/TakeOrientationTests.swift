import XCTest
@testable import EchoelCore

/// A video take is turned the way the phone is held, and stays so while it runs (wave W7).
final class TakeOrientationTests: XCTestCase {
    func testALandscapeTakeIsWiderThanTall() {
        var orientation = TakeOrientation()
        orientation.held(.landscapeLeft, lens: .back)
        let size = orientation.frameSize(sensorWidth: 1920, sensorHeight: 1080)
        XCTAssertGreaterThan(size.width, size.height)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
        orientation.held(.landscapeRight, lens: .front)
        let front = orientation.frameSize(sensorWidth: 1080, sensorHeight: 1920)
        XCTAssertGreaterThan(front.width, front.height, "the sensor's sides in either order")
    }

    func testAnUprightTakeIsTallerThanWide() {
        var orientation = TakeOrientation()
        let fresh = orientation.frameSize(sensorWidth: 1920, sensorHeight: 1080)
        XCTAssertGreaterThan(fresh.height, fresh.width, "upright until the phone says otherwise")
        orientation.held(.landscapeLeft, lens: .back)
        orientation.held(.portraitUpsideDown, lens: .back)
        XCTAssertEqual(orientation.angle, 270)
        let size = orientation.frameSize(sensorWidth: 1920, sensorHeight: 1080)
        XCTAssertGreaterThan(size.height, size.width)
    }

    func testEachHoldHasItsAngleAndTheFrontLensTurnsLandscapeTheOtherWay() {
        XCTAssertEqual(TakeOrientation.angle(for: .portrait, lens: .back), 90)
        XCTAssertEqual(TakeOrientation.angle(for: .portraitUpsideDown, lens: .back), 270)
        XCTAssertEqual(TakeOrientation.angle(for: .landscapeLeft, lens: .back), 0)
        XCTAssertEqual(TakeOrientation.angle(for: .landscapeRight, lens: .back), 180)
        XCTAssertEqual(TakeOrientation.angle(for: .landscapeLeft, lens: .front), 180)
        XCTAssertEqual(TakeOrientation.angle(for: .landscapeRight, lens: .front), 0)
        XCTAssertEqual(TakeOrientation.angle(for: .portrait, lens: .front), 90)
    }

    func testAPhoneLyingFlatKeepsTheLastAngle() {
        var orientation = TakeOrientation()
        orientation.held(.landscapeRight, lens: .back)
        orientation.held(.faceUp, lens: .back)
        XCTAssertEqual(orientation.angle, 180, "face up names no up")
        orientation.held(.faceDown, lens: .back)
        XCTAssertEqual(orientation.angle, 180, "nor does face down")
        orientation.held(.unknown, lens: .back)
        XCTAssertEqual(orientation.angle, 180)
        XCTAssertTrue(orientation.isLandscape)
    }

    func testARunningTakeNeverFlips() {
        var orientation = TakeOrientation()
        orientation.held(.landscapeLeft, lens: .back)
        orientation.beginTake()
        orientation.held(.portrait, lens: .back)
        orientation.captured(angle: 90)
        XCTAssertEqual(orientation.angle, 0, "the take keeps the angle it began with")
        let size = orientation.frameSize(sensorWidth: 1920, sensorHeight: 1080)
        XCTAssertGreaterThan(size.width, size.height)
        orientation.endTake()
        orientation.held(.portrait, lens: .back)
        XCTAssertEqual(orientation.angle, 90, "after the take the angle follows the phone again")
    }

    func testTheCoordinatorsReadingIsSnappedAndANonFiniteOneIgnored() {
        var orientation = TakeOrientation()
        orientation.captured(angle: 179.6)
        XCTAssertEqual(orientation.angle, 180)
        orientation.captured(angle: .nan)
        XCTAssertEqual(orientation.angle, 180)
        orientation.captured(angle: .infinity)
        XCTAssertEqual(orientation.angle, 180)
        orientation.captured(angle: 360)
        XCTAssertEqual(orientation.angle, 0)
        orientation.captured(angle: -90)
        XCTAssertEqual(orientation.angle, 270)
    }
}

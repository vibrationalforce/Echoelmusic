import XCTest
@testable import EchoelCore

final class SpokenTests: XCTestCase {
    func testAPanPositionIsSaidInWordsOnTheScreensRounding() {
        XCTAssertEqual(Spoken.pan(0), "Center")
        XCTAssertEqual(Spoken.pan(0.004), "Center", "the screen shows C here too")
        XCTAssertEqual(Spoken.pan(-0.2), "20 percent left")
        XCTAssertEqual(Spoken.pan(0.2), "20 percent right")
        XCTAssertEqual(Spoken.pan(-1), "100 percent left")
        XCTAssertEqual(Spoken.pan(1), "100 percent right")
        XCTAssertEqual(Spoken.pan(0.333), "33 percent right")
        XCTAssertEqual(Spoken.pan(.nan), "Center", "a value that is no number says nothing alarming")
        XCTAssertEqual(Spoken.pan(-.infinity), "Center")
    }

    func testAControllerIsSaidAsTheDeviceCountsIt() {
        XCTAssertEqual(Spoken.control(MIDIControl(channel: 0, number: 7)), "controller 7 on channel 1")
        XCTAssertEqual(Spoken.control(MIDIControl(channel: 15, number: 127)), "controller 127 on channel 16")
    }
}

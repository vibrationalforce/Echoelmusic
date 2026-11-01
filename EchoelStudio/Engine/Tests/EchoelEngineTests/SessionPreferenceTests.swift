import XCTest
@testable import EchoelEngine

final class SessionPreferenceTests: XCTestCase {
    /// 512 frames at the 48 kHz asked for are 10.7 ms, the earlier app's measured buffer; at a
    /// granted 44.1 kHz the buffer asked again is still 512 frames, 11.6 ms.
    func testTheBufferIsFiveHundredTwelveFramesAtWhateverRateIsGranted() {
        XCTAssertEqual(SessionPreference.sampleRate, 48_000)
        XCTAssertEqual(SessionPreference.bufferDuration(atRate: 48_000) * 1_000, 10.667, accuracy: 0.001)
        XCTAssertEqual(SessionPreference.bufferDuration(atRate: 44_100) * 44_100, 512, accuracy: 1e-9)
        XCTAssertEqual(SessionPreference.bufferDuration(atRate: 96_000) * 96_000, 512, accuracy: 1e-9)
    }

    func testARateThatIsNoNumberAsksAtTheRateAskedFor() {
        for rate in [0.0, -44_100, .nan, .infinity] {
            XCTAssertEqual(SessionPreference.bufferDuration(atRate: rate), 512 / 48_000.0)
        }
    }

    /// The buffer is asked again only when the session reports a rate, and another one.
    func testTheBufferIsAskedAgainOnlyAtAnotherRate() {
        XCTAssertFalse(SessionPreference.asksAgain(asked: 48_000, granted: 48_000))
        XCTAssertFalse(SessionPreference.asksAgain(asked: 48_000, granted: 48_000.5))
        XCTAssertTrue(SessionPreference.asksAgain(asked: 48_000, granted: 44_100))
        XCTAssertFalse(SessionPreference.asksAgain(asked: 48_000, granted: 0))
        XCTAssertFalse(SessionPreference.asksAgain(asked: 48_000, granted: .nan))
    }
}

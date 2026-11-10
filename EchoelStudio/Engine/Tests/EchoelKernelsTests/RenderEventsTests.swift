import XCTest
@testable import EchoelKernels

/// A render block reads a host's numbers without stopping its process (`RenderEvents`). The
/// expected values follow from the definition: an event plays at its distance from the call's
/// first sample, held between the frames already rendered and the call's length.
final class RenderEventsTests: XCTestCase {
    func testAnEventFallsOnItsFrameInsideTheCall() {
        XCTAssertEqual(RenderEvents.offset(eventTime: 1_100, start: 1_000, done: 0, frames: 256), 100)
        XCTAssertEqual(RenderEvents.offset(eventTime: 900, start: 1_000, done: 0, frames: 256), 0, "a late event plays at once")
        XCTAssertEqual(RenderEvents.offset(eventTime: 5_000, start: 1_000, done: 0, frames: 256), 256, "an early one waits for the end")
        XCTAssertEqual(RenderEvents.offset(eventTime: 1_010, start: 1_000, done: 64, frames: 256), 64, "never before what is rendered")
        XCTAssertEqual(RenderEvents.offset(eventTime: -400, start: -512, done: 0, frames: 256), 112, "a pre-roll counts from below zero")
    }

    func testTimesAtTheEdgesOfTheirTypeHaveAnAnswer() {
        XCTAssertEqual(RenderEvents.offset(eventTime: .min, start: .max, done: 3, frames: 256), 3)
        XCTAssertEqual(RenderEvents.offset(eventTime: .max, start: .min, done: 3, frames: 256), 256)
        XCTAssertEqual(RenderEvents.offset(eventTime: .min, start: 4_096, done: 0, frames: 256), 0)
        XCTAssertEqual(RenderEvents.offset(eventTime: .max, start: -1, done: 0, frames: 256), 256)
        XCTAssertEqual(RenderEvents.offset(eventTime: 10, start: 0, done: 300, frames: 256), 300, "what is rendered is never taken back")
    }

    func testASampleTimeThatIsNoTimeCountsAsZero() {
        XCTAssertEqual(RenderEvents.start(sampleTime: 48_000), 48_000)
        XCTAssertEqual(RenderEvents.start(sampleTime: 48_000.9), 48_000, "cut, as the conversion before it")
        XCTAssertEqual(RenderEvents.start(sampleTime: -512.9), -512)
        let unusable: [Double] = [.nan, .infinity, -.infinity, 1e300, -1e300]
        for time in unusable {
            XCTAssertEqual(RenderEvents.start(sampleTime: time), 0, "\(time)")
        }
    }

    func testAnAddressBeyondAnIndexNamesNoParameter() {
        XCTAssertEqual(RenderEvents.address(0), 0)
        XCTAssertEqual(RenderEvents.address(7), 7)
        XCTAssertEqual(RenderEvents.address(.max), -1)
    }
}

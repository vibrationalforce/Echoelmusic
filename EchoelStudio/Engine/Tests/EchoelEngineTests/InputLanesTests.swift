import XCTest
@testable import EchoelEngine

final class InputLanesTests: XCTestCase {
    private typealias Lane = InputLanes.Lane

    func testEachInputHasItsOwnBufferOrItsOwnLane() {
        XCTAssertEqual(InputLanes.find(3, buffers: 4, channelsPerBuffer: 1), Lane(buffer: 3, lane: 0),
                       "one buffer per channel")
        XCTAssertEqual(InputLanes.find(3, buffers: 1, channelsPerBuffer: 4), Lane(buffer: 0, lane: 3),
                       "every channel interleaved in one buffer")
        XCTAssertNil(InputLanes.find(4, buffers: 4, channelsPerBuffer: 1))
        XCTAssertNil(InputLanes.find(4, buffers: 1, channelsPerBuffer: 4))
        XCTAssertNil(InputLanes.find(-1, buffers: 4, channelsPerBuffer: 1))
        XCTAssertNil(InputLanes.find(0, buffers: 0, channelsPerBuffer: 2))
        XCTAssertEqual(InputLanes.find(0, buffers: 1, channelsPerBuffer: 0), Lane(buffer: 0, lane: 0),
                       "a buffer that claims no channels still carries one")
    }

    func testAPairKeepsItsLeftOnTheLeftAndItsRightOnTheRight() throws {
        let split = try XCTUnwrap(InputLanes.resolve(left: 2, right: 3, buffers: 4, channelsPerBuffer: 1))
        XCTAssertEqual(split.left, Lane(buffer: 2, lane: 0))
        XCTAssertEqual(split.right, Lane(buffer: 3, lane: 0))
        let woven = try XCTUnwrap(InputLanes.resolve(left: 2, right: 3, buffers: 1, channelsPerBuffer: 4))
        XCTAssertEqual(woven.left, Lane(buffer: 0, lane: 2))
        XCTAssertEqual(woven.right, Lane(buffer: 0, lane: 3))
        let mono = try XCTUnwrap(InputLanes.resolve(left: 1, right: 1, buffers: 1, channelsPerBuffer: 2))
        XCTAssertEqual(mono.left, mono.right, "a mono take reads one input into both")
    }

    func testAMissingSideNeverLeavesAFrameHalfWritten() throws {
        // A pair on inputs 2/3 of an interface with three: the right is missing and records the left.
        let short = try XCTUnwrap(InputLanes.resolve(left: 2, right: 3, buffers: 1, channelsPerBuffer: 3))
        XCTAssertEqual(short.left, Lane(buffer: 0, lane: 2))
        XCTAssertEqual(short.right, short.left)
        // The built-in microphone: one input, so the pair records the first in both sides.
        let microphone = try XCTUnwrap(InputLanes.resolve(left: 2, right: 3, buffers: 1, channelsPerBuffer: 1))
        XCTAssertEqual(microphone.left, Lane(buffer: 0, lane: 0))
        XCTAssertEqual(microphone.right, Lane(buffer: 0, lane: 0))
        XCTAssertNil(InputLanes.resolve(left: 0, right: 1, buffers: 0, channelsPerBuffer: 2))
    }
}

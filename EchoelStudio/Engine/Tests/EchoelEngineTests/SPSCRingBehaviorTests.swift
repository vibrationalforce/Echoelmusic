import XCTest
@testable import EchoelEngine

/// Pure behavioural tests for the preallocated render-to-MIDI SPSC handoff.
/// These are not allocation or thread-scheduling measurements.
final class SPSCRingBehaviorTests: XCTestCase {
    func testFullRingDropsNewestAndPreservesEarlierMessages() {
        let ring = SPSCRing<Int>(capacity: 3, filler: 0)

        XCTAssertTrue(ring.push(10))
        XCTAssertTrue(ring.push(20))
        XCTAssertTrue(ring.push(30))
        XCTAssertFalse(ring.push(99), "a full ring must not overwrite an unread event")

        XCTAssertEqual(ring.pop(), 10)
        XCTAssertTrue(ring.push(40), "consuming one event makes exactly one space")
        XCTAssertEqual(ring.pop(), 20)
        XCTAssertEqual(ring.pop(), 30)
        XCTAssertEqual(ring.pop(), 40)
        XCTAssertNil(ring.pop())
    }

    func testSingleSlotRingReusesItsSlotWithoutInventingEvents() {
        let ring = SPSCRing<Int>(capacity: 1, filler: -1)
        XCTAssertNil(ring.pop(), "the filler must never appear as a queued event")
        XCTAssertTrue(ring.push(7))
        XCTAssertFalse(ring.push(8))
        XCTAssertEqual(ring.pop(), 7)
        XCTAssertNil(ring.pop())
        XCTAssertTrue(ring.push(9))
        XCTAssertEqual(ring.pop(), 9)
        XCTAssertNil(ring.pop())
    }

    func testRepeatedWrapAroundMaintainsFIFOAcrossCapacityBoundary() {
        let ring = SPSCRing<Int>(capacity: 4, filler: -1)
        for iteration in 0..<1_024 {
            XCTAssertTrue(ring.push(iteration * 2))
            XCTAssertTrue(ring.push(iteration * 2 + 1))
            XCTAssertEqual(ring.pop(), iteration * 2)
            XCTAssertEqual(ring.pop(), iteration * 2 + 1)
        }
        XCTAssertNil(ring.pop())
    }

    func testTimedMIDIMessageUsesOneEventSlotRegardlessOfWireLength() {
        let ring = MIDIClockRing(capacity: 2)
        let songPosition = TimedMIDIMessage(hostTime: 111, frame: 3, status: 0xF2, data1: 7, data2: 5)
        let clock = TimedMIDIMessage(hostTime: 112, frame: 4, status: 0xF8, data1: 0, data2: 0)
        let extra = TimedMIDIMessage(hostTime: 113, frame: 5, status: 0x90, data1: 60, data2: 80)

        XCTAssertTrue(ring.push(songPosition))
        XCTAssertTrue(ring.push(clock))
        XCTAssertFalse(ring.push(extra))
        XCTAssertEqual(ring.pop(), songPosition)
        XCTAssertEqual(ring.pop(), clock)
        XCTAssertNil(ring.pop())

        XCTAssertEqual(songPosition.bytes, [0xF2, 7, 5])
        XCTAssertEqual(clock.bytes, [0xF8])
        XCTAssertEqual(extra.bytes, [0x90, 60, 80])
    }
}

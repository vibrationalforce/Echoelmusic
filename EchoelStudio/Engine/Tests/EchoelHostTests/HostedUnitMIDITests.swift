import AudioToolbox
import XCTest
@testable import EchoelHost

/// The bytes `HostedUnit` sends a unit, as the unit's MIDI block receives them.
private final class ReceivedMIDI: @unchecked Sendable {
    private(set) var messages: [[UInt8]] = []

    func makeUnit() -> HostedUnit {
        HostedUnit(render: { _, _, _, _, _, _ in noErr }, scheduleMIDI: { [self] _, _, length, bytes in
            messages.append(Array(UnsafeBufferPointer(start: bytes, count: length)))
        }, sampleRate: 48_000, maximumFrames: 256, owner: nil)
    }
}

final class HostedUnitMIDITests: XCTestCase {
    /// Notes go out on channel 1, so the messages that shape them do too, whatever channel they
    /// were played on.
    func testControlsGoOutOnTheChannelOfTheNotes() {
        let received = ReceivedMIDI()
        let unit = received.makeUnit()
        unit.noteOn(pitch: 60, velocity: 100, offset: 0)
        unit.control(status: 0xB3, 1, 64)
        unit.control(status: 0xE9, 0, 0x50)
        XCTAssertEqual(received.messages, [[0x90, 60, 100], [0xB0, 1, 64], [0xE0, 0, 0x50]])
    }

    func testPressureAndAProgramChangeReachTheUnitWithTheirLength() {
        let received = ReceivedMIDI()
        let unit = received.makeUnit()
        unit.control(status: 0xA0, 60, 90)
        unit.control(status: 0xD1, 100, 0)
        unit.control(status: 0xC2, 5, 0)
        XCTAssertEqual(received.messages, [[0xA0, 60, 90], [0xD0, 100], [0xC0, 5]])
    }

    func testDataBytesStayBelow128AndNotesOrSystemMessagesAreNotSentAsControls() {
        let received = ReceivedMIDI()
        let unit = received.makeUnit()
        unit.control(status: 0xB0, 0xFF, 0xFF)
        unit.control(status: 0x90, 60, 100)
        unit.control(status: 0xF8, 0, 0)
        XCTAssertEqual(received.messages, [[0xB0, 0x7F, 0x7F]])
    }
}

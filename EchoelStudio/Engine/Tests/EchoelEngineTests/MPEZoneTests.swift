import Foundation
import XCTest
@testable import EchoelEngine

/// MPE out, the lower zone (RP-053). Every expected byte here is worked out by hand from the
/// specification, not from the code: channels are 0-based in the status nibble (0 = MIDI 1).
final class MPEZoneTests: XCTestCase {
    private typealias Message = MPEZone.Message

    private func bytes(_ messages: [Message]) -> [[UInt8]] { messages.map(\.bytes) }

    /// RPN 6 with the member count on the master channel, then RPN 0 (bend sensitivity) on the
    /// master and on every member, each closed by the null RPN.
    func testTheConfigurationAnnouncesTheZoneAndEveryBendRange() {
        let zone = MPEZone(members: 3)
        let expected: [[UInt8]] = [
            [0xB0, 101, 0], [0xB0, 100, 6], [0xB0, 6, 3], [0xB0, 101, 127], [0xB0, 100, 127],
            [0xB0, 101, 0], [0xB0, 100, 0], [0xB0, 6, 2], [0xB0, 38, 0], [0xB0, 101, 127], [0xB0, 100, 127],
            [0xB1, 101, 0], [0xB1, 100, 0], [0xB1, 6, 48], [0xB1, 38, 0], [0xB1, 101, 127], [0xB1, 100, 127],
            [0xB2, 101, 0], [0xB2, 100, 0], [0xB2, 6, 48], [0xB2, 38, 0], [0xB2, 101, 127], [0xB2, 100, 127],
            [0xB3, 101, 0], [0xB3, 100, 0], [0xB3, 6, 48], [0xB3, 38, 0], [0xB3, 101, 127], [0xB3, 100, 127],
        ]
        XCTAssertEqual(bytes(zone.configuration()), expected)
        XCTAssertEqual(MPEZone(members: 0).memberCount, 1, "a zone has at least one member")
        XCTAssertEqual(MPEZone(members: 40).memberCount, 15, "and at most fifteen")
    }

    /// The first note goes to MIDI channel 2, its bend, slide and pressure stated before it.
    func testANoteStatesItsExpressionBeforeItStarts() {
        var zone = MPEZone()
        let expected: [[UInt8]] = [[0xE1, 0x00, 0x40], [0xB1, 74, 64], [0xD1, 0], [0x91, 60, 100]]
        XCTAssertEqual(bytes(zone.noteOn(pitch: 60, velocity: 100)), expected)
        XCTAssertEqual(zone.channel(of: 60), 1)
        XCTAssertEqual(bytes(zone.noteOff(pitch: 60)), [[0x81, 60, 0]])
        XCTAssertEqual(zone.soundingCount, 0)
    }

    /// Each sounding note has a channel of its own; a freed channel waits while one never used
    /// is free, so a release tail is not cut by the next note.
    func testEachNoteHasItsOwnChannelAndTheLongestFreedIsReused() {
        var zone = MPEZone(members: 3)
        _ = zone.noteOn(pitch: 60, velocity: 90)
        _ = zone.noteOn(pitch: 64, velocity: 90)
        XCTAssertEqual(zone.channel(of: 60), 1)
        XCTAssertEqual(zone.channel(of: 64), 2)
        _ = zone.noteOff(pitch: 60)
        _ = zone.noteOn(pitch: 67, velocity: 90)
        XCTAssertEqual(zone.channel(of: 67), 3, "channel 4 was never used; channel 2 was just freed")
        _ = zone.noteOn(pitch: 72, velocity: 90)
        XCTAssertEqual(zone.channel(of: 72), 1, "the only free channel")
    }

    /// With every member sounding, the oldest note ends first and its channel plays the new one.
    func testAFullZoneStealsTheOldestNote() {
        var zone = MPEZone(members: 2)
        _ = zone.noteOn(pitch: 60, velocity: 90)
        _ = zone.noteOn(pitch: 62, velocity: 90)
        let expected: [[UInt8]] = [[0x81, 60, 0], [0xE1, 0x00, 0x40], [0xB1, 74, 64], [0xD1, 0], [0x91, 64, 90]]
        XCTAssertEqual(bytes(zone.noteOn(pitch: 64, velocity: 90)), expected)
        XCTAssertNil(zone.channel(of: 60))
        XCTAssertEqual(zone.soundingCount, 2)
    }

    /// A pitch sounds once: struck again, it ends first; a velocity-0 note-on ends it; a release
    /// of a pitch that does not sound sends nothing.
    func testAPitchSoundsOnceAndAStrayReleaseSendsNothing() {
        var zone = MPEZone(members: 4)
        _ = zone.noteOn(pitch: 60, velocity: 90)
        let again = bytes(zone.noteOn(pitch: 60, velocity: 70))
        XCTAssertEqual(again.first, [0x81, 60, 0])
        XCTAssertEqual(again.last, [0x92, 60, 70])
        XCTAssertEqual(zone.soundingCount, 1)
        XCTAssertEqual(bytes(zone.noteOn(pitch: 60, velocity: 0)), [[0x82, 60, 0]])
        XCTAssertTrue(zone.noteOff(pitch: 61).isEmpty)
        XCTAssertTrue(zone.noteOn(pitch: 61, velocity: 0).isEmpty)
    }

    /// 14-bit bend against a 48-semitone member range: +12 is 8192 + 2048 = 10240 (LSB 0, MSB 80),
    /// −48 is 0, beyond the range clamps to 16383; not finite or not sounding sends nothing.
    func testPerNoteBendIsScaledByTheMemberRange() {
        var zone = MPEZone()
        _ = zone.noteOn(pitch: 60, velocity: 90)
        XCTAssertEqual(bytes(zone.bend(pitch: 60, semitones: 12)), [[0xE1, 0, 80]])
        XCTAssertEqual(bytes(zone.bend(pitch: 60, semitones: -48)), [[0xE1, 0, 0]])
        XCTAssertEqual(bytes(zone.bend(pitch: 60, semitones: 100)), [[0xE1, 0x7F, 0x7F]])
        XCTAssertTrue(zone.bend(pitch: 60, semitones: .nan).isEmpty)
        XCTAssertTrue(zone.bend(pitch: 61, semitones: 1).isEmpty)
        XCTAssertEqual(bytes(zone.masterBend(8_192)), [[0xE0, 0x00, 0x40]])
    }

    /// The body's pressure and slide reach every sounding note, on each channel only when the
    /// 7-bit value changed; absent or not finite sends nothing and is not remembered.
    func testBodyExpressionReachesEverySoundingNoteOnlyWhenItChanges() {
        var zone = MPEZone(members: 4)
        _ = zone.noteOn(pitch: 60, velocity: 90)
        _ = zone.noteOn(pitch: 64, velocity: 90)
        XCTAssertEqual(bytes(zone.setPressure(0.5)), [[0xD1, 64], [0xD2, 64]])
        XCTAssertTrue(zone.setPressure(0.5).isEmpty, "unchanged sends nothing")
        XCTAssertTrue(zone.setPressure(nil).isEmpty)
        XCTAssertTrue(zone.setPressure(.infinity).isEmpty)
        XCTAssertEqual(bytes(zone.setSlide(1)), [[0xB1, 74, 127], [0xB2, 74, 127]])
        let next = bytes(zone.noteOn(pitch: 67, velocity: 90))
        XCTAssertEqual(next, [[0xE3, 0x00, 0x40], [0xB3, 74, 127], [0xD3, 64], [0x93, 67, 90]],
                       "a new note starts with the body's expression as it is now")
        XCTAssertTrue(zone.setPressure(0.5).isEmpty)
    }

    /// All notes off ends each note on its channel, then CC 123 on every member channel.
    func testAllNotesOffEndsEveryNoteThenSilencesEveryMember() {
        var zone = MPEZone(members: 2)
        _ = zone.noteOn(pitch: 60, velocity: 90)
        _ = zone.noteOn(pitch: 64, velocity: 90)
        XCTAssertEqual(bytes(zone.allNotesOff()), [[0x81, 60, 0], [0x82, 64, 0], [0xB1, 123, 0], [0xB2, 123, 0]])
        XCTAssertEqual(zone.soundingCount, 0)
        let changed = bytes(MPEZone(members: 2).reconfiguring(to: 5))
        XCTAssertEqual(changed.prefix(2), [[0xB1, 123, 0], [0xB2, 123, 0]])
        XCTAssertEqual(changed[4], [0xB0, 6, 5], "the new zone is announced after everything ended")
    }

    /// Channel pressure carries one data byte on the wire.
    func testChannelPressureIsTwoBytes() {
        XCTAssertEqual(Message(0xD4, 10).bytes, [0xD4, 10])
        XCTAssertEqual(Message(0x95, 60, 100).channel, 5)
    }
}

private extension MPEZone {
    func reconfiguring(to members: Int) -> [Message] {
        var copy = self
        return copy.reconfigure(members: members)
    }
}

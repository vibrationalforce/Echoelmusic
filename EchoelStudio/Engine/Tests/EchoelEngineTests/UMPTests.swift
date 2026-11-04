import XCTest
@testable import EchoelEngine

/// MIDI 2.0 (UMP) in and out. Every expected word and value is worked out by hand from M2-104-UM
/// (message layout) and its Appendix D (Min-Center-Max scaling), not from the code.
final class UMPTests: XCTestCase {
    private typealias Message = UMP.Message

    private func roundTrip(_ message: Message, file: StaticString = #filePath, line: UInt = #line) {
        let words = message.words
        XCTAssertEqual(Message(words.0, words.1), message, "parses back to itself", file: file, line: line)
    }

    // MARK: - Parser and builder

    func testANoteOnIsBuiltAsTheSpecificationLaysItOut() {
        // Type 4, group 0, opcode 9, channel 3 · note 60 · attribute type 0; velocity 0xC000, attribute 0.
        let message = Message(channel: 3, .noteOn(note: 60, velocity: 0xC000, attributeType: 0, attribute: 0))
        XCTAssertEqual(message.words.0, 0x4093_3C00)
        XCTAssertEqual(message.words.1, 0xC000_0000)
    }

    func testNotesControllersAndBendsRoundTrip() {
        roundTrip(Message(channel: 0, .noteOn(note: 60, velocity: 0xFFFF, attributeType: 3, attribute: 0x1234)))
        roundTrip(Message(group: 5, channel: 15, .noteOff(note: 127, velocity: 0, attributeType: 0, attribute: 0)))
        roundTrip(Message(channel: 1, .controlChange(index: 74, value: 0x8000_0000)))
        roundTrip(Message(channel: 2, .pitchBend(value: 0xFFFF_FFFF)))
        roundTrip(Message(channel: 2, .perNotePitchBend(note: 64, value: 0x1234_5678)))
        roundTrip(Message(channel: 4, .perNoteController(note: 61, registered: true, index: 74, value: 7)))
        roundTrip(Message(channel: 4, .perNoteController(note: 61, registered: false, index: 200, value: 9)))
        roundTrip(Message(channel: 6, .polyPressure(note: 10, value: 0x4000_0000)))
        roundTrip(Message(channel: 7, .channelPressure(value: 1)))
        roundTrip(Message(channel: 8, .programChange(program: 5, bank: (msb: 1, lsb: 2))))
        roundTrip(Message(channel: 8, .programChange(program: 5, bank: nil)))
        roundTrip(Message(channel: 9, .parameter(registered: true, bank: 0, index: 0, value: 42)))
        roundTrip(Message(channel: 9, .relativeParameter(registered: false, bank: 3, index: 4, step: -5)))
        roundTrip(Message(channel: 9, .perNoteManagement(note: 60, detach: true, reset: true)))
    }

    func testThePerNotePitchBendCarriesItsNoteAndThirtyTwoBits() {
        let words = Message(channel: 1, .perNotePitchBend(note: 0x40, value: 0x8000_0000)).words
        XCTAssertEqual(words.0, 0x4061_4000, "opcode 6, channel 1, note 64")
        XCTAssertEqual(words.1, 0x8000_0000)
    }

    func testInvalidPacketsAreDropped() {
        XCTAssertNil(Message(0x2090_3C64, 0), "a MIDI 1.0 word is not a MIDI 2.0 message")
        XCTAssertNil(Message(0x4070_0000, 0), "opcode 7 is undefined")
        XCTAssertNil(Message(0x4090_BC00, 0xC000_0000), "a note byte with its top bit set is reserved")
        XCTAssertNil(Message(0x40B0_8000, 0), "so is a controller index")
        XCTAssertNil(Message(0x4020_8000, 0), "and an RPN bank")
        XCTAssertNil(Message(0x40C0_0001, 0x8000_0000), "a program number above 127")
    }

    func testMessageLengthsFollowTheirType() {
        XCTAssertEqual(UMP.wordCount(messageType: 0x2), 1)
        XCTAssertEqual(UMP.wordCount(messageType: 0x4), 2)
        XCTAssertEqual(UMP.wordCount(messageType: 0x5), 4)
        XCTAssertEqual(UMP.wordCount(messageType: 0xB), 3)
    }

    // MARK: - Scaling

    func testScalingUpKeepsMinimumCentreAndMaximum() {
        XCTAssertEqual(UMP.scaleUp(0, from: 7, to: 16), 0)
        XCTAssertEqual(UMP.scaleUp(64, from: 7, to: 16), 0x8000)
        XCTAssertEqual(UMP.scaleUp(127, from: 7, to: 16), 0xFFFF)
        XCTAssertEqual(UMP.scaleUp(0, from: 7, to: 32), 0)
        XCTAssertEqual(UMP.scaleUp(64, from: 7, to: 32), 0x8000_0000)
        XCTAssertEqual(UMP.scaleUp(127, from: 7, to: 32), 0xFFFF_FFFF)
        XCTAssertEqual(UMP.scaleUp(8192, from: 14, to: 32), 0x8000_0000)
        XCTAssertEqual(UMP.scaleUp(16_383, from: 14, to: 32), 0xFFFF_FFFF)
        XCTAssertEqual(UMP.scaleUp(0xFFFF, from: 16, to: 32), 0xFFFF_FFFF)
    }

    func testAboveTheCentreTheLowBitsRepeat() {
        // 65 = 0b100_0001: shifted 0x8200, the six low bits (1) repeated from bit 3 → 0x8208.
        XCTAssertEqual(UMP.scaleUp(65, from: 7, to: 16), 0x8208)
        // Below the centre it is a plain shift: 63 << 9.
        XCTAssertEqual(UMP.scaleUp(63, from: 7, to: 16), 0x7E00)
    }

    func testScalingDownIsAShiftAndUndoesScalingUp() {
        XCTAssertEqual(UMP.scaleDown(0xFFFF_FFFF, from: 32, to: 7), 127)
        XCTAssertEqual(UMP.scaleDown(0x8000_0000, from: 32, to: 14), 8192)
        XCTAssertEqual(UMP.scaleDown(0xFFFF, from: 16, to: 7), 127)
        for value in UInt32(0)...127 {
            XCTAssertEqual(UMP.scaleDown(UMP.scaleUp(value, from: 7, to: 16), from: 16, to: 7), value)
            XCTAssertEqual(UMP.scaleDown(UMP.scaleUp(value, from: 7, to: 32), from: 32, to: 7), value)
        }
        for value in stride(from: UInt32(0), through: 16_383, by: 7) {
            XCTAssertEqual(UMP.scaleDown(UMP.scaleUp(value, from: 14, to: 32), from: 32, to: 14), value)
        }
    }

    // MARK: - What the 7-bit engine hears

    func testANoteKeepsItsVelocityAndNeverTurnsIntoANoteOff() {
        XCTAssertEqual(Message(channel: 2, .noteOn(note: 60, velocity: 0xFFFF, attributeType: 0, attribute: 0)).midi1,
                       [UMP.Channel1(0x92, 60, 127)])
        XCTAssertEqual(Message(channel: 2, .noteOn(note: 60, velocity: 0x0100, attributeType: 0, attribute: 0)).midi1,
                       [UMP.Channel1(0x92, 60, 1)], "a soft MIDI 2.0 strike is still a note-on")
        XCTAssertEqual(Message(channel: 2, .noteOff(note: 60, velocity: 0x8000, attributeType: 0, attribute: 0)).midi1,
                       [UMP.Channel1(0x82, 60, 64)])
    }

    func testControllersAndBendsAreScaledDown() {
        XCTAssertEqual(Message(channel: 0, .controlChange(index: 1, value: 0x8000_0000)).midi1, [UMP.Channel1(0xB0, 1, 64)])
        XCTAssertEqual(Message(channel: 0, .pitchBend(value: 0x8000_0000)).midi1, [UMP.Channel1(0xE0, 0, 64)])
        XCTAssertEqual(Message(channel: 0, .pitchBend(value: 0xFFFF_FFFF)).midi1, [UMP.Channel1(0xE0, 127, 127)])
        XCTAssertEqual(Message(channel: 3, .perNotePitchBend(note: 60, value: 0x8000_0000)).midi1,
                       [UMP.Channel1(0xE3, 0, 64)], "a note's bend bends its channel")
        XCTAssertEqual(Message(channel: 3, .perNoteController(note: 60, registered: true, index: 74, value: 0xFFFF_FFFF)).midi1,
                       [UMP.Channel1(0xB3, 74, 127)])
        XCTAssertEqual(Message(channel: 0, .channelPressure(value: 0x4000_0000)).midi1, [UMP.Channel1(0xD0, 32)])
        XCTAssertEqual(Message(channel: 0, .programChange(program: 9, bank: (msb: 1, lsb: 2))).midi1,
                       [UMP.Channel1(0xB0, 0, 1), UMP.Channel1(0xB0, 32, 2), UMP.Channel1(0xC0, 9)])
        XCTAssertEqual(Message(channel: 0, .parameter(registered: true, bank: 0, index: 0, value: UMP.scaleUp(48 << 7, from: 14, to: 32))).midi1,
                       [UMP.Channel1(0xB0, 101, 0), UMP.Channel1(0xB0, 100, 0), UMP.Channel1(0xB0, 6, 48), UMP.Channel1(0xB0, 38, 0)])
    }

    func testWhatMIDIOneCannotSayIsReportedNotSwallowed() {
        XCTAssertNil(Message(channel: 0, .relativeParameter(registered: true, bank: 0, index: 0, step: 1)).midi1)
        XCTAssertNil(Message(channel: 0, .perNoteController(note: 60, registered: false, index: 1, value: 0)).midi1)
        XCTAssertNil(Message(channel: 0, .perNoteController(note: 60, registered: true, index: 3, value: 0)).midi1,
                     "pitch 7.25 has no MIDI 1.0 form")
        XCTAssertEqual(Message(channel: 0, .perNoteManagement(note: 60, detach: false, reset: true)).midi1, [],
                       "nothing to do is not something lost")
        XCTAssertTrue(Message(channel: 0, .noteOn(note: 60, velocity: 1, attributeType: 3, attribute: 0)).hasUnheardAttribute)
        XCTAssertFalse(Message(channel: 0, .noteOn(note: 60, velocity: 1, attributeType: 0, attribute: 0)).hasUnheardAttribute)
    }

    func testALearnedControllerKeepsItsFullResolution() {
        let value = Message(channel: 0, .controlChange(index: 7, value: 0x8000_0000)).normalizedControl ?? -1
        XCTAssertEqual(value, Double(0x8000_0000) / Double(UInt32.max), accuracy: 1e-12)
        XCTAssertNil(Message(channel: 0, .pitchBend(value: 0)).normalizedControl)
    }

    // MARK: - MPE out

    func testWithTheSwitchOffTheOutputIsTheWordsItAlwaysWas() {
        var zone = MPEZone()
        let messages = zone.configuration() + zone.noteOn(pitch: 60, velocity: 100) + zone.noteOff(pitch: 60)
        // The formula MPE out has always sent: type 2, group 0, status, data1, data2.
        let before = messages.map { UInt32(0x2) << 28 | UInt32($0.status) << 16 | UInt32($0.data1) << 8 | UInt32($0.data2) }
        XCTAssertEqual(MPEOutputWords.midi1(messages), before)
        var off: MIDI2Translator?
        XCTAssertNil(MPEOutputWords.midi2(messages, translator: &off), "off sends nothing over MIDI 2.0")
        XCTAssertNil(off)
    }

    func testAMemberBendBecomesTheNotesOwnBend() {
        var zone = MPEZone()
        var translator: MIDI2Translator? = MIDI2Translator()
        let on = MPEOutputWords.midi2(zone.noteOn(pitch: 60, velocity: 127), translator: &translator) ?? []
        // Slide (CC 74 at 64) and pressure (0) on channel 2, the note at full strike, then its
        // centred per-note bend; the bend stated before the note waits for it.
        XCTAssertEqual(on, [0x40B1_4A00, 0x8000_0000,
                            0x40D1_0000, 0x0000_0000,
                            0x4091_3C00, 0xFFFF_0000,
                            0x4061_3C00, 0x8000_0000])
        let bend = MPEOutputWords.midi2(zone.bend(pitch: 60, semitones: 48), translator: &translator) ?? []
        XCTAssertEqual(bend, [0x4061_3C00, 0xFFFF_FFFF], "the top of the member range")
        let master = MPEOutputWords.midi2(zone.masterBend(8192), translator: &translator) ?? []
        XCTAssertEqual(master, [0x40E0_0000, 0x8000_0000], "the master channel bends the zone")
        XCTAssertEqual(MPEOutputWords.midi2(zone.noteOff(pitch: 60), translator: &translator) ?? [], [0x4081_3C00, 0])
    }

    func testTheZoneAnnouncementBecomesRegisteredParameters() {
        let zone = MPEZone(members: 1)
        var translator: MIDI2Translator? = MIDI2Translator()
        let words = MPEOutputWords.midi2(zone.configuration(), translator: &translator) ?? []
        // RPN 6 = 1 member (data MSB only), RPN 0 = 2 then 2.00 on the master, 48 then 48.00 on
        // channel 2; the null RPN sends nothing.
        XCTAssertEqual(words, [0x4020_0006, UMP.scaleUp(1 << 7, from: 14, to: 32),
                               0x4020_0000, UMP.scaleUp(2 << 7, from: 14, to: 32),
                               0x4020_0000, UMP.scaleUp(2 << 7, from: 14, to: 32),
                               0x4021_0000, UMP.scaleUp(48 << 7, from: 14, to: 32),
                               0x4021_0000, UMP.scaleUp(48 << 7, from: 14, to: 32)])
    }
}

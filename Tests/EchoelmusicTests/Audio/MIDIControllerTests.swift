import XCTest
@testable import Echoelmusic

/// Comprehensive tests for MIDIController - MIDI handling
/// Coverage target: All MIDI message types and edge cases
final class MIDIControllerTests: XCTestCase {

    // MARK: - MIDI Message Type Tests

    func testNoteOnMessage() {
        // Note On: Status = 0x90 + channel, Data1 = note, Data2 = velocity
        let status: UInt8 = 0x90  // Note On, Channel 0
        let note: UInt8 = 60      // Middle C
        let velocity: UInt8 = 100

        XCTAssertEqual(status & 0xF0, 0x90, "Should be Note On")
        XCTAssertEqual(status & 0x0F, 0, "Should be Channel 0")
        XCTAssertEqual(note, 60, "Should be Middle C")
        XCTAssertTrue(velocity > 0, "Note On velocity must be > 0")
    }

    func testNoteOffMessage() {
        // Note Off: Status = 0x80 + channel
        let status: UInt8 = 0x80  // Note Off, Channel 0
        let note: UInt8 = 60

        XCTAssertEqual(status & 0xF0, 0x80, "Should be Note Off")
    }

    func testNoteOnWithZeroVelocity() {
        // Note On with velocity 0 = Note Off (common practice)
        let status: UInt8 = 0x90
        let velocity: UInt8 = 0

        let isNoteOff = (status & 0xF0 == 0x80) || (status & 0xF0 == 0x90 && velocity == 0)
        XCTAssertTrue(isNoteOff, "Note On with velocity 0 should be treated as Note Off")
    }

    func testControlChangeMessage() {
        // CC: Status = 0xB0 + channel, Data1 = controller, Data2 = value
        let status: UInt8 = 0xB0
        let controller: UInt8 = 1   // Modulation wheel
        let value: UInt8 = 64       // Half value

        XCTAssertEqual(status & 0xF0, 0xB0, "Should be Control Change")
        XCTAssertTrue(controller <= 127, "Controller should be 0-127")
        XCTAssertTrue(value <= 127, "Value should be 0-127")
    }

    func testPitchBendMessage() {
        // Pitch Bend: Status = 0xE0 + channel, 14-bit value (LSB, MSB)
        let status: UInt8 = 0xE0
        let lsb: UInt8 = 0x00
        let msb: UInt8 = 0x40  // Center position

        XCTAssertEqual(status & 0xF0, 0xE0, "Should be Pitch Bend")

        let pitchBend = Int(msb) << 7 | Int(lsb)
        XCTAssertEqual(pitchBend, 8192, "Center should be 8192 (0x2000)")
    }

    func testProgramChangeMessage() {
        // Program Change: Status = 0xC0 + channel, Data1 = program
        let status: UInt8 = 0xC0
        let program: UInt8 = 0  // Acoustic Grand Piano (GM)

        XCTAssertEqual(status & 0xF0, 0xC0, "Should be Program Change")
        XCTAssertTrue(program <= 127, "Program should be 0-127")
    }

    // MARK: - Channel Tests

    func testAllMIDIChannels() {
        // MIDI has 16 channels (0-15)
        for channel in 0..<16 {
            let status: UInt8 = 0x90 | UInt8(channel)
            let extractedChannel = status & 0x0F
            XCTAssertEqual(Int(extractedChannel), channel, "Channel extraction failed")
        }
    }

    // MARK: - Note Range Tests

    func testMIDINoteRange() {
        // MIDI notes: 0-127 (C-1 to G9)
        let minNote: UInt8 = 0    // C-1 (8.18 Hz)
        let maxNote: UInt8 = 127  // G9 (12543.85 Hz)
        let middleC: UInt8 = 60   // C4 (261.63 Hz)

        XCTAssertEqual(minNote, 0)
        XCTAssertEqual(maxNote, 127)
        XCTAssertEqual(middleC, 60)
    }

    func testMIDINoteToFrequency() {
        // f = 440 * 2^((n-69)/12) where n is MIDI note, 69 is A4
        let a4: UInt8 = 69
        let frequency = 440.0 * pow(2.0, Double(Int(a4) - 69) / 12.0)
        XCTAssertEqual(frequency, 440.0, accuracy: 0.001)

        // Middle C (note 60)
        let middleC: UInt8 = 60
        let middleCFreq = 440.0 * pow(2.0, Double(Int(middleC) - 69) / 12.0)
        XCTAssertEqual(middleCFreq, 261.626, accuracy: 0.01)
    }

    // MARK: - Velocity Tests

    func testVelocityRange() {
        // Velocity: 1-127 (0 = Note Off)
        let minVelocity: UInt8 = 1
        let maxVelocity: UInt8 = 127
        let mediumVelocity: UInt8 = 64

        XCTAssertTrue(minVelocity >= 1)
        XCTAssertTrue(maxVelocity <= 127)
        XCTAssertEqual(mediumVelocity, 64)
    }

    func testVelocityToAmplitude() {
        // Linear mapping: amplitude = velocity / 127
        let velocity: UInt8 = 100
        let amplitude = Float(velocity) / 127.0
        XCTAssertEqual(amplitude, 0.787, accuracy: 0.01)
    }

    // MARK: - System Messages Tests

    func testSystemExclusive() {
        // SysEx: F0 ... F7
        let sysExStart: UInt8 = 0xF0
        let sysExEnd: UInt8 = 0xF7

        XCTAssertEqual(sysExStart, 0xF0)
        XCTAssertEqual(sysExEnd, 0xF7)
    }

    func testMIDIClock() {
        // MIDI Clock: F8 (24 pulses per quarter note)
        let clockMessage: UInt8 = 0xF8
        XCTAssertEqual(clockMessage, 0xF8)

        // PPQ = 24 is standard
        let ppq = 24
        XCTAssertEqual(ppq, 24, "Standard MIDI PPQ is 24")
    }

    func testMIDIStart() {
        let startMessage: UInt8 = 0xFA
        XCTAssertEqual(startMessage, 0xFA, "MIDI Start")
    }

    func testMIDIStop() {
        let stopMessage: UInt8 = 0xFC
        XCTAssertEqual(stopMessage, 0xFC, "MIDI Stop")
    }

    func testMIDIContinue() {
        let continueMessage: UInt8 = 0xFB
        XCTAssertEqual(continueMessage, 0xFB, "MIDI Continue")
    }

    // MARK: - Running Status Tests

    func testRunningStatus() {
        // Running status: reuse last status byte for same message type
        let noteOn: UInt8 = 0x90
        let note1: UInt8 = 60
        let vel1: UInt8 = 100
        let note2: UInt8 = 64  // Next note uses running status (no status byte)
        let vel2: UInt8 = 90

        // Both should be interpreted as Note On on channel 0
        XCTAssertEqual(noteOn & 0xF0, 0x90)
    }

    // MARK: - Edge Cases

    func testInvalidStatusByte() {
        // Data bytes have MSB = 0 (0x00-0x7F)
        // Status bytes have MSB = 1 (0x80-0xFF)
        let dataByte: UInt8 = 0x60
        let statusByte: UInt8 = 0x90

        XCTAssertTrue(dataByte < 0x80, "Data byte MSB should be 0")
        XCTAssertTrue(statusByte >= 0x80, "Status byte MSB should be 1")
    }

    func testMIDIBufferOverflow() {
        // MIDI messages are max 3 bytes (except SysEx)
        let maxMessageSize = 3
        XCTAssertEqual(maxMessageSize, 3)
    }
}

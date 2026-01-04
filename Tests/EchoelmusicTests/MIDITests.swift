import XCTest
@testable import Echoelmusic

/// Comprehensive tests for MIDI 2.0, UMP packets, and MPE functionality
final class MIDITests: XCTestCase {

    // MARK: - UMP Packet 32-bit Tests

    func testUMPPacket32Creation() {
        let packet = UMPPacket32(
            messageType: 0x2,  // MIDI 1.0 channel voice
            group: 0,
            status: 0x90,      // Note On, channel 0
            data1: 60,         // Middle C
            data2: 100         // Velocity
        )

        XCTAssertEqual(packet.messageType, 0x2)
        XCTAssertEqual(packet.group, 0)
        XCTAssertEqual(packet.status, 0x90)
        XCTAssertEqual(packet.data1, 60)
        XCTAssertEqual(packet.data2, 100)
    }

    func testUMPPacket32Bytes() {
        let packet = UMPPacket32(
            messageType: 0x2,
            group: 0x1,
            status: 0x80,
            data1: 64,
            data2: 0
        )

        let bytes = packet.bytes
        XCTAssertEqual(bytes.count, 4)
        // Verify byte order is correct
        XCTAssertEqual(bytes[0], 0x21)  // MessageType + Group
        XCTAssertEqual(bytes[1], 0x80)  // Status
        XCTAssertEqual(bytes[2], 64)    // Data1
        XCTAssertEqual(bytes[3], 0)     // Data2
    }

    // MARK: - UMP Packet 64-bit Tests

    func testUMPPacket64Creation() {
        let packet = UMPPacket64(
            messageType: 0x4,  // MIDI 2.0 channel voice
            group: 0,
            status: 0x9,       // Note On
            channel: 0,
            index: 60,         // Note number
            data: 0xFFFF0000   // Max velocity
        )

        XCTAssertEqual(packet.messageType, 0x4)
        XCTAssertEqual(packet.group, 0)
        XCTAssertEqual(packet.status, 0x9)
        XCTAssertEqual(packet.channel, 0)
        XCTAssertEqual(packet.index, 60)
        XCTAssertEqual(packet.data, 0xFFFF0000)
    }

    func testUMPPacket64Bytes() {
        let packet = UMPPacket64(
            messageType: 0x4,
            group: 0,
            status: 0x9,
            channel: 1,
            index: 72,
            data: 0x80000000
        )

        let bytes = packet.bytes
        XCTAssertEqual(bytes.count, 8)
    }

    // MARK: - MIDI 2.0 Note On Tests

    func testNoteOnPacket() {
        let packet = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.75)

        XCTAssertEqual(packet.messageType, UMPMessageType.midi2ChannelVoice.rawValue)
        XCTAssertEqual(packet.channel, 0)
    }

    func testNoteOnVelocityMapping() {
        // Test minimum velocity
        let minPacket = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.0)
        XCTAssertEqual(minPacket.data >> 16, 0)

        // Test maximum velocity
        let maxPacket = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 1.0)
        XCTAssertEqual(maxPacket.data >> 16, 0xFFFF)

        // Test mid velocity (approximately)
        let midPacket = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.5)
        let midVelocity = UInt16(midPacket.data >> 16)
        XCTAssertTrue(midVelocity > 32000 && midVelocity < 33000)
    }

    func testNoteOnWithAttributes() {
        let packet = UMPPacket64.noteOn(
            channel: 0,
            note: 64,
            velocity: 0.8,
            attributeType: 3,      // Pitch attribute
            attributeData: 0x8000  // Center pitch
        )

        // Verify attribute data is included
        let attributeData = UInt16(packet.data & 0xFFFF)
        XCTAssertEqual(attributeData, 0x8000)
    }

    // MARK: - MIDI 2.0 Note Off Tests

    func testNoteOffPacket() {
        let packet = UMPPacket64.noteOff(channel: 0, note: 60, velocity: 0.0)

        XCTAssertEqual(packet.messageType, UMPMessageType.midi2ChannelVoice.rawValue)
    }

    // MARK: - Per-Note Controller Tests

    func testPerNoteControllerPacket() {
        let packet = UMPPacket64.perNoteController(
            channel: 0,
            note: 60,
            controller: .sound2Brightness,
            value: 0.75
        )

        XCTAssertEqual(packet.messageType, UMPMessageType.midi2ChannelVoice.rawValue)
        XCTAssertEqual(packet.index, PerNoteController.sound2Brightness.rawValue)
    }

    func testPerNoteControllerValueRange() {
        // Test minimum value
        let minPacket = UMPPacket64.perNoteController(
            channel: 0, note: 60, controller: .modulation, value: 0.0
        )
        XCTAssertEqual(minPacket.data, 0)

        // Test maximum value
        let maxPacket = UMPPacket64.perNoteController(
            channel: 0, note: 60, controller: .modulation, value: 1.0
        )
        XCTAssertEqual(maxPacket.data, 0xFFFFFFFF)
    }

    // MARK: - Per-Note Pitch Bend Tests

    func testPerNotePitchBendCenter() {
        let packet = UMPPacket64.perNotePitchBend(channel: 0, note: 60, bend: 0.0)

        // Center should be approximately 0x80000000
        let center = UInt32(0x80000000)
        let tolerance = UInt32(100)  // Allow some floating point tolerance
        XCTAssertTrue(abs(Int64(packet.data) - Int64(center)) < Int64(tolerance))
    }

    func testPerNotePitchBendUp() {
        let packet = UMPPacket64.perNotePitchBend(channel: 0, note: 60, bend: 1.0)

        // Full up should be maximum value
        XCTAssertEqual(packet.data, 0xFFFFFFFF)
    }

    func testPerNotePitchBendDown() {
        let packet = UMPPacket64.perNotePitchBend(channel: 0, note: 60, bend: -1.0)

        // Full down should be 0
        XCTAssertEqual(packet.data, 0)
    }

    // MARK: - Channel Pressure Tests

    func testChannelPressure() {
        let packet = UMPPacket64.channelPressure(channel: 5, pressure: 0.5)

        XCTAssertEqual(packet.channel, 5)
        XCTAssertEqual(packet.messageType, UMPMessageType.midi2ChannelVoice.rawValue)
    }

    // MARK: - Control Change Tests

    func testControlChange() {
        let packet = UMPPacket64.controlChange(channel: 0, controller: 74, value: 0.8)

        XCTAssertEqual(packet.channel, 0)
        XCTAssertEqual(packet.index, 74)  // Filter cutoff
    }

    // MARK: - Message Type Tests

    func testUMPMessageTypes() {
        XCTAssertEqual(UMPMessageType.utility.rawValue, 0x0)
        XCTAssertEqual(UMPMessageType.systemRealTime.rawValue, 0x1)
        XCTAssertEqual(UMPMessageType.midi1ChannelVoice.rawValue, 0x2)
        XCTAssertEqual(UMPMessageType.sysEx.rawValue, 0x3)
        XCTAssertEqual(UMPMessageType.midi2ChannelVoice.rawValue, 0x4)
        XCTAssertEqual(UMPMessageType.data128.rawValue, 0x5)
    }

    // MARK: - MIDI 2.0 Status Tests

    func testMIDI2StatusCodes() {
        XCTAssertEqual(MIDI2Status.noteOff.rawValue, 0x8)
        XCTAssertEqual(MIDI2Status.noteOn.rawValue, 0x9)
        XCTAssertEqual(MIDI2Status.polyPressure.rawValue, 0xA)
        XCTAssertEqual(MIDI2Status.controlChange.rawValue, 0xB)
        XCTAssertEqual(MIDI2Status.programChange.rawValue, 0xC)
        XCTAssertEqual(MIDI2Status.channelPressure.rawValue, 0xD)
        XCTAssertEqual(MIDI2Status.pitchBend.rawValue, 0xE)
    }

    // MARK: - Per-Note Controller ID Tests

    func testPerNoteControllerIDs() {
        XCTAssertEqual(PerNoteController.modulation.rawValue, 1)
        XCTAssertEqual(PerNoteController.breath.rawValue, 2)
        XCTAssertEqual(PerNoteController.expression.rawValue, 11)
        XCTAssertEqual(PerNoteController.sound1Timbre.rawValue, 70)
        XCTAssertEqual(PerNoteController.sound2Brightness.rawValue, 71)
        XCTAssertEqual(PerNoteController.sound4Cutoff.rawValue, 74)
    }

    // MARK: - Value Conversion Tests

    func testFloatToMIDI2Value() {
        XCTAssertEqual(Float(0.0).toMIDI2Value, 0)
        XCTAssertEqual(Float(1.0).toMIDI2Value, 0xFFFFFFFF)

        let midValue = Float(0.5).toMIDI2Value
        XCTAssertTrue(midValue > 2147483000 && midValue < 2147484000)
    }

    func testFloatToMIDI2PitchBend() {
        XCTAssertEqual(Float(-1.0).toMIDI2PitchBend, 0)
        XCTAssertEqual(Float(1.0).toMIDI2PitchBend, 0xFFFFFFFF)

        let centerBend = Float(0.0).toMIDI2PitchBend
        XCTAssertEqual(centerBend, 0x80000000)
    }

    func testUInt32FromMIDI2Value() {
        XCTAssertEqual(UInt32(0).fromMIDI2Value, 0.0)
        XCTAssertEqual(UInt32(0xFFFFFFFF).fromMIDI2Value, 1.0, accuracy: 0.001)
    }

    func testUInt32FromMIDI2PitchBend() {
        XCTAssertEqual(UInt32(0).fromMIDI2PitchBend, -1.0, accuracy: 0.001)
        XCTAssertEqual(UInt32(0x80000000).fromMIDI2PitchBend, 0.0, accuracy: 0.001)
        XCTAssertEqual(UInt32(0xFFFFFFFF).fromMIDI2PitchBend, 1.0, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testVelocityClamping() {
        // Test velocity above 1.0 is clamped
        let overMax = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 2.0)
        let velocity = UInt16(overMax.data >> 16)
        XCTAssertEqual(velocity, 0xFFFF)

        // Test velocity below 0.0 is clamped
        let underMin = UMPPacket64.noteOn(channel: 0, note: 60, velocity: -1.0)
        let minVelocity = UInt16(underMin.data >> 16)
        XCTAssertEqual(minVelocity, 0)
    }

    func testChannelRange() {
        // Test channel is masked to 4 bits (0-15)
        let packet = UMPPacket64.noteOn(channel: 15, note: 60, velocity: 0.5)
        XCTAssertEqual(packet.channel, 15)

        // Channel 16 should wrap to 0
        let wrappedPacket = UMPPacket64.noteOn(channel: 16, note: 60, velocity: 0.5)
        XCTAssertEqual(wrappedPacket.channel, 0)
    }

    func testNoteRange() {
        // Test full MIDI note range
        let lowNote = UMPPacket64.noteOn(channel: 0, note: 0, velocity: 0.5)
        XCTAssertNotNil(lowNote)

        let highNote = UMPPacket64.noteOn(channel: 0, note: 127, velocity: 0.5)
        XCTAssertNotNil(highNote)
    }
}

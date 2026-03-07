#if canImport(AVFoundation)
// MIDITests.swift
// Echoelmusic — Phase 4 Test Coverage: MIDI 2.0 Types
//
// Tests for UMPPacket32, UMPPacket64, MIDI2Status, UMPMessageType,
// PerNoteController, and Float/UInt32 MIDI extensions.

import XCTest
@testable import Echoelmusic

// MARK: - UMPMessageType Tests

final class UMPMessageTypeTests: XCTestCase {

    func testAllTypes() {
        XCTAssertEqual(UMPMessageType.utility.rawValue, 0x0)
        XCTAssertEqual(UMPMessageType.systemRealTime.rawValue, 0x1)
        XCTAssertEqual(UMPMessageType.midi1ChannelVoice.rawValue, 0x2)
        XCTAssertEqual(UMPMessageType.sysEx.rawValue, 0x3)
        XCTAssertEqual(UMPMessageType.midi2ChannelVoice.rawValue, 0x4)
        XCTAssertEqual(UMPMessageType.data128.rawValue, 0x5)
    }
}

// MARK: - MIDI2Status Tests

final class MIDI2StatusTests: XCTestCase {

    func testCoreStatuses() {
        XCTAssertNotNil(MIDI2Status.noteOff)
        XCTAssertNotNil(MIDI2Status.noteOn)
        XCTAssertNotNil(MIDI2Status.polyPressure)
        XCTAssertNotNil(MIDI2Status.controlChange)
        XCTAssertNotNil(MIDI2Status.programChange)
        XCTAssertNotNil(MIDI2Status.channelPressure)
        XCTAssertNotNil(MIDI2Status.pitchBend)
    }

    func testPerNoteStatuses() {
        XCTAssertNotNil(MIDI2Status.perNoteManagement)
        XCTAssertNotNil(MIDI2Status.perNoteController)
        XCTAssertNotNil(MIDI2Status.perNotePitchBend)
    }
}

// MARK: - PerNoteController Tests

final class PerNoteControllerTests: XCTestCase {

    func testCoreControllers() {
        XCTAssertNotNil(PerNoteController.modulation)
        XCTAssertNotNil(PerNoteController.breath)
        XCTAssertNotNil(PerNoteController.expression)
    }

    func testSoundControllers() {
        XCTAssertNotNil(PerNoteController.sound1Timbre)
        XCTAssertNotNil(PerNoteController.sound2Brightness)
        XCTAssertNotNil(PerNoteController.sound3Attack)
        XCTAssertNotNil(PerNoteController.sound4Cutoff)
        XCTAssertNotNil(PerNoteController.sound5Decay)
    }
}

// MARK: - UMPPacket64 Tests

final class UMPPacket64Tests: XCTestCase {

    func testNoteOn() {
        let packet = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.8)
        XCTAssertEqual(packet.channel, 0)
        XCTAssertEqual(packet.index, 60) // note number
        XCTAssertEqual(packet.messageType, UMPMessageType.midi2ChannelVoice.rawValue)
    }

    func testNoteOff() {
        let packet = UMPPacket64.noteOff(channel: 0, note: 60, velocity: 0.0)
        XCTAssertEqual(packet.channel, 0)
        XCTAssertEqual(packet.index, 60)
    }

    func testNoteOnVelocityMapping() {
        // Full velocity
        let full = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 1.0)
        let fullData = full.data
        XCTAssertGreaterThan(fullData, 0)

        // Zero velocity
        let zero = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.0)
        let zeroData = zero.data
        XCTAssertEqual(zeroData, 0)
    }

    func testPerNoteController() {
        let packet = UMPPacket64.perNoteController(
            channel: 1,
            note: 64,
            controller: PerNoteController.modulation.rawValue,
            value: 0x80000000
        )
        XCTAssertEqual(packet.channel, 1)
        XCTAssertEqual(packet.index, 64)
    }

    func testPerNotePitchBend() {
        let packet = UMPPacket64.perNotePitchBend(channel: 0, note: 60, bend: 0x80000000)
        XCTAssertEqual(packet.channel, 0)
        XCTAssertEqual(packet.index, 60)
    }

    func testChannelPressure() {
        let packet = UMPPacket64.channelPressure(channel: 5, pressure: 0x40000000)
        XCTAssertEqual(packet.channel, 5)
    }

    func testControlChange() {
        let packet = UMPPacket64.controlChange(channel: 0, controller: 1, value: 0x7FFFFFFF)
        XCTAssertEqual(packet.channel, 0)
    }

    func testBytes() {
        let packet = UMPPacket64.noteOn(channel: 0, note: 60, velocity: 0.5)
        let bytes = packet.bytes
        XCTAssertEqual(bytes.count, 8)
    }
}

// MARK: - UMPPacket32 Tests

final class UMPPacket32Tests: XCTestCase {

    func testInit() {
        let packet = UMPPacket32(
            messageType: UMPMessageType.midi1ChannelVoice.rawValue,
            group: 0,
            status: MIDI2Status.noteOn.rawValue,
            data1: 60,
            data2: 100
        )
        XCTAssertEqual(packet.messageType, UMPMessageType.midi1ChannelVoice.rawValue)
        XCTAssertEqual(packet.group, 0)
        XCTAssertEqual(packet.status, MIDI2Status.noteOn.rawValue)
        XCTAssertEqual(packet.data1, 60)
        XCTAssertEqual(packet.data2, 100)
    }

    func testBytes() {
        let packet = UMPPacket32(
            messageType: 0x2,
            group: 0,
            status: 0x90,
            data1: 60,
            data2: 127
        )
        let bytes = packet.bytes
        XCTAssertEqual(bytes.count, 4)
    }
}

// MARK: - MIDI Float/UInt32 Extension Tests

final class MIDIValueConversionTests: XCTestCase {

    func testFloatToMIDI2Value() {
        let zero: Float = 0.0
        XCTAssertEqual(zero.toMIDI2Value, 0)

        let full: Float = 1.0
        XCTAssertEqual(full.toMIDI2Value, UInt32.max)

        let half: Float = 0.5
        let halfValue = half.toMIDI2Value
        // Should be approximately half of UInt32.max
        let expected = UInt32(Float(UInt32.max) * 0.5)
        XCTAssertEqual(halfValue, expected, accuracy: 1000)
    }

    func testMIDI2ValueToFloat() {
        let zero: UInt32 = 0
        XCTAssertEqual(zero.fromMIDI2Value, 0.0, accuracy: 0.001)

        let max = UInt32.max
        XCTAssertEqual(max.fromMIDI2Value, 1.0, accuracy: 0.001)
    }

    func testFloatToMIDI2PitchBend() {
        let center: Float = 0.0
        let centerValue = center.toMIDI2PitchBend
        // Center should be ~0x80000000
        XCTAssertEqual(centerValue, 0x80000000, accuracy: 1000)
    }

    func testMIDI2PitchBendToFloat() {
        let center: UInt32 = 0x80000000
        let value = center.fromMIDI2PitchBend
        XCTAssertEqual(value, 0.0, accuracy: 0.01)
    }

    func testRoundtripConversion() {
        let original: Float = 0.75
        let midi2 = original.toMIDI2Value
        let back = midi2.fromMIDI2Value
        XCTAssertEqual(back, original, accuracy: 0.001)
    }
}

// Helper for UInt32 accuracy comparison
private func XCTAssertEqual(_ a: UInt32, _ b: UInt32, accuracy: UInt32, file: StaticString = #file, line: UInt = #line) {
    let diff = a > b ? a - b : b - a
    XCTAssertLessThanOrEqual(diff, accuracy, "Values \(a) and \(b) differ by more than \(accuracy)", file: file, line: line)
}
#endif

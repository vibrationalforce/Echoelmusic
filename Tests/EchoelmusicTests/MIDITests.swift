// MIDITests.swift
// Echoelmusic - MIDI Test Suite
// Wise Mode Implementation

import XCTest
@testable import Echoelmusic

final class MIDITests: XCTestCase {

    // MARK: - Properties

    var midiService: MIDIService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        midiService = MIDIService()
    }

    override func tearDown() {
        midiService = nil
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testInitiallyDisconnected() {
        XCTAssertFalse(midiService.isConnected)
    }

    func testConnect() async throws {
        try await midiService.connect()
        XCTAssertTrue(midiService.isConnected)
    }

    func testDisconnect() async throws {
        try await midiService.connect()
        midiService.disconnect()
        XCTAssertFalse(midiService.isConnected)
    }

    // MARK: - MIDI Note Validation Tests

    func testMIDINoteValidation() {
        // Valid range 0-127
        for note: UInt8 in 0...127 {
            XCTAssertEqual(InputValidator.validateMIDINote(note), note)
        }

        // Edge case: UInt8 max is 255, but MIDI notes max at 127
        XCTAssertEqual(InputValidator.validateMIDINote(128), 127)
        XCTAssertEqual(InputValidator.validateMIDINote(255), 127)
    }

    func testMIDIVelocityValidation() {
        // Valid range 0-127
        for velocity: UInt8 in 0...127 {
            XCTAssertEqual(InputValidator.validateMIDIVelocity(velocity), velocity)
        }

        // Clamp to 127
        XCTAssertEqual(InputValidator.validateMIDIVelocity(200), 127)
    }

    func testMIDIChannelValidation() {
        // Valid range 0-15 (channels 1-16 in MIDI spec)
        for channel: UInt8 in 0...15 {
            XCTAssertEqual(InputValidator.validateMIDIChannel(channel), channel)
        }

        // Clamp to 15
        XCTAssertEqual(InputValidator.validateMIDIChannel(16), 15)
        XCTAssertEqual(InputValidator.validateMIDIChannel(100), 15)
    }

    func testMIDICCValidation() {
        // Valid range 0-127
        for cc: UInt8 in 0...127 {
            XCTAssertEqual(InputValidator.validateMIDICC(cc), cc)
        }

        // Clamp to 127
        XCTAssertEqual(InputValidator.validateMIDICC(200), 127)
    }

    func testMIDIPitchBendValidation() {
        // Valid range 0-16383 (14-bit)
        XCTAssertEqual(InputValidator.validateMIDIPitchBend(0), 0)
        XCTAssertEqual(InputValidator.validateMIDIPitchBend(8192), 8192) // Center
        XCTAssertEqual(InputValidator.validateMIDIPitchBend(16383), 16383)

        // Clamp to max
        XCTAssertEqual(InputValidator.validateMIDIPitchBend(20000), 16383)
    }

    // MARK: - Note Name Tests

    func testNoteNameConversion() {
        XCTAssertEqual(noteNameFromMIDI(60), "C4")   // Middle C
        XCTAssertEqual(noteNameFromMIDI(69), "A4")   // A440
        XCTAssertEqual(noteNameFromMIDI(0), "C-1")
        XCTAssertEqual(noteNameFromMIDI(127), "G9")
    }

    func testMIDIFromNoteName() {
        XCTAssertEqual(midiFromNoteName("C4"), 60)
        XCTAssertEqual(midiFromNoteName("A4"), 69)
        XCTAssertEqual(midiFromNoteName("C-1"), 0)
        XCTAssertEqual(midiFromNoteName("G9"), 127)
    }

    func testNoteNameRoundTrip() {
        for note: UInt8 in 0...127 {
            let name = noteNameFromMIDI(note)
            let converted = midiFromNoteName(name)
            XCTAssertEqual(converted, note, "Note \(note) -> \(name) -> \(String(describing: converted))")
        }
    }

    // MARK: - Frequency Tests

    func testMIDIToFrequency() {
        // A4 = 440 Hz
        XCTAssertEqual(midiToFrequency(69), 440.0, accuracy: 0.01)

        // A3 = 220 Hz (one octave below)
        XCTAssertEqual(midiToFrequency(57), 220.0, accuracy: 0.01)

        // A5 = 880 Hz (one octave above)
        XCTAssertEqual(midiToFrequency(81), 880.0, accuracy: 0.01)

        // C4 (Middle C) ~= 261.63 Hz
        XCTAssertEqual(midiToFrequency(60), 261.63, accuracy: 0.1)
    }

    func testFrequencyToMIDI() {
        XCTAssertEqual(frequencyToMIDI(440.0), 69)
        XCTAssertEqual(frequencyToMIDI(220.0), 57)
        XCTAssertEqual(frequencyToMIDI(880.0), 81)
        XCTAssertEqual(frequencyToMIDI(261.63), 60)
    }

    // MARK: - MPE Zone Tests

    func testMPEZoneDefaults() {
        let zone = MPEZone()
        XCTAssertEqual(zone.masterChannel, 0)
        XCTAssertEqual(zone.memberChannels, 1...15)
        XCTAssertEqual(zone.pitchBendRange, 48)
    }

    func testMPEZoneCustom() {
        let zone = MPEZone(masterChannel: 15, memberChannels: 1...7, pitchBendRange: 24)
        XCTAssertEqual(zone.masterChannel, 15)
        XCTAssertEqual(zone.memberChannels, 1...7)
        XCTAssertEqual(zone.pitchBendRange, 24)
    }

    func testMPEMemberChannelCount() {
        let zone = MPEZone()
        XCTAssertEqual(zone.memberChannels.count, 15, "Standard MPE has 15 member channels")
    }

    // MARK: - Send Note Tests

    func testSendNoteValidation() {
        // This should not crash with any values
        midiService.sendNote(note: 60, velocity: 127, channel: 0)
        midiService.sendNote(note: 0, velocity: 0, channel: 15)
        midiService.sendNote(note: 127, velocity: 127, channel: 15)

        // Values beyond valid range should be clamped
        midiService.sendNote(note: 200, velocity: 200, channel: 20)
    }

    // MARK: - Helper Functions

    private func noteNameFromMIDI(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteName = noteNames[Int(note) % 12]
        return "\(noteName)\(octave)"
    }

    private func midiFromNoteName(_ name: String) -> UInt8? {
        let noteValues: [String: Int] = [
            "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
            "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
            "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11
        ]

        // Parse note name and octave
        var notePart = ""
        var octavePart = ""

        for char in name {
            if char.isNumber || char == "-" {
                octavePart.append(char)
            } else {
                notePart.append(char)
            }
        }

        guard let noteValue = noteValues[notePart],
              let octave = Int(octavePart) else {
            return nil
        }

        let midi = (octave + 1) * 12 + noteValue
        guard midi >= 0 && midi <= 127 else { return nil }
        return UInt8(midi)
    }

    private func midiToFrequency(_ note: UInt8) -> Double {
        440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }

    private func frequencyToMIDI(_ frequency: Double) -> UInt8 {
        let note = 69.0 + 12.0 * log2(frequency / 440.0)
        return UInt8(round(note).clamped(to: 0...127))
    }
}

// MARK: - Performance Tests

extension MIDITests {

    func testNoteConversionPerformance() {
        measure {
            for _ in 0..<10000 {
                let note = UInt8.random(in: 0...127)
                _ = noteNameFromMIDI(note)
            }
        }
    }

    func testFrequencyConversionPerformance() {
        measure {
            for _ in 0..<10000 {
                let note = UInt8.random(in: 0...127)
                _ = midiToFrequency(note)
            }
        }
    }

    func testValidationPerformance() {
        measure {
            for _ in 0..<100000 {
                _ = InputValidator.validateMIDINote(UInt8.random(in: 0...255))
                _ = InputValidator.validateMIDIVelocity(UInt8.random(in: 0...255))
                _ = InputValidator.validateMIDIChannel(UInt8.random(in: 0...255))
            }
        }
    }
}

// MARK: - Extensions

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

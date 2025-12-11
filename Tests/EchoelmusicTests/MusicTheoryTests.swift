// MusicTheoryTests.swift
// Echoelmusic - Music Theory Type Tests
// SPDX-License-Identifier: MIT

import XCTest
@testable import Echoelmusic

final class MusicTheoryTests: XCTestCase {

    // MARK: - Musical Scale Tests

    func testMajorScaleIntervals() {
        let scale = MusicalScale.major
        XCTAssertEqual(scale.intervals, [0, 2, 4, 5, 7, 9, 11])
        XCTAssertEqual(scale.noteCount, 7)
    }

    func testMinorScaleIntervals() {
        let scale = MusicalScale.minor
        XCTAssertEqual(scale.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testPentatonicScales() {
        XCTAssertEqual(MusicalScale.pentatonicMajor.noteCount, 5)
        XCTAssertEqual(MusicalScale.pentatonicMinor.noteCount, 5)
    }

    func testChromaticScale() {
        let scale = MusicalScale.chromatic
        XCTAssertEqual(scale.noteCount, 12)
        XCTAssertEqual(scale.intervals, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    }

    func testNoteInScale() {
        let cMajor = MusicalScale.major

        // C4 = 60
        XCTAssertEqual(cMajor.noteInScale(degree: 0, root: 60), 60) // C
        XCTAssertEqual(cMajor.noteInScale(degree: 1, root: 60), 62) // D
        XCTAssertEqual(cMajor.noteInScale(degree: 2, root: 60), 64) // E
        XCTAssertEqual(cMajor.noteInScale(degree: 3, root: 60), 65) // F
        XCTAssertEqual(cMajor.noteInScale(degree: 4, root: 60), 67) // G
        XCTAssertEqual(cMajor.noteInScale(degree: 5, root: 60), 69) // A
        XCTAssertEqual(cMajor.noteInScale(degree: 6, root: 60), 71) // B
        XCTAssertEqual(cMajor.noteInScale(degree: 7, root: 60), 72) // C (next octave)
    }

    func testAllNotesInScale() {
        let cMajor = MusicalScale.major
        let notes = cMajor.allNotes(root: 60, octaves: 1)

        XCTAssertEqual(notes.count, 7)
        XCTAssertEqual(notes, [60, 62, 64, 65, 67, 69, 71])
    }

    func testScaleContainsNote() {
        let cMajor = MusicalScale.major

        // C major contains C, D, E, F, G, A, B
        XCTAssertTrue(cMajor.contains(note: 60, root: 60)) // C
        XCTAssertTrue(cMajor.contains(note: 62, root: 60)) // D
        XCTAssertFalse(cMajor.contains(note: 61, root: 60)) // C# not in C major
        XCTAssertFalse(cMajor.contains(note: 63, root: 60)) // D# not in C major
    }

    func testScaleQuantization() {
        let cMajor = MusicalScale.major

        // C# should quantize to C or D
        let quantized = cMajor.quantize(note: 61, root: 60)
        XCTAssertTrue(quantized == 60 || quantized == 62)

        // C should stay C
        XCTAssertEqual(cMajor.quantize(note: 60, root: 60), 60)
    }

    // MARK: - Chord Type Tests

    func testMajorChord() {
        let chord = ChordType.major
        XCTAssertEqual(chord.intervals, [0, 4, 7])

        let cMajor = chord.notes(root: 60)
        XCTAssertEqual(cMajor, [60, 64, 67]) // C, E, G
    }

    func testMinorChord() {
        let chord = ChordType.minor
        XCTAssertEqual(chord.intervals, [0, 3, 7])

        let cMinor = chord.notes(root: 60)
        XCTAssertEqual(cMinor, [60, 63, 67]) // C, Eb, G
    }

    func testSeventhChords() {
        let maj7 = ChordType.major7.notes(root: 60)
        XCTAssertEqual(maj7, [60, 64, 67, 71]) // C, E, G, B

        let min7 = ChordType.minor7.notes(root: 60)
        XCTAssertEqual(min7, [60, 63, 67, 70]) // C, Eb, G, Bb

        let dom7 = ChordType.dominant7.notes(root: 60)
        XCTAssertEqual(dom7, [60, 64, 67, 70]) // C, E, G, Bb
    }

    func testChordInversions() {
        let chord = ChordType.major

        // Root position
        let root = chord.notes(root: 60, inversion: 0)
        XCTAssertEqual(root, [60, 64, 67])

        // First inversion - E in bass
        let first = chord.notes(root: 60, inversion: 1)
        XCTAssertEqual(first, [64, 67, 72])

        // Second inversion - G in bass
        let second = chord.notes(root: 60, inversion: 2)
        XCTAssertEqual(second, [67, 72, 76])
    }

    func testChordSymbols() {
        XCTAssertEqual(ChordType.major.symbol, "")
        XCTAssertEqual(ChordType.minor.symbol, "m")
        XCTAssertEqual(ChordType.diminished.symbol, "°")
        XCTAssertEqual(ChordType.augmented.symbol, "+")
        XCTAssertEqual(ChordType.dominant7.symbol, "7")
        XCTAssertEqual(ChordType.major7.symbol, "maj7")
    }

    // MARK: - Note Utility Tests

    func testNoteNames() {
        XCTAssertEqual(NoteUtility.name(for: 60), "C")
        XCTAssertEqual(NoteUtility.name(for: 61), "C#")
        XCTAssertEqual(NoteUtility.name(for: 61, useFlats: true), "Db")
        XCTAssertEqual(NoteUtility.name(for: 69), "A")
    }

    func testFullNoteNames() {
        XCTAssertEqual(NoteUtility.fullName(for: 60), "C4")
        XCTAssertEqual(NoteUtility.fullName(for: 69), "A4")
        XCTAssertEqual(NoteUtility.fullName(for: 21), "A0")
        XCTAssertEqual(NoteUtility.fullName(for: 108), "C8")
    }

    func testMIDINoteFromName() {
        XCTAssertEqual(NoteUtility.midiNote(name: "C", octave: 4), 60)
        XCTAssertEqual(NoteUtility.midiNote(name: "A", octave: 4), 69)
        XCTAssertEqual(NoteUtility.midiNote(name: "C#", octave: 4), 61)
        XCTAssertEqual(NoteUtility.midiNote(name: "Db", octave: 4), 61)
    }

    func testChordNames() {
        XCTAssertEqual(NoteUtility.chordName(root: 60, type: .major), "C")
        XCTAssertEqual(NoteUtility.chordName(root: 60, type: .minor), "Cm")
        XCTAssertEqual(NoteUtility.chordName(root: 60, type: .dominant7), "C7")
        XCTAssertEqual(NoteUtility.chordName(root: 62, type: .minor7), "Dm7")
    }

    func testFrequencyConversion() {
        // A4 = 440 Hz
        XCTAssertEqual(NoteUtility.frequency(for: 69), 440.0, accuracy: 0.001)

        // A3 = 220 Hz
        XCTAssertEqual(NoteUtility.frequency(for: 57), 220.0, accuracy: 0.001)

        // A5 = 880 Hz
        XCTAssertEqual(NoteUtility.frequency(for: 81), 880.0, accuracy: 0.001)

        // C4 ≈ 261.63 Hz
        XCTAssertEqual(NoteUtility.frequency(for: 60), 261.63, accuracy: 0.01)
    }

    func testMIDINoteFromFrequency() {
        XCTAssertEqual(NoteUtility.midiNote(for: 440.0), 69) // A4
        XCTAssertEqual(NoteUtility.midiNote(for: 261.63), 60) // C4
        XCTAssertEqual(NoteUtility.midiNote(for: 880.0), 81) // A5
    }

    // MARK: - Key Signature Tests

    func testKeySignatureCreation() {
        let cMajor = KeySignature.cMajor
        XCTAssertEqual(cMajor.root, 0)
        XCTAssertEqual(cMajor.scale, .major)
        XCTAssertEqual(cMajor.displayName, "C Major")
    }

    func testRelativeKeys() {
        let cMajor = KeySignature.cMajor
        let relative = cMajor.relative

        XCTAssertEqual(relative.root, 9) // A
        XCTAssertEqual(relative.scale, .minor)
        XCTAssertEqual(relative.displayName, "A Minor")
    }

    func testParallelKeys() {
        let cMajor = KeySignature.cMajor
        let parallel = cMajor.parallel

        XCTAssertEqual(parallel.root, 0) // Still C
        XCTAssertEqual(parallel.scale, .minor)
    }

    // MARK: - Time Signature Tests

    func testCommonTimeSignatures() {
        let common = TimeSignature.common
        XCTAssertEqual(common.numerator, 4)
        XCTAssertEqual(common.denominator, 4)
        XCTAssertEqual(common.beatsPerBar, 4)
        XCTAssertEqual(common.displayString, "4/4")

        let waltz = TimeSignature.waltz
        XCTAssertEqual(waltz.beatsPerBar, 3)
        XCTAssertEqual(waltz.displayString, "3/4")
    }

    func testBeatDuration() {
        let common = TimeSignature.common
        XCTAssertEqual(common.beatDuration, 1.0) // Quarter note

        let sixEight = TimeSignature.sixEight
        XCTAssertEqual(sixEight.beatDuration, 0.5) // Eighth note
    }
}

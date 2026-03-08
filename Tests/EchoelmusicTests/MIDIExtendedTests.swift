#if canImport(AVFoundation)
// MIDIExtendedTests.swift
// Echoelmusic — Extended MIDI Module Test Coverage
//
// Tests for TouchInstruments types.

import XCTest
@testable import Echoelmusic

// MARK: - TouchMusicalScale Tests

final class TouchMusicalScaleTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TouchMusicalScale.allCases.count, 14)
    }

    func testRawValues() {
        XCTAssertEqual(TouchMusicalScale.major.rawValue, "Major")
        XCTAssertEqual(TouchMusicalScale.minor.rawValue, "Minor")
        XCTAssertEqual(TouchMusicalScale.harmonicMinor.rawValue, "Harmonic Minor")
        XCTAssertEqual(TouchMusicalScale.melodicMinor.rawValue, "Melodic Minor")
        XCTAssertEqual(TouchMusicalScale.dorian.rawValue, "Dorian")
        XCTAssertEqual(TouchMusicalScale.phrygian.rawValue, "Phrygian")
        XCTAssertEqual(TouchMusicalScale.lydian.rawValue, "Lydian")
        XCTAssertEqual(TouchMusicalScale.mixolydian.rawValue, "Mixolydian")
        XCTAssertEqual(TouchMusicalScale.locrian.rawValue, "Locrian")
        XCTAssertEqual(TouchMusicalScale.pentatonicMajor.rawValue, "Pentatonic Major")
        XCTAssertEqual(TouchMusicalScale.pentatonicMinor.rawValue, "Pentatonic Minor")
        XCTAssertEqual(TouchMusicalScale.blues.rawValue, "Blues")
        XCTAssertEqual(TouchMusicalScale.chromatic.rawValue, "Chromatic")
        XCTAssertEqual(TouchMusicalScale.wholeNote.rawValue, "Whole Tone")
    }

    func testIntervalsNotEmpty() {
        for scale in TouchMusicalScale.allCases {
            XCTAssertFalse(scale.intervals.isEmpty, "\(scale.rawValue) should have intervals")
        }
    }

    func testIntervalsStartWithZero() {
        for scale in TouchMusicalScale.allCases {
            XCTAssertEqual(scale.intervals.first, 0, "\(scale.rawValue) should start at root")
        }
    }

    func testIntervalsBoundedByOctave() {
        for scale in TouchMusicalScale.allCases {
            for interval in scale.intervals {
                XCTAssertGreaterThanOrEqual(interval, 0, "\(scale.rawValue) interval out of range")
                XCTAssertLessThanOrEqual(interval, 11, "\(scale.rawValue) interval exceeds octave")
            }
        }
    }

    func testMajorScaleIntervals() {
        XCTAssertEqual(TouchMusicalScale.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testMinorScaleIntervals() {
        XCTAssertEqual(TouchMusicalScale.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testChromaticScaleHas12Notes() {
        XCTAssertEqual(TouchMusicalScale.chromatic.intervals.count, 12)
    }

    func testPentatonicScalesHave5Notes() {
        XCTAssertEqual(TouchMusicalScale.pentatonicMajor.intervals.count, 5)
        XCTAssertEqual(TouchMusicalScale.pentatonicMinor.intervals.count, 5)
    }

    func testBluesScaleHas6Notes() {
        XCTAssertEqual(TouchMusicalScale.blues.intervals.count, 6)
    }

    func testWholeNoteScaleHas6Notes() {
        XCTAssertEqual(TouchMusicalScale.wholeNote.intervals.count, 6)
    }

    func testNoteInScaleRootDegree() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 0, root: 60)
        XCTAssertEqual(note, 60)
    }

    func testNoteInScaleSecondDegree() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 1, root: 60)
        XCTAssertEqual(note, 62)
    }

    func testNoteInScaleOctaveWrap() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 7, root: 60) // One octave up
        XCTAssertEqual(note, 72)
    }

    func testNoteInScaleClampedTo127() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 50, root: 120)
        XCTAssertLessThanOrEqual(note, 127)
    }

    func testNoteInScaleClampedTo0() {
        let scale = TouchMusicalScale.major
        let note = scale.noteInScale(degree: 0, root: 0)
        XCTAssertGreaterThanOrEqual(note, 0)
    }
}

// MARK: - ChordType Tests (TouchInstruments)

final class TouchChordTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordType.allCases.count, 11)
    }

    func testRawValues() {
        XCTAssertEqual(ChordType.major.rawValue, "Major")
        XCTAssertEqual(ChordType.minor.rawValue, "Minor")
        XCTAssertEqual(ChordType.diminished.rawValue, "Dim")
        XCTAssertEqual(ChordType.augmented.rawValue, "Aug")
        XCTAssertEqual(ChordType.major7.rawValue, "Maj7")
        XCTAssertEqual(ChordType.minor7.rawValue, "Min7")
        XCTAssertEqual(ChordType.dominant7.rawValue, "7")
        XCTAssertEqual(ChordType.sus2.rawValue, "Sus2")
        XCTAssertEqual(ChordType.sus4.rawValue, "Sus4")
        XCTAssertEqual(ChordType.add9.rawValue, "Add9")
        XCTAssertEqual(ChordType.power.rawValue, "5")
    }

    func testIntervalsNotEmpty() {
        for chord in ChordType.allCases {
            XCTAssertFalse(chord.intervals.isEmpty, "\(chord.rawValue) should have intervals")
        }
    }

    func testIntervalsStartWithRoot() {
        for chord in ChordType.allCases {
            XCTAssertEqual(chord.intervals.first, 0, "\(chord.rawValue) should start with root")
        }
    }

    func testMajorChordIntervals() {
        XCTAssertEqual(ChordType.major.intervals, [0, 4, 7])
    }

    func testMinorChordIntervals() {
        XCTAssertEqual(ChordType.minor.intervals, [0, 3, 7])
    }

    func testPowerChordIntervals() {
        XCTAssertEqual(ChordType.power.intervals, [0, 7])
    }

    func testNotesFunction() {
        let notes = ChordType.major.notes(root: 60)
        XCTAssertEqual(notes, [60, 64, 67])
    }

    func testNotesFunctionMinor() {
        let notes = ChordType.minor.notes(root: 60)
        XCTAssertEqual(notes, [60, 63, 67])
    }

    func testNotesFunctionClampedHigh() {
        let notes = ChordType.major.notes(root: 125)
        for note in notes {
            XCTAssertLessThanOrEqual(note, 127)
        }
    }

    func testNotesFunctionClampedLow() {
        let notes = ChordType.major.notes(root: 0)
        for note in notes {
            XCTAssertGreaterThanOrEqual(note, 0)
        }
    }

    func testTriadHas3Notes() {
        XCTAssertEqual(ChordType.major.intervals.count, 3)
        XCTAssertEqual(ChordType.minor.intervals.count, 3)
        XCTAssertEqual(ChordType.diminished.intervals.count, 3)
        XCTAssertEqual(ChordType.augmented.intervals.count, 3)
    }

    func testSeventhHas4Notes() {
        XCTAssertEqual(ChordType.major7.intervals.count, 4)
        XCTAssertEqual(ChordType.minor7.intervals.count, 4)
        XCTAssertEqual(ChordType.dominant7.intervals.count, 4)
    }

    func testPowerHas2Notes() {
        XCTAssertEqual(ChordType.power.intervals.count, 2)
    }
}

// MARK: - ChordPad Tests

final class ChordPadTests: XCTestCase {

    func testInit() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.rootNote, 60)
        XCTAssertEqual(pad.chordType, .major)
        XCTAssertNotNil(pad.id)
    }

    func testChordNameC() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.chordName, "C")
    }

    func testChordNameD() {
        let pad = ChordPad(rootNote: 62, chordType: .minor, color: .red)
        XCTAssertEqual(pad.chordName, "D")
    }

    func testChordNameA() {
        let pad = ChordPad(rootNote: 69, chordType: .minor, color: .green)
        XCTAssertEqual(pad.chordName, "A")
    }

    func testNotes() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertEqual(pad.notes, [60, 64, 67])
    }

    func testNotesMinor() {
        let pad = ChordPad(rootNote: 69, chordType: .minor, color: .blue)
        XCTAssertEqual(pad.notes, [69, 72, 76])
    }

    func testIdentifiable() {
        let pad = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertNotNil(pad.id)
    }

    func testUniqueIds() {
        let pad1 = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        let pad2 = ChordPad(rootNote: 60, chordType: .major, color: .blue)
        XCTAssertNotEqual(pad1.id, pad2.id)
    }
}

// MARK: - DrumPadModel Tests

final class DrumPadModelTests: XCTestCase {

    func testInit() {
        let pad = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        XCTAssertEqual(pad.name, "Kick")
        XCTAssertEqual(pad.midiNote, 36)
        XCTAssertNotNil(pad.id)
    }

    func testUniqueIds() {
        let pad1 = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        let pad2 = DrumPadModel(name: "Kick", midiNote: 36, color: .red)
        XCTAssertNotEqual(pad1.id, pad2.id)
    }
}

// MARK: - DrumKit Tests

final class DrumKitTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(DrumKit.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(DrumKit.acoustic.rawValue, "Acoustic")
        XCTAssertEqual(DrumKit.electronic.rawValue, "Electronic")
        XCTAssertEqual(DrumKit.tr808.rawValue, "808")
        XCTAssertEqual(DrumKit.tr909.rawValue, "909")
        XCTAssertEqual(DrumKit.hiphop.rawValue, "Hip Hop")
        XCTAssertEqual(DrumKit.percussion.rawValue, "Percussion")
    }

    func testAllKitsHave16Pads() {
        for kit in DrumKit.allCases {
            XCTAssertEqual(kit.pads.count, 16, "\(kit.rawValue) should have 16 pads")
        }
    }

    func testAcousticKitKick() {
        let pads = DrumKit.acoustic.pads
        XCTAssertEqual(pads[0].name, "Kick")
        XCTAssertEqual(pads[0].midiNote, 36)
    }

    func testTR808KitKick() {
        let pads = DrumKit.tr808.pads
        XCTAssertEqual(pads[0].name, "Kick")
        XCTAssertEqual(pads[0].midiNote, 36)
    }

    func testAllKitPadsHaveNames() {
        for kit in DrumKit.allCases {
            for pad in kit.pads {
                XCTAssertFalse(pad.name.isEmpty, "\(kit.rawValue) pad should have a name")
            }
        }
    }

    func testAllKitPadsHaveValidMIDINotes() {
        for kit in DrumKit.allCases {
            for pad in kit.pads {
                XCTAssertLessThanOrEqual(pad.midiNote, 127, "\(kit.rawValue) \(pad.name) exceeds MIDI range")
            }
        }
    }
}

// MARK: - TouchInstrumentsHub.InstrumentType Tests

final class TouchInstrumentTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.chordPad.rawValue, "Chord Pad")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.drumPad.rawValue, "Drum Pad")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.melodyPad.rawValue, "Melody XY")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.keyboard.rawValue, "Keyboard")
        XCTAssertEqual(TouchInstrumentsHub.InstrumentType.strumPad.rawValue, "Strum Pad")
    }
}

// MARK: - ChordPadViewModel.PlayMode Tests

final class ChordPadPlayModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordPadViewModel.PlayMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(ChordPadViewModel.PlayMode.simultaneous.rawValue, "Chord")
        XCTAssertEqual(ChordPadViewModel.PlayMode.strum.rawValue, "Strum")
        XCTAssertEqual(ChordPadViewModel.PlayMode.arpeggio.rawValue, "Arp")
    }
}

// MARK: - ChordPadViewModel.ArpPattern Tests

final class ChordPadArpPatternTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ChordPadViewModel.ArpPattern.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(ChordPadViewModel.ArpPattern.up.rawValue, "Up")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.down.rawValue, "Down")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.upDown.rawValue, "Up/Down")
        XCTAssertEqual(ChordPadViewModel.ArpPattern.random.rawValue, "Random")
    }
}

// MARK: - DrumPadViewModel.VelocityCurve Tests

final class VelocityCurveTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.soft.rawValue, "Soft")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.linear.rawValue, "Linear")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.hard.rawValue, "Hard")
        XCTAssertEqual(DrumPadViewModel.VelocityCurve.fixed.rawValue, "Fixed")
    }

    func testLinearApply() {
        let curve = DrumPadViewModel.VelocityCurve.linear
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.01)
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.01)
    }

    func testSoftApply() {
        let curve = DrumPadViewModel.VelocityCurve.soft
        // sqrt(0.25) = 0.5 — soft curve should be higher than linear for mid values
        XCTAssertGreaterThan(curve.apply(0.25), 0.25)
    }

    func testHardApply() {
        let curve = DrumPadViewModel.VelocityCurve.hard
        // pow(0.5, 2.0) = 0.25 — hard curve should be lower than linear for mid values
        XCTAssertLessThan(curve.apply(0.5), 0.5)
    }

    func testFixedApply() {
        let curve = DrumPadViewModel.VelocityCurve.fixed
        XCTAssertEqual(curve.apply(0.1), 0.9)
        XCTAssertEqual(curve.apply(0.5), 0.9)
        XCTAssertEqual(curve.apply(1.0), 0.9)
    }

    func testAllCurvesReturnValidRange() {
        for curve in DrumPadViewModel.VelocityCurve.allCases {
            for input in stride(from: Float(0), through: Float(1.0), by: 0.1) {
                let result = curve.apply(input)
                XCTAssertGreaterThanOrEqual(result, 0.0, "\(curve.rawValue) returned negative for input \(input)")
                XCTAssertLessThanOrEqual(result, 1.0, "\(curve.rawValue) exceeded 1.0 for input \(input)")
            }
        }
    }
}
#endif

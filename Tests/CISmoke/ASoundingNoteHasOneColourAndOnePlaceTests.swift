// ASoundingNoteHasOneColourAndOnePlaceTests.swift
// Echoel — DMMW Phase 6 · slice 1 (founder 2026-09-29, "Klang-zu-Licht und Grit": note/frequency
// → octave colour → cloud/grid deterministic; key and A4 change colour and place consistently;
// neighbouring octaves visibly belong together; base colour, brightness and density separate;
// silence has a defined neutral; greyscale must not destroy the information; tests for key, A4
// and octave changes).
//
// WHY A TEST-ONLY SLICE FIRST. The rule already exists and is live — `SpectralColor.toneLinearRGB`
// (octave-folded CIE 1931 light, closed over the purple line) is the one colour the clouds, the
// touch ripple, the grid tint and, through `physicalColor`, the Art-Net/sACN fixtures use; the
// cloud's place is `TouchPitchMap.fieldPosition` with `SpectralColor.notePosition` as fallback; and
// the one publisher, `PianoRollModel.musicalFrame`, bakes A4 into each note's Hz. But the
// Kammerton and key behaviour was pinned only in `Tests/EchoelmusicTests`, which NO gate compiles
// (#208). So the phase's acceptance rules had no guard at all. This file drives the SHIPPED pure
// functions, end to end, in the blocking bundle — it states the contract before any slice changes it.
//
// Claims — ALL END-TO-END over shipped, pure code (`Tests/CISmoke/CLAUDE.md` §1):
//   1. OCTAVE — every pitch class keeps ONE colour across neighbouring octaves (they belong
//      together), and its place differs only in height (they stay distinguishable).
//   2. KAMMERTON — the same written note at A4 432 / 440 / 444 sounds at exactly A4 and gets three
//      different colours, while its cloud stays in the same cell: colour follows the SOUNDING
//      frequency, the cell follows the note's NAME.
//   3. KEY — changing the key moves the note's column (its scale degree) and leaves its colour
//      alone (a frequency, not a name, has a colour); an off-key note has no cell and falls back
//      to pitch space.
//   4. NEUTRAL — silence and invalid input land on ONE defined neutral, which carries no hue.
//   5. SEPARATION — the note's level moves the frame's level, never its colour; and position
//      alone tells the pitch classes of an octave apart (the greyscale carrier).
// GRADING against the parent: every symbol exists there, so every assertion has a verdict on the
// parent and is GREEN on it — these are REGRESSION PINS for current behaviour, not forward guards
// (§3). Hand-derived from the algebra (#442), not from printed values.
// ⛔ HONEST LIMITS. The shader copy of the colour rule (`toneColour` in `MetalBioView`'s MSL) is not
// driven here — `SpectralSeamTwinTests` pins its constants to the CPU rule. What the eye sees on a
// device is a DEVICE PROBE. Known gaps this slice does NOT close, recorded for the next slices:
// the generated notes' Hz carries A4 but no tone-system cents (touch notes carry both); the grid
// tint was not rebuilt on an A4 change on the same synth (CLOSED by slice 2,
// `TheGridRepaintsWhenTheVoiceRetunesTests`); the shader's silence colour is a warm
// grey that differs from `SpectralColor.neutral`; and C lies exactly on the octave fold of
// `SpectralColor.notePosition` (fraction 0 vs 0.999… is decided by the last ulp of `log2`), so in
// pitch space its cloud can sit at the left OR the right edge — its column is not pinned here.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ASoundingNoteHasOneColourAndOnePlaceTests: XCTestCase {

    private func distance(_ a: LinearRGB, _ b: LinearRGB) -> Double {
        let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// The Hz the ONE publisher gives a written pitch — the path every generated note takes.
    private func publishedHz(pitch: Int, a4: Double) throws -> Double {
        let frame = PianoRollModel.musicalFrame(
            forActive: [Note(pitch: pitch, startStep: 0, velocity: 0.8)], a4Hz: a4,
            rootPitchClass: 0, scaleName: "major", tempoBPM: 120, beatPhase: 0)
        return try XCTUnwrap(frame.notes.first?.frequencyHz)
    }

    // MARK: 1 — OCTAVE

    func testNeighbouringOctavesShareTheColourAndDifferOnlyInHeight() throws {
        for pitchClass in 0..<12 {
            let low = try publishedHz(pitch: 48 + pitchClass, a4: 440)
            let mid = try publishedHz(pitch: 60 + pitchClass, a4: 440)
            let high = try publishedHz(pitch: 72 + pitchClass, a4: 440)
            let cMid = SpectralColor.toneLinearRGB(forToneHz: mid)
            XCTAssertLessThan(distance(SpectralColor.toneLinearRGB(forToneHz: low), cMid), 1e-9,
                              "pitch class \(pitchClass): an octave down is the same light")
            XCTAssertLessThan(distance(SpectralColor.toneLinearRGB(forToneHz: high), cMid), 1e-9,
                              "pitch class \(pitchClass): an octave up is the same light")

            let pLow = SpectralColor.notePosition(forHz: low)
            let pMid = SpectralColor.notePosition(forHz: mid)
            let pHigh = SpectralColor.notePosition(forHz: high)
            // C sits ON the fold of pitch space (x = ±0.75 at the octave seam): whether its
            // fraction is 0 or 0.999… is the last ulp of `log2`, which differs between math
            // libraries — so its column is not pinned here (a recorded limit, not a pass).
            if pitchClass != 0 {
                XCTAssertEqual(pLow.x, pMid.x, accuracy: 1e-9, "same pitch class, same column in pitch space")
                XCTAssertEqual(pHigh.x, pMid.x, accuracy: 1e-9)
            }
            XCTAssertLessThan(pLow.y, pMid.y, "the lower octave sits lower")
            XCTAssertLessThan(pMid.y, pHigh.y, "the higher octave sits higher")
        }
        // On the grid: the same scale degree, one band apart.
        let key = MusicalKey(root: 0, scale: .major)
        let g4 = try XCTUnwrap(TouchPitchMap.fieldPosition(forPitch: 67, key: key))
        let g5 = try XCTUnwrap(TouchPitchMap.fieldPosition(forPitch: 79, key: key))
        XCTAssertEqual(g4.x, g5.x, accuracy: 1e-9, "G4 and G5 share their grid column")
        XCTAssertLessThan(g4.y, g5.y, "and G5 sits in the band above")
    }

    // MARK: 2 — KAMMERTON

    func testAConcertPitchChangeMovesTheColourAndKeepsTheCell() throws {
        let key = MusicalKey(root: 9, scale: .minor)      // A minor: A is the root column
        var colours: [LinearRGB] = []
        var cell: (x: Double, y: Double)?
        for a4 in [432.0, 440.0, 444.0] {
            let hz = try publishedHz(pitch: 69, a4: a4)
            XCTAssertEqual(hz, a4, accuracy: 1e-9, "the written A4 sounds at the concert pitch itself")
            colours.append(SpectralColor.toneLinearRGB(forToneHz: hz))
            let here = try XCTUnwrap(TouchPitchMap.fieldPosition(forHz: hz, a4Hz: a4, key: key))
            if let cell {
                XCTAssertEqual(here.x, cell.x, accuracy: 1e-9, "A stays in A's column at A4 = \(a4)")
                XCTAssertEqual(here.y, cell.y, accuracy: 1e-9)
            }
            cell = here
        }
        XCTAssertGreaterThan(distance(colours[0], colours[1]), 1e-3, "432 and 440 are different light")
        XCTAssertGreaterThan(distance(colours[1], colours[2]), 1e-3, "440 and 444 are different light")
        // Deterministic: the same input gives the same colour, bit for bit.
        XCTAssertEqual(SpectralColor.toneLinearRGB(forToneHz: 440), SpectralColor.toneLinearRGB(forToneHz: 440))
    }

    // MARK: 3 — KEY

    func testAKeyChangeMovesTheColumnAndLeavesTheColour() throws {
        let cMajor = MusicalKey(root: 0, scale: .major)
        let dMajor = MusicalKey(root: 2, scale: .major)
        let e4 = 64
        let inC = try XCTUnwrap(TouchPitchMap.fieldPosition(forPitch: e4, key: cMajor))
        let inD = try XCTUnwrap(TouchPitchMap.fieldPosition(forPitch: e4, key: dMajor))
        let columnC = try XCTUnwrap(cMajor.pitchClasses.firstIndex(of: 4))
        let columnD = try XCTUnwrap(dMajor.pitchClasses.firstIndex(of: 4))
        XCTAssertNotEqual(columnC, columnD, "E is a different scale degree in C and in D")
        XCTAssertNotEqual(inC.x, inD.x, "so its cloud moves to that degree's column")
        XCTAssertEqual(inC.y, inD.y, accuracy: 1e-9, "the octave band does not depend on the key")

        let hz = try publishedHz(pitch: e4, a4: 440)
        let colourC = SpectralColor.toneLinearRGB(forToneHz: hz)
        let colourD = SpectralColor.toneLinearRGB(forToneHz: hz)
        XCTAssertEqual(colourC, colourD, "the same sounding frequency is the same light in any key")

        // F is not in D major: no cell, and the caller falls back to pitch space.
        XCTAssertNil(TouchPitchMap.fieldPosition(forPitch: 65, key: dMajor))
        let fallback = SpectralColor.notePosition(forHz: try publishedHz(pitch: 65, a4: 440))
        XCTAssertTrue(fallback.x.isFinite && fallback.y.isFinite)
    }

    // MARK: 4 — NEUTRAL

    func testSilenceAndBadInputLandOnTheOneNeutralWhichHasNoHue() {
        let neutral = SpectralColor.neutral
        for bad in [0.0, -440.0, Double.nan, Double.infinity] {
            XCTAssertEqual(SpectralColor.toneLinearRGB(forToneHz: bad), neutral, "\(bad) Hz is no tone")
        }
        XCTAssertEqual(SpectralColor.physicalColor(forChord: []), neutral, "no note, no colour")
        XCTAssertEqual(neutral.r, neutral.g, accuracy: 1e-9, "the neutral carries no hue")
        XCTAssertEqual(neutral.g, neutral.b, accuracy: 1e-9)

        let silent = PianoRollModel.musicalFrame(forActive: [], a4Hz: 440, rootPitchClass: 0,
                                                 scaleName: "major", tempoBPM: 120, beatPhase: 0)
        XCTAssertTrue(silent.notes.isEmpty)
        XCTAssertEqual(silent.masterLevel, 0)
        XCTAssertFalse(silent.isSounding, "an empty frame is silence, not a dark colour")
    }

    // MARK: 5 — SEPARATION (colour · level · place)

    func testLevelNeverMovesTheColourAndPlaceAloneSeparatesTheTwelve() throws {
        let hz = try publishedHz(pitch: 67, a4: 440)
        let quiet = SpectralColor.physicalColor(forChord: [(hz: hz, amplitude: 0.1)])
        let loud = SpectralColor.physicalColor(forChord: [(hz: hz, amplitude: 0.9)])
        XCTAssertLessThan(distance(quiet, loud), 1e-9, "the chord colour is a hue, never a level")

        func frame(_ velocity: Float) -> MusicalFrame {
            PianoRollModel.musicalFrame(forActive: [Note(pitch: 67, startStep: 0, velocity: velocity)],
                                        a4Hz: 440, rootPitchClass: 0, scaleName: "major",
                                        tempoBPM: 120, beatPhase: 0)
        }
        XCTAssertLessThan(frame(0.2).masterLevel, frame(0.8).masterLevel, "the level lives in the frame's level")
        XCTAssertEqual(frame(0.2).notes.first?.frequencyHz, frame(0.8).notes.first?.frequencyHz)

        // Greyscale carrier: with the colour removed, position still names the pitch classes
        // (C♯…B strictly left to right; C is the fold itself, see claim 1).
        var previous = -Double.infinity
        for pitchClass in 1..<12 {
            let x = SpectralColor.notePosition(forHz: try publishedHz(pitch: 60 + pitchClass, a4: 440)).x
            XCTAssertGreaterThan(x, previous, "pitch class \(pitchClass) has its own place")
            previous = x
        }
    }
}

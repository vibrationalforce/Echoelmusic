// TheNoteGridSpeaksTheReadersNoteNamesTests.swift
// Echoel — modes census 2026-09-26, design slice 3: the note grid names its rows and a picked
// note in the reader's own note names.
//
// WHAT THIS PINS. The grid printed `"C\(octave)"` in English on its C rows whatever note-name
// system the reader had chosen, so a solfège or sargam reader saw "C4" beside a key named
// "Do major" / "Sa". And one picked note was only a highlighted block: its name, where it starts
// and how long it is had no words on screen.
//
// 1. END-TO-END BEHAVIOUR (`ClipNoteEdit.rowName` / `pickedNoteLine`, pure): the row name comes
//    from `NoteNaming` (middle C = octave 4); the picked-note line says name · bar, beat · length
//    in sixteenths, and its spoken form expands ♯/♭ the way `NoteNaming.spokenName` does.
// 2. SOURCE: the canvas draws the C rows through `rowName` with the reader's naming, and the grid
//    shows the line only for exactly ONE picked note, with the spoken form as its VoiceOver label.
//
// Grading (§0, no Swift toolchain): `rowName` and `pickedNoteLine` do not exist on the parent
// (`705f771fd`), so this file does not compile there — every claim is a FORWARD guard, one
// absence (#486). Claim 1 transcribed into Python and driven on the cases below; claim 2
// transcribed against this tree: green.
// NOT covered: legibility of 9 pt row names on glass — a device look.
// NEEDS-FOUNDER-VERIFY: Settings → note names → Solfège; Workstation → a MIDI part → Notes: the C
// rows read "Do3", "Do4"…; tap one note: a line reads e.g. "Mi4 · bar 1, beat 2 · 2 sixteenths".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteGridSpeaksTheReadersNoteNamesTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — the words, pure

    func testRowsAreNamedInTheReadersSystem() {
        XCTAssertEqual(ClipNoteEdit.rowName(pitch: 60, naming: .english, preferFlats: false), "C4",
                       "middle C stays C4 — the octave convention the grid always used")
        XCTAssertEqual(ClipNoteEdit.rowName(pitch: 60, naming: .solfege, preferFlats: false), "Do4")
        XCTAssertEqual(ClipNoteEdit.rowName(pitch: 48, naming: .sargam, preferFlats: false), "Sa3")
        XCTAssertEqual(ClipNoteEdit.rowName(pitch: 71, naming: .german, preferFlats: false), "H4",
                       "the German B natural is H")
        XCTAssertEqual(ClipNoteEdit.rowName(pitch: 0, naming: .english, preferFlats: false), "C-1",
                       "MIDI 0 is C-1, the bottom of the range")
    }

    func testOnePickedNoteIsSaidInWords() {
        let note = Note(pitch: 64, startTick: TimelineTime.ticksPerBar + TimelineTime.ticksPerBeat,   // bar 2, beat 2
                        lengthTicks: 2 * Note.ticksPerStep)
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(note, naming: .english, preferFlats: false, spoken: false),
                       "E4 · bar 2, beat 2 · 2 sixteenths")
        let sharp = Note(pitch: 61, startTick: 0, lengthTicks: Note.ticksPerStep)
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(sharp, naming: .english, preferFlats: false, spoken: false),
                       "C♯4 · bar 1, beat 1 · 1 sixteenth")
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(sharp, naming: .english, preferFlats: false, spoken: true),
                       "C sharp 4 · bar 1, beat 1 · 1 sixteenth",
                       "VoiceOver hears the accidental as a word, not as a mark it cannot say")
        XCTAssertTrue(ClipNoteEdit.pickedNoteLine(sharp, naming: .english, preferFlats: true, spoken: false)
                        .hasPrefix("D♭4"), "a flat key spells the same pitch as a flat")
    }

    // MARK: 2 — the grid uses them

    func testTheGridDrawsAndSaysThem() throws {
        let code = try source(Self.editor)
        XCTAssertTrue(code.contains("ClipNoteEdit.rowName(pitch: pitch, naming: naming, preferFlats: false)"),
                      "the C rows are named through the reader's naming")
        XCTAssertFalse(code.contains("Text(\"C\\(pitch / 12 - 1)\")"),
                       "the hard-coded English row label is back")
        XCTAssertTrue(code.contains("PartNoteCanvas(visible: visible, steps: steps, grid: grid, naming: naming,"),
                      "the canvas is handed the naming the grid already holds")
        guard let gate = code.range(of: "if selected.count == 1, let one = visible.first(where: { selected.contains($0.id) }) {"),
              let shown = code.range(of: "spoken: false))", range: gate.upperBound..<code.endIndex),
              let said = code.range(of: ".accessibilityLabel(ClipNoteEdit.pickedNoteLine(one, naming: naming,",
                                    range: gate.upperBound..<code.endIndex) else {
            return XCTFail("the grid no longer says ONE picked note in words, with a spoken VoiceOver form")
        }
        XCTAssertLessThan(shown.lowerBound, said.lowerBound)
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.pickedNoteLine(").count - 1, 2,
                       "one shown line and its spoken twin — nothing else describes a picked note")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

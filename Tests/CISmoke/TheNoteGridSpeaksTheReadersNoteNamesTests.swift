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
//    in sixteenths, and its spoken form expands ♯/♭ the way `NoteNaming.spokenName` does. The
//    bar is the SONG's — the part's start plus the note's — and agrees with
//    `WorkstationSummary.barNumber`, the rule the heading above it uses (review of 292a932af, MED:
//    the first version counted from the part, so "bar 1" sat under "Selected part · Bar 9").
// 2. SOURCE: the canvas draws the C rows through `rowName` with the reader's naming, and the grid
//    shows the line only for exactly ONE picked note ON SCREEN, fed the part's start, the
//    reader's naming and the key's spelling, with the spoken form as its VoiceOver label.
//
// Grading (§0, no Swift toolchain). Against `292a932af` (where `pickedNoteLine` first appeared)
// the function takes no `partStartTick`, so this file does not compile there — no assertion has
// a verdict; the song-bar case, the barNumber agreement and the argument pins are FORWARD guards
// of the review repair, one absence (#486). `rowName` and the row-label pins are COUNTERWEIGHTS,
// green on both. Claim 1 transcribed into Python and driven on the cases below; claim 2
// transcribed against this tree with mutants (English naming hard-coded, flats hard-coded, the
// part start dropped, the gate back on the whole selection): each red.
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
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(note, partStartTick: 0, naming: .english,
                                                   preferFlats: false, spoken: false),
                       "E4 · bar 2, beat 2 · 2 sixteenths")
        let sharp = Note(pitch: 61, startTick: 0, lengthTicks: Note.ticksPerStep)
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(sharp, partStartTick: 0, naming: .english,
                                                   preferFlats: false, spoken: false),
                       "C♯4 · bar 1, beat 1 · 1 sixteenth")
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(sharp, partStartTick: 0, naming: .english,
                                                   preferFlats: false, spoken: true),
                       "C sharp 4 · bar 1, beat 1 · 1 sixteenth",
                       "VoiceOver hears the accidental as a word, not as a mark it cannot say")
        XCTAssertTrue(ClipNoteEdit.pickedNoteLine(sharp, partStartTick: 0, naming: .english,
                                                  preferFlats: true, spoken: false)
                        .hasPrefix("D♭4"), "a flat key spells the same pitch as a flat")
    }

    func testThePickedNoteIsCountedInTheSongsBars() {
        let bar = TimelineTime.ticksPerBar
        let beat = TimelineTime.ticksPerBeat
        let note = Note(pitch: 64, startTick: bar + beat, lengthTicks: 2 * Note.ticksPerStep)
        XCTAssertEqual(ClipNoteEdit.pickedNoteLine(note, partStartTick: 8 * bar, naming: .english,
                                                   preferFlats: false, spoken: false),
                       "E4 · bar 10, beat 2 · 2 sixteenths",
                       "a part at bar 9: its second bar is the song's bar 10, as the heading counts")
        let first = Note(pitch: 60, startTick: 0, lengthTicks: Note.ticksPerStep)
        XCTAssertTrue(ClipNoteEdit.pickedNoteLine(first, partStartTick: 8 * bar + beat, naming: .english,
                                                  preferFlats: false, spoken: false)
                        .contains("bar 9, beat 2"),
                      "an off-grid part: its first note sits on the song's beat 2, not beat 1")
        let starts: [Int] = [0, 1, beat - 1, bar - 1, bar, 3 * bar + 2 * beat, 17 * bar + 5]
        for start in starts {
            let line = ClipNoteEdit.pickedNoteLine(first, partStartTick: start, naming: .english,
                                                   preferFlats: false, spoken: false)
            XCTAssertTrue(line.contains("bar \(WorkstationSummary.barNumber(forTick: start)),"),
                          "tick \(start): the line's bar is the heading's bar rule — got \(line)")
        }
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
        guard let gate = code.range(of: "if pickedCount == 1, let one = visible.first(where: { pickedOnScreen.contains($0.id) }) {"),
              let flats = code.range(of: "let flats = session.key.prefersFlatSpelling", range: gate.upperBound..<code.endIndex),
              let shown = sequence(["Text(ClipNoteEdit.pickedNoteLine(one, partStartTick: region.startTick, naming: naming,",
                                    "preferFlats: flats, spoken: false))"], in: code, from: flats.upperBound),
              let said = sequence([".accessibilityLabel(ClipNoteEdit.pickedNoteLine(one, partStartTick: region.startTick,",
                                   "naming: naming, preferFlats: flats,", "spoken: true))"],
                                  in: code, from: flats.upperBound) else {
            return XCTFail("""
                the grid no longer says ONE picked note ON SCREEN in words, in the song's bars \
                (the part's start), the reader's naming and the key's spelling, with a spoken \
                VoiceOver form
                """)
        }
        XCTAssertLessThan(shown.lowerBound, said.lowerBound)
        XCTAssertEqual(code.components(separatedBy: "ClipNoteEdit.pickedNoteLine(").count - 1, 2,
                       "one shown line and its spoken twin — nothing else describes a picked note")
    }

    // MARK: helpers

    /// Where `tokens` occur in order from `start`, with nothing but whitespace between them, or nil.
    private func sequence(_ tokens: [String], in text: String, from start: String.Index) -> Range<String.Index>? {
        var from = start
        while let first = text.range(of: tokens[0], range: from..<text.endIndex) {
            var end = first.upperBound
            var matched = true
            for token in tokens.dropFirst() {
                guard let next = text.range(of: token, range: end..<text.endIndex),
                      text[end..<next.lowerBound].allSatisfy(\.isWhitespace) else { matched = false; break }
                end = next.upperBound
            }
            if matched { return first.lowerBound..<end }
            from = first.upperBound
        }
        return nil
    }

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

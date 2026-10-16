// AShortenedPartSaysWhatItHidesTests.swift
// Echoel — A1 (ultra master plan slice 5, 2026-10-16). A MIDI part shortened by its Length field
// or an edge keeps the notes past its new end in the clip, unheard — by design (Undo and a longer
// length bring them back). Until now only the Length field's VoiceOver HINT said so; a sighted
// person saw notes vanish. The part bar now prints how many lie past the end.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`PartLength.notesPastTheEnd`, pure): counts exactly the notes the
//      player's window drops at the END — a note starting at the end counts, one starting just
//      inside does not, and a trimmed-in start is not counted (that is Trim start's cut, not a
//      hidden note). Counterweight: the count equals the clip's notes minus `windowed` minus the
//      notes before the offset — the player's own rule, asked.
//   2. The sentence names the number, and the one-note form is singular.
//   3. SOURCE-TEXT SCAN: the line is its own leaf under the MIDI Length field.
//
// ⚠️ HONEST GRADING (#433): claims 1–3 drive symbols this commit creates — FORWARD guards, one
// absence on the parent (#486). Transcribed by reading against `RegionNoteWindow.windowed`.
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: shorten a MIDI part over its last note — the
// line appears; lengthen it — the line goes).

import Foundation
import XCTest
@testable import Echoelmusic

final class AShortenedPartSaysWhatItHidesTests: XCTestCase {

    private let bar = TimelineTime.ticksPerBar
    private let q = Note.ticksPerQuarter

    func testItCountsTheNotesTheWindowDropsAtTheEnd() {
        let clip = Clip(name: "C", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 40, startTick: 0, lengthTicks: q),                  // before a trimmed-in start
            Note(pitch: 43, startTick: bar + q, lengthTicks: q),            // inside
            Note(pitch: 44, startTick: 2 * bar - 120, lengthTicks: q),      // last step inside
            Note(pitch: 45, startTick: 2 * bar, lengthTicks: q),            // exactly at the end
            Note(pitch: 47, startTick: 3 * bar, lengthTicks: q),            // past it
        ]))
        let lane = UUID()
        let trimmed = TimelineRegion(laneID: lane, clipID: clip.id, startTick: 0, lengthTicks: bar,
                                     contentOffsetTicks: bar)
        XCTAssertEqual(PartLength.notesPastTheEnd(of: trimmed, clip: clip, bpm: 120), 2,
                       "the note at the end and the one past it — not the trimmed-in first note")
        let whole = TimelineRegion(laneID: lane, clipID: clip.id, startTick: 0, lengthTicks: 4 * bar)
        XCTAssertEqual(PartLength.notesPastTheEnd(of: whole, clip: clip, bpm: 120), 0, "every note plays")

        // Counterweight: the player's window is the rule being reported.
        let offset = RegionNoteWindow.effectiveOffsetTicks(of: trimmed, bpm: 120)
        let notes = clip.melody?.notes ?? []
        let heard = RegionNoteWindow.windowed(notes: notes, offsetTicks: offset, lengthTicks: trimmed.lengthTicks).count
        let before = notes.filter { $0.startTick < offset }.count
        XCTAssertEqual(notes.count - heard - before, 2)
    }

    func testTheSentenceNamesTheNumber() {
        XCTAssertTrue(PartLength.pastTheEndText(1).hasPrefix("1 note lies"))
        XCTAssertTrue(PartLength.pastTheEndText(3).hasPrefix("3 notes lie"))
    }

    func testTheLineIsALeafUnderTheMIDILength() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let path = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
        guard let text = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) else {
            return XCTFail("ANCHOR MISSING: cannot read \(path) (#454)")
        }
        let code = SourceText.codeOnly(text)
        guard let field = code.range(of: "PartLengthField(part: part, songBars:"),
              let line = code.range(of: "PartHiddenNotesLine(regionID: regionID)") else {
            return XCTFail("ANCHOR MISSING: the Length field or the hidden-notes line")
        }
        XCTAssertLessThan(field.lowerBound, line.lowerBound, "the line sits under the Length field")
        XCTAssertTrue(code.contains("private struct PartHiddenNotesLine: View"))
    }
}

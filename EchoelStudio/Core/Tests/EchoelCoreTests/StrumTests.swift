import Foundation
import XCTest
@testable import EchoelCore

/// Strum spreads the starts of the musician's chords and keeps everything else: pitches,
/// velocities, ids and where each note ends.
final class StrumTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func clip(_ chords: [[Int]]) -> Clip {
        var notes: [Note] = []
        for (index, chord) in chords.enumerated() {
            for pitch in chord { notes.append(Note(pitch: pitch, start: Tick(index) * bar, length: bar)) }
        }
        return Clip(name: "C", length: Tick(chords.count) * bar, notes: notes)
    }

    private func apply(_ result: Strum.Result, to clip: Clip) -> Clip {
        guard case .updateNotes(_, let changed)? = result.command else { return clip }
        var out = clip
        for note in changed {
            if let index = out.notes.firstIndex(where: { $0.id == note.id }) { out.notes[index] = note }
        }
        return out
    }

    private func starts(_ clip: Clip) -> [Int: Tick] {
        Dictionary(uniqueKeysWithValues: clip.notes.map { ($0.pitch, $0.start) })
    }

    func testDownPlaysTheLowestNoteFirstAndEveryNoteEndsWhereItEnded() {
        let written = clip([[48, 64, 67]])
        let after = apply(Strum.strummed(written, direction: .down, span: 60), to: written)
        XCTAssertEqual(starts(after), [48: 0, 64: 30, 67: 60])
        for note in after.notes { XCTAssertEqual(note.start + note.length, bar) }
    }

    func testUpPlaysTheHighestNoteFirst() {
        let written = clip([[48, 64, 67, 72]])
        let after = apply(Strum.strummed(written, direction: .up, span: 90), to: written)
        XCTAssertEqual(starts(after), [72: 0, 67: 30, 64: 60, 48: 90])
    }

    func testOnlyStartsAndLengthsChange() {
        let written = clip([[48, 64, 67], [53, 69, 72]])
        let after = apply(Strum.strummed(written, direction: .down, span: 120), to: written)
        XCTAssertEqual(Set(after.notes.map(\.id)), Set(written.notes.map(\.id)))
        for (before, now) in zip(written.notes, after.notes) {
            XCTAssertEqual(now.pitch, before.pitch)
            XCTAssertEqual(now.velocity, before.velocity)
            XCTAssertEqual(now.start + now.length, before.start + before.length)
        }
    }

    func testAStrummedChordStaysOneChordAndStrumsAgainFromItsAnchor() {
        let written = clip([[48, 64, 67]])
        let down = apply(Strum.strummed(written, direction: .down, span: Strum.maximumSpan), to: written)
        XCTAssertEqual(Revoice.chords(in: down).count, 1)
        XCTAssertNil(Strum.strummed(down, direction: .down, span: Strum.maximumSpan).command, "the same strum twice moves nothing")
        let up = apply(Strum.strummed(down, direction: .up, span: 60), to: down)
        XCTAssertEqual(starts(up), [67: 0, 64: 30, 48: 60])
        let together = apply(Strum.strummed(up, direction: .down, span: 0), to: up)
        XCTAssertEqual(together.notes, written.notes, "a span of 0 puts the chord back as written")
    }

    func testASpanIsBoundedBothWays() {
        let written = clip([[48, 64, 67]])
        let wide = apply(Strum.strummed(written, direction: .down, span: 100_000), to: written)
        XCTAssertEqual(starts(wide)[67], Strum.maximumSpan)
        XCTAssertNil(Strum.strummed(written, direction: .down, span: -50).command)
    }

    func testAChosenNoteStrumsOnlyItsChord() {
        let written = clip([[48, 64, 67], [53, 69, 72]])
        let chosen = written.notes.first { $0.pitch == 69 }.map { Set([$0.id]) } ?? []
        let result = Strum.strummed(written, chosen: chosen, direction: .down, span: 60)
        XCTAssertEqual(result.chordCount, 1)
        let after = apply(result, to: written)
        XCTAssertEqual(starts(after)[67], 0, "the first chord is not touched")
        XCTAssertEqual(starts(after)[72], bar + 60)
    }

    func testSingleNotesAndPairsAreNoChord() {
        let pair = clip([[48, 60]])
        let result = Strum.strummed(pair, direction: .down, span: 60)
        XCTAssertNil(result.command)
        XCTAssertEqual(result.chordCount, 0)
        XCTAssertEqual(Strum.message(result, direction: .down, span: 60), "Strum needs a chord of 3 or more notes together.")
    }

    func testAStartNeverLeavesTheClipAndALengthStaysAtLeastOneTick() {
        let short = Clip(name: "S", length: 40, notes: [Note(pitch: 48, start: 0, length: 40),
                                                        Note(pitch: 52, start: 0, length: 40),
                                                        Note(pitch: 55, start: 0, length: 40)])
        let after = apply(Strum.strummed(short, direction: .down, span: Strum.maximumSpan), to: short)
        for note in after.notes {
            XCTAssertLessThan(note.start, short.length)
            XCTAssertGreaterThanOrEqual(note.length, 1)
        }
        guard case .updateNotes(_, let changed)? = Strum.strummed(short, direction: .down, span: 120).command else {
            return XCTFail("the short chord spreads")
        }
        for note in changed {
            XCTAssertNoThrow(try Command.validate(note, in: short), "the door accepts what Strum makes")
        }
    }

    func testTheMessageSaysWhatHappened() {
        let written = clip([[48, 64, 67], [53, 69, 72]])
        let result = Strum.strummed(written, direction: .up, span: 60)
        XCTAssertEqual(Strum.message(result, direction: .up, span: 60), "2 chords strummed up, highest note first.")
        let back = Strum.strummed(written, direction: .down, span: 0)
        XCTAssertEqual(Strum.message(back, direction: .down, span: 0), "2 chords already together.")
    }
}

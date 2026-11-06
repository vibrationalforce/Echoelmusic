import Foundation
import XCTest
@testable import EchoelCore

/// Revoice moves only the upper notes of the musician's chords, by whole octaves, and finds the
/// least total movement among those placements — checked here against a brute force over every
/// combination, not against its own ranking.
final class RevoiceTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func clip(_ chords: [[Int]], spacing: Tick? = nil) -> Clip {
        let step = spacing ?? bar
        var notes: [Note] = []
        for (index, chord) in chords.enumerated() {
            for pitch in chord { notes.append(Note(pitch: pitch, start: Tick(index) * step, length: step)) }
        }
        return Clip(name: "C", length: Tick(chords.count) * step, notes: notes)
    }

    private func apply(_ result: Revoice.Result, to clip: Clip) -> Clip {
        guard case .updateNotes(_, let changed)? = result.command else { return clip }
        var out = clip
        for note in changed {
            if let index = out.notes.firstIndex(where: { $0.id == note.id }) { out.notes[index] = note }
        }
        return out
    }

    /// C (48 64 67) then F written high (53 69 72): the F's upper notes come down an octave to
    /// 60 and 69 … the least movement is 11 semitones against 15 as written.
    func testAKnownProgressionMovesLess() {
        let written = clip([[48, 64, 67], [53, 69, 72]])
        let result = Revoice.revoiced(written)
        XCTAssertEqual(result.writtenMovement, 15)
        XCTAssertEqual(result.revoicedMovement, 11)
        let after = apply(result, to: written)
        XCTAssertEqual(Revoice.chords(in: after)[1].map(\.pitch).sorted(), [53, 60, 69])
    }

    func testEveryNoteKeepsWhatTheMusicianWroteButItsOctave() {
        let written = clip([[48, 64, 67], [41, 69, 72, 76], [43, 71, 74], [48, 76, 79]])
        let after = apply(Revoice.revoiced(written), to: written)
        XCTAssertEqual(after.notes.count, written.notes.count)
        XCTAssertEqual(Set(after.notes.map(\.id)), Set(written.notes.map(\.id)))
        for (before, now) in zip(written.notes, after.notes) {
            XCTAssertEqual(before.id, now.id)
            XCTAssertEqual(((now.pitch % 12) + 12) % 12, ((before.pitch % 12) + 12) % 12, "the pitch class stays")
            XCTAssertEqual(Swift.abs(now.pitch - before.pitch) % 12, 0, "only whole octaves")
            XCTAssertEqual(now.start, before.start)
            XCTAssertEqual(now.length, before.length)
            XCTAssertEqual(now.velocity, before.velocity)
            XCTAssertTrue(Note.pitchRange.contains(now.pitch))
        }
        let chordsBefore = Revoice.chords(in: written), chordsAfter = Revoice.chords(in: after)
        XCTAssertEqual(chordsAfter[0].map(\.pitch), chordsBefore[0].map(\.pitch), "the first chord stays")
        for (b, a) in zip(chordsBefore, chordsAfter) {
            XCTAssertEqual(a.map(\.pitch).min(), b.map(\.pitch).min(), "every bass stays")
        }
    }

    /// The search is exhaustive within its placements: on small progressions its total equals a
    /// brute force over every combination of every chord's placements, and is never above the
    /// written total.
    func testTheTotalIsTheBruteForceMinimum() {
        let progressions: [[[Int]]] = [
            [[48, 64, 67], [53, 69, 72], [55, 59, 74]],
            [[45, 60, 64], [50, 65, 69, 74], [43, 59, 62], [48, 55, 76]],
            [[36, 52, 55, 59], [41, 57, 72], [43, 47, 62, 65]],
            [[38, 47, 59], [38, 46, 59], [43, 57, 64]],
            [[48, 60, 60], [48, 48, 60], [53, 57, 72]],
        ]
        for chords in progressions {
            let written = clip(chords)
            let result = Revoice.revoiced(written)
            var options: [[[Int]]] = []
            for (index, chord) in Revoice.chords(in: written).enumerated() {
                options.append(index == 0 ? [chord.map(\.pitch)] : Revoice.placements(of: chord))
            }
            var best = Int.max
            func walk(_ k: Int, _ previous: [Int], _ total: Int) {
                if k == options.count {
                    best = Swift.min(best, total)
                    return
                }
                for candidate in options[k] { walk(k + 1, candidate, total + Revoice.movement(previous, candidate)) }
            }
            walk(1, options[0][0], 0)
            XCTAssertEqual(result.revoicedMovement, best, "\(chords)")
            XCTAssertLessThanOrEqual(result.revoicedMovement, result.writtenMovement)
            XCTAssertEqual(Revoice.revoiced(written), result, "the same clip gives the same result")
        }
    }

    /// Equal totals: the path that moves the fewest notes wins.
    func testAmongEqualTotalsTheFewestNotesMove() {
        let written = clip([[38, 47, 59], [38, 46, 59], [43, 57, 64]])
        let result = Revoice.revoiced(written)
        XCTAssertEqual(result.writtenMovement, 22)
        XCTAssertEqual(result.revoicedMovement, 12)
        guard case .updateNotes(_, let changed)? = result.command else { return XCTFail("something moves") }
        XCTAssertEqual(changed.count, 1, "one note an octave down reaches the least total")
        XCTAssertEqual(changed.first?.pitch, 45)
    }

    /// Two paths reach the same placement of the second chord at the same total, one moving a
    /// note fewer: the search keeps that one there, not only at the end.
    func testATieOnTheWayKeepsThePathThatMovesFewer() {
        let written = clip([[51, 58, 68], [42, 50, 51, 69], [42, 44, 54, 67]])
        let result = Revoice.revoiced(written)
        XCTAssertEqual(result.revoicedMovement, 16)
        guard case .updateNotes(_, let changed)? = result.command else { return XCTFail("something moves") }
        XCTAssertEqual(changed.count, 2, "50 up an octave and 44 up: two notes, where the other path of 16 moves three")
    }

    /// Notes of two chords that both may move and sound together never land on one pitch: the top
    /// of the second chord is held into the third, and both could come to 60.
    func testTwoMovedNotesThatSoundTogetherNeverShareAPitch() {
        var notes: [Note] = []
        for pitch in [47, 50, 71] { notes.append(Note(pitch: pitch, start: 0, length: bar)) }
        for pitch in [46, 70] { notes.append(Note(pitch: pitch, start: bar, length: bar)) }
        notes.append(Note(pitch: 72, start: bar, length: 2 * bar))
        for pitch in [40, 48, 55] { notes.append(Note(pitch: pitch, start: 2 * bar, length: bar)) }
        let written = Clip(name: "C", length: 3 * bar, notes: notes)
        let result = Revoice.revoiced(written)
        XCTAssertEqual(result.revoicedMovement, 23, "the held 72 stays and 48 comes to 60; 21 would put 72 on 60 too")
        let after = apply(result, to: written).notes
        for (index, a) in after.enumerated() {
            for b in after[(index + 1)...] where a.pitch == b.pitch {
                XCTAssertFalse(a.start < b.start + b.length && b.start < a.start + a.length, "\(a.pitch) twice at once")
            }
        }
    }

    /// A grace note just before a chord, ended before the chord sounds, is no part of it: the
    /// chord's own lowest note stays its bass and does not move.
    func testAGraceNoteBeforeAChordIsNotItsBass() {
        var written = clip([[48, 64, 67], [53, 69, 72]])
        written.notes.append(Note(pitch: 40, start: bar - 100, length: 60))
        let after = apply(Revoice.revoiced(written), to: written)
        XCTAssertEqual(Revoice.chords(in: after)[1].map(\.pitch).sorted(), [53, 60, 69], "the F stays the bass")
        XCTAssertTrue(after.notes.contains { $0.pitch == 40 && $0.start == bar - 100 }, "the grace note as written")
    }

    /// A grace note does not start the window of the chord after it, and the notes of a short,
    /// humanized chord that sound one with another stay one chord.
    func testAGraceNoteNeitherAnchorsNorSplitsTheChordAfterIt() {
        var notes = [48, 64, 67].map { Note(pitch: $0, start: 0, length: bar) }
        notes.append(Note(pitch: 40, start: bar - 100, length: 60))
        notes += [Note(pitch: 53, start: bar - 20, length: bar), Note(pitch: 69, start: bar + 10, length: bar),
                  Note(pitch: 72, start: bar + 40, length: bar)]
        let graced = Clip(name: "C", length: 3 * bar, notes: notes)
        XCTAssertEqual(Revoice.chords(in: graced).map { $0.map(\.pitch) }, [[48, 64, 67], [53, 69, 72]])
        let short = Clip(name: "C", length: 2 * bar, notes: [48, 64, 67].map { Note(pitch: $0, start: 0, length: 60) }
            + [Note(pitch: 53, start: bar - 30, length: 60), Note(pitch: 69, start: bar, length: 60),
               Note(pitch: 72, start: bar + 30, length: 60)])
        XCTAssertEqual(Revoice.chords(in: short).map { $0.map(\.pitch) }, [[48, 64, 67], [53, 69, 72]])
    }

    /// What the command writes is what the search reports: the chords after it travel exactly
    /// the reported total.
    func testTheWrittenNotesTravelTheReportedTotal() {
        for chords in [[[48, 64, 67], [41, 69, 72, 76], [43, 71, 74], [48, 76, 79]],
                       [[45, 60, 64], [50, 65, 69, 74], [43, 59, 62], [48, 55, 76]]] {
            let written = clip(chords)
            let result = Revoice.revoiced(written)
            let after = Revoice.chords(in: apply(result, to: written)).map { $0.map(\.pitch) }
            var total = 0
            for k in 1..<after.count { total += Revoice.movement(after[k - 1], after[k]) }
            XCTAssertEqual(total, result.revoicedMovement, "\(chords)")
        }
    }

    func testNothingToMoveIsNoCommand() {
        XCTAssertNil(Revoice.revoiced(clip([])).command)
        XCTAssertNil(Revoice.revoiced(clip([[48, 64, 67]])).command, "one chord")
        XCTAssertNil(Revoice.revoiced(clip([[60], [64], [67]])).command, "single notes are no chords")
        XCTAssertNil(Revoice.revoiced(clip([[36, 64], [41, 72], [36, 76]])).command, "a bass under a melody is no chord")
        XCTAssertNil(Revoice.revoiced(clip([[48, 64, 67], [48, 64, 67]])).command, "already the least")
        XCTAssertTrue(Revoice.message(Revoice.revoiced(clip([[48, 64, 67]]))).hasPrefix("Revoice needs two chords"))
        XCTAssertTrue(Revoice.message(Revoice.revoiced(clip([[48, 64, 67], [48, 64, 67]]))).hasPrefix("No octave move"))
        XCTAssertTrue(Revoice.message(Revoice.revoiced(clip([[48, 64, 67], [53, 69, 72]])))
                        .contains("11 semitones instead of 15"))
    }

    /// An upper note never falls to or below its bass, never lands on a pitch its chord holds
    /// (a written unison stays, none is made), and a doubled bass stays.
    func testTheBassStaysBelowAndNoUnisonIsMade() {
        // 57 an octave down (45) would fall below the bass 53: it is not allowed.
        let below = clip([[60, 64, 67], [53, 57, 72]])
        for chord in Revoice.chords(in: apply(Revoice.revoiced(below), to: below)) {
            let pitches = chord.map(\.pitch)
            XCTAssertTrue(pitches.dropFirst().allSatisfy { $0 > (pitches.first ?? 0) }, "\(pitches)")
        }
        // A doubled bass (48, 48) and a written duplicate: no note moves onto a held pitch.
        let doubled = clip([[48, 60, 60], [48, 48, 60]])
        XCTAssertNil(Revoice.revoiced(doubled).command, "the second 48 is bass, 60 cannot go to 48 or onto itself")
        // 44 up to 56 would save the most (14 against 22) and double the chord's 56: not allowed.
        let unison = clip([[48, 54, 59, 73], [42, 44, 56, 64]])
        let voiced = Revoice.revoiced(unison)
        XCTAssertEqual(voiced.revoicedMovement, 22)
        let second = Revoice.chords(in: apply(voiced, to: unison))[1].map(\.pitch)
        XCTAssertEqual(Set(second).count, second.count, "no two notes of the chord on one pitch: \(second)")
        let high = clip([[100, 124, 127], [101, 125, 116]])
        XCTAssertTrue(apply(Revoice.revoiced(high), to: high).notes.allSatisfy { Note.pitchRange.contains($0.pitch) })
    }

    /// A note outside the chords that sounds at the same time keeps its pitch to itself: an upper
    /// note does not move onto it (playback would cut one of the two).
    func testANoteOutsideTheChordIsNotLandedOn() {
        var written = clip([[48, 64, 67], [53, 60, 81]])
        // Without the melody, 81 would come down to 69.
        let free = apply(Revoice.revoiced(written), to: written)
        XCTAssertTrue(Revoice.chords(in: free)[1].map(\.pitch).contains(69))
        written.notes.append(Note(pitch: 69, start: bar + bar / 8, length: bar / 8))
        let after = apply(Revoice.revoiced(written), to: written)
        XCTAssertFalse(Revoice.chords(in: after)[1].map(\.pitch).contains(69), "the melody's A4 sounds then")
    }

    /// A humanized chord (starts a few ticks apart, one press at its widest) is one chord; a
    /// chord of six upper notes after the first is left as written, counted and said.
    func testHumanizedStartsAndBigChords() {
        var humanized = clip([[48, 64, 67], [53, 69, 72]])
        let spread: [Tick] = [-60, 60, 0]
        var seen = 0
        for index in humanized.notes.indices where humanized.notes[index].start > 0 {
            humanized.notes[index].start += spread[seen % spread.count]
            seen += 1
        }
        XCTAssertEqual(Revoice.chords(in: humanized).count, 2, "120 ticks apart is still one chord")
        let big = clip([[36, 48, 52, 55], [41, 53, 57, 60, 64, 67, 70], [43, 55, 59, 62, 65, 69, 72]])
        let result = Revoice.revoiced(big)
        XCTAssertEqual(result.keptAsWritten, 2)
        XCTAssertNil(result.command)
        XCTAssertEqual(Revoice.message(result),
                       "Nothing to revoice: 2 chords with more than 4 notes above the bass left as written.")
        // A doubled bass is bass: four notes above it are still searched.
        let doubledBass = clip([[36, 48, 52, 55], [41, 41, 53, 57, 60, 76]])
        XCTAssertEqual(Revoice.revoiced(doubledBass).keptAsWritten, 0)
        let mixed = Revoice.revoiced(clip([[48, 64, 67], [53, 69, 72], [41, 53, 57, 60, 64, 67, 70]]))
        XCTAssertTrue(Revoice.message(mixed).hasSuffix(" 1 chord with more than 4 notes above the bass left as written."))
    }
}

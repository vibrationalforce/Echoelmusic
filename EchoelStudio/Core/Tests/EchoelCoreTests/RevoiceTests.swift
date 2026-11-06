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
            [[60, 64], [62, 77], [55, 71, 74]],
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

    func testNothingToMoveIsNoCommand() {
        XCTAssertNil(Revoice.revoiced(clip([])).command)
        XCTAssertNil(Revoice.revoiced(clip([[48, 64, 67]])).command, "one chord")
        XCTAssertNil(Revoice.revoiced(clip([[60], [64], [67]])).command, "single notes are no chords")
        XCTAssertNil(Revoice.revoiced(clip([[48, 64, 67], [48, 64, 67]])).command, "already the least")
    }

    func testEdgesStayInsideTheRangeAndAboveTheBass() {
        let high = clip([[100, 124, 127], [101, 125, 116]])
        let after = apply(Revoice.revoiced(high), to: high)
        XCTAssertTrue(after.notes.allSatisfy { Note.pitchRange.contains($0.pitch) })
        let low = clip([[0, 4, 7], [5, 21, 12]])
        for chord in Revoice.chords(in: apply(Revoice.revoiced(low), to: low)) {
            let bass = chord.map(\.pitch).min() ?? 0
            XCTAssertEqual(chord.filter { $0.pitch == bass }.count, 1, "no upper note falls to or below the bass")
        }
        // A unison the musician wrote stays allowed; no new one is made.
        let unison = clip([[48, 60, 60], [53, 72, 69]])
        let chords = Revoice.chords(in: apply(Revoice.revoiced(unison), to: unison))
        XCTAssertGreaterThanOrEqual(Set(chords[1].map(\.pitch)).count, 3)
    }

    /// A humanized chord (starts a few ticks apart) is one chord; a chord of six upper notes is
    /// left as written and counted.
    func testHumanizedStartsAndBigChords() {
        var humanized = clip([[48, 64, 67], [53, 69, 72]])
        for index in humanized.notes.indices where humanized.notes[index].start > 0 {
            humanized.notes[index].start += Tick(index * 7)
        }
        XCTAssertEqual(Revoice.chords(in: humanized).count, 2)
        let big = clip([[36, 48, 52, 55, 59, 62, 65], [41, 53, 57, 60, 64, 67, 70], [43, 55, 59, 62]])
        XCTAssertEqual(Revoice.revoiced(big).keptAsWritten, 2)
    }
}

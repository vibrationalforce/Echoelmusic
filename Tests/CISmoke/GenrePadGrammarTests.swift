// GenrePadGrammarTests.swift
// Echoel — the authored pad figures obey the composer's laws (G2), in the BLOCKING bundle.
//
// KIND: END-TO-END BEHAVIOUR on pure Foundation value types (`PadGrammar.hits`,
// `PadGrammar.onsets(secStart:secLen:)`, `MusicStyle.padGrammar`). No engine, no view, no RNG.
// What no assertion here can reach is whether a figure GROOVES — that is a device question and
// it is deliberately NOT filed as one yet: no genre plays these figures, so there is nothing to
// listen to. The ask arrives with the batch that claims the first figure.
//
// ⚠️ `authoredAhead` STARTS FULL AND EMPTIES OVER G5…G15 — read this before treating a red as a
// break. Every figure below is authored ahead of the genre that will own it, exactly as
// `BassGrammar.rollingSixteenths` was through S1…S5, and claim 5 is what makes that state a
// declared fact instead of an omission. When a batch gives a genre a figure, it MOVES the name
// out of `authoredAhead` in the same commit; the red that follows a forgotten move names the
// figure, which is the point.
//
// ⛔ WHAT THIS FILE DOES NOT PIN, deliberately (#364): the level numbers inside a figure (a
// designer may re-balance 0.85 against 0.9), the phases of any individual figure beyond the
// structural laws below, and the genre→figure table itself. Pinning a phase would make authoring
// the eleven batches a fight with this file rather than with the ear.
//
// ⚠️ HONEST GRADING (§3): this file cannot be driven against the parent at all — `PadGrammar`
// does not exist there, so no assertion has a verdict (#486, one absence reported once). It is
// hand-transcribed in Python against the worktree, and the grading that means anything is
// mutant-driven: each claim was re-driven against a deliberately broken figure (a descending
// pair, an overlap, a zero length, a phase of 16, a figure owned AND listed ahead).

import XCTest
@testable import Echoelmusic

final class GenrePadGrammarTests: XCTestCase {

    // MARK: - claim 1 — a figure is ascending and never overlaps itself

    /// Two chords of the SAME voicing overlapping is not a rhythm, it is a stuck note: the second
    /// onset re-triggers pitches that are still sounding, and on a pad patch with a long release
    /// that reads as a smear rather than a chop. `chordOnsets`, which these figures replace,
    /// cannot produce one — it walks the section forward — so the law has to be stated here.
    func testEveryFigureIsAscendingAndNonOverlapping() {
        for grammar in PadGrammar.allCases {
            let hits = grammar.hits
            XCTAssertFalse(hits.isEmpty, "\(grammar) has no hits — an empty figure silences the pad")
            for (a, b) in zip(hits, hits.dropFirst()) {
                XCTAssertLessThan(a.phase, b.phase,
                                  "\(grammar) is not in ascending phase order at \(a.phase) → \(b.phase)")
                XCTAssertLessThanOrEqual(a.phase + a.length, b.phase, """
                    \(grammar)'s hit at phase \(a.phase) (length \(a.length)) runs into the next \
                    at \(b.phase). Two onsets of the same voicing overlapping re-trigger pitches \
                    that are still ringing — a smear, not a chop.
                    """)
            }
        }
    }

    // MARK: - claim 2 — a figure lives inside the 16-step bar, and no hit is zero-length

    /// `length >= 1` is the #205/#176 no-zero-length law: a note of length 0 is written to the
    /// take, reaches the player, and never ends. The phase bound is what makes
    /// `onsets(secStart:secLen:)`'s forward scan terminate — a phase of 16 matches no step.
    func testEveryHitIsInTheBarAndAtLeastOneStepLong() {
        for grammar in PadGrammar.allCases {
            for hit in grammar.hits {
                XCTAssertTrue((0..<16).contains(hit.phase), """
                    \(grammar) has a hit at phase \(hit.phase), outside the composer's 16-step \
                    bar. `onsets(secStart:secLen:)` scans forward for a matching phase and would \
                    silently drop it — a figure that loses a chord with no error anywhere.
                    """)
                XCTAssertGreaterThanOrEqual(hit.length, 1,
                                            "\(grammar) has a zero-length hit at phase \(hit.phase) (#205/#176)")
                XCTAssertGreaterThan(hit.level, 0, "\(grammar)'s hit at phase \(hit.phase) is silent")
                XCTAssertLessThanOrEqual(hit.level, 1, """
                    \(grammar)'s hit at phase \(hit.phase) has level \(hit.level) > 1. The caller \
                    multiplies the section velocity by it and clamps, so a level above 1 does not \
                    make that hit louder — it makes every OTHER hit quieter by comparison, which \
                    is not what the number reads as.
                    """)
            }
        }
    }

    // MARK: - claim 3 — resolving into a section stays inside it

    /// The clip is the contract `.pushedOffbeats` depends on: its last chord is written to ring
    /// over the barline, so it must be shortened rather than dropped. A resolved onset that ran
    /// past the section would write a note into the next section's steps.
    func testResolvedOnsetsAreClippedIntoTheSection() {
        for grammar in PadGrammar.allCases {
            for secStart in [0, 5, 16, 37] {
                for secLen in [1, 3, 8, 16, 31] {
                    let onsets = grammar.onsets(secStart: secStart, secLen: secLen)
                    for onset in onsets {
                        XCTAssertGreaterThanOrEqual(onset.start, secStart,
                                                    "\(grammar) placed an onset before the section")
                        XCTAssertGreaterThanOrEqual(onset.len, 1, "\(grammar) resolved a zero-length onset")
                        XCTAssertLessThanOrEqual(onset.start + onset.len, secStart + secLen, """
                            \(grammar) at secStart \(secStart) len \(secLen) wrote an onset that \
                            runs past the section end — it would sound over the next chord.
                            """)
                    }
                    // ⚠️ `{ $0.start }`, not `\.start`: a key path onto a TUPLE element is the
                    // kind of construct #689 had to re-measure before trusting, and a closure
                    // costs nothing. `\.padGrammar` below is a key path onto a TYPE and is fine.
                    let starts = onsets.map { $0.start }
                    XCTAssertEqual(starts, starts.sorted(),
                                   "\(grammar) resolved out of order at secStart \(secStart)")
                    XCTAssertEqual(Set(starts).count, onsets.count, """
                        \(grammar) resolved two hits onto the SAME step at secStart \(secStart) \
                        len \(secLen). The composer's take is one bar, so at most one step per \
                        section can carry a given phase; two hits on one step stack the voicing.
                        """)
                }
            }
        }
    }

    // MARK: - claim 4 — a section too short for a phase loses that hit, not the whole figure

    /// The degenerate inputs, asserted rather than assumed: a zero-length section yields nothing
    /// (never a crash, never a phantom onset at `secStart`), and a one-step section yields at
    /// most the single hit whose phase it happens to carry.
    func testShortSectionsDegradeQuietly() {
        for grammar in PadGrammar.allCases {
            XCTAssertTrue(grammar.onsets(secStart: 0, secLen: 0).isEmpty,
                          "\(grammar) wrote an onset into a zero-length section")
            for start in 0..<16 {
                XCTAssertLessThanOrEqual(grammar.onsets(secStart: start, secLen: 1).count, 1,
                                         "\(grammar) fitted more than one hit into a one-step section")
            }
        }
    }

    // MARK: - claim 5 — every figure is owned by a genre or declared authored ahead

    /// ⚠️ TODAY THE TABLE IS EMPTY AND EVERY FIGURE IS AHEAD. That is the G2 design — the
    /// mechanism ships before any genre claims it, so byte-identity is provable in one commit.
    /// The `isDisjoint` half is what turns a forgotten update into a named red rather than a
    /// quietly weakened claim.
    func testEveryFigureIsOwnedOrAuthoredAhead() {
        let owned = Set(MusicStyle.offered.compactMap(\.padGrammar))
        let authoredAhead: Set<PadGrammar> = [.pushedOffbeats, .tresilloChops, .charleston, .sweptSwell]
        XCTAssertEqual(owned.union(authoredAhead), Set(PadGrammar.allCases), """
            a pad figure is neither owned by an offered genre nor listed as authored ahead. A new \
            figure is added WITH its line in `authoredAhead` here, and moved out of it in the \
            batch that gives a genre the figure (G5…G15).
            """)
        XCTAssertTrue(owned.isDisjoint(with: authoredAhead), """
            a figure listed as authored ahead is already owned by an offered genre — the batch \
            that claimed it did not update this list, so claim 5 is now weaker than it reads.
            """)
    }
}

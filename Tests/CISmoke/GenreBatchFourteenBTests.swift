// GenreBatchFourteenBTests.swift
// Echoel — G14b's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchFourteenTests` form. No source-text scan.
//
// ⭐ THE TRIAD IS THE DECISION, AND THE PLAN OFFERED AN OPTION THAT DOES NOT EXIST (#33). The
// design sheet asked for `chordTones: [0, 2, 4, 6]` on `.harmonicMinor`, which resolves to
// `[0, 3, 7, 11]` — the minor-major seventh that is `slowedGothPop`'s entire separation, pinned
// there as a sweep over `allCases` (#1354). The plan's escape hatch was "give tango a different
// four-note voicing". Measured, that is not available: `GenreBatchFourVoicingTests` pins the
// four-note field to exactly TWO shapes — `detroitTechno`'s fifth-less `[0, 2, 6, 8]` and the
// plain `[0, 2, 4, 6]` the other arms carry — so a third shape would have rewritten that guard
// and Detroit's doc too. Claim 2 pins the triad AND the counterfactual: on this scale the plain
// four-note shape IS the neighbour's chord. That second half is the one nobody else owns, and it
// is what makes the triad necessary rather than merely convenient.
//
// ⭐ AND THE THIRD BLOCKER WAS A SUPERLATIVE, NOT A SWEEP — which is the durable lesson here.
// The idiomatic tango progression is the falling tetrachord `[0, 6, 5, 4]`, and it is FREE across
// the roster: a fingerprint sweep would have waved it through. It would have reddened
// `GenreBatchThreeVoicingTests`, where `upliftingTrance` holds the STRICT claim that it visits
// more distinct roots than every other offered genre — it is today the only offered genre with
// four, so a second four-root genre makes a true sentence false by TIE. `prebatch.py` checks
// sweeps; a superlative in a neighbour's guard has to be READ. Claim 4 pins the chosen
// `[0, 6, 4]` at three roots and carries trance's lead as an explicit counterweight (#343), so
// the day someone widens this progression the reason appears in THIS file rather than only in a
// guard that never mentions tango.
//
// ⚠️ THE LEAD NAME IS FORCED BY ARITHMETIC ALONE, and the header says so rather than dressing it
// up. The sheet said "Hollow Reed" — the bandoneón is a reed, so that was the honest name — and
// it stood at 8 against a pigeonhole ceiling of 8, i.e. 9 of 47. Only "Deep Sub" and "Warm
// Strings" had headroom. Of those two, strings are what an orquesta típica actually carries
// beside the bandoneón. `leadDensity` is 0.0, so no claim in this file calls it a sound.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `swing: 0.10` ties FOUR arms (`detroitTechno`,
// `andalusianCadence`, `afroHouse`, the un-offered `oriental`), so no swing claim is written.
// `mixLevels` is a free triple and takes no rank. The tempo window OVERLAPS its own shelf-mate
// `cumbia` (88…104) and `gospelChoir` (88…112); claim 5 pins the shelf-mate overlap so nobody
// later writes a disjointness that would be false — five of seven axes separate those two, not
// the clock.
//
// ⛔ FOUR CLAIMS OF MINE WERE WRONG IN THIS BATCH AND ALL FOUR WERE CAUGHT BY MEASURING BEFORE
// THE COMMIT, NOT BY A GUARD. They are listed because the PATTERN is one thing, not four: every
// one was a statement about a NEIGHBOUR written from memory. (1) `cumbia`'s tempo comment named
// one overlap where there are three, and got `andalusianCadence`'s window wrong. (2) `Lilt Sub`'s
// arm gave `Drone Sub`'s envelope as 0.030/0.90/0.88/0.55; it is 0.09/0.40/0.92/0.60. (3) This
// genre's swing comment named `disco` as a tie; `disco` is not among the four. (4) `Marcato
// Sub`'s arm called its envelope "the shortest sub"; it is the FIFTH-shortest of twenty-one.
// None of the four would have reddened any guard, in either batch. **The rule that catches this
// class is one line: a sentence about a neighbour is a MEASUREMENT, and `--patch` or a two-line
// sweep answers it in seconds.**
//
// ⭐ EVERY NUMBER IN THE TWO NEW PATCH DOCS CAME FROM `scripts/genre-prebatch.py --patch` at full
// coverage (79 of 79 blocks before the cut). `Marcato Sub`'s `cutoff: 720` is NOT free —
// `Dub Chord` holds it — so the arm names the tie and separates on role and envelope instead,
// both measured. #1352's law, three slices on: check the sibling with the tool BEFORE arguing a
// separation from it.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically before this file
// was written is `python3 scripts/genre-prebatch.py`: lead ceiling (Warm Strings 7 → 8 against a
// ceiling that stays 8), fingerprint (no two offered genres share the 7-tuple), patches (free
// ids 77, 78), voicing, tempo, register and grammar ownership — all OK, re-run after the cut:
// **57 genres, 40 offered, 81 patches**, GenreFX arms parsed 57 of 57. All eight repo checkers
// are green.
//
// ⛔ A §0 TRANSCRIPTION IS EVIDENCE ABOUT THE ROSTER, NEVER A COMPILE VERDICT (#1355). The
// slice before last read 41 of 41 green on a file that did not compile. Every type this file
// touches was therefore read from source first: `bassPatch` is `SynthPatch?` and claim 7 unwraps
// it, `bassGrammar` is `BassGrammar?`, `tempoRange` is `ClosedRange<Double>`, and a `zip(_:_:)`
// closure takes ONE tuple parameter (`$0.0 == $0.1`, not `$0 == $1` — the previous slice's draft
// had that and it would not have compiled).
//
// Against the parent tree this file does not COMPILE — it names `MusicStyle.tangoMarcato`, which
// does not exist there — so **no assertion has a verdict on the parent** (§3); that is one
// absence, not thirty-nine (#486). The compile verdict is CI/CD's `Build for Testing`; until it
// lands, this file is UNPROVEN, not green. **39 assertions across seven claims**
// (1 = 5 · 2 = 6 · 3 = 3 · 4 = 5 · 5 = 7 · 6 = 6 · 7 = 7) — counted
// mechanically, not estimated (#1334). One count is a loop body, so the STATEMENT count is the
// tally and the executed count is higher.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFourteenBTests: XCTestCase {

    // MARK: - 1 · The genre is offered, and its shelf now holds two

    func testTheGenreIsOfferedAndTheShelfHoldsTwo() {
        let style = MusicStyle.tangoMarcato
        XCTAssertEqual(style.displayName, "Tango Marcato")
        XCTAssertTrue(MusicStyle.offered.contains(style),
                      "a genre nobody can choose is not shipped")
        XCTAssertEqual(style.subcategory, .latinAmerica)

        // The shelf `cumbia` opened (#1357) stops being a one-genre drawer. Both must be
        // OFFERED, or the picker renders a section that silently omits one.
        let residents = MusicStyle.offered.filter { $0.subcategory == .latinAmerica }
        XCTAssertEqual(Set(residents), [.cumbia, .tangoMarcato])

        // And `.folk`'s shelves stay contiguous — no new shelf was added by this slice, so this
        // is a counterweight: it must read exactly as it did before.
        let folkShelves = MusicStyle.Subcategory.allCases.filter { $0.parent == .folk }
        XCTAssertEqual(folkShelves, [.europeanFolk, .nearEastCentralAsia, .latinAmerica])
    }

    // MARK: - 2 · The triad, and the counterfactual that made it necessary

    func testTheTriadAvoidsTheNeighboursMinorMajorSeventh() {
        let style = MusicStyle.tangoMarcato
        XCTAssertEqual(style.scale, .harmonicMinor)
        XCTAssertEqual(style.harmonicProfile.chordTones, [0, 2, 4])
        XCTAssertEqual(semitoneStack(of: style), [0, 3, 7],
                       "a plain minor triad — shared with twenty-three arms and claiming nothing")

        // ⭐ THE HALF NOBODY ELSE OWNS: on THIS scale, the four-note shape the roster allows
        // resolves to the neighbour's chord. That is why the sheet's `[0, 2, 4, 6]` was not
        // buildable and why a "tidy-up" back to four degrees is not a cosmetic edit.
        let key = MusicalKey(root: 0, scale: .harmonicMinor)
        let octave = style.harmonicProfile.padOctave
        let root = key.degree(0, octave: octave)
        let wouldBeFourNote = [0, 2, 4, 6].map { key.degree($0, octave: octave) - root }
        XCTAssertEqual(wouldBeFourNote, [0, 3, 7, 11],
                       "the plain four-note shape on harmonic minor IS the minor-major seventh")
        XCTAssertEqual(wouldBeFourNote, semitoneStack(of: .slowedGothPop),
                       "and that chord is slowedGothPop's whole separation (#1354) — which is "
                       + "why this genre takes a triad rather than a fourth degree")
        XCTAssertNotEqual(semitoneStack(of: style), semitoneStack(of: .slowedGothPop))
    }

    // MARK: - 3 · The major dominant, which is where the harmonic-minor colour went

    func testTheDominantIsMajorWhereNaturalMinorWouldGiveAMinorOne() {
        let style = MusicStyle.tangoMarcato
        let octave = style.harmonicProfile.padOctave
        func triad(_ rootDegree: Int, _ key: MusicalKey) -> [Int] {
            let root = key.degree(rootDegree, octave: octave)
            return [0, 2, 4].map { key.degree(rootDegree + $0, octave: octave) - root }
        }
        let harmonic = MusicalKey(root: 0, scale: .harmonicMinor)
        XCTAssertEqual(triad(0, harmonic), [0, 3, 7], "the tonic is minor")
        XCTAssertEqual(triad(4, harmonic), [0, 4, 7],
                       "the dominant is MAJOR — the colour the sheet wanted from a seventh, "
                       + "carried by the progression instead")
        XCTAssertEqual(triad(4, MusicalKey(root: 0, scale: .minor)), [0, 3, 7],
                       "on natural minor the same degree is minor, which is the contrast this "
                       + "scale was kept for")
    }

    // MARK: - 4 · Three roots, and the superlative that decided it

    func testTheProgressionIsFreeAndLeavesTranceItsLead() {
        let style = MusicStyle.tangoMarcato
        XCTAssertEqual(style.harmonicProfile.progression, [0, 6, 4])

        // Free across the roster — a sweep, so a later arm taking it reddens here.
        let sharers = MusicStyle.allCases.filter {
            $0 != style && $0.harmonicProfile.progression == [0, 6, 4]
        }
        XCTAssertTrue(sharers.isEmpty,
                      "i → ♭VII → V is now shared with \(sharers.map(\.rawValue).sorted())")

        // ⭐ THE COUNTERWEIGHT (#343), and the reason the falling tetrachord `[0, 6, 5, 4]` was
        // rejected even though it is FREE. `GenreBatchThreeVoicingTests` claims trance visits
        // more distinct roots than every other offered genre — STRICTLY. Four roots here would
        // be a tie, making a true sentence false in a guard that never mentions tango.
        let myRoots = Set(style.harmonicProfile.progression).count
        XCTAssertEqual(myRoots, 3,
                       "three roots on purpose — a fourth ties upliftingTrance and reddens "
                       + "GenreBatchThreeVoicingTests")
        let tranceRoots = Set(MusicStyle.upliftingTrance.harmonicProfile.progression).count
        XCTAssertGreaterThan(tranceRoots, myRoots,
                             "trance must still visit strictly more distinct roots than this "
                             + "genre, or the claim it owns has to be rewritten first")
        let ties = MusicStyle.offered.filter {
            $0 != .upliftingTrance
                && Set($0.harmonicProfile.progression).count >= tranceRoots
        }
        XCTAssertTrue(ties.isEmpty,
                      "\(ties.map(\.rawValue).sorted()) now match or beat trance's distinct-root "
                      + "count — that claim lives in GenreBatchThreeVoicingTests and has to be "
                      + "rewritten there before an arm here is widened")
    }

    // MARK: - 5 · The clock: the shelf-mate overlap is pinned, not denied

    func testTheTempoWindowOverlapsItsShelfMateOnPurpose() {
        let style = MusicStyle.tangoMarcato
        XCTAssertEqual(style.beatArchetype, .backbeat)
        XCTAssertEqual(style.tempoRange, 92...128)
        XCTAssertEqual(style.defaultTempo, 112)
        XCTAssertTrue(style.tempoRange.contains(style.defaultTempo))

        XCTAssertTrue(style.tempoRange.overlaps(MusicStyle.cumbia.tempoRange), """
            these two share a shelf AND a stretch of the tempo window, and that is on purpose. \
            Nothing here may claim they are separated by tempo — they are separated on five of \
            seven axes (archetype, lead voice, progression, register, bass figure).
            """)
        XCTAssertNotEqual(style.beatArchetype, MusicStyle.cumbia.beatArchetype)
        XCTAssertNotEqual(style.harmonicProfile.padOctave,
                          MusicStyle.cumbia.harmonicProfile.padOctave)
    }

    // MARK: - 6 · No delay, and it is SETTLED rather than defaulted

    func testTheEchoIsExplicitlyOff() {
        let fx = MusicStyle.tangoMarcato.fxPreset
        XCTAssertFalse(fx.delayEnabled,
                       "a marcato is defined by the silence between attacks; an echo fills "
                       + "exactly that silence")
        XCTAssertEqual(fx.delayMix, 0.0, accuracy: 1e-6)
        XCTAssertEqual(fx.delayFeedback, 0.0, accuracy: 1e-6)

        // The room does the work instead — counterweight, so "no delay" cannot be read as
        // "no space at all".
        XCTAssertTrue(fx.reverbEnabled)
        XCTAssertGreaterThan(fx.reverbMix, 0.0)

        // And the shelf-mate DOES carry an echo, which is one of the five separations claim 5
        // refuses to put on the clock.
        XCTAssertTrue(MusicStyle.cumbia.fxPreset.delayEnabled)
    }

    // MARK: - 7 · The two voices are this genre's own

    func testTheTwoPatchesAreThisGenresOwn() {
        let style = MusicStyle.tangoMarcato
        XCTAssertEqual(style.synthPatch.name, "Marcato Reed")

        // `bassPatch` is OPTIONAL — unwrapped, never forced (#1355).
        guard let bass = style.bassPatch else {
            return XCTFail("tangoMarcato has no bassPatch — `drivingEighths` would then play on "
                           + "a voice this genre does not own")
        }
        XCTAssertEqual(bass.name, "Marcato Sub")

        // Figure shared, voice never.
        XCTAssertEqual(style.bassGrammar, .drivingEighths)
        let otherDriving = MusicStyle.allCases.filter {
            $0 != style && $0.bassGrammar == .drivingEighths
        }
        XCTAssertFalse(otherDriving.isEmpty, "the figure is meant to be shared")
        for sibling in otherDriving {
            XCTAssertNotEqual(sibling.bassPatch?.name, bass.name,
                              "\(sibling.rawValue) now plays this genre's bass VOICE — the "
                              + "grammar is shareable, the patch is not")
            XCTAssertNotEqual(sibling.synthPatch.name, style.synthPatch.name,
                              "\(sibling.rawValue) now plays this genre's chord VOICE")
        }
    }

    // MARK: - Helpers

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

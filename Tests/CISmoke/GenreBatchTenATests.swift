// GenreBatchTenATests.swift
// Echoel — G10a's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchElevenDTests` form. No source-text scan.
//
// ⭐ THIS SLICE DEBUTS A RUBRIC, NOT ONLY A GENRE, AND THAT IS WHY CLAIM 6 EXISTS.
// `MusicStyle.Category` carried a ⛔ block saying `.chant` was "deliberately not here" because
// every genre the plan files under it was unwritten — and the block stated its own release
// condition: *a case is added ONLY together with its door*. `gospelChoir` is that door. The
// block is RETRACTED in place rather than deleted, because the rule it states is the live one
// and `GenreSubcategoryTests` claim 4 enforces it for every future rubric.
//
// ⚠️ THE RUBRIC TITLE IS HONEST-BUT-INCOMPLETE AND IT IS SAID OUT LOUD HERE. "Chant, Choir &
// Drone" names three families and holds exactly ONE genre today — a gospel CHOIR. Chant (G8)
// and Drone (G10's two) are BLOCKED on plan §5-2 (the tone systems `pythagorean`, `edo24`,
// `just-major`), not merely unwritten.
// ⭐ MEASURED, and it downgrades that from a shipped over-claim to a filing debt:
// **`Category.title` has ZERO production readers.** The genre menu loops `Subcategory.allCases`
// and renders `Section(shelf.title)`; no surface renders a rubric title. That is written at the
// `Category` doc too, because it is the line a session reads before adding a rubric — and it is
// deliberately NOT asserted here. A guard saying "nothing renders this" would go red the day
// someone correctly mounts a rubric header (#364).
//
// ⭐ WHY G10 SHIPS AS ONE GENRE OF THREE, measured rather than chosen. `overtoneDrone` and
// `lowBreathDrone` each carry TWO independent blockers: both name the tone system `just-major`
// (plan §5-2, unanswered) and both name a `pedalDrone` pad figure — a `PadGrammar` case that
// does not exist, in a table where `MusicStyle.padGrammar` returns `nil` for EVERY genre, so
// the first arm there is a mechanism debut and not a genre property (the #1295b finding).
// Neither blocker touches `gospelChoir`.
//
// ⚠️ THE REAL RISK IN THIS SLICE IS NOT THE RUBRIC — IT IS `soulBallad`, and claim 3 is the
// whole answer. The two genres share `major`, share `[0, 2, 4, 6]`, share `.backbeat` and share
// `padOctave: 4`; on the weaker identity key that `MusicStyleTests` uses they differ on exactly
// ONE axis. Three deviations from the design sheet were made deliberately and each is measured,
// not chosen: tempo 88…112 (the sheet's 72…100 sits INSIDE `soulBallad`'s 64…86), bass figure
// `drivingEighths` (the sheet said `offbeatEighths`, which is `soulBallad`'s own), and the lead
// bucket "Warm Strings" (the sheet said Choir Vox, already at 7 of a ceiling of 7).
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `drivingEighths` is now shared with seven other genres
// and `[0, 4, 7, 11]` is carried by twelve arms — both measured before writing, neither claimed.
// The tempo window overlaps eight other offered genres and that is fine; tempo is a hint, not an
// identity, and `GenreFamilyDistinctnessTests` does not read it. The disjointness asserted in
// claim 3 is against `soulBallad` ALONE and says so.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically, before a line of
// this file was written, is `python3 scripts/genre-prebatch.py` with the candidate: lead ceiling
// (Warm Strings 6 → 7, ceiling stays 7), fingerprint (no offered pair shares one), patches (free
// ids 67, 68), voicing (`[0, 2, 4, 6]` on major = 0, 4, 7, 11), tempo/delay, register and
// grammar ownership — all OK, and re-run after the cut: **52 genres, 35 offered, 71 patches**.
// The weak-key collision sweep (`scale|progression|chordTones|beatArchetype` over ALL genres,
// the key `MusicStyleTests` uses) was run separately and returned EMPTY. Against the parent
// tree the file does not COMPILE — it names `MusicStyle.gospelChoir`, `.chant` and
// `.gospelSpiritual`, none of which exist there — so **no assertion has a verdict on the parent**
// (§3); that is one absence, not thirty (#486). The compile verdict is CI/CD's `Build for
// Testing`; until it lands, this file is UNPROVEN, not green. **31 assertions across six claims**
// (1 = 7 · 2 = 5 · 3 = 8 · 4 = 5 · 5 = 3 · 6 = 3) — the tally, so a later reader can tell at a
// glance whether the file still makes the claims its header describes (#1334).
//
// NEEDS-FOUNDER-VERIFY: Gospel Choir at 96 in Loop mode, A/B against Soul Ballad at 72. Two ear
// questions, and they are the two the arithmetic cannot answer. (1) Do the two genres read as
// DIFFERENT pieces of music, or as one ballad at two speeds? They share scale, stack and
// register by design; everything separating them is tempo, figure and voice. (2) Does "Church
// Choir" (uni 4, det 12, attack 0.14, reverb room 0.84) read as a massed choir, or as a detuned
// organ? If (2) fails the fix is the unison count and the chorus depth, not the cutoff — that
// sits at a measured free value between two named neighbours.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchTenATests: XCTestCase {

    private let addition: MusicStyle = .gospelChoir
    private let neighbour: MusicStyle = .soulBallad

    // MARK: - Claim 1 — the door, on the shelf and in the rubric it both debuts

    func testTheFirstChantRubricDoorIsOpen() {
        XCTAssertTrue(MusicStyle.offered.contains(addition),
                      "gospelChoir is built but not offered — a doorless genre (#254), and here "
                      + "it would also leave the rubric it debuts standing empty")
        XCTAssertEqual(addition.category, .chant)
        XCTAssertEqual(addition.subcategory, .gospelSpiritual)
        XCTAssertTrue(addition.category.offeredGenres.contains(addition))
        XCTAssertTrue(addition.subcategory.offeredGenres.contains(addition))
        XCTAssertEqual(addition.displayName, "Gospel Choir")
        XCTAssertFalse(addition.lineage.isEmpty)
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, never in degree numbers

    func testTheStackIsTheMajorSeventhAndTheCadenceLifts() {
        // ⭐ `[0, 2, 4, 6]` is NOT semitones — the #1286 trap. Resolved through `MusicalKey.degree`
        // on major `[0,2,4,5,7,9,11]` it is 0, 4, 7, 11: the major seventh.
        XCTAssertEqual(semitoneStack(of: addition), [0, 4, 7, 11],
                       "the choir stack is no longer a major seventh — it is the whole voicing "
                       + "of this genre, which has no melodic voice of its own")
        XCTAssertEqual(addition.harmonicProfile.chordTones, [0, 2, 4, 6])
        XCTAssertEqual(addition.harmonicProfile.progression, [0, 3, 4],
                       "I → IV → V: the dominant as a third ROOT is the gospel lift, and it is "
                       + "the single axis separating this genre from soulBallad's [0, 3, 5] "
                       + "under MusicStyleTests' weaker identity key")
        XCTAssertFalse(addition.harmonicProfile.arpeggiated,
                       "the choir is the PAD; rolling the stack turns the genre's one gesture "
                       + "into a figure")
        XCTAssertEqual(addition.harmonicProfile.leadDensity, 0,
                       "leadDensity moved off zero. If that is deliberate, the `lineage` line "
                       + "may now name a melodic voice — plan §2b-9 forbids it only while this "
                       + "is identically 0")
    }

    // MARK: - Claim 3 — the near neighbour, and the axes that actually separate the two

    func testItIsSeparatedFromSoulBalladOnTempoFigureAndVoice() {
        // The PREMISES first (#343). Four shared axes are what makes this claim necessary; if
        // soulBallad moved off any of them, the separation argument in the case doc is stale.
        XCTAssertEqual(neighbour.scale, addition.scale,
                       "the shared scale IS the premise — if soulBallad left major, the case "
                       + "doc's separation argument has to be rewritten, not just this line")
        XCTAssertEqual(neighbour.harmonicProfile.chordTones, addition.harmonicProfile.chordTones)
        XCTAssertEqual(neighbour.beatArchetype, addition.beatArchetype)
        XCTAssertEqual(neighbour.harmonicProfile.padOctave, addition.harmonicProfile.padOctave)

        // Axis 1 — tempo, and this is the only CLEAN CUT in the set: the windows are disjoint.
        // Asserted against soulBallad ALONE; the window overlaps eight other offered genres on
        // purpose and no disjointness is claimed there.
        XCTAssertGreaterThan(addition.tempoRange.lowerBound, neighbour.tempoRange.upperBound,
                             "the two tempo windows now touch. The design sheet's 72…100 sat "
                             + "INSIDE soulBallad's 64…86, which is exactly why this genre "
                             + "deviates to 88…112 — if they overlap again the deviation has "
                             + "lost its reason and the case doc must say so")

        // Axis 2 — the bass figure.
        XCTAssertNotEqual(addition.bassGrammar, neighbour.bassGrammar,
                          "the sheet gave this genre soulBallad's own `offbeatEighths`; two "
                          + "genres sharing scale, stack, register and groove must not walk alike")

        // Axis 3 — the lead bucket, forced by the pigeonhole arithmetic.
        XCTAssertNotEqual(addition.leadPatchName, neighbour.leadPatchName)

        // Axis 4 — the progression, the one axis the weak identity key can see.
        XCTAssertNotEqual(addition.harmonicProfile.progression,
                          neighbour.harmonicProfile.progression,
                          "with the progression equal these two collide on "
                          + "MusicStyleTests.testEveryGenreHasADistinctMusicalIdentity")
    }

    // MARK: - Claim 4 — figure shared, VOICE never

    func testItSharesTheFigureAndOwnsItsTwoVoices() {
        XCTAssertEqual(addition.bassGrammar, .drivingEighths,
                       "the eighth owner of a shared figure — shared on purpose")
        guard let bass = addition.bassPatch else {
            return XCTFail("gospelChoir has no bassPatch — `drivingEighths` would then play on "
                           + "the pad voice an octave down, the pre-grammar path (#1286).")
        }
        XCTAssertEqual(bass.name, "Church Sub")
        XCTAssertEqual(addition.synthPatch.name, "Church Choir")

        // Counterweight (#343): the figure is shareable, the VOICE is not — on BOTH sides.
        let sameBass = MusicStyle.offered.filter { $0 != addition && $0.bassPatch?.name == bass.name }
        let sameLead = MusicStyle.offered.filter { $0 != addition && $0.synthPatch.name == addition.synthPatch.name }
        XCTAssertTrue(sameBass.isEmpty && sameLead.isEmpty,
                      "\(sameBass + sameLead) share one of gospelChoir's VOICES. The lead BUCKET "
                      + "(`leadPatchName`) is shared with six genres and that is the ceiling "
                      + "arithmetic; the patch is not.")
    }

    // MARK: - Claim 5 — the three things a compiler cannot check

    func testTheModeTempoAndPadFigureAreDeliberate() {
        // `defaultMode` ends in `default: .studioLocked`, so this genre takes no arm. For a
        // driven backbeat that is right, and it is the silent inheritance nothing would report.
        XCTAssertEqual(addition.defaultMode, .studioLocked)
        XCTAssertTrue(addition.tempoRange.contains(addition.defaultTempo),
                      "a default tempo outside its own range is a picker that opens wrong")

        // NOT a prohibition (#364): the day a slice gives this genre the table's first arm, this
        // line goes red and its message says what has to move with it.
        XCTAssertNil(addition.padGrammar,
                     "gospelChoir now carries a pad figure. If that is the deliberate debut of "
                     + "`MusicStyle.padGrammar`'s FIRST arm, say so here and in this file's "
                     + "header — the two drones this batch left behind are waiting on exactly "
                     + "that table plus plan §5-2, and their blocker list changes with it.")
    }

    // MARK: - Claim 6 — the rubric this slice debuts, and the law it had to meet

    func testTheNewRubricAndShelfAreNotEmptyDrawers() {
        XCTAssertEqual(MusicStyle.Subcategory.gospelSpiritual.parent, .chant)
        XCTAssertEqual(MusicStyle.Subcategory.gospelSpiritual.title, "Gospel & Spiritual")
        // The general form of this is `GenreSubcategoryTests` claim 4; asserted HERE too because
        // this is the slice that released the ⛔ block, and a rubric whose only genre is later
        // moved elsewhere would leave the exact empty drawer that block forbids.
        XCTAssertFalse(MusicStyle.Category.chant.offeredGenres.isEmpty,
                       "the `.chant` rubric is offered-empty. It was added under the rule that a "
                       + "case arrives ONLY with its door; if gospelChoir moved shelves, the "
                       + "rubric has to move with it or go.")
    }

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

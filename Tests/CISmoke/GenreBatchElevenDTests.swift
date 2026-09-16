// GenreBatchElevenDTests.swift
// Echoel — G11d's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchElevenCTests` form. No source-text scan.
//
// ⭐ THIS SLICE CARRIES A RETRACTION, AND THAT IS WHY IT IS ITS OWN COMMIT. `balkanModal` takes
// `hungarianMinor`, and `blackMetal`'s doc said in as many words that the scale was "used by no
// other genre" (#1288). Shipping the two together in G11c would have buried a retraction inside
// a feature, where nobody reads it. The retraction is written at `blackMetal`'s own arm — the
// doc a session reads when it asks whether a scale is free — and claim 3 here pins the four
// axes that replace the uniqueness argument.
//
// ⭐ AND THE OTHER PLANNED RISK DISSOLVED ON MEASUREMENT, WHICH IS THE BETTER OUTCOME. The
// design sheet asked for an `additive332` pad grammar. Two facts killed it:
//   1. `PadGrammar.tresilloChops` IS 3+3+2 — same `hits` array, phases 0·3·6 then 8·11·14. The
//      Balkan name for that grouping is *aksak*; building `additive332` would have been a
//      second implementation of one figure, separated only by which tradition names it (#416).
//      That note now lives at the case itself, so the next tradition does not re-add it.
//   2. `MusicStyle.padGrammar` returns `nil` for EVERY genre in the roster. The first arm there
//      is the debut of a whole mechanism, not a property of this genre, and folding a mechanism
//      debut into a genre introduction makes a listening problem and a wiring problem
//      indistinguishable on the device. Claim 5 pins the `nil` so the omission is deliberate
//      and visible rather than forgotten.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `drivingEighths` is shared with six other genres and
// `[0, 3, 7]` semitones is the commonest stack in the file — both measured before writing,
// neither claimed. The tempo windows of this genre and `blackMetal` OVERLAP (120…170 against
// 160…200) and that is named here so nobody writes a disjointness claim; tempo is a hint, not
// an identity, and `GenreFamilyDistinctnessTests` does not read it.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types the
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416), which is worse than no transcription. What WAS
// driven mechanically, before a line of this file was written, is
// `python3 scripts/genre-prebatch.py` with the candidate: lead ceiling (Hollow Reed 6 → 7,
// ceiling stays 7), fingerprint (no offered pair shares one), patches (free ids 65, 66),
// voicing (`[0, 2, 4]` on hungarianMinor = 0, 3, 7; progression unique), delay (0.75 quarters
// at 170 BPM = 0.26 s, under the 2.0 s ceiling), register and grammar ownership — all OK, and
// re-run after the cut: 51 genres, 34 offered, 69 patches. The compile verdict is CI/CD's
// `Build for Testing`; until it lands, this file is UNPROVEN, not green. **30 assertions
// across five claims** (1 = 8 · 2 = 5 · 3 = 7 · 4 = 6 · 5 = 4) — the tally, so a later reader can tell at a glance whether
// the file still makes the claims its header describes (#1334).
//
// NEEDS-FOUNDER-VERIFY: Balkan Modal at 140 in Loop mode. Two ear questions, both about the
// raised fourth. (1) Does `progression: [0, 4, 3]` land the tritone root as COLOUR, or does it
// read as a wrong chord? (2) Does "Brass Reed" (noise 0.08, harmonics 0.78) read as a double
// reed, or just as a bright saw? If (2) fails the fix is the noise and harmonic level, not the
// cutoff — the cutoff is already at a measured free value between two neighbours.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchElevenDTests: XCTestCase {

    private let addition: MusicStyle = .balkanModal

    // MARK: - Claim 1 — the door, on the shelf it joins

    func testTheFourthEuropeanFolkDoorIsOpen() {
        XCTAssertTrue(MusicStyle.offered.contains(addition),
                      "balkanModal is built but not offered — a doorless genre (#254)")
        XCTAssertEqual(addition.category, .folk)
        XCTAssertEqual(addition.subcategory, .europeanFolk)
        XCTAssertTrue(addition.category.offeredGenres.contains(addition))
        XCTAssertTrue(addition.subcategory.offeredGenres.contains(addition))
        XCTAssertEqual(addition.displayName, "Balkan Modal")
        XCTAssertFalse(addition.lineage.isEmpty)

        // Counterweight (#343): the shelf must still hold the three doors this batch was
        // measured against, or claim 1 stays green on a tree that replaced the shelf.
        let shelf = MusicStyle.Subcategory.europeanFolk
        for mate in [MusicStyle.celticAir, .andalusianCadence, .nordicFiddle] {
            XCTAssertTrue(shelf.offeredGenres.contains(mate),
                          "\(mate.rawValue) left the shelf this batch was measured against")
        }
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, never in degree numbers

    func testTheStackIsAPlainMinorTriadOnARaisedFourthScale() {
        // ⭐ `[0, 2, 4]` is NOT semitones — the #1286 trap. Resolved through `MusicalKey.degree`
        // on hungarianMinor `[0,2,3,6,7,8,11]` it is 0, 3, 7: a plain minor triad. The raised
        // fourth is in the SCALE and in the PROGRESSION, never in the pad's own stack.
        XCTAssertEqual(semitoneStack(of: addition), [0, 3, 7],
                       "the pad no longer states the mode; the whole separation from blackMetal "
                       + "is that this one voices a third and that one refuses to")
        XCTAssertEqual(addition.harmonicProfile.chordTones, [0, 2, 4])
        XCTAssertEqual(addition.harmonicProfile.progression, [0, 4, 3])
        XCTAssertTrue(addition.harmonicProfile.arpeggiated,
                      "a tune with runs has to move; this is the only arpeggiating European "
                      + "Folk arm")
        XCTAssertEqual(addition.scale, .hungarianMinor)
    }

    // MARK: - Claim 3 — the four axes that REPLACE blackMetal's retracted uniqueness claim

    func testItIsSeparatedFromTheOnlyOtherGenreOnThisScale() {
        let metal = MusicStyle.blackMetal
        XCTAssertEqual(metal.scale, addition.scale,
                       "the shared scale IS the premise of this claim — if blackMetal moved off "
                       + "hungarianMinor, the retraction in its doc is now wrong too")

        // Axis 1 — voicing on the SAME array: minor triad against a power chord with no third.
        XCTAssertEqual(semitoneStack(of: metal), [0, 7, 12],
                       "blackMetal's power-chord voicing is gone; it is the half of the "
                       + "separation that does the most work")
        XCTAssertNotEqual(addition.harmonicProfile.chordTones, metal.harmonicProfile.chordTones)

        // Axis 2 — progression.
        XCTAssertNotEqual(addition.harmonicProfile.progression, metal.harmonicProfile.progression)

        // Axis 3 — the lead voice.
        XCTAssertNotEqual(addition.leadPatchName, metal.leadPatchName)

        // Axis 4 — register.
        XCTAssertNotEqual(addition.harmonicProfile.padOctave, metal.harmonicProfile.padOctave)

        // ⚠️ NOT an axis, and asserted so nobody promotes it to one: the tempo windows OVERLAP.
        // blackMetal 160…200 against 120…170. Naming it here is the same discipline its own doc
        // applies to `punk`.
        XCTAssertTrue(addition.tempoRange.contains(metal.tempoRange.lowerBound),
                      "the tempo overlap this file documents is gone — if the windows became "
                      + "disjoint, remove the warning here and in blackMetal's doc, because a "
                      + "warning about a condition that no longer holds is the #364 defect")
    }

    // MARK: - Claim 4 — figure shared, VOICE never

    func testItSharesTheFigureAndOwnsItsVoice() {
        XCTAssertEqual(addition.bassGrammar, .drivingEighths,
                       "the sixth owner of a shared figure — shared on purpose")
        guard let bass = addition.bassPatch else {
            return XCTFail("balkanModal has no bassPatch — `drivingEighths` would then play on "
                           + "the pad voice an octave down, the pre-grammar path (#1286).")
        }
        XCTAssertEqual(bass.name, "Brass Sub")

        // Counterweight (#343): the figure is shareable, the VOICE is not.
        let sameVoice = MusicStyle.offered.filter { $0 != addition && $0.bassPatch?.name == bass.name }
        XCTAssertTrue(sameVoice.isEmpty, "\(sameVoice) share balkanModal's bass VOICE")

        // And the contrast that the two patch docs argue: the shelf-mate's drone is built never
        // to finish inside a bar, this one must.
        XCTAssertLessThan(bass.sustain, 0.6,
                          "a driving-eighths bass that sustains like the bordun beside it would "
                          + "smear the runs this genre exists for")
        XCTAssertEqual(addition.leadPatchName, "Hollow Reed",
                       "measured at 6 → 7 owners, exactly the ceiling, before writing")
    }

    // MARK: - Claim 5 — the two things a compiler cannot check

    func testTheModeAndThePadFigureAreBothDeliberateOmissions() {
        // `defaultMode` ends in `default: .studioLocked`, so this genre takes no arm. For a dance
        // tune that is right, and it is exactly the silent inheritance nothing would report.
        XCTAssertEqual(addition.defaultMode, .studioLocked)
        XCTAssertTrue(addition.tempoRange.contains(addition.defaultTempo),
                      "a default tempo outside its own range is a picker that opens wrong")

        // The pad figure is `nil` ON PURPOSE — see the header. This assertion is what makes the
        // omission deliberate rather than forgotten, and it is NOT a prohibition (#364): the day
        // a slice gives this genre the table's first arm, this line goes red and its message
        // says the header and `PadGrammar`'s aksak note must move in the same commit.
        XCTAssertNil(addition.padGrammar,
                     "balkanModal now carries a pad figure. If that is the deliberate debut of "
                     + "`MusicStyle.padGrammar`'s FIRST arm, say so here and in this file's "
                     + "header — and check it is not a rename of `tresilloChops`, which already "
                     + "is 3+3+2 (aksak is the Balkan name for the same cell, #416).")
        XCTAssertNil(MusicStyle.nordicFiddle.padGrammar,
                     "the counterweight: the table was empty for EVERY genre when this was "
                     + "written. If a different genre took the first arm, this batch's reason "
                     + "for abstaining no longer holds and the header must say so.")
    }

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

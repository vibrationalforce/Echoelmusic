// GenreBatchFifteenATests.swift
// Echoel — G15a's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchTenATests` form. No source-text scan.
//
// ⭐ THIS SLICE ADDS NO TAXONOMY, AND THAT IS THE POINT OF CHOOSING IT. `loFiHipHop` joins
// the EXISTING `.loFiHazy` shelf beside `vaporwave`, under the EXISTING `.underground` rubric.
// G10a had to debut a rubric with its genre; this one debuts nothing, so every assertion below
// is about the music rather than about the filing.
//
// ⚠️ THE REAL RISK IS NOT THE SHELF-MATE — IT IS TWO GENRES ON OTHER SHELVES, and claims 3 and
// 4 are the whole answer. Measured over the seven identity axes (scale · beatArchetype ·
// leadPatchName · progression · chordTones · padOctave · bassGrammar) against ALL 53 genres,
// exactly two sit at the maximum of FOUR shared axes:
//   · `dubTechno`        — scale, chordTones, leadPatchName, padOctave
//   · `boomBapHipHop`    — beatArchetype, bassGrammar, chordTones, padOctave
// `vaporwave`, the shelf-mate, shares two. The three deviations from the design sheet were each
// made to hold that maximum at four, and each is measured rather than chosen:
//   1. `padOctave: 3` (sheet: 4). It does NOT lower the maximum — it halves the CROWD at it:
//      at 4 the genres tied at four axes are `modalJazz`, `jazz`, `electroFunk` and
//      `detroitTechno`; at 3 they are `dubTechno` and `boomBapHipHop`. Smaller claim than the
//      first draft made, and the true one.
//   2. `leadPatchName: "Pluck"` (sheet: "Soft Keys"). The pigeonhole ceiling had room for all
//      six names, so nothing was forced — but of the six, five hold the maximum at four and
//      "Soft Keys" alone raises it to FIVE, against `boomBapHipHop`. The arithmetic vetoes one
//      name; which of the remaining five is an ear call, written as one.
//   3. `bassGrammar: .sparseSub` is the sheet's own pick and is kept — the FIFTH owner of that
//      figure. The separation from `boomBapHipHop`, which walks the same figure, is the VOICE
//      ("Wobble Sub" against "Dust Sub"), asserted in claim 5.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `[0, 2, 4, 6]` is carried by FOURTEEN arms including
// this one, and `.dorian` by nine — both measured before writing, neither claimed as an
// identity. The tempo window 72…88 OVERLAPS `boomBapHipHop`'s 84…96 and the un-offered `jazz`'s
// 80…150; claim 4 pins that overlap so nobody writes the disjointness that would be false.
// `swing: 0.22` is an exact TIE with the un-offered `rocksteady`, so no swing superlative is
// written; the only swing claim is the ordering against `modalJazz`'s pinned 0.30.
//
// ⭐ THREE COMMENT REPAIRS TRAVEL WITH THIS SLICE, TWO OF THEM IN CODE THAT SHIPPED IN #1349,
// and the cause is one defect: a throwaway parser that silently read 31 of `GenrePatches.swift`'s
// 73 `patch(` blocks and reported only what it matched. Five numbers in "Church Choir"'s doc
// (#1349) and five in this batch's own first draft came from it. The LAW now written at the
// "Church Choir" arm: **a measurement that cannot state its own COVERAGE is not a measurement** —
// a parser over that file prints `parsed N of M` and nothing derived from it is written down
// until N == M. This is the same failure `.claude/rules/context.md` §2 records for a grep that
// can silently return less than the truth, one file over. The third repair is a false
// superlative in `MusicStyle.mixLevels` ("the lead trimmed furthest of any arm here" — it is
// 0.86 against `glacialField`/`slowBloom`'s 0.85).
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically, before a line of
// this file was written, is `python3 scripts/genre-prebatch.py`: lead ceiling (bearing 42 → 43,
// ceiling 7 → 8, "Pluck" 7 → 8 and therefore exactly AT it), fingerprint (no two offered genres
// share the 7-tuple), patches (free ids 69, 70), voicing, tempo/delay, register and grammar
// ownership — all OK, re-run after the cut: **53 genres, 36 offered, 73 patches**. The weak-key
// collision sweep (`scale|progression|chordTones|beatArchetype` over ALL 53, the key
// `MusicStyleTests` uses) was run through the same parser and returned EMPTY. Against the parent
// tree this file does not COMPILE — it names `MusicStyle.loFiHipHop`, which does not exist there
// — so **no assertion has a verdict on the parent** (§3); that is one absence, not forty-five
// (#486). The compile verdict is CI/CD's `Build for Testing`; until it lands, this file is
// UNPROVEN, not green. **45 assertions across seven claims** (1 = 8 · 2 = 6 · 3 = 7 · 4 = 7 ·
// 5 = 5 · 6 = 5 · 7 = 7) — the tally, so a later reader can tell at a glance whether the file
// still makes the claims its header describes (#1334).
//
// NEEDS-FOUNDER-VERIFY: Lo-Fi Hip-Hop at 80 in Loop mode, A/B against Boom Bap at 90. Two ear
// questions, both about the wobble. (1) Does "Wobble Keys" (lfoRate 0.32, vibDepth 0.11, det 13)
// read as worn tape, or as an out-of-tune synth? (2) Is the quarter-TRIPLET echo heard as a drag
// against the backbeat, or does it just sound late? If (2) fails the fix is the division — a
// dotted quarter is the next candidate — not the mix, which is at a measured free value.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFifteenATests: XCTestCase {

    private let addition: MusicStyle = .loFiHipHop

    // MARK: - Claim 1 — the door, on a shelf that already existed

    func testTheSecondLoFiHazyDoorIsOpen() {
        XCTAssertTrue(MusicStyle.offered.contains(addition),
                      "loFiHipHop is built but not offered — a doorless genre (#254)")
        XCTAssertEqual(addition.category, .underground)
        XCTAssertEqual(addition.subcategory, .loFiHazy)
        XCTAssertTrue(addition.category.offeredGenres.contains(addition))
        XCTAssertTrue(addition.subcategory.offeredGenres.contains(addition))
        XCTAssertEqual(addition.displayName, "Lo-Fi Hip-Hop")
        XCTAssertFalse(addition.lineage.isEmpty)

        // Counterweight (#343): the shelf must still hold the mate this batch was measured
        // against, or claim 1 stays green on a tree that emptied the shelf around it.
        XCTAssertTrue(MusicStyle.Subcategory.loFiHazy.offeredGenres.contains(.vaporwave),
                      "vaporwave left the shelf this genre was placed beside")
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, never in degree numbers

    func testTheStackIsTheMinorSeventhAndTheLoopIsThreeRoots() {
        // ⭐ `[0, 2, 4, 6]` is NOT semitones — the #1286 trap. Resolved through `MusicalKey.degree`
        // on dorian `[0,2,3,5,7,9,10]` it is 0, 3, 7, 10: the minor seventh.
        XCTAssertEqual(semitoneStack(of: addition), [0, 3, 7, 10],
                       "the dragged minor seventh is the genre; the lineage line names it")
        XCTAssertEqual(addition.harmonicProfile.chordTones, [0, 2, 4, 6])
        XCTAssertEqual(addition.harmonicProfile.progression, [0, 5, 3],
                       "i → vi → IV. `composeHarmonic` ROTATES over progressionPhase, so this "
                       + "is a SET of roots opening on the tonic, never a score (#1290)")
        XCTAssertEqual(addition.scale, .dorian)
        XCTAssertFalse(addition.harmonicProfile.arpeggiated,
                       "the loop is a held comped stack; a rolled figure turns a background "
                       + "music into a foreground one")
        XCTAssertEqual(addition.harmonicProfile.leadDensity, 0,
                       "leadDensity moved off zero. If that is deliberate the `lineage` line "
                       + "may now name a melodic voice — plan §2b-9 forbids it only while this "
                       + "is identically 0")
    }

    // MARK: - Claim 3 — the first of the two four-axis neighbours

    func testItIsSeparatedFromDubTechnoOnGrooveLoopAndTempo() {
        let dub = MusicStyle.dubTechno

        // The PREMISES first (#343). These four shared axes are WHY this claim exists; if any
        // of them moved, the header's neighbour measurement is stale, not merely this line.
        XCTAssertEqual(dub.scale, addition.scale)
        XCTAssertEqual(dub.harmonicProfile.chordTones, addition.harmonicProfile.chordTones)
        XCTAssertEqual(dub.leadPatchName, addition.leadPatchName,
                       "the lead BUCKET is shared on purpose — it is the one collision the "
                       + "\"Pluck\" choice accepts in exchange for not colliding with boomBap")
        XCTAssertEqual(dub.harmonicProfile.padOctave, addition.harmonicProfile.padOctave)

        // Axis 1 — the groove. `.signature` against `.backbeat`: sustained against comped.
        XCTAssertNotEqual(addition.beatArchetype, dub.beatArchetype)
        // Axis 2 — the loop.
        XCTAssertNotEqual(addition.harmonicProfile.progression, dub.harmonicProfile.progression)
        // Axis 3 — tempo, and against THIS genre alone the windows are genuinely disjoint.
        XCTAssertLessThan(addition.tempoRange.upperBound, dub.tempoRange.lowerBound,
                          "the two tempo windows now touch. The disjointness is claimed against "
                          + "dubTechno ONLY — see claim 4 for the overlap that is deliberate")
    }

    // MARK: - Claim 4 — the second, and the one the name makes dangerous

    func testItIsSeparatedFromBoomBapOnModeVoiceAndLoop() {
        let boomBap = MusicStyle.boomBapHipHop

        // The PREMISES (#343): same groove, same bass figure, same stack, same register.
        XCTAssertEqual(boomBap.beatArchetype, addition.beatArchetype)
        XCTAssertEqual(boomBap.bassGrammar, addition.bassGrammar)
        XCTAssertEqual(boomBap.harmonicProfile.chordTones, addition.harmonicProfile.chordTones)

        // Axis 1 — the MODE, and it is the heaviest of the three: dorian's raised sixth against
        // a plain minor is what makes one hazy and the other dusty.
        XCTAssertNotEqual(addition.scale, boomBap.scale)
        // Axis 2 — the lead bucket. "Soft Keys" here would have made this pair five-of-seven.
        XCTAssertNotEqual(addition.leadPatchName, boomBap.leadPatchName)
        // Axis 3 — the loop: three roots against two.
        XCTAssertNotEqual(addition.harmonicProfile.progression, boomBap.harmonicProfile.progression)

        // ⚠️ NOT an axis, and asserted so nobody promotes it to one: the tempo windows OVERLAP
        // (72…88 against 84…96). These are adjacent musics and that is correct.
        XCTAssertTrue(addition.tempoRange.contains(boomBap.tempoRange.lowerBound),
                      "the tempo overlap this file documents is gone. If the windows became "
                      + "disjoint, remove the warning here and in the case doc — a warning "
                      + "about a condition that no longer holds is the #364 defect")
    }

    // MARK: - Claim 5 — figure shared, VOICE never

    func testItSharesTheFigureAndOwnsItsTwoVoices() {
        XCTAssertEqual(addition.bassGrammar, .sparseSub,
                       "the fifth owner of a shared figure — shared on purpose")
        guard let bass = addition.bassPatch else {
            return XCTFail("loFiHipHop has no bassPatch — `sparseSub` would then play on the "
                           + "pad voice an octave down, the pre-grammar path (#1286).")
        }
        XCTAssertEqual(bass.name, "Wobble Sub")
        XCTAssertEqual(addition.synthPatch.name, "Wobble Keys")

        // Counterweight (#343): the figure is shareable, the VOICE is not — on BOTH sides.
        let sameBass = MusicStyle.offered.filter { $0 != addition && $0.bassPatch?.name == bass.name }
        let sameLead = MusicStyle.offered.filter { $0 != addition && $0.synthPatch.name == addition.synthPatch.name }
        XCTAssertTrue(sameBass.isEmpty && sameLead.isEmpty,
                      "\(sameBass + sameLead) share one of loFiHipHop's VOICES. The lead BUCKET "
                      + "(`leadPatchName`) is shared with eight genres and that is the ceiling "
                      + "arithmetic; the patch is not.")
    }

    // MARK: - Claim 6 — the things a compiler cannot check

    func testTheModeTempoSwingAndPadFigureAreDeliberate() {
        // `defaultMode` ends in `default: .studioLocked`, so this genre takes no arm. For a
        // loop-based music that is right, and it is the silent inheritance nothing reports.
        XCTAssertEqual(addition.defaultMode, .studioLocked)
        XCTAssertTrue(addition.tempoRange.contains(addition.defaultTempo),
                      "a default tempo outside its own range is a picker that opens wrong")

        // The drag IS the genre, and it must stay under the pinned maximum.
        XCTAssertEqual(addition.swing, 0.22, accuracy: 0.0001)
        XCTAssertLessThan(addition.swing, MusicStyle.modalJazz.swing,
                          "modalJazz's 0.30 is pinned elsewhere as the largest offered swing; "
                          + "if this one passed it, that pin and this genre's case doc both move")

        // NOT a prohibition (#364): the day a slice gives this genre the table's first arm,
        // this line goes red and its message says what has to move with it.
        XCTAssertNil(addition.padGrammar,
                     "loFiHipHop now carries a pad figure. If that is the deliberate debut of "
                     + "`MusicStyle.padGrammar`'s FIRST arm, say so here and in this file's "
                     + "header — the table was empty for EVERY genre when this was written.")
    }

    // MARK: - Claim 7 — the echo, which is where this genre and boom bap would have blurred

    func testTheEchoIsAQuarterTripletAndResolvesAcrossTheWholeWindow() {
        let fx = addition.fxPreset
        XCTAssertTrue(fx.delayEnabled)
        XCTAssertEqual(fx.delayMode, .tape)
        XCTAssertEqual(fx.delaySync, TempoSyncOption(.quarter, .triplet))

        // ⭐ The separation that the fingerprint test cannot see: `boomBapHipHop` is ALSO a tape
        // delay, on a DOTTED EIGHTH. Taking that pair would have given the two arms one echo
        // with two labels — the #1349 lesson that a green fingerprint is the FLOOR, not the
        // question.
        XCTAssertNotEqual(fx.delaySync, MusicStyle.boomBapHipHop.fxPreset.delaySync,
                          "the two hip-hop arms now notate the same division on the same delay "
                          + "mode. One of them has to move, and the case doc says which and why")

        // `GenreDelaySyncResolvabilityTests` guards the roster; this pins THIS genre's own
        // window, because the ceiling is what makes a notated division a lie in the source.
        let ceiling = 2.0
        XCTAssertLessThan(fx.delaySync.seconds(bpm: addition.tempoRange.lowerBound), ceiling,
                          "the echo clamps at the SLOWEST tempo this genre allows")
        XCTAssertLessThan(fx.delaySync.seconds(bpm: addition.tempoRange.upperBound), ceiling,
                          "the echo clamps at the FASTEST tempo this genre allows")

        // No chorus, and it is deliberate: the wobble lives in the patch LFO (`lfoRate: 0.32`,
        // `vibDepth: 0.11`). A chain chorus would be a second implementation of one effect
        // (#416) and would smear the only thing holding the chord together.
        XCTAssertFalse(fx.chorusEnabled,
                       "a chorus was added to this chain. If that is deliberate, the patch's "
                       + "own LFO and vibrato are now doing the same job twice — say which one "
                       + "owns the wobble, here and at the \"Wobble Keys\" arm")
    }

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

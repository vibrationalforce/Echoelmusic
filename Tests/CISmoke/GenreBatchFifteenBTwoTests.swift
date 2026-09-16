// GenreBatchFifteenBTwoTests.swift
// Echoel — G15b-2's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchFifteenBOneTests` form. No source-text scan.
//
// ⭐ THE SEPARATION IS ONE CHORD, AND IT IS THE ONLY ONE OF ITS KIND IN THE FILE. `[0, 2, 4, 6]`
// on `.harmonicMinor` resolves to `[0, 3, 7, 11]` — a minor triad under a MAJOR seventh. Measured
// across all 55 genres' tonic stacks before this file was written: nobody else has it. Ten arms
// voice the ordinary minor seventh `[0, 3, 7, 10]`, four the major seventh `[0, 4, 7, 11]`, and
// this one lands between them. Claim 2 pins that, as a SWEEP over `allCases` rather than against
// a hardcoded list, so a later genre that picks the chord up reddens here instead of quietly
// halving the axis (the `GenreBatchFourVoicingTests` form).
//
// ⚠️ THE SHAPE IS NOT THE DECISION — THE SCALE IS, and claim 2 says so in two assertions rather
// than one. `[0, 2, 4, 6]` is the same four degrees eight other arms carry, because
// `GenreBatchFourVoicingTests` REQUIRES exactly that shape for every four-note genre but Detroit.
// Harmonic minor's raised seventh is the whole difference. A future "simplification" to `.minor`
// would leave the chordTones untouched, leave that guard green, and silently delete the genre's
// identity — claim 2's second half is aimed precisely there.
//
// ⚠️ THE NEAREST NEIGHBOURS ARE A TIE AT 3 OF 6 AXES, AND THE HEADER SAYS SO RATHER THAN NAMING A
// CLOSEST. `sciFi` shares beatArchetype/leadPatchName/padOctave; `stillMeditation` and
// `selfObservation` share leadPatchName/chordTones/padOctave. Measured, and deliberately not
// written as a superlative — #1350 shipped "the lead trimmed furthest of any arm here" while two
// arms sat lower. All three are `sustained` Flächen, so the `"Choir Vox"` overlap is NOMINAL: not
// one of them ever voices that patch. This genre BEARS it, which is why the lead ceiling counts
// it and they do not. Claim 4 pins the nominal-overlap fact, because it is the thing that makes
// the shared name harmless and it is invisible from the name alone.
//
// ⚠️ TWO measured deviations from the design sheet, each one bought a separation:
//   1. `progression: [0, 5, 4]` (sheet: `[0, 1]`). `[0, 1]` is already the most crowded pair in
//      the file — six genres, four of them offered, `sciFi` among them — so keeping it would have
//      put this genre at four shared axes with the one neighbour it already shares an archetype
//      with. `[0, 5, 4]` is free across the roster, and its point is degree 4: on harmonic minor
//      the V voices `[0, 4, 7]`, a MAJOR dominant, where natural minor gives `[0, 3, 7]`. Claim 3
//      pins the major V, which is the audible half of choosing this scale.
//   2. `chordTones: [0, 2, 4, 6]` (sheet: `[0, 2, 4]`). A triad on this scale is an ordinary minor
//      chord shared with twenty-two arms. The fourth degree is what makes the genre.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `swing: 0.16` ties `deepHouse`, `boomBapHipHop` and
// `nordicFiddle` exactly, so no swing claim is written. `delayFeedback: 0.44` takes no rank. The
// tempo window 60…76 overlaps `vaporwave`'s 60…80 almost completely and claim 5 pins the OVERLAP
// so nobody later writes the disjointness that would be false — they are both slowed half-time
// musics, and what separates them is the mode and the chord, not the clock.
//
// ⭐ EVERY NUMBER IN THE TWO NEW PATCH DOCS CAME FROM `scripts/genre-prebatch.py --patch` at full
// coverage (77 of 77 blocks). It caught one thing during this slice that a read would not have:
// `Drag Sub`'s `cutoff: 580` is NOT free — `Dust Sub` holds it too — so the arm names the tie and
// argues the separation on the four envelope values instead, all of which were measured. #1352's
// law, one slice on: check the sibling with the tool BEFORE arguing a separation from it.
//
// ⭐ AND THE DELAY CHOICE CAME FROM `--patch`'s neighbour, section 5, which #1353 taught to report
// the BINDING end of a tempo window. `tape` + a half note already carries three offered genres
// including `sciFi`; this arm takes `pingPong` + a dotted eighth, whose only other owner in the
// file (`synthwave`) is not offered. At 60…76 BPM that is 0.750…0.592 s — no clamp anywhere, so
// the echo tracks the body's tempo across the whole window. Claim 6 pins the combination and the
// resolvability at the SLOW end, which is the end that binds.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically, before a line of
// this file was written, is `python3 scripts/genre-prebatch.py`: lead ceiling (Choir Vox 7 → 8
// against a ceiling that stays 8), fingerprint (no two offered genres share the 7-tuple), patches
// (free ids 73, 74), voicing, tempo/delay, register and grammar ownership — all OK, re-run after
// the cut: **55 genres, 38 offered, 77 patches**, GenreFX arms parsed 55 of 55. The weak-key
// collision sweep over all 55 returned EMPTY. Beyond that, ALL 41 assertions were transcribed
// into Python and driven against the working tree: 41 green, 0 red — unusually complete for a §0
// pass, because this file's claims are values and set memberships rather than engine behaviour.
//
// ⛔ AND THE FIRST PUSH OF THIS FILE DID NOT COMPILE, WHILE THAT §0 PASS READ 41 GREEN. Both
// statements are true at once, and the pair is the lesson: `bassPatch` is `SynthPatch?`, and this
// file dereferenced it twice without unwrapping (`style.bassPatch.name`). A source-text mirror
// evaluates the CLAIM — "the bass patch is named Drag Sub", a fact about the tree, and correct —
// and can say nothing about the TYPE of the expression that asks the question.
// **A §0 transcription is evidence about the roster, never a compile verdict**, and printing it
// beside one invites exactly the reading that "41 green" retired the gate. It did not: CI/CD's
// `Build for Testing` on 10dd909 went RED and named this file. That is the gate working.
//
// ⛔ AND THE TRANSCRIPTION PRODUCED ONE FALSE RED, WHICH IS WORTH MORE THAN THE FORTY-ONE GREENS.
// It reported `progression [0, 5]` for an arm whose source says `[0, 5, 4]`. The code was right;
// the mirror was wrong — it anchored on the FIRST `case .slowedGothPop:` in the file, which is
// the SUBCATEGORY switch, and walked non-greedily into a different genre's `HarmonicProfile`.
// Two of its three parsed values happened to match what was expected, so it looked like a single
// isolated failure rather than a broken anchor. That is the THIRD time in this session a parser
// anchored on the wrong thing and nearly overturned correct source (a `$` that dropped a trailing
// comment; a block-cut that read 31 of 73 patches). The law is the same each time and it is why
// this note is in a file rather than a scratchpad: **measure your own tool before refuting the
// code**, and treat two agreeing values as a coincidence until the third is checked
// (`.claude/rules/context.md` §2, "two counts that agree are not a set comparison").
//
// Against the parent tree this file does not COMPILE
// — it names `MusicStyle.slowedGothPop` and `Subcategory.darkSynthScenes`, neither of which
// exists there — so **no assertion has a verdict on the parent** (§3); that is one absence, not
// forty-one (#486). The compile verdict is CI/CD's `Build for Testing`; until it lands, this
// file is UNPROVEN, not green. **41 assertions across seven claims** (1 = 7 · 2 = 6 · 3 = 5 ·
// 4 = 5 · 5 = 6 · 6 = 7 · 7 = 5) — counted mechanically, not estimated, so a later reader can
// tell at a glance whether the file has been edited without its header being pulled along
// (#1334). Three of the counts are loop bodies over three siblings each, so the STATEMENT count
// is the tally and the executed count is higher.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFifteenBTwoTests: XCTestCase {

    // MARK: - 1 · The genre exists, is offered, and stands on its own shelf

    func testTheGenreIsOfferedOnItsOwnShelf() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.displayName, "Slowed Goth Pop")
        XCTAssertTrue(MusicStyle.offered.contains(style),
                      "a genre nobody can choose is not shipped")
        XCTAssertEqual(style.subcategory, .darkSynthScenes)
        XCTAssertEqual(MusicStyle.Subcategory.darkSynthScenes.parent, .underground)
        XCTAssertEqual(MusicStyle.Subcategory.darkSynthScenes.title, "Dark Synth Scenes",
                       "the picker RENDERS this string — it is the one title a player reads")

        // The shelf must not be an empty drawer: an unpopulated subcategory is skipped by the
        // picker, so nothing looks wrong while the genre is unreachable through it.
        let residents = MusicStyle.offered.filter { $0.subcategory == .darkSynthScenes }
        XCTAssertEqual(residents, [.slowedGothPop])

        // And the rubric's shelves must stay contiguous — declaring the case anywhere else in
        // `allCases` splits `.underground` across the menu.
        let undergroundShelves = MusicStyle.Subcategory.allCases.filter { $0.parent == .underground }
        XCTAssertEqual(undergroundShelves, [.loFiHazy, .dubEchoes, .darkSynthScenes])
    }

    // MARK: - 2 · The minor-major seventh, and that the SCALE is what makes it

    func testTheTonicChordIsTheOnlyMinorMajorSeventhInTheRoster() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.scale, .harmonicMinor)
        XCTAssertEqual(style.harmonicProfile.chordTones, [0, 2, 4, 6])
        XCTAssertEqual(semitoneStack(of: style), [0, 3, 7, 11],
                       "minor third, fifth, MAJOR seventh — the chord the genre is named for")

        // A SWEEP, not a list: any later genre that lands on this stack reddens here.
        let sharers = MusicStyle.allCases.filter {
            $0 != style && semitoneStack(of: $0) == [0, 3, 7, 11]
        }
        XCTAssertTrue(sharers.isEmpty,
                      "the minor-major seventh is now shared with "
                      + "\(sharers.map(\.rawValue).sorted()) — it is this genre's whole "
                      + "separation, so either give the newcomer its own chord or rewrite both "
                      + "docs")

        // ⛔ The half that a `chordTones` assertion alone would miss. The shape is ordinary; the
        // scale is not. Swapping `.harmonicMinor` for `.minor` leaves the shape untouched, leaves
        // `GenreBatchFourVoicingTests` green, and turns the chord into the plain minor seventh
        // ten other arms already carry.
        let onNaturalMinor = MusicalKey(root: 0, scale: .minor)
        let profile = style.harmonicProfile
        let naturalRoot = onNaturalMinor.degree(profile.chordTones[0], octave: profile.padOctave)
        let naturalStack = profile.chordTones.map {
            onNaturalMinor.degree($0, octave: profile.padOctave) - naturalRoot
        }
        XCTAssertEqual(naturalStack, [0, 3, 7, 10],
                       "the SAME chordTones on natural minor give the ordinary seventh — which is "
                       + "why the scale, not the shape, is this genre's decision")
        XCTAssertNotEqual(naturalStack, semitoneStack(of: style))
    }

    // MARK: - 3 · The major dominant, which is the other half of harmonic minor

    func testTheDominantIsMajorWhereNaturalMinorWouldGiveAMinorOne() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.harmonicProfile.progression, [0, 5, 4])

        // Free across the roster — measured as a sweep so a later arm taking it reddens here.
        let sharers = MusicStyle.allCases.filter {
            $0 != style && $0.harmonicProfile.progression == [0, 5, 4]
        }
        XCTAssertTrue(sharers.isEmpty,
                      "i → ♭VI → V is now shared with \(sharers.map(\.rawValue).sorted())")

        let key = MusicalKey(root: 0, scale: .harmonicMinor)
        let octave = style.harmonicProfile.padOctave
        func triad(_ rootDegree: Int, _ k: MusicalKey) -> [Int] {
            let root = k.degree(rootDegree, octave: octave)
            return [0, 2, 4].map { k.degree(rootDegree + $0, octave: octave) - root }
        }
        XCTAssertEqual(triad(0, key), [0, 3, 7], "the tonic is minor")
        XCTAssertEqual(triad(4, key), [0, 4, 7], "the dominant is MAJOR — the raised seventh")
        XCTAssertEqual(triad(4, MusicalKey(root: 0, scale: .minor)), [0, 3, 7],
                       "and on natural minor the same degree is minor, which is the contrast the "
                       + "progression was chosen for")
    }

    // MARK: - 4 · The lead is BORNE, and the overlap with its namesakes is nominal

    func testTheLeadIsBorneWhileEveryNamesakeLeavesItUnvoiced() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.leadPatchName, "Choir Vox")
        XCTAssertFalse(style.harmonicProfile.sustained,
                       "this genre VOICES its lead — that is why the pigeonhole ceiling counts it")
        XCTAssertFalse(MusicStyle.sustainedFlächen.contains(style))

        // The three nearest neighbours by shared axes all name the same patch and none sounds it.
        for namesake in [MusicStyle.sciFi, .stillMeditation, .selfObservation] {
            XCTAssertEqual(namesake.leadPatchName, "Choir Vox")
            XCTAssertTrue(namesake.harmonicProfile.sustained,
                          "\(namesake.rawValue) is a sustained Fläche, so its lead patch is never "
                          + "voiced — if that changes, the shared name stops being harmless and "
                          + "this genre needs a different one")
        }
    }

    // MARK: - 5 · The clock: half-time, and an overlap that is pinned rather than denied

    func testTheTempoWindowOverlapsVaporwaveAndThatIsDeliberate() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.beatArchetype, .halfTime)
        XCTAssertEqual(style.tempoRange, 60...76)
        XCTAssertEqual(style.defaultTempo, 66)
        XCTAssertTrue(style.tempoRange.contains(style.defaultTempo))

        XCTAssertTrue(style.tempoRange.overlaps(MusicStyle.vaporwave.tempoRange),
                      "these windows overlap almost completely and that is on purpose — both are "
                      + "slowed half-time musics. Nothing here may claim they are separated by "
                      + "tempo; the chord and the mode separate them.")
        XCTAssertNotEqual(style.scale, MusicStyle.vaporwave.scale)
    }

    // MARK: - 6 · The echo: a combination nobody offered holds, resolving at the binding end

    func testTheEchoIsAPingPongDottedEighthThatNeverClamps() {
        let fx = MusicStyle.slowedGothPop.fxPreset
        XCTAssertTrue(fx.delayEnabled)
        XCTAssertEqual(fx.delayMode, .pingPong)
        XCTAssertEqual(fx.delaySync, TempoSyncOption(.eighth, .dotted))

        // Not `sciFi`'s echo — the one genre it shares an archetype with.
        XCTAssertNotEqual(fx.delaySync, MusicStyle.sciFi.fxPreset.delaySync)
        XCTAssertNotEqual(fx.delayMode, MusicStyle.sciFi.fxPreset.delayMode)

        // #1353: the SLOW end is the one that binds, so that is the end asserted.
        let slowest = fx.delaySync.seconds(bpm: MusicStyle.slowedGothPop.tempoRange.lowerBound)
        XCTAssertEqual(slowest, 0.75, accuracy: 1e-6)
        XCTAssertLessThan(slowest, 2.0,
                          "a dotted eighth at 60 BPM must resolve un-clamped, or the notated "
                          + "division is not what a listener would hear")
    }

    // MARK: - 7 · The two voices are this genre's own

    func testTheTwoPatchesAreThisGenresOwn() {
        let style = MusicStyle.slowedGothPop
        XCTAssertEqual(style.synthPatch.name, "Dragged Choir")

        // `bassPatch` is OPTIONAL — a genre may carry none. Unwrapped rather than forced: a
        // `sparseSub` owner with no bass patch would fall back to another genre's voice, which
        // is precisely what the rest of this claim exists to forbid.
        guard let bass = style.bassPatch else {
            return XCTFail("slowedGothPop has no bassPatch — `sparseSub` would then play on a "
                           + "voice this genre does not own")
        }
        XCTAssertEqual(bass.name, "Drag Sub")

        // Figure shared, voice never: the sixth `sparseSub` owner, on a bass nobody else plays.
        XCTAssertEqual(style.bassGrammar, .sparseSub)
        let otherSparse = MusicStyle.allCases.filter {
            $0 != style && $0.bassGrammar == .sparseSub
        }
        XCTAssertFalse(otherSparse.isEmpty, "the figure is meant to be shared")
        for sibling in otherSparse {
            XCTAssertNotEqual(sibling.bassPatch?.name, bass.name,
                              "\(sibling.rawValue) now plays this genre's bass VOICE — the "
                              + "grammar is shareable, the patch is not")
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

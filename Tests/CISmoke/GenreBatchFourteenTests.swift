// GenreBatchFourteenTests.swift
// Echoel — G14's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchFifteenBTwoTests` form. No source-text scan.
//
// ⭐ THE SEPARATION IS THE SCALE, AND IT IS A MUSICAL DECISION BEFORE IT IS AN ARITHMETIC ONE.
// `progression: [0, 4]` — roots i → V — on `.harmonicMinor` voices degree 4 as `[0, 4, 7]`, a
// MAJOR dominant; the same two roots on natural minor give `[0, 3, 7]`, a minor v. The i → V7
// turn IS cumbia, so the scale follows the harmony. Claim 2 pins both halves, and pins the
// contrast against `deepHouse` specifically, because it is one of the two genres that share
// four of this one's seven identity axes and the only one of the two on natural minor — so the
// minor v is exactly what the shared archetype, register, bass figure and lead name do NOT tell
// them apart by.
//
// ⚠️ THE ARITHMETIC AGREES AND THAT IS A CONSEQUENCE, NOT THE REASON — but it is the half a guard
// can hold, so claim 3 holds it. On `.minor` this genre would have shared FIVE of seven identity
// axes with `deepHouse` (scale, archetype, lead name, register, bass figure): the same
// five-of-seven, against the same neighbour, that forced `dubEcho` off "Soft Keys" in #1352.
// Measured over all 703 offered pairs in the parent tree, 25 of 38 genres sat at a worst
// neighbour of four and only six at five — four is the ordinary band, five is the tail. Claim 3
// asserts this genre's worst OFFERED neighbour is at most four, as a sweep. It does not assert a
// bound for the roster (#364: six shipped genres are at five and are correct).
//
// ⚠️ AT FOUR IT IS A TIE AND NOT A NEAREST — `deepHouse` (archetype, lead name, register,
// bass figure) and `afroHouse` (archetype, chord tones, register, bass figure) both sit there,
// and #1350's lesson is why that is written out: that slice shipped "the lead trimmed furthest
// of any arm here" while two arms sat lower. Claim 3's second assertion names `deepHouse`
// because the case doc's separation argument is built against it, not because it is alone.
//
// ⚠️ THE LEAD NAME IS NOT FORCED HERE AND THE HEADER SAYS SO rather than dressing an ear call as
// arithmetic. All three names with ceiling headroom ("Deep Sub", "Soft Keys", "Warm Strings")
// land at four, so the numbers pick none of them; "Soft Keys" is chosen because cumbia sonidera
// is organ-and-keyboard music. `leadDensity` is 0.0, so it resolves a factory voice rather than
// sounding a line — which is why no claim in this file calls it a sound.
//
// ⭐ AND THE CROSS-SLICE CLAIM IS THE ONE WORTH MOST. This genre is the FOURTH arm on
// `.harmonicMinor` and the SECOND offered one, so it lands on the scale #1354 shipped
// `slowedGothPop` on. That slice's whole separation is its TONIC CHORD — `[0, 3, 7, 11]`, the
// only minor-major seventh in the roster, pinned there as a sweep over `allCases`. A triad on
// this scale is a plain `[0, 3, 7]`, so nothing is taken; claim 4 asserts that from THIS side
// too, because the day someone widens this genre's `chordTones` to four degrees the neighbour's
// guard goes red in a file that says nothing about cumbia. Two guards, one fact, and this is the
// half that names the cause.
//
// ⚠️ TWO measured deviations from the design sheet, each bought a separation:
//   1. `.harmonicMinor` (sheet: `.minor`) — the major V above, and the five-of-seven above.
//   2. `TempoSyncOption(.sixteenth)` on `.tape` (sheet: a bare quarter-note division). Measured
//      across all 56 arms of `GenreFX`: `tape` appears with the half, the quarter and the
//      eighth and NEVER with a sixteenth, so this pair is the file's first — the way #1350
//      opened `(.quarter, .triplet)`. Both near misses were crowded: `digital` + straight
//      sixteenth carries five arms including the un-offered `ska`, which shares this genre's
//      archetype, and `pingPong` + straight sixteenth is `psyProgHouse`'s. Claim 6 pins it.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `swing: 0.12` ties `techHouse` and the un-offered `trap`
// exactly, so no swing claim is written. `mixLevels` is a free triple and takes no rank.
// `delayFeedback: 0.30` takes no rank. The tempo window OVERLAPS `andalusianCadence` (90…130)
// and the un-offered `klezmer` (90…170) and `rocksteady` (80…110), and claim 5 pins the overlap
// with `andalusianCadence` so nobody later writes a disjointness that would be false — what
// separates those two is scale, lead voice, progression and bass figure, not the clock.
//
// ⭐ EVERY NUMBER IN THE TWO NEW PATCH DOCS CAME FROM `scripts/genre-prebatch.py --patch` at full
// coverage (77 of 77 blocks in the parent tree). It caught the thing a read would have missed:
// `Lilt Sub`'s `cutoff: 660` is NOT free — `Drone Sub` holds it too — so the arm names the tie
// and argues the separation on attack, sustain, release and envelope total, all measured. It
// also caught a claim of MINE, which is why this sentence is here: a first draft of that arm
// wrote `Drone Sub`'s envelope from memory as 0.030/0.90/0.88/0.55 and every one of the four was
// wrong (0.09/0.40/0.92/0.60). #1352's law, two slices on: check the sibling with the tool
// BEFORE arguing a separation from it.
//
// ⛔ AND A SECOND CLAIM OF MINE WAS WRONG THE SAME WAY, IN `MusicStyle` ITSELF. The `tempoRange`
// comment first said this window "clears every other `.offbeat` window except `andalusianCadence`
// (96…120)". Measured: that genre's window is 90…130, and there are THREE overlaps, not one. Both
// slips were written into a file, both were caught by measuring before the commit, and neither
// would have reddened any guard — which is the argument for claim 5 existing at all.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically, before a line of
// this file was written, is `python3 scripts/genre-prebatch.py`: lead ceiling (Soft Keys 7 → 8
// against a ceiling that stays 8), fingerprint (no two offered genres share the 7-tuple), patches
// (free ids 75, 76), voicing, tempo/delay at the BINDING end, register and grammar ownership —
// all OK, re-run after the cut: **56 genres, 39 offered, 79 patches**, GenreFX arms parsed 56 of
// 56. All eight repo checkers are green. Beyond that, 39 of the 40 assertions were transcribed
// into Python and driven against BOTH trees: 39 green / 0 red on the working tree, and on the
// parent a single reported ABSENCE (`cumbia` does not exist there) rather than 39 reds. The
// fortieth is claim 7's second in-loop assertion, folded into one set comparison in the mirror
// because a per-sibling loop adds no evidence there — said out loud rather than rounded up.
//
// ⛔ A §0 TRANSCRIPTION IS EVIDENCE ABOUT THE ROSTER, NEVER A COMPILE VERDICT (#1355). The
// previous slice's mirror read 41 of 41 green on a file that did not compile: a source-text
// mirror evaluates the CLAIM, never the TYPE of the expression that asks it. Every type this
// file touches was therefore read from source before it was written — in particular
// `bassPatch` is `SynthPatch?` and claim 7 unwraps it, `bassGrammar` is `BassGrammar?`, and
// `tempoRange` is `ClosedRange<Double>`.
//
// Against the parent tree this file does not COMPILE — it names `MusicStyle.cumbia` and
// `Subcategory.latinAmerica`, neither of which exists there — so **no assertion has a verdict on
// the parent** (§3); that is one absence, not forty (#486). The compile verdict is CI/CD's
// `Build for Testing`; until it lands, this file is UNPROVEN, not green. **40 assertions across
// seven claims** (1 = 6 · 2 = 6 · 3 = 2 · 4 = 5 · 5 = 6 · 6 = 8 · 7 = 7) — counted mechanically,
// not estimated, so a later reader can tell at a glance whether the file has been edited without
// its header being pulled along (#1334). Two of the counts are loop bodies, so the STATEMENT
// count is the tally and the executed count is higher.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFourteenTests: XCTestCase {

    // MARK: - 1 · The genre exists, is offered, and stands on a new shelf under `.folk`

    func testTheGenreIsOfferedOnItsOwnShelf() {
        let style = MusicStyle.cumbia
        XCTAssertEqual(style.displayName, "Cumbia")
        XCTAssertTrue(MusicStyle.offered.contains(style),
                      "a genre nobody can choose is not shipped")
        XCTAssertEqual(style.subcategory, .latinAmerica)
        XCTAssertEqual(MusicStyle.Subcategory.latinAmerica.title, "Latin America",
                       "the picker RENDERS this string — it is the one title a player reads")

        // Filed under `.folk` and not `.caribbean`. That rubric already holds two REGION
        // shelves, which is the shape a third region belongs in; `.caribbean` holds one
        // lineage (`rootsReggae`, `ska`, `rocksteady` are all Jamaican sound-system music).
        XCTAssertEqual(MusicStyle.Subcategory.latinAmerica.parent, .folk)

        // The rubric's shelves must stay contiguous — declaring the case anywhere else in
        // `allCases` splits `.folk` across the menu.
        let folkShelves = MusicStyle.Subcategory.allCases.filter { $0.parent == .folk }
        XCTAssertEqual(folkShelves, [.europeanFolk, .nearEastCentralAsia, .latinAmerica])
    }

    // MARK: - 2 · The major dominant, which is what choosing harmonic minor is FOR

    func testTheDominantIsMajorWhereNaturalMinorWouldGiveAMinorOne() {
        let style = MusicStyle.cumbia
        XCTAssertEqual(style.scale, .harmonicMinor)
        XCTAssertEqual(style.harmonicProfile.progression, [0, 4])

        let octave = style.harmonicProfile.padOctave
        func triad(_ rootDegree: Int, _ key: MusicalKey) -> [Int] {
            let root = key.degree(rootDegree, octave: octave)
            return [0, 2, 4].map { key.degree(rootDegree + $0, octave: octave) - root }
        }
        let harmonic = MusicalKey(root: 0, scale: .harmonicMinor)
        XCTAssertEqual(triad(0, harmonic), [0, 3, 7], "the tonic is minor")
        XCTAssertEqual(triad(4, harmonic), [0, 4, 7],
                       "the dominant is MAJOR — the raised seventh, and the reason this genre is "
                       + "not on natural minor")
        XCTAssertEqual(triad(4, MusicalKey(root: 0, scale: .minor)), [0, 3, 7],
                       "on natural minor the same degree is minor, which is the deep-house and "
                       + "dub sound rather than this one")

        // The neighbour this contrast is aimed at: same archetype, same register, same bass
        // figure, same lead name — and a minor v, because it is on natural minor.
        XCTAssertEqual(MusicStyle.deepHouse.scale, .minor)
    }

    // MARK: - 3 · The crowding the scale bought off, as a sweep

    func testNoOfferedGenreSharesMoreThanFourIdentityAxes() {
        let style = MusicStyle.cumbia
        func axes(_ s: MusicStyle) -> [String] {
            let p = s.harmonicProfile
            return ["\(s.scale)", "\(s.beatArchetype)", s.leadPatchName,
                    "\(p.progression)", "\(p.chordTones)", "\(p.padOctave)",
                    "\(String(describing: s.bassGrammar))"]
        }
        let mine = axes(style)
        var worst = 0
        var worstNames: [String] = []
        for other in MusicStyle.offered where other != style {
            let shared = zip(mine, axes(other)).filter { $0.0 == $0.1 }.count
            if shared > worst { worst = shared; worstNames = [other.rawValue] }
            else if shared == worst { worstNames.append(other.rawValue) }
        }
        XCTAssertLessThanOrEqual(worst, 4, """
            cumbia now shares \(worst) of seven identity axes with \(worstNames.sorted()). \
            On `.minor` it shared five with deepHouse — scale, archetype, lead name, register \
            and bass figure — which is the same five-of-seven that forced `dubEcho` off "Soft \
            Keys" in #1352, against the same neighbour. The scale is what bought it down; if an \
            axis here has to change, change one of those five and pull the case doc along.
            """)
        XCTAssertTrue(worstNames.contains("deepHouse"), """
            deepHouse dropped out of the worst-neighbour set \(worstNames.sorted()). At four it \
            is a TIE with afroHouse rather than a nearest — but the case doc builds its \
            separation argument against deepHouse specifically (scale, progression, a window 16 \
            BPM clear), so if it is no longer there the doc needs rewriting, not this line.
            """)
    }

    // MARK: - 4 · The neighbour on this scale keeps its chord

    func testThisGenreDoesNotTakeSlowedGothPopsTonicChord() {
        let style = MusicStyle.cumbia
        XCTAssertEqual(style.harmonicProfile.chordTones, [0, 2, 4])
        XCTAssertEqual(semitoneStack(of: style), [0, 3, 7],
                       "a plain minor triad — shared with twenty-two arms and claiming nothing")

        // #1354's separation is `[0, 3, 7, 11]` and it is pinned there as a sweep over
        // `allCases`. This genre is the second OFFERED arm on the same scale, so the day its
        // chordTones grow a fourth degree that guard reddens in a file that never mentions
        // cumbia. This assertion names the cause from the other side.
        XCTAssertEqual(MusicStyle.slowedGothPop.scale, style.scale)
        XCTAssertEqual(semitoneStack(of: .slowedGothPop), [0, 3, 7, 11])
        XCTAssertNotEqual(semitoneStack(of: style), semitoneStack(of: .slowedGothPop),
                          "two genres on one scale with one tonic chord is a chord with two "
                          + "labels")
    }

    // MARK: - 5 · The clock: an overlap pinned rather than denied

    func testTheTempoWindowOverlapsAndalusianCadenceAndClearsDeepHouse() {
        let style = MusicStyle.cumbia
        XCTAssertEqual(style.beatArchetype, .offbeat)
        XCTAssertEqual(style.tempoRange, 88...104)
        XCTAssertEqual(style.defaultTempo, 96)
        XCTAssertTrue(style.tempoRange.contains(style.defaultTempo))

        XCTAssertFalse(style.tempoRange.overlaps(MusicStyle.deepHouse.tempoRange),
                       "deepHouse (120…126) is the four-of-seven neighbour and the clock is one "
                       + "of the three things that separate them — if these windows ever meet, "
                       + "the case doc's separation argument loses a third of its weight")

        XCTAssertTrue(style.tempoRange.overlaps(MusicStyle.andalusianCadence.tempoRange), """
            these windows overlap (90…130 against 88…104) and that is on purpose. Nothing here \
            may claim they are separated by tempo; scale, lead voice, progression and bass \
            figure separate them.
            """)
    }

    // MARK: - 6 · The echo: a mode-and-division pair nobody else in the file holds

    func testTheEchoIsATapeSixteenthNobodyElseCarries() {
        let style = MusicStyle.cumbia
        let fx = style.fxPreset
        XCTAssertTrue(fx.delayEnabled)
        XCTAssertEqual(fx.delayMode, .tape)
        XCTAssertEqual(fx.delaySync, TempoSyncOption(.sixteenth))

        // A SWEEP, not a list: any later arm taking this exact pair reddens here.
        let sharers = MusicStyle.allCases.filter {
            $0 != style && $0.fxPreset.delayEnabled
                && $0.fxPreset.delayMode == .tape
                && $0.fxPreset.delaySync == TempoSyncOption(.sixteenth)
        }
        XCTAssertTrue(sharers.isEmpty,
                      "tape + a straight sixteenth is now shared with "
                      + "\(sharers.map(\.rawValue).sorted()) — it was this file's first use, so "
                      + "either give the newcomer its own pair or rewrite both docs")

        // Not the crowded near misses: `ska` shares this genre's archetype and takes the
        // digital sixteenth; `psyProgHouse` takes the ping-pong one.
        XCTAssertNotEqual(fx.delayMode, MusicStyle.ska.fxPreset.delayMode)
        XCTAssertNotEqual(fx.delayMode, MusicStyle.psyProgHouse.fxPreset.delayMode)

        // #1353: the SLOW end is the one that binds, so that is the end asserted.
        let slowest = fx.delaySync.seconds(bpm: style.tempoRange.lowerBound)
        XCTAssertEqual(slowest, 60.0 / 88.0 / 4.0, accuracy: 1e-6)
        XCTAssertLessThan(slowest, 2.0,
                          "a sixteenth at 88 BPM must resolve un-clamped, or the notated "
                          + "division is not what a listener would hear")
    }

    // MARK: - 7 · The two voices are this genre's own

    func testTheTwoPatchesAreThisGenresOwn() {
        let style = MusicStyle.cumbia
        XCTAssertEqual(style.synthPatch.name, "Lilt Keys")

        // `bassPatch` is OPTIONAL — a genre may carry none. Unwrapped rather than forced: an
        // `offbeatEighths` owner with no bass patch would fall back to another genre's voice,
        // which is precisely what the rest of this claim exists to forbid. (#1355: the previous
        // slice shipped this line forced, and the §0 mirror could not see it.)
        guard let bass = style.bassPatch else {
            return XCTFail("cumbia has no bassPatch — `offbeatEighths` would then play on a "
                           + "voice this genre does not own")
        }
        XCTAssertEqual(bass.name, "Lilt Sub")

        // Figure shared, voice never: the sixth `offbeatEighths` owner, on a bass nobody plays.
        XCTAssertEqual(style.bassGrammar, .offbeatEighths)
        let otherOffbeat = MusicStyle.allCases.filter {
            $0 != style && $0.bassGrammar == .offbeatEighths
        }
        XCTAssertFalse(otherOffbeat.isEmpty, "the figure is meant to be shared")
        for sibling in otherOffbeat {
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

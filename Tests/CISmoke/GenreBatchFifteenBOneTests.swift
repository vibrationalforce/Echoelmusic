// GenreBatchFifteenBOneTests.swift
// Echoel — G15b-1's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchFifteenATests` form. No source-text scan.
//
// ⭐ THIS SLICE DEBUTS A SHELF, AND THE SHELF IS NAMED FOR WHAT IT HOLDS. The design plan calls
// it "Dub & Drone"; it ships as **"Dub & Echo"**, and the change is the #1349 lesson applied one
// level down. G10a shipped a RUBRIC titled "Chant, Choir & Drone" holding one gospel choir, and
// the only thing that made that tolerable is that `Category.title` has ZERO production readers.
// `Subcategory.title` is the opposite — the genre picker renders it as a section header — so a
// shelf named for a drone it does not hold is an over-claim a player reads. `droneMetal`, the
// intended second resident, is blocked on the `PadGrammar.pedalDrone` mechanism debut anyway,
// and it belongs beside the other pedal-drone genres rather than beside dub. Claim 1 pins the
// title and claim 7 pins that the shelf is not an empty drawer.
//
// ⚠️ THE TWO NEAREST ARE `rootsReggae` AND `deepHouse`, both at FOUR of the seven identity axes,
// and against `rootsReggae` they are the same four: `minor`, `.offbeat`, `offbeatEighths`,
// `padOctave 3`. That quartet IS dub — a minor skank over an offbeat bass, low — so it is shared
// on purpose and no attempt is made to break it. Claims 3 and 4 pin what does separate them.
//
// ⚠️ TWO measured deviations from the design sheet, each one bought a separation:
//   1. `leadPatchName: "Hollow Reed"` (sheet: "Soft Keys"). This one IS forced, by two
//      independent constraints at once: "Soft Keys" puts this genre at FIVE of seven against
//      `deepHouse`, and "Pluck" — the other musical fit — already stands at 8 against a
//      pigeonhole ceiling of 8 and would break it. "Deep Sub" lands at five against
//      `rootsReggae`. The reed bucket is also the honest one: dub comps on an organ or a
//      melodica, never a piano.
//   2. `progression: [0, 6]` (sheet: `[0, 5]`). Roots i → ♭VII, the idiomatic dub turnaround;
//      `[0, 5]` is `boomBapHipHop`'s own and keeping it would have put a THIRD genre on four
//      shared axes for nothing.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. The tempo windows of this genre and `rootsReggae` overlap
// almost completely (66…82 against 68…84) and claim 3 pins the overlap so nobody writes the
// disjointness that would be false — these are the same music one generation apart. `swing: 0.18`
// ties `celticAir`, `soulBallad` and `ska` exactly, so no swing superlative is written. The delay
// DIVISION (`.tape` on a plain `.half`) is shared with `sciFi`, `doom` and `selfObservation`;
// none is a near neighbour, so the division claims nothing and claim 6 asserts the FEEDBACK
// depth instead, which is what separates this echo from `rootsReggae`'s.
//
// ⭐ EVERY NUMBER IN THE TWO NEW PATCH DOCS CAME FROM `scripts/genre-prebatch.py --patch`, the
// mode #1351 added, and it caught a real defect DURING this slice: the first "Dub Sub" draft
// shared THREE of four envelope values with `rootsReggae`'s bass patch — and the comment arguing
// the separation named that patch "Roots Sub" when it is called "Roll Sub". A near-duplicate
// voice for the one other genre that walks the same figure, defended by a sentence about a patch
// that does not exist. The law is written at the arm: check the sibling with the tool BEFORE
// arguing a separation from it.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types a
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416). What WAS driven mechanically, before a line of
// this file was written, is `python3 scripts/genre-prebatch.py`: lead ceiling (Hollow Reed 7 → 8
// against a ceiling that stays 8), fingerprint (no two offered genres share the 7-tuple), patches
// (free ids 71, 72), voicing, tempo/delay (a half note resolves at BOTH ends of 66…82), register
// and grammar ownership — all OK, re-run after the cut: **54 genres, 37 offered, 75 patches**.
// The weak-key collision sweep over all 54 returned EMPTY. Against the parent tree this file does
// not COMPILE — it names `MusicStyle.dubEcho` and `Subcategory.dubEchoes`, neither of which
// exists there — so **no assertion has a verdict on the parent** (§3); that is one absence, not
// forty-six (#486). The compile verdict is CI/CD's `Build for Testing`; until it lands, this file
// is UNPROVEN, not green. **46 assertions across seven claims** (1 = 8 · 2 = 6 · 3 = 8 · 4 = 6 ·
// 5 = 5 · 6 = 8 · 7 = 5) — the tally, so a later reader can tell at a glance whether the file
// still makes the claims its header describes (#1334).
//
// NEEDS-FOUNDER-VERIFY: Dub Echo at 72 in Loop mode, A/B against Roots Reggae at 76. Two ear
// questions, both about the echo. (1) At feedback 0.52 on a half note, does the third repeat sit
// UNDER the next stab or does the bar turn to mud? (2) Does "Echo Stab" (sustain 0.22, release
// 0.35) leave enough room for the repeats, or does the voice itself need to be shorter still? If
// (1) fails the fix is the feedback, not the mix — the mix is at a measured free value and the
// feedback deliberately stops short of `dubTechno`'s 0.58, which is the roster maximum.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFifteenBOneTests: XCTestCase {

    private let addition: MusicStyle = .dubEcho

    // MARK: - Claim 1 — the door, and the shelf it debuts

    func testTheFirstDubEchoDoorIsOpen() {
        XCTAssertTrue(MusicStyle.offered.contains(addition),
                      "dubEcho is built but not offered — a doorless genre (#254), and here it "
                      + "would also leave the shelf it debuts standing empty")
        XCTAssertEqual(addition.category, .underground)
        XCTAssertEqual(addition.subcategory, .dubEchoes)
        XCTAssertTrue(addition.category.offeredGenres.contains(addition))
        XCTAssertTrue(addition.subcategory.offeredGenres.contains(addition))
        XCTAssertEqual(addition.displayName, "Dub Echo")
        XCTAssertFalse(addition.lineage.isEmpty)

        // Counterweight (#343): the rubric must still hold the shelf it had, or claim 1 stays
        // green on a tree where this slice replaced `.loFiHazy` instead of joining it.
        XCTAssertTrue(MusicStyle.Category.underground.subcategories.contains(.loFiHazy),
                      "`.loFiHazy` left the `.underground` rubric this shelf was added beside")
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, never in degree numbers

    func testTheStackIsAMinorSeventhAndTheTurnaroundIsFlatSeven() {
        // ⭐ `[0, 2, 4, 6]` is NOT semitones — the #1286 trap. Resolved through `MusicalKey.degree`
        // on minor `[0,2,3,5,7,9,10]` it is 0, 3, 7, 10: the minor seventh, the stack fourteen
        // other arms carry. It is NOT what separates this genre, which is the point.
        XCTAssertEqual(semitoneStack(of: addition), [0, 3, 7, 10],
                       "the stabbed minor seventh is the chord this genre throws into the delay")
        XCTAssertEqual(addition.harmonicProfile.chordTones, [0, 2, 4, 6])
        XCTAssertEqual(addition.harmonicProfile.progression, [0, 6],
                       "i → ♭VII, the dub turnaround. `composeHarmonic` ROTATES over "
                       + "progressionPhase, so this is a PAIR of roots opening on the tonic, "
                       + "never a score (#1290)")
        XCTAssertEqual(addition.scale, .minor)
        XCTAssertFalse(addition.harmonicProfile.arpeggiated,
                       "the stab is a struck block; the ECHO is what turns one block into a "
                       + "figure, and a rolled stack would compete with the repeats")
        XCTAssertEqual(addition.harmonicProfile.leadDensity, 0,
                       "leadDensity moved off zero. If that is deliberate the `lineage` line may "
                       + "now name a melodic voice — plan §2b-9 forbids it only while this is 0")
    }

    // MARK: - Claim 3 — the same family, one generation apart

    func testItIsSeparatedFromRootsReggaeOnVoicingTurnaroundAndEcho() {
        let roots = MusicStyle.rootsReggae

        // The PREMISES (#343): all four shared axes. If any moved, the header's neighbour
        // measurement is stale, not merely this line.
        XCTAssertEqual(roots.scale, addition.scale)
        XCTAssertEqual(roots.beatArchetype, addition.beatArchetype)
        XCTAssertEqual(roots.bassGrammar, addition.bassGrammar)
        XCTAssertEqual(roots.harmonicProfile.padOctave, addition.harmonicProfile.padOctave)

        // Axis 1 — the voicing: a plain triad against a seventh.
        XCTAssertNotEqual(addition.harmonicProfile.chordTones, roots.harmonicProfile.chordTones)
        // Axis 2 — the turnaround.
        XCTAssertNotEqual(addition.harmonicProfile.progression, roots.harmonicProfile.progression)
        // Axis 3 — the echo, which is the genre. Asserted as an ORDER, not a value: both arms
        // are free numbers today and either may be retuned, but dub must stay the deeper one.
        XCTAssertGreaterThan(addition.fxPreset.delayFeedback, roots.fxPreset.delayFeedback,
                             "dub is roots reggae with the echo turned up; if this inverts, the "
                             + "two arms' docs and this file's header all argue the wrong way")

        // ⚠️ NOT an axis, and asserted so nobody promotes it to one: the tempo windows OVERLAP
        // almost completely (66…82 against 68…84). These are the same music, and that is right.
        XCTAssertTrue(addition.tempoRange.contains(roots.tempoRange.lowerBound),
                      "the tempo overlap this file documents is gone. If the windows became "
                      + "disjoint, remove the warning here and in the case doc — a warning about "
                      + "a condition that no longer holds is the #364 defect")
    }

    // MARK: - Claim 4 — the other four-axis neighbour, at twice the tempo

    func testItIsSeparatedFromDeepHouseOnRegisterAndTempo() {
        let house = MusicStyle.deepHouse

        XCTAssertEqual(house.scale, addition.scale)
        XCTAssertEqual(house.beatArchetype, addition.beatArchetype)
        XCTAssertEqual(house.bassGrammar, addition.bassGrammar)

        XCTAssertNotEqual(addition.harmonicProfile.padOctave, house.harmonicProfile.padOctave,
                          "the register is one of only three axes separating these two; dub sits "
                          + "low on purpose")
        XCTAssertNotEqual(addition.harmonicProfile.progression, house.harmonicProfile.progression)
        // Against THIS genre the windows are genuinely disjoint — unlike claim 3's.
        XCTAssertLessThan(addition.tempoRange.upperBound, house.tempoRange.lowerBound,
                          "the disjointness is claimed against deepHouse ONLY; see claim 3 for "
                          + "the overlap that is deliberate")
    }

    // MARK: - Claim 5 — figure shared, VOICE never

    func testItSharesTheFigureAndOwnsItsTwoVoices() {
        XCTAssertEqual(addition.bassGrammar, .offbeatEighths,
                       "the fifth owner of a shared figure — the skank IS the figure, and dub "
                       + "inherits it from reggae unchanged")
        guard let bass = addition.bassPatch else {
            return XCTFail("dubEcho has no bassPatch — `offbeatEighths` would then play on the "
                           + "pad voice an octave down, the pre-grammar path (#1286).")
        }
        XCTAssertEqual(bass.name, "Dub Sub")
        XCTAssertEqual(addition.synthPatch.name, "Echo Stab")

        // Counterweight (#343): the figure is shareable, the VOICE is not — on BOTH sides. This
        // is the assertion the first draft of "Dub Sub" would have failed in spirit and passed
        // in letter: it had its own NAME and three of `rootsReggae`'s four envelope values.
        let sameBass = MusicStyle.offered.filter { $0 != addition && $0.bassPatch?.name == bass.name }
        let sameLead = MusicStyle.offered.filter { $0 != addition && $0.synthPatch.name == addition.synthPatch.name }
        XCTAssertTrue(sameBass.isEmpty && sameLead.isEmpty,
                      "\(sameBass + sameLead) share one of dubEcho's VOICES. The lead BUCKET "
                      + "(`leadPatchName`) is shared and that is ceiling arithmetic; the patch "
                      + "is not.")
    }

    // MARK: - Claim 6 — the things a compiler cannot check

    func testTheModeTempoSwingLeadAndPadFigureAreDeliberate() {
        XCTAssertEqual(addition.defaultMode, .studioLocked,
                       "`defaultMode` takes NO arm — it inherits `default: .studioLocked`, the "
                       + "silent inheritance nothing else would report")
        XCTAssertTrue(addition.tempoRange.contains(addition.defaultTempo),
                      "a default tempo outside its own range is a picker that opens wrong")
        XCTAssertEqual(addition.swing, 0.18, accuracy: 0.0001)
        XCTAssertLessThan(addition.swing, MusicStyle.modalJazz.swing,
                          "modalJazz's 0.30 is pinned elsewhere as the largest offered swing")

        // The lead bucket is FORCED here, and by two constraints at once — see the header.
        XCTAssertEqual(addition.leadPatchName, "Hollow Reed")
        XCTAssertNotEqual(addition.leadPatchName, MusicStyle.deepHouse.leadPatchName,
                          "the sheet's \"Soft Keys\" is deepHouse's own and would make that pair "
                          + "five of seven — the constraint that decided this bucket")
        XCTAssertNotEqual(addition.leadPatchName, MusicStyle.rootsReggae.leadPatchName,
                          "\"Deep Sub\" is rootsReggae's own and would make THAT pair five of "
                          + "seven — the second of the two constraints")

        // NOT a prohibition (#364): the day a slice gives this genre the table's first arm, this
        // goes red and its message says what has to move with it.
        XCTAssertNil(addition.padGrammar,
                     "dubEcho now carries a pad figure. If that is the deliberate debut of "
                     + "`MusicStyle.padGrammar`'s FIRST arm, say so here and in this file's "
                     + "header — `droneMetal`, this shelf's intended second resident, is blocked "
                     + "on exactly that mechanism and its blocker list changes with it.")
    }

    // MARK: - Claim 7 — the shelf, and the echo that is the genre

    func testTheShelfIsNotAnEmptyDrawerAndTheEchoResolves() {
        XCTAssertEqual(MusicStyle.Subcategory.dubEchoes.parent, .underground)
        XCTAssertEqual(MusicStyle.Subcategory.dubEchoes.title, "Dub & Echo",
                       "the shelf title is RENDERED by the genre picker, unlike a rubric title — "
                       + "so it must name what the shelf holds. The plan says \"Dub & Drone\"; "
                       + "the drone is blocked and does not live here (see the header)")
        XCTAssertFalse(MusicStyle.Subcategory.dubEchoes.offeredGenres.isEmpty,
                       "the new shelf is offered-empty. It was added under the rule that a case "
                       + "arrives ONLY with its door; if dubEcho moved shelves, this one has to "
                       + "move with it or go.")

        let fx = addition.fxPreset
        XCTAssertEqual(fx.delaySync, TempoSyncOption(.half),
                       "the half note is the length that makes the third repeat land under the "
                       + "next stab; the patch's short release is built for it")
        // `GenreDelaySyncResolvabilityTests` sweeps the roster at each genre's FASTEST tempo.
        // This genre's risk is the SLOWEST end — a half note at 66 BPM is 1.818 s against a
        // 2.0 s ceiling, the narrowest margin of any offered arm at the time of writing.
        XCTAssertLessThan(fx.delaySync.seconds(bpm: addition.tempoRange.lowerBound), 2.0,
                          "the echo clamps at the slowest tempo this genre allows. Lowering "
                          + "`tempoRange.lowerBound` below 60 makes the notated half note "
                          + "unresolvable — the exact defect GenreDelaySyncResolvabilityTests "
                          + "was written for")
    }

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

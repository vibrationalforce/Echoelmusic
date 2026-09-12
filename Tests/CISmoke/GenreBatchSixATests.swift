// GenreBatchSixATests.swift
// Echoel — G6a's three additions, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster. Door · shelf · voicing-in-semitones · pace · patch · FX
// placed against NAMED neighbours · bass figure. No source-text scan.
//
// ⭐ WHAT THIS BATCH IS. Three RUBRICS had an arm and no door: `.rock` (heavyMetal, doom, punk,
// rock, rocknroll), `.jazz` (jazz) and the Soul shelf, which did not exist. Every genre in them
// was dark in the picker, so the picker's own section headers named three rooms a player could
// not enter. These are the first OFFERED metal, jazz and soul genres, and `.soul` is a NEW shelf
// added together with its first resident — the empty-shelf law `GenreSubcategoryTests` enforces.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED, because asserting it would be FALSE rather than merely
// redundant — the #1286 lesson, applied before writing rather than after:
//   · Voicing uniqueness. `blackMetal` shares `[0, 4, 7]` with punk/rock/heavyMetal/doom ON
//     PURPOSE (a metal genre that did not voice a power chord would separate itself on the wrong
//     axis), and `modalJazz`/`soulBallad` share `[0, 2, 4, 6]` with eight other arms. What IS
//     pinned is each genre's own claim: a unique SCALE for two of them, and for the third a
//     unique PROGRESSION.
//   · Tempo disjointness. `blackMetal` 160…200 overlaps `punk` 160…210 at both ends.
//     `GenreFamilyDistinctnessTests` excludes tempo from the fingerprint and says why.
//   · The roster-wide fingerprint sweep, the delay-resolvability sweep and the published genre
//     counts — one owner per claim (#416).
//
// NEEDS-FOUNDER-VERIFY: Black Metal at 180 — does the long thin hall read as COLD, or just as
// far away? Modal Jazz — is swing 0.30 a shuffle or a stumble on a two-chord vamp? Soul Ballad —
// does the maj7 plate read warm, or washed out? Three ear questions, no test can answer them.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchSixATests: XCTestCase {

    private let additions: [MusicStyle] = [.blackMetal, .modalJazz, .soulBallad]

    // MARK: - Claim 1 — the door, and the three rubrics that had none

    func testAllThreeAreReachableAndOpenTheirRubric() {
        for style in additions {
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) is built but not offered — a doorless genre (#254)")
            XCTAssertTrue(style.category.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its rubric's offered subset")
            XCTAssertTrue(style.subcategory.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its SHELF's offered subset")
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.lineage.isEmpty)
        }
        XCTAssertEqual(MusicStyle.blackMetal.category, .rock)
        XCTAssertEqual(MusicStyle.modalJazz.category, .jazz)
        XCTAssertEqual(MusicStyle.soulBallad.category, .jazz)
        XCTAssertEqual(MusicStyle.blackMetal.subcategory, .metal)
        XCTAssertEqual(MusicStyle.modalJazz.subcategory, .jazzCore)
        XCTAssertEqual(MusicStyle.soulBallad.subcategory, .soul)
        XCTAssertEqual(MusicStyle.blackMetal.displayName, "Black Metal")
        XCTAssertEqual(MusicStyle.modalJazz.displayName, "Modal Jazz")
        XCTAssertEqual(MusicStyle.soulBallad.displayName, "Soul Ballad")

        // The point of the batch, stated as the property rather than as a count: a rubric whose
        // offered subset is empty renders a header a player cannot enter.
        for category in [MusicStyle.Category.rock, .jazz] {
            XCTAssertFalse(category.offeredGenres.isEmpty, """
                \(category) has no offered genre again. Its header still renders in the picker \
                and every row under it is dark — the shape this batch exists to close.
                """)
        }
        // And the new shelf is not empty, which is the law a shelf is added under.
        XCTAssertFalse(MusicStyle.Subcategory.soul.genres.isEmpty,
                       "the Soul shelf was added without a resident — the lying-`toolItems` shape")
        XCTAssertEqual(MusicStyle.Subcategory.soul.parent, .jazz)
        XCTAssertEqual(MusicStyle.Subcategory.soul.title, "Soul")
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES (a degree array without its scale says nothing)

    func testTheMetalChordIsAPowerChordAndTheModeIsWhatIsNew() {
        XCTAssertEqual(semitoneStack(of: .blackMetal), [0, 7, 12], """
            The black-metal voicing is no longer root + fifth + octave. `[0, 4, 7]` of \
            hungarianMinor resolves there, and the sharing with punk/rock/heavyMetal/doom is the \
            design — the SCALE is what this genre owns.
            """)
        XCTAssertEqual(MusicStyle.blackMetal.scale, .hungarianMinor)
        let otherHungarian = MusicStyle.allCases.filter {
            $0 != .blackMetal && $0.scale == .hungarianMinor
        }
        XCTAssertTrue(otherHungarian.isEmpty, """
            \(otherHungarian.map(\.rawValue)) also use hungarianMinor. The case doc rests the \
            whole separation on the mode being this genre's alone.
            """)
        // The counterweight that keeps the sharing honest: if nobody else carried the power
        // chord, the doc's "shared on purpose" would be a sentence about nothing.
        let powerChordFamily = MusicStyle.allCases.filter {
            $0 != .blackMetal && $0.harmonicProfile.chordTones == [0, 4, 7]
        }
        XCTAssertFalse(powerChordFamily.isEmpty,
                       "nothing else carries [0, 4, 7] — the doc claims the voicing is the family's")
    }

    func testTheTwoSeventhGenresAreToldApartByScaleAndProgression() {
        XCTAssertEqual(semitoneStack(of: .modalJazz), [0, 3, 7, 10], "a minor seventh")
        XCTAssertEqual(semitoneStack(of: .soulBallad), [0, 4, 7, 11], "a major seventh")
        XCTAssertEqual(MusicStyle.modalJazz.harmonicProfile.chordTones,
                       MusicStyle.soulBallad.harmonicProfile.chordTones, """
            The two stopped sharing their degree array. That sharing is the point of the pair — \
            same degrees, different scale, different chord — and the file says so in both docs.
            """)
        XCTAssertNotEqual(MusicStyle.modalJazz.scale, MusicStyle.soulBallad.scale)

        // modalJazz's own claim is the two-root vamp; soulBallad's is its progression.
        XCTAssertEqual(MusicStyle.modalJazz.harmonicProfile.progression, [0, 3],
                       "the two-chord vamp IS the genre — a third root makes it a progression")
        let sameSoulVamp = MusicStyle.allCases.filter {
            $0 != .soulBallad && $0.harmonicProfile.progression == [0, 3, 5]
        }
        XCTAssertTrue(sameSoulVamp.isEmpty, "\(sameSoulVamp.map(\.rawValue)) now carry I–IV–vi too")

        // Against the offered neighbour each doc names, the separation asserted as the property
        // the doc rests on — not as a uniqueness sweep that would be false.
        XCTAssertNotEqual(MusicStyle.soulBallad.chordArticulation,
                          MusicStyle.vaporwave.chordArticulation, """
            `soulBallad` and `vaporwave` are both major with the same degree array; the \
            articulation is the WHOLE separation, and it just disappeared.
            """)
        XCTAssertEqual(MusicStyle.modalJazz.chordArticulation, .comp)
        // ⛔ THIS USED TO ASSERT that no other OFFERED dorian genre comps, and the transcription
        // in the same commit measured it FALSE: `detroitTechno` is dorian and `.backbeat`. The
        // doc was corrected with it. What separates the two is the rest of the row, and that is
        // what is pinned — three properties, any one of which collapsing makes them one genre.
        let detroit = MusicStyle.detroitTechno
        XCTAssertEqual(detroit.scale, MusicStyle.modalJazz.scale, "the premise of this claim")
        XCTAssertEqual(detroit.chordArticulation, MusicStyle.modalJazz.chordArticulation)
        XCTAssertNotEqual(detroit.harmonicProfile.progression,
                          MusicStyle.modalJazz.harmonicProfile.progression,
                          "modalJazz and detroitTechno now share a progression too")
        XCTAssertNotEqual(detroit.harmonicProfile.chordTones,
                          MusicStyle.modalJazz.harmonicProfile.chordTones,
                          "a ninth shell and a minor seventh were the voicing separation")
        XCTAssertNotEqual(detroit.swing, MusicStyle.modalJazz.swing,
                          "and the shuffle depth was the third")
    }

    // MARK: - Claim 3 — the pace, and the swing that IS a genre

    func testTheThreeCompOnAStudioClockAndTheJazzSwingIsTheLargestOffered() {
        for style in additions {
            XCTAssertEqual(style.beatArchetype, .backbeat)
            XCTAssertEqual(style.chordArticulation, .comp,
                           "`chordArticulation` derives from the archetype — this is that claim")
            XCTAssertTrue(style.isBeatDriven)
            XCTAssertEqual(style.defaultMode, .studioLocked)
            XCTAssertTrue(style.tempoRange.contains(style.defaultTempo),
                          "\(style.rawValue)'s default tempo is outside its own window")
            XCTAssertFalse(style.harmonicProfile.arpeggiated)
            XCTAssertFalse(style.harmonicProfile.sustained)
            XCTAssertEqual(style.harmonicProfile.leadDensity, 0, accuracy: 0.0001,
                           "\(style.rawValue) would wake the five dormant lead paths")
        }
        // ⚠️ `detroitTechno` is pinned elsewhere as the only ELECTRONIC genre that comps. These
        // three comp and are `.rock`/`.jazz`, so that claim survives — asserted here because a
        // later re-shelving is exactly how it would quietly stop being true.
        XCTAssertNotEqual(MusicStyle.blackMetal.category, .electronic)
        XCTAssertNotEqual(MusicStyle.modalJazz.category, .electronic)
        XCTAssertNotEqual(MusicStyle.soulBallad.category, .electronic)

        let offeredSwings = MusicStyle.offered.map(\.swing)
        let maxOffered = offeredSwings.max() ?? 0
        XCTAssertEqual(MusicStyle.modalJazz.swing, maxOffered, accuracy: 0.0001, """
            `modalJazz` is no longer the swingiest OFFERED genre (max is \(maxOffered)). Its case \
            doc rests the whole identity on that: a straight two-chord dorian vamp is an ambient \
            loop, and the shuffle is what makes it read as jazz.
            """)
        XCTAssertGreaterThan(MusicStyle.jazz.swing, MusicStyle.modalJazz.swing,
                             "the un-offered `jazz` arm keeps its own margin, per both docs")
        XCTAssertEqual(MusicStyle.blackMetal.swing, 0, accuracy: 0.0001,
                       "a tremolo wall has nothing to shuffle")
        XCTAssertGreaterThan(MusicStyle.soulBallad.swing, 0)
        XCTAssertLessThan(MusicStyle.soulBallad.tempoRange.upperBound,
                          MusicStyle.modalJazz.tempoRange.lowerBound,
                          "the ballad sits under the vamp")
        XCTAssertLessThanOrEqual(MusicStyle.modalJazz.tempoRange.upperBound,
                                 MusicStyle.blackMetal.tempoRange.lowerBound, """
            The jazz and metal windows now OVERLAP. They are allowed to TOUCH — both end and \
            begin at 160 — but an overlap means the two can be handed the same tempo and then \
            differ only in mode. (The strict `<` stood here for one draft and was red on a \
            correct tree at 160 vs 160, the same shape G5b hit at 145 — #364.)
            """)
    }

    // MARK: - Claim 4 — the patches, the ceiling, and three neighbour claims they must not take

    func testThePatchesKeepEveryNeighbourClaimTheyCouldHaveTaken() {
        XCTAssertEqual(additions.map(\.synthPatch.name), ["Cold Stack", "Warm Comp Keys", "Warm Keys"])
        XCTAssertEqual(Set(additions.map(\.synthPatch.id)).count, 3)
        for style in additions {
            XCTAssertNotNil(style.bassPatch,
                            "\(style.rawValue) has an authored bass figure and no voice of its own")
        }
        let allNames = MusicStyle.allCases.flatMap { [$0.synthPatch.name] + [$0.bassPatch?.name].compactMap { $0 } }
        XCTAssertEqual(Set(allNames).count, allNames.count, """
            Two patches now ship under one name. "Velvet Sub" is named that because `afroHouse` \
            already ships "Round Sub" — the preset list is keyed by id and READ by name.
            """)

        // Three superlatives the batch could have taken silently, each measured rather than
        // remembered — two of the three drafts DID take one, and nothing would have gone red.
        let bassPatches = MusicStyle.allCases.compactMap(\.bassPatch)
        if let minimalSub = MusicStyle.minimalTechno.bassPatch {
            for p in bassPatches where p.id != minimalSub.id {
                XCTAssertGreaterThan(p.filterCutoff, minimalSub.filterCutoff, """
                    "\(p.name)" is at or below "Minimal Sub"'s cutoff, which two neighbouring arms \
                    quote as "the lowest cutoff, darkest in the file". `GenreDarkMinimalTests` \
                    pins that only PAIRWISE, so a roster-wide break reddens nothing else.
                    """)
            }
        }
        if let psy = MusicStyle.psyProgHouse.bassPatch {
            for p in bassPatches where p.id != psy.id {
                XCTAssertGreaterThan(p.attack + p.decay + p.release,
                                     psy.attack + psy.decay + psy.release, """
                    "\(p.name)" now has a shorter envelope than "Psy Bass", whose own arm claims \
                    the shortest of every bass patch here.
                    """)
            }
        }
        for style in MusicStyle.allCases where style != .deepDrone {
            XCTAssertLessThan(style.synthPatch.attack, MusicStyle.deepDrone.synthPatch.attack + 0.0001,
                              "\(style.rawValue) took deepDrone's \"slowest attack of any genre patch\"")
            XCTAssertLessThan(style.synthPatch.release, MusicStyle.deepDrone.synthPatch.release + 0.0001,
                              "\(style.rawValue) took deepDrone's \"longest release\"")
        }

        // The ceiling, DERIVED — never a literal (#818).
        let bearing = MusicStyle.allCases.filter { !$0.harmonicProfile.sustained }
        let ceiling = Int(ceil(Double(bearing.count) / 6.0))
        var counts: [String: Int] = [:]
        for style in bearing { counts[style.leadPatchName, default: 0] += 1 }
        for style in additions {
            XCTAssertLessThanOrEqual(counts[style.leadPatchName] ?? 0, ceiling, """
                \(style.rawValue) took "\(style.leadPatchName)", over the pigeonhole ceiling of \
                \(ceiling) across \(bearing.count) lead-bearing genres. `blackMetal` was moved \
                off the drafted "Deep Sub" for exactly this — measure before choosing.
                """)
        }
    }

    // MARK: - Claim 5 — the FX, and the three absent delays

    func testTheThreeHaveNoDelayAndTakeNoHallSuperlative() {
        let contemplation = MusicStyle.contemplation.fxPreset
        let drift = MusicStyle.drift.fxPreset
        let deepDrone = MusicStyle.deepDrone.fxPreset
        let minimal = MusicStyle.minimalTechno.fxPreset

        for style in additions {
            let p = style.fxPreset
            XCTAssertFalse(p.delayEnabled, """
                \(style.rawValue) grew a delay. Each arm gives its OWN reason for the absence — a \
                continuous tremolo wall has no event to repeat, an echo at swing 0.30 lands \
                between the swung eighths, and a delay on top of a long plate is mud. A delay \
                added here also puts the genre back under the resolvability sweep it currently \
                skips by construction.
                """)
            XCTAssertTrue(p.reverbEnabled)
            XCTAssertFalse(p.filterEnabled, "`acidTechno` is the only genre arm that enables the chain filter")
            XCTAssertLessThan(p.reverbRoom, contemplation.reverbRoom,
                              "\(style.rawValue) took contemplation's \"biggest hall in the roster\"")
            XCTAssertLessThan(p.reverbRoom, drift.reverbRoom, "\(style.rawValue) outgrew drift's hall")
            XCTAssertGreaterThan(p.reverbDamping, drift.reverbDamping,
                                 "\(style.rawValue) took drift's \"brightest, least-damped big hall\"")
            XCTAssertLessThan(p.reverbDamping, deepDrone.reverbDamping,
                              "\(style.rawValue) took deepDrone's \"most DAMPED hall in the roster\"")
            XCTAssertGreaterThan(p.saturation, minimal.saturation,
                                 "\(style.rawValue) took minimalTechno's \"cleanest beat-driven chain\"")
        }
        XCTAssertGreaterThan(MusicStyle.blackMetal.fxPreset.saturation,
                             MusicStyle.heavyMetal.fxPreset.saturation,
                             "black metal reads dirtier than the classic rig, which is the design")
        XCTAssertLessThan(MusicStyle.blackMetal.fxPreset.saturation,
                          MusicStyle.doom.fxPreset.saturation,
                          "and cleaner than doom's wall — it claims no extreme, it sits between two")
        XCTAssertFalse(MusicStyle.blackMetal.fxPreset.chorusEnabled,
                       "width on a power chord is mud, not size")
        XCTAssertTrue(MusicStyle.modalJazz.fxPreset.chorusEnabled)
        XCTAssertTrue(MusicStyle.soulBallad.fxPreset.chorusEnabled)
    }

    // MARK: - Claim 6 — the bass figures, shared by design and voiced apart

    func testTheFiguresAreSharedAndTheVoicesAreNot() {
        XCTAssertEqual(MusicStyle.blackMetal.bassGrammar, .drivingEighths, "techHouse's figure")
        XCTAssertEqual(MusicStyle.modalJazz.bassGrammar, .drivingEighths)
        XCTAssertEqual(MusicStyle.soulBallad.bassGrammar, .offbeatEighths, "deepHouse's figure")
        for style in additions {
            guard let figure = style.bassGrammar else { return XCTFail("\(style.rawValue) lost its figure") }
            let owners = MusicStyle.allCases.filter { $0.bassGrammar == figure }
            XCTAssertGreaterThanOrEqual(owners.count, 3,
                                        "\(figure) should have at least three owners after this batch")
            let ids = owners.compactMap { $0.bassPatch?.id }
            XCTAssertEqual(ids.count, owners.count,
                           "a \(figure) owner has no bass patch: \(owners.filter { $0.bassPatch == nil }.map(\.rawValue))")
            XCTAssertEqual(Set(ids).count, ids.count,
                           "two \(figure) owners share a bass patch — share the figure, never the voice")
        }
    }

    // MARK: - Claim 7 (COUNTERWEIGHT) — the roster still composes

    func testEveryOfferedGenreStillComposesAPad() {
        for style in MusicStyle.offered {
            let input = BioComposer.Input(heartRateBPM: 64, hrvNormalized: 0.6, coherence: 0.5,
                                          breathPhase: 0.5, breathDepth: 0.3,
                                          key: MusicalKey(root: 0, scale: style.scale),
                                          style: style, mode: style.defaultMode,
                                          lockedTempo: style.defaultTempo,
                                          seed: 0xC0FFEE, suggestJourney: true)
            let pad = BioComposer.compose(input).notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, "\(style.rawValue) produces no pad at a resting body")
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style.rawValue) has a zero-length pad note (#205/#176)")
        }
    }

    // MARK: - helper (#416: the resolution `GenreBatchFourVoicingTests` already owns)

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

// GenreBatchSixBTests.swift
// Echoel — G6b's three additions, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchSixATests` form. No source-text scan.
//
// ⭐ WHAT THIS BATCH CLOSES. With G6a it opens the `.popular` rubric: Hip-Hop had `trap` and no
// door; R&B had no shelf at all; Caribbean had `ska` and `rocksteady`, both dark. `.rnbPop` is
// added together with `electroFunk`, its only resident — the empty-shelf law again.
//
// ⛔ AND THE FIRST DRAFT OF THIS HEADER CLAIMED MORE THAN THE COMMIT DOES, in both halves of one
// sentence. It said "after this commit EVERY rubric in the picker has at least one offered genre".
// `.folk` (`europeanFolk` = `klezmer`, `nearEastCentralAsia` = `oriental`) has none and will not
// until G11/G12 — so the sweep written from that sentence was RED on a correct tree, the #364
// shape this batch series keeps paying for. Worse, its FAILURE MESSAGE described a picker that
// does not exist: `WorkspaceView`'s genre menu iterates `Subcategory.allCases` and renders a
// section only `if !shelf.offeredGenres.isEmpty`, so an offered-empty rubric renders NOTHING —
// there is no dark header. A claim that cannot fail for the reason its message gives is #367,
// and mine could not fail for that reason even when it failed. What is asserted below instead is
// the DIRECTION: the set of doorless rubrics may shrink (G11/G12) and must never grow.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. All three are `minor`, which eight arms share; two carry
// the minor seventh `[0, 2, 4, 6]` that ten arms share, and `rootsReggae` the plain triad that
// eighteen share. NONE of it is claimed as its own — the fingerprint sweep in
// `GenreFamilyDistinctnessTests` is what enforces distinctness, and it reads the 7-tuple. What
// each doc DOES claim is asserted here: the tempo/articulation/progression combination.
//
// ⛔ AND ONE CLAIM IS DELIBERATELY A TIE. `electroFunk`'s plain sixteenth is the shortest delay
// division in the roster TOGETHER WITH `psyProgHouse` — not instead of it. #1286 had to retract
// `techHouse`'s "shortest of any offered genre" when psy-prog broke it silently, so this batch
// pins the FLOOR and its holders rather than a single owner.
//
// NEEDS-FOUNDER-VERIFY: Boom Bap at 90 — does the tape wow read as dust or as wobble? Electro
// Funk — is the sixteenth slap audible under the snap, or does it just thicken it? Roots Reggae
// — the quarter echo at 0.71 s with 0.46 feedback is the loudest tail of this batch: is it the
// genre, or is it too much? Three ear questions.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchSixBTests: XCTestCase {

    private let additions: [MusicStyle] = [.boomBapHipHop, .electroFunk, .rootsReggae]

    // MARK: - Claim 1 — the door, and the property this batch completes

    func testEveryRubricAndEveryShelfNowHasAGenre() {
        for style in additions {
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) is built but not offered — a doorless genre (#254)")
            XCTAssertEqual(style.category, .popular)
            XCTAssertTrue(style.category.offeredGenres.contains(style))
            XCTAssertTrue(style.subcategory.offeredGenres.contains(style))
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.lineage.isEmpty)
        }
        XCTAssertEqual(MusicStyle.boomBapHipHop.subcategory, .hipHop)
        XCTAssertEqual(MusicStyle.electroFunk.subcategory, .rnbPop)
        XCTAssertEqual(MusicStyle.rootsReggae.subcategory, .caribbean)
        XCTAssertEqual(MusicStyle.Subcategory.rnbPop.parent, .popular)
        XCTAssertEqual(MusicStyle.Subcategory.rnbPop.title, "R&B & Pop")
        XCTAssertEqual(MusicStyle.boomBapHipHop.displayName, "Boom Bap")
        XCTAssertEqual(MusicStyle.electroFunk.displayName, "Electro Funk")
        XCTAssertEqual(MusicStyle.rootsReggae.displayName, "Roots Reggae")

        // ⭐ THE CLAIM THIS BATCH EXISTS FOR, asserted as a DIRECTION over the whole taxonomy
        // rather than as a list — so it keeps meaning something when the roster grows, and so
        // that filling `.folk` in G11/G12 leaves it green instead of red (#364).
        let doorless = MusicStyle.Category.allCases.filter { $0.offeredGenres.isEmpty }
        XCTAssertLessThanOrEqual(doorless.count, 1, """
            More than one rubric has no offered genre: \(doorless). Exactly one is expected \
            (`.folk`, filled in G11/G12); a second means a rubric was added without a door, \
            which is the lying-`toolItems` shape at the rubric level.
            """)
        XCTAssertTrue(doorless.allSatisfy { $0 == .folk }, """
            A rubric other than `.folk` lost its door: \(doorless). `.folk` is the one this \
            series has not reached yet; every other rubric is opened and must stay opened.
            """)
        XCTAssertEqual(MusicStyle.Category.popular.offeredGenres.count, 3,
                       "the rubric this batch opens carries exactly its three additions")
        // The shelf half of the empty-shelf law is about GENRES, not offered genres — five
        // shelves are offered-empty today and the picker simply skips them, which is correct.
        // What is forbidden is a shelf with nothing filed under it at all.
        for shelf in MusicStyle.Subcategory.allCases {
            XCTAssertFalse(shelf.genres.isEmpty,
                           "shelf .\(shelf.rawValue) has no genres at all — the lying-`toolItems` shape")
        }
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, and what actually separates the three

    func testTheThreeShareAScaleAndAreToldApartByEverythingElse() {
        for style in additions {
            XCTAssertEqual(style.scale, .minor, "all three are minor — stated in every doc, claimed by none")
        }
        XCTAssertEqual(semitoneStack(of: .boomBapHipHop), [0, 3, 7, 10], "a minor seventh")
        XCTAssertEqual(semitoneStack(of: .electroFunk), [0, 3, 7, 10], "the same seventh, an octave up")
        XCTAssertEqual(semitoneStack(of: .rootsReggae), [0, 3, 7], "a plain minor triad")

        // boomBap vs electroFunk share scale, voicing AND articulation. Three properties are
        // left, and the docs rest on all three — so all three are pinned.
        XCTAssertEqual(MusicStyle.boomBapHipHop.harmonicProfile.chordTones,
                       MusicStyle.electroFunk.harmonicProfile.chordTones)
        XCTAssertEqual(MusicStyle.boomBapHipHop.chordArticulation,
                       MusicStyle.electroFunk.chordArticulation)
        XCTAssertNotEqual(MusicStyle.boomBapHipHop.harmonicProfile.progression,
                          MusicStyle.electroFunk.harmonicProfile.progression, """
            The two `.popular` comps now share a progression as well as a scale, a voicing and \
            an articulation. Two roots against three was one of the three axes left.
            """)
        XCTAssertNotEqual(MusicStyle.boomBapHipHop.harmonicProfile.padOctave,
                          MusicStyle.electroFunk.harmonicProfile.padOctave, "register was the second")
        XCTAssertFalse(MusicStyle.boomBapHipHop.tempoRange.overlaps(MusicStyle.electroFunk.tempoRange),
                       "and tempo was the third — 84…96 against 112…124")
        XCTAssertEqual(MusicStyle.electroFunk.harmonicProfile.progression.count, 3,
                       "i → IV → V is the only three-root minor turn in this batch")

        // rootsReggae shares its progression exactly with modalJazz; the separation is elsewhere.
        XCTAssertEqual(MusicStyle.rootsReggae.harmonicProfile.progression,
                       MusicStyle.modalJazz.harmonicProfile.progression, "the premise of the next two")
        XCTAssertNotEqual(MusicStyle.rootsReggae.chordArticulation,
                          MusicStyle.modalJazz.chordArticulation, "skank against comp")
        XCTAssertNotEqual(MusicStyle.rootsReggae.scale, MusicStyle.modalJazz.scale, "minor against dorian")
    }

    // MARK: - Claim 3 — the pace, the skank, and the swing ceiling G6a pinned

    func testThePaceAndThatModalJazzKeepsTheSwingCrown() {
        XCTAssertEqual(MusicStyle.boomBapHipHop.beatArchetype, .backbeat)
        XCTAssertEqual(MusicStyle.electroFunk.beatArchetype, .backbeat)
        XCTAssertEqual(MusicStyle.rootsReggae.beatArchetype, .offbeat)
        XCTAssertEqual(MusicStyle.rootsReggae.chordArticulation, .skank,
                       "the chord between the beats IS the genre")
        for style in additions {
            XCTAssertTrue(style.isBeatDriven)
            XCTAssertEqual(style.defaultMode, .studioLocked)
            XCTAssertTrue(style.tempoRange.contains(style.defaultTempo))
            XCTAssertFalse(style.harmonicProfile.arpeggiated)
            XCTAssertFalse(style.harmonicProfile.sustained)
            XCTAssertEqual(style.harmonicProfile.leadDensity, 0, accuracy: 0.0001)
            XCTAssertLessThan(style.swing, MusicStyle.modalJazz.swing, """
                \(style.rawValue) now swings at least as hard as `modalJazz`, whose doc and \
                `GenreBatchSixATests` both call it the largest of any offered genre. Either this \
                value comes down or that claim is retracted in the same commit.
                """)
        }
        // §2b-7, pinned: `electroFunk` is filed `.popular` and NOT `.electronic` precisely so
        // that `GenreBatchFourVoicingTests`' "detroitTechno is the only electronic genre that
        // comps" stays true. That is the reason the filing must not drift.
        XCTAssertEqual(MusicStyle.electroFunk.category, .popular, """
            `electroFunk` moved rubric. It comps, so under `.electronic` it would break \
            `detroitTechno`'s pinned "only electronic genre that comps" — the repair would then \
            be that guard's doc rather than this filing, which is the more expensive of the two.
            """)
        let electronicComps = MusicStyle.allCases.filter {
            $0.category == .electronic && $0.chordArticulation == .comp
        }
        XCTAssertEqual(electronicComps, [.detroitTechno],
                       "a second electronic genre now comps: \(electronicComps.map(\.rawValue))")
    }

    // MARK: - Claim 4 — the patches, the ceiling, and the claims they must not take

    func testThePatchesKeepEveryNeighbourClaim() {
        XCTAssertEqual(additions.map(\.synthPatch.name), ["Dust Keys", "Snap Keys", "Roots Organ"])
        XCTAssertNotEqual(MusicStyle.rootsReggae.synthPatch.name, MusicStyle.ska.synthPatch.name, """
            "Roots Organ" is named that because `ska` already ships "Skank Organ" — the third \
            name collision the pre-batch check caught in three batches.
            """)
        for style in additions {
            XCTAssertNotNil(style.bassPatch, "\(style.rawValue) has a figure and no voice")
        }
        let allNames = MusicStyle.allCases.flatMap {
            [$0.synthPatch.name] + [$0.bassPatch?.name].compactMap { $0 }
        }
        XCTAssertEqual(Set(allNames).count, allNames.count,
                       "two patches ship under one name — the list is keyed by id and READ by name")
        let allIDs = MusicStyle.allCases.flatMap { [$0.synthPatch.id] + [$0.bassPatch?.id].compactMap { $0 } }
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "two patches share an id")

        if let minimalSub = MusicStyle.minimalTechno.bassPatch {
            for p in MusicStyle.allCases.compactMap(\.bassPatch) where p.id != minimalSub.id {
                XCTAssertGreaterThan(p.filterCutoff, minimalSub.filterCutoff,
                                     "\"\(p.name)\" took \"Minimal Sub\"'s lowest-cutoff claim")
            }
        }
        if let psy = MusicStyle.psyProgHouse.bassPatch {
            for p in MusicStyle.allCases.compactMap(\.bassPatch) where p.id != psy.id {
                XCTAssertGreaterThan(p.attack + p.decay + p.release,
                                     psy.attack + psy.decay + psy.release,
                                     "\"\(p.name)\" took \"Psy Bass\"'s shortest-envelope claim")
            }
        }

        let bearing = MusicStyle.allCases.filter { !$0.harmonicProfile.sustained }
        let ceiling = Int(ceil(Double(bearing.count) / 6.0))
        var counts: [String: Int] = [:]
        for style in bearing { counts[style.leadPatchName, default: 0] += 1 }
        for style in additions {
            XCTAssertLessThanOrEqual(counts[style.leadPatchName] ?? 0, ceiling, """
                \(style.rawValue) took "\(style.leadPatchName)", over the ceiling of \(ceiling) \
                across \(bearing.count) lead-bearing genres. The design sheet gave BOTH \
                `boomBapHipHop` and `electroFunk` "Soft Keys", which is 8 — electro funk takes \
                Pluck instead, and a snapping comp is a pluck's timbre anyway.
                """)
        }
    }

    // MARK: - Claim 5 — the FX, the shared division floor, and the scoped feedback claim

    func testTheDivisionFloorIsSharedAndNoScopedClaimBreaks() {
        for style in additions {
            let p = style.fxPreset
            XCTAssertTrue(p.delayEnabled, "all three of this batch echo — each arm says why")
            XCTAssertTrue(p.reverbEnabled)
            XCTAssertFalse(p.filterEnabled, """
                \(style.rawValue) enabled the chain filter. `acidTechno` is the only genre arm \
                that does, and `boomBapHipHop`'s dust is in its PATCH for exactly this reason.
                """)
            XCTAssertGreaterThan(p.saturation, MusicStyle.minimalTechno.fxPreset.saturation,
                                 "\(style.rawValue) took minimalTechno's \"cleanest beat-driven chain\"")
            XCTAssertGreaterThan(p.delayTone, MusicStyle.deepDrone.fxPreset.delayTone,
                                 "\(style.rawValue) took deepDrone's \"darkest tone in the roster\"")
            XCTAssertLessThan(p.reverbDamping, MusicStyle.techHouse.fxPreset.reverbDamping,
                              "\(style.rawValue) is damped harder than techHouse, whose arm lists what is above it")
            XCTAssertLessThanOrEqual(p.delaySpread, MusicStyle.detroitTechno.fxPreset.delaySpread,
                                     "\(style.rawValue) is wider than detroitTechno, the widest offered spread")
        }
        let filtered = MusicStyle.allCases.filter { $0.fxPreset.filterEnabled }
        XCTAssertEqual(filtered, [.acidTechno], "the chain filter is acidTechno's alone; found \(filtered)")

        // ⛔ The SCOPED claim, pinned as scoped. `minimalTechno`'s arm says "longest tail of the
        // FOUR-ON-FLOOR offered genres" — `rootsReggae` is `.offbeat` and sits ABOVE it at 0.46,
        // which is legal and is exactly what quoting a neighbour's scope means. Read this as the
        // counterweight it is: if someone ever makes rootsReggae four-on-floor, this goes red.
        XCTAssertNotEqual(MusicStyle.rootsReggae.beatArchetype, .fourOnFloor, """
            `rootsReggae`'s feedback 0.46 sits above `minimalTechno`'s 0.44, which is legal only \
            because that arm's claim is scoped to four-on-floor genres. Making this one \
            four-on-floor breaks that claim silently.
            """)
        for style in MusicStyle.offered where style.beatArchetype == .fourOnFloor
            && style != .minimalTechno && style.fxPreset.delayEnabled {
            XCTAssertLessThan(style.fxPreset.delayFeedback,
                              MusicStyle.minimalTechno.fxPreset.delayFeedback,
                              "\(style.rawValue) took minimalTechno's four-on-floor tail claim")
        }

        // The division FLOOR and its holders — a floor, not an owner (#1286's retraction).
        // Divisions are compared at ONE fixed BPM, which is an exact ordering of the note values
        // themselves: `seconds(bpm:)` is linear in 1/bpm, so the ranking cannot depend on the
        // tempo chosen. (`TempoSyncOption` exposes no multiplier; this is the same fact.)
        let probeBPM = 120.0
        let divisions = MusicStyle.offered.filter { $0.fxPreset.delayEnabled }
            .map { $0.fxPreset.delaySync.seconds(bpm: probeBPM) }
        guard let floor = divisions.min() else { return XCTFail("no offered genre has a delay") }
        let holders = MusicStyle.offered.filter {
            $0.fxPreset.delayEnabled
                && abs($0.fxPreset.delaySync.seconds(bpm: probeBPM) - floor) < 1e-9
        }
        XCTAssertTrue(holders.contains(.electroFunk) && holders.contains(.psyProgHouse), """
            The shortest offered division is no longer held jointly by `electroFunk` and \
            `psyProgHouse` (holders: \(holders.map(\.rawValue))). Both arms say "jointly"; a \
            single owner means one of those two arms is now wrong.
            """)
    }

    // MARK: - Claim 6 — the bass figures

    func testTheFiguresAreSharedAndTheVoicesAreNot() {
        XCTAssertEqual(MusicStyle.boomBapHipHop.bassGrammar, .sparseSub)
        XCTAssertEqual(MusicStyle.electroFunk.bassGrammar, .drivingEighths)
        XCTAssertEqual(MusicStyle.rootsReggae.bassGrammar, .offbeatEighths)
        for style in additions {
            guard let figure = style.bassGrammar else { return XCTFail("\(style.rawValue) lost its figure") }
            let owners = MusicStyle.allCases.filter { $0.bassGrammar == figure }
            XCTAssertGreaterThanOrEqual(owners.count, 4, "\(figure) should have four owners after this batch")
            let ids = owners.compactMap { $0.bassPatch?.id }
            XCTAssertEqual(ids.count, owners.count,
                           "a \(figure) owner has no bass patch: \(owners.filter { $0.bassPatch == nil }.map(\.rawValue))")
            XCTAssertEqual(Set(ids).count, ids.count, "two \(figure) owners share a voice")
        }
    }

    // MARK: - Claim 7 (COUNTERWEIGHT) — the roster still composes

    func testEveryOfferedGenreStillComposesAPad() {
        for style in MusicStyle.offered {
            let input = BioComposer.Input(heartRateBPM: 70, hrvNormalized: 0.5, coherence: 0.4,
                                          breathPhase: 0.75, breathDepth: 0.4,
                                          key: MusicalKey(root: 0, scale: style.scale),
                                          style: style, mode: style.defaultMode,
                                          lockedTempo: style.defaultTempo,
                                          seed: 0xFEED, suggestJourney: true)
            let pad = BioComposer.compose(input).notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, "\(style.rawValue) produces no pad at a resting body")
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style.rawValue) has a zero-length pad note (#205/#176)")
        }
    }

    // MARK: - helper (#416)

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

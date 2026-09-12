// GenreBatchElevenATests.swift
// Echoel — G11a's two additions, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchSixBTests` form. No source-text scan.
//
// ⭐ WHAT THIS BATCH CLOSES, and this time the claim is measured before it is written. `.folk`
// was the LAST rubric with no offered genre: `klezmer` had the European Folk shelf to itself and
// was dark in the picker. After this commit every rubric in `Category.allCases` has at least one
// offered genre — asserted here as the FACT, and as the DIRECTION in `GenreBatchSixBTests`,
// which predicted exactly this batch by name.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `celticAir` shares `dorian` with five offered genres and
// `andalusianCadence` shares `[0, 2, 4]` with twenty arms. Neither is claimed. What each doc DOES
// claim is asserted: the fourth-voiced stack with no third, the unique progression, the tonic-led
// authoring, and the five axes that keep the second `phrygianDominant` genre away from the first.
//
// ⛔ THIS BATCH REDDENED TWO GUARDS ON A CORRECT TREE AND BOTH ARE REPAIRED IN THE SAME COMMIT
// (§4 — a repair goes to every home of the claim):
//   1. `GenreBatchFiveBTests.testTheDarkPsyModeIsItsOwnAndItsVoicingIsNot` forbade a second
//      `phrygianDominant` genre. That is the #364 shape, and it is the SAME defect #1286's own
//      `rollingSixteenths` retraction had fixed one claim earlier in the same file. It now
//      asserts what the figure retraction settled on: the property may be shared, the IDENTITY
//      may not.
//   2. `GenreDelaySyncResolvabilityTests.testTheDrumFreeOfferedGenresOccupyTheDelayAxis`
//      required EVERY drum-free offered genre to carry a delay — and `glacialField`/`slowBloom`
//      have had none since #1285. **That guard was already red, for five commits, and #1285's
//      commit message asserted the opposite.** Not this batch's defect; this batch's to fix.
//
// NEEDS-FOUNDER-VERIFY: Celtic Air in Flow mode — does the body-followed tempo read as an
// unhurried air, or as a tempo that cannot make up its mind? Andalusian Cadence — the ♭2 → tonic
// step is the LOOP SEAM, not a chord inside the bar: does the cadence still land, or does it
// only land every time the loop turns over? Two ear questions.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchElevenATests: XCTestCase {

    private let additions: [MusicStyle] = [.celticAir, .andalusianCadence]

    // MARK: - Claim 1 — the door, and the last doorless rubric

    func testTheFolkRubricFinallyHasADoor() {
        for style in additions {
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) is built but not offered — a doorless genre (#254)")
            XCTAssertEqual(style.category, .folk)
            XCTAssertEqual(style.subcategory, .europeanFolk)
            XCTAssertTrue(style.category.offeredGenres.contains(style))
            XCTAssertTrue(style.subcategory.offeredGenres.contains(style))
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.lineage.isEmpty)
        }
        XCTAssertEqual(MusicStyle.celticAir.displayName, "Celtic Air")
        XCTAssertEqual(MusicStyle.andalusianCadence.displayName, "Andalusian Cadence")
        XCTAssertTrue(MusicStyle.Subcategory.europeanFolk.genres.contains(.klezmer),
                      "the shelf's original resident is still filed here — it is still dark, and "
                      + "these two are the doors it never had")
        XCTAssertFalse(MusicStyle.offered.contains(.klezmer),
                       "klezmer became offered; the batch prose says it did not, and the "
                       + "separation from `andalusianCadence` is then a live question")

        // ⭐ THE PROPERTY THIS BATCH COMPLETES, and the one `GenreBatchSixBTests` left as a
        // direction naming `.folk` by name. It is asserted as a FACT here because it is true
        // from this commit — the direction there stays the ratchet.
        let doorless = MusicStyle.Category.allCases.filter { $0.offeredGenres.isEmpty }
        XCTAssertTrue(doorless.isEmpty, """
            \(doorless) has no offered genre. Every rubric has had a door since this commit; a \
            rubric losing its last one means either a genre left `offered` or a rubric was added \
            without a resident, and the picker renders neither.
            """)
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES

    func testTheStacksAreWhatTheDocsSayAndNotWhatTheDegreesLookLike() {
        // ⭐ `[0, 3, 7]` LOOKS like a minor triad read as semitones and is not one. This is the
        // trap #1286 paid for: degrees are resolved through `MusicalKey.degree`, always.
        XCTAssertEqual(semitoneStack(of: .celticAir), [0, 5, 12],
                       "root, perfect fourth, octave — an OPEN FOURTH with no third at all")
        XCTAssertFalse(semitoneStack(of: .celticAir).contains(3),
                       "a minor third appeared; the whole point is that the chord is modeless")
        XCTAssertFalse(semitoneStack(of: .celticAir).contains(4), "nor a major third")
        XCTAssertEqual(MusicStyle.celticAir.scale, .dorian)
        XCTAssertEqual(MusicStyle.celticAir.harmonicProfile.progression, [0, 6], "i → ♭VII")

        XCTAssertEqual(semitoneStack(of: .andalusianCadence), [0, 4, 7],
                       "a MAJOR triad over a phrygian mode — the clash IS the cadence")
        XCTAssertEqual(MusicStyle.andalusianCadence.scale, .phrygianDominant)
        XCTAssertEqual(MusicStyle.andalusianCadence.harmonicProfile.progression, [0, 2, 1])
        XCTAssertEqual(MusicStyle.andalusianCadence.harmonicProfile.progression.first, 0, """
            The cadence no longer opens on the tonic. `composeHarmonic` rotates the progression \
            over `progressionPhase`, so a descent authored away from the tonic is never played \
            in its authored order — that is why the plan's `[2, 1, 0]` became `[0, 2, 1]`.
            """)
        let sameTurn = MusicStyle.allCases.filter {
            $0 != .andalusianCadence && $0.harmonicProfile.progression == [0, 2, 1]
        }
        XCTAssertTrue(sameTurn.isEmpty, "the doc calls this turn unique in the file; found \(sameTurn)")
    }

    // MARK: - Claim 3 — the second phrygianDominant genre, and the FIVE axes

    func testTheSecondPhrygianDominantGenreIsNotTheFirst() {
        let psy = MusicStyle.darkPsyTrance
        let cadence = MusicStyle.andalusianCadence
        XCTAssertEqual(psy.scale, cadence.scale, "the premise: the mode IS shared now")
        XCTAssertNotEqual(psy.harmonicProfile.arpeggiated, cadence.harmonicProfile.arpeggiated)
        XCTAssertNotEqual(psy.beatArchetype, cadence.beatArchetype)
        XCTAssertNotEqual(psy.harmonicProfile.padOctave, cadence.harmonicProfile.padOctave)
        XCTAssertNotEqual(psy.harmonicProfile.progression, cadence.harmonicProfile.progression)
        XCTAssertFalse(psy.tempoRange.overlaps(cadence.tempoRange),
                       "145…155 against 90…130 — the fifth axis, and the windows must not touch")
        // The retraction this batch forced, pinned so it cannot be re-written as exclusivity.
        let allPD = MusicStyle.allCases.filter { $0.scale == .phrygianDominant }
        XCTAssertGreaterThan(allPD.count, 1, """
            `phrygianDominant` is back to a single user, so `darkPsyTrance`'s doc could be \
            rewritten to claim the mode is its own again — the claim #1290 had to retract. If \
            this is deliberate, retract this counterweight in the same commit.
            """)
    }

    // MARK: - Claim 4 — the pace, the first non-ambient Flow genre

    func testCelticAirIsTheFirstFlowGenreThatIsNotAPad() {
        XCTAssertEqual(MusicStyle.celticAir.beatArchetype, .none)
        XCTAssertFalse(MusicStyle.celticAir.isBeatDriven)
        XCTAssertEqual(MusicStyle.celticAir.chordArticulation, .sustained,
                       "`.none` derives `.sustained` articulation — that is the chord grid, not the flag")
        XCTAssertFalse(MusicStyle.celticAir.harmonicProfile.sustained, """
            `celticAir` became a sustained Fläche. The PROFILE flag suppresses the breath-onset \
            generator, and those onsets are what phrase an unmetred air — `ambientPulse` and \
            `slowBloom` are the two shipped genres in exactly this shape.
            """)
        XCTAssertEqual(MusicStyle.celticAir.defaultMode, .flowFree, """
            `celticAir` defaults to a locked grid tempo. `defaultMode` ends in \
            `default: .studioLocked`, so this is the omission a compiler cannot catch.
            """)
        // The claim the case doc makes: it is the first Flow genre outside the calm shelves.
        let flowOutsideMeditative = MusicStyle.allCases.filter {
            $0.defaultMode == .flowFree && $0.category != .meditative
        }
        XCTAssertEqual(flowOutsideMeditative, [.celticAir], """
            The set of Flow genres outside `.meditative` is \(flowOutsideMeditative.map(\.rawValue)). \
            The case doc calls `celticAir` the first and only one; a second means that sentence \
            is now wrong, not that this assertion is.
            """)

        XCTAssertEqual(MusicStyle.andalusianCadence.beatArchetype, .offbeat)
        XCTAssertEqual(MusicStyle.andalusianCadence.chordArticulation, .skank)
        XCTAssertEqual(MusicStyle.andalusianCadence.defaultMode, .studioLocked)
        for style in additions {
            XCTAssertTrue(style.tempoRange.contains(style.defaultTempo))
            XCTAssertFalse(style.harmonicProfile.arpeggiated)
            XCTAssertEqual(style.harmonicProfile.leadDensity, 0, accuracy: 0.0001)
            XCTAssertLessThan(style.swing, MusicStyle.modalJazz.swing, """
                \(style.rawValue) now swings at least as hard as `modalJazz`, whose doc and \
                `GenreBatchSixATests` both call it the largest of any offered genre.
                """)
        }
    }

    // MARK: - Claim 5 — the patches, the ceiling, and the neighbour claims they must not take

    func testThePatchesKeepEveryNeighbourClaim() {
        XCTAssertEqual(additions.map(\.synthPatch.name), ["Air Reed", "Nylon Pluck"])
        XCTAssertNil(MusicStyle.celticAir.bassPatch, "the air has no figure, so it needs no voice")
        XCTAssertEqual(MusicStyle.andalusianCadence.bassPatch?.name, "Cadence Sub")

        let allNames = MusicStyle.allCases.flatMap {
            [$0.synthPatch.name] + [$0.bassPatch?.name].compactMap { $0 }
        }
        XCTAssertEqual(Set(allNames).count, allNames.count,
                       "two patches ship under one name — the list is keyed by id and READ by name")
        let allIDs = MusicStyle.allCases.flatMap { [$0.synthPatch.id] + [$0.bassPatch?.id].compactMap { $0 } }
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "two patches share an id")

        // Neighbour superlatives, roster-wide, each quoted from the arm that carries it.
        let drone = MusicStyle.deepDrone.synthPatch
        for style in additions {
            XCTAssertLessThan(style.synthPatch.attack, drone.attack,
                              "\"\(style.synthPatch.name)\" took \"Drone Bed\"'s slowest-attack claim")
            XCTAssertLessThan(style.synthPatch.release, drone.release,
                              "\"\(style.synthPatch.name)\" took \"Drone Bed\"'s longest-release claim")
        }
        if let minimalSub = MusicStyle.minimalTechno.bassPatch, let cadence = MusicStyle.andalusianCadence.bassPatch {
            XCTAssertGreaterThan(cadence.filterCutoff, minimalSub.filterCutoff,
                                 "\"Cadence Sub\" took \"Minimal Sub\"'s lowest-cutoff claim")
        }
        if let psy = MusicStyle.psyProgHouse.bassPatch, let cadence = MusicStyle.andalusianCadence.bassPatch {
            XCTAssertGreaterThan(cadence.attack + cadence.decay + cadence.release,
                                 psy.attack + psy.decay + psy.release,
                                 "\"Cadence Sub\" took \"Psy Bass\"'s shortest-envelope claim")
        }

        let bearing = MusicStyle.allCases.filter { !$0.harmonicProfile.sustained }
        let ceiling = Int(ceil(Double(bearing.count) / 6.0))
        var counts: [String: Int] = [:]
        for style in bearing { counts[style.leadPatchName, default: 0] += 1 }
        for style in additions {
            XCTAssertLessThanOrEqual(counts[style.leadPatchName] ?? 0, ceiling, """
                \(style.rawValue) took "\(style.leadPatchName)", over the ceiling of \(ceiling) \
                across \(bearing.count) lead-bearing genres. The design sheet gave \
                `andalusianCadence` "Pluck", which was already on 7 — Choir Vox is the measured \
                replacement, not a preference.
                """)
        }
    }

    // MARK: - Claim 6 — the FX, and the delay axis this batch had to repair

    func testNeitherEchoesAndTheCalmAxisStillStands() {
        for style in additions {
            let p = style.fxPreset
            XCTAssertFalse(p.delayEnabled, """
                \(style.rawValue) gained an echo. Both arms say why they have none — an air's \
                phrase is not finished when the repeat arrives, and a repeat smears the ♭2 into \
                the tonic, which is the one interval the cadence exists for.
                """)
            XCTAssertTrue(p.reverbEnabled)
            XCTAssertFalse(p.filterEnabled,
                           "\(style.rawValue) enabled the chain filter — `acidTechno`'s alone, roster-wide")
            XCTAssertLessThan(p.reverbRoom, MusicStyle.contemplation.fxPreset.reverbRoom,
                              "\(style.rawValue) took contemplation's biggest-hall claim")
            XCTAssertLessThan(p.reverbDamping, MusicStyle.deepDrone.fxPreset.reverbDamping,
                              "\(style.rawValue) took deepDrone's most-damped claim")
            XCTAssertGreaterThan(p.reverbDamping, MusicStyle.drift.fxPreset.reverbDamping,
                                 "\(style.rawValue) is less damped than drift, whose arm claims that floor")
            XCTAssertGreaterThan(p.delayTone, MusicStyle.deepDrone.fxPreset.delayTone,
                                 "\(style.rawValue) took deepDrone's darkest-tone claim")
            XCTAssertLessThanOrEqual(p.delaySpread, MusicStyle.detroitTechno.fxPreset.delaySpread,
                                     "\(style.rawValue) is wider than detroitTechno, the widest offered spread")
        }
        // `andalusianCadence` IS beat-driven, so it is inside the scope of minimal's claim;
        // `celticAir` is not, and the assertion is written per-genre for exactly that reason.
        XCTAssertGreaterThan(MusicStyle.andalusianCadence.fxPreset.saturation,
                             MusicStyle.minimalTechno.fxPreset.saturation,
                             "andalusianCadence took minimalTechno's \"cleanest beat-driven chain\"")
        let filtered = MusicStyle.allCases.filter { $0.fxPreset.filterEnabled }
        XCTAssertEqual(filtered, [.acidTechno], "the chain filter is acidTechno's alone; found \(filtered)")

        // ⛔ THE RATCHET THIS BATCH HAD TO REPAIR, pinned from the other side so the repair
        // cannot silently become a licence to strip echoes off the calm family.
        let drumFreeOffered = MusicStyle.offered.filter { $0.beatArchetype == .none }
        let echoing = drumFreeOffered.filter { $0.fxPreset.delayEnabled }
        XCTAssertGreaterThanOrEqual(echoing.count, 7, """
            Only \(echoing.count) drum-free offered genres carry an echo. Seven is the floor \
            `GenreDelaySyncResolvabilityTests` now asserts; this batch added a THIRD genre with \
            none (after glacialField and slowBloom) and that is legal, taking one away is not.
            """)
        XCTAssertGreaterThan(drumFreeOffered.count, echoing.count,
                             "every drum-free offered genre echoes again — the equality this batch "
                             + "replaced would be assertable once more, so re-read why it was not")
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

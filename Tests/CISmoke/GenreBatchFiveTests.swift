// GenreBatchFiveTests.swift
// Echoel — G5's two Contemplative additions, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreDeepTechTests` form: door · voicing · pace ·
// patch · FX ordering against NAMED neighbours. Nothing here is a source-text scan; every claim
// reads the shipped values.
//
// ⭐ THE SHELF THIS BATCH FILLS. `Still Pads` held five genres and `Moving Ambient` held ONE
// (`ambientPulse`), which is the shape #1275's taxonomy was supposed to fix and could not —
// a shelf is only as useful as the number of things standing on it. `glacialField` and
// `slowBloom` are the two that make Moving Ambient a shelf rather than a label, and they are
// deliberately opposites of the genres they stand beside:
//   · `glacialField` vs `deepDrone` — SAME stillness, OPPOSITE register. deepDrone is the
//     darkest, lowest bed in the product (padOctave 2, brightness 0.10); this is the HIGHEST
//     sustained genre (padOctave 5) with a bright, lightly damped hall.
//   · `slowBloom` vs `ambientPulse` — SAME shelf, opposite motion. The pulse repeats; the bloom
//     opens once and keeps opening.
//
// ⚠️ THE LEAD PATCH NAME WAS COMPUTED, NOT PICKED, and that is the batch template's own rule.
// `slowBloom` is lead-bearing (`sustained: false`), so it counts toward the pigeonhole ceiling
// `ceil(leadBearing / 6)`. At 28 lead-bearing genres the ceiling is 5, and Deep Sub, Pluck and
// Soft Keys were ALREADY at 5 — naming any of them would have turned
// `GenreBatchFourVoicingTests` red on a correct batch. Hollow Reed and Warm Strings sat at 4.
// `glacialField` is `sustained` and therefore does NOT count, which is why it may take Warm
// Strings without moving the arithmetic. Claim 4 pins the consequence rather than the number,
// so it cannot go stale the way a literal would (#818).
//
// ⛔ WHAT THIS FILE DOES NOT ASSERT, because a roster-wide sweep already does and two spellings
// of one law is the defect (#416): that no two OFFERED genres share an audible fingerprint
// (`GenreFamilyDistinctnessTests`), that every division resolves at its fastest allowed tempo
// (`GenreDelaySyncResolvabilityTests` — both presets have no delay at all, so they are skipped
// there by construction), and that the published genre counts match the roster
// (`WebsitePagesAreFindableAndHonestTests`).
//
// NEEDS-FOUNDER-VERIFY: pick Glacial Field with a calm body and listen for a minute — is the
// high cluster BEATING audibly (the intended movement) or just sitting there as a chord? Then
// Slow Bloom: does the stack read as OPENING, or as a pad that simply fades in? Both are ear
// questions no test can answer, and they are the only two things about this batch that are not
// measured.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFiveTests: XCTestCase {

    private let additions: [MusicStyle] = [.glacialField, .slowBloom]

    // MARK: - Claim 1 — the door

    func testBothAdditionsAreReachable() {
        for style in additions {
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) is built but not offered — a doorless genre")
            XCTAssertEqual(style.category, .meditative)
            XCTAssertTrue(MusicStyle.Category.meditative.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its category's offered subset")
            XCTAssertTrue(style.subcategory.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its SHELF's offered subset")
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.lineage.isEmpty)
        }
        XCTAssertEqual(MusicStyle.glacialField.subcategory, .stillPads)
        XCTAssertEqual(MusicStyle.slowBloom.subcategory, .movingAmbient)
        XCTAssertEqual(MusicStyle.glacialField.displayName, "Glacial Field")
        XCTAssertEqual(MusicStyle.slowBloom.displayName, "Slow Bloom")
        XCTAssertGreaterThanOrEqual(MusicStyle.Subcategory.movingAmbient.offeredGenres.count, 2, """
            Moving Ambient is back to one resident. The point of this batch is that a shelf with \
            one genre on it is a label, not a shelf.
            """)
    }

    // MARK: - Claim 2 — the voicing, and that it is nobody else's

    func testTheVoicingsAreNewToTheRoster() {
        let glacial = MusicStyle.glacialField.harmonicProfile
        XCTAssertEqual(glacial.chordTones, [0, 1, 4], "the CLUSTER is the genre")
        XCTAssertEqual(glacial.progression, [0, 2])
        XCTAssertEqual(glacial.padOctave, 5)
        XCTAssertTrue(glacial.sustained)
        XCTAssertFalse(glacial.arpeggiated)
        XCTAssertEqual(MusicStyle.glacialField.scale, .lydianAugmented)

        let bloom = MusicStyle.slowBloom.harmonicProfile
        XCTAssertEqual(bloom.chordTones, [0, 2, 4, 6, 8], "five degrees over a six-note scale")
        XCTAssertEqual(bloom.progression, [0, 2])
        XCTAssertEqual(bloom.padOctave, 4)
        XCTAssertFalse(bloom.sustained, """
            `slowBloom` has become a sustained Fläche. That suppresses the onset generator, and \
            the onsets ARE the opening — the same call `ambientPulse` documents for itself.
            """)
        XCTAssertEqual(MusicStyle.slowBloom.scale, .prometheus)

        for style in additions {
            let copies = MusicStyle.allCases.filter {
                $0 != style && $0.harmonicProfile.chordTones == style.harmonicProfile.chordTones
            }
            XCTAssertTrue(copies.isEmpty, """
                \(style.rawValue)'s voicing \(style.harmonicProfile.chordTones) is also carried \
                by \(copies.map(\.rawValue)). The case doc says it is new to the roster; either \
                the doc or the arm is now wrong.
                """)
            XCTAssertEqual(style.harmonicProfile.leadDensity, 0, accuracy: 0.0001,
                           "\(style.rawValue) would wake the five dormant lead paths")
        }
    }

    // MARK: - Claim 3 — the pace, and the mode a Fläche must default to

    func testBothAreBreathPacedAndDrumFree() {
        for style in additions {
            XCTAssertEqual(style.beatArchetype, .none)
            XCTAssertEqual(style.chordArticulation, .sustained)
            XCTAssertFalse(style.isBeatDriven)
            XCTAssertEqual(style.swing, 0, accuracy: 0.0001, "a Fläche has no shuffle to swing")
            XCTAssertEqual(style.defaultMode, .flowFree, """
                \(style.rawValue) defaults to a locked grid tempo. `defaultMode` ends in \
                `default: .studioLocked`, so this is the omission a compiler cannot catch — and \
                it would put a 50-BPM glacial pad on a studio clock.
                """)
            XCTAssertTrue(style.tempoRange.contains(style.defaultTempo),
                          "\(style.rawValue)'s default tempo is outside its own window")
        }
        XCTAssertEqual(MusicStyle.glacialField.tempoRange, 42...60)
        XCTAssertEqual(MusicStyle.glacialField.defaultTempo, 50)
        XCTAssertEqual(MusicStyle.slowBloom.tempoRange, 56...72)
        XCTAssertEqual(MusicStyle.slowBloom.defaultTempo, 62)
        XCTAssertLessThan(MusicStyle.glacialField.tempoRange.upperBound,
                          MusicStyle.slowBloom.tempoRange.upperBound,
                          "the still shelf must sit under the moving one")
    }

    // MARK: - Claim 4 — the patches, and the ceiling the lead name was chosen against

    func testThePatchesAreTheirOwnAndTheLeadNameStaysUnderTheCeiling() {
        XCTAssertEqual(MusicStyle.glacialField.synthPatch.name, "Glacier Pad")
        XCTAssertEqual(MusicStyle.slowBloom.synthPatch.name, "Bloom Pad")
        XCTAssertNotEqual(MusicStyle.glacialField.synthPatch.id, MusicStyle.slowBloom.synthPatch.id)
        XCTAssertNil(MusicStyle.glacialField.bassPatch, "a Fläche has no authored bass figure")
        XCTAssertNil(MusicStyle.slowBloom.bassPatch)
        XCTAssertNil(MusicStyle.glacialField.bassGrammar)
        XCTAssertNil(MusicStyle.slowBloom.bassGrammar)

        // deepDrone's own doc claims the slowest attack and the longest release of any genre
        // patch. Both survive this batch on purpose — a new patch that quietly took a
        // superlative would leave a false sentence two files away with nothing going red.
        XCTAssertLessThan(MusicStyle.glacialField.synthPatch.attack,
                          MusicStyle.deepDrone.synthPatch.attack,
                          "deepDrone's \"slowest attack of any genre patch\" must survive")
        XCTAssertLessThan(MusicStyle.glacialField.synthPatch.release,
                          MusicStyle.deepDrone.synthPatch.release,
                          "deepDrone's \"longest release\" must survive")
        XCTAssertGreaterThan(MusicStyle.glacialField.synthPatch.brightness,
                             MusicStyle.deepDrone.synthPatch.brightness, """
            The two stillest genres now read as one patch at two registers. deepDrone is the \
            dark end and this is the bright one; that contrast is the whole reason the shelf \
            can hold both.
            """)
        XCTAssertGreaterThan(MusicStyle.slowBloom.synthPatch.harmonicity,
                             MusicStyle.glacialField.synthPatch.harmonicity,
                             "the shelf's two residents differ in timbre as well as in motion")

        // The ceiling, DERIVED — never a literal (#818). This is the arithmetic the batch
        // template says to run before choosing a lead name, asserted rather than remembered.
        let bearing = MusicStyle.allCases.filter { !$0.harmonicProfile.sustained }
        let ceiling = Int(ceil(Double(bearing.count) / 6.0))
        var counts: [String: Int] = [:]
        for style in bearing { counts[style.leadPatchName, default: 0] += 1 }
        XCTAssertLessThanOrEqual(counts[MusicStyle.slowBloom.leadPatchName] ?? 0, ceiling, """
            `slowBloom` took a lead name that is already at the pigeonhole ceiling of \
            \(ceiling) over \(bearing.count) lead-bearing genres. The name is the one field \
            that may move without a plan change — move it to a name below the ceiling rather \
            than widening the palette.
            """)
        XCTAssertTrue(MusicStyle.glacialField.harmonicProfile.sustained, """
            `glacialField` is no longer sustained, so it now COUNTS toward the ceiling the \
            comment above says it does not. Re-run the arithmetic before trusting either \
            addition's lead name — this is the assumption, not the conclusion.
            """)
    }

    // MARK: - Claim 5 — the FX, placed against neighbours that make superlative claims

    func testTheHallsSitUnderEveryNeighbourThatClaimsAnExtreme() {
        let glacial = MusicStyle.glacialField.fxPreset
        let bloom = MusicStyle.slowBloom.fxPreset

        for (name, preset) in [("glacialField", glacial), ("slowBloom", bloom)] {
            XCTAssertFalse(preset.delayEnabled, """
                \(name) grew a delay. An echo repeats an event, and neither genre has one to \
                repeat — the design is a hall and nothing else.
                """)
            XCTAssertTrue(preset.reverbEnabled)
            XCTAssertTrue(preset.chorusEnabled, "the chorus is what widens the stack")
            XCTAssertFalse(preset.filterEnabled)
            XCTAssertFalse(preset.phaserEnabled)
            XCTAssertFalse(preset.harmonizerEnabled)
        }

        // `contemplation`'s arm says "the BIGGEST hall in the roster"; `drift`'s says "the
        // brightest, least-damped big hall". Both are prose in GenreFX.swift, and prose does
        // not go red on its own — this is what makes them survive a batch.
        for (name, preset) in [("glacialField", glacial), ("slowBloom", bloom)] {
            XCTAssertLessThan(preset.reverbRoom, MusicStyle.contemplation.fxPreset.reverbRoom,
                              "\(name) took contemplation's \"biggest hall in the roster\"")
            XCTAssertLessThan(preset.reverbRoom, MusicStyle.drift.fxPreset.reverbRoom,
                              "\(name) now has a bigger hall than drift")
            XCTAssertGreaterThan(preset.reverbDamping, MusicStyle.drift.fxPreset.reverbDamping,
                                 "\(name) took drift's \"least-damped big hall\"")
        }
        XCTAssertGreaterThan(glacial.reverbRoom, bloom.reverbRoom,
                             "the glacial space is the wider of the two")
        XCTAssertLessThan(glacial.reverbDamping, bloom.reverbDamping,
                          "and the brighter — that pair IS how a listener tells the shelves apart")
    }

    // MARK: - Claim 6 (COUNTERWEIGHT) — the roster still composes

    /// Green on both trees by construction (#343). Two genres were spliced into eleven
    /// exhaustive switches; the cheapest way for that to be wrong is a genre that resolves but
    /// produces nothing.
    func testEveryOfferedGenreStillComposesAPad() {
        for style in MusicStyle.offered {
            let input = BioComposer.Input(heartRateBPM: 56, hrvNormalized: 0.8, coherence: 0.9,
                                          breathPhase: 0.25, breathDepth: 0.2,
                                          key: MusicalKey(root: 0, scale: style.scale),
                                          style: style, mode: style.defaultMode,
                                          lockedTempo: style.defaultTempo,
                                          seed: 0xD00D, suggestJourney: true)
            let pad = BioComposer.compose(input).notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, "\(style.rawValue) produces no pad at a resting body")
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style.rawValue) has a zero-length pad note (#205/#176)")
        }
    }
}

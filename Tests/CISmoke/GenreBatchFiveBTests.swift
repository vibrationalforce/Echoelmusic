// GenreBatchFiveBTests.swift
// Echoel — G5b's three electronic additions, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchFiveTests` / `GenreDeepTechTests` form:
// door · voicing · pace · patch · FX placed against NAMED neighbours · bass figure. Nothing here
// is a source-text scan; every claim reads a shipped value.
//
// ⭐ WHAT THE BATCH IS FOR. `Techno` held six residents, `House` three and `Trance` one. These
// three are the poles those shelves were missing, and each is defined AGAINST a resident rather
// than as "more of the same":
//   · `industrialTechno` vs `darkMinimal` — SAME `sparseSub` figure, OPPOSITE harmony. Dark
//     minimal is phrygian with a wide hollow open-fifth stack; this is locrian with a semitone
//     cluster that has no fifth at all.
//   · `afroHouse` vs `deepHouse` — SAME `.offbeat` archetype and `offbeatEighths` figure, warmer
//     mode and a four-step vamp that comes home MID-CYCLE instead of stating one change.
//   · `darkPsyTrance` vs `psyProgHouse` — the psy family's two halves: this one arpeggiated at a
//     trance tempo on `phrygianDominant`, that one a plain stab at a house tempo on minor.
//
// ⚠️ WHAT THIS FILE DELIBERATELY DOES **NOT** ASSERT, because asserting it would be wrong rather
// than merely redundant:
//   · **Voicing uniqueness.** `GenreBatchFiveTests` could sweep for it because a CLUSTER is rare.
//     `afroHouse` and `darkPsyTrance` both carry `[0, 2, 4]`, which eighteen arms carry — the
//     offered `sciFi` even shares the full `(chordTones, progression)` PAIR with darkPsyTrance.
//     A copied uniqueness sweep would have been red on a correct tree (#364). What IS asserted is
//     the property each genre's doc actually claims: a unique MODE, a unique PROGRESSION SHAPE.
//   · The roster-wide fingerprint sweep (`GenreFamilyDistinctnessTests`), the delay-division
//     resolvability sweep (`GenreDelaySyncResolvabilityTests`) and the published genre counts
//     (`WebsitePagesAreFindableAndHonestTests`) — one owner per claim (#416).
//   · That `psyProgHouse` is the only offered four-on-floor genre on ping-pong. That sweep lives
//     in `GenrePsyProgHouseTests`, it is why `darkPsyTrance` takes `.digital` against the family
//     resemblance, and re-spelling it here would be the second home (#416).
//
// NEEDS-FOUNDER-VERIFY: play Industrial Techno for a minute — does the fifth-less cluster read as
// METAL, or merely as a wrong chord? Then Afro House: does the mid-cycle return to the root read
// as a groove cycle rather than a loop restarting? Both are ear questions no test can answer.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFiveBTests: XCTestCase {

    private let additions: [MusicStyle] = [.industrialTechno, .afroHouse, .darkPsyTrance]

    // MARK: - Claim 1 — the door

    func testAllThreeAdditionsAreReachable() {
        for style in additions {
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) is built but not offered — a doorless genre (#254)")
            XCTAssertEqual(style.category, .electronic,
                           "\(style.rawValue) must be categorised or `Category.genres` is no "
                           + "longer the full taxonomy")
            XCTAssertTrue(MusicStyle.Category.electronic.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its category's offered subset")
            XCTAssertTrue(style.subcategory.offeredGenres.contains(style),
                          "\(style.rawValue) is offered but absent from its SHELF's offered subset")
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.lineage.isEmpty)
        }
        XCTAssertEqual(MusicStyle.industrialTechno.subcategory, .techno)
        XCTAssertEqual(MusicStyle.afroHouse.subcategory, .house)
        XCTAssertEqual(MusicStyle.darkPsyTrance.subcategory, .trance)
        XCTAssertEqual(MusicStyle.industrialTechno.displayName, "Industrial Techno")
        XCTAssertEqual(MusicStyle.afroHouse.displayName, "Afro House")
        XCTAssertEqual(MusicStyle.darkPsyTrance.displayName, "Dark Psy")
        XCTAssertGreaterThanOrEqual(MusicStyle.Subcategory.trance.offeredGenres.count, 2, """
            Trance is back to one resident. A shelf with one genre on it is a label, not a shelf \
            — the same argument G5a made for Moving Ambient.
            """)
    }

    // MARK: - Claim 2 — the harmony, asserted in SEMITONES, not in degree literals

    /// A degree array means nothing without its scale — `deepDrone`'s `[0, 3, 6]` on a five-note
    /// scale is a completely different chord from the same digits on a seven-note one. So the
    /// industrial cluster is resolved through `MusicalKey.degree`, the way `GenreBatchFourVoicingTests`
    /// resolves its two.
    func testTheIndustrialClusterHasNoFifthAtAll() {
        let semitones = semitoneStack(of: .industrialTechno)
        XCTAssertEqual(semitones, [0, 1, 8], """
            The industrial voicing is no longer root + ♭2 + ♭6 (got \(semitones)). Degrees \
            [0, 1, 5] on locrian resolve to 0, 1 and 8 — the ♭5 is in the MODE, not in the pad, \
            and the case doc records the draft that read the array as semitones and claimed a \
            tritone that is not there.
            """)
        XCTAssertFalse(semitones.contains(6), """
            A tritone appeared in the industrial pad. If that is deliberate, the chord array \
            became `[0, 1, 4]` — which is `glacialField`'s array, and `GenreBatchFiveTests` \
            sweeps that voicing for uniqueness. Change one and the other goes red.
            """)
        XCTAssertFalse(semitones.contains(7), "a perfect fifth appeared — the absence IS the genre")
        XCTAssertEqual(MusicStyle.industrialTechno.scale, .locrian)
        let otherLocrian = MusicStyle.allCases.filter { $0 != .industrialTechno && $0.scale == .locrian }
        XCTAssertTrue(otherLocrian.isEmpty, """
            \(otherLocrian.map(\.rawValue)) also use locrian. The case doc claims this is the \
            only genre-used scale whose FIFTH DEGREE is a tritone; either the doc or the arm moved.
            """)
    }

    /// The afro vamp's claim is its SHAPE, not its notes: four steps whose root returns in the
    /// MIDDLE. `classical`'s `[0, 3, 4, 0]` returns on the last step (a phrase close); nothing
    /// else returns at all. That is asserted as the derived property, so a renumbered vamp that
    /// keeps the shape stays green and one that loses it goes red.
    func testTheAfroVampComesHomeMidCycle() {
        let prog = MusicStyle.afroHouse.harmonicProfile.progression
        XCTAssertEqual(prog.count, 4)
        XCTAssertEqual(prog.first, 0)
        let interiorReturns = prog.dropFirst().dropLast().filter { $0 == prog[0] }
        XCTAssertEqual(interiorReturns.count, 1, """
            The afro vamp \(prog) no longer returns to its root mid-cycle. That return is the \
            whole separation from every other four-step arm in the file — without it this is \
            another three-root house progression with a spare step.
            """)
        let sameShape = MusicStyle.allCases.filter {
            $0 != .afroHouse && $0.harmonicProfile.progression == prog
        }
        XCTAssertTrue(sameShape.isEmpty, "\(sameShape.map(\.rawValue)) now carry the same vamp")
        XCTAssertEqual(MusicStyle.afroHouse.scale, .dorian, "shared with dubTechno/drift/detroitTechno")
        XCTAssertEqual(semitoneStack(of: .afroHouse), [0, 3, 7], "a plain minor triad, stated plainly")
    }

    /// The psy separation is the MODE and the arpeggio, never the array — this is the assertion
    /// that replaces the uniqueness sweep the header refuses, and it is a COUNTERWEIGHT: it is
    /// green today and names the exact sharer, so a future uniqueness claim cannot be written
    /// without this going red first.
    func testTheDarkPsyModeIsItsOwnAndItsVoicingIsNot() {
        XCTAssertEqual(MusicStyle.darkPsyTrance.scale, .phrygianDominant)
        let otherPD = MusicStyle.allCases.filter {
            $0 != .darkPsyTrance && $0.scale == .phrygianDominant
        }
        XCTAssertTrue(otherPD.isEmpty, "\(otherPD.map(\.rawValue)) also use phrygianDominant")
        XCTAssertTrue(MusicStyle.darkPsyTrance.harmonicProfile.arpeggiated,
                      "the psy identity is a pitch figure walking the voicing, not a chord")
        XCTAssertFalse(MusicStyle.psyProgHouse.harmonicProfile.arpeggiated,
                       "the family's two halves are separated by exactly this")

        let profile = MusicStyle.darkPsyTrance.harmonicProfile
        let sharers = MusicStyle.allCases.filter {
            $0 != .darkPsyTrance
                && $0.harmonicProfile.chordTones == profile.chordTones
                && $0.harmonicProfile.progression == profile.progression
        }
        XCTAssertFalse(sharers.isEmpty, """
            Nothing shares darkPsyTrance's (chordTones, progression) pair any more. That is not \
            a failure of this genre — it means the arm that shared it (sciFi, offered) moved. \
            The case doc states the sharing explicitly so nobody writes a uniqueness claim here; \
            if the sharing is genuinely gone, delete this assertion and the doc line together.
            """)
    }

    // MARK: - Claim 3 — the pace, and the mode a beat-driven genre must default to

    func testAllThreeAreBeatDrivenOnAStudioClock() {
        for style in additions {
            XCTAssertTrue(style.isBeatDriven)
            XCTAssertNotEqual(style.beatArchetype, .none)
            XCTAssertEqual(style.defaultMode, .studioLocked, """
                \(style.rawValue) defaults to flow-free. A four-on-floor or offbeat genre on a \
                body-following clock has no grid to be offbeat AGAINST.
                """)
            XCTAssertTrue(style.tempoRange.contains(style.defaultTempo),
                          "\(style.rawValue)'s default tempo is outside its own window")
        }
        XCTAssertEqual(MusicStyle.industrialTechno.beatArchetype, .fourOnFloor)
        XCTAssertEqual(MusicStyle.darkPsyTrance.beatArchetype, .fourOnFloor)
        XCTAssertEqual(MusicStyle.afroHouse.beatArchetype, .offbeat)
        XCTAssertEqual(MusicStyle.afroHouse.chordArticulation, .skank, """
            `chordArticulation` is DERIVED from `beatArchetype`, so this is really a claim about \
            the archetype — and the offbeat chord is what the afro lineage line promises.
            """)
        XCTAssertEqual(MusicStyle.industrialTechno.swing, 0, accuracy: 0.0001, "metal is machine-straight")
        XCTAssertEqual(MusicStyle.darkPsyTrance.swing, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(MusicStyle.afroHouse.swing, 0, "the lilt is the genre")
        XCTAssertLessThan(MusicStyle.afroHouse.swing, MusicStyle.deepHouse.swing, """
            Afro house now shuffles as hard as deep house. The two share an archetype AND a bass \
            figure; the swing depth is one of the few axes left that tells them apart.
            """)
        XCTAssertLessThan(MusicStyle.afroHouse.tempoRange.upperBound,
                          MusicStyle.industrialTechno.tempoRange.lowerBound,
                          "house sits under techno")
        XCTAssertLessThanOrEqual(MusicStyle.industrialTechno.tempoRange.upperBound,
                                 MusicStyle.darkPsyTrance.tempoRange.lowerBound, """
            The techno and psy windows now OVERLAP. They are allowed to touch — both end and \
            begin at 145, and the case doc says the psy tempo family is deliberately adjacent \
            to psytrance's — but an overlap means the two genres can be handed the same tempo \
            and then differ only in mode. (The strict `<` stood here for one draft and was red \
            on a correct tree at 145 vs 145: an ordering guard has to decide whether touching \
            is legal, and it is here — #364.)
            """)
    }

    // MARK: - Claim 4 — the patches, and the ceiling the lead names were chosen against

    func testThePatchesAreTheirOwnAndTheLeadNamesStayUnderTheCeiling() {
        let names = additions.map(\.synthPatch.name)
        XCTAssertEqual(names, ["Iron Stab", "Warm Skank", "Dark Arp"])
        XCTAssertEqual(Set(additions.map(\.synthPatch.id)).count, additions.count)
        for style in additions {
            let bass = style.bassPatch
            XCTAssertNotNil(bass, """
                \(style.rawValue) has an authored bass GRAMMAR and no bass PATCH. Share a figure, \
                never a voice — otherwise two genres become one bassline at two tempos.
                """)
        }
        XCTAssertEqual(Set(additions.compactMap { $0.bassPatch?.id }).count, additions.count)
        let allBassNames = MusicStyle.allCases.compactMap { $0.bassPatch?.name }
        XCTAssertEqual(Set(allBassNames).count, allBassNames.count, """
            Two genres ship a bass patch under the same NAME. The preset list is keyed by id but \
            READ by name; `darkPsyTrance` took "Void Sub" precisely because `darkMinimal` already \
            ships a "Dark Sub".
            """)

        // The ceiling, DERIVED — never a literal (#818). This is the arithmetic the batch
        // template says to run before choosing a lead name, asserted rather than remembered.
        let bearing = MusicStyle.allCases.filter { !$0.harmonicProfile.sustained }
        let ceiling = Int(ceil(Double(bearing.count) / 6.0))
        var counts: [String: Int] = [:]
        for style in bearing { counts[style.leadPatchName, default: 0] += 1 }
        for style in additions {
            XCTAssertLessThanOrEqual(counts[style.leadPatchName] ?? 0, ceiling, """
                \(style.rawValue) took the lead name "\(style.leadPatchName)", which is over the \
                pigeonhole ceiling of \(ceiling) across \(bearing.count) lead-bearing genres. The \
                name is the one field that may move without a plan change — `darkPsyTrance` was \
                moved off "Deep Sub" for exactly this reason. Move it to a name below the ceiling \
                rather than widening the palette.
                """)
        }
    }

    // MARK: - Claim 5 — the FX, placed against neighbours that make superlative claims

    /// Every one of these orderings exists because a NEIGHBOUR's comment claims a superlative.
    /// Prose does not go red on its own; this is what makes those sentences survive a batch —
    /// and #1286 found two of them already false before adding anything, so they are asserted
    /// here as ORDERINGS over shipped values, never as the literals the arms happen to carry.
    func testEveryNeighbourSuperlativeSurvivesTheBatch() {
        let minimal = MusicStyle.minimalTechno.fxPreset
        let techHouse = MusicStyle.techHouse.fxPreset
        let deepDrone = MusicStyle.deepDrone.fxPreset
        let detroit = MusicStyle.detroitTechno.fxPreset

        for style in additions {
            let p = style.fxPreset
            XCTAssertTrue(p.delayEnabled)
            XCTAssertTrue(p.reverbEnabled)
            XCTAssertFalse(p.filterEnabled, """
                \(style.rawValue) enabled the chain filter. `acidTechno`'s arm claims to be the \
                only genre that does, and that is a roster-wide claim.
                """)
            XCTAssertFalse(p.harmonizerEnabled)
            if style.beatArchetype == .fourOnFloor {
                XCTAssertLessThan(p.delayFeedback, minimal.delayFeedback, """
                    \(style.rawValue) took `minimalTechno`'s "longest tail of the four-on-floor \
                    offered genres".
                    """)
            }
            XCTAssertGreaterThan(p.saturation, minimal.saturation, """
                \(style.rawValue) took `minimalTechno`'s "cleanest beat-driven chain" — a \
                blocking claim in that arm.
                """)
            XCTAssertLessThan(p.reverbDamping, techHouse.reverbDamping, """
                \(style.rawValue) is now damped harder than `techHouse`, whose arm enumerates \
                the presets above it. Add this one to that list or lower the damping.
                """)
            XCTAssertGreaterThan(p.delayTone, deepDrone.delayTone, """
                \(style.rawValue) took `deepDrone`'s "darkest tone in the roster".
                """)
            XCTAssertLessThanOrEqual(p.delaySpread, detroit.delaySpread, """
                \(style.rawValue) is now wider than `detroitTechno`, which is the widest spread \
                in the offered roster. #1286 corrected a comment that credited that superlative \
                to `drift` (0.55) — drift's own sentence is scoped to the ambient presets.
                """)
        }

        // `acidTechno`'s filter claim asserted from the other side, so the loop above cannot go
        // green because the filter left the roster entirely.
        let filtered = MusicStyle.allCases.filter { $0.fxPreset.filterEnabled }
        XCTAssertEqual(filtered, [.acidTechno], "the chain filter is acidTechno's alone; found \(filtered)")
    }

    // MARK: - Claim 6 — the bass figures, shared by design and voiced apart

    func testTheBassFiguresAreSharedAndTheVoicesAreNot() {
        XCTAssertEqual(MusicStyle.industrialTechno.bassGrammar, .sparseSub, "darkMinimal's figure")
        XCTAssertEqual(MusicStyle.afroHouse.bassGrammar, .offbeatEighths, "deepHouse's figure")
        XCTAssertEqual(MusicStyle.darkPsyTrance.bassGrammar, .rollingSixteenths, "psyProgHouse's figure")

        // Each addition is the SECOND owner of a figure that already had one. That is the design
        // — `GenrePsyProgHouseTests` had to be amended in this same commit because it forbade it
        // outright, which is the #364 shape: a guard that reddens on correct work.
        for style in additions {
            guard let figure = style.bassGrammar else { return XCTFail("\(style.rawValue) lost its figure") }
            let owners = MusicStyle.allCases.filter { $0.bassGrammar == figure }
            XCTAssertGreaterThanOrEqual(owners.count, 2,
                                        "\(figure) is \(style.rawValue)'s alone — the batch doc says it is shared")
            let ids = owners.compactMap { $0.bassPatch?.id }
            XCTAssertEqual(ids.count, owners.count,
                           "a \(figure) owner has no bass patch: \(owners.filter { $0.bassPatch == nil }.map(\.rawValue))")
            XCTAssertEqual(Set(ids).count, ids.count,
                           "two \(figure) owners share a bass patch — share the figure, never the voice")
        }
    }

    // MARK: - Claim 7 (COUNTERWEIGHT) — the roster still composes

    /// Green on both trees by construction (#343). Three genres were spliced into eleven
    /// exhaustive switches; the cheapest way for that to be wrong is a genre that resolves and
    /// then produces nothing.
    func testEveryOfferedGenreStillComposesAPad() {
        for style in MusicStyle.offered {
            let input = BioComposer.Input(heartRateBPM: 62, hrvNormalized: 0.7, coherence: 0.6,
                                          breathPhase: 0.25, breathDepth: 0.3,
                                          key: MusicalKey(root: 0, scale: style.scale),
                                          style: style, mode: style.defaultMode,
                                          lockedTempo: style.defaultTempo,
                                          seed: 0xBEEF, suggestJourney: true)
            let pad = BioComposer.compose(input).notes.filter { $0.role == .harmony }
            XCTAssertFalse(pad.isEmpty, "\(style.rawValue) produces no pad at a resting body")
            XCTAssertTrue(pad.allSatisfy { $0.lengthSteps >= 1 },
                          "\(style.rawValue) has a zero-length pad note (#205/#176)")
        }
    }

    // MARK: - helper (#416: the same resolution `GenreBatchFourVoicingTests` uses)

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

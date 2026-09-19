// END-TO-END BEHAVIOUR (§1) over shipped value types — `MusicStyle`, `MusicalKey`,
// `GenreFXPreset`, `SynthPatch`. It drives the real arms; it says nothing about how the genre
// SOUNDS, which is an ear and stays open (NEEDS-FOUNDER-VERIFY below).
//
// ── WHAT #1382 G14c SHIPS ──────────────────────────────────────────────────────────
// `andeanHighland`, the THIRD and last door on the Latin America shelf. Post-cut, measured:
// 58 genres, 41 offered, 83 patches, GenreFX arms 58 of 58, fingerprint sweep empty, all six
// lead names at 8 against a ceiling of 8.
//
// The genre's identity is the ROOTS and the REGISTER, not the chord shape:
//   · `progression [0, 5, 6]` on `minor` — roots 0, 8, 10 semitones, i → ♭VI → ♭VII, and the
//     same `[0, 2, 4]` triad comes out MINOR on the tonic and MAJOR on both others. That is
//     why this arm takes plain `minor` where both shelf-mates reached for `harmonicMinor`.
//   · `.none` archetype, NOT `sustained` — the `celticAir`/`ambientPulse` shape, but
//     `.studioLocked`: highland dance music has a fixed pulse. `classical` is the only other
//     `.none` arm that locks.
//   · The two patches own both ends of the file's brightness axis (`Thin Air Pad` 0.72 max,
//     `Air Sub` 0.09 min).
//
// ── GRADING AGAINST THE PARENT (§3) ────────────────────────────────────────────────
// The file names a symbol this commit creates, so it DOES NOT COMPILE against the parent and
// NO assertion has a verdict there (§3's explicit case). Graded by transcription instead (§0):
// every claim re-implemented in Python and driven against the worktree, plus mutants.
//   · FORWARD guards: 1–6 — they drive an arm this commit writes and could never have been red.
//   · COUNTERWEIGHTS inside them, green regardless of this genre: the shelf's other two
//     residents, `slowedGothPop`'s minor-major seventh, the `sparseSub` owner set, the
//     11-genre shared reverb floor.
//
// ⚠️ #364 — nothing here forbids ordinary work. The tempo window, the swing, the patch numbers
// and the reverb values are all free to move; what is pinned is that the ROOTS produce a minor
// tonic with two major chords, that the shelf holds three OFFERED residents, that the echo
// resolves, and that the two voices are this genre's own.
//
// NEEDS-FOUNDER-VERIFY: on the device, does `andeanHighland` read as thin and open next to
// `cumbia` and `tangoMarcato` on the same shelf — or does the 0.62 room simply make it vague?
// The quarter echo at 100 BPM is 0.600 s; is that one reflection, or a second chord?

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchFourteenCTests: XCTestCase {

    // MARK: - 1 · Offered, and the shelf now holds three

    func testTheGenreIsOfferedAndTheShelfHoldsThree() {
        let style = MusicStyle.andeanHighland
        XCTAssertEqual(style.displayName, "Andean Highland")
        XCTAssertTrue(MusicStyle.offered.contains(style),
                      "a genre nobody can choose is not shipped")
        XCTAssertEqual(style.subcategory, .latinAmerica)

        // All three must be OFFERED, or the picker renders a section that silently omits one.
        let residents = MusicStyle.offered.filter { $0.subcategory == .latinAmerica }
        XCTAssertEqual(Set(residents), [.cumbia, .tangoMarcato, .andeanHighland])

        // COUNTERWEIGHT: no shelf was added by this slice, so `.folk` must read exactly as
        // before — claim 6 of `GenreSubcategoryTests` requires a rubric's shelves to be
        // contiguous, and this is the cheapest place to notice a silent reorder.
        let folkShelves = MusicStyle.Subcategory.allCases.filter { $0.parent == .folk }
        XCTAssertEqual(folkShelves, [.europeanFolk, .nearEastCentralAsia, .latinAmerica])
    }

    // MARK: - 2 · The roots are the genre: minor tonic, two major chords a tone apart

    func testTheCycleIsAMinorTonicUnderTwoMajorChords() {
        let style = MusicStyle.andeanHighland
        XCTAssertEqual(style.scale, .minor)
        XCTAssertEqual(style.harmonicProfile.progression, [0, 5, 6])
        XCTAssertEqual(style.harmonicProfile.chordTones, [0, 2, 4])

        let key = MusicalKey(root: 0, scale: .minor)
        let octave = style.harmonicProfile.padOctave
        func triad(onDegree d: Int) -> [Int] {
            let root = key.degree(d, octave: octave)
            return [0, 2, 4].map { key.degree(d + $0, octave: octave) - root }
        }
        XCTAssertEqual(triad(onDegree: 0), [0, 3, 7], "the tonic is MINOR")
        XCTAssertEqual(triad(onDegree: 5), [0, 4, 7], "♭VI is MAJOR")
        XCTAssertEqual(triad(onDegree: 6), [0, 4, 7], "♭VII is MAJOR")

        // ⭐ And that is why this arm does NOT need a raised seventh. Both shelf-mates take
        // `harmonicMinor` to buy a major dominant; this cycle gets its two major chords out of
        // natural minor, so the leading tone would be an import, not a colour.
        XCTAssertEqual(MusicStyle.cumbia.scale, .harmonicMinor)
        XCTAssertEqual(MusicStyle.tangoMarcato.scale, .harmonicMinor)
    }

    // MARK: - 3 · Drum-free but moving, and locked

    func testItIsDrumFreeAndNotSustainedAndStillLocked() {
        let style = MusicStyle.andeanHighland
        XCTAssertEqual(style.beatArchetype, MusicStyle.BeatArchetype.none,
                       "nothing in this file voices a highland drum; claiming one would be a "
                       + "sound the engine cannot make")
        XCTAssertFalse(MusicStyle.sustainedFlächen.contains(style),
                       "the PROFILE flag stays false so the onset generator keeps running — "
                       + "`sustained: true` would freeze the cycle into a pad")
        XCTAssertFalse(style.harmonicProfile.arpeggiated)

        // ⭐ THE PART A COMPILER CANNOT CATCH: `defaultMode` takes no arm, so this genre
        // inherits `default: .studioLocked`. Highland dance music has a fixed pulse — the
        // opposite of every other `.none`-archetype genre except `classical`.
        XCTAssertEqual(style.defaultMode, .studioLocked)
        XCTAssertEqual(MusicStyle.classical.defaultMode, .studioLocked)
        for sibling in [MusicStyle.ambientPulse, .slowBloom, .celticAir] {
            XCTAssertEqual(sibling.defaultMode, .flowFree,
                           "\(sibling.rawValue) is the free-tempo half of this shape; if it "
                           + "locked, the contrast this genre is written against is gone")
        }
    }

    // MARK: - 4 · The echo resolves, and it is not the room

    func testTheQuarterEchoResolvesAcrossTheWholeWindow() {
        let style = MusicStyle.andeanHighland
        let fx = style.fxPreset
        XCTAssertTrue(fx.delayEnabled)

        // The SLOW end binds — the longest time the division can ever produce (#1353). Measured
        // rather than quoted: a quarter at 88 BPM is 60/88 s.
        let slowest = 60.0 / Double(style.tempoRange.lowerBound)
        XCTAssertEqual(slowest, 0.6818, accuracy: 0.001)
        XCTAssertLessThan(slowest, 2.0,
                          "the ceiling GenreDelaySyncResolvabilityTests sweeps")

        // COUNTERWEIGHT: the room is the genre, so a future "tidy-up" that drops the reverb
        // must go red here rather than quietly leaving a dry cycle.
        XCTAssertTrue(fx.reverbEnabled)
        XCTAssertGreaterThan(fx.reverbRoom, MusicStyle.cumbia.fxPreset.reverbRoom)
        XCTAssertGreaterThan(fx.reverbRoom, MusicStyle.tangoMarcato.fxPreset.reverbRoom)

        // And the shared-floor half of the same mechanism still exists: a genre whose arm
        // leaves reverb off gets the floor applied in `fxPreset`, never silence.
        XCTAssertTrue(MusicStyle.rock.fxPreset.reverbEnabled,
                      "`rock` is one of the eleven arms that take the shared room floor")
    }

    // MARK: - 5 · The two voices are this genre's own

    func testTheTwoPatchesAreThisGenresOwn() {
        let style = MusicStyle.andeanHighland
        XCTAssertEqual(style.synthPatch.name, "Thin Air Pad")

        // `bassPatch` is OPTIONAL — unwrapped, never forced (#1355).
        guard let bass = style.bassPatch else {
            return XCTFail("andeanHighland has no bassPatch — `sparseSub` would then play on a "
                           + "voice this genre does not own")
        }
        XCTAssertEqual(bass.name, "Air Sub")

        // Figure shared, voice never.
        XCTAssertEqual(style.bassGrammar, .sparseSub)
        let otherSparse = MusicStyle.allCases.filter {
            $0 != style && $0.bassGrammar == .sparseSub
        }
        XCTAssertFalse(otherSparse.isEmpty, "the figure is meant to be shared")
        for sibling in otherSparse {
            XCTAssertNotEqual(sibling.bassPatch?.name, bass.name,
                              "\(sibling.rawValue) now plays this genre's bass VOICE — the "
                              + "grammar is shareable, the patch is not")
            XCTAssertNotEqual(sibling.synthPatch.name, style.synthPatch.name,
                              "\(sibling.rawValue) now plays this genre's chord VOICE")
        }
    }

    // MARK: - 6 · One genre owns both ends of the brightness axis

    func testThePairOwnsBothEndsOfTheBrightnessAxis() {
        let style = MusicStyle.andeanHighland
        guard let bass = style.bassPatch else {
            return XCTFail("no bassPatch — claim 5 says why that matters")
        }
        let pad = style.synthPatch

        // ⭐ This is the one RANK the slice's doc comments claim, so it is the one worth
        // pinning: the pad is the file's brightest voice and the sub its darkest. A superlative
        // is a date (#818) — if a brighter patch ships, this claim and BOTH doc comments move
        // together (#456), which is exactly what this assertion is for.
        let brights = SynthPatch.factory.map(\.brightness)
        XCTAssertEqual(pad.brightness, brights.max(),
                       "`Thin Air Pad` is no longer the file's brightest voice — update its "
                       + "doc comment in GenrePatches.swift in this same commit")
        XCTAssertEqual(bass.brightness, brights.min(),
                       "`Air Sub` is no longer the file's darkest voice — update its doc "
                       + "comment in GenrePatches.swift in this same commit")
        XCTAssertGreaterThan(pad.brightness, bass.brightness)
    }
}

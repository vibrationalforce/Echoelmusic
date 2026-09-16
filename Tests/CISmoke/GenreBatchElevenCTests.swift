// GenreBatchElevenCTests.swift
// Echoel — G11c's one addition, in the BLOCKING bundle.
//
// KIND: BEHAVIOUR over the roster, in the `GenreBatchElevenATests` form. No source-text scan.
//
// ⭐ WHAT THIS SLICE IS, and why it is ONE genre and not the two its plan row names. The plan's
// G11c row reads "nordicFiddle, balkanModal" and then says, in the same row, that `balkanModal`
// carries TWO independent risks that do not belong here: it names `additive332`, a `PadGrammar`
// case that does not exist, and it would be a SECOND `hungarianMinor` genre, which makes it a
// RETRACTION of `blackMetal`'s "used by no other genre" doc (#1288) rather than an addition.
// Shipping them together would have hidden a retraction inside a feature. `balkanModal` is its
// own slice; this one closes the figure that #1294 authored ahead.
//
// ⭐ THE HANDSHAKE THIS BATCH COMPLETES, and it is the reason `heldRoot` was safe to leave
// sitting unowned for a cycle. #1294 (G11b) shipped the FIGURE alone — one enum case, one `hits`
// arm, no owner — and listed it in `GenreBassGrammarTests.testEveryGrammarIsOwnedOrAuthoredAhead`
// under `authoredAhead`, with its own doc saying that list goes red the day a genre claims it.
// It did. That guard's list is EMPTY in this commit and its doc records the ending. An
// authored-ahead property is only honest while something makes the wait visible.
//
// ⚠️ WHAT IS DELIBERATELY NOT ASSERTED. `minor` is the most-shared scale in the file, `[0, 3, 7]`
// is shared with `celticAir`, and `[0, 6, 5]` is shared with `deepHouse` and `psyProgHouse` —
// all three measured before writing, none claimed. What the doc DOES claim is asserted: the
// fourth-voiced stack with no third, the register below its shelf-mate, the drone's own voice,
// and the five axes that keep this genre away from `celticAir` despite the shared voicing.
//
// ⚠️ AND ONE ASSERTION EXISTS ONLY BECAUSE A COMPILER CANNOT MAKE IT. `defaultMode` ends in
// `default: .studioLocked`, so a new genre silently inherits it. For this genre that is CORRECT
// and it is still the omission nobody would notice if it were wrong — `celticAir`'s own arm one
// screen above says the same thing from the other side. Claim 5 asserts it rather than trusting
// the default, which is the practice that arm asked for by name.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain, and this is BEHAVIOUR over types the
// transcription cannot evaluate — a Python mirror of `MusicalKey.degree` would be a second
// implementation of the thing under test (#416), which is worse than no transcription. What WAS
// driven mechanically instead, before a line of this file was written, is
// `python3 scripts/genre-prebatch.py`: lead ceiling (Warm Strings 5 → 6, ceiling stays 7),
// fingerprint (no offered pair shares one), patches (free ids 63, 64), voicing, tempo/delay
// ceiling, register and grammar ownership — all OK. The compile verdict is CI/CD's
// `Build for Testing`; until it lands, this file is UNPROVEN, not green.
//
// NEEDS-FOUNDER-VERIFY: Nordic Fiddle at 120 in Loop mode. Two ear questions, and they are about
// the drone, not the tune. (1) Does the bordun read as ONE held instrument, or does the
// root→fifth change at the last quarter read as a second note being played? (2) With "Drone Sub"
// sustaining at 0.92 under "Sympathetic Bow", is the tune still legible above it, or does the
// drone swallow the melody? If the second one fails the fix is the mix weight (1.12 bass), not
// the patch.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreBatchElevenCTests: XCTestCase {

    private let addition: MusicStyle = .nordicFiddle

    // MARK: - Claim 1 — the door, on the shelf it closes

    func testTheThirdEuropeanFolkDoorIsOpen() {
        XCTAssertTrue(MusicStyle.offered.contains(addition),
                      "nordicFiddle is built but not offered — a doorless genre (#254)")
        XCTAssertEqual(addition.category, .folk)
        XCTAssertEqual(addition.subcategory, .europeanFolk)
        XCTAssertTrue(addition.category.offeredGenres.contains(addition))
        XCTAssertTrue(addition.subcategory.offeredGenres.contains(addition))
        XCTAssertEqual(addition.displayName, "Nordic Fiddle")
        XCTAssertFalse(addition.lineage.isEmpty)

        // Counterweight to claim 1 (#343): the shelf it joins must still hold the two G11a doors
        // and its original dark resident. Without this, claim 1 stays green on a tree that
        // replaced the shelf rather than adding to it.
        let shelf = MusicStyle.Subcategory.europeanFolk
        for mate in [MusicStyle.celticAir, .andalusianCadence] {
            XCTAssertTrue(shelf.offeredGenres.contains(mate),
                          "\(mate.rawValue) left the shelf this batch was measured against")
        }
        XCTAssertTrue(shelf.genres.contains(.klezmer))
        XCTAssertFalse(MusicStyle.offered.contains(.klezmer),
                       "klezmer became offered; this batch's separation argument assumed it dark")
    }

    // MARK: - Claim 2 — the harmony, in SEMITONES, never in degree numbers

    func testTheStackIsAFourthAndNotAMinorTriad() {
        // ⭐ `[0, 3, 7]` LOOKS like a minor triad read as semitones and is not one — the trap
        // #1286 paid for. Resolved through `MusicalKey.degree` on `minor` it is root, perfect
        // FOURTH, octave, which is what lets the drone sit under any mode of the tune.
        XCTAssertEqual(semitoneStack(of: addition), [0, 5, 12],
                       "the open-fourth stack is gone; the doc's whole separation argument, and "
                       + "the reason a bordun works under it, rest on there being no third")
        XCTAssertEqual(addition.harmonicProfile.chordTones, [0, 3, 7])
        XCTAssertEqual(addition.harmonicProfile.progression, [0, 6, 5])
        XCTAssertFalse(addition.harmonicProfile.arpeggiated,
                       "a bordun is held, not rolled")

        // Counterweight: the shelf-mate it shares this voicing with must still resolve the SAME
        // way on its OWN scale. If `celticAir` drifted, the separation claim below compares this
        // genre against something that no longer exists.
        XCTAssertEqual(semitoneStack(of: .celticAir), [0, 5, 12])
    }

    // MARK: - Claim 3 — separated from its shelf-mate on everything except the voicing

    func testItIsNotTheAirItSharesAVoicingWith() {
        let air = MusicStyle.celticAir
        XCTAssertNotEqual(addition.scale, air.scale,
                          "minor vs dorian is the first of the five axes")
        XCTAssertNotEqual(addition.beatArchetype, air.beatArchetype,
                          "backbeat vs none — the dance tune against the air")
        XCTAssertNotEqual(addition.defaultMode, air.defaultMode,
                          "studioLocked vs flowFree — a fixed tempo against a body-followed one")
        XCTAssertNotEqual(addition.harmonicProfile.padOctave, air.harmonicProfile.padOctave,
                          "register: the drone must sit BELOW the tune's own octave, or it stops "
                          + "reading as a floor")
        XCTAssertLessThan(addition.harmonicProfile.padOctave, air.harmonicProfile.padOctave)
        XCTAssertFalse(addition.tempoRange.contains(air.defaultTempo),
                       "the two default tempos must not fall inside each other's range — that is "
                       + "the fifth axis, and the one a listener hears first")
    }

    // MARK: - Claim 4 — the drone has its OWN voice, and it is the first owner of the figure

    func testTheBordunHasItsOwnVoiceAndOwnsTheFigure() {
        XCTAssertEqual(addition.bassGrammar, .heldRoot,
                       "the figure #1294 authored ahead has lost its first owner")
        guard let bass = addition.bassPatch else {
            return XCTFail("nordicFiddle has no bassPatch — `heldRoot` would then play on the "
                           + "pad voice an octave down, which is the pre-grammar path and not a "
                           + "drone. Figure shared, voice NEVER (#1286).")
        }
        XCTAssertEqual(bass.name, "Drone Sub")
        XCTAssertGreaterThan(bass.sustain, 0.85,
                             "a bordun that decays is not a bordun — this is the one patch here "
                             + "built to never finish inside a bar")

        // Counterweight (#343): the figure is shared-able, the VOICE is not. No other offered
        // genre may carry this patch name, or the licence this file's header states is broken.
        let sameVoice = MusicStyle.offered.filter { $0 != addition && $0.bassPatch?.name == bass.name }
        XCTAssertTrue(sameVoice.isEmpty, "\(sameVoice) share nordicFiddle's bass VOICE")

        // And the lead is a SHARED name on purpose — measured at 5 → 6 owners before writing.
        XCTAssertEqual(addition.leadPatchName, "Warm Strings")
    }

    // MARK: - Claim 5 — the default a compiler cannot check

    func testTheModeIsTheDefaultAndThatIsDeliberate() {
        // `defaultMode` ends in `default: .studioLocked`, so this genre takes no arm there. For a
        // dance tune that is right; it is also exactly the kind of silent inheritance that is
        // wrong for the next genre and that nothing would report. `celticAir`'s arm asks for this
        // assertion by name.
        XCTAssertEqual(addition.defaultMode, .studioLocked)
        XCTAssertEqual(MusicStyle.celticAir.defaultMode, .flowFree,
                       "the arm that made this assertion worth writing is gone")
        XCTAssertTrue(addition.tempoRange.contains(addition.defaultTempo),
                      "a default tempo outside its own range is a picker that opens wrong")
    }

    private func semitoneStack(of style: MusicStyle) -> [Int] {
        let profile = style.harmonicProfile
        let key = MusicalKey(root: 0, scale: style.scale)
        let root = key.degree(profile.chordTones[0], octave: profile.padOctave)
        return profile.chordTones.map { key.degree($0, octave: profile.padOctave) - root }
    }
}

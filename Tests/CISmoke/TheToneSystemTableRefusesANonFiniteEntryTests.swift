// TheToneSystemTableRefusesANonFiniteEntryTests.swift
// Echoel — 2026-09-25 (overnight P8): the poly engine and the sub refuse a tone-system table
// with a non-finite entry, the rule the lane rack and the bio voice already apply. Blocking bundle.
//
// THE DEFECT (measured before the repair). `EchoelPolyDDSP.setTuningCents` checked only
// `count == 12`. `LaneVoiceRack.setTuningCents` and `BioReactiveSynthVoice.setTuningCents` refuse a
// non-finite entry — but the studio calls the primary voices DIRECTLY, past the rack's gate. A NaN
// or +inf entry made `noteOn`'s `baseFreq` non-finite for that pitch class; the voice's smoothed
// frequency and phases went NaN, and the voice's own output guard zeroed it: every note on that
// pitch class was silent (the other voices played on, quieter while it was held, because
// `polyMakeupTarget` counted it). The `uiTuningCents` mirror took the bad table
// too. (⛔ review 13 corrected "the poly mix guard zeroed every sample" — the scope was one pitch
// class, not the bus.) `SubBassVoice.setTuningCents` was size-only on the same direct path; there
// a NaN entry played at `minHz` (off-pitch, not silent) because `feltFrequency` guards it. Closed
// in the follow-up commit; claim 4 pins it through the Debug seam `lastTuningCentsForTests` (the
// blocking bundle builds Debug, `SubBassFollowsTheToneSystemTests` uses the same seam).
// Found by tonight's read-only sticky-NaN sweep (its candidate 2).
//
// LATENT: the one producer is `TuningSystem.pitchClassCents(root:)`, a finite library table.
// Closed on the #588 boundary rule and on #416 (one boundary, one rule).
//
// THE REPAIR. `guard cents.count == 12, cents.allSatisfy({ $0.isFinite })` in the engine and in
// `SubBassVoice.setTuningCents`; the `PolySynthVoice` mirror applies the same acceptance.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped engine (voice `frequency` is
// public) and of the public mirror (claims 1–3). Claim 4 is weaker: it reads the sub's
// CONTROL-SIDE latch through the Debug seam, not a rendered pitch.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `f585182d2`: claim 1
// (voice frequency NaN or +inf) and claim 2 (mirror took the NaN table) are REGRESSIONS, two
// findings from one missing gate. Claim 1's −inf row is green on the parent too: `pow(2, −inf)` is
// 0, a finite 0 Hz voice (not silent — frozen phases give a DC offset shaped by the envelope, a
// thump) — the row stays because the gate must refuse it all the same. Claim 3 is a
// COUNTERWEIGHT (a finite table still retunes), green on both. Claim 4 (the sub) is graded against
// ITS parent `fe7865a14`: a REGRESSION there on all three rows (the size-only sub latched every
// non-finite table), green after `d371e45b9`. One finding, three rows (#486).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheToneSystemTableRefusesANonFiniteEntryTests: XCTestCase {

    private static func table(_ c0: Float) -> [Float] { [c0] + Array(repeating: 0, count: 11) }

    // MARK: - claim 1

    func testANonFiniteEntryCannotReachAVoicePitch() {
        for bad: Float in [.nan, .infinity, -.infinity] {
            let poly = EchoelPolyDDSP(maxVoices: 2)
            poly.setTuningCents(Self.table(bad))
            poly.noteOn(note: 60)
            poly.forEachVoice { voice in
                XCTAssertTrue(voice.frequency.isFinite, "a \(bad) cents entry reached a voice pitch")
            }
        }
    }

    // MARK: - claim 2

    func testTheMirrorKeepsTheLastTableTheEngineTook() {
        let synth = PolySynthVoice(maxVoices: 1)
        let good = Self.table(-13.7)
        synth.setTuningCents(good)
        synth.setTuningCents(Self.table(.nan))
        XCTAssertEqual(synth.uiTuningCents, good, "the mirror took a table the engine refused")
    }

    // MARK: - claim 4 (added with the sub's gate; the parent of THAT commit has no sub gate)

    func testTheSubRefusesANonFiniteEntryAndKeepsItsLastTable() {
        for bad: Float in [.nan, .infinity, -.infinity] {
            let sub = SubBassVoice()
            let good = Self.table(-13.7)
            sub.setTuningCents(good)
            sub.setTuningCents(Self.table(bad))
            XCTAssertEqual(sub.lastTuningCentsForTests ?? [], good,
                           "the sub took a table with a \(bad) entry; that pitch class plays off-pitch")
        }
    }

    // MARK: - claim 3 (COUNTERWEIGHT)

    func testAFiniteTableStillRetunes() {
        let plain = EchoelPolyDDSP(maxVoices: 1)
        plain.noteOn(note: 60)
        let retuned = EchoelPolyDDSP(maxVoices: 1)
        retuned.setTuningCents(Self.table(-13.7))   // C is pitch class 0
        retuned.noteOn(note: 60)
        var f0: Float = 0
        var f1: Float = 0
        plain.forEachVoice { f0 = $0.frequency }
        retuned.forEachVoice { f1 = $0.frequency }
        XCTAssertEqual(f1 / f0, powf(2, -13.7 / 1200), accuracy: 1e-4, "a finite table no longer retunes its pitch class")
    }
}

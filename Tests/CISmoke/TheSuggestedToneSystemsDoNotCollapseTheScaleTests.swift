// TheSuggestedToneSystemsDoNotCollapseTheScaleTests.swift
// Echoel — G4: a suggested intonation must colour the genre's scale, not delete notes from it.
//
// KIND: BEHAVIOUR, on pure value types (`TuningSystem`, `Scale`), no composer and no view.
//
// ⭐ THE FAILURE, and it is not the one the plan predicted. `centsDeviation` SNAPS each semitone
// to the NEAREST degree of the system, so a system with fewer than twelve degrees can map two
// different scale steps onto the same pitch — the retuned chord comes out with a note missing,
// and it sounds THIN rather than foreign, two files away from the cause.
//
// ⛔ THE PLAN (§4 G4) SAID TO ASSERT ALL TWELVE PITCH CLASSES PAIRWISE DISTINCT, naming Sléndro
// as the case. MEASURED, that check rejects almost the entire world half of the library —
// `maqam-hijaz` folds 5 pairs of the twelve, `gamelan-pelog` 7, `hirajoshi` 11 — because a
// seven-degree system necessarily collapses some of the five chromatic steps a seven-note scale
// never plays. It would have made G12's maqām batch unshippable for a reason that is not a
// musical problem at all. THE PROPERTY THAT MATTERS IS NARROWER: the degrees the GENRE'S OWN
// SCALE uses must stay distinct. That is asserted here instead, and it is strictly the check
// worth having.
//
// ⭐ AND THE NARROW CHECK IS NOT TOOTHLESS — it found a real constraint for the batches ahead
// (measured over the library against five shipped scales):
//   · `pythagorean` (the plainchant candidate) collapses under dorian, phrygian and minor, and
//     is clean under major — it is a DIATONIC MAJOR system, so it must be paired with a scale
//     built on that, not simply named next to a modal genre.
//   · `maqam-rast` collapses under phrygian and minor; `gamelan-pelog` under dorian, minor and
//     major; `hirajoshi` under nearly everything, including pentatonic minor.
//   · `maqam-bayati` and `maqam-hijaz` are clean under all five; every equal temperament is.
// So the design constraint a batch inherits is: A TONE SYSTEM IS CHOSEN TOGETHER WITH THE SCALE,
// never independently of it. This file is where that is enforced.
//
// ⚠️ CLAIM 2 IS VACUOUS TODAY (no genre names a system) and says so rather than reading as a
// pass (#806). CLAIM 1 IS WHAT MAKES THE FILE WORTH ITS BYTES NOW: it pins that the detector
// sees the collapse it claims to see, AND that it does not cry wolf — same system, two scales,
// opposite verdicts. Without it, claim 2 would be a green line over an empty set running a
// predicate nobody has ever executed (#367).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSuggestedToneSystemsDoNotCollapseTheScaleTests: XCTestCase {

    /// The scale's own degrees as this system renders them, in cents from the tonic: the 12-TET
    /// position plus the system's deviation. Two entries closer than a cent are, to a listener,
    /// the same note — and one of them has been deleted from every chord that used it.
    private func collapsedDegrees(_ system: TuningSystem, scale: Scale) -> [(Int, Int)] {
        let steps = scale.intervals
        let cents = steps.map { Double($0) * 100.0 + system.centsDeviation(forSemitone: $0) }
        var out: [(Int, Int)] = []
        for a in 0..<steps.count {
            for b in (a + 1)..<steps.count where abs(cents[a] - cents[b]) < 1.0 {
                out.append((steps[a], steps[b]))
            }
        }
        return out
    }

    // MARK: - claim 1 (COUNTERWEIGHT) — the detector sees a collapse, and only a real one

    func testTheDetectorSeparatesAMatchedPairingFromAMismatchedOne() throws {
        let twelve = TuningSystem.named("edo12")
        XCTAssertEqual(twelve.id, "edo12", "the library lost 12-TET, or `named` stopped resolving it")
        for scale in Scale.allCases {
            XCTAssertTrue(collapsedDegrees(twelve, scale: scale).isEmpty, """
                12-TET collapses \(scale). The detector is then measuring something other than \
                what it claims and claim 2 below means nothing — 12-TET's deviation is zero \
                everywhere by construction.
                """)
        }

        let pythagorean = TuningSystem.named("pythagorean")
        try XCTSkipIf(pythagorean.id != "pythagorean", """
            the library no longer carries Pythagorean — re-anchor this counterweight on another \
            system with fewer than twelve degrees, and re-measure which scales it collapses
            """)
        XCTAssertTrue(collapsedDegrees(pythagorean, scale: .major).isEmpty, """
            Pythagorean now collapses the major scale. It is a diatonic MAJOR system, so this \
            is the pairing it was built for; if this is red the detector has become too strict \
            and would reject every honest world pairing.
            """)
        XCTAssertFalse(collapsedDegrees(pythagorean, scale: .dorian).isEmpty, """
            Pythagorean no longer collapses dorian. Its seven degrees sit on the major scale, \
            so dorian's flat third has no degree of its own and snaps onto the second. If this \
            is green the detector stopped detecting, and the one constraint the batches ahead \
            inherit from this file — pick the system WITH the scale — is unenforced.
            """)
    }

    // MARK: - claim 2 — no genre is handed a system its own scale cannot survive

    /// ⚠️ VACUOUS UNTIL G7 and deliberately not dressed up as more (#806). It is written now so
    /// the batch that first names a system meets it in the same commit, not on a device.
    func testNoSuggestedSystemCollapsesItsGenresOwnScale() {
        for style in MusicStyle.allCases {
            guard let id = style.suggestedToneSystemID else { continue }
            let system = TuningSystem.named(id)
            let folded = collapsedDegrees(system, scale: style.scale)
            XCTAssertTrue(folded.isEmpty, """
                \(style) suggests "\(id)", which folds \(folded.count) pair(s) of its own \
                \(style.scale) degrees onto one pitch — \
                \(folded.map { "\($0.0)/\($0.1)" }.joined(separator: ", ")). Chords written for \
                this genre come out with notes missing, and a listener hears "thin", not \
                "foreign". THE REPAIR IS A PAIRING, not a removal: either give the genre a scale \
                this system has degrees for, or give it a system built on the scale it has. A \
                tone system is chosen together with the scale, never independently of it.
                """)
        }
    }

    // MARK: - claim 3 — the silent fallback this design rests on is still silent

    /// Not a duplicate of `TheGenreSuggestsTheToneSystemTests` claim 1 (#416): that one asserts
    /// the TABLE's ids resolve. This asserts the FALLBACK's shape — the reason a typo in that
    /// table is inaudible rather than fatal. If `named(_:)` ever started trapping instead,
    /// several doc comments in this repo would be wrong and a bad id would become a crash.
    func testAnUnknownIdStillDegradesToTwelveTET() {
        XCTAssertEqual(TuningSystem.named("not-a-tone-system-id").id, "edo12", """
            `TuningSystem.named(_:)` no longer falls back to 12-TET for an unknown id. That is \
            not necessarily wrong, but it changes what a typo costs — and the warning written \
            on `MusicStyle.suggestedToneSystemID` describes the old behaviour.
            """)
    }
}

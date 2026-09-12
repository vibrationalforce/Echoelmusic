// UnmeasuredPulseIsNotZeroTests.swift
// Echoel — a heart that has not been read yet is not a heart at zero. BLOCKING bundle.
//
// ⛔ THE DEFECT, measured on device (log 2476, v10.79.359, build 2476):
//
//     1785362582.450  transport play (generate) tempo=44
//
// 44 is the FLOOR of Contemplation's window (44…66). The founder's one product claim is "your
// body plays it". It played the floor — for the whole ~13 s the camera needs to lock, because the
// settling branch only keeps the running tempo when it is already `>= 50`, and 44 is not.
//
// THE CHAIN, all three links verified against source and executed below in pure code:
//
//   1. Camera rPPG reports `bpm=0` until it locks (same log: `bpm=0 conf=0.00` for six frames)
//      and again whenever it loses lock.
//   2. `EchoelStudioView`'s `fin(_:_:)` substitutes a neutral only for nil or NON-FINITE values.
//      Zero is finite, so it passed through as a measurement — as if the heart had stopped.
//      (`heldCoh`, a few lines above in the same function, already applies the `> 0` rule to
//      coherence, and the comment on the very next line describes exactly this bug for HRV. Heart
//      rate was the one field left unguarded — and the one that sets the tempo.)
//   3. `BioComposer.tempo(for:)` in `.flowFree` computed `hr·(1−calm) + 72·calm`, so a zero heart
//      at zero coherence yielded 0, which its own `min(max(·, 40), 160)` lifted to 40.
//      `StudioCalculator.genreTempo(40, into: 44...66)` folds 40 up to 80, finds 80 above the
//      ceiling, and picks the FLOOR because 80 sits proportionally further above 66 than 44 does
//      above 40. Result: exactly 44.
//
// ⭐ LINK 3 NO LONGER EXISTS, AND THAT IS WHY THIS FILE WAS REWRITTEN (#1282). #1271 replaced the
// coherence blend with `guard hr.isFinite, hr > 0 else { return resonancePulseBPM }` — so a zero
// heart does not become 40 any more, it becomes 72, a deliberate musical default instead of a
// clamp floor. The device log's 44 is therefore UNREACHABLE AT THE SOURCE, not merely blocked at
// the call site, and this file's assertions were pinning the retired chain: it was RED ON A
// CORRECT TREE from #1271 until this commit. CI could not show it — the job log is `tail -200`
// (#807) and the failure was outside the window; what found it was a `git grep` across the whole
// blocking bundle for the behaviour that changed, run because the SAME change had already left
// `ThePaceIsTiltedInsideTheGenreTests` red and visible.
//
// ⚠️ THE FIX IS NOW BELT AND BRACES, AND BOTH BELONG. Link 2's call-site guard (asserted below,
// unchanged) stops a zero being handed over as a measurement; link 3's fallback decides what to
// play when no reading exists at all. Removing either because "the other one covers it" would
// re-open the defect from the opposite end — the call-site guard cannot choose a tempo, and the
// fallback cannot tell an unread body from a body the view has decided is real.
//
// ⚠️ AND THE OBVIOUS SUMMARY IS WRONG, which is why the numbers are computed here instead of
// described. "An unread body makes the music too slow" holds for Contemplation and for NOTHING
// ELSE. The direction is genre-dependent, because the fold's crossover moves with the window:
// on `.selfObservation` (46…78 — the DEFAULT genre) a zero body produced 78, the CEILING, so the
// bug made the default genre too FAST. On `.jazz` and `.oriental` it produced 80 where a resting
// pulse gives 140. My first draft of this file asserted "no genre is entered at its floor" and
// would have failed on Psytrance, where 70 bpm doubles to exactly 140 and the floor IS the honest
// answer. The invariant is not about floors — it is that THE READING MUST MATTER.
//
// AND IT WAS NEVER ONLY THE TEMPO. `BioComposer.musicalState` maps `energy` over 50…120 bpm, so a
// zero clamps to minimum cardiac drive: the composer also built a lower-energy, sparser take for a
// body it had simply not read yet. That half is not asserted here (it is `internal` and covered in
// the non-blocking suite); it is recorded so the fix is not mistaken for a tempo-only change.
//
// WHY BEHAVIOURAL AND NOT A SOURCE SCAN: `tempo(for:)` is `public static` on a pure enum and
// `genreTempo` is pure, so the whole chain runs here. Only the call-site guard needs text, because
// it is a local `func` inside a `private` method on a SwiftUI `View` with no seam.

import Foundation
import XCTest
@testable import Echoelmusic

final class UnmeasuredPulseIsNotZeroTests: XCTestCase {

    /// A body that has never been read. 70 bpm is the resting neutral the call site substitutes.
    private func mapped(hr: Float, _ style: MusicStyle) -> Double {
        StudioCalculator.genreTempo(
            BioComposer.tempo(for: .init(heartRateBPM: hr, coherence: 0,
                                         style: style, mode: .flowFree)),
            into: style.tempoRange)
    }

    // MARK: - The device log, reproduced

    /// ⛔ THE 44 IS NO LONGER REPRODUCIBLE, AND THE FILE TOOK ITS OWN ADVICE. The previous version
    /// of this test said: "If this stops holding, the log no longer explains the code and this
    /// file's rationale must be rewritten — not the number adjusted." #1271 stopped it holding.
    /// So the rationale is rewritten above and this test now pins the REPLACEMENT: an unread
    /// pulse takes the resonance fallback, a chosen musical default, instead of falling through a
    /// clamp floor. The device evidence stays in the header as history, where it explains WHY the
    /// fallback exists.
    func testAnUnreadPulseTakesTheResonanceFallbackNotAClampFloor() {
        XCTAssertEqual(BioComposer.tempo(for: .init(heartRateBPM: 0, coherence: 0,
                                                    style: .contemplation, mode: .flowFree)),
                       BioComposer.resonancePulseBPM, accuracy: 0.001, """
                       An unread pulse no longer resolves to the resonance default. The old \
                       answer was 40 — `min(max(0, 40), 160)`, the mapping's clamp FLOOR, chosen \
                       by the absence of information rather than by anything musical — and that \
                       is what put `tempo=44` in device log 2476.
                       """)
        XCTAssertNotEqual(BioComposer.tempo(for: .init(heartRateBPM: 0, coherence: 0,
                                                       style: .contemplation, mode: .flowFree)),
                          40, accuracy: 0.001, """
                          The clamp floor is back. 40 is what a zero heart became before #1271, \
                          and on Contemplation it folded to the genre's floor of 44 — the \
                          measured defect this file exists for.
                          """)
        // And the fold no longer lands on the floor: 72 into 44…66 sits ABOVE the ceiling, and
        // the proportional rule picks the ceiling rather than halving to 36. Computed, not
        // described — this file's own standing rule.
        XCTAssertEqual(mapped(hr: 0, .contemplation), 66, accuracy: 0.001,
                       "an unread body on Contemplation now lands at the ceiling, not the floor")
    }

    /// …and the resting neutral lands at the other end of the same window: 66. A resting body is
    /// at the fast end of a contemplative window, which is the honest answer — the convergence
    /// then walks the tempo down as the real (slower) pulse arrives, continuously, with no jump.
    func testTheRestingNeutralAndTheUnreadBodyNowAgreeOnContemplation() {
        XCTAssertEqual(mapped(hr: 70, .contemplation), 66, accuracy: 0.001)
        // ⭐ THE FACTOR IS 1.0 NOW, AND THAT IS THE FIX RATHER THAN A LOSS. This assertion used
        // to read `1.5` and called it "the audible size of the defect on the genre the founder
        // was actually using". #1271 removed the sentinel path entirely: an unread body takes the
        // 72 bpm resonance default, which folds to the same 66 a resting 70 does. So on this
        // genre the music no longer changes character when the camera finally locks — it was
        // already playing what a resting body plays.
        //
        // ⚠️ DO NOT READ THIS AS "the reading stopped mattering" — that claim is measured one
        // test down and still holds for 16 genres. Contemplation's window is narrow enough
        // (44…66) that both inputs fold onto its ceiling; that is a property of this window, not
        // of the law.
        XCTAssertEqual(mapped(hr: 70, .contemplation) / mapped(hr: 0, .contemplation),
                       1.0, accuracy: 0.001, """
                       An unread body and a resting body no longer agree on Contemplation. If \
                       this moved, the resonance fallback or the window changed — check which \
                       before adjusting the number, because a factor greater than 1 here is the \
                       shape of the ORIGINAL defect (#1282).
                       """)
    }

    /// ⚠️ THE DEFAULT GENRE WENT THE OTHER WAY, and this is the assertion that stops the fix from
    /// being remembered as "it was too slow". On `.selfObservation` (46…78) a zero body produced
    /// the CEILING. Whatever genre you were on, the tempo was decided by a sentinel instead of by
    /// a body — sometimes too slow, sometimes too fast.
    /// ⚠️ THE HISTORICAL POINT SURVIVES AND THE NUMBERS DO NOT. On `.selfObservation` (46…78) a
    /// zero body used to produce the CEILING, 78 — which is why the defect must never be
    /// remembered as "the music was too slow"; whatever genre you were on, a sentinel decided the
    /// tempo, sometimes too slow and sometimes too fast. Since #1271 an unread body takes 72,
    /// which sits INSIDE this window and needs no fold at all, so the ceiling is no longer
    /// reached and the remaining gap to a resting 70 is two bpm rather than eight.
    func testOnTheDefaultGenreTheUnreadBodySitsInsideTheWindow() {
        XCTAssertEqual(mapped(hr: 0, .selfObservation), BioComposer.resonancePulseBPM,
                       accuracy: 0.001, """
                       An unread body on the DEFAULT genre no longer lands on the resonance \
                       default. 72 falls inside 46…78, so no octave fold applies — if this \
                       changed, either the fallback or the window moved.
                       """)
        XCTAssertEqual(mapped(hr: 70, .selfObservation), 70, accuracy: 0.001,
                       "a resting body lands inside the window at its own pulse")
        XCTAssertTrue(MusicStyle.selfObservation.tempoRange.contains(mapped(hr: 0, .selfObservation)),
                      "the fallback escaped the default genre's own window")
    }

    // MARK: - The invariant that actually holds everywhere

    /// THE READING MUST MATTER — and since #1271 that claim is WEAKER on purpose, so read the
    /// bound before trusting the name. An unread body now takes the 72 bpm resonance default
    /// rather than a clamp floor, and 72 is close to a resting pulse, so the two COINCIDING on a
    /// given genre is the fallback working rather than the sentinel returning. Measured: 16 of
    /// the 36 genres still distinguish them, where 20 did before. The floor below is unchanged
    /// and still passes; what changed is why a genre may legitimately fail to differ.
    ///
    /// The bound is a LOWER bound, not an exact count, and deliberately so: SOME windows are
    /// arranged such that both inputs fold to the same tempo (dubTechno, eighties, disco,
    /// synthwave, stillMeditation, punk, rocksteady, and since #254 batch 2 also deepDrone,
    /// whose 40…58 window maps both a zero body and a resting 70 to its 40 floor — verified, not
    /// guessed). No totals are quoted: they moved twice in one day as genres were added, and the
    /// lower bound is the claim that matters. On those the fix is a no-op, which is correct rather than a miss. Pinning an
    /// exact count would redden this gate the first time a genre is re-voiced for musical reasons.
    func testTheReadingMattersForMostGenresAndTheWindowAlwaysHolds() {
        var differ = 0
        for style in MusicStyle.allCases {
            let zero = mapped(hr: 0, style)
            let rest = mapped(hr: 70, style)
            XCTAssertTrue(style.tempoRange.contains(zero),
                          "\(style): \(zero) escaped \(style.tempoRange)")
            XCTAssertTrue(style.tempoRange.contains(rest),
                          "\(style): \(rest) escaped \(style.tempoRange)")
            if abs(zero - rest) > 0.001 { differ += 1 }
        }
        XCTAssertGreaterThanOrEqual(differ, 15,
                                    "only \(differ) of \(MusicStyle.allCases.count) genres "
                                    + "distinguish an unread body from a resting one. Either the "
                                    + "fold or the windows changed shape — check whether the "
                                    + "sentinel still matters at all before relaxing this.")
    }

    // MARK: - The zero can no longer be built

    /// ⛔ THE GUARD ON THE FIX ITSELF. The tests above prove what a zero DOES; this one proves a
    /// zero can no longer reach the composer. Source text because the guard is a local `func`
    /// inside a `private` method on a SwiftUI `View` — no seam, no local toolchain.
    func testTheHeartRateInputCannotBeAnUnmeasuredZero() throws {
        let text = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        let squashed = text.components(separatedBy: .whitespacesAndNewlines).joined()

        XCTAssertTrue(squashed.contains("guardletv,v.isFinite,v>0else{returnnil}"),
                      "the `measured(_:)` guard no longer rejects a finite zero, so an unlocked "
                      + "rPPG's `bpm=0` reaches the composer as a measurement again (#236).")

        // …and the heart-rate field actually USES it. A guard nobody calls is the shape this
        // defect already had: `fin` existed, `heldCoh` existed, and the one field that mattered
        // went through neither.
        // ⛔ #608b re-anchor: the chain moved OUT of the `Input` construction into the hoisted
        // local `hrForInput` (one definition for the auto fold AND the Input, #416) — the old
        // needle `heartRateBPM: fin(` matched nothing on the new tree and this guard was the
        // one live red of the #608 slice (found by the review, not by me). The law is
        // unchanged: the ONE spelling of the heart-rate chain must pass through `measured(`.
        let lines = text.components(separatedBy: .newlines)
        guard let hrLine = lines.first(where: { $0.contains("hrForInput = fin(") }) else {
            return XCTFail("the composer's heart-rate chain (`hrForInput = fin(`) was renamed or "
                           + "restructured — re-point this guard rather than deleting it")
        }
        XCTAssertTrue(hrLine.contains("measured("),
                      "the composer's heart rate is built without the zero guard: "
                      + hrLine.trimmingCharacters(in: .whitespaces))
        // The second half the old single-line needle proved implicitly: the Input actually
        // CONSUMES the guarded local. Without this, `hrForInput` could pass through `measured`
        // while the Input quietly rebuilds its own unguarded chain — the #416 split this
        // hoist exists to prevent.
        XCTAssertTrue(lines.contains { $0.contains("heartRateBPM: hrForInput") },
                      "the composer's `heartRateBPM:` no longer consumes the guarded "
                      + "`hrForInput` local — the zero guard is bypassed or the chain was "
                      + "re-inlined; re-point this guard with the code in the same commit")
    }

    /// Guards the PREMISE: `fin` must still be the non-finite guard ONLY. If it ever starts
    /// rejecting zero itself, `measured` is redundant and this file's story is wrong — better to
    /// fail loudly than to keep a stale explanation alive beside working code.
    func testFinStillOnlyGuardsNonFinite() throws {
        let squashed = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
            .components(separatedBy: .whitespacesAndNewlines).joined()
        XCTAssertTrue(squashed.contains("guardletv,v.isFiniteelse{returnd}"),
                      "`fin(_:_:)` changed shape. That may be an improvement, but this whole file "
                      + "explains the defect as 'zero is finite, so `fin` waved it through' — "
                      + "reconcile the two rather than leaving one of them lying.")
    }

    // MARK: - Reading the source

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo
        guard FileManager.default.fileExists(atPath:
                root.appendingPathComponent("Sources/Echoelmusic").path) else {
            throw XCTSkip("source tree not present — this test inspects source text, so it "
                          + "SKIPS rather than reporting a green it did not earn")
        }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

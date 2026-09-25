// TheConcertPitchIgnoresANonFiniteValueTests.swift
// Echoel — overnight P8 (2026-09-25). The concert-pitch boundary had two answers.
//
// WHAT WAS WRONG. Three voices take A4 through `setTuning(a4Hz:)`. `BioReactiveSynthVoice`
// guarded it with `isFinite` and returned; `PolySynthVoice` and `SubBassVoice` clamped with
// `min(max(a4Hz, 380), 500)`, and every comparison with NaN is false, so a NaN passed the
// clamp and became the pitch every next note is computed from. One boundary, two rules (#416).
//
// ⚠️ LATENT, NOT LIVE — stated so nobody reads this as a shipped silence. The one production
// source, `SessionContext.a4Hz`, restores only a stored value `> 0` (NaN fails that) and is
// edited through `EchoelValueField`, which cannot produce NaN. The guard closes the boundary
// for the next caller, not for a known one.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). END-TO-END BEHAVIOUR on the shipped voices
// (no engine, no render). Transcribed by hand against the parent: claims 1 and 2 are
// REGRESSIONS there (a NaN reached `poly.a4Hz` / `lastTuningForTests`); claim 3 is a
// COUNTERWEIGHT (a finite value still lands, clamped) and is green on both trees.
// ⚠️ `lastTuningForTests` is a DEBUG-only seam; the blocking bundle builds Debug.

import XCTest
@testable import Echoelmusic

@MainActor
final class TheConcertPitchIgnoresANonFiniteValueTests: XCTestCase {

    private let poison: [Double] = [.nan, .infinity, -.infinity]

    /// 1 — the polyphonic voice keeps its last good pitch.
    func testThePolyVoiceKeepsItsPitchOnANonFiniteValue() {
        let voice = PolySynthVoice(maxVoices: 1)
        voice.setTuning(a4Hz: 432)
        for bad in poison {
            voice.setTuning(a4Hz: bad)
            XCTAssertEqual(voice.poly.a4Hz, 432, accuracy: 1e-4, """
                `PolySynthVoice.setTuning(a4Hz: \(bad))` changed the concert pitch to \
                \(voice.poly.a4Hz). A NaN passes `min(max(_, 380), 500)` unchanged; it must be \
                refused before the clamp, like `BioReactiveSynthVoice.setTuning`.
                """)
        }
    }

    /// 2 — the sub keeps its last good pitch (observed through the Debug seam).
    func testTheSubKeepsItsPitchOnANonFiniteValue() {
        let voice = SubBassVoice()
        voice.setTuning(a4Hz: 432)
        for bad in poison {
            voice.setTuning(a4Hz: bad)
            XCTAssertEqual(voice.lastTuningForTests ?? -1, 432, accuracy: 1e-9, """
                `SubBassVoice.setTuning(a4Hz: \(bad))` was accepted. The sub's felt frequency \
                is computed from this value on the render thread.
                """)
        }
    }

    /// 3 — COUNTERWEIGHT (#343): a finite value still lands, and the clamp still holds.
    func testAFiniteValueStillLandsAndIsClamped() {
        let voice = PolySynthVoice(maxVoices: 1)
        voice.setTuning(a4Hz: 445)
        XCTAssertEqual(voice.poly.a4Hz, 445, accuracy: 1e-4,
                       "A finite in-range pitch no longer reaches the voice.")
        voice.setTuning(a4Hz: 1_000)
        XCTAssertEqual(voice.poly.a4Hz, 500, accuracy: 1e-4,
                       "The 380…500 Hz clamp no longer holds above the range.")
    }
}

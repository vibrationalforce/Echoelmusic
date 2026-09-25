// TheUnisonDetuneCannotBecomeANaNPitchTests.swift
// Echoel — 2026-09-25 (overnight P8): a NaN unison detune cannot become a NaN voice pitch.
// Blocking bundle.
//
// THE DEFECT (measured before the repair). `EchoelPolyDDSP.setUnison` stored
// `min(max(detuneCents, 0), 50)`, the NaN-transparent order. `noteOn` snapshots that spread and
// spawns each unison voice at `baseFreq * pow(2, (t * spread * 0.5) / 1200)`. With a NaN spread
// every frequency, and therefore every rendered sample of the stack, is NaN. `setOctaver`, a few
// lines below in the same type, already refused a non-finite mix: one boundary, two rules (#416).
//
// LATENT, and only with unison ON: `noteOn` reads the spread only when `unisonCount` >= 2. The one
// production caller is the patch apply in `PolySynthVoice` (`poly.setUnison(count: patch.
// unisonVoices ?? 2, …)`), fed by a decoded patch (JSONDecoder rejects NaN) or by the Sound panel's
// detune binding, whose setter already maps a non-finite value to 0. `PolySynthVoice.setUnison`,
// which this guard drives, has NO production caller. Closed on the #588 boundary rule. (⛔ Until
// review 10 this line named that method as the UI path.)
//
// THE REPAIR. `detuneCents.clamped(to: 0...50)`: NaN reads as 0 (no spread); every other value,
// ±inf included, is unchanged.
//
// WHAT KIND OF GREEN (§1): BEHAVIOUR of the shipped setter, read back from the public field
// `noteOn` snapshots.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `bf43cc71b`, claim 1 is
// RED because the field holds NaN; that is one finding. Claim 2 is a COUNTERWEIGHT and is green
// on both trees.

import XCTest
@testable import Echoelmusic

@MainActor
final class TheUnisonDetuneCannotBecomeANaNPitchTests: XCTestCase {

    // MARK: - claim 1

    func testANaNDetuneReadsAsNoSpread() {
        let voice = PolySynthVoice(maxVoices: 1)
        voice.setUnison(count: 3, detuneCents: 12)
        voice.setUnison(count: 3, detuneCents: .nan)
        let spread = voice.poly.unisonDetuneCents
        XCTAssertTrue(spread.isFinite, """
            `EchoelPolyDDSP.setUnison` stored a NaN detune. `noteOn` multiplies every unison \
            voice's frequency by `pow(2, t * spread …)`, so the whole stack renders NaN.
            """)
        XCTAssertEqual(spread, 0, "a NaN detune must read as 0 (no spread)")
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testEveryNonNaNDetuneLandsAsBefore() {
        let voice = PolySynthVoice(maxVoices: 1)
        for (input, expected): (Float, Float) in [(7, 7), (100, 50), (-5, 0), (.infinity, 50), (-.infinity, 0)] {
            voice.setUnison(count: 3, detuneCents: input)
            XCTAssertEqual(voice.poly.unisonDetuneCents, expected,
                           "detune \(input) no longer lands at \(expected)")
        }
    }
}

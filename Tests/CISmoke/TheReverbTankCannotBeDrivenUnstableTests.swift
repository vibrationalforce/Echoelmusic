// TheReverbTankCannotBeDrivenUnstableTests.swift
// Echoel — 2026-09-25 (overnight P8): an out-of-range or NaN `EchoelReverb.roomSize` / `damping`
// cannot drive the comb tanks unstable. Blocking bundle.
//
// THE DEFECT (measured before the repair). `updateDamping()` fed both controls to the comb
// coefficients raw: `combFeedback = roomSize * 0.28 + 0.7`, `combDamp1 = damping`,
// `combDamp2 = 1 - damping`. Every shipped producer writes 0…1 (GenreFX 0.30–0.96 / 0.18–0.68,
// the curated library, the UI fields, the bio routes clamped by `FXModulation.combine`). The one
// that is not range-bound is `FXPreset.apply`, from a decoded preset file with no range check —
// JSON cannot carry NaN, but it carries 1.5. Room above ~1.07 puts the loop gain at or above 1;
// damping outside 0…1 makes the damping one-pole grow every sample. The combs diverge to inf, then
// NaN, and the tank latches it: the melodic voice falls silent until the stage is re-enabled or
// drained, and `decayTimeSeconds` (which sizes the AUv3 `tailTime`) reported infinity. A NaN
// control did the same directly. Found by tonight's read-only sticky-NaN sweep (its candidate 1).
//
// THE REPAIR. Both are `clamped(to: 0...1)` inside `updateDamping()` — at the type, not at the
// callers. NaN maps to 0; every in-range value is bit-identical. The stored property keeps what
// was written, so a preset round-trips unchanged.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped public DSP type.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `1d5d627e7`: claim 1
// (room 1.5 → decay infinite) and claim 2 (damping 1.5 → non-finite output) are REGRESSIONS, two
// findings from one missing clamp; claim 3 (NaN room → decay 0, not the room-0 value) is red on the
// parent too. Claim 4 is a COUNTERWEIGHT, green on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheReverbTankCannotBeDrivenUnstableTests: XCTestCase {

    // MARK: - claim 1

    func testARoomAboveOneCannotPushTheLoopGainToOne() {
        let atOne = EchoelReverb(sampleRate: 48_000)
        atOne.roomSize = 1
        let over = EchoelReverb(sampleRate: 48_000)
        over.roomSize = 1.5
        XCTAssertTrue(over.decayTimeSeconds.isFinite,
                      "room 1.5 puts the comb loop gain at or above 1 — the tank can only diverge")
        XCTAssertEqual(over.decayTimeSeconds, atOne.decayTimeSeconds,
                       "a room above 1 must read as 1")
    }

    // MARK: - claim 2

    func testADampingAboveOneCannotBlowUpTheTank() {
        let reverb = EchoelReverb(sampleRate: 48_000)
        reverb.damping = 1.5
        var worst: Float = 0
        for i in 0..<4_800 {
            let x: Float = i == 0 ? 1 : 0
            let (l, r) = reverb.processStereo(x, x)
            XCTAssertTrue(l.isFinite && r.isFinite, "damping 1.5 made the reverb output non-finite at sample \(i)")
            if !(l.isFinite && r.isFinite) { return }
            worst = Swift.max(worst, abs(l), abs(r))
        }
        XCTAssertLessThan(worst, 2, "an impulse through a stable tank cannot grow")
    }

    // MARK: - claim 3

    func testANaNRoomReadsAsTheSmallestRoom() {
        let smallest = EchoelReverb(sampleRate: 48_000)
        smallest.roomSize = 0
        let nan = EchoelReverb(sampleRate: 48_000)
        nan.roomSize = .nan
        XCTAssertEqual(nan.decayTimeSeconds, smallest.decayTimeSeconds,
                       "a NaN room must read as 0, the smallest room")
    }

    // MARK: - claim 4 (COUNTERWEIGHT)

    func testInRangeValuesAndTheStoredValueAreUnchanged() {
        let fresh = EchoelReverb(sampleRate: 48_000)
        let written = EchoelReverb(sampleRate: 48_000)
        written.roomSize = 0.72
        XCTAssertEqual(written.decayTimeSeconds, fresh.decayTimeSeconds,
                       "the default room no longer decays as before")
        let small = EchoelReverb(sampleRate: 48_000)
        small.roomSize = 0.3
        XCTAssertLessThan(small.decayTimeSeconds, fresh.decayTimeSeconds, "a smaller room no longer decays faster")
        written.roomSize = 1.5
        written.damping = 1.5
        XCTAssertEqual(written.roomSize, 1.5, "the stored room must keep what was written (preset round-trip)")
        XCTAssertEqual(written.damping, 1.5, "the stored damping must keep what was written (preset round-trip)")
    }
}

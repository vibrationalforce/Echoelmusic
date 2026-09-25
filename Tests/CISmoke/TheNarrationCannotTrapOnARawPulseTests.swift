// TheNarrationCannotTrapOnARawPulseTests.swift
// Echoel — 2026-09-25 (overnight P8aa): `BioExplanation.text(for:tempo:)` cannot trap on a
// non-finite or out-of-range pulse. Blocking bundle.
//
// THE DEFECT (measured before the repair). The narration bound
// `let measuredHR = f.map { Int($0.heartRateBPM.rounded()) }` — for EVERY frame, before any
// clause asked whether the pulse was measured. `BioSampleFrame` is raw by contract (it sanitises
// nothing; its consumers do — `heartRateForSound` says so and treats non-finite as ABSENT), and
// `Int(Float.nan)`, `Int(.infinity)` and `Int(1e30)` are Swift TRAPS. The call sits on the main
// actor in `EchoelStudioView`'s generate path, so one such frame was an app crash on the next
// take. LATENT: every shipped publisher writes a finite pulse today (rPPG gates on `bpm > 0` of a
// finite estimate, BLE/HealthKit convert integers/finite doubles). Found by tonight's sweep for
// `Int(` over a value that can be non-finite.
//
// THE REPAIR. `f.flatMap { Int(exactly: $0.heartRateBPM.rounded()) }` — nil for NaN, ±∞ and any
// value outside `Int`, exact for every finite pulse, so no plausibility threshold is invented
// (#416). A `+inf` pulse passes `hasMeasuredHeartRate` and so carries an arousal; with no integer
// to print it falls into the "no pulse measured yet" clause, which is the honest reading.
//
// WHAT KIND OF GREEN (§1): END-TO-END BEHAVIOUR of the shipped narration.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `1a813fe23`: claim 1 TRAPS
// there on its first frame (NaN) rather than failing an assertion — the clone dies, which the CI
// log cannot tell apart from #396 (#1174). ONE finding. Claim 2 is a COUNTERWEIGHT, green on both
// trees: a measured finite pulse is still narrated with its integer value. Compiles on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNarrationCannotTrapOnARawPulseTests: XCTestCase {

    private static func frame(pulse: Float) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1, heartRateBPM: pulse, hrvNormalized: 0.5, breathRate: 0,
                       breathPhase: 0, coherence: 0.5, motionEnergy: 0, source: .healthKit)
    }

    // MARK: - claim 1

    func testANonFiniteOrHugePulseIsNarratedAsAbsent() {
        for bad: Float in [.nan, .infinity, -.infinity, 1e30] {
            let t = BioExplanation.text(for: Self.frame(pulse: bad), tempo: 120)   // traps on the parent
            XCTAssertTrue(t.contains("no pulse measured yet"),
                          "a pulse of \(bad) was narrated as a reading: \(t)")
            XCTAssertFalse(t.contains("BPM sets a"),
                           "a pulse of \(bad) was credited with setting the tempo: \(t)")
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testAMeasuredPulseIsStillNarratedExactly() {
        let t = BioExplanation.text(for: Self.frame(pulse: 72.4), tempo: 96)
        XCTAssertTrue(t.contains("heart rate 72 BPM sets a"),
                      "a finite measured pulse lost its narration: \(t)")
    }
}

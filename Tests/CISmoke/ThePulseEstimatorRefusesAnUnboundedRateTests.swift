// ThePulseEstimatorRefusesAnUnboundedRateTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle. END-TO-END BEHAVIOUR
// (`Tests/CISmoke/CLAUDE.md` §1): it drives the shipped, public, pure
// `PulsePeriodEstimator.dominantBPM` on synthetic windows, with no camera and no analyzer.
//
// ⭐ THE DEFECT. `dominantBPM` is the autocorrelation half of the rPPG pulse path (the flagship
// bio source). Its guard read `sampleRate > 1`, which ADMITS +∞, and the lag bounds were then
// `Int(((60 / maxBPM) * sampleRate).rounded(.up))` and `Int((60 / minBPM) * sampleRate)`.
// `Int(+∞)` is a Swift TRAP, not a nil. So is `Int` of a finite product past `Int.max`, which a
// tiny `minBPM` or an absurd rate produces. A trap here takes the whole app down from inside
// the analyzer's poll.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The one caller (`CameraAnalyzer.detectPeaks`)
// divides by the timestamp span only under `span > 0` and passes the default BPM band. This
// closes the boundary for the next caller. The repair bounds both lags in `Double` before the
// conversion and refuses a non-finite rate or band.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claims 1 and 2 are REGRESSIONS: on the parent the infinite rate, the tiny `minBPM` and
//     the absurd finite rate each TRAP (`Int(+∞)`, then two `Int` overflows), which kills the
//     test clone instead of failing an assertion (#1174). One finding, one mechanism, three
//     inputs (#486). The NaN-rate line in claim 1 is a COUNTERWEIGHT: `NaN > 1` is false, so
//     the parent already refused it.
//   · claim 3 is a COUNTERWEIGHT: a clean 72 bpm sine at 15 Hz over 10 s still reads ≈ 72 bpm
//     with a strong periodicity. The expectation comes from a Python port of the whole
//     estimator (71.84 bpm, strength 0.97), not from a guess (#442). It is green on both trees:
//     the lag bounds are identical for every realistic window.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class ThePulseEstimatorRefusesAnUnboundedRateTests: XCTestCase {

    /// A clean sine at `bpm`, sampled at `rate` for `count` samples.
    private func sine(bpm: Double, rate: Double, count: Int) -> [Float] {
        (0..<count).map { i in
            Float(sin(2 * Double.pi * (bpm / 60) * Double(i) / rate))
        }
    }

    /// claim 1 — a non-finite rate is refused, not converted.
    func testANonFiniteRateReturnsNilInsteadOfTrapping() {
        let window = sine(bpm: 72, rate: 15, count: 150)
        XCTAssertNil(PulsePeriodEstimator.dominantBPM(window, sampleRate: .infinity), """
            `dominantBPM` accepted an infinite sample rate. `sampleRate > 1` admits +∞, and the \
            lag bound `Int((60 / minBPM) * sampleRate)` then TRAPS. Refuse a non-finite rate.
            """)
        XCTAssertNil(PulsePeriodEstimator.dominantBPM(window, sampleRate: .nan))
    }

    /// claim 2 — a finite product past `Int.max` is bounded before the conversion.
    func testAHugeFiniteLagIsBoundedBeforeTheIntConversion() {
        let window = sine(bpm: 72, rate: 15, count: 150)
        // A tiny minimum BPM makes the long-lag bound ~1e301 samples: finite, and far past
        // `Int.max`. The lag search cannot use more than the window, so the bound caps there.
        let tinyFloor = PulsePeriodEstimator.dominantBPM(window, sampleRate: 15,
                                                         minBPM: 1e-300, maxBPM: 200)
        if let reading = tinyFloor {
            XCTAssertTrue(reading.bpm.isFinite && reading.strength.isFinite, """
                A tiny `minBPM` produced a non-finite reading: \(reading).
                """)
        }
        // An absurd but finite rate makes BOTH bounds huge; the lag range is then empty.
        XCTAssertNil(PulsePeriodEstimator.dominantBPM(window, sampleRate: 1e300), """
            A finite but absurd rate was not refused. Both lag bounds exceed the window, so \
            there is nothing to search — and on the parent the `Int` conversion trapped.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: a clean pulse still reads as itself.
    func testACleanPulseStillReadsAsItself() {
        let window = sine(bpm: 72, rate: 15, count: 150)
        guard let reading = PulsePeriodEstimator.dominantBPM(window, sampleRate: 15) else {
            XCTFail("a clean 72 bpm sine at 15 Hz returned nil — the estimator no longer reads a pulse")
            return
        }
        XCTAssertEqual(reading.bpm, 72, accuracy: 2, "Python port of the estimator: 71.84 bpm")
        XCTAssertGreaterThan(reading.strength, 0.9, "Python port of the estimator: 0.97")
    }
}

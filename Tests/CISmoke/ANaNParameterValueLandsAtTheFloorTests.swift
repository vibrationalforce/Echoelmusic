// ANaNParameterValueLandsAtTheFloorTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle. END-TO-END BEHAVIOUR
// (`Tests/CISmoke/CLAUDE.md` §1): it drives the shipped, public `ParameterDescriptor` value
// type, with no engine and no view.
//
// ⭐ THE DEFECT. `ParameterDescriptor.denormalized(_:)` is the ONE conversion every canonical
// parameter write takes — `ParameterApplyRouter.applyNormalized` (the modulation matrix and every
// automation lane), `PerTrackAutomationResolver`, `ParameterToolCore`. It clamped with a
// hand-rolled `Swift.max(0, Swift.min(1, t))`. `Swift.min(1, NaN)` is `1` (every comparison with
// NaN is false), so a NaN mapped to the TOP of the parameter's range: full output level, the
// longest release. The NaN-safe `clamped(to:)` in `Core/FloatingPointClamp` lands NaN on the
// FLOOR — two spellings of one clamp, with opposite answers (#416). (⛔ This line first said
// "every other NaN boundary lands on the floor"; review found three bare ceiling clamps on the
// lane-pan path, repaired in f2bef146d, and boundaries that map NaN to a neutral value instead.
// ⛔ Its repair then called `FloatingPointClamp` "the repo's ONE NaN-safe clamp". Review 3
// named three floor-landing `clamp01`s (`Core/FXModulation`, `Core/ModulationMatrix`,
// `Bio/BioNormalizer`). Review 4 found more (`Sequencer/BreathArp`, `Sequencer/FieldAutoPlay`,
// `Core/MusicalFrame`, `Core/SpectralColor`, `Sequencer/AutomationLane`). No count stands here
// on purpose: a uniqueness or count claim needs the grep, not the memory.)
// `normalized(_:)`, the inverse, had the same shape and returned 1 for a NaN value.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The live producers are finite: the modulation
// matrix maps NaN to 0 before its handler (`ModulationMatrix`), automation lanes interpolate
// decoded points (`JSONDecoder` throws on NaN), and `ParameterToolCore` has no production
// caller. This closes the boundary for the next producer.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claims 1 and 2 are REGRESSIONS: red on the parent (NaN → 200 and → 1), green here.
//   · claim 3 is a COUNTERWEIGHT: every finite and infinite input maps exactly as before, on
//     both trees — the repair changes the NaN answer and nothing else.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class ANaNParameterValueLandsAtTheFloorTests: XCTestCase {

    private let descriptor = ParameterDescriptor(keyPath: "t.x", displayName: "X",
                                                 min: 100, max: 200, defaultValue: 150)

    /// claim 1 — a NaN tool value lands at the floor of the range, not the ceiling.
    func testANaNNormalizedValueDenormalizesToTheFloor() {
        XCTAssertEqual(descriptor.denormalized(.nan), 100, """
            `denormalized(.nan)` no longer returns the range's floor. The hand-rolled \
            `Swift.max(0, Swift.min(1, t))` sends NaN to the CEILING (`Swift.min(1, NaN)` is 1), \
            so a poisoned modulation or automation value writes the parameter's maximum. Use the \
            one NaN-safe clamp, `clamped(to: 0...1)` (#416).
            """)
    }

    /// claim 2 — the inverse agrees: a NaN value normalizes to 0, not 1.
    func testANaNValueNormalizesToZero() {
        XCTAssertEqual(descriptor.normalized(.nan), 0, """
            `normalized(.nan)` no longer returns 0. The inverse must take the same clamp as \
            `denormalized`, or a round trip through a NaN reads back as the top of the range.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: every non-NaN answer is unchanged, including the infinities
    /// and the out-of-range tool values the clamp exists for.
    func testEveryNonNaNValueMapsAsBefore() {
        XCTAssertEqual(descriptor.denormalized(0), 100)
        XCTAssertEqual(descriptor.denormalized(1), 200)
        XCTAssertEqual(descriptor.denormalized(0.5), 150)
        XCTAssertEqual(descriptor.denormalized(-3), 100)
        XCTAssertEqual(descriptor.denormalized(9), 200)
        XCTAssertEqual(descriptor.denormalized(.infinity), 200)
        XCTAssertEqual(descriptor.denormalized(-.infinity), 100)
        XCTAssertEqual(descriptor.normalized(150), 0.5, accuracy: 1e-6)
        XCTAssertEqual(descriptor.normalized(500), 1)
        XCTAssertEqual(descriptor.normalized(-500), 0)
        let degenerate = ParameterDescriptor(keyPath: "t.d", displayName: "D",
                                             min: 5, max: 5, defaultValue: 5)
        XCTAssertEqual(degenerate.normalized(5), 0, "a degenerate range still reads 0")
    }
}

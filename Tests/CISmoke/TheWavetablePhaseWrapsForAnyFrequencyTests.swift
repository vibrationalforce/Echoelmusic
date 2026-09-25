// TheWavetablePhaseWrapsForAnyFrequencyTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle.
//
// ⭐ THE DEFECT. `EchoelCellular.renderWavetable()` runs on the render thread and wrapped its
// phase with `while wavetablePhase >= Float(cellCount) { wavetablePhase -= Float(cellCount) }`.
// That loop holds only for a finite, non-negative increment below ~2^24 × the table length:
//   · a NaN or infinite frequency made the phase non-finite, and `Int(wavetablePhase)` TRAPPED;
//   · a negative frequency left the phase below 0, so the index −1 TRAPPED on the array;
//   · a huge finite frequency (~1e20) never left the loop: subtracting 128 from ~1e17 does not
//     change a Float, so the render thread HUNG.
// The wrap is now `truncatingRemainder` (exact), with a negative branch, and a non-finite
// increment is refused. For every increment below the table length (any frequency below the
// sample rate) the phase is bit-identical to the loop's: 900 cases (5 table lengths ×
// 3 rates × 60 frequencies × 3000 frames) simulated in float32, 0 differences.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The one production texture (the AUv3's) runs
// `.additive`, never `.wavetable`, and its frequency is `baseFrequency · 0.5` after the host
// value is admitted to its descriptor range. This closes the render path for the next caller.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claim 1 is END-TO-END BEHAVIOUR on the shipped public type and a REGRESSION: on the
//     parent the negative and non-finite rows TRAP and the 1e20 row HANGS. A trap kills the test
//     clone, and a hang runs into the job's timeout, instead of failing an assertion (#1174). One
//     finding: one wrap missing three cases.
//   · claim 2 is a COUNTERWEIGHT: an ordinary frequency renders finite, non-silent audio on
//     both trees.
//   · claim 3 is a SOURCE-TEXT SCAN: no subtraction loop in `renderWavetable()`. REGRESSION on
//     the parent (the same finding as claim 1).
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class TheWavetablePhaseWrapsForAnyFrequencyTests: XCTestCase {

    private func render(frequency: Float, frames: Int = 256) -> [Float] {
        let texture = EchoelCellular(cellCount: 128, sampleRate: 48000)
        texture.synthMode = .wavetable
        texture.frequency = frequency
        var buffer = [Float](repeating: 0, count: frames)
        texture.render(buffer: &buffer, frameCount: frames)
        return buffer
    }

    /// claim 1 — no frequency traps or hangs the wavetable render.
    func testNoFrequencyTrapsOrHangsTheWavetable() {
        let hostile: [Float] = [-500, -1e20, .nan, .infinity, -.infinity, 1e20, 3e38]
        for frequency in hostile {
            let out = render(frequency: frequency)
            XCTAssertTrue(out.allSatisfy { $0.isFinite }, """
                The wavetable render at frequency \(frequency) produced non-finite audio. On the \
                parent this row trapped (negative or non-finite) or hung (1e20) on the render \
                thread.
                """)
        }
    }

    /// claim 2 — COUNTERWEIGHT: an ordinary frequency still sounds.
    func testAnOrdinaryFrequencyStillSounds() {
        let out = render(frequency: 220, frames: 4800)
        XCTAssertTrue(out.allSatisfy { $0.isFinite })
        XCTAssertGreaterThan(out.map { abs($0) }.max() ?? 0, 0,
                             "a 220 Hz wavetable texture rendered silence")
    }

    /// claim 3 — the wrap is not a subtraction loop (source-text).
    func testTheWrapIsNotASubtractionLoop() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("Sources/Echoelmusic/DSP/EchoelCellular.swift")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        let code = SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
        guard let head = code.range(of: "private func renderWavetable() -> Float {"),
              let tail = code.range(of: "private func renderAdditive() -> Float {",
                                    range: head.upperBound..<code.endIndex) else {
            XCTFail("`renderWavetable()` or the function after it moved — re-anchor (#454).")
            return
        }
        let body = code[head.upperBound..<tail.lowerBound]
        XCTAssertFalse(body.contains("while wavetablePhase"), """
            `renderWavetable()` wraps its phase with a loop again. A huge increment never leaves \
            it (Float subtraction stops changing the value) — a hang on the render thread.
            """)
        XCTAssertTrue(body.contains("guard phaseIncrement.isFinite else { return 0 }"), """
            `renderWavetable()` no longer refuses a non-finite increment; `Int(…)` of a NaN \
            phase traps.
            """)
    }
}

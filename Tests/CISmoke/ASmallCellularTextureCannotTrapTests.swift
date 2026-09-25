// ASmallCellularTextureCannotTrapTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle. END-TO-END BEHAVIOUR
// (`Tests/CISmoke/CLAUDE.md` §1): it constructs and renders the shipped, public
// `EchoelCellular` (the AUv3's `texture` voice), with no engine.
//
// ⭐ THE DEFECT — two traps in one engine, both for a SMALL cell count.
//   · `init(cellCount:)` stored the count as given. 0 then trapped inside `init` itself,
//     `seed(.singleCenter)` writing `cells[0]` into an empty array; a negative count trapped
//     in `Array(repeating:count:)`. Two `cellCount > 0` guards further down the file show
//     the author meant 0 to be survivable; `init` never got that far. The count is now at least 1.
//   · `renderSpectral2D()` bounded its partial loop by `min(partialCount, grid2DSize)` and
//     then indexed `phases[i]`. But `phases` holds `cellCount` entries, not `grid2DSize` (64).
//     With the default `partialCount` of 32, ANY texture with fewer than 32 cells indexed past
//     `phases` on the render thread at its first spectral sample. The loop is now bounded by
//     `phases.count` too.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The one production construction is the AUv3's
// `EchoelCellular(cellCount: 128, …)` with `synthMode = .additive`. 128 ≥ 64 and the additive
// path already bounds by `cellCount`. This closes the boundary for the next caller.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claims 1 and 2 are REGRESSIONS: each TRAPS on the parent — claim 1 in `init`, claim 2 on
//     the first spectral sample. A trap kills the test clone instead of failing an assertion
//     (#1174). Two findings, two mechanisms, one file.
//   · claim 3 is a COUNTERWEIGHT: an ordinary 128-cell texture keeps its count and renders
//     finite audio in every mode, on both trees. No input that did not trap changes behaviour:
//     the floor only affects counts < 1, and the spectral bound only affects cellCount <
//     min(partialCount, 64), which trapped before.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class ASmallCellularTextureCannotTrapTests: XCTestCase {

    private func renderAllFinite(_ texture: EchoelCellular, frames: Int = 512) -> Bool {
        var buffer = [Float](repeating: 0, count: frames)
        texture.render(buffer: &buffer, frameCount: frames)
        return buffer.allSatisfy { $0.isFinite }
    }

    /// claim 1 — a zero or negative cell count becomes one cell instead of trapping in init.
    func testAZeroOrNegativeCellCountBecomesOneCell() {
        for asked in [0, -5] {
            let texture = EchoelCellular(cellCount: asked, sampleRate: 48000)
            XCTAssertEqual(texture.cellCount, 1, """
                `EchoelCellular(cellCount: \(asked))` did not floor the count at 1. On the parent \
                `init` trapped here: `seed(.singleCenter)` writes `cells[cellCount / 2]` into an \
                empty array, and a negative count traps in `Array(repeating:count:)`.
                """)
            for mode in EchoelCellular.SynthMode.allCases {
                texture.synthMode = mode
                XCTAssertTrue(renderAllFinite(texture), "a one-cell texture rendered non-finite audio in \(mode)")
            }
        }
    }

    /// claim 2 — a texture with fewer cells than partials renders the spectral mode.
    func testASmallTextureRendersTheSpectralMode() {
        let texture = EchoelCellular(cellCount: 16, sampleRate: 48000)
        texture.synthMode = .spectral2D
        XCTAssertLessThan(texture.cellCount, texture.partialCount,
                          "premise: this texture must have fewer cells than partials")
        XCTAssertTrue(renderAllFinite(texture), """
            A 16-cell texture in `.spectral2D` did not render finite audio. On the parent it \
            TRAPPED: the partial loop was bounded by `min(partialCount, grid2DSize)` and indexed \
            `phases`, which holds only `cellCount` entries.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: an ordinary texture keeps its count and renders in every mode.
    func testAnOrdinaryTextureIsUnchanged() {
        let texture = EchoelCellular(cellCount: 128, sampleRate: 48000)
        XCTAssertEqual(texture.cellCount, 128)
        for mode in EchoelCellular.SynthMode.allCases {
            texture.synthMode = mode
            XCTAssertTrue(renderAllFinite(texture), "a 128-cell texture rendered non-finite audio in \(mode)")
        }
    }
}

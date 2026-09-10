// TheDrawableFollowsTheTierTests.swift
// Echoel — #1243 (visual audit 2026-09-10, V1). The quality tier scales the Metal drawable's
// resolution — the one lever that changes fragment cost — and stands down while recording.
//
// THE DEFECT. `AdaptiveQuality.visualDetailScale` (0.5 / 0.7 / 1.0) reached `MetalBioView` only
// as `ringDensity: lookRingDensity * detailScale …`, a shader UNIFORM that the fragment code
// clamps into a density; its loops are fixed-count (`k < 6`, `k < 5`). So `.low` and `.minimal`
// changed what the picture looked like and left what it COST untouched: the drawable was always
// `bounds × screen.scale` — ~8 MP per frame full-screen on a 3x display — at 60 fps, at thermal
// `.critical` too. The governor demoted, the GPU did not notice.
//
// WHAT THIS PINS. (1) The drawable's wanted size is multiplied by a `renderScale` derived from
// `governor?.settings.visualDetailScale`, clamped 0.5…1. (2) The lever is 1 while a take or a
// still wants the drawable (`wantsCapture`), because the recorder pools at the drawable's size.
// (3) COUNTERWEIGHT, by behaviour on the pure core: the factor is 1 at `.balanced` and `.high`
// and below 1 at `.low` and `.minimal` — the lever engages only when the governor says so, so
// the shipped picture at the default tier is byte-identical. (4) COUNTERWEIGHT, by text: the
// frame RATE stays pinned at 60 (`preferredFramesPerSecond = 60`, never reassigned) — this
// slice moves resolution, not cadence; the cadence law in `draw(in:)` stands.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`0d004d1`) and this tree: claims 1
// and 2 RED on the parent, GREEN here; claims 3 and 4 GREEN on both. Softness at 0.7 and the
// recording's size are device questions (NEEDS-FOUNDER-VERIFY at the lever).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDrawableFollowsTheTierTests: XCTestCase {

    /// Claim 1 — the wanted drawable size carries the tier factor.
    func testTheWantedDrawableSizeCarriesTheTierFactor() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertTrue(src.contains("let want = CGSize(width: max(1, view.bounds.width * scale * renderScale),"),
                      "the drawable is sized without the tier factor again — `.low`/`.minimal` then change the look and not the cost (#1243)")
        XCTAssertTrue(src.contains("let tierScale = governor?.settings.visualDetailScale") && src.contains("return CGFloat(max(0.5, min(1, tierScale)))"),
                      "`renderScale` is no longer the clamped tier detail scale (#1243)")
    }

    /// Claim 2 — the lever stands down while capture is wanted.
    func testTheLeverStandsDownWhileRecording() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertTrue(src.contains("guard !wantsCapture, let tierScale = governor?.settings.visualDetailScale else { return 1 }"),
                      "the resolution lever no longer yields to a take/still — the recorder pools at the drawable's size, and a mid-take step would re-pool against a writer sized for the start (#1243)")
        XCTAssertTrue(src.contains("let (readyToCapture, wantsCapture): (Bool, Bool) = MainActor.assumeIsolated {"),
                      "`wantsCapture` no longer comes from the ONE capture question at the top of draw(in:) (#985/#1243)")
    }

    /// Claim 3 — counterweight: the default tiers leave the picture untouched.
    func testTheDefaultTiersLeaveResolutionAtOne() {
        for tier in [QualityTier.balanced, .high] {
            XCTAssertEqual(AdaptiveQuality.settings(for: tier).visualDetailScale, 1.0, accuracy: 1e-6,
                           "\(tier) no longer renders at full resolution — the lever engaged at the default tier (#1243)")
        }
        for tier in [QualityTier.low, .minimal] {
            let s = AdaptiveQuality.settings(for: tier).visualDetailScale
            XCTAssertTrue(s >= 0.5 && s < 1.0, "\(tier) detail scale \(s) is outside 0.5…<1 — the lever would do nothing or overshoot the clamp (#1243)")
        }
    }

    /// Claim 4 — counterweight: the frame rate is still the pinned one.
    func testTheFrameRateStaysPinned() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertTrue(src.contains("preferredFramesPerSecond = 60"),
                      "the 60 fps pin is gone — #1243 moved RESOLUTION with the tier precisely so the cadence never has to move (#1243)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

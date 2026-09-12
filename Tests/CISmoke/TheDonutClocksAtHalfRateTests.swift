// TheDonutClocksAtHalfRateTests.swift
// Echoel — #1242 (visual audit 2026-09-10, V5). The spectral donut's `TimelineView` ticks at
// 30 Hz, and it may because every motion in its draw is time-based.
//
// THE COST. `SpectralDonutView` is a `Canvas` in a `TimelineView(.animation(minimumInterval:))`
// that ran at 1/60: a 1024-point FFT of the master ring, fresh band arrays and a full Canvas
// pass on the MAIN thread sixty times a second, with no governor on this look (it deliberately
// reads none — the menu-freeze law). The Metal view is pinned at 60 for a reason (CLAUDE.md
// PERFORMANCE); the donut has no such reason: its rings ease over hundreds of milliseconds.
//
// WHAT THIS PINS. (1) The interval is a named constant equal to 1/30 and the body uses it.
// (2) COUNTERWEIGHT — the reason halving is free: the draw's easing and idle motion are
// TIME-based (`date.timeIntervalSince(state.lastDate)`, `pow(0.0001, dt)`), not per-frame
// steps; if someone rewrites them per-frame, halving the clock halves the motion and this
// claim says so.
//
// ⛔ CLAIM 3 IS RETRACTED, NOT FAILED (#1304). It read `Video/VideoRecorder.swift` and forbade
// one sentence there — that the AdaptiveQuality tier throttles the draw loop — because
// `targetFPS` has no consumer. The file went with video capture (founder 2026-09-12), so the
// assertion could only ever throw on a missing file: an assertion that cannot fail for its
// named reason is the #367 defect, and one that reds a correct tree is #364. **The fact it
// guarded is unchanged and lives on: `AdaptiveQuality.targetFPS` still has no consumer, and
// `MetalBioView` still pins `preferredFramesPerSecond = 60` statically.** CLAUDE.md's
// PERFORMANCE table is where that is law; do not re-derive a throttle from a comment.
//
// ⚠️ `frameInterval` is `nonisolated static let` on purpose: `SpectralDonutView` is `@MainActor`, and
// claim 1 reads the constant off the actor (CLAUDE.md build-error table, the SE-0434 row).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`7534646`) and this tree: claims 1
// and 3 RED on the parent, GREEN here; claim 2 GREEN on both. Whether 30 Hz still reads as
// smooth is a device question (NEEDS-FOUNDER-VERIFY at the constant).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDonutClocksAtHalfRateTests: XCTestCase {

    /// Claim 1 — 30 Hz, by value and by use.
    func testTheDonutTicksAtThirtyHertz() throws {
        XCTAssertEqual(SpectralDonutView.frameInterval, 1.0 / 30.0, accuracy: 1e-9,
                       "the donut clock moved off 1/30 — re-read #1242 before spending a full FFT per 60th of a second again")
        let src = try text("Sources/Echoelmusic/Studio/SpectralDonutView.swift")
        XCTAssertTrue(src.contains("TimelineView(.animation(minimumInterval: Self.frameInterval, paused: reduceMotion))"),
                      "the TimelineView no longer uses the named constant (#1242)")
        XCTAssertFalse(src.contains("minimumInterval: 1.0 / 60.0"), "a 1/60 literal is back in the donut (#1242)")
    }

    /// Claim 2 — counterweight: the motion is time-based, so the clock rate is not the speed.
    func testTheEasingIsTimeBasedSoTheClockIsNotTheSpeed() throws {
        let src = try text("Sources/Echoelmusic/Studio/SpectralDonutView.swift")
        XCTAssertTrue(src.contains("date.timeIntervalSince(state.lastDate)") && src.contains("pow(0.0001, dt)"),
                      "the donut's easing is no longer computed from elapsed time — at 30 Hz a per-frame step would move at half speed; either restore the dt form or re-decide the clock (#1242)")
    }

    /// Claim 3 — the FACT that claim 3 used to guard through a deleted file: nothing reads the
    /// governor's frame-rate knob, and the renderer's rate is a static pin. Anchored on the two
    /// live files rather than on the removed recorder's comment (#1304).
    func testNothingThrottlesTheDrawLoopFromTheQualityTier() throws {
        let quality = try text("Sources/Echoelmusic/Core/AdaptiveQuality.swift")
        XCTAssertTrue(quality.contains("targetFPS"),
                      "`targetFPS` is gone from AdaptiveQuality — re-anchor this claim (#454) rather than letting it drift green")
        let metal = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertTrue(metal.contains("view.preferredFramesPerSecond = 60"),
                      "`MetalBioView` no longer pins 60 fps statically. If the tier now drives the frame RATE, CLAUDE.md's PERFORMANCE table and the AdaptiveQuality knob table must be corrected in the SAME commit — they both say the rate is never changed at runtime (#1242).")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

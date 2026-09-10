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
// claim says so. (3) `VideoRecorder`'s comment no longer claims an AdaptiveQuality frame-rate
// throttle that nothing implements.
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

    /// Claim 3 — the recorder's comment describes what runs.
    func testTheRecorderDoesNotClaimAThrottleThatNothingImplements() throws {
        let src = try text("Sources/Echoelmusic/Video/VideoRecorder.swift")
        XCTAssertFalse(src.contains("throttling to 30/24 only under thermal/battery load). This is"),
                       "VideoRecorder again claims AdaptiveQuality throttles the draw loop — `targetFPS` has no consumer (#1242)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

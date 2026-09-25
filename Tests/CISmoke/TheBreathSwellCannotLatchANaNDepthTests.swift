// TheBreathSwellCannotLatchANaNDepthTests.swift
// Echoel — 2026-09-25 (overnight P8): a NaN breath-swell depth cannot latch in the render and
// silently disable the swell for the rest of the session. Blocking bundle.
//
// THE DEFECT (measured before the repair). `PolySynthVoice.setBreathSwell(depth:)` stored
// `Swift.min(Swift.max(depth, 0), 0.6)`, the NaN-transparent order, into the audio-thread target.
// The render ramps `breathSwellDepth += (breathSwellTargetDepth - breathSwellDepth) * 0.05`, so a
// NaN target makes the applied depth NaN, and NaN plus anything stays NaN: the `> 0.0005` test is
// false on every later block and the swell is skipped for good, even after a finite depth is set
// again. The UI mirror `isBreathSwellActive` then reports true for that later call — the panel says
// "breathing" over a swell that never runs. The OUTPUT is not NaN (the multiply is skipped); the
// loss is the feature, permanently, with nothing watching.
//
// LATENT: the two production callers pass literals (0 and 0.22). Closed on the #588 boundary rule,
// because the failure is sticky rather than transient.
//
// THE REPAIR. `depth.clamped(to: 0...0.6)`: NaN reads as 0 (off); every other value, ±inf
// included, is unchanged.
//
// WHAT KIND OF GREEN (§1): claim 1 is a SOURCE-TEXT SCAN (comment-stripped) — the target and the
// applied depth are `private` audio-thread fields no test can read, and a render needs an engine.
// Claim 2 is BEHAVIOUR of the public mirror. The sticky latch itself is a device/render fact.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. On the parent `5b9354296`: claim 1 is a
// REGRESSION, one finding (the setter holds the NaN-transparent spelling). Claim 2 is a
// COUNTERWEIGHT and is green on both trees.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheBreathSwellCannotLatchANaNDepthTests: XCTestCase {

    private static let voice = "Sources/Echoelmusic/Tools/PolySynthVoice.swift"

    // MARK: - claim 1

    func testTheSetterClampsWithTheNaNSafeSpelling() throws {
        let code = SourceText.codeOnly(try text(Self.voice))
        let anchor = try XCTUnwrap(code.range(of: "public func setBreathSwell(depth: Float) {"),
                                   "`setBreathSwell(depth:)` not found — re-anchor this guard (#456)")
        let body = Self.braceBody(from: anchor.lowerBound, in: code)
        XCTAssertTrue(body.contains("depth.clamped(to: 0...0.6)"), """
            `setBreathSwell` no longer clamps with `clamped(to:)`. The NaN-transparent \
            `min(max(depth, 0), 0.6)` lets a NaN reach the render's one-pole, which latches it and \
            skips the swell for the rest of the session.
            """)
        XCTAssertFalse(body.contains("Swift.max(depth"), "the NaN-transparent clamp is back in `setBreathSwell`")
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testTheMirrorStillFollowsEveryNonNaNDepth() {
        let synth = PolySynthVoice(maxVoices: 1)
        for (depth, active): (Float, Bool) in [(0.22, true), (0, false), (-1, false), (.infinity, true),
                                               (-.infinity, false), (.nan, false)] {
            synth.setBreathSwell(depth: depth)
            XCTAssertEqual(synth.isBreathSwellActive, active, "depth \(depth) no longer maps to active=\(active)")
        }
    }

    // MARK: - helpers

    private static func braceBody(from start: String.Index, in code: String) -> String {
        var depth = 0
        var out = ""
        for ch in code[start...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return out
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

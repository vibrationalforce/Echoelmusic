// TheSwitchedOnStateIsMonochromeTests.swift
// Echoel — Restructure F4a (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §2C/§3).
//
// WHAT WAS WRONG. Four switches sit in the Workstation's track header and transport line: Mute,
// Solo, Warp, Click. Mute and Solo showed ON as the inverted monochrome tile (`.text` fill,
// `onPrimary` label). Warp and Click showed ON as a bio-green surface behind a black label —
// the same state in two looks a few points apart, and the body's colour spent on two controls
// that have nothing to do with the body (`EchoelTheme`, beside `accent`).
//
// THE REPAIR. Warp and Click take the Mute/Solo look. The luminance inversion stays — that is
// the hue-free cue a switch needs (a green label alone would have been colour-only) — only the
// hue goes. "Plays" (F3: green label, strong frame) and "switched on" (this) are now the two
// state looks, and neither paints a green surface.
//
// ⚠️ WHY NOT THE PLAN'S "selected = borderStrong frame + fill". Measured while building this:
// every control already declares itself with `borderStrong` at rest (`ControlBoundaryIsInteractive
// Tests`), so a strong frame cannot tell ON from OFF. The plan is amended in the same push.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `8613d84d6` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: one conditional accent fill in each file.
//   · claim 2 — RED on the parent, a REGRESSION for Click; the WorkstationView needle is
//     carried by Mute/Solo on both trees (claim 1 is what catches a Warp regression).
//   · claim 3 — COUNTERWEIGHT, green on both: the black labels, without which an off-white ON
//     tile is an invisible label.
// It does NOT prove the switches read well; that is a device glance.

import Foundation
import XCTest

final class TheSwitchedOnStateIsMonochromeTests: XCTestCase {

    private static let click = "Sources/Echoelmusic/Studio/WorkstationClickToggle.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    /// `.fill(<condition> ? EchoelTheme.accent …` — a surface that turns bio-green by state.
    private static let conditionalAccentFill = #"\.fill\([^)\n]*\?\s*EchoelTheme\.accent\b"#

    /// 1 — no switch in the two files turns its surface bio-green when ON.
    func testNoSwitchTurnsItsSurfaceGreen() throws {
        let regex = try NSRegularExpression(pattern: Self.conditionalAccentFill)
        for path in [Self.click, Self.workstation] {
            let code = try read(path)
            let hits = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            XCTAssertEqual(hits, 0, """
                \(path) paints a switch's ON state bio-green. ON is the inverted monochrome tile \
                (`.text` fill, `onPrimary` label), the look Mute and Solo wear.
                """)
        }
    }

    /// 2 — ON fills with `.text`, in the click switch and in the track header.
    func testOnFillsTheMonochromePrimary() throws {
        for path in [Self.click, Self.workstation] {
            XCTAssertTrue(try read(path).contains(".fill(on ? EchoelTheme.text : EchoelTheme.fill))"),
                          "\(path) no longer fills a switch's ON state with `EchoelTheme.text`")
        }
    }

    /// 3 — COUNTERWEIGHT: the black label stays, or the ON tile reads 1.00:1.
    func testOnKeepsTheBlackLabel() throws {
        let labels = [
            (Self.click, ".foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)"),
            (Self.workstation, ".foregroundStyle(on ? EchoelTheme.onPrimary"),
        ]
        for (path, needle) in labels {
            XCTAssertTrue(try read(path).contains(needle), """
                \(path) no longer labels its ON state `onPrimary`: `\(needle)`. On a `.text` \
                fill a `.text` label is invisible.
                """)
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func read(_ relativePath: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: url.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}

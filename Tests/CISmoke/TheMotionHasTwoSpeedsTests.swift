// TheMotionHasTwoSpeedsTests.swift
// Echoel — Restructure F2b (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md`).
//
// WHAT WAS WRONG. Seven UI transitions used five durations (0.12 · 0.15 · 0.18 · 0.22) and two
// curves, each chosen where it was written. Two of them (the visual window's resize dip) ran
// 0.22 s — outside the 100–200 ms transition law in CLAUDE.md's UI constraints.
//
// THE REPAIR. `EchoelTheme.motionQuick` (feedback under the finger) and `motionStandard`
// (something comes, goes or moves into view). Every eased transition in `Sources/` takes one.
// `.linear(duration:)` stays allowed: the three sites that use it follow the breath signal,
// they are not transitions, and pinning them to a UI speed would make the breath ball lag.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `704e0acfa` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: 8 eased literals in 6 files.
//   · claim 2 — red on the parent by ANCHOR ABSENCE only (no tokens). One absence.
//   · claim 3 — RED on the parent, a REGRESSION: none of the seven sites names a token.
// It does NOT prove the motion feels right; that is a device glance.

import Foundation
import XCTest

final class TheMotionHasTwoSpeedsTests: XCTestCase {

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    /// An eased curve given a literal duration — the thing the two tokens replace.
    private static let easedLiteral = #"\.(easeInOut|easeOut|easeIn|spring)\(duration:\s*[0-9]"#

    /// 1 — outside the theme, no eased transition carries its own number.
    func testNoTransitionChoosesItsOwnDuration() throws {
        let regex = try NSRegularExpression(pattern: Self.easedLiteral)
        var offenders: [String] = []
        for (path, code) in try swiftSources() where path != Self.theme {
            let n = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            if n > 0 { offenders.append("\(path) (\(n))") }
        }
        XCTAssertTrue(offenders.isEmpty, """
            An eased transition picks its own duration in \(offenders). Take \
            `EchoelTheme.motionQuick` (feedback under the finger) or `motionStandard` (something \
            comes, goes or moves into view).
            """)
    }

    /// 2 — the two tokens exist, and both sit inside the 100–200 ms transition law.
    func testBothSpeedsSitInsideTheTransitionLaw() throws {
        let theme = try read(Self.theme)
        for name in ["motionQuick", "motionStandard"] {
            let pattern = #"static var "# + name + #": Animation \{ \.[A-Za-z]+\(duration: ([0-9.]+)\) \}"#
            let regex = try NSRegularExpression(pattern: pattern)
            guard let match = regex.firstMatch(in: theme, range: NSRange(theme.startIndex..., in: theme)),
                  let range = Range(match.range(at: 1), in: theme),
                  let seconds = Double(theme[range]) else {
                XCTFail("ANCHOR MISSING: `static var \(name): Animation { .curve(duration: …) }` (#454)")
                continue
            }
            XCTAssertTrue((0.1...0.2).contains(seconds),
                          "\(name) runs \(seconds) s — UI transitions stay within 100–200 ms (CLAUDE.md)")
        }
    }

    /// 3 — the seven former literals now name a token: the scan in claim 1 cannot pass by the
    /// sites simply having been deleted.
    func testTheSevenTransitionsNameAToken() throws {
        let sites: [(String, String)] = [
            ("Sources/Echoelmusic/Studio/EchoelStudioView.swift",
             "withAnimation(EchoelTheme.motionStandard) { proxy.scrollTo"),
            ("Sources/Echoelmusic/Studio/EchoelValueField.swift",
             ".animation(EchoelTheme.motionQuick, value: scrubbing)"),
            ("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift",
             "withAnimation(EchoelTheme.motionStandard) { isPresented = false }"),
            ("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift",
             "withAnimation(EchoelTheme.motionStandard) { resizeDip = false }"),
            ("Sources/Echoelmusic/Studio/LiveColaboView.swift",
             "$shareBio.animation(EchoelTheme.motionQuick)"),
            ("Sources/Echoelmusic/Studio/StudioCaptionView.swift",
             ".animation(EchoelTheme.motionStandard, value: caption.text)"),
            ("Sources/Echoelmusic/Studio/WorkspaceView.swift",
             "withAnimation(EchoelTheme.motionStandard) { floatingVisualVisible.toggle() }"),
        ]
        for (path, needle) in sites {
            XCTAssertTrue(try read(path).contains(needle), "\(path) no longer carries `\(needle)`")
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// Every `.swift` file under `Sources/`, comment-stripped. An empty walk FAILS — it would
    /// pass claim 1 vacuously.
    private func swiftSources() throws -> [(String, String)] {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(name: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(("Sources/" + String(url.path[cut.upperBound...]), SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the scan cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }
}

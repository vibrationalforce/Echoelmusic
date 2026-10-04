// TheRunningStateIsOneLookTests.swift
// Echoel — Restructure F3 (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md`).
//
// WHAT WAS WRONG. "Something is running" looked two ways. The scene and track tiles in
// `SessionLaunchView` light up with the monochrome primary (off-white fill, black label), which
// is the rule `EchoelTheme` writes beside `accent`: primary buttons fill with `.text`; the
// bio-green is reserved for the body's live signal. Three other running buttons filled
// bio-green instead — the head's Play/Stop, the part bar's "Play from here" and LiveColabo's
// "Go Live". So the same state wore green in one place and white in the next, and the green
// said "your body" on three controls that have nothing to do with it.
//
// `PrimaryFillIsMonochromeTests` did not see them, for two reasons: none of the three files is
// on its list, and its scan reads `fill(EchoelTheme.accent)` on one line, while all three wrote
// the colour inside a ternary.
//
// THE REPAIR. All three now fill `.text` while running, with the `onPrimary` label they already
// had. This is coherence, not contrast — black on green and black on off-white both clear
// 4.5:1 (`PrimaryFillIsMonochromeTests` does that arithmetic).
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `6f1d71279` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: one conditional accent fill in each of the
//     three running buttons' files.
//   · claim 2 — RED on the parent, a REGRESSION for the three buttons; the `SessionLaunchView`
//     needle is a COUNTERWEIGHT (green on both — it is the look the others now match).
//   · claim 3 — COUNTERWEIGHT, green on both: the black label is load-bearing now, because a
//     `.text` label on a `.text` fill would be 1.00:1.
//   · claim 4 — RED on the parent, a REGRESSION: 11 conditional accent fills against a ceiling
//     of 8.
// It does NOT prove the buttons look right; that is a device glance.

import Foundation
import XCTest

final class TheRunningStateIsOneLookTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/"

    /// `.fill(<condition> ? EchoelTheme.accent …` — a fill that turns bio-green by state.
    private static let conditionalAccentFill = #"\.fill\([^)\n]*\?\s*EchoelTheme\.accent\b"#

    /// The files whose buttons show a running process; `SessionLaunchView` is the reference.
    private static let runningButtons = [
        "ProjectHeader.swift", "SelectedPartBar.swift", "LiveColaboView.swift", "SessionLaunchView.swift",
    ]

    /// Measured 2026-10-04 on the F3 tree. What is left, and why it may stay or must go:
    /// two loop-progress capsules (`FloatingVisualWindow`, `WorkspaceView`) are a signal bar,
    /// which the rule allows; the Warp switch (`WorkstationView`) and the click switch
    /// (`WorkstationClickToggle`) are the ON state of a toggle, which F4's one chip style
    /// takes; `BioSourceView` (2), `ImmersiveStageView` and `SessionView` are doorless.
    /// LOWER it in the commit that removes one; never raise it.
    private static let ceiling = 8

    /// 1 — no running button turns bio-green by state.
    func testNoRunningButtonFillsBioGreen() throws {
        let regex = try NSRegularExpression(pattern: Self.conditionalAccentFill)
        for file in Self.runningButtons {
            let code = try read(Self.studio + file)
            let hits = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            XCTAssertEqual(hits, 0, """
                \(file) fills a button bio-green while something runs. Running is the \
                monochrome primary (`EchoelTheme.text` fill, `onPrimary` label); the green is \
                reserved for the body's signal (`EchoelTheme`, beside `accent`).
                """)
        }
    }

    /// 2 — each running button paints the monochrome primary, the look `SessionLaunchView`'s
    /// tiles already had.
    func testEveryRunningButtonFillsTheMonochromePrimary() throws {
        let fills = [
            ("ProjectHeader.swift", ".fill(running ? EchoelTheme.text : EchoelTheme.fill))"),
            ("SelectedPartBar.swift", ".fill(playing ? EchoelTheme.text : EchoelTheme.fill))"),
            ("LiveColaboView.swift", ".fill(colab.isLive ? EchoelTheme.text : EchoelTheme.fill))"),
            ("SessionLaunchView.swift", ".fill(state == .playing ? EchoelTheme.text : EchoelTheme.fill))"),
        ]
        for (file, needle) in fills {
            XCTAssertTrue(try read(Self.studio + file).contains(needle),
                          "\(file) no longer fills its running state with `EchoelTheme.text`: `\(needle)`")
        }
    }

    /// 3 — and each keeps the black label, without which an off-white fill is an invisible
    /// button.
    func testEveryRunningButtonKeepsTheBlackLabel() throws {
        let labels = [
            ("ProjectHeader.swift", ".foregroundStyle(running ? EchoelTheme.onPrimary"),
            ("SelectedPartBar.swift", ".foregroundStyle(playing ? EchoelTheme.onPrimary"),
            ("LiveColaboView.swift", ".foregroundStyle(colab.isLive ? EchoelTheme.onPrimary"),
            ("SessionLaunchView.swift", ".foregroundStyle(state == .playing ? EchoelTheme.onPrimary"),
        ]
        for (file, needle) in labels {
            XCTAssertTrue(try read(Self.studio + file).contains(needle), """
                \(file) no longer labels its running state `onPrimary`: `\(needle)`. On a \
                `.text` fill a `.text` label reads 1.00:1.
                """)
        }
    }

    /// 4 — RATCHET: across `Sources/`, state-driven green fills only fall.
    func testTheStateDrivenGreenFillsOnlyFall() throws {
        let regex = try NSRegularExpression(pattern: Self.conditionalAccentFill)
        var total = 0
        var holders: [String] = []
        for (path, code) in try swiftSources() {
            let hits = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            total += hits
            if hits > 0 { holders.append("\(path) (\(hits))") }
        }
        XCTAssertLessThanOrEqual(total, Self.ceiling, """
            \(total) state-driven bio-green fills in Sources/, ceiling \(Self.ceiling). A new \
            running or ON state takes the monochrome primary. Holders: \(holders.sorted()).
            """)
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

    /// Every `.swift` file under `Sources/`, comment-stripped. A walk that finds nothing FAILS:
    /// an empty walk would pass the ratchet vacuously.
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
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the ratchet cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }
}

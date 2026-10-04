// TheRunningStateIsOneLookTests.swift
// Echoel — Restructure F3 (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §2C/§3).
//
// WHAT WAS WRONG. "Something is running" looked three ways. The head's Play/Stop, the part
// bar's "Play from here" and LiveColabo's "Go Live" filled their whole surface bio-green; the
// scene and track tiles in `SessionLaunchView` filled theirs off-white; the plate's Pause
// (`PlaybackToggleButton`) kept a plain tile and turned only its label green inside the strong
// frame. Three looks for one state, and the green surfaces spent the body's colour on controls
// that have nothing to do with the body.
//
// `PrimaryFillIsMonochromeTests` did not see the green surfaces, for two reasons: none of the
// three files is on its list, and its scan reads `fill(EchoelTheme.accent)` on one line, while
// all three wrote the colour inside a ternary.
//
// THE REPAIR — the plan's one "plays": the label (symbol and word) turns green, the tile stays
// `EchoelTheme.fill`, and a `borderStrong` frame holds it. That is the Pause's look, so it is
// not invented here; the surface no longer says anything about the state. In the scene grid
// "Queued" keeps its filled glyph and its word inside the QUIET frame (`border`): green means
// sounding, and a queued part is not sounding yet.
//
// ⛔ The first local draft of this slice (a74b17f1a, never pushed) unified on the OFF-WHITE
// fill instead — the primary-button look, which the plan reserves for the primary action, not
// for a state. Caught against the plan's §2C before it left the machine.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the pushed parent `6f1d71279` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: a state-driven fill in all four files.
//   · claim 2 — RED on the parent, a REGRESSION: no running label is green there.
//   · claim 3 — RED on the parent, a REGRESSION: no running state carries the strong frame
//     (the head's frame was even CLEARED while running).
//   · claim 4 — COUNTERWEIGHT, green on both: the Pause wears the look the others now match;
//     without it, claims 1–3 would describe a look nothing anchors.
//   · claim 5 — RED on the parent, a REGRESSION: 11 state-driven green fills against 8.
// It does NOT prove the buttons read well; that is a device glance.

import Foundation
import XCTest

final class TheRunningStateIsOneLookTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/"

    /// `.fill(<condition> ? …` — a surface that changes with state.
    private static let conditionalFill = #"\.fill\([^)\n]*\?"#

    /// `.fill(<condition> ? EchoelTheme.accent …` — a surface that turns bio-green by state.
    private static let conditionalAccentFill = #"\.fill\([^)\n]*\?\s*EchoelTheme\.accent\b"#

    /// The files whose buttons show a running process.
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

    /// 1 — no running button changes its SURFACE with its state: the tile is the tile.
    func testNoRunningButtonChangesItsSurface() throws {
        let regex = try NSRegularExpression(pattern: Self.conditionalFill)
        for file in Self.runningButtons {
            let code = try read(Self.studio + file)
            let hits = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            XCTAssertEqual(hits, 0, """
                \(file) fills a surface by state. "Plays" is the green label inside the strong \
                frame on the plain `EchoelTheme.fill` tile — never a green or off-white surface \
                (plan §2C; the Pause in `PlaybackToggleButton` is the reference).
                """)
        }
    }

    /// 2 — each running state turns its LABEL green.
    func testEveryRunningLabelTurnsGreen() throws {
        let labels = [
            ("ProjectHeader.swift", ".foregroundStyle(running ? EchoelTheme.accent"),
            ("SelectedPartBar.swift", ".foregroundStyle(playing ? EchoelTheme.accent"),
            ("LiveColaboView.swift", ".foregroundStyle(colab.isLive ? EchoelTheme.accent : EchoelTheme.text)"),
            ("SessionLaunchView.swift", ".foregroundStyle(state == .playing ? EchoelTheme.accent"),
        ]
        for (file, needle) in labels {
            XCTAssertTrue(try read(Self.studio + file).contains(needle),
                          "\(file) no longer turns its running label green: `\(needle)`")
        }
    }

    /// 3 — and each running state carries the strong frame, so the state is not colour alone.
    func testEveryRunningStateCarriesTheStrongFrame() throws {
        let frames = [
            ("ProjectHeader.swift", ".strokeBorder(available ? EchoelTheme.borderStrong : Color.clear, lineWidth: 1))"),
            ("SelectedPartBar.swift", ".strokeBorder(playing ? EchoelTheme.borderStrong : Color.clear, lineWidth: 1))"),
            ("LiveColaboView.swift", ".strokeBorder(colab.isLive ? EchoelTheme.borderStrong : EchoelTheme.border,"),
            ("SessionLaunchView.swift", ".strokeBorder(state == .playing ? EchoelTheme.borderStrong"),
        ]
        for (file, needle) in frames {
            XCTAssertTrue(try read(Self.studio + file).contains(needle), """
                \(file) lost the strong frame of its running state: `\(needle)`. Without it the \
                state is carried by colour alone.
                """)
        }
    }

    /// 4 — COUNTERWEIGHT: the reference. The plate's Pause shows only while the music plays,
    /// and wears the look claims 1–3 hold the others to.
    func testThePauseIsTheReferenceLook() throws {
        let workspace = try read(Self.studio + "WorkspaceView.swift")
        for needle in [
            ".foregroundStyle(EchoelTheme.accent)",
            ".background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))",
            ".strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))",
        ] {
            XCTAssertTrue(workspace.contains(needle), """
                The plate's Pause (`PlaybackToggleButton`) no longer carries `\(needle)`. It is \
                the reference for the one "plays" look; if it changed on purpose, move claims \
                1–3 with it in the same commit.
                """)
        }
    }

    /// 5 — RATCHET: across `Sources/`, state-driven green fills only fall.
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
            running state turns its label green inside the strong frame. Holders: \(holders.sorted()).
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

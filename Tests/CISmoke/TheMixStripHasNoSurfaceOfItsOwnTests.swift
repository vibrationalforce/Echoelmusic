// TheMixStripHasNoSurfaceOfItsOwnTests.swift
// Echoel — Restructure F6a (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §1D/§3).
//
// WHAT WAS WRONG. `mixStripCard` — the five titled groups of the Mix panel (Bass · Melodic · Pad
// · Field · Click) and the "Variations" group of the Tempo & variations panel — drew a filled,
// bordered rounded card. Every one of them sits inside `panel(…)`, i.e. inside `EchoelPanel`,
// which is already a filled, bordered card. A card in a card: the plan's §3 row "ein Panel hat
// eine Fläche" was broken in exactly the two panels §1D measured.
//
// THE REPAIR. The strip keeps its title and content and loses its surface: no background, no
// rounded frame. A 1-pt rule in the decorative `border` token over its top edge separates the
// groups; the panel stays the one surface.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `75645cff9` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: the strip draws a rounded fill and frame.
//   · claim 2 — RED on the parent by absence: the rule does not exist there. One absence.
//   · claim 3 — COUNTERWEIGHT, green on both: every strip sits inside a `panel(…)`, and that
//     panel IS a surface — without it, claim 1 would strip the groups bare instead of
//     un-nesting them.
// It does NOT prove the panel reads well; that is a device glance.

import Foundation
import XCTest

final class TheMixStripHasNoSurfaceOfItsOwnTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let panel = "Sources/Echoelmusic/Studio/EchoelPanel.swift"

    /// 1 — the strip draws no surface of its own.
    func testTheStripDrawsNoCard() throws {
        let body = try stripBody()
        for needle in ["RoundedRectangle(", ".background("] {
            XCTAssertFalse(body.contains(needle), """
                `mixStripCard` draws `\(needle)` again. Every strip sits inside a `panel(…)`, \
                which is already the card — a second surface inside it is a card in a card \
                (plan §3, F6a).
                """)
        }
    }

    /// 2 — the groups are still told apart: a 1-pt rule over each strip's top edge.
    func testTheStripsAreSeparatedByARule() throws {
        let body = try stripBody()
        XCTAssertTrue(body.contains("Rectangle().fill(EchoelTheme.border).frame(height: 1)"), """
            `mixStripCard` lost its top rule. Without a surface, the rule is what separates one \
            strip from the next.
            """)
    }

    /// 3 — COUNTERWEIGHT: every strip sits inside a panel, and the panel is a surface.
    func testEveryStripSitsInsideThePanelSurface() throws {
        let code = try read(Self.studio)
        XCTAssertEqual(code.components(separatedBy: "mixStripCard(\"").count - 1, 5,
                       "five strips on 2026-10-04 (Bass, Melodic · Pad, Field, Click, Variations) — a new one must sit inside a panel too")
        for host in ["panel(\"Mix\", \"Level per part\", isExpanded: $showMix) {",
                     "panel(\"Tempo & variations\", \"Tap · metronome · haptic beat · ideas\","] {
            XCTAssertTrue(code.contains(host), "the strips' host `\(host)` changed — re-check that every strip still sits on a panel surface")
        }
        let panel = try read(Self.panel)
        XCTAssertTrue(panel.contains(".background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))"),
                      "`EchoelPanel` no longer draws the surface the strips sit on — without it the strips are bare")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The body of `mixStripCard`, brace-matched from its declaration (#408).
    private func stripBody() throws -> String {
        let code = try read(Self.studio)
        guard let decl = code.range(of: "private func mixStripCard<Content: View>("),
              let open = code[decl.upperBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `private func mixStripCard<Content: View>(` (#454)")
            throw AnchorMissing(name: "mixStripCard")
        }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced braces in `mixStripCard` (#454)")
        throw AnchorMissing(name: "mixStripCard body")
    }

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
}

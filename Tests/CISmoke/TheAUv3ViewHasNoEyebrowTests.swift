// TheAUv3ViewHasNoEyebrowTests.swift
// Echoel — interface audit 2026-09-30, rule 12 (visible adaptation, contrast) and the design
// bans of CLAUDE.md ("Eyebrow labels: tiny uppercase with letter-spacing above headings").
//
// WHAT IT GUARDS. The AUv3 plug-in view (`AUv3PluginView` in `AudioUnitViewController.swift`)
// is the one surface that compiles WITHOUT the app's theme — the extension links `DSP/` plus
// three Foundation-only `Core/` files — so it spells its typography in absolute `.system(size:)`
// and `Color(white:)` literals. That exemption covers `EchoelValueField` and nothing else. Until
// 2026-09-30 its two section titles were eyebrows (`uppercased()`, 11 pt bold, `.kerning(1.5)`,
// white 0.35 on the 0.05 background = 2.8:1), and two more text colours sat at white 0.4
// (3.4:1). Rule 12's floor for text is 4.5:1; the ban is on the shape.
//
// §1 LIMIT: SOURCE-TEXT SCAN, all claims. Nothing here renders the view in a host. What the
// scans carry: the shape is gone, every text colour literal clears the floor by the WCAG
// formula, the titles are still shown. Device look in AUM is the founder's.
//
// §3 HONEST GRADING, transcribed in Python against the parent (e4bc07122) and this tree:
// claim 1 is the DECISION — on the parent `.kerning(` and `uppercased()` are both present, so
// its two assertions are RED there (one decision, #486). Claim 2 is red on the parent too, as
// ONE offender list (0.35, 0.4, 0.4) and green here; it is written as a computed threshold, not
// a pinned grey, so a designer may pick any shade that clears 4.5:1 (#364). Claim 3's first
// assertion (the section builder exists) is a COUNTERWEIGHT, green on both trees; its second
// (`Text(title)`) is the other half of the decision and RED on the parent, which spelled
// `Text(title.uppercased())`. ZERO regressions claimed.

import Foundation
import XCTest

final class TheAUv3ViewHasNoEyebrowTests: XCTestCase {

    private static let view = "Sources/EchoelmusicAUv3/AudioUnitViewController.swift"

    /// The plug-in background, as the file spells it. An anchor: if it moves, claim 2 has
    /// nothing to contrast against and must FAIL, not pass.
    private static let backgroundLiteral = "Color(red: 0.05, green: 0.05, blue: 0.05)"
    private static let backgroundWhite = 0.05

    // MARK: - claim 1 — the DECISION: no eyebrow shape

    func testTheSectionTitlesAreNotEyebrows() throws {
        let code = try source(Self.view)
        XCTAssertFalse(code.contains(".kerning(") || code.contains(".tracking("), """
            The AUv3 view letter-spaces a label again. Letter-spacing on a small uppercase title \
            is the eyebrow pattern CLAUDE.md bans (Uncodixfy). A section title is a plain word: \
            13 pt semibold, normal case, a legible grey.
            """)
        XCTAssertFalse(code.contains("uppercased()"), """
            The AUv3 view uppercases a label again — the other half of the eyebrow shape. Titles \
            keep the case they are written in.
            """)
    }

    // MARK: - claim 2 — every text colour clears the 4.5:1 floor against the background

    func testEveryTextGreyClearsTheContrastFloor() throws {
        let code = try source(Self.view)
        guard code.contains(Self.backgroundLiteral) else {
            XCTFail("ANCHOR MISSING: the plug-in background is no longer `\(Self.backgroundLiteral)`. "
                    + "Re-anchor `backgroundWhite` to the new colour — a missing anchor is a finding, not a pass.")
            return
        }
        let greys = Self.textGreys(in: code)
        XCTAssertFalse(greys.isEmpty, "ANCHOR: no `.foregroundColor(Color(white:))` left to grade — re-anchor this scan")
        let floor = 4.5
        let offenders = greys.filter { Self.contrast($0, Self.backgroundWhite) < floor }
        XCTAssertTrue(offenders.isEmpty, """
            \(offenders.count) AUv3 text grey(s) sit under the \(floor):1 floor against the \
            \(Self.backgroundWhite) background: \(offenders). Rule 12 (WCAG 1.4.3): body-size \
            text needs 4.5:1. white 0.6 gives 6.8:1, white 0.7 gives 9.2:1 — pick any shade that \
            clears the floor; the number is computed, not pinned.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT, #343) — the titles are still shown

    func testTheSectionTitlesAreStillRendered() throws {
        let code = try source(Self.view)
        XCTAssertTrue(code.contains("private func parameterSection<Content: View>(_ title: String"), """
            `parameterSection(_ title:)` is gone — claim 1 would then be green over a deleted \
            title rather than a repaired one. Move this scan with the section builder.
            """)
        XCTAssertTrue(code.contains("Text(title)"), """
            The section title is no longer rendered as `Text(title)`. The repair kept the word \
            and removed the shape; a title that disappears is not the fix.
            """)
    }

    // MARK: - helpers

    /// Every `X` in `.foregroundColor(Color(white: X))` — TEXT colours only. Fills, tints and
    /// the background use other spellings and are graded by the 3:1 component rule, not here.
    static func textGreys(in code: String) -> [Double] {
        var out: [Double] = []
        var search = code[...]
        let marker = ".foregroundColor(Color(white: "
        while let r = search.range(of: marker) {
            let rest = search[r.upperBound...]
            let digits = rest.prefix { $0.isNumber || $0 == "." }
            if let v = Double(digits) { out.append(v) }
            search = rest
        }
        return out
    }

    /// WCAG 2.x relative luminance of a grey, then the contrast ratio of two greys.
    static func luminance(_ grey: Double) -> Double {
        grey <= 0.03928 ? grey / 12.92 : pow((grey + 0.055) / 1.055, 2.4)
    }

    static func contrast(_ a: Double, _ b: Double) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // MARK: - source access

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped source (#453 — one stripper for the whole bundle). A SKIP without a
    /// checkout, a FAILURE when a named file moved (#454: a skip passes CI).
    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

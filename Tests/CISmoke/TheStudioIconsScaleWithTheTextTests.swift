// TheStudioIconsScaleWithTheTextTests.swift
// Echoel — Zug 4 „Klarheit" (2026-09-30), first family: the small Studio surfaces' SF Symbols
// grow with Dynamic Type, the way the Workstation's already do (UX D, 2026-09-26,
// `TheWorkstationIconsScaleWithTheTextTests`).
//
// WHAT THIS PINS. 63 icon sites under `Sources/Echoelmusic/` still drew their SF Symbol with an
// absolute `.font(.system(size: N))`, beside labels set in `EchoelTheme.font(N)` — which is
// `Font.custom(_:size:relativeTo: .body)` and scales. At the larger accessibility text sizes the
// word grew and the glyph next to it did not: a 44 pt label with an 11 pt chevron. A symbol takes
// its point size (and weight) from whatever font it is given, so the label's own font is the
// repair; nothing new is introduced. `.medium` and `.light` become the regular face, because the
// app ships Regular and Bold only (`TypeWeightsThatExistTests`) — spelling a weight that cannot
// draw would be the #361 defect written on purpose.
//
// 1. RATCHET (a NAMED list, grown family by family — #364: a directory walk would forbid the one
//    legitimate fixed size, see 3): the listed files contain no `.system(size:` in CODE.
// 2. COUNTERWEIGHTS (#343): every listed file still draws an `Image(systemName:` (a scan over a
//    file with no icons would pass for nothing), and `EchoelTheme.font` is still the scaling face.
// 3. CEILING over the whole tree: at most N absolute `.font(.system(size:` remain in CODE under
//    `Sources/Echoelmusic/`, `Resources/AppIcon.swift` excluded. N only ever goes DOWN — lower it
//    in the same commit that converts the next family; raising it is the regression. The one
//    excluded file is excluded for a stated reason and that reason is pinned: its `E` is sized
//    PROPORTIONALLY to a `GeometryReader` box (`size * 0.52`), the fixed-ratio canvas case that
//    `EchoelTheme.faceName`'s own doc names as the place a scaling font is the bug, not the tidy.
// 4. REACH: the walk behind 3 saw the tree (an empty walk would make 3 a vacuous green).
//
// Grading (§0, no Swift toolchain; transcribed in Python against both trees, raw and
// comment-stripped). Family 1: claim 1 red on the parent `22fac500a` for all 14 files (21 sites
// — ONE finding, #486), green on `51c2a34e0`; the stripper is LOAD-BEARING for one file
// (`BioMetricInfo` quotes the spelling in two comments, so raw text stays red on the corrected
// tree). Claim 3 red on the parent (63 > 42), green there at exactly 42. Family 2: claim 1 red
// on `51c2a34e0` for `EchoelStudioView` (19 sites, one finding), green here; claim 3 red there
// (42 > 23), green here at exactly 23. Claims 2 and 4 green on every tree.
// SOURCE-TEXT SCAN throughout: it proves the font is written this way, never how it reads.
// NEEDS-FOUNDER-VERIFY: Settings → Accessibility → Larger Text, largest size → the guide's ✕,
// the FX star, the Bio Learn chevrons, the space stage's empty-state glyph, the instrument's
// chip chevrons and preset stars grow with their words and nothing clips.

import Foundation
import XCTest

final class TheStudioIconsScaleWithTheTextTests: XCTestCase {

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"
    private static let appIcon = "Sources/Echoelmusic/Resources/AppIcon.swift"

    /// Family 1 (2026-09-30): the small Studio surfaces, 21 sites. Family 2 (same day):
    /// `EchoelStudioView`, 19 sites. Family 3 — `FloatingVisualWindow` · `BioStripView` ·
    /// `PatchbayView` · `BioSourceView` — is added here as it is converted, and `ceiling` drops.
    private static let converted = [
        "GuideOverlay", "EchoelIconTile", "ProUnlockView", "ImmersiveStageView", "BioMetricInfo",
        "EchoelFXView", "AudioDegradedRow", "LiveNarrationDisclosure", "BodyTempoField",
        "LearnView", "SessionView", "LiveColaboView", "MeditationView", "HeaderMonitors",
        "EchoelStudioView",
    ].map { "Sources/Echoelmusic/Studio/\($0).swift" }

    /// Absolute icon sizes still allowed in CODE across the tree (AppIcon excluded). 63 before
    /// family 1, 42 after it, 23 after family 2. Lower it with every converted family; never
    /// raise it.
    private static let ceiling = 23

    // MARK: 1 — RATCHET

    func testTheConvertedFilesHaveNoFixedSizeFont() throws {
        for path in Self.converted {
            let code = try source(path)
            XCTAssertFalse(code.contains(".system(size:"), """
                `\(path)` sets an absolute `.system(size:)` again. It does not scale with Dynamic \
                Type, so the icon stays small beside a label that grows. Give the \
                `Image(systemName:)` the label's own `EchoelTheme.font(_:_:)` — and if the site \
                asked for `.medium` or `.light`, write no weight: the bundled family has neither.
                """)
        }
    }

    // MARK: 2 — COUNTERWEIGHTS

    func testTheConvertedFilesStillDrawIconsAndTheFaceStillScales() throws {
        for path in Self.converted {
            XCTAssertTrue(try source(path).contains("Image(systemName:"),
                          "the scan above only means something while `\(path)` draws icons")
        }
        let theme = try source(Self.theme)
        XCTAssertTrue(theme.contains("return .custom(faceName(weight), size: size, relativeTo: .body)"),
                      "`EchoelTheme.font` must stay the Dynamic-Type-scaling face, or the swap fixed nothing")
    }

    // MARK: 3 — CEILING

    func testTheTreeKeepsNoMoreFixedIconSizesThanTheCeiling() throws {
        let files = try swiftFiles()
        var sites: [String] = []
        for file in files where file.rel != "Resources/AppIcon.swift" {
            for (i, line) in file.code.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains(".font(.system(size:") {
                sites.append("\(file.rel):\(i + 1)")
            }
        }
        XCTAssertLessThanOrEqual(sites.count, Self.ceiling, """
            \(sites.count) absolute `.font(.system(size:` sites in code under Sources/Echoelmusic \
            (AppIcon excluded) — the ceiling is \(Self.ceiling). A new fixed icon size went in: \
            \(sites.suffix(5).joined(separator: ", ")). Use `EchoelTheme.font(_:_:)`, which scales \
            with Dynamic Type; the ceiling only ever comes down.
            """)
        // The exclusion is a reason, not a blanket: the mark's `E` is proportional to its box.
        XCTAssertTrue(try source(Self.appIcon).contains(".font(.system(size: size * 0.52"), """
            `AppIcon.swift` is excluded from the ceiling because its `E` is sized proportionally to \
            a GeometryReader box — the fixed-ratio canvas case `EchoelTheme.faceName` documents. \
            That proportional spelling is gone, so the exclusion has lost its reason: fold the \
            file into the walk or state the new one here.
            """)
    }

    // MARK: 4 — REACH

    func testTheWalkSawTheTree() throws {
        let files = try swiftFiles()
        XCTAssertGreaterThan(files.count, 200, """
            Only \(files.count) Swift files were walked under Sources/Echoelmusic. The tree holds \
            well over three hundred; a truncated walk makes the ceiling above a vacuous green.
            """)
        XCTAssertTrue(files.contains { $0.rel == "Resources/AppIcon.swift" },
                      "the excluded file must be one the walk would otherwise have seen")
    }

    // MARK: helpers

    private func repoRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources/Echoelmusic").path) else {
            throw XCTSkip("source tree not present under \(root.path) — this test inspects source text")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func swiftFiles() throws -> [(rel: String, code: String)] {
        let sources = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return [] }
        var out: [(rel: String, code: String)] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(rel), encoding: .utf8)
            out.append((rel, SourceText.codeOnly(text)))
        }
        return out
    }
}

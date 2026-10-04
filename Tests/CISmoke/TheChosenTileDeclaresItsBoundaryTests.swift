// TheChosenTileDeclaresItsBoundaryTests.swift
// Echoel — Restructure F4b (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §2C/§3).
//
// WHAT WAS WRONG. A switch or a chosen option is one tile with two states: OFF is the plain
// `fill` tile, ON is the inverted monochrome tile (`.text` fill, `onPrimary` label — F4a). Eleven
// such tiles exist in `Sources/`. Two of them (the studio menu chip, `EchoelIconTile`) draw
// their OFF state with `borderStrong`, the token `EchoelTheme` introduced because the old
// `border` reads 1.16:1 — a control nobody can see until it is already on. The other nine —
// the Mute and Solo letters, the Warp and Click switches, the scene and mixer switches, the
// play-surface sound, visual preset and look chips, the visual-window switch — still drew it
// with `border`. So one tile had two boundaries, and nine of them were invisible at rest.
//
// THE REPAIR. All nine take `borderStrong`. A tile that clears its frame while ON (the `.text`
// fill is its own edge) keeps doing so: `on ? Color.clear : EchoelTheme.borderStrong`, the
// spelling `EchoelIconTile` already uses.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `09741ea80` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: 9 of 11 tiles bounded by `border`.
//   · claim 2 — COUNTERWEIGHT, green on both: the walk finds all eleven tiles, so claim 1 cannot
//     pass by a tile changing its fill spelling and dropping out of the scan.
// It does NOT prove the edge reads on a device; that is a glance with Increase Contrast on and off.

import Foundation
import XCTest

final class TheChosenTileDeclaresItsBoundaryTests: XCTestCase {

    /// `.fill(<state> ? EchoelTheme.text : EchoelTheme.fill))` — the inverted monochrome tile.
    private static let invertedTile = #"\.fill\([^)\n]*\?\s*EchoelTheme\.text\s*:\s*EchoelTheme\.fill\)\)"#

    /// Measured 2026-10-04 on the F4b tree. A new tile raises it; a removed one lowers it.
    private static let expectedTiles = 11

    /// Each tile's stroke sits in the overlay right after its fill. Comment lines are blanked by
    /// `SourceText.codeOnly` and skipped, so a comment between the two cannot hide the stroke.
    private func tiles() throws -> [(site: String, stroke: String?)] {
        let regex = try NSRegularExpression(pattern: Self.invertedTile)
        var out: [(site: String, stroke: String?)] = []
        for (path, code) in try swiftSources() {
            let lines = code.components(separatedBy: "\n")
            for (i, line) in lines.enumerated()
            where regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                var stroke: String?
                var seen = 0
                var j = i + 1
                while j < lines.count, seen < 4 {
                    let next = lines[j].trimmingCharacters(in: .whitespaces)
                    j += 1
                    if next.isEmpty { continue }
                    seen += 1
                    if next.contains("strokeBorder(") { stroke = next; break }
                }
                out.append((site: "\(path):\(i + 1)", stroke: stroke))
            }
        }
        return out
    }

    /// 1 — every inverted tile declares its OFF boundary with `borderStrong`.
    func testEveryChosenTileDrawsTheStrongBoundary() throws {
        for tile in try tiles() {
            guard let stroke = tile.stroke else {
                XCTFail("\(tile.site): an inverted tile with no `strokeBorder(` after its fill — a switch with no edge at rest")
                continue
            }
            XCTAssertTrue(stroke.contains("EchoelTheme.borderStrong"), """
                \(tile.site) bounds its tile with `\(stroke)`. A switch or chosen option draws its \
                OFF edge with `EchoelTheme.borderStrong` — `border` reads 1.16:1 and the control \
                is invisible until it is on.
                """)
        }
    }

    /// 2 — COUNTERWEIGHT: the walk finds the tiles it is about.
    func testTheScanFindsEveryTile() throws {
        let found = try tiles()
        XCTAssertEqual(found.count, Self.expectedTiles, """
            Expected \(Self.expectedTiles) inverted tiles, found \(found.count): \
            \(found.map { $0.site }). Move the number with the tile, in the same commit.
            """)
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// Every `.swift` file under `Sources/`, comment-stripped. An empty walk FAILS.
    private func swiftSources() throws -> [(String, String)] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let sources = root.appendingPathComponent("Sources")
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

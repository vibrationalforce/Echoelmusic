// TheSpacingSitsOnTheScaleTests.swift
// Echoel — Restructure F2a (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md`).
//
// WHAT WAS WRONG. The app had no spacing scale. `spacing:` took fourteen different literals
// across `Sources/` (8, 6, 10, 4, 2, 14, 0, 12, 1, 3, 5, 16, 18, 7, 24, …), so two neighbouring
// rows rarely shared a rhythm, and the F1 tool buttons sat 6 pt apart in one file and 8 pt in
// the next.
//
// THE REPAIR. `EchoelTheme` owns one 4-pt scale: `spaceXS` … `spaceXL`. The three files F1
// touched (`SelectedPartBar`, `PartNoteEditor`, `SongHistoryRow`) now take every gap from it;
// 6 became 8. The rest of the app migrates file by file, and this guard is the ratchet: the
// number of literal gaps may only fall.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`. Transcribed in Python against the parent `ef49372bf` and the worktree, with
// `SourceText.codeOnly` copied line for line:
//   · claim 1 — RED on the parent, a REGRESSION: 9 + 9 + 2 literals in the three files.
//   · claim 2 — RED on the parent, a REGRESSION: 716 literal gaps against a ceiling of 696.
//   · claim 3 — red on the parent by ANCHOR ABSENCE only (the scale did not exist). One absence.
//   · claim 4 — COUNTERWEIGHT, green on both: the walk must find the source tree.
// It does NOT prove the rows look right; the 2-pt widening is a device glance.

import Foundation
import XCTest

final class TheSpacingSitsOnTheScaleTests: XCTestCase {

    private static let migrated = [
        "Sources/Echoelmusic/Studio/SelectedPartBar.swift",
        "Sources/Echoelmusic/Studio/PartNoteEditor.swift",
        "Sources/Echoelmusic/Studio/SongHistoryRow.swift",
    ]

    /// Measured 2026-10-04 on the F2a tree. LOWER it in the commit that migrates another file;
    /// never raise it — a new literal gap takes a step from the scale instead.
    private static let ceiling = 696

    /// A numeric literal as a stack's `spacing:` or as a `.padding(` amount, with or without
    /// an edge set in front of it.
    private static let literalGap =
        #"spacing:\s*-?[0-9]|\.padding\((?:\.[A-Za-z]+,\s*|\[[^\]]*\],\s*)?-?[0-9]"#

    /// 1 — the files that migrated carry no literal gap.
    func testTheMigratedFilesTakeEveryGapFromTheScale() throws {
        for path in Self.migrated {
            let hits = try count(in: read(path))
            XCTAssertEqual(hits, 0, """
                \(path) has \(hits) literal `spacing:`/`.padding(` amount(s). It migrated to the \
                scale in F2a; take `EchoelTheme.spaceXS` … `spaceXL` instead of a number.
                """)
        }
    }

    /// 2 — RATCHET: across `Sources/`, the literal gaps only fall.
    func testTheLiteralGapsOnlyFall() throws {
        var total = 0
        var worst: [(String, Int)] = []
        for (path, code) in try swiftSources() {
            let hits = try count(in: code)
            total += hits
            if hits > 0 { worst.append((path, hits)) }
        }
        let top = worst.sorted { $0.1 > $1.1 }.prefix(5).map { "\($0.0) (\($0.1))" }
        XCTAssertLessThanOrEqual(total, Self.ceiling, """
            \(total) literal gaps in Sources/, ceiling \(Self.ceiling). A new row takes a step \
            from the scale (`EchoelTheme.spaceXS` … `spaceXL`). Largest holders: \(top).
            """)
    }

    /// 3 — the scale: five named steps, ascending, each on the 4-pt grid.
    func testTheScaleIsFiveStepsOnTheFourPointGrid() throws {
        let theme = try read("Sources/Echoelmusic/Studio/EchoelTheme.swift")
        var values: [Int] = []
        for name in ["spaceXS", "spaceS", "spaceM", "spaceL", "spaceXL"] {
            let pattern = #"static let "# + name + #":\s*CGFloat = ([0-9]+)\b"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(theme.startIndex..., in: theme)
            guard let match = regex.firstMatch(in: theme, range: range),
                  let swiftRange = Range(match.range(at: 1), in: theme),
                  let value = Int(theme[swiftRange]) else {
                return XCTFail("ANCHOR MISSING: `static let \(name): CGFloat = …` in EchoelTheme (#454)")
            }
            values.append(value)
        }
        XCTAssertEqual(values, values.sorted(), "the steps must ascend XS → XL: \(values)")
        XCTAssertEqual(Set(values).count, values.count, "two steps share a value: \(values)")
        XCTAssertTrue(values.allSatisfy { $0 > 0 && $0 % 4 == 0 }, "every step sits on the 4-pt grid: \(values)")
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

    private func count(in code: String) throws -> Int {
        let regex = try NSRegularExpression(pattern: Self.literalGap)
        return regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
    }

    /// 4 (inside 2) — every `.swift` file under `Sources/`, comment-stripped. A walk that finds
    /// nothing FAILS: an empty walk would pass the ratchet vacuously.
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

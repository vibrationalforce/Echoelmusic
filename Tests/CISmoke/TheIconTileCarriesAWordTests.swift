// TheIconTileCarriesAWordTests.swift
// Echoel — interface audit 2026-09-30, Gestaltung rule 3 ("Symbol plus Wort, immer"). BLOCKING
// bundle. SOURCE-TEXT SCAN: it proves the tile renders its word and every caller supplies one;
// how the row reads on the device is a founder look.
//
// THE DEFECT. `EchoelIconTile` — the one chrome chip (#481/#482) — was a glyph in a box. Seven
// main actions on the instrument plate (Record, Keep last, Export MIDI, Save, Open, Live Colabo,
// Learn) were icon-only, each with a spoken label and none with a visible word. The tile's own
// doc called that "a real cost, paid" through `accessibilityLabel` — paid for VoiceOver, not for
// a sighted first-time user, who has to guess what `clock.arrow.circlepath` does. WCAG 2.5.3
// (Label in Name) wants the visible word inside the accessible name; COGA wants recognition.
//
// THE DECISION (council 2026-09-30, founder-approved rule 3, design delegated). The tile carries
// a REQUIRED `title` (no default — #431: an argument no call site writes appears in no diff, so
// the compiler makes every caller choose a word) rendered under the glyph at the 11 pt floor
// (rule 12), in the tile's own tint. All seven grow by the same caption, so "immer gleichgroß"
// (#481) holds; the glyph box keeps `controlHeight`, the tap floor keeps `controlTapHeight`
// (`OneChromeControlHeightTests` still reads both). ⚠️ The chip is taller than the header tiles
// it was matched to on 2026-08-07 — that is the trade rule 3 makes, stated, not hidden.
//
// WHAT THIS GUARDS.
//   1. The tile declares `let title: String` with no default and renders `Text(title)`.
//   2. Every `EchoelIconTile(` call site in `Sources/` passes `title:` (paren-matched, so a
//      multi-line call counts once).
//   3. LABEL IN NAME, for every call site whose title is a literal AND whose Button's FIRST
//      `.accessibilityLabel(` carries a literal: that literal contains the word. Two sites are
//      dynamic and read by eye, stated as a limit: Record's title `exportTitle` is a word of the
//      matching `exportLabel` state in every branch; Keep last's LABEL is `KeepLastCopy.title`,
//      whose branches begin "Keep last" except the busy label while a take is being written —
//      the tile is disabled then. ⛔ The first draft took the next label LITERAL anywhere before
//      the next tile and, for Keep last, read a different control's label 300 lines down; the
//      transcription caught it. The first `.accessibilityLabel(` after a tile is its Button's.
//   4. The caption sits on the floor: `EchoelTheme.font(11` in the tile, nothing smaller.
//
// GRADING against the parent: claims 1, 2 and 4 RED by absence of `title` (one absence, #486);
// claim 3 RED there too, by its floor of five literal titles (none exist on the parent); all green here.

import Foundation
import XCTest

final class TheIconTileCarriesAWordTests: XCTestCase {

    private static let tile = "Sources/Echoelmusic/Studio/EchoelIconTile.swift"

    // MARK: 1 — the tile has a required word and renders it

    func testTheTileDeclaresARequiredTitleAndRendersIt() throws {
        let code = try codeOnly(Self.tile)
        XCTAssertTrue(code.contains("let title: String\n"), """
            EchoelIconTile no longer declares `let title: String` as a stored, undefaulted \
            property. A default (`= ""`) would let a caller ship a mute tile again without a \
            diff line — the compiler is the guard here (#431).
            """)
        XCTAssertTrue(code.contains("Text(title)"), "EchoelIconTile no longer renders `Text(title)` — the word is the point of rule 3")
    }

    // MARK: 2 — every caller passes a word

    func testEveryCallSitePassesATitle() throws {
        let sites = try callSites()
        XCTAssertGreaterThanOrEqual(sites.count, 7, "expected at least the seven tiles counted at #492; found \(sites.count) — a scan that saw fewer is not a pass")
        for site in sites {
            XCTAssertTrue(site.arguments.contains("title:"), """
                \(site.file): `EchoelIconTile(\(site.arguments))` passes no `title:`. Rule 3: \
                symbol plus word, always — an icon-only main action is a guess.
                """)
        }
    }

    // MARK: 3 — the visible word is inside the spoken name

    func testTheVisibleWordIsInsideTheSpokenName() throws {
        let sites = try callSites()
        var literalSites = 0
        for site in sites {
            guard let word = Self.literalTitle(in: site.arguments) else { continue }
            literalSites += 1
            XCTAssertFalse(word.isEmpty, "\(site.file): an empty title is a mute tile in a costume")
            guard site.hasAccessibilityLabel else {
                XCTFail("\(site.file): the tile titled \"\(word)\" has no `.accessibilityLabel(` at all — an icon-plus-word control still needs its spoken name"); continue
            }
            guard let label = site.nextAccessibilityLabel else { continue } // dynamic label — read by eye (header)
            XCTAssertTrue(label.contains(word), """
                \(site.file): the tile shows "\(word)" but VoiceOver says "\(label)". WCAG 2.5.3 — \
                the visible word must be inside the spoken name, or a voice-control user cannot \
                say what they see.
                """)
        }
        XCTAssertGreaterThanOrEqual(literalSites, 5, "expected at least five literal titles (Open, Live Colabo, Learn, Save, MIDI); found \(literalSites)")
    }

    // MARK: 4 — the caption sits on the 11 pt floor

    func testTheCaptionSitsOnTheFloor() throws {
        let code = try codeOnly(Self.tile)
        XCTAssertTrue(code.contains("EchoelTheme.font(11"), "the caption is no longer set through `EchoelTheme.font(11` — rule 12's floor, scaling with Dynamic Type")
        for small in ["EchoelTheme.font(10", "EchoelTheme.font(9", ".system(size: 10", ".system(size: 9"] {
            XCTAssertFalse(code.contains(small), "EchoelIconTile carries `\(small)` — below the 11 pt floor")
        }
    }

    // MARK: - scanning

    private struct Site {
        let file: String
        let arguments: String
        /// The Button's first `.accessibilityLabel(` exists at all.
        let hasAccessibilityLabel: Bool
        /// Its literal, when it is a plain `"…"`; nil for a dynamic label.
        let nextAccessibilityLabel: String?
    }

    /// Every `EchoelIconTile(` construction under `Sources/`, comment-stripped, with its
    /// paren-matched argument text and the first `.accessibilityLabel("…")` literal after it
    /// (before the next construction). Text-based, never a line window: this repo's comment
    /// blocks become long runs of blank lines under `SourceText.codeOnly`.
    private func callSites() throws -> [Site] {
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not enumerable")
        }
        var sites: [Site] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let needle = "EchoelIconTile("
            var from = code.startIndex
            while let hit = code.range(of: needle, range: from..<code.endIndex) {
                // Skip the declaration itself and any mention that is not a call.
                let before = code[..<hit.lowerBound]
                if before.hasSuffix("struct ") { from = hit.upperBound; continue }
                var depth = 1
                var i = hit.upperBound
                while i < code.endIndex, depth > 0 {
                    if code[i] == "(" { depth += 1 } else if code[i] == ")" { depth -= 1 }
                    i = code.index(after: i)
                }
                let arguments = String(code[hit.upperBound..<code.index(before: i)])
                let next = code.range(of: needle, range: i..<code.endIndex)?.lowerBound ?? code.endIndex
                let label = Self.firstLabel(in: String(code[i..<next]))
                sites.append(Site(file: url.lastPathComponent, arguments: arguments,
                                  hasAccessibilityLabel: label.found, nextAccessibilityLabel: label.literal))
                from = i
            }
        }
        return sites
    }

    /// The FIRST `.accessibilityLabel(` after the tile — that one is its Button's. A later
    /// literal belongs to another control (the first draft's defect, see the header).
    private static func firstLabel(in text: String) -> (found: Bool, literal: String?) {
        guard let start = text.range(of: ".accessibilityLabel(") else { return (false, nil) }
        let rest = text[start.upperBound...]
        guard rest.first == "\"" else { return (true, nil) }
        let body = rest.dropFirst()
        guard let end = body.firstIndex(of: "\"") else { return (true, nil) }
        return (true, String(body[..<end]))
    }

    /// The literal after `title:` if the argument is a plain `"…"`, else nil (a dynamic title).
    private static func literalTitle(in arguments: String) -> String? {
        guard let t = arguments.range(of: "title:") else { return nil }
        let rest = arguments[t.upperBound...].drop { $0 == " " }
        guard rest.first == "\"" else { return nil }
        let body = rest.dropFirst()
        guard let end = body.firstIndex(of: "\"") else { return nil }
        return String(body[..<end])
    }

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("repository root not found from \(#filePath) — source scan skipped, not passed")
        }
        return url
    }

    private func codeOnly(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — the file moved; update the path, do not let the scan pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

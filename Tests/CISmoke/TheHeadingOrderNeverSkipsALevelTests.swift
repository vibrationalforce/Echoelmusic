// TheHeadingOrderNeverSkipsALevelTests.swift
// Echoel — #1399: thirteen headings on the site jumped a level, and one labelled nothing at all.
//
// WHAT WAS MEASURED, 2026-09-20, over `docs/*.html` with `<style>`, `<script>` and HTML comments
// removed: **13** headings whose level was more than one deeper than the heading before them
// (`h1 → h3` on claims, health and support; `h2 → h4` on accessibility, brainstorming, overview
// and tools), and **one** `<h2>` immediately followed by another `<h2>` with nothing between —
// `integrations.html`'s "What is not here", which sat above the OSC-control section while the
// paragraph written for it sat below the table.
//
// ⭐ WHY IT MATTERS TO A PERSON. A screen-reader user navigates a long page by heading, and the
// level IS the outline: a jump from h2 to h4 says "this is a sub-sub-point of the last thing",
// and a heading followed by another heading says "this section is empty". Both are false here —
// the cards are peers, and the paragraph exists. This is WCAG 1.3.1 / technique H42 territory:
// advisory rather than a hard SC failure, which is exactly why it survives audits that only
// chase the normative list.
//
// ⚠️ THE REPAIR HAD TO BE INVISIBLE, AND THAT IS THE EXPENSIVE HALF. A browser's default `h3`
// is 1.17 em and `h4` is 1 em, so promoting a tag grows the text ~17 % unless the size is pinned.
// Every container rule was widened to name BOTH tags and given an explicit `font-size`, and
// `.subpage h2:not(.page-cta h2)` — which is (0,2,2) — had to gain two more `:not()`s, because
// otherwise it beat `.warning-box h2` (0,1,1) and would have restyled two callout boxes with
// uppercase and 2 px letter-spacing. Verified by measuring, not by reading: every promoted
// heading's computed `font-size`, `font-weight`, `color`, `text-transform`, `letter-spacing`,
// `margin-top`, `margin-bottom`, `line-height` and `font-family` before and after, in headless
// Chromium at 1024 px. **Zero differences across all 13.**
//
// KIND (§1): **SOURCE-TEXT SCAN.** It parses the heading tags out of the shipped HTML and checks
// their order. It cannot see a rendered size — the invisibility above is a measurement this
// commit made, not a property CI can re-check. Claims 3 and 4 pin the source conditions that
// made it invisible, which is the part a later edit can silently undo.
//
// GRADING (§3), transcribed in Python against both trees, parent `26ec1ee8d`:
// · Claim 1 (no level is skipped) — **RED on the parent**, 13 hits across 7 files.
// · Claim 2 (no heading is immediately followed by one of the same level with nothing between)
//   — **RED on the parent**, 1 hit: `integrations.html`.
// · Claims 3 and 4 are **FORWARD GUARDS**, not regressions, and saying so is the unflattering
//   label (#433). They read RED on the parent, but only because they name CSS rules this very
//   commit writes — they could never have been red for the defect's own reason, and booking
//   them as regressions would inflate this slice from two findings to four.
// · Claim 5 is the COUNTERWEIGHT (#343): green on both trees (313 headings parsed, all with
//   text), and it is what stops claims 1 and 2 passing over an empty parse.
// · NOT covered: the rendered size, and whether the outline is SEMANTICALLY right (a heading at
//   the correct level can still be the wrong heading).
//
// MUTATION, eight probes, each driven in Python against the worktree: demoting one card heading
// back to `h4` reds c1 and nothing else · splitting a section so two `h2`s meet reds c2 · dropping
// the old tag from the shared rule OR from a page's inline rule reds c3 · removing one `:not()`
// reds c4. THREE FALSE-POSITIVE PROBES STAY GREEN and they are the point of the design: a genuine
// third level (`h3` then `h4`), an `<h2>` written inside a `<style>` comment, and an `h2`
// introducing a row of `h3` cards — the normal shape of every page on this site.
//
// ⚠️ WHAT THIS GUARD DELIBERATELY DOES NOT DO (#364). It does not require a particular level for
// a particular card, does not forbid `h4` (a genuine third level under an `h3` is correct work
// and passes), and does not pin a count of headings per page. It asks one question — does any
// heading sit more than one level below the heading before it — which is the defect itself.

import XCTest

final class TheHeadingOrderNeverSkipsALevelTests: XCTestCase {

    private func docsDir() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        return dir.appendingPathComponent("docs")
    }

    private func pages() -> [(String, String)] {
        let docs = docsDir()
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [])
            .filter { $0.hasSuffix(".html") }.sorted()
        return names.compactMap { name in
            guard let body = try? String(contentsOf: docs.appendingPathComponent(name),
                                         encoding: .utf8) else { return nil }
            return (name, body)
        }
    }

    /// `html` with comments, `<style>` and `<script>` removed — see the sibling guards; a raw
    /// tag scan reads our own explanatory prose as markup (§2, #408).
    private func markupOnly(_ html: String) -> String {
        var out = html
        for (open, close) in [("<!--", "-->"), ("<style", "</style>"), ("<script", "</script>")] {
            var result = ""
            var rest = Substring(out)
            while let start = rest.range(of: open) {
                result += rest[rest.startIndex..<start.lowerBound]
                guard let end = rest[start.upperBound...].range(of: close) else {
                    rest = Substring(""); break
                }
                rest = rest[end.upperBound...]
            }
            result += rest
            out = result
        }
        return out
    }

    /// (level, text, everything up to the next heading) for each heading, in document order.
    private func headings(in html: String) -> [(Int, String, String)] {
        let code = markupOnly(html)
        var found: [(Int, String, String.Index, String.Index)] = []   // level, text, start, end
        var rest = Substring(code)
        while let open = rest.range(of: "<h") {
            let after = rest[open.upperBound...]
            guard let digit = after.first, let level = Int(String(digit)), (1...6).contains(level),
                  let tagEnd = after.firstIndex(of: ">") else {
                rest = after; continue
            }
            let bodyStart = after.index(after: tagEnd)
            guard let close = after[bodyStart...].range(of: "</h\(level)>") else {
                rest = after; continue
            }
            let inner = String(after[bodyStart..<close.lowerBound])
            var visible = ""
            var depth = 0
            for ch in inner {
                if ch == "<" { depth += 1 }
                else if ch == ">" { depth = max(0, depth - 1) }
                else if depth == 0 { visible.append(ch) }
            }
            found.append((level, visible.trimmingCharacters(in: .whitespacesAndNewlines),
                          open.lowerBound, close.upperBound))
            rest = after[close.upperBound...]
        }
        // The "content after this heading" runs from its close to the NEXT heading's open.
        var out: [(Int, String, String)] = []
        for (i, h) in found.enumerated() {
            let end = i + 1 < found.count ? found[i + 1].2 : code.endIndex
            out.append((h.0, h.1, String(code[h.3..<end])))
        }
        return out
    }

    // MARK: - Claim 1 — the outline has no hole in it

    func testNoHeadingSitsMoreThanOneLevelBelowTheOneBeforeIt() {
        var skips: [String] = []
        for (name, html) in pages() {
            var previous = 0
            for (level, text, _) in headings(in: html) {
                if previous > 0 && level > previous + 1 {
                    skips.append("\(name): h\(previous) → h\(level) at \"\(text.prefix(36))\"")
                }
                previous = level
            }
        }
        XCTAssertTrue(skips.isEmpty, """
            \(skips.count) heading(s) skip a level: \(skips.prefix(5).joined(separator: " · ")).
            A screen-reader user navigates a long page by heading, and the LEVEL is the outline: \
            h2 → h4 tells them "this is a sub-sub-point of the last thing" when the cards are \
            actually peers. Measured 2026-09-20: 13 such jumps across 7 pages, every one a card \
            heading inside a `.capability` / `.pillar` / `.engine-item` / `.feature-content` list \
            or a `.warning-box` / `.contact-box` callout.
            The repair is the TAG, not the look: widen the container's CSS rule to name both tags \
            and pin an explicit `font-size` (claim 3 checks that), or the promoted heading grows \
            ~17 % — a browser's default h3 is 1.17 em against h4's 1 em. This guard does not \
            forbid `h4` (#364): a genuine third level under an `h3` is correct and passes.
            """)
    }

    // MARK: - Claim 2 — no heading labels an empty section

    func testNoHeadingIsImmediatelyFollowedByAnotherAtTheSameLevel() {
        var empties: [String] = []
        for (name, html) in pages() {
            let hs = headings(in: html)
            for (i, h) in hs.enumerated() where i + 1 < hs.count {
                guard hs[i + 1].0 == h.0 else { continue }
                var visible = ""
                var depth = 0
                for ch in h.2 {
                    if ch == "<" { depth += 1 }
                    else if ch == ">" { depth = max(0, depth - 1) }
                    else if depth == 0 { visible.append(ch) }
                }
                if visible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    empties.append("\(name): h\(h.0) \"\(h.1.prefix(30))\" → h\(hs[i + 1].0) "
                                   + "\"\(hs[i + 1].1.prefix(30))\"")
                }
            }
        }
        XCTAssertTrue(empties.isEmpty, """
            \(empties.count) heading(s) are followed immediately by another at the same level \
            with nothing in between: \(empties.prefix(3).joined(separator: " · ")).
            To a screen reader that is a section with no content — the user jumps to it and \
            lands on the next heading. Measured 2026-09-20: `integrations.html`'s \
            "What is not here" sat above the OSC-control section while the paragraph written \
            for it (motion, EEG and live streaming — the three things that page denies) sat \
            below the table. The repair was to move the HEADING to its content, not to invent \
            copy for it. \
            ⚠️ A heading followed by a DEEPER one is fine and is not reported here — an `h2` \
            introducing a row of `h3` cards is the normal shape of this site.
            """)
    }

    // MARK: - Claim 3 — the counterweight: the promotion is still invisible

    func testEveryPromotedHeadingRuleStillNamesBothTagsAndPinsASize() {
        let shared = (try? String(contentsOf: docsDir().appendingPathComponent("shared.css"),
                                  encoding: .utf8)) ?? ""
        for rule in [".feature-content h3, .feature-content h4",
                     ".warning-box h2, .warning-box h3",
                     ".contact-box h2, .contact-box h3"] {
            XCTAssertTrue(shared.contains(rule), """
                `docs/shared.css` no longer carries the rule `\(rule)`.
                #1399 promoted the tag inside these containers one level up for heading order \
                and kept the OLD tag in the selector so an unconverted page still renders the \
                same. Dropping half the selector, or dropping the explicit `font-size` beside \
                it, makes the promotion visible: a browser's default h3 is 1.17 em against \
                h4's 1 em, and h2 is 1.5 em. Measured before and after — zero computed-style \
                differences across all 13 headings. Re-measure before changing this.
                """)
        }
        for (page, rule) in [("tools.html", ".capability h3, .capability h4"),
                             ("brainstorming.html", ".idea h3, .idea h4"),
                             ("brainstorming.html", ".capability h3, .capability h4"),
                             ("overview.html", ".pillar h3, .pillar h4"),
                             ("overview.html", ".engine-item h3, .engine-item h4")] {
            let body = (try? String(contentsOf: docsDir().appendingPathComponent(page),
                                    encoding: .utf8)) ?? ""
            XCTAssertTrue(body.contains(rule), """
                `docs/\(page)` no longer carries its inline rule `\(rule)`. Same reason as the \
                `shared.css` half above — these pages style their own cards (docs/CLAUDE.md §6 \
                is about exactly this split), so the fix had to be made in both places.
                """)
        }
    }

    // MARK: - Claim 4 — the counterweight: the generic h2 rule still yields to the callouts

    func testTheGenericSubpageHeadingRuleStillExcludesTheCallouts() {
        let shared = (try? String(contentsOf: docsDir().appendingPathComponent("shared.css"),
                                  encoding: .utf8)) ?? ""
        for exclusion in [":not(.warning-box h2)", ":not(.contact-box h2)"] {
            XCTAssertTrue(shared.contains(exclusion), """
                `docs/shared.css`'s `.subpage … h2` rule no longer carries `\(exclusion)`.
                That rule is specificity (0,2,2) and `.warning-box h2` is (0,1,1), so without \
                the exclusion the generic rule WINS and the two callout boxes silently gain \
                uppercase and 2 px letter-spacing — a visual change nobody asked for, caused by \
                a heading-order fix. `:not(.page-cta h2)` was already there and is the same \
                idiom. If the rule was restructured, re-measure the two boxes in a browser \
                before removing this claim.
                """)
        }
    }

    // MARK: - Claim 5 — the counterweight: the parser still sees the site

    func testTheHeadingParserStillFindsTheHeadings() {
        var total = 0
        var withText = 0
        for (_, html) in pages() {
            for (_, text, _) in headings(in: html) {
                total += 1
                if !text.isEmpty { withText += 1 }
            }
        }
        XCTAssertGreaterThan(total, 100, """
            Only \(total) heading(s) parsed across `docs/*.html` — there were well over 200 on \
            2026-09-20. Claims 1 and 2 pass trivially over an empty set (#926: a scan that finds \
            nothing is a finding, not a pass). Read `headings(in:)` and `markupOnly` before \
            believing the site lost its headings.
            """)
        XCTAssertEqual(withText, total, """
            \(total - withText) heading(s) parsed with EMPTY text. Either the site really has a \
            heading with no words in it — itself a finding — or the tag-stripping loop in \
            `headings(in:)` is eating the content, in which case claim 2 is comparing empty \
            strings and reports nothing. Both are worth opening.
            """)
    }
}

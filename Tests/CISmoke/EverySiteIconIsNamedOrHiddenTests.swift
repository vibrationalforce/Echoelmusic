// EverySiteIconIsNamedOrHiddenTests.swift
// Echoel — #1398: 29 of the site's 67 inline `<svg>` marks reached a screen reader as anonymous
// graphics sitting next to the text they duplicate.
//
// WHAT WAS MEASURED, 2026-09-20, over `docs/*.html` with `<style>`, `<script>` and HTML comments
// removed: **67** `<svg>` opening tags, **29** of them carrying neither `aria-hidden`, nor
// `role`, nor `aria-label`. Every one of the 29 was read in context before it was touched, and
// every one is DECORATIVE — which is why the repair is `aria-hidden="true"` throughout and not
// a label:
// · 15 social marks inside `<a aria-label="Instagram|TikTok|YouTube">` — the LINK is already
//   named; the mark repeats it, so an assistive technology announces the name twice.
// · 2 envelope marks inside `<a href="mailto:…">echoel@tropicaldrones.com</a>` — the address is
//   right there as text.
// · 11 `.cap-icon` / `.bento-icon` marks on the homepage, each immediately followed by the
//   `<span class="cap-label">` or `<h3>` that says what it means.
// · 1 waveform mark in `og-image.html`, a 1200 px Open-Graph template that is screenshotted and
//   linked from nowhere.
//
// ⚠️ THE MEASUREMENT THAT DECIDED "HIDE" RATHER THAN "LABEL", and it is the reason this is safe.
// The same rendered audit that found the invisible skip link (#1396) also asks which interactive
// elements have NO accessible name at all — `innerText`, `aria-label`, `aria-labelledby` and
// `title` all empty. It reported **zero** across every page at 390 and 320 px. So there is no
// icon-only control on this site whose meaning lives in its picture; hiding all 29 cannot
// silence anything. Claim 3 pins the half of that a source scan can see.
//
// KIND (§1): **SOURCE-TEXT SCAN.** It proves the attribute is written. Whether VoiceOver then
// says the right thing is a DEVICE PROBE and stays open — `docs/accessibility.html` is the page
// that promises this behaviour, and nothing in CI can hear it.
//
// GRADING (§3), transcribed in Python against both trees, parent `af4997e32`:
// · Claim 1 (no bare `<svg>` anywhere in `docs/`) — **RED on the parent**, 29 hits across 8 files.
// · Claims 2 and 3 are COUNTERWEIGHTS (#343), green on both trees, and they are what makes
//   claim 1 safe rather than merely tidy: `markupOnly` still leaves the marks claim 1 judges
//   (claim 2 — a stripper that swallowed the document would make claim 1 vacuous, #926), and
//   every icon-only link still carries a name of its own (claim 3 — hiding the mark is correct
//   only while the link around it is named; they are a PAIR, #739).
// · NOT covered: what a screen reader actually announces, and every non-`svg` image.
//
// ⛔ BOTH COUNTERWEIGHTS WERE WRONG IN THEIR FIRST DRAFT, IN OPPOSITE DIRECTIONS, AND MUTATION
// FOUND BOTH — reasoning about them did not. Claim 2 was `tags.count > 40`: a mutant that
// deleted all 25 marks from `index.html` left 42 and it stayed GREEN, while raising the number
// would have planted a stale literal (#818) that reds a legitimate redesign (#364). It now
// compares the stripped mark count against the RAW one, which is the hazard it was always
// about. Claim 3 demanded an `aria-label` on the first `instagram.com` / `tiktok.com` /
// `youtube.com` link per page — on `artist.html` that is a link to a reel and on `index.html`
// it is the words "Loewe Immerlieb", both correctly named by their own text: 2 findings on a
// tree where nothing was wrong. It now selects links whose content is ONLY a mark, which is the
// exact pair to claim 1 (§2, #408). Each claim's own doc comment carries its retraction.
//
// ⚠️ WHAT THIS GUARD DELIBERATELY DOES NOT DO (#364). It does not require `aria-hidden`; it
// requires ONE OF `aria-hidden`, `role` or `aria-label`. A future informative mark — a diagram,
// a status dot that is the only carrier of its meaning — is correct work: give it
// `role="img"` and an `aria-label`, and this guard goes green on that instead. The rule is
// "no anonymous graphic", not "no visible graphic".

import XCTest

final class EverySiteIconIsNamedOrHiddenTests: XCTestCase {

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

    /// `html` with the regions that are not markup removed: comments, `<style>`, `<script>`.
    ///
    /// ⚠️ NOT TIDINESS — the sibling guard `TheNavCannotLeaveTheScreenTests` shipped its first
    /// draft RED on a correct tree because a CSS comment it had just written contained the
    /// characters `<table>`. A tag scan over raw HTML reads prose as markup (§2, #408).
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

    /// Every `<svg …>` opening tag that is real markup, as (file, tag).
    private func svgTags() -> [(String, String)] {
        var out: [(String, String)] = []
        for (name, raw) in pages() {
            var rest = Substring(markupOnly(raw))
            while let open = rest.range(of: "<svg") {
                guard let close = rest[open.upperBound...].firstIndex(of: ">") else { break }
                out.append((name, String(rest[open.lowerBound...close])))
                rest = rest[rest.index(after: close)...]
            }
        }
        return out
    }

    // MARK: - Claim 1 — no anonymous graphic anywhere on the site

    func testNoInlineMarkReachesAScreenReaderAnonymously() {
        let tags = svgTags()
        let anonymous = tags.filter { _, tag in
            !tag.contains("aria-hidden") && !tag.contains("role=") && !tag.contains("aria-label")
        }
        XCTAssertTrue(anonymous.isEmpty, """
            \(anonymous.count) inline `<svg>` mark(s) in `docs/` carry none of `aria-hidden`, \
            `role` or `aria-label`: \
            \(anonymous.prefix(4).map { "\($0.0): \($0.1.prefix(48))" }.joined(separator: " · ")).
            A bare `<svg>` is announced as an unnamed graphic, next to the text it usually just \
            repeats. Measured 2026-09-20: all 29 marks in this state were decorative — social \
            icons inside links that already carry `aria-label`, envelope icons beside the \
            address written out as text, and homepage tiles whose label follows immediately.
            If yours is decorative too, `aria-hidden="true"` is the whole fix. If it is \
            INFORMATIVE — the only carrier of its own meaning — this guard is not a ban (#364): \
            give it `role="img"` and an `aria-label`, and it passes on that instead. What is not \
            acceptable is neither.
            """)
    }

    // MARK: - Claim 2 — the counterweight: the stripper is not eating the markup

    /// ⛔ THE FIRST VERSION OF THIS CLAIM WAS A COUNT (`tags.count > 40`) AND IT DID NOT BITE.
    /// Driven against a mutant that removed every `<svg>` from `index.html` — 25 of the site's
    /// 67 — it stayed GREEN at 42. Raising the number would have made it bite that mutant and
    /// made it a stale literal in the same breath (#818), red the day a page is legitimately
    /// redesigned (#364). The count was never the question: what makes claim 1 vacuous is
    /// `markupOnly` starting to swallow live markup, and that is measurable DIRECTLY — strip
    /// the file and compare the mark count with the raw one. A redesign that removes icons is
    /// correct work and leaves this green; a stripper that eats a page does not.
    func testTheStripperStillLeavesTheMarksItIsJudging() {
        var rawTotal = 0
        var strippedTotal = 0
        for (_, raw) in pages() {
            rawTotal += raw.components(separatedBy: "<svg").count - 1
            strippedTotal += markupOnly(raw).components(separatedBy: "<svg").count - 1
        }
        XCTAssertGreaterThan(strippedTotal, 0, """
            `markupOnly` leaves NO `<svg>` at all across `docs/*.html` (raw count \(rawTotal)). \
            Claim 1 then passes over an empty set and proves nothing (#926: a scan that finds \
            nothing is a finding, not a pass). Read `markupOnly` before believing the site lost \
            its icons.
            """)
        XCTAssertGreaterThanOrEqual(strippedTotal, rawTotal - 4, """
            `markupOnly` removed \(rawTotal - strippedTotal) of \(rawTotal) `<svg>` occurrences. \
            On 2026-09-20 it removed ZERO — every mark on this site is live markup, none sits \
            inside a comment, a `<style>` or a `<script>`. A jump means the stripper has started \
            swallowing the document (an unbalanced `<style` with no `</style>` truncates \
            everything after it), and claim 1 is now judging a fraction of the site while \
            reporting a clean run. The slack of four is for a future mark that genuinely lives \
            in a script template; it is not room for a broken stripper.
            """)
    }

    // MARK: - Claim 3 — the counterweight: hiding a mark is only safe while its link is named

    /// ⚠️ THIS CLAIM'S FIRST NEEDLE WAS TOO BROAD AND WAS RED ON A CORRECT TREE. It looked for
    /// the first `instagram.com` / `tiktok.com` / `youtube.com` on each page and demanded an
    /// `aria-label` on the `<a>` around it. On `artist.html` that first hit is a link to an
    /// Instagram REEL, and on `index.html` it is the words "Loewe Immerlieb" — ordinary text
    /// links, correctly named by their own text, needing no label at all. Measured: 2 findings
    /// on a tree where nothing was wrong. The question was never "is this link to a social
    /// network named"; it is **"is a link whose only content is a hidden mark named"** — which
    /// is the exact pair to claim 1 and matches only the sites it is about (§2, #408).
    func testAnIconOnlyLinkStillCarriesItsOwnName() {
        var checked = 0
        var anonymous: [(String, String)] = []
        for (name, raw) in pages() {
            let html = markupOnly(raw)
            var rest = Substring(html)
            while let open = rest.range(of: "<a ") {
                guard let tagEnd = rest[open.lowerBound...].firstIndex(of: ">") else { break }
                let tag = String(rest[open.lowerBound...tagEnd])
                let after = rest[rest.index(after: tagEnd)...]
                guard let closing = after.range(of: "</a>") else {
                    rest = after; continue
                }
                let inner = String(after[after.startIndex..<closing.lowerBound])
                rest = after[closing.upperBound...]

                guard inner.contains("<svg") else { continue }
                // Visible text = the inner content with every tag removed.
                var visible = ""
                var depth = 0
                for ch in inner {
                    if ch == "<" { depth += 1 }
                    else if ch == ">" { depth = max(0, depth - 1) }
                    else if depth == 0 { visible.append(ch) }
                }
                guard visible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue  // the link says its own name in words
                }
                checked += 1
                if !tag.contains("aria-label") && !tag.contains("aria-labelledby")
                    && !tag.contains("title=") {
                    anonymous.append((name, tag))
                }
            }
        }
        XCTAssertTrue(anonymous.isEmpty, """
            \(anonymous.count) link(s) in `docs/` contain nothing but an `<svg>` and carry no \
            name of their own: \
            \(anonymous.prefix(4).map { "\($0.0): \($0.1.prefix(70))" }.joined(separator: " · ")).
            Claim 1 requires every mark to be `aria-hidden` or labelled, and #1398 hid 29 of \
            them BECAUSE the link around each one was already named. A link that is only a \
            hidden mark has no accessible name at all — a screen reader announces a bare \
            "link" and the user cannot know where it goes. The two are a PAIR (#739): name the \
            link, or un-hide the mark and give it `role="img"` plus `aria-label`.
            """)
        XCTAssertGreaterThan(checked, 10, """
            Only \(checked) icon-only link(s) examined — there were 15 on 2026-09-20, the three \
            social marks on each of five pages. Re-anchor this claim before trusting it (#454); \
            as written it may be measuring almost nothing (#926).
            """)
    }
}

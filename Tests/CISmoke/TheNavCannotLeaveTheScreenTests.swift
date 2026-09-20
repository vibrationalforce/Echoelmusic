// TheNavCannotLeaveTheScreenTests.swift
// Echoel — #1397: one unclassed `<table>` pushed the whole site navigation off a phone screen.
//
// WHAT WAS MEASURED, 2026-09-20, headless Chromium at 390×844 against the served tree:
// `integrations.html` reported `document.documentElement.scrollWidth == 531` in a 390 px
// viewport, and `.nav` — the fixed header — had a used width of **531 px**. The burger button,
// the only door to the menu at phone width, sat at x = 467…507. **Entirely off-screen, with no
// way to open the navigation.** `body { overflow-x: hidden }` hid the scrollbar that would have
// betrayed it, so the page looked fine and the menu simply did not exist.
//
// ⭐ THE MECHANISM, because it is not obvious and it will recur. `body` carries
// `overflow-x: hidden` while `html` leaves overflow `visible`, so that value PROPAGATES to the
// viewport — and `body` itself keeps behaving as `visible`. Any element wider than the screen
// therefore grows the initial containing block. A `position: fixed` box with `left: 0; right: 0`
// resolves its width against THAT block, not against the screen. So a wide element ANYWHERE on
// a page drags the fixed header out with it. The wide element here was the OSC control-input
// table added with the remote-control slice: three tables on that page carry `class="spec-table"`
// (which becomes `display: block; overflow-x: auto` under 600 px) and the fourth carried no class
// at all, so it laid out at its natural 531 px.
//
// KIND (§1): **SOURCE-TEXT SCAN of a rendered finding.** No browser runs in CI, so nothing here
// can see a width. What is pinned is the source condition that produced the width, plus the two
// premises that make the hazard exist at all — if a premise changes, the message says what to
// re-measure.
//
// GRADING (§3), transcribed in Python against both trees, parent `17ba7ef4a`:
// · Claim 3 (`shared.css`'s `.nav` carries `max-width: 100vw`) — **RED on the parent.**
// · Claim 4 (`index.html`'s `.nav` carries it too) — **RED on the parent.**
// · Claim 5 (no `<table>` in `docs/` lays out unconstrained) — **RED on the parent**, one hit:
//   `integrations.html`. This is the claim that pins the actual repair.
// · Claim 7 (`code, kbd, samp { overflow-wrap: anywhere }`) — **RED on the parent.** A second,
//   independent reflow defect found in the same sweep: `<code>com.apple.developer.networking
//   .multicast</code>` laid out at 337 px in a 320 px viewport on artnet-sacn-from-a-phone.html
//   (and a 2 px case on architecture.html). `docs/shared.css` had no `code` rule at all.
// · Claims 1, 2, 6 and 8 are COUNTERWEIGHTS (#343), green on both trees, and they are the point:
//   the fixed/left/right shape still exists (claim 1), the overflow propagation still exists
//   (claim 2), the class a table is given still does something at phone width (claim 6), and a
//   spec-table address still refuses to break (claim 8 — the PAIR to claim 7, #739: making every
//   token breakable site-wide is wrong INSIDE a table that scrolls instead). A tree that kept
//   `max-width: 100vw` and lost any of those has kept the LINE and lost the FACT.
// · NOT covered: the rendered width itself, and every other element on the page. One page still
//   overflows after this commit and is CORRECT: `og-image.html` is a fixed 1200 px Open-Graph
//   template, linked from nowhere (`grep -l og-image.html docs/*.html` → nothing), whose whole
//   job is to be screenshotted at that size. It is named here so the next sweep does not "fix" it.
//
// ⚠️ WHICH LINE IS LOAD-BEARING WHERE — measured, not assumed, because the two homes differ.
// Removing `max-width` at runtime on `overview.html` (shared.css) and injecting a 900 px element
// takes the nav to 900 px and the burger's right edge to 876 on a 390 px screen. The SAME
// experiment on `index.html` leaves the nav at 390 px, because that page's `body` rule already
// carries `max-width: 100vw`. So claim 3 pins a repair and claim 4 pins PARITY between the two
// copies of `.nav` — docs/CLAUDE.md §6 exists because this file drifts from the shared one. Both
// are worth a claim; only one of them is the fix, and each file's own comment says which.
//
// ⚠️ WHAT THIS GUARD DELIBERATELY DOES NOT DO (#364). It does not ban a wide element, or pin a
// pixel value, or require `.spec-table` on future markup by name alone. Claim 5 asks a narrower
// question — does every `<table>` opening tag name a class this file knows to be width-safe —
// and its allow-list is ONE entry today. Adding a second table style is correct work: add its
// class here in the same commit, with its own narrow-width rule, and claim 6 will check that the
// rule exists. The guard makes the trade conscious; it does not forbid it.

import XCTest

final class TheNavCannotLeaveTheScreenTests: XCTestCase {

    /// Table classes known to become a horizontal scroller under 600 px. One entry today.
    private static let widthSafeTableClasses = ["spec-table"]

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        return dir
    }

    private func text(_ relative: String) -> String {
        guard let s = try? String(contentsOf: repoRoot().appendingPathComponent(relative),
                                  encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return s
    }

    /// The declaration block that follows the LAST occurrence of `selector` in `css`.
    private func ruleBody(after selector: String, in css: String) -> String? {
        guard let hit = css.range(of: selector, options: .backwards),
              let open = css[hit.upperBound...].firstIndex(of: "{"),
              let close = css[open...].firstIndex(of: "}") else { return nil }
        return String(css[css.index(after: open)..<close])
    }

    /// `html` with the regions that are NOT markup removed: comments, `<style>` and `<script>`.
    ///
    /// ⚠️ THIS IS NOT TIDINESS — it was a false positive, caught while grading this very file.
    /// The comment this commit added to `index.html` explains the defect in words, and the words
    /// contain the characters `<table>`. A raw scan for `<table` therefore reported `index.html`
    /// as carrying an unclassed table — on a page that has none at all (`grep -c '<table'` → 0
    /// before this commit). The guard would have been RED on a correct tree, for prose it
    /// required to be written. Same class as §2's #408: anchor on a token that occurs only at
    /// the intended site, and check that while AUTHORING the scan.
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

    /// Every `<table …>` opening tag in every page of `docs/`, as (file, tag).
    private func tableTags() -> [(String, String)] {
        let docs = repoRoot().appendingPathComponent("docs")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [])
            .filter { $0.hasSuffix(".html") }.sorted()
        var out: [(String, String)] = []
        for file in names {
            guard let raw = try? String(contentsOf: docs.appendingPathComponent(file),
                                        encoding: .utf8) else { continue }
            let body = markupOnly(raw)
            var rest = Substring(body)
            while let open = rest.range(of: "<table") {
                guard let close = rest[open.upperBound...].firstIndex(of: ">") else { break }
                out.append((file, String(rest[open.lowerBound...close])))
                rest = rest[rest.index(after: close)...]
            }
        }
        return out
    }

    // MARK: - Claim 1 — the premise: the header is still a fixed box sized by left/right

    func testTheHeaderIsStillAFixedBoxSizedByItsEdges() {
        let css = text("docs/shared.css")
        guard let body = ruleBody(after: "\n.nav ", in: css) ?? ruleBody(after: "\n.nav{", in: css)
        else {
            return XCTFail("No `.nav` rule in docs/shared.css — re-anchor this file before "
                           + "trusting any claim in it (#454).")
        }
        XCTAssertTrue(body.contains("position: fixed") && body.contains("left: 0")
                      && body.contains("right: 0"), """
            `docs/shared.css`'s `.nav` is no longer `position: fixed` with `left: 0; right: 0`:
              \(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            That shape is the whole reason claim 3 exists — a fixed box sized by its edges takes \
            its width from the initial containing block, which grows with the widest element on \
            the page. If the header is now `sticky`, or has an explicit width, re-measure in a \
            browser (inject a 900 px element, read `.nav`'s used width) before relaxing anything \
            here. This claim is a premise, not a ban.
            """)
    }

    // MARK: - Claim 2 — the premise: body's overflow still propagates to the viewport

    func testBodyStillHidesHorizontalOverflowAndHTMLDoesNot() {
        let css = text("docs/shared.css")
        guard let body = ruleBody(after: "\nbody ", in: css) else {
            return XCTFail("No `body` rule in docs/shared.css — re-anchor (#454).")
        }
        XCTAssertTrue(body.contains("overflow-x: hidden"), """
            `docs/shared.css`'s `body` no longer sets `overflow-x: hidden`.
            That is HALF of the mechanism behind #1397, and losing it is not automatically good \
            news: it is what hides the horizontal scrollbar, so a page can overflow and look \
            fine. If it is gone, an overflowing page now scrolls sideways visibly — a different \
            WCAG 1.4.10 problem with the same cause. Re-measure `document.documentElement\
            .scrollWidth` at 390 px on every page before changing claim 3.
            """)
        // The propagation only happens while `html` itself leaves overflow alone.
        let htmlRule = ruleBody(after: "\nhtml ", in: css) ?? ""
        XCTAssertFalse(htmlRule.contains("overflow"), """
            `docs/shared.css`'s `html` rule now sets `overflow`:
              \(htmlRule.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            That STOPS `body`'s `overflow-x: hidden` propagating to the viewport, which changes \
            what grows the initial containing block and therefore changes whether claim 3 is \
            load-bearing. It may well be the better fix — but it is a different fix, and the \
            comments in `shared.css` and `index.html` both describe the propagation as live. \
            Measure, then rewrite those two comments in the same commit (#456).
            """)
    }

    // MARK: - Claim 3 — the repair, in the shared stylesheet (LOAD-BEARING, measured)

    func testTheSharedHeaderCannotGrowPastTheScreen() {
        let css = text("docs/shared.css")
        guard let body = ruleBody(after: "\n.nav ", in: css) ?? ruleBody(after: "\n.nav{", in: css)
        else { return XCTFail("No `.nav` rule in docs/shared.css.") }
        XCTAssertTrue(body.contains("max-width: 100vw"), """
            `docs/shared.css`'s `.nav` no longer carries `max-width: 100vw`:
              \(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            Measured 2026-09-20: with that line removed at runtime and a 900 px element injected \
            into overview.html, `.nav` lays out at 900 px and the burger button's right edge \
            reaches x = 876 on a 390 px screen — the menu becomes unreachable on a phone, \
            silently, because `body { overflow-x: hidden }` hides the scrollbar. This is the \
            line, not a nicety. Claims 1 and 2 pin the two conditions that make it necessary; if \
            either is red, read THAT first.
            """)
    }

    // MARK: - Claim 4 — the same line in the homepage's own copy (PARITY, not the fix)

    func testTheHomepageHeaderCarriesTheSameLine() {
        let html = text("docs/index.html")
        guard let body = ruleBody(after: "\n        .nav ", in: html) else {
            return XCTFail("No `.nav` rule in docs/index.html — that page inlines its CSS "
                           + "(docs/CLAUDE.md §6); re-anchor before trusting this claim.")
        }
        XCTAssertTrue(body.contains("max-width: 100vw"), """
            `docs/index.html`'s inline `.nav` rule lost `max-width: 100vw`.
            On THIS page the line is prophylactic and measured to be so — its `body` rule already \
            carries `max-width: 100vw`, so injecting a 900 px element leaves the nav at 390 px \
            with or without it. What this claim protects is PARITY: index.html is the one page \
            that does not load `shared.css`, docs/CLAUDE.md §6 exists because it drifts, and a \
            header rule that says something different from the shared one is how the next \
            site-wide fix misses a page. If you removed it on purpose, remove the comment above \
            it in the same commit — it currently explains why it is there.
            """)
    }

    // MARK: - Claim 5 — the actual repair: no table lays out unconstrained

    func testNoTableInTheSiteLaysOutUnconstrained() {
        let tags = tableTags()
        XCTAssertGreaterThan(tags.count, 3, """
            Only \(tags.count) `<table>` tag(s) found across `docs/*.html`. This claim is \
            measuring almost nothing — re-anchor it (#926: a scan that finds nothing is a \
            finding, not a pass).
            """)
        let unsafe = tags.filter { _, tag in
            !Self.widthSafeTableClasses.contains { tag.contains("class=\"\($0)\"") }
        }
        XCTAssertTrue(unsafe.isEmpty, """
            \(unsafe.count) table(s) in `docs/` carry no width-safe class \
            (\(Self.widthSafeTableClasses.joined(separator: ", "))): \
            \(unsafe.prefix(4).map { "\($0.0) \($0.1)" }.joined(separator: " · ")).
            A table with no class lays out at its natural width. Measured 2026-09-20 on exactly \
            this defect: the unclassed OSC-control table on integrations.html was 531 px wide in \
            a 390 px viewport, which grew the initial containing block, which took the fixed \
            header to 531 px, which put the burger button at x = 467…507 — off-screen, with no \
            way to open the navigation on a phone. The failure is SILENT because \
            `body { overflow-x: hidden }` swallows the scrollbar.
            If this table is a genuinely narrow one, that is fine and this guard is not a ban \
            (#364): give it a class, give that class a `@media (max-width: 600px)` rule, and add \
            the class name to `widthSafeTableClasses` in the same commit. Claim 6 then checks \
            the rule really exists.
            """)
    }

    // MARK: - Claim 6 — the counterweight: the class still does something at phone width

    func testTheTableClassStillBecomesAScrollerOnASmallScreen() {
        let docs = repoRoot().appendingPathComponent("docs")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [])
            .filter { $0.hasSuffix(".html") }.sorted()
        var declaring: [String] = []
        for file in names {
            guard let body = try? String(contentsOf: docs.appendingPathComponent(file),
                                         encoding: .utf8),
                  body.contains(".spec-table{") else { continue }
            declaring.append(file)
            XCTAssertTrue(body.contains("@media (max-width:600px){.spec-table{display:block;overflow-x:auto}}"), """
                `docs/\(file)` declares `.spec-table` but no longer turns it into a horizontal \
                scroller under 600 px. Without that rule the class is decoration: the table lays \
                out at its natural width again and takes the fixed header off the screen with it \
                — the exact #1397 defect, now hidden behind a class name that looks safe. \
                Claim 5 trusts this class; this is what makes that trust meaningful.
                """)
        }
        XCTAssertGreaterThan(declaring.count, 2, """
            Only \(declaring.count) page(s) declare `.spec-table` inline. Claim 5 allows that \
            class on every table in the site, so if the style now lives somewhere this scan \
            cannot see — `shared.css`, say — re-anchor this claim there rather than deleting it; \
            otherwise claim 5 is trusting a class nothing defines.
            """)
    }

    // MARK: - Claim 7 — the second reflow repair: a long token cannot widen the page

    func testALongCodeTokenCanBreak() {
        let css = text("docs/shared.css")
        XCTAssertTrue(css.contains("code, kbd, samp { overflow-wrap: anywhere; }"), """
            `docs/shared.css` no longer lets an inline code token break.
            Measured 2026-09-20 at a 320 px viewport — the width WCAG 1.4.10 names — \
            `<code>com.apple.developer.networking.multicast</code>` laid out at 337 px on \
            artnet-sacn-from-a-phone.html and took the whole page 17 px past the screen; a \
            second, 2 px case sat on architecture.html. Before this rule the file carried no \
            `code` declaration at all, so every inline span rode the browser default. If you \
            replaced `anywhere` with `break-word`, re-measure: `break-word` only breaks a word \
            that would overflow ITS OWN line box, which does nothing for a token that is alone \
            on the line.
            """)
    }

    // MARK: - Claim 8 — the counterweight: a spec-table address still stays in one piece

    func testTheSpecTableStillRefusesToBreakItsAddresses() {
        let docs = repoRoot().appendingPathComponent("docs")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [])
            .filter { $0.hasSuffix(".html") }.sorted()
        var checked = 0
        for file in names {
            guard let body = try? String(contentsOf: docs.appendingPathComponent(file),
                                         encoding: .utf8),
                  body.contains(".spec-table{") else { continue }
            checked += 1
            XCTAssertTrue(body.contains(".spec-table code{white-space:nowrap}"), """
                `docs/\(file)` declares `.spec-table` but no longer pins \
                `.spec-table code{white-space:nowrap}`. Claim 7 made every inline code token \
                breakable site-wide; inside a spec table that is the WRONG behaviour — an OSC \
                address broken mid-path is unreadable, and the table is already a horizontal \
                scroller (claim 6) precisely so it does not have to wrap. The two rules are a \
                PAIR (#739): remove this one and claim 7's rule starts shredding addresses, \
                and nothing else in the tree would say so.
                """)
        }
        XCTAssertGreaterThan(checked, 2,
            "Only \(checked) page(s) declare `.spec-table` — re-anchor this claim (#926).")
    }
}

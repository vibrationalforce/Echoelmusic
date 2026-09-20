// TheSkipLinkIsVisibleWhenFocusedTests.swift
// Echoel — #1396: the skip link rendered #e0e0e0 on #e0e0e0 — contrast ratio 1.00, invisible —
// on every page of the site that loads `shared.css`, and the homepage's primary call-to-action
// did the same thing.
//
// WHY THIS EXISTS. Measured 2026-09-20 in headless Chromium against the served tree, not read
// off the source: `getComputedStyle(document.querySelector('.skip-link'))` returned
// `color: rgb(224,224,224)` over `background: rgb(224,224,224)`. The skip link is the FIRST
// thing a keyboard or switch-control user reaches on any page; it was unreadable on 20 of them.
// `index.html`'s nav CTA ("Join the TestFlight") was the same defect in the homepage's inline
// copy of the stylesheet: `color: rgba(224,224,224,0.55)` on `rgb(224,224,224)`.
//
// ⭐ THE CAUSE IS CSS SPECIFICITY, AND IT IS INVISIBLE TO READING. Both files carry a generic
// reset, `a, a:visited, a:active, a:link { color: inherit }`. `a:link` is one type plus one
// pseudo-class — specificity (0,1,1). A bare `.skip-link` is (0,1,0) and LOSES, so the rule's
// own `color: #000` never applied. Nothing in the source looks wrong; the rule is right there,
// three lines above. Only a render says which one won.
//
// ⚠️ `:link` IS NOT A REDUNDANT STATE. `:visited` and `:active` were both listed in the broken
// rules; `:link` — the state an ordinary unvisited link is in, i.e. almost every link almost
// always — was the one left out. Every OTHER classed link rule in `shared.css` already carried
// the four-state list. These two were the exceptions, which is why nobody re-read them.
//
// ⚠️ WHAT THIS GUARD DELIBERATELY DOES NOT DO (#364 — a guard must never forbid correct work).
// The tempting general rule is "every link rule that sets `color` must carry `:link`". Measured:
// **eight** further rules in the tree omit it (`.subpage section a:visited`, `.contact-box a`,
// `.faq-answer a`, `.ov-toc a` on two pages, two `artist.html` rules, and `index.html`'s own
// generic reset) and **every one of them is correct** — a descendant chain raises their
// specificity above `a:link` on its own, and the render confirms all of them pass 4.5:1. A
// guard asserting that rule would red eight correct lines on a correct tree. So this file pins
// the two REPAIRED rules and, more usefully, their PREMISES — the conditions that make the
// hazard exist at all. If a premise changes, the message says what to re-read.
//
// KIND (§1): **SOURCE-TEXT SCAN of a rendered finding.** The finding is a render measurement;
// what is pinned here is the source condition that produced it. This guard cannot see contrast —
// no browser runs in CI. It can see the state list, which is what went missing.
//
// GRADING (§3), transcribed in Python against both trees, parent `fbe9a9cde`:
// · Claim 2 (`shared.css` `.skip-link` carries `:link`) — **RED on the parent**, green here.
// · Claim 3 (`index.html` `.nav-cta` carries `:link`) — **RED on the parent**, green here.
// · Claims 1, 4, 5 are COUNTERWEIGHTS (#343), green on both trees, and they are the point: the
//   generic reset still exists (claim 1, the reason `:link` is needed), `index.html`'s reset
//   still omits `a:link` (claim 4, the reason ITS skip link works), and the four cache versions
//   still agree (claim 5, the reason the fix reaches a returning visitor at all).
// · NOT covered: the contrast ratio itself, and every other page element. A device/browser
//   probe is outside CI here.

import XCTest

final class TheSkipLinkIsVisibleWhenFocusedTests: XCTestCase {

    private func text(_ relative: String) -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        guard let s = try? String(contentsOf: dir.appendingPathComponent(relative),
                                  encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return s
    }

    /// The selector group that opens the rule setting `color` for `name`, or nil.
    private func selectorGroup(for name: String, in css: String) -> String? {
        guard let hit = css.range(of: ".\(name)") else { return nil }
        // Walk back to the end of the previous rule (or the start), forward to the brace.
        let before = css[css.startIndex..<hit.lowerBound]
        let start = before.lastIndex(where: { $0 == "}" || $0 == ">" })
            .map { css.index(after: $0) } ?? css.startIndex
        guard let brace = css[hit.lowerBound...].firstIndex(of: "{") else { return nil }
        return String(css[start..<brace])
    }

    // MARK: - Claim 1 — the premise: the generic reset that beats a bare class still exists

    func testSharedCSSStillCarriesTheGenericLinkReset() {
        let css = text("docs/shared.css")
        XCTAssertTrue(css.contains("a:link"), """
            `docs/shared.css` no longer contains a generic `a:link` colour reset.
            That reset is WHY claims 2 and 3 exist: it is specificity (0,1,1) and beats a bare
            class (0,1,0), which is how the skip link ended up invisible. If it is genuinely
            gone, re-measure in a browser before relaxing anything here — and re-read this
            file's header, because its whole argument rests on that rule.
            """)
    }

    // MARK: - Claim 2 — the repair itself, in the shared stylesheet

    func testTheSharedSkipLinkOwnsTheUnvisitedState() {
        let css = text("docs/shared.css")
        guard let group = selectorGroup(for: "skip-link", in: css) else {
            return XCTFail("No `.skip-link` rule in docs/shared.css. The skip link is the first "
                           + "thing a keyboard user reaches; it cannot lose its rule silently.")
        }
        XCTAssertTrue(group.contains(".skip-link:link"), """
            `docs/shared.css`'s `.skip-link` rule no longer lists `:link`:
              \(group.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            Without it the generic `a:link { color: inherit }` wins (claim 1 pins that it still \
            exists) and the link renders #e0e0e0 on #e0e0e0 — contrast 1.00, invisible, on every \
            page that loads this file. Measured in headless Chromium on 2026-09-20. If the \
            generic reset was removed instead, claim 1 is red too and THAT is the thing to read.
            """)
    }

    // MARK: - Claim 3 — the same repair in the homepage's own inline copy

    func testTheHomepageCallToActionOwnsTheUnvisitedState() {
        let html = text("docs/index.html")
        guard let group = selectorGroup(for: "nav-cta,", in: html)
                ?? selectorGroup(for: "nav-cta ", in: html) else {
            return XCTFail("No `.nav-cta` rule found in docs/index.html.")
        }
        XCTAssertTrue(group.contains(".nav-cta:link"), """
            `docs/index.html`'s `.nav-cta` rule no longer lists `:link`:
              \(group.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            `.nav-links a:link` above it is (0,2,1) and this rule is (0,2,0), so the primary \
            call-to-action renders rgba(224,224,224,0.55) on #e0e0e0 — ratio 1.00. \
            `shared.css` carries the four-state list for the same class; this inline copy is \
            the second home docs/CLAUDE.md §6 warns about, and it is the one that goes stale.
            """)
    }

    // MARK: - Claim 4 — why the homepage's OWN skip link is fine, stated instead of assumed

    func testTheHomepageResetStillOmitsTheUnvisitedState() {
        let html = text("docs/index.html")
        let reset = "a, a:visited, a:active { color: inherit;"
        XCTAssertTrue(html.contains(reset), """
            `docs/index.html`'s generic link reset changed. It read `\(reset)…` — note that it \
            omits `a:link`, which is the ONLY reason the homepage's own `.skip-link` rule wins \
            without listing `:link`. If a `:link` was added to that reset, the homepage skip \
            link just went invisible the same way `shared.css`'s did: give `.skip-link` the \
            four-state list there too, in the same commit. This claim is a premise, not a ban — \
            it exists so the change cannot happen silently.
            """)
    }

    // MARK: - Claim 5 — a stylesheet fix that a returning visitor never sees is not a fix

    func testTheCacheVersionsAgreeAcrossEveryPageThatLoadsTheStylesheet() {
        let sw = text("docs/sw.js")
        let versionJSON = text("docs/version.json")

        func firstMatch(_ pattern: String, in s: String) -> String? {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let r = Range(m.range(at: 1), in: s) else { return nil }
            return String(s[r])
        }

        guard let cache = firstMatch(#"CACHE_NAME\s*=\s*'echoelmusic-v([0-9.]+)'"#, in: sw),
              let declared = firstMatch(#""version"\s*:\s*"([0-9.]+)""#, in: versionJSON) else {
            return XCTFail("Could not read sw.js CACHE_NAME or version.json version — "
                           + "re-anchor before trusting this claim (#454).")
        }
        XCTAssertEqual(cache, declared,
            "sw.js CACHE_NAME is v\(cache) but version.json says \(declared).")

        // ⚠️ THE ASSET VERSION IS **NOT** READ FROM `index.html`. The homepage is the one page
        // that does NOT load `shared.css` — it inlines its own CSS (docs/CLAUDE.md §6) — so a
        // needle pointed there returns nothing and the claim would pass vacuously. It nearly
        // shipped that way; the transcription caught it. Scan the DIRECTORY instead, which also
        // catches the drift §4 of that file records (one page on a different `?v=` from the rest).
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let docs = dir.appendingPathComponent("docs")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? []
        var seen: [String: String] = [:]
        for file in names.filter({ $0.hasSuffix(".html") }).sorted() {
            guard let body = try? String(contentsOf: docs.appendingPathComponent(file),
                                         encoding: .utf8) else { continue }
            if let v = firstMatch(#"shared\.css\?v=([0-9.]+)"#, in: body) { seen[file] = v }
        }
        XCTAssertGreaterThan(seen.count, 10,
            "Only \(seen.count) page(s) load shared.css with a version query — this claim is "
            + "measuring almost nothing; re-anchor it.")
        let disagreeing = seen.filter { $0.value != declared }
        XCTAssertTrue(disagreeing.isEmpty, """
            \(disagreeing.count) page(s) cache-bust shared.css at a version that is not \
            \(declared): \(disagreeing.sorted(by: { $0.key < $1.key }).prefix(4).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")).
            This is not cosmetic: the service worker caches by CACHE_NAME and the pages \
            cache-bust by the query. A stylesheet repair that moves neither is invisible to \
            every returning visitor — which is exactly what happened while measuring #1396: \
            the fixed CSS sat on disk and the browser kept serving the broken one until the \
            service worker was bypassed. Move all of them together, or the fix does not ship.
            """)
    }
}

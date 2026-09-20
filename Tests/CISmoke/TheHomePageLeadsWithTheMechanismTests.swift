// TheHomePageLeadsWithTheMechanismTests.swift
// Echoel — #1238 (audit 2026-09-10 `docs-claims-2/3/5/7`, marketing action "Stale-Copy"). The two
// acquisition pages sell the mechanism, the shipped surfaces, and fit a search snippet.
//
// THE DEFECTS, measured on the parent (`94c6109`). (a) The first bolded sentence of `index.html`
// and the lead of `overview.html` read "compose music to calm down and observe yourself" — an
// EFFECT promise, the exact line `ContentPipeline/CLAIMS.md` §2 draws ("Erlaubt: ruhiger Puls →
// andere Musik. Nicht erlaubt: macht Dich ruhig"), on the page a journalist quotes. (b) The
// touch-playable picture (`TouchInstrumentView`, CLAIMS ✅) was sold only on `faq.html`
// (`grep -c -iE 'playable|fingers' docs/index.html docs/overview.html` → 0 0); the external-
// display stage (`ExternalDisplayScene`, CLAIMS ✅) only on `tools.html`/`overview.html`, never on
// the home page. (c) The home page's Specs tile listed "OSC · ADM-OSC · Art-Net" while the same
// page claims sACN ten times and MPE note output. (d) `index.html`'s meta description was 497
// characters (search engines cut at ~155) and led with what is absent ("live broadcast is not
// planned"); `overview.html`'s was 200.
//
// WHAT THIS PINS, all by text on the two pages. (1) No effect promise: neither page contains
// "calm down". (2) The home page's visual card sells the playable picture AND the connected-
// screen stage in the CLAIMS wording; (3) `overview.html`'s EchoelVis row sells the playable
// picture. (4) The Specs tile names all five open standards. (5) Both meta descriptions are
// ≤ 160 characters and contain no "not planned".
//
// COUNTERWEIGHT (claim 6): the playable claim is only true while its mount exists — same shape as
// `ThePictureIsSoldAsPlayableTests.testTheClaimStillHasItsMount`, restated here so the two new
// pages go red with the FAQ if `TouchInstrumentView(` is ever unmounted.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`94c6109`) and this tree: claims 1–5
// RED on the parent, GREEN here; claim 6 GREEN on both.

import Foundation
import XCTest

final class TheHomePageLeadsWithTheMechanismTests: XCTestCase {

    /// Claim 1 — no effect promise on either acquisition page.
    func testNeitherPagePromisesToCalmYouDown() throws {
        for page in ["docs/index.html", "docs/overview.html"] {
            let html = try text(page).lowercased()
            XCTAssertFalse(html.contains("calm down"),
                           "\(page) promises an effect (\"calm down\") again — CLAIMS.md §2 allows the mechanism (a settling pulse changes the music), never the outcome (#1238)")
        }
    }

    /// Claim 2 — the home page's visual card sells the playable picture and the connected-screen stage.
    func testTheHomePageSellsThePlayablePictureAndTheStage() throws {
        let html = try text("docs/index.html")
        guard let card = html.range(of: "<h3>Living visuals</h3>") else {
            return XCTFail("the \"Living visuals\" card is gone from docs/index.html — move these needles to wherever the visual is sold now (#1238)")
        }
        let window = String(html[card.upperBound...].prefix(900))
        XCTAssertTrue(window.contains("touch the visual and your fingers become notes"),
                      "the home page no longer sells the playable picture in the CLAIMS wording (#1238; the FAQ sentence is the template)")
        XCTAssertTrue(window.contains("AirPlay") && window.contains("its own stage"),
                      "the home page no longer sells the connected-screen stage (`ExternalDisplayScene`, CLAIMS ✅) (#1238)")
    }

    /// Claim 3 — the overview's EchoelVis row sells the playable picture.
    func testTheOverviewSellsThePlayablePicture() throws {
        let html = try text("docs/overview.html")
        guard let row = html.range(of: "<h4>EchoelVis</h4>") else {
            return XCTFail("the EchoelVis row is gone from docs/overview.html (#1238)")
        }
        XCTAssertTrue(String(html[row.upperBound...].prefix(700)).contains("your fingers become notes"),
                      "overview.html's EchoelVis row no longer says the picture is playable (#1238)")
    }

    /// Claim 4 — the Specs tile names every shipped open standard.
    func testTheSpecsTileNamesAllFiveStandards() throws {
        let html = try text("docs/index.html")
        XCTAssertTrue(html.contains("<div class=\"spec-label\">OSC &middot; ADM-OSC &middot; MIDI &middot; Art-Net &middot; sACN</div>"),
                      "the Specs tile dropped a shipped standard again — sACN is live (`Sync/SACNSender`) and MIDI is sold on the same page (#1238)")
    }

    /// Claim 5 — every page's meta description fits a snippet and leads with what ships.
    ///
    /// ⛔ #1392 — THIS CLAIM CHECKED TWO PAGES AND THE SITE HAS MANY. #1238 measured
    /// `index.html` at 497 characters, repaired it and `overview.html`, and pinned exactly the
    /// two files it had looked at. A scan whose SCOPE is a hand-written list of what was
    /// examined that day cannot find the next instance (the §AB/#1379 lesson, here on the
    /// website side): six further pages sat between 164 and 261 characters for weeks, each one
    /// a search result cut mid-sentence, and no assertion could see them. The list is now the
    /// DIRECTORY, so a page added tomorrow is covered without anyone remembering this file.
    ///
    /// ⚠️ ONE FILE IS EXEMPT BY NAME, and the exemption is narrow on purpose:
    /// `og-image.html` is a 1200×630 RENDER TARGET for the social card, never served to a
    /// reader and not in the sitemap, so it has no snippet to fit. Every OTHER page missing a
    /// description is a finding — the exemption is a literal, so the day a second descriptionless
    /// page appears, this goes red rather than quietly widening.
    func testTheMetaDescriptionsFitASnippetAndLeadWithWhatShips() throws {
        let docs = repoRoot().appendingPathComponent("docs")
        let pages = ((try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [])
            .filter { $0.hasSuffix(".html") }
            .sorted()
        XCTAssertGreaterThan(pages.count, 2,
                             "ANCHOR MISSING: fewer than three pages under `docs/` — the "
                             + "directory listing failed, and an empty scope is a finding, "
                             + "never a pass (#454).")
        for file in pages {
            let page = "docs/" + file
            let html = try text(page)
            guard let start = html.range(of: "<meta name=\"description\" content=\""),
                  let end = html[start.upperBound...].range(of: "\"") else {
                if file == "og-image.html" { continue }
                XCTFail("\(page) has no meta description (#1238/#1392) — a page with no snippet "
                        + "lets the search engine invent one out of the first text it finds.")
                continue
            }
            let description = String(html[start.upperBound..<end.lowerBound])
            XCTAssertLessThanOrEqual(description.count, 160,
                                     "\(page)'s meta description is \(description.count) characters — search engines cut at ~155; the parent's was 497 (#1238)")
            XCTAssertFalse(description.contains("not planned"),
                           "\(page)'s snippet leads with what is absent again (#1238)")
        }
    }

    /// Claim 6 — counterweight: the playable claim still has its mount.
    func testThePlayableClaimStillHasItsMount() throws {
        let window = try text("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        XCTAssertTrue(window.contains("TouchInstrumentView("),
                      "`TouchInstrumentView` is no longer mounted — pull the playable sentences from index.html, overview.html and the FAQ in the same commit (#1238, #456)")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}

// TheSiteDoesNotSellADeletedFullscreenTests.swift
// Echoel — #1332. The published site advertised an in-app FULLSCREEN visual door that #1069
// deleted, and told the reader that live streaming "was built and removed in July 2026" — a
// sentence wrong in three ways at once.
//
// ⭐ THE FULLSCREEN HALF. `showVisual` drove a `.fullScreenCover` and went with #1069; the
// floating window is the only in-app mount left (`git grep -n showVisual -- Sources` finds one
// tombstone). Five places on the site still offered "movable window or fullscreen", twice in
// the JSON-LD that Google reads and three times in visible copy. ⚠️ The repair is NOT a
// deletion: `ExternalDisplayScene` is real and live, so a full-screen picture on a connected
// display (EchoelStage) genuinely ships. The claim was in the wrong PLACE, not simply false —
// the copy now says which surface it happens on.
//
// ⭐ THE HISTORY HALF, and it is the more expensive kind. One visible sentence said video
// editing, multitrack recording and live streaming "were built and removed in July 2026".
// Three different histories were flattened into one date, and two of the three were wrong:
// multitrack recording went in SEPTEMBER 2026 with the audio input (#1302), and live streaming
// was NEVER BUILT — `BroadcastPublisher` is a `#if canImport(HaishinKit)` scaffold and
// `Package.swift` has an empty `dependencies` array. The same page already said the video
// dates correctly three answers further down, so the site contradicted itself. Claiming a
// capability was "built" is the direction that costs a 2.3 rejection when it is a claim
// (#184) and costs trust when it is a boast about deletion.
//
// ⚠️ SCOPE, and the trap `docs/CLAUDE.md` §5 names. A grep hit for "RTMP" or "AUv3" in `docs/`
// is almost always a DENIAL that two whole cycles paid for (#158/#192). Claim 3 exists to keep
// those denials in place, so this guard can never be satisfied by deleting the corrections.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **8 assertions across four claims**
// (claim 1 = 2, claim 2 = 2, claim 3 = 2, claim 4 = 2), transcribed in Python and driven
// against BOTH trees. On the parent (`c983830`) **5 are red** and they are THREE findings
// (#486): the fullscreen offer (claim 1, one assertion naming `faq.html` and `index.html`),
// the flattened history sentence (claim 2, two assertions — the false one present AND the
// corrected one absent), and support.html sending the reader to a screen that does not exist
// (claim 4, two assertions). ⛔ A draft of this paragraph said FOUR and also pinned the RTMP
// denial in `faq.html`; measured, faq.html did not carry that phrase before this commit — the
// pin would have been this slice watching its OWN sentence and booking a forward guard as a
// regression (#433/#464). It is pinned in `tools.html`, which carried it on the parent.
// The genuine COUNTERWEIGHTS (#343) are claim 1's page count, claim 3's two denials and
// claim 2's needles read on both sides — green on both trees.
// FILE-CONTENT SCAN (§1): it proves what the site SAYS. Whether a page renders, and whether
// the external display actually shows the picture, are device probes and stay open.

import Foundation
import XCTest

final class TheSiteDoesNotSellADeletedFullscreenTests: XCTestCase {

    /// Claim 1 — no page offers the in-app fullscreen door. The needle is the OFFER
    /// ("or fullscreen"), not the word: "full-screen on a connected display" is true and must
    /// stay, and `architecture.html`'s "renders a full-screen pulse" describes the renderer
    /// filling its host, which is also true.
    func testNoPageOffersTheInAppFullscreen() throws {
        let pages = try Self.htmlPages()
        XCTAssertGreaterThan(pages.count, 10,
                             "ANCHOR MISSING: read \(pages.count) pages under docs/ — too few "
                             + "for this absence to mean anything (#454/#926).")
        let offenders = pages.filter { $0.value.contains("or fullscreen") }.keys.sorted()
        XCTAssertEqual(
            offenders, [],
            "\(offenders) still offer the visual \"or fullscreen\". The in-app full-screen "
            + "cover was `showVisual` and #1069 deleted it; the floating window is the only "
            + "mount on the phone. If a full-screen door is built again this guard reports it "
            + "(#364) — it does not forbid it. What ships today and must stay in the copy is "
            + "the EXTERNAL display (`ExternalDisplayScene`, EchoelStage).")
    }

    /// Claim 2 — the three cut capabilities keep their three different histories.
    func testTheThreeCutHistoriesAreNotFlattened() throws {
        let faq = try Self.text("docs/faq.html")
        XCTAssertFalse(
            faq.contains("live streaming are <strong>not planned</strong> &mdash; they were built and removed"),
            "faq.html says live streaming was built and removed. It was NEVER built: "
            + "`BroadcastPublisher` is a `#if canImport(HaishinKit)` scaffold and "
            + "`Package.swift` carries an empty `dependencies` array. The same page states the "
            + "video dates correctly three answers below, so this sentence also contradicts "
            + "its own page.")
        XCTAssertTrue(
            faq.contains("live streaming was <strong>never built</strong>"),
            "the corrected sentence is gone. Three capabilities, three histories: the video "
            + "editor July 2026, video recording September 2026, multitrack September 2026 "
            + "with the audio input — and streaming never at all.")
    }

    /// Claim 3 — counterweight, and the one `docs/CLAUDE.md` §5 exists for: the site's RTMP
    /// and video DENIALS stay. Two cycles (#158/#192) paid for them; claim 1 and 2 must never
    /// be satisfiable by deleting the corrections instead of the claims.
    func testTheDenialsSurvive() throws {
        XCTAssertTrue(try Self.text("docs/architecture.html").contains("compile-guarded scaffold"),
                      "architecture.html no longer explains that the broadcast publisher is a "
                      + "compile-guarded scaffold. That sentence IS the correction — removing "
                      + "it reopens the claim it retracts (docs/CLAUDE.md §5).")
        XCTAssertTrue(try Self.text("docs/tools.html").contains("compile-guarded scaffold"),
                      "tools.html no longer carries the RTMP denial (docs/CLAUDE.md §5). It is "
                      + "pinned HERE rather than in faq.html on purpose: faq.html's copy of that "
                      + "phrase is written by THIS commit, so pinning it there would be a guard "
                      + "watching its own slice instead of the work two earlier cycles paid for.")
    }

    /// Claim 4 — support.html sends the reader to a control that exists. Before #1331 there
    /// was none at all; the page named an "Audio Settings" screen this app has never had.
    func testSupportPointsAtTheRealLatencyControl() throws {
        let support = try Self.text("docs/support.html")
        XCTAssertTrue(
            support.contains("<strong>Audio latency</strong>"),
            "support.html no longer names the `Audio latency` row in the Master panel. That "
            + "control was restored by #1331; before it, the page's advice could not be "
            + "followed at all.")
        XCTAssertFalse(
            support.contains("Reduce buffer size in Audio Settings"),
            "support.html still sends the reader to an \"Audio Settings\" screen. No such "
            + "screen exists — the tier lives in Master → Audio latency.")
    }

    // MARK: - helpers

    private static func htmlPages() throws -> [String: String] {
        let docs = repoRoot().appendingPathComponent("docs")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: docs.path) else {
            return [:]
        }
        var pages: [String: String] = [:]
        for name in names where name.hasSuffix(".html") {
            if let body = try? String(contentsOf: docs.appendingPathComponent(name),
                                      encoding: .utf8) {
                pages[name] = body
            }
        }
        return pages
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}

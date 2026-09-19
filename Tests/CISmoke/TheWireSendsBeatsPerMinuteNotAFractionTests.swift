// TheWireSendsBeatsPerMinuteNotAFractionTests.swift
// Echoel — #1373. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// what the sender's code says and what the published page says, never that a datagram left.
//
// ⭐ WHY THIS FILE EXISTS. `docs/resolume-osc.html` ships in this commit, and its whole reason
// to exist is one warning a reader cannot get anywhere else: a Resolume parameter runs 0…1,
// `/echoelmusic/bio/heart/bpm` carries **beats per minute**, and a parameter bound straight to
// it pins at maximum on the first datagram and stays there. That warning is only true while the
// sender keeps writing `frame.heartRateBPM` unscaled. Nothing connected the two — the address
// COUNT is pinned (`WebsitePagesAreFindableAndHonestTests.testTheSiteCountsTheAddressesThe…`),
// the address RANGES are pinned nowhere, and `docs/integrations.html` states the same 40–200 in
// its own table.
//
// ⚠️ THIS IS NOT "BPM SHOULD BE NORMALIZED" AND MUST NOT BE READ AS A BAN (#364). Adding a
// normalized twin, or rescaling this address, is legitimate work — `hrv` is normalized at
// exactly this layer and claim 2 pins that as the precedent. What the guard buys is the day it
// happens: claim 1 goes red BY DESIGN and its message names the two published surfaces that
// have to move in the same commit. A guard that forbade the change would be deleted, and the
// law would go with it.
//
// ⛔ AND IT IS NOT A ROSTER OF SPOKE PAGES. The obvious second guard — "the hub links Reaper,
// TouchDesigner and Resolume" — would be roster-shaped, and a roster-shaped guard goes blind
// exactly as its roster ages: a fourth spoke added next month leaves it green while the hub
// forgets to link it. `testNoPageIsAnOrphan` already answers linkage GENERALLY, for every page
// that will ever exist. Claim 4 pins only the narrower fact this slice depends on — that the
// page carrying the warning is reachable at all — and says so in its message.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Ten assertions across four claims**,
// stated rather than counted from the file's shape. Every needle was re-derived by `grep` on
// today's tree before it was written down: the nine `msgs.append(("/echoelmusic/bio/` lines in
// `OSCSender.swift`, and the four page-local needles. Transcribed into Python and driven against
// this tree (GREEN) and against SIX mutants — bpm divided by 200, the page's warning deleted,
// the hub link removed, the `hrv` precedent rewritten, a bpm row added to the "map straight"
// table, and the table's anchor renamed — each of which turned the intended claim RED. The last
// two were added after the first four passed: writing them is what replaced claim 3's original
// needle ("bind heart rate to", a phrase no editor would type) with the table anchor. A mutant
// nobody can imagine writing is not a mutant. **0 regression catches, 10 COUNTERWEIGHTS (#343)**: correct, because this slice publishes
// a page rather than repairing code, and booking them as catches would be the flattering
// direction (#433/#464).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWireSendsBeatsPerMinuteNotAFractionTests: XCTestCase {

    private static let senderFile = "Sources/Echoelmusic/Sync/OSCSender.swift"
    private static let spokePage = "docs/resolume-osc.html"
    private static let hubPage = "docs/integrations.html"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ rel: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(rel), encoding: .utf8)
    }

    /// Comment-stripped, because this repo argues about its own addresses in prose. `OSCSender`'s
    /// header alone names `/echoelmusic/bio/heart/bpm` twice inside ⛔ blocks, so a raw scan would
    /// read a retraction as a send site — the #453/#1050 shape.
    private func senderCode() throws -> String {
        SourceText.codeOnly(try text(Self.senderFile))
    }

    // MARK: - Claim 1 — the sender writes the rate, not a fraction of one

    func testTheWireSendsBeatsPerMinuteNotAFraction() throws {
        let code = try senderCode()
        XCTAssertTrue(code.contains("msgs.append((\"/echoelmusic/bio/heart/bpm\", [frame.heartRateBPM]))"), """
            `/echoelmusic/bio/heart/bpm` no longer goes out as the bare `frame.heartRateBPM`. \
            That is legitimate work and this guard does not forbid it (#364) — but TWO published \
            surfaces state the old range as an integration contract and must move in the SAME \
            commit: `\(Self.spokePage)` (the "Heart rate is the exception" paragraph, which is \
            the page's entire reason to exist) and `\(Self.hubPage)` (the OSC address table's \
            Range column). A reader binds a fader to this number; leaving either behind ships a \
            mapping that silently pins.
            """)
        // The mirror half: nothing between the address and the field. If a scale appears, the
        // literal above stops matching — this asserts the SAME fact from the other side so a
        // reformatting that keeps the literal but adds a factor cannot pass both.
        XCTAssertFalse(code.contains("/echoelmusic/bio/heart/bpm\", [frame.heartRateBPM /"), """
            The bpm send divides `frame.heartRateBPM`. See the message above: the page and the \
            hub table both state 40–200 and are now wrong.
            """)
    }

    // MARK: - Claim 2 — the counterweight that makes claim 1 mean something

    /// Without this, claim 1 reads as "Echoel cannot normalize", which is false and is exactly
    /// the over-reach a negative claim invites (#367). Normalization at this layer is routine —
    /// `hrv` is normalized, and the page recommends the three 0…1 channels BECAUSE they are.
    func testTheZeroToOneChannelsAreNormalizedAtThisSameLayer() throws {
        let code = try senderCode()
        for line in ["msgs.append((\"/echoelmusic/bio/heart/hrv\", [frame.hrvNormalized]))",
                     "msgs.append((\"/echoelmusic/bio/breath/phase\", [frame.breathPhase]))",
                     "msgs.append((\"/echoelmusic/bio/coherence\", [frame.coherence]))"] {
            XCTAssertTrue(code.contains(line), """
                `OSCSender` no longer sends `\(line)`. `\(Self.spokePage)` recommends exactly \
                these three as the channels that map straight to a Resolume parameter; if one \
                changed shape, that recommendation is now wrong and the page moves with it.
                """)
        }
    }

    // MARK: - Claim 3 — the warning is actually on the page

    /// A page can lose its point and still render, pass every metadata check and stay in the
    /// sitemap. The three needles are the substance, not the wording: the address, the unit, and
    /// the consequence a reader needs BEFORE spending an evening on the mapping.
    func testTheSpokePageCarriesTheRangeWarning() throws {
        let page = try text(Self.spokePage).lowercased()
        for needle in ["/echoelmusic/bio/heart/bpm", "beats per minute", "pins at the top"] {
            XCTAssertTrue(page.contains(needle), """
                `\(Self.spokePage)` no longer contains "\(needle)". The range trap is the one \
                thing this page knows that the hub table does not spell out; without it the page \
                is a duplicate of three lines already on `\(Self.hubPage)`.
                """)
        }
        // #425 — the page must not also list bpm among the channels it calls safe. The anchor is
        // the page's ONE `spec-table` (#408: measured, there is exactly one), whose heading is
        // "Which channels map straight". A first draft used the needle "bind heart rate to",
        // which no careless editor would ever type — a tripwire that cannot trip. This one can:
        // adding a bpm row to that table is the obvious, plausible edit, and it would silently
        // contradict the paragraph directly beneath it.
        let raw = try text(Self.spokePage)
        guard let open = raw.range(of: "<table class=\"spec-table\">"),
              let close = raw.range(of: "</table>", range: open.upperBound..<raw.endIndex) else {
            return XCTFail("""
                `\(Self.spokePage)` has no `spec-table`, so this claim checked nothing — it FAILS \
                rather than passing vacuously (#454). If the channel table moved, re-anchor here \
                in the same commit.
                """)
        }
        let table = String(raw[open.upperBound..<close.lowerBound])
        XCTAssertFalse(table.contains("/echoelmusic/bio/heart/bpm"), """
            `\(Self.spokePage)` lists `/echoelmusic/bio/heart/bpm` in the table of channels that \
            map straight to a 0…1 parameter, while the paragraph below it explains that this one \
            does not. A slice must not contain a claim and its own refutation (#425).
            """)
    }

    // MARK: - Claim 4 — the page is reachable from the hub

    /// Deliberately NOT a roster of spokes (see the header). This asserts only that the page
    /// carrying claim 3's warning can be reached from the page a reader actually lands on.
    func testTheHubLinksTheSpokeThatCarriesTheWarning() throws {
        let hub = try text(Self.hubPage)
        XCTAssertTrue(hub.contains("\"resolume-osc.html\""), """
            `\(Self.hubPage)` no longer links `\(Self.spokePage)`. `testNoPageIsAnOrphan` would \
            still pass on a link from anywhere — the FAQ links it too — but the integrations hub \
            is where someone wiring Resolume is standing, and the range warning is worth nothing \
            to a reader who never arrives.
            """)
    }
}

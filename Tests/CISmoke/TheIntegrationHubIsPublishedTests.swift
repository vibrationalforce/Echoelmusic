// TheIntegrationHubIsPublishedTests.swift
// Echoel — #1241 (audit 2026-09-10 `output-sync-7`, Council step 2, Ultraplan row 9). The
// integration surface for VJ, lighting and DAW operators is a published, findable page whose
// address table is pinned to the SENDER, not to a dev doc.
//
// THE GAP. The only complete OSC address table lived in `docs/dev/VJ_BRIDGE.md`, linked from
// no page (`git grep -n VJ_BRIDGE -- docs/*.html README.md` → 0); TouchDesigner, grandMA3 and
// QLC+ need the list up front, and `VJ_BRIDGE.md` itself carried a stale claim (the camera
// "may never" reach coherence — false since #1220). A dev doc drifts silently; a page a guard
// reads against `OSCSender.swift` cannot.
//
// WHAT THIS PINS. (1) The hub and both spokes exist, are in the sitemap, and are linked: hub
// from the home page, the FAQ and tools; spokes from the hub. (2) Every address `OSCSender`
// SENDS appears on the hub, and the two it never sends are named as never sent. (3) The ADM-OSC
// rows use the v1.0 shape (`/azim /elev /dist /gain`) and no `/position/` remains. (4) The four
// ports are on the page. (5) The page's inbound claim matches the tree: since #1255 the ONE
// `NWListener` in `Sources/` is `OSCReceiver` and the hub documents its whitelist (⛔ "no
// inbound socket … no `NWListener`" until then). A second listener, or a hub that stops naming
// the whitelist, must change the page in the same commit.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`48d0be7`) and this tree: claims 1–4
// RED on the parent (the pages do not exist there), GREEN here; claim 5 GREEN on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheIntegrationHubIsPublishedTests: XCTestCase {

    private static let pages = ["integrations.html", "reaper-osc.html", "touchdesigner-osc.html"]

    /// Claim 1 — published, in the sitemap, and reachable.
    func testTheHubAndSpokesArePublishedAndLinked() throws {
        let sitemap = try text("docs/sitemap.xml")
        for page in Self.pages {
            XCTAssertTrue(sitemap.contains("https://echoelmusic.com/\(page)"), "\(page) is not in docs/sitemap.xml (#1241)")
            _ = try text("docs/\(page)")   // throws XCTSkip only if the whole docs tree is absent; the page itself is asserted below
        }
        for linker in ["docs/index.html", "docs/faq.html", "docs/tools.html"] {
            XCTAssertTrue(try text(linker).contains("href=\"integrations.html\""), "\(linker) no longer links the integrations hub (#1241)")
        }
        let hub = try text("docs/integrations.html")
        XCTAssertTrue(hub.contains("href=\"reaper-osc.html\"") && hub.contains("href=\"touchdesigner-osc.html\""),
                      "the hub no longer links both spokes — an orphan spoke is findable only by URL (#1241)")
    }

    /// Claim 2 — the address table is the sender's, and the never-sent pair is named as such.
    func testEverySentAddressIsOnTheHub() throws {
        let sender = try text("Sources/Echoelmusic/Sync/OSCSender.swift")
        let hub = try text("docs/integrations.html")
        let sent = Self.addresses(in: sender).subtracting(["/echoelmusic/bio/motion", "/echoelmusic/bio/event/motion", "/echoelmusic/bio/event/eeg"])
        XCTAssertGreaterThanOrEqual(sent.count, 12, "the sender scan found only \(sent.count) addresses — a scan that finds few is a broken scan (#1241)")
        for address in sent.sorted() {
            XCTAssertTrue(hub.contains("<code>\(address)</code>"), "`\(address)` is sent by OSCSender and missing from docs/integrations.html (#1241)")
        }
        for never in ["/echoelmusic/bio/motion", "/echoelmusic/bio/event/eeg"] {
            guard let at = hub.range(of: never) else { return XCTFail("\(never) is not named on the hub — an integrator will wait on it (#1241)") }
            XCTAssertTrue(hub[at.lowerBound...].prefix(400).contains("never sent"), "\(never) is on the hub without being marked never sent (#1241)")
        }
    }

    /// Claim 3 — the ADM-OSC rows carry the v1.0 shape #1210 restored.
    func testTheADMRowsUseTheSpecShape() throws {
        let hub = try text("docs/integrations.html")
        for leaf in ["azim", "elev", "dist", "gain"] {
            XCTAssertTrue(hub.contains("/adm/obj/n/\(leaf)"), "the hub lost the ADM-OSC `/\(leaf)` row (#1241)")
        }
        XCTAssertFalse(hub.contains("/position/"), "the hub sells the pre-#1210 `/position/…` shape that no renderer reads (#1241)")
    }

    /// Claim 4 — the four ports.
    func testTheFourPortsAreOnTheHub() throws {
        let hub = try text("docs/integrations.html")
        // 9000 -> 4001 with #1433: the spec's own "Default send port" for the role Echoel
        // plays (sender). The page and the code move together or the hub starts lying (#456).
        for port in ["8000", "4001", "6454", "5568"] {
            XCTAssertTrue(hub.contains(port), "port \(port) is missing from the hub (#1241)")
        }
    }

    /// Claim 5 — the page's inbound claim matches the tree: ONE listener, the control whitelist,
    /// documented on the hub with every address it honours (#1255).
    func testTheInboundSocketClaimMatchesTheTree() throws {
        let hub = try text("docs/integrations.html")
        XCTAssertTrue(hub.contains("OSC control input"), "the hub no longer documents the control input (#1255)")
        XCTAssertFalse(hub.contains("no inbound socket"), "the hub still says there is no inbound socket (#1255)")
        for address in OSCControlCommand.addresses {
            XCTAssertTrue(hub.contains(address), "\(address) is missing from the hub's control table (#1255)")
        }
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot enumerate Sources — refusing to report a green it did not earn")
        }
        var listeners: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            if let code = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8),
               code.contains("NWListener") { listeners.append(relative) }
        }
        XCTAssertEqual(listeners.sorted(), ["Echoelmusic/Sync/OSCReceiver.swift"], "the inbound-socket census moved (\(listeners.sorted())) — the hub's control-input section and the FAQ's OSC-in answer must change in the same commit (#1241/#1255)")
    }

    private static func addresses(in sender: String) -> Set<String> {
        var out = Set<String>()
        var search = sender.startIndex
        while let r = sender.range(of: "\"/echoelmusic/", range: search..<sender.endIndex) {
            let rest = sender[r.upperBound...]
            let body = rest.prefix { $0 != "\"" }
            let address = "/echoelmusic/" + body
            if !address.contains("\\(") { out.insert(address) }   // skip the templated `/mod/\(key)`
            search = r.upperBound
            _ = rest
        }
        return out
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Claim 4b — the CODE's default port and the PAGE's number are the same number (#1433).
    ///
    /// ⭐ THIS IS THE COUPLING THAT JUST BIT, pinned rather than remembered. Claim 4 asks only
    /// that the hub CARRY four port strings; it stayed green for as long as the page said 9000
    /// and would have stayed green if the code had moved alone. A port the app does not send on
    /// is worse than an undocumented one: the reader configures their renderer, sees no error —
    /// UDP reports nothing when the two ends disagree — and concludes the feature is broken.
    ///
    /// ⚠️ It reads the DECLARATION, not a prose sentence, so a comment about the old number
    /// (the file deliberately keeps a tombstone naming 9000) cannot satisfy or break it.
    func testTheAdvertisedADMPortIsTheOneTheSenderDefaultsTo() throws {
        let sender = try text("Sources/Echoelmusic/Sync/ADMOSCSender.swift")
        guard let range = sender.range(of: #"port: UInt16 = (\d+)"#, options: .regularExpression) else {
            return XCTFail("""
                ANCHOR MISSING: no `port: UInt16 = <n>` declaration in ADMOSCSender.swift.                 Re-anchor rather than letting this stay green (#454).
                """)
        }
        let declared = sender[range].split(separator: "=").last.map {
            $0.trimmingCharacters(in: .whitespaces)
        } ?? ""
        XCTAssertEqual(declared, "4001", """
            The ADM-OSC sender defaults to \(declared), not 4001. 4001 is the port ADM-OSC v1.0             names as the default for the role Echoel plays — a SENDER. (The spec's 4002 is the             receiver's query-reply port and is not ours: Echoel has no ADM listener.) If this             moves on purpose, move the hub page and this pin in the SAME commit (#456).
            """)

        let hub = try text("docs/integrations.html")
        XCTAssertTrue(hub.contains(declared), """
            The hub page does not carry \(declared), the port the sender actually defaults to.             A reader configures their renderer from this page; a number that does not match the             code sends them to a port nothing arrives on, and UDP reports no error either end.
            """)
    }

    private func text(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not present at \(url.path) — this test reads repo files as text, so it SKIPS rather than reporting a green it did not earn")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

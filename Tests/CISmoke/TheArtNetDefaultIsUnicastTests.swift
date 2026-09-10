// TheArtNetDefaultIsUnicastTests.swift
// Echoel — #1219 (audit 2026-09-10 `output-sync-2`). Art-Net no longer defaults to a
// broadcast address iOS will not deliver, and the OS's refusal reaches the patchbay.
//
// THE RISK. `ArtNetSender.init` defaulted to limited broadcast 255.255.255.255. iOS gates
// broadcast/multicast sends behind `com.apple.developer.networking.multicast`, which this app
// does not hold — so an operator who switched the Art-Net route on without typing a node IP
// saw the patchbay dot read "sending" (the datagram WAS handed to the OS) while nothing could
// reach the rig. The sACN sender next to it had always defaulted to unicast 192.168.1.100 and
// the website said "broadcast by default" as if it worked.
//
// WHAT THIS PINS. (1) The Art-Net default host equals the sACN default — ONE unicast literal
// for both light outputs (read after clearing the persisted keys, because `init` prefers a
// stored host). (2) The OS's word reaches the operator: `lastError` exists, `connect()`
// installs a `stateUpdateHandler`, `send()` reads its completion error, and `PatchbayView`
// renders `artNet.lastError`. (3) COUNTERWEIGHT — a typed broadcast literal is still accepted
// by `connect()` (`allowLocalEndpointReuse`, no literal is refused), and the website no longer
// says "broadcast by default".
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`f5f7fcb`) and this tree: claim 1
// RED on the parent (255.255.255.255 ≠ 192.168.1.100), GREEN here; claim 2 RED on the parent
// (no `lastError`), GREEN here; claim 3's website half RED on the parent, GREEN here; the
// sACN half green on both. NEEDS-FOUNDER-VERIFY (Wireshark on the LAN, route on, default host):
// packets to 192.168.1.100:6454 — and the entitlement half is Apple's published wording, not
// re-measured here (the sandbox cannot fetch the entitlement page).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArtNetDefaultIsUnicastTests: XCTestCase {

    /// Claim 1 — one unicast default for both light outputs.
    @MainActor
    func testTheArtNetDefaultHostIsTheSACNDefault() {
        let d = UserDefaults.standard
        let savedArt = d.string(forKey: "net.artnet.host"), savedSacn = d.string(forKey: "net.sacn.host")
        d.removeObject(forKey: "net.artnet.host"); d.removeObject(forKey: "net.sacn.host")
        defer {
            if let savedArt { d.set(savedArt, forKey: "net.artnet.host") }
            if let savedSacn { d.set(savedSacn, forKey: "net.sacn.host") }
        }
        let art = ArtNetSender(), sacn = SACNSender()
        XCTAssertEqual(art.host, ArtNetSender.defaultHost)
        XCTAssertEqual(art.host, sacn.host, "the two light outputs default to two different hosts again (#1219)")
        XCTAssertFalse(art.host.hasSuffix(".255"), "Art-Net defaults to a broadcast address iOS will not deliver without the multicast entitlement (#1219)")
    }

    /// Claim 2 — the OS's refusal reaches the operator.
    func testTheOSRefusalReachesThePatchbay() throws {
        let sender = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/ArtNetSender.swift"))
        XCTAssertTrue(sender.contains("public private(set) var lastError: String?"), "ArtNetSender.lastError left (#1219)")
        XCTAssertTrue(sender.contains("conn.stateUpdateHandler = {"), "connect() no longer installs a stateUpdateHandler (#1219)")
        XCTAssertTrue(sender.contains("case .failed(let error):") && sender.contains("case .waiting(let error):"),
                      "the state handler no longer surfaces .failed/.waiting (#1219)")
        XCTAssertTrue(sender.contains("if let error { self.lastError = "), "send() discards its completion error again (#1219)")
        let patchbay = SourceText.codeOnly(try text("Sources/Echoelmusic/Studio/PatchbayView.swift"))
        XCTAssertTrue(patchbay.contains("if let artNetError = artNet.lastError {"), "PatchbayView no longer shows artNet.lastError (#1219)")
    }

    /// Claim 3 — counterweights: a typed broadcast literal is still allowed; the website is honest.
    func testATypedBroadcastStillConnectsAndTheWebsiteIsHonest() throws {
        let sender = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/ArtNetSender.swift"))
        XCTAssertTrue(sender.contains("params.allowLocalEndpointReuse = true"), "connect() changed shape — re-read #1219 before refusing any literal")
        XCTAssertFalse(sender.contains("guard host != \"255.255.255.255\""), "a typed broadcast literal is refused — that is the operator's call, not ours (#1219)")
        let page = try text("docs/artnet-sacn-from-a-phone.html")
        XCTAssertFalse(page.contains("broadcast by default"), "the website sells a broadcast default the app cannot deliver (#1219)")
        XCTAssertFalse(page.contains("Art-Net broadcasts on UDP 6454"), "the meta description still says Art-Net broadcasts (#1219)")
        XCTAssertTrue(page.contains("unicast to the node IP you enter"))
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

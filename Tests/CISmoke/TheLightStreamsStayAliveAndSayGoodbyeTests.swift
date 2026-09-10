// TheLightStreamsStayAliveAndSayGoodbyeTests.swift
// Echoel — #1218 (audit 2026-09-10 `output-sync-3`). The two light outputs keep the universe
// claimed through a stall, and sACN releases it on stop.
//
// THE DEFECT. `SACNSender` and `ArtNetSender` emitted only on change (fresh source, master
// move, or a settling slew). E1.31 receivers declare a source LOST after 2.5 s without a
// packet and Art-Net nodes forget a source after ~4 s — so a bio stall, a paused transport
// or a held look flipped a grandMA/QLC+ universe to "source lost" mid-show, and the desk
// either froze the last look or faded to black per its own config: an unannounced state
// change the operator cannot tell from a network fault. And `stop()` never sent E1.31
// Stream_Terminated, so the desk waited out its timeout with the merge priority still claimed.
//
// WHAT THIS PINS. (1) PACKET, by behaviour: the builder writes the Options byte, and the
// default is still 0 (counterweight — every existing golden byte stays). (2) KEEP-ALIVE, by
// text + value: both senders re-send when `keepAliveSeconds` has passed, and that number sits
// below E1.31's 2.5 s and above the 33 ms tick. (3) GOODBYE, by text: `stop()` sends three
// terminated packets and closes the socket in the last send's completion, never before.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`43cbd01`) and this tree: claim 1
// RED on the parent (no `options` parameter), GREEN here; claim 2 RED on the parent (no
// keep-alive), GREEN here; claim 3 RED on the parent, GREEN here; the default-0 counterweight
// green on both. NEEDS-FOUNDER-VERIFY: a console (sACNView is free) showing the source stay
// present through a 10 s stall and vanish immediately on stop.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLightStreamsStayAliveAndSayGoodbyeTests: XCTestCase {

    private let cid: [UInt8] = Array(repeating: 0xAB, count: 16)

    /// Claim 1 — the Options byte (offset 112, right after the sequence at 111).
    func testTheOptionsByteCarriesStreamTerminated() {
        let bye = [UInt8](SACNSender.e131Packet(universe: 1, sequence: 3, cid: cid, channels: [],
                                                synthetic: nil, options: SACNSender.streamTerminatedOption))
        XCTAssertEqual(bye[111], 3)
        XCTAssertEqual(bye[112], 0x40, "Stream_Terminated is E1.31 Options bit 6 (#1218)")
        let data = [UInt8](SACNSender.e131Packet(universe: 1, sequence: 3, cid: cid, channels: [], synthetic: nil))
        XCTAssertEqual(data[112], 0, "a plain data packet grew an Options bit — every golden byte moves (#1218)")
        XCTAssertEqual(data.count, bye.count)
    }

    /// Claim 2 — both senders keep the universe claimed, with one number below the E1.31 timeout.
    func testBothSendersKeepAliveBelowTheLossTimeout() throws {
        for path in ["Sources/Echoelmusic/Sync/SACNSender.swift", "Sources/Echoelmusic/Sync/ArtNetSender.swift"] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("|| keepAliveDue else { return }"),
                          "\(path) no longer re-sends when the keep-alive is due — the desk declares the source lost on the next stall (#1218)")
        }
        XCTAssertEqual(ArtNetSender.keepAliveSeconds, SACNSender.keepAliveSeconds, "the two light outputs drifted to two keep-alive numbers")
        XCTAssertLessThan(SACNSender.keepAliveSeconds, 2.5, "E1.31 §6.7.1 declares a source lost after 2.5 s")
        XCTAssertGreaterThan(SACNSender.keepAliveSeconds, Double(FlashGuard.senderTickMilliseconds) / 1000,
                             "a keep-alive faster than the tick would send every tick")
    }

    /// Claim 3 — stop() says goodbye three times and closes the socket AFTER the last send.
    func testStopSendsThreeTerminatedPacketsThenCloses() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/SACNSender.swift"))
        XCTAssertTrue(src.contains("for i in 0..<3 {") && src.contains("options: Self.streamTerminatedOption)"),
                      "stop() no longer sends the three Stream_Terminated packets (#1218)")
        XCTAssertTrue(src.contains(".contentProcessed { _ in conn.cancel() }"),
                      "the socket no longer closes in the last send's completion — cancel() drops pending sends, so the goodbye is lost (#1218)")
        XCTAssertTrue(src.contains("sayGoodbye()\n        connection = nil"),
                      "stop() cancels or nils the connection before the goodbye is enqueued (#1218)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

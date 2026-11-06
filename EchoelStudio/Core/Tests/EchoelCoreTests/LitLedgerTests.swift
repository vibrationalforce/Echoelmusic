import Foundation
import XCTest
@testable import EchoelCore

/// The lit-ledger (SAF-1): what a crashed run left lit is darkened at the next switch-on, only on
/// the receiver it was lit on, and a run that said its rig dark leaves nothing owed.
final class LitLedgerTests: XCTestCase {
    private let node = "10.0.0.5"

    func testALitFrameIsRememberedAndADarkOneIsNot() {
        var ledger = LitLedger()
        XCTAssertFalse(ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [0, 0, 0, 0]),
                       "an all-dark frame lights nothing")
        XCTAssertTrue(ledger.isEmpty)
        XCTAssertTrue(ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [255, 10, 0, 0]))
        XCTAssertFalse(ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [200, 0, 0, 0]),
                       "the same universe again changes nothing, so the defaults are not written every frame")
        XCTAssertTrue(ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [1], frameLength: 24),
                      "a longer frame on the wire is remembered, so the dark frame covers every slot")
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6454), [0: 24])
    }

    func testOnlyTheSameReceiverIsDarkened() {
        var ledger = LitLedger()
        ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [255, 0, 0, 0])
        ledger.lit(.artNet, host: node, port: 6454, universe: 1, channels: [UInt8](repeating: 9, count: 512))
        ledger.lit(.sacn, host: node, port: 5568, universe: 1, channels: [UInt8](repeating: 1, count: 512))
        ledger.lit(.artNet, host: "10.0.0.6", port: 6454, universe: 0, channels: [7])
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6454), [0: 4, 1: 512])
        XCTAssertEqual(ledger.leftLit(.sacn, host: node, port: 5568), [1: 512])
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6455), [:], "another port is another receiver")
        XCTAssertEqual(ledger.leftLit(.sacn, host: "10.0.0.6", port: 5568), [:],
                       "another protocol to the same host is not the connection that lit it")
    }

    func testSayingDarkForgets() {
        var ledger = LitLedger()
        ledger.lit(.artNet, host: node, port: 6454, universe: 0, channels: [255])
        ledger.lit(.artNet, host: node, port: 6454, universe: 1, channels: [255])
        ledger.lit(.artNet, host: "10.0.0.6", port: 6454, universe: 0, channels: [255])
        XCTAssertTrue(ledger.forget(.artNet, host: node, port: 6454, universe: 1))
        XCTAssertFalse(ledger.forget(.artNet, host: node, port: 6454, universe: 1), "already forgotten")
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6454), [0: 1])
        XCTAssertTrue(ledger.forget(.artNet, host: node, port: 6454))
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6454), [:])
        XCTAssertEqual(ledger.leftLit(.artNet, host: "10.0.0.6", port: 6454), [0: 1],
                       "another receiver is still owed its dark frame")
        XCTAssertTrue(ledger.forget(.artNet, host: "10.0.0.6", port: 6454))
        XCTAssertTrue(ledger.isEmpty, "a run that said its rig dark leaves nothing for the next launch")
    }

    func testTheLedgerSurvivesItsBytes() {
        var ledger = LitLedger()
        ledger.lit(.artNet, host: node, port: 6454, universe: 3, channels: [1, 2, 3, 4, 5, 6])
        ledger.lit(.sacn, host: node, port: 5568, universe: 63_999, channels: [UInt8](repeating: 255, count: 512))
        let kept = LitLedger.decoded(ledger.encoded())
        XCTAssertEqual(kept, ledger)
        XCTAssertEqual(kept.leftLit(.sacn, host: node, port: 5568), [63_999: 512])
    }

    func testDamagedBytesAreAnEmptyLedger() {
        XCTAssertTrue(LitLedger.decoded(nil).isEmpty)
        XCTAssertTrue(LitLedger.decoded(Data()).isEmpty)
        XCTAssertTrue(LitLedger.decoded(Data("not a ledger".utf8)).isEmpty)
        XCTAssertTrue(LitLedger.decoded(Data("{\"entries\":1}".utf8)).isEmpty)
    }

    func testAnEntryNoFrameCanReachIsDropped() {
        let ledger = LitLedger(entries: [
            .init(output: .artNet, host: "", port: 6454, universe: 0, frameLength: 4),
            .init(output: .artNet, host: node, port: 0, universe: 0, frameLength: 4),
            .init(output: .artNet, host: node, port: 6454, universe: 40_000, frameLength: 4),
            .init(output: .sacn, host: node, port: 5568, universe: 0, frameLength: 512),
            .init(output: .artNet, host: node, port: 6454, universe: 2, frameLength: 0),
            .init(output: .artNet, host: node, port: 6454, universe: 2, frameLength: 513),
            .init(output: .artNet, host: node, port: 6454, universe: 1, frameLength: 8),
            .init(output: .artNet, host: node, port: 6454, universe: 1, frameLength: 16),
        ])
        XCTAssertEqual(ledger.entries.count, 1, "only one usable universe, held once")
        XCTAssertEqual(ledger.leftLit(.artNet, host: node, port: 6454), [1: 16], "a repeat keeps its longest frame")
        var lit = LitLedger()
        XCTAssertFalse(lit.lit(.sacn, host: node, port: 5568, universe: 0, channels: [255]), "sACN has no universe 0")
        XCTAssertFalse(lit.lit(.artNet, host: "", port: 6454, universe: 0, channels: [255]))
    }

    func testTheLedgerIsBounded() {
        var ledger = LitLedger()
        for universe in 0..<(LitLedger.capacity + 10) {
            ledger.lit(.artNet, host: node, port: 6454, universe: universe, channels: [255])
        }
        XCTAssertEqual(ledger.entries.count, LitLedger.capacity)
        XCTAssertNil(ledger.leftLit(.artNet, host: node, port: 6454)[0], "the oldest goes first")
        XCTAssertNotNil(ledger.leftLit(.artNet, host: node, port: 6454)[LitLedger.capacity + 9])
    }
}

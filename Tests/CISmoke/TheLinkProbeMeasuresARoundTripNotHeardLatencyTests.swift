//
//  TheLinkProbeMeasuresARoundTripNotHeardLatencyTests.swift
//  Live-jam J0/J1 (founder 2026-10-07). Two phones in a Live Colabo session time a ten-byte
//  probe round trip on the sender's own clock, and the diag log gets p50 / p95 / p99 / max /
//  loss per peer. This guard pins that the numbers are what they say — measured samples,
//  never extrapolated tails, never a forged or late echo — and that the line names itself a
//  NETWORK ROUND TRIP, so an exported log cannot be read as the heard latency the founder's
//  targets are about.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · BEHAVIOUR (claims 1–5) — the shipped `LinkProbeFrame` and `LinkLatencyMeter`, driven with
//    explicit times (the meter has no clock of its own).
//  · SOURCE (claim 6) — `MultipeerSession` answers a ping on the transport callback BEFORE any
//    main-actor hop, sends probes `.unreliable`, and tears probing down on stop and disconnect.
//  · NOT PINNED, and said so: any real number. Nothing here has run on two phones —
//    NEEDS-FOUNDER-VERIFY (J1): two devices in one Live Colabo session, export Diagnostics,
//    read the `link:` lines.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid a JSON probe or a reliable
//  channel forever; it pins today's reasons (older builds stay silent, the jam path is
//  unreliable) and fails loudly when either changes, so the change is made consciously.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `LinkProbeFrame` and
//  `LinkLatencyMeter` are created by this commit (ONE absence, #486). The frame codec and the
//  meter were transcribed in Python: claim 2 is red against a linear-interpolated percentile,
//  claim 3 against a percentile that names a tail from any sample count (p95 of 19), claim 4 against a
//  meter that accepts an unknown id and one that keeps a late echo as a sample, claim 5 against
//  an unbounded outstanding map, claim 1 against an echo that echoes an echo.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLinkProbeMeasuresARoundTripNotHeardLatencyTests: XCTestCase {

    // MARK: 1 — the frame is ten bytes, older builds cannot mistake it for a payload, and an echo is never echoed

    func testTheFrameIsTenBytesThatNoPayloadDecoderAccepts() throws {
        let ping = LinkProbeFrame.encode(.ping, id: 0xA1B2_C3D4)
        XCTAssertEqual(ping.count, LinkProbeFrame.length)
        let decoded = try XCTUnwrap(LinkProbeFrame.decode(ping))
        XCTAssertEqual(decoded.kind, .ping)
        XCTAssertEqual(decoded.id, 0xA1B2_C3D4)

        let echo = try XCTUnwrap(LinkProbeFrame.echo(of: ping))
        XCTAssertEqual(LinkProbeFrame.decode(echo)?.kind, .echo)
        XCTAssertEqual(LinkProbeFrame.decode(echo)?.id, 0xA1B2_C3D4, "the echo carries the same id")
        XCTAssertNil(LinkProbeFrame.echo(of: echo), "an echo is never echoed — two peers cannot bounce one frame forever")

        XCTAssertNil(ColabPayload.decode(ping), "an older build's payload decoder drops the probe silently")
        XCTAssertNil(ColabPayload.decode(echo))
        let payload = try XCTUnwrap(ColabPayload(kind: "bio", senderName: "A").encoded())
        XCTAssertNil(LinkProbeFrame.decode(payload), "a JSON payload is never read as a probe")

        var wrongMagic = [UInt8](ping); wrongMagic[0] = 0x7B
        XCTAssertNil(LinkProbeFrame.decode(Data(wrongMagic)))
        XCTAssertNil(LinkProbeFrame.decode(ping.prefix(9)))
        XCTAssertNil(LinkProbeFrame.decode(ping + Data([0])))
    }

    // MARK: 2 — the percentiles are nearest-rank: every reported number is a round trip that happened

    func testThePercentilesAreMeasuredSamples() {
        var meter = LinkLatencyMeter()
        for id in UInt32(1)...100 {
            meter.didSend(id: id, at: 0)
            XCTAssertTrue(meter.didEcho(id: id, at: Double(id) / 1000))
        }
        let summary = meter.summary()
        XCTAssertEqual(summary.samples, 100)
        XCTAssertEqual(summary.p50 ?? -1, 50, accuracy: 1e-9)
        XCTAssertEqual(summary.p95 ?? -1, 95, accuracy: 1e-9)
        XCTAssertEqual(summary.p99 ?? -1, 99, accuracy: 1e-9)
        XCTAssertEqual(summary.max ?? -1, 100, accuracy: 1e-9)
        XCTAssertEqual(summary.sent, 100)
        XCTAssertEqual(summary.received, 100)
        XCTAssertEqual(summary.lost, 0)
    }

    // MARK: 3 — a tail is named only once a round trip can sit in it

    func testATailIsNamedOnlyWithEnoughRoundTrips() {
        XCTAssertNil(LinkLatencyMeter.percentile([4], 0.50), "one sample has no median")
        XCTAssertEqual(LinkLatencyMeter.percentile([4, 6], 0.50), 4)
        let nineteen = (1...19).map(Double.init)
        XCTAssertNil(LinkLatencyMeter.percentile(nineteen, 0.95), "19 round trips have no 95th percentile")
        let twenty = (1...20).map(Double.init)
        XCTAssertEqual(LinkLatencyMeter.percentile(twenty, 0.95), 19, "20 do — the 19th")
        XCTAssertNil(LinkLatencyMeter.percentile((1...99).map(Double.init), 0.99))
        XCTAssertEqual(LinkLatencyMeter.percentile((1...100).map(Double.init), 0.99), 99)

        var meter = LinkLatencyMeter()
        meter.didSend(id: 1, at: 10)
        meter.didEcho(id: 1, at: 10.004)
        let one = meter.summary()
        XCTAssertNil(one.p50)
        XCTAssertNil(one.p95)
        XCTAssertEqual(one.max ?? -1, 4, accuracy: 1e-6, "the maximum of what was measured is always a fact")
    }

    // MARK: 4 — a forged, repeated, late or impossible echo is never a round trip

    func testOnlyAnEchoOfAnOutstandingProbeCounts() {
        var meter = LinkLatencyMeter()
        XCTAssertFalse(meter.didEcho(id: 7, at: 1), "an id this side never sent")
        meter.didSend(id: 7, at: 1)
        XCTAssertTrue(meter.didEcho(id: 7, at: 1.010))
        XCTAssertFalse(meter.didEcho(id: 7, at: 1.020), "the same echo twice counts once")

        meter.didSend(id: 8, at: 2)
        XCTAssertFalse(meter.didEcho(id: 8, at: 2 + LinkLatencyMeter.lostAfter + 0.1),
                       "an echo later than the loss window is a loss, not a sample")
        meter.didSend(id: 9, at: 5)
        XCTAssertFalse(meter.didEcho(id: 9, at: 4), "a negative interval is not a round trip")
        XCTAssertFalse(meter.didEcho(id: 9, at: .nan))
        meter.didSend(id: 10, at: .infinity)

        let summary = meter.summary()
        XCTAssertEqual(summary.samples, 1)
        XCTAssertEqual(summary.received, 1)
        XCTAssertEqual(summary.lost, 1, "only the late echo is lost so far — probe 9 is still outstanding")
        XCTAssertEqual(summary.sent, 3, "a probe with a non-finite send time is not recorded at all")
    }

    // MARK: 5 — silence becomes loss, and a silent peer costs bounded memory

    func testSilenceIsLossAndTheBacklogIsBounded() {
        var meter = LinkLatencyMeter()
        let count = LinkLatencyMeter.maxOutstanding + 1
        for id in 1...count { meter.didSend(id: UInt32(id), at: 0) }
        XCTAssertEqual(meter.summary().lost, 1, "past the cap the oldest unanswered probe is written off")
        XCTAssertFalse(meter.didEcho(id: 1, at: 0.01), "a written-off probe cannot come back as a sample")

        meter.expire(now: LinkLatencyMeter.lostAfter / 2)
        XCTAssertEqual(meter.summary().lost, 1, "inside the window nothing more is lost")
        meter.expire(now: LinkLatencyMeter.lostAfter + 0.5)
        XCTAssertEqual(meter.summary().lost, count, "after it, every unanswered probe is")
        XCTAssertEqual(meter.summary().sent, count)
        XCTAssertEqual(meter.summary().samples, 0)
        XCTAssertNil(meter.summary().max)

        let line = meter.summary().logLine(peer: "abc123")
        XCTAssertTrue(line.hasPrefix("link: peer=abc123 rtt "), line)
        XCTAssertTrue(line.contains("network round trip, not heard latency"),
                      "the exported line names what it measures: \(line)")
        XCTAssertTrue(line.contains("p95=-"), "an unmeasured tail prints as absent, never as 0: \(line)")
    }

    // MARK: 6 — the session answers on the transport callback, unreliably, and stops with the session

    func testTheSessionEchoesBeforeTheMainActorAndStopsProbing() throws {
        let source = try Self.source("Sources/Echoelmusic/Sync/MultipeerSession.swift")
        let receive = try XCTUnwrap(source.range(of: "didReceive data: Data, fromPeer peerID: MCPeerID)"))
        let body = String(source[receive.upperBound...].prefix(2_000))
        let echo = try XCTUnwrap(body.range(of: "try? session.send(reply, toPeers: [peerID], with: .unreliable)"),
                                 "a ping is answered from the delegate itself")
        let hop = try XCTUnwrap(body.range(of: "Task { @MainActor"))
        XCTAssertLessThan(echo.lowerBound, hop.lowerBound,
                          "the echo leaves BEFORE the first main-actor hop — the round trip measures the link, not the UI")
        XCTAssertTrue(source.contains("try? mcSession.send(LinkProbeFrame.encode(.ping, id: id), toPeers: peers, with: .unreliable)"),
                      "probes travel the unreliable channel a jam would use")

        let stop = try XCTUnwrap(source.range(of: "public func stop() {"))
        let stopBody = String(source[stop.upperBound...].prefix(1_200))
        XCTAssertTrue(stopBody.contains("stopProbing()") && stopBody.contains("linkMeters.removeAll()"),
                      "stop() ends the probes and forgets every link")
        XCTAssertTrue(source.contains("linkMeters.removeValue(forKey: peer.stableID)"),
                      "a peer that leaves takes its meter with it")
        XCTAssertTrue(source.contains("if connectedPeers.isEmpty { stopProbing() }"),
                      "no peers, no probes")
    }

    private static func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }
}

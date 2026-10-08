//
//  TheLinkRoundTripRowSaysNetworkNotHeardTests.swift
//  Live-jam J1 (founder 2026-10-07). The link round trip `LinkProbe` measures reached only the
//  diag log — `MultipeerSession.linkSummary(forPeer:)` had no caller. Now each connected peer's
//  row in Live Colabo carries the line. This guard pins (a) that the line says what the number
//  IS — the NETWORK round trip, never the heard latency — and prints an unmeasured value as
//  absent, never as 0; (b) that the read lives in its own leaf on a tick, because the meter is
//  deliberately NOT observed (10.76.41/50: a 2 Hz read in the host body would rebuild the page
//  twice a second and tear down whatever is open on it).
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · BEHAVIOUR (claims 1–2) — `LinkLatencySummary.rowText(_:)`, a Foundation-only formatter.
//  · SOURCE (claims 3–5) — exactly one production caller of the meter, inside `PeerLinkRow`
//    under a `TimelineView` tick; the host's `connectedSection` mounts the leaf and never calls
//    the meter itself; `linkMeters` stays `@ObservationIgnored`; "latency" occurs in the view
//    and in the probe file only as "not heard latency".
//  · NOT PINNED, and said so: any real number, the layout, how VoiceOver reads the line —
//    NEEDS-FOUNDER-VERIFY (J1) sits at the row.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it does not forbid observing the meter forever. It
//  pins today's reason — the tick is the read — and claim 4 goes red so the trade is made
//  consciously, together with the leaf, not by flipping one attribute.
//
//  GRADING (#433/#464), parent tree 4251d7b (kit commit, no code): the file does NOT compile
//  there — `rowText(_:)` is created by this commit (ONE absence, #486) — so claims 1–2 have no
//  verdict on the parent and were driven in Python instead: claim 1 red against a formatter
//  that printed "0 ms" for a nil median and one that dropped the qualifier; claim 2 red against
//  one that printed "20 ms" for 20.6. Claims 3 and 5 are SOURCE scans transcribed against
//  `git show HEAD:…` and the worktree: claim 3 is RED on the parent for its named reason (no
//  caller, no `PeerLinkRow`); claim 5 is green on both (1 == 1 in the probe file, 0 == 0 in the
//  view) — a COUNTERWEIGHT that becomes load-bearing the day someone writes a bare "latency".
//  Its first draft lowercased the text and was red on BOTH trees for the wrong reason — the
//  type names `LinkLatencySummary` / `LinkLatencyMeter` — which is exactly #367; it now counts
//  the lowercase word only. Claim 4 is a COUNTERWEIGHT, green on both trees.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLinkRoundTripRowSaysNetworkNotHeardTests: XCTestCase {

    private static let qualifier = "network round trip, not heard latency"

    // MARK: 1 — an unmeasured value is absent, never 0

    func testAnUnmeasuredLinkPrintsAsAbsentNeverAsZero() {
        let none = LinkLatencySummary.rowText(nil)
        XCTAssertTrue(none.contains("measuring"), "no meter yet says so: \(none)")
        XCTAssertTrue(none.contains(Self.qualifier), "even the empty row names what it will measure: \(none)")
        XCTAssertFalse(none.contains("0 ms"), "an absent number is not a zero: \(none)")

        let noMedian = LinkLatencySummary(sent: 3, received: 1, lost: 0, samples: 1,
                                          p50: nil, p95: nil, p99: nil, max: 9.0)
        let early = LinkLatencySummary.rowText(noMedian)
        XCTAssertTrue(early.contains("measuring") && early.contains(Self.qualifier), early)
        XCTAssertFalse(early.contains("0 ms"), early)

        let noTail = LinkLatencySummary(sent: 12, received: 12, lost: 0, samples: 12,
                                        p50: 8.4, p95: nil, p99: nil, max: 11.0)
        let tailless = LinkLatencySummary.rowText(noTail)
        XCTAssertTrue(tailless.contains("8 ms median"), tailless)
        XCTAssertTrue(tailless.contains("p95 —"), "a tail the window cannot name prints as absent: \(tailless)")
        XCTAssertFalse(tailless.contains("0 ms"), tailless)
    }

    // MARK: 2 — the measured row carries its numbers, rounded, and the qualifier

    func testTheRowNamesTheNetworkRoundTripWithItsNumbers() {
        let summary = LinkLatencySummary(sent: 40, received: 39, lost: 1, samples: 39,
                                         p50: 12.4, p95: 20.6, p99: nil, max: 33.0)
        let row = LinkLatencySummary.rowText(summary)
        XCTAssertTrue(row.contains("12 ms median"), "whole milliseconds, half-up: \(row)")
        XCTAssertTrue(row.contains("21 ms p95"), "20.6 rounds to 21, not to 20: \(row)")
        XCTAssertTrue(row.contains("lost 1/40"), "loss is written against what was sent: \(row)")
        XCTAssertTrue(row.contains(Self.qualifier), "the row names what the number IS: \(row)")
        XCTAssertFalse(row.contains("measuring"), row)
    }

    // MARK: 3 — exactly one reader, and it is the ticking leaf

    func testTheOnlyReaderIsTheLiveColaboLeafOnATick() throws {
        let callers = try Self.sourceFiles().filter { Self.codeOnly(try Self.source($0)).contains("linkSummary(forPeer:") }
        XCTAssertEqual(callers, ["Sources/Echoelmusic/Studio/LiveColaboView.swift"],
                       "the meter has exactly one production reader, the Live Colabo row — found \(callers)")

        let view = Self.codeOnly(try Self.source("Sources/Echoelmusic/Studio/LiveColaboView.swift"))
        XCTAssertEqual(view.components(separatedBy: "linkSummary(forPeer:").count - 1, 1,
                       "one call site in the view — a second one is a second reader to justify")

        let leafStart = try XCTUnwrap(view.range(of: "private struct PeerLinkRow: View {"),
                                      "the leaf exists under its own name")
        let leafEnd = try XCTUnwrap(view.range(of: "\n}\n", range: leafStart.upperBound..<view.endIndex))
        let leaf = String(view[leafStart.lowerBound..<leafEnd.upperBound])
        XCTAssertTrue(leaf.contains("linkSummary(forPeer:"), "the read is INSIDE the leaf")
        XCTAssertTrue(leaf.contains("TimelineView(.periodic(from: .now, by: 1))"),
                      "the tick is the read — the meter is not observed, so nothing else redraws this row")
        XCTAssertTrue(leaf.contains("LinkLatencySummary.rowText("), "the leaf shows the one formatter, not its own sentence")

        let hostStart = try XCTUnwrap(view.range(of: "private var connectedSection: some View {"))
        let hostEnd = try XCTUnwrap(view.range(of: "private var discoveredSection", range: hostStart.upperBound..<view.endIndex))
        let host = String(view[hostStart.lowerBound..<hostEnd.lowerBound])
        XCTAssertTrue(host.contains("PeerLinkRow(stableID: peer.stableID)"), "the host MOUNTS the leaf per connected peer")
        XCTAssertFalse(host.contains("linkSummary("), "the host never reads the meter itself (10.76.41/50)")
    }

    // MARK: 4 — counterweight: the meter stays unobserved, which is why the tick exists

    func testTheMeterStaysUnobservedSoTheTickIsTheRead() throws {
        let session = Self.codeOnly(try Self.source("Sources/Echoelmusic/Sync/MultipeerSession.swift"))
        XCTAssertTrue(session.contains("@ObservationIgnored private var linkMeters"), """
            `linkMeters` is observed now. Then `PeerLinkRow`'s read registers a 2 Hz observer and \
            the `TimelineView` tick is redundant — decide the trade in the leaf and here together, \
            not by flipping the attribute alone.
            """)
    }

    // MARK: 5 — "latency" is spoken only with its qualifier

    func testLatencyAppearsOnlyAsNotHeardLatency() throws {
        for relative in ["Sources/Echoelmusic/Studio/LiveColaboView.swift",
                         "Sources/Echoelmusic/Sync/LinkProbe.swift"] {
            // Case-sensitive on purpose: the lowercase word is what a SENTENCE carries; the
            // capitalised form in code is a type name (`LinkLatencySummary`, `LinkLatencyMeter`)
            // and would make this count fail for a reason other than its name (#367).
            let code = Self.codeOnly(try Self.source(relative))
            let all = code.components(separatedBy: "latency").count - 1
            let qualified = code.components(separatedBy: "not heard latency").count - 1
            XCTAssertEqual(all, qualified, """
                `\(relative)` says "latency" \(all) time(s) in code or strings but qualifies it as \
                "not heard latency" only \(qualified) time(s). A bare "latency" next to a network \
                round trip reads as the heard latency the founder's targets are about.
                """)
        }
    }

    // MARK: - helpers

    private static func codeOnly(_ text: String) -> String { SourceText.codeOnly(text) }

    private static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every tracked Swift file under `Sources/`, repo-relative.
    private static func sourceFiles() throws -> [String] {
        let root = repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var files: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append("Sources" + url.path.replacingOccurrences(of: root.path, with: ""))
        }
        return files.sorted()
    }
}

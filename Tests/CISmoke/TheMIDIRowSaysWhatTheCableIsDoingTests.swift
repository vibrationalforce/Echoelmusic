// TheMIDIRowSaysWhatTheCableIsDoingTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// the MIDI path: the Routing surface gets a "MIDI" card with one status line per direction.
//
// WHAT IT GUARDS. Routing carried four MIDI switches and no word about the cable: whether a
// controller is connected (`MIDIInput.isConnected`, no Studio reader), whether notes arrive
// (`MIDIBusPublisher.lastEventTimestamp`, no reader at all), whether the out port opened
// (`MIDIOutput.isReady`, no reader — a #837 failed port looked like an unrouted one). Now
// `MIDIInRung` (No controller / Connected / Playing) and `MIDIOutRung` (Off / On / Unavailable)
// name the rungs and `PatchbayView.MIDIStatusRow` renders them above the switches.
//
// HOW THE SURFACE READS AN INPUT IT DOES NOT HOLD. `MIDIInput` is internal and injected nowhere;
// the injected `MIDIBusPublisher` FORWARDS its two cold facts (`sourceConnected`, `sourceName`) —
// one definition each (#416) — and the per-event stamp stays `@ObservationIgnored`, POLLED by the
// leaf on its own 2 s clock (the #919/#928 law: a per-note observer would rebuild Routing per key).
//
// §1 LIMIT: claims 1–3 are END-TO-END BEHAVIOUR on the two pure enums. Claims 4–6 are SOURCE-TEXT
// SCANS: mounted, gated, cold, wired; not rendered. Whether "Connected · KeyStep" turns into
// "Playing · KeyStep" under a hand is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY sits on the struct.
//
// §3 HONEST GRADING. Names NEW symbols (`MIDIInRung`, `MIDIOutRung`), so it does not compile
// against the parent: NO assertion has a verdict there. Hand-transcribed in Python against both
// trees: claims 1–3 FORWARD; claim 4 red on the parent by ANCHOR ABSENCE (no `MIDIStatusRow`
// struct — one absence, #486); claim 5 red on the parent by the same absence (zero mounts); claim
// 6 red on the parent for its named reason (no forwarders, no `destinationCount`), and its
// negative halves are COUNTERWEIGHTS green on both trees. ZERO regressions claimed. Stripper:
// `SourceText.codeOnly` on both trees — measured in the transcription, reported in the commit.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMIDIRowSaysWhatTheCableIsDoingTests: XCTestCase {

    private static let surface = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let publisher = "Sources/Echoelmusic/Sync/MIDIBusPublisher.swift"
    private static let output = "Sources/Echoelmusic/Audio/MIDIOutput.swift"
    private static let leafOpening = "private struct MIDIStatusRow: View {"

    // MARK: - claim 1 (E2E) — the inbound ladder, every rung reached

    func testTheInboundLadderIsATotalFunctionOfCableAndClock() {
        typealias Row = (connected: Bool, last: TimeInterval, now: TimeInterval, expect: MIDIInRung)
        let w = MIDIInRung.playingWindow
        let table: [Row] = [
            (false, 0, 100, .off),
            (false, 99, 100, .off),            // a stale-but-fresh stamp cannot outrank an unplugged cable
            (true, 0, 100, .connected),        // never played
            (true, 99, 100, .playing),         // 1 s ago
            (true, 100 - w, 100, .connected),  // exactly the window: closed at the edge
            (true, 100 - w + 0.5, 100, .playing),
            (true, 50, 100, .connected),       // long quiet
        ]
        for row in table {
            XCTAssertEqual(MIDIInRung.rung(sourceConnected: row.connected, lastEvent: row.last, now: row.now),
                           row.expect, "connected=\(row.connected) last=\(row.last) now=\(row.now)")
        }
        XCTAssertEqual(Set(table.map { $0.expect }).count, MIDIInRung.allCases.count,
                       "the table must reach every rung, or a rung has no proof")
        XCTAssertGreaterThan(w, 0)
    }

    // MARK: - claim 2 (E2E) — the outbound ladder and its destination count

    func testTheOutboundLadderSeparatesOffFromAPortThatDidNotOpen() {
        typealias Row = (enabled: Bool, ready: Bool, expect: MIDIOutRung)
        let table: [Row] = [
            (false, false, .off),
            (false, true, .off),          // a ready port that nobody routed is OFF, not On
            (true, false, .unavailable),  // routed, port refused — the #837 shape
            (true, true, .on),
        ]
        for row in table {
            XCTAssertEqual(MIDIOutRung.rung(enabled: row.enabled, isReady: row.ready), row.expect,
                           "enabled=\(row.enabled) ready=\(row.ready)")
        }
        XCTAssertEqual(Set(table.map { $0.expect }).count, MIDIOutRung.allCases.count)
        XCTAssertEqual(MIDIOutRung.on.line(destinations: 0), "On · offered as a source")
        XCTAssertEqual(MIDIOutRung.on.line(destinations: 1), "On · source + 1 destination")
        XCTAssertEqual(MIDIOutRung.on.line(destinations: 3), "On · source + 3 destinations")
        XCTAssertEqual(MIDIOutRung.off.line(destinations: 7), MIDIOutRung.off.line(destinations: 0),
                       "Off says the same thing however many destinations exist — nothing reaches them")
        XCTAssertTrue(MIDIOutRung.on.spoken(destinations: 1).hasSuffix("1 destination"))
        XCTAssertTrue(MIDIOutRung.on.spoken(destinations: 2).hasSuffix("2 destinations"))
    }

    // MARK: - claim 3 (E2E) — the words: word-led lines, a remedy per rung, no struck or recipe word

    func testEveryRungLeadsWithItsWordAndCarriesARemedy() {
        let forbidden = ["session", "microphone", "denied", "then", "first", "take", "lane"]
        var lines: [String] = []
        var captions: [String] = []
        for rung in MIDIInRung.allCases {
            let line = rung.line(source: "KeyStep")
            XCTAssertTrue(line.hasPrefix(rung.word + " · "), "in \(rung): '\(line)'")
            XCTAssertFalse(rung.caption.isEmpty)
            XCTAssertNotEqual(rung.caption, line)
            XCTAssertFalse(rung.spoken(source: "KeyStep").isEmpty)
            lines.append(line); captions.append(rung.caption)
        }
        for rung in MIDIOutRung.allCases {
            let line = rung.line(destinations: 1)
            XCTAssertTrue(line.hasPrefix(rung.word + " · "), "out \(rung): '\(line)'")
            XCTAssertFalse(rung.caption.isEmpty)
            XCTAssertNotEqual(rung.caption, line)
            XCTAssertTrue(rung.spoken(destinations: 1).contains("MIDI out"))
            lines.append(line); captions.append(rung.caption)
        }
        XCTAssertEqual(Set(lines).count, lines.count, "two rungs read the same — a ladder with a repeated step")
        XCTAssertEqual(Set(captions).count, captions.count)
        for text in lines + captions {
            let tokens = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
            for word in forbidden {
                XCTAssertFalse(tokens.contains(word), "'\(word)' in '\(text)' — struck word, recipe word or a deleted capability")
            }
        }
        XCTAssertTrue(MIDIInRung.off.line(source: "").contains("pair"), "the off rung names the remedy")
        XCTAssertTrue(MIDIOutRung.off.line(destinations: 0).contains("route"), "the off rung names the switch")
        XCTAssertTrue(MIDIOutRung.unavailable.caption.contains("returns to the front"),
                      "the remedy is TRUE only because `EchoelmusicApp` calls `rearmIfDead()` on foreground; claim 6 pins that")
        XCTAssertTrue(MIDIInRung.connected.line(source: "KeyStep").contains("KeyStep"))
        XCTAssertFalse(MIDIInRung.off.line(source: "No Device").contains("No Device"),
                       "the unplugged rung must not print `MIDIInput.deviceName`'s placeholder")
    }

    // MARK: - claim 4 (SCAN) — the leaf: its own clock, polled stamp, describes and does not own

    func testTheCardIsALeafOnItsOwnClockThatOwnsNothing() throws {
        let body = try member(Self.leafOpening, in: try source(Self.surface))
        for needle in ["TimelineView(.periodic(from: .now, by: Self.tick))",
                       "midiPub.sourceConnected", "midiPub.lastEventTimestamp", "midiPub.sourceName",
                       "midiOut.enabled", "midiOut.isReady", "midiOut.destinationCount",
                       "MIDIInRung.rung(", "MIDIOutRung.rung(",
                       ".accessibilityValue(spoken)", ".accessibilityLabel(label)",
                       "@Environment(MIDIBusPublisher.self)", "@Environment(MIDIOutput.self)"] {
            XCTAssertTrue(body.contains(needle), "the MIDI card lost `\(needle)`")
        }
        for banned in ["Timer.", "MIDIInput", ".start(", ".stop(", "enabled =", "applyRouting", "Task {"] {
            XCTAssertFalse(body.contains(banned), "`\(banned)` in the MIDI card — it describes the cable, it never drives it")
        }
        XCTAssertEqual(body.components(separatedBy: "statusLine(label:").count - 1, 3,
                       "two calls and one declaration: exactly one line per direction")
    }

    // MARK: - claim 5 (SCAN) — mounted once, in the CoreMIDI block, above the switches it explains

    func testTheCardIsMountedOnceAboveTheSwitches() throws {
        var mounts = 0
        var files = 0
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return XCTFail("cannot walk Sources/")
        }
        for case let path as URL in walker where path.pathExtension == "swift" {
            files += 1
            mounts += SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
                .components(separatedBy: "MIDIStatusRow()").count - 1
        }
        XCTAssertGreaterThan(files, 100, "the Sources walk found \(files) files — it did not walk")
        XCTAssertEqual(mounts, 1, "`MIDIStatusRow()` must be constructed exactly once, in Routing's `content`")

        let content = try member("private var content: some View", in: try source(Self.surface))
        guard let mount = content.range(of: "MIDIStatusRow()"),
              let wireless = content.range(of: "networkMIDISection"),
              let gate = content.range(of: "#if os(iOS) && canImport(CoreMIDI)") else {
            return XCTFail("ANCHOR MISSING in `content`: MIDIStatusRow(), networkMIDISection or the CoreMIDI gate — re-anchor")
        }
        XCTAssertTrue(gate.upperBound <= mount.lowerBound && mount.upperBound <= wireless.lowerBound, """
            The card sits inside the CoreMIDI block (its publisher exists only there) and ABOVE the \
            wireless-MIDI switch: what the cable is doing, and beneath it what can be changed.
            """)
    }

    // MARK: - claim 6 (SCAN) — the boundary: forwarded facts, a queried count, a re-armed port

    func testTheFactsAreForwardedOnceAndThePortIsReArmed() throws {
        let pub = try source(Self.publisher)
        for needle in ["public var sourceConnected: Bool { midi.isConnected }",
                       "public var sourceName: String { midi.deviceName }"] {
            XCTAssertTrue(pub.contains(needle), "`MIDIBusPublisher` lost `\(needle)` — one definition, forwarded (#416)")
        }
        XCTAssertFalse(pub.contains("var sourceConnected = "), "a STORED mirror of `isConnected` would drift from the cable")
        let out = try source(Self.output)
        XCTAssertTrue(out.contains("public var destinationCount: Int {"), "`MIDIOutput.destinationCount` is gone")
        XCTAssertTrue(out.contains("return Int(MIDIGetNumberOfDestinations())"),
                      "the count must be the CoreMIDI query `send` fans out over — not a cached number")
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("midiOut.rearmIfDead()"),
                      "the Unavailable caption promises a retry on foreground return; `EchoelmusicApp` must still make it")
        XCTAssertTrue(app.contains(".environment(midiPub)"), "the card reads the publisher from the environment")
        let surface = try source(Self.surface)
        XCTAssertFalse(surface.contains("MIDIInput("), "Routing must not construct a second CoreMIDI client")
        XCTAssertFalse(surface.contains("midiPub.start(") || surface.contains("midiPub.stop("),
                       "Routing describes the publisher, it never drives it")
    }

    // MARK: - helpers

    private func member(_ opening: String, in code: String) throws -> String {
        guard code.components(separatedBy: opening).count == 2, let start = code.range(of: opening) else {
            throw AnchorMissing(reason: "`\(opening)` must occur exactly once")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(opening)`")
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}

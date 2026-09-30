// TheAudioRouteRowSaysWhereTheSoundGoesTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// second step: the master panel gets an "Audio route" row.
//
// WHAT IT GUARDS. The master panel carried the buffer tier (`AudioLatencyRow`) and the timing
// tally (`AudioTimingRow`) and no sentence about WHERE the sound goes. `AudioRouteRung`
// (`Studio/AudioRouteStatusWord.swift`) is the ladder — Off / Playing / Call mode — and
// `EchoelStudioView.AudioRouteRow` renders it between the two existing rows, with
// `RouteCodec.note` (the one Bluetooth remedy sentence, `TheCodecNoteNamesNoInputTests`) beneath
// the line whenever the route is in call mode.
//
// §1 LIMIT: claims 1–4 are END-TO-END BEHAVIOUR on a pure value type (`AudioRouteRung`,
// Foundation-only, `@testable`-reachable). Claims 5–7 are SOURCE-TEXT SCANS: they prove the row
// is mounted, ordered and cold; they do not prove it renders. Whether "Call mode · AirPods …"
// appears when a phone call holds the Bluetooth link is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY sits
// on the row's declaration, not here.
//
// §3 HONEST GRADING. This file names a NEW symbol (`AudioRouteRung`), so it does not compile
// against the parent (747e77012): NO assertion has a verdict there. Hand-transcribed in Python
// against both trees instead: claims 1–4 are FORWARD (the type does not exist on the parent);
// claim 5 is red on the parent by ANCHOR ABSENCE (no `AudioRouteRow(` in `masterPanel` — one
// absence, reported once, #486); claims 6–7 are red on the parent by the same absence (the struct
// is not declared) and are COUNTERWEIGHTS on this tree. The `outputNames` field and the
// `.codec.note` read (claim 7) are new with this slice. ZERO regressions claimed.
//
// Stripper: `SourceText.codeOnly` on both trees — PROPHYLAKTISCH (0 of 7 verdicts flip; every
// anchor here is a code token that appears in no comment of the scanned files).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAudioRouteRowSaysWhereTheSoundGoesTests: XCTestCase {

    private typealias Codec = AudioConfiguration.RouteCodec
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    /// Whole words the ladder may not speak: there has been no audio input since #1302
    /// (`TheCodecNoteNamesNoInputTests` pins the same set on the codec note).
    private static let inputWords: Set<String> = ["mic", "microphone", "input", "inputs"]

    // MARK: - Claim 1 — Off wins over every codec (END-TO-END)

    func testOffWinsOverEveryCodecWhenTheEngineIsNotRunning() {
        let codecs: [Codec] = [.wideband, .telephony, .telephonySuspected]
        for codec in codecs {
            XCTAssertEqual(AudioRouteRung.rung(isRunning: false, codec: codec), .off,
                           "A route nobody hears is a fact for later, not a warning now (\(codec)).")
        }
    }

    // MARK: - Claim 2 — the running truth table (END-TO-END)

    func testARunningEngineSpeaksPlayingOrCallMode() {
        XCTAssertEqual(AudioRouteRung.rung(isRunning: true, codec: .wideband), .playing)
        XCTAssertEqual(AudioRouteRung.rung(isRunning: true, codec: .telephony), .callMode,
                       "iOS NAMED the HFP port: that is call mode, not a suspicion.")
        XCTAssertEqual(AudioRouteRung.rung(isRunning: true, codec: .telephonySuspected), .callMode,
                       "An inferred call mode still narrows the band; the word is the same, "
                       + "the remedy sentence (`RouteCodec.note`) carries the 'looks like'.")
        // Every rung is reachable — a case nothing produces would be a word on no screen.
        let produced: Set<AudioRouteRung> = [
            AudioRouteRung.rung(isRunning: false, codec: .wideband),
            AudioRouteRung.rung(isRunning: true, codec: .wideband),
            AudioRouteRung.rung(isRunning: true, codec: .telephony),
        ]
        XCTAssertEqual(produced, Set(AudioRouteRung.allCases))
    }

    // MARK: - Claim 3 — the line and the spoken value carry the facts, in order (END-TO-END)

    func testTheLineCarriesOutputsAndFloorOnlyWhilePlaying() {
        let off = AudioRouteRung.off.line(outputs: "Speaker", floorText: "7.3 ms")
        XCTAssertTrue(off.hasPrefix("Off"), off)
        XCTAssertFalse(off.contains("7.3 ms"),
                       "The floor of a route nobody hears is a number without a use.")
        XCTAssertFalse(off.contains("Speaker"), off)

        for rung in [AudioRouteRung.playing, .callMode] {
            let line = rung.line(outputs: "AirPods Pro", floorText: "12.0+ ms")
            // word · outputs · floor — the number is last, as on the timing row. Compared as
            // the whole triple, not by index arithmetic (#442).
            XCTAssertEqual(line.components(separatedBy: " · "), [rung.word, "AirPods Pro", "12.0+ ms"])
        }
        XCTAssertEqual(AudioRouteRung.callMode.word, "Call mode")
        XCTAssertTrue(AudioRouteRung.callMode.spoken(outputs: "AirPods Pro").contains("mono"),
                      "VoiceOver hears WHAT call mode costs, not only its name.")
        XCTAssertTrue(AudioRouteRung.playing.spoken(outputs: "Speaker").contains("Speaker"))
        XCTAssertFalse(AudioRouteRung.off.spoken(outputs: "Speaker").contains("Speaker"))
    }

    // MARK: - Claim 4 — no word about an input, and call mode always has its remedy (END-TO-END)

    func testTheLadderNamesNoInputAndCallModeAlwaysHasARemedy() {
        var spoken: [String] = [AudioRouteRung.caption]
        for rung in AudioRouteRung.allCases {
            spoken.append(rung.word)
            spoken.append(rung.line(outputs: "Speaker", floorText: "7.3 ms"))
            spoken.append(rung.spoken(outputs: "Speaker"))
        }
        for text in spoken {
            let hit = words(text).intersection(Self.inputWords)
            XCTAssertTrue(hit.isEmpty, "\(text) — speaks of an input that does not exist: \(hit)")
        }
        // The row shows `codec.note` beneath the line; `nil` falls back to the neutral caption.
        // So the promise "call mode always shows its remedy" is: every codec that maps to
        // `.callMode` carries a non-nil note. `.wideband.note == nil` is pinned by the sibling.
        for codec in [Codec.telephony, .telephonySuspected] {
            XCTAssertEqual(AudioRouteRung.rung(isRunning: true, codec: codec), .callMode)
            XCTAssertNotNil(codec.note, "\(codec) reads Call mode and would show the neutral caption.")
        }
    }

    // MARK: - Claim 5 — the row is mounted ONCE, between the buffer tier and the timing tally (SCAN)

    func testTheRowIsMountedOnceBetweenLatencyAndTiming() throws {
        let body = try masterPanelBody()
        let mount = "AudioRouteRow(engine: audioEngine)"
        XCTAssertEqual(body.filter { $0.contains(mount) }.count, 1,
                       "`masterPanel` must mount the route row exactly once.")
        guard let latency = body.firstIndex(where: { $0.contains("AudioLatencyRow()") }),
              let route = body.firstIndex(where: { $0.contains(mount) }),
              let timing = body.firstIndex(where: { $0.contains("AudioTimingRow(engine: audioEngine)") })
        else { XCTFail("one of the three rows is missing from `masterPanel`"); return }
        XCTAssertTrue(latency < route && route < timing,
                      "Reading order is cost → where → health: buffer tier, route, timing.")
    }

    // MARK: - Claim 6 — the row is a COLD leaf: value state, refreshed on events, never polled (SCAN)

    func testTheRowIsColdAndRefreshesOnRouteChanges() throws {
        let row = try routeRowBody()
        XCTAssertTrue(row.contains("@State private var readout: AudioConfiguration.LatencyReadout?"),
                      "The readout is a @State VALUE — not a live read of the session in `body`.")
        XCTAssertTrue(row.contains("AVAudioSession.routeChangeNotification"),
                      "iOS announces headphone/Bluetooth/speaker changes; the row must listen, not poll.")
        XCTAssertTrue(row.contains(".onChange(of: engine.isRunning)"),
                      "Start/stop re-reads the snapshot; `isRunning` is the cold read the timing row also takes.")
        XCTAssertEqual(occurrences(of: "AudioConfiguration.latencySnapshot()", in: row), 3,
                       "appear · start/stop · route change — three refresh sites, no fourth path.")
        for hot in ["Timer.", ".task {", "masterLevel", "lastTimingLine", "cameraRPPG", "waveform"] {
            XCTAssertFalse(row.contains(hot), "hot or polled read `\(hot)` in a leaf that must stay cold")
        }
    }

    // MARK: - Claim 7 — the remedy is `RouteCodec.note`, one definition; outputs come by name (SCAN)

    func testTheRemedyIsTheCodecNoteAndOutputsArrivePlainlyNamed() throws {
        let row = try routeRowBody()
        XCTAssertTrue(row.contains("readout?.codec.note ?? AudioRouteRung.caption"),
                      "Beneath the line: the codec's own sentence, or the neutral caption — never a third spelling.")
        XCTAssertTrue(row.contains("readout?.outputNames"),
                      "The row shows plain port names, not the log form `none→Speaker[BT]`.")
        let config = try source("Sources/Echoelmusic/Audio/AudioConfiguration.swift")
        XCTAssertTrue(config.contains("let outputNames: String"),
                      "`LatencyReadout.outputNames` is the field the row reads.")
        XCTAssertTrue(config.contains("outputNames: sanitisedRoute(v.outputNames)"),
                      "`latencySnapshot()` fills it from the session values through the same sanitiser as `route`.")
        XCTAssertTrue(config.contains(".map(\\.portName).joined(separator: \" + \")"),
                      "Plain `portName`s joined with ' + ' — no `[BT]` marker, no arrow.")
    }

    // MARK: - Helpers

    private func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init))
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// Lines of `masterPanel`, from its declaration to the next `private ` member.
    private func masterPanelBody() throws -> [String] {
        let lines = try source(Self.studio).components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.contains("private var masterPanel") }) else {
            throw AnchorMissing(reason: "`masterPanel` is gone from \(Self.studio)")
        }
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("    private ") } ?? lines.endIndex
        return Array(lines[start..<end])
    }

    /// The body of `private struct AudioRouteRow: View`, brace-matched from its declaration (#408).
    private func routeRowBody() throws -> String {
        let code = try source(Self.studio)
        let decl = "private struct AudioRouteRow: View {"
        guard let start = code.range(of: decl) else {
            throw AnchorMissing(reason: "`AudioRouteRow` is not declared in \(Self.studio)")
        }
        var depth = 0
        var index = start.upperBound
        var end = code.endIndex
        depth = 1
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { end = index; break } }
            index = code.index(after: index)
        }
        return String(code[start.lowerBound..<end])
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}

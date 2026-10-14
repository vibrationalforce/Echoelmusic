//
//  TheLaneNeverStartsAnUnwiredPlayerTests.swift
//  Crash 2624 (v10.79.499, founder device log 2026-10-14): a tap two seconds after a Stop died in
//  `AVAudioPlayerNode.play()` — "com.apple.coreaudio.avfaudio: player started when in a
//  disconnected state", SIGABRT on the main thread. The audio track's node had played fine three
//  seconds earlier; nothing in the log named the link that went missing.
//
//  The repair has three parts, and this guard pins each:
//  · `AudioEngine.missingOutputLink(from:)` walks a node's output connections to the engine's
//    output and NAMES the first missing link (claim 1).
//  · `TimelineAudioSink` asks it before EVERY start: the two ready-buffer fast paths in their
//    conditions, the main path in a `guard` before its `stop()` — which also covers the faded path,
//    because `playFaded` is called after that guard (claim 2).
//  · an unwired node writes a breadcrumb and requests a rebuild, and the prime that starts
//    playback rebuilds a lane with an unwired node (claim 3).
//
//  KIND: SOURCE-TEXT SCAN (Tests/CISmoke/CLAUDE.md §1). It proves where the checks sit, not that
//  the walk matches AVFAudio's own notion of "disconnected" — that is a DEVICE PROBE, open:
//  NEEDS-FOUNDER-VERIFY: crash 2624 — an audio track in Headphone space, Play, Stop, Play again:
//  no crash; if the log shows "audio lane: player not wired", the next Play sounds again.
//
//  GRADING against the parent tree (#433/#464): `missingOutputLink` and `wired(` do not exist
//  there, so claims 1–3 are red by ONE absence (#486). Claim 4 is a COUNTERWEIGHT, green on both:
//  the sink's four `.play()` sites are still four. Transcribed in Python against the worktree.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest

final class TheLaneNeverStartsAnUnwiredPlayerTests: XCTestCase {

    private static let sink = "Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift"
    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(path) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    // MARK: 1 — the engine names the missing link

    func testTheEngineNamesTheMissingLink() throws {
        let engine = try code(Self.engine)
        XCTAssertTrue(engine.contains("func missingOutputLink(from node: AVAudioNode) -> String?"),
                      "The engine no longer offers the walk that names a node's missing output link.")
        XCTAssertTrue(engine.contains("masterEngine.outputConnectionPoints(for: current, outputBus: 0)"),
                      "The walk no longer follows the node's real output connections.")
        XCTAssertTrue(engine.contains("current === masterEngine.mainMixerNode || current === masterEngine.outputNode"),
                      "The walk no longer stops at the engine's output — every node would read unwired.")
    }

    // MARK: 2 — every start asks first

    func testEveryStartAsksWhetherTheNodeIsWired() throws {
        let sink = try code(Self.sink)
        XCTAssertEqual(occurrences(of: "plainNode.engine?.isRunning == true, wired(plainNode)", in: sink), 2, """
            A ready-buffer fast path (Beats, grain) starts its plain node without asking whether it \
            reaches the output — the shape of crash 2624.
            """)
        guard let guardLine = sink.range(of: "guard wired(node) else { stop(); return }"),
              let faded = sink.range(of: "if let fades, playFaded(") else {
            return XCTFail("The main path's wiring guard or its faded call is gone.")
        }
        XCTAssertLessThan(guardLine.lowerBound, faded.lowerBound,
                          "The wiring guard must come BEFORE the faded path, which starts the same node.")
    }

    // MARK: 3 — an unwired node is logged and rebuilt

    func testAnUnwiredNodeIsLoggedAndRebuilt() throws {
        let sink = try code(Self.sink)
        XCTAssertTrue(sink.contains("EchoelCrashLog.breadcrumb(\"audio lane: player not wired ("),
                      "An unwired node is skipped silently — the next device log would again name nothing.")
        XCTAssertTrue(sink.contains("rewireRequested = true"),
                      "An unwired node no longer asks for a rebuild — the lane would stay silent.")
        XCTAssertTrue(sink.contains("|| rewireRequested || hasUnwiredNode(engine) {"),
                      "The prime that starts playback no longer rebuilds a lane with an unwired node.")
    }

    // MARK: 4 — counterweight: the start sites are the ones this guard reasons about

    func testTheSinkStillHasFourStartSites() throws {
        let sink = try code(Self.sink)
        XCTAssertEqual(occurrences(of: ".play()", in: sink), 4, """
            The sink's start sites changed. Each new `.play()` needs the wiring question before \
            it (crash 2624); then update this count.
            """)
    }
}

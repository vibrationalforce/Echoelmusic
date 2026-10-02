// ThePieceBouncesToAWavTests.swift
// Echoel — UX audit 2026-10-02, slice 10a: the whole piece can be written to a WAV, and only a
// piece that played to its END is written.
//
// WHAT IT GUARDS. `LoopExporter.exportPiece` plays the piece once from bar 1 with the song loop
// switched off and captures the master through the same RetroCapture tap the loop export uses.
// Three things make that honest, and each is a claim here: (a) the loop is switched off only for
// the take and restored however it ends; (b) the exporter never starts the song itself — the
// caller's door does, so `WorkstationView` keeps the ONE `player.play(` site; (c) a take the user
// stopped half-way is discarded, which needs the player to say WHY it stopped — `isPlaying` reads
// `false` after the end and after a Stop alike.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. `exportPiece` needs an `AudioEngine` and a
// running transport, which no test here can construct. It proves where the lines sit — never
// that the file sounds right, that the tail is long enough, or that a long piece survives a
// route change mid-take. Those are device probes. NEEDS-FOUNDER-VERIFY: Piece → export the piece
// as WAV → it plays once from bar 1 and stops; the shared file starts on bar 1, ends with the last
// release decaying (not cut), and has the length of the song. Stop it half-way → nothing is shared.
//
// GRADING (#433, parent = the tree before this slice): claims 1–4 are FORWARD guards — the parent
// has no `exportPiece` and no `lastStopReachedSongEnd` (measured: 0 occurrences of either in
// `Sources/`), so they are red there by the absence of one feature, reported four times (#486).
// Claims 5 and 6 are COUNTERWEIGHTS, green on both trees: the one SingleExport configuration and
// its load-bearing recording guard survive, and a song still loops by default. On the parent,
// claim 4 is red by absence too (the keys do not exist yet). Stripper `SourceText.codeOnly`:
// PROPHYLACTIC on all six (measured: 0 of 6 verdicts flip raw vs stripped on this tree) — kept
// because the player's own doc block names the flag and a future one could spell the writer.

import Foundation
import XCTest

final class ThePieceBouncesToAWavTests: XCTestCase {

    private static let exporter = "Sources/Echoelmusic/Audio/LoopExporter.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let exportHead = "public func exportPiece(engine: AudioEngine"
    private static let waitHead = "private func waitForPieceEnd(_ player: TimelineRegionPlayer)"
    private static let stepHead = "public func transportStep(_ step: Int) {"
    private static let playHead = "public func play(\n"

    // MARK: - Claim 1 — the loop is off for the take only, and the exporter does not start the song

    func testTheLoopIsOffForTheTakeAndTheDoorStartsIt() throws {
        let body = try self.body(of: Self.exportHead, in: try source(Self.exporter))
        guard let off = body.range(of: "player.loopEnabled = false"),
              let restore = body.range(of: "defer { player.loopEnabled = wasLooping }"),
              let start = body.range(of: "\n        start()\n") else {
            return XCTFail("ANCHOR MISSING: the loop switch, its `defer` restore or `start()` left `exportPiece` (#454)")
        }
        XCTAssertLessThan(off.lowerBound, start.lowerBound, "the loop is off before the piece starts")
        XCTAssertLessThan(restore.lowerBound, start.lowerBound,
                          "the restore is a `defer` registered before the start, so every exit restores it")
        XCTAssertFalse(body.contains("player.play("),
                       "the exporter never starts the song itself — `WorkstationView` owns the ONE `player.play(`")
        XCTAssertTrue(try source(Self.exporter).contains("player: TimelineRegionPlayer, start: @MainActor () -> Void,"),
                      "the start is the caller's door, handed in")
    }

    // MARK: - Claim 2 — only a piece that reached its end is written

    func testOnlyAFinishedPieceIsWritten() throws {
        let code = try source(Self.exporter)
        let wait = try body(of: Self.waitHead, in: code)
        XCTAssertTrue(wait.contains("return player.lastStopReachedSongEnd ? .reachedEnd : .stopped"),
                      "the wait asks the player WHY it stopped — `isPlaying` alone cannot tell the end from a Stop")
        let export = try body(of: Self.exportHead, in: code)
        guard let gate = export.range(of: "guard outcome == .reachedEnd else {"),
              let write = export.range(of: "await finishRecording(engine)") else {
            return XCTFail("ANCHOR MISSING: the outcome gate or the recording close left `exportPiece` (#454)")
        }
        XCTAssertLessThan(gate.lowerBound, write.lowerBound,
                          "a stopped, cancelled or too-long take is discarded BEFORE anything is written")
        XCTAssertTrue(export.contains("loopSeconds: nil"),
                      "the piece keeps its whole take — no bar-grid trim")
    }

    // MARK: - Claim 3 — the player says it reached the end, in one place, before it stops

    func testThePlayerSaysItReachedTheEnd() throws {
        let code = try source(Self.player)
        XCTAssertEqual(code.components(separatedBy: "lastStopReachedSongEnd = true").count - 1, 1,
                       "ONE writer of `true`: the end branch of `transportStep`")
        let step = try body(of: Self.stepHead, in: code)
        guard let mark = step.range(of: "lastStopReachedSongEnd = true"),
              let stop = step.range(of: "stop()", range: mark.upperBound..<step.endIndex) else {
            return XCTFail("ANCHOR MISSING: the end flag or the `stop()` after it left `transportStep` (#454)")
        }
        XCTAssertLessThan(mark.upperBound, stop.lowerBound, "the flag is set before the stop it explains")
        let play = try body(of: Self.playHead, in: code)
        XCTAssertTrue(play.contains("self.lastStopReachedSongEnd = false"),
                      "every take starts with the flag cleared, so an old end cannot vouch for a new Stop")
    }

    // MARK: - Claim 4 — the two new failure reasons are catalogue keys

    func testTheFailureReasonsAreKeys() throws {
        let code = try source(Self.exporter)
        for reason in ["The piece has nothing to play", "The piece is longer than one hour"] {
            XCTAssertTrue(code.contains(".failed(String(localized: \"\(reason)\"))"), "`\(reason)` is a key")
            XCTAssertFalse(code.contains(".failed(\"\(reason)\")"), "`\(reason)` is handed over verbatim")
        }
    }

    // MARK: - Claim 5 — COUNTERWEIGHT: one SingleExport configuration, one guarded close

    func testThePieceReusesTheOneRenderPath() throws {
        let code = try source(Self.exporter)
        XCTAssertEqual(code.components(separatedBy: "engine.singleExport.reset()").count - 1, 1,
                       "the piece goes through `renderTrimmed`, not a second SingleExport setup")
        XCTAssertTrue(code.contains("guard engine.retroCapture.isRecording else { return nil }"),
                      "the load-bearing guard in `finishRecording` is still there")
    }

    // MARK: - Claim 6 — COUNTERWEIGHT: a song still loops by default

    func testASongStillLoopsByDefault() throws {
        XCTAssertTrue(try source(Self.player).contains("public var loopEnabled = true"),
                      "only the bounce turns the loop off, and only for its take")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    private func body(of head: String, in code: String) throws -> String {
        guard let start = code.range(of: head),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "`\(head)` is gone (#454)")
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[open.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
    }

    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

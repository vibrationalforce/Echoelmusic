// ThePieceHasAWavDoorTests.swift
// Echoel — UX audit 2026-10-02, slice 10b: the piece's tab row carries a "WAV" door that bounces
// the whole song to audio and hands it to the share sheet.
//
// WHAT IT GUARDS. `PieceAudioExportTab` is the door to `LoopExporter.exportPiece` (slice 10a). The
// claims pin the shape that keeps it honest: it lives in the piece's tab row beside the MIDI
// export and behind the same skill gate; it starts the song through the ONE start
// (`WorkstationView.startSong`) and never `player.play(`; it is dim when the song cannot play (the
// same `songCanStart` the transport asks); it shares through `ShareLink`, so no modal joins any
// chain; it reads nothing hot in `body`; and a finished file is dropped the moment the song
// changes, so "Share WAV" never offers an older piece.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. The view is a SwiftUI struct no test bundle
// renders. It proves where the lines sit — never that the tile reads well at the narrowest width,
// that the share sheet opens, or that the file sounds right. NEEDS-FOUNDER-VERIFY: Piece (skill
// level that shows songs) → the tab row reads Arrange · Mix · Export · WAV; tap WAV → the piece
// plays once from bar 1 and the tile reads Stop; at the end it reads Share WAV and shares a .wav
// named after the project; edit a part → it reads WAV again.
//
// GRADING (#433, parent = the tree before this slice): claims 1–6 are FORWARD guards — the parent
// has no `PieceAudioExportTab` (measured: 0 occurrences in `Sources/`), so they are red there by
// one absence, reported six times (#486). Claim 7 is a COUNTERWEIGHT, green on both trees: the
// MIDI door is still the one `SongExportTab()`, still a `ShareLink`. Stripper `SourceText.codeOnly`:
// TRAGEND on claim 2 — the file's header names `player.play(` in prose (raw 1, stripped 0);
// PROPHYLACTIC on the others (measured).

import Foundation
import XCTest

final class ThePieceHasAWavDoorTests: XCTestCase {

    private static let tab = "Sources/Echoelmusic/Studio/PieceAudioExportTab.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let midiTab = "Sources/Echoelmusic/Studio/SongExportTab.swift"

    // MARK: - Claim 1 — one door, in the tab row, behind the songs gate, after the MIDI export

    func testTheDoorSitsBesideTheMIDIExport() throws {
        var mounts = 0
        for path in try swiftFiles() {
            mounts += try source(path).components(separatedBy: "PieceAudioExportTab()").count - 1
        }
        XCTAssertEqual(mounts, 1, "exactly one WAV door on the piece")
        let tabs = try body(of: "private var pieceTabs: some View {", in: try source(Self.workstation))
        guard let midi = tabs.range(of: "SongExportTab()"),
              let wav = tabs.range(of: "PieceAudioExportTab()"),
              let gate = tabs.range(of: "if level.showsSongs {", options: .backwards,
                                    range: tabs.startIndex..<midi.lowerBound) else {
            return XCTFail("ANCHOR MISSING: the MIDI door, the WAV door or their songs gate in `pieceTabs` (#454)")
        }
        XCTAssertLessThan(midi.upperBound, wav.lowerBound, "WAV follows the MIDI export")
        XCTAssertFalse(tabs[gate.upperBound..<wav.lowerBound].contains("}"),
                       "the WAV door sits inside the same songs gate as the MIDI export")
    }

    // MARK: - Claim 2 — it starts the song through the ONE start and asks the exporter

    func testItStartsThroughTheOneStart() throws {
        let code = try source(Self.tab)
        XCTAssertTrue(code.contains("exporter.exportPiece("), "the door asks the exporter")
        XCTAssertTrue(code.contains("WorkstationView.startSong(player: player"), "the song starts through the ONE start")
        XCTAssertTrue(code.contains("fromTick: 0, launching: [])"), "from bar 1, no scene")
        XCTAssertFalse(code.contains("player.play("), "the door never starts the player itself")
    }

    // MARK: - Claim 3 — dim when the song cannot play; Stop only for its own take

    func testItIsDimWhenThereIsNothingToPlay() throws {
        let code = try source(Self.tab)
        XCTAssertTrue(code.contains("WorkstationView.songCanStart(player: player, timeline: timeline, clipStore: clipStore)"),
                      "the same question the transport's Play asks — one predicate (#416)")
        XCTAssertTrue(code.contains(".disabled(!enabled)") && code.contains("enabled: enabled"),
                      "dim AND inert together — a lit door that does nothing is #164/#227")
        let tap = try body(of: "private func tap() {", in: code)
        guard let mine = tap.range(of: "if bouncing {"), let cancel = tap.range(of: "exporter.cancel()") else {
            return XCTFail("ANCHOR MISSING: the own-take branch or the cancel in `tap()` (#454)")
        }
        XCTAssertLessThan(mine.lowerBound, cancel.lowerBound, "only this tile's own take is stopped from here")
    }

    // MARK: - Claim 4 — the share sheet belongs to ShareLink; no modal

    func testItSharesWithoutAModal() throws {
        let code = try source(Self.tab)
        XCTAssertTrue(code.contains("ShareLink(item: bounced)"), "the finished file is shared through `ShareLink`")
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".fileExporter(", ".confirmationDialog("] {
            XCTAssertFalse(code.contains(modal), "`\(modal)` on the WAV door — the black-screen law forbids growing a chain")
        }
    }

    // MARK: - Claim 5 — nothing hot is read in the leaf

    func testItReadsNothingHot() throws {
        let code = try source(Self.tab)
        for hot in ["audioEngine.", "pattern.tempo", "transport.", "currentTick", "masterLevel"] {
            XCTAssertFalse(code.contains(hot), """
                `\(hot)` in the WAV door — it sits in the piece's tab row, an ancestor of the plate's \
                pickers; a hot read here is the 10.76.41/50 freeze
                """)
        }
    }

    // MARK: - Claim 6 — a finished file never outlives the song it was made from

    func testAStaleFileIsDropped() throws {
        XCTAssertTrue(try source(Self.tab).contains(".onChange(of: timeline.document) { _, _ in bounced = nil }"),
                      "an edit drops the finished file, so Share WAV never offers an older piece")
    }

    // MARK: - Claim 7 — COUNTERWEIGHT: the MIDI door is untouched

    func testTheMIDIDoorIsUntouched() throws {
        XCTAssertTrue(try source(Self.midiTab).contains("ShareLink(item: file, preview: SharePreview(file.name))"),
                      "the MIDI export is still a ShareLink")
        XCTAssertEqual(try source(Self.workstation).components(separatedBy: "SongExportTab()").count - 1, 1,
                       "still one MIDI door")
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

    private func swiftFiles() throws -> [String] {
        let root = try repoRoot()
        guard let walker = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"),
                                                          includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "cannot enumerate Sources/")
        }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            out.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        XCTAssertGreaterThan(out.count, 100, "the walk over Sources/ returned almost nothing — a scan that matches nothing is a finding, never a pass")
        return out
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}

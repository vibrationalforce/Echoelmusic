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
// GRADING (#433, parent = the tree before this slice): claims 1–6 and 8 are FORWARD guards — the
// parent has no `PieceAudioExportTab` (measured: 0 occurrences in `Sources/`), so they are red
// there by one absence, reported seven times (#486). Claim 7 is a COUNTERWEIGHT, green on both
// trees: the MIDI door is still the one `SongExportTab()`, still a `ShareLink`. Claims 6 and 8 were
// rewritten by the review repair (state moved onto `LoopExporter`); against 387e64bf6 claim 6's
// new needles and claim 8 are red — the regression they exist for. Stripper `SourceText.codeOnly`:
// TRAGEND on claims 2 and 8 — the header names `player.play(` and `@State` in prose; PROPHYLACTIC
// on the others (measured).
// ⛔ The first version's `body(of:)` searched for the brace AFTER the head, so a head that ENDS in
// `{` returned the first block inside the member, not the member — claim 3 was red on correct
// code (found by the review, by running the helper on this tree). It now searches from the head's
// start.

import Foundation
import XCTest

final class ThePieceHasAWavDoorTests: XCTestCase {

    private static let tab = "Sources/Echoelmusic/Studio/PieceAudioExportTab.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let midiTab = "Sources/Echoelmusic/Studio/SongExportTab.swift"

    // MARK: - Claim 1 — one door, on the Project plate, after the MIDI export (S2; before: the tab row's songs gate)

    func testTheDoorSitsBesideTheMIDIExport() throws {
        var mounts = 0
        for path in try swiftFiles() {
            mounts += try source(path).components(separatedBy: "PieceAudioExportTab()").count - 1
        }
        XCTAssertEqual(mounts, 1, "exactly one WAV door on the piece")
        // DAW shell S2 (founder 2026-10-02, E18/E19): both doors live on the Project plate, at every
        // level — beside each other in one row, the WAV door after the MIDI one.
        let workstation = try source(Self.workstation)
        let project = try body(of: "private var projectPlate: some View {", in: workstation)
        guard let midi = project.range(of: "SongExportTab()"),
              let wav = project.range(of: "PieceAudioExportTab()"),
              let row = project.range(of: "HStack(spacing: 6) {", options: .backwards,
                                      range: project.startIndex..<midi.lowerBound) else {
            return XCTFail("ANCHOR MISSING: the MIDI door, the WAV door or their row on the Project plate (#454)")
        }
        XCTAssertLessThan(midi.upperBound, wav.lowerBound, "WAV follows the MIDI export")
        XCTAssertFalse(project[row.upperBound..<wav.lowerBound].contains("}"),
                       "the WAV door sits in the same row as the MIDI export")
        XCTAssertFalse(project.contains("showsSongs"), "no level gate on the Project plate (E19)")
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
        let code = try source(Self.tab)
        XCTAssertTrue(code.contains(".onChange(of: timeline.document) { _, _ in exporter.lastPieceFile = nil }"),
                      "an edit drops the finished file, so Share WAV never offers an older piece")
        XCTAssertTrue(code.contains(".onChange(of: loudnessTargetRaw) { _, _ in exporter.lastPieceFile = nil }"),
                      "so does a new loudness target — the file was normalised to the old one")
    }

    // MARK: - Claim 7 — COUNTERWEIGHT: the MIDI door is untouched

    func testTheMIDIDoorIsUntouched() throws {
        XCTAssertTrue(try source(Self.midiTab).contains("ShareLink(item: file, preview: SharePreview(file.name))"),
                      "the MIDI export is still a ShareLink")
        XCTAssertEqual(try source(Self.workstation).components(separatedBy: "SongExportTab()").count - 1, 1,
                       "still one MIDI door")
    }

    // MARK: - Claim 8 — the bounce state is the exporter's, so it survives a stage switch

    func testTheBounceStateLivesOnTheExporter() throws {
        let code = try source(Self.tab)
        XCTAssertFalse(code.contains("@State"), """
            the Piece stage is unmounted on a switch to the Instrument; bounce state held in `@State` \
            here came back unable to stop its own take and dropped the finished file (review of slice 10)
            """)
        XCTAssertTrue(code.contains("exporter.pieceTakeInFlight") && code.contains("exporter.lastPieceFile")
                      && code.contains("exporter.lastPieceFailure"),
                      "in flight, the finished file and the last failure are read from the exporter")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    private func body(of head: String, in code: String) throws -> String {
        guard let start = code.range(of: head),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
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

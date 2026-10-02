// TheAddMenuHoldsTheCreationDoorsTests.swift
// Echoel — UX audit 2026-10-02, slice 4: once the piece has a track, the five creation doors live
// in ONE "Add" menu in the piece's tab row; the empty plate keeps the doors themselves.
//
// WHY. Five full-width buttons (Add Audio Track · Import Audio · Add MIDI Track · Import MIDI ·
// New MIDI Part) stood under the arrangement on every piece and pushed the song down a phone
// screen — the founder's "Vermeide, dass es unübersichtlich ist". A professional workstation
// keeps creation behind one "+" and gives the screen to the music. The empty plate is the
// exception on purpose: its sentence names the doors by label, so there they stay visible.
//
// THE FOUR CLAIMS.
// 1. The tab row mounts `addMenu` once, behind `if !WorkstationSummary(document: timeline.document)
//    .isEmpty {` — the same predicate `body` uses for the empty plate (#416) — and AFTER the songs
//    gate, not inside it: the doors it replaces stand at every skill level.
// 2. ONE BODY PER ACTION (#416): each menu item and its door call the same function
//    (`addAudioTrack()`, `openImporter(.audio)`, `addMIDITrack()`, `openImporter(.midi)`,
//    `newMIDIPart()`), the items keep the doors' words in the doors' order, and the transaction
//    and the importer flag are each written exactly once in the file.
// 3. The doors stand only on the empty plate: `body` opens their block with `if summary.isEmpty {`,
//    the predicate the empty state is shown under.
// 4. COUNTERWEIGHTS: the menu is no modal (black-screen law); it shows and speaks the word "Add";
//    it reads nothing hot (it sits in the pinned tab row, an ancestor of the plate's pickers); and
//    the empty plate's sentence names "Add", since that is where the doors go next.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. `WorkstationView` is a SwiftUI struct no test
// bundle renders. It proves where the lines sit — never that the menu opens under a finger, that
// a pick from it presents the file importer, or that the tile reads well at the narrowest width.
// NEEDS-FOUNDER-VERIFY: Piece → a new piece shows the five doors under "No tracks yet" and no Add
// tile; tap Add Audio Track → the doors go, an "Add" tile appears at the end of the tab row; tap
// it → Add Audio Track · Import Audio, then Add MIDI Track · Import MIDI · New MIDI Part; Import
// Audio from the menu opens the Files picker and the result line reads under the song as before.
//
// GRADING (#433, parent = the tree before this slice): claims 1 and 2 are FORWARD guards — the
// parent has no `addMenu`, `addAudioTrack()` or `openImporter(` (measured: 0 occurrences of each in
// `Sources/`), so they are red there by ONE absence, reported in two claims (#486). Claim 3 is a
// REGRESSION guard: on the parent the doors' block has no gate (red for its named reason). Claim 4
// is red on the parent only by the same absence, plus its last needle ("Add holds") is red there
// for its named reason (the sentence promised "its own Import button" per track). Stripper
// `SourceText.codeOnly`: PROPHYLACTIC on all four (measured: 0 verdicts flip raw vs stripped on
// this tree) — kept because this file's own header and the view's comments name the needles.

import Foundation
import XCTest

final class TheAddMenuHoldsTheCreationDoorsTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    /// Door member, the action it calls, and the word the menu item must show — in mount order.
    private static let doors: [(member: String, action: String, word: String)] = [
        ("addTrackRow", "addAudioTrack()", "Add Audio Track"),
        ("importRow", "openImporter(.audio)", "Import Audio"),
        ("addMIDITrackRow", "addMIDITrack()", "Add MIDI Track"),
        ("importMIDIRow", "openImporter(.midi)", "Import MIDI"),
        ("newMIDIPartRow", "newMIDIPart()", "New MIDI Part"),
    ]

    // MARK: - Claim 1 — one Add menu, in the tab row, behind the same empty predicate, every level

    func testTheTabRowCarriesOneAddMenuOnceThePieceHasATrack() throws {
        let code = try source(Self.workstation)
        let lines = code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(lines.filter { $0 == "addMenu" }.count, 1, "the Add menu is mounted exactly once")
        let tabs = try body(of: "private var pieceTabs: some View {", in: code)
        guard let gate = tabs.range(of: "if !WorkstationSummary(document: timeline.document).isEmpty {"),
              let mount = tabs.range(of: "addMenu", range: gate.upperBound..<tabs.endIndex),
              let wav = tabs.range(of: "PieceAudioExportTab()") else {
            return XCTFail("ANCHOR MISSING: the Add menu, its empty-piece gate or the WAV door in `pieceTabs` (#454)")
        }
        XCTAssertTrue(tabs[gate.upperBound..<mount.lowerBound].allSatisfy(\.isWhitespace),
                      "the menu sits directly inside its gate — shown once the piece is not empty")
        XCTAssertLessThan(wav.upperBound, gate.lowerBound, "Add is the last tile of the row")
        let between = tabs[wav.upperBound..<gate.lowerBound]
        XCTAssertTrue(between.contains("}"), """
            the Add menu sits OUTSIDE the songs gate the exports share — the five doors it replaces \
            stand at every skill level, so hiding Add at a lower level would leave a piece with tracks \
            and no way to add another
            """)
        XCTAssertTrue(code.contains("let summary = WorkstationSummary(document: timeline.document)"),
                      "`body` builds its summary from the same document — one predicate, `isEmpty` (#416)")
    }

    // MARK: - Claim 2 — one body per action: door and menu item call the same function

    func testEachMenuItemAndItsDoorShareOneAction() throws {
        let code = try source(Self.workstation)
        let menu = try body(of: "private var addMenu: some View {", in: code)
        var cursor = menu.startIndex
        for door in Self.doors {
            let row = try body(of: "private var \(door.member): some View {", in: code)
            XCTAssertTrue(row.contains(door.action), "`\(door.member)` calls `\(door.action)` — the menu's action (#416)")
            guard let item = menu.range(of: "{ \(door.action) } label: { Label(\"\(door.word)\"",
                                        range: cursor..<menu.endIndex) else {
                XCTFail("""
                    the Add menu has no item `\(door.word)` calling `\(door.action)` after the previous \
                    one — the items keep the doors' words and order, which the refusals name
                    """)
                continue
            }
            cursor = item.upperBound
        }
        XCTAssertEqual(code.components(separatedBy: "AudioImport.addAudioTrack(timeline: timeline)").count - 1, 1,
                       "the audio-track transaction is written once, in `addAudioTrack()`")
        XCTAssertEqual(code.components(separatedBy: "importPresented = true").count - 1, 1,
                       "the importer is opened in one place, `openImporter(_:)`")
        let opener = try body(of: "private func openImporter(_ kind: ImportKind) {", in: code)
        for line in ["importNote = nil", "tuningPending = nil", "importKind = kind", "importPresented = true"] {
            XCTAssertTrue(opener.contains(line), "`openImporter` still does what the two Import doors did: `\(line)`")
        }
    }

    // MARK: - Claim 3 — the doors stand only on the empty plate

    func testTheDoorsStandOnlyOnTheEmptyPlate() throws {
        let code = try source(Self.workstation)
        let view = try body(of: "var body: some View {", in: code)
        guard let empty = view.range(of: "if summary.isEmpty {"),
              let shown = view.range(of: "emptyState", range: empty.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: the empty plate under `if summary.isEmpty {` (#454)")
        }
        XCTAssertTrue(view[empty.upperBound..<shown.lowerBound].allSatisfy(\.isWhitespace),
                      "the empty state is what `summary.isEmpty` shows — the predicate the doors share")
        guard let gate = view.range(of: "if summary.isEmpty {", range: shown.upperBound..<view.endIndex),
              let pair = view.range(of: "creationPair {", range: gate.upperBound..<view.endIndex) else {
            return XCTFail("""
                the creation doors are not behind `if summary.isEmpty {` — on a piece with tracks they \
                stand under the song AND in the Add menu: two doors to each action on one screen
                """)
        }
        XCTAssertTrue(view[gate.upperBound..<pair.lowerBound].allSatisfy(\.isWhitespace),
                      "the doors' block opens directly with the first pair")
    }

    // MARK: - Claim 4 — counterweights: no modal, a word, nothing hot, the empty plate names Add

    func testTheMenuIsAWordNotAModalAndReadsNothingHot() throws {
        let code = try source(Self.workstation)
        let menu = try body(of: "private var addMenu: some View {", in: code)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".fileImporter(", ".confirmationDialog("] {
            XCTAssertFalse(menu.contains(modal), "`\(modal)` in the Add menu — the black-screen law forbids growing a chain")
        }
        XCTAssertTrue(menu.contains("title: \"Add\""), "the tile shows the word Add")
        XCTAssertTrue(menu.contains(".accessibilityLabel(\"Add\")"), "and says the same word to VoiceOver")
        for hot in ["player.", "transport.", "metronome.", "cameraRPPG", "bus.", "audioEngine."] {
            XCTAssertFalse(menu.contains(hot), """
                `\(hot)` in the Add menu — it sits in the pinned tab row, an ancestor of the plate's \
                pickers; a hot read here closes the open menu (the 10.76.41/50 freeze)
                """)
        }
        let plate = try body(of: "private var emptyState: some View {", in: try rawSource(Self.workstation))
        XCTAssertTrue(plate.contains("Add holds"), """
            the empty plate no longer says where the doors go once a track exists — it named "its own \
            Import button" per track before slice 4, which stopped being true
            """)
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

    private func rawSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}

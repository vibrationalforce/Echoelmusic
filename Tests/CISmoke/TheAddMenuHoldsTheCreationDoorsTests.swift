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
// THE FIVE CLAIMS.
// 1. The tab row mounts `addMenu` once, behind `if pieceView == .arrange && hasTrack {`, where
//    `hasTrack` is `!WorkstationSummary(document: timeline.document).isEmpty` — the same predicate
//    `body` uses for the empty plate (#416) — and behind no level gate: the doors it replaces
//    stand at every skill level. (DAW shell S2, 2026-10-02: the row is now the Arrange plate's
//    toolbar; the songs gate and the exports it held moved to the Project plate.)
// 2. ONE BODY PER ACTION (#416): each menu item and its door call the same function
//    (`addAudioTrack()`, `openImporter(.audio)`, `addMIDITrack()`, `openImporter(.midi)`,
//    `newMIDIPart()`), the items keep the doors' words in the doors' order, and the transaction
//    and the importer flag are each written exactly once in the file.
// 3. The doors stand only on the empty plate: `body` opens their block with `if summary.isEmpty {`,
//    the predicate the empty state is shown under.
// 4. COUNTERWEIGHTS: the menu is no modal (black-screen law); it shows and speaks the word "Add";
//    it reads nothing hot (it sits in the pinned tab row, an ancestor of the plate's pickers); and
//    the empty plate's sentence no longer promises "its own Import button" per track.
// 5. REVIEW OF fe04ad196 (MED): the one note line follows the doors — under them on the empty
//    plate, under the Add tile in the pinned tab row once the piece has a track, with the same
//    predicate, so a menu refusal is said where the tap was and never twice. "Add Audio Track"
//    selects and names the track it made, because from the menu it lands off screen.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. `WorkstationView` is a SwiftUI struct no test
// bundle renders. It proves where the lines sit — never that the menu opens under a finger, that
// a pick from it presents the file importer, or that the tile reads well at the narrowest width.
// NEEDS-FOUNDER-VERIFY: Piece → a new piece shows the five doors under "No tracks yet" and no Add
// tile; tap Add Audio Track → the doors go, an "Add" tile appears at the end of the tab row; tap
// it → Add Audio Track · Import Audio, then Add MIDI Track · Import MIDI · New MIDI Part; Import
// Audio from the menu opens the Files picker and the result line reads directly under the tab row
// (the Add tile), with an × that clears it; Add Audio Track from the menu selects the new track and
// names it there. At song level the row holds five tiles (Arrange · Mix · Export · WAV · Add) — on
// a 375 pt phone check that every word still reads.
//
// REVIEW REPAIR (fe04ad196 → its repair): claim 1's gate became `if hasTrack {`; claim 4's last
// needle ("Add holds") was the recipe the review found, replaced by the absence of the old false
// promise; claim 5 is new — against fe04ad196 it is red for its named reason (the note line sat
// outside the doors' block, and nothing under the Add tile could say a thing).
//
// GRADING (#433, parent = the tree before this slice): claims 1 and 2 are FORWARD guards — the
// parent has no `addMenu`, `addAudioTrack()` or `openImporter(` (measured: 0 occurrences of each in
// `Sources/`), so they are red there by ONE absence, reported in two claims (#486). Claim 3 is a
// REGRESSION guard: on the parent the doors' block has no gate (red for its named reason). Claim 4
// is red on the parent only by the same absence, plus its last needle is red there for its named
// reason (the sentence promised "its own Import button" per track). Claim 5 is red on the parent
// by the absence of `pinnedNoteLine` and of the doors' gate (one absence). Stripper
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

    // MARK: - Claim 1 — one Add menu, in the Arrange plate's tab row, behind the same empty predicate, every level

    func testTheTabRowCarriesOneAddMenuOnceThePieceHasATrack() throws {
        let code = try source(Self.workstation)
        let lines = code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(lines.filter { $0 == "addMenu" }.count, 1, "the Add menu is mounted exactly once")
        let tabs = try body(of: "private var pieceTabs: some View {", in: code)
        XCTAssertTrue(tabs.contains("let hasTrack = !WorkstationSummary(document: timeline.document).isEmpty"),
                      "the tab row's gate is the empty plate's predicate, negated (#416)")
        // DAW shell S2 (founder 2026-10-02, E18): the tab row is the ARRANGE plate's toolbar — the
        // switcher at the bottom took the Arrange/Mix tiles, the Project plate took both exports.
        // The gate is the empty predicate plus the plate, and nothing else: no level, no songs gate.
        guard let gate = tabs.range(of: "if pieceView == .arrange && hasTrack {"),
              let mount = tabs.range(of: "addMenu", range: gate.upperBound..<tabs.endIndex) else {
            return XCTFail("ANCHOR MISSING: the Add menu or its gate in `pieceTabs` (#454)")
        }
        let lead = SourceText.codeOnly(String(tabs[gate.upperBound..<mount.lowerBound]))
        XCTAssertFalse(lead.contains("if ") || lead.contains("ForEach"), """
            a second condition between the gate and the Add menu — Add is shown whenever the \
            arrangement has a track, and only then
            """)
        for gateWord in ["showsSongs", "skillLevel", "SkillLevel", "PieceAudioExportTab()", "SongExportTab()"] {
            XCTAssertFalse(tabs.contains(gateWord), """
                `\(gateWord)` in the tab row. The doors Add replaces stand at every skill level, so a \
                level gate here would leave a piece with tracks and no way to add another; the exports \
                live on the Project plate (E19)
                """)
        }
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
        XCTAssertFalse(plate.contains("its own Import button"), """
            the empty plate promises "its own Import button" per track again — since slice 4 a \
            track brings no button; every import is in the Add menu
            """)
    }

    // MARK: - Claim 5 — the note line is said where the tap was, once

    func testTheNoteLineFollowsTheDoors() throws {
        let code = try source(Self.workstation)
        let view = try body(of: "var body: some View {", in: code)
        guard let doors = try? body(of: "if summary.isEmpty {\n                creationPair {", in: view) else {
            return XCTFail("ANCHOR MISSING: the doors' block in `body` (#454)")
        }
        XCTAssertTrue(doors.contains("if let note = importNote { importNoteLine(note) }"), """
            the note line is not inside the doors' block — on a piece with tracks it would stand a \
            screen below the Add tile that was tapped, so a refusal reads as a tap that did nothing
            """)
        let tabs = try body(of: "private var pieceTabs: some View {", in: code)
        // S2: the pinned note sits INSIDE the Add menu's gate, under the Add row — same predicate.
        guard let gate = tabs.range(of: "if pieceView == .arrange && hasTrack {"),
              let pinned = tabs.range(of: "if let note = importNote {", range: gate.upperBound..<tabs.endIndex),
              let line = tabs.range(of: "pinnedNoteLine(note)", range: pinned.upperBound..<tabs.endIndex) else {
            return XCTFail("the tab row does not say the Add menu's outcome under the Add tile")
        }
        XCTAssertTrue(tabs[pinned.upperBound..<line.lowerBound].allSatisfy(\.isWhitespace))
        XCTAssertEqual(code.components(separatedBy: "importNoteLine(note)").count - 1, 2,
                       "two places, one predicate (`isEmpty` / `hasTrack`), never both on screen")
        let pinnedLine = try body(of: "private func pinnedNoteLine(_ note: String) -> some View {", in: code)
        XCTAssertTrue(pinnedLine.contains("importNote = nil"), "the pinned line can be dismissed — the row keeps its height")
        XCTAssertTrue(pinnedLine.contains(".accessibilityLabel(\"Dismiss\")"))
        let add = try body(of: "private func addAudioTrack() {", in: code)
        XCTAssertTrue(add.contains("selection.selectTrack(added.id)")
                      && add.contains("importNote = MIDIImport.addedTrackNote(laneName: added.name)"), """
            "Add Audio Track" from the menu appends a track below, often off screen — it must select \
            it and name it on the note line, as "Add MIDI Track" does
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

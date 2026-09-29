// WriteNotesOpensTheNoteEditorTests.swift
// Echoel — DMMW Phase 2 · slice 1 (founder 2026-09-29, "Selbstkomposition ohne versteckte
// Schritte … 'Write notes' muss den Noten-Editor automatisch öffnen").
//
// WHAT IT PINS. Until this slice the note grid's open/closed switch was `@State` inside
// `PartNoteEditor`, so nothing but that switch could open it. The compose guide's "Write notes"
// selected a part and then said "Tap Notes to write into it" — a hidden step; "New MIDI Part"
// said the same. The switch now lives on the ONE selection owner (`WorkstationSelection
// .notesOpen`), and both doors open it.
//
// 1. END-TO-END BEHAVIOUR over the shipped owner: closed by default; the one setter opens and
//    closes it; it survives a change of part (the editor's old behaviour — it stayed mounted, so
//    did its switch); the owner stays unsaved (no `Codable` — pinned by
//    `TheWorkstationHasOneSelectionTests`, counterweight here).
// 2. END-TO-END BEHAVIOUR over `ComposeGuide`: the "Write notes" line promises the open, never
//    "Tap Notes"; the card's sentence after the tap says where the grid is; the New MIDI Part
//    sentence does the same and keeps what it already said (#343 counterweight).
// 3. SOURCE-TEXT SCAN (the members are `private` on `View`s): the editor keeps no switch of
//    its own and reads/writes the owner's; the guide's "Write notes" selects the part THEN opens
//    it; "New MIDI Part" selects its part THEN opens it; nothing else writes the switch.
//
// GRADING (§3). Against the parent (`09d35f56e`) this file does NOT COMPILE — `notesOpen`,
// `setNotesOpen` and `ComposeGuide.notesOpenedNote` are new — so no assertion has a verdict
// there: ONE absence (#486), every claim a FORWARD guard. Counterweights green on both trees
// if isolated: the part bar's selection needle, the empty-part note's "once it has notes".
// Transcribed in Python against THIS tree (no toolchain here): each scan needle found exactly
// where claimed; the writer census found the two files named.
//
// ⛔ HONEST LIMIT: nothing here proves the grid is VISIBLE after the tap — on a phone it sits
// under the canvas and may be below the fold; the card says where. DEVICE PROBE, open.
// NEEDS-FOUNDER-VERIFY: Workstation → Create a piece → steps 1–3: after "Write notes" the note
// grid is open under the arrangement without tapping "Notes"; VoiceOver reads the card's line.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class WriteNotesOpensTheNoteEditorTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: - 1. the owner

    func testTheNotesSwitchLivesOnTheOneSelectionOwner() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let first = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0,
                                   lengthTicks: TimelineTime.ticksPerBar)
        let second = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: TimelineTime.ticksPerBar,
                                    lengthTicks: TimelineTime.ticksPerBar)
        let document = TimelineDocument(lanes: [keys], regions: [first, second])

        let selection = WorkstationSelection()
        XCTAssertFalse(selection.notesOpen, "a fresh Workstation shows the switch closed, as before")
        selection.selectRegion(first.id, in: document)
        selection.setNotesOpen(true)
        XCTAssertTrue(selection.notesOpen)
        selection.selectRegion(second.id, in: document)
        XCTAssertTrue(selection.notesOpen, "choosing another part keeps the grid open — the old editor did")
        selection.setNotesOpen(false)
        XCTAssertFalse(selection.notesOpen, "the switch still closes it")
    }

    // MARK: - 2. the words promise what the tap does

    func testTheGuideAndTheNewPartSayTheNotesAreOpen() {
        let facts = ComposeGuide.Facts(hasMIDITrack: true, hasPart: true, hasNotes: false,
                                       canPlay: false, isPlaying: false, canSave: true)
        XCTAssertEqual(ComposeGuide.state(of: .notes, facts), .next, "fixture premise: step 3 is the next step")
        let detail = ComposeGuide.detail(.notes, facts)
        XCTAssertFalse(detail.contains("Tap Notes"), "the hidden step is gone — the tap opens the notes itself")
        XCTAssertTrue(detail.hasPrefix("Opens the part's notes"), "the line says what the tap does: \(detail)")

        XCTAssertTrue(ComposeGuide.notesOpenedNote.contains("under the arrangement"),
                      "on a phone the grid can be off screen — the card says where it opened")

        let note = MIDIImport.emptyPartNote(laneName: "Keys", atSongStart: true, notOnSelected: nil)
        XCTAssertFalse(note.contains("Tap Notes"), "New MIDI Part opens the notes too")
        XCTAssertTrue(note.contains("Its notes are open under the arrangement"))
        XCTAssertTrue(note.contains("once it has notes"), "what an empty part does not do yet stays said (M1b review)")
    }

    // MARK: - 3. the doors run the owner's setter, and only they do

    func testTheEditorAndBothDoorsUseTheOwnersSwitch() throws {
        let editor = try source(Self.editor)
        let switchView = try member("struct PartNoteEditor: View {", in: editor)
        XCTAssertFalse(switchView.contains("@State private var isOpen"),
                       "a private switch is exactly what no door could open")
        XCTAssertTrue(switchView.contains("let isOpen = selection.notesOpen"))
        XCTAssertTrue(switchView.contains("Button { selection.setNotesOpen(!isOpen) } label: {"),
                      "the editor's own switch writes the owner, not a copy")

        let view = try source(Self.view)
        let guide = try member("private var composeGuide: some View {", in: view)
        let select = try XCTUnwrap(guide.range(of: "selection.selectRegion(id, in: timeline.document)"),
                                   "\"Write notes\" no longer selects the part (ThePlateShowsHowAPieceIsMadeTests)")
        let open = try XCTUnwrap(guide.range(of: "selection.setNotesOpen(true)"),
                                 "\"Write notes\" must open the notes — the founder's order")
        XCTAssertLessThan(select.lowerBound, open.lowerBound, "select the part, THEN open its notes")
        XCTAssertTrue(guide.contains("guideNote = ComposeGuide.notesOpenedNote"), "the card says where the grid opened")

        let newPart = try member("private func newMIDIPart() {", in: view)
        let landed = try XCTUnwrap(newPart.range(of: "selection.selectRegion(landing.region.id, in: timeline.document)"))
        let opened = try XCTUnwrap(newPart.range(of: "selection.setNotesOpen(true)"),
                                   "New MIDI Part must open the part it made")
        XCTAssertLessThan(landed.lowerBound, opened.lowerBound)

        XCTAssertEqual(try filesUnderSources(containing: "setNotesOpen("),
                       ["Studio/PartNoteEditor.swift", "Studio/WorkstationSelection.swift",
                        "Studio/WorkstationView.swift"],
                       "a new writer of the notes switch must be named here (the owner declares it)")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor` (§2, #408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
            throw AnchorMissing()
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}

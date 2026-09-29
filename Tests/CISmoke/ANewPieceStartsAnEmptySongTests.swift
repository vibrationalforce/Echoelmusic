// ANewPieceStartsAnEmptySongTests.swift
// Echoel — DMMW Phase 5 · slice 1 (founder 2026-09-29: "Neues Stück → Instrument/Spur → Part →
// Noten → … → Speichern/Wiederöffnen"). The flow had no first step: the Library could only open
// what was saved, so a player could not start an empty song without deleting parts by hand. The
// Library sheet now carries a "New piece" row.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR over `SessionSaveOpen.emptySong`: ONE definition of "the empty song"
//    (#416) — the same song a project saved before Sessions opens into (`restoreSong`'s
//    `.absent` branch): the default MIDI and audio track, no parts, an empty clip grid.
// 2. END-TO-END over a real `TimelineStore` + `ClipStore`: a song with a written part is
//    replaced by the empty song, the grid is emptied, there is no Undo back (a replacement is
//    not an edit), and the Compose guide's next step is Part — the flow's next step.
// 3. END-TO-END over a real `ProjectStore`: after "New piece" the header names nothing
//    (`clearCurrent`), and nothing in the library is deleted.
// 4. SOURCE: the action rescues FIRST (`autosaveTake()`, the rescue Open runs), then replaces,
//    and only a replacement that happened clears the name; it re-states the song's Echoel
//    instance exactly as Open does; it reaches Compose through the AREA door (never a direct
//    plate assignment — `TheWorkstationHasADoorTests`); the row is mounted inside `openSheet`
//    (no presentation modifier), 44 pt, and its hint IS its footer (#416).
//
// GRADING (§3). Against the parent this file does NOT COMPILE — `emptySong`, `startEmptySong`
// and `clearCurrent` are new — so no assertion has a verdict there: ONE absence (#486), every
// claim a FORWARD guard. Counterweights (#343), green in intent on both trees: the Compose
// area's home is the Workstation (so "opens Compose" is a true sentence), the refused note has a
// place to render, and no direct `activeMenu =` is written by the action. Transcribed in Python
// against THIS tree (no toolchain here): the lane shape of `migrate(sections: [])`, the guide's
// part step, and every scan needle.
//
// ⛔ HONEST LIMITS. "The song you had is kept in Autosave" rests on `autosaveTake()`, which
// writes only when there is something worth keeping (a user part or a composed take) and keeps
// the richer of slot and live per half (`recoveryRow`) — a song with nothing in it is not saved
// because there is nothing to lose. The refusal branch (`replaceSlots` false) cannot be driven:
// `emptySong` always carries `slotCount` slots; it is defensive. The instrument's take, genre and
// sound are untouched on purpose. Whether the row reads well and VoiceOver speaks it is a device
// probe. NEEDS-FOUNDER-VERIFY: Library → New piece → Compose opens on an empty song with
// "MIDI 1" and "Audio 1"; Library again → the old song is under Autosave and opens back.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ANewPieceStartsAnEmptySongTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let saveOpenPath = "Sources/Echoelmusic/Core/SessionSaveOpen.swift"

    private static let take = Project(
        name: "Old piece", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 120,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "",
        patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
        drumSteps: [], drumAccents: [])

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    // MARK: 1 — one definition of the empty song

    func testTheEmptySongIsWhatAProjectWithoutASessionOpensInto() {
        let empty = SessionSaveOpen.emptySong
        XCTAssertEqual(empty.document.lanes.map(\.name), ["MIDI 1", "Audio 1"])
        XCTAssertEqual(empty.document.lanes.map(\.kind), [.midi, .audio])
        XCTAssertTrue(empty.document.regions.isEmpty, "no parts")
        XCTAssertEqual(empty.slots.count, ClipStore.slotCount, "a grid the store accepts")
        XCTAssertTrue(empty.slots.allSatisfy { $0 == nil }, "an empty grid")

        // The same song Open gives a project saved before Sessions (#416).
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        XCTAssertNil(Self.take.sessionEnvelope, "ANCHOR: the fixture carries no Session")
        XCTAssertTrue(SessionSaveOpen.restoreSong(of: Self.take, timeline: timeline, clips: clips,
                                                  player: TimelineRegionPlayer()))
        XCTAssertEqual(timeline.document.lanes.map(\.name), empty.document.lanes.map(\.name))
        XCTAssertEqual(timeline.document.lanes.map(\.kind), empty.document.lanes.map(\.kind))
        XCTAssertEqual(timeline.document.regions, empty.document.regions)
        XCTAssertEqual(clips.slots, empty.slots)
    }

    // MARK: 2 — on the real stores

    func testANewPieceReplacesAWrittenSong() {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        timeline.replaceDocument(TimelineDocument(lanes: [TimelineLane(name: "Keys", kind: .midi)], regions: []))
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))
        guard case .success(let landing) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline,
                                                                   selectedTrack: nil, voiceCapacity: 0) else {
            return XCTFail("ANCHOR: the old song needs a written part")
        }
        XCTAssertTrue(SessionSaveOpen.songHasUserParts(timeline.document, clips: clips.filledClips),
                      "premise: the song being replaced holds the player's own part")
        let player = TimelineRegionPlayer()

        XCTAssertTrue(SessionSaveOpen.startEmptySong(timeline: timeline, clips: clips, player: player))

        XCTAssertEqual(timeline.document.lanes.map(\.name), ["MIDI 1", "Audio 1"])
        XCTAssertFalse(timeline.document.regions.contains { $0.id == landing.region.id }, "the old part is gone")
        XCTAssertTrue(timeline.document.regions.isEmpty)
        XCTAssertTrue(clips.slots.allSatisfy { $0 == nil }, "the old part's clip is gone from the grid")
        XCTAssertFalse(timeline.canUndo, "a new piece is not an edit — no Undo back into the old song")
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(SessionSaveOpen.songHasUserParts(timeline.document, clips: clips.filledClips))

        let facts = ComposeGuide.facts(document: timeline.document, clips: clips.filledClips,
                                       canPlay: false, isPlaying: false)
        XCTAssertEqual(ComposeGuide.nextStep(facts), .part,
                       "the empty song has its MIDI track; the flow's next step is a part")
    }

    // MARK: 3 — the header names nothing, the library keeps everything

    func testANewPieceNamesNothingAndDeletesNothing() throws {
        let disk = AppGroupStore(subdirectory: "NewPiece-\(UUID().uuidString)")
        defer { disk.delete(name: "projects.json") }
        let library = ProjectStore(store: disk)
        library.save(Self.take)
        XCTAssertEqual(ProjectTransport.projectName(library.currentProjectName), "Old piece",
                       "premise: after Save the header names the piece")
        let before = library.projects.map(\.id)

        library.clearCurrent()

        XCTAssertEqual(ProjectTransport.projectName(library.currentProjectName), ProjectTransport.unsavedName)
        XCTAssertEqual(library.projects.map(\.id), before, "clearing the name deletes nothing")
        let reloaded = ProjectStore(store: disk)
        XCTAssertTrue(reloaded.projects.contains { $0.id == Self.take.id }, "the old piece is still on disk")
    }

    // MARK: 4 — source: rescue, then replace, through the owners

    func testTheActionRescuesFirstAndOpensComposeThroughTheAreaDoor() throws {
        let code = try source(Self.studioPath)
        let action = try member("private func startNewPiece() {", in: code)
        guard let rescue = action.range(of: "autosaveTake()"),
              let replace = action.range(of: "SessionSaveOpen.startEmptySong(timeline: timelineStore, clips: clipStore,"),
              let refused = action.range(of: "openNote = Self.newPieceRefusedNote"),
              let clear = action.range(of: "projects.clearCurrent()"),
              let genre = action.range(of: "timelineStore.setEchoelGenre(style)"),
              let fx = action.range(of: "adoptEchoelFXFromSong()"),
              let area = action.range(of: "selectArea(.compose)") else {
            return XCTFail("ANCHOR MISSING: startNewPiece lost a step (#454): \(action)")
        }
        XCTAssertLessThan(rescue.lowerBound, replace.lowerBound, """
            the rescue must run BEFORE the song is replaced — after it, the recovery slot would \
            record the EMPTY song and the player's song would be gone
            """)
        XCTAssertLessThan(refused.lowerBound, clear.lowerBound,
                          "a refused replacement keeps the header's name — the song is unchanged")
        XCTAssertLessThan(clear.lowerBound, genre.lowerBound)
        XCTAssertLessThan(genre.lowerBound, fx.lowerBound, "the same two lines Open ends with, in its order")
        XCTAssertLessThan(fx.lowerBound, area.lowerBound)
        XCTAssertTrue(action.contains("showOpen = false"), "the Library closes onto Compose")
        XCTAssertFalse(action.contains("activeMenu ="), """
            nothing may force the plate (`TheWorkstationHasADoorTests`) — the action goes through \
            the Compose area door the area row taps
            """)
        // Counterweights (#343): the area door leads where the sentence says.
        let homes = try member("private static func areaHome(_ area: StudioArea) -> StudioMenu? {", in: code)
        XCTAssertTrue(homes.contains("case .compose:  return .workstation"), "Compose's home is the Workstation")
        XCTAssertEqual(StudioArea.compose.label, "Compose")
        XCTAssertTrue(SessionSaveOpen.emptySong.slots.count == ClipStore.slotCount,
                      "the refusal branch is defensive: the empty song always fits the grid")
    }

    func testTheRowLivesInTheLibrarySheetAndSaysWhatIsKept() throws {
        let code = try source(Self.studioPath)
        let sheet = try member("private var openSheet: some View {", in: code)
        XCTAssertTrue(sheet.contains("newPieceRow"), "the row is mounted in the Library sheet")
        XCTAssertTrue(sheet.contains("if let openNote"), "counterweight: a refused new piece has a line to say so")
        XCTAssertEqual(code.components(separatedBy: "newPieceRow").count - 1, 2, "declared once, mounted once")
        let row = try member("private var newPieceRow: some View {", in: code)
        XCTAssertTrue(row.contains("startNewPiece()"))
        XCTAssertTrue(row.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"), "a 44-pt target")
        XCTAssertTrue(row.contains(".accessibilityHint(Self.newPieceNote)"))
        XCTAssertTrue(row.contains("Text(Self.newPieceNote)"), "the footer and the spoken hint are one sentence (#416)")
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(row.contains(modal), "black-screen law: the row adds no presentation (`\(modal)`)")
        }
        XCTAssertTrue(EchoelStudioView.newPieceNote.contains("opens Compose"))
        XCTAssertTrue(EchoelStudioView.newPieceNote.contains("kept in Autosave"))
        XCTAssertTrue(EchoelStudioView.newPieceRefusedNote.contains("unchanged"))
    }

    func testTheReplacementKeepsOpensOrderAndOneEmptySong() throws {
        let code = try source(Self.saveOpenPath)
        let start = try member("public static func startEmptySong(timeline: TimelineStore, clips: ClipStore,", in: code)
        guard let stop = start.range(of: "player.stop()"),
              let grid = start.range(of: "guard clips.replaceSlots(song.slots) else { return false }"),
              let doc = start.range(of: "timeline.replaceDocument(song.document)") else {
            return XCTFail("ANCHOR MISSING: startEmptySong lost a step (#454): \(start)")
        }
        XCTAssertLessThan(stop.lowerBound, grid.lowerBound, "the player stops before the song goes")
        XCTAssertLessThan(grid.lowerBound, doc.lowerBound,
                          "grid before timeline — `restoreSong`'s order, so no region names a missing clip")
        let restoreBody = try member("public static func restoreSong(of project: Project,", in: code)
        XCTAssertTrue(restoreBody.contains("song = emptySong"), "Open's session-less branch asks the one definition")
        XCTAssertEqual(code.components(separatedBy: "TimelineStore.migrate(sections: [])").count - 1, 1,
                       "the empty song is spelled once in this file (#416)")
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

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}

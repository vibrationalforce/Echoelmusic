// TheSelectedPartsNotesAreEditedThroughOneWriterTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M1: the selected MIDI part's notes.
//
// WHAT IT PINS. The Workstation places, cuts and moves parts; since M1 it also changes the notes
// inside a MIDI part (`Studio/PartNoteEditor.swift`). The law of that change, which the founder
// wrote down before a line of it existed: ONE owner of the content (`ClipStore`), ONE writer
// (`TimelineStore.setClipNotes`), ONE history (the Workstation's Undo), ONE commit per action.
//
// 1. PURE (`ClipNoteEdit`): who may be edited and why not; the window is the player's own
//    (`RegionNoteWindow`); a created note lands at offset + step, one step long, clipped at the
//    part's end, and never outside the part; a removal keeps the survivors' order; the rows are
//    two octaves and stay inside MIDI.
// 2. END-TO-END over a REAL `TimelineStore` and `ClipStore`: a notes edit is ONE undo step;
//    Undo and Redo move it; a notes step and a parts step undo in order WITHOUT touching each
//    other; a composer-owned clip is refused with no step; an unchanged list makes no step; a
//    notes step whose clip is gone is skipped, not played as a dead Undo; Open clears it.
// 3. SOURCE: `ClipStore.updateMelody` is called from the store alone; the editor writes through
//    `setClipNotes` and nothing else, reads no transport, tempo or playhead, owns no persistence
//    and no modal, and is mounted once, under the part bar.
// 4. THE M1 REVIEW (independent ui-state review of 4781cbc0d, five findings, all repaired here):
//    (1) a note edit changes the CLIP, not the document, so the structure chase never saw it and
//    a part spanning the loop — every imported MIDI song — kept its Play-time notes until Stop:
//    `ClipStore.userMelodyGeneration` now moves on every user note write (not the composer's)
//    and `TimelineRegionPlayer.refreshNoteContent` re-loads on the next step (counter:
//    END-TO-END over the real store; the player's call order: SOURCE — the player needs a live
//    engine no test bundle can build); (2) the rows centre once per opened part; (3) the legacy
//    refusal no longer says "shown"; (4) a note rounding past the part's last step gets a
//    column; (5) Delete acts only on picked notes that are on screen. (2) and (5) are SOURCE.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 were transcribed into Python
// over models of `ClipNoteEdit`, `RegionNoteWindow.windowed/effectiveOffsetTicks`, `Note`'s
// step views and the store's typed history; claim 3 was driven against this tree. On the parent
// `ClipNoteEdit`, `setClipNotes` and `PartNoteEditor` do not exist, so the bundle does not build
// there — ONE absence, not N findings (#486): every claim here is a FORWARD guard. The two
// guards this commit moved (the history shape in `TheTrackPartsAreArrangedThroughTheStoreTests`,
// the caption in `TheWorkstationPlaysTheTimelineTests`) carry their own grading.
// NOT covered: that the grid renders, that a tap lands on the cell under the finger, that an
// added note is HEARD while the song loops — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Workstation → import a MIDI file → tap its part on the canvas → Notes →
// tap an empty cell (a note appears), tap it (it lights), Delete, then Undo and Redo under the
// canvas; while the song loops, hear the added note the next time the playhead reaches it
// (no Stop + Play needed — `TimelineRegionPlayer.refreshNoteContent`).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSelectedPartsNotesAreEditedThroughOneWriterTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let clipStorePath = "Sources/Echoelmusic/Core/ClipStore.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let step = Note.ticksPerStep
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — pure

    func testOnlyAUserMIDIPartWithATickWindowIsEditable() {
        let region = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0,
                                    lengthTicks: Self.bar)
        let user = Clip(name: "user", kind: .midi, melody: MelodyClip(notes: []))
        let composed = Clip(name: "composer", kind: .midi, melody: MelodyClip(notes: []),
                            composerOwned: true)
        let audio = Clip(name: "audio", kind: .audio)
        XCTAssertNil(ClipNoteEdit.refusal(clip: user, region: region))
        XCTAssertEqual(ClipNoteEdit.refusal(clip: nil, region: region), .missing)
        XCTAssertEqual(ClipNoteEdit.refusal(clip: audio, region: region), .notMIDI)
        XCTAssertEqual(ClipNoteEdit.refusal(clip: composed, region: region), .composerOwned,
                       "evolve rewrites a composer clip every ~25–45 s — an edit would vanish")
        let legacy = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0,
                                    lengthTicks: Self.bar, contentOffsetSeconds: 1.5)
        XCTAssertEqual(ClipNoteEdit.refusal(clip: user, region: legacy), .legacyOffset,
                       "a seconds-only window needs a tempo to place — shown, not edited")
        for refusal: ClipNoteEdit.Refusal in [.missing, .notMIDI, .composerOwned, .legacyOffset] {
            XCTAssertFalse(refusal.sentence.isEmpty, "\(refusal) says nothing on screen")
        }
        XCTAssertTrue(ClipNoteEdit.acceptsEdits(user))
        XCTAssertFalse(ClipNoteEdit.acceptsEdits(composed))
        XCTAssertFalse(ClipNoteEdit.acceptsEdits(audio))
    }

    func testTheWindowIsThePlayersOwn() {
        let trimmed = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 4 * Self.bar,
                                     lengthTicks: Self.bar, contentOffsetTicks: Self.bar)
        XCTAssertEqual(ClipNoteEdit.windowOffset(of: trimmed), Self.bar)
        XCTAssertEqual(ClipNoteEdit.windowOffset(of: TimelineRegion(
            laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: Self.bar)), 0)
        let before = Note(pitch: 60, startTick: 0, lengthTicks: Self.step)
        let inside = Note(pitch: 62, startTick: Self.bar + 2 * Self.step, lengthTicks: Self.step)
        let after = Note(pitch: 64, startTick: 2 * Self.bar, lengthTicks: Self.step)
        let clipNotes = [before, inside, after]
        let shown = ClipNoteEdit.visibleNotes(clipNotes, offsetTicks: Self.bar,
                                              lengthTicks: Self.bar)
        XCTAssertEqual(shown, RegionNoteWindow.windowed(notes: clipNotes, offsetTicks: Self.bar,
                                                        lengthTicks: Self.bar),
                       "the editor shows exactly what the player plays (#416)")
        XCTAssertEqual(shown.map(\.id), [inside.id])
        XCTAssertEqual(shown.first?.startStep, 2, "region-relative")
        XCTAssertEqual(ClipNoteEdit.stepCount(lengthTicks: Self.bar), 16)
        XCTAssertEqual(ClipNoteEdit.stepCount(lengthTicks: Self.bar + 1), 17, "a partial step counts")
        XCTAssertEqual(ClipNoteEdit.stepCount(lengthTicks: 0), 1)
    }

    func testANewNoteLandsInsideThePartOneStepLong() throws {
        let existing = Note(pitch: 60, startTick: Self.bar, lengthTicks: Self.step)
        let id = UUID()
        let added = try XCTUnwrap(ClipNoteEdit.adding(pitch: 67, step: 3, to: [existing],
                                                      offsetTicks: Self.bar,
                                                      lengthTicks: Self.bar, id: id))
        XCTAssertEqual(added.id, id)
        XCTAssertEqual(added.notes.count, 2)
        XCTAssertEqual(added.notes.first, existing, "the clip's other notes are untouched")
        let note = try XCTUnwrap(added.notes.last, "appended, so it draws on top")
        XCTAssertEqual(note.id, id)
        XCTAssertEqual(note.pitch, 67)
        XCTAssertEqual(note.startTick, Self.bar + 3 * Self.step, "clip tick = offset + step")
        XCTAssertEqual(note.lengthTicks, Self.step)
        XCTAssertEqual(note.velocity, 0.8, accuracy: 1e-6)

        // A part that ends mid-step: the last cell's note is clipped at the part's end.
        let short = try XCTUnwrap(ClipNoteEdit.adding(pitch: 60, step: 1, to: [], offsetTicks: 0,
                                                      lengthTicks: Self.step + 40))
        XCTAssertEqual(short.notes.first?.lengthTicks, 40)

        XCTAssertNil(ClipNoteEdit.adding(pitch: 60, step: 16, to: [], offsetTicks: 0,
                                         lengthTicks: Self.bar), "past the part's end")
        XCTAssertNil(ClipNoteEdit.adding(pitch: 60, step: -1, to: [], offsetTicks: 0,
                                         lengthTicks: Self.bar))
        XCTAssertNil(ClipNoteEdit.adding(pitch: 128, step: 0, to: [], offsetTicks: 0,
                                         lengthTicks: Self.bar), "outside MIDI")
        XCTAssertNil(ClipNoteEdit.adding(pitch: 60, step: 0, to: [], offsetTicks: 0,
                                         lengthTicks: 0))
    }

    func testARemovalKeepsTheOthersInOrderAndTheRowsStayInsideMIDI() {
        let a = Note(pitch: 60, startStep: 0), b = Note(pitch: 62, startStep: 1)
        let c = Note(pitch: 64, startStep: 2)
        XCTAssertEqual(ClipNoteEdit.removing([b.id], from: [a, b, c]), [a, c])
        XCTAssertEqual(ClipNoteEdit.removing([], from: [a, b, c]), [a, b, c])

        XCTAssertEqual(ClipNoteEdit.centrePitch(of: []), 60, "C4 when empty")
        XCTAssertEqual(ClipNoteEdit.centrePitch(of: [Note(pitch: 90, startStep: 0)]), 90,
                       "centred on the part's own notes")
        XCTAssertEqual(ClipNoteEdit.pitchRange(centre: 60, octaveShift: 0), 48...72, "C3–C5")
        XCTAssertEqual(ClipNoteEdit.pitchRange(centre: 60, octaveShift: 1), 60...84)
        XCTAssertEqual(ClipNoteEdit.pitchRange(centre: 60, octaveShift: -9), 0...24, "floored, not shrunk")
        XCTAssertEqual(ClipNoteEdit.pitchRange(centre: 60, octaveShift: 9), 103...127, "capped, not shrunk")
        XCTAssertEqual(ClipNoteEdit.pitchRange(centre: 90, octaveShift: 0), 78...102)
    }

    /// M1 review, finding 4: an unquantized note in a part's last half-step rounds to
    /// `startStep == stepCount`. The player sounds it, so the grid must draw a column for it.
    func testANoteTheGridWouldRoundPastThePartsEndStillGetsAColumn() {
        let edge = Note(pitch: 60, startTick: Self.bar - 20, lengthTicks: 20)
        let visible = ClipNoteEdit.visibleNotes([edge], offsetTicks: 0, lengthTicks: Self.bar)
        XCTAssertEqual(visible.count, 1, "premise: the player's window keeps it")
        XCTAssertEqual(visible.first?.startStep, 16, "premise: it rounds past the last column")
        XCTAssertEqual(ClipNoteEdit.stepCount(lengthTicks: Self.bar), 16)
        XCTAssertEqual(ClipNoteEdit.columnCount(lengthTicks: Self.bar, visible: visible), 17,
                       "a column exists to see, select and delete it")
        XCTAssertEqual(ClipNoteEdit.columnCount(lengthTicks: Self.bar, visible: []), 16)
        XCTAssertNil(ClipNoteEdit.adding(pitch: 60, step: 16, to: [], offsetTicks: 0,
                                         lengthTicks: Self.bar),
                     "the extra column shows; it never creates outside the part")
    }

    // MARK: 2 — the real stores

    func testANotesEditIsOneUndoStepOnTheSongsHistory() throws {
        try withStores { timeline, clips, clipID, regionID in
            let first = Note(pitch: 60, startStep: 0)
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [first], clips: clips))
            XCTAssertTrue(timeline.canUndo, "a notes edit is an undo step")
            XCTAssertEqual(clips.clip(id: clipID)?.melody?.notes, [first])

            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [first], clips: clips),
                          "an unchanged list is accepted")
            timeline.undo()
            XCTAssertEqual(clips.clip(id: clipID)?.melody?.notes ?? [], [],
                           "…and made no step: ONE Undo takes the edit back")
            XCTAssertFalse(timeline.canUndo)
            timeline.redo()
            XCTAssertEqual(clips.clip(id: clipID)?.melody?.notes, [first], "Redo puts it back")

            // A parts step and a notes step, interleaved: each Undo reverts its own kind only.
            let partsBefore = timeline.document.regions
            timeline.duplicateRegion(id: regionID)
            XCTAssertEqual(timeline.document.regions.count, partsBefore.count + 1)
            let second = Note(pitch: 64, startStep: 4)
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [first, second], clips: clips))
            timeline.undo()
            XCTAssertEqual(clips.clip(id: clipID)?.melody?.notes, [first], "the notes step first")
            XCTAssertEqual(timeline.document.regions.count, partsBefore.count + 1,
                           "…and it did not touch the parts")
            timeline.undo()
            XCTAssertEqual(timeline.document.regions, partsBefore, "then the parts step")
            XCTAssertEqual(clips.clip(id: clipID)?.melody?.notes, [first],
                           "…and it did not touch the notes")
        }
    }

    func testAComposerClipIsRefusedAndAGoneClipIsSkipped() throws {
        try withStores { timeline, clips, clipID, regionID in
            // The composer's clip: refused, nothing written, no step.
            let composed = Clip(name: "M1 guard composer", kind: .midi,
                                melody: MelodyClip(notes: []), composerOwned: true)
            clips.setClip(at: 1, composed)
            XCTAssertFalse(timeline.setClipNotes(clipID: composed.id,
                                                 [Note(pitch: 60, startStep: 0)], clips: clips))
            XCTAssertEqual(clips.clip(id: composed.id)?.melody?.notes ?? [], [])
            XCTAssertFalse(timeline.canUndo, "a refused edit leaves no dead undo step")
            XCTAssertFalse(timeline.setClipNotes(clipID: UUID(), [], clips: clips),
                           "an unknown clip is refused")

            // A parts step, then a notes step whose clip is then removed from the grid:
            // Undo skips the dead notes step and takes the parts step back.
            let partsBefore = timeline.document.regions
            timeline.duplicateRegion(id: regionID)
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [Note(pitch: 60, startStep: 0)],
                                                clips: clips))
            let slot = try XCTUnwrap(clips.slots.firstIndex(where: { $0?.id == clipID }))
            clips.clear(at: slot)
            timeline.undo()
            XCTAssertEqual(timeline.document.regions, partsBefore,
                           "Undo never does nothing while it reads as available")
            XCTAssertFalse(timeline.canUndo)
        }
    }

    func testOpeningASongClearsTheNotesHistory() throws {
        try withStores { timeline, clips, clipID, _ in
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [Note(pitch: 60, startStep: 0)],
                                                clips: clips))
            XCTAssertTrue(timeline.canUndo)
            timeline.replaceDocument(timeline.document)
            XCTAssertFalse(timeline.canUndo, "a notes step belongs to the song that was replaced")
            XCTAssertFalse(timeline.canRedo)
        }
    }

    /// M1 review, finding 1: a note write moves the counter the playing timeline reads; the
    /// composer's own write does not (it keeps its delivery, and an evolve must not restage).
    func testAUserNoteWriteMovesTheCounterThePlayerReads() throws {
        try withStores { timeline, clips, clipID, _ in
            let before = clips.userMelodyGeneration
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [Note(pitch: 60, startStep: 0)],
                                                clips: clips))
            XCTAssertEqual(clips.userMelodyGeneration, before &+ 1, "one edit, one bump")
            timeline.undo()
            XCTAssertEqual(clips.userMelodyGeneration, before &+ 2, "Undo is a note write too")
            XCTAssertTrue(timeline.setClipNotes(clipID: clipID, [], clips: clips),
                          "unchanged list accepted")
            XCTAssertEqual(clips.userMelodyGeneration, before &+ 2, "…and wrote nothing")
            let composed = Clip(name: "M1 guard composer", kind: .midi,
                                melody: MelodyClip(notes: []), composerOwned: true)
            clips.setClip(at: 1, composed)
            let atComposer = clips.userMelodyGeneration
            clips.updateComposerMelody(id: composed.id, notes: [Note(pitch: 64, startStep: 0)])
            XCTAssertEqual(clips.userMelodyGeneration, atComposer,
                           "the composer's evolve never restages playback through this path")
        }
    }

    // MARK: 3 — source

    func testTheEditorWritesOnlyThroughTheStoreAndReadsColdState() throws {
        let editor = try source(Self.editorPath)
        // M2 (`ANoteDragIsOneCommitAtReleaseTests`) moved this from 2 to 4: create, delete, and
        // since M2 a finished move and a finished stretch — still one commit per action.
        XCTAssertEqual(editor.components(separatedBy: "timeline.setClipNotes(").count - 1, 4,
                       "create, delete, move, stretch — each one commit through the one writer")
        for banned in ["updateMelody", "PianoRollModel", "pianoRoll", "currentTick", "player.",
                       "preflightTempo", "pattern.", "UserDefaults", "@AppStorage", ".sheet(",
                       ".fullScreenCover(", "Slider(", "Stepper("] {
            XCTAssertFalse(editor.contains(banned), """
                PartNoteEditor contains `\(banned)`. It edits through `setClipNotes` only (one \
                owner, one history), reads no transport, tempo or playhead (it sits under the \
                menu host), and owns no persistence and no modal. (`DragGesture` stood in this \
                list for M1; M2 added the drag with a gesture-local preview and ONE commit at \
                release, pinned by `ANoteDragIsOneCommitAtReleaseTests`.)
                """)
        }
        let callers = try filesMatching { code, _ in code.contains(".updateMelody(") }
        XCTAssertEqual(callers, [Self.storePath], """
            `ClipStore.updateMelody` is called from \(callers). A caller outside the store writes \
            notes that no Undo can take back — the one writer is `TimelineStore.setClipNotes`.
            """)
        let store = try source(Self.storePath)
        XCTAssertEqual(store.components(separatedBy: ".updateMelody(").count - 1, 2,
                       "setClipNotes and the history's own apply — nothing else")

        // Finding 5: Delete acts only on picked notes that are ON SCREEN.
        XCTAssertTrue(editor.contains("range.contains($0.pitch) && picked.contains($0.id)"),
                      "Delete must be scoped to the rows shown — a scrolled-out note is never removed unseen")
        // Finding 2: the rows centre ONCE per opened part, never on the live notes.
        XCTAssertTrue(editor.contains("@State private var centre: Int?"),
                      "ANCHOR MISSING: the held centre")
        XCTAssertFalse(editor.contains("pitchRange(of:"), "the rows must not follow the live notes")

        // Finding 1: the player pulls a note edit in on the next step.
        let player = try source(Self.playerPath)
        guard let step = player.range(of: "public func transportStep(_ step: Int) {"),
              let structure = player.range(of: "refreshStructure()", range: step.upperBound..<player.endIndex),
              let notes = player.range(of: "refreshNoteContent()", range: step.upperBound..<player.endIndex),
              let advance = player.range(of: "cursor.advance(step: step)", range: step.upperBound..<player.endIndex)
        else {
            return XCTFail("ANCHOR MISSING: transportStep's chase calls (#454)")
        }
        XCTAssertLessThan(structure.lowerBound, notes.lowerBound)
        XCTAssertLessThan(notes.lowerBound, advance.lowerBound,
                          "note edits are pulled in BEFORE this step's window, like structure edits")
        XCTAssertTrue(player.contains("self.seenMelodyGeneration = clips.userMelodyGeneration"),
                      "Play must load the current notes and start the count from there")
        let clipStore = try source(Self.clipStorePath)
        XCTAssertTrue(clipStore.contains("@ObservationIgnored public private(set) var userMelodyGeneration"),
                      "the counter is never observed — a view reading it would churn")

        let mounts = try filesMatching { code, _ in code.contains("PartNoteEditor()") }
        XCTAssertEqual(mounts, [Self.workstationPath], "one door, on the Workstation")
        let workstation = try source(Self.workstationPath)
        guard let bar = workstation.range(of: "SelectedPartBar()"),
              let editorMount = workstation.range(of: "PartNoteEditor()"),
              let history = workstation.range(of: "SongHistoryRow()") else {
            return XCTFail("ANCHOR MISSING: the part bar, the editor or the history row (#454)")
        }
        XCTAssertLessThan(bar.lowerBound, editorMount.lowerBound, "the editor sits under the part bar")
        XCTAssertLessThan(editorMount.lowerBound, history.lowerBound,
                          "…and above the one Undo/Redo it shares")
    }

    // MARK: helpers

    /// A real store pair with one user MIDI clip in slot 0 and one part playing it; both stores
    /// are put back afterwards.
    private func withStores(_ body: (TimelineStore, ClipStore, UUID, UUID) throws -> Void) throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let clip = Clip(name: "M1 guard", kind: .midi, melody: MelodyClip(notes: []))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "M1 guard", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        try body(timeline, clips, clip.id, region.id)
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func filesMatching(_ matches: (String, String) -> Bool) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var scanned = 0
        while let relative = walker.nextObject() as? String {
            guard relative.hasSuffix(".swift") else { continue }
            let path = "\(Self.sourcesRoot)/\(relative)"
            let code = try source(path)
            scanned += 1
            if matches(code, path) { hits.append(path) }
        }
        XCTAssertGreaterThan(scanned, 100, "the walk saw \(scanned) files — a short walk is not a pass")
        return hits.sorted()
    }
}

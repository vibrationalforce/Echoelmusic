// ANoteDragIsOneCommitAtReleaseTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M2: move · stretch · box-select ·
// multi-select on the selected part's note grid.
//
// THE LAW (founder performance law, written before the code): finger samples → a LOCAL preview
// → ONE bounded canonical commit when the finger lifts → ONE undo step. No per-sample write, no
// finger-rate state above the grid leaf.
//
// 1. PURE (`NoteGridGesture.resolve`, END-TO-END BEHAVIOUR on shipped value types): where a hold
//    starts decides the gesture — a note's body moves the selection (or that note alone), its
//    right edge stretches it, an empty cell draws a box. Moves are clamped PER GROUP to the part
//    and the rows shown, and a zero slide is a zero move — including for a note in the widened
//    last column (the reason `RollHitTest.clampedGroupDelta` is not used, see the core's header).
// 2. PURE (`ClipNoteEdit.moving` / `resizing`): the commit acts on the CLIP's notes by id, keeps
//    an unquantized note's offset, keeps every start inside the part's window, and returns nil
//    when nothing changes — so a slide back to the start commits no step.
// 3. WYSIWYG: the preview (`applied(to:)` on the part's visible notes) equals the part's visible
//    notes after the commit. Preview and commit are one value, never two computations.
// 4. END-TO-END over a REAL `TimelineStore`/`ClipStore`: a finished group move is ONE undo step.
// 5. SOURCE-TEXT SCAN: `@GestureState` lives only in the canvas leaf; the drag is hold-then-slide;
//    the per-sample `.updating` closure writes nothing; the one commit is in `.onEnded`.
//
// Grading (§0 — no Swift toolchain here): claims 1–3 were transcribed into Python over models of
// `RollHitTest.classify/notesInRect`, `Note`'s step views, `RegionNoteWindow
// .windowed` and the two new functions; claim 5 was driven against this tree. On the parent
// `NoteGridGesture`, `moving` and `resizing` do not exist, so the bundle does not build there: ONE
// absence, not N findings (#486) — every claim is a FORWARD guard. The M1 guard moved in the same
// commit (`DragGesture` left its banned list, the writer count went 2 → 4).
// ⭐ INDEPENDENT REVIEW (M2, ui-state) found one MEDIUM defect and it is repaired here: a stretch
// was an ABSOLUTE length, so a hold on a note's edge WITHOUT a slide re-stated its drawn length —
// re-quantizing an imported 455-tick note, or writing a part-cut length into a clip another part
// plays longer — and pushed an undo step. A stretch is now a DELTA of whole steps (`dSteps`), zero
// on a hold, and the commit moves the end THIS part draws. Also repaired: the group's LEFT bound
// counts steps below the earliest start tick, so a note at tick 60 is not squeezed to 0. The four
// new assertions (hold-without-slide ×2, the tick-60 group, the cut note) are REGRESSIONS against
// 7674eff6b in intent; there the enum case had another shape, so the file does not build there.
// ⚠️ Claim 3 is exact for notes that stay clear of the part's end. A note the part CUTS at its end
// is drawn mid-slide at its cut length, while the commit re-cuts it at the new position — the
// release can therefore show it a little longer or shorter than the slide did. Starts and
// pitches never differ.
// NOT covered: that the hold is recognised under a scroll view, that the preview follows the
// finger smoothly, that the result sounds — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: New MIDI Part → Notes → add four notes → press and hold one, slide right
// and up (it follows, lands on release, Undo takes it back in one step) → hold its right edge and
// slide (it stretches) → hold an empty cell and draw a box over two notes (both light) → hold one
// of them and slide (both move) → a plain swipe still scrolls the grid.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ANoteDragIsOneCommitAtReleaseTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let corePath = "Sources/Echoelmusic/Studio/NoteGridGesture.swift"
    private static let step = Note.ticksPerStep
    private static let bar = TimelineTime.ticksPerBar
    private static let grid = NoteGridGesture.Grid(stepWidth: 22, rowHeight: 14, rows: 48...72,
                                                   partSteps: 16)

    /// Top of pitch `p`'s row, plus a little, in the grid's coordinates.
    private func rowY(_ pitch: Int) -> Double { Double(72 - pitch) * 14 + 2 }

    // MARK: 1 — what a hold means

    func testWhereTheHoldStartsDecidesTheGesture() {
        let a = Note(pitch: 60, startStep: 2, lengthSteps: 2)     // x 44…88
        let b = Note(pitch: 64, startStep: 6)                     // x 132…154
        let c = Note(pitch: 62, startStep: 10)                    // x 220…242
        let notes = [a, b, c]
        let g = Self.grid

        // Body, not selected: that note alone, 2 steps right, 2 semitones up.
        XCTAssertEqual(NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: 44, dy: -28,
                                               visible: notes, picked: [], grid: g),
                       .move(ids: [a.id], dPitch: 2, dStep: 2))
        // Body of a selected note: the whole selection moves together.
        XCTAssertEqual(NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: 44, dy: -28,
                                               visible: notes, picked: [a.id, b.id], grid: g),
                       .move(ids: [a.id, b.id], dPitch: 2, dStep: 2))
        // No slide → no move.
        XCTAssertEqual(NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: 0, dy: 0,
                                               visible: notes, picked: [], grid: g),
                       .move(ids: [a.id], dPitch: 0, dStep: 0))
        // Right edge (the last 8 points): the END moves by the steps the finger crossed, never
        // past the part (a DELTA since the M2 review — see claim 2's hold-without-slide cases).
        XCTAssertEqual(NoteGridGesture.resolve(startX: 84, startY: rowY(60), dx: 44, dy: 0,
                                               visible: notes, picked: [], grid: g),
                       .resize(id: a.id, dSteps: 2), "2 steps long → 4")
        XCTAssertEqual(NoteGridGesture.resolve(startX: 84, startY: rowY(60), dx: 5_000, dy: 0,
                                               visible: notes, picked: [], grid: g),
                       .resize(id: a.id, dSteps: 12), "16 steps in the part, starting at 2 → 14 long")
        XCTAssertEqual(NoteGridGesture.resolve(startX: 84, startY: rowY(60), dx: -500, dy: 0,
                                               visible: notes, picked: [], grid: g),
                       .resize(id: a.id, dSteps: -1), "never shorter than one step")
        // A hold on the edge without a slide — or with the few points of drift every real touch
        // has — is a ZERO stretch (M2 review: an absolute length re-stated here committed a step).
        XCTAssertEqual(NoteGridGesture.resolve(startX: 84, startY: rowY(60), dx: 0, dy: 0,
                                               visible: notes, picked: [], grid: g),
                       .resize(id: a.id, dSteps: 0))
        XCTAssertEqual(NoteGridGesture.resolve(startX: 84, startY: rowY(60), dx: 3, dy: 2,
                                               visible: notes, picked: [], grid: g),
                       .resize(id: a.id, dSteps: 0))
        // Empty cell: a box; the notes it touches become the selection.
        guard case .marquee(let all, _, _, _, _) =
                NoteGridGesture.resolve(startX: 0, startY: 0, dx: 300, dy: 200,
                                        visible: notes, picked: [], grid: g) else {
            return XCTFail("a hold on an empty cell must draw a box")
        }
        XCTAssertEqual(all, [a.id, b.id, c.id])
        guard case .marquee(let none, _, _, _, _) =
                NoteGridGesture.resolve(startX: 0, startY: 0, dx: 100, dy: 100,
                                        visible: notes, picked: [], grid: g) else {
            return XCTFail("a hold on an empty cell must draw a box")
        }
        XCTAssertEqual(none, [], "a box over no note selects nothing")
        XCTAssertFalse(NoteGridGesture.marquee(ids: [], x0: 0, y0: 0, x1: 1, y1: 1).edits,
                       "a box only selects — a part that is shown, not edited, may still use it")
    }

    func testAMoveIsClampedAsAGroupAndAZeroSlideNeverMoves() {
        let a = Note(pitch: 60, startStep: 2)
        let b = Note(pitch: 70, startStep: 12)
        let both: Set<UUID> = [a.id, b.id]
        let g = Self.grid
        let right = NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: 22 * 20, dy: 0,
                                            visible: [a, b], picked: both, grid: g)
        XCTAssertEqual(right, .move(ids: both, dPitch: 0, dStep: 3),
                       "the LAST note stops at the part's last step, the group keeps its spacing")
        let left = NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: -22 * 20, dy: 0,
                                           visible: [a, b], picked: both, grid: g)
        XCTAssertEqual(left, .move(ids: both, dPitch: 0, dStep: -2), "the FIRST note stops at step 0")
        let up = NoteGridGesture.resolve(startX: 50, startY: rowY(60), dx: 0, dy: -14 * 20,
                                         visible: [a, b], picked: both, grid: g)
        XCTAssertEqual(up, .move(ids: both, dPitch: 2, dStep: 0), "the highest note stops on the top row shown")

        // An unquantized note at tick 60 ROUNDS to step 1 but starts in step 0: the group may not
        // move left at all, or that note would be clamped to 0 and the spacing squeezed (M2 review).
        let early = Note(pitch: 60, startTick: 60, lengthTicks: 60)
        let later = Note(pitch: 60, startTick: 300, lengthTicks: 60)
        XCTAssertEqual(early.startStep, 1, "fixture premise: it draws in column 1")
        XCTAssertEqual(NoteGridGesture.resolve(startX: 28, startY: rowY(60), dx: -22 * 3, dy: 0,
                                               visible: [early, later],
                                               picked: [early.id, later.id], grid: g),
                       .move(ids: [early.id, later.id], dPitch: 0, dStep: 0))

        // A note in the widened last column (it rounds to step 16 of a 16-step part): a hold
        // without a slide must not move it — the defect a note-END bound would have.
        let late = Note(pitch: 60, startTick: 1_900, lengthTicks: 20)
        XCTAssertEqual(late.startStep, 16, "fixture premise: the note sits in the widened column")
        XCTAssertEqual(NoteGridGesture.resolve(startX: 16 * 22 + 3, startY: rowY(60), dx: 0, dy: 0,
                                               visible: [late], picked: [], grid: g),
                       .move(ids: [late.id], dPitch: 0, dStep: 0))
        XCTAssertEqual(NoteGridGesture.resolve(startX: 16 * 22 + 3, startY: rowY(60), dx: 44, dy: 0,
                                               visible: [late], picked: [], grid: g),
                       .move(ids: [late.id], dPitch: 0, dStep: 0), "and it cannot go further right")
    }

    func testATapTogglesANoteInOrOutOfTheSelection() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(NoteGridGesture.toggling(a, in: []), [a])
        XCTAssertEqual(NoteGridGesture.toggling(b, in: [a]), [a, b])
        XCTAssertEqual(NoteGridGesture.toggling(a, in: [a, b]), [b])
    }

    // MARK: 2 — the commit

    func testTheCommitMovesTheClipsNotesByIdInsideThePart() throws {
        let offset = Self.bar                       // the part shows the clip's second bar
        let length = Self.bar
        let n = Note(pitch: 60, startTick: offset + 2 * Self.step, lengthTicks: Self.step)
        let loose = Note(pitch: 62, startTick: offset + 2 * Self.step + 10, lengthTicks: Self.step)
        let other = Note(pitch: 67, startTick: 5, lengthTicks: Self.step)
        let clip = [other, n, loose]

        let moved = try XCTUnwrap(ClipNoteEdit.moving([n.id, loose.id], dPitch: 2, dStep: 3, in: clip,
                                                      offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(moved.map(\.id), clip.map(\.id), "order is kept")
        XCTAssertEqual(moved[0], other, "a note that was not moved is untouched")
        XCTAssertEqual(moved[1].startTick, n.startTick + 3 * Self.step)
        XCTAssertEqual(moved[1].pitch, 62)
        XCTAssertEqual(moved[2].startTick - moved[1].startTick, 10,
                       "an unquantized note keeps its offset from the grid")

        let early = try XCTUnwrap(ClipNoteEdit.moving([n.id], dPitch: 0, dStep: -10, in: clip,
                                                      offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(early[1].startTick, offset, "a start never leaves the part at its left edge")
        let late = try XCTUnwrap(ClipNoteEdit.moving([n.id], dPitch: 0, dStep: 100, in: clip,
                                                     offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(late[1].startTick, offset + length - 1, "…nor at its right edge")

        XCTAssertNil(ClipNoteEdit.moving([n.id], dPitch: 0, dStep: 0, in: clip,
                                         offsetTicks: offset, lengthTicks: length),
                     "a slide back to the start commits nothing")
        XCTAssertNil(ClipNoteEdit.moving([UUID()], dPitch: 1, dStep: 1, in: clip,
                                         offsetTicks: offset, lengthTicks: length),
                     "a note that is gone moves nothing")

        let stretched = try XCTUnwrap(ClipNoteEdit.resizing(n.id, bySteps: 3, in: clip,
                                                            offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(stretched[1].lengthTicks, 4 * Self.step)
        XCTAssertEqual(stretched[1].startTick, n.startTick, "a stretch keeps the start")
        XCTAssertNil(ClipNoteEdit.resizing(n.id, bySteps: 0, in: clip, offsetTicks: offset,
                                           lengthTicks: length), "a zero stretch commits nothing")
        XCTAssertNil(ClipNoteEdit.resizing(n.id, bySteps: -1, in: clip, offsetTicks: offset,
                                           lengthTicks: length), "never shorter than one step")
        XCTAssertNil(ClipNoteEdit.resizing(UUID(), bySteps: 2, in: clip, offsetTicks: offset,
                                           lengthTicks: length))

        // M2 review: an unquantized length keeps its offset — a stretch is never a re-quantize.
        let imported = Note(pitch: 64, startTick: offset, lengthTicks: 455)
        let grown = try XCTUnwrap(ClipNoteEdit.resizing(imported.id, bySteps: 1, in: [imported],
                                                        offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(grown[0].lengthTicks, 575, "455 + one step, not 600")

        // M2 review: a note the part cuts off (8 steps from step 14 of a 16-step part). Growing
        // it changes nothing; shortening moves the end THIS part draws, and every part hears it.
        let cut = Note(pitch: 65, startTick: offset + 14 * Self.step, lengthTicks: 8 * Self.step)
        XCTAssertNil(ClipNoteEdit.resizing(cut.id, bySteps: 1, in: [cut], offsetTicks: offset,
                                           lengthTicks: length),
                     "a note already running past the part is never cut by a lengthening")
        let trimmed = try XCTUnwrap(ClipNoteEdit.resizing(cut.id, bySteps: -1, in: [cut],
                                                          offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(trimmed[0].lengthTicks, Self.step, "the drawn 2 steps less one")
        let cutGrid = NoteGridGesture.Grid(stepWidth: 22, rowHeight: 14, rows: 48...72, partSteps: 16)
        let cutShown = ClipNoteEdit.visibleNotes([cut], offsetTicks: offset, lengthTicks: length)
        XCTAssertEqual(NoteGridGesture.resolve(startX: 16 * 22 - 2, startY: rowY(65), dx: 0, dy: 0,
                                               visible: cutShown, picked: [], grid: cutGrid),
                       .resize(id: cut.id, dSteps: 0), "a hold on a cut note's edge writes nothing")
    }

    // MARK: 3 — the preview is the commit

    func testThePreviewIsWhatTheCommitLeaves() throws {
        let offset = Self.bar
        let length = Self.bar
        let clip = [Note(pitch: 60, startTick: offset + 2 * Self.step, lengthTicks: Self.step),
                    Note(pitch: 64, startTick: offset + 6 * Self.step + 30, lengthTicks: 2 * Self.step),
                    Note(pitch: 55, startTick: 40, lengthTicks: Self.step)]
        let visible = ClipNoteEdit.visibleNotes(clip, offsetTicks: offset, lengthTicks: length)
        XCTAssertEqual(visible.count, 2, "fixture premise: the part shows two of the three")
        let ids = Set(visible.map(\.id))

        let gesture = NoteGridGesture.move(ids: ids, dPitch: -3, dStep: 4)
        let committed = try XCTUnwrap(ClipNoteEdit.moving(ids, dPitch: -3, dStep: 4, in: clip,
                                                          offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(gesture.applied(to: visible),
                       ClipNoteEdit.visibleNotes(committed, offsetTicks: offset, lengthTicks: length),
                       "what the finger sees must be what the part plays after release")

        let first = visible[0]
        let stretch = NoteGridGesture.resize(id: first.id, dSteps: 2)
        let resized = try XCTUnwrap(ClipNoteEdit.resizing(first.id, bySteps: 2, in: clip,
                                                          offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(stretch.applied(to: visible),
                       ClipNoteEdit.visibleNotes(resized, offsetTicks: offset, lengthTicks: length))
    }

    // MARK: 4 — one step on the real history

    func testAFinishedGroupMoveIsOneUndoStep() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 60, startStep: 0), Note(pitch: 64, startStep: 4)]
        let clip = Clip(name: "M2 guard", kind: .midi, melody: MelodyClip(notes: notes))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "M2 guard", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")

        let moved = try XCTUnwrap(ClipNoteEdit.moving(Set(notes.map(\.id)), dPitch: 1, dStep: 2,
                                                      in: notes, offsetTicks: 0,
                                                      lengthTicks: Self.bar))
        XCTAssertTrue(timeline.setClipNotes(clipID: clip.id, moved, clips: clips))
        XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, moved)
        timeline.undo()
        XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, notes, "ONE Undo takes the whole move back")
        XCTAssertFalse(timeline.canUndo, "…because it was one step")
    }

    // MARK: 5 — source

    func testTheDragPreviewsLocallyAndCommitsOnceAtRelease() throws {
        let editor = try source(Self.editorPath)
        XCTAssertEqual(editor.components(separatedBy: "@GestureState").count - 1, 1,
                       "one finger-rate state in the editor")
        guard let leaf = editor.range(of: "private struct PartNoteCanvas: View {"),
              let state = editor.range(of: "@GestureState private var live: NoteGridGesture?") else {
            return XCTFail("ANCHOR MISSING: the canvas leaf or its gesture state (#454)")
        }
        XCTAssertLessThan(leaf.lowerBound, state.lowerBound,
                          "the finger-rate state lives in the canvas leaf, not in the grid that reads the stores")
        XCTAssertTrue(editor.contains("LongPressGesture(minimumDuration: 0.3)")
                      && editor.contains(".sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))"),
                      "hold first, then slide — so a swipe still scrolls the grid")

        let updating = try body(of: ".updating($live) {", in: editor)
        for banned in ["setClipNotes", "onRelease", "clipStore", "timeline"] {
            XCTAssertFalse(updating.contains(banned),
                           "the per-sample closure touches `\(banned)` — nothing may be written while the finger moves")
        }
        let ended = try body(of: ".onEnded {", in: editor)
        XCTAssertTrue(ended.contains("onRelease(gesture)"), "the one commit is handed over at release")

        let finish = try body(of: "private func finish(", in: editor)
        XCTAssertEqual(finish.components(separatedBy: "timeline.setClipNotes(").count - 1, 2,
                       "a finished move and a finished stretch — one commit each; a box writes nothing")

        let core = try source(Self.corePath)
        XCTAssertFalse(core.contains("import SwiftUI"), "the gesture's meaning is Foundation-only")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor)")
            throw AnchorMissing(name: anchor)
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
        throw AnchorMissing(name: anchor)
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}

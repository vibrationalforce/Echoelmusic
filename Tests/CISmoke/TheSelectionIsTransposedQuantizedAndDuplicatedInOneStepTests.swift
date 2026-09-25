// TheSelectionIsTransposedQuantizedAndDuplicatedInOneStepTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M3: duplicate · velocity · quantize ·
// transpose on the selected part's notes.
//
// 1. PURE (`ClipNoteEdit`, END-TO-END BEHAVIOUR on shipped value types): each operation acts on
//    `targets` — the on-screen selection, or the whole part when nothing is selected — returns
//    the CLIP's notes whole, and returns nil when nothing would change, so a button that would
//    do nothing commits no step. Transpose clamps as a group (a chord keeps its shape);
//    quantize snaps starts to the part's sixteenths and keeps them inside the part; velocity
//    is NaN-safe and set as one value; duplicate places the copies one selection-span later
//    and refuses a copy the player would skip.
// 2. END-TO-END over a REAL `TimelineStore`/`ClipStore`: each operation is ONE undo step.
// 3. SOURCE-TEXT SCAN: the editor's velocity row edits a LOCAL draft and commits once, in
//    `onCommit` — the drag of an `EchoelValueField` is finger-rate, and the performance law
//    forbids a write per sample.
//
// Grading (§0 — no Swift toolchain here): claims 1–2 were transcribed into Python over models of
// the six functions and `Note`'s tick views, and every expected value below was reproduced
// there; claim 3 against this tree. On the parent the functions do not exist, so the bundle does
// not build there: ONE absence, not N findings (#486) — every claim is a FORWARD guard. The same
// commit moves the writer count in `TheSelectedPartsNotesAreEditedThroughOneWriterTests` 4 → 8.
// NOT covered: that the buttons render and read well, that the velocity is heard — a device
// probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Notes → select two notes → +1 / Octave up (both move, the chord keeps its
// shape) → Quantize an off-grid imported note → Velocity drag (one Undo takes the whole drag
// back) → Duplicate (the copies land right after the selection and stay selected).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSelectionIsTransposedQuantizedAndDuplicatedInOneStepTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let step = Note.ticksPerStep
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — pure

    func testTheTargetIsTheSelectionOrTheWholePart() {
        let a = Note(pitch: 60, startStep: 0), b = Note(pitch: 62, startStep: 2)
        XCTAssertEqual(ClipNoteEdit.targets(selected: [a.id], visible: [a, b]), [a.id])
        XCTAssertEqual(ClipNoteEdit.targets(selected: [], visible: [a, b]), [a.id, b.id])
    }

    func testTransposeMovesTheGroupAndKeepsItsShape() throws {
        let low = Note(pitch: 10, startStep: 0), high = Note(pitch: 120, startStep: 0)
        let other = Note(pitch: 50, startStep: 4)
        let clip = [low, high, other]
        let up = try XCTUnwrap(ClipNoteEdit.transposing([low.id, high.id], by: 12, in: clip))
        XCTAssertEqual(up.map(\.pitch), [17, 127, 50],
                       "clamped as a GROUP: the top note stops at 127 and the chord keeps its shape")
        let down = try XCTUnwrap(ClipNoteEdit.transposing([low.id], by: -1, in: clip))
        XCTAssertEqual(down.map(\.pitch), [9, 120, 50], "an untargeted note is untouched")
        let top = Note(pitch: 127, startStep: 0)
        XCTAssertNil(ClipNoteEdit.transposing([top.id], by: 1, in: [top]),
                     "a note already at the top: nothing to do, no step")
        XCTAssertNil(ClipNoteEdit.transposing([], by: 1, in: clip))
    }

    func testQuantizeSnapsStartsToThePartsSixteenthsInsideThePart() throws {
        let offset = Self.bar
        let length = Self.bar
        let early = Note(pitch: 60, startTick: offset + 2 * Self.step + 50, lengthTicks: 90)   // → step 2
        let lateHalf = Note(pitch: 62, startTick: offset + 5 * Self.step + 70, lengthTicks: 90) // → step 6
        let edge = Note(pitch: 64, startTick: offset + length - 10, lengthTicks: 5)            // → last step
        let outside = Note(pitch: 65, startTick: 30, lengthTicks: 90)                          // not in the part
        let clip = [early, lateHalf, edge, outside]
        let ids = Set(clip.map(\.id))
        let snapped = try XCTUnwrap(ClipNoteEdit.quantizing(ids, in: clip, offsetTicks: offset,
                                                            lengthTicks: length))
        XCTAssertEqual(snapped[0].startTick, offset + 2 * Self.step)
        XCTAssertEqual(snapped[1].startTick, offset + 6 * Self.step)
        XCTAssertEqual(snapped[2].startTick, offset + 15 * Self.step,
                       "a note in the last half-step snaps to the part's last step, not past it")
        XCTAssertEqual(snapped[3], outside, "a note the part does not show is never moved")
        XCTAssertEqual(snapped.map(\.lengthTicks), clip.map(\.lengthTicks), "lengths are untouched")
        XCTAssertNil(ClipNoteEdit.quantizing(ids, in: snapped, offsetTicks: offset, lengthTicks: length),
                     "quantizing a quantized part commits nothing")
    }

    func testVelocityIsOneNaNSafeValue() throws {
        let a = Note(pitch: 60, startStep: 0, velocity: 0.2)
        let b = Note(pitch: 62, startStep: 1, velocity: 0.6)
        let clip = [a, b]
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.meanVelocity([a.id, b.id], in: clip)), 0.4, accuracy: 1e-6)
        let set = try XCTUnwrap(ClipNoteEdit.settingVelocity([a.id, b.id], to: 0.9, in: clip))
        XCTAssertEqual(set.map(\.velocity), [0.9, 0.9])
        let nan = try XCTUnwrap(ClipNoteEdit.settingVelocity([a.id], to: .nan, in: clip))
        XCTAssertTrue(nan[0].velocity.isFinite, "a NaN never reaches a note — it traps at export")
        XCTAssertNil(ClipNoteEdit.settingVelocity([a.id], to: 0.2, in: clip), "unchanged: no step")
        XCTAssertNil(ClipNoteEdit.meanVelocity([UUID()], in: clip))
    }

    func testDuplicatePlacesTheCopiesOneSpanLaterAndRefusesPastThePart() throws {
        let offset = Self.bar
        let length = Self.bar
        let a = Note(pitch: 60, startTick: offset, lengthTicks: Self.step)
        let b = Note(pitch: 64, startTick: offset + 2 * Self.step, lengthTicks: Self.step + 10)
        let clip = [a, b]
        let result = try XCTUnwrap(ClipNoteEdit.duplicating([a.id, b.id], in: clip,
                                                            offsetTicks: offset, lengthTicks: length))
        XCTAssertEqual(result.notes.count, 4)
        XCTAssertEqual(Array(result.notes.prefix(2)), clip, "the originals stay first and untouched")
        let copies = Array(result.notes.suffix(2))
        XCTAssertEqual(Set(copies.map(\.id)), result.ids, "the copies' ids are returned to select them")
        XCTAssertTrue(result.ids.isDisjoint(with: [a.id, b.id]), "copies get new ids")
        // span = first start … last end = 3 steps + 10 ticks → rounded up to 4 steps.
        XCTAssertEqual(copies.map(\.startTick), [offset + 4 * Self.step, offset + 6 * Self.step])
        XCTAssertEqual(copies.map(\.pitch), [60, 64])

        let late = Note(pitch: 60, startTick: offset + 12 * Self.step, lengthTicks: 4 * Self.step)
        XCTAssertNil(ClipNoteEdit.duplicating([late.id], in: [late], offsetTicks: offset,
                                              lengthTicks: length),
                     "a copy that would start past the part is refused, not created unheard")
        XCTAssertNil(ClipNoteEdit.duplicating([], in: clip, offsetTicks: offset, lengthTicks: length))
    }

    // MARK: 2 — one step each on the real history

    func testEachOperationIsOneUndoStep() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 60, startTick: 30, lengthTicks: Self.step),
                     Note(pitch: 64, startTick: 4 * Self.step, lengthTicks: Self.step)]
        let clip = Clip(name: "M3 guard", kind: .midi, melody: MelodyClip(notes: notes))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "M3 guard", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        let ids = Set(notes.map(\.id))

        let steps: [[Note]] = try [
            XCTUnwrap(ClipNoteEdit.transposing(ids, by: 12, in: notes)),
            XCTUnwrap(ClipNoteEdit.quantizing(ids, in: notes, offsetTicks: 0, lengthTicks: Self.bar)),
            XCTUnwrap(ClipNoteEdit.settingVelocity(ids, to: 0.3, in: notes)),
            XCTUnwrap(ClipNoteEdit.duplicating(ids, in: notes, offsetTicks: 0, lengthTicks: Self.bar)).notes,
        ]
        for edited in steps {
            XCTAssertTrue(timeline.setClipNotes(clipID: clip.id, edited, clips: clips))
            XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, edited)
            timeline.undo()
            XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, notes, "ONE Undo takes it back")
            XCTAssertFalse(timeline.canUndo, "…because it was one step")
        }
    }

    // MARK: 3 — source

    func testTheVelocityDragCommitsOnceWhenItEnds() throws {
        let editor = try source(Self.editorPath)
        guard let row = editor.range(of: "private struct NoteVelocityRow: View {") else {
            return XCTFail("ANCHOR MISSING: the velocity row leaf (#454)")
        }
        let leaf = String(editor[row.lowerBound...])
        XCTAssertTrue(leaf.contains("@State private var draft"),
                      "the drag edits a LOCAL draft — the leaf, not the grid, redraws at finger rate")
        XCTAssertTrue(leaf.contains("EchoelValueField("), "a numeric parameter uses the one control")
        XCTAssertTrue(leaf.contains("onCommit: {"), "the write happens when the edit ends")
        XCTAssertFalse(leaf.contains("onChange: {"),
                       "nothing may be written per drag sample (performance law)")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

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

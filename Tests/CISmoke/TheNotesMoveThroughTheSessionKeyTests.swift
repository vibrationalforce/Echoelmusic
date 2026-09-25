// TheNotesMoveThroughTheSessionKeyTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M4: scale-aware operations.
//
// 1. PURE (`ClipNoteEdit`, END-TO-END BEHAVIOUR on shipped value types): "Fit" moves each
//    target to the nearest note of the key (`MusicalKey.quantize` — the one definition, #416);
//    "±1 step" transposes by one step OF THE KEY'S SCALE, fitting an outside note first, and a
//    group that would leave MIDI 0…127 refuses whole rather than folding one note back. Both
//    return nil when nothing would change, so a button that does nothing commits no step.
// 2. END-TO-END over a REAL `TimelineStore`/`ClipStore`: each is ONE undo step.
// 3. SOURCE-TEXT SCAN: the editor READS the session key and never writes it — `SessionContext`
//    is the one owner of `echoel.keyRoot`/`echoel.keyScale` — and the rows shade by the key.
//
// Grading (§0 — no Swift toolchain here): claims 1–2 were transcribed into Python over models of
// `MusicalKey.contains`/`quantize` and the two new functions, and every expected pitch below was
// reproduced there; claim 3 against this tree. On the parent the functions do not exist, so the
// bundle does not build there: ONE absence, not N findings (#486) — every claim is a FORWARD
// guard. The same commit moves the writer count in
// `TheSelectedPartsNotesAreEditedThroughOneWriterTests` 8 → 10.
// ⭐ INDEPENDENT REVIEW (M4, code-reviewer): an out-of-key note's −1 skipped its nearest key
// note below (fitting first, and the fit's tie goes down) — it now steps to its nearest key note
// in the step's direction; "Fit" left MIDI 0/127 out of the key where the nearest key note lies
// outside MIDI — it now takes the nearest on the side that exists; and the key row spoke the
// English interop name — it now uses the reader's note names. The three new assertions are
// REGRESSIONS against 9dc19bf71.
// NOT covered: that the shading reads well and that a step "sounds right" — a device listen.
// NEEDS-FOUNDER-VERIFY: Notes → the rows outside the key are darker → a chord, "+1 step" (it
// climbs the scale, not by semitones) → an off-key note, "Fit" → one Undo each.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheNotesMoveThroughTheSessionKeyTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let cMajor = MusicalKey(root: 0, scale: .major)

    // MARK: 1 — pure

    func testFitMovesEachTargetToTheNearestKeyNote() throws {
        let sharp = Note(pitch: 61, startStep: 0)     // C#  → C  (a tie: the lower wins)
        let inKey = Note(pitch: 64, startStep: 1)     // E   stays
        let fSharp = Note(pitch: 66, startStep: 2)    // F#  → F  (a tie: the lower wins)
        let other = Note(pitch: 70, startStep: 3)     // A#, not targeted
        let clip = [sharp, inKey, fSharp, other]
        let fitted = try XCTUnwrap(ClipNoteEdit.fittingToKey([sharp.id, inKey.id, fSharp.id],
                                                             key: Self.cMajor, in: clip))
        XCTAssertEqual(fitted.map(\.pitch), [60, 64, 65, 70])
        XCTAssertEqual(fitted.map(\.id), clip.map(\.id), "a fit moves notes, it never replaces them")
        XCTAssertNil(ClipNoteEdit.fittingToKey([inKey.id], key: Self.cMajor, in: clip),
                     "already in the key: nothing to do, no step")
        // M4 review: MIDI 0 in D major quantizes to −1 (B, below MIDI). The nearest key note on
        // the side that exists is taken — C#-1 — instead of leaving the note out of the key.
        let bottom = Note(pitch: 0, startStep: 0)
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.fittingToKey([bottom.id],
                                                               key: MusicalKey(root: 2, scale: .major),
                                                               in: [bottom])).map(\.pitch), [1])
    }

    func testAStepClimbsTheScaleNotTheSemitones() throws {
        let c = Note(pitch: 60, startStep: 0), e = Note(pitch: 64, startStep: 0)
        let g = Note(pitch: 67, startStep: 0)
        let chord = [c, e, g]
        let ids = Set(chord.map(\.id))
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey(ids, by: 1, key: Self.cMajor,
                                                                   in: chord)).map(\.pitch),
                       [62, 65, 69], "C E G one step up is D F A")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey(ids, by: -1, key: Self.cMajor,
                                                                   in: chord)).map(\.pitch),
                       [59, 62, 65], "one step down is B D F")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey([c.id], by: 7, key: Self.cMajor,
                                                                   in: chord)).map(\.pitch),
                       [72, 64, 67], "seven steps of a seven-note scale is an octave")
        let sharp = Note(pitch: 61, startStep: 0)
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey([sharp.id], by: 1,
                                                                   key: Self.cMajor,
                                                                   in: [sharp])).map(\.pitch),
                       [62], "an outside note's first step up is its nearest key note above (C# → D)")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey([sharp.id], by: -1,
                                                                   key: Self.cMajor,
                                                                   in: [sharp])).map(\.pitch),
                       [60], "…and down, its nearest below (C# → C, not B — M4 review)")
        let a3 = Note(pitch: 57, startStep: 0)
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey([a3.id], by: 2,
                                                                   key: MusicalKey(root: 9, scale: .minor),
                                                                   in: [a3])).map(\.pitch),
                       [60], "in A minor, A two steps up is C")
        let chromatic = MusicalKey(root: 0, scale: .chromatic)
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.transposingInKey([c.id], by: 1, key: chromatic,
                                                                   in: [c])).map(\.pitch),
                       [61], "in a chromatic key a step is a semitone")
        XCTAssertNil(ClipNoteEdit.transposingInKey(ids, by: 0, key: Self.cMajor, in: chord))
    }

    func testAGroupThatWouldLeaveTheMIDIRangeRefusesWhole() {
        let low = Note(pitch: 0, startStep: 0), top = Note(pitch: 127, startStep: 0)
        let mid = Note(pitch: 60, startStep: 0)
        XCTAssertNil(ClipNoteEdit.transposingInKey([low.id, mid.id], by: -1, key: Self.cMajor,
                                                   in: [low, mid]),
                     "C-1 has no step below it — the whole group refuses")
        XCTAssertNil(ClipNoteEdit.transposingInKey([top.id, mid.id], by: 1, key: Self.cMajor,
                                                   in: [top, mid]),
                     "G9 has no step above it inside MIDI — the whole group refuses")
    }

    // MARK: 2 — one step each on the real history

    func testEachKeyOperationIsOneUndoStep() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 61, startStep: 0), Note(pitch: 64, startStep: 4)]
        let clip = Clip(name: "M4 guard", kind: .midi, melody: MelodyClip(notes: notes))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "M4 guard", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: TimelineTime.ticksPerBar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        let ids = Set(notes.map(\.id))

        let fitted = try XCTUnwrap(ClipNoteEdit.fittingToKey(ids, key: Self.cMajor, in: notes))
        let stepped = try XCTUnwrap(ClipNoteEdit.transposingInKey(ids, by: 1, key: Self.cMajor,
                                                                  in: notes))
        for edited in [fitted, stepped] {
            XCTAssertTrue(timeline.setClipNotes(clipID: clip.id, edited, clips: clips))
            XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, edited)
            timeline.undo()
            XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, notes, "ONE Undo takes it back")
            XCTAssertFalse(timeline.canUndo, "…because it was one step")
        }
    }

    // MARK: 3 — source

    func testTheEditorReadsTheSessionKeyAndNeverWritesIt() throws {
        let editor = try source(Self.editorPath)
        XCTAssertTrue(editor.contains("@Environment(SessionContext.self) private var session"),
                      "the key comes from its one owner")
        XCTAssertTrue(editor.contains("keyClasses: Set(session.key.pitchClasses)"),
                      "the rows shade by the session key")
        XCTAssertTrue(editor.contains("key: session.key)"),
                      "the M4 buttons act on the key the rows show")
        // M4 review: `MusicalKey.name` is the ENGLISH interop spelling; the row says the key in
        // the reader's own note names (German: H, not B), handed in by `NoteNamingReader`.
        XCTAssertTrue(editor.contains("key.name(naming: naming)"), "the key row uses the reader's note names")
        XCTAssertFalse(editor.contains("Text(key.name)"), "never the English interop name on screen")
        for write in ["session.adopt(", "keyRoot =", "keyScale =", "session.key ="] {
            XCTAssertFalse(editor.contains(write), """
                PartNoteEditor writes the session key (`\(write)`). `SessionContext` is its one \
                owner; the editor reads it and the player decides (#416).
                """)
        }
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

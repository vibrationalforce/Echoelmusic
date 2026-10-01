// TheVelocityIsDrawnUnderTheNotesInOneStepTests.swift
// Echoel — workstation redesign B6a (2026-10-01): the velocity lane under the note grid.
//
// 1. PURE (`ClipNoteEdit`, END-TO-END BEHAVIOUR on shipped value types): a height in the lane is
//    a velocity in hundredths (top 1, bottom 0, NaN-safe); a stroke draws a straight line across
//    the columns it crosses and touches only TARGET notes; the drawn velocities become ONE edit of
//    the clip's notes, NaN-safe, and nil when nothing changes (so no empty undo step).
// 2. END-TO-END over a REAL `TimelineStore`/`ClipStore`: a stroke is ONE `.clipNotes` undo step.
// 3. SOURCE-TEXT SCAN: the lane is its own leaf whose finger-rate state is `@GestureState` and
//    which writes nothing — it hands the stroke over ONCE, at release, and draws every stem dim
//    on a part that is shown, not edited; the editor mounts it INSIDE the brace-matched body of
//    the grid's horizontal scroll view, after the canvas, hands it the same target set the
//    buttons use, and commits it through the one writer. Proves where text sits, not what renders.
//
// Grading (§0/§3 — no Swift toolchain): claims 1–2 transcribed into Python over models of
// `laneVelocity`, `laneStroke`, `settingVelocities` and `Note.startStep`; every expected value
// below was reproduced there. Claim 3 driven as substring/brace scans against both trees.
// On the parent (d05aa750f) the three functions and `PartVelocityLane` do not exist, so this
// file does not compile there and NO assertion has a verdict on it: ONE absence, not N findings
// (#486). REGRESSIONS: 0. FORWARD: every assertion that names a new symbol or the lane mount.
// COUNTERWEIGHTS (green on both trees, transcribed): `NoteVelocityRow(` still mounted (the
// VoiceOver path), the canvas still inside the scroll view, the editor's `@GestureState` count
// still 1, `ClipNoteEdit.targets(` still asked once. STRIPPER (#453): TRAGEND — 2 verdicts flip
// raw vs `codeOnly` on the worktree (the lane's banned `setClipNotes` matches its own header
// comment; the editor's `@GestureState` count reads 3 raw, 1 stripped). The same commit moves
// the writer count in `TheSelectedPartsNotesAreEditedThroughOneWriterTests` 10 → 11.
// NOT covered: that the lane renders under the right column, that a hold-and-slide does not
// fight the horizontal scroll, that the new velocity is heard — device probes, owned below.
// NEEDS-FOUNDER-VERIFY: Notes → a part with four notes → tap under the second note near the top
// (only its stem rises; the Velocity row reads it) → hold under the first note, slide to the
// fourth and down (a falling ramp) → Undo once (the whole ramp goes back) → select one note,
// stroke across all four (only the selected stem moves) → swipe sideways on the lane without
// holding (the part scrolls, no stem moves).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheVelocityIsDrawnUnderTheNotesInOneStepTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let lanePath = "Sources/Echoelmusic/Studio/PartVelocityLane.swift"
    private static let step = Note.ticksPerStep
    private static let bar = TimelineTime.ticksPerBar
    private static let stepWidth = 22.0
    /// The lane's own height (#416) — not a restatement of it.
    private static let height = Double(PartVelocityLane.height)

    // MARK: 1 — pure

    func testAHeightInTheLaneIsAVelocityInHundredths() throws {
        let h = Self.height
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: 0, height: h)), 1, "the top edge is full")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: h, height: h)), 0, "the bottom edge is silent")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: h / 2, height: h)), 0.5, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: 32, height: h)), 0.33, accuracy: 1e-6,
                       "rounded to the two decimals the Velocity row prints")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: -20, height: h)), 1, "above the lane is full, not more")
        XCTAssertEqual(try XCTUnwrap(ClipNoteEdit.laneVelocity(atY: 90, height: h)), 0, "below the lane is silent, not less")
        XCTAssertNil(ClipNoteEdit.laneVelocity(atY: .nan, height: h), "a NaN point draws nothing")
        XCTAssertNil(ClipNoteEdit.laneVelocity(atY: 10, height: 0), "a lane with no height draws nothing")
    }

    func testAStrokeDrawsAStraightLineAcrossTheTargetsItCrosses() {
        let w = Self.stepWidth, h = Self.height
        let first = Note(pitch: 60, startStep: 0), second = Note(pitch: 62, startStep: 2)
        let third = Note(pitch: 64, startStep: 4), chord = Note(pitch: 67, startStep: 2)
        let notes = [first, second, third, chord]
        let all = Set(notes.map(\.id))
        // From the top of column 0 to the bottom of column 4: a falling ramp.
        let ramp = ClipNoteEdit.laneStroke(fromX: 5, y0: 0, toX: 4 * w + 5, y1: h,
                                           stepWidth: w, height: h, notes: notes, targets: all)
        XCTAssertEqual(ramp[first.id], 1)
        XCTAssertEqual(ramp[second.id], 0.5, "the middle column takes the line's middle")
        XCTAssertEqual(ramp[chord.id], 0.5, "a chord's notes share a column and move together")
        XCTAssertEqual(ramp[third.id], 0)
        // The same stroke drawn right to left: the START column takes the start height.
        let back = ClipNoteEdit.laneStroke(fromX: 4 * w + 5, y0: 0, toX: 5, y1: h,
                                           stepWidth: w, height: h, notes: notes, targets: all)
        XCTAssertEqual(back[third.id], 1)
        XCTAssertEqual(back[first.id], 0)
        // A stroke that stays in one column follows the finger's CURRENT height.
        let drag = ClipNoteEdit.laneStroke(fromX: 2 * w + 3, y0: 40, toX: 2 * w + 10, y1: 12,
                                           stepWidth: w, height: h, notes: notes, targets: all)
        XCTAssertEqual(drag.count, 2, "only the column under the finger")
        XCTAssertEqual(drag[second.id], 0.75)
        // Only targets: a selection of one keeps every other stem where it is.
        let picked = ClipNoteEdit.laneStroke(fromX: 5, y0: 0, toX: 4 * w + 5, y1: h,
                                             stepWidth: w, height: h, notes: notes, targets: [second.id])
        XCTAssertEqual(picked, [second.id: 0.5], "a stem that is not a target never moves")
        XCTAssertTrue(ClipNoteEdit.laneStroke(fromX: 5, y0: 0, toX: 4 * w + 5, y1: h,
                                              stepWidth: w, height: h, notes: notes, targets: []).isEmpty,
                      "no target, nothing drawn — a selection off screen is never redrawn unseen")
        XCTAssertTrue(ClipNoteEdit.laneStroke(fromX: 6 * w, y0: 0, toX: 9 * w, y1: h,
                                              stepWidth: w, height: h, notes: notes, targets: all).isEmpty,
                      "a stroke over empty columns draws nothing")
        XCTAssertTrue(ClipNoteEdit.laneStroke(fromX: .nan, y0: 0, toX: 5, y1: h,
                                              stepWidth: w, height: h, notes: notes, targets: all).isEmpty)
        XCTAssertTrue(ClipNoteEdit.laneStroke(fromX: 5, y0: 0, toX: 5, y1: h,
                                              stepWidth: 0, height: h, notes: notes, targets: all).isEmpty)
        XCTAssertTrue(ClipNoteEdit.laneStroke(fromX: -1e300, y0: 0, toX: 1e300, y1: h,
                                              stepWidth: w, height: h, notes: notes, targets: all).count == 4,
                      "a wild coordinate is bounded, never a trap in `Int(_:)`")
    }

    func testTheDrawnVelocitiesAreOneNaNSafeEditOfTheClip() throws {
        let a = Note(pitch: 60, startStep: 0, velocity: 0.2)
        let b = Note(pitch: 62, startStep: 1, velocity: 0.6)
        let c = Note(pitch: 64, startStep: 2, velocity: 0.9)
        let clip = [a, b, c]
        let drawn = try XCTUnwrap(ClipNoteEdit.settingVelocities([a.id: 0.5, b.id: 0.7], in: clip))
        XCTAssertEqual(drawn.map(\.velocity), [0.5, 0.7, 0.9], "each its own value; an undrawn note untouched")
        XCTAssertEqual(drawn.map(\.id), clip.map(\.id), "order and identity kept")
        let wild = try XCTUnwrap(ClipNoteEdit.settingVelocities([a.id: .nan, b.id: 4], in: clip))
        XCTAssertEqual(wild[0].velocity, 0, "a NaN never reaches a note — it traps at export")
        XCTAssertEqual(wild[1].velocity, 1)
        XCTAssertNil(ClipNoteEdit.settingVelocities([a.id: 0.2, c.id: 0.9], in: clip),
                     "a stroke that redraws what is there commits no step")
        XCTAssertNil(ClipNoteEdit.settingVelocities([:], in: clip))
        XCTAssertNil(ClipNoteEdit.settingVelocities([UUID(): 0.3], in: clip), "an id the clip does not hold is ignored")
    }

    // MARK: 2 — one step on the real history

    func testAStrokeIsOneUndoStepOnTheSongsHistory() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 60, startTick: 0, lengthTicks: Self.step),
                     Note(pitch: 62, startTick: 2 * Self.step, lengthTicks: Self.step),
                     Note(pitch: 64, startTick: 4 * Self.step, lengthTicks: Self.step)]
        let clip = Clip(name: "B6a guard", kind: .midi, melody: MelodyClip(notes: notes))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = clip
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the clip")
        let lane = TimelineLane(name: "B6a guard", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0,
                                    lengthTicks: Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")

        let stroke = ClipNoteEdit.laneStroke(fromX: 5, y0: 0, toX: 4 * Self.stepWidth + 5, y1: Self.height,
                                             stepWidth: Self.stepWidth, height: Self.height,
                                             notes: notes, targets: Set(notes.map(\.id)))
        let ramp = try XCTUnwrap(ClipNoteEdit.settingVelocities(stroke, in: notes))
        XCTAssertTrue(timeline.setClipNotes(clipID: clip.id, ramp, clips: clips))
        XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes.map(\.velocity), [1, 0.5, 0])
        timeline.undo()
        XCTAssertEqual(clips.clip(id: clip.id)?.melody?.notes, notes, "ONE Undo takes the whole stroke back")
        XCTAssertFalse(timeline.canUndo, "…because it was one step")
    }

    // MARK: 3 — source

    func testTheLaneIsALeafThatWritesOnceAtRelease() throws {
        let lane = try source(Self.lanePath)
        XCTAssertTrue(lane.contains("@GestureState private var live: [UUID: Float]?"),
                      "the stroke's preview is gesture-local — only the lane redraws at finger rate")
        XCTAssertTrue(lane.contains("LongPressGesture(minimumDuration: 0.3)")
                      && lane.contains(".sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))"),
                      "hold first, then slide — the grid's gesture, so a swipe still scrolls the part")
        let updating = try body(of: ".updating($live) {", in: lane)
        for banned in ["onRelease", "setClipNotes", "clipStore", "timeline"] {
            XCTAssertFalse(updating.contains(banned),
                           "the per-sample closure touches `\(banned)` — nothing may be handed over while the finger moves")
        }
        XCTAssertTrue(updating.contains("Self.resolve("), "the preview is the rule the release uses")
        let ended = try body(of: ".onEnded {", in: lane)
        XCTAssertTrue(ended.contains("onRelease(Self.resolve("), "the one hand-over happens at release, through the same rule")
        let resolve = try body(of: "private nonisolated static func resolve(", in: lane)
        XCTAssertTrue(resolve.contains("ClipNoteEdit.laneStroke("), "one stroke rule, in the pure file (#416)")
        for banned in ["setClipNotes", "updateMelody", "clipStore", "TimelineStore", "currentTick", "player.",
                       ".sheet(", ".fullScreenCover(", "Slider(", "Stepper("] {
            XCTAssertFalse(lane.contains(banned), """
                PartVelocityLane contains `\(banned)`. The lane owns no store, reads no clock and \
                presents no modal: it hands a stroke to the editor, which writes through the one writer.
                """)
        }
        XCTAssertTrue(lane.contains(".accessibilityHidden(true)"),
                      "VoiceOver's velocity path is the Velocity row; the lane must not read as an unlabelled element")
        XCTAssertTrue(lane.contains("let color = editable && targets.contains(note.id) ? EchoelTheme.accent : EchoelTheme.dim"),
                      "a part that is shown, not edited, draws every stem dim — no stem may promise a stroke that changes nothing")
    }

    func testTheEditorMountsTheLaneInTheGridsScrollViewAndCommitsOnce() throws {
        let editor = try source(Self.editorPath)
        // The brace-matched body of the ONE horizontal scroll view (#408 — the anchor occurs once
        // in the file); an ordering check against the next sibling would stay green for a lane
        // mounted after the scroll view closed (#367).
        XCTAssertEqual(editor.components(separatedBy: "ScrollView(.horizontal, showsIndicators: true) {").count - 1, 1,
                       "the anchor is unique, so the body below is the grid's scroll view")
        let scroll = try body(of: "ScrollView(.horizontal, showsIndicators: true) {", in: editor)
        guard let canvas = scroll.range(of: "PartNoteCanvas(visible: visible, steps: steps, grid: grid, naming: naming,"),
              let mount = scroll.range(of: "PartVelocityLane(notes: onScreen, targets: targets, steps: steps,") else {
            return XCTFail("ANCHOR MISSING: the canvas or the lane mount inside the grid's horizontal scroll view (#454)")
        }
        XCTAssertLessThan(canvas.lowerBound, mount.lowerBound,
                          "the lane rides in the grid's scroll view, UNDER the canvas, so a stem stays under its note's column")
        XCTAssertEqual(editor.components(separatedBy: "PartVelocityLane(").count - 1, 1, "mounted once")
        XCTAssertTrue(editor.contains("stepWidth: Self.stepWidth, editable: editable,"),
                      "the grid's own column width — one width for notes and stems")
        XCTAssertTrue(editor.contains("drawVelocities(drawn, region: region)"))
        // One target set for the lane AND the buttons (#416): the M3 rule, asked once.
        XCTAssertEqual(editor.components(separatedBy: "ClipNoteEdit.targets(").count - 1, 1, """
            the target rule is asked once in the editor and handed to both the lane and the buttons \
            (#416). A legitimate second consumer takes the same `targets` value; if a surface \
            genuinely needs a DIFFERENT rule, it belongs in `ClipNoteEdit` under its own name and \
            this count moves in the same commit with the reason (#364).
            """)
        XCTAssertTrue(editor.contains("selectionControls(targets: targets,"), "the buttons act on the lane's targets")
        let draw = try body(of: "private func drawVelocities(", in: editor)
        XCTAssertTrue(draw.contains("ClipNoteEdit.settingVelocities("))
        XCTAssertEqual(draw.components(separatedBy: "timeline.setClipNotes(").count - 1, 1,
                       "one stroke, one commit through the one writer, one undo step")
        // Counterweights: the numeric, VoiceOver-reachable path stays, and the drag law's one
        // finger-rate state in the EDITOR file is still the canvas's.
        XCTAssertTrue(editor.contains("NoteVelocityRow(shown: mean, mixed: mixed, targets: targets, what: what)"),
                      "the Velocity row (EchoelValueField) stays — the lane has no VoiceOver path of its own")
        XCTAssertEqual(editor.components(separatedBy: "@GestureState").count - 1, 1,
                       "the lane's gesture state lives in its own file, not in the grid that reads the stores")
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

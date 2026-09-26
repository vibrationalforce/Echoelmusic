//
//  NoteGridGesture.swift
//  Echoelmusic — Studio (Phase 3 / Creation Workflow, MIDI editor slice M2)
//
//  WHAT ONE PRESS-HOLD-AND-SLIDE ON THE NOTE GRID MEANS — decided once, as a pure value, so the
//  preview the finger sees and the commit at release are the SAME arithmetic (#416). The grid
//  (`PartNoteEditor`) keeps the live value in `@GestureState` and hands the final one to
//  `ClipNoteEdit` exactly once, when the finger lifts.
//
//  Where the hold starts decides the gesture, in `RollHitTest`'s own words:
//  · on a note's RIGHT EDGE → move that note's END by the whole steps the finger slid (at least
//    one step long, never past the part; a hold without a slide stretches nothing);
//  · on a note's BODY → move the selection by whole steps and semitones — the whole on-screen
//    selection when the note is part of it, otherwise that note alone;
//  · on an EMPTY cell → a selection box; the notes it touches JOIN the selection (M9, `boxing`).
//
//  ⭐ A MOVE NEVER TAKES A NOTE OUT OF WHAT THE USER CAN SEE OR HEAR. The step delta keeps every
//  moved note's start inside the part (the player skips a note that starts outside its window),
//  and the pitch delta keeps every moved note on the rows shown. The clamp is per GROUP, so the
//  notes keep their spacing; a zero slide is always a zero move. The LEFT bound counts whole
//  steps below the earliest START TICK, not its rounded column, so an unquantized note is never
//  pushed before the part (M2 review). ⚠️ The right bound stays on the rounded column: a part
//  whose length is not a whole number of steps can therefore draw a moved note's start a few
//  ticks past where the commit clamps it — same column, never a different pitch or step.
//  ⛔ `RollHitTest.clampedGroupDelta` (from the deleted roll) is deliberately NOT used: it bounds
//  a note's END by the part, and an imported note that already reaches past a trimmed part
//  would give it a negative upper bound — a hold with no slide would then MOVE the note.
//
//  Foundation only; screen geometry travels as Doubles in the grid's own coordinates.

import Foundation

/// The meaning of one press-hold-and-slide on the note grid.
enum NoteGridGesture: Equatable, Sendable {
    /// Move `ids` by whole semitones and whole steps.
    case move(ids: Set<UUID>, dPitch: Int, dStep: Int)
    /// Move one note's END by `dSteps` whole steps. A DELTA, never an absolute length (M2 review):
    /// an absolute length re-stated the note's drawn length on a hold without a slide, and that
    /// committed a step — re-quantizing an imported 455-tick note, or writing a part-cut length
    /// into a clip another part plays longer. A zero delta commits nothing, like a zero move.
    case resize(id: UUID, dSteps: Int)
    /// A selection box from (x0, y0) to (x1, y1); `ids` are the on-screen notes it touches.
    case marquee(ids: Set<UUID>, x0: Double, y0: Double, x1: Double, y1: Double)

    /// The grid's geometry: cell size, the rows shown, and the part's own step count (not the
    /// widened column count — creation, moves and stretches stay inside the part).
    struct Grid: Equatable, Sendable {
        var stepWidth: Double
        var rowHeight: Double
        var rows: ClosedRange<Int>
        var partSteps: Int
    }

    /// Points at a note's right end that grab its length rather than its body.
    static let edgeSlop: Double = 8

    /// Whether this gesture changes notes (a box only selects).
    var edits: Bool {
        if case .marquee = self { return false }
        return true
    }

    /// Decide what a hold starting at (`startX`, `startY`) and slid by (`dx`, `dy`) means.
    static func resolve(startX: Double, startY: Double, dx: Double, dy: Double,
                        visible: [Note], picked: Set<UUID>, grid: Grid) -> NoteGridGesture {
        let onScreen = visible.filter { grid.rows.contains($0.pitch) }
        let hit = RollHitTest.classify(x: startX, y: startY, notes: onScreen,
                                       stepW: grid.stepWidth, rowH: grid.rowHeight,
                                       highPitch: grid.rows.upperBound,
                                       lowPitch: grid.rows.lowerBound,
                                       stepCount: Swift.max(1, grid.partSteps),
                                       edgeSlop: edgeSlop)
        switch hit {
        case .rightEdge(let id):
            guard let note = onScreen.first(where: { $0.id == id }), grid.stepWidth > 0 else {
                return .resize(id: id, dSteps: 0)
            }
            // The steps the finger SLID, rounded — the rule a body move uses. Not the column
            // boundaries it crossed: the grab zone is the last 8 points before a boundary, so a
            // 2-point drift to the right crossed one and committed a step (M4 review).
            let slid = Int((dx / grid.stepWidth).rounded())
            let drawn = note.lengthSteps
            let room = Swift.max(1, grid.partSteps - note.startStep)
            // Bounded so the drawn length stays 1…room; both bounds contain zero.
            let dSteps = Swift.min(Swift.max(slid, 1 - drawn), Swift.max(0, room - drawn))
            return .resize(id: id, dSteps: dSteps)
        case .body(let id):
            let shown = Set(onScreen.map(\.id))
            let ids = picked.contains(id) ? picked.intersection(shown) : [id]
            let moving = onScreen.filter { ids.contains($0.id) }
            let wantStep = grid.stepWidth > 0 ? Int((dx / grid.stepWidth).rounded()) : 0
            let wantPitch = grid.rowHeight > 0 ? -Int((dy / grid.rowHeight).rounded()) : 0
            let delta = clampedMove(dPitch: wantPitch, dStep: wantStep, moving: moving,
                                    rows: grid.rows, partSteps: grid.partSteps)
            return .move(ids: ids, dPitch: delta.dPitch, dStep: delta.dStep)
        case .empty:
            let ids = RollHitTest.notesInRect(x0: startX, y0: startY, x1: startX + dx, y1: startY + dy,
                                              notes: onScreen, stepW: grid.stepWidth,
                                              rowH: grid.rowHeight, highPitch: grid.rows.upperBound)
            return .marquee(ids: Set(ids), x0: startX, y0: startY, x1: startX + dx, y1: startY + dy)
        }
    }

    /// The group delta, clamped so every moved note starts inside the part and sits on a row
    /// shown. Both bounds always contain zero, so no slide means no move.
    static func clampedMove(dPitch: Int, dStep: Int, moving: [Note], rows: ClosedRange<Int>,
                            partSteps: Int) -> (dPitch: Int, dStep: Int) {
        // The LEFT bound is in whole steps BELOW the earliest start (floor, not the rounded
        // `startStep`): a note at tick 60 rounds to step 1, and a −1 move would push it before
        // the part and squeeze the group's spacing (M2 review).
        guard let lowPitch = moving.map(\.pitch).min(), let highPitch = moving.map(\.pitch).max(),
              let first = moving.map({ Swift.max(0, $0.startTick) / Note.ticksPerStep }).min(),
              let last = moving.map(\.startStep).max()
        else { return (0, 0) }
        let pitch = Swift.min(Swift.max(dPitch, Swift.min(0, rows.lowerBound - lowPitch)),
                              Swift.max(0, rows.upperBound - highPitch))
        let step = Swift.min(Swift.max(dStep, -Swift.max(0, first)),
                             Swift.max(0, partSteps - 1 - last))
        return (pitch, step)
    }

    /// The notes as the finger sees them mid-gesture (window-relative, as the grid draws them).
    func applied(to visible: [Note]) -> [Note] {
        switch self {
        case .move(let ids, let dPitch, let dStep):
            guard dPitch != 0 || dStep != 0 else { return visible }
            return visible.map { note in
                guard ids.contains(note.id) else { return note }
                var moved = note
                moved.pitch = Swift.min(Swift.max(note.pitch + dPitch, 0), 127)
                moved.startTick = Swift.max(0, note.startTick + dStep * Note.ticksPerStep)
                return moved
            }
        case .resize(let id, let dSteps):
            guard dSteps != 0 else { return visible }
            return visible.map { note in
                guard note.id == id else { return note }
                var stretched = note
                stretched.lengthTicks = Swift.max(1, note.lengthSteps + dSteps) * Note.ticksPerStep
                return stretched
            }
        case .marquee:
            return visible
        }
    }

    /// The selection a TAP leaves: the note joins it, or leaves it if it was already in.
    static func toggling(_ id: UUID, in picked: Set<UUID>) -> Set<UUID> {
        var next = picked
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        return next
    }

    /// The selection a BOX leaves (M9): the boxed notes JOIN it, like a tap's. A box that
    /// replaced the selection dropped every note picked elsewhere — two octaves away, or in the
    /// bar before — so a selection could not be built from two boxes. Deselect clears it. The
    /// canvas lights the same set while the finger slides, so the preview is the commit.
    static func boxing(_ ids: Set<UUID>, into picked: Set<UUID>) -> Set<UUID> {
        picked.union(ids)
    }

    /// The selection a finished MOVE leaves (M8–M10 review repair). A drag that grabbed a PICKED
    /// note moved the picks on screen (`resolve`: `picked ∩ shown`), so the selection keeps the
    /// ones it did not move — the picks off screen. A drag that grabbed an UNPICKED note moved that
    /// note alone, and it alone is the selection afterwards: that is what the canvas lit during the
    /// drag, and folding the old picks back in would light notes the finger never touched and hand
    /// them to the next Delete.
    static func afterMove(_ moved: Set<UUID>, from picked: Set<UUID>) -> Set<UUID> {
        moved.isSubset(of: picked) ? picked.union(moved) : moved
    }
}

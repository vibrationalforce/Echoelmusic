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
//  · on a note's RIGHT EDGE → stretch that note (whole steps, at least one, never past the part);
//  · on a note's BODY → move the selection by whole steps and semitones — the whole on-screen
//    selection when the note is part of it, otherwise that note alone;
//  · on an EMPTY cell → a selection box; the notes it touches become the selection.
//
//  ⭐ A MOVE NEVER TAKES A NOTE OUT OF WHAT THE USER CAN SEE OR HEAR. The step delta keeps every
//  moved note's start inside the part (the player skips a note that starts outside its window),
//  and the pitch delta keeps every moved note on the rows shown. The clamp is per GROUP, so the
//  notes keep their spacing; a zero slide is always a zero move.
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
    /// Stretch or shorten one note to `lengthSteps`.
    case resize(id: UUID, lengthSteps: Int)
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
                return .resize(id: id, lengthSteps: 1)
            }
            let finger = Int(((startX + dx) / grid.stepWidth).rounded(.down))
            let wanted = RollHitTest.resizedLengthSteps(fingerStep: finger, startStep: note.startStep)
            let room = Swift.max(1, grid.partSteps - note.startStep)
            return .resize(id: id, lengthSteps: Swift.min(wanted, room))
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
        guard let lowPitch = moving.map(\.pitch).min(), let highPitch = moving.map(\.pitch).max(),
              let first = moving.map(\.startStep).min(), let last = moving.map(\.startStep).max()
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
        case .resize(let id, let lengthSteps):
            return visible.map { note in
                guard note.id == id else { return note }
                var stretched = note
                stretched.lengthTicks = Swift.max(1, lengthSteps) * Note.ticksPerStep
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
}

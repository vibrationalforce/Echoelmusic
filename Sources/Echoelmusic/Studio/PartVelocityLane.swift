//
//  PartVelocityLane.swift
//  Echoelmusic — Studio (workstation redesign B6a, 2026-10-01)
//
//  WHY THIS EXISTS. The note grid shows a note's velocity only as depth of colour (design slice
//  12), and the one control that changed it was the Velocity row, which sets every target to ONE
//  value. A crescendo, an accent on the downbeat, a ghost note — the everyday dynamics of a part —
//  had no way in. This lane sits under the grid and draws each note's velocity as a stem under its
//  column; a tap sets the stems in one column, a press-hold-and-slide draws a straight line.
//
//  ⭐ THE DRAG LAW, the grid's own (M2): finger samples → a GESTURE-LOCAL preview (`live` is
//  `@GestureState`, so only this leaf redraws at finger rate and a scroll that cancels the
//  gesture leaves nothing behind) → ONE hand-over when the finger lifts → ONE `setClipNotes` in
//  the editor → ONE undo step. Preview and commit are the same value (`ClipNoteEdit.laneStroke`).
//  This file holds no store and writes nothing itself.
//
//  WHAT IT DRAWS AND CHANGES: the notes on the rows the grid shows (a note scrolled off by
//  Lower/Higher has no stem — nothing is changed unseen), and of those only the M3 targets
//  (`ClipNoteEdit.targets`: the selection, or the whole part when nothing is selected). A stem
//  that is not a target is drawn dim and never moves — and on a part that is shown, not edited
//  (composer-owned), EVERY stem is dim, because no stroke there changes anything.
//
//  ⚠️ WHAT IT DOES NOT DO, so the surface does not read as more: no freehand curve (a stroke is
//  ONE straight line from where the finger went down to where it is), no per-note pick inside a
//  column (a chord's notes share a column and move together — select one note first to move it
//  alone), no CC, pitch-bend or pressure lanes (B6b), and no VoiceOver path of its own: the lane
//  is hidden from VoiceOver, whose way to velocity is the Velocity row below the buttons.
//
//  Cold reads only: everything arrives as a value from the grid, which reads no clock.
//

import SwiftUI

/// The velocity of each note on screen as a stem under its column of the note grid, and the
/// stroke that redraws them.
@MainActor
struct PartVelocityLane: View {

    /// The notes on the rows the grid draws, region-relative (the grid's own `onScreen`).
    let notes: [Note]
    /// What a stroke may change — `ClipNoteEdit.targets`, decided by the grid.
    let targets: Set<UUID>
    /// The grid's column count, so the lane is exactly as wide as the notes above it.
    let steps: Int
    /// The grid's column width — one width for notes and stems.
    let stepWidth: CGFloat
    /// A composer-owned part is shown, not edited: the stems draw, a stroke does nothing.
    let editable: Bool
    /// The drawn velocities, handed over ONCE when the finger lifts (or on a tap).
    let onRelease: ([UUID: Float]) -> Void

    /// Tall enough to aim a velocity and to be a 44 pt touch target.
    nonisolated static let height: CGFloat = 48

    @GestureState private var live: [UUID: Float]? = nil

    var body: some View {
        let stepW = stepWidth
        let drawn = live ?? [:]
        let notes = self.notes
        let targets = self.targets
        let steps = self.steps
        let editable = self.editable
        Canvas { context, size in
            // Beats and bars, the grid's own lines, so a stem reads under its note.
            for step in stride(from: 0, through: steps, by: 4) {
                let x = CGFloat(step) * stepW
                let color = step % 16 == 0 ? EchoelTheme.borderStrong.opacity(0.5) : EchoelTheme.border
                context.fill(Path(CGRect(x: x, y: 0, width: step % 16 == 0 ? 1 : 0.5,
                                         height: size.height)), with: .color(color))
            }
            // Stems: a 3 pt bar from the bottom to the velocity, capped by a short top line so a
            // silent note still shows where it sits. Drawn at the note's own left edge — the x the
            // grid draws its block at.
            for note in notes {
                let velocity = CGFloat((drawn[note.id] ?? note.velocity).clamped(to: 0...1))
                let top = Swift.min((1 - velocity) * size.height, size.height - 2)
                let x = CGFloat(note.startStep) * stepW + 1
                let color = editable && targets.contains(note.id) ? EchoelTheme.accent : EchoelTheme.dim
                context.fill(Path(CGRect(x: x, y: top, width: 3, height: size.height - top)),
                             with: .color(color))
                context.fill(Path(CGRect(x: x, y: top, width: Swift.max(3, Swift.min(stepW - 2, 10)),
                                         height: 2)), with: .color(color))
            }
        }
        .frame(width: CGFloat(steps) * stepW, height: Self.height)
        .background(EchoelTheme.surface)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in tap(location) }
        .gesture(strokeGesture)
        .accessibilityHidden(true)
    }

    /// A tap sets the target stems in the tapped column to the tapped height — one hand-over.
    private func tap(_ location: CGPoint) {
        guard editable else { return }
        onRelease(ClipNoteEdit.laneStroke(fromX: Double(location.x), y0: Double(location.y),
                                          toX: Double(location.x), y1: Double(location.y),
                                          stepWidth: Double(stepWidth), height: Double(Self.height),
                                          notes: notes, targets: targets))
    }

    /// Hold first, then slide — the grid's own gesture, so a swipe that starts on the lane still
    /// scrolls the part.
    private var strokeGesture: some Gesture {
        // Values, captured once per body — the gesture closures read no view state.
        let notes = self.notes
        let targets = self.targets
        let stepW = Double(stepWidth)
        let laneH = Double(Self.height)
        let editable = self.editable
        return LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($live) { value, state, _ in
                guard editable, case .second(true, let drag?) = value else { return }
                state = Self.resolve(drag, notes: notes, targets: targets, stepWidth: stepW,
                                     height: laneH)
            }
            .onEnded { value in
                guard editable, case .second(true, let drag?) = value else { return }
                onRelease(Self.resolve(drag, notes: notes, targets: targets, stepWidth: stepW,
                                       height: laneH))
            }
    }

    /// What a slide means — the one rule the preview and the hand-over share.
    private nonisolated static func resolve(_ drag: DragGesture.Value, notes: [Note],
                                            targets: Set<UUID>, stepWidth: Double,
                                            height: Double) -> [UUID: Float] {
        ClipNoteEdit.laneStroke(fromX: Double(drag.startLocation.x), y0: Double(drag.startLocation.y),
                                toX: Double(drag.location.x), y1: Double(drag.location.y),
                                stepWidth: stepWidth, height: height, notes: notes, targets: targets)
    }
}

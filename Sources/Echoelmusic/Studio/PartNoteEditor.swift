//
//  PartNoteEditor.swift
//  Echoelmusic — Studio (Phase 3 / Creation Workflow, MIDI editor slice M1)
//
//  WHY THIS EXISTS. The Workstation could place, cut and move a MIDI part but not change a note
//  in it — `PianoRollView` went with #475 and nothing replaced it. This is the note editor for
//  the part selected on the Arrange canvas, inline under its part bar: see the part's notes,
//  tap an empty cell to add one, tap notes to select them, delete the selection, and take any of
//  it back with the Workstation's one Undo. Since M2: press and hold, then slide — on a note to
//  move the selection, on its right edge to stretch it, on an empty cell to box-select. An edit is heard from the next step while the song
//  plays (`TimelineRegionPlayer.refreshNoteContent`), not only from the part's next start.
//
//  ⭐ ONE OWNER, ONE WRITER, ONE HISTORY. The notes are the clip's (`ClipStore`,
//  `Clip.melody.notes`); the part is a window onto them (`ClipNoteEdit`). Every edit builds the
//  whole new list locally and commits it ONCE through `TimelineStore.setClipNotes` — one call,
//  one undo step, on the same stack `SongHistoryRow` drives. `PianoRollModel` is the playback
//  buffer and is never written from here.
//
//  ⭐ THE DRAG LAW (M2, founder performance law): finger samples → a GESTURE-LOCAL preview
//  (`@GestureState` in the `PartNoteCanvas` leaf, so only the canvas redraws at finger rate and
//  a scroll that cancels the gesture leaves nothing behind) → ONE commit when the finger lifts
//  → ONE undo step. Preview and commit are the same value (`NoteGridGesture.resolve`). Nothing
//  is persisted per sample. Hold first, like the Arrange canvas, so a swipe still scrolls.
//
//  Since M3: Transpose (±1, ±12), Quantize (starts to the part's sixteenths), Duplicate (the
//  copies land right after the selection and become it) and Velocity — each acts on the selection
//  on screen, or on the whole part when nothing is selected (`ClipNoteEdit.targets`); a selection
//  that is not on screen acts on NOTHING, and the row says which of the three it is. A button is
//  enabled only when its operation would change something, and each is ONE commit. The Velocity drag edits a draft in its own leaf (`NoteVelocityRow`) and writes once,
//  when it ends.
//
//  Since M4: the rows shade the notes OUTSIDE the session key (`SessionContext.key`, read and
//  never written here), "Fit" moves the targets to the nearest key notes, and "−1 step" / "+1
//  step" transpose them by one step of the key's scale — each ONE commit.
//
//  ⚠️ WHAT IT DOES NOT DO, stated so the surface does not read as more: no scale LOCK — a tap
//  or a drag may still place a note outside the key (the shading shows it; Fit repairs it), no
//  playhead, no auto-scroll while dragging (a move stays
//  on the rows and inside the part shown), and the grid is touch-only — VoiceOver hears its
//  summary, not the cells. A composer-owned part is
//  shown and not edited (evolve rewrites it); a part saved before tick offsets is not shown.
//  The rows centre ONCE per opened part (`@State centre`) and never follow the notes, so an
//  add or an undo cannot move a row under the finger. Delete acts only on selected notes that
//  are ON SCREEN — a note scrolled out by Lower/Higher is never removed unseen.
//
//  Cold reads only: the selection, `timeline.document` and the clip grid change on a tap, an
//  import or a composer evolve (~25–45 s) — never on a clock. No transport, tempo or playhead is
//  read here, so the leaf cannot churn the menu host above it.
//

import SwiftUI

/// The notes of the MIDI part selected on the Arrange canvas — a "Notes" switch, then the grid.
@MainActor
struct PartNoteEditor: View {

    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// View state: whether the grid is open. Not part of the song, never persisted.
    @State private var isOpen = false

    var body: some View {
        let document = timeline.document
        if let regionID = WorkstationSelection.resolvedRegion(selection.regionID,
                                                              track: selection.trackID, in: document),
           let region = document.regions.first(where: { $0.id == regionID }),
           let lane = document.lanes.first(where: { $0.id == region.laneID }),
           lane.kind == .midi, !lane.isBio {
            VStack(alignment: .leading, spacing: 6) {
                Button { isOpen.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Notes").font(EchoelTheme.font(12, .semibold))
                    }
                    .foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.fill))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Hide the selected part's notes"
                                           : "Show the selected part's notes")
                if isOpen {
                    // Keyed by the part: another part starts with an empty selection and its
                    // own octave, never with the last part's.
                    PartNoteGrid(regionID: regionID)
                        .id(regionID)
                }
            }
        }
    }
}

/// The grid of one part's notes. Local state is view state only: which notes are picked and
/// which octaves are shown.
@MainActor
private struct PartNoteGrid: View {

    let regionID: UUID

    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    /// The key the rows shade and the M4 buttons use. Read, never written: `SessionContext` is
    /// the one owner of the key, and it changes on a user choice or a composer take — never on
    /// a clock, so this is a cold read.
    @Environment(SessionContext.self) private var session
    @State private var picked: RollSelection = .none
    @State private var octaveShift = 0
    /// The pitch the rows centre on — taken when the grid first draws, then held.
    @State private var centre: Int?

    private static let stepWidth: CGFloat = 22
    private static let rowHeight: CGFloat = 14

    var body: some View {
        let document = timeline.document
        if let region = document.regions.first(where: { $0.id == regionID }) {
            let clip = clipStore.clip(id: region.clipID)
            let refusal = ClipNoteEdit.refusal(clip: clip, region: region)
            VStack(alignment: .leading, spacing: 6) {
                if let clip, clip.kind == .midi, let offset = ClipNoteEdit.windowOffset(of: region) {
                    let visible = ClipNoteEdit.visibleNotes(clip.melody?.notes ?? [],
                                                            offsetTicks: offset,
                                                            lengthTicks: region.lengthTicks)
                    let steps = ClipNoteEdit.columnCount(lengthTicks: region.lengthTicks,
                                                         visible: visible)
                    let heldCentre = centre ?? ClipNoteEdit.centrePitch(of: visible)
                    let range = ClipNoteEdit.pitchRange(centre: heldCentre, octaveShift: octaveShift)
                    let editable = refusal == nil
                    let pickedOnScreen = Set(visible.filter {
                        range.contains($0.pitch) && picked.contains($0.id)
                    }.map(\.id))
                    let pickedCount = pickedOnScreen.count
                    let grid = NoteGridGesture.Grid(
                        stepWidth: Double(Self.stepWidth), rowHeight: Double(Self.rowHeight),
                        rows: range, partSteps: ClipNoteEdit.stepCount(lengthTicks: region.lengthTicks))
                    ScrollView(.horizontal, showsIndicators: true) {
                        PartNoteCanvas(visible: visible, steps: steps, grid: grid,
                                       picked: picked.ids, editable: editable,
                                       keyClasses: Set(session.key.pitchClasses),
                                       onTap: { location in
                                           tap(location, visible: visible, region: region,
                                               offset: offset, steps: steps, range: range,
                                               editable: editable)
                                       },
                                       onRelease: { gesture in
                                           finish(gesture, region: region, offset: offset)
                                       })
                            .accessibilityElement()
                            .accessibilityLabel("Note grid: \(visible.count) notes, \(pickedCount) selected")
                            .accessibilityHint(editable
                                ? "Touch only in this version: tap an empty cell to add a note, tap notes to select them; press and hold, then slide, to move, stretch or box-select"
                                : "Shown, not edited")
                    }
                    controls(range: range, picked: pickedOnScreen, editable: editable,
                             region: region)
                        .onAppear { if centre == nil { centre = heldCentre } }
                    if editable, !visible.isEmpty {
                        let selected = picked.ids.intersection(Set(visible.map(\.id)))
                        selectionControls(targets: ClipNoteEdit.targets(selected: selected,
                                                                         onScreen: pickedOnScreen,
                                                                         visible: visible),
                                          scope: Self.scope(selected: selected.count,
                                                            onScreen: pickedCount),
                                          clip: clip, region: region, offset: offset,
                                          range: range, heldCentre: heldCentre,
                                          key: session.key)
                    }
                    if editable {
                        Text(hint(sharedBy: document.regions.filter { $0.clipID == region.clipID }.count))
                            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    }
                }
                if let refusal {
                    Text(refusal.sentence)
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                }
            }
        }
    }

    private func hint(sharedBy parts: Int) -> String {
        let heard = "A change plays the next time the playhead reaches it."
        guard parts > 1 else { return heard }
        return "This clip plays in \(parts) parts — a change edits all of them. " + heard
    }

    // MARK: - Actions (one commit each)

    private func tap(_ location: CGPoint, visible: [Note], region: TimelineRegion, offset: Int,
                     steps: Int, range: ClosedRange<Int>, editable: Bool) {
        let hit = RollHitTest.classify(x: Double(location.x), y: Double(location.y),
                                       notes: visible,
                                       stepW: Double(Self.stepWidth), rowH: Double(Self.rowHeight),
                                       highPitch: range.upperBound, lowPitch: range.lowerBound,
                                       stepCount: steps, edgeSlop: 0)
        switch hit {
        case .body(let id), .rightEdge(let id):
            // Multi-select: a tap adds the note to the selection, or takes it out again.
            picked = RollSelection(ids: Array(NoteGridGesture.toggling(id, in: picked.ids)))
        case .empty(let pitch, let step):
            guard editable, let clip = clipStore.clip(id: region.clipID),
                  let added = ClipNoteEdit.adding(pitch: pitch, step: step,
                                                  to: clip.melody?.notes ?? [],
                                                  offsetTicks: offset,
                                                  lengthTicks: region.lengthTicks) else { return }
            if timeline.setClipNotes(clipID: region.clipID, added.notes, clips: clipStore) {
                picked = .single(added.id)
            }
        }
    }

    /// The finger lifted: a box selects; a move or a stretch is ONE commit through the one
    /// writer, and a gesture that changed nothing commits nothing.
    private func finish(_ gesture: NoteGridGesture, region: TimelineRegion, offset: Int) {
        switch gesture {
        case .marquee(let ids, _, _, _, _):
            picked = RollSelection(ids: Array(ids))
        case .move(let ids, let dPitch, let dStep):
            guard let clip = clipStore.clip(id: region.clipID),
                  let moved = ClipNoteEdit.moving(ids, dPitch: dPitch, dStep: dStep,
                                                  in: clip.melody?.notes ?? [],
                                                  offsetTicks: offset,
                                                  lengthTicks: region.lengthTicks) else { return }
            if timeline.setClipNotes(clipID: region.clipID, moved, clips: clipStore) {
                picked = RollSelection(ids: Array(ids))
            }
        case .resize(let id, let dSteps):
            guard let clip = clipStore.clip(id: region.clipID),
                  let resized = ClipNoteEdit.resizing(id, bySteps: dSteps,
                                                      in: clip.melody?.notes ?? [],
                                                      offsetTicks: offset,
                                                      lengthTicks: region.lengthTicks) else { return }
            if timeline.setClipNotes(clipID: region.clipID, resized, clips: clipStore) {
                picked = .single(id)
            }
        }
    }

    private func deletePicked(_ ids: Set<UUID>, region: TimelineRegion) {
        guard !ids.isEmpty, let clip = clipStore.clip(id: region.clipID) else { return }
        let remaining = ClipNoteEdit.removing(ids, from: clip.melody?.notes ?? [])
        if timeline.setClipNotes(clipID: region.clipID, remaining, clips: clipStore) {
            picked = .none
        }
    }

    // MARK: - M3: operations on the selection (one commit each)
    //
    // Each acts on `ClipNoteEdit.targets` — the selection on screen, or every note of the part
    // when nothing is selected — and each is ONE `setClipNotes`, so ONE Undo takes it back. A
    // button that would change nothing commits nothing (the pure op returns nil).

    private func transpose(_ ids: Set<UUID>, by semitones: Int, region: TimelineRegion,
                           range: ClosedRange<Int>, heldCentre: Int) {
        let notes = clipStore.clip(id: region.clipID)?.melody?.notes ?? []
        guard let moved = ClipNoteEdit.transposing(ids, by: semitones, in: notes),
              timeline.setClipNotes(clipID: region.clipID, moved, clips: clipStore) else { return }
        // The rows follow an octave move so the notes stay under the finger — but only a move
        // that really WAS an octave (a group clamp can make +12 a +5), and only when the rows can
        // still go that way (M3 review: at the top the shift counted on, invisibly).
        let before = notes.first { ids.contains($0.id) }?.pitch
        let after = moved.first { ids.contains($0.id) }?.pitch
        guard let before, let after, abs(after - before) == 12 else { return }
        let next = octaveShift + (after > before ? 1 : -1)
        if ClipNoteEdit.pitchRange(centre: heldCentre, octaveShift: next) != range {
            octaveShift = next
        }
    }

    private func quantize(_ ids: Set<UUID>, region: TimelineRegion, offset: Int) {
        guard let clip = clipStore.clip(id: region.clipID),
              let snapped = ClipNoteEdit.quantizing(ids, in: clip.melody?.notes ?? [],
                                                    offsetTicks: offset,
                                                    lengthTicks: region.lengthTicks) else { return }
        _ = timeline.setClipNotes(clipID: region.clipID, snapped, clips: clipStore)
    }

    private func duplicate(_ ids: Set<UUID>, region: TimelineRegion, offset: Int) {
        guard let clip = clipStore.clip(id: region.clipID),
              let copied = ClipNoteEdit.duplicating(ids, in: clip.melody?.notes ?? [],
                                                    offsetTicks: offset,
                                                    lengthTicks: region.lengthTicks) else { return }
        if timeline.setClipNotes(clipID: region.clipID, copied.notes, clips: clipStore) {
            picked = RollSelection(ids: Array(copied.ids))
        }
    }

    private func fitToKey(_ ids: Set<UUID>, key: MusicalKey, region: TimelineRegion) {
        guard let clip = clipStore.clip(id: region.clipID),
              let fitted = ClipNoteEdit.fittingToKey(ids, key: key,
                                                     in: clip.melody?.notes ?? []) else { return }
        _ = timeline.setClipNotes(clipID: region.clipID, fitted, clips: clipStore)
    }

    private func stepInKey(_ ids: Set<UUID>, by degrees: Int, key: MusicalKey,
                           region: TimelineRegion) {
        guard let clip = clipStore.clip(id: region.clipID),
              let moved = ClipNoteEdit.transposingInKey(ids, by: degrees, key: key,
                                                        in: clip.melody?.notes ?? []) else { return }
        _ = timeline.setClipNotes(clipID: region.clipID, moved, clips: clipStore)
    }

    private func setVelocity(_ ids: Set<UUID>, to velocity: Float, region: TimelineRegion) {
        guard let clip = clipStore.clip(id: region.clipID),
              let updated = ClipNoteEdit.settingVelocity(ids, to: velocity,
                                                         in: clip.melody?.notes ?? []) else { return }
        _ = timeline.setClipNotes(clipID: region.clipID, updated, clips: clipStore)
    }

    /// What the M3/M4 buttons act on, said on screen (M3 review: it reached only VoiceOver).
    private static func scope(selected: Int, onScreen: Int) -> (visible: String, spoken: String) {
        if selected == 0 { return ("All notes in this part", "every note in this part") }
        if onScreen == 0 {
            return ("Selection not on screen — Lower / Higher to see it", "no note — the selection is not on screen")
        }
        return onScreen == 1 ? ("1 selected", "the selected note")
            : ("\(onScreen) selected", "the \(onScreen) selected notes")
    }

    private func selectionControls(targets: Set<UUID>, scope: (visible: String, spoken: String),
                                   clip: Clip, region: TimelineRegion, offset: Int,
                                   range: ClosedRange<Int>, heldCentre: Int,
                                   key: MusicalKey) -> some View {
        let what = scope.spoken
        let notes = clip.melody?.notes ?? []
        // Every button is enabled only when its operation would change something (M3 review: an
        // enabled button that silently does nothing). Cold inputs — the clip and the selection.
        func can(_ edit: [Note]?) -> Bool { edit != nil }
        let length = region.lengthTicks
        return VStack(alignment: .leading, spacing: 6) {
            Text(scope.visible).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            HStack(spacing: 6) {
                Text("Transpose").font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                button("−12", "", enabled: can(ClipNoteEdit.transposing(targets, by: -12, in: notes)),
                       label: "Move \(what) down an octave") {
                    transpose(targets, by: -12, region: region, range: range, heldCentre: heldCentre)
                }
                button("−1", "", enabled: can(ClipNoteEdit.transposing(targets, by: -1, in: notes)),
                       label: "Move \(what) down a semitone") {
                    transpose(targets, by: -1, region: region, range: range, heldCentre: heldCentre)
                }
                button("+1", "", enabled: can(ClipNoteEdit.transposing(targets, by: 1, in: notes)),
                       label: "Move \(what) up a semitone") {
                    transpose(targets, by: 1, region: region, range: range, heldCentre: heldCentre)
                }
                button("+12", "", enabled: can(ClipNoteEdit.transposing(targets, by: 12, in: notes)),
                       label: "Move \(what) up an octave") {
                    transpose(targets, by: 12, region: region, range: range, heldCentre: heldCentre)
                }
            }
            HStack(spacing: 6) {
                // M4: the key is the session's (`SessionContext`), named on the row so the
                // buttons never act on a key the player cannot see.
                Text(key.name).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .lineLimit(1)
                button("Fit", "", enabled: can(ClipNoteEdit.fittingToKey(targets, key: key, in: notes)),
                       label: "Move \(what) to the nearest notes of \(key.name)") {
                    fitToKey(targets, key: key, region: region)
                }
                button("−1 step", "",
                       enabled: can(ClipNoteEdit.transposingInKey(targets, by: -1, key: key, in: notes)),
                       label: "Move \(what) down one step of \(key.name)") {
                    stepInKey(targets, by: -1, key: key, region: region)
                }
                button("+1 step", "",
                       enabled: can(ClipNoteEdit.transposingInKey(targets, by: 1, key: key, in: notes)),
                       label: "Move \(what) up one step of \(key.name)") {
                    stepInKey(targets, by: 1, key: key, region: region)
                }
            }
            HStack(spacing: 6) {
                button("Quantize", "square.grid.3x3",
                       enabled: can(ClipNoteEdit.quantizing(targets, in: notes, offsetTicks: offset,
                                                            lengthTicks: length)),
                       label: "Snap the starts of \(what) to the nearest sixteenth") {
                    quantize(targets, region: region, offset: offset)
                }
                button("Duplicate", "plus.square.on.square",
                       enabled: ClipNoteEdit.duplicating(targets, in: notes, offsetTicks: offset,
                                                         lengthTicks: length) != nil,
                       label: "Copy \(what) to right after themselves, and select the copies") {
                    duplicate(targets, region: region, offset: offset)
                }
            }
            if let mean = ClipNoteEdit.meanVelocity(targets, in: notes) {
                let mixed = Set(notes.filter { targets.contains($0.id) }.map(\.velocity)).count > 1
                NoteVelocityRow(shown: mean, mixed: mixed, targets: targets, what: what) { velocity in
                    setVelocity(targets, to: velocity, region: region)
                }
            }
        }
    }

    // MARK: - Controls

    private func controls(range: ClosedRange<Int>, picked: Set<UUID>, editable: Bool,
                          region: TimelineRegion) -> some View {
        let pickedCount = picked.count
        return HStack(spacing: 6) {
            button("Lower", "chevron.down", enabled: range.lowerBound > 0,
                   label: "Show the octave below") { octaveShift -= 1 }
            button("Higher", "chevron.up", enabled: range.upperBound < 127,
                   label: "Show the octave above") { octaveShift += 1 }
            if editable {
                button("Delete", "trash", enabled: pickedCount > 0,
                       label: pickedCount == 1 ? "Delete the selected note"
                                               : "Delete the \(pickedCount) selected notes") {
                    deletePicked(picked, region: region)
                }
            }
        }
    }

    private func button(_ title: String, _ systemImage: String, enabled: Bool, label: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                }
                Text(title).font(EchoelTheme.font(11, .semibold)).lineLimit(1)
            }
            .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// The drawn grid and its press-hold-and-slide. ⭐ THE ONLY FINGER-RATE STATE IN THE EDITOR:
/// `live` is `@GestureState`, so only this leaf redraws while a finger slides, and it resets
/// itself when the scroll view cancels the gesture. Nothing is written until the finger lifts,
/// and then exactly once, through `onRelease`.
@MainActor
private struct PartNoteCanvas: View {

    let visible: [Note]
    let steps: Int
    let grid: NoteGridGesture.Grid
    let picked: Set<UUID>
    let editable: Bool
    /// The pitch classes of the session key: rows outside it are shaded (M4). A chromatic key
    /// has no outside, so the rows fall back to the piano's black keys.
    let keyClasses: Set<Int>
    let onTap: (CGPoint) -> Void
    let onRelease: (NoteGridGesture) -> Void

    @GestureState private var live: NoteGridGesture? = nil

    var body: some View {
        let shown = live?.applied(to: visible) ?? visible
        let lit: Set<UUID> = {
            switch live {
            case .marquee(let ids, _, _, _, _)?: return ids
            case .move(let ids, _, _)?: return ids
            case .resize(let id, _)?: return [id]
            case nil: return picked
            }
        }()
        let stepW = CGFloat(grid.stepWidth)
        let rowH = CGFloat(grid.rowHeight)
        let range = grid.rows
        let high = range.upperBound
        let box: CGRect? = {
            guard case .marquee(_, let x0, let y0, let x1, let y1)? = live else { return nil }
            return CGRect(x: Swift.min(x0, x1), y: Swift.min(y0, y1),
                          width: abs(x1 - x0), height: abs(y1 - y0))
        }()
        let shaded: Set<Int> = keyClasses.count < 12
            ? Set(0..<12).subtracting(keyClasses) : [1, 3, 6, 8, 10]
        Canvas { context, size in
            // Rows: the notes OUTSIDE the key darker, so a pitch reads without a keyboard and a
            // new note lands in the key by eye (in C major these are the black keys).
            for pitch in range {
                let y = CGFloat(high - pitch) * rowH
                if shaded.contains(((pitch % 12) + 12) % 12) {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: rowH)),
                                 with: .color(EchoelTheme.fill))
                }
            }
            // Columns: bars strong, beats light, sixteenths faint.
            for step in 0...steps {
                let x = CGFloat(step) * stepW
                let color = step % 16 == 0 ? EchoelTheme.borderStrong.opacity(0.5)
                    : step % 4 == 0 ? EchoelTheme.border : EchoelTheme.border.opacity(0.4)
                context.fill(Path(CGRect(x: x, y: 0, width: step % 16 == 0 ? 1 : 0.5,
                                         height: size.height)), with: .color(color))
            }
            // Octave names on the C rows.
            for pitch in range where pitch % 12 == 0 {
                let y = CGFloat(high - pitch) * rowH + rowH / 2
                context.draw(Text("C\(pitch / 12 - 1)").font(EchoelTheme.font(9))
                                .foregroundStyle(EchoelTheme.dim),
                             at: CGPoint(x: 3, y: y), anchor: .leading)
            }
            // Notes, in draw order: later on top — the order `RollHitTest` reads.
            for note in shown where range.contains(note.pitch) {
                let rect = CGRect(x: CGFloat(note.startStep) * stepW + 1,
                                  y: CGFloat(high - note.pitch) * rowH + 1,
                                  width: Swift.max(2, CGFloat(note.lengthSteps) * stepW - 2),
                                  height: rowH - 2)
                let shape = Path(roundedRect: rect, cornerRadius: 2)
                context.fill(shape, with: .color(lit.contains(note.id) ? EchoelTheme.text
                                                                         : EchoelTheme.accent))
            }
            // The selection box, outline only.
            if let box {
                context.stroke(Path(box), with: .color(EchoelTheme.text.opacity(0.7)), lineWidth: 1)
            }
        }
        .frame(width: CGFloat(steps) * stepW, height: CGFloat(range.count) * rowH)
        .background(EchoelTheme.surface)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in onTap(location) }
        .gesture(edit)
    }

    /// Hold first, then slide — so a swipe that starts on the grid still scrolls it.
    private var edit: some Gesture {
        // Values, captured once per body — the gesture closures read no view state.
        let visible = self.visible
        let picked = self.picked
        let grid = self.grid
        let editable = self.editable
        return LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($live) { value, state, _ in
                guard case .second(true, let drag?) = value else { return }
                state = Self.resolve(drag, visible: visible, picked: picked, grid: grid,
                                     editable: editable)
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let gesture = Self.resolve(drag, visible: visible, picked: picked,
                                                 grid: grid, editable: editable) else { return }
                onRelease(gesture)
            }
    }

    /// The gesture a slide means; a part that is shown, not edited, can still be box-selected.
    private nonisolated static func resolve(_ drag: DragGesture.Value, visible: [Note],
                                            picked: Set<UUID>, grid: NoteGridGesture.Grid,
                                            editable: Bool) -> NoteGridGesture? {
        let gesture = NoteGridGesture.resolve(
            startX: Double(drag.startLocation.x), startY: Double(drag.startLocation.y),
            dx: Double(drag.translation.width), dy: Double(drag.translation.height),
            visible: visible, picked: picked, grid: grid)
        return editable || !gesture.edits ? gesture : nil
    }
}

private extension RollSelection {
    /// The selected note ids, whatever the case.
    var ids: Set<UUID> {
        switch self {
        case .none: return []
        case .single(let id): return [id]
        case .group(let ids): return ids
        }
    }
}

/// The velocity of the notes an M3 operation targets. ⭐ ITS OWN LEAF, FOR THE PERFORMANCE LAW:
/// an `EchoelValueField` drag moves the value at finger rate, so the drag edits `draft` — only
/// this row redraws — and the notes are written ONCE, when the edit ends. One drag, one commit,
/// one Undo. A mixed selection shows its mean; the commit sets every target to one value.
@MainActor
private struct NoteVelocityRow: View {

    let shown: Float
    /// The targets do not share one velocity: the row shows their MEAN, and a commit sets
    /// every one of them to the new value — said on the label, not only to VoiceOver.
    let mixed: Bool
    let targets: Set<UUID>
    let what: String
    let commit: (Float) -> Void

    @State private var draft: Double?

    var body: some View {
        EchoelValueField(label: mixed ? "Velocity (avg)" : "Velocity",
                         value: Binding(get: { draft ?? Double(shown) },
                                        set: { draft = $0 }),
                         range: 0...1, decimals: 2,
                         hint: "Sets \(what) to one velocity",
                         onCommit: {
                             if let draft { commit(Float(draft)) }
                             draft = nil
                         })
            // A draft that no commit cleared (a drag the scroll view took, a drag back to its
            // start) must not outlive the value it was drafted from: an Undo changes `shown`
            // without changing `targets` (M3 review).
            .onChange(of: targets) { _, _ in draft = nil }
            .onChange(of: shown) { _, _ in draft = nil }
    }
}

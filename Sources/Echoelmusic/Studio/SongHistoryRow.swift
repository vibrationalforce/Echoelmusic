//
//  SongHistoryRow.swift
//  Echoelmusic — Studio (WA4 critical path 7: Undo / Redo where the song is edited)
//
//  WHY THIS EXISTS. Until now Undo/Redo sat inside `TrackPartsView`, under the inspector of
//  whichever track was open. Since the Arrange canvas and its part bar edit the song from
//  above the track list, that was the wrong place twice over: Undo was hidden unless a track
//  was open, and REMOVING the selected part hid the part bar — so the action you most want to
//  take back had no visible Undo at all. This is the ONE history control for the whole song.
//  It MOVED (never copied) twice: WA4 path 7 out of the inspector to under the canvas, and head
//  leaf 3 of the interface audit (2026-09-30) into `ProjectHeader`, the head above BOTH stages —
//  under the canvas it existed on the Piece stage only, while the Instrument stage writes the
//  composer's part into this same history and had no Undo in reach. (⛔ M6 once moved it above
//  the canvas and was reverted by its own review as "farther from the edit"; proximity lost to
//  presence when the alternative was a whole stage without a way back.)
//
//  ⚠️ WHAT IT COVERS, stated rather than implied (the store's contract): the history holds the
//  song's PARTS — moves, copies, splits, removals, imports and the composer's part — and, since
//  Phase 3 / M1, the NOTES of a MIDI part edited in `PartNoteEditor`, and since Automation A1
//  the song's AUTOMATION drawn in `SongAutomationEditor`, and since Media B2b a RELINK of a
//  missing file in the Media Library (one audio clip's file binding), and since B3b ONE gesture on
//  a track's level, pan, Mute or Solo (`.laneMix`, only the fields it moved) — since B3c from every
//  surface a hand reaches: Mix, the inspector, the track header, the Perform grid — and since
//  Workstation redesign B2b ONE pick in a rack track's Sound row (`.lanePatch`, both sounds kept
//  as values) — each as its own step kind. Never a rename or a track. Three writers stay OUT, and
//  the hint names the two a person can see: the Studio instrument's Start healing its own track
//  (its own intent, not an edit), the Studio instrument's own sound (shaped in its Sound panel,
//  outside this history), and the agent's level writes (it keeps its own way back; no door
//  today). A part whose
//  track was removed after the step does
//  not come back (`TimelineStore.restoreRegions` drops it rather than resurrect an invisible
//  orphan).
//
//  Cold reads only: `canUndo`/`canRedo` flip on an edit.
//

import SwiftUI

/// Undo / Redo for the piece's parts, notes, automation, relinks, mixer gestures and picked track sounds — one control, in the head.
@MainActor
struct SongHistoryRow: View {

    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        let canUndo = timeline.canUndo
        let canRedo = timeline.canRedo
        HStack(spacing: 6) {
            button(String(localized: "Undo"), "arrow.uturn.backward", enabled: canUndo,
                   label: String(localized: "Undo the last change to the piece's parts, notes, automation, mix or a relinked file")) {
                timeline.undo()
            }
            button(String(localized: "Redo"), "arrow.uturn.forward", enabled: canRedo,
                   label: String(localized: "Redo the last undone change to the piece's parts, notes, automation, mix or a relinked file")) {
                timeline.redo()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Covers moves, copies, splits, removals, imports, note edits, automation points, relinked files, the composer's part and a track's level, pan, mute, solo or picked sound — not the Studio instrument's own sound or what its Start changes")
    }

    private func button(_ title: String, _ systemImage: String, enabled: Bool, label: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(EchoelTheme.font(11, .semibold))
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

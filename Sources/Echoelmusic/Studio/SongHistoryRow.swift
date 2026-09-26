//
//  SongHistoryRow.swift
//  Echoelmusic — Studio (WA4 critical path 7: Undo / Redo where the song is edited)
//
//  WHY THIS EXISTS. Until now Undo/Redo sat inside `TrackPartsView`, under the inspector of
//  whichever track was open. Since the Arrange canvas and its part bar edit the song from
//  above the track list, that was the wrong place twice over: Undo was hidden unless a track
//  was open, and REMOVING the selected part hid the part bar — so the action you most want to
//  take back had no visible Undo at all. This is the ONE history control, mounted once under
//  the canvas for the whole song. It MOVED here; it was not copied (one history, one control).
//
//  ⚠️ WHAT IT COVERS, stated rather than implied (the store's contract): the history holds the
//  song's PARTS — moves, copies, splits, removals, imports and the composer's part — and, since
//  Phase 3 / M1, the NOTES of a MIDI part edited in `PartNoteEditor`, and since Automation A1
//  the song's AUTOMATION drawn in `SongAutomationEditor` — each as its own step kind.
//  Never a mixer change, a rename or a track. A part whose track was removed after the step does
//  not come back (`TimelineStore.restoreRegions` drops it rather than resurrect an invisible
//  orphan).
//
//  Cold reads only: `canUndo`/`canRedo` flip on an edit.
//

import SwiftUI

/// Undo / Redo for the song's parts and notes — one control for the whole Workstation.
@MainActor
struct SongHistoryRow: View {

    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        let canUndo = timeline.canUndo
        let canRedo = timeline.canRedo
        HStack(spacing: 6) {
            button("Undo", "arrow.uturn.backward", enabled: canUndo,
                   label: "Undo the last change to the song's parts, notes or automation") {
                timeline.undo()
            }
            button("Redo", "arrow.uturn.forward", enabled: canRedo,
                   label: "Redo the last undone change to the song's parts, notes or automation") {
                timeline.redo()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Covers moves, copies, splits, removals, imports, note edits, automation points and the composer's part — never mixer changes")
    }

    private func button(_ title: String, _ systemImage: String, enabled: Bool, label: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
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

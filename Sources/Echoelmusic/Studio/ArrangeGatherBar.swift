//
//  ArrangeGatherBar.swift
//  Echoelmusic — Studio (A9: select several parts, copy, paste, delete)
//
//  WHY THIS EXISTS. Live and Logic select several clips and copy, paste or delete them together
//  (founder 2026-10-16, "Arrangement auf Ableton-Level", gap list item 3). A phone has no Shift
//  key, so the canvas has a Select mode: "Select" turns it on, and while it is on a tap on a part
//  GATHERS it (or lets it go) instead of selecting it. The gathered parts wear the selection ring.
//  · Copy keeps the gathered parts in memory (`WorkstationSelection.clipboard`) — never the system
//    pasteboard, never persisted.
//  · Paste places them at the bar Play starts from (the ruler's line): the earliest lands there,
//    the others keep their spacing and their tracks (`RegionClipboard`). One Undo step.
//  · Delete removes the gathered parts — `TimelineStore.removeRegions`, one Undo step.
//  · Done leaves the mode and lets every part go.
//  Paste stays offered outside the mode once something is copied, so a copy can land anywhere.
//
//  ⚠️ NOT A MODAL: a row of buttons above the canvas; nothing is presented.
//  ⚠️ COLD: it reads the selection, the piece and the cue, each changed by a tap — never
//  `currentTick`.
//
//  NEEDS-FOUNDER-VERIFY (A9): tap Select, tap two parts on different tracks → both ringed, "2
//  parts"; Copy; tap the ruler on a later bar; Paste → both stand again from that bar, on their own
//  tracks, the same distance apart. Undo → gone in one step. Delete → the gathered parts go, Undo
//  brings them back.
//

import SwiftUI

/// The pure half: what the bar says.
enum GatherChoice {

    /// The count line while Select mode is on — the number, then a catalogued noun (E4-24: never a
    /// format key). Pure.
    nonisolated static func countLine(_ count: Int) -> String {
        "\(count) " + (count == 1 ? String(localized: "part") : String(localized: "parts"))
    }
}

/// The row above the canvas that selects several parts and copies, pastes or deletes them.
struct ArrangeGatherBar: View {
    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// Only `cueTick` — cold (a tap on the ruler).
    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        let document = timeline.document
        let gathered = WorkstationSelection.resolvedGathered(selection.gathered, in: document)
        let canPaste = !selection.clipboard.isEmpty
        HStack(spacing: 8) {
            if selection.gathering {
                Text(GatherChoice.countLine(gathered.count))
                    .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                action(String(localized: "Copy"), enabled: !gathered.isEmpty) {
                    selection.copyGathered(from: document)
                }
                action(String(localized: "Paste"), enabled: canPaste) { paste(in: document) }
                action(String(localized: "Delete"), enabled: !gathered.isEmpty) {
                    timeline.removeRegions(ids: gathered)
                }
                action(String(localized: "Done"), enabled: true) { selection.setGathering(false) }
            } else {
                action(String(localized: "Select"), enabled: true) { selection.setGathering(true) }
                    .accessibilityHint(String(localized: "Tap parts to gather them, then copy, paste or delete them together."))
                if canPaste {
                    action(String(localized: "Paste"), enabled: true) { paste(in: document) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Paste at the bar Play starts from — the ruler's line, the Marker button's bar.
    private func paste(in document: TimelineDocument) {
        let start = TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)
        timeline.pasteRegions(selection.clipboard, atTick: start)
    }

    private func action(_ title: String, enabled: Bool, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(EchoelTheme.font(13, .medium))
                .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

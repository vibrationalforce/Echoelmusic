// PerformSessionView.swift
// Echoel — DMMW Phase 3 · slice 1 (founder 2026-09-29): "Compose und Perform als zwei Sichten
// derselben Session — gleiche IDs, keine Kopien. Perform kann starten, stoppen, muten und
// Clips/Parts wechseln."
//
// ⭐ THE SAME SESSION, A SECOND VIEW. This leaf mounts the EXISTING Session projection
// (`SessionLaunchView`) on the Perform plate. It builds nothing of its own: the scenes and cells
// are the document's regions (`timeline.document`), the launch state is the one player's, and a
// scene that starts a stopped song goes through the Workstation's ONE start
// (`WorkstationView.startSong`) — so the ids a player launches here are the ids Compose edits,
// and the Stop that ends it is the header's ONE Stop. No copy, no second clock, no store.
//
// ⚠️ A LEAF, AND THAT IS THE FREEZE LAW, NOT STYLE. The Sound panel is built inside
// `EchoelStudioView`'s `dropdownContent`, which the ROOT body evaluates. Every read below —
// the document, the clip grid, `songCanStart`'s cold inputs, and `SessionLaunchView`'s
// `launchGeneration` (a tap or a fired bar, never a step) — happens in THIS body, so a change
// rebuilds this leaf only. `beatPlayer.pattern` (it leads to the gliding tempo) and `pianoRoll`
// are read only inside the start closure, at tap time.
//
// Slice 2: Mute and Solo per heard track, through the same `TrackMix` doors Compose's track
// header uses — one lane flag, two views of it. (Not undoable in either view: the store's
// toggles never were; that is the same truth in both places, not a Perform gap.)
//
// ⚠️ NO MODAL, NO NEW PRESENTATION SLOT: one more child of an existing panel builder (the
// black-screen law counts the root chain; this is not on it).

import SwiftUI

@MainActor
struct PerformSessionView: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore
    /// ⚠️ READ ONLY INSIDE THE START CLOSURE — `pattern` leads to the gliding tempo.
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll

    var body: some View {
        // The Workstation's own start guard (the one `canPlay` question, #416): while the song
        // has nothing that would play, the projection shows no scene — say so, and where parts
        // come from, instead of an empty space on the Perform plate.
        let startable = WorkstationView.songCanStart(player: player, timeline: timeline,
                                                     clipStore: clipStore)
        VStack(alignment: .leading, spacing: 6) {
            if !startable && !player.isPlaying {
                Text(Self.emptyNote)
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SessionLaunchView(playFrom: { tick, parts in
                WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,
                                          pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                                          fromTick: tick, launching: parts)
            })
            // Slice 2 — Mute and Solo while performing, on the SAME lane flags Compose's track
            // header flips (`TrackMix.flipMute`/`flipSolo` → `TimelineStore`). Both views read
            // the document, so a switch flipped here is lit there. Only tracks that are HEARD
            // get a row (the inspector's rule, `TrackMix.controls(…).muteSolo`).
            let rows = Self.mixRows(in: timeline.document, voiceCapacity: player.laneVoiceCapacity)
            if !rows.isEmpty {
                Text("Tracks")
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                    .padding(.top, 4)
                ForEach(rows) { row in
                    mixRow(row)
                }
            }
        }
    }

    /// One heard track's Mute/Solo state, read from the document — the ONE truth both views show.
    struct MixRow: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let role: TrackMix.Role
        let isMuted: Bool
        let isSoloed: Bool
    }

    /// The tracks a Mute or Solo is heard on, in document order: `TrackMix.controls` decides,
    /// the same question the Workstation's track header asks. `voiceCapacity` is
    /// `TimelineRegionPlayer.laneVoiceCapacity`, never defaulted (#431).
    nonisolated static func mixRows(in document: TimelineDocument, voiceCapacity: Int) -> [MixRow] {
        document.lanes.compactMap { lane in
            guard let controls = TrackMix.controls(of: lane.id, in: document, voiceCapacity: voiceCapacity),
                  controls.muteSolo else { return nil }
            return MixRow(id: lane.id, name: lane.name, role: controls.role,
                          isMuted: lane.isMuted, isSoloed: lane.isSoloed)
        }
    }

    private func mixRow(_ row: MixRow) -> some View {
        HStack(spacing: 8) {
            Text(row.name)
                .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            mixSwitch("Mute", track: row.name, on: row.isMuted, hint: TrackMix.muteHint(row.role)) {
                TrackMix.flipMute(laneID: row.id, timeline: timeline)
            }
            mixSwitch("Solo", track: row.name, on: row.isSoloed, hint: TrackMix.soloHint(row.role)) {
                TrackMix.flipSolo(laneID: row.id, timeline: timeline)
            }
        }
    }

    /// A word, not a letter: the Perform plate is read at a glance mid-performance. Monochrome
    /// fill when on, never a coloured area behind a label (EchoelTheme); 44 pt target.
    private func mixSwitch(_ name: String, track: String, on: Bool, hint: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(on ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) \(track)")
        .accessibilityInputLabels(["\(name) \(track)", name])
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityHint(hint)
    }

    /// What the Perform plate says while the song has nothing to launch. It names the area that
    /// makes parts (Compose) rather than a control on another plate, so it cannot go stale when
    /// that plate's rows move.
    static let emptyNote = "Session: nothing to launch yet. Parts you write in Compose appear here as scenes to launch on the bar."
}

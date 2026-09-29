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
        }
    }

    /// What the Perform plate says while the song has nothing to launch. It names the area that
    /// makes parts (Compose) rather than a control on another plate, so it cannot go stale when
    /// that plate's rows move.
    static let emptyNote = "Session: nothing to launch yet. Parts you write in Compose appear here as scenes to launch on the bar."
}

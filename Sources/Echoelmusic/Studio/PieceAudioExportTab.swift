// PieceAudioExportTab.swift
// Echoel — the piece's "WAV" tab: the whole song bounced to an audio file and handed to the share
// sheet (UX audit 2026-10-02, slice 10b — "Wo bleiben die ganzen Features?": a piece that can be
// built but only leave the app as MIDI is a sketchpad, not a workstation).
//
// WHAT IT DOES. A tap plays the piece ONCE from bar 1 and records the master while it plays —
// `LoopExporter.exportPiece`, realtime, through the capture the loop export already uses. When the
// piece has reached its end the tile turns into "Share WAV", a `ShareLink` to the finished file.
// While it records, the same tile is "Stop": the take is discarded, nothing half is shared. A Stop
// from anywhere else (the project head) discards it the same way — the exporter only writes a
// piece the player says reached its end.
//
// WHY A SHARELINK AND NO MODAL: the share sheet belongs to `ShareLink`, so this door adds no
// presentation modifier to any chain (black-screen law) — the shape `SongExportTab` set.
//
// WHY ITS OWN LEAF: it reads the exporter's status, the song and the player's run state. None of
// them is hot — each changes a few times per export or per edit, never per transport step — and
// reading them here keeps the piece's tab row (an ancestor of the plate's pickers) from
// subscribing to any of them. The engine is only handed over inside the tap, never read in `body`
// (its meters write at 60 Hz).
//
// ONE START, ONE EXPORTER: the song starts through `WorkstationView.startSong` (the one
// `player.play(` site), and the capture belongs to the app's one `LoopExporter`, so this door and
// the Instrument's loop export can never record at the same time — while one runs, this tile is
// dim, and the Instrument's Record tile offers only its Stop. The bounce state (in flight, the
// finished file, the last failure) lives on the exporter too, so it survives a stage switch.

import SwiftUI

struct PieceAudioExportTab: View {
    @Environment(LoopExporter.self) private var exporter
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ProjectStore.self) private var projects
    @AppStorage(StudioDefaultKeys.loudnessTarget.key) private var loudnessTargetRaw = StudioDefaultKeys.loudnessTarget.value

    /// Bounce state lives on the exporter, not here (review of slice 10): the Piece stage is
    /// unmounted on a switch to the Instrument, and `@State` here came back unable to stop its
    /// own take and dropped the finished file.
    private var bouncing: Bool { exporter.pieceTakeInFlight }
    private var failure: String? { exporter.lastPieceFailure }

    var body: some View {
        Group {
            if let bounced = exporter.lastPieceFile {
                ShareLink(item: bounced) {
                    EchoelIconTile(systemImage: "square.and.arrow.up", title: "Share WAV", expands: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share WAV")
                .accessibilityHint(String(localized: "Shares the piece as a WAV file. Change the piece, and this becomes WAV again"))
            } else {
                let enabled = canTap
                Button(action: tap) {
                    EchoelIconTile(systemImage: symbol, title: title, expands: true, enabled: enabled)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityLabel(title)
                .accessibilityHint(hint(enabled: enabled))
            }
        }
        // A finished file never outlives what it was made from: an edit to the song, or a new
        // loudness target, and the tile reads WAV again. (Tempo and the master chain are not
        // watched here — reading them in this leaf would be a hot read; the tile says "Share
        // WAV" for the take it made, and a new tap after such a change makes a new one.)
        .onChange(of: timeline.document) { _, _ in exporter.lastPieceFile = nil }
        .onChange(of: loudnessTargetRaw) { _, _ in exporter.lastPieceFile = nil }
    }

    // MARK: - State in words

    /// The exporter is busy with a take this tile did not start (the Instrument's loop export).
    private var busyElsewhere: Bool {
        !bouncing && (exporter.status == .capturing || exporter.status == .rendering)
    }

    private var canTap: Bool {
        if bouncing { return exporter.isCancellable }
        if busyElsewhere { return false }
        return WorkstationView.songCanStart(player: player, timeline: timeline, clipStore: clipStore)
    }

    private var title: String {
        guard bouncing else { return failure == nil ? String(localized: "WAV") : String(localized: "Retry WAV") }
        return exporter.isCancellable ? String(localized: "Stop") : String(localized: "Writing")
    }

    private var symbol: String {
        guard bouncing else { return "waveform" }
        return exporter.isCancellable ? "stop.circle" : "hourglass"
    }

    private func hint(enabled: Bool) -> String {
        if bouncing {
            return exporter.isCancellable
                ? String(localized: "Recording the piece. Stops and discards the recording")
                : String(localized: "Writing the WAV file")
        }
        if busyElsewhere { return String(localized: "Another recording is running. Wait for it to finish") }
        if !enabled { return String(localized: "Nothing to record yet. Add a part the piece can play") }
        let action = String(localized: "Plays the piece once from bar 1 and records everything you hear as a WAV file. It takes as long as the piece")
        guard let failure else { return action }
        return String(localized: "The last try failed: ") + failure + ". " + action
    }

    // MARK: - The one action

    private func tap() {
        if bouncing {
            exporter.cancel()
            return
        }
        let name = SongExportTab.fileName(projects.currentProjectName)
        Task { @MainActor in
            // The exporter owns the outcome: the named file in `lastPieceFile`, a failure in
            // `lastPieceFailure`, and `status` back at `.idle` either way.
            await exporter.exportPiece(
                engine: audioEngine, beatPlayer: beatPlayer, player: player,
                start: {
                    WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,
                                              pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                                              fromTick: 0, launching: [])
                },
                fileName: name,
                targetLUFS: LoudnessTarget.resolvedLUFS(rawValue: loudnessTargetRaw))
        }
    }
}

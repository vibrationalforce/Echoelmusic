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
// the Instrument's loop export can never record at the same time — while one runs, the other is dim.

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

    /// The last finished bounce. Dropped the moment the song changes — a file of the old piece
    /// offered as "Share WAV" after an edit would be a stale export with a current-looking door.
    @State private var bounced: URL?
    /// Whether THIS tile started the export in flight. The exporter is shared with the
    /// Instrument's loop export; only our own take may be stopped from here.
    @State private var bouncing = false
    /// The reason the last bounce from this tile failed, spoken by the tile until the next try.
    @State private var failure: String?

    var body: some View {
        Group {
            if let bounced {
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
        .onChange(of: timeline.document) { _, _ in bounced = nil }
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
        bounced = nil
        failure = nil
        bouncing = true
        let name = SongExportTab.fileName(projects.currentProjectName)
        Task { @MainActor in
            let url = await exporter.exportPiece(
                engine: audioEngine, beatPlayer: beatPlayer, player: player,
                start: {
                    WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,
                                              pattern: beatPlayer.pattern, pianoRoll: pianoRoll,
                                              fromTick: 0, launching: [])
                },
                targetLUFS: LoudnessTarget.resolvedLUFS(rawValue: loudnessTargetRaw))
            if let url {
                bounced = Self.renamed(url, to: name)
            } else if case .failed(let reason) = exporter.status {
                failure = reason
            }
            exporter.finishAttempt()   // keeps `.failed` readable (#216)
            bouncing = false
        }
    }

    /// A copy named after the piece, so the share sheet offers "<piece>.wav" rather than the
    /// exporter's working name. Falls back to the original file if the copy fails.
    static func renamed(_ url: URL, to name: String) -> URL {
        let stem = name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .filter { !$0.isEmpty }.joined(separator: "-")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(stem + ".wav")
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return url
        }
    }
}

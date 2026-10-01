// SongExportTab.swift
// Echoel — the piece's "Export" tab: the whole song as a MIDI file, handed to the share sheet
// (Workstation redesign B4, founder 2026-10-01).
//
// WHY A SHARELINK AND NOT A BUTTON: the share sheet belongs to `ShareLink` itself, so the piece
// gains a door without a presentation modifier on its own chain (the black-screen law) — the
// pattern the instrument's project list already uses (`SharedEchoelProject`).
//
// WHY ITS OWN LEAF: the tile reads the song, the clip grid and the open project's name. None of
// them is hot (they change on an edit, never per transport step), and keeping the reads here
// means the piece's tab row does not subscribe to the clip grid on this tab's behalf. The TEMPO
// is the one hot value (`PatternEngine.tempo` glides at ~20 Hz) and nothing here subscribes to
// it: the tile and the file read `TimelineRegionPlayer.preflightTempo`, the player's own
// `@ObservationIgnored` mirror of the live tempo — the file at the moment the share sheet asks
// for the bytes, so it carries the tempo the song plays at THEN, not the one at the last redraw.
//
// What the file is decided in `SongMIDIExport` (which notes) and `MIDIFileExporter.exportSong`
// (which bytes); this view only asks.

import SwiftUI
import UniformTypeIdentifiers

/// The song as a `.mid`, built when the share sheet asks for it — not on every redraw.
struct SongMIDIFile: Transferable {
    let document: TimelineDocument
    let clips: [Clip]
    let keyRootPitchClass: Int
    let keyIsMinor: Bool
    let name: String
    /// Asked for the live tempo when the bytes are built (see the file header).
    let player: TimelineRegionPlayer

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .midi) { file in
            await file.makeData()
        }
        .suggestedFileName { file in file.name + ".mid" }
    }

    /// On the main actor because the tempo lives there; the file itself is pure arithmetic.
    @MainActor func makeData() -> Data {
        data(bpm: player.preflightTempo)
    }

    func data(bpm: Double) -> Data {
        var byID: [UUID: Clip] = [:]
        for clip in clips where byID[clip.id] == nil { byID[clip.id] = clip }
        return SongMIDIExport.file(of: document, clip: { byID[$0] }, bpm: bpm,
                                   keyRootPitchClass: keyRootPitchClass, keyIsMinor: keyIsMinor)
    }
}

/// The "Export" tile of the piece's tab row. Dimmed and inert while the song holds no note to
/// write — a share sheet over an empty file would be a button that does nothing (#164/#227).
struct SongExportTab: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ProjectStore.self) private var projects
    @AppStorage(StudioDefaultKeys.rootIndex.key) private var rootIndex = StudioDefaultKeys.rootIndex.value
    @AppStorage(StudioDefaultKeys.scale.key) private var scale: Scale = StudioDefaultKeys.scale.value

    var body: some View {
        let document = timeline.document
        let clips = clipStore.filledClips
        // `preflightTempo` is `@ObservationIgnored`: reading it here subscribes to nothing. It
        // only decides the enabled state (a legacy part's trim window needs a tempo); the file
        // itself reads the tempo again when it is built.
        let enabled = SongMIDIExport.hasNotes(document, clip: { id in clips.first { $0.id == id } },
                                              bpm: player.preflightTempo)
        let file = SongMIDIFile(
            document: document, clips: clips,
            keyRootPitchClass: rootIndex, keyIsMinor: scale.isMinorTonality,
            name: Self.fileName(projects.currentProjectName),
            player: player)
        ShareLink(item: file, preview: SharePreview(file.name)) {
            EchoelIconTile(systemImage: "square.and.arrow.up", title: "Export",
                           expands: true, enabled: enabled)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Export")
        .accessibilityHint(enabled
            ? String(localized: "Shares the piece as a MIDI file: every MIDI track with its notes, muted ones included. Level, pan and sound stay here")
            : String(localized: "Nothing to export yet. Write a part on a MIDI track, and the piece can be shared as a MIDI file"))
    }

    /// The open project's name, or a plain default; a slash would read as a folder.
    static func fileName(_ projectName: String?) -> String {
        let trimmed = (projectName ?? "").replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Echoelmusic Piece") : trimmed
    }
}

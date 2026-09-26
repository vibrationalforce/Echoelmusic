// MediaBrowserView.swift
// Echoel — the media library on the Workstation plate (Phase 3 / MA1, founder order 2026-09-25:
// "MediaAsset + lazy Browser"; plan `scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`).
//
// "Media Library" opens a list of the audio files already imported into the app, each with where
// it is used and a "Place" that puts it on the song as a part — reusing the clip that already
// plays it, so a second part of the same file spends no clip slot and makes no second copy.
//
// ⭐ A LEAF, AND THE LISTING IS NEVER IN `body`. Listing the directory is disk I/O, so it runs
// DETACHED in `.task(id:)`, once when the list opens and again when the set of imported files the
// clip grid knows about changes (an import landed). The rows are in a `LazyVStack`, so a long
// library builds only the rows on screen. Nothing here decodes audio: sizes come from the one
// directory call, lengths from the clips that already measured them.
//
// ⭐ B1 — A NAME FILTER over the listing already in memory (`MediaAsset.matching`): typing narrows
// the rows, with no disk and no re-listing; the field is empty again when the list closes.
//
// ⭐ B2 — A FILE THIS DEVICE CANNOT FIND IS NAMED, NOT SILENT. Before, a clip whose file was gone
// just made Play grey out. The open list now says which clip expects which file and how many
// parts wait for it. The question goes to the PLAYING path's own resolver
// (`AudioLanePlayer.resolvedURL`, #1439), asked in `.task` while the list is open — never in
// `body`, never while closed. The clip and its parts are left exactly as they are.
// ⭐ B2b — RELINK points a missing clip at a library file (`MediaRelink`, same length only, never
// while the song plays); its id, name, tempo and every part stay, so the silent parts sound again.
// ⚠️ It is not undoable and cannot tell two equal-length recordings apart (`MediaRelink` header).
//
// ⭐ B3 — PREVIEW plays a file's first `previewSeconds` on the audition path `BeatPlayer` already
// attaches at launch (`audition(url:fromSeconds:lengthSeconds:)`, until now without a caller).
// It is refused while the song or the instrument's loop plays (`previewRefusal`): the sink's
// first use of a file format attaches a node, which pauses the engine. It ends itself, with the
// list closing, with the Workstation leaving, and when the song or the loop starts.
// ⚠️ Not refused: an armed body voice sounding with nothing playing — the first preview of a new
// file format may cut it for the attach. Device-unconfirmed, like every sound here.
//
// ⭐ IT READS ONLY COLD STATE: the clip grid and the song document change on an edit, never on a
// clock; the two play flags change on a start or a stop. The tempo a placement spans bars at is `preflightTempo`, `@ObservationIgnored`, read in
// the tap. The root (`WorkstationView`) mounts this leaf and reads none of its state.
//
// ⚠️ NO MODAL. It is an inline section of the plate, like `PartNoteEditor`, so the black-screen
// budget on the Studio's modifier chain is untouched.
//
// ⛔ IT WRITES NOTHING ITSELF. Two writers are reachable from here — `MediaPlacement.perform`
// (Place) and `MediaRelink.perform` (Relink) — and neither deletes, copies or moves a file (see
// their headers). This view names no `FileManager`, no `Clip(` and no
// `TimelineRegion(`.

import SwiftUI

struct MediaBrowserView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(MediaAssetStore.self) private var mediaAssets
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(WorkstationSelection.self) private var selection
    /// B3: the preview reuses the audition path that `BeatPlayer` already attaches at launch.
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(AudioEngine.self) private var audioEngine

    @State private var isOpen = false
    /// nil = not read yet; `.unreadable` = the home could not be read (different from empty).
    @State private var listing: Listing?
    @State private var note: String?
    /// The name filter (B1). Local to this leaf: typing rebuilds the list, never the Workstation.
    @State private var query = ""
    /// Clips whose file the player's resolver could not find at the last listing (B2).
    @State private var missingIDs: Set<UUID> = []
    /// The file a preview is playing (B3). nil = nothing previews.
    @State private var previewing: MediaAsset.Key?

    private enum Listing: Equatable {
        case assets([MediaAsset])
        case unreadable
    }

    /// Re-list when the list opens, and when the clip grid starts or stops knowing a file.
    private struct ListingKey: Equatable {
        var open: Bool
        var refs: [String]
    }

    var body: some View {
        let clips = clipStore.slots.compactMap { $0 }
        VStack(alignment: .leading, spacing: 8) {
            toggleRow
            if isOpen {
                let missing = MediaAsset.missing(clips: clips, document: timeline.document,
                                                 resolves: { !missingIDs.contains($0) })
                if !missing.isEmpty {
                    missingSection(missing)
                }
                content(usage: MediaAsset.usage(clips: clips, document: timeline.document))
                    // B3: the song or the instrument's loop starting ends a preview — never two
                    // sources over each other. Observed only while the list is open.
                    .onChange(of: player.isPlaying || beatPlayer.pattern.isPlaying) { _, playing in
                        if playing { stopPreview() }
                    }
                if let note {
                    Text(note)
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // B3: a preview ends itself after `previewSeconds`, and with the Workstation.
        .task(id: previewing) {
            guard previewing != nil else { return }
            try? await Task.sleep(for: .seconds(Self.previewSeconds))
            guard !Task.isCancelled else { return }
            previewing = nil
        }
        .onDisappear { stopPreview() }
        .task(id: ListingKey(open: isOpen,
                             refs: clips.filter { $0.kind == .audio }.compactMap(\.mediaRef).sorted())) {
            guard isOpen else { return }
            let result = await Task.detached(priority: .utility) { MediaLibrary.listAudio() }.value
            // A detached hop does not inherit cancellation: a listing started before an import
            // landed can finish AFTER the newer one and overwrite it with the older set.
            guard !Task.isCancelled else { return }
            if let assets = result { listing = .assets(assets) } else { listing = .unreadable }
            // B2: the player's own resolver, a handful of existence checks (eight slots at most).
            // No player wired means no answer — nothing is called missing on a guess.
            if let lanes = player.audioLanes {
                missingIDs = Set(MediaAsset.missing(clips: clipStore.filledClips, document: timeline.document,
                                                    resolves: { lanes.resolvedURL(forClipID: $0) != nil })
                    .map(\.clipID))
            } else {
                missingIDs = []
            }
        }
    }

    private var toggleRow: some View {
        Button {
            isOpen.toggle()
            if !isOpen {
                stopPreview()
                note = nil
                query = ""
                missingIDs = []
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("Media Library").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The label is the visible words (Voice Control's label-in-name); the state is a value.
        .accessibilityLabel("Media Library")
        .accessibilityValue(isOpen ? "Shown" : "Hidden")
        .accessibilityHint("Lists the audio files already imported into the app")
    }

    @ViewBuilder
    private func content(usage: [MediaAsset.Key: MediaAsset.Usage]) -> some View {
        switch listing {
        case nil:
            line("Reading the library…")
        case .unreadable:
            line("Couldn't read the media library.")
        case .assets(let assets) where assets.isEmpty:
            line("No imported audio yet — Import Audio copies a file here.")
        case .assets(let assets):
            let shown = MediaAsset.matching(assets, query: query)
            VStack(alignment: .leading, spacing: 6) {
                filterField
                if shown.isEmpty {
                    line(Self.noMatchText(query))
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(shown) { asset in
                            row(asset, usage: usage[asset.key] ?? .unused)
                        }
                    }
                }
                // Only beside a non-empty result: under "No file name contains …" a
                // "0 of N files" line says the same thing twice (review of B1).
                if !shown.isEmpty, shown.count != assets.count {
                    line("\(shown.count) of \(assets.count) files")
                }
            }
        }
    }

    /// Label above the input (the form rule), a plain field: a name filter, not a search engine.
    private var filterField: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The field carries the same words as its label; hidden here so VoiceOver says
            // them once (review of B1).
            Text("Filter by name")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .accessibilityHidden(true)
            TextField("Name contains", text: $query)
                .font(EchoelTheme.font(13))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel("Filter by name")
        }
    }

    /// The clips whose file is gone, above the library (B2). Relink (B2b) offers the library
    /// files the name filter shows; without any, the way back is a file of that name in the
    /// library (the resolver finds it by name).
    private func missingSection(_ missing: [MediaAsset.Missing]) -> some View {
        let candidates: [MediaAsset]
        if case .assets(let all) = listing {
            candidates = MediaAsset.matching(all, query: query)
        } else {
            candidates = []
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Missing on this device")
                .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                .accessibilityAddTraits(.isHeader)
            ForEach(missing) { item in
                HStack(spacing: 10) {
                    line(Self.missingText(item))
                    Spacer(minLength: 8)
                    if !candidates.isEmpty {
                        relinkMenu(item, candidates: candidates)
                    }
                }
            }
            line(candidates.isEmpty
                 ? "Their parts stay in the song. Relink offers the library's files once one is there."
                 : "Their parts stay in the song. Relink points a clip at a library file of the same length.")
        }
    }

    /// The library files a missing clip can be pointed at — the rows the filter shows.
    private func relinkMenu(_ item: MediaAsset.Missing, candidates: [MediaAsset]) -> some View {
        Menu {
            ForEach(candidates) { asset in
                Button(asset.displayName) { relink(item, to: asset) }
            }
        } label: {
            Text("Relink").font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .padding(.horizontal, 12)
                .frame(minWidth: 64, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Relink \(item.clipName)")
        .accessibilityHint("Chooses a library file of the same length")
    }

    /// B2b review M3: why a relink may not happen now, or nil. The relinked clip's lane was never
    /// preloaded, so its next onset would attach a node mid-song, and an attach pauses the
    /// engine. A stopped song preloads it on the next Play, where the pause is silent.
    static func relinkRefusal(songPlaying: Bool) -> String? {
        songPlaying ? "Stop the song to relink a file." : nil
    }

    private func relink(_ item: MediaAsset.Missing, to asset: MediaAsset) {
        if let refusal = Self.relinkRefusal(songPlaying: player.isPlaying) {
            note = refusal
            return
        }
        #if canImport(AVFoundation)
        switch MediaRelink.perform(item.clipID, to: asset, clipStore: clipStore, timeline: timeline) {
        case .success:
            missingIDs.remove(item.clipID)
            note = "Relinked \u{201C}\(item.clipName)\u{201D} to \(asset.displayName)."
        case .failure(let refusal):
            note = refusal.userMessage
        }
        #else
        note = MediaRelink.Refusal.unreadable.userMessage
        #endif
    }

    /// One missing clip, in the words its row shows.
    static func missingText(_ item: MediaAsset.Missing) -> String {
        let parts: String
        switch item.partCount {
        case 0:  parts = "no part"
        case 1:  parts = "1 part"
        default: parts = "\(item.partCount) parts"
        }
        return "\(item.clipName) — expects \(item.fileName) · \(parts)"
    }

    /// What the list says when the filter leaves nothing.
    static func noMatchText(_ query: String) -> String {
        "No file name contains \u{201C}\(query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}."
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ asset: MediaAsset, usage: MediaAsset.Usage) -> some View {
        let size = ByteCountFormatter.string(fromByteCount: asset.byteSize, countStyle: .file)
        let use = Self.usageText(usage)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.displayName)
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                    .lineLimit(1)
                Text("\(size) · \(use)")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            }
            // One spoken element for the facts; the button stays its own element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(asset.displayName), \(size), \(use)")
            Spacer(minLength: 8)
            previewButton(asset)
            Button {
                place(asset)
            } label: {
                Text("Place").font(EchoelTheme.font(13, .semibold))
                    .foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 64, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                        .fill(EchoelTheme.fill))
                    .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                        .strokeBorder(EchoelTheme.border, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Place \(asset.displayName)")
            .accessibilityHint("Adds it as a part at the end of the audio track")
        }
    }

    /// B3: Preview plays the file's first seconds; while it plays the same button is Stop.
    private func previewButton(_ asset: MediaAsset) -> some View {
        let playing = previewing == asset.key
        let label: String = playing ? "Stop preview" : "Preview \(asset.displayName)"
        let hint: String = playing ? "" : "Plays its first \(Int(Self.previewSeconds)) seconds"
        return Button {
            if playing { stopPreview() } else { preview(asset) }
        } label: {
            Text(playing ? "Stop" : "Preview").font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .padding(.horizontal, 12)
                .frame(minWidth: 64, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    /// B3: how long a preview plays — enough to recognise a recording; a forgotten preview
    /// ends itself.
    static let previewSeconds: Double = 10

    /// B3: why a preview may not start now, or nil. The audition sink's first use of a file
    /// format ATTACHES a node, and an attach pauses the engine — inaudible only while nothing
    /// plays (the rule `AudioRegionPlayback.auditionWindow` states for the region audition);
    /// over a playing song a second source would also double-sound. A stopped engine would
    /// light the button and play nothing.
    static func previewRefusal(songPlaying: Bool, loopPlaying: Bool,
                               engineRunning: Bool) -> String? {
        if songPlaying { return "Stop the song to preview a file." }
        if loopPlaying { return "Stop the instrument's loop to preview a file." }
        if !engineRunning { return "Sound is off right now, so a preview can't play." }
        return nil
    }

    private func preview(_ asset: MediaAsset) {
        if let refusal = Self.previewRefusal(songPlaying: player.isPlaying,
                                             loopPlaying: beatPlayer.pattern.isPlaying,
                                             engineRunning: audioEngine.isRunning) {
            note = refusal
            return
        }
        beatPlayer.audition(url: asset.url, fromSeconds: 0, lengthSeconds: Self.previewSeconds)
        previewing = asset.key
    }

    private func stopPreview() {
        guard previewing != nil else { return }
        beatPlayer.stopAudition()
        previewing = nil
    }

    /// Where a file is used, in the words the row shows.
    static func usageText(_ usage: MediaAsset.Usage) -> String {
        switch usage.partCount {
        case 0:  return usage.clipIDs.isEmpty ? "not in the song" : "in a clip, no part yet"
        case 1:  return "in 1 part"
        default: return "in \(usage.partCount) parts"
        }
    }

    private func place(_ asset: MediaAsset) {
        #if canImport(AVFoundation)
        switch MediaPlacement.perform(asset, clipStore: clipStore, timeline: timeline,
                                      assets: mediaAssets, bpm: player.preflightTempo) {
        case .success(let placed):
            selection.selectRegion(placed.region.id, in: timeline.document)
            let laneName = timeline.document.lanes
                .first { $0.id == placed.region.laneID }?.name ?? "the audio track"
            note = MediaPlacement.successNote(placed, laneName: laneName)
        case .failure(let failure):
            note = failure.userMessage
        }
        #else
        note = AudioImport.Failure.unreadableAudio.userMessage
        #endif
    }
}

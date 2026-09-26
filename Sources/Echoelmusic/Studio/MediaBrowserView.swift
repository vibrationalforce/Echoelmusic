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
// ⭐ IT READS ONLY COLD STATE: the clip grid and the song document change on an edit, never on a
// clock. The tempo a placement spans bars at is `preflightTempo`, `@ObservationIgnored`, read in
// the tap. The root (`WorkstationView`) mounts this leaf and reads none of its state.
//
// ⚠️ NO MODAL. It is an inline section of the plate, like `PartNoteEditor`, so the black-screen
// budget on the Studio's modifier chain is untouched.
//
// ⛔ IT WRITES NOTHING ITSELF. `MediaPlacement.perform` is the one writer, and it never deletes a
// file (see that file's header). This view names no `FileManager`, no `Clip(` and no
// `TimelineRegion(`.

import SwiftUI

struct MediaBrowserView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(WorkstationSelection.self) private var selection

    @State private var isOpen = false
    /// nil = not read yet; `.unreadable` = the home could not be read (different from empty).
    @State private var listing: Listing?
    @State private var note: String?
    /// The name filter (B1). Local to this leaf: typing rebuilds the list, never the Workstation.
    @State private var query = ""

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
                content(usage: MediaAsset.usage(clips: clips, document: timeline.document))
                if let note {
                    Text(note)
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task(id: ListingKey(open: isOpen,
                             refs: clips.filter { $0.kind == .audio }.compactMap(\.mediaRef).sorted())) {
            guard isOpen else { return }
            let result = await Task.detached(priority: .utility) { MediaLibrary.listAudio() }.value
            // A detached hop does not inherit cancellation: a listing started before an import
            // landed can finish AFTER the newer one and overwrite it with the older set.
            guard !Task.isCancelled else { return }
            if let assets = result { listing = .assets(assets) } else { listing = .unreadable }
        }
    }

    private var toggleRow: some View {
        Button {
            isOpen.toggle()
            if !isOpen {
                note = nil
                query = ""
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
                if shown.count != assets.count {
                    line("\(shown.count) of \(assets.count) files")
                }
            }
        }
    }

    /// Label above the input (the form rule), a plain field: a name filter, not a search engine.
    private var filterField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Filter by name")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            TextField("Name contains", text: $query)
                .font(EchoelTheme.font(13))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel("Filter by name")
        }
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
                                      bpm: player.preflightTempo) {
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

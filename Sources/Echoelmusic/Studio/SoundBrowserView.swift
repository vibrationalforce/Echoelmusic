// SoundBrowserView.swift
// Echoel — DAW shell S6: the Browse plate's SOUNDS. The stored sounds (`PatchStore`), a star on
// the favorites, and one tap gives the open synth track that sound.
//
// ⭐ ONE SEAM, NOT A SECOND SOUND LOGIC (#416). A tap writes exactly what the Device page's
// Sound row writes: `TrackMix.setSound(.library(id), …)` inside `timeline.editLanePatch`, so it
// is ONE Undo step and the piece keeps its own copy of the sound. Which track can take a sound
// is `TrackMix.controls(…).sound` — the rule the Sound row is shown by — so the browser never
// offers a sound to a track whose voice takes no patch (sub-bass, sampler, body voice, audio,
// the Echoel track).
//
// ⚠️ STORE ORDER, NOT `sortedPatches`. The Device page's hint says "Default plays the first of
// the Sounds", meaning the store's first (factory first, `TheTrackChoosesItsSoundTests`); a
// favorites-first list here would make "the first of the Sounds" two different sounds on two
// plates. The star marks a favorite instead of moving it, and a tap records no use (`markUsed`
// would reorder nothing here, but it ranks the instrument's Sound panel, which stays its owner).
//
// ⭐ REVIEW OF 4dedb218d — FOUR REPAIRS, each the Device row's own behaviour carried across:
// · the list folds like the media library beside it (closed until opened), because ~20 sounds at
//   44 pt each pushed the library and the photo/video seeds screens down on a phone;
// · Default and the piece's own copy are rows, as in the Device menu, so the sound that plays is
//   always the checked one — a lane with no patch plays the first of the Sounds, and a browser
//   that checked nothing there said "no sound";
// · a row with no target LOOKS disabled (the text dims; `.plain` does not dim a styled label) and
//   its hint says why, not what a tap would do;
// · the Echoel track is named: its sound lives on Sound in Instrument, so "open a synth track"
//   was a wrong instruction to someone who had opened the main one.
//
// ⚠️ COLD READS ONLY. The song (`timeline.document`, changes on an edit), the selection (a tap),
// the store (a save) and `player.laneVoiceCapacity` (set once at start) — none of the four hot
// producers (`TheMenuHostReadsNoHotStateTests`), and no presentation modifier: the rows act in
// place. Device-unverified: the list's length on 375 pt, and that the sound is heard.

import SwiftUI

@MainActor
struct SoundBrowserView: View {

    @Environment(TimelineStore.self) private var timeline
    /// Read for `laneVoiceCapacity` only — a cold number set once at start.
    @Environment(TimelineRegionPlayer.self) private var player
    /// Read for `trackID` only — it changes on a tap of a track.
    @Environment(WorkstationSelection.self) private var selection
    @Environment(PatchStore.self) private var patchStore
    /// Closed until opened, like `MediaBrowserView` beside it (review of 4dedb218d, MED-2).
    @State private var isOpen = false

    var body: some View {
        let target = Self.target(selection.trackID, in: timeline.document,
                                 voiceCapacity: player.laneVoiceCapacity)
        // Once per body, not once per row: the answer is the same for every row (LOW-3).
        let choice = target.map {
            TrackMix.soundChoice(of: $0, in: timeline.document, library: patchStore.patches)
        }
        VStack(alignment: .leading, spacing: 6) {
            toggleRow
            if isOpen {
                caption(target)
                // The Device menu's own order: Default, the piece's copy, then the store (#416).
                row(String(localized: "Default"), pick: .standard, favorite: false,
                    choice: choice, target: target)
                if let target,
                   let kept = TrackMix.keptSound(of: target, in: timeline.document, library: patchStore.patches) {
                    row(String(localized: "In this piece: ") + kept.name, pick: .kept, favorite: false,
                        choice: choice, target: target)
                }
                ForEach(patchStore.patches) { patch in
                    row(patch.name, pick: .library(patch.id), favorite: patchStore.isFavorite(id: patch.id),
                        choice: choice, target: target)
                }
            }
        }
    }

    /// The open track, if its voice takes a sound — the Sound row's own rule (#416).
    nonisolated static func target(_ trackID: UUID?, in document: TimelineDocument,
                                   voiceCapacity: Int) -> UUID? {
        guard let laneID = WorkstationSelection.resolvedTrack(trackID, in: document),
              let controls = TrackMix.controls(of: laneID, in: document, voiceCapacity: voiceCapacity),
              controls.sound else { return nil }
        return laneID
    }

    /// Why there is no target, when there is none: the open track is the Echoel track (its sound
    /// is the instrument's), or no synth track is open.
    nonisolated static func opensTheEchoelTrack(_ trackID: UUID?, in document: TimelineDocument) -> Bool {
        guard let laneID = WorkstationSelection.resolvedTrack(trackID, in: document) else { return false }
        return laneID == document.rollLaneID
    }

    private var toggleRow: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(EchoelTheme.font(12, .semibold))
                Text("Sounds").font(EchoelTheme.font(13, .semibold))
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
        // The label is the visible word (Voice Control's label-in-name); the state is a value.
        .accessibilityLabel("Sounds")
        .accessibilityValue(isOpen ? String(localized: "Shown") : String(localized: "Hidden"))
        .accessibilityHint("Lists the stored sounds. A tap on one gives it to the open synth track")
    }

    @ViewBuilder
    private func caption(_ target: UUID?) -> some View {
        Group {
            if let target, let lane = timeline.document.lanes.first(where: { $0.id == target }) {
                Text(String(localized: "Tap a sound to give it to the open track: ") + lane.name)
            } else if Self.opensTheEchoelTrack(selection.trackID, in: timeline.document) {
                Text("The Echoel track plays the instrument's sound. Shape it with Sound in Instrument.")
            } else {
                Text("Open a synth track in Arrange to give it one of these sounds.")
            }
        }
        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ name: String, pick: TrackMix.SoundChoice, favorite: Bool,
                     choice: TrackMix.SoundChoice?, target: UUID?) -> some View {
        let chosen = choice == pick
        let enabled = target != nil
        return Button {
            guard let target else { return }
            timeline.editLanePatch(id: target) {
                TrackMix.setSound(pick, laneID: target, library: patchStore.patches, timeline: timeline)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(EchoelTheme.font(12))
                    .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
                    .opacity(favorite ? 1 : 0)
                    .accessibilityHidden(true)
                Text(name)
                    .font(EchoelTheme.font(13))
                    // `.plain` does not dim a styled label, so the disabled state is drawn here
                    // (review of 4dedb218d, MED-1 — the Warp switch's own pattern).
                    .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if chosen {
                    Image(systemName: "checkmark")
                        .font(EchoelTheme.font(12, .semibold))
                        .foregroundStyle(EchoelTheme.text)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(chosen ? EchoelTheme.text : EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .accessibilityLabel(name)
        .accessibilityValue(favorite ? String(localized: "Favorite") : "")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityHint(enabled ? String(localized: "Gives the open synth track this sound. One Undo step")
                                   : String(localized: "Unavailable: open a synth track in Arrange first"))
    }
}

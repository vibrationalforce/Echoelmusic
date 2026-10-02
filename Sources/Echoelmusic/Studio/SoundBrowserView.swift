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

    var body: some View {
        let target = Self.target(selection.trackID, in: timeline.document,
                                 voiceCapacity: player.laneVoiceCapacity)
        VStack(alignment: .leading, spacing: 6) {
            Text("Sounds")
                .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                .accessibilityAddTraits(.isHeader)
            caption(target)
            ForEach(patchStore.patches) { patch in
                row(patch, target: target)
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

    @ViewBuilder
    private func caption(_ target: UUID?) -> some View {
        if let target, let lane = timeline.document.lanes.first(where: { $0.id == target }) {
            Text(String(localized: "Tap a sound to give it to the open track: ") + lane.name)
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Open a synth track in Arrange to give it one of these sounds.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ patch: SynthPatch, target: UUID?) -> some View {
        let chosen = target.map {
            TrackMix.soundChoice(of: $0, in: timeline.document, library: patchStore.patches)
                == .library(patch.id)
        } ?? false
        let favorite = patchStore.isFavorite(id: patch.id)
        return Button {
            guard let target else { return }
            timeline.editLanePatch(id: target) {
                TrackMix.setSound(.library(patch.id), laneID: target,
                                  library: patchStore.patches, timeline: timeline)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(EchoelTheme.font(12))
                    .foregroundStyle(favorite ? EchoelTheme.text : EchoelTheme.dim)
                    .opacity(favorite ? 1 : 0)
                    .accessibilityHidden(true)
                Text(patch.name)
                    .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
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
        .accessibilityLabel(patch.name)
        .accessibilityValue(favorite ? String(localized: "Favorite") : "")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityHint("Gives the open synth track this sound. One Undo step")
    }
}

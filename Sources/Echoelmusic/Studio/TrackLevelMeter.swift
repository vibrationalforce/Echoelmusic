// TrackLevelMeter.swift
// Echoel — one track's level in its mixer strip, while the piece plays (Workstation redesign B5,
// founder 2026-10-01: "Gestalte alles so um, dass ich Echoelmusic als Workstation ernsthaft
// vertreten kann").
//
// ⭐ WHAT IT MEASURES, SAID ONCE. The peak of the samples the track's OWN rack voice rendered —
// after its effect chain, its insert and the breath swell — held with the master meter's decay
// (`PolySynthVoice.heldPeak`, one store per render block), times that voice's mixer volume (the
// track fader; Mute and Solo land there as 0). So: the track AFTER its fader and BEFORE pan and
// the master chain, as a share of full scale. It is a sample PEAK, not the mix meter's `3 · RMS`;
// it is drawn by the same bar (`MixLevelBar`, #416), whose warning colour therefore means "this
// track alone is within 1 dB of full scale" here.
//
// ⚠️ ONLY A TRACK WITH ITS OWN POLY VOICE HAS ONE (`LaneVoiceRack.meterLevel(slot:)`). The Echoel
// track plays through the instrument's own voices, an audio track through player nodes nothing
// taps, and the sub / sampler / body units carry no meter cell (the sub unit can also be the
// Echoel track's voice). Those strips say "Not metered": a bar there would show silence or
// another track's sound (#164/#227). Which slot a track holds is the player's own rule,
// `MultiRollFanout.slot` — the one `TrackMix.role` asks too (#416).
//
// ⚠️ WHY THIS IS ITS OWN FILE AND ITS OWN STRUCT. The level is not `@Observable` at all: it is an
// audio-thread cell, read here inside a `TimelineView` that runs only while the piece plays.
// `PieceMixerView` mounts this leaf and names no engine (`ThePieceHasAMixerTests` claim 2), so the
// strip list never re-renders at meter rate (the 10.76.41/50 law). A bar that changes length is
// not a flash; the 3 Hz rule is not in play.
//
// ⚠️ WHILE STOPPED the bar-or-words choice can describe the LAST play: the rack's slot bindings
// are written at prime (`LaneVoiceRack.bindings` is not observed), so a kind changed after Stop
// shows its new meter state only from the next Play. The bar itself reads 0 while stopped, so the
// stale half is the words, never a level. During play the player re-adopts the document every step
// (`refreshStructure`/`refreshMixer`), so slot drift lasts at most one step.
//
// DEVICE PROBE, open: the bar moves with a playing poly track, falls to zero on Mute, rests at
// zero after Stop, and an open Picker elsewhere on the plate stays open while it moves.

#if canImport(SwiftUI)
import SwiftUI

/// One track's post-fader peak in its mixer strip, while the piece plays.
@MainActor
struct TrackLevelMeter: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(LaneVoiceRack.self) private var rack

    let laneID: UUID
    /// `TimelineRegionPlayer.laneVoiceCapacity`, handed down by the strip — required, never
    /// defaulted (#431): which slot a track holds depends on it.
    let voiceCapacity: Int

    var body: some View {
        let playing = player.isPlaying
        let document = timeline.document
        let slot = MultiRollFanout.slot(forLaneID: laneID, in: document,
                                        rollLane: document.rollLaneID, capacity: voiceCapacity)
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !playing)) { _ in
            if let slot, let level = rack.meterLevel(slot: slot) {
                // Stopped reads zero: the cell would otherwise show a stopped engine's last block.
                let shown: Float = playing ? level : 0
                // Typed, like `MixLevelMeter.spokenText` (E4-61): one String, one overload.
                let spoken: String = "\(MixLevelMeter.percent(shown))" + String(localized: " percent")
                MixLevelBar(level: shown)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Track level")
                    .accessibilityValue(spoken)
                    .accessibilityHint("Peak of this track's sound after its fader, as a share of full scale. Moves while the piece plays.")
                    .accessibilityAddTraits(.updatesFrequently)
            } else {
                Text("Not metered")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            }
        }
    }
}
#endif

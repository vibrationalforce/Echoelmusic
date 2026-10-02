// MasterStripView.swift
// Echoel — the Mixer's master strip (DAW shell S5, founder 2026-10-02: "DAW look mit allen Features").
//
// WHY: a mixer ends in its master. Until S5 the master level and the loudness meters stood in the
// Instrument stage's Master panel — behind a chip, on a different stage from the track strips they
// sum — so balancing a song meant leaving the Mixer to read what the balance did. This is the last
// strip of the Mixer: the master volume, the stereo level bars and the four EBU R128 numbers, with
// Clear.
//
// ⭐ ONE DOOR: the three MOVED, they were not copied. The Instrument's Master panel keeps what is not
// the master's level — the delivery Target and Tone, and the audio-system rows (buffer, route,
// timing, Release all notes) — and no longer mounts `MasterVolumeField`, `MasterLoudnessGrid` or the
// Clear button (`TheMixerEndsInTheMasterStripTests`).
//
// ⭐ NO HOT READ IN THIS BODY: it reads no engine property. `MasterVolumeField` (`masterVolume`,
// rewritten on every transport step by a master automation lane) and `MasterLoudnessGrid` (the 60 Hz
// meters) are the two leaves that read them — the same two leaves the Master panel mounted, unchanged.
// Clear calls the engine from its button ACTION, which registers no observation.
//
// ⚠️ IT IS MOUNTED ONCE, by `WorkstationView` on the Mixer view, OUTSIDE the song's empty/non-empty
// branch: an empty song still plays the instrument, so its master must stay reachable there too.

import SwiftUI

@MainActor
struct MasterStripView: View {
    @Environment(AudioEngine.self) private var audioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(EchoelTheme.text)
                    .frame(width: 3)
                    .frame(minHeight: 28)
                Text("Master")
                    .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
            }
            // The master fader — its own leaf, so an automation lane rewriting `masterVolume` re-renders
            // only that field (the menus-freeze-while-playing repair, `MasterLoudnessGrid.swift`).
            MasterVolumeField()
            // The level bars and the four loudness numbers — its own leaf, because the 60 Hz meter
            // refresh must re-render only this grid. It claims the expensive metering while on screen.
            MasterLoudnessGrid()
            // ⛔ Until S5 this sentence read "The Target above sets the auto-gain and the export; …" —
            // the Target picker no longer stands above it (it stays in the Instrument's Master panel),
            // so "above" left with the move. Before #316 the line was a streaming-target verdict the
            // numbers cannot support; it still says what the Target GOVERNS, never what the numbers mean.
            HStack {
                Text("These numbers are the mix, not the delivered file. The loudness Target sets the auto-gain and the export.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                // ⛔ #394 — THIS WAS A BARE TITLE BUTTON WITH NO FRAME AT ALL, i.e. a tap
                // target the size of the word: ~35 × 15 pt at `EchoelTheme.font(12)`. That is
                // under the HIG 44×44 floor AND under WCAG 2.5.8 (AA)'s 24×24 — the only
                // control in `EchoelStudioView`'s audited `Button("literal") { … }` set (where it
                // stood until S5) that failed both, and the same class as the clear-place ✕ that `TapTargetFloorTests`
                // already pins. It sits hard against the panel's right edge behind a
                // `Spacer`, so a thumb that lands ten points low hits nothing at all.
                //
                // The frame goes on the LABEL, not on the `Button`: for a title button the
                // label's bounds are what gets hit-tested, so an outer `.frame` would grow the
                // picture without growing the target. `contentShape` then makes the whole
                // 44 pt-tall rectangle hittable rather than just the glyph run.
                //
                // `minHeight`, never `height`: the sentence to the left wraps and is already
                // taller than 44 in most widths, so on a phone this changes no layout — it
                // guarantees the floor exactly in the cases (wide screen, one-line text) where
                // the row would otherwise collapse to the label's own height. A fixed height
                // would also clip the label at large Dynamic Type sizes (the #353 class).
                //
                // `.buttonStyle(.plain)` is not a look change: `foregroundStyle` already
                // overrode the accent tint, so this only stops the default style from
                // re-asserting its own padding on top of the frame.
                Button {
                    audioEngine.resetMastering()
                } label: {
                    Text("Clear")
                        .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Clear the integrated loudness and peak hold")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
        // VoiceOver enters the strip under "Master", like each track strip under its name.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Master")
        // The track strips' own outer gutter (`PieceMixerView`), so the master lines up under them.
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

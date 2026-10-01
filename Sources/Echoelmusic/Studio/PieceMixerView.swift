// PieceMixerView.swift
// Echoel — the piece's mixer: every sounding track as one channel strip (Workstation redesign B3,
// founder 2026-10-01 — „Gestalte alles so um, dass ich Echoelmusic als Workstation ernsthaft
// vertreten kann").
//
// WHY: until B3 a track's level, pan, Mute and Solo were reachable only one track at a time —
// open the track, read its inspector, close it, open the next. A workstation balances a song on
// ONE surface. This view shows every track that makes a sound, top to bottom in song order, each
// with its hue, its name, its level (with the dB reading) and — where the engine honours it — its
// pan and its Mute/Solo.
//
// ⭐ IT ADDS NO SECOND RULE AND NO SECOND WRITER. Which controls a strip carries is
// `TrackMix.controls` — the inspector's own answer, so a sub-bass strip has no pan field for the
// same measured reason the inspector has none (`LaneVoiceRack.setPan` is a no-op there). Every
// write goes through `TrackMix.setLevel`/`setPan`/`flipMute`/`flipSolo`, the one funnel into
// `TimelineStore`. Tracks that make no sound (a bio curve, a track with no voice, an unplayed
// kind) get no strip — a fader there would move a number and not the sound (#164/#227) — and the
// view says how many it left out, so nothing vanishes silently.
//
// ⚠️ ONE CONTROL PER FACT ON SCREEN: the Workstation shows this view INSTEAD of the arrangement
// and its track column (the "Mix" tab), never beside them, so a Mute here and the track header's
// Mute are never on screen together. No meters: a level meter needs a per-track tap on the render
// path (B5, audio-thread review, device) — a strip that pretends to meter would be decoration.
// ⭐ B3b — EVERY EDIT HERE IS ONE STEP IN THE PIECE'S UNDO, one per gesture: each finger sample runs
// inside `TimelineStore.editLaneMix(id:_:)` (the write is still the `TrackMix` call), and the field's
// `onCommit` — or the tap itself for Mute/Solo — closes it with `commitLaneMix(id:)` (`.laneMix`, the
// gesture's fields only). The agent's `TrackMix.setLevel` stays outside that history, and so do the
// inspector, the track header and the Perform grid until they wrap their writes the same way.

import SwiftUI

struct PieceMixerView: View {
    @Environment(TimelineStore.self) private var timeline

    /// `TimelineRegionPlayer.laneVoiceCapacity` — required, never defaulted (#431): the strip set
    /// depends on which MIDI tracks have a voice, and a forgotten call site must not assume one.
    let voiceCapacity: Int

    var body: some View {
        let document = timeline.document
        let strips: [Strip] = document.lanes.compactMap { lane in
            guard let controls = TrackMix.controls(of: lane.id, in: document, voiceCapacity: voiceCapacity),
                  controls.level else { return nil }
            return Strip(lane: lane, controls: controls)
        }
        let silent = document.lanes.count - strips.count
        VStack(alignment: .leading, spacing: 8) {
            if strips.isEmpty {
                Text("No track makes a sound yet. Add a track or write a part, and its strip appears here")
                    .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(strips) { item in
                strip(item.lane, item.controls)
            }
            if silent > 0 {
                Text(silentNote(silent))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One sounding track and the controls its engine honours (`TrackMix.controls`).
    private struct Strip: Identifiable {
        let lane: TimelineLane
        let controls: TrackMix.Controls
        var id: UUID { lane.id }
    }

    /// The count of tracks without a strip, as a sentence — never a silent omission.
    private func silentNote(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 track makes no sound and has no strip")
            : "\(count) " + String(localized: "tracks make no sound and have no strip")
    }

    // MARK: - One channel strip

    private func strip(_ lane: TimelineLane, _ controls: TrackMix.Controls) -> some View {
        let hue = EchoelTheme.TrackHue.of(kind: lane.kind, instrument: lane.builtinInstrument, isBio: lane.isBio)
        let level = Double(lane.level)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(hue.color)
                    .frame(width: 3)
                    .frame(minHeight: 28)
                Image(systemName: EchoelTheme.TrackHue.symbol(kind: lane.kind, instrument: lane.builtinInstrument,
                                                              isBio: lane.isBio))
                    .foregroundStyle(hue.color)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lane.name)
                        .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
                        .lineLimit(1)
                    Text(TrackMix.decibelText(level))
                        .font(EchoelTheme.font(11).monospacedDigit()).foregroundStyle(EchoelTheme.dim)
                        .accessibilityLabel("Level in decibels")
                        .accessibilityValue(TrackMix.decibelText(level))
                }
                Spacer(minLength: 4)
                if controls.muteSolo {
                    stripSwitch("M", name: String(localized: "Mute"), on: lane.isMuted,
                                hint: TrackMix.muteHint(controls.role)) {
                        tapped(lane.id) { TrackMix.flipMute(laneID: lane.id, timeline: timeline) }
                    }
                    stripSwitch("S", name: String(localized: "Solo"), on: lane.isSoloed,
                                hint: TrackMix.soloHint(controls.role)) {
                        tapped(lane.id) { TrackMix.flipSolo(laneID: lane.id, timeline: timeline) }
                    }
                }
            }
            EchoelValueField(
                label: "Level",
                value: Binding(
                    get: { Double(timeline.document.lanes
                        .first(where: { $0.id == lane.id })?.level ?? TimelineLane.defaultLevel) },
                    set: { newLevel in
                        timeline.editLaneMix(id: lane.id) { TrackMix.setLevel(newLevel, laneID: lane.id, timeline: timeline) }
                    }),
                range: TrackMix.levelRange,
                decimals: 2,
                hint: TrackMix.levelHint(controls.role),
                standard: Double(TimelineLane.defaultLevel),
                onCommit: { timeline.commitLaneMix(id: lane.id) })
            if controls.pan {
                EchoelValueField(
                    label: "Pan",
                    value: Binding(
                        get: { Double(timeline.document.lanes
                            .first(where: { $0.id == lane.id })?.pan ?? TimelineLane.defaultPan) },
                        set: { newPan in
                            timeline.editLaneMix(id: lane.id) { TrackMix.setPan(newPan, laneID: lane.id, timeline: timeline) }
                        }),
                    range: TrackMix.panRange,
                    decimals: 2,
                    hint: String(localized: "−1 left, 0 centre, 1 right"),
                    standard: Double(TimelineLane.defaultPan),
                    onCommit: { timeline.commitLaneMix(id: lane.id) })
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
        // A list of strips says "Level" once per track — VoiceOver enters each strip under the
        // track's own name, so the field it lands on belongs to a named track.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: lane.name))
    }

    /// A Mute or Solo tap is a whole gesture: one write through the `TrackMix` funnel, one undo step
    /// (B3b). The two number fields close their gesture on `onCommit` instead, once per drag.
    private func tapped(_ laneID: UUID, _ write: () -> Void) {
        timeline.editLaneMix(id: laneID, write)
        timeline.commitLaneMix(id: laneID)
    }

    /// Mute or Solo on a strip: a letter on screen, the full word to VoiceOver, monochrome fill
    /// when on — the track header's own treatment, so the two read as the same switch.
    private func stripSwitch(_ letter: String, name: String, on: Bool, hint: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(letter)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(on ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityInputLabels([name, letter])
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? String(localized: "On") : String(localized: "Off"))
        .accessibilityHint(hint)
    }
}

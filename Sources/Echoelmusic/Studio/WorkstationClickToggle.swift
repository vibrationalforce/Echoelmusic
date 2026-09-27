// WorkstationClickToggle.swift
// Echoel — design slice 10 (modes census 2026-09-26), second half: the click, on the Workstation.
//
// The instrument has had a click for a long time (Tempo panel `metronomeRow`, Mix panel's Click
// strip). The Workstation — where a musician arranges, records a take and plays the song through —
// had none, so playing in time there meant leaving the surface to arm it. This is the same switch,
// on the same `MetronomeVoice`; one model, three doors, nothing duplicated. Level, accent and
// "accent every" stay in the Tempo panel: this door arms the click and nothing else.
//
// ⭐ WHY THE CLICK CAN BE ARMED HERE AT ALL (54b2e28cf). Until that commit the click ran on its own
// sample clock and only the instrument's Play (one sixteenth early) ever lined it up; the
// Workstation's Play never did. The transport's step subscriber now anchors the click on every
// beat, so a click armed here lands on the song's beats. Without that commit this door would have
// offered a click that drifts against the parts it plays under.
//
// ⚠️ WHY THIS IS ITS OWN FILE. `WorkstationView` sits on the always-evaluated `dropdownContent`
// path (#479) and names no voice; the recorder's door set the precedent (`RecordTakeControls`).
// And the one read here is `metronome.enabled` — COLD, a finger flips it. `metronome.bpm` is the
// hot one (the "metronome" tempo relay pushes it during a glide, `TheMenuHostReadsNoHotStateTests`),
// so this leaf must never show the tempo: a tempo readout belongs to its own self-driving leaf.

import SwiftUI

/// The Click switch beside the Workstation's Play. Arms or disarms the one metronome.
@MainActor
struct WorkstationClickToggle: View {
    @Environment(MetronomeVoice.self) private var metronome

    var body: some View {
        let on = metronome.enabled
        Button {
            metronome.enabled.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "metronome")
                    .font(EchoelTheme.font(13, .semibold))
                Text("Click")
                    .font(EchoelTheme.font(13, .semibold))
            }
            // Never truncated to "Cl…" on a narrow phone at large text: the position readout
            // beside it can shrink (`minimumScaleFactor`), a one-word label cannot (review LOW-2).
            .fixedSize()
            // The armCard idiom of the Play beside it: accent + onPrimary while it is ON,
            // fill + border while it is off. Never dimmed — the click is always available.
            .foregroundStyle(on ? EchoelTheme.onPrimary : EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .fill(on ? EchoelTheme.accent : EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(on ? Color.clear : EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Click")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(WorkstationSummary.clickHint(on: on))
    }
}

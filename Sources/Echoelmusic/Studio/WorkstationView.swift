// WorkstationView.swift
// Echoel — #1436, founder Phase 3: *"build the smallest read-only Workstation surface."*
//
// WHAT THIS IS. A reachable, READ-ONLY window onto the canonical timeline state — the lanes
// and regions `TimelineStore` already owns and already persists. It is a DMMW surface, not a
// product and not a rebuild of the arrangement UI #121 Slice 4 deleted. Phase 3 proves
// REACHABLE; it deliberately does not prove PLAYABLE.
//
// ⛔ IT OWNS NOTHING AND MUTATES NOTHING. No second `TimelineDocument`, no `Arrangement`, no
// project store, no persistence file, no clock, no routing graph. It reads
// `TimelineStore.document` and projects it through `WorkstationSummary`, which is a pure
// function. Every one of `TimelineStore`'s ~40 mutating methods is deliberately unreached
// from here — `TheWorkstationHasADoorTests` pins that, because "read-only" is a property a
// later slice can lose in one line.
//
// ⚠️ RENDER SAFETY (10.76.41/50). This is a COLD leaf. It reads `TimelineStore.document`,
// which changes on a user edit, never on a clock — no audio meters, no buffer-rate state, no
// bio, no playhead. That matters more than it looks: this view is reached through
// `dropdownContent`, which since #479 is evaluated in the ROOT body permanently, so a
// high-frequency read added here would rebuild the whole Studio at that rate and tear down
// any open `.menu` Picker. The law is in `.claude/skills/swiftui-render-safety/SKILL.md`;
// the reason it applies HERE is that this file sits on the always-evaluated path.
//
// ⭐ THE DOOR COSTS ZERO PRESENTATION MODIFIERS, which is the whole reason this shape was
// chosen over a `.sheet`. It is a `StudioMenu` case in the existing chip strip — the same
// idiom `soundPanel`, `mixerPanel` and the rest use — so the body's aggregate generic type is
// untouched and the black-screen law (10.76.34) is not approached. A modal would have spent
// one of the last slots under the 14 ceiling on a surface that needs no modality at all.

#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
struct WorkstationView: View {

    @Environment(TimelineStore.self) private var timeline

    var body: some View {
        let summary = WorkstationSummary(document: timeline.document)
        VStack(alignment: .leading, spacing: 10) {
            if summary.isEmpty {
                emptyState
            } else {
                songLine(summary)
                ForEach(summary.lanes) { laneRow($0) }
                if summary.orphanRegionCount > 0 { orphanLine(summary.orphanRegionCount) }
                if summary.automationLaneCount > 0 { automationLine(summary.automationLaneCount) }
            }

            // MARK: - Phase 4 seam — timeline transport goes HERE
            //
            // ⚠️ NOTHING IN THIS FILE CALLS `TimelineRegionPlayer.play(…)`, and that is the
            // phase boundary rather than an oversight: Phase 3 proves the surface is
            // REACHABLE, Phase 4 makes it PLAYABLE. `TheWorkstationHasADoorTests` claim H
            // pins that the player still has no production caller, so this slice cannot
            // quietly absorb the next one.
            //
            // A DISABLED play button was the obvious thing to put here and is deliberately
            // absent: a control that cannot do what it depicts is a lying control, and this
            // repo has paid for that shape before (the doorless surfaces register). One
            // honest sentence says the same thing and cannot be tapped.
            transportSeam
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pieces

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No arrangement yet")
                .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
            Text("Takes you record or generate appear here as parts on a track.")
                .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        // One spoken sentence rather than two fragments — VoiceOver would otherwise read the
        // heading and the explanation as unrelated items.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No arrangement yet. Takes you record or generate appear here as parts on a track.")
    }

    private func songLine(_ summary: WorkstationSummary) -> some View {
        let tracks = summary.lanes.count
        let parts = summary.regionCount
        let bars = summary.lengthBars
        return HStack(spacing: 10) {
            Text("\(tracks) \(tracks == 1 ? "track" : "tracks")")
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(parts) \(parts == 1 ? "part" : "parts")")
            Text("·").foregroundStyle(EchoelTheme.dim)
            Text("\(bars) \(bars == 1 ? "bar" : "bars")")
            Spacer(minLength: 0)
        }
        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arrangement: \(tracks) tracks, \(parts) parts, \(bars) bars long")
    }

    private func laneRow(_ row: WorkstationSummary.LaneRow) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.kind.systemImage)
                .foregroundStyle(EchoelTheme.dim)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
                    if let instrument = row.instrument {
                        Text(instrument.displayName)
                            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    }
                }
                Text(detailLine(row))
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            }
            Spacer(minLength: 0)
            ForEach(stateTags(row), id: \.self) { tag in
                Text(tag)
                    .font(EchoelTheme.font(10, .semibold))
                    .foregroundStyle(EchoelTheme.dim)
                    .padding(.horizontal, 6).frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.fill))
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
        // The row is several fragments on screen and ONE fact to a listener (#1436): the
        // sentence is built once, in `WorkstationSummary`, so it cannot drift from the numbers
        // rendered beside it (#416).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WorkstationSummary.spokenDescription(of: row))
    }

    /// The printed half of the same facts `spokenDescription` says — short, because the row
    /// is 11 pt and the listener already has the long form.
    private func detailLine(_ row: WorkstationSummary.LaneRow) -> String {
        var text = row.kind.displayName
        if row.isBio { text += " · bio curve" }
        switch row.regionCount {
        case 0:  text += " · no parts"
        case 1:  text += " · 1 part"
        default: text += " · \(row.regionCount) parts"
        }
        if let first = row.firstTick, let last = row.lastTick, row.regionCount > 0 {
            // One spelling of the span, shared with the spoken form — an en dash here and the
            // word "to" there, but the same two bar numbers (#416).
            text += " · " + WorkstationSummary.barSpan(firstTick: first, lastTick: last,
                                                       joiner: "–")
        }
        if !row.playsOnTheTimeline && row.regionCount > 0 { text += " · no engine yet" }
        return text
    }

    /// Only the states that are ON. A row of greyed-out "not muted, not soloed, not armed"
    /// badges would be three pieces of chrome saying nothing.
    private func stateTags(_ row: WorkstationSummary.LaneRow) -> [String] {
        var tags: [String] = []
        if row.isMuted { tags.append("MUTE") }
        if row.isSoloed { tags.append("SOLO") }
        if row.isArmed { tags.append("ARM") }
        return tags
    }

    private func orphanLine(_ count: Int) -> some View {
        Text("\(count) \(count == 1 ? "part belongs" : "parts belong") to a track this song no longer has.")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(count) parts belong to a track this song no longer has")
    }

    private func automationLine(_ count: Int) -> some View {
        Text("\(count) automation \(count == 1 ? "lane" : "lanes")")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
    }

    private var transportSeam: some View {
        Text("Read-only for now — the arrangement is not played from here yet.")
            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
            .accessibilityLabel("This view is read-only. The arrangement is not played from here yet.")
    }
}
#endif

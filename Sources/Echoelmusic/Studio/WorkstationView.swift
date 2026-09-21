// WorkstationView.swift
// Echoel — #1436 founder Phase 3 (the surface) + #1437 founder Phase 4 (its transport).
//
// WHAT THIS IS. A reachable window onto the canonical timeline state — the lanes and regions
// `TimelineStore` already owns and already persists — with ONE control: Play/Stop. It is a
// DMMW surface, not a product and not a rebuild of the arrangement UI #121 Slice 4 deleted.
//
// ⭐ READ-ONLY NOW MEANS A NARROWER, SHARPER THING, and the distinction is the whole reason
// the word survives here. The surface still cannot CHANGE the song — no region or lane
// editing, no drag, trim, split, duplicate, no automation authoring, no import, no record.
// What Phase 4 added is the ability to START it. Editing the document and starting the
// transport are different powers; #1437 took exactly one of them.
//
// ⛔ IT OWNS NOTHING AND MINTS NOTHING. No second `TimelineDocument`, no `Arrangement`, no
// project store, no persistence file, no clock, no routing graph, no second player. It reads
// `TimelineStore.document`, projects it through `WorkstationSummary` (a pure function), and
// hands that same document to the ONE `TimelineRegionPlayer` the app constructs. Every one of
// `TimelineStore`'s ~40 mutating methods is deliberately unreached from here —
// `TheWorkstationPlaysTheTimelineTests` pins that, because "read-only" is a property a later
// slice can lose in one line.
//
// ⚠️ THE CLOCK IS NOT HERE AND MUST NEVER BE. `PatternEngine` is the musical authority;
// `play(...)` joins it (`pattern.play(cause: .timelineRegion)`) rather than starting anything
// of its own, and Stop rides the same transport back out. There is no timer, no display link
// and no tick in this file, and a guard says so — a second clock is the Ω-level mistake this
// phase was most at risk of making.
//
// ⚠️ RENDER SAFETY (10.76.41/50). This is a COLD leaf, and #1437 kept it one ON PURPOSE.
// `body` reads exactly two things: `TimelineStore.document`, which changes on a user edit and
// never on a clock, and `TimelineRegionPlayer.isPlaying`, which changes TWICE per take. It
// does NOT read `currentTick` — the player marks that `@ObservationIgnored` precisely so a
// view cannot subscribe to the ~8 Hz song position, and a playhead readout here would undo
// that with one line. No audio meters, no buffer-rate state, no bio. That matters more than
// it looks: this view is reached through
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
//
// NEEDS-FOUNDER-VERIFY (#1436/#1437): the door AND its transport, on the device. None of
// this is a thing a gate can answer — a green `Build for Testing` proves the bundle compiles
// and says nothing about whether a note is heard. (1) The "Workstation" chip is there,
// between Field and Save/Export, and the strip scrolls far enough to reach it. (2) A tap
// swaps the plate, and tapping Sound afterwards brings the instrument back — no stuck panel.
// (3) On a fresh install the plate shows EITHER the empty state OR the two seeded lanes
// ("MIDI 1", "Audio 1") with zero parts, and Play reads "Nothing to play yet" and does not
// respond. (4) With a MIDI part on the song: Play SOUNDS it, the button turns to Stop, Stop
// silences it, and a second Play after that starts it again — the stick is what a lifecycle
// bug looks like from outside. (5) The instrument's own ■ also stops it (one transport, not
// two). (6) VoiceOver reads each lane row as ONE sentence and announces Play/Stop with the
// hint, not as an unlabelled glyph.

#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
struct WorkstationView: View {

    @Environment(TimelineStore.self) private var timeline
    /// The ONE player the app constructs (`EchoelmusicApp`, `@State`), reached through the
    /// environment. This view never MINTS one — a second player would be a second follow-state
    /// over one transport, and `TheWorkstationPlaysTheTimelineTests` claim F pins that.
    @Environment(TimelineRegionPlayer.self) private var player
    /// ⚠️ THE NEXT THREE ARE READ ONLY INSIDE THE TAP HANDLERS, never in `body`. Declaring an
    /// `@Environment` subscribes to nothing; READING a property in `body` does, and this file
    /// sits on the always-evaluated `dropdownContent` path (#479). `beatPlayer.pattern` in
    /// particular leads to the ~20 Hz transport — a body read of it would be the 10.76.41/50
    /// freeze with a different producer.
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(PianoRollModel.self) private var pianoRoll
    @Environment(ClipStore.self) private var clipStore

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

            // MARK: - The timeline transport (#1437, founder Phase 4)
            //
            // ⭐ THIS IS THE ONE PRODUCTION CALLER of `TimelineRegionPlayer.play(…)`, and it
            // arrives with the guard that says so. Phase 3's claim H pinned "zero callers";
            // it is REPLACED, in the same commit, by the invariant that exactly this path
            // may call it — inverted deliberately rather than routed around, because a
            // guard that survives by aliasing is worse than no guard.
            //
            // ⚠️ THE CONTROL IS UNAVAILABLE WHEN THE ENGINE WOULD REFUSE. `canPlay` is the
            // engine's OWN guard (#416), not a second opinion, so the button can never offer
            // a start that silently does nothing — the "disabled decorative transport" this
            // surface was told not to grow.
            transportRow
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

    /// Play / Stop for the arrangement. ONE button, because there is one thing to say:
    /// the song is running or it is not. A separate greyed Stop beside a Play would be two
    /// claims where the state has one — the #305 lesson from the instrument's own row, where
    /// two controls carrying the same glyph meant different things.
    private var transportRow: some View {
        // `canPlay` is the engine's own guard, asked here so the control matches it exactly.
        // `isPlaying` is the player's only hot-ish observable on this path and it changes
        // TWICE per take, not per step (`currentTick` is `@ObservationIgnored` precisely so
        // a reader like this one cannot subscribe to the ~8 Hz position).
        let playing = player.isPlaying
        // ⚠️ THE CLIPS ARE PART OF THE QUESTION (#1438). A placed region is a POINTER; the
        // engine can only start if at least one of them resolves into content it would
        // execute, so the control must hand over the same clip values `play(...)` will.
        // Reading `filledClips` here also SUBSCRIBES this leaf to the clip grid, which is
        // wanted: the moment the composer writes notes into its clip, Play becomes
        // available without a second tap. It is not a hot read — `ClipStore.slots` is
        // written by generate/evolve (~30 s at most), never per transport step.
        let startable = TimelineRegionPlayer.canPlay(timeline.document,
                                                     clips: clipStore.filledClips)
        return HStack(spacing: 8) {
            Button {
                if playing { player.stop() } else { startTimeline() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(playing ? "Stop" : "Play")
                        .font(EchoelTheme.font(13, .semibold))
                }
                // The armCard idiom, unchanged: accent + onPrimary while it is RUNNING,
                // fill + border while it is not. Dim only where the control is unavailable,
                // so "off" and "cannot" do not wear the same colour.
                .foregroundStyle(playing ? EchoelTheme.onPrimary
                                         : (startable ? EchoelTheme.text : EchoelTheme.dim))
                .padding(.horizontal, 14)
                .frame(minWidth: 92, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(playing ? EchoelTheme.accent : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(playing || !startable ? Color.clear : EchoelTheme.border,
                                  lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!playing && !startable)
            .accessibilityLabel(playing ? "Stop timeline" : "Play timeline")
            .accessibilityHint(WorkstationSummary.transportHint(playing: playing, startable: startable))

            Text(WorkstationSummary.transportCaption(playing: playing, startable: startable))
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)   // the button's own hint already carries this
        }
        .padding(.top, 2)
    }

    /// Start the arrangement on the ONE transport. Everything this hands over is already
    /// owned elsewhere: the document by `TimelineStore`, the clock by `PatternEngine` (the
    /// player calls `pattern.play(cause: .timelineRegion)` itself), the notes by
    /// `PianoRollModel`. Nothing is constructed here.
    private func startTimeline() {
        player.play(document: timeline.document,
                    clips: clipStore,
                    pattern: beatPlayer.pattern,
                    pianoRoll: pianoRoll)
    }

}
#endif

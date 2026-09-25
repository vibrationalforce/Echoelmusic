//
//  SelectedPartBar.swift
//  Echoelmusic — Studio (WA4 critical path 5: edit the part selected on the Arrange canvas)
//
//  WHY THIS EXISTS. The canvas selects a part; this bar acts on it — one bar earlier / later,
//  split, copy, remove. Every write is `TimelineStore`'s existing method (one call = one undo
//  step, `snapshotForUndo` inside each); the playing engine chases a structural edit live.
//  Nothing here is a second truth: the part is resolved from the document on every render,
//  and a part that no longer exists (after Remove, Undo, Open) simply hides the bar.
//
//  ⭐ SPLIT KEEPS WARPED AUDIO SEAMLESS. `TimelineRegion.split(at:bpm:)` advances the second
//  piece's media offset by the elapsed time at the `bpm` it is handed. For an unwarped part
//  that is the song tempo. For a WARPED part it is not: the engine consumes media `rate×` as
//  fast as song time passes (`AudioRegionPlayback.filePositionSeconds`), so a split at the song
//  tempo started the second half `rate×` too early or late in the file — an audible jump at
//  the cut. `PartSplit.mediaBPM` hands the split the tempo at which media time elapses, asked
//  from the SAME `StretchPlan.resolve` the engine plays with (#416), so the second half starts
//  exactly where the first stopped.
//
//  ⚠️ WHERE SPLIT CUTS: the song-grid bar nearest the part's middle, or the nearest beat when
//  no bar line falls inside it — canonical snapping, never a free tick. A part one beat long
//  or shorter cannot be split and the button says so by being unavailable.
//
//  ⚠️ AND A CUT MAY NOT CHANGE WHO PLAYS (review MEDIUM-1). The second half starts later than
//  the original, and `activeRegion` gives an overlap to the later start — so cutting a part
//  that another part overlaps could hand bars back to the buried one. `PartSplit.keepsWhoPlays`
//  asks the one precedence rule before and after; if any tick changes hands, Split is refused
//  and its label says why.
//
//  Cold reads only: the selection and `timeline.document` change on a tap. The song tempo and
//  the clip are read INSIDE the Split handler, never in `body`.
//

import SwiftUI

/// The pure half of Split: where it cuts, and the tempo at which the part's media elapses.
enum PartSplit {

    /// The cut for `part`: the song-grid bar nearest its middle, else the nearest beat, or nil
    /// when no grid line falls strictly inside the part.
    nonisolated static func tick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard part.lengthTicks > 1 else { return nil }
        let middle = Double(start) + Double(part.lengthTicks) / 2
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let snapped = Int((middle / Double(unit)).rounded()) * unit
            if snapped > start, snapped < end { return snapped }
            // The nearest line may sit outside a short part while another is inside it.
            let inward = snapped <= start ? snapped + unit : snapped - unit
            if inward > start, inward < end { return inward }
        }
        return nil
    }

    /// The tempo at which `region`'s MEDIA elapses when the song plays at `projectBPM` — the
    /// song tempo for an unwarped part, the song tempo divided by the engine's stretch rate for
    /// a warped one. nil for a tempo no split may use (non-finite or not positive).
    nonisolated static func mediaBPM(for region: TimelineRegion, clip: Clip?,
                                     projectBPM: Double) -> Double? {
        guard projectBPM.isFinite, projectBPM > 0 else { return nil }
        let rate = StretchPlan.resolve(mode: region.stretchMode,
                                       warpEnabled: region.warpEnabled,
                                       nativeBPM: clip?.nativeBPM ?? 0,
                                       projectBPM: projectBPM,
                                       capabilities: StretchMode.timelineCapabilities).rate
        guard rate.isFinite, rate > 0 else { return projectBPM }
        return projectBPM / rate
    }

    /// Whether cutting `regionID` at `tick` leaves every tick of its track played by the SAME
    /// part (its second half counting as itself). `activeRegion` gives an overlap to the LATER
    /// start, so the second half of a cut starts later than the original did and can win over a
    /// part that used to cover it — a "cut" that un-buries a hidden part (review MEDIUM-1).
    /// Asked of the one precedence rule (#1440) at the bounded set of ticks where the winner
    /// can change (`candidateSampleTicks`), before and after. The tempo handed to the
    /// hypothetical split moves only media offsets, never who plays, so any positive one does.
    nonisolated static func keepsWhoPlays(regionID: UUID, atTick tick: Int,
                                          in document: TimelineDocument) -> Bool {
        guard let index = document.regions.firstIndex(where: { $0.id == regionID }),
              let (first, second) = document.regions[index].split(at: tick, bpm: 120) else {
            return false
        }
        // The store's own placement: the first half in place, the second appended
        // (`TimelineStore.splitRegion`) — placement breaks ties in `activeRegion`.
        var after = document
        after.regions[index] = first
        after.regions.append(second)
        let lane = first.laneID
        let ticks = Set(TimelineScheduling.candidateSampleTicks(in: document, laneID: lane))
            .union(TimelineScheduling.candidateSampleTicks(in: after, laneID: lane))
        for sample in ticks {
            let before = TimelineScheduling.activeRegion(in: document, laneID: lane, at: sample)?.id
            var now = TimelineScheduling.activeRegion(in: after, laneID: lane, at: sample)?.id
            if now == second.id { now = regionID }
            if before != now { return false }
        }
        return true
    }
}

/// The actions for the part selected on the Arrange canvas.
@MainActor
struct SelectedPartBar: View {

    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// ⚠️ READ ONLY INSIDE THE SPLIT HANDLER — `preflightTempo` is `@ObservationIgnored` and
    /// the clip grid is not this bar's to observe.
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore

    var body: some View {
        let document = timeline.document
        if let regionID = WorkstationSelection.resolvedRegion(selection.regionID,
                                                              track: selection.trackID, in: document),
           let trackID = selection.trackID,
           TrackParts.arrangeable(trackID, in: document),
           let part = TrackParts.parts(onLane: trackID, in: document).first(where: { $0.id == regionID }) {
            let title = TrackParts.title(part)
            let cut = PartSplit.tick(for: part)
            // A cut that would change which overlapping part plays is refused, not made.
            let splittable = cut.map { PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0,
                                                                in: document) } ?? false
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected part · \(title)")
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                // Five labelled buttons do not fit a phone at every type size (review
                // MEDIUM-3): the row falls back to icons, every button keeping its full label.
                ViewThatFits(in: .horizontal) {
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              showsTitles: true)
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              showsTitles: false)
                }
            }
        }
    }

    private func actionRow(_ part: TrackParts.Part, regionID: UUID, cut: Int?, splittable: Bool,
                           showsTitles: Bool) -> some View {
        let earlier = TrackParts.earlierStart(part)
        return HStack(spacing: 6) {
            button("Earlier", "chevron.left", enabled: earlier != nil, showsTitle: showsTitles,
                   label: "Move the selected part one bar earlier") {
                if let tick = earlier { TrackParts.move(part, toStartTick: tick, timeline: timeline) }
            }
            button("Later", "chevron.right", enabled: true, showsTitle: showsTitles,
                   label: "Move the selected part one bar later") {
                TrackParts.move(part, toStartTick: TrackParts.laterStart(part), timeline: timeline)
            }
            button("Split", "scissors", enabled: splittable, showsTitle: showsTitles,
                   label: splitLabel(cut: cut, splittable: splittable)) {
                if splittable, let cut { split(regionID, at: cut) }
            }
            button("Copy", "plus.square.on.square", enabled: true, showsTitle: showsTitles,
                   label: "Copy the selected part to right after it") {
                TrackParts.duplicate(part, timeline: timeline)
            }
            button("Remove", "trash", enabled: true, showsTitle: showsTitles,
                   label: "Remove the selected part. Undo brings it back") {
                TrackParts.remove(part, timeline: timeline)
            }
        }
    }

    private func splitLabel(cut: Int?, splittable: Bool) -> String {
        guard let cut else { return "This part is too short to split" }
        guard splittable else {
            return "Splitting here would change which overlapping part plays"
        }
        return "Split the selected part at \(SessionGrid.label(forTick: cut))"
    }

    private func split(_ regionID: UUID, at tick: Int) {
        guard let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),
                                           projectBPM: player.preflightTempo) else {
            log.log(.info, category: .audio, "Split refused: no usable song tempo")
            return
        }
        timeline.splitRegion(id: regionID, atTick: tick, bpm: bpm)
    }

    private func button(_ title: String, _ systemImage: String, enabled: Bool, showsTitle: Bool,
                        label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                if showsTitle {
                    Text(title).font(EchoelTheme.font(11, .semibold)).lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

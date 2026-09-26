//
//  SelectedPartBar.swift
//  Echoelmusic — Studio (WA4 critical path 5: edit the part selected on the Arrange canvas)
//
//  WHY THIS EXISTS. The canvas selects a part; this bar acts on it — one bar earlier / later,
//  trim start / end (one grid step inward, `PartTrim`), split, copy, remove. Every write is `TimelineStore`'s existing method (one call = one undo
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
//  ⚠️ TRIM ONLY TAKES AWAY, and under the same rule: a trimmed start moves later and can win an
//  overlap it used to lose, so `PartTrim.onlyLetsGo` lets a trim change nothing but the ticks
//  the part gives up — revealing a part underneath is what a trim is for; stealing bars is not.
//
//  Cold reads only: the selection and `timeline.document` change on a tap. The song tempo and
//  the clip are read INSIDE the Split and Trim-start handlers, never in `body`.
//
//  ⭐ M10 — PLAY FROM THE PART, ONE TAP ABOVE ITS NOTES. The loop OPEN → EDIT → PLAY ended at
//  the Workstation's Play, below every track row and far from the note grid — and it always
//  started the song from the top. `PartPlayButton` starts it from the selected part's bar. It
//  starts nothing itself: `playFrom` is the Workstation's one start (`startTimeline`, the one
//  `player.play(` caller) and `songCanStart` its one `canPlay` question, both handed in. The
//  button reads `player.isPlaying` in its OWN body (twice per take), never in this bar's.
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

/// The pure half of Trim (WA4 critical path 5, the verb that was held): each edge moves ONE song
/// grid step INWARD — never outward. A trim only takes material away, so the name promises
/// exactly what happens; lengthening a part past its media would be a different act with a
/// different answer per media kind (silence for audio, a loop for MIDI) and stays out.
enum PartTrim {

    /// The new start for "Trim start": the first song-grid bar line after the part's start, else
    /// the first beat, strictly inside the part — or nil when no grid line falls inside it.
    nonisolated static func startTick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard start >= 0, part.lengthTicks > 1 else { return nil }
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let next = (start / unit + 1) * unit
            if next > start, next < end { return next }
        }
        return nil
    }

    /// The new end for "Trim end": the last song-grid bar line before the part's end, else the
    /// last beat, strictly inside the part — or nil when no grid line falls inside it.
    nonisolated static func endTick(for part: TrackParts.Part) -> Int? {
        let start = part.startTick
        let end = part.startTick + part.lengthTicks
        guard start >= 0, part.lengthTicks > 1 else { return nil }
        for unit in [TimelineTime.ticksPerBar, TimelineTime.ticksPerBeat] where unit > 0 {
            let previous = ((end - 1) / unit) * unit
            if previous > start, previous < end { return previous }
        }
        return nil
    }

    /// Whether replacing `regionID` with `trimmed` changes NOTHING but the ticks the part let go
    /// of. Trimming the START moves the part's start later, and `activeRegion` gives an overlap
    /// to the later start — so a trim could hand bars the part still covers to it from a part
    /// that used to win them (or the other way round). The one change a trim may make is the
    /// part giving up a tick outside its new span; anything else is refused, asked of the one
    /// precedence rule (#1440) at the bounded set of ticks where the winner can change.
    nonisolated static func onlyLetsGo(_ trimmed: TimelineRegion, replacing regionID: UUID,
                                       in document: TimelineDocument) -> Bool {
        guard let index = document.regions.firstIndex(where: { $0.id == regionID }) else {
            return false
        }
        var after = document
        after.regions[index] = trimmed
        let lane = trimmed.laneID
        let ticks = Set(TimelineScheduling.candidateSampleTicks(in: document, laneID: lane))
            .union(TimelineScheduling.candidateSampleTicks(in: after, laneID: lane))
        for sample in ticks {
            let before = TimelineScheduling.activeRegion(in: document, laneID: lane, at: sample)?.id
            let now = TimelineScheduling.activeRegion(in: after, laneID: lane, at: sample)?.id
            if before == now { continue }
            let stillCovered = sample >= trimmed.startTick && sample < trimmed.endTick
            if before == regionID, !stillCovered { continue }
            return false
        }
        return true
    }

    /// The region "Trim start" would leave, or nil when it cannot move or would change who plays.
    /// The media offset follows at 120 BPM here — it moves no tick, so precedence cannot see it;
    /// the store's write uses the tempo the media really elapses at (`PartSplit.mediaBPM`).
    nonisolated static func startTrim(_ part: TrackParts.Part,
                                      in document: TimelineDocument) -> Int? {
        guard let tick = startTick(for: part),
              let region = document.regions.first(where: { $0.id == part.id }),
              let trimmed = region.trimmedStart(toTick: tick, bpm: 120),
              trimmed.startTick == tick,
              onlyLetsGo(trimmed, replacing: part.id, in: document) else { return nil }
        return tick
    }

    /// The new length "Trim end" would leave, or nil when it cannot move or would change who plays.
    nonisolated static func endTrim(_ part: TrackParts.Part,
                                    in document: TimelineDocument) -> Int? {
        guard let tick = endTick(for: part),
              let region = document.regions.first(where: { $0.id == part.id }) else { return nil }
        var trimmed = region
        trimmed.lengthTicks = tick - region.startTick
        guard onlyLetsGo(trimmed, replacing: part.id, in: document) else { return nil }
        return trimmed.lengthTicks
    }
}

/// The actions for the part selected on the Arrange canvas.
@MainActor
struct SelectedPartBar: View {

    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// ⚠️ READ ONLY INSIDE THE SPLIT AND TRIM-START HANDLERS — `preflightTempo` is `@ObservationIgnored` and
    /// the clip grid is not this bar's to observe.
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(ClipStore.self) private var clipStore

    /// The Workstation's one start, from a tick (M10). Required (#431).
    let playFrom: (Int) -> Void
    /// The Workstation's one "would Play start the song?" (M10) — asked in the button's body.
    let songCanStart: () -> Bool

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
            let trims = Trims(start: PartTrim.startTrim(part, in: document),
                              endLength: PartTrim.endTrim(part, in: document))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Selected part · \(title)")
                        .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                    Spacer(minLength: 8)
                    PartPlayButton(startTick: part.startTick, playFrom: playFrom,
                                   songCanStart: songCanStart)
                }
                // Seven labelled buttons do not fit a phone at every type size (review
                // MEDIUM-3): the row falls back to icons, then to two rows of icons — every
                // button keeping its full spoken label.
                ViewThatFits(in: .horizontal) {
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              trims: trims, showsTitles: true)
                    actionRow(part, regionID: regionID, cut: cut, splittable: splittable,
                              trims: trims, showsTitles: false)
                    VStack(alignment: .leading, spacing: 6) {
                        moveRow(part, showsTitles: false)
                        editRow(part, regionID: regionID, cut: cut, splittable: splittable,
                                trims: trims, showsTitles: false)
                    }
                }
                // Review of 75d27e615 (LOW): a refused Split said why only to VoiceOver — a
                // sighted player saw a dimmed scissors and no reason.
                if cut != nil, !splittable {
                    Text("Split is off here: it would change which overlapping part plays.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                }
            }
        }
    }

    /// The two edges a trim may move, resolved once per render (nil = unavailable).
    private struct Trims {
        let start: Int?
        let endLength: Int?
    }

    private func actionRow(_ part: TrackParts.Part, regionID: UUID, cut: Int?, splittable: Bool,
                           trims: Trims, showsTitles: Bool) -> some View {
        HStack(spacing: 6) {
            moveRow(part, showsTitles: showsTitles)
            editRow(part, regionID: regionID, cut: cut, splittable: splittable, trims: trims,
                    showsTitles: showsTitles)
        }
    }

    private func moveRow(_ part: TrackParts.Part, showsTitles: Bool) -> some View {
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
        }
    }

    private func editRow(_ part: TrackParts.Part, regionID: UUID, cut: Int?, splittable: Bool,
                         trims: Trims, showsTitles: Bool) -> some View {
        HStack(spacing: 6) {
            button("Trim start", "arrow.right.to.line", enabled: trims.start != nil,
                   showsTitle: showsTitles, label: trimStartLabel(trims.start)) {
                if let tick = trims.start { trimStart(regionID, to: tick) }
            }
            button("Trim end", "arrow.left.to.line", enabled: trims.endLength != nil,
                   showsTitle: showsTitles, label: trimEndLabel(part, trims.endLength)) {
                if let length = trims.endLength {
                    timeline.resizeRegion(id: regionID, lengthTicks: length)
                }
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

    private func trimStartLabel(_ tick: Int?) -> String {
        guard let tick else {
            return "The start cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays"
        }
        return "Trim the selected part so it starts at \(SessionGrid.label(forTick: tick))"
    }

    private func trimEndLabel(_ part: TrackParts.Part, _ length: Int?) -> String {
        guard let length else {
            return "The end cannot be trimmed: no grid line inside the part, or it would change which overlapping part plays"
        }
        return "Trim the selected part so it ends at \(SessionGrid.label(forTick: part.startTick + length))"
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

    /// Trim start moves the media offset with the cut, so the tempo is the one the part's media
    /// really elapses at — the same answer Split uses (`PartSplit.mediaBPM`, #416).
    private func trimStart(_ regionID: UUID, to tick: Int) {
        guard let region = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),
                                           projectBPM: player.preflightTempo) else {
            log.log(.info, category: .audio, "Trim start refused: no usable song tempo")
            return
        }
        timeline.trimRegionStart(id: regionID, toTick: tick, bpm: bpm)
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

/// M10 — Play the song from the selected part's bar, or Stop it. A leaf, so the only view that
/// rebuilds when the transport starts or stops is this one button.
///
/// ⚠️ It never calls `player.play(`: `playFrom` is the Workstation's `startTimeline`, which the
/// player floors to the part's bar (`barStartTick`). A part that starts off the grid plays from
/// the bar it starts in. And it asks `songCanStart` rather than `canPlay` — the Workstation is
/// the one control that may ask the engine (`TheWorkstationPlaysTheTimelineTests`), and the
/// answer is the same one its own Play is dimmed by: a button that is lit here does something.
/// ⚠️ While the song plays it is Stop, the player's own stop — never a second start: a restart
/// while the shared pattern runs lands the roll mid-bar (M7 review, LOW-3).
@MainActor
private struct PartPlayButton: View {
    let startTick: Int
    let playFrom: (Int) -> Void
    let songCanStart: () -> Bool
    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        let playing = player.isPlaying
        let startable = playing || songCanStart()
        Button {
            if playing { player.stop() } else { playFrom(startTick) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: playing ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(playing ? "Stop" : "Play from here")
                    .font(EchoelTheme.font(11, .semibold)).lineLimit(1)
            }
            .foregroundStyle(playing ? EchoelTheme.onPrimary
                                     : (startable ? EchoelTheme.text : EchoelTheme.dim))
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(playing ? EchoelTheme.accent : EchoelTheme.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!startable)
        .accessibilityLabel(playing ? "Stop timeline" : "Play the song from the selected part")
    }
}

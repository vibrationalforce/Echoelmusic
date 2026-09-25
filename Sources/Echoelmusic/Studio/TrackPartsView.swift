//
//  TrackPartsView.swift
//  Echoelmusic — Studio (WA4.3: arrange the selected track's parts — move, copy, remove)
//
//  WHY THIS EXISTS. The WA4 journey step ARRANGE. `TimelineStore` has carried the whole
//  arrangement API since the arrange surface was cut (#121): `moveRegion`, `duplicateRegion`,
//  `removeRegion`, and a region-only undo history — with ZERO production callers for the
//  edits and for `undo`/`redo`. The only reachable writes to that history were imports and
//  the composer's own part. So the Workstation could list and play a song but not arrange it.
//  This is the door, opened under the selected track's inspector (one door, no new modal).
//
//  ⭐ NO NEW TRUTH. Every write is the store's existing method, one call = one undo step
//  (`snapshotForUndo` runs inside each). The playing engine chases a structural edit live
//  (`TimelineRegionPlayer.refreshStructure`), so a part moved while the song plays is heard
//  where it now sits — no stop, no second path.
//
//  ⚠️ WHAT UNDO COVERS, stated rather than implied: the store's history holds REGION arrays
//  only (by design — a fader move or rename made after a part edit must never be silently
//  reverted). So Undo reverts the last change to the song's PARTS — including an import and
//  the part the composer adds when the instrument starts — and never a mixer change. The
//  hint says so.
//
//  ⚠️ MOVING STEPS BY ONE BAR and does not resolve overlaps: two overlapping parts are
//  resolved at play time by `TimelineScheduling.activeRegion` (the later start wins), the one
//  definition of precedence (#1440). Nothing here trims a neighbour.
//
//  Cold reads only: `timeline.document` changes on an edit; `canUndo`/`canRedo` flip on an
//  edit. No playhead, no meter, no bio.
//

import SwiftUI

/// The pure half: the parts on one track, how they are named, and where a one-bar move lands.
enum TrackParts {

    /// A move steps by one bar — the unit the arrangement, the loop point and launches use.
    static let stepTicks = TimelineTime.ticksPerBar

    struct Part: Identifiable, Equatable, Sendable {
        let id: UUID
        let startTick: Int
        let lengthTicks: Int
    }

    /// The track's parts in song order (start tick, then placement order — the order
    /// `activeRegion` breaks ties in).
    nonisolated static func parts(onLane laneID: UUID, in document: TimelineDocument) -> [Part] {
        document.regions.enumerated()
            .filter { $0.element.laneID == laneID }
            .sorted { ($0.element.startTick, $0.offset) < ($1.element.startTick, $1.offset) }
            .map { Part(id: $0.element.id, startTick: $0.element.startTick,
                        lengthTicks: $0.element.lengthTicks) }
    }

    /// Which tracks have parts to arrange: MIDI and audio lanes that are not bio. A bio lane
    /// carries a recorded curve, and video/visual lanes play nothing on the timeline.
    nonisolated static func arrangeable(_ laneID: UUID, in document: TimelineDocument) -> Bool {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return false }
        return !lane.isBio && (lane.kind == .midi || lane.kind == .audio)
    }

    /// Where "one bar earlier" lands, or nil when the part already starts at the song's top.
    nonisolated static func earlierStart(_ part: Part) -> Int? {
        guard part.startTick > 0 else { return nil }
        return Swift.max(0, part.startTick - stepTicks)
    }

    nonisolated static func laterStart(_ part: Part) -> Int {
        part.startTick + stepTicks
    }

    /// "Bar 5 · 4 bars" — the start as `SessionGrid.label` names it (one label rule, #416)
    /// and the length in the largest whole unit that fits.
    nonisolated static func title(_ part: Part) -> String {
        "\(SessionGrid.label(forTick: part.startTick)) · \(lengthText(part.lengthTicks))"
    }

    nonisolated static func lengthText(_ ticks: Int) -> String {
        let bar = TimelineTime.ticksPerBar
        let beat = TimelineTime.ticksPerBeat
        if ticks > 0, ticks % bar == 0 {
            let n = ticks / bar
            return n == 1 ? "1 bar" : "\(n) bars"
        }
        if ticks > 0, ticks % beat == 0 {
            let n = ticks / beat
            return n == 1 ? "1 beat" : "\(n) beats"
        }
        return String(format: "%.2f bars", Double(ticks) / Double(bar))
    }

    // MARK: Writes — through the store's existing API, one call = one undo step

    @MainActor
    static func move(_ part: Part, toStartTick tick: Int, timeline: TimelineStore) {
        timeline.moveRegion(id: part.id, toStartTick: tick)
    }

    @MainActor
    static func duplicate(_ part: Part, timeline: TimelineStore) {
        timeline.duplicateRegion(id: part.id)
    }

    @MainActor
    static func remove(_ part: Part, timeline: TimelineStore) {
        timeline.removeRegion(id: part.id)
    }
}

/// The selected track's parts, with move / copy / remove (Undo/Redo: `SongHistoryRow`).
@MainActor
struct TrackPartsView: View {

    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    var body: some View {
        let document = timeline.document
        if TrackParts.arrangeable(laneID, in: document) {
            let parts = TrackParts.parts(onLane: laneID, in: document)
            VStack(alignment: .leading, spacing: 6) {
                Text("Parts")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                if parts.isEmpty {
                    Text("No parts on this track yet. Import a file, or start the instrument on the Echoel track.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(parts) { part in
                    partRow(part)
                }
                // Undo/Redo MOVED to `SongHistoryRow`, the one history control under the
                // Arrange canvas (WA4 path 7) — Undo must stay visible after the part it
                // would restore is gone, and this list shows only while a track is open.
            }
        }
    }

    private func partRow(_ part: TrackParts.Part) -> some View {
        let title = TrackParts.title(part)
        let earlier = TrackParts.earlierStart(part)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
            HStack(spacing: 6) {
                actionButton("Earlier", systemImage: "chevron.left", enabled: earlier != nil,
                             label: "Move part at \(title) one bar earlier") {
                    if let tick = earlier {
                        TrackParts.move(part, toStartTick: tick, timeline: timeline)
                    }
                }
                actionButton("Later", systemImage: "chevron.right", enabled: true,
                             label: "Move part at \(title) one bar later") {
                    TrackParts.move(part, toStartTick: TrackParts.laterStart(part), timeline: timeline)
                }
                actionButton("Copy", systemImage: "plus.square.on.square", enabled: true,
                             label: "Copy part at \(title) to right after it") {
                    TrackParts.duplicate(part, timeline: timeline)
                }
                actionButton("Remove", systemImage: "trash", enabled: true,
                             label: "Remove part at \(title). Undo brings it back") {
                    TrackParts.remove(part, timeline: timeline)
                }
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
    }

    private func actionButton(_ title: String, systemImage: String, enabled: Bool, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(EchoelTheme.font(11, .semibold)).lineLimit(1)
            }
            .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

//
//  TrackPartsView.swift
//  Echoelmusic — Studio (WA4.3: arrange the selected track's parts — move, copy, remove;
//  WA4 path 8: the list SELECTS, and the one part editor is `SelectedPartBar`)
//
//  WHY THIS EXISTS. The WA4 journey step ARRANGE. `TimelineStore` has carried the whole
//  arrangement API since the arrange surface was cut (#121): `moveRegion`, `duplicateRegion`,
//  `removeRegion`, and a region-only undo history — with ZERO production callers for the
//  edits and for `undo`/`redo`. The only reachable writes to that history were imports and
//  the composer's own part. So the Workstation could list and play a song but not arrange it.
//  This file gave those edits their first door, under the selected track's inspector.
//  ⚠️ SINCE WA4 PATH 8 THE ROWS ONLY SELECT: the Arrange canvas's part bar
//  (`SelectedPartBar`) makes the same edits through the same `TrackParts` calls, and two sets
//  of buttons for one part was a second door. `TrackParts` (the pure half and the three store
//  writes below) stays here and is what the part bar calls.
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
//  Cold reads only: `timeline.document` changes on an edit, the selection on a tap. No
//  playhead, no meter, no bio.
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

/// The selected track's parts, as a list that SELECTS. The actions on a selected part live in
/// ONE place — `SelectedPartBar`, under the Arrange canvas (WA4 path 8, one inspector); the
/// history in `SongHistoryRow`.
@MainActor
struct TrackPartsView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    let laneID: UUID

    var body: some View {
        let document = timeline.document
        if TrackParts.arrangeable(laneID, in: document) {
            let parts = TrackParts.parts(onLane: laneID, in: document)
            let selected = WorkstationSelection.resolvedRegion(selection.regionID,
                                                               track: selection.trackID, in: document)
            VStack(alignment: .leading, spacing: 6) {
                Text("Parts")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                if parts.isEmpty {
                    Text("No parts on this track yet. Import a file, or start the instrument on the Echoel track.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(parts) { part in
                    partRow(part, isSelected: part.id == selected, document: document)
                }
                // Review of 6bf183726 (MEDIUM): with several tracks the part bar can be scrolled
                // out of view when a part is picked here, and the accent border alone does not
                // say where its actions went. Said in words, to everyone, not only to VoiceOver.
                if let selected, parts.contains(where: { $0.id == selected }) {
                    Text("Its actions — move, trim, split, copy, remove — are under the arrangement above.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // WA4 path 8 — the per-part Earlier/Later/Copy/Remove buttons that stood here
                // were a SECOND door to the same edits `SelectedPartBar` makes. A row now
                // selects its part; the one part editor acts on the one selection.
            }
        }
    }

    private func partRow(_ part: TrackParts.Part, isSelected: Bool,
                         document: TimelineDocument) -> some View {
        let title = TrackParts.title(part)
        return Button {
            selection.selectRegion(part.id, in: document)
        } label: {
            Text(title)
                .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 8)
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(isSelected ? EchoelTheme.accent : EchoelTheme.border,
                                  lineWidth: isSelected ? 2 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Part at \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this part. Its actions are under the arrangement above")
    }
}

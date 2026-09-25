//
//  ArrangeCanvasView.swift
//  Echoelmusic — Studio (WA4 critical path 4: the Arrange canvas)
//
//  WHY THIS EXISTS. Until now the song was drawn as one thin, read-only strip under each track
//  row (WA4.5), and a part could only be reached through its track's inspector list. The
//  canvas is the arrangement itself: every track that holds parts, one row each, on ONE shared
//  scale, and a part is selected by tapping it. Selecting a part selects its track too
//  (`WorkstationSelection`), so the inspector below opens on the track that owns it.
//
//  ⚠️ ONE GEOMETRY RULE. Block positions come from `ArrangementStrip.blocks` — the pure half
//  WA4.5 already pinned — and draw order is `TrackParts.parts` order, so a later-starting part
//  sits ON TOP of the one it overlaps, which is exactly who `TimelineScheduling.activeRegion`
//  lets play (#1440). The part you tap on top is the part you hear.
//
//  ⚠️ THE CANVAS IS COLD; THE PLAYHEAD IS ITS OWN LEAF. The canvas re-renders only when the
//  document or the selection changes (both on a tap). The position is `@ObservationIgnored`
//  ~8 Hz state; `ArrangePlayheadView` self-drives with `TimelineView(.animation)` at 15 Hz,
//  paused while the timeline is stopped, and is the ONLY reader of `currentTick` here. A body
//  read of the position in this canvas or in the Workstation would make every ancestor a hot
//  reader and tear down an open `.menu` Picker (10.76.41/50).
//
//  Selection only. Moving, trimming and splitting are separate slices through the existing
//  `TimelineStore` methods.
//

import SwiftUI

/// The pure half of the canvas: which tracks it draws and where the playhead sits.
enum ArrangeCanvas {

    /// The tracks the canvas draws, in the document's order: every non-bio track with parts.
    /// A bio curve is not an arrangement and draws no row.
    nonisolated static func rows(_ summary: WorkstationSummary) -> [WorkstationSummary.LaneRow] {
        summary.lanes.filter { !$0.isBio && $0.regionCount > 0 }
    }

    /// Where the playhead sits on the song's scale, 0…1, or nil when there is no scale. A
    /// position past the end (a loop running on) pins to the end instead of leaving the canvas.
    nonisolated static func playheadFraction(tick: Int, songTicks: Int) -> Double? {
        guard songTicks > 0 else { return nil }
        return (Double(tick) / Double(songTicks)).clamped(to: 0...1)
    }
}

/// Every track's parts on one scale, each part tappable to select it.
struct ArrangeCanvasView: View {

    @Environment(WorkstationSelection.self) private var selection

    let rows: [WorkstationSummary.LaneRow]
    let document: TimelineDocument
    let songTicks: Int

    /// Tall enough to hit with a finger; the rows carry no text inside the lane itself.
    private static let rowHeight: CGFloat = 28
    private static let nameWidth: CGFloat = 76
    private static let gutter: CGFloat = 8

    var body: some View {
        let selected = WorkstationSelection.resolvedRegion(selection.regionID,
                                                           track: selection.trackID, in: document)
        VStack(spacing: 4) {
            ForEach(rows) { row in
                HStack(spacing: Self.gutter) {
                    // A name gutter: one line, truncating, so every lane starts at the same x
                    // and the rows line up bar for bar. Only the NAME grows with the type size;
                    // the gutter width and the lane's 28 pt height are fixed (review LOW-3) —
                    // the parts list in the track inspector is the large-type way in.
                    Text(row.name)
                        .font(EchoelTheme.font(12))
                        .foregroundStyle(EchoelTheme.dim)
                        .lineLimit(1)
                        .frame(width: Self.nameWidth, alignment: .leading)
                        .accessibilityHidden(true)
                    laneRow(row, selected: selected)
                }
                .frame(minHeight: Self.rowHeight)
            }
        }
        .overlay(alignment: .leading) {
            ArrangePlayheadView(songTicks: songTicks)
                .padding(.leading, Self.nameWidth + Self.gutter)
        }
    }

    private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {
        let blocks = ArrangementStrip.blocks(onLane: row.id, in: document, songTicks: songTicks)
        let starts = Dictionary(TrackParts.parts(onLane: row.id, in: document)
            .map { ($0.id, $0.startTick) }, uniquingKeysWith: { first, _ in first })
        return GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill)
                ForEach(blocks) { block in
                    let isSelected = block.id == selected
                    RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.dim)
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .strokeBorder(isSelected ? EchoelTheme.accent : EchoelTheme.border,
                                          lineWidth: isSelected ? 2 : 1))
                        .frame(width: Swift.max(2, width * block.width))
                        .offset(x: width * block.start)
                        .contentShape(Rectangle())
                        .onTapGesture { selection.selectRegion(block.id, in: document) }
                        .accessibilityElement()
                        .accessibilityLabel("\(row.name), part at "
                            + SessionGrid.label(forTick: starts[block.id] ?? 0))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityAction { selection.selectRegion(block.id, in: document) }
                }
            }
        }
        .frame(height: Self.rowHeight)
        // The row speaks as a group — the track and where its parts start (the one label
        // rule, `ArrangementStrip.spoken`) — and each part inside it is its own button.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(row.name): " + ArrangementStrip.spoken(onLane: row.id, in: document))
    }
}

/// The song position over the canvas. The ONLY reader of `currentTick` on this surface: it
/// self-drives at 15 Hz while the timeline plays and is paused (and absent) while it is
/// stopped, so nothing above it ever observes the position.
struct ArrangePlayheadView: View {

    @Environment(TimelineRegionPlayer.self) private var player

    let songTicks: Int

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            GeometryReader { geometry in
                if playing,
                   let fraction = ArrangeCanvas.playheadFraction(tick: player.currentTick,
                                                                 songTicks: songTicks) {
                    Rectangle()
                        .fill(EchoelTheme.accent)
                        .frame(width: 1)
                        .offset(x: geometry.size.width * fraction)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

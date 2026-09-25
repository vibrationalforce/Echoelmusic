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
//  ⭐ DRAG-TO-MOVE (WA4 path D). Press and hold a part, then slide it: it follows the finger in
//  whole bars and lands where its preview sits. The preview is GESTURE-LOCAL — `@GestureState`
//  in `ArrangePartBlock`, so only the dragged block redraws at finger rate and a drag the
//  surrounding scroll view cancels springs back by itself — and the release is ONE bounded
//  commit through `TrackParts.move`, the same store call as the part bar's Earlier/Later, i.e.
//  one undo step. Preview and commit both come from `ArrangeCanvas.dropTick`, so what you see
//  is where it lands.
//  History (classified, not restored): the cut `ArrangeTimelineView` (eb58e7a^) dragged a clip
//  BODY with a `@GestureState` delta and previewed the snapped drop — INTERACTION IDEA PORTED.
//  Its tick conversion (`TimelineDragMath.tickDelta`, still shipped) — ALGORITHM PORTED. Its
//  zoom, snap menu, neighbour magnet, lane change and overlap trimming — NOT RESTORED: the
//  canvas has one fixed scale, the part bar's one-bar step is the grid, precedence stays with
//  `TimelineScheduling.activeRegion` (#1440), and rows here are only the tracks with parts, so a
//  vertical drop has no honest target yet. The long press is new, and deliberate: the canvas
//  sits inside the Workstation's vertical scroll, and a bare drag on a part would steal it.
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

    /// Where a part dragged `dragPoints` across a lane `laneWidth` wide lands: its start moved by
    /// WHOLE BARS — the part bar's step, so an off-grid part keeps its offset and a small wobble
    /// is no move — never before the song's top. Degenerate geometry is no move.
    nonisolated static func dropTick(startTick: Int, dragPoints: CGFloat, laneWidth: CGFloat,
                                     songTicks: Int) -> Int {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return startTick }
        let pointsPerBeat = laneWidth * CGFloat(TimelineTime.ticksPerBeat) / CGFloat(songTicks)
        let ticks = TimelineDragMath.tickDelta(fromPoints: dragPoints, ppb: pointsPerBeat)
        let bars = Int((Double(ticks) / Double(TimelineTime.ticksPerBar)).rounded())
        return Swift.max(0, startTick + bars * TimelineTime.ticksPerBar)
    }

    /// How far, in points, a part drawn at `startTick` is shown shifted when it will land at
    /// `tick` — the preview of `dropTick`, on the same scale the blocks are placed on.
    nonisolated static func offsetPoints(from startTick: Int, to tick: Int, laneWidth: CGFloat,
                                         songTicks: Int) -> CGFloat {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return 0 }
        return CGFloat(tick - startTick) / CGFloat(songTicks) * laneWidth
    }
}

/// Every track's parts on one scale, each part tappable to select it.
struct ArrangeCanvasView: View {

    @Environment(WorkstationSelection.self) private var selection
    /// Only for the drop's ONE commit (`TrackParts.move`); the canvas reads the song from the
    /// `document` it is handed, never from the store.
    @Environment(TimelineStore.self) private var timeline

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
                    let start = starts[block.id] ?? 0
                    ArrangePartBlock(block: block, startTick: start,
                                     isSelected: block.id == selected,
                                     laneWidth: width, songTicks: songTicks,
                                     label: "\(row.name), part at " + SessionGrid.label(forTick: start),
                                     onSelect: { selection.selectRegion(block.id, in: document) },
                                     onDrop: { tick in drop(block.id, onLane: row.id, from: start, to: tick) })
                }
            }
        }
        .frame(height: Self.rowHeight)
        // The row speaks as a group — the track and where its parts start (the one label
        // rule, `ArrangementStrip.spoken`) — and each part inside it is its own button.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(row.name): " + ArrangementStrip.spoken(onLane: row.id, in: document))
    }

    /// The release of a drag: select the part, then ONE store edit — or nothing, when it lands
    /// where it started (no empty undo step).
    private func drop(_ regionID: UUID, onLane laneID: UUID, from startTick: Int, to tick: Int) {
        selection.selectRegion(regionID, in: document)
        guard tick != startTick,
              let part = TrackParts.parts(onLane: laneID, in: document)
                .first(where: { $0.id == regionID }) else { return }
        TrackParts.move(part, toStartTick: tick, timeline: timeline)
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

/// One part on a lane: tap to select it; press, hold and slide to move it by whole bars.
///
/// ⭐ THE ONLY FINGER-RATE STATE ON THE CANVAS. `dragPoints` is `@GestureState`, so it lives
/// in this leaf alone (only this block redraws while it moves) and resets itself when the
/// scroll view cancels the gesture — a plain `@State` delta stuck there and left the part
/// drawn away from where it sits (the cut arrange view's #56 C2). Nothing is written until the
/// finger lifts, and then exactly once, through `onDrop`.
struct ArrangePartBlock: View {

    let block: ArrangementStrip.Block
    let startTick: Int
    let isSelected: Bool
    let laneWidth: CGFloat
    let songTicks: Int
    let label: String
    let onSelect: () -> Void
    let onDrop: (Int) -> Void

    @GestureState private var dragPoints: CGFloat = 0

    var body: some View {
        let landing = ArrangeCanvas.dropTick(startTick: startTick, dragPoints: dragPoints,
                                             laneWidth: laneWidth, songTicks: songTicks)
        let shift = ArrangeCanvas.offsetPoints(from: startTick, to: landing,
                                               laneWidth: laneWidth, songTicks: songTicks)
        let moving = dragPoints != 0
        RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
            .fill(EchoelTheme.dim)
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(isSelected || moving ? EchoelTheme.accent : EchoelTheme.border,
                              lineWidth: isSelected || moving ? 2 : 1))
            .opacity(moving ? 0.8 : 1)
            .frame(width: Swift.max(2, laneWidth * block.width))
            .offset(x: laneWidth * block.start + shift)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .gesture(move)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction { onSelect() }
    }

    /// Hold first, then slide — so a swipe that starts on a part still scrolls the Workstation.
    private var move: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragPoints) { value, state, _ in
                if case .second(true, let drag?) = value { state = drag.translation.width }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                onDrop(ArrangeCanvas.dropTick(startTick: startTick,
                                              dragPoints: drag.translation.width,
                                              laneWidth: laneWidth, songTicks: songTicks))
            }
    }
}

//
//  ArrangeCycleHandles.swift
//  Echoelmusic — Studio (A2: drag the cycle's edges)
//
//  WHY THIS EXISTS. The Cycle button turns a cycle on — the selected part's bars, or four bars
//  from where Play starts — but its range could not be changed afterwards, while Live's loop brace
//  and Logic's cycle are dragged by their edges (founder 2026-10-16, "Arrangement auf Ableton-
//  Level", gap list item 2). While a cycle plays, its band on the ruler now carries a grip at each
//  edge; dragging one moves that edge to the nearest bar line, and lifting the finger writes the
//  new range in ONE `TimelineStore.setCycle` call — one `.cycle` Undo step, the Cycle button's own.
//
//  ⚠️ ITS OWN VIEW, because the ruler row's law forbids a drag and gesture state in the row itself
//  (`TheRulerAuditionsOnlyWhileStoppedTests` claim 4, `ThePlayStartsWhereTheRulerSaysTests`). The
//  row only mounts this; the grips hold the drag, the row keeps its one tap and its scrub.
//
//  ⚠️ PREVIEW, THEN ONE WRITE. During the drag the new range is drawn as an outline over the band
//  (local `@State`); the store is written once, on lift. A write per drag frame would be dozens of
//  Undo steps and a structure refresh of the playing song per frame.
//
//  ⚠️ COLD: it reads the piece handed in, never `currentTick`.
//
//  ⛔ LOCKED WHEN THE ROW IS (a take records, a bounce or capture runs) — the Cycle button's reason.
//
//  ⚠️ GESTURE ONLY, stated rather than hidden: the ruler row is ONE VoiceOver element (children
//  ignored), so the grips are not separate VoiceOver controls. VoiceOver sets a cycle through the
//  Cycle button (a part's bars), which is unchanged.
//
//  NEEDS-FOUNDER-VERIFY (A2): turn Cycle on, drag the band's right grip two bars right → the
//  outline follows the finger bar by bar; lift → the band covers the new bars and Play loops them.
//  Undo → the old range. A plain tap on a grip still sets Play to that bar.
//

import SwiftUI

/// The pure half: which range a drag of one cycle edge names.
enum CycleDrag {

    enum Edge: Equatable, Sendable { case start, end }

    /// The bar line nearest `x` on a lane `laneWidth` wide whose scale is `songTicks` — rounded,
    /// not floored, so an edge snaps to the line the finger is closest to. nil for degenerate
    /// geometry. Pure.
    nonisolated static func barLine(atX x: CGFloat, laneWidth: CGFloat, songTicks: Int) -> Int? {
        let bar = TimelineTime.ticksPerBar
        guard bar > 0, songTicks >= bar, x.isFinite, laneWidth.isFinite, laneWidth > 0 else { return nil }
        let fraction = Double(x / laneWidth).clamped(to: 0...1)
        let bars = Int((fraction * Double(songTicks) / Double(bar)).rounded())
        return Swift.min(bars, songTicks / bar) * bar
    }

    /// The cycle after dragging `edge` of `window` to `tick`: that edge on `tick`, never closer than
    /// one bar to the other edge, inside the piece, stored as the window it plays
    /// (`TimelineCycle.window`). nil = no cycle can stand there (it would cover the whole piece,
    /// which already loops, or the piece is too short). Pure.
    nonisolated static func dragged(_ window: Range<Int>, edge: Edge, toTick tick: Int,
                                    loopTicks: Int) -> TimelineCycle? {
        let bar = TimelineTime.ticksPerBar
        guard loopTicks > bar else { return nil }
        let start: Int, end: Int
        switch edge {
        case .start:
            start = Swift.max(0, Swift.min(tick, window.upperBound - bar))
            end = window.upperBound
        case .end:
            start = window.lowerBound
            end = Swift.min(loopTicks, Swift.max(tick, window.lowerBound + bar))
        }
        guard let played = TimelineCycle(startTick: start, endTick: end).window(loopTicks: loopTicks) else { return nil }
        return TimelineCycle(startTick: played.lowerBound, endTick: played.upperBound)
    }
}

/// The two grips on the cycle's band; mounted by the ruler row, over the band it draws.
struct ArrangeCycleHandles: View {
    @Environment(TimelineStore.self) private var timeline

    let document: TimelineDocument
    let songTicks: Int
    let laneWidth: CGFloat
    let height: CGFloat
    let locked: Bool

    /// The range under the finger while a grip is dragged; nil otherwise. Never persisted.
    @State private var preview: TimelineCycle?

    /// The hit width of a grip — the tap floor, centred on the edge.
    private static let gripTarget: CGFloat = 44

    var body: some View {
        let loopTicks = TimelineRegionPlayer.loopTicks(for: document)
        if !locked, let committed = document.cycle?.window(loopTicks: loopTicks),
           let band = RulerLocate.cycleBand(document.cycle, loopTicks: loopTicks, songTicks: songTicks) {
            ZStack(alignment: .topLeading) {
                if let shown = preview,
                   let outline = RulerLocate.cycleBand(shown, loopTicks: loopTicks, songTicks: songTicks) {
                    Rectangle()
                        .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1)
                        .frame(width: laneWidth * outline.width, height: height)
                        .offset(x: laneWidth * outline.start)
                        .allowsHitTesting(false)
                }
                grip(.start, at: laneWidth * band.start, committed: committed, loopTicks: loopTicks)
                grip(.end, at: laneWidth * (band.start + band.width), committed: committed, loopTicks: loopTicks)
            }
            .frame(width: laneWidth, height: height, alignment: .topLeading)
            .accessibilityHidden(true)
        }
    }

    private func grip(_ edge: CycleDrag.Edge, at x: CGFloat, committed: Range<Int>,
                      loopTicks: Int) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(EchoelTheme.text)
            .frame(width: 3, height: height)
            .frame(width: Self.gripTarget, height: height)
            .contentShape(Rectangle())
            .offset(x: x - Self.gripTarget / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard let tick = CycleDrag.barLine(atX: x + value.translation.width,
                                                           laneWidth: laneWidth, songTicks: songTicks) else { return }
                        preview = CycleDrag.dragged(committed, edge: edge, toTick: tick, loopTicks: loopTicks)
                    }
                    .onEnded { _ in
                        // ONE write, on lift — one `.cycle` Undo step; an unchanged range writes nothing.
                        if let next = preview { timeline.setCycle(next) }
                        preview = nil
                    }
            )
    }
}

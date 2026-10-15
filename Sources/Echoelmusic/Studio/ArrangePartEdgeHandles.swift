//
//  ArrangePartEdgeHandles.swift
//  Echoelmusic — One World T1 (founder 2026-10-15: "Midi trim fehlt").
//
//  The selected part's two edges on the Arrange canvas. Hold, then slide: the edge follows the
//  finger on the canvas grid, a line shows where it will land, and releasing writes ONCE —
//  `trimRegionStart` for the start, `resizeRegion` for the end, each one Undo step. MIDI and audio
//  parts alike, inward and outward:
//  · a MIDI part's END moves out over silence — notes an earlier trim hid come back, then nothing
//    plays; it never loops. Its START moves by whole bars and never before its content's start
//    (clip tick 0 — `ArrangeCanvas.edgeUnit`, `TimelineRegion.trimmedStart`).
//  · an audio part's end stays inside its file as measured at import; a file whose length the
//    canvas does not know is not lengthened here (the track's Part page can, once it has read it).
//    ⚠️ The canvas measures from the part's END, not from the drawn end of its file as the audio
//    editor does, so a part whose bar-rounded end already runs past its file shows the refused line
//    on an outward slide — the rule holds, the editor is where that part can reach its file's end.
//  The question both the preview and the release ask is `ArrangeCanvas.edgeEdit`, whose rule is
//  `PartTrim.edgeEdit` — the audio editor's own (#416).
//
//  ⭐ THE FINGER-RATE STATE LIVES HERE, not in the canvas. `drag` is `@GestureState`; only this
//  leaf redraws while the finger moves. Nothing here reads the song position, and the tempo is
//  read from the player's cold `preflightTempo` through the computed `mediaBPM`, once for the
//  preview and once at release.
//
//  ⭐ THE PART'S BODY AND ITS NEIGHBOURS STAY FREE. On a part at least two targets wide each handle
//  is centred on its edge; on a narrower part both handles sit OUTSIDE it (`ArrangePartEdges.frames`),
//  so the hold-and-slide that moves the part still reaches it. No handle reaches past the nearest
//  neighbouring part or the lane's end (`ArrangePartEdges.room`) — a side without half a target of
//  room has no handle, and the part bar's Trim buttons still move it.
//  ⚠️ Known and accepted: while the part itself is being moved, its handles stay at the old edges
//  (they read the stored part, not the block's live offset); and the slide gives no haptic tick.
//
//  Hidden from VoiceOver like the audio editor's handles; the part bar's Trim buttons move an edge
//  inward by one step on the same rules. ⚠️ Lengthening a part has no VoiceOver path yet — an open
//  accessibility gap, not a covered one.
//  NEEDS-FOUNDER-VERIFY: on Arrange, select a MIDI part, hold its right edge and slide right — the
//  line follows, release lengthens it once (one Undo); slide its left edge — it moves by bars; the
//  hold wins over the canvas scroll and the part can still be moved by its middle.
//

import SwiftUI

/// The pure half of the canvas's edge handles: where their touch areas sit.
enum ArrangePartEdges {

    /// The two handles' touch areas, as x ranges, for a part drawn from `startX` to `endX` with free
    /// room from `leftLimit` to `rightLimit` — the lane's ends, or the nearest neighbouring parts'
    /// edges. A part at least two targets (`AudioPartEditor.handleHitPoints`) wide gets them centred
    /// on its edges; a narrower part gets them OUTSIDE its edges, so its body stays free for the
    /// move. Neither reaches past its limit, so a neighbour stays tappable and movable; a side left
    /// narrower than half a target is nil. nil for unusable input or when neither side has room.
    nonisolated static func frames(startX: Double, endX: Double, leftLimit: Double,
                                   rightLimit: Double) -> (start: ClosedRange<Double>?, end: ClosedRange<Double>?)? {
        let hit = AudioPartEditor.handleHitPoints
        guard startX.isFinite, endX.isFinite, leftLimit.isFinite, rightLimit.isFinite,
              leftLimit <= startX, startX <= endX, endX <= rightLimit else { return nil }
        let inside = endX - startX >= 2 * hit
        let start = Swift.max(startX - (inside ? hit / 2 : hit), leftLimit)...(inside ? startX + hit / 2 : startX)
        let end = (inside ? endX - hit / 2 : endX)...Swift.min(endX + (inside ? hit / 2 : hit), rightLimit)
        func usable(_ range: ClosedRange<Double>) -> ClosedRange<Double>? {
            range.upperBound - range.lowerBound >= hit / 2 ? range : nil
        }
        let pair = (start: usable(start), end: usable(end))
        return pair.start == nil && pair.end == nil ? nil : pair
    }

    /// The free room around `region` on its lane, in ticks: from the latest end of a part that ends
    /// at or before its start (0 when none), to the earliest start of a part that starts at or after
    /// its end (nil when none — the song's end).
    nonisolated static func room(for region: TimelineRegion,
                                 in document: TimelineDocument) -> (left: Int, right: Int?) {
        var left = 0
        var right: Int?
        for other in document.regions where other.laneID == region.laneID && other.id != region.id {
            if other.endTick <= region.startTick { left = Swift.max(left, other.endTick) }
            if other.startTick >= region.endTick { right = Swift.min(right ?? other.startTick, other.startTick) }
        }
        return (left, right)
    }
}

/// The selected part's two edge handles on one canvas lane.
struct ArrangePartEdgeHandles: View {

    @Environment(TimelineStore.self) private var timeline
    /// Read for `preflightTempo` only — `@ObservationIgnored`, so nothing here observes it.
    @Environment(TimelineRegionPlayer.self) private var player

    let region: TimelineRegion
    let document: TimelineDocument
    /// The part's clip, handed in by the canvas (which already reads the clip grid once per lane).
    let clip: Clip?
    let laneWidth: CGFloat
    let songTicks: Int
    let height: CGFloat

    @GestureState private var drag: AudioPartEditor.EdgeDrag? = nil

    /// The tempo the part's content elapses at NOW (the AE-4b M2 rule): `preflightTempo` follows
    /// the pulse in Flow without redrawing anything, so a tempo carried from the last draw can be
    /// minutes old when the finger lets go.
    private var mediaBPM: Double? {
        PartSplit.mediaBPM(for: region, clip: clip, projectBPM: player.preflightTempo)
    }

    var body: some View {
        let startX = x(of: region.startTick)
        let endX = x(of: region.endTick)
        let room = ArrangePartEdges.room(for: region, in: document)
        let rightLimit = room.right.map { Swift.min(x(of: $0), Double(laneWidth)) } ?? Double(laneWidth)
        if let frames = ArrangePartEdges.frames(startX: startX, endX: endX, leftLimit: x(of: room.left),
                                                rightLimit: rightLimit) {
            ZStack(alignment: .topLeading) {
                if let start = frames.start { handle(.start, frame: start, edgeX: startX) }
                if let end = frames.end { handle(.end, frame: end, edgeX: endX) }
                if let drag {
                    preview(drag, edgeX: drag.edge == .start ? startX : endX)
                }
            }
            .frame(width: laneWidth, height: height, alignment: .topLeading)
            .accessibilityHidden(true)
        }
    }

    /// Where a tick sits on this lane, in points from its left edge.
    private func x(of tick: Int) -> Double {
        guard songTicks > 0 else { return 0 }
        return Double(tick) / Double(songTicks) * Double(laneWidth)
    }

    /// One handle: a full target wide and as tall as the lane, with a short grip on the edge
    /// itself so the person can see there is something to hold.
    private func handle(_ edge: AudioPartEditor.Edge, frame: ClosedRange<Double>, edgeX: Double) -> some View {
        let hit = CGFloat(frame.upperBound - frame.lowerBound)
        let gripX = CGFloat(edgeX - frame.lowerBound).clamped(to: 0...hit) - Self.gripWidth / 2
        return ZStack(alignment: .leading) {
            Color.clear
            RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.borderStrong)
                .frame(width: Self.gripWidth, height: Swift.min(Self.gripHeight, height))
                .offset(x: gripX)
        }
        .frame(width: hit, height: height)
        .contentShape(Rectangle())
        .offset(x: CGFloat(frame.lowerBound))
        .gesture(slide(edge))
    }

    /// Where the edge will land — or, when the rules refuse, where the finger is.
    @ViewBuilder
    private func preview(_ drag: AudioPartEditor.EdgeDrag, edgeX: Double) -> some View {
        if let bpm = mediaBPM,
           let landing = edit(drag.edge, points: drag.points, bpm: bpm),
           let landingX = ArrangeCanvas.edgeX(landing, region: region, laneWidth: laneWidth, songTicks: songTicks) {
            Rectangle()
                .fill(EchoelTheme.accent)
                .frame(width: Self.landingWidth, height: height)
                .offset(x: landingX - Self.landingWidth / 2)
                .allowsHitTesting(false)
        } else {
            Rectangle()
                .fill(EchoelTheme.dim)
                .frame(width: Self.refusedWidth, height: height)
                .offset(x: CGFloat((edgeX + drag.points).clamped(to: 0...Double(laneWidth))))
                .allowsHitTesting(false)
        }
    }

    /// Hold first, then slide — the canvas's 0.3 s, so a swipe still scrolls the song. Nothing is
    /// written until release.
    private func slide(_ edge: AudioPartEditor.Edge) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($drag) { value, state, _ in
                if case .second(true, let slide?) = value {
                    state = AudioPartEditor.EdgeDrag(edge: edge, points: Double(slide.translation.width))
                }
            }
            .onEnded { value in
                // One tempo read for the question and the write, so they cannot disagree.
                guard case .second(true, let slide?) = value, let bpm = mediaBPM,
                      let change = edit(edge, points: Double(slide.translation.width), bpm: bpm)
                else { return }
                switch change {
                case .start(let tick):
                    timeline.trimRegionStart(id: region.id, toTick: tick, bpm: bpm)
                case .end(let lengthTicks):
                    timeline.resizeRegion(id: region.id, lengthTicks: lengthTicks)
                }
            }
    }

    /// The one question both the preview and the release ask.
    private func edit(_ edge: AudioPartEditor.Edge, points: Double, bpm: Double) -> AudioPartEditor.EdgeEdit? {
        ArrangeCanvas.edgeEdit(edge, dragPoints: CGFloat(points), laneWidth: laneWidth, songTicks: songTicks,
                               region: region, in: document, clip: clip, mediaBPM: bpm)
    }

    /// The grip drawn on each edge: thin and short, in the selection's accent.
    private static let gripWidth: CGFloat = 4
    private static let gripHeight: CGFloat = 24
    /// The landing line, one point wider than the playhead so the two read apart.
    private static let landingWidth: CGFloat = 2
    /// The refused slide's line: the finger's place, quiet.
    private static let refusedWidth: CGFloat = 1
}

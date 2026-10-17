import EchoelCore
import SwiftUI

/// The song on a bar timeline: one lane per track, its clips laid out where they play.
/// Tap empty space to place the track's clip at that bar, tap a clip to edit its notes, drag
/// a clip to move it by whole bars, hold for Duplicate and Delete. One drag is one undo step.
/// Reads no playhead, so nothing here rebuilds while the song plays.
struct ArrangeView: View {
    @Environment(ProjectStore.self) private var store
    /// Opens a track's editor.
    let open: (TrackID) -> Void

    @ScaledMetric(relativeTo: .body) private var nameWidth: CGFloat = 96
    /// Points per bar; the horizontal zoom.
    private let pointsPerBar: CGFloat = 88
    /// Empty bars drawn past the song's end, so there is always room to place the next clip.
    private static let spareBars = 8

    var body: some View {
        let project = store.project
        let bars = Arranging.songBars(of: project) + Self.spareBars
        let laneWidth = CGFloat(bars) * pointsPerBar
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 1) {
                    Text("\(Arranging.songBars(of: project)) bars")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(height: Theme.Size.rulerHeight)
                        .accessibilityLabel("Song length \(Arranging.songBars(of: project)) bars")
                    ForEach(project.tracks) { track in
                        Text(track.name)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Color.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, Theme.Space.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: Theme.Size.trackRowHeight)
                            .background(Theme.Color.surface)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: nameWidth)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 1) {
                        BarRuler(bars: bars, pointsPerBar: pointsPerBar)
                        ForEach(project.tracks) { track in
                            ArrangeLane(track: track, signature: project.timeSignature,
                                        pointsPerBar: pointsPerBar, open: open)
                                .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                        }
                    }
                }
            }
            if project.tracks.isEmpty {
                Text("Add a track on the Tracks page to start arranging.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
    }
}

/// Bar numbers along the top.
private struct BarRuler: View {
    let bars: Int
    let pointsPerBar: CGFloat

    var body: some View {
        Canvas { context, size in
            for bar in 0..<bars {
                let x = CGFloat(bar) * pointsPerBar
                context.fill(Path(CGRect(x: x, y: size.height - 6, width: 1, height: 6)),
                             with: .color(Theme.Color.border))
                context.draw(Text("\(bar + 1)").font(Theme.Font.caption).foregroundStyle(Theme.Color.textSecondary),
                             at: CGPoint(x: x + 4, y: size.height / 2), anchor: .leading)
            }
        }
        .frame(width: CGFloat(bars) * pointsPerBar, height: Theme.Size.rulerHeight)
        .background(Theme.Color.surface)
        .accessibilityHidden(true)
    }
}

/// One track's lane: bar lines, its placements, and taps on empty space.
private struct ArrangeLane: View {
    @Environment(ProjectStore.self) private var store
    let track: Track
    let signature: TimeSignature
    let pointsPerBar: CGFloat
    let open: (TrackID) -> Void

    private var ticksPerPoint: Double {
        Double(MusicalTime.ticksPerBar(signature)) / Double(pointsPerBar)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                                 with: .color(Theme.Color.border.opacity(0.6)))
                    x += pointsPerBar
                }
            }
            .background(Theme.Color.surface)
            .contentShape(Rectangle())
            .onTapGesture { location in tapEmpty(at: location.x) }
            .accessibilityElement()
            .accessibilityLabel("\(track.name) lane")
            .accessibilityHint(track.clips.isEmpty ? "Tap to create a clip." : "")
            .accessibilityAction(named: "Place Clip at End") { placeAtEnd() }

            ForEach(track.placements) { placement in
                if let clip = track.clips.first(where: { $0.id == placement.clip }) {
                    PlacementBlock(track: track, placement: placement, clip: clip, signature: signature,
                                   pointsPerBar: pointsPerBar, open: open)
                }
            }
        }
        .coordinateSpace(.named(ArrangeLane.space))
    }

    /// Drags are measured here, not in the moving block, so the offset never feeds back.
    static let space = "arrange.lane"

    private func tapEmpty(at x: CGFloat) {
        guard track.kind == .instrument else { return }
        let tick = Tick((Double(x) * ticksPerPoint).rounded(.down))
        if track.clips.isEmpty {
            createClip(at: Arranging.barStart(tick, signature: signature))
        } else if let command = Arranging.tap(on: track, at: tick, signature: signature) {
            try? store.perform(command)
        }
    }

    private func placeAtEnd() {
        let end = track.placements.compactMap { Arranging.end(of: $0, in: track) }.max() ?? 0
        let start = Arranging.barStart(end + MusicalTime.ticksPerBar(signature) - 1, signature: signature)
        if track.clips.isEmpty {
            createClip(at: start)
        } else if let command = Arranging.tap(on: track, at: start, signature: signature) {
            try? store.perform(command)
        }
    }

    /// A track's first clip: four empty bars, placed where the tap fell.
    private func createClip(at start: Tick) {
        guard track.kind == .instrument else { return }
        let clip = ClipID()
        try? store.perform([
            .createClip(track: track.id, id: clip, name: "\(track.name) Clip",
                        length: 4 * MusicalTime.ticksPerBar(signature)),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: start),
        ], title: "New Clip")
    }
}

/// A placed clip. The drag offset lives in view state while the finger is down and becomes
/// one move command when it lifts.
private struct PlacementBlock: View {
    @Environment(ProjectStore.self) private var store
    let track: Track
    let placement: Placement
    let clip: Clip
    let signature: TimeSignature
    let pointsPerBar: CGFloat
    let open: (TrackID) -> Void

    @State private var dragX: CGFloat = 0

    private var ticksPerBar: Tick { MusicalTime.ticksPerBar(signature) }
    private var ticksPerPoint: Double { Double(ticksPerBar) / Double(pointsPerBar) }
    private var startBar: Int { Int(placement.start / Swift.max(1, ticksPerBar)) + 1 }
    private var lengthBars: Int { Int((clip.length + ticksPerBar - 1) / Swift.max(1, ticksPerBar)) }

    var body: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(clip.length) / ticksPerPoint))
        RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(color, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Text(clip.name)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                    .padding(Theme.Space.xs)
            }
            .frame(width: width, height: Theme.Size.trackRowHeight - 8)
            .offset(x: CGFloat(Double(placement.start) / ticksPerPoint) + dragX, y: 4)
            .opacity(dragX == 0 ? 1 : 0.8)
            .onTapGesture { open(track.id) }
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { dragX = $0.translation.width }
                    .onEnded { value in
                        let delta = Tick((Double(value.translation.width) * ticksPerPoint).rounded())
                        dragX = 0
                        if let command = Arranging.moved(placement, in: track, byTicks: delta, signature: signature) {
                            try? store.perform(command)
                        }
                    }
            )
            .contextMenu {
                Button("Edit Notes", systemImage: "pianokeys") { open(track.id) }
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                Button("Delete", systemImage: "trash", role: .destructive) { remove() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(clip.name), bar \(startBar), \(lengthBars) bars")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the note editor.")
            .accessibilityAction { open(track.id) }
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Delete") { remove() }
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(placement, in: track, byTicks: bars * ticksPerBar, signature: signature) {
            try? store.perform(command)
        }
    }

    private func duplicate() {
        if let command = Arranging.duplicated(placement, in: track) { try? store.perform(command) }
    }

    private func remove() {
        try? store.perform(.removePlacement(track: track.id, placement.id))
    }
}

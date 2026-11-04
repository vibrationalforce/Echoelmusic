import EchoelCore
import Foundation
import SwiftUI

/// The lanes of a track's take folders (Recovery 4), under the track's own row in Arrange: one
/// lane per take, oldest on top. The stretches the comp chooses a take for are filled; a tap on a
/// lane chooses that take for the bar, a swipe along it for the stretch swiped, on the grid.
/// Every choice is one command, so one undo step. The takes themselves are never edited here.
enum TakeLanes {
    /// One lane's height, the same in the name column and on the timeline.
    static let rowHeight: CGFloat = Theme.Size.touch

    /// Every lane of `track`, in order: the folder, the take, its number among the folder's takes.
    static func rows(of track: Track) -> [Row] {
        track.takeGroups.flatMap { group in
            group.takes.enumerated().map { Row(group: group.id, take: $0.element, number: $0.offset + 1) }
        }
    }

    struct Row: Identifiable, Hashable {
        let group: TakeGroupID
        let take: UUID
        let number: Int
        var id: UUID { take }
    }
}

/// A take lane's name in the name column.
struct TakeLaneName: View {
    let row: TakeLanes.Row

    var body: some View {
        Text("Take \(row.number)")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.leading, Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: TakeLanes.rowHeight)
            .background(Theme.Color.background)
            .accessibilityHidden(true)
    }
}

/// One take's lane on the timeline.
struct TakeLane: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard
    let track: Track
    let project: Project
    let row: TakeLanes.Row
    let pointsPerBar: CGFloat

    private var meter: MeterMap { project.meterMap }
    private var ticksPerPoint: Double { Double(meter.ticksPerBar(at: 0)) / Double(pointsPerBar) }
    private var span: Range<Tick>? { project.takeSpan(row.take, on: track) }
    private var chosen: [Range<Tick>] {
        TakeComp.chosen(row.take, in: track.takeGroups.first { $0.id == row.group }?.comp ?? [])
    }

    var body: some View {
        Canvas { [span, chosen, ticksPerPoint] context, size in
            func rect(_ range: Range<Tick>) -> CGRect {
                let x = CGFloat(Double(range.lowerBound) / ticksPerPoint)
                let width = CGFloat(Double(range.upperBound - range.lowerBound) / ticksPerPoint)
                return CGRect(x: x, y: 4, width: Swift.max(width, 1), height: size.height - 8)
            }
            if let span {
                let take = Path(roundedRect: rect(span), cornerRadius: Theme.Radius.small)
                context.fill(take, with: .color(Theme.Color.surfaceRaised))
                context.stroke(take, with: .color(Theme.Color.border), lineWidth: 1)
            }
            for range in chosen {
                context.fill(Path(roundedRect: rect(range), cornerRadius: Theme.Radius.small),
                             with: .color(Theme.Color.accent.opacity(0.55)))
            }
        }
        .background(Theme.Color.background)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
            let from = tick(at: value.startLocation.x)
            if abs(value.translation.width) < 6 {
                choose(span.flatMap { TakeComp.stretch(tappedAt: from, in: $0, meter: meter) })
            } else {
                choose(span.flatMap {
                    TakeComp.stretch(swipedFrom: from, to: tick(at: value.location.x), in: $0, snap: snap, meter: meter)
                })
            }
        })
        .accessibilityElement()
        .accessibilityLabel("Take \(row.number) of \(track.name)")
        .accessibilityValue(spokenChoice)
        .accessibilityHint("Tap a bar to use this take there, or swipe along the lane to use it for a stretch.")
        .accessibilityAction(named: "Use This Take at the Playhead Bar") { useAtPlayhead() }
        .accessibilityAction(named: "Use the Whole Take") { choose(span) }
        .accessibilityAction(named: "Unfold Takes") { unfold() }
        .contextMenu {
            Button("Use the Whole Take", systemImage: "checkmark.rectangle") { choose(span) }
            Button("Unfold Takes", systemImage: "rectangle.split.1x2") { unfold() }
        }
    }

    private var spokenChoice: String {
        let ranges = chosen
        guard !ranges.isEmpty else { return "Not used" }
        let bars = ranges.map { range -> String in
            let first = meter.bar(at: range.lowerBound) + 1
            let last = meter.bar(at: Swift.max(range.lowerBound, range.upperBound - 1)) + 1
            return first == last ? "bar \(first)" : "bars \(first) to \(last)"
        }
        return "Used in " + bars.joined(separator: ", ")
    }

    private func tick(at x: CGFloat) -> Tick {
        let value = Double(x) * ticksPerPoint
        guard value.isFinite else { return 0 }
        return Swift.max(0, Tick(value.rounded(.down)))
    }

    private func choose(_ stretch: Range<Tick>?) {
        guard let stretch else { return }
        try? store.perform(.compTake(track: track.id, group: row.group, take: row.take,
                                     start: stretch.lowerBound, end: stretch.upperBound))
    }

    private func useAtPlayhead() {
        let at = engine.playheadTick(in: store.project)
        choose(span.flatMap { TakeComp.stretch(tappedAt: at, in: $0, meter: meter) })
    }

    private func unfold() {
        try? store.perform(.removeTakeGroup(track: track.id, row.group))
    }
}

import EchoelCore
import SwiftUI

/// The step sequencer for a drum track: one row per kit piece, one cell per step. Tap a cell
/// to set or clear a hit, hold it to accent. The cells are a view over the clip's notes, so
/// whatever the piano roll or a recording put there shows here too.
struct StepGridView: View {
    @Environment(ProjectStore.self) private var store
    let clip: Clip
    let color: Color
    /// Step length in ticks: the editor's grid.
    let step: Tick

    @ScaledMetric(relativeTo: .body) private var cell: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var nameWidth: CGFloat = 92

    private let lanes = DrumLane.standardKit

    var body: some View {
        let count = StepEditing.stepCount(of: clip, step: step)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: Theme.Space.xs) {
                laneNames
                ScrollView(.horizontal) {
                    VStack(spacing: 2) {
                        ForEach(lanes) { lane in
                            laneRow(lane, count: count)
                        }
                    }
                }
            }
            .padding(Theme.Space.m)
        }
        .background(Theme.Color.background)
    }

    private var laneNames: some View {
        VStack(spacing: 2) {
            ForEach(lanes) { lane in
                Text(lane.name)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: nameWidth, height: cell, alignment: .leading)
                    .contextMenu {
                        Button("Clear \(lane.name)", systemImage: "xmark", role: .destructive) { clear(lane) }
                    }
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: "Clear \(lane.name)") { clear(lane) }
            }
        }
    }

    private func laneRow(_ lane: DrumLane, count: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                stepCell(lane, index)
            }
        }
    }

    private func stepCell(_ lane: DrumLane, _ index: Int) -> some View {
        let mark = state(lane, index)
        return StepCell(state: mark, color: color, downbeat: index % 4 == 0, size: cell)
            .onTapGesture { toggle(lane, index) }
            .onLongPressGesture { accent(lane, index) }
            .accessibilityElement()
            .accessibilityLabel("\(lane.name), step \(index + 1)")
            .accessibilityValue(mark.spoken)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggle(lane, index) }
            .accessibilityAction(named: "Accent") { accent(lane, index) }
    }

    private func state(_ lane: DrumLane, _ index: Int) -> StepCell.Mark {
        guard let hit = StepEditing.hit(in: clip, pitch: lane.pitch, step: index, step: step) else { return .off }
        return hit.velocity >= StepEditing.accentVelocity ? .accent : .on
    }

    private func toggle(_ lane: DrumLane, _ index: Int) {
        if let command = StepEditing.toggle(in: clip, pitch: lane.pitch, step: index, step: step) {
            try? store.perform(command)
        }
    }

    /// Holding an empty step sets an accented hit; holding a hit flips its accent.
    private func accent(_ lane: DrumLane, _ index: Int) {
        let command = StepEditing.toggleAccent(in: clip, pitch: lane.pitch, step: index, step: step)
            ?? StepEditing.toggle(in: clip, pitch: lane.pitch, step: index, step: step,
                                  velocity: StepEditing.accentVelocity)
        if let command { try? store.perform(command) }
    }

    private func clear(_ lane: DrumLane) {
        if let command = StepEditing.clearLane(in: clip, pitch: lane.pitch) { try? store.perform(command) }
    }
}

private struct StepCell: View {
    enum Mark {
        case off, on, accent

        var spoken: String {
            switch self {
            case .off: "Off"
            case .on: "On"
            case .accent: "Accent"
            }
        }
    }

    let state: Mark
    let color: Color
    /// The first step of each beat is drawn a little brighter, for orientation.
    let downbeat: Bool
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(state == .off ? Theme.Color.border : color, lineWidth: 1)
            )
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }

    private var fill: Color {
        switch state {
        case .off: downbeat ? Theme.Color.surfaceRaised : Theme.Color.surface
        case .on: color.opacity(0.6)
        case .accent: color
        }
    }
}

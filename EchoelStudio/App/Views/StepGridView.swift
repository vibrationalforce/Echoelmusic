import EchoelCore
import SwiftUI

/// The step sequencer for a drum track: one row per kit piece, one cell per step. Tap a cell
/// to set or clear a hit, hold it to accent. The cells are a view over the clip's notes, so
/// whatever the piano roll or a recording put there shows here too. With VoiceOver the rotor
/// "Lanes" jumps to the first step of each kit piece, and every step says its beat
/// (accessibility audit 2026-11-01, M1).
struct StepGridView: View {
    @Environment(ProjectStore.self) private var store
    let clip: Clip
    let color: Color
    /// Step length in ticks: the editor's grid.
    let step: Tick

    /// One step, a full touch target (44 pt) at the standard text size and growing with it — up
    /// to `largestCell`, so a bar of steps still reads as a row at the largest sizes (M3).
    @ScaledMetric(relativeTo: .body) private var cell: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var nameWidth: CGFloat = 92
    /// The rotor's marks: the first step of each lane.
    @Namespace private var lanesRotor

    private static let largestCell: CGFloat = 72
    private static let widestName: CGFloat = 128

    private let lanes = DrumLane.standardKit

    private var cellSize: CGFloat { Swift.min(cell, Self.largestCell) }
    private var nameColumn: CGFloat { Swift.min(nameWidth, Self.widestName) }

    var body: some View {
        let count = StepEditing.stepCount(of: clip, step: step)
        // The bars of the clip's own meter: the song's from where the clip is placed.
        let meter = store.project.clipMeter(clip.id)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: Theme.Space.xs) {
                laneNames
                // Column by column, and lazily: a sixteen-bar clip has 256 steps a lane, and only
                // the columns on screen are built (clip length menu, 2026-11-18).
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: Theme.Space.xxs) {
                        ForEach(0..<count, id: \.self) { index in
                            stepColumn(index, meter: meter)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        StepPlayhead(clip: clip.id, step: step, columnWidth: cellSize + Theme.Space.xxs,
                                     height: CGFloat(lanes.count) * (cellSize + Theme.Space.xxs))
                    }
                }
            }
            .padding(Theme.Space.m)
        }
        .background(Theme.Color.background)
        .accessibilityRotor("Lanes") {
            ForEach(lanes) { lane in
                // A string label takes the id unlabeled when a namespace follows.
                AccessibilityRotorEntry(lane.name, lane.id, in: lanesRotor)
            }
        }
    }

    private var laneNames: some View {
        VStack(spacing: Theme.Space.xxs) {
            ForEach(lanes) { lane in
                Text(lane.name)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(width: nameColumn, height: cellSize, alignment: .leading)
                    .contextMenu { laneMenu(lane) }
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: "Clear \(lane.name)") { clear(lane) }
                    .accessibilityAction(named: "Rotate \(lane.name) Later") { rotate(lane, by: 1) }
                    .accessibilityAction(named: "Rotate \(lane.name) Earlier") { rotate(lane, by: -1) }
            }
        }
    }

    /// Euclidean rhythms (ECHOELTOOLS A12): a few classic spreads, each filling the lane over the
    /// whole clip in the editor's steps; Rotate turns whatever the lane holds by one step. Only
    /// what the musician picks is written, one undo step each.
    @ViewBuilder
    private func laneMenu(_ lane: DrumLane) -> some View {
        Menu("Euclidean Rhythm", systemImage: "circle.dotted") {
            ForEach(Self.euclideanSpreads, id: \.self) { spread in
                Button("\(spread[0]) over \(spread[1])") { euclid(lane, hits: spread[0], steps: spread[1]) }
            }
        }
        Button("Rotate Later", systemImage: "arrow.right") { rotate(lane, by: 1) }
        Button("Rotate Earlier", systemImage: "arrow.left") { rotate(lane, by: -1) }
        Button("Clear \(lane.name)", systemImage: "xmark", role: .destructive) { clear(lane) }
    }

    /// Hits over steps: the tresillo and cinquillo, then spreads over three and four beats.
    private static let euclideanSpreads: [[Int]] = [[3, 8], [5, 8], [7, 8], [5, 12], [7, 12],
                                                    [3, 16], [5, 16], [7, 16], [9, 16], [11, 16]]

    private func euclid(_ lane: DrumLane, hits: Int, steps: Int) {
        guard let commands = StepEditing.euclid(in: clip, pitch: lane.pitch, hits: hits, steps: steps, step: step) else {
            return Theme.Accessibility.announce(Announcement("\(lane.name) already plays \(hits) over \(steps).", priority: .normal))
        }
        do {
            try store.perform(commands, title: "Euclidean Rhythm")
            Theme.Accessibility.announce(Announcement("\(lane.name): \(hits) over \(steps).", priority: .normal))
        } catch {
            Theme.Accessibility.announce(Announcement("The rhythm could not be written.", priority: .urgent))
        }
    }

    private func rotate(_ lane: DrumLane, by steps: Int) {
        guard let command = StepEditing.rotateLane(in: clip, pitch: lane.pitch, by: steps, step: step) else { return }
        try? store.perform(command)
    }

    /// One step of every lane, top to bottom in the lanes' order.
    private func stepColumn(_ index: Int, meter: MeterMap) -> some View {
        VStack(spacing: Theme.Space.xxs) {
            ForEach(lanes) { lane in
                rotorMark(stepCell(lane, index, meter: meter), lane: lane, index: index)
            }
        }
    }

    private func stepCell(_ lane: DrumLane, _ index: Int, meter: MeterMap) -> some View {
        let mark = state(lane, index)
        let place = NoteEditing.spokenStep(index, step: step, meter: meter, clipLength: clip.length)
        let accentAction = mark == .accent ? "Remove Accent" : "Accent"
        // A step on a beat of the clip's own meter is marked — every fourth only held for
        // sixteenths in 4/4, and put the marks on the wrong steps for eighths and triplets
        // (audit A3 #15).
        let tick = Tick(index) * step
        let onBeat = meter.beatStart(at: tick) == tick
        return StepCell(state: mark, color: color, downbeat: onBeat, size: cellSize)
            .onTapGesture { toggle(lane, index) }
            .onLongPressGesture { accent(lane, index) }
            .accessibilityElement()
            .accessibilityLabel("\(lane.name), \(place)")
            .accessibilityValue(mark.spoken)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggle(lane, index) }
            .accessibilityAction(named: accentAction) { accent(lane, index, announced: true) }
    }

    /// The first step of a lane is where the rotor's "Lanes" lands.
    @ViewBuilder
    private func rotorMark(_ content: some View, lane: DrumLane, index: Int) -> some View {
        if index == 0 {
            content.accessibilityRotorEntry(id: lane.id, in: lanesRotor)
        } else {
            content
        }
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

    /// Holding an empty step sets an accented hit; holding a hit flips its accent. The VoiceOver
    /// action says the step's new state: an action, unlike the step's own double tap, changes
    /// nothing VoiceOver reads back by itself.
    private func accent(_ lane: DrumLane, _ index: Int, announced: Bool = false) {
        let wasAccented = state(lane, index) == .accent
        let command = StepEditing.toggleAccent(in: clip, pitch: lane.pitch, step: index, step: step)
            ?? StepEditing.toggle(in: clip, pitch: lane.pitch, step: index, step: step,
                                  velocity: StepEditing.accentVelocity)
        guard let command else { return }
        do {
            try store.perform(command)
        } catch {
            return
        }
        guard announced else { return }
        let said = wasAccented ? "Accent removed." : "Accented."
        Theme.Accessibility.announce(Announcement(said, priority: .normal))
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
                    .strokeBorder(border, lineWidth: state == .accent ? 3 : 1)
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

    /// An empty step is outlined as a control's boundary (3.6:1, where the hairline was 1.16:1 —
    /// WCAG 1.4.11 asks 3:1, M2); a hit in its track colour; an accent in a thick light edge, so
    /// it differs from a hit by more than brightness (m2).
    private var border: Color {
        switch state {
        case .off: Theme.Color.borderStrong
        case .on: color
        case .accent: Theme.Color.text
        }
    }
}

/// The step the song plays in the grid, as a thin line at its left edge: while the song plays the
/// clip from a placement (`Arranging.position`); nothing otherwise. It moves from step to step and
/// never lights a cell, so it adds no flash. A leaf of its own, so the clock redraws only the line
/// (Law 6).
private struct StepPlayhead: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    let clip: ClipID
    let step: Tick
    let columnWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let playing = engine.isPlaying
        let project = store.project
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { _ in
            if playing, step > 0, let at = Arranging.position(inClip: clip, of: project, atSongTick: engine.heardTick(in: project)) {
                Rectangle()
                    .fill(Theme.Color.accent)
                    .frame(width: 2, height: height)
                    .offset(x: CGFloat(Int(at) / Int(step)) * columnWidth)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

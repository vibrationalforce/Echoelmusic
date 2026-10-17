import EchoelCore
import SwiftUI

/// "Automate" for one owner: every parameter of it that has no lane yet. A new lane starts
/// with one point holding the parameter's current value.
struct AutomateMenu: View {
    @Environment(ProjectStore.self) private var store
    let owner: ParameterAddress.Owner

    var body: some View {
        let project = store.project
        let open = project.parameters.filter {
            $0.address.owner == owner && $0.address != .tempo && project.automation(for: $0.address) == nil
        }
        Menu("Automate", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
            ForEach(open, id: \.address) { descriptor in
                Button(descriptor.title) {
                    let value = project.value(of: descriptor.address) ?? descriptor.defaultValue
                    try? store.perform(.setAutomation(descriptor.address, points: [AutomationPoint(tick: 0, value: value)]))
                }
            }
        }
        .disabled(open.isEmpty)
    }
}

/// The name cell of an automation lane, with its delete action.
struct AutomationName: View {
    @Environment(ProjectStore.self) private var store
    let lane: AutomationLane

    var body: some View {
        let title = store.project.descriptor(for: lane.target)?.title ?? lane.target.description
        Text(title)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.leading, Theme.Space.l)
            .padding(.trailing, Theme.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Theme.Size.trackRowHeight)
            .background(Theme.Color.background)
            .contextMenu {
                Button("Remove Automation", systemImage: "trash", role: .destructive) {
                    try? store.perform(.setAutomation(lane.target, points: []))
                }
            }
            .accessibilityHidden(true)
    }
}

/// One lane drawn on the bar timeline: the line between its points, and the points. Tap empty
/// space to add a point there (snapped to a sixteenth), tap a point to remove it, drag a point
/// to move it between its neighbours. One drag is one undo step.
struct AutomationRow: View {
    @Environment(ProjectStore.self) private var store
    let lane: AutomationLane
    let signature: TimeSignature
    let pointsPerBar: CGFloat

    @State private var dragging: Int?

    private static let hit: CGFloat = 14
    private static let snap = MusicalTime.ticksPerQuarter / 4

    private var ticksPerPoint: Double { Double(MusicalTime.ticksPerBar(signature)) / Double(pointsPerBar) }

    var body: some View {
        let descriptor = store.project.descriptor(for: lane.target)
        GeometryReader { geometry in
            let height = geometry.size.height
            Canvas { context, size in draw(context, size, descriptor) }
                .background(Theme.Color.background)
                .contentShape(Rectangle())
                .gesture(drag(height: height, descriptor))
                .onTapGesture { location in tap(at: location, height: height, descriptor) }
        }
        .accessibilityElement()
        .accessibilityLabel("\(descriptor?.title ?? "Parameter") automation")
        .accessibilityValue("\(lane.points.count) points")
        .accessibilityAction(named: "Remove Automation") {
            try? store.perform(.setAutomation(lane.target, points: []))
        }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize, _ descriptor: ParameterDescriptor?) {
        guard let descriptor, !lane.points.isEmpty else { return }
        let points = lane.points.map { CGPoint(x: x(of: $0.tick), y: y(of: $0.value, descriptor, size.height)) }
        var line = Path()
        line.move(to: CGPoint(x: 0, y: points[0].y))
        for point in points { line.addLine(to: point) }
        line.addLine(to: CGPoint(x: size.width, y: points[points.count - 1].y))
        context.stroke(line, with: .color(Theme.Color.accent), lineWidth: 1.5)
        for point in points {
            let dot = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dot), with: .color(Theme.Color.text))
        }
    }

    private func x(of tick: Tick) -> CGFloat { CGFloat(Double(tick) / ticksPerPoint) }

    private func y(of value: Double, _ descriptor: ParameterDescriptor, _ height: CGFloat) -> CGFloat {
        let inset: CGFloat = 6
        return inset + (1 - CGFloat(descriptor.normalized(value))) * (height - 2 * inset)
    }

    private func value(atY y: CGFloat, _ descriptor: ParameterDescriptor, _ height: CGFloat) -> Double {
        let inset: CGFloat = 6
        let n = 1 - (y - inset) / Swift.max(1, height - 2 * inset)
        return descriptor.value(forNormalized: Double(n))
    }

    private func tick(atX x: CGFloat) -> Tick {
        let raw = Tick((Double(Swift.max(0, x)) * ticksPerPoint).rounded())
        return Swift.min((raw + Self.snap / 2) / Self.snap * Self.snap, MusicalTime.maximumTick)
    }

    private func nearest(to location: CGPoint, height: CGFloat, _ descriptor: ParameterDescriptor) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, point) in lane.points.enumerated() {
            let dx = x(of: point.tick) - location.x, dy = y(of: point.value, descriptor, height) - location.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= Self.hit, distance < (best?.distance ?? .infinity) { best = (index, distance) }
        }
        return best?.index
    }

    private func tap(at location: CGPoint, height: CGFloat, _ descriptor: ParameterDescriptor?) {
        guard let descriptor else { return }
        var points = lane.points
        if let index = nearest(to: location, height: height, descriptor) {
            points.remove(at: index)
            try? store.perform(.setAutomation(lane.target, points: points))
            return
        }
        let tick = tick(atX: location.x)
        points.removeAll { $0.tick == tick }
        let index = points.firstIndex { $0.tick > tick } ?? points.count
        points.insert(AutomationPoint(tick: tick, value: value(atY: location.y, descriptor, height)), at: index)
        try? store.perform(.setAutomation(lane.target, points: points))
    }

    private func drag(height: CGFloat, _ descriptor: ParameterDescriptor?) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                guard let descriptor else { return }
                if dragging == nil { dragging = nearest(to: drag.startLocation, height: height, descriptor) ?? -1 }
                guard let index = dragging, index >= 0, index < lane.points.count else { return }
                var points = lane.points
                let low = index > 0 ? points[index - 1].tick + 1 : 0
                let high = index + 1 < points.count ? points[index + 1].tick - 1 : MusicalTime.maximumTick
                guard low <= high else { return }
                let snapped = tick(atX: drag.location.x)
                points[index] = AutomationPoint(tick: Swift.min(Swift.max(snapped, low), high),
                                                value: value(atY: drag.location.y, descriptor, height))
                try? store.perform(.setAutomation(lane.target, points: points), coalescingKey: "automation.edit.\(lane.target)")
            }
            .onEnded { _ in
                dragging = nil
                store.endGesture()
            }
    }
}

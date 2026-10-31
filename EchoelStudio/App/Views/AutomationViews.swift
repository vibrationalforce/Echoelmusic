import EchoelCore
import SwiftUI

/// "Automate" for one owner: every parameter of it that has no lane yet. A new lane starts
/// with one point holding the parameter's current value.
struct AutomateMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let owner: ParameterAddress.Owner

    /// One loaded unit of the track and its parameters that have no lane yet.
    private struct UnitParameters: Identifiable {
        let unit: PluginParameter.Unit
        let title: String
        let parameters: [PluginParameterInfo]
        var id: PluginParameter.Unit { unit }
    }

    var body: some View {
        let project = store.project
        let open = project.parameters.filter {
            $0.address.owner == owner && $0.address.owner != .project && project.automation(for: $0.address) == nil
        }
        let units = pluginUnits(project)
        Menu("Automate", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
            ForEach(open, id: \.address) { descriptor in
                Button(descriptor.title) {
                    let value = project.value(of: descriptor.address) ?? descriptor.defaultValue
                    try? store.perform(.setAutomation(descriptor.address, points: [AutomationPoint(tick: 0, value: value)]))
                }
            }
            ForEach(units) { unit in
                Menu(unit.title) {
                    ForEach(unit.parameters) { parameter in
                        Button(parameter.name) { automate(unit.unit, parameter) }
                    }
                }
            }
        }
        .disabled(open.isEmpty && units.isEmpty)
    }

    /// A new lane starts where the unit's control is now.
    private func automate(_ unit: PluginParameter.Unit, _ parameter: PluginParameterInfo) {
        guard case .track(let track) = owner else { return }
        let address = ParameterAddress.plugin(track, PluginParameter(unit, address: parameter.address))
        try? store.perform(.setAutomation(address, points: [AutomationPoint(tick: 0, value: parameter.position)]))
    }

    private func pluginUnits(_ project: Project) -> [UnitParameters] {
        guard case .track(let id) = owner, let track = project.track(id) else { return [] }
        _ = engine.plugins.revision
        var units: [(PluginParameter.Unit, PluginHost.Slot, String)] = []
        if track.kind == .instrument, track.instrument.device == .plugin, let plugin = track.instrument.plugin {
            units.append((.instrument, .instrument(id), plugin.displayName))
        }
        for insert in track.inserts { units.append((.insert(insert.id), .insert(insert.id), insert.plugin.displayName)) }
        return units.compactMap { unit, slot, title in
            let open = engine.plugins.automatableParameters(slot).filter {
                project.automation(for: .plugin(id, PluginParameter(unit, address: $0.address))) == nil
            }
            return open.isEmpty ? nil : UnitParameters(unit: unit, title: title, parameters: open)
        }
    }
}

/// The name cell of an automation lane, with its delete action.
struct AutomationName: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let lane: AutomationLane

    var body: some View {
        let title = pluginTitle ?? store.project.descriptor(for: lane.target)?.title ?? lane.target.description
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

    /// A plugin parameter by the name its unit gives it, once the unit is loaded.
    private var pluginTitle: String? {
        guard case .track(let id) = lane.target.owner, let parameter = lane.target.key.pluginParameter,
              let track = store.project.track(id), let plugin = track.plugin(for: parameter.unit) else { return nil }
        _ = engine.plugins.revision
        let slot: PluginHost.Slot
        switch parameter.unit {
        case .instrument: slot = .instrument(id)
        case .insert(let insert): slot = .insert(insert)
        }
        guard let name = engine.plugins.automatableParameters(slot).first(where: { $0.address == parameter.address })?.name
        else { return nil }
        return "\(plugin.displayName) \(name)"
    }
}

/// One lane drawn on the bar timeline: the line between its points, and the points. Tap empty
/// space to add a point there (snapped to a sixteenth), tap a point to remove it, drag a point
/// to move it between its neighbours. Each segment has a handle at its middle: drag it up or
/// down to bend the segment, tap it to straighten it. A lane of choices (the waveform) holds each
/// point until the next, is drawn as steps and has no handles. One drag is one undo step.
struct AutomationRow: View {
    @Environment(ProjectStore.self) private var store
    let lane: AutomationLane
    let signature: TimeSignature
    let pointsPerBar: CGFloat

    /// What the current drag holds: a point, or the bend of the segment after a point.
    @State private var dragging: Grab?
    @State private var bendStart: Double = 0

    enum Grab: Equatable { case point(Int), bend(Int), nothing }

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
        let holds = descriptor.taper == .stepped
        var line = Path()
        line.move(to: CGPoint(x: 0, y: points[0].y))
        line.addLine(to: points[0])
        for index in lane.points.indices.dropLast() {
            if holds {
                // A choice holds until the next point and jumps there, as the engine plays it.
                line.addLine(to: CGPoint(x: points[index + 1].x, y: points[index].y))
                line.addLine(to: points[index + 1])
                continue
            }
            let a = lane.points[index], b = lane.points[index + 1]
            // Enough steps that a bend reads as a curve at any zoom.
            let steps = Swift.max(2, Swift.min(48, Int((points[index + 1].x - points[index].x) / 3)))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                let value = a.value + (b.value - a.value) * AutomationPoint.shape(t, curve: a.curve)
                line.addLine(to: CGPoint(x: points[index].x + (points[index + 1].x - points[index].x) * CGFloat(t),
                                         y: y(of: value, descriptor, size.height)))
            }
        }
        line.addLine(to: CGPoint(x: size.width, y: points[points.count - 1].y))
        context.stroke(line, with: .color(Theme.Color.accent), lineWidth: 1.5)
        for index in lane.points.indices.dropLast() where !holds {
            let handle = bendHandle(index, descriptor, size.height)
            let mark = CGRect(x: handle.x - 3, y: handle.y - 3, width: 6, height: 6)
            context.stroke(Path(roundedRect: mark, cornerRadius: 1), with: .color(Theme.Color.accent), lineWidth: 1)
        }
        for point in points {
            let dot = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dot), with: .color(Theme.Color.text))
        }
    }

    private func x(of tick: Tick) -> CGFloat { CGFloat(Double(tick) / ticksPerPoint) }

    /// The middle of the segment after point `index`, on its curve.
    private func bendHandle(_ index: Int, _ descriptor: ParameterDescriptor, _ height: CGFloat) -> CGPoint {
        let a = lane.points[index], b = lane.points[index + 1]
        let value = a.value + (b.value - a.value) * AutomationPoint.shape(0.5, curve: a.curve)
        return CGPoint(x: (x(of: a.tick) + x(of: b.tick)) / 2, y: y(of: value, descriptor, height))
    }

    /// A choice has no bend: nothing lies between two choices.
    private func nearestBend(to location: CGPoint, height: CGFloat, _ descriptor: ParameterDescriptor) -> Int? {
        guard descriptor.taper != .stepped else { return nil }
        for index in lane.points.indices.dropLast() {
            let handle = bendHandle(index, descriptor, height)
            let dx = handle.x - location.x, dy = handle.y - location.y
            if (dx * dx + dy * dy).squareRoot() <= Self.hit { return index }
        }
        return nil
    }

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
        if let index = nearestBend(to: location, height: height, descriptor) {
            // A tap on a bend handle straightens the segment.
            points[index].curve = 0
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
                if dragging == nil {
                    if let index = nearest(to: drag.startLocation, height: height, descriptor) {
                        dragging = .point(index)
                    } else if let index = nearestBend(to: drag.startLocation, height: height, descriptor) {
                        dragging = .bend(index)
                        bendStart = lane.points[index].curve
                    } else {
                        dragging = .nothing
                    }
                }
                if case .bend(let index) = dragging {
                    bend(index, by: drag.translation.height, height: height)
                    return
                }
                guard case .point(let index) = dragging, index < lane.points.count else { return }
                var points = lane.points
                let low = index > 0 ? points[index - 1].tick + 1 : 0
                let high = index + 1 < points.count ? points[index + 1].tick - 1 : MusicalTime.maximumTick
                guard low <= high else { return }
                let snapped = tick(atX: drag.location.x)
                points[index] = AutomationPoint(tick: Swift.min(Swift.max(snapped, low), high),
                                                value: value(atY: drag.location.y, descriptor, height),
                                                curve: points[index].curve)
                try? store.perform(.setAutomation(lane.target, points: points), coalescingKey: "automation.edit.\(lane.target)")
            }
            .onEnded { _ in
                dragging = nil
                store.endGesture()
            }
    }

    /// The handle follows the finger: pulling the middle of a segment down bends it below the
    /// straight line, pulling it up bends it above, whichever way the segment runs.
    private func bend(_ index: Int, by dy: CGFloat, height: CGFloat) {
        guard index + 1 < lane.points.count else { return }
        var points = lane.points
        let rising = points[index + 1].value >= points[index].value
        let amount = Double(dy / Swift.max(height, 1)) * 2 * (rising ? 1 : -1)
        let curve = Swift.min(Swift.max(bendStart + amount, AutomationPoint.curveRange.lowerBound),
                              AutomationPoint.curveRange.upperBound)
        guard curve != points[index].curve else { return }
        points[index].curve = curve
        try? store.perform(.setAutomation(lane.target, points: points), coalescingKey: "automation.bend.\(lane.target)")
    }
}

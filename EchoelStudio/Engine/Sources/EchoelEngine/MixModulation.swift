import EchoelCore
import Foundation

/// The routes on one mixer value (a track's or the master's volume or pan), compiled for the
/// render thread (wave W2). The value moves along its control's travel — the fader's, the pan
/// knob's — by the sum of the routes whose source is measured right now, clamped once, after the
/// last route; with every source absent it is exactly the stored or automated value. Arithmetic
/// is `Modulation.contribution`, the one the song's own rules use. Render-safe: no allocation,
/// no lock; the sources are `ModulationInputs` cells.
public struct MixModulation: Sendable {
    /// One enabled route, reduced to plain values.
    struct Route: Sendable {
        let source: Int
        let depth: Double
        let curve: ModulationRoute.Curve
        let polarity: ModulationRoute.Polarity
    }

    let descriptor: ParameterDescriptor
    let routes: [Route]
    let inputs: ModulationInputs

    /// Nil when no enabled route moves `target`, so the render thread keeps its fixed path.
    public init?(_ target: ParameterAddress, in project: Project, inputs: ModulationInputs?) {
        guard let inputs, let descriptor = project.descriptor(for: target) else { return nil }
        let ordered = project.modRoutes
            .filter { $0.enabled && $0.target == target }
            .sorted { $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased() }
        let compiled = ordered.compactMap { route -> Route? in
            guard let source = ModulationInputs.index(route.source) else { return nil }
            return Route(source: source, depth: route.depth, curve: route.curve, polarity: route.polarity)
        }
        guard !compiled.isEmpty else { return nil }
        self.descriptor = descriptor
        routes = compiled
        self.inputs = inputs
    }

    /// `base` moved by the routes. Render-safe.
    public func value(_ base: Double) -> Double {
        var sum = 0.0
        var moved = false
        for route in routes {
            guard let reading = inputs.value(at: route.source) else { continue }
            sum += Modulation.contribution(of: reading, depth: route.depth, curve: route.curve, polarity: route.polarity)
            moved = true
        }
        guard moved else { return base }
        let position = Swift.min(1, Swift.max(0, descriptor.normalized(base) + sum))
        return descriptor.value(forNormalized: position)
    }
}

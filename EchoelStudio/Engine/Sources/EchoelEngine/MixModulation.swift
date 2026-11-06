import EchoelCore
import Foundation

/// The routes on one mixer value (a track's or the master's volume or pan), compiled for the
/// render thread (wave W2). The value moves along its control's travel — the fader's, the pan
/// knob's — by the sum of the routes whose source is measured right now, clamped once, after the
/// last route; with every source absent it is exactly the stored or automated value. Arithmetic
/// is `Modulation.contribution`, the one the song's own rules use. Render-safe: no allocation,
/// no lock. A body source is a `ModulationInputs` cell, live only; `lfo.1` and `weave.1` are read
/// from the song position (`Modulation.songLFO`, `Modulation.songWeave`), so they move an export
/// exactly as they move playback.
public struct MixModulation: Sendable {
    /// One enabled route, reduced to plain values. `source` is its `ModulationInputs` cell; a
    /// route on the song clock (`lfo.1`, `weave.1` — `weave`) reads the position instead.
    struct Route: Sendable {
        let source: Int
        let clock: Bool
        let weave: Bool
        let depth: Double
        let curve: ModulationRoute.Curve
        let polarity: ModulationRoute.Polarity
    }

    let descriptor: ParameterDescriptor
    let routes: [Route]
    let inputs: ModulationInputs?
    let meter: MeterMap
    /// The Weave's first row, from the song's key, for `weave.1`.
    let weaveSeed: UInt64

    /// Nil when no enabled route moves `target`, so the render thread keeps its fixed path.
    /// Without `inputs` (an offline render) only routes on the song clock compile: an export never
    /// reads a live sensor.
    public init?(_ target: ParameterAddress, in project: Project, inputs: ModulationInputs?) {
        guard let descriptor = project.descriptor(for: target) else { return nil }
        let ordered = project.modRoutes
            .filter { $0.enabled && $0.target == target }
            .sorted { $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased() }
        let compiled = ordered.compactMap { route -> Route? in
            if route.source == .lfo1 || route.source == .weave1 {
                return Route(source: -1, clock: true, weave: route.source == .weave1, depth: route.depth,
                             curve: route.curve, polarity: route.polarity)
            }
            guard inputs != nil, let source = ModulationInputs.index(route.source) else { return nil }
            return Route(source: source, clock: false, weave: false, depth: route.depth, curve: route.curve,
                         polarity: route.polarity)
        }
        guard !compiled.isEmpty else { return nil }
        self.descriptor = descriptor
        routes = compiled
        self.inputs = inputs
        meter = project.meterMap
        weaveSeed = BarWeave.seed(keyMask: BarWeave.keyMask(project.context))
    }

    /// Whether a route reads the song position, so the value moves while the song plays.
    public var followsSongClock: Bool { routes.contains { $0.clock } }

    /// `base` moved by the routes at song position `position` (ticks; nil while the song stands,
    /// when a route on the song clock adds nothing). Render-safe.
    public func value(_ base: Double, at position: Double? = nil) -> Double {
        var sum = 0.0
        var moved = false
        for route in routes {
            let measured: Double?
            if route.clock {
                measured = position.flatMap {
                    route.weave ? Modulation.songWeave(at: $0, meter: meter, seed: weaveSeed)
                                : Modulation.songLFO(at: $0, meter: meter)
                }
            } else {
                measured = inputs?.value(at: route.source)
            }
            guard let reading = measured else { continue }
            sum += Modulation.contribution(of: reading, depth: route.depth, curve: route.curve, polarity: route.polarity)
            moved = true
        }
        guard moved else { return base }
        let position = Swift.min(1, Swift.max(0, descriptor.normalized(base) + sum))
        return descriptor.value(forNormalized: position)
    }
}

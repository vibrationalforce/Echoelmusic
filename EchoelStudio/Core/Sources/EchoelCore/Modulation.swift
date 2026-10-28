import Foundation

/// Where a modulation's value comes from. The names are the G-A contract's proposed sources
/// (`.claude/skills/g-a-body-modulation/references/CONTRACT.md`); more LFOs, macros and MIDI
/// controllers get their own names before anything is written to a song.
public enum ModulationSource: String, Codable, Sendable, CaseIterable {
    case heartRate = "body.heartRate"
    case hrv = "body.hrv"
    case coherence = "body.coherence"
    case breath = "body.breath"
    case lfo1 = "lfo.1"
    case macro1 = "macro.1"
    case midiCC1 = "midi.cc.1"
}

/// One route: a source moves one parameter by `depth` (−1 … 1) through a curve. Wave W2. Not yet
/// stored in a song: storing it is format 3, its own step.
public struct ModulationRoute: Equatable, Sendable, Identifiable {
    public enum Curve: String, Codable, Sendable { case linear, square }
    /// Unipolar reads the source 0 … 1 as is; bipolar centres it, −1 … 1.
    public enum Polarity: String, Codable, Sendable { case unipolar, bipolar }

    public let id: UUID
    public var source: ModulationSource
    public var target: ParameterAddress
    public var depth: Double
    public var curve: Curve
    public var polarity: Polarity
    public var enabled: Bool

    public init(id: UUID = UUID(), source: ModulationSource, target: ParameterAddress, depth: Double,
                curve: Curve = .linear, polarity: Polarity = .unipolar, enabled: Bool = true) {
        self.id = id
        self.source = source
        self.target = target
        self.depth = depth
        self.curve = curve
        self.polarity = polarity
        self.enabled = enabled
    }
}

/// The rules every route follows, as the G-A contract and its vectors (`ModulationTests`) fix them:
/// - the base is the automated value where there is one, else the stored one, both 0 … 1;
/// - a missing, out-of-range or disabled source adds exactly nothing — never a centred stand-in,
///   so a missing bipolar source is not −depth;
/// - routes add in the order of their ids, and the sum is clamped to 0 … 1 ONCE, after the last
///   route, never after each one.
/// Validation runs off the render thread, when routes are compiled; `value` is plain arithmetic.
public enum Modulation {
    /// The most routes a song may hold, disabled ones included — a capacity, not a speed proof.
    public static let routeLimit = 64

    public enum Failure: Error, Equatable {
        case routeLimit, duplicateID, target, depth, base
    }

    /// The routes in the order they add, after checking them all: at most `routeLimit`, ids
    /// unique, each target among `targets` (the registry's addresses), each depth finite and
    /// within −1 … 1. One bad route refuses the whole list.
    public static func validate(_ routes: [ModulationRoute], targets: Set<ParameterAddress>) throws -> [ModulationRoute] {
        guard routes.count <= routeLimit else { throw Failure.routeLimit }
        var seen = Set<UUID>()
        for route in routes {
            guard seen.insert(route.id).inserted else { throw Failure.duplicateID }
            guard targets.contains(route.target) else { throw Failure.target }
            guard route.depth.isFinite, (-1...1).contains(route.depth) else { throw Failure.depth }
        }
        return routes.sorted { $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased() }
    }

    /// The normalized value of `target` once `routes` move it. `sources` holds only sources that
    /// are measured now; a source missing from it adds nothing.
    public static func value(of target: ParameterAddress, base: Double, automation: Double? = nil,
                             routes: [ModulationRoute], sources: [ModulationSource: Double],
                             targets: Set<ParameterAddress>) throws -> Double {
        guard targets.contains(target) else { throw Failure.target }
        guard base.isFinite, (0...1).contains(base) else { throw Failure.base }
        if let automation { guard automation.isFinite, (0...1).contains(automation) else { throw Failure.base } }
        var sum = automation ?? base
        for route in try validate(routes, targets: targets) where route.enabled && route.target == target {
            guard let reading = sources[route.source], reading.isFinite, (0...1).contains(reading) else { continue }
            let position = route.polarity == .unipolar ? reading : 2 * reading - 1
            let curved = route.curve == .linear ? position : position * Swift.abs(position)
            sum += route.depth * curved
        }
        return Swift.min(1, Swift.max(0, sum))
    }
}

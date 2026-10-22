import Foundation

/// One breakpoint of an automation lane: the parameter's value at a tick, and how the line to
/// the next point bends.
public struct AutomationPoint: Codable, Equatable, Sendable {
    public var tick: Tick
    public var value: Double
    /// −1…1. 0 is a straight line; above 0 the segment starts slowly and rises late
    /// (exponential), below 0 it moves early and settles (logarithmic).
    public var curve: Double

    public static let curveRange: ClosedRange<Double> = -1...1

    public init(tick: Tick, value: Double, curve: Double = 0) {
        self.tick = tick
        self.value = value
        self.curve = curve
    }

    private enum CodingKeys: String, CodingKey { case tick, value, curve }

    /// A point written before curves existed is straight.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tick = try c.decode(Tick.self, forKey: .tick)
        value = try c.decode(Double.self, forKey: .value)
        curve = try c.decodeIfPresent(Double.self, forKey: .curve) ?? 0
    }

    /// Where a segment with this curve is at `t` (0…1) of its way.
    public static func shape(_ t: Double, curve: Double) -> Double {
        guard curve.isFinite, Swift.abs(curve) > 1e-6 else { return t }
        let k = curve * 6
        return Foundation.expm1(k * t) / Foundation.expm1(k)
    }
}

/// A parameter's value over song time: lines between breakpoints, straight or bent, the first value
/// before the first point and the last after the last. Mixer and instrument parameters can be
/// automated; the tempo has its own tempo track and cannot.
public struct AutomationLane: Codable, Equatable, Sendable {
    public var target: ParameterAddress
    /// Sorted by tick, each tick once.
    public var points: [AutomationPoint]

    public static let maximumPoints = 10_000

    public init(target: ParameterAddress, points: [AutomationPoint]) {
        self.target = target
        self.points = points
    }

    /// The value at `tick`, or nil for a lane without points.
    public func value(at tick: Tick) -> Double? {
        value(atPosition: Double(tick))
    }

    /// The value at a fractional tick — what the engine reads, so a slow ramp moves between
    /// ticks instead of in whole-tick steps.
    public func value(atPosition position: Double) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        guard position.isFinite, position > Double(first.tick) else { return first.value }
        if position >= Double(last.tick) { return last.value }
        let low = pointIndex(before: position), high = low + 1
        let a = points[low], b = points[high]
        let t = (position - Double(a.tick)) / Double(b.tick - a.tick)
        return a.value + (b.value - a.value) * AutomationPoint.shape(t, curve: a.curve)
    }

    /// The value at a fractional tick for a parameter whose values are choices (a waveform):
    /// each point holds until the next one, since nothing lies between two choices. A line
    /// there would switch at the middle of a segment and pass through choices nobody made.
    public func heldValue(atPosition position: Double) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        guard position.isFinite, position > Double(first.tick) else { return first.value }
        if position >= Double(last.tick) { return last.value }
        return points[pointIndex(before: position)].value
    }

    /// The last point at or before `position`, by binary search. Needs at least two points with
    /// `position` after the first and before the last.
    private func pointIndex(before position: Double) -> Int {
        var low = 0, high = points.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if Double(points[mid].tick) <= position { low = mid } else { high = mid }
        }
        return low
    }

    /// Rejects what the engine could not play: unsorted or repeated ticks, ticks outside the
    /// song, and values that are not finite or outside the parameter's range.
    static func validate(_ points: [AutomationPoint], range: ClosedRange<Double>) throws {
        guard points.count <= maximumPoints else {
            throw CommandError.invalidValue(parameter: "points", reason: "at most \(maximumPoints)")
        }
        var previous: Tick = -1
        for point in points {
            guard point.tick > previous, point.tick <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "points", reason: "ticks must rise from 0, each once")
            }
            guard point.value.isFinite, range.contains(point.value) else {
                throw CommandError.invalidValue(parameter: "points", reason: "values must lie within \(range)")
            }
            guard point.curve.isFinite, AutomationPoint.curveRange.contains(point.curve) else {
                throw CommandError.invalidValue(parameter: "points", reason: "curves must lie within −1…1")
            }
            previous = point.tick
        }
    }
}

extension Project {
    /// The lane for `target`, if the song automates it.
    public func automation(for target: ParameterAddress) -> AutomationLane? {
        automation.first { $0.target == target }
    }
}

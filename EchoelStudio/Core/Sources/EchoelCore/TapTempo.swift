import Foundation

/// Tempo from taps in time. Value type with no clock of its own: the caller passes a monotonic
/// time per tap. The estimate is the median interval of the last few taps, so one early or late
/// tap does not pull it; a pause of two seconds starts a new measurement.
public struct TapTempo: Sendable, Equatable {
    public static let resetGap: Double = 2
    public static let window = 8

    private var taps: [Double] = []

    public init() {}

    /// True when the next tap starts a new measurement.
    public func startsOver(at time: Double) -> Bool {
        guard let last = taps.last else { return true }
        return !(time - last > 0 && time - last <= Self.resetGap)
    }

    /// Records a tap and returns the tempo once two taps exist, clamped to `Tempo.range` and
    /// rounded to tenths.
    public mutating func tap(at time: Double) -> Double? {
        guard time.isFinite else { return nil }
        if startsOver(at: time) { taps.removeAll() }
        taps.append(time)
        if taps.count > Self.window { taps.removeFirst(taps.count - Self.window) }
        guard taps.count >= 2 else { return nil }
        let intervals = zip(taps.dropFirst(), taps).map { $0 - $1 }.sorted()
        let middle = intervals.count / 2
        let interval = intervals.count % 2 == 1 ? intervals[middle] : (intervals[middle - 1] + intervals[middle]) / 2
        guard interval > 0 else { return nil }
        let bpm = Swift.min(Swift.max(60 / interval, Tempo.range.lowerBound), Tempo.range.upperBound)
        return (bpm * 10).rounded() / 10
    }

    public mutating func reset() { taps.removeAll() }
}

import Foundation

/// A linear move from one normalized value to another over a fixed number of samples, wave W2:
/// how a modulated value reaches its new target without a step (the G-A contract's sample ramp,
/// vectors R01–R03 in `LinearRampTests`). Its position survives block boundaries, so the same
/// ramp gives the same samples whatever the block sizes. Plain value, render-thread safe.
public struct LinearRamp: Equatable, Sendable {
    public let start: Double
    public let target: Double
    public let durationSamples: Int
    /// Samples taken so far.
    public private(set) var position = 0

    /// Nil for a value outside 0 … 1, a non-finite one, or a duration under one sample.
    public init?(from start: Double, to target: Double, durationSamples: Int) {
        guard start.isFinite, target.isFinite, (0...1).contains(start), (0...1).contains(target),
              durationSamples >= 1 else { return nil }
        self.start = start
        self.target = target
        self.durationSamples = durationSamples
    }

    /// The current value, then one sample on; after the duration it stays on the target.
    public mutating func next() -> Double {
        let fraction = Swift.min(Double(position) / Double(durationSamples), 1)
        if position < durationSamples { position += 1 }
        return start + (target - start) * fraction
    }

    public var isFinished: Bool { position >= durationSamples }
}

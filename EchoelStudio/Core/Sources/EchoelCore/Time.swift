/// Musical time. Every position and length in the document is a whole number of ticks,
/// so arithmetic is exact and an edit never drifts by a rounding error.
public typealias Tick = Int64

public enum MusicalTime {
    /// Pulses per quarter note. 960 divides cleanly by 2, 3, 4, 5, 6, 8, 10, 12, 15, 16,
    /// so triplets, quintuplets and 1/64 notes all land on whole ticks.
    public static let ticksPerQuarter: Tick = 960

    /// The longest position the document accepts: 9 999 bars of 4/4.
    public static let maximumTick: Tick = 9_999 * 4 * ticksPerQuarter

    public static func ticksPerBar(_ signature: TimeSignature) -> Tick {
        ticksPerQuarter * 4 * Tick(signature.numerator) / Tick(signature.denominator)
    }

    public static func ticksPerBeat(_ signature: TimeSignature) -> Tick {
        ticksPerQuarter * 4 / Tick(signature.denominator)
    }
}

public struct TimeSignature: Codable, Hashable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(_ numerator: Int, _ denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let common = TimeSignature(4, 4)

    public static let allowedDenominators: Set<Int> = [1, 2, 4, 8, 16, 32]

    public var isValid: Bool {
        (1...32).contains(numerator) && Self.allowedDenominators.contains(denominator)
    }
}

public enum Tempo {
    public static let range: ClosedRange<Double> = 20...999
    public static let defaultBPM: Double = 120
}

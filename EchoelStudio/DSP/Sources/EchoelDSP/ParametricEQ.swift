import Foundation

/// One biquad section, transposed direct form II (the form that copes best with coefficient
/// changes while it runs). Coefficients from the RBJ Audio EQ Cookbook.
public struct Biquad: Sendable {
    public var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
    private var z1: Float = 0, z2: Float = 0

    public init() {}

    public mutating func reset() {
        z1 = 0
        z2 = 0
    }

    @inline(__always)
    public mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        if !y.isFinite {
            reset()
            return 0
        }
        return y
    }

    /// The gain in dB this section applies at `hz`.
    public func response(at hz: Double, sampleRate: Double) -> Double {
        let w = 2 * Double.pi * hz / sampleRate
        let (c1, s1, c2, s2) = (cos(w), sin(w), cos(2 * w), sin(2 * w))
        let nr = Double(b0) + Double(b1) * c1 + Double(b2) * c2, ni = -(Double(b1) * s1 + Double(b2) * s2)
        let dr = 1 + Double(a1) * c1 + Double(a2) * c2, di = -(Double(a1) * s1 + Double(a2) * s2)
        return 10 * log10((nr * nr + ni * ni) / Swift.max(dr * dr + di * di, 1e-30))
    }

    public enum Shape: Sendable { case highpass, lowShelf, bell, highShelf }

    /// A section of `shape` at `hz`; `gain` in dB (shelves and bells), `q` for bells and the
    /// highpass.
    public static func make(_ shape: Shape, hz: Double, gain: Double, q: Double, sampleRate: Double) -> Biquad {
        let f = Swift.min(Swift.max(hz, 10), sampleRate * 0.49)
        let w = 2 * Double.pi * f / sampleRate
        let cw = cos(w), sw = sin(w)
        let a = Foundation.pow(10, gain / 40)
        let alpha = sw / (2 * Swift.max(q, 0.05))
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
        switch shape {
        case .highpass:
            b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2
            a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
        case .bell:
            b0 = 1 + alpha * a; b1 = -2 * cw; b2 = 1 - alpha * a
            a0 = 1 + alpha / a; a1 = -2 * cw; a2 = 1 - alpha / a
        case .lowShelf, .highShelf:
            // Shelf slope 1.
            let s = 2 * a.squareRoot() * sin(w) / 2 * Foundation.sqrt(2.0)
            let sign: Double = shape == .lowShelf ? 1 : -1
            b0 = a * ((a + 1) - sign * (a - 1) * cw + s)
            b1 = sign * 2 * a * ((a - 1) - sign * (a + 1) * cw)
            b2 = a * ((a + 1) - sign * (a - 1) * cw - s)
            a0 = (a + 1) + sign * (a - 1) * cw + s
            a1 = -sign * 2 * ((a - 1) + sign * (a + 1) * cw)
            a2 = (a + 1) + sign * (a - 1) * cw - s
        }
        var section = Biquad()
        section.b0 = Float(b0 / a0); section.b1 = Float(b1 / a0); section.b2 = Float(b2 / a0)
        section.a1 = Float(a1 / a0); section.a2 = Float(a2 / a0)
        return section
    }
}

/// A five-band stereo equaliser: highpass, low shelf, two bells, high shelf — the channel EQ of
/// a mixing desk. A band at 0 dB (or the highpass at its floor) is skipped, so a flat EQ passes
/// the signal bit for bit.
///
/// Owned by the render thread. Nothing allocates.
public struct ParametricEQ: Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Highpass in Hz; 20 is off.
        public var highpass: Double = 20
        public var lowFrequency: Double = 120
        public var lowGain: Double = 0
        public var lowMidFrequency: Double = 500
        public var lowMidGain: Double = 0
        public var lowMidQ: Double = 1
        public var highMidFrequency: Double = 3_000
        public var highMidGain: Double = 0
        public var highMidQ: Double = 1
        public var highFrequency: Double = 8_000
        public var highGain: Double = 0

        public init() {}

        public static let gainRange: ClosedRange<Double> = -18...18

        public var clamped: Settings {
            var s = self
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            s.highpass = clamp(highpass, 20...1_000, base.highpass)
            s.lowFrequency = clamp(lowFrequency, 30...1_000, base.lowFrequency)
            s.lowGain = clamp(lowGain, Self.gainRange, 0)
            s.lowMidFrequency = clamp(lowMidFrequency, 60...8_000, base.lowMidFrequency)
            s.lowMidGain = clamp(lowMidGain, Self.gainRange, 0)
            s.lowMidQ = clamp(lowMidQ, 0.3...8, base.lowMidQ)
            s.highMidFrequency = clamp(highMidFrequency, 200...16_000, base.highMidFrequency)
            s.highMidGain = clamp(highMidGain, Self.gainRange, 0)
            s.highMidQ = clamp(highMidQ, 0.3...8, base.highMidQ)
            s.highFrequency = clamp(highFrequency, 1_000...18_000, base.highFrequency)
            s.highGain = clamp(highGain, Self.gainRange, 0)
            return s
        }
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
        }
    }

    public let sampleRate: Double
    /// Per band, the left and right sections share coefficients and keep their own state.
    private var left: (Biquad, Biquad, Biquad, Biquad, Biquad)
    private var right: (Biquad, Biquad, Biquad, Biquad, Biquad)
    private var active: (Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false)

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.settings = settings.clamped
        let flat = Biquad()
        left = (flat, flat, flat, flat, flat)
        right = left
        update()
    }

    /// The bands as they are set, for a response curve.
    public var sections: [Biquad] {
        var all: [Biquad] = []
        if active.0 { all.append(left.0) }
        if active.1 { all.append(left.1) }
        if active.2 { all.append(left.2) }
        if active.3 { all.append(left.3) }
        if active.4 { all.append(left.4) }
        return all
    }

    /// The whole EQ's gain at `hz`, in dB.
    public func response(at hz: Double) -> Double {
        sections.reduce(0) { $0 + $1.response(at: hz, sampleRate: sampleRate) }
    }

    private mutating func update() {
        let s = settings, rate = sampleRate
        func set(_ l: inout Biquad, _ r: inout Biquad, _ b: Biquad) {
            (l.b0, l.b1, l.b2, l.a1, l.a2) = (b.b0, b.b1, b.b2, b.a1, b.a2)
            (r.b0, r.b1, r.b2, r.a1, r.a2) = (b.b0, b.b1, b.b2, b.a1, b.a2)
        }
        active = (s.highpass > 20, s.lowGain != 0, s.lowMidGain != 0, s.highMidGain != 0, s.highGain != 0)
        set(&left.0, &right.0, .make(.highpass, hz: s.highpass, gain: 0, q: 0.7071, sampleRate: rate))
        set(&left.1, &right.1, .make(.lowShelf, hz: s.lowFrequency, gain: s.lowGain, q: 0.7071, sampleRate: rate))
        set(&left.2, &right.2, .make(.bell, hz: s.lowMidFrequency, gain: s.lowMidGain, q: s.lowMidQ, sampleRate: rate))
        set(&left.3, &right.3, .make(.bell, hz: s.highMidFrequency, gain: s.highMidGain, q: s.highMidQ, sampleRate: rate))
        set(&left.4, &right.4, .make(.highShelf, hz: s.highFrequency, gain: s.highGain, q: 0.7071, sampleRate: rate))
    }

    public mutating func reset() {
        left.0.reset(); left.1.reset(); left.2.reset(); left.3.reset(); left.4.reset()
        right.0.reset(); right.1.reset(); right.2.reset(); right.3.reset(); right.4.reset()
    }

    /// Processes `frames` samples in place.
    public mutating func process(left l: UnsafeMutablePointer<Float>, right r: UnsafeMutablePointer<Float>, frames: Int) {
        let on = active
        for i in 0..<frames {
            var x = l[i], y = r[i]
            if on.0 { x = left.0.process(x); y = right.0.process(y) }
            if on.1 { x = left.1.process(x); y = right.1.process(y) }
            if on.2 { x = left.2.process(x); y = right.2.process(y) }
            if on.3 { x = left.3.process(x); y = right.3.process(y) }
            if on.4 { x = left.4.process(x); y = right.4.process(y) }
            l[i] = x
            r[i] = y
        }
    }
}

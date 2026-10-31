import Foundation

/// A number typed on Echoel's number pad. The pad is our own and not the system's decimal pad,
/// because that one has no sign key: here − makes the value negative and + positive (a transpose,
/// a pan to the left), and − is disabled where the range cannot go below zero.
///
/// The text is ASCII — digits, at most one ".", an optional leading "-" — whatever the reader's
/// locale shows as its separator; the pad translates for display. Value type, no UI.
public struct NumberEntry: Sendable, Equatable {
    /// Characters the text may hold, sign and separator included.
    public static let maxLength = 9

    public let range: ClosedRange<Double>
    public let decimals: Int
    public private(set) var text = ""

    /// `range` and `decimals` in the units the pad shows (see `NumberEntryFormat`).
    public init(range: ClosedRange<Double>, decimals: Int) {
        self.range = range
        self.decimals = Swift.max(0, decimals)
    }

    public var allowsNegative: Bool { range.lowerBound < 0 }
    public var allowsDecimal: Bool { decimals > 0 }
    public var isEmpty: Bool { text.isEmpty }
    public var isNegative: Bool { text.hasPrefix("-") }

    /// Appends a digit 0…9, unless the text is full or already holds every decimal place. A lone
    /// leading zero is replaced, so "0" then "7" reads "7", not "07".
    public mutating func type(_ digit: Int) {
        guard (0...9).contains(digit), text.count < Self.maxLength else { return }
        if let separator = text.firstIndex(of: ".") {
            guard text.distance(from: separator, to: text.endIndex) - 1 < decimals else { return }
        }
        let body = isNegative ? String(text.dropFirst()) : text
        if body == "0" { text.removeLast() }
        text += String(digit)
    }

    /// Starts the decimal places; "0." when nothing is typed yet.
    public mutating func typeDecimal() {
        guard allowsDecimal, !text.contains("."), text.count < Self.maxLength - 1 else { return }
        let body = isNegative ? String(text.dropFirst()) : text
        text += body.isEmpty ? "0." : "."
    }

    /// − or +. A negative sign is refused where the range has no negative values.
    public mutating func setNegative(_ negative: Bool) {
        let body = isNegative ? String(text.dropFirst()) : text
        text = negative && allowsNegative ? "-" + body : body
    }

    public mutating func deleteLast() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }

    /// Replaces the text with `value`, written to the entry's decimals (the pad's Default key).
    public mutating func show(_ value: Double) {
        guard value.isFinite else { return }
        let snapped = Self.snapped(value, to: range, decimals: decimals)
        text = String(format: "%.\(decimals)f", snapped)
        if text.hasPrefix("-"), Double(text) == 0 { text.removeFirst() }
    }

    /// The typed number on the entry's grid and inside its range; `fallback` when nothing that
    /// reads as a number is typed ("", "-", ".", "-.").
    public func value(else fallback: Double) -> Double {
        // "7." reads as 7: a separator with no places typed after it yet.
        let digits = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard let typed = Double(digits), typed.isFinite else { return fallback }
        return Self.snapped(typed, to: range, decimals: decimals)
    }

    /// `raw` clamped to `range` and rounded to `decimals` places. When rounding pushes it past a
    /// bound that is not itself on the grid, it steps one grid place inward instead.
    public static func snapped(_ raw: Double, to range: ClosedRange<Double>, decimals: Int) -> Double {
        guard raw.isFinite else { return range.lowerBound }
        let places = Swift.max(0, decimals)
        let step = Foundation.pow(10, -Double(places))
        let slack = step * 1e-6
        let inRange = Swift.min(Swift.max(raw, range.lowerBound), range.upperBound)
        let nearest = gridded(inRange, decimals: places)
        if nearest >= range.lowerBound - slack, nearest <= range.upperBound + slack { return nearest }
        let inward = gridded(nearest > range.upperBound ? nearest - step : nearest + step, decimals: places)
        if inward >= range.lowerBound - slack, inward <= range.upperBound + slack { return inward }
        return inRange
    }

    static func gridded(_ raw: Double, decimals: Int) -> Double {
        let factor = Foundation.pow(10, Double(decimals))
        return (raw * factor).rounded() / factor
    }
}

/// How a parameter reads on the number pad: the unit a musician types in, how many decimal
/// places, and the factor from the parameter's own value. A time is typed in milliseconds, a pan
/// in percent (− is left), a frequency in hertz; a named choice is not typed at all (it is a
/// picker), so it has no format.
public struct NumberEntryFormat: Sendable, Equatable {
    /// Pad value = parameter value × `scale`.
    public let scale: Double
    public let decimals: Int
    /// Shown after the number; empty for a plain amount.
    public let unit: String

    public init(scale: Double, decimals: Int, unit: String) {
        self.scale = scale.isFinite && scale != 0 ? scale : 1
        self.decimals = Swift.max(0, decimals)
        self.unit = unit
    }

    /// The format for `descriptor`, nil for a named choice.
    public init?(_ descriptor: ParameterDescriptor) {
        let span = descriptor.range.upperBound - descriptor.range.lowerBound
        switch descriptor.unit {
        case .choice:
            return nil
        case .decibel:
            self.init(scale: 1, decimals: 1, unit: "dB")
        case .pan:
            self.init(scale: 100, decimals: 0, unit: "%")
        case .bpm:
            // To the hundredth, as Ableton types a tempo (100.25).
            self.init(scale: 1, decimals: 2, unit: "BPM")
        case .hertz:
            self.init(scale: 1, decimals: descriptor.range.upperBound <= 1_000 ? 1 : 0, unit: "Hz")
        case .seconds:
            self.init(scale: 1_000, decimals: span * 1_000 < 100 ? 1 : 0, unit: "ms")
        case .octaves:
            self.init(scale: 1, decimals: 2, unit: "oct")
        case .amount:
            self.init(scale: 1, decimals: descriptor.taper == .stepped ? 0 : 2, unit: "")
        }
    }

    public func display(_ value: Double) -> Double { value * scale }

    public func parameter(fromDisplay value: Double) -> Double { value / scale }

    public func displayRange(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        let low = display(range.lowerBound), high = display(range.upperBound)
        return Swift.min(low, high)...Swift.max(low, high)
    }

    /// An empty entry over `range` (the parameter's own), in pad units.
    public func entry(for range: ClosedRange<Double>) -> NumberEntry {
        NumberEntry(range: displayRange(range), decimals: decimals)
    }
}

/// How finely a drag moves a value: slow travel is fine adjustment, fast travel covers the range.
/// Below `fineSpeed` points per second the drag moves `fineScale` of its distance; above
/// `fullSpeed`, all of it; in between, a straight blend — so a musician gets precision by slowing
/// down, without a modifier key a phone does not have.
public enum DragPrecision {
    public static let fineSpeed: Double = 60
    public static let fullSpeed: Double = 320
    public static let fineScale: Double = 0.22

    public static func scale(speed: Double) -> Double {
        guard speed.isFinite else { return 1 }
        let pace = abs(speed)
        if pace <= fineSpeed { return fineScale }
        if pace >= fullSpeed { return 1 }
        return fineScale + (1 - fineScale) * (pace - fineSpeed) / (fullSpeed - fineSpeed)
    }

    /// True when a drag from `old` to `new` reaches a place worth a tick under the finger: an end
    /// of the range, or the default (landing on it or crossing it). Leaving the default is not.
    public static func reachesDetent(from old: Double, to new: Double, standard: Double?,
                                     range: ClosedRange<Double>) -> Bool {
        guard old.isFinite, new.isFinite, old != new else { return false }
        if new == range.lowerBound || new == range.upperBound { return true }
        guard let standard, standard.isFinite else { return false }
        if new == standard { return true }
        if old == standard { return false }
        return (old < standard) != (new < standard)
    }
}

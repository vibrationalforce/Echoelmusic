import Foundation

/// A ratio of two whole numbers in lowest terms with a positive denominator: the form in which the
/// app keeps a value it shows without rounding (2026-11-27: every time, rate and frequency exact —
/// in seconds, hertz and note values, never rounded up or down). A tempo as typed, a sample rate, a
/// note value and every product and quotient of them stay ratios: a half-note triplet at 150 BPM is
/// 8/15 s, not 0.5333333333333333, and `ExactText` writes it 0,53̅ s.
///
/// Arithmetic that would leave `Int64` gives nil instead of a wrong value; a caller then shows the
/// approximate value, marked as approximate (`ExactText(approximately:)`).
public struct Rational: Hashable, Sendable {
    public let numerator: Int64
    public let denominator: Int64

    /// The ratio in lowest terms. nil for a zero denominator, and for `Int64.min` on either side
    /// (its magnitude is no `Int64`).
    public init?(numerator: Int64, denominator: Int64) {
        guard denominator != 0, numerator != .min, denominator != .min else { return nil }
        let divisor = Rational.greatestCommonDivisor(Swift.abs(numerator), Swift.abs(denominator))
        let sign: Int64 = denominator < 0 ? -1 : 1
        self.numerator = sign * (numerator / divisor)
        self.denominator = sign * (denominator / divisor)
    }

    /// The exact value of a decimal written with a point — "132", "132.5", "-0.25", "1e-05",
    /// "4.4E+4", the forms a `Double` prints. nil for anything else, and for a value with more
    /// digits than `Int64` holds.
    public init?(decimal text: String) {
        var rest = Substring(text)
        var negative = false
        if rest.first == "-" {
            negative = true
            rest = rest.dropFirst()
        } else if rest.first == "+" {
            rest = rest.dropFirst()
        }
        var exponent = 0
        if let mark = rest.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            guard let power = Int(rest[rest.index(after: mark)...]) else { return nil }
            exponent = power
            rest = rest[..<mark]
        }
        let parts = rest.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        let wholePart = parts[0]
        let fractionPart = parts.count == 2 ? parts[1] : Substring("")
        guard !wholePart.isEmpty || !fractionPart.isEmpty else { return nil }
        var digits: Int64 = 0
        for character in wholePart + fractionPart {
            guard character.isASCII, let digit = character.wholeNumberValue else { return nil }
            let (shifted, shiftOverflow) = digits.multipliedReportingOverflow(by: 10)
            let (added, addOverflow) = shifted.addingReportingOverflow(Int64(digit))
            guard !shiftOverflow, !addOverflow else { return nil }
            digits = added
        }
        let scale = fractionPart.count - exponent
        guard let power = Rational.powerOfTen(Swift.abs(scale)) else { return nil }
        let signed = negative ? -digits : digits
        if scale >= 0 {
            self.init(numerator: signed, denominator: power)
        } else {
            let (scaled, overflow) = signed.multipliedReportingOverflow(by: power)
            guard !overflow else { return nil }
            self.init(numerator: scaled, denominator: 1)
        }
    }

    /// The value a `Double` prints as, exactly: 132.1 is 1321/10 — the decimal that was typed, not
    /// the binary fraction nearest to it. nil for a value that is not finite, or that needs more
    /// digits than `Int64` holds.
    public init?(roundTripping value: Double) {
        guard value.isFinite else { return nil }
        self.init(decimal: "\(value)")
    }

    /// The ratio a stored `Double` stands for: the simplest ratio, denominator at most
    /// `maxDenominator`, whose `Double` is exactly this one — 1/6 for 0.16666666666666666, 20/11 for
    /// 60 / 132 × 4 — else the decimal it prints. A value computed from a tempo and a note value
    /// thus reads as the ratio it is (166,6̅ ms), not as the binary fraction that holds it. nil for a
    /// value that is not finite.
    public init?(stored value: Double, maxDenominator: Int64 = 1_000_000) {
        guard let ratio = Rational.simplest(for: value, maxDenominator: maxDenominator)
            ?? Rational(roundTripping: value) else { return nil }
        self = ratio
    }

    /// The first continued-fraction convergent of `value` whose `Double` equals `value` exactly.
    static func simplest(for value: Double, maxDenominator: Int64) -> Rational? {
        guard value.isFinite else { return nil }
        let negative = value < 0
        let target = Swift.abs(value)
        var (previousTop, top): (Int64, Int64) = (0, 1)
        var (previousBottom, bottom): (Int64, Int64) = (1, 0)
        var rest = target
        for _ in 0..<48 {
            let whole = rest.rounded(.down)
            guard whole < 9.0e18 else { return nil }
            let term = Int64(whole)
            let (scaledTop, topOverflow) = term.multipliedReportingOverflow(by: top)
            let (nextTop, nextTopOverflow) = scaledTop.addingReportingOverflow(previousTop)
            let (scaledBottom, bottomOverflow) = term.multipliedReportingOverflow(by: bottom)
            let (nextBottom, nextBottomOverflow) = scaledBottom.addingReportingOverflow(previousBottom)
            guard !topOverflow, !nextTopOverflow, !bottomOverflow, !nextBottomOverflow,
                  nextBottom <= maxDenominator else { return nil }
            if Double(nextTop) / Double(nextBottom) == target {
                return Rational(numerator: negative ? -nextTop : nextTop, denominator: nextBottom)
            }
            (previousTop, top) = (top, nextTop)
            (previousBottom, bottom) = (bottom, nextBottom)
            let fraction = rest - whole
            guard fraction > 0 else { return nil }
            rest = 1 / fraction
        }
        return nil
    }

    public static let zero: Rational = 0
    public static let one: Rational = 1

    /// `numerator`/`denominator` for a known positive denominator — the note tables' constants. A
    /// zero denominator gives zero; no caller passes one.
    static func constant(_ numerator: Int64, _ denominator: Int64) -> Rational {
        Rational(numerator: numerator, denominator: denominator) ?? .zero
    }

    public var doubleValue: Double { Double(numerator) / Double(denominator) }
    public var isWhole: Bool { denominator == 1 }
    public var isZero: Bool { numerator == 0 }
    public var isNegative: Bool { numerator < 0 }

    public func adding(_ other: Rational) -> Rational? {
        let divisor = Rational.greatestCommonDivisor(denominator, other.denominator)
        let (left, leftOverflow) = numerator.multipliedReportingOverflow(by: other.denominator / divisor)
        let (right, rightOverflow) = other.numerator.multipliedReportingOverflow(by: denominator / divisor)
        let (sum, sumOverflow) = left.addingReportingOverflow(right)
        let (common, commonOverflow) = (denominator / divisor).multipliedReportingOverflow(by: other.denominator)
        guard !leftOverflow, !rightOverflow, !sumOverflow, !commonOverflow else { return nil }
        return Rational(numerator: sum, denominator: common)
    }

    public func subtracting(_ other: Rational) -> Rational? {
        guard let negated = Rational(numerator: -other.numerator, denominator: other.denominator) else { return nil }
        return adding(negated)
    }

    public func multiplied(by other: Rational) -> Rational? {
        let first = Rational.greatestCommonDivisor(Swift.abs(numerator), other.denominator)
        let second = Rational.greatestCommonDivisor(Swift.abs(other.numerator), denominator)
        let (top, topOverflow) = (numerator / first).multipliedReportingOverflow(by: other.numerator / second)
        let (bottom, bottomOverflow) = (denominator / second).multipliedReportingOverflow(by: other.denominator / first)
        guard !topOverflow, !bottomOverflow else { return nil }
        return Rational(numerator: top, denominator: bottom)
    }

    /// nil for a division by zero, as for an overflow.
    public func divided(by other: Rational) -> Rational? {
        guard let reciprocal = other.reciprocal else { return nil }
        return multiplied(by: reciprocal)
    }

    /// 1 divided by the value; nil for zero.
    public var reciprocal: Rational? { Rational(numerator: denominator, denominator: numerator) }

    static func greatestCommonDivisor(_ first: Int64, _ second: Int64) -> Int64 {
        var (larger, smaller) = (first, second)
        while smaller != 0 { (larger, smaller) = (smaller, larger % smaller) }
        return larger == 0 ? 1 : larger
    }

    /// 10 to the power `exponent`, for 0…18; nil beyond what `Int64` holds.
    static func powerOfTen(_ exponent: Int) -> Int64? {
        guard (0...18).contains(exponent) else { return nil }
        var power: Int64 = 1
        for _ in 0..<exponent { power *= 10 }
        return power
    }
}

extension Rational: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        numerator = value
        denominator = 1
    }
}

extension Rational: Comparable {
    /// Exact: both cross products are compared at 128 bits, so no ratio is too large to order.
    public static func < (lhs: Rational, rhs: Rational) -> Bool {
        let left = lhs.numerator.multipliedFullWidth(by: rhs.denominator)
        let right = rhs.numerator.multipliedFullWidth(by: lhs.denominator)
        return left.high != right.high ? left.high < right.high : left.low < right.low
    }
}

extension Rational: CustomStringConvertible {
    public var description: String { isWhole ? "\(numerator)" : "\(numerator)/\(denominator)" }
}

/// A ratio written out in decimal: the whole part, the digits after the point that come once, and
/// the group that repeats for ever — empty when the decimal ends. 8/15 is 0.5 and then 3 repeating;
/// 20/11 is 1. and then 81 repeating; 8/5 is 1.6 and ends.
public struct DecimalDigits: Equatable, Sendable {
    public let isNegative: Bool
    /// The whole part's digits, "0" for a value under one.
    public let whole: String
    /// The digits after the point before the repeating group.
    public let fixed: String
    /// The group that repeats for ever; empty when the decimal ends.
    public let repeating: String
    /// False when the repeating group did not show within the digit limit: `fixed` then holds the
    /// first digits only, and every text made of it ends in "…".
    public let isComplete: Bool

    public init(isNegative: Bool, whole: String, fixed: String, repeating: String, isComplete: Bool) {
        self.isNegative = isNegative
        self.whole = whole
        self.fixed = fixed
        self.repeating = repeating
        self.isComplete = isComplete
    }
}

extension Rational {
    /// The decimal by long division, with at most `limit` digits after the point: 8/15 needs two,
    /// 1/7 six, 1/97 ninety-six. A remainder that comes back marks where the repeating group starts.
    public func decimalDigits(limit: Int = 64) -> DecimalDigits {
        let negative = numerator < 0
        let magnitude = numerator.magnitude
        let divisor = UInt64(denominator)
        let whole = String(magnitude / divisor)
        var remainder = magnitude % divisor
        var digits: [Character] = []
        var seen: [UInt64: Int] = [:]
        while remainder != 0 {
            if let start = seen[remainder] {
                return DecimalDigits(isNegative: negative, whole: whole, fixed: String(digits[..<start]),
                                     repeating: String(digits[start...]), isComplete: true)
            }
            let (shifted, overflow) = remainder.multipliedReportingOverflow(by: 10)
            guard digits.count < limit, !overflow else {
                return DecimalDigits(isNegative: negative, whole: whole, fixed: String(digits), repeating: "",
                                     isComplete: false)
            }
            seen[remainder] = digits.count
            digits.append(Character(String(shifted / divisor)))
            remainder = shifted % divisor
        }
        return DecimalDigits(isNegative: negative, whole: whole, fixed: String(digits), repeating: "", isComplete: true)
    }
}

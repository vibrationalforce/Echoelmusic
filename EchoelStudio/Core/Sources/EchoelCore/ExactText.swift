import Foundation

/// The decimal mark the reader's region writes: "1,6" in German, "1.6" in English. No thousands
/// mark, like every number on screen (`NumberText`: a tempo of 1200 is "1200").
public struct NumberMarks: Equatable, Sendable {
    public let decimal: String

    public init(decimal: String) {
        self.decimal = decimal
    }

    public init(locale: Locale) {
        decimal = locale.decimalSeparator ?? "."
    }

    public static let point = NumberMarks(decimal: ".")
    public static let comma = NumberMarks(decimal: ",")
}

/// A value as text, never rounded (2026-11-27). `full` keeps every digit: a repeating group carries
/// a bar over each of its digits (0,53̅ — the 3 repeats for ever), and only a value whose digits
/// never end, or end past the digit limit, closes with "…". `compact` keeps at most a given number
/// of significant digits and ends in "…" whenever it left digits out, so a shortened value never
/// passes for a whole one; the full value is one long press away. `spoken` is the full value for
/// VoiceOver, with the repeating group said in words, because a bar is not read aloud.
public struct ExactText: Equatable, Sendable {
    public let full: String
    public let compact: String
    public let spoken: String

    /// True when `compact` leaves digits out.
    public var isShortened: Bool { compact != full }

    /// The bar over a repeating digit: COMBINING OVERLINE.
    public static let repeatMark = "\u{0305}"
    /// The mark for digits left out.
    public static let more = "…"
    /// The minus sign numbers on screen use (−∞ dB).
    public static let minus = "\u{2212}"
    /// Significant digits a compact value keeps, unless the whole part alone has more.
    public static let compactDigits = 6

    public init(full: String, compact: String, spoken: String) {
        self.full = full
        self.compact = compact
        self.spoken = spoken
    }

    /// `value`, exactly.
    public init(_ value: Rational, marks: NumberMarks, compactDigits: Int = ExactText.compactDigits) {
        self.init(digits: value.decimalDigits(), marks: marks, compactDigits: compactDigits)
    }

    /// A value that is no ratio of whole numbers (an equal-tempered pitch, 2^(n/12)), or one whose
    /// ratio would not fit: every digit the `Double` holds, then "…", because its digits go on.
    /// "–" for a value that is not a number.
    public init(approximately value: Double, marks: NumberMarks, compactDigits: Int = ExactText.compactDigits) {
        guard value.isFinite, let ratio = Rational(roundTripping: value) else {
            self.init(full: "–", compact: "–", spoken: "no value")
            return
        }
        let digits = ratio.decimalDigits()
        let open = DecimalDigits(isNegative: digits.isNegative, whole: digits.whole,
                                 fixed: digits.fixed + digits.repeating, repeating: "", isComplete: false)
        self.init(digits: open, marks: marks, compactDigits: compactDigits)
    }

    public init(digits: DecimalDigits, marks: NumberMarks, compactDigits: Int = ExactText.compactDigits) {
        let sign = digits.isNegative ? ExactText.minus : ""
        let marked = digits.repeating.map { "\($0)\(ExactText.repeatMark)" }.joined()
        let fraction = digits.fixed + marked
        let tail = digits.isComplete ? "" : ExactText.more
        let full = sign + digits.whole + (fraction.isEmpty ? "" : marks.decimal + fraction) + tail

        // "0.53, the last digit repeating": the digits once, then which of them repeat.
        let afterPoint = digits.fixed + digits.repeating
        var spoken = (digits.isNegative ? "minus " : "") + digits.whole
        if !afterPoint.isEmpty { spoken += marks.decimal + afterPoint }
        switch digits.repeating.count {
        case 0: break
        case 1: spoken += ", the last digit repeating"
        default: spoken += ", the last \(digits.repeating.count) digits repeating"
        }
        if !digits.isComplete { spoken += ", continuing" }

        self.init(full: full,
                  compact: ExactText.compact(digits, sign: sign, marks: marks, limit: compactDigits, full: full),
                  spoken: spoken)
    }

    /// The whole part always stays; after the point, digits until `limit` significant digits are
    /// shown (zeros right after the point of a value under one do not count). When everything fits,
    /// the full text, bars and all; otherwise the digits shown, without bars, then "…".
    private static func compact(_ digits: DecimalDigits, sign: String, marks: NumberMarks, limit: Int,
                                full: String) -> String {
        let afterPoint = digits.fixed + digits.repeating
        var budget = Swift.max(0, limit - (digits.whole == "0" ? 0 : digits.whole.count))
        var shown = ""
        var leading = digits.whole == "0"
        for digit in afterPoint {
            if leading, digit == "0" {
                shown.append(digit)
                continue
            }
            leading = false
            guard budget > 0 else { break }
            shown.append(digit)
            budget -= 1
        }
        if shown.count == afterPoint.count, digits.isComplete { return full }
        return sign + digits.whole + (shown.isEmpty ? "" : marks.decimal + shown) + ExactText.more
    }
}

/// A value and its unit, exactly, in the unit that reads best — the rule every time and rate on
/// screen follows (2026-11-27).
public enum ExactUnits {
    /// Seconds below one read in milliseconds ("533,3̅ ms"), one and above in seconds ("1,6 s").
    public static func time(_ seconds: Rational, marks: NumberMarks) -> (text: ExactText, unit: String) {
        if seconds.numerator.magnitude < UInt64(seconds.denominator), let milliseconds = seconds.multiplied(by: 1_000) {
            return (ExactText(milliseconds, marks: marks), "ms")
        }
        return (ExactText(seconds, marks: marks), "s")
    }

    /// Hertz from one thousand on read in kilohertz ("1,875 Hz", "2,5 kHz").
    public static func rate(_ hertz: Rational, marks: NumberMarks) -> (text: ExactText, unit: String) {
        if hertz >= 1_000, let kilohertz = hertz.divided(by: 1_000) {
            return (ExactText(kilohertz, marks: marks), "kHz")
        }
        return (ExactText(hertz, marks: marks), "Hz")
    }
}

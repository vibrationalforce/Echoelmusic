import Foundation

/// How a parameter's value reads, exactly (2026-11-27: every time, rate and frequency in seconds,
/// hertz and note value, never rounded up or down; compact only where room is short, then marked).
/// A moved control writes on the grid the field shows (`ParameterDescriptor.movedValue`), so the
/// text is every digit the song holds; a value the musician typed reads as typed, and a value made
/// from a tempo and a note value reads as the ratio it is (`Rational(stored:)`).
public enum ParameterText {
    /// A value and its unit, as one text.
    public struct UnitText: Equatable, Sendable {
        public let text: ExactText
        public let unit: String

        public init(text: ExactText, unit: String) {
            self.text = text
            self.unit = unit
        }

        public var compact: String { text.compact + (unit.isEmpty ? "" : " " + unit) }
        public var full: String { text.full + (unit.isEmpty ? "" : " " + unit) }
        /// The full value with its unit in words, as VoiceOver reads it.
        public var spoken: String { text.spoken + (unit.isEmpty ? "" : " " + ExactUnits.spoken(unit)) }
    }

    /// The note value a time lasts: `isExact` when it is that note to the last digit, else near it
    /// within one percent (`TempoNote.tolerance`).
    public struct NoteMatch: Equatable, Sendable {
        public let note: NoteValue
        public let isExact: Bool

        /// "1/8 dotted", or "≈ 1/8 dotted" when the time is near it, not on it.
        public var name: String { isExact ? note.name : "≈ " + note.name }
    }

    /// The value in the unit that reads best: a time below one second in ms, a frequency from
    /// 1000 Hz in kHz, a tempo in BPM, octaves in oct, a level in dB, an amount bare. nil for a pan
    /// and a named choice, which read in their own words.
    public static func value(_ value: Double, unit: ParameterUnit, marks: NumberMarks) -> UnitText? {
        guard let ratio = Rational(stored: value) else { return printed(value, unit: unit, marks: marks) }
        switch unit {
        case .seconds:
            let time = ExactUnits.time(ratio, marks: marks)
            return UnitText(text: time.text, unit: time.unit)
        case .hertz:
            let rate = ExactUnits.rate(ratio, marks: marks)
            return UnitText(text: rate.text, unit: rate.unit)
        case .bpm: return UnitText(text: ExactText(ratio, marks: marks), unit: "BPM")
        case .octaves: return UnitText(text: ExactText(ratio, marks: marks), unit: "oct")
        case .decibel: return UnitText(text: ExactText(ratio, marks: marks), unit: "dB")
        case .amount: return UnitText(text: ExactText(ratio, marks: marks), unit: "")
        case .pan, .choice: return nil
        }
    }

    /// A stored value no ratio of `Int64` holds — a drag an earlier build saved, 0.0012345678901234567
    /// s — read as the digits it prints, in the same unit as `value(_:unit:marks:)` would choose.
    static func printed(_ value: Double, unit: ParameterUnit, marks: NumberMarks) -> UnitText? {
        guard value.isFinite else { return nil }
        switch unit {
        case .seconds where Swift.abs(value) < 1:
            return UnitText(text: ExactText(printed: value * 1_000, marks: marks), unit: "ms")
        case .seconds: return UnitText(text: ExactText(printed: value, marks: marks), unit: "s")
        case .hertz where Swift.abs(value) >= 1_000:
            return UnitText(text: ExactText(printed: value / 1_000, marks: marks), unit: "kHz")
        case .hertz: return UnitText(text: ExactText(printed: value, marks: marks), unit: "Hz")
        case .bpm: return UnitText(text: ExactText(printed: value, marks: marks), unit: "BPM")
        case .octaves: return UnitText(text: ExactText(printed: value, marks: marks), unit: "oct")
        case .decibel: return UnitText(text: ExactText(printed: value, marks: marks), unit: "dB")
        case .amount: return UnitText(text: ExactText(printed: value, marks: marks), unit: "")
        case .pan, .choice: return nil
        }
    }

    /// The note value `seconds` lasts at `bpm`; nil when it is within one percent of none.
    public static func noteValue(ofSeconds seconds: Rational, bpm: Rational) -> NoteMatch? {
        guard seconds > .zero, bpm > .zero,
              let quarters = seconds.multiplied(by: bpm)?.divided(by: 60) else { return nil }
        if let exact = NoteValue.all.first(where: { $0.quarters == quarters }) {
            return NoteMatch(note: exact, isExact: true)
        }
        let played = quarters.doubleValue
        guard let near = NoteValue.all.first(where: { note in
            let length = note.quarters.doubleValue
            return Swift.abs(played - length) <= length * TempoNote.tolerance
        }) else { return nil }
        return NoteMatch(note: near, isExact: false)
    }

    /// A time or a slow rate in the calculator's other two forms: a time as a rate and a note value
    /// at `bpm`; a rate up to 40 Hz as a time and a note value. Above 40 Hz a frequency is a pitch,
    /// not a rhythm, and both are nil; so they are for a value that is not a positive number.
    public static func companions(_ value: Double, unit: ParameterUnit, bpm: Double,
                                  marks: NumberMarks) -> (other: UnitText?, note: NoteMatch?) {
        guard let ratio = Rational(stored: value), ratio > .zero else { return (nil, nil) }
        let tempo = Rational(stored: bpm)
        switch unit {
        case .seconds:
            let rate = TempoCalculator.hertz(ofSeconds: ratio).map { hertz in
                let shown = ExactUnits.rate(hertz, marks: marks)
                return UnitText(text: shown.text, unit: shown.unit)
            }
            return (rate, tempo.flatMap { noteValue(ofSeconds: ratio, bpm: $0) })
        case .hertz where value <= 40:
            guard let period = ratio.reciprocal else { return (nil, nil) }
            let time = ExactUnits.time(period, marks: marks)
            return (UnitText(text: time.text, unit: time.unit), tempo.flatMap { noteValue(ofSeconds: period, bpm: $0) })
        default:
            return (nil, nil)
        }
    }
}

extension ParameterDescriptor {
    /// Significant digits a moved control writes for a time, a frequency, an octave count or a tempo.
    public static let movedDigits = 4

    /// `value(forNormalized:)` as a dragged, swiped or MIDI-moved control writes it (2026-11-27): on
    /// the grid its field shows, so the value stored is the value read, every digit of it — a time,
    /// a frequency, an octave count or a tempo to four significant digits (375,1 ms, 1234 Hz), a
    /// level to a tenth of a decibel, a pan or an amount to a hundredth. A typed value is stored as
    /// typed; the range's ends and a stepped value stay as they are.
    ///
    /// A plugin parameter is a position along the unit's own travel, not a value in a unit: it is
    /// never snapped here (its unit's field snaps in its own unit before it becomes a position).
    public func movedValue(forNormalized position: Double) -> Double {
        let raw = value(forNormalized: position)
        guard address.key.pluginParameter == nil else { return raw }
        guard raw.isFinite, raw > range.lowerBound, raw < range.upperBound, taper != .stepped else { return raw }
        let snapped: Double
        switch unit {
        case .seconds, .hertz, .octaves, .bpm:
            snapped = ParameterDescriptor.significant(raw, digits: ParameterDescriptor.movedDigits)
        case .decibel:
            snapped = (raw * 10).rounded() / 10
        case .pan, .amount:
            snapped = (raw * 100).rounded() / 100
        case .choice:
            snapped = raw
        }
        return Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
    }

    /// `value` kept to `digits` significant digits: 0.0123456 to 4 is 0.01235, 12345 is 12350.
    public static func significant(_ value: Double, digits: Int) -> Double {
        guard value.isFinite, value != 0 else { return value }
        let exponent = Int(Foundation.floor(Foundation.log10(Swift.abs(value))))
        let shift = digits - 1 - exponent
        if shift >= 0 {
            let scale = Foundation.pow(10, Double(shift))
            return (value * scale).rounded() / scale
        }
        let scale = Foundation.pow(10, Double(-shift))
        return (value / scale).rounded() * scale
    }
}

/// A value a unit holds as a `Float` (Echoel's effects keep their parameters as `AUValue`), read
/// within its own precision (2026-11-27, audit G2): the shortest decimal among the Floats a few units
/// of the last place around it, so 0.6 reads 0,6 and −6 reads −6 — not 0,6000000238418579, which is the
/// binary residue a Float carries into a Double, and not the one or two last-place steps the unit's
/// position path adds. A Float holds about seven significant digits; nothing finer is in it.
public enum FloatReading {
    /// Last-place steps to either side that a value set through its position may stray.
    public static let steps = 8

    public static func value(_ float: Float) -> Double {
        guard float.isFinite else { return Double(float) }
        var best = float
        var bestDigits = significantDigits(float)
        var below = float, above = float
        for _ in 0..<steps {
            below = below.nextDown
            above = above.nextUp
            for candidate in [below, above] where candidate.isFinite {
                let digits = significantDigits(candidate)
                if digits < bestDigits {
                    best = candidate
                    bestDigits = digits
                }
            }
        }
        return Double("\(best)") ?? Double(best)
    }

    /// The significant digits a Float prints: "0.6" has one, "-5.9999995" eight.
    static func significantDigits(_ float: Float) -> Int {
        var text = "\(float)"
        if let mark = text.firstIndex(where: { $0 == "e" || $0 == "E" }) { text = String(text[..<mark]) }
        let digits = text.filter(\.isNumber).drop { $0 == "0" }
        return String(digits.reversed()).drop { $0 == "0" }.count
    }
}

import Foundation

/// How a time and a slow rate read on their fields (2026-11-27): as a note value at the song's
/// tempo by default, or in seconds, milliseconds or hertz on the musician's choice. A setting of the
/// device, never stored in a song. Every form shows exactly what the song holds; where the field
/// shows a note value, the time in its unit stands beside it, so no digit is ever hidden.
public enum TimeReading: String, CaseIterable, Sendable {
    case noteValue, seconds, milliseconds, hertz

    /// What a field shows before the musician chooses.
    public static let standard: TimeReading = .noteValue

    /// The name the choice carries in a menu.
    public var title: String {
        switch self {
        case .noteValue: "Note Value"
        case .seconds: "Seconds"
        case .milliseconds: "Milliseconds"
        case .hertz: "Hertz"
        }
    }
}

extension ParameterText {
    /// A time or a slow rate in the form a field shows (`TimeReading`), and its other forms beside
    /// it, compact, full and spoken: the main text, then the rest in the order the field lists them.
    public struct RhythmText: Equatable, Sendable {
        /// What the field shows large: "1/8 dotted", "≈ 1/8 dotted", "375 ms", "2,6̅ Hz".
        public let main: String
        /// The main text with every digit, for the long press.
        public let mainFull: String
        /// The main text as VoiceOver reads it.
        public let mainSpoken: String
        /// The other forms, compact: the field's small line.
        public let others: [String]
        /// The other forms with every digit.
        public let othersFull: [String]
        /// The other forms as VoiceOver reads them.
        public let othersSpoken: [String]
    }

    /// The highest rate that still reads as a rhythm: above it a frequency is a pitch.
    public static let rhythmCeiling = 40.0

    /// Whether `value` in `unit` reads as a rhythm: any positive time, or a positive rate up to
    /// `rhythmCeiling`.
    public static func isRhythm(_ value: Double, unit: ParameterUnit) -> Bool {
        guard value.isFinite, value > 0 else { return false }
        switch unit {
        case .seconds: return true
        case .hertz: return value <= rhythmCeiling
        default: return false
        }
    }

    /// `value` (a time in seconds or a rate in hertz) as `reading` shows it at `bpm`; nil for a value
    /// that is no rhythm (`isRhythm`). With `.noteValue`, a time that lies on no note value — an
    /// attack of 3 ms — shows in its own unit, so the main text never pretends.
    public static func rhythm(_ value: Double, unit: ParameterUnit, bpm: Double, reading: TimeReading,
                              marks: NumberMarks) -> RhythmText? {
        guard isRhythm(value, unit: unit), let stored = Rational(stored: value), stored > .zero else { return nil }
        let seconds: Rational
        let hertz: Rational
        switch unit {
        case .seconds:
            seconds = stored
            guard let rate = TempoCalculator.hertz(ofSeconds: stored) else { return nil }
            hertz = rate
        default:
            hertz = stored
            guard let period = stored.reciprocal else { return nil }
            seconds = period
        }
        let note = Rational(stored: bpm).flatMap { noteValue(ofSeconds: seconds, bpm: $0) }
        let time = UnitText(ExactUnits.time(seconds, marks: marks))
        let rate = UnitText(ExactUnits.rate(hertz, marks: marks))
        // The unit the parameter itself is in, and its partner.
        let own = unit == .seconds ? time : rate
        let partner = unit == .seconds ? rate : time
        let main: UnitText?
        var others: [UnitText] = []
        var noteBeside = note
        switch reading {
        case .noteValue:
            if note != nil {
                main = nil
                others = [own, partner]
                noteBeside = nil
            } else {
                main = own
                others = [partner]
            }
        case .seconds:
            main = UnitText(text: ExactText(seconds, marks: marks), unit: "s")
            others = [rate]
        case .milliseconds:
            main = seconds.multiplied(by: 1_000).map { UnitText(text: ExactText($0, marks: marks), unit: "ms") }
            others = [rate]
        case .hertz:
            main = rate
            others = [time]
        }
        let noteName = noteBeside?.name
        if let main {
            return RhythmText(main: main.compact, mainFull: main.full, mainSpoken: main.spoken,
                              others: others.map(\.compact) + [noteName].compactMap { $0 },
                              othersFull: others.map(\.full) + [noteName].compactMap { $0 },
                              othersSpoken: others.map(\.spoken) + [noteName].compactMap { $0 })
        }
        guard let note else { return nil }
        return RhythmText(main: note.name, mainFull: note.name, mainSpoken: note.name,
                          others: others.map(\.compact), othersFull: others.map(\.full), othersSpoken: others.map(\.spoken))
    }

    /// Every note value that fits in `range` at `bpm`, as the value the parameter stores (seconds
    /// for a time, hertz for a rate), shortest time first. Empty for a unit that is no rhythm or a
    /// tempo that is no positive number.
    public static func noteGrid(unit: ParameterUnit, range: ClosedRange<Double>, bpm: Double) -> [(note: NoteValue, value: Double)] {
        guard unit == .seconds || unit == .hertz, let tempo = Rational(stored: bpm), tempo > .zero else { return [] }
        var grid: [(note: NoteValue, value: Double)] = []
        for note in NoteValue.all {
            guard let seconds = note.quarters.multiplied(by: 60)?.divided(by: tempo) else { continue }
            let stored: Rational?
            switch unit {
            case .seconds: stored = seconds
            default: stored = seconds.reciprocal
            }
            guard let stored else { continue }
            let value = stored.doubleValue
            guard range.contains(value), unit == .seconds || value <= rhythmCeiling else { continue }
            grid.append((note, value))
        }
        return grid.sorted { (first: (note: NoteValue, value: Double), second: (note: NoteValue, value: Double)) -> Bool in
            unit == .seconds ? first.value < second.value : first.value > second.value
        }
    }

    /// The note value nearest `value` (by ratio, so 1/8 and 1/4 are as far apart at any tempo), as
    /// the parameter stores it; nil when no note value fits the range. What a moved rhythmic
    /// control writes while the field reads note values.
    public static func nearestNote(to value: Double, unit: ParameterUnit, range: ClosedRange<Double>,
                                   bpm: Double) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        let grid = noteGrid(unit: unit, range: range, bpm: bpm)
        return grid.min { (first: (note: NoteValue, value: Double), second: (note: NoteValue, value: Double)) -> Bool in
            Swift.abs(Foundation.log(first.value / value)) < Swift.abs(Foundation.log(second.value / value))
        }?.value
    }
}

extension ParameterDescriptor {
    /// Whether a moved control lands on note values while times read as note values: a rate that
    /// keeps time with the song (the texture engine's evolve rate). An envelope's time is no
    /// rhythm to snap: its field still reads a note value where one fits, and its long press sets
    /// one exactly.
    public var isRhythmic: Bool { address.key == SynthParameter.Name.textureRate.parameter.key }
}

extension ParameterText.UnitText {
    /// A time or a rate as `ExactUnits` writes it.
    init(_ form: (text: ExactText, unit: String)) {
        self.init(text: form.text, unit: form.unit)
    }
}

import Foundation

/// A note value as the tempo calculator lists it: 1/1 to 1/64, straight, dotted or triplet.
public struct NoteValue: Hashable, Sendable {
    public enum Feel: String, CaseIterable, Sendable {
        case straight, dotted, triplet
    }

    /// The written value: 1, 2, 4, 8, 16, 32 or 64.
    public let denominator: Int
    public let feel: Feel

    public static let denominators = [1, 2, 4, 8, 16, 32, 64]

    public init?(denominator: Int, feel: Feel = .straight) {
        guard NoteValue.denominators.contains(denominator) else { return nil }
        self.denominator = denominator
        self.feel = feel
    }

    /// Length in quarter notes, exact: a dotted eighth is 3/4, an eighth triplet 1/3.
    public var quarters: Rational {
        switch feel {
        case .straight: Rational.constant(4, Int64(denominator))
        case .dotted: Rational.constant(6, Int64(denominator))
        case .triplet: Rational.constant(8, 3 * Int64(denominator))
        }
    }

    /// "1/8", "1/8 dotted", "1/8 triplet" — the names `TempoNote` gives.
    public var name: String {
        switch feel {
        case .straight: "1/\(denominator)"
        case .dotted: "1/\(denominator) dotted"
        case .triplet: "1/\(denominator) triplet"
        }
    }

    /// Every note value: 1/1, 1/1 dotted, 1/1 triplet, 1/2 … 1/64 triplet.
    public static let all: [NoteValue] = denominators.flatMap { denominator in
        Feel.allCases.compactMap { NoteValue(denominator: denominator, feel: $0) }
    }
}

/// The tempo calculator (2026-11-27; the earlier app's studio calculator, exact this time): at a
/// tempo, how long a bar and every note value lasts in seconds, samples, hertz and video frames,
/// and which tempo a length implies. Every value is a `Rational`, so `ExactText` writes it without
/// rounding — at 150 BPM a half-note triplet is 0,53̅ s, 23520 samples, 1,875 Hz.
public struct TempoCalculator: Equatable, Sendable {
    /// Beats per minute as typed: 132.5 is 265/2.
    public var bpm: Rational
    public var sampleRate: Rational
    /// The meter: beats per bar over the beat's note value — 4/4, 6/8, 7/8.
    public var beatsPerBar: Int
    public var beatUnit: Int
    /// Video frames per second: 24, 25, 30, or 30000/1001 for 29,97.
    public var frameRate: Rational

    /// The speed of sound the calculator assumes for wavelengths, in metres per second (dry air
    /// at about 20 °C).
    public static let speedOfSound: Rational = 343

    public init(bpm: Rational, sampleRate: Rational = 44_100, beatsPerBar: Int = 4, beatUnit: Int = 4,
                frameRate: Rational = 30) {
        self.bpm = bpm
        self.sampleRate = sampleRate
        self.beatsPerBar = beatsPerBar
        self.beatUnit = beatUnit
        self.frameRate = frameRate
    }

    /// From the song's numbers: the tempo as typed, the rate the engine runs at. nil for a tempo, a
    /// rate or a frame rate that is not positive, or a meter without beats or with an odd unit.
    public init?(songTempo: Double, sampleRate: Double, beatsPerBar: Int = 4, beatUnit: Int = 4,
                 frameRate: Rational = 30) {
        guard let tempo = Rational(roundTripping: songTempo), tempo > .zero,
              let rate = Rational(roundTripping: sampleRate), rate > .zero,
              beatsPerBar > 0, NoteValue.denominators.contains(beatUnit), frameRate > .zero else { return nil }
        self.init(bpm: tempo, sampleRate: rate, beatsPerBar: beatsPerBar, beatUnit: beatUnit, frameRate: frameRate)
    }

    /// Seconds of `quarters` quarter notes: quarters × 60 / bpm.
    public func seconds(ofQuarters quarters: Rational) -> Rational? {
        quarters.multiplied(by: 60)?.divided(by: bpm)
    }

    public func seconds(of note: NoteValue) -> Rational? {
        seconds(ofQuarters: note.quarters)
    }

    /// Quarter notes in one bar: 4/4 is 4, 6/8 is 3, 7/8 is 7/2.
    public var barQuarters: Rational {
        Rational.constant(Int64(beatsPerBar) * 4, Int64(beatUnit))
    }

    public var barSeconds: Rational? {
        seconds(ofQuarters: barQuarters)
    }

    public func samples(ofSeconds seconds: Rational) -> Rational? {
        seconds.multiplied(by: sampleRate)
    }

    public func frames(ofSeconds seconds: Rational) -> Rational? {
        seconds.multiplied(by: frameRate)
    }

    /// One cycle per `seconds`, in hertz; nil for zero.
    public static func hertz(ofSeconds seconds: Rational) -> Rational? {
        seconds.reciprocal
    }

    /// The tempo at which `quarters` quarter notes last `seconds`: one 4/4 bar in 1,818 s is
    /// 132,0̅1̅3̅2̅ BPM. nil for a length that is not positive.
    public static func bpm(quarters: Rational, lasting seconds: Rational) -> Rational? {
        guard seconds > .zero else { return nil }
        return quarters.multiplied(by: 60)?.divided(by: seconds)
    }

    /// The unit the delay table reads in: seconds, milliseconds, or hertz (one cycle per note,
    /// the rate an LFO needs to move once per note).
    public enum DelayUnit: String, CaseIterable, Sendable {
        case seconds, milliseconds, hertz

        public var symbol: String {
            switch self {
            case .seconds: "s"
            case .milliseconds: "ms"
            case .hertz: "Hz"
            }
        }
    }

    /// `note` in `unit`, exact.
    public func value(of note: NoteValue, in unit: DelayUnit) -> Rational? {
        guard let length = seconds(of: note) else { return nil }
        switch unit {
        case .seconds: return length
        case .milliseconds: return length.multiplied(by: 1_000)
        case .hertz: return TempoCalculator.hertz(ofSeconds: length)
        }
    }

    /// The delay table's rows: 1/2 to 1/64, straight, dotted and triplet.
    public static let delayNotes: [NoteValue] = NoteValue.all.filter { $0.denominator >= 2 }

    /// Every delay row with its time, longest first: the sorted list.
    public var sortedDelays: [(note: NoteValue, seconds: Rational)] {
        TempoCalculator.delayNotes
            .compactMap { note in seconds(of: note).map { (note: note, seconds: $0) } }
            .sorted { $0.seconds > $1.seconds }
    }

    /// The pitch of MIDI note `note` in twelve equal steps, A4 (69) at `concertPitch`. Exact only for
    /// the octaves of A (concert pitch times a power of two); every other step is irrational, so nil
    /// here and `approximateHertz` there, shown with "…".
    public static func exactHertz(ofMIDINote note: Int, concertPitch: Rational) -> Rational? {
        let steps = note - 69
        guard steps % 12 == 0 else { return nil }
        let octaves = steps / 12
        guard (-30...30).contains(octaves) else { return nil }
        var value = concertPitch
        for _ in 0..<Swift.abs(octaves) {
            guard let next = octaves > 0 ? value.multiplied(by: 2) : value.divided(by: 2) else { return nil }
            value = next
        }
        return value
    }

    /// The pitch of MIDI note `note` in twelve equal steps as a `Double`.
    public static func approximateHertz(ofMIDINote note: Int, concertPitch: Double) -> Double {
        concertPitch * pow(2, Double(note - 69) / 12)
    }

    /// The wavelength of `hertz` in air, in metres; nil for zero.
    public static func wavelength(ofHertz hertz: Rational) -> Rational? {
        speedOfSound.divided(by: hertz)
    }
}

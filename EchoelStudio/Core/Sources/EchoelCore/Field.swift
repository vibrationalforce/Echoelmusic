import Foundation

/// What the Field — the picture that moves with the music and the body (wave W3) — shows at one
/// moment, as plain numbers each 0 … 1. The renderer draws from it and from nothing else, so the
/// picture, light and OSC out (W4) can read the same frame. Pure; built off the render thread.
public struct FieldFrame: Equatable, Sendable {
    /// Where the playhead is in its beat and in its bar, 0 ..< 1; 0 while stopped.
    public var beatPhase: Double
    public var barPhase: Double
    /// The key's colour: its place on the circle of fifths, 0 ..< 1, so related keys sit close.
    public var keyHue: Double
    /// The master's loudness, 0 (silence) … 1 (full scale).
    public var level: Double
    /// The body's sources, nil while not measured — the picture never invents a pulse.
    public var pulse: Double?
    public var hrv: Double?
    public var coherence: Double?
    public var isPlaying: Bool

    public init(beatPhase: Double = 0, barPhase: Double = 0, keyHue: Double = 0, level: Double = 0,
                pulse: Double? = nil, hrv: Double? = nil, coherence: Double? = nil, isPlaying: Bool = false) {
        self.beatPhase = Self.unit(beatPhase)
        self.barPhase = Self.unit(barPhase)
        self.keyHue = Self.unit(keyHue)
        self.level = Swift.min(1, Swift.max(0, level.isFinite ? level : 0))
        self.pulse = pulse.flatMap(Self.reading)
        self.hrv = hrv.flatMap(Self.reading)
        self.coherence = coherence.flatMap(Self.reading)
        self.isPlaying = isPlaying
    }

    /// The frame at `tick` of a song in `signature` and `context`.
    public static func at(tick: Double, signature: TimeSignature, context: MusicalContext, level: Double,
                          pulse: Double?, hrv: Double?, coherence: Double?, isPlaying: Bool) -> FieldFrame {
        let beat = Double(MusicalTime.ticksPerBeat(signature)), bar = Double(MusicalTime.ticksPerBar(signature))
        let position = isPlaying && tick.isFinite ? Swift.max(0, tick) : 0
        return FieldFrame(beatPhase: beat > 0 ? position.truncatingRemainder(dividingBy: beat) / beat : 0,
                          barPhase: bar > 0 ? position.truncatingRemainder(dividingBy: bar) / bar : 0,
                          keyHue: keyHue(root: context.root), level: level,
                          pulse: pulse, hrv: hrv, coherence: coherence, isPlaying: isPlaying)
    }

    /// C at 0, G a twelfth on, D two twelfths: the circle of fifths.
    public static func keyHue(root: Int) -> Double {
        let pitchClass = ((root % 12) + 12) % 12
        return Double((pitchClass * 7) % 12) / 12
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let wrapped = value - value.rounded(.down)
        return wrapped >= 1 ? 0 : wrapped
    }

    private static func reading(_ value: Double) -> Double? {
        value.isFinite && (0...1).contains(value) ? value : nil
    }
}

/// The Field's guard against flashing (WCAG 2.3.1: no more than three flashes a second). Every
/// brightness the picture shows passes through it: it follows its target, but never faster than
/// `maximumRate` of full scale per second. A flash is a rise and a fall of at least `flashStep`;
/// at this rate a rise and a fall take at least 2 × `flashStep` / `maximumRate` = 1/3 s, so at
/// most three flashes fit in a second — whatever the music, the body or a bug asks for.
public struct FlashLimit: Equatable, Sendable {
    public static let flashStep = 0.1
    public static let flashesPerSecond = 3.0
    public static let maximumRate = 2 * flashStep * flashesPerSecond

    public private(set) var value: Double

    public init(value: Double = 0) {
        self.value = value.isFinite ? Swift.min(1, Swift.max(0, value)) : 0
    }

    /// One step `seconds` later towards `target`; returns the brightness to show.
    public mutating func next(towards target: Double, after seconds: Double) -> Double {
        guard target.isFinite, seconds.isFinite, seconds > 0 else { return value }
        let goal = Swift.min(1, Swift.max(0, target))
        let room = Self.maximumRate * seconds
        value += Swift.min(room, Swift.max(-room, goal - value))
        return value
    }
}

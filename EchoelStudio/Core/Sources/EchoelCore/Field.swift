import Foundation

/// What the Field — the picture that moves with the music and the body (wave W3) — shows at one
/// moment, as plain numbers each 0 … 1. The renderer draws from it and from nothing else, so the
/// picture, light and OSC out (W4) can read the same frame. Pure; built off the render thread.
///
/// One timebase: the song's phases come from the engine's playhead, never from a second clock.
public struct FieldFrame: Equatable, Sendable {
    /// Where the playhead is in its beat and in its bar, 0 ..< 1; 0 while stopped.
    public var beatPhase: Double
    public var barPhase: Double
    /// The key's colour: its place on the circle of fifths, 0 ..< 1, so related keys sit close.
    public var keyHue: Double
    /// The key's tonic in hertz, in the octave of middle C at the song's concert pitch. The Metal
    /// renderer colours the picture with it: the pitch transposed by whole octaves into light.
    public var tonicHz: Double
    /// The master's loudness, 0 (silence) … 1 (full scale).
    public var level: Double
    /// The body's sources, nil while not measured — the picture never invents a pulse.
    public var pulse: Double?
    public var hrv: Double?
    public var coherence: Double?
    /// Lungs empty (0) … full (1), where a source measures the breath.
    public var breath: Double?
    public var isPlaying: Bool

    public init(beatPhase: Double = 0, barPhase: Double = 0, keyHue: Double = 0, tonicHz: Double = FieldFrame.middleC,
                level: Double = 0, pulse: Double? = nil, hrv: Double? = nil, coherence: Double? = nil,
                breath: Double? = nil, isPlaying: Bool = false) {
        self.beatPhase = Self.unit(beatPhase)
        self.barPhase = Self.unit(barPhase)
        self.keyHue = Self.unit(keyHue)
        self.tonicHz = Self.audible(tonicHz)
        self.level = Swift.min(1, Swift.max(0, level.isFinite ? level : 0))
        self.pulse = pulse.flatMap(Self.reading)
        self.hrv = hrv.flatMap(Self.reading)
        self.coherence = coherence.flatMap(Self.reading)
        self.breath = breath.flatMap(Self.reading)
        self.isPlaying = isPlaying
    }

    /// Middle C at A = 440 Hz: the tonic of the default song, and what a bad pitch falls back to.
    public static let middleC = 440 * pow(2, -9.0 / 12)
    /// The pitches a tonic may take; outside them the picture keeps middle C.
    public static let audibleRange: ClosedRange<Double> = 20...20_000

    /// The frame at `tick` of a song in `signature` and `context`.
    public static func at(tick: Double, signature: TimeSignature, context: MusicalContext, level: Double,
                          pulse: Double?, hrv: Double?, coherence: Double?, isPlaying: Bool,
                          breath: Double? = nil) -> FieldFrame {
        let beat = Double(MusicalTime.ticksPerBeat(signature)), bar = Double(MusicalTime.ticksPerBar(signature))
        let position = isPlaying && tick.isFinite ? Swift.max(0, tick) : 0
        return FieldFrame(beatPhase: beat > 0 ? position.truncatingRemainder(dividingBy: beat) / beat : 0,
                          barPhase: bar > 0 ? position.truncatingRemainder(dividingBy: bar) / bar : 0,
                          keyHue: keyHue(root: context.root), tonicHz: tonicHz(of: context), level: level,
                          pulse: pulse, hrv: hrv, coherence: coherence, breath: breath, isPlaying: isPlaying)
    }

    /// C at 0, G a twelfth on, D two twelfths: the circle of fifths.
    public static func keyHue(root: Int) -> Double {
        let pitchClass = ((root % 12) + 12) % 12
        return Double((pitchClass * 7) % 12) / 12
    }

    /// The key's tonic in the octave of middle C, at the song's concert pitch: C4 is 261.63 Hz
    /// at A = 440, and a root of 9 (A) is the concert pitch itself.
    public static func tonicHz(of context: MusicalContext) -> Double {
        let pitchClass = ((context.root % 12) + 12) % 12
        let a4 = context.concertPitch.isFinite ? context.concertPitch : 440
        return audible(a4 * pow(2, (Double(pitchClass) - 9) / 12))
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let wrapped = value - value.rounded(.down)
        return wrapped >= 1 ? 0 : wrapped
    }

    private static func reading(_ value: Double) -> Double? {
        value.isFinite && (0...1).contains(value) ? value : nil
    }

    private static func audible(_ hertz: Double) -> Double {
        hertz.isFinite && audibleRange.contains(hertz) ? hertz : middleC
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
    /// WCAG's general flash: a swing of this much of the maximum relative luminance, where the
    /// darker state is below 0.80. A swing under it is not a flash, however fast it repeats.
    public static let generalFlashThreshold = 0.10

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

/// The two clocks the Metal Field moves with, each capped at `maximumRateHz` however fast the
/// song or the heart runs: the body's heartbeat (a rate in hertz, from the measured pulse) and the
/// song's bar (a phase the engine's playhead already carries). Both integrate a phase in turns,
/// and a renderer that draws from the phase can never flash faster than the phase advances — the
/// hard clamp under the picture (WCAG 2.3.1), stated once here and read by the shader's constants.
///
/// The ceiling is 2.5 Hz, under WCAG's three flashes a second on purpose: an interference field
/// shows the SQUARE of its wave, and squaring a wave doubles its rate. The field therefore damps
/// its phase by `foldDamping` before squaring — 2 × 0.5 × 2.5 Hz lands exactly on the ceiling,
/// with half a flash a second to spare under the law.
public struct FieldPulse: Equatable, Sendable {
    /// The house ceiling on any rate the picture pulses at.
    public static let maximumRateHz = 2.5
    /// How fast the pulse rate may move, in hertz per second: a weak-signal reading that bounces
    /// between beats cannot stutter the picture.
    public static let maximumSlewHzPerSecond = 0.5
    /// The heart rates the body sources normalize over (40 … 200 bpm, as `HeartRateStrap` does).
    public static let heartRange: ClosedRange<Double> = 40...200
    /// A heartbeat drives the picture between these rates: 0.5 Hz (a slow 30) and 2 Hz (120 bpm);
    /// faster hearts keep the picture at 2 Hz.
    public static let heartRateHzRange: ClosedRange<Double> = 0.5...2.0
    /// The field's phase is damped by this before the square — see the type's note.
    public static let foldDamping = 0.5
    public static let foldDampingLiteral = "0.5"
    /// How far one heartbeat may brighten the centre bloom (`gain = 0.80 + swing × beat`). The
    /// bloom runs at the heart's rate ON TOP of the field, so its swing stays under WCAG's
    /// general-flash threshold: swing × `restGlowCeiling` × (1 − `ambient`) < 0.10 — then its
    /// transitions are not flashes and only the field's rate counts. `FieldTests` keep the product.
    public static let bloomSwing = 0.42
    public static let bloomSwingLiteral = "0.42"
    /// The most the resting bloom may glow (`glow = 0.05 + 0.18 × light`).
    public static let restGlowCeiling = 0.23
    public static let restGlowFloorLiteral = "0.05"
    public static let restGlowSpanLiteral = "0.18"
    /// The picture is never a dead black: this much of the colour shows with no energy at all.
    public static let ambient = 0.06
    public static let ambientLiteral = "0.06"

    /// The heartbeat's phase, in turns, 0 ..< 1.
    public private(set) var phase: Double = 0
    /// The rate the phase advances at now, in hertz; 0 while the picture holds still.
    public private(set) var rateHz: Double = 0

    public init() {}

    /// The measured pulse (0 … 1 over `heartRange`) back in beats per minute.
    public static func beatsPerMinute(pulse: Double?) -> Double? {
        guard let pulse, pulse.isFinite, (0...1).contains(pulse) else { return nil }
        return heartRange.lowerBound + pulse * (heartRange.upperBound - heartRange.lowerBound)
    }

    /// The rate the heart asks the picture to pulse at: 0 with no pulse or under Reduce Motion,
    /// else the heart rate bounded to `heartRateHzRange` and never above `maximumRateHz`.
    public static func rate(beatsPerMinute: Double?, reduceMotion: Bool) -> Double {
        guard !reduceMotion, let bpm = beatsPerMinute, bpm.isFinite, bpm > 0 else { return 0 }
        let hertz = Swift.min(Swift.max(bpm / 60, heartRateHzRange.lowerBound), heartRateHzRange.upperBound)
        return Swift.min(hertz, maximumRateHz)
    }

    /// One frame: the rate slews towards `target` (a stop is immediate, a start or change
    /// gradual), is capped at the ceiling, and advances the phase by it. Returns the phase.
    @discardableResult
    public mutating func advance(towards target: Double, after seconds: Double) -> Double {
        guard seconds.isFinite, seconds > 0 else { return phase }
        let goal = target.isFinite ? Swift.min(Swift.max(target, 0), Self.maximumRateHz) : 0
        if goal <= 0 {
            rateHz = 0
        } else {
            let room = Self.maximumSlewHzPerSecond * seconds
            rateHz += Swift.min(room, Swift.max(-room, goal - rateHz))
        }
        phase = Self.wrapped(phase + rateHz * seconds)
        return phase
    }

    /// The song's bar as the field's phase: it follows the playhead's bar phase step for step (a
    /// wrap of the bar is a small step forward, never a jump back), but gains no more than
    /// `maximumRateHz` turns a second — a song faster than the eye may follow slows the picture's
    /// drift rather than strobing it. Returns the new phase in turns.
    public static func songPhase(_ phase: Double, barPhase: Double, previousBarPhase: Double?,
                                 after seconds: Double) -> Double {
        guard seconds.isFinite, seconds > 0, barPhase.isFinite, let previous = previousBarPhase, previous.isFinite
        else { return wrapped(phase) }
        var step = barPhase - previous
        if step < 0 { step += 1 }
        return wrapped(phase + Swift.min(Swift.max(step, 0), maximumRateHz * seconds))
    }

    private static func wrapped(_ turns: Double) -> Double {
        guard turns.isFinite else { return 0 }
        let wrapped = turns - turns.rounded(.down)
        return wrapped >= 1 ? 0 : wrapped
    }
}

/// How much the Field draws, from the device's heat, power and the frame rate it achieves —
/// never the frame rate it asks for: the display link stays pinned at `frameRate`, because
/// changing it reconfigures the display cadence (a visible hitch the earlier app paid for).
/// Heat and a low battery shed DETAIL: fewer pixels in the drawable, fewer rings, and at the
/// lowest level a still picture. Pure; the renderer feeds the readings in once a second.
public struct FieldDetail: Equatable, Sendable {
    public enum Thermal: Int, Comparable, Sendable, CaseIterable {
        case nominal, fair, serious, critical
        public static func < (lhs: Thermal, rhs: Thermal) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum Level: Int, Comparable, Sendable, CaseIterable {
        /// A still picture at half resolution: thermal critical, or a battery nearly empty.
        case minimal
        /// Low Power Mode, a warm device, a low battery, or a frame rate the device cannot hold.
        case low
        /// Everything.
        case full
        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The display's frames per second, pinned. Nothing lowers it; detail is the lever.
    public static let frameRate = 60
    /// Below this share of `frameRate`, measured over a second, the device is not keeping up
    /// and the level steps down once.
    public static let keepingUpShare = 0.75

    public let level: Level

    public init(level: Level) {
        self.level = level
    }

    /// The linear factor on the drawable's width and height: the pixel count falls to 49 % and
    /// 25 % exactly when the device cannot afford it; the layer scales the picture up.
    public var resolutionScale: Double {
        switch level {
        case .minimal: 0.5
        case .low: 0.7
        case .full: 1
        }
    }

    /// The factor on the pattern's ring count: fewer, wider fringes on a tired device.
    public var patternScale: Double { resolutionScale }

    /// Whether the picture holds still, as it does under Reduce Motion.
    public var isStill: Bool { level == .minimal }

    /// How long after a memory warning the Field stays at `.low` at most: a smaller drawable is
    /// memory the system gets back, and the warning says nothing about when the pressure ends.
    public static let memoryWarningSeconds = 60.0

    /// The level for the device's state. `batteryLevel` is 0 … 1, or negative when unknown
    /// (a Mac, a simulator); `measuredFrameRate` ≤ 0 means no reading yet; `memoryWarned` while
    /// the last memory warning is younger than `memoryWarningSeconds`.
    public static func level(thermal: Thermal, lowPower: Bool, batteryLevel: Double, charging: Bool,
                             measuredFrameRate: Double, memoryWarned: Bool = false) -> Level {
        var ceiling = Level.full
        switch thermal {
        case .nominal, .fair: break
        case .serious: ceiling = .low
        case .critical: ceiling = .minimal
        }
        if lowPower || memoryWarned { ceiling = Swift.min(ceiling, .low) }
        if batteryLevel.isFinite, batteryLevel >= 0, !charging {
            if batteryLevel < 0.10 {
                ceiling = .minimal
            } else if batteryLevel < 0.20 {
                ceiling = Swift.min(ceiling, .low)
            }
        }
        var chosen = ceiling
        if measuredFrameRate.isFinite, measuredFrameRate > 0,
           measuredFrameRate < Double(frameRate) * keepingUpShare,
           let lower = Level(rawValue: chosen.rawValue - 1) {
            chosen = lower
        }
        return chosen
    }
}

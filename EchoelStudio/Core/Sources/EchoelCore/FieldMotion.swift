import Foundation

/// How the Field moves from one drawn frame to the next (waves W3, W15): the two clocks
/// (`FieldPulse`), the flash guards (`FlashLimit`) and the slow glides of the body and the key,
/// stepped by the seconds since the last frame. Every Field renderer draws what `step` returns —
/// the window, the live stream, the video window's layer and the video export — so the picture
/// moves one way wherever it is drawn. Pure and deterministic: the same frames at the same steps
/// give the same pictures, which is what makes two exports of one song the same film.
public struct FieldMotion: Equatable, Sendable {
    /// What one frame shows: the numbers the Field shader reads (all but the frame's aspect).
    public struct Shown: Equatable, Sendable {
        public var beatPhase = 0.0
        public var fieldPhase = 0.0
        public var pulsePhase = 0.0
        public var beatLight = 0.0
        public var centreLight = 0.0
        public var levelLight = 0.0
        public var coherence = 0.5
        public var breath = 0.5
        public var toneHz = FieldFrame.middleC
        public var density = FieldMotion.ringDensity
        public var hasPulse = false
        public var hasCoherence = false
        /// The rings' wavenumber (`ringsK(density:toneHz:)` of the glided density and tonic), and
        /// the coherence the rings' detune and sharpness read: each moving at a capped speed
        /// (`ringsKRate`, `ringsCoherenceRate`), so a key change or a coherence jump never slides
        /// the rings across a point faster than the flash law allows.
        public var ringsK = FieldMotion.ringsK(density: FieldMotion.ringDensity, toneHz: FieldFrame.middleC)
        public var ringsCoherence = 0.5

        public init() {}
    }

    /// The rings' spacing at full detail and middle C.
    public static let ringDensity = 40.0
    /// How fast the rings' wavenumber may change (per unit, per second) and how fast the coherence
    /// they read may (per second). The tonic's 0.45 s glide moved the rings from C to B (k 40 to
    /// 75) across a point near the edge 17 to 21 times a second, and a coherence jump re-detuned
    /// them 12 to 23 times (simulated per pixel, 2026-11-06); at these rates a key change tightens
    /// the rings over some seconds and coherence settles over half a minute.
    public static let ringsKRate = 2.0
    public static let ringsCoherenceRate = 0.03

    /// The rings' wavenumber for a ring density and a tonic.
    public static func ringsK(density: Double, toneHz: Double) -> Double {
        let hertz = toneHz.isFinite ? Swift.max(toneHz, 20) : FieldFrame.middleC
        let pitch = Swift.min(Swift.max(hertz / FieldFrame.middleC, 0.5), 2.0)
        let k = (density.isFinite ? density : ringDensity) * pitch
        return Swift.min(Swift.max(k, 4), 120)
    }

    private var pulse = FieldPulse()
    private var fieldPhase = 0.0
    private var previousBarPhase: Double?
    private var beatLight = FlashLimit()
    private var centreLight = FlashLimit()
    private var levelLight = FlashLimit()
    private var coherence = 0.5
    private var breath = 0.5
    private var toneHz = FieldFrame.middleC
    private var density = FieldMotion.ringDensity
    private var ringsK = FieldMotion.ringsK(density: FieldMotion.ringDensity, toneHz: FieldFrame.middleC)
    private var ringsCoherence = 0.5
    private var hasSeeded = false

    public init() {}

    /// One frame `seconds` after the last: the clocks advance (each capped, `FieldPulse`), every
    /// brightness passes its flash guard, the slow signals glide. `still` holds the picture (Reduce
    /// Motion, or a device at its lowest detail): the beat ring rests and the field stops drifting.
    /// `patternScale` is the detail's factor on the ring count (`FieldDetail.patternScale`). The
    /// first frame shows the song and the body as they are, with no glide from defaults.
    public mutating func step(_ frame: FieldFrame, after seconds: Double, still: Bool,
                              patternScale: Double) -> Shown {
        if !hasSeeded { seed(frame, patternScale: patternScale) }

        // The two clocks, each capped: the heart's rate, the song's bar.
        let beatsPerMinute = FieldPulse.beatsPerMinute(pulse: frame.pulse)
        pulse.advance(towards: FieldPulse.rate(beatsPerMinute: beatsPerMinute, reduceMotion: still), after: seconds)
        if !still {
            fieldPhase = FieldPulse.songPhase(fieldPhase, barPhase: frame.barPhase,
                                              previousBarPhase: previousBarPhase, after: seconds)
        }
        previousBarPhase = frame.barPhase

        // Every brightness passes the flash guard; while still, the beat ring rests.
        var shown = Shown()
        let beatTarget = frame.isPlaying && !still ? 1 - frame.beatPhase : 0
        shown.beatLight = beatLight.next(towards: beatTarget, after: seconds)
        shown.centreLight = centreLight.next(towards: frame.pulse ?? frame.level, after: seconds)
        shown.levelLight = levelLight.next(towards: frame.level, after: seconds)

        // Slow signals glide; a key change sweeps the colour along the spectrum, never a jump.
        coherence = Self.ease(coherence, frame.coherence ?? 0.5, tau: 0.6, seconds: seconds)
        breath = Self.ease(breath, frame.breath ?? 0.5, tau: 0.35, seconds: seconds)
        toneHz = Self.ease(toneHz, frame.tonicHz, tau: 0.45, seconds: seconds)
        density = Self.ease(density, Self.ringDensity * patternScale, tau: 0.7, seconds: seconds)
        let elapsed = seconds.isFinite && seconds > 0 ? seconds : 0
        ringsK = Self.approach(ringsK, Self.ringsK(density: density, toneHz: toneHz), by: Self.ringsKRate * elapsed)
        ringsCoherence = Self.approach(ringsCoherence, coherence, by: Self.ringsCoherenceRate * elapsed)

        shown.beatPhase = still ? 0 : frame.beatPhase
        shown.fieldPhase = fieldPhase
        shown.pulsePhase = pulse.phase
        shown.coherence = coherence
        shown.breath = breath
        shown.toneHz = toneHz
        shown.density = density
        shown.hasPulse = frame.pulse != nil
        shown.hasCoherence = frame.coherence != nil
        shown.ringsK = ringsK
        shown.ringsCoherence = ringsCoherence
        return shown
    }

    private mutating func seed(_ frame: FieldFrame, patternScale: Double) {
        hasSeeded = true
        coherence = frame.coherence ?? 0.5
        breath = frame.breath ?? 0.5
        toneHz = frame.tonicHz
        density = Self.ringDensity * patternScale
        ringsK = Self.ringsK(density: density, toneHz: toneHz)
        ringsCoherence = coherence
        beatLight = FlashLimit(value: 0)
        centreLight = FlashLimit(value: frame.pulse ?? frame.level)
        levelLight = FlashLimit(value: frame.level)
        previousBarPhase = frame.barPhase
    }

    /// `value` moved towards `target` by at most `step`; a non-finite target leaves it.
    static func approach(_ value: Double, _ target: Double, by step: Double) -> Double {
        guard target.isFinite else { return value }
        return value + Swift.min(Swift.max(target - value, -step), step)
    }

    /// Exponential smoothing by elapsed time: the same glide at any frame rate.
    static func ease(_ value: Double, _ target: Double, tau: Double, seconds: Double) -> Double {
        guard target.isFinite else { return value }
        guard tau > 0, seconds > 0 else { return target }
        return value + (target - value) * (1 - Foundation.exp(-seconds / tau))
    }
}

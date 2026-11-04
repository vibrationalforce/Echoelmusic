import Foundation

/// What makes a synth voice's raw tone before its filter and envelopes (EchoelTools A1, A4, A8):
/// the classic oscillator, a seven-saw supersaw, two-operator FM, the oscillator with a sine
/// an octave below, a morph through eight shapes (A7), a struck object — six decaying modes
/// (A5) — the harmonic-plus-noise model of the earlier app's `EchoelDDSP` (W5,
/// `DDSPSource`), a small choir singing a vowel (VOX, `ChoirSource`), or a plucked string (A6,
/// `PluckSource`). `character` (0 … 1) is
/// each engine's one control — the supersaw's detune, the FM index, the sub's level, the morph's
/// position, the mallet's material from wood to metal, the DDSP's brightness, harmonicity and
/// noise together (dark and breathy to bright and pure), the choir's vowel from oo to ee, the
/// pluck's brightness; the classic oscillator ignores it. Ported from the earlier app's `EchoelPolySynth` engines
/// as one value type a voice owns; nothing here allocates.
public enum SynthEngine: String, CaseIterable, Codable, Sendable {
    // A song stores the index of the choice: a new engine goes at the end.
    case classic, supersaw, fm, sub, morph, mallet, ddsp, choir
    /// A plucked string, Karplus-Strong (A6): `character` its brightness, the patch's Decay how
    /// long it rings (`PluckSource`).
    case pluck
    /// A wavetable (the user's own sample cut into cycles, or the factory shapes): `character` the
    /// position across its cycles (`WavetableBank`).
    case wavetable

    /// A gain inside the voice, so the same patch sounds about as loud on every engine. Without it
    /// a preset jumped by up to 16 LU when only its engine changed ("Sub Bass": FM −26.4, Sub
    /// −10.1 LUFS), and the choir presets clipped a six-note chord on the classic, FM, sub and
    /// morph engines at +1.6 … +3.7 dBFS (audit 2026-11-04). Measured on the reference patch —
    /// the Init sound with the filter open (cutoff 18 kHz, no envelope, no resonance), a six-note
    /// chord held for two seconds, averaged over Character 0, 0.5 and 1 — each engine is brought
    /// to −17 LUFS, the level at which no built-in preset clips that chord on any engine: classic
    /// −12.8, supersaw −13.3, FM −11.0, sub −13.6, morph −12.7, DDSP −13.0, choir −18.0 before.
    /// The mallet (−23.5) rings down instead of holding, so its integrated loudness undersells
    /// it; it is raised by +2 dB, which brings its strike's peak to the others' and not further.
    /// The plucked string (A6) rings down too and is matched the same way, by its pluck's peak.
    /// The trim lives in the voice, never in the song: a song stores the patch as it always did.
    /// A filter set low still hears a bright engine quieter than a dark one; that is the filter.
    public var loudnessTrim: Float {
        switch self {
        case .classic: 0.617   // −4.2 dB
        case .supersaw: 0.653  // −3.7 dB
        case .fm: 0.501        // −6.0 dB
        case .sub: 0.676       // −3.4 dB
        case .morph: 0.610     // −4.3 dB
        case .mallet: 1.259    // +2.0 dB
        case .ddsp: 0.631      // −4.0 dB
        case .choir: 1.122     // +1.0 dB
        // Rings down like the mallet, and its noise burst is its peak: raised until that peak
        // stands where the mallet's strike does (−5.8 dBFS on the reference chord, 2026-11-04;
        // −10.8 before), not further — its integrated −24.9 LUFS then is a string dying away.
        case .pluck: 1.778     // +5.0 dB
        // Measured like the held engines, on the factory shapes (−13.9 LUFS before, 2026-11-04).
        case .wavetable: 0.708 // −3.0 dB
        }
    }
}

/// The morph's eight shapes (A7), in order: sine, folded sine, triangle, ramp (a triangle leaning
/// toward the saw), saw, a 12.5 % pulse, a 25 % pulse, square. The four new shapes are drawn from
/// the shared phase — the pulses band-limited with PolyBLEP like the square, the folded sine and
/// the ramp continuous, so their harmonics fall as a triangle's do.
enum MorphShapes {
    /// Where each shape stands on Character. 0, ⅓, ⅔ and 1 are the earlier morph's four.
    /// Computed, not stored: the render thread reads it, and a stored static is initialised lazily.
    static var positions: (Float, Float, Float, Float, Float, Float, Float, Float) {
        (0, 1.0 / 6, 1.0 / 3, 0.5, 2.0 / 3, 7.0 / 9, 8.0 / 9, 1)
    }
    /// How far the ramp's peak leans toward the saw's (0.5 is the triangle, 1 the saw).
    static let rampPeak: Float = 0.75
    static let narrowPulse: Float = 0.125
    static let widePulse: Float = 0.25

    @inline(__always)
    static func value(at c: Float, phase t: Float, dt: Float,
                      sine: Float, triangle: Float, saw: Float, square: Float) -> Float {
        let p = positions
        if c < p.1 { return sine + (folded(t) - sine) * ((c - p.0) / (p.1 - p.0)) }
        if c < p.2 {
            let f = folded(t)
            return f + (triangle - f) * ((c - p.1) / (p.2 - p.1))
        }
        if c < p.3 { return triangle + (ramp(t) - triangle) * ((c - p.2) / (p.3 - p.2)) }
        if c < p.4 {
            let r = ramp(t)
            return r + (saw - r) * ((c - p.3) / (p.4 - p.3))
        }
        if c < p.5 { return saw + (pulse(t, dt, narrowPulse) - saw) * ((c - p.4) / (p.5 - p.4)) }
        if c < p.6 {
            let n = pulse(t, dt, narrowPulse)
            return n + (pulse(t, dt, widePulse) - n) * ((c - p.5) / (p.6 - p.5))
        }
        if c < p.7 {
            let w = pulse(t, dt, widePulse)
            return w + (square - w) * ((c - p.6) / (p.7 - p.6))
        }
        return square
    }

    /// A sine driven past full scale and folded back: odd harmonics, softly.
    @inline(__always)
    static func folded(_ t: Float) -> Float {
        let x = 1.6 * sinf(2 * Float.pi * t)
        if x > 1 { return 2 - x }
        if x < -1 { return -2 - x }
        return x
    }

    /// A triangle whose peak leans toward the end of the cycle; it starts at −1 as the triangle
    /// and the saw do.
    @inline(__always)
    static func ramp(_ t: Float) -> Float {
        let w = rampPeak
        return t < w ? -1 + 2 * t / w : 1 - 2 * (t - w) / (1 - w)
    }

    /// A pulse `width` of the cycle high, without its offset, at peak 1.
    @inline(__always)
    static func pulse(_ t: Float, _ dt: Float, _ width: Float) -> Float {
        var out: Float = t < width ? 1 : -1
        out += Oscillator.polyBLEP(t, dt)
        var fall = t - width
        if fall < 0 { fall += 1 }
        out -= Oscillator.polyBLEP(fall, dt)
        return (out - (2 * width - 1)) / (2 - 2 * width)
    }
}

/// One mode of a struck object: a sine whose amplitude falls by `damping` each sample.
struct MalletMode: Sendable {
    var phase: Float = 0
    var amplitude: Float = 0
    var ratio: Float = 1
    /// Per fundamental cycle, so a higher note rings fewer seconds, as a shorter bar does.
    var cyclesToFall: Float = 1

    /// Wood (a tuned marimba bar) at material 0, metal (a free bar, as a glockenspiel) at 1.
    static let woodRatios: (Float, Float, Float, Float, Float, Float) = (1, 3.99, 10.0, 16.7, 24.3, 33.1)
    static let metalRatios: (Float, Float, Float, Float, Float, Float) = (1, 2.756, 5.404, 8.933, 13.344, 18.638)
    /// How many fundamental cycles the lowest mode takes to fall to 1/e, for wood and for metal.
    static let woodCycles: Float = 90
    static let metalCycles: Float = 900

    /// Struck: the mode sounds again at its level for `material`, on top of what still rings.
    mutating func strike(index: Int, wood: Float, metal: Float, material: Float) {
        ratio = wood + (metal - wood) * material
        let n = Float(index)
        amplitude = Swift.min(1, amplitude + 1 / (1 + n * (1.6 - material)))
        let base = Self.woodCycles + (Self.metalCycles - Self.woodCycles) * material
        cyclesToFall = base / (1 + n * (2.5 - 1.5 * material))
    }

    @inline(__always)
    mutating func next(dt: Float) -> Float {
        guard amplitude > 1e-5 else { amplitude = 0; return 0 }
        let step = dt * ratio
        // A mode above Nyquist is not heard, and folding it back would be a false tone.
        let out: Float = step < 0.5 ? amplitude * sinf(2 * Float.pi * phase) : 0
        phase += step
        phase -= phase.rounded(.down)
        amplitude *= Swift.max(0, 1 - dt / cyclesToFall)
        return out
    }
}

/// The oscillators behind one voice's engine. All of them are stored inline — six extra saws,
/// a modulator phase, a sub phase, the DDSP's partial bank, the choir's singers and vocal tract —
/// so switching engines needs nothing new.
struct EngineSource: Sendable {
    /// Detune of the six outer saws in units of the full spread (the centre saw is the voice's own).
    static let spreadPositions: (Float, Float, Float, Float, Float, Float) = (-1, -0.62, -0.28, 0.28, 0.62, 1)
    /// The widest supersaw spread, in semitones each side.
    static let maximumSpreadSemitones: Float = 0.5
    /// The FM modulator runs at twice the carrier: bell, electric piano, metallic bass.
    static let fmRatio: Float = 2
    /// The FM index at full character.
    static let maximumFMIndex: Float = 6

    private var s0 = Oscillator(waveform: .saw, phase: 0.11)
    private var s1 = Oscillator(waveform: .saw, phase: 0.37)
    private var s2 = Oscillator(waveform: .saw, phase: 0.59)
    private var s3 = Oscillator(waveform: .saw, phase: 0.23)
    private var s4 = Oscillator(waveform: .saw, phase: 0.81)
    private var s5 = Oscillator(waveform: .saw, phase: 0.47)
    private var carrier: Float = 0
    private var modulator: Float = 0
    private var subPhase: Float = 0
    /// The morph's four shapes, phase-locked: they start together and advance by the same step.
    private var m0 = Oscillator(waveform: .sine)
    private var m1 = Oscillator(waveform: .triangle)
    private var m2 = Oscillator(waveform: .saw)
    private var m3 = Oscillator(waveform: .square)
    /// The mallet's six modes, struck at each note.
    private var k0 = MalletMode(), k1 = MalletMode(), k2 = MalletMode()
    private var k3 = MalletMode(), k4 = MalletMode(), k5 = MalletMode()
    /// The DDSP's sixty-four partials and its noise bank.
    private var ddsp = DDSPSource()
    /// The choir's three singers and its vocal tract.
    private var choir = ChoirSource()
    /// The plucked string's loop; its delay line is allocated here, once.
    private var pluck: PluckSource
    /// Where the wavetable engine is in its cycle, 0 ..< 1.
    private var tablePhase: Float = 0

    init(sampleRate: Float) {
        pluck = PluckSource(sampleRate: sampleRate)
    }

    mutating func reset() {
        s0.reset(phase: 0.11); s1.reset(phase: 0.37); s2.reset(phase: 0.59)
        s3.reset(phase: 0.23); s4.reset(phase: 0.81); s5.reset(phase: 0.47)
        carrier = 0
        modulator = 0
        subPhase = 0
        m0.reset(); m1.reset(); m2.reset(); m3.reset()
        k0 = MalletMode(); k1 = MalletMode(); k2 = MalletMode()
        k3 = MalletMode(); k4 = MalletMode(); k5 = MalletMode()
        ddsp.reset()
        choir.reset()
        pluck.reset()
        tablePhase = 0
    }

    /// How long the plucked string rings, from the patch's Decay and Sustain. Before each render.
    mutating func setPluckRing(decaySeconds: Float, sustain: Float, sampleRate: Float) {
        pluck.ringSamples = PluckSource.ringSeconds(decay: decaySeconds, sustain: sustain) * sampleRate
    }

    /// A key struck this voice: the mallet's modes sound again, the DDSP's noise starts a
    /// sequence of its own for this note (`order` is the synth's note counter), and the choir takes
    /// the note's register and the rate it sings at. The other engines have nothing to strike.
    mutating func strike(character: Float, order: UInt64, pitch: UInt8, sampleRate: Float, dt: Float) {
        let c = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        let w = MalletMode.woodRatios, m = MalletMode.metalRatios
        k0.strike(index: 0, wood: w.0, metal: m.0, material: c)
        k1.strike(index: 1, wood: w.1, metal: m.1, material: c)
        k2.strike(index: 2, wood: w.2, metal: m.2, material: c)
        k3.strike(index: 3, wood: w.3, metal: m.3, material: c)
        k4.strike(index: 4, wood: w.4, metal: m.4, material: c)
        k5.strike(index: 5, wood: w.5, metal: m.5, material: c)
        ddsp.reseed(order)
        choir.strike(pitch: pitch, sampleRate: sampleRate, order: order)
        pluck.strike(order: order, dt: dt)
    }

    /// One sample. `main` is the voice's own oscillator; `dt` its increment this sample.
    @inline(__always)
    mutating func next(_ engine: SynthEngine, character: Float, main: inout Oscillator, dt: Float,
                       table: WavetableView) -> Float {
        guard dt.isFinite, dt > 0, dt < 0.5 else { return 0 }
        let c = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        switch engine {
        case .classic:
            return main.next(increment: dt)
        case .supersaw:
            let spread = c * Self.maximumSpreadSemitones / 12
            let p = Self.spreadPositions
            var sum = main.next(increment: dt)
            sum += s0.next(increment: dt * exp2f(p.0 * spread))
            sum += s1.next(increment: dt * exp2f(p.1 * spread))
            sum += s2.next(increment: dt * exp2f(p.2 * spread))
            sum += s3.next(increment: dt * exp2f(p.3 * spread))
            sum += s4.next(increment: dt * exp2f(p.4 * spread))
            sum += s5.next(increment: dt * exp2f(p.5 * spread))
            // Seven uncorrelated saws add like noise: √7 keeps the level near one saw's.
            return sum * 0.378
        case .fm:
            let modulating = sinf(2 * Float.pi * modulator)
            let out = sinf(2 * Float.pi * carrier + c * Self.maximumFMIndex * modulating)
            carrier += dt
            if carrier >= 1 { carrier -= 1 }
            modulator += dt * Self.fmRatio
            if modulator >= 1 { modulator -= 1 }
            return out
        case .sub:
            let top = main.next(increment: dt)
            let below = sinf(2 * Float.pi * subPhase)
            subPhase += dt / 2
            if subPhase >= 1 { subPhase -= 1 }
            return (top + c * below) / (1 + c * 0.5)
        case .morph:
            // Eight shapes (A7) at `MorphShapes.positions`; between two, a crossfade. The first
            // four of the earlier morph — sine 0, triangle ⅓, saw ⅔, square 1 — stand where they
            // stood, so a song's morph at one of them sounds as it did; the four new shapes sit
            // between them. All shapes share one phase and advance every sample, so the next
            // crossfade starts in phase.
            let t = m0.phase
            let a = m0.next(increment: dt), b = m1.next(increment: dt)
            let d = m2.next(increment: dt), e = m3.next(increment: dt)
            return MorphShapes.value(at: c, phase: t, dt: dt, sine: a, triangle: b, saw: d, square: e)
        case .mallet:
            // The material was set at the strike; character between strikes does not retune a
            // bar that is already ringing.
            let sum = k0.next(dt: dt) + k1.next(dt: dt) + k2.next(dt: dt)
                + k3.next(dt: dt) + k4.next(dt: dt) + k5.next(dt: dt)
            return sum * 0.5
        case .ddsp:
            return ddsp.next(character: c, dt: dt)
        case .choir:
            return choir.next(character: c, dt: dt)
        case .pluck:
            return pluck.next(character: c, dt: dt)
        case .wavetable:
            let out = table.sample(position: c, phase: tablePhase, dt: dt)
            tablePhase += dt
            if tablePhase >= 1 { tablePhase -= 1 }
            return out
        }
    }
}

import Foundation

/// What makes a synth voice's raw tone before its filter and envelopes (EchoelTools A1, A4, A8):
/// the classic oscillator, a seven-saw supersaw, two-operator FM, the oscillator with a sine
/// an octave below, a morph through four shapes (A7), or a struck object — six decaying modes
/// (A5). `character` (0 … 1) is each engine's one control — the supersaw's detune, the FM index,
/// the sub's level, the morph's position, the mallet's material from wood to metal; the classic
/// oscillator ignores it. Ported from the earlier
/// app's `EchoelPolySynth` engines as one value type a voice owns; nothing here allocates.
public enum SynthEngine: String, CaseIterable, Codable, Sendable {
    // A song stores the index of the choice: a new engine goes at the end.
    case classic, supersaw, fm, sub, morph, mallet
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
/// a modulator phase, a sub phase — so switching engines needs nothing new.
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

    mutating func reset() {
        s0.reset(phase: 0.11); s1.reset(phase: 0.37); s2.reset(phase: 0.59)
        s3.reset(phase: 0.23); s4.reset(phase: 0.81); s5.reset(phase: 0.47)
        carrier = 0
        modulator = 0
        subPhase = 0
        m0.reset(); m1.reset(); m2.reset(); m3.reset()
        k0 = MalletMode(); k1 = MalletMode(); k2 = MalletMode()
        k3 = MalletMode(); k4 = MalletMode(); k5 = MalletMode()
    }

    /// A key struck this voice: the mallet's modes sound again. The other engines have nothing
    /// to strike.
    mutating func strike(character: Float) {
        let c = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        let w = MalletMode.woodRatios, m = MalletMode.metalRatios
        k0.strike(index: 0, wood: w.0, metal: m.0, material: c)
        k1.strike(index: 1, wood: w.1, metal: m.1, material: c)
        k2.strike(index: 2, wood: w.2, metal: m.2, material: c)
        k3.strike(index: 3, wood: w.3, metal: m.3, material: c)
        k4.strike(index: 4, wood: w.4, metal: m.4, material: c)
        k5.strike(index: 5, wood: w.5, metal: m.5, material: c)
    }

    /// One sample. `main` is the voice's own oscillator; `dt` its increment this sample.
    @inline(__always)
    mutating func next(_ engine: SynthEngine, character: Float, main: inout Oscillator, dt: Float) -> Float {
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
            // Sine at 0, triangle at ⅓, saw at ⅔, square at 1; between two, a crossfade. All four
            // advance every sample so the next crossfade starts in phase.
            let a = m0.next(increment: dt), b = m1.next(increment: dt)
            let d = m2.next(increment: dt), e = m3.next(increment: dt)
            let position = c * 3
            if position < 1 { return a + (b - a) * position }
            if position < 2 { return b + (d - b) * (position - 1) }
            return d + (e - d) * (position - 2)
        case .mallet:
            // The material was set at the strike; character between strikes does not retune a
            // bar that is already ringing.
            let sum = k0.next(dt: dt) + k1.next(dt: dt) + k2.next(dt: dt)
                + k3.next(dt: dt) + k4.next(dt: dt) + k5.next(dt: dt)
            return sum * 0.5
        }
    }
}

import Foundation

/// What makes a synth voice's raw tone before its filter and envelopes (EchoelTools A1, A4, A8):
/// the classic oscillator, a seven-saw supersaw, two-operator FM, or the oscillator with a sine
/// an octave below. `character` (0 … 1) is each engine's one control — the supersaw's detune,
/// the FM index, the sub's level; the classic oscillator ignores it. Ported from the earlier
/// app's `EchoelPolySynth` engines as one value type a voice owns; nothing here allocates.
public enum SynthEngine: String, CaseIterable, Codable, Sendable {
    case classic, supersaw, fm, sub
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

    mutating func reset() {
        s0.reset(phase: 0.11); s1.reset(phase: 0.37); s2.reset(phase: 0.59)
        s3.reset(phase: 0.23); s4.reset(phase: 0.81); s5.reset(phase: 0.47)
        carrier = 0
        modulator = 0
        subPhase = 0
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
        }
    }
}

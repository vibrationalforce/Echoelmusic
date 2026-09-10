import Foundation

/// Modulation effects family, all audio-thread safe (no allocation or locks in
/// the hot loop) and built on the shared `EchoelDelayLine` / `EchoelLFO`
/// primitives. Stereo width comes from driving the right channel with the
/// inverted LFO value — a deterministic 180° offset, no extra LFO state.
///
/// - `EchoelChorus`  — medium modulated delay (thickening, ensemble).
/// - `EchoelFlanger` — short modulated delay with feedback (jet/comb sweep).
/// - `EchoelPhaser`  — cascaded first-order allpass notch sweep with feedback.
/// - `EchoelTremolo` — amplitude modulation with optional auto-pan.
///
/// References: Julius O. Smith III, "Physical Audio Signal Processing"
/// (allpass / comb filters); Pirkle, "Designing Audio Effect Plugins".

// MARK: - Chorus

public final class EchoelChorus: @unchecked Sendable {

    /// LFO rate in Hz [0.05, 8].
    public var rate: Float = 0.6 { didSet { lfo.rate = clampRate(rate) } }
    /// Modulation depth [0, 1].
    public var depth: Float = 0.5
    /// Wet/dry blend [0, 1].
    public var mix: Float = 0.5
    /// Centre delay in milliseconds.
    public var baseDelayMs: Float = 12
    /// Peak modulation excursion in milliseconds at depth 1.
    public var spreadMs: Float = 7

    private let sr: Float
    private let dlL: EchoelDelayLine
    private let dlR: EchoelDelayLine
    private let lfo: EchoelLFO

    public init(sampleRate: Float = 48000) {
        self.sr = sampleRate
        self.dlL = EchoelDelayLine(maxDelaySeconds: 0.05, sampleRate: sampleRate)
        self.dlR = EchoelDelayLine(maxDelaySeconds: 0.05, sampleRate: sampleRate)
        self.lfo = EchoelLFO(sampleRate: sampleRate)
        lfo.rate = 0.6; lfo.depth = 1.0; lfo.waveform = .sine
    }

    @inline(__always)
    public func processStereo(_ inL: Float, _ inR: Float) -> (Float, Float) {
        let m = clamp01(mix)
        let v = lfo.next()                       // [-1, 1]
        // #1206 — `depth` is bounded HERE, the way `mix` one line up and `feedback` in the
        // flanger already are. It is documented `[0, 1]` and its UI field carries `0...1`, but
        // the stored property took anything: a preset JSON decodes an out-of-range Float
        // cleanly (`FXPreset.init(from:)`'s `f(_:_:)` does no range check), and `depth = 50`
        // drives `baseDelayMs ± 350 ms`, which slams BOTH taps onto the line's end stops —
        // `msToSamples` floors at 1.0 and `readAllpass` ceilings at `maxDelaySamples`. Two
        // exact integers, alternating with the LFO: a hard switch, not a chorus.
        let exc = clamp01(depth) * spreadMs
        let dL = msToSamples(baseDelayMs + exc * v)
        let dR = msToSamples(baseDelayMs - exc * v)   // inverted → stereo width
        let yL = dlL.readAllpass(delaySamples: dL)
        let yR = dlR.readAllpass(delaySamples: dR)
        dlL.write(inL)
        dlR.write(inR)
        return (inL * (1 - m) + yL * m, inR * (1 - m) + yR * m)
    }

    public func reset() { dlL.reset(); dlR.reset(); lfo.reset() }

    @inline(__always) private func msToSamples(_ ms: Float) -> Float {
        Swift.max(1.0, ms * 0.001 * sr)
    }
}

// MARK: - Flanger

public final class EchoelFlanger: @unchecked Sendable {

    public var rate: Float = 0.25 { didSet { lfo.rate = clampRate(rate) } }
    public var depth: Float = 0.7
    public var mix: Float = 0.5
    /// Feedback (resonance) [-0.95, 0.95].
    public var feedback: Float = 0.5
    public var baseDelayMs: Float = 3
    public var spreadMs: Float = 2

    private let sr: Float
    private let dlL: EchoelDelayLine
    private let dlR: EchoelDelayLine
    private let lfo: EchoelLFO
    private var fbL: Float = 0
    private var fbR: Float = 0

    public init(sampleRate: Float = 48000) {
        self.sr = sampleRate
        self.dlL = EchoelDelayLine(maxDelaySeconds: 0.02, sampleRate: sampleRate)
        self.dlR = EchoelDelayLine(maxDelaySeconds: 0.02, sampleRate: sampleRate)
        self.lfo = EchoelLFO(sampleRate: sampleRate)
        lfo.rate = 0.25; lfo.depth = 1.0; lfo.waveform = .triangle
    }

    @inline(__always)
    public func processStereo(_ inL: Float, _ inR: Float) -> (Float, Float) {
        let m = clamp01(mix)
        // #1206b — `feedback` multiplies the WRITE-BACK two lines below, so a NaN here is the
        // WORST latch this family has: it goes into the ring buffer, and `EchoelDelayLine`'s own
        // header records why that never heals — the drain that would call `reset()` is gated on
        // the output being under 1e-5, and `NaN < 1e-5` is FALSE. #1206 repaired the LFO latch
        // (which heals the moment a finite rate arrives) and left this one four lines away.
        // ⚠️ THE `isFinite` TERNARY IS NOT DECORATION HERE. `clamped(to:)` maps NaN to the
        // range's LOWER bound, and this range's lower bound is -0.95 — maximum NEGATIVE
        // feedback, i.e. the loudest thing the stage can do. Neutral is 0, so it is named.
        let fb = (feedback.isFinite ? feedback : 0).clamped(to: -0.95...0.95)
        let v = lfo.next()
        // #1206 — see the chorus. Same unbounded `depth`, shorter line (3 ms base, 20 ms
        // capacity), so it reaches its end stops sooner.
        let exc = clamp01(depth) * spreadMs
        let dL = msToSamples(baseDelayMs + exc * v)
        let dR = msToSamples(baseDelayMs - exc * v)
        let yL = dlL.readAllpass(delaySamples: dL)
        let yR = dlR.readAllpass(delaySamples: dR)
        dlL.write(inL + yL * fb)
        dlR.write(inR + yR * fb)
        fbL = yL; fbR = yR
        return (inL * (1 - m) + yL * m, inR * (1 - m) + yR * m)
    }

    public func reset() { dlL.reset(); dlR.reset(); lfo.reset(); fbL = 0; fbR = 0 }

    @inline(__always) private func msToSamples(_ ms: Float) -> Float {
        Swift.max(1.0, ms * 0.001 * sr)
    }
}

// MARK: - Phaser

public final class EchoelPhaser: @unchecked Sendable {

    public var rate: Float = 0.4 { didSet { lfo.rate = clampRate(rate) } }
    public var depth: Float = 0.7
    public var mix: Float = 0.5
    public var feedback: Float = 0.3
    /// Sweep range in Hz.
    public var minHz: Float = 300
    public var maxHz: Float = 2200

    private let sr: Float
    private let stages: Int
    private var zL: [Float]
    private var zR: [Float]
    private var lastL: Float = 0
    private var lastR: Float = 0
    private let lfo: EchoelLFO

    public init(sampleRate: Float = 48000, stages: Int = 6) {
        self.sr = sampleRate
        self.stages = Swift.max(2, stages)
        self.zL = [Float](repeating: 0, count: self.stages)
        self.zR = [Float](repeating: 0, count: self.stages)
        self.lfo = EchoelLFO(sampleRate: sampleRate)
        lfo.rate = 0.4; lfo.depth = 1.0; lfo.waveform = .sine
    }

    @inline(__always)
    public func processStereo(_ inL: Float, _ inR: Float) -> (Float, Float) {
        let m = clamp01(mix)
        // #1206b — same law. A NaN `fb` reaches `var s = x + last * fb`, and `last` plus all
        // `stages` entries of `z` then hold NaN for the life of the instance. No ternary needed:
        // this range's lower bound IS the neutral value.
        let fb = feedback.clamped(to: 0.0...0.95)
        // One LFO value, inverted for the right channel.
        let u = (lfo.next() * 0.5 + 0.5)         // [0, 1]
        let uR = 1.0 - u
        let aL = allpassCoeff(forUnipolar: u)
        let aR = allpassCoeff(forUnipolar: uR)

        let wetL = processChannel(inL, coeff: aL, fb: fb, z: &zL, last: &lastL)
        let wetR = processChannel(inR, coeff: aR, fb: fb, z: &zR, last: &lastR)
        return (inL * (1 - m) + wetL * m, inR * (1 - m) + wetR * m)
    }

    public func reset() {
        for i in 0..<stages { zL[i] = 0; zR[i] = 0 }
        lastL = 0; lastR = 0; lfo.reset()
    }

    @inline(__always)
    private func processChannel(_ x: Float, coeff a: Float, fb: Float,
                                z: inout [Float], last: inout Float) -> Float {
        var s = x + last * fb
        for i in 0..<stages {
            let y = a * s + z[i]
            z[i] = s - a * y
            s = y
        }
        last = s
        return s
    }

    /// First-order allpass coefficient for a break frequency set by the sweep.
    @inline(__always)
    private func allpassCoeff(forUnipolar u: Float) -> Float {
        let lo = Swift.max(20.0, minHz)
        let hi = Swift.min(sr * 0.45, Swift.max(lo + 1, maxHz))
        let modDepth = clamp01(depth)
        let fc = lo + (hi - lo) * (u * modDepth + (1 - modDepth) * 0.5)
        let t = tanf(Float.pi * fc / sr)
        return (t - 1.0) / (t + 1.0)
    }
}

// MARK: - Tremolo

public final class EchoelTremolo: @unchecked Sendable {

    public var rate: Float = 5.0 { didSet { lfo.rate = clampRate(rate) } }
    /// Modulation depth [0, 1] (0 = no effect, 1 = full on/off).
    public var depth: Float = 0.5
    /// When true, L and R modulate in anti-phase (auto-pan).
    public var stereoPan: Bool = false

    private let lfo: EchoelLFO

    public init(sampleRate: Float = 48000) {
        self.lfo = EchoelLFO(sampleRate: sampleRate)
        lfo.rate = 5.0; lfo.depth = 1.0; lfo.waveform = .sine
    }

    @inline(__always)
    public func processStereo(_ inL: Float, _ inR: Float) -> (Float, Float) {
        let d = clamp01(depth)
        let u = lfo.next() * 0.5 + 0.5           // [0, 1]
        let gL = 1.0 - d * (1.0 - u)
        let gR = stereoPan ? (1.0 - d * u) : gL
        return (inL * gL, inR * gR)
    }

    public func reset() { lfo.reset() }
}

// MARK: - Shared helpers

/// ⛔ THESE USE `clamped(to:)`, AND #1206's FIRST ATTEMPT DID NOT — that is the correction, not
/// a style change. The spelling that stood here was `Swift.min(Swift.max(x, 0), 1)`, which is
/// NaN-TRANSPARENT: every comparison against NaN is false, so `Swift.max(x, 0)` returns `x` and
/// the "clamp" is a no-op. #1206 repaired it by reversing the operands. That works, but it
/// invents a second spelling of a decision this repo already owns — CLAUDE.md says in as many
/// words to *"use the NaN-safe `clamped(to:)` (`Core/FloatingPointClamp.swift`) for anything
/// that reaches the audio thread"*, `EchoelDelay` was migrated to it by #588, and
/// `EchoelDelayLine` (also `DSP/`, also the render path) already calls it. One definition per
/// decision (#416). ⚠️ `clamped(to:)` maps NaN to the range's LOWER bound, so it is only the
/// right tool where that bound is also the NEUTRAL value — true for both helpers here, NOT true
/// for the flanger's feedback, which is why that one carries an explicit `isFinite` ternary.
/// For every FINITE input the shipped `clamped(to:)` is bit-identical to the ORIGINAL spelling —
/// it is literally `min(max(self, lo), hi)` behind an `isNaN` guard — so this repair has no
/// audible surface at all. (#1206's reversed-operand form was bit-identical too, with exactly
/// ONE exception: `-0.0` came back as `-0.0` instead of `+0.0`. Inert downstream, and moot now,
/// but recorded because #1206's commit claimed "bit-identical for every finite input" without it.)
///
/// ⭐ FOR `clampRate` THIS IS LATCHING, not merely wrong-for-one-sample. `EchoelLFO.next()`
/// does `phase += rate / sampleRate` and resets on `phase >= 1.0`; with a NaN rate the phase
/// becomes NaN, the reset comparison is false forever, and the LFO never recovers — the same
/// shape as a poisoned filter state. Every mod-FX stage funnels its `rate` setter through here.
///
/// ⚠️ LATENT TODAY, and say so rather than claiming a save. No shipped producer emits NaN into
/// these fields: `JSONDecoder`'s default `nonConformingFloatDecodingStrategy` is `.throw`, the
/// UI fields carry finite ranges, and `GenreFX` and `FXCuratedLibrary` are literals.
/// ⛔ #1206 ALSO WROTE "the one live 30 Hz writer (`FXBioModulator`) is guarded by
/// `FXModulation.clamp01`", and that sentence is wrong twice. The guard is
/// `FXModulation.combine(…)`, whose ternary is `v.isFinite ? v : base` — same conclusion, other
/// function, and its fallback `base` is read live off the chain, so it is NaN-safe only while
/// the chain value is finite. And `FXBioModulator` writes `chorus.mix`, `flanger.mix`,
/// `phaser.mix` and `tremolo.depth` — NEVER `chorus.depth` or `flanger.depth`, the two fields
/// #1206 bounded. It is not a writer into these fields at all.
/// ⚠️ The producer #1206 MISSED is `FXPreset.morphed(to:amount:)`: it clamps its own `amount`
/// with the NaN-transparent idiom, so a NaN amount makes every interpolated field NaN at once —
/// including `flangerFeedback` and `phaserFeedback`, the two #1206b bounds. Latent only because
/// its fader carries a `0...1` range. This is closed on engineering.md's boundary rule.
///
/// ⚠️ AND IT DOES NOT CLOSE THE CLASS. The same NaN-transparent spelling occurs many times under
/// `DSP/` and across `Sources/` — ⛔ two figures stood here and are deleted rather than
/// refreshed: they were measured BEFORE the repair and printed after it, and this very doc block
/// is one of the hits its own regex counts. Run
/// `grep -rnE '(Swift\.)?min\(\s*(Swift\.)?max\(' --include='*.swift' Sources/` and READ the
/// hits; many are already guarded by an `isFinite` ternary in the same expression and several
/// are comments warning about the idiom. Fixing them in one commit is exactly what
/// `ANonFiniteControlCannotReachTheRenderTests` warns against. #1206b closes all FOUR clamps in
/// THIS file and nothing else — ⛔ #1206 claimed that boundary while closing only two of them.
@inline(__always) private func clamp01(_ x: Float) -> Float {
    x.clamped(to: 0.0...1.0)
}
@inline(__always) private func clampRate(_ x: Float) -> Float {
    x.clamped(to: 0.05...8.0)
}

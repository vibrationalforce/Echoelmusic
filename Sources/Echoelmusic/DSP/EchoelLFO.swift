import Foundation

/// Free-running Low Frequency Oscillator for modulation.
/// Audio-thread safe — no allocation, no branching.
public final class EchoelLFO: @unchecked Sendable {

    // MARK: - Waveform

    public enum Waveform: String, CaseIterable, Sendable {
        case sine
        case triangle
        case square
        case sawtooth
        case sampleAndHold
    }

    // MARK: - Parameters

    /// LFO rate in Hz [0.01 - 20]
    public var rate: Float = 0.2       // Slow — one sweep every 5 seconds

    /// LFO depth [0 - 1]
    public var depth: Float = 0.3      // Gentle modulation

    /// Waveform shape
    public var waveform: Waveform = .sine

    // MARK: - State

    private var phase: Float = 0
    private var sampleRate: Float
    private var sAndHValue: Float = 0  // Sample & Hold current value

    /// Inline xorshift32 RNG state for Sample & Hold. Replaces `Float.random`,
    /// which pulls from the system RNG (a syscall) and is NOT audio-thread safe.
    /// This keeps `next()` real-time safe even when driven from a render block.
    private var rngState: UInt32 = 0x2545_F491

    // MARK: - Init

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Process

    /// Get next LFO value. Returns [-depth, +depth]. Audio-thread safe.
    ///
    /// ⭐ THE WRAP CANNOT RUN AWAY (#1207b). It used to be `if phase >= 1.0 { phase -= 1.0 }`,
    /// and that is only a wrap while `phase` stays small. Two ways out of the fold, both
    /// permanent, and neither needed a NaN to start:
    ///   · A LARGE rate. `-= 1.0` is a no-op once `phase` passes ~2^24, so `phase` climbed
    ///     every sample. Simulated in float32 at 48 kHz with `rate = 3.4e38`: the sine
    ///     argument `phase * Float.pi * 2` goes non-finite on sample 7 646 (0,159 s) and
    ///     `phase` itself on sample 48 064 (1,0013 s).
    ///   · A NEGATIVE rate. `phase` only ever fell and never met `>= 1.0`, so it NEVER
    ///     wrapped: it drifted down without bound, the sample-and-hold never re-triggered
    ///     (its only trigger is that branch), and the phase's absolute precision decayed as
    ///     the magnitude grew. ⚠️ Measured rather than assumed, because the obvious wording
    ///     over-claims: at an ordinary −2 Hz the output stays FINITE for any realistic run
    ///     (50 000 samples reach −2,08, not `-inf`); only a hostile magnitude actually
    ///     reaches `-inf`. The everyday defect is the dead S&H and the drift, not a NaN.
    /// After either, `sinf` sees a non-finite argument and returns NaN on EVERY sample, and
    /// nothing recovers it: `reset()` has no production caller (`git grep "filterLFO\."` finds
    /// one `next()`, one capture read and two writes — no `reset()`), so even loading a sane
    /// patch leaves the old `phase` in place.
    ///
    /// ⚠️ AND THE SYMPTOM IS NOT NaN AUDIO, which is worth stating because it is the harder
    /// one to recognise: `EchoelDDSP`'s render folds `lfoMod` into a cutoff that ends in
    /// `.clamped(to: Self.cutoffRange)`, and the NaN-safe clamp maps NaN to the LOWER bound.
    /// So the voice does not crackle — it goes and stays dark at 20 Hz. That is this repo's
    /// "permanent silence" class, not an obvious fault.
    ///
    /// THE REPLACEMENT IS TOTAL. For `phase` in [1, 2) it subtracts exactly 1.0, so every
    /// legitimate rate is BIT-IDENTICAL to the old line; a negative phase folds up into
    /// [0, 1); for a huge phase `rounded(.down)` is the value itself, so the result is 0 and
    /// the oscillator restarts rather than latching; a non-finite phase (NaN from a NaN rate,
    /// or a leftover `inf`) is reset to 0 — note `inf - inf` is NaN, so the `isFinite` test is
    /// load-bearing and not decoration. The fold runs only on the wrap branch — roughly once
    /// per LFO cycle, not per sample — and `floorf` is a C math function, which the
    /// audio-thread rules list as SAFE. The added per-sample cost is one float comparison.
    ///
    /// ⚠️ IT DELIBERATELY DOES NOT CLAMP `rate`. A bound there would forbid a future writer an
    /// audio-rate LFO for no safety gain now that the wrap is total (#364), and the doc on
    /// `rate` above says [0.01 - 20] while enforcing nothing — that mismatch is a separate
    /// question. What the range POLICY needs is a bound where a value enters from a file, and
    /// that is `SynthPatch.clampToBounds()` (#1207).
    ///
    /// ⭐ THE CLASS IS ENUMERATED, NOT ASSUMED — #1206 shipped a boundary sentence that was an
    /// incomplete count, and this is the same shape. `git grep -n "phase >= 1\|phase -= 1"`
    /// over `Sources/` finds exactly TWO wraps of this form: this one, and
    /// `EchoelEntrainment.process`. The second is NOT reachable by a hostile rate and is left
    /// alone deliberately: it advances by `band.centerFrequency`, a five-case `switch`
    /// returning 2 / 6 / 10 / 20 / 40, and `band` is an ENUM — no file, no setter and no bio
    /// value can put a large or non-finite number there. Changing it would be churn on a
    /// correct path. If a future slice makes that frequency a `Float` parameter, this wrap is
    /// the form to copy.
    @inline(__always)
    public func next() -> Float {
        // Advance phase
        phase += rate / sampleRate
        // NEGATED, not `>= 1.0 || < 0.0` — those two are the same test for every FINITE
        // phase, and differ on exactly the case that latches: every comparison against NaN
        // is false, so an already-NaN phase would take neither branch and stay NaN forever.
        if !(phase >= 0.0 && phase < 1.0) {
            phase = phase.isFinite ? phase - phase.rounded(.down) : 0
            // Update S&H on phase reset — audio-thread-safe inline PRNG.
            sAndHValue = nextRandom()
        }

        let raw: Float
        switch waveform {
        case .sine:
            raw = sinf(phase * Float.pi * 2)

        case .triangle:
            // 0→0.25: rise 0→1, 0.25→0.75: fall 1→-1, 0.75→1: rise -1→0
            if phase < 0.25 {
                raw = phase * 4.0
            } else if phase < 0.75 {
                raw = 1.0 - (phase - 0.25) * 4.0
            } else {
                raw = -1.0 + (phase - 0.75) * 4.0
            }

        case .square:
            raw = phase < 0.5 ? 1.0 : -1.0

        case .sawtooth:
            raw = 2.0 * phase - 1.0

        case .sampleAndHold:
            raw = sAndHValue
        }

        return raw * depth
    }

    /// Get next LFO value as unipolar [0, depth]
    @inline(__always)
    public func nextUnipolar() -> Float {
        return (next() + depth) * 0.5
    }

    /// Reset phase
    public func reset() {
        phase = 0
        sAndHValue = 0
        rngState = 0x2545_F491
    }

    /// Inline xorshift32 — audio-thread safe (no syscall). Returns [-1, 1].
    @inline(__always)
    private func nextRandom() -> Float {
        var x = rngState
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        rngState = x
        return Float(x) / Float(UInt32.max) * 2.0 - 1.0
    }
}

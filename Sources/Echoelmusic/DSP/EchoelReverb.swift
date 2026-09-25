import Foundation

/// Freeverb-style algorithmic reverb — eight parallel damped feedback-comb
/// filters into four series allpass filters per channel, the classic Schroeder/
/// Moorer topology popularised by Jezar's "Freeverb". Cheap, stable, and the
/// reference cheap-reverb sound; gives the additive synth the room/hall space
/// that makes it read as produced rather than thin and dry.
///
/// Audio-thread safe: every delay buffer is pre-allocated in `init` (sized from
/// the sample rate). The hot loop only reads/writes indices and does scalar
/// arithmetic — no allocation, locks, ObjC, GCD, or I/O.
///
/// Reference: M. R. Schroeder, "Natural Sounding Artificial Reverberation"
/// (1962); Jezar at Dreampoint, "Freeverb" (public domain).
public final class EchoelReverb: @unchecked Sendable {

    // MARK: - Control-plane parameters

    /// Tail length / feedback [0…1]. Higher = longer decay.
    public var roomSize: Float = 0.72 { didSet { updateDamping() } }
    /// High-frequency damping [0…1]. Higher = darker, faster HF decay.
    public var damping: Float = 0.5 { didSet { updateDamping() } }
    /// Wet/dry blend [0…1]. 0 = dry, 1 = fully wet.
    public var mix: Float = 0.25
    /// #202 — set by the AUv3 space stage (`EchoelBodyVibeDevice.renderSpace`) after its first
    /// block: from then on `mix` holds the value the last sample PLAYED, so the next block may
    /// glide from it. Before that, `mix` is this type's default, not something a listener
    /// heard, and gliding from it would put a wet fade on the first block of a dry plugin.
    /// Nothing else reads it; the app's FX chain sets `mix` directly and never glides.
    /// `reset()` leaves it alone on purpose: the rising-edge reset in `renderSpace` must still
    /// glide up from 0. The AUv3's `allocateRenderResources` clears it beside its own `reset()`,
    /// so a re-allocated unit starts like a fresh one instead of gliding out of the last
    /// session's mix.
    public var mixGlidePrimed = false
    /// Stereo width of the wet signal [0…1].
    public var width: Float = 1.0

    // MARK: - Freeverb tuning (samples at 44.1 kHz, scaled to the real SR)

    private static let combTuning: [Int]   = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allpassTuning: [Int] = [556, 441, 341, 225]
    private static let stereoSpread = 23
    private static let fixedGain: Float = 0.015
    private static let roomScale: Float = 0.28
    private static let roomOffset: Float = 0.7
    private static let allpassFeedback: Float = 0.5

    // MARK: - Comb state (per channel)

    private var combBufL: [[Float]]
    private var combBufR: [[Float]]
    private var combIdxL: [Int]
    private var combIdxR: [Int]
    private var combStoreL: [Float]
    private var combStoreR: [Float]
    private var combFeedback: Float = 0
    private var combDamp1: Float = 0
    private var combDamp2: Float = 0

    // MARK: - Allpass state (per channel)

    private var apBufL: [[Float]]
    private var apBufR: [[Float]]
    private var apIdxL: [Int]
    private var apIdxR: [Int]

    private let combCount: Int
    private let apCount: Int

    /// The rate the tanks are sized for (Hz). Written only by `init` and `setSampleRate`, both
    /// control plane.
    public private(set) var sampleRate: Float
    /// Length of the longest comb tank in samples — the slowest-decaying mode. Cached as a
    /// plain scalar so `decayTimeSeconds` never reads the tank arrays the render thread mutates.
    private var longestCombSamples: Int

    public init(sampleRate: Float = 48000) {
        let rate = Self.usableRate(sampleRate)
        self.sampleRate = rate
        combCount = Self.combTuning.count
        apCount = Self.allpassTuning.count

        let tanks = Self.makeTanks(rate: rate)
        combBufL = tanks.combL
        combBufR = tanks.combR
        apBufL = tanks.allpassL
        apBufR = tanks.allpassR
        longestCombSamples = tanks.longestComb
        combIdxL = [Int](repeating: 0, count: combCount)
        combIdxR = [Int](repeating: 0, count: combCount)
        combStoreL = [Float](repeating: 0, count: combCount)
        combStoreR = [Float](repeating: 0, count: combCount)
        apIdxL = [Int](repeating: 0, count: apCount)
        apIdxR = [Int](repeating: 0, count: apCount)

        updateDamping()
    }

    /// ⭐ Re-points the reverb at a new rate (2026-09-24). Every tank is rebuilt at the
    /// rate-scaled Freeverb tuning — the same rule as `init` — and the state starts empty, so a
    /// re-pointed instance is indistinguishable from one constructed at that rate. Before this
    /// existed, a reverb built at 48 kHz and run in a 96 kHz host had delay lines half as long
    /// in SECONDS: a smaller, shorter, differently coloured room than the one it was tuned as.
    ///
    /// ⚠️ ALLOCATES. Control plane only, and only while no render is in flight: the AUv3 calls
    /// it in `allocateRenderResources`, the one moment Apple guarantees that. The OBJECT a render
    /// block holds is never reseated — only the arrays inside it are replaced.
    /// A call at the current rate changes nothing, so the 48 kHz path stays bit-identical.
    public func setSampleRate(_ newRate: Float) {
        let rate = Self.usableRate(newRate)
        guard rate != sampleRate else { return }
        sampleRate = rate
        let tanks = Self.makeTanks(rate: rate)
        combBufL = tanks.combL
        combBufR = tanks.combR
        apBufL = tanks.allpassL
        apBufR = tanks.allpassR
        longestCombSamples = tanks.longestComb
        // The old write positions may lie past the end of the new, shorter tanks.
        for i in 0..<combCount {
            combIdxL[i] = 0; combIdxR[i] = 0
            combStoreL[i] = 0; combStoreR[i] = 0
        }
        for i in 0..<apCount {
            apIdxL[i] = 0; apIdxR[i] = 0
        }
    }

    /// Time (s) for the slowest mode to fall by 60 dB: the longest comb, at DC, where the
    /// damping lowpass has unity gain and the loop gain is exactly `combFeedback`
    /// (T60 = delay · 3 / −log10 g). Every other mode decays faster. This bounds the energy
    /// left in the COMB tanks; it is NOT a bound on the output. Measured 2026-09-24 in a
    /// transcription of this file: an output read against its own note-off level took up to
    /// 2.85 s at the 0.72 default, against 2.49 s from this formula.
    /// ⛔ The first version of this comment blamed "the eight combs partly cancel in the sum".
    /// The 2026-09-25 DSP review (reasoned, not measured) points at the output stages instead:
    /// Freeverb's four "allpass" diffusers are not unity-gain (|H| runs 1…1.667 each, up to
    /// ~7.7× over the cascade), so as the tail narrows to the slowest modes its level relative to
    /// the broadband note-off level can rise by up to ~17.7 dB — about 0.7 s at this decay rate —
    /// and the cascade adds its own ring (~0.37 s). Both are consistent with the +0.36 s measured;
    /// neither is proven by it. Anything that needs a true output bound adds a margin on top.
    /// Read from the control plane only.
    public var decayTimeSeconds: Double {
        let g = Double(combFeedback)
        guard g > 0 else { return 0 }
        guard g < 1 else { return .infinity }
        return Double(longestCombSamples) / Double(sampleRate) * 3 / -log10(g)
    }

    /// A rate the tank sizing can use: NaN, zero or a negative rate becomes 1 Hz (every tank one
    /// sample long), and an absurd rate is capped, so `Int(·)` below can never trap.
    private static func usableRate(_ rate: Float) -> Float {
        rate.clamped(to: 1...768_000)
    }

    private struct Tanks {
        var combL: [[Float]]
        var combR: [[Float]]
        var allpassL: [[Float]]
        var allpassR: [[Float]]
        var longestComb: Int
    }

    /// The tanks for `rate` — the Freeverb tunings are samples at 44.1 kHz, scaled to the rate.
    private static func makeTanks(rate: Float) -> Tanks {
        let scale = rate / 44100.0
        func scaled(_ n: Int) -> Int { Swift.max(1, Int(Float(n) * scale)) }
        let combL = combTuning.map { [Float](repeating: 0, count: scaled($0)) }
        let combR = combTuning.map { [Float](repeating: 0, count: scaled($0 + stereoSpread)) }
        let longest = (combL + combR).map(\.count).max() ?? 1
        return Tanks(
            combL: combL, combR: combR,
            allpassL: allpassTuning.map { [Float](repeating: 0, count: scaled($0)) },
            allpassR: allpassTuning.map { [Float](repeating: 0, count: scaled($0 + stereoSpread)) },
            longestComb: longest)
    }

    private func updateDamping() {
        // ⭐ 2026-09-25 (overnight P8): both controls are clamped to their documented 0…1 HERE,
        // at the type. They reached the coefficients raw, and the one writer that is not
        // range-bound — `FXPreset.apply`, from a decoded preset file with no range check — could
        // hand over a finite 1.5: room above ~1.07 puts `combFeedback` ≥ 1; damping above 1 makes
        // the damping one-pole grow every sample, and damping well below 0 lifts the loop gain at
        // Nyquist above 1. The combs diverge to inf, then NaN, and the tank LATCHES it: `reset()`
        // (re-enable edge, idle drain) clears the tank but not these coefficients, so with the bad
        // value still stored it diverged again — only an in-range write ended it.
        // `decayTimeSeconds` reported infinity for the room case (no AUv3 impact: nothing writes
        // the AUv3's room, and `tailSeconds` maps infinity to a finite value). A NaN did the same
        // directly. `clamped(to:)` maps NaN to 0 and is bit-identical for every
        // in-range value, which is every value a shipped producer writes (GenreFX, the curated
        // library, the UI fields and the bio routes are all 0…1). The stored property keeps
        // what was written, so a preset round-trips unchanged.
        // Guard: `TheReverbTankCannotBeDrivenUnstableTests`.
        let room = roomSize.clamped(to: 0...1)
        let damp = damping.clamped(to: 0...1)
        combFeedback = room * Self.roomScale + Self.roomOffset
        combDamp1 = damp
        combDamp2 = 1.0 - damp
    }

    @inline(__always)
    public func processStereo(_ inL: Float, _ inR: Float) -> (Float, Float) {
        // ⭐ 2026-09-25 (overnight P8x): `clamped(to:)`, the repo's NaN-safe clamp. The old
        // `min(max(mix, 0), 1)` is the argument order that passes NaN straight through
        // (CLAUDE.md, API gotchas), so a NaN mix put NaN on the output. NaN now reads as 0
        // (dry); every finite value clamps exactly as before.
        // Guard: `TheReverbCannotPassANaNControlTests`.
        let m = mix.clamped(to: 0...1)
        if m <= 0 { return (inL, inR) }

        // Mono excitation into the tank (Freeverb feeds the sum, scaled).
        let input = (inL + inR) * Self.fixedGain

        var outL: Float = 0
        var outR: Float = 0

        // Parallel damped feedback combs.
        for i in 0..<combCount {
            outL += comb(input, buf: &combBufL[i], idx: &combIdxL[i], store: &combStoreL[i])
            outR += comb(input, buf: &combBufR[i], idx: &combIdxR[i], store: &combStoreR[i])
        }
        // Series allpass diffusers.
        for i in 0..<apCount {
            outL = allpass(outL, buf: &apBufL[i], idx: &apIdxL[i])
            outR = allpass(outR, buf: &apBufR[i], idx: &apIdxR[i])
        }

        // Stereo spread of the wet signal.
        let w = width.clamped(to: 0...1)   // NaN → 0 (P8x), finite values unchanged
        let wet1 = w * 0.5 + 0.5
        let wet2 = (1.0 - w) * 0.5
        let wetL = outL * wet1 + outR * wet2
        let wetR = outR * wet1 + outL * wet2

        let dry = 1.0 - m
        return (inL * dry + wetL * m, inR * dry + wetR * m)
    }

    /// ⚠️ AUDIO-THREAD REACHABLE — bulk fill, not a nested element loop (#1196b). Same reason
    /// as `EchoelDelayLine.reset()`, and this one was the worse shape: a NESTED
    /// array-of-arrays loop, so every store paid two bounds checks plus the inner array's
    /// uniqueness check. The tank is ~26 000 floats; the cost was never the tank, it was the
    /// per-element overhead. Bit-identical result.
    ///
    /// ⚠️ The caller's ownership rule (audio thread drains only ENABLED stages, control plane
    /// only DISABLED ones) is untouched — see `EchoelFXChain.noteRenderSleeping`. Making this
    /// faster is not a licence to call it from both sides.
    ///
    /// ⛔ #1196b INTRODUCED THE SAME HAZARD IN TWO FILES AND ONLY ONE OF THEM WROTE IT DOWN.
    /// `withUnsafeMutableBufferPointer` swaps the array for the empty-storage singleton for
    /// the duration of the closure, so a reader that indexes it in that window sees a
    /// ZERO-COUNT array — `Index out of range`, a TRAP on the audio thread, where the nested
    /// element loop this replaced left only a half-cleared tank (a click). The control plane
    /// reaches this `reset()` on the rising edge of `EchoelFXChain.reverbEnabled`, and the
    /// disjointness from the audio thread rests on SOURCE ORDER, not on a fence.
    /// `EchoelDelayLine.reset()` carried that analysis alone for one cycle — the #937 shape
    /// this repo keeps paying for: one form repaired, the twin left broken and unnamed.
    ///
    /// ⭐ #1203 GATES BOTH. `comb` and `allpass` now check `idx < buf.count` before they
    /// index. Read `EchoelDelayLine.reset()` for the full argument, including the part that
    /// matters most: this is a NARROWING, not a fix, and the residual window is UNMEASURED.
    /// Eight comb tanks and four allpass tanks per channel bottom out here.
    public func reset() {
        for i in 0..<combCount {
            combBufL[i].withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
            combBufR[i].withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
            combIdxL[i] = 0; combIdxR[i] = 0
            combStoreL[i] = 0; combStoreR[i] = 0
        }
        for i in 0..<apCount {
            apBufL[i].withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
            apBufR[i].withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
            apIdxL[i] = 0; apIdxR[i] = 0
        }
    }

    // MARK: - Filter primitives

    /// Lowpass-feedback comb filter (Freeverb's `comb`).
    @inline(__always)
    private func comb(_ input: Float, buf: inout [Float], idx: inout Int, store: inout Float) -> Float {
        // #1203 — see `reset()`. `idx` is only ever 0 or a wrapped increment, so it cannot be
        // negative; the ONLY reachable out-of-range state is storage that is not the real
        // tank. This costs nothing new in kind: the wrap two lines down already reads
        // `buf.count` on every sample.
        guard idx < buf.count else { return 0 }
        let output = buf[idx]
        // + tiny DC keeps the decaying feedback state out of the denormal range
        // (< ~1e-38), where each sample would trigger a CPU stall → audible crackle
        // on the reverb tail. 1e-20 is inaudible (steady-state DC ≈ 1e-19).
        store = output * combDamp2 + store * combDamp1 + 1.0e-20
        buf[idx] = input + store * combFeedback
        idx += 1
        if idx >= buf.count { idx = 0 }
        return output
    }

    /// Schroeder allpass diffuser (Freeverb's `allpass`).
    @inline(__always)
    private func allpass(_ input: Float, buf: inout [Float], idx: inout Int) -> Float {
        // #1203 — see `reset()`, and the same reasoning as `comb` above.
        guard idx < buf.count else { return 0 }
        let bufout = buf[idx]
        let output = -input + bufout
        buf[idx] = input + bufout * Self.allpassFeedback
        idx += 1
        if idx >= buf.count { idx = 0 }
        return output
    }
}

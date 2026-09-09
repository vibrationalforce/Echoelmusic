import Foundation

/// Fractional-delay ring buffer — the shared foundation for every delay-based
/// effect (delay, chorus, flanger). Zero allocation in the audio path, no
/// branching in the hot loop: capacity is rounded up to a power of two so the
/// wrap is a single bitmask.
///
/// Indexing contract: `write(_:)` stores at the head and advances; a `read`
/// with `delaySamples == 1` returns the most recently written sample, `2`
/// returns the one before it, and so on. Negative wrap is handled by the mask
/// (two's-complement `& mask` == modulo for power-of-two capacity).
///
/// Reference: Julius O. Smith III, "Physical Audio Signal Processing" —
/// delay-line interpolation (linear & first-order allpass).
public final class EchoelDelayLine: @unchecked Sendable {

    // MARK: - Storage

    private var buffer: [Float]
    private let capacity: Int       // power of two
    private let mask: Int
    private var writeIndex: Int = 0

    /// First-order allpass interpolation state (single-tap use only).
    private var apPrev: Float = 0

    public let sampleRate: Float
    public let maxDelaySamples: Int

    /// Upper bound on the frame count that reaches `Int(_:)` in `init` (#1171). 2^20 frames
    /// is ~21.8 s at 48 kHz — TEN TIMES the longest line any shipped stage requests (2.0 s,
    /// `EchoelDelay`'s default) — so no real request can touch it. It exists to turn an
    /// overflow into a BOUNDED allocation instead of a trap.
    ///
    /// The size is chosen, not arbitrary: the capacity rounds up to the next power of two, so
    /// this cap costs at most 2^21 Floats = 8 MB on a garbage input. The first draft used
    /// 2^22 and would have allocated 33 MB against a 200 MB budget — for an input that is
    /// already nonsense. A defensive bound that is itself expensive is a poor bound.
    private static let maxFrames: Float = 1_048_576

    // MARK: - Init

    /// #1171 — THE TRAP IS HERE, AND IT WAS GUARDED AT ONE CALLER OUT OF FIVE.
    /// `Int(_: Float)` traps on `.nan`, on `.infinity`, and on any finite value past
    /// `Int.max`. The old line read
    /// `Swift.max(4, Int((maxDelaySeconds * sampleRate).rounded(.up)) + 4)` — and
    /// `Swift.max` runs AFTER the conversion, so the net hung behind the hole.
    ///
    /// FIVE stage initialisers build a line from a rate they did not check —
    /// `EchoelTape`, `EchoelHarmonizer`, `EchoelChorus`, `EchoelDelay` all store
    /// `self.sr = sampleRate` raw. `EchoelGranular` is the ONLY one that guards, and its
    /// comment names this exact site: "reaches `Int((inf * sr).rounded(.up))` inside
    /// `EchoelDelayLine.init`, which TRAPS". That is #937 — one form repaired, four twins
    /// left broken — so the repair belongs at the shared site, not at five call sites.
    /// `EchoelGranular`'s guard stays: it is now belt-and-braces, and correct.
    ///
    /// BIT-IDENTICAL FOR EVERY PREVIOUSLY-VALID INPUT. The clamp keeps the old SHAPE —
    /// `Swift.max(4, Int(...) + 4)` — and only bounds what feeds the conversion, so a
    /// 0.05 s line at 48 kHz still yields 2404 exactly as before — verified across every
    /// request the shipped stages actually make (0.05/0.12/1.0/2.0 s at 44.1/48/96 kHz).
    /// ONE input changes, and it is named rather than hidden: a rate of exactly 0 used to
    /// produce `wanted = 4`, i.e. a two-sample line that can hold no delay at all; it now
    /// falls back to 48 kHz and yields the requested length. That input was never valid.
    /// Argument order is
    /// deliberate: `Swift.max(0, NaN)` returns 0 because `NaN >= 0` is false, while the
    /// reversed `Swift.max(NaN, 0)` returns NaN and traps one line later.
    ///
    /// ⚠️ LATENT, NOT LIVE: every caller today passes a literal 48 kHz, or is guarded
    /// upstream (`MonitorInsertAU` checks `negotiated.isFinite, negotiated > 0`). Closed on
    /// engineering.md's boundary rule — non-finite at a DSP boundary is an edge case, not an
    /// impossibility — and because a trap is a crash, not a degraded sound.
    public init(maxDelaySeconds: Float = 2.0, sampleRate: Float = 48000) {
        let rate = (sampleRate.isFinite && sampleRate > 0) ? sampleRate : 48000
        let seconds = (maxDelaySeconds.isFinite && maxDelaySeconds > 0) ? maxDelaySeconds : 2.0
        self.sampleRate = rate
        // `seconds * rate` is finite-times-finite, which cannot be NaN but CAN overflow to
        // `.infinity`; `Swift.min` catches that. The cap is ~21.8 s at 48 kHz — ten times the
        // longest line any stage asks for (2.0 s), so no real request is touched.
        let frames = Swift.min(Self.maxFrames, Swift.max(0, (seconds * rate).rounded(.up)))
        let wanted = Swift.max(4, Int(frames) + 4)
        self.capacity = EchoelDelayLine.nextPowerOfTwo(wanted)
        self.mask = capacity - 1
        self.maxDelaySamples = capacity - 2
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    // MARK: - Write

    /// Push one sample into the line. Audio-thread safe.
    @inline(__always)
    public func write(_ x: Float) {
        buffer[writeIndex] = x
        writeIndex = (writeIndex &+ 1) & mask
    }

    // MARK: - Read (linear interpolation)

    /// Read the line `delaySamples` in the past with linear interpolation.
    /// `delaySamples` is clamped to `[1, maxDelaySamples]`. Audio-thread safe.
    @inline(__always)
    public func read(delaySamples: Float) -> Float {
        // NaN-safe. `Swift.min(Swift.max(x, 1), max)` is a no-op for NaN (every
        // comparison against NaN is false), and the very next line is `Int(d)`, which
        // TRAPS on NaN — a crash on the audio thread, not a degradation.
        let d = delaySamples.clamped(to: 1.0...Float(maxDelaySamples))
        let i0 = Int(d)
        let frac = d - Float(i0)
        let idx0 = (writeIndex &- i0) & mask
        let idx1 = (idx0 &- 1) & mask
        return buffer[idx0] * (1.0 - frac) + buffer[idx1] * frac
    }

    // MARK: - Read (first-order allpass interpolation)

    /// Read with first-order allpass interpolation — flatter magnitude response
    /// than linear, preferred for smoothly modulated taps (flanger/chorus).
    /// Assumes a single modulated read tap (keeps one filter state).
    @inline(__always)
    public func readAllpass(delaySamples: Float) -> Float {
        // NaN-safe. `Swift.min(Swift.max(x, 1), max)` is a no-op for NaN (every
        // comparison against NaN is false), and the very next line is `Int(d)`, which
        // TRAPS on NaN — a crash on the audio thread, not a degradation.
        let d = delaySamples.clamped(to: 1.0...Float(maxDelaySamples))
        let i0 = Int(d)
        let frac = d - Float(i0)
        let idx0 = (writeIndex &- i0) & mask
        let idx1 = (idx0 &- 1) & mask
        // eta in [0,1); coefficient for the allpass interpolator
        let eta = (1.0 - frac) / (1.0 + frac)
        let s0 = buffer[idx0]
        let s1 = buffer[idx1]
        let out = s1 + eta * (s0 - apPrev)
        apPrev = out
        return out
    }

    // MARK: - Reset

    /// ⚠️ THIS RUNS ON THE AUDIO THREAD, and that is why the fill is bulk (#1196b).
    /// `PolySynthVoice.renderOnAudioThread` calls `EchoelFXChain.noteRenderSleeping()` 2.5 s
    /// after a voice goes quiet, and that drains every ENABLED stage — delay, granular,
    /// harmonizer, chorus, flanger and tape all bottom out HERE. `EchoelDelay` alone takes
    /// `maxDelaySeconds: 2.0`, so one `reset()` can clear 131 072 floats per channel; a whole
    /// drain is on the order of 1.8 MB, inside a 10.67 ms render deadline — and four voices
    /// go quiet in the SAME block when the composer stops, so it convoys.
    ///
    /// A per-element Array-subscript zero loop — the shape this used to be — is NOT lowered
    /// to a `memset`: every element carries a bounds check and the loop carries the array's
    /// uniqueness check. (The retracted spelling is deliberately NOT quoted here: the guard
    /// asserts its ABSENCE from this file, and a quote of it in prose is the #491 shape —
    /// it survives only because `codeLines` happens to strip `//` lines, and a guard that
    /// depends on that accident is one refactor from failing on correct code. It also makes
    /// `scripts/moved-needles.py` report this file forever.) A single
    /// `update(repeating:)` is one exclusivity check and one bulk store — `memcpy`/`memset`
    /// class writes are on the SAFE list in `.claude/rules/swift-audio.md`, an Array subscript
    /// loop is not. Bit-identical result; it is the same zeroes, written the fast way.
    ///
    /// ⚠️ THE CALLER'S THREAD-OWNERSHIP RULE IS UNCHANGED and is what makes this safe at all:
    /// the audio thread drains a stage only while its enable flag is TRUE, the control plane
    /// only while it is FALSE (the reasoning is in `EchoelFXChain.noteRenderSleeping`'s ⛔
    /// block — do not weaken it on the strength of this one being faster).
    ///
    /// ⛔ AND THAT RULE RESTS ON SOURCE ORDER, NOT ON THE MEMORY MODEL — `PolySynthVoice`
    /// says so itself, and #1196b's mandatory review is what connected the two halves. THIS
    /// CHANGE SHARPENS THE CONSEQUENCE IF THE RACE EVER FIRES, at unchanged probability, and
    /// that is the one thing a future session must not learn from a crash report instead:
    /// `fxEnabled` is a plain non-atomic `Bool` with no fence, and the control-plane drain is
    /// reachable from a live user control (the FX sheet). Under the element loop this
    /// degraded to a HALF-CLEARED BUFFER — an audible click. `withUnsafeMutableBufferPointer`
    /// swaps the array for the empty-storage singleton for the duration of the closure, so a
    /// concurrent `read(delaySamples:)` would index a ZERO-COUNT array: `Index out of range`,
    /// i.e. a TRAP on the audio thread. Click → crash.
    ///
    /// NOT REVERTED, and the reasoning is the trade, not a shrug: the crackle this repairs is
    /// certain and reported from the device; the race is documented-but-unobserved. The
    /// candidate remedy for a later slice is `vDSP_vclr`, whose implicit array-to-pointer
    /// conversion is believed not to perform that swap — BELIEVED, not measured, and it would
    /// give this file its first `import Accelerate`. Do not take it on the strength of this
    /// sentence; the honest fix for the underlying hazard is to fence `fxEnabled`, which is a
    /// different slice with a different owner.
    public func reset() {
        buffer.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        writeIndex = 0
        apPrev = 0
    }

    // MARK: - Helpers

    @inline(__always)
    private static func nextPowerOfTwo(_ n: Int) -> Int {
        var p = 1
        while p < n { p <<= 1 }
        return p
    }
}

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
        // #1203 — see `reset()`. NOTE THE ASYMMETRY WITH THE TWO READERS: this index is not
        // masked at the use site. It is safe because `writeIndex` is STORED masked — the line
        // below, plus 0 in `init` and in `reset()`. Drop the `& mask` there and this gate does
        // NOT catch it: `buffer.count == capacity` says nothing about `writeIndex`.
        // Returning also skips the advance, which is the right pairing (an advance without a
        // store would leave a stale sample at the head) and is moot anyway: the `reset()` that
        // opened the window re-zeroes `writeIndex` before it closes.
        guard buffer.count == capacity else { return }
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
        // #1203 — see `reset()`. `x & mask` lands in [0, capacity - 1] for ANY x, negative
        // wrap included, so for THESE two indices the only reachable out-of-range state is
        // storage that is not the real buffer. Zero is the right answer for a line being
        // cleared: it is what the clear is about to write anyway.
        guard buffer.count == capacity else { return 0 }
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
        // #1203 — see `reset()`. Returning before `apPrev` is written costs nothing and is
        // the tidier order; do NOT read it as a benefit, though — the same `reset()` that
        // opened the window zeroes `apPrev` a few instructions later, so the state this
        // preserves is discarded either way. (`eta` above is then dead work on the drop path.)
        guard buffer.count == capacity else { return 0 }
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
    /// reachable from a live user control (the FX sheet) — and, less obviously, from
    /// `FXBioModulator`, which raises enable flags from the modulation loop, so that store
    /// happens far more often than a finger does. A THIRD control-plane path resets stages
    /// unconditionally and is NOT covered by the enable-flag rule at all:
    /// `MonitorInsertAU.allocateRenderResources()`, safe by the AU contract that the node is
    /// not rendering during (re)allocation, on a different chain instance. Under the element
    /// loop this
    /// degraded to a HALF-CLEARED BUFFER — an audible click. `withUnsafeMutableBufferPointer`
    /// swaps the array for the empty-storage singleton for the duration of the closure, so a
    /// concurrent `read(delaySamples:)` would index a ZERO-COUNT array: `Index out of range`,
    /// i.e. a TRAP on the audio thread. Click → crash.
    ///
    /// ⭐ #1203 TOOK THAT SHARPENING BACK — AND IT IS A NARROWING, NOT A FIX. Say which one
    /// this is, because the difference decides whether the fence below is still owed. All
    /// three accessors now gate on `buffer.count == capacity` before they index, so inside
    /// the window a concurrent read returns 0 and a concurrent write is dropped: the
    /// pre-#1196b severity (a click), reached without touching the memory model, the
    /// ownership rule, or this file's import list.
    ///
    /// ⚠️ ONE COMPARISON IS ENOUGH FOR THE TWO READERS AND ENOUGH-BY-ACCIDENT FOR THE WRITER.
    /// `x & mask` lands in [0, capacity - 1] for any `x`, so in `read`/`readAllpass` the only
    /// reachable out-of-range state really is foreign storage. `write` indexes `writeIndex`
    /// UNMASKED at the use site and is safe only because that field is STORED masked — a
    /// separate invariant this gate does not check. It is pinned in the guard instead.
    ///
    /// ⛔ THE SIZE OF THE REMAINING WINDOW IS **UNMEASURED**, and the first draft of this
    /// block asserted it as a fact — "two adjacent instructions, which is why each gate is
    /// placed at the index and not at the top of its function". BOTH halves were wrong.
    /// `buffer.count` and `buffer[i]` are two source-level accesses, but the compiler decides
    /// what they lower to, and it can go either way: CSE may fold them into ONE load of the
    /// storage pointer (a race is UB, so nothing single-threaded may change `buffer` between
    /// them), which CLOSES the seam and makes this a full fix; or LICM may hoist the count
    /// load out of the caller's per-sample loop — `read`/`write` are `@inline(__always)` and
    /// are called per sample from `EchoelDelay.processStereo` inside `processBuffer`'s
    /// `for i in 0..<n` — which WIDENS it to a whole render block. Source placement does not
    /// control machine placement, so the gates stay adjacent to their index because it is
    /// tidier, NOT because it buys a bound. And the rule as first written was vacuous at one
    /// of the three sites anyway: in `write` the gate IS the top of the function.
    /// There is no toolchain in a web session, so this stays UNMEASURED rather than estimated;
    /// what is certain is only the direction — the exposed window is no larger than before,
    /// and the bulk clear of up to 131 072 floats is no longer inside it.
    ///
    /// ⚠️ TWO PREMISES THIS GATE LEANS ON, LABELLED because the paragraph below declines
    /// `vDSP_vclr` on exactly this standard and it must not apply it in one direction only.
    /// (1) Lifetimes: `withUnsafeMutableBufferPointer` MOVES the real storage into the
    /// resetting frame and installs the immortal empty singleton, so a reader that loaded
    /// either reference reads live memory — read out of stdlib SOURCE, not out of a documented
    /// contract, and not measured here. (2) No torn reference: the property is one aligned
    /// 64-bit slot and arm64 gives single-copy atomicity for such loads and stores — a
    /// HARDWARE property, not a Swift-language guarantee. The race is UB either way.
    ///
    /// ⛔ AND THE ALTERNATIVE THIS BLOCK FIRST PRICED WAS THE WRONG ONE. It said the seam
    /// could be closed by binding the array to a local, "which costs a retain/release per
    /// sample". The real objection is worse and is the reason not to: a transient second
    /// reference is exactly what makes `_makeMutableAndUnique()` inside this `reset()` FAIL
    /// its uniqueness check — which allocates a new buffer and copies the old one, ON THE
    /// AUDIO THREAD. Two alternatives it did not consider at all, and one of them is the
    /// structural repair rather than a narrowing: the NON-mutating `withUnsafeBufferPointer`
    /// does not swap, so count and subscript come from one access; and storing an
    /// `UnsafeMutablePointer<Float>` allocated once in `init` removes the hazard CLASS — an
    /// immutable pointer has nothing to swap, `reset()` loses its uniqueness check, and the
    /// per-sample bounds checks go with it. `capacity` is fixed and the buffer never resizes,
    /// so nothing blocks it; it is a different slice, not a different file.
    ///
    /// STILL OWED, unchanged by this slice: `fxEnabled` is a plain non-atomic `Bool` with no
    /// fence, so the disjointness that keeps the two threads out of each other's way rests on
    /// SOURCE ORDER. Fencing it is a different slice with a different owner. `vDSP_vclr` is
    /// still NOT taken, on a corrected reason: its implicit conversion goes through
    /// `_convertMutableArrayToPointerArgument`, which does NOT install the empty singleton —
    /// readable in stdlib source, so "nothing here can measure it" was too strong. It is
    /// declined because it would still leave the half-cleared click and would give this file
    /// its first `import Accelerate`, for a hazard the pointer rewrite above removes outright.
    // NEEDS-FOUNDER-VERIFY: eine Sequenz spielen, stoppen, rund fuenf Sekunden warten, dann
    // im Master-Panel die Zeile `N late` ablesen. Der Ausschlag, der ~2,5 s NACH dem Stoppen
    // kam (alle Stimmen leeren ihre Puffer im selben Block), soll verschwunden sein (#1196b).
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

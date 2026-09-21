import Foundation

/// Brainwave frequency bands for isochronic entrainment
public enum BrainwaveBand: String, CaseIterable, Sendable {
    case delta = "Delta"     // 0.5-4 Hz — deep sleep
    case theta = "Theta"     // 4-8 Hz — meditation, REM
    case alpha = "Alpha"     // 8-13 Hz — relaxed focus
    case beta  = "Beta"      // 13-30 Hz — alert, active
    case gamma = "Gamma"     // 30-50 Hz — peak cognition

    /// Center frequency of the band
    public var centerFrequency: Float {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .beta:  return 20.0
        case .gamma: return 40.0
        }
    }

    /// Human-readable description
    public var stateDescription: String {
        switch self {
        case .delta: return "Deep Sleep"
        case .theta: return "Meditation"
        case .alpha: return "Relaxed Focus"
        case .beta:  return "Alert"
        case .gamma: return "Peak Flow"
        }
    }
}

/// Isochronic brainwave entrainment processor.
/// Applies rhythmic amplitude modulation at brainwave frequencies.
///
/// Unlike binaural beats (headphones only), isochronic tones work
/// through any speaker — they modulate the amplitude of the carrier
/// signal at the target brainwave frequency.
///
/// Audio-thread safe — no allocation.
public final class EchoelEntrainment: @unchecked Sendable {

    // MARK: - Parameters

    /// Target brainwave band
    public var band: BrainwaveBand = .alpha

    /// Entrainment depth [0-1] (0 = off, 1 = full pulse)
    public var depth: Float = 0.0

    /// Whether entrainment is active
    public var isActive: Bool { depth > 0.01 }

    // MARK: - State

    private var phase: Float = 0
    private var sampleRate: Float

    // MARK: - Init

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    /// Re-point the entrainment oscillator at a new sample rate — CONTROL PLANE ONLY.
    ///
    /// Nothing is derived: `process(_:)` reads `sampleRate` per sample. The phase is NOT reset
    /// for the same reason as `EchoelLFO.setSampleRate` — a rate change happens between
    /// renders, and restarting the cycle would be an audible discontinuity for no gain.
    ///
    /// ⚠️ IN PLACE, NOT A NEW INSTANCE — `EchoelDDSP` holds this object and its render block
    /// dereferences it (the ARC-reseat law is written out at `EchoelDDSP.updateReverbDecay`).
    /// Same refusal shape as `EchoelLFO`: a non-positive or non-finite rate keeps the last
    /// known-good one rather than inventing a second default.
    public func setSampleRate(_ newRate: Float) {
        guard newRate > 0, newRate.isFinite else { return }
        sampleRate = newRate
    }

    // MARK: - Process

    /// Process a single sample with isochronic amplitude modulation.
    /// Audio-thread safe — no allocation.
    @inline(__always)
    public func process(_ sample: Float) -> Float {
        guard depth > 0.01 else { return sample }

        // Advance phase at brainwave frequency
        phase += band.centerFrequency / sampleRate
        // ⭐ THE #1207b WRAP, COPIED HERE BECAUSE THIS SLICE IS WHAT MADE IT REACHABLE.
        // `EchoelLFO.next()`'s doc enumerated the two wraps of this form and said this one was
        // safe — correctly, at the time: the NUMERATOR is `band.centerFrequency`, a five-case
        // enum switch returning 2/6/10/20/40, which no file or setter can make large. Its
        // prediction was that a slice turning that numerator into a parameter would owe this
        // fix. The slice that arrived changed the DENOMINATOR instead (`setSampleRate` above),
        // which reaches the same runaway from the other side: at a small rate the increment is
        // far above 1, `phase -= 1.0` subtracts a rounding error off it, and the old form
        // never folds back — the phase grows every sample until it overflows to `inf`, and
        // `cosf(inf)` is NaN, i.e. permanent silence or worse downstream.
        // ⚠️ MEASURED, NOT REASONED, because the first estimate written here was three orders
        // of magnitude out: at `sampleRate = 4e-36` the increment is 1e37 — still FINITE — and
        // the phase goes non-finite on call **34**. (At 1e-30 it takes ~8,5 million calls, so
        // an estimate of "a few thousand" would have made the guard vacuous.)
        // ⚠️ The `guard` in `setSampleRate` refuses ≤ 0 and non-finite but NOT small,
        // deliberately (#364 — a bound there would forbid a legitimate future caller), so the
        // wrap is the thing that has to be total.
        //
        // NEGATED, not `>= 1.0`: every comparison against NaN is false, so an already-NaN
        // phase would take neither branch of the old form and latch forever. `inf - inf` is
        // NaN, which is why the `isFinite` test is load-bearing and not decoration.
        if !(phase >= 0.0 && phase < 1.0) {
            phase = phase.isFinite ? phase - phase.rounded(.down) : 0
        }

        // Smooth isochronic pulse: raised cosine envelope
        // Sounds smoother than a hard on/off square pulse
        let envelope = (1.0 + cosf(phase * Float.pi * 2)) * 0.5  // 0→1→0 per cycle

        // Modulate amplitude: full signal at peak, reduced at trough
        let modulation = 1.0 - depth + depth * envelope
        return sample * modulation
    }

    /// Process a buffer in-place
    public func processBuffer(_ buffer: inout [Float], frameCount: Int) {
        guard depth > 0.01 else { return }
        for i in 0..<frameCount {
            buffer[i] = process(buffer[i])
        }
    }

    /// Reset phase
    public func reset() {
        phase = 0
    }
}

import Foundation

/// Peak / RMS / true-peak meter. Audio-thread safe (no allocation or locks in
/// the measurement loop). True peak is the ITU-R BS.1770-4 4× estimate
/// (`EchoelTruePeak` — the SAME estimator the export is bounded by), always ≥ the
/// sample peak.
///
/// ⛔ Until LS-TP2 (2026-10-16) this was a Catmull-Rom interpolation at t = ¼, ½, ¾.
/// Emulated against a 64× band-limited reference it read up to 2.2 dB UNDER (a
/// quarter-rate tone 45° off: −1.07 dBTP for a unit crest), so the "dBTP" on the
/// Master readout said there was headroom that a DAC did not have.
///
/// Readings are held with per-call decay so a UI meter falls back smoothly;
/// `reset()` returns to the −120 dB floor.
public final class EchoelMeter: @unchecked Sendable {

    public static let floorDb: Float = -120

    /// Held sample-peak level in dBFS.
    public private(set) var peakDb: Float = floorDb
    /// Block RMS level in dBFS.
    public private(set) var rmsDb: Float = floorDb
    /// Held true-peak (inter-sample) level in dBTP.
    public private(set) var truePeakDb: Float = floorDb
    /// Max-hold true-peak (dBTP) — the highest inter-sample peak since the last
    /// `reset()`, never decays. Pro mastering reference for "did it ever clip".
    public private(set) var truePeakMaxDb: Float = floorDb

    /// Per-call hold decay (linear multiplier applied to the held peak before
    /// taking the max with the new block). 1.0 = infinite hold.
    public var holdDecay: Float = 0.85

    private var heldPeak: Float = 0
    private var heldTruePeak: Float = 0
    private var maxTruePeak: Float = 0

    // Each side is interpolated from its OWN signed history (the estimator keeps one per
    // channel); feeding one channel the linked/rectified value would skew the estimate.
    private var truePeakEstimator = EchoelTruePeak(channels: 2)

    public init() {}

    // MARK: - Process

    /// Measure a mono buffer. Audio-thread safe.
    public func process(_ buf: [Float], frameCount: Int) {
        let n = Swift.min(frameCount, buf.count)
        guard n > 0 else { return }
        var peak: Float = 0
        var sumSq: Float = 0
        for i in 0..<n {
            let x = buf[i]
            let a = abs(x)
            if a > peak { peak = a }
            sumSq += x * x
        }
        let tp = buf.withUnsafeBufferPointer { b -> Float in
            guard let base = b.baseAddress else { return 0 }
            return truePeakEstimator.append(left: base, right: nil, frameCount: n)
        }
        commit(peak: peak, rms: sqrtf(sumSq / Float(n)), truePeak: Self.reported(tp, peak))
    }

    /// Measure a stereo pair, linking channels (the louder side drives the meter).
    public func processStereo(left: [Float], right: [Float], frameCount: Int) {
        let n = Swift.min(frameCount, Swift.min(left.count, right.count))
        guard n > 0 else { return }
        left.withUnsafeBufferPointer { lb in
            right.withUnsafeBufferPointer { rb in
                guard let l = lb.baseAddress, let r = rb.baseAddress else { return }
                processStereo(left: l, right: r, frameCount: n)
            }
        }
    }

    public func reset() {
        peakDb = Self.floorDb; rmsDb = Self.floorDb; truePeakDb = Self.floorDb
        truePeakMaxDb = Self.floorDb
        heldPeak = 0; heldTruePeak = 0; maxTruePeak = 0
        truePeakEstimator.reset()
    }

    /// Measure a stereo pair from raw channel pointers — no allocation, for use
    /// inside an `AVAudioEngine` tap callback. `right` may be nil for mono (the
    /// left channel is then used for both sides). Channels are linked: the louder
    /// side drives the meter.
    public func processStereo(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount n: Int) {
        guard n > 0 else { return }
        var peak: Float = 0
        var sumSq: Float = 0
        for i in 0..<n {
            let l = left[i]
            let r = right?[i] ?? l
            let a = Swift.max(abs(l), abs(r))
            if a > peak { peak = a }
            sumSq += (l * l + r * r) * 0.5
        }
        let tp = truePeakEstimator.append(left: left, right: right, frameCount: n)
        commit(peak: peak, rms: sqrtf(sumSq / Float(n)), truePeak: Self.reported(tp, peak))
    }

    // MARK: - Helpers

    @inline(__always)
    private func commit(peak: Float, rms: Float, truePeak: Float) {
        heldPeak = Swift.max(peak, heldPeak * holdDecay)
        heldTruePeak = Swift.max(truePeak, heldTruePeak * holdDecay)
        maxTruePeak = Swift.max(maxTruePeak, truePeak)
        peakDb = Self.db(heldPeak)
        truePeakDb = Self.db(heldTruePeak)
        truePeakMaxDb = Self.db(maxTruePeak)
        rmsDb = Self.db(rms)
    }

    /// The meter IGNORES a non-finite sample, as it always has (a NaN never wins a `>`), so a
    /// block whose estimate came back NaN reports its sample peak instead of poisoning the hold.
    /// (The EXPORT keeps the NaN on purpose — there it must refuse a boost.)
    @inline(__always)
    private static func reported(_ truePeak: Float, _ samplePeak: Float) -> Float {
        truePeak.isNaN ? samplePeak : Swift.max(truePeak, samplePeak)
    }

    public static func db(_ linear: Float) -> Float {
        guard linear > 1e-6 else { return floorDb }
        return Swift.max(floorDb, 20.0 * log10f(linear))
    }
}

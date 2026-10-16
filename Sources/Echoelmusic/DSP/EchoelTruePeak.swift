import Foundation

/// ITU-R BS.1770-4 Annex 2 true-peak estimate: 4× oversampling through the 48-tap
/// interpolation filter the Recommendation tabulates (four phases × 12 taps), and the
/// reading is the largest of |sample| and every interpolated value. That is what "dBTP"
/// means in a delivery spec — the number a loudness-normalised export is bounded by.
///
/// STATEFUL PER CHANNEL. An interleaved stream may arrive in segments of any length — an
/// `AVAssetReader` block can end between the left and the right sample of a frame — and the
/// estimator carries both the channel position and each channel's 12-sample history across
/// the boundary, so a stream read in pieces measures exactly like one pass.
///
/// THE TABLE IS USED AS PUBLISHED, unaltered. Its two intermediate phases sum to 0.973, not 1
/// (the outer two to 1.0016), so on slowly varying material the interpolated values sit a
/// hair under the samples — which is why |sample| always enters the maximum and the reading
/// can never fall below the sample peak.
///
/// ⚠️ WHAT IT IS NOT. A 4× estimate, not the band-limited peak: on material with energy near
/// Nyquist it can read up to ~1 dB under the infinitely oversampled value (emulated against
/// a 64× FFT interpolation of short windowed bursts; the old Catmull-Rom estimate in
/// `EchoelMeter` read up to ~2.2 dB under on the same set). It knows nothing about what a
/// lossy ENCODER does after it — codec overshoot is a separate margin.
///
/// Allocation-free after `init` (the history is pre-sized and written in place), so it is
/// usable on a render thread as well as offline. A NaN is kept once seen, so a caller that
/// bounds a gain by the reading refuses rather than trusting a partial measurement.
public struct EchoelTruePeak: Sendable {

    /// Phase 0 of the BS.1770-4 Annex 2 interpolation filter (Table 1).
    /// Phase 3 is phase 0 reversed, phase 2 is phase 1 reversed.
    public static let phase0: [Float] = [
        0.0017089843750, 0.0109863281250, -0.0196533203125, 0.0332031250000,
        -0.0594482421875, 0.1373291015625, 0.9721679687500, -0.1022949218750,
        0.0476074218750, -0.0266113281250, 0.0148925781250, -0.0083007812500,
    ]

    /// Phase 1 of the BS.1770-4 Annex 2 interpolation filter (Table 1).
    public static let phase1: [Float] = [
        -0.0291748046875, 0.0292968750000, -0.0517578125000, 0.0891113281250,
        -0.1665039062500, 0.4650878906250, 0.7797851562500, -0.2003173828125,
        0.1015625000000, -0.0582275390625, 0.0330810546875, -0.0189208984375,
    ]

    public static let tapsPerPhase = 12

    public let channels: Int

    /// Largest linear true-peak magnitude since `init`/`reset()`. NaN once a NaN was read.
    public private(set) var peak: Float = 0

    /// Per channel a doubled ring of 2 × 12 samples, so the 12 newest are always contiguous.
    private var ring: [Float]
    private var write = 0
    private var channel = 0

    public init(channels: Int) {
        self.channels = Swift.max(1, channels)
        ring = [Float](repeating: 0, count: self.channels * 2 * Self.tapsPerPhase)
        // A `static let` is initialised lazily, on first read — touch both tables HERE so that
        // first read (and its allocation) never lands on a render thread.
        _ = Self.phase0.count + Self.phase1.count
    }

    public mutating func reset() {
        peak = 0
        write = 0
        channel = 0
        for i in ring.indices { ring[i] = 0 }
    }

    /// Feed `sampleCount` interleaved floats. Segments may split a frame. Returns the largest
    /// true-peak magnitude in THIS block (NaN if a NaN arrived in it) and folds it into `peak`.
    @discardableResult
    public mutating func append(interleaved samples: UnsafePointer<Float>, sampleCount: Int) -> Float {
        guard sampleCount > 0 else { return 0 }
        let channels = self.channels
        // Locals, written back after: touching `self.write` inside the closure would overlap
        // the exclusive access to `self.ring`.
        var block: Float = 0
        var write = self.write
        var channel = self.channel
        ring.withUnsafeMutableBufferPointer { buf in
            guard let r = buf.baseAddress else { return }
            Self.withTables { p0, p1 in
                for i in 0..<sampleCount {
                    let v = Self.push(samples[i], into: r, base: channel * 2 * Self.tapsPerPhase,
                                      write: write, p0, p1)
                    // `v.isNaN ||` keeps a NaN once seen: `Swift.max` would drop it.
                    if v.isNaN || v > block { block = v }
                    channel += 1
                    if channel == channels {
                        channel = 0
                        write = (write + 1) % Self.tapsPerPhase
                    }
                }
            }
        }
        self.write = write
        self.channel = channel
        fold(block)
        return block
    }

    /// Feed planar stereo — a tap's two channel pointers — frame by frame; `right == nil`
    /// feeds the left channel to both sides. Only for a two-channel estimator (any other count
    /// measures nothing and returns 0). Allocation-free: this is the live meter's path.
    @discardableResult
    public mutating func append(left: UnsafePointer<Float>, right: UnsafePointer<Float>?,
                                frameCount: Int) -> Float {
        guard frameCount > 0, channels == 2, channel == 0 else { return 0 }
        var block: Float = 0
        var write = self.write
        ring.withUnsafeMutableBufferPointer { buf in
            guard let r = buf.baseAddress else { return }
            Self.withTables { p0, p1 in
                for i in 0..<frameCount {
                    let l = left[i]
                    let vl = Self.push(l, into: r, base: 0, write: write, p0, p1)
                    let vr = Self.push(right?[i] ?? l, into: r, base: 2 * Self.tapsPerPhase,
                                       write: write, p0, p1)
                    if vl.isNaN || vl > block { block = vl }
                    if vr.isNaN || vr > block { block = vr }
                    write = (write + 1) % Self.tapsPerPhase
                }
            }
        }
        self.write = write
        fold(block)
        return block
    }

    private mutating func fold(_ block: Float) {
        if block.isNaN || block > peak { peak = block }
    }

    /// Both coefficient tables as raw pointers, fetched ONCE per block: read through the
    /// `static let` per tap they would cost an init check, a bounds check and a possible
    /// retain/release 48 times a sample (audio-thread review, LS-TP2). If a table could not
    /// lend its storage the block measures nothing rather than reading out of bounds.
    @inline(__always)
    private static func withTables(_ body: (UnsafePointer<Float>, UnsafePointer<Float>) -> Void) {
        phase0.withUnsafeBufferPointer { a in
            phase1.withUnsafeBufferPointer { b in
                guard let p0 = a.baseAddress, let p1 = b.baseAddress,
                      a.count == tapsPerPhase, b.count == tapsPerPhase else { return }
                body(p0, p1)
            }
        }
    }

    /// The ONE interpolation: write `x` into its channel's doubled ring at `write`, run the four
    /// phases over the 12 newest samples, return max(|x|, |y0…y3|).
    @inline(__always)
    private static func push(_ x: Float, into r: UnsafeMutablePointer<Float>, base: Int, write: Int,
                             _ phase0: UnsafePointer<Float>, _ phase1: UnsafePointer<Float>) -> Float {
        let taps = tapsPerPhase
        r[base + write] = x
        r[base + write + taps] = x
        // Newest sample at `newest`, the one k steps older at `newest - k`.
        let newest = base + write + taps
        var y0: Float = 0, y1: Float = 0, y2: Float = 0, y3: Float = 0
        for k in 0..<taps {
            let h = r[newest - k]
            y0 += phase0[k] * h
            y1 += phase1[k] * h
            y2 += phase1[taps - 1 - k] * h
            y3 += phase0[taps - 1 - k] * h
        }
        return Swift.max(Swift.max(abs(x), abs(y0)),
                         Swift.max(Swift.max(abs(y1), abs(y2)), abs(y3)))
    }
}

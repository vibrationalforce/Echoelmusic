// WaveformReducer.swift
// Echoel — pure waveform reduction (Stage 2 core). Research-validated pro
// rendering: per pixel-column keep MIN and MAX (visual extremes survive) plus
// RMS (the inner "body" layer). Never draw raw PCM. Pure Foundation —
// Linux-CI-testable.
//
// ⭐ LIVE AGAIN SINCE AUDIO EDITOR W1 (2026-10-08). Its consumer is
// `Sequencer/WaveformSketch`: the overview of a media file is folded with
// `foldStereo`, bucketed with `reduce`, and each display column of an audio part on
// the Arrange canvas is the `join` of the buckets a column overlaps — the same
// algebra as `downsample` of that span, without copying it. `downsample` is
// `join` repeated, so there is still one reduction rule (#416).
//
// ⭐ A column used to call `downsample(Array(slice), factor: slice.count).first`.
// `Array(slice)` heap-copied the span, and `downsample` allocated a second
// array, once per column, up to `WaveformSketch.maxColumns` (1 024), inside the
// canvas draw that runs on every pinch and trim frame. That is the hitch on
// zoom. `join` walks the slice in place: min of mins, max of maxes, RMS of RMS,
// and returns the one bucket. The picture is unchanged.
//
// ⛔ History, kept because it is why the core survived: it was TEST-ONLY from
// 2026-07-28 (#132 Slice 5), when the reader, the disk cache and the view that drew
// it (`Audio/WaveformCache.swift`, `Studio/WaveformView.swift`) were deleted. It was
// kept on purpose as a pure, tested, dependency-free core — a parked core rather than
// an orphan, which is exactly what made the deleted `FileWaveformView` a defect
// instead of a parked feature. W1 ported the idea, not that code: no disk cache, one
// in-memory overview per part, read off the main actor.

import Foundation

/// One display bucket: the extremes + energy of `bucketSize` samples.
public struct WaveformBucket: Codable, Sendable, Equatable {
    public var min: Float
    public var max: Float
    public var rms: Float
    public init(min: Float, max: Float, rms: Float) {
        self.min = min; self.max = max; self.rms = rms
    }
}

public enum WaveformReducer {

    /// Reduce mono samples into min/max/RMS buckets of `bucketSize` samples
    /// (last bucket may cover fewer). Empty input → empty output; bucketSize
    /// is clamped ≥ 1. No allocation beyond the result; O(n).
    public static func reduce(_ samples: [Float], bucketSize: Int) -> [WaveformBucket] {
        guard !samples.isEmpty else { return [] }
        let size = Swift.max(1, bucketSize)
        var out: [WaveformBucket] = []
        out.reserveCapacity((samples.count + size - 1) / size)
        var i = 0
        while i < samples.count {
            let end = Swift.min(i + size, samples.count)
            var lo = samples[i], hi = samples[i]
            var sumSq: Double = 0
            for j in i..<end {
                let s = samples[j]
                if s < lo { lo = s }
                if s > hi { hi = s }
                sumSq += Double(s) * Double(s)
            }
            let rms = Float((sumSq / Double(end - i)).squareRoot())
            out.append(WaveformBucket(min: lo, max: hi, rms: rms))
            i = end
        }
        return out
    }

    /// Fold stereo to the display channel: per sample keep the value with the
    /// larger magnitude (extremes of EITHER channel stay visible).
    public static func foldStereo(left: [Float], right: [Float]) -> [Float] {
        let n = Swift.min(left.count, right.count)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            out[i] = abs(left[i]) >= abs(right[i]) ? left[i] : right[i]
        }
        return out
    }

    /// Re-reduce an existing bucket tier to a coarser one (mip chain: fine tier
    /// is computed from samples once; coarse tiers derive cheaply from it).
    /// Each group is `join` — one rule, not a second copy of the min/max/RMS math.
    public static func downsample(_ buckets: [WaveformBucket], factor: Int) -> [WaveformBucket] {
        guard !buckets.isEmpty else { return [] }
        let f = Swift.max(1, factor)
        var out: [WaveformBucket] = []
        out.reserveCapacity((buckets.count + f - 1) / f)
        var i = 0
        while i < buckets.count {
            let end = Swift.min(i + f, buckets.count)
            if let joined = join(buckets[i..<end]) { out.append(joined) }
            i = end
        }
        return out
    }

    /// One coarser bucket from `buckets`, in place: min of mins, max of maxes,
    /// RMS of the RMS values. Nil when `buckets` is empty. No heap allocation —
    /// a display column calls this on the slice it overlaps, and `downsample`
    /// calls it on each group, so both stay the same algebra.
    public static func join<S: Sequence>(_ buckets: S) -> WaveformBucket? where S.Element == WaveformBucket {
        var iterator = buckets.makeIterator()
        guard let first = iterator.next() else { return nil }
        var lo = first.min
        var hi = first.max
        var sumSq = Double(first.rms) * Double(first.rms)
        var count = 1
        while let bucket = iterator.next() {
            lo = Swift.min(lo, bucket.min)
            hi = Swift.max(hi, bucket.max)
            sumSq += Double(bucket.rms) * Double(bucket.rms)
            count += 1
        }
        let rms = Float((sumSq / Double(count)).squareRoot())
        return WaveformBucket(min: lo, max: hi, rms: rms)
    }
}

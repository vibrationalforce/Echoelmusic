// VideoSeed.swift
// Echoel — MV1 (founder order 2026-09-27, "Foto und Video werden zu kreativem Material"): what a
// short video gives to the music and the visuals, measured once from a bounded set of sampled
// frames. Pure and Foundation-only; reading frames is AVFoundation's job in a later slice, and it
// hands over only the small summaries below — never a decoded frame buffer, never the file.
//
// ⭐ THE INPUT IS ALREADY SMALL. A `VideoFrameSample` is one timestamp, a `gridSide × gridSide`
// luma thumbnail (16 × 16 = 256 bytes) and a mean colour. At most `maxSamples` of them are
// accepted, so the analysis is bounded however long the video is.
//
// ⭐ WRONG VALUES ARE REFUSED, NOT SMOOTHED. The input is refused when:
// · a sample carries a grid of the wrong size, a non-finite or out-of-range colour, or a
//   timestamp that goes backwards or beyond the duration;
// · the duration or frame rate is non-finite or implausible.
// `analyze` then returns nil. A stored seed is re-checked with `isPlausible` before anything
// applies it: motion outside 0…1, a transient outside the clip or out of order, NaN anywhere —
// each is caught there.
//
// ⚠️ WHAT THE NUMBERS ARE, AND ARE NOT.
// · `motionEnergy`: the mean change of the luma thumbnail between two CLOSE samples (at most
//   `motionPairMaxSeconds` apart), per second of video, over `fullScaleChangePerSecond` and clamped
//   to 0…1. It is picture change: a camera pan and a moving subject read alike. It is not a motion
//   vector or object tracking.
//   ⭐ GMMW VV-1a: ONLY CLOSE PAIRS. Change between two frames saturates once they are far apart —
//   seconds apart, any moving footage looks like a different picture — so a rate taken over the
//   12.5 s gaps of a 600 s clip read near 0.24 for footage a 6 s clip of the same scene read at 0.39.
//   The motion is now measured where it is linear, and a reader supplies close pairs (VV-1b). With
//   no close pair at all (a sparse reader), the mean over every neighbour is the fallback — and it
//   is length-dependent, which is why VV-1b exists. Guard: `TheVideoMotionDoesNotDependOnLengthTests`.
// · `transientTimes`: the sample times where the picture changed much more than it usually does —
//   more than the median change plus `transientMADs` × the median absolute deviation, and above
//   `transientFloor`, at least `transientSpacing` seconds apart. They are CUTS and FLASHES in the
//   picture, not beats in its sound. ⭐ The close and the far neighbours are judged each against
//   THEIR OWN usual change (VV-1a): mixed, a paired reading put the median between the two kinds
//   and every far pair of moving footage read as a cut.
// · Nothing here reads the video's AUDIO. Offering it as a beat or sampler source is its own
//   slice (`scratchpads/PLAN_MEDIA_SEED_2026-09-27.md` §3.4).

import Foundation

/// One sampled frame, already reduced by the reader.
public struct VideoFrameSample: Sendable, Equatable {
    /// Seconds from the start of the clip.
    public var time: Double
    /// Luma thumbnail, row-major, exactly `VideoSeedAnalysis.gridSide²` bytes.
    public var luma: [UInt8]
    /// Mean sRGB colour of the frame, each 0…1.
    public var meanRed: Double
    public var meanGreen: Double
    public var meanBlue: Double

    public init(time: Double, luma: [UInt8], meanRed: Double, meanGreen: Double, meanBlue: Double) {
        self.time = time
        self.luma = luma
        self.meanRed = meanRed
        self.meanGreen = meanGreen
        self.meanBlue = meanBlue
    }
}

/// The numeric summary of one short video.
public struct VideoSeed: Codable, Sendable, Equatable {

    public static let formatVersion = 1

    public var version: Int
    public var durationSeconds: Double
    public var frameRate: Double
    /// Mean luma of the sampled frames, 0…1.
    public var brightness: Double
    /// The colour summary of the mean frame colour — the same rules as a photo.
    public var hue: Double
    public var saturation: Double
    public var hasDominantColour: Bool
    /// Picture change per second, normalised to 0…1.
    public var motionEnergy: Double
    /// Seconds of the clip where the picture changed abruptly, ascending.
    public var transientTimes: [Double]
    public var sampledFrames: Int

    /// Whether a stored seed can be what it claims. Anything that fails is treated as no seed.
    public var isPlausible: Bool {
        let unit = [brightness, hue, saturation, motionEnergy]
        guard version >= 1,
              durationSeconds.isFinite, durationSeconds > 0,
              durationSeconds <= VideoSeedAnalysis.maxDurationSeconds,
              VideoSeedAnalysis.frameRateRange.contains(frameRate),
              unit.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }), hue < 1,
              sampledFrames >= 2, sampledFrames <= VideoSeedAnalysis.maxSamples,
              transientTimes.count < sampledFrames else { return false }
        var previous = -Double.infinity
        for t in transientTimes {
            guard t.isFinite, t >= 0, t <= durationSeconds, t > previous else { return false }
            previous = t
        }
        return true
    }
}

/// The analysis rules. Every threshold is named once here.
public enum VideoSeedAnalysis {

    /// Side of the luma thumbnail each sample carries.
    public static let gridSide = 16
    /// Most samples accepted — the bound on the work, whatever the video's length.
    public static let maxSamples = 240
    /// Longest clip accepted, in seconds. Longer videos are refused rather than half-read.
    public static let maxDurationSeconds = 600.0
    /// Frame rates a real video can have.
    public static let frameRateRange: ClosedRange<Double> = 1...240
    /// Picture change per second that reads as full motion energy (a fifth of the luma range
    /// changing every second, on average over the thumbnail).
    public static let fullScaleChangePerSecond = 0.2
    /// A transient needs this many median absolute deviations above the median change…
    public static let transientMADs = 4.0
    /// …and at least this much change (a share of the luma range) between the two samples.
    public static let transientFloor = 0.12
    /// Two transients are at least this far apart, in seconds.
    public static let transientSpacing = 0.25
    /// Two neighbouring samples at most this far apart, in seconds, are a CLOSE pair: their change
    /// measures motion. Farther pairs are kept for cut detection only (VV-1a).
    public static let motionPairMaxSeconds = 0.3

    /// The seed of a sampled video, or nil when the input cannot be what it claims (see the
    /// file header). nil is the safe fallback: nothing is applied.
    public static func analyze(samples: [VideoFrameSample], durationSeconds: Double,
                               frameRate: Double) -> VideoSeed? {
        let cells = gridSide * gridSide
        guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= maxDurationSeconds,
              frameRate.isFinite, frameRateRange.contains(frameRate),
              samples.count >= 2, samples.count <= maxSamples else { return nil }
        var previousTime = -Double.infinity
        for s in samples {
            let colour = [s.meanRed, s.meanGreen, s.meanBlue]
            guard s.luma.count == cells,
                  s.time.isFinite, s.time >= 0, s.time <= durationSeconds, s.time > previousTime,
                  colour.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else { return nil }
            previousTime = s.time
        }

        // Brightness and colour: the mean over the samples.
        var lumaSum = 0.0, red = 0.0, green = 0.0, blue = 0.0
        for s in samples {
            lumaSum += Double(s.luma.reduce(0) { $0 + Int($1) }) / Double(cells * 255)
            red += s.meanRed; green += s.meanGreen; blue += s.meanBlue
        }
        let n = Double(samples.count)
        let hsv = MediaSeedAnalysis.hsv(red / n, green / n, blue / n)
        let coloured = hsv.s >= MediaSeedAnalysis.chromaFloor && hsv.v >= MediaSeedAnalysis.valueFloor

        // Change between neighbouring samples, as a share of the luma range.
        var changes: [Double] = []
        changes.reserveCapacity(samples.count - 1)
        var closeRate = 0.0
        var closePairs = 0
        var everyRate = 0.0
        for i in 1..<samples.count {
            var total = 0
            for c in 0..<cells {
                total += abs(Int(samples[i].luma[c]) - Int(samples[i - 1].luma[c]))
            }
            let change = Double(total) / Double(cells * 255)
            changes.append(change)
            let gap = samples[i].time - samples[i - 1].time
            everyRate += change / gap
            if gap <= motionPairMaxSeconds {
                closeRate += change / gap
                closePairs += 1
            }
        }
        let meanRate = closePairs > 0 ? closeRate / Double(closePairs) : everyRate / Double(changes.count)
        let motion = Swift.min(1, meanRate / fullScaleChangePerSecond)

        return VideoSeed(version: VideoSeed.formatVersion, durationSeconds: durationSeconds,
                         frameRate: frameRate, brightness: lumaSum / n,
                         hue: coloured ? hsv.h : 0, saturation: hsv.s, hasDominantColour: coloured,
                         motionEnergy: motion,
                         transientTimes: transients(changes: changes, samples: samples),
                         sampledFrames: samples.count)
    }

    /// The sample times where the change stands out from the clip's own usual change — close and
    /// far neighbours each against their own (VV-1a; one kind alone is today's single rule).
    static func transients(changes: [Double], samples: [VideoFrameSample]) -> [Double] {
        let close = changes.indices.filter { samples[$0 + 1].time - samples[$0].time <= motionPairMaxSeconds }
        let far = changes.indices.filter { samples[$0 + 1].time - samples[$0].time > motionPairMaxSeconds }
        let candidates = (standingOut(close, in: changes) + standingOut(far, in: changes)).sorted()
        var times: [Double] = []
        for i in candidates {
            let t = samples[i + 1].time
            if let last = times.last, t - last < transientSpacing { continue }
            times.append(t)
        }
        return times
    }

    /// The members of `group` whose change exceeds the group's median plus `transientMADs` × its
    /// median absolute deviation, and `transientFloor`.
    static func standingOut(_ group: [Int], in changes: [Double]) -> [Int] {
        guard !group.isEmpty else { return [] }
        let values = group.map { changes[$0] }
        let median = Self.median(values)
        let mad = Self.median(values.map { abs($0 - median) })
        let threshold = Swift.max(transientFloor, median + transientMADs * mad)
        return group.filter { changes[$0] > threshold }
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }

    /// The whole number of bars nearest to `seconds` at `bpm` in `beatsPerBar`, at least one —
    /// the musical length a clip is quantised to. nil when the inputs are not a tempo and a time.
    public static func bars(forSeconds seconds: Double, bpm: Double, beatsPerBar: Int = 4) -> Int? {
        guard seconds.isFinite, seconds > 0, bpm.isFinite, bpm > 0, beatsPerBar > 0 else { return nil }
        let barSeconds = 60.0 / bpm * Double(beatsPerBar)
        let bars = (seconds / barSeconds).rounded()
        guard bars.isFinite else { return nil }
        return Int(Swift.min(Swift.max(bars, 1), 9_999))
    }

    /// The length in seconds of `bars` bars at `bpm` — where a quantised clip is trimmed or looped.
    public static func seconds(forBars bars: Int, bpm: Double, beatsPerBar: Int = 4) -> Double? {
        guard bars > 0, bpm.isFinite, bpm > 0, beatsPerBar > 0 else { return nil }
        return Double(bars) * 60.0 / bpm * Double(beatsPerBar)
    }
}

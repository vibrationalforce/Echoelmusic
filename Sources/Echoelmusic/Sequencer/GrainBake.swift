// GrainBake.swift
// Echoel — GMMW GA-10b: Echoel Grain rendered ONCE, off the render thread, into a stereo buffer.
//
// ⭐ WHY A BAKE AND NOT A LIVE INSERT. `GrainCloud` allocates in `init`/`prepare`, frees in `deinit`,
// and has no adopt/retire handshake of its own (its header). Running it live would need a second
// SPSC hand-over path into `TimelineAudioSink`. A part's grain is a fixed function of (its file,
// its settings, its seed), so it can be rendered once — the same shape the W4b fades and the Beats
// pre-render already take: compute off the main actor, schedule the finished buffer. GA-10c plays
// it; this file decides nothing about scheduling.
//
// THE LAWS THIS FILE KEEPS, each pinned by `TheGrainBakeIsTheDryPartAtMixZeroTests`:
// · **mix 0 is the dry part, bit for bit** — no arithmetic touches a dry sample on that path;
// · **silence in → silence out**, and every output sample is finite;
// · **the seed pins the result** — equal inputs bake equal buffers, another seed another pattern;
// · **level-matched against Off**: the cloud pans each grain at equal POWER (L² + R² = 1, −3 dB per
//   channel at the centre), while the dry part sits on both channels at full level (L² + R² = 2).
//   The wet signal is raised by √2 so the two carry the same power — otherwise turning the mix up
//   would read as "the effect is quieter".
//
// ⚠️ THE LIMITS, stated so GA-10c does not rediscover them:
// · the SOURCE is the first `GrainCloud.maxSourceSeconds` of the file — `position` 0…1 spans that,
//   not the whole of a longer file;
// · the OUTPUT is capped at `maxSeconds`; a longer part returns nil and the caller plays it DRY —
//   never silent. The cap is memory, not taste: two Float channels of this many seconds.
// · it ALLOCATES (the cloud, the source copy, the two output arrays) and runs for as long as the
//   part is long. Never on the render thread, never on the main actor for a long part.

import Foundation

enum GrainBake {

    /// The longest part baked, in seconds. 120 s × 48 kHz × 2 channels × 4 B ≈ 46 MB.
    static let maxSeconds: Double = 120

    /// A baked part: two channels of equal length.
    struct Buffer: Equatable, Sendable {
        let left: [Float]
        let right: [Float]
        var frameCount: Int { left.count }
    }

    /// Power match between the equal-power cloud and the dry part on both channels (header).
    static let wetLevelMatch: Float = Float(2).squareRoot()

    /// `frameCount` frames of the part with `settings` applied: the dry part — `source[i]` on both
    /// channels at frame i, silence past its end — crossfaded with the cloud by `mix`.
    /// Nil when there is nothing to bake (no frames, a bad rate) or the part is longer than
    /// `maxSeconds`; the caller then plays the part unchanged.
    static func render(source: [Float], sampleRate: Double, frameCount: Int,
                       settings: GrainSettings) -> Buffer? {
        guard frameCount > 0, sampleRate.isFinite, sampleRate >= 1, sampleRate <= 768_000,
              Double(frameCount) <= maxSeconds * sampleRate else { return nil }
        let s = settings.sanitized
        var left = [Float](repeating: 0, count: frameCount)
        let dryCount = Swift.min(frameCount, source.count)
        for i in 0..<dryCount {
            let x = source[i]
            left[i] = x.isFinite ? x : 0
        }
        // mix 0: the dry part, untouched — no multiply, so it is the same bits.
        guard s.mix > 0 else { return Buffer(left: left, right: left) }

        let cloud = GrainCloud(sampleRate: Float(sampleRate), seed: s.seed)
        cloud.position = s.position
        cloud.grainMilliseconds = s.grainMilliseconds
        cloud.density = s.density
        cloud.spraySeconds = s.spraySeconds
        cloud.pitchSemitones = s.pitchSemitones
        cloud.stereoSpread = s.stereoSpread
        cloud.prepare(source: source)
        var wetL = [Float](repeating: 0, count: frameCount)
        var wetR = [Float](repeating: 0, count: frameCount)
        wetL.withUnsafeMutableBufferPointer { l in
            wetR.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                cloud.process(left: lp, right: rp, frameCount: frameCount)
            }
        }

        let dryGain = 1 - s.mix
        let wetGain = s.mix * wetLevelMatch
        var right = left
        for i in 0..<frameCount {
            let dry = left[i]
            let outL = dry * dryGain + wetL[i] * wetGain
            let outR = dry * dryGain + wetR[i] * wetGain
            left[i] = outL.isFinite ? outL : 0
            right[i] = outR.isFinite ? outR : 0
        }
        return Buffer(left: left, right: right)
    }
}

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
// · **a stereo part keeps its image** (GA-10d): each dry channel stays on its own side; only the
//   cloud reads the channels' mean;
// · **silence in → silence out**, and every output sample is finite;
// · **the seed pins the result** — equal inputs bake equal buffers, another seed another pattern;
// · **level-matched against Off**: the cloud pans each grain at equal POWER (L² + R² = 1, −3 dB per
//   channel at the centre), while the dry part sits on both channels at full level (L² + R² = 2).
//   The wet signal is raised by √2 so the two carry the same power — otherwise turning the mix up
//   would read as "the effect is quieter". The crossfade is equal-POWER too (cos/sin): dry and
//   cloud read different places in the file, so they add as uncorrelated signals, and a linear
//   crossfade would dip 3 dB at mix 0.5;
// · **the part's length is the part's**: past the end of the dry part the bake is silent, as Off
//   is — the cloud does not keep sounding over a stretch where the part has no audio.
//
// ⚠️ THE LIMITS, stated so GA-10c does not rediscover them:
// · the SOURCE is the first `GrainCloud.maxSourceSeconds` of the file — `position` 0…1 spans that,
//   not the whole of a longer file;
// · the OUTPUT is capped at `maxFrames` (120 s at 48 kHz) — in FRAMES, so a higher rate buys a
//   shorter part, never more memory; a longer part returns nil and the caller plays it DRY, never
//   silent. Working set at the cap: four Float arrays of `maxFrames` (≈ 92 MB) plus the cloud's
//   own source copy (≤ 30 s) — the second dry channel is the GA-10d cost of a stereo image;
// · the match holds for CENTRED grains at density ≥ 0.5: a hard-panned grain is +3 dB on its side
//   (a full-scale source can reach ≈ 1.41 — no clipping inside a Float buffer, but the player
//   should know), and below density 0.5 the cloud thins (`GrainCloud` header);
// · it ALLOCATES (the cloud, the source copy, the two output arrays) and runs for as long as the
//   part is long. Never on the render thread, never on the main actor for a long part.

import Foundation

enum GrainBake {

    /// The longest part baked, in frames: 120 s at 48 kHz, whatever the rate (header).
    static let maxFrames = 5_760_000

    /// A baked part: two channels of equal length.
    struct Buffer: Equatable, Sendable {
        let left: [Float]
        let right: [Float]
        var frameCount: Int { left.count }
    }

    /// Power match between the equal-power cloud and the dry part on both channels (header).
    static let wetLevelMatch: Float = Float(2).squareRoot()

    /// `frameCount` frames of a MONO part with `settings` applied — the stereo bake with the same
    /// samples on both sides (the dry part sits on both channels, as Off plays a mono file).
    static func render(source: [Float], sampleRate: Double, frameCount: Int,
                       settings: GrainSettings) -> Buffer? {
        render(left: source, right: source, sampleRate: sampleRate, frameCount: frameCount, settings: settings)
    }

    /// `frameCount` frames of the part with `settings` applied: the dry part — `left[i]`/`right[i]`
    /// at frame i, each on its OWN channel (GA-10d: a stereo file keeps its image under the grain)
    /// — crossfaded with the cloud by `mix`, and silence past the dry part's end. The cloud reads
    /// the mean of the two channels (`GrainCloud` takes one source). Nil when there is nothing to
    /// bake (no frames, a bad rate) or the part is longer than `maxFrames`; the caller then plays
    /// the part unchanged.
    static func render(left source: [Float], right sourceRight: [Float], sampleRate: Double, frameCount: Int,
                       settings: GrainSettings) -> Buffer? {
        guard frameCount > 0, sampleRate.isFinite, sampleRate >= 1, sampleRate <= 768_000,
              frameCount <= maxFrames else { return nil }
        let s = settings.sanitized
        let dryCount = Swift.min(frameCount, source.count, sourceRight.count)
        var left = [Float](repeating: 0, count: frameCount)
        for i in 0..<dryCount {
            let x = source[i]
            left[i] = x.isFinite ? x : 0
        }
        var right = left
        if sourceRight != source {
            for i in 0..<dryCount {
                let x = sourceRight[i]
                right[i] = x.isFinite ? x : 0
            }
        }
        // mix 0: the dry part, untouched — no multiply, so it is the same bits.
        guard s.mix > 0 else { return Buffer(left: left, right: right) }

        let cloud = GrainCloud(sampleRate: Float(sampleRate), seed: s.seed)
        cloud.position = s.position
        cloud.grainMilliseconds = s.grainMilliseconds
        cloud.density = s.density
        cloud.spraySeconds = s.spraySeconds
        cloud.pitchSemitones = s.pitchSemitones
        cloud.stereoSpread = s.stereoSpread
        if sourceRight == source {
            cloud.prepare(source: source)
        } else {
            // The mean, scoped so it is freed before the part-length wet arrays exist.
            let count = Swift.min(source.count, sourceRight.count)
            var mono = [Float](repeating: 0, count: count)
            for i in 0..<count { mono[i] = (source[i] + sourceRight[i]) * 0.5 }
            cloud.prepare(source: mono)
        }
        var wetL = [Float](repeating: 0, count: frameCount)
        var wetR = [Float](repeating: 0, count: frameCount)
        wetL.withUnsafeMutableBufferPointer { l in
            wetR.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                cloud.process(left: lp, right: rp, frameCount: frameCount)
            }
        }

        // Equal-power crossfade (header); mix 1 is the cloud alone, not a cosine's rounding of it.
        let angle = s.mix * Float.pi / 2
        let dryGain: Float = s.mix >= 1 ? 0 : cosf(angle)
        let wetGain = sinf(angle) * wetLevelMatch
        // Written into the wet arrays in place: no further array of the part's length.
        for i in 0..<dryCount {
            let outL = left[i] * dryGain + wetL[i] * wetGain
            let outR = right[i] * dryGain + wetR[i] * wetGain
            wetL[i] = outL.isFinite ? outL : 0
            wetR[i] = outR.isFinite ? outR : 0
        }
        for i in dryCount..<frameCount {
            wetL[i] = 0
            wetR[i] = 0
        }
        return Buffer(left: wetL, right: wetR)
    }
}

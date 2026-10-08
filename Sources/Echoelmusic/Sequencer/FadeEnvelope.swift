// FadeEnvelope.swift
// Echoelmusic — Sequencer (audio editor W4a, founder 2026-10-08: "Die klassische DAW Audio
// Editing View fehlt mir noch.")
//
// THE ONE FADE RULE (#416). A fade-in raises the level linearly from silence to full over its
// length from the start; a fade-out lowers it linearly from full to silence over its length up
// to the end. When the two would overlap, the fade-in keeps its full length and the fade-out
// gets what is left ("in wins") — so the level never leaves 0…1 and never dips twice.
//
// ⭐ IT WAS WRITTEN ONCE ALREADY, AND THIS IS THAT RULE, MOVED — NOT A SECOND ONE.
// `AudioClipRegion.fadeMultiplier` carried it first, on a path that has no executor today
// (`AudioClipPlayer`, #1381). A timeline part got fade lengths in W4a; rather than restate the
// rule beside it, both now ask this enum. The arithmetic is the old method's, line for line;
// the one addition is that a non-finite or negative length counts as no fade, which the old
// method never met because its initializer clamped first.
//
// Pure, Foundation-only, unit-free: the lengths and the elapsed time share whatever unit the
// caller uses — seconds for a clip, ticks for a part's stored lengths, media seconds for the
// player.

import Foundation

enum FadeEnvelope {

    /// The fade lengths as they play inside `duration`: each held to 0…duration, the fade-out
    /// to what the fade-in leaves ("in wins"). A non-finite or negative length is no fade; a
    /// non-finite or non-positive duration leaves room for neither.
    nonisolated static func effective(fadeIn: Double, fadeOut: Double,
                                      duration: Double) -> (fadeIn: Double, fadeOut: Double) {
        guard duration.isFinite, duration > 0 else { return (0, 0) }
        let fin = held(fadeIn, to: duration)
        return (fin, held(fadeOut, to: duration - fin))
    }

    /// The level 0…1 at `elapsed` into a stretch `duration` long. Unity everywhere when there
    /// is no fade or no duration. An `elapsed` outside the stretch reads at the nearer edge; a
    /// non-finite one reads at the start.
    nonisolated static func gain(atElapsed elapsed: Double, duration: Double,
                                 fadeIn: Double, fadeOut: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 1 }
        let (fin, fout) = effective(fadeIn: fadeIn, fadeOut: fadeOut, duration: duration)
        let t = Swift.min(duration, Swift.max(0, elapsed.isFinite ? elapsed : 0))
        var g = 1.0
        if fin > 0, t < fin { g = t / fin }                                       // 0 → 1
        if fout > 0, t > duration - fout { g = Swift.min(g, (duration - t) / fout) } // 1 → 0
        return Swift.min(1, Swift.max(0, g))
    }

    /// `value` held to 0…`limit`; a non-finite or non-positive value, or no room, is 0.
    private nonisolated static func held(_ value: Double, to limit: Double) -> Double {
        guard value.isFinite, value > 0, limit > 0 else { return 0 }
        return Swift.min(value, limit)
    }
}

/// Audio editor W4b: one part's fades in MEDIA time — where the part starts in its file, how long
/// it runs there, and the two fade lengths as they play in that same time. The lane player cuts
/// the stretch of the file it schedules at the two fade edges: the ends are read, multiplied by
/// the ramp and scheduled as short buffers, the middle plays straight from the file. Built by
/// `AudioRegionPlayback.fadePlan`; pure, so the cut and the ramp are driven without a device.
public struct PartFadePlan: Equatable, Sendable {
    /// Where the part starts in its file, in seconds (`contentOffsetSeconds`).
    public let partStart: Double
    /// How long the part runs in its file, in seconds (its song length × the stretch rate).
    public let duration: Double
    /// The fade lengths as they play inside `duration` — already `FadeEnvelope.effective`.
    public let fadeIn: Double
    public let fadeOut: Double

    /// nil when no fade plays — no length survives the rule — or the mapping is degenerate.
    /// The player then takes its plain path, unchanged.
    public init?(partStart: Double, duration: Double, fadeIn: Double, fadeOut: Double) {
        guard partStart.isFinite, duration.isFinite, duration > 0 else { return nil }
        let fades = FadeEnvelope.effective(fadeIn: fadeIn, fadeOut: fadeOut, duration: duration)
        guard fades.fadeIn > 0 || fades.fadeOut > 0 else { return nil }
        self.partStart = partStart
        self.duration = duration
        self.fadeIn = fades.fadeIn
        self.fadeOut = fades.fadeOut
    }

    /// The level 0…1 of the file's moment `seconds` inside this part — the one rule, asked.
    public func gain(atMediaSeconds seconds: Double) -> Double {
        FadeEnvelope.gain(atElapsed: seconds - partStart, duration: duration,
                          fadeIn: fadeIn, fadeOut: fadeOut)
    }

    /// The frames `startFrame ..< startFrame + frameCount` cut at the two fade edges: `head`
    /// (inside the fade-in), `middle` (unity, played straight from the file) and `tail` (inside
    /// the fade-out). Contiguous and in order — together exactly the input, every edge an
    /// integer frame, so no frame is dropped or played twice. An empty piece is nil, and a part
    /// without a fade-in (or fade-out) never yields a head (or tail).
    public func pieces(startFrame: Int64, frameCount: Int64, sampleRate: Double)
        -> (head: Range<Int64>?, middle: Range<Int64>?, tail: Range<Int64>?) {
        guard startFrame >= 0, frameCount > 0, startFrame <= Int64.max - frameCount,
              sampleRate.isFinite, sampleRate > 0 else { return (nil, nil, nil) }
        let start = startFrame, end = startFrame + frameCount
        /// A media time as a frame edge, held inside the scheduled frames before it becomes an
        /// integer, so no conversion can overflow.
        func edge(_ seconds: Double, lowest: Int64) -> Int64 {
            let frame = (seconds * sampleRate).rounded()
            guard frame.isFinite else { return lowest }
            return Int64(Swift.min(Swift.max(frame, Double(lowest)), Double(end)))
        }
        let fadeInEnd = fadeIn > 0 ? edge(partStart + fadeIn, lowest: start) : start
        let fadeOutStart = fadeOut > 0 ? edge(partStart + duration - fadeOut, lowest: fadeInEnd) : end
        func piece(_ from: Int64, _ to: Int64) -> Range<Int64>? { from < to ? from..<to : nil }
        return (piece(start, fadeInEnd), piece(fadeInEnd, fadeOutStart), piece(fadeOutStart, end))
    }
}

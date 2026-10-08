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

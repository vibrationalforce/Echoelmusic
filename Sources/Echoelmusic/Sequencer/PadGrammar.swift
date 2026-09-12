//
//  PadGrammar.swift
//  Echoelmusic — Sequencer
//
//  ONE AUTHORED PAD FIGURE PER GENRE — the pad's half of the axis `BassGrammar` opened for the
//  low end (#983, founder 2026-09-04: "Ich will richtig gute Bass und Pad etc Loops … haben").
//
//  ⛔ WHY THIS EXISTS, measured before it was written. The pad already has a genre axis and it is
//  `MusicStyle.ChordArticulation` — but that type is FOUR cases (`skank` · `stab` · `comp` ·
//  `sustained`), it is DERIVED rather than authored (`ChordArticulation(groove:)` maps five
//  archetypes onto them, so `.halfTime`, `.none` and `.signature` all land on `.sustained`), and
//  the grid it produces is a function of the BODY: `chordOnsets` takes `energy`, `syncopation`
//  and `liveliness`, so what the listener hears at rest is not what the genre was given. Thirty-
//  six genres therefore share four body-modulated grids. A pushed chord that lands an 8th BEFORE
//  the beat, a 3+3+2 tresillo, a Charleston — none of them is expressible, whatever the genre
//  says. This type is the missing axis, in the same shape and for the same reason as the bass one.
//
//  THE FIGURE IS THE GENRE, NOT THE BODY, and that is the whole difference from `chordOnsets`.
//  A grammar applies at a resting body too — the body keeps its say through the section VELOCITY
//  (`padVelocity`, which already carries breath depth and the mood tilt) and through `hVel`'s
//  humanising. What the body no longer decides for these genres is WHERE the chord re-articulates.
//
//  THE LEVELS ARE THE ACCENT, AND THEY REPLACE `metricAccent`. The rhythmic branch in
//  `composeHarmonic` shapes its chops by metric position (downbeat > backbeat > offbeat) because
//  a derived grid has no opinion of its own. An authored figure does: `.pushedOffbeats` leans on
//  the anticipation, not on the downbeat it deliberately leaves empty, so applying a metric
//  accent on top would flatten exactly the thing that makes it recognisable.
//
//  PRECEDENCE, decided here so `composeHarmonic` does not have to discover it, and it is the
//  `BassGrammar` order with one addition:
//    1. a user's Pad-rhythm Picker choice (`Input.padRhythm`, non-nil) WINS — the person named a
//       character, the genre only offered one. Structural, not a flag: that path fills `padBeats`
//       and returns before the grammar branch is reached.
//    2. an ARPEGGIATED profile wins over a grammar. An arp genre's pitch figure IS its identity
//       (`voiced[t % count]` walking the voicing); a chord-shaped grammar would silence it.
//    3. otherwise the grammar plays, INCLUDING over `profile.sustained`. A genre that is given a
//       figure has been given it on purpose, and the authored statement beats the derived one —
//       the same call `BassGrammar` makes against the walking bass.
//    4. `nil` — every genre today — falls through to the unchanged `chordOnsets` branches,
//       byte-identical. No RNG is touched on the way past, so every later note in the take keeps
//       its identity and the `#253 A4` Golden law (`PadRhythmOverrideTests`) is untouched.
//
//  ⚠️ THE TABLE IS EMPTY IN THIS SLICE, ON PURPOSE (G2 of `PLAN_GENRE_WELT_2026-09-11.md`): the
//  mechanism ships before any genre claims it, so the byte-identity above is provable in ONE
//  commit instead of being argued about inside a commit that also changes how a genre sounds.
//  Every figure below is therefore AUTHORED AHEAD — pinned as a FIGURE, never as a sound. The
//  guard states which are owned and which are still ahead, and that set empties over G5…G15;
//  `BassGrammar.rollingSixteenths` spent S1…S5 in exactly this state.
//
//  Pure Foundation value type, no RNG of its own (the caller humanises), so a figure is assertable
//  in CI — `Tests/CISmoke/GenrePadGrammarTests.swift`. Whether it GROOVES is a device question.
//

import Foundation

/// A fixed one-bar pad figure, in the composer's 16-step bar.
public enum PadGrammar: String, CaseIterable, Sendable, Codable {
    /// The ANTICIPATED chord: every hit lands an 8th before its beat (phases 3 · 7 · 11 · 15) and
    /// rings across it. The bar's downbeat is empty on purpose — the chord has already arrived.
    /// Neither `.skank` (every offbeat, short) nor `.comp` (on 2 and 4) can place this.
    case pushedOffbeats
    /// 3+3+2 over each half-bar (phases 0 · 3 · 6, then 8 · 11 · 14) — the tresillo that underlies
    /// most Caribbean and Latin pulse. The cell repeats, so the second half answers the first
    /// rather than restating the bar.
    case tresilloChops
    /// Charleston: the downbeat long, then ONE push on the "&" of 2 (phase 6), and nothing else.
    /// The jazz/soul comp figure a four-case bucket rounds off into `.comp`'s busier grid.
    case charleston
    /// The swell: one chord held three quarters, then two short pickups (phases 13 · 15) that lead
    /// into the next bar instead of closing this one. Motion without a pulse.
    case sweptSwell

    /// One hit of a figure. `phase` is the 16-step bar position; `length` in steps (≥ 1, the
    /// #205/#176 no-zero-length law); `level` scales the section velocity (1 = the section's own).
    ///
    /// ⚠️ DELIBERATELY NOT `BassGrammar.Hit`, and this is not the #416 duplicate-definition
    /// defect: that type carries `fifth`, because a bass hit chooses ONE degree of the chord. A
    /// pad hit plays the whole voicing, so the field would be meaningless here and a future
    /// reader would have to work out that it is ignored. Two facts, two types.
    public struct Hit: Equatable, Sendable {
        public let phase: Int
        public let length: Int
        public let level: Float

        public init(phase: Int, length: Int, level: Float) {
            self.phase = phase
            self.length = length
            self.level = level
        }
    }

    /// The figure, in ascending phase order, never overlapping (pinned by the guard).
    public var hits: [Hit] {
        switch self {
        case .pushedOffbeats:
            // Length 3 so each chord rings THROUGH the beat it anticipates; the last one carries
            // over the barline, where the caller clips it to the section end.
            return [Hit(phase: 3, length: 3, level: 1.0),
                    Hit(phase: 7, length: 3, level: 0.85),
                    Hit(phase: 11, length: 3, level: 1.0),
                    Hit(phase: 15, length: 3, level: 0.9)]
        case .tresilloChops:
            var out: [Hit] = []
            out.reserveCapacity(6)
            for half in 0..<2 {
                let base = half * 8
                // 3 + 3 + 2: the last of each cell is shortest, which is what makes the pattern
                // lean forward instead of sounding like three even chops.
                out.append(Hit(phase: base, length: 3, level: 1.0))
                out.append(Hit(phase: base + 3, length: 3, level: 0.8))
                out.append(Hit(phase: base + 6, length: 2, level: 0.9))
            }
            return out
        case .charleston:
            return [Hit(phase: 0, length: 6, level: 1.0),
                    Hit(phase: 6, length: 2, level: 0.85)]
        case .sweptSwell:
            return [Hit(phase: 0, length: 12, level: 1.0),
                    Hit(phase: 13, length: 1, level: 0.55),
                    Hit(phase: 15, length: 1, level: 0.75)]
        }
    }

    /// The figure resolved into this section's ABSOLUTE steps, clipped to it.
    ///
    /// Same shape as `BioComposer.chordOnsets` plus the authored `level`, so the call site
    /// substitutes one for the other rather than growing a second note-writing loop.
    ///
    /// ⚠️ THE PHASE SEARCH IS `appendBass`'s, DELIBERATELY — a hit is placed at the FIRST step of
    /// the section whose bar phase matches, and skipped when the section is too short to contain
    /// one. The composer's take is one bar, so at most one step per section can match a phase;
    /// scanning rather than computing keeps that true for a section whose start is not bar-aligned
    /// (a mood splice can make sections an odd length, which is why `metricAccent` is relative too).
    /// A hit that would run past the section end is CLIPPED, never dropped: `.pushedOffbeats`'s
    /// last chord is written to ring over the barline and losing it would empty the anticipation.
    public func onsets(secStart: Int, secLen: Int) -> [(start: Int, len: Int, level: Float)] {
        guard secLen > 0 else { return [] }
        let secEnd = secStart + secLen
        var out: [(start: Int, len: Int, level: Float)] = []
        out.reserveCapacity(hits.count)
        for hit in hits {
            var step = secStart
            while step < secEnd {
                if ((step % 16) + 16) % 16 == hit.phase { break }
                step += 1
            }
            guard step < secEnd else { continue }
            out.append((start: step,
                        len: Swift.max(1, Swift.min(hit.length, secEnd - step)),
                        level: hit.level))
        }
        return out
    }
}


public extension MusicStyle {
    /// The pad figure this genre owns, or `nil` = the unchanged `chordOnsets` grid, byte-identical.
    ///
    /// ⚠️ EVERY GENRE IS `nil` TODAY and the switch is written out rather than collapsed to a bare
    /// `return nil`, so that G5…G15 add an arm instead of rediscovering where the table lives.
    /// Opt-in by design, so `default: nil` is the honest arm here and NOT the exhaustiveness dodge
    /// the rest of `MusicStyle` avoids: a genre that has not been given a figure keeps the grid it
    /// always had.
    var padGrammar: PadGrammar? {
        switch self {
        default: return nil
        }
    }
}

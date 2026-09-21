//
//  TempoMap.swift
//  Echoelmusic — Core (DMMW M1: the conversion authority)
//
//  WHAT THIS IS, AND — more usefully — WHAT IT IS NOT.
//
//  ⛔ IT IS NOT A CLOCK, AND THAT IS A FOUNDER CONSTRAINT, NOT A STYLE CHOICE.
//  `PatternEngine` is and stays the musical clock authority; `Transport` is and stays the
//  fan-out. Nothing in this file or in `Timebase.swift` ticks, schedules, observes, holds
//  mutable engine state or reaches an actor: they are pure value types that ANSWER QUESTIONS
//  about time, asked by whoever is already running the clock. A second thing in this repo that
//  advances time would be a second master, and the tempo path has already been paid for once
//  (`Core/BioTempoDirector`, a finished twin of the live inline servo, sits in the register of
//  unwired cores precisely because a duplicate authority is worse than a missing one).
//
//  WHAT IT BUYS. Today a musical position is an `Int` tick, a media position is a `Double`
//  second, and the conversion between them is IMPLICIT in a scalar tempo — correct only while
//  the tempo never changes. `TimelineRegion` already papers over this with two parallel trims
//  (ticks for MIDI, seconds for media) and its own comment explains why: a seconds-stored MIDI
//  trim shifts when the tempo changes between edit and play. That workaround is right for two
//  domains and does not scale. `TempoMap` makes the conversion EXPLICIT and tempo-change-safe.
//
//  ⚠️ ZERO PRODUCTION CALL SITES, ON PURPOSE. Nothing reads this yet. That is the definition
//  of done for this slice, not an omission: if landing the conversion authority had required
//  changing a caller, the slice would be wrong. `Xcode Compile Check` proves it compiles,
//  `Build for Testing` proves its guard compiles, and the arithmetic below was driven in
//  Python against the five properties BEFORE the Swift existed (#686/#943b — a CI round trip
//  is a lottery ticket, not a check on your arithmetic).
//
//  ⚠️ THE CONSTANTS ARE ASKED FOR, NEVER RESTATED (#416). The tempo bounds and the default
//  tempo come from `Transport`; `PatternEngine.defaultTempo` already delegates the same way.
//  The PPQ is NOT defaulted here at all — the app's song grid is `Note.ticksPerQuarter` (480)
//  and a caller passes it, because MIDI import already has to deal with a foreign file's PPQ
//  and a second hard-coded grid is exactly the defect this paragraph is about.
//  ⭐ WHEN THIS EVENTUALLY MOVES INTO ITS OWN FOUNDATION-ONLY TARGET, the dependency direction
//  inverts: `Transport` would read the bounds FROM here. That is a founder-gated step
//  (`project.yml`), so it is written down rather than pre-empted.
//

import Foundation

// MARK: - Tempo

/// How the tempo travels from one map entry to the NEXT one.
public enum TempoCurve: String, Codable, Sendable, CaseIterable {
    /// Hold this entry's BPM until the next entry, then jump.
    case step
    /// Ramp linearly in TICKS from this entry's BPM to the next entry's BPM.
    case linear
}

/// The one thing that converts musical ticks ↔ wall seconds.
///
/// ⚠️ A ramp INTEGRATES, it does not average. Seconds over a `.linear` segment are
/// `∫ 60 / (bpm(t) · ppq) dt` with `bpm` linear in ticks, which closes to
/// `(60/ppq) · span · ln(b₁/b₀) / (b₁ − b₀)`. Taking the mean BPM instead is the classic
/// wrong answer and it is wrong in a way that only shows up on long ramps — a 60→120 BPM
/// quarter takes `ln 2 ≈ 0.693 s`, not the `0.667 s` a mean of 90 would give.
public struct TempoMap: Codable, Sendable, Equatable {

    public struct Entry: Codable, Sendable, Equatable, Hashable {
        /// Song-absolute tick at which this tempo takes effect. Never negative.
        public var atTick: Int64
        /// Beats per minute, inside `TempoMap.bpmRange`.
        public var bpm: Double
        /// How the tempo travels from HERE to the next entry.
        public var curve: TempoCurve

        public init(atTick: Int64, bpm: Double, curve: TempoCurve = .step) {
            self.atTick = Swift.max(0, atTick)
            self.bpm = bpm.isFinite
                ? bpm.clamped(to: TempoMap.bpmRange)
                : Transport.defaultTempo
            self.curve = curve
        }
    }

    /// Asked for, never restated (#416) — `Transport` owns the app's tempo bounds and
    /// `BioTempoDirector` already delegates to them in exactly this shape.
    public static let bpmRange: ClosedRange<Double> = Transport.minTempo...Transport.maxTempo

    /// Normalised on the way in: sorted, deduplicated, seeded at tick 0, every BPM bounded.
    /// `private(set)` because every mutation has to re-run that normalisation.
    public private(set) var entries: [Entry]

    /// Always succeeds. A hostile input becomes a defined map, never a trap and never a
    /// half-valid one: this type is decoded from persisted documents written by older builds.
    public init(entries: [Entry]) {
        var normalised = entries
            .map { Entry(atTick: $0.atTick, bpm: $0.bpm, curve: $0.curve) }
            .sorted { $0.atTick < $1.atTick }

        // Later declaration wins at an identical tick — a document cannot carry two tempi
        // for one instant, and picking silently is better than trapping on someone's file.
        var collapsed: [Entry] = []
        for entry in normalised {
            if let last = collapsed.last, last.atTick == entry.atTick {
                collapsed[collapsed.count - 1] = entry
            } else {
                collapsed.append(entry)
            }
        }
        normalised = collapsed

        if normalised.isEmpty {
            normalised = [Entry(atTick: 0, bpm: Transport.defaultTempo, curve: .step)]
        } else if let first = normalised.first, first.atTick != 0 {
            // Seed tick 0 with the first declared tempo rather than the default: a map that
            // starts at bar 9 still describes bars 1–8, and inventing 120 there would put a
            // silent tempo change into a document the user never wrote one into.
            normalised.insert(Entry(atTick: 0, bpm: first.bpm, curve: .step), at: 0)
        }
        self.entries = normalised
    }

    /// A single constant tempo — the shape every project starts in.
    public static func constant(_ bpm: Double) -> TempoMap {
        TempoMap(entries: [Entry(atTick: 0, bpm: bpm, curve: .step)])
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        // Re-normalise on DECODE, not only on init: the invariants below (sorted, seeded at
        // tick 0, bounded BPM) are what every walk in this file relies on, and a document
        // written by an older or hand-edited build is exactly where they break.
        self.init(entries: decoded)
    }

    // MARK: Musical → wall

    /// Seconds for `span` ticks that begin at `from` BPM and end at `to` BPM.
    /// Pure, total, and the only place the ramp integral is written.
    private func segmentSeconds(span: Int64, from: Double, to: Double,
                                curve: TempoCurve, ppq: Int) -> Double {
        guard span > 0, ppq > 0, from > 0 else { return 0 }
        guard curve == .linear, to > 0, to != from else {
            return Double(span) * 60.0 / (from * Double(ppq))
        }
        return (60.0 / Double(ppq)) * Double(span) * Foundation.log(to / from) / (to - from)
    }

    /// Wall-clock seconds at a song-absolute tick. Negative ticks extrapolate backwards at
    /// the opening tempo; ticks past the last entry continue at the last tempo forever.
    public func seconds(atTick tick: Int64, ppq: Int) -> Double {
        let ppq = TimeMath.ppq(ppq)
        guard let opening = entries.first else { return 0 }
        guard tick > 0 else {
            return Double(tick) * 60.0 / (opening.bpm * Double(ppq))
        }
        var accumulated = 0.0
        for index in entries.indices {
            let entry = entries[index]
            let next: Entry? = index + 1 < entries.count ? entries[index + 1] : nil
            guard let next else {
                // Last entry: constant forever. A `.linear` here has no target to ramp to,
                // so it degrades to `.step` — stated rather than left to the reader.
                return accumulated + segmentSeconds(span: tick - entry.atTick,
                                                    from: entry.bpm, to: entry.bpm,
                                                    curve: .step, ppq: ppq)
            }
            if tick < next.atTick {
                let span = tick - entry.atTick
                let segment = next.atTick - entry.atTick
                let reached = segment > 0
                    ? entry.bpm + (next.bpm - entry.bpm) * (Double(span) / Double(segment))
                    : entry.bpm
                return accumulated + segmentSeconds(span: span, from: entry.bpm, to: reached,
                                                    curve: entry.curve, ppq: ppq)
            }
            accumulated += segmentSeconds(span: next.atTick - entry.atTick,
                                          from: entry.bpm, to: next.bpm,
                                          curve: entry.curve, ppq: ppq)
        }
        return accumulated
    }

    // MARK: Wall → musical

    /// Song-absolute tick at a wall-clock second. The exact inverse of `seconds(atTick:ppq:)`
    /// — the `.linear` branch solves the same integral rather than approximating it.
    public func tick(atSeconds seconds: Double, ppq: Int) -> Int64 {
        let ppq = TimeMath.ppq(ppq)
        guard seconds.isFinite, let opening = entries.first else { return 0 }
        guard seconds > 0 else {
            return TimeMath.whole(seconds * opening.bpm * Double(ppq) / 60.0)
        }
        var accumulated = 0.0
        for index in entries.indices {
            let entry = entries[index]
            let next: Entry? = index + 1 < entries.count ? entries[index + 1] : nil
            if let next {
                let segment = segmentSeconds(span: next.atTick - entry.atTick,
                                             from: entry.bpm, to: next.bpm,
                                             curve: entry.curve, ppq: ppq)
                if seconds >= accumulated + segment {
                    accumulated += segment
                    continue
                }
            }
            let remaining = seconds - accumulated
            var span: Double
            let span64 = next.map { $0.atTick - entry.atTick } ?? 0
            if let next, entry.curve == .linear, next.bpm != entry.bpm, span64 > 0,
               entry.bpm > 0, next.bpm > 0 {
                // Invert `s = (60/ppq)·span·ln(b₁/b₀)/(b₁−b₀)` for the partial span.
                let slope = (next.bpm - entry.bpm) / Double(span64)   // BPM per tick
                let growth = Foundation.exp(remaining * slope * Double(ppq) / 60.0)
                span = entry.bpm * (growth - 1.0) / slope
            } else {
                span = remaining * entry.bpm * Double(ppq) / 60.0
            }
            if next != nil {
                // Numerically the solve can land a hair outside its own segment; clamping
                // here is what keeps the walk monotone across the seam.
                span = span.clamped(to: 0...Double(span64))
            }
            return TimeMath.whole(Double(entry.atTick) + span)
        }
        return 0
    }
}

// MARK: - Meter

/// A bar's shape. `beatUnit` is the note value that gets one beat (4 = quarter).
public struct TimeSignature: Codable, Sendable, Equatable, Hashable {
    public var beatsPerBar: Int
    public var beatUnit: Int

    /// The only legal denominators. A non-power-of-two beat unit has no tick length.
    public static let legalBeatUnits: Set<Int> = [1, 2, 4, 8, 16, 32, 64]

    public init(beatsPerBar: Int, beatUnit: Int) {
        self.beatsPerBar = Swift.min(Swift.max(1, beatsPerBar), 64)
        self.beatUnit = TimeSignature.legalBeatUnits.contains(beatUnit) ? beatUnit : 4
    }

    /// 4/4 — `beatsPerBar` asked of `Transport` (#416), which owns the app's bar shape.
    public static let fourFour = TimeSignature(beatsPerBar: Transport.beatsPerBar, beatUnit: 4)

    /// Ticks in one beat of this signature at `ppq`. At least 1, so no caller divides by zero.
    public func ticksPerBeat(ppq: Int) -> Int64 {
        Swift.max(1, Int64(TimeMath.ppq(ppq)) * 4 / Int64(beatUnit))
    }

    /// Ticks in one bar of this signature at `ppq`.
    public func ticksPerBar(ppq: Int) -> Int64 {
        Int64(beatsPerBar) * ticksPerBeat(ppq: ppq)
    }
}

/// A musical position as a musician reads it. `bar` and `beat` are ZERO-based, matching
/// `TransportPosition`, which clamps both the same way (#416: one convention, not two).
public struct BarBeat: Codable, Sendable, Equatable, Hashable {
    public var bar: Int
    public var beat: Int
    public var tick: Int64

    public init(bar: Int, beat: Int, tick: Int64) {
        self.bar = Swift.min(Swift.max(0, bar), MeterMap.barLimit)
        // The bounds are overflow guards, not musical opinions: `beatsPerBar` tops out at 64
        // and a beat holds at most `4 × TimeMath.ppqLimit` ticks, so anything past these is a
        // hand-edited document. An unbounded value here would trap in `tick(atBarBeat:)`, and
        // a trap in this bundle reads exactly like #396 — a silent green over a dead clone.
        self.beat = Swift.min(Swift.max(0, beat), 4_095)
        self.tick = Swift.min(Swift.max(0, tick), 4 * Int64(TimeMath.ppqLimit))
    }
}

/// Where the bar shape changes. Same normalisation contract as `TempoMap`.
public struct MeterMap: Codable, Sendable, Equatable {

    public struct Entry: Codable, Sendable, Equatable, Hashable {
        public var atBar: Int
        public var signature: TimeSignature

        public init(atBar: Int, signature: TimeSignature) {
            self.atBar = Swift.min(Swift.max(0, atBar), MeterMap.barLimit)
            self.signature = signature
        }
    }

    /// Ten million bars is ~190 days of 4/4 at 120 BPM. The bound exists so `bar × ticksPerBar`
    /// cannot overflow `Int64` on a hand-edited document, not because anyone will reach it.
    public static let barLimit = 10_000_000

    public private(set) var entries: [Entry]

    public init(entries: [Entry]) {
        var normalised = entries
            .map { Entry(atBar: $0.atBar,
                         signature: TimeSignature(beatsPerBar: $0.signature.beatsPerBar,
                                                  beatUnit: $0.signature.beatUnit)) }
            .sorted { $0.atBar < $1.atBar }
        var collapsed: [Entry] = []
        for entry in normalised {
            if let last = collapsed.last, last.atBar == entry.atBar {
                collapsed[collapsed.count - 1] = entry
            } else {
                collapsed.append(entry)
            }
        }
        normalised = collapsed
        if normalised.isEmpty {
            normalised = [Entry(atBar: 0, signature: .fourFour)]
        } else if let first = normalised.first, first.atBar != 0 {
            normalised.insert(Entry(atBar: 0, signature: first.signature), at: 0)
        }
        self.entries = normalised
    }

    public static let fourFour = MeterMap(entries: [Entry(atBar: 0, signature: .fourFour)])

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        self.init(entries: decoded)
    }

    /// Bar/beat/tick at a song-absolute tick. Negative ticks clamp to the song start, the way
    /// `TransportPosition` clamps its own bar and step.
    public func barBeat(atTick tick: Int64, ppq: Int) -> BarBeat {
        let ppq = TimeMath.ppq(ppq)
        guard tick > 0 else { return BarBeat(bar: 0, beat: 0, tick: 0) }
        var accumulated: Int64 = 0
        for index in entries.indices {
            let entry = entries[index]
            let perBar = entry.signature.ticksPerBar(ppq: ppq)
            if index + 1 < entries.count {
                let span = Int64(entries[index + 1].atBar - entry.atBar) * perBar
                if tick >= accumulated + span {
                    accumulated += span
                    continue
                }
            }
            let remaining = tick - accumulated
            let perBeat = entry.signature.ticksPerBeat(ppq: ppq)
            let within = remaining % perBar
            let barsIn = Swift.min(remaining / perBar, Int64(MeterMap.barLimit))
            return BarBeat(bar: entry.atBar + Int(barsIn),
                           beat: Int(within / perBeat),
                           tick: within % perBeat)
        }
        return BarBeat(bar: 0, beat: 0, tick: 0)
    }

    /// Song-absolute tick at a bar/beat/tick.
    public func tick(atBarBeat position: BarBeat, ppq: Int) -> Int64 {
        let ppq = TimeMath.ppq(ppq)
        var accumulated: Int64 = 0
        for index in entries.indices {
            let entry = entries[index]
            let perBar = entry.signature.ticksPerBar(ppq: ppq)
            if index + 1 < entries.count, position.bar >= entries[index + 1].atBar {
                accumulated += Int64(entries[index + 1].atBar - entry.atBar) * perBar
                continue
            }
            accumulated += Int64(position.bar - entry.atBar) * perBar
            return accumulated
                + Int64(position.beat) * entry.signature.ticksPerBeat(ppq: ppq)
                + position.tick
        }
        return 0
    }
}

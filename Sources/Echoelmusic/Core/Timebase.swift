//
//  Timebase.swift
//  Echoelmusic — Core (DMMW M1: the four coordinate spaces)
//
//  ⛔ NOT A CLOCK. The reasoning lives once, at the top of `TempoMap.swift` (#416) — in one
//  line: `PatternEngine` stays the musical clock authority, `Transport` stays the fan-out,
//  and a second thing that ADVANCES time would be a second master. These types answer
//  questions about time; they never move it.
//
//  THE PROBLEM THIS SOLVES. A musical position is an `Int` tick, a media position is a
//  `Double` second, a recording position is a sample frame — and today they sit in sibling
//  fields of the same struct with nothing saying which space a bare number is in. Three
//  concrete failures follow from that, and two of them are already visible in this tree:
//  · a seconds-stored MIDI trim shifts when the tempo changes between edit and play
//    (`TimelineRegion` carries two parallel trims for exactly this reason, and says so);
//  · a punch point stored in seconds cannot round-trip — 48 000 and 44 100 disagree;
//  · two `SampleTime`s at different rates must NEVER be compared by frame count, which is
//    why this file deliberately does NOT conform `SampleTime` to `Comparable`.
//
//  ⚠️ THREE SPACES, NOT FOUR — AND THE MISSING ONE IS A DECISION, NOT AN OVERSIGHT.
//  The audit proposed a fourth, `FrameTime` (frames + a drop-frame-aware video rate). It is
//  NOT built here because the founder withdrew video on 2026-09-12 (#1303/#1304, verbatim
//  "Kein Video Capture"): `Sources/` constructs no VIDEO writer at all. ⛔ THIS LINE SAID
//  "`AVAssetWriter` occurs zero times under `Sources/`" and that was FALSE the day it was
//  written (#1425) — `Audio/SingleExport.swift` constructs exactly one, with
//  `mediaType: .audio`, for the master export. The argument survives UNCHANGED and a
//  little stronger: the one writer in the tree is audio-typed, so it gives a frame type
//  no domain either. Pinned by `TheShareReadyClipIsNotSoldAnywhereTests` claim 4 (no
//  `AVAssetWriterInput(mediaType: .video` anywhere, audio input still in `SingleExport`),
//  never by a count in a comment — a count in prose is a date (§W).
//  A 29.97-drop-frame timecode type with no domain would be a
//  doorless core, and this repository keeps a whole register of those precisely because they
//  cost a later session real confusion. It is registered as its own slice, to be built the
//  day a video or timecode domain comes back — with the SMPTE reference table
//  (00:10:00;00 → frame 17982, 01:00:00;00 → frame 107892) as its guard, never a scale factor.
//
//  ⚠️ ZERO PRODUCTION CALL SITES, ON PURPOSE — see `TempoMap.swift`. Compile-verified by both
//  gates; the arithmetic was driven in Python against the round-trip, monotonicity and
//  totality properties before the Swift existed. NOT device-verified, and there is nothing
//  on a device to verify yet: nothing calls it.
//

import Foundation

// MARK: - Shared numeric floor

/// The narrowing conversions every space type shares, in ONE place.
///
/// ⚠️ Why this is not inlined at the eight sites that need it: `Int64(someDouble)` TRAPS on
/// NaN, on ±infinity and on anything past `Int64.max`. A trap inside the blocking bundle kills
/// the simulator clone, which from outside is indistinguishable from #396 (#1174) — a silent
/// green over a dead test run. Every `Double → Int64` in this slice goes through here.
public enum TimeMath {

    /// Upper bound for a pulses-per-quarter grid. 960 000 is far past any sane value (the app's
    /// own grid is `Note.ticksPerQuarter` = 480, SMF allows 32 767); it exists so that
    /// `Int64(ppq) * 4 * beatsPerBar * barLimit` cannot overflow, not to express an opinion.
    public static let ppqLimit = 960_000

    /// `Int64.max` is 9.223e18; 9.0e18 is exactly representable as a `Double` and leaves room
    /// for the rounding step, so a clamp to it can never produce an out-of-range conversion.
    public static let tickLimit: Double = 9.0e18

    /// A usable pulses-per-quarter value, whatever was passed.
    public static func ppq(_ raw: Int) -> Int {
        Swift.min(Swift.max(1, raw), ppqLimit)
    }

    /// Nearest whole count — ticks OR sample frames — total on NaN, ±infinity and overflow.
    public static func whole(_ value: Double) -> Int64 {
        guard value.isFinite else { return 0 }
        return Int64(value.clamped(to: -tickLimit...tickLimit).rounded())
    }
}

// MARK: - The spaces

/// Musical position: PPQ-based ticks. Authoritative for MIDI and for everything the
/// generative engine writes, because it is the only space that survives a tempo change.
///
/// Signed on purpose: a negative tick is a legal count-in / pre-roll position, and clamping
/// it at zero here would silently move a pickup bar onto the downbeat.
public struct MusicalTime: Hashable, Comparable, Codable, Sendable {
    public let ticks: Int64
    public init(ticks: Int64) { self.ticks = ticks }

    public static let zero = MusicalTime(ticks: 0)
    public static func < (lhs: MusicalTime, rhs: MusicalTime) -> Bool { lhs.ticks < rhs.ticks }

    public init(from decoder: Decoder) throws {
        self.init(ticks: try decoder.singleValueContainer().decode(Int64.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(ticks)
    }
}

/// Wall-clock position in seconds. Authoritative for media playback and for the network.
///
/// ⚠️ NaN becomes ZERO here, and that is a deliberate departure from `clamped(to:)`'s
/// NaN → lowerBound rule. The LAW is "a NaN never propagates"; the substitute value is a
/// per-quantity decision, and for a SIGNED quantity the range's lower bound would turn a
/// missing measurement into the most negative time expressible. `clamped(to:)` is written for
/// gains and cutoffs, where the lower bound IS the safe floor.
public struct WallTime: Hashable, Comparable, Codable, Sendable {

    /// One billion seconds is ~31.7 years — past any project, and small enough that
    /// `limitSeconds × 768 000` frames stays four orders of magnitude inside `Int64`.
    public static let limitSeconds: Double = 1e9

    public let seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds.isFinite
            ? seconds.clamped(to: -WallTime.limitSeconds...WallTime.limitSeconds)
            : 0
    }

    public static let zero = WallTime(seconds: 0)
    public static func < (lhs: WallTime, rhs: WallTime) -> Bool { lhs.seconds < rhs.seconds }

    public init(from decoder: Decoder) throws {
        self.init(seconds: try decoder.singleValueContainer().decode(Double.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }
}

/// Sample position. Authoritative wherever audio is rendered or recorded.
///
/// ⛔ IT CARRIES ITS OWN RATE, AND IT IS DELIBERATELY **NOT** `Comparable`. Two positions at
/// 44 100 and 48 000 with the same `frames` are different instants, so a frame-count `<` would
/// be quietly wrong in the one place — punch points, loop ends, recording offsets — where
/// being quietly wrong costs a take. Comparison goes through `seconds`, which forces the
/// rate into the reader's hands. Adding `Comparable` later would re-open exactly that hole.
public struct SampleTime: Hashable, Codable, Sendable {

    /// 8 kHz is the lowest rate any Apple audio path produces; 768 kHz the highest an
    /// `AVAudioFormat` accepts. Domain bounds, not a copy of anybody's preferred rate.
    public static let rateRange: ClosedRange<Double> = 8_000...768_000

    public let frames: Int64
    public let sampleRate: Double

    /// ⚠️ A non-finite rate clamps to the LOW end, via the repo's NaN-safe `clamped(to:)`.
    /// That is the loud failure on purpose: at 8 kHz a position reads six times LONGER than it
    /// should and is noticed at once, whereas silently substituting a plausible 48 000 would
    /// look right and be wrong. It must not be stored raw — a NaN rate would break `Hashable`
    /// reflexivity, so the value would not even equal itself.
    public init(frames: Int64, sampleRate: Double) {
        self.frames = frames
        self.sampleRate = sampleRate.clamped(to: SampleTime.rateRange)
    }

    /// Seconds at THIS position's own rate.
    public var seconds: WallTime {
        WallTime(seconds: Double(frames) / sampleRate)
    }

    /// The same instant counted at another rate. Explicit by design — property 5 of the
    /// slice: a conversion between two rates resamples, it never reinterprets a frame count.
    public func converted(to newRate: Double) -> SampleTime {
        let target = newRate.clamped(to: SampleTime.rateRange)
        let scaled = Double(frames) * target / sampleRate
        return SampleTime(frames: TimeMath.whole(scaled), sampleRate: target)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(frames: try container.decode(Int64.self, forKey: .frames),
                  sampleRate: try container.decode(Double.self, forKey: .sampleRate))
    }
}

// MARK: - Timebase

/// The conversion authority: one PPQ grid, one render rate, one tempo map, one meter map, and
/// a total conversion between every pair of spaces.
///
/// ⚠️ `ppq` HAS NO DEFAULT, on purpose. The app's song grid is `Note.ticksPerQuarter` (480)
/// and MIDI import already has to rescale a foreign file's own division — a second hard-coded
/// grid in this file would be the #416 defect in the type built to end it. Callers pass it.
public struct Timebase: Codable, Sendable, Equatable {

    public let ppq: Int
    public let sampleRate: Double
    public var tempoMap: TempoMap
    public var meterMap: MeterMap

    public init(ppq: Int, sampleRate: Double, tempoMap: TempoMap, meterMap: MeterMap = .fourFour) {
        self.ppq = TimeMath.ppq(ppq)
        self.sampleRate = sampleRate.clamped(to: SampleTime.rateRange)
        self.tempoMap = tempoMap
        self.meterMap = meterMap
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(ppq: try container.decode(Int.self, forKey: .ppq),
                  sampleRate: try container.decode(Double.self, forKey: .sampleRate),
                  tempoMap: try container.decodeIfPresent(TempoMap.self, forKey: .tempoMap)
                      ?? TempoMap(entries: []),
                  meterMap: try container.decodeIfPresent(MeterMap.self, forKey: .meterMap)
                      ?? .fourFour)
    }

    // MARK: Musical ↔ wall

    public func seconds(at time: MusicalTime) -> WallTime {
        WallTime(seconds: tempoMap.seconds(atTick: time.ticks, ppq: ppq))
    }

    public func musical(atSeconds time: WallTime) -> MusicalTime {
        MusicalTime(ticks: tempoMap.tick(atSeconds: time.seconds, ppq: ppq))
    }

    // MARK: Musical ↔ sample

    public func samples(at time: MusicalTime) -> SampleTime {
        SampleTime(frames: TimeMath.whole(seconds(at: time).seconds * sampleRate),
                   sampleRate: sampleRate)
    }

    public func musical(atSamples time: SampleTime) -> MusicalTime {
        // `time.seconds` divides by the POSITION's rate, never this timebase's — that is the
        // whole reason `SampleTime` carries one.
        musical(atSeconds: time.seconds)
    }

    // MARK: Wall ↔ sample

    public func samples(atSeconds time: WallTime) -> SampleTime {
        SampleTime(frames: TimeMath.whole(time.seconds * sampleRate), sampleRate: sampleRate)
    }

    public func seconds(at time: SampleTime) -> WallTime { time.seconds }

    // MARK: Musical ↔ bar/beat

    public func barBeat(at time: MusicalTime) -> BarBeat {
        meterMap.barBeat(atTick: time.ticks, ppq: ppq)
    }

    public func musical(atBarBeat position: BarBeat) -> MusicalTime {
        MusicalTime(ticks: meterMap.tick(atBarBeat: position, ppq: ppq))
    }
}

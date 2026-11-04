import Foundation

/// How the tempo reaches a change (`TempoChange.curve`). Stored by name, so a curve from a later
/// build is kept and plays as `step`, the fallback (`docs/FORMAT.md`, "A name it does not know").
public enum TempoCurve: String, Codable, CaseIterable, Sendable {
    /// The new tempo starts at the change and holds until the next one. What every song before
    /// tempo ramps plays, and what a change without a `curve` plays.
    case step
    /// The tempo glides from the tempo before the change, in beats per minute rising or falling
    /// evenly per tick, and arrives at the change's tempo exactly on its tick (an accelerando or
    /// ritardando). From there it holds, like a step, until the next change.
    case linear
}

/// A tempo change that takes effect at `tick` and holds until the next one; with a `linear`
/// curve, the tempo before it glides into it.
public struct TempoChange: Codable, Equatable, Hashable, Sendable {
    public let tick: Tick
    public let bpm: Double
    /// The stored curve name; nil — the key absent — is a step, so a step change is written
    /// exactly as it was before ramps existed.
    private let curveName: String?

    public init(tick: Tick, bpm: Double, curve: TempoCurve = .step) {
        self.tick = tick
        self.bpm = bpm
        self.curveName = curve == .step ? nil : curve.rawValue
    }

    /// How the tempo reaches this change; a name this build does not know plays as a step.
    public var curve: TempoCurve { curveName.flatMap(TempoCurve.init(rawValue:)) ?? .step }

    /// The stored curve name of a curve this build does not know, kept and saved back unchanged.
    public var unrecognizedCurve: String? { curveName.flatMap { TempoCurve(rawValue: $0) == nil ? $0 : nil } }

    /// The same change with another curve; a curve this build does not know is replaced.
    public func with(curve: TempoCurve) -> TempoChange { TempoChange(tick: tick, bpm: bpm, curve: curve) }

    /// The same change at another tempo, keeping its stored curve name — known or not.
    public func with(bpm: Double) -> TempoChange { TempoChange(tick: tick, bpm: bpm, curveName: curveName) }

    private init(tick: Tick, bpm: Double, curveName: String?) {
        self.tick = tick
        self.bpm = bpm
        self.curveName = curveName
    }

    private enum CodingKeys: String, CodingKey {
        case tick, bpm
        case curveName = "curve"
    }
}

/// The song's tempo over time: the project tempo from tick 0, then each change in order.
/// Every conversion between musical time (ticks) and clock time (seconds, samples) goes
/// through this, so audio, MIDI clock and — later — light and video agree on one timeline.
///
/// A segment runs from one change to the next. Its tempo is constant, or — when the next change
/// is `linear` — rises or falls evenly per tick from its own tempo to the next one's. Time in a
/// ramp is the integral of seconds per tick, `60 / (ppq · bpm(t))`, which is a logarithm; its
/// inverse is an exponential. A constant segment keeps the plain product, so a song without
/// ramps converts to exactly the same numbers as before ramps existed.
///
/// Built on the main thread; every lookup is a binary search over arrays it already holds plus
/// arithmetic (`log1p`, `expm1`), so the render thread may call it without allocating.
public struct TempoMap: Equatable, Sendable {
    public struct Segment: Equatable, Sendable {
        public let startTick: Tick
        /// The tempo at `startTick`.
        public let bpm: Double
        public let startSeconds: Double
        /// Beats per minute gained per tick; 0 for a constant segment, and always 0 for the last.
        public let slope: Double

        init(startTick: Tick, bpm: Double, startSeconds: Double, slope: Double = 0) {
            self.startTick = startTick
            self.bpm = bpm
            self.startSeconds = startSeconds
            self.slope = slope
        }

        var secondsPerTick: Double { 60 / (bpm * Double(MusicalTime.ticksPerQuarter)) }

        /// Whether the tempo moves inside this segment.
        public var isRamp: Bool { slope != 0 }

        /// The tempo `ticks` (fractional) after the start; before the start, the start tempo.
        func bpm(after ticks: Double) -> Double {
            guard isRamp, ticks > 0 else { return bpm }
            return bpm + slope * ticks
        }

        /// Seconds from the segment start to `ticks` (fractional) after it.
        func seconds(after ticks: Double) -> Double {
            guard isRamp, ticks > 0 else { return ticks * secondsPerTick }
            // ∫ 60 / (ppq · (b + k·t)) dt = 60 / (ppq · k) · ln(1 + k·t / b)
            return 60 / (Double(MusicalTime.ticksPerQuarter) * slope) * Foundation.log1p(slope * ticks / bpm)
        }

        /// Fractional ticks from the segment start to `seconds` after it — the inverse of
        /// `seconds(after:)`.
        func ticks(after seconds: Double) -> Double {
            guard isRamp, seconds > 0 else { return seconds / secondsPerTick }
            return bpm / slope * Foundation.expm1(seconds * Double(MusicalTime.ticksPerQuarter) * slope / 60)
        }
    }

    public let segments: [Segment]

    public init(bpm: Double, changes: [TempoChange] = []) {
        // The points the tempo passes: the project tempo at 0, then each change; a change at the
        // tick of the one before replaces it.
        var points: [(tick: Tick, bpm: Double, ramp: Bool)] = [(0, bpm, false)]
        for change in changes.sorted(by: { $0.tick < $1.tick }) where change.tick > 0 {
            guard let last = points.last else { break }
            let point = (tick: change.tick, bpm: change.bpm, ramp: change.curve == .linear)
            if change.tick == last.tick {
                points[points.count - 1] = point
            } else {
                points.append(point)
            }
        }
        var segments: [Segment] = []
        segments.reserveCapacity(points.count)
        var seconds = 0.0
        for (index, point) in points.enumerated() {
            var slope = 0.0
            if index + 1 < points.count, points[index + 1].ramp {
                let next = points[index + 1]
                slope = (next.bpm - point.bpm) / Double(next.tick - point.tick)
                if !slope.isFinite { slope = 0 }
            }
            let segment = Segment(startTick: point.tick, bpm: point.bpm, startSeconds: seconds, slope: slope)
            segments.append(segment)
            if index + 1 < points.count {
                let length = points[index + 1].tick - point.tick
                // A constant segment keeps the arithmetic of the map before ramps, bit for bit.
                seconds = segment.isRamp ? seconds + segment.seconds(after: Double(length))
                                         : seconds + Double(length) * segment.secondsPerTick
            }
        }
        self.segments = segments
    }

    /// Whether any segment's tempo moves — what an exporter that writes steps needs to know.
    public var hasRamps: Bool { segments.contains(where: \.isRamp) }

    /// Whether the tempo moves in the segment holding `tick`.
    public func isRamp(at tick: Tick) -> Bool { segments[segmentIndex(atTick: tick)].isRamp }

    /// The tempo sounding at `tick`; inside a ramp, the tempo at that very tick.
    public func bpm(at tick: Tick) -> Double {
        let s = segments[segmentIndex(atTick: tick)]
        return s.bpm(after: Double(tick - s.startTick))
    }

    /// Clock time of `tick`, counted from tick 0. Negative ticks extrapolate the first tempo.
    public func seconds(at tick: Tick) -> Double {
        let s = segments[segmentIndex(atTick: tick)]
        guard s.isRamp else { return s.startSeconds + Double(tick - s.startTick) * s.secondsPerTick }
        return s.startSeconds + s.seconds(after: Double(tick - s.startTick))
    }

    /// The tick sounding at `seconds`, rounded down. Non-finite input reads as tick 0; a time past
    /// any tick saturates instead of overflowing (`MusicalTime.integer`).
    public func tick(atSeconds seconds: Double) -> Tick {
        guard seconds.isFinite else { return 0 }
        let s = segments[segmentIndex(atSeconds: seconds)]
        guard s.isRamp else {
            let ticks = (seconds - s.startSeconds) / s.secondsPerTick
            return MusicalTime.integer(Double(s.startTick) + ticks.rounded(.down))
        }
        return MusicalTime.integer(Double(s.startTick) + s.ticks(after: seconds - s.startSeconds).rounded(.down))
    }

    /// Where in musical time `seconds` falls, in fractional ticks — for what moves continuously
    /// (automation), where a whole tick would be a step. Non-finite input reads as 0.
    public func position(atSeconds seconds: Double) -> Double {
        guard seconds.isFinite else { return 0 }
        let s = segments[segmentIndex(atSeconds: seconds)]
        guard s.isRamp else { return Double(s.startTick) + (seconds - s.startSeconds) / s.secondsPerTick }
        return Double(s.startTick) + s.ticks(after: seconds - s.startSeconds)
    }

    /// Clock time of a fractional tick — the inverse of `position(atSeconds:)`. Non-finite input
    /// reads as 0.
    public func seconds(atPosition position: Double) -> Double {
        guard position.isFinite else { return 0 }
        let whole = Tick(Swift.min(Swift.max(position, -Double(MusicalTime.maximumTick)), Double(MusicalTime.maximumTick)).rounded(.down))
        let s = segments[segmentIndex(atTick: whole)]
        guard s.isRamp else { return s.startSeconds + (position - Double(s.startTick)) * s.secondsPerTick }
        return s.startSeconds + s.seconds(after: position - Double(s.startTick))
    }

    private func segmentIndex(atTick tick: Tick) -> Int {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startTick <= tick { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private func segmentIndex(atSeconds seconds: Double) -> Int {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startSeconds <= seconds { low = mid } else { high = mid - 1 }
        }
        return low
    }
}

extension Project {
    /// The tempo map this project plays at.
    public var tempoMap: TempoMap { TempoMap(bpm: tempo, changes: tempoChanges) }
}

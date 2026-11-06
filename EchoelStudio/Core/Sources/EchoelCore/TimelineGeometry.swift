import Foundation

/// The pure core of the timeline's picture: where a tick sits across the arrangement, and how a
/// song position reads as bar.beat.division. The arrangement's lanes, its ruler, the playhead line
/// and the transport's position readout all draw through it, so the line the musician sees and the
/// numbers they read never disagree.
///
/// `ticksPerPoint` is always handed in, never assumed: the arrangement's horizontal zoom sets it.
/// The first bar is `pointsPerBar` wide, every later bar as wide as its ticks — a 7/8 bar after
/// 4/4 is narrower — so x stays proportional to musical time across a meter change.
///
/// Every position from outside is sanitised here: a fractional playhead interpolated between two
/// render buffers can come in negative (the output latency taken off right after Play) or, from a
/// broken anchor, not a number. Both read as tick 0, never as a trap or a line drawn off screen.
public enum TimelineGeometry {
    /// The width of the first bar at the arrangement's standard zoom.
    public static let pointsPerBar: Double = 88

    /// Ticks one point spans when the song's first bar is `pointsPerBar` wide. A width that is
    /// not a positive number falls back to the standard zoom.
    public static func ticksPerPoint(meter: MeterMap, pointsPerBar: Double = TimelineGeometry.pointsPerBar) -> Double {
        let width = pointsPerBar.isFinite && pointsPerBar > 0 ? pointsPerBar : Self.pointsPerBar
        return Double(meter.ticksPerBar(at: 0)) / width
    }

    /// A position in fractional ticks as a whole tick inside what a song holds: negative and
    /// not-a-number read as 0, anything past the last tick as the last tick.
    public static func tick(clamping position: Double) -> Tick {
        Tick(position.clamped(to: 0...Double(MusicalTime.maximumTick)).rounded(.down))
    }

    /// Where `tick` sits across the arrangement, in points from the song's start. 0 for a tick
    /// before the start or a zoom that is not a positive number.
    public static func x(ofTick tick: Tick, ticksPerPoint: Double) -> Double {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        return Double(Swift.max(0, tick)) / ticksPerPoint
    }

    /// Where a fractional position sits across the arrangement — the playhead between two
    /// buffers. Sanitised as `tick(clamping:)` sanitises, but keeps the fraction so the line moves
    /// smoothly between ticks.
    public static func x(ofPosition position: Double, ticksPerPoint: Double) -> Double {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        return position.clamped(to: 0...Double(MusicalTime.maximumTick)) / ticksPerPoint
    }

    /// A song position as the transport reads it: bar, beat and sixteenth, each counted from 1.
    /// The third number counts sixteenths inside the beat (two in a 7/8 beat, four in 4/4), so it
    /// changes at a pace the eye can follow while the song plays.
    public struct Position: Equatable, Sendable {
        public let bar: Int64
        public let beat: Int64
        public let division: Int64

        /// "2.3.1".
        public var text: String { "\(bar).\(beat).\(division)" }
        /// "Bar 2, beat 3" — what VoiceOver says; the sixteenth would be noise when spoken.
        public var spoken: String { "Bar \(bar), beat \(beat)" }
    }

    /// The ticks of the readout's third number: a sixteenth.
    public static let divisionTicks: Tick = MusicalTime.ticksPerQuarter / 4

    /// Where `tick` lies in the bars of `meter`. A tick before the song's start reads as the start.
    public static func position(at tick: Tick, meter: MeterMap) -> Position {
        let at = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        let barStart = meter.barStart(at: at)
        let beatStart = meter.beatStart(at: at)
        let beatTicks = Swift.max(meter.ticksPerBeat(at: at), 1)
        return Position(bar: meter.bar(at: at) + 1,
                        beat: (beatStart - barStart) / beatTicks + 1,
                        division: (at - beatStart) / divisionTicks + 1)
    }

    /// Where a fractional position lies — the playhead between two buffers.
    public static func position(atPosition value: Double, meter: MeterMap) -> Position {
        position(at: tick(clamping: value), meter: meter)
    }
}

extension Double {
    /// This value inside `range`; not a number reads as the range's lower bound. `Swift.min` and
    /// `Swift.max` alone would pass a NaN straight through.
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard !isNaN else { return range.lowerBound }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

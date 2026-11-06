import Foundation

/// The arrangement's horizontal zoom: how wide a bar is drawn. A view of the song, never an edit —
/// it is kept on the device (`storageKey`), never in the song file, and never part of Undo.
///
/// The level multiplies `TimelineGeometry.pointsPerBar`: 1 is the standard 88-pt bar, 2 doubles
/// it. Every number the arrangement draws or reads with goes through one `ticksPerPoint(_:meter:)`
/// at that level — the ruler, the lanes, the blocks on them and the playhead line — so a tick
/// sits at the same x in all of them at every zoom, and a finger's drag of N points spans
/// N × ticksPerPoint ticks: at twice the zoom the same drag moves half as far in the song.
///
/// A stored level that is not a positive number (written by another version, or broken) reads
/// as the standard zoom; one outside `range` is held to it.
public enum ArrangeZoom {
    /// Where the level is kept: on this device, never in the song.
    public static let storageKey = "arrange.zoom"
    /// The standard zoom: an 88-pt first bar.
    public static let base: Double = 1
    /// From four bars in the room of one (a long song at a glance) to a bar eight times as wide
    /// (a beat wider than a fingertip, for a fade or a trim).
    public static let range: ClosedRange<Double> = 0.25...8
    /// What one press of Zoom In multiplies the level by; Zoom Out divides by it.
    public static let step: Double = 2

    /// The stored `value` as a level the arrangement can draw: not a number, zero or negative read
    /// as `base`; anything else held inside `range`.
    public static func level(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return base }
        return value.clamped(to: range)
    }

    /// The level after a pinch of `factor` (a magnification of 1 changes nothing). A factor that
    /// is not a positive number leaves the level where it was.
    public static func zoomed(_ value: Double, by factor: Double) -> Double {
        let current = level(value)
        guard factor.isFinite, factor > 0 else { return current }
        return level(current * factor)
    }

    /// One press of Zoom In.
    public static func zoomedIn(_ value: Double) -> Double { zoomed(value, by: step) }

    /// One press of Zoom Out.
    public static func zoomedOut(_ value: Double) -> Double { zoomed(value, by: 1 / step) }

    /// Whether Zoom In can still widen the bars.
    public static func canZoomIn(_ value: Double) -> Bool { level(value) < range.upperBound }

    /// Whether Zoom Out can still narrow the bars.
    public static func canZoomOut(_ value: Double) -> Bool { level(value) > range.lowerBound }

    /// The level as VoiceOver says it: "200 percent".
    public static func spoken(_ value: Double) -> String {
        "\(Int((level(value) * 100).rounded())) percent"
    }

    /// The width of the song's first bar at this level, in points.
    public static func pointsPerBar(_ value: Double) -> Double {
        TimelineGeometry.pointsPerBar * level(value)
    }

    /// Ticks one point spans at this level: the one scale the ruler, the lanes and the playhead
    /// line all draw with.
    public static func ticksPerPoint(_ value: Double, meter: MeterMap) -> Double {
        TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: pointsPerBar(value))
    }

    /// The ticks a finger's drag of `points` spans: points × ticksPerPoint, to the nearest tick.
    /// A drag or a scale that is not a number spans nothing; a drag past the song's room is held
    /// to it, so no addition after it can overflow.
    public static func ticks(dragged points: Double, ticksPerPoint: Double) -> Tick {
        guard points.isFinite, ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        let limit = Double(MusicalTime.maximumTick)
        return Tick((points * ticksPerPoint).rounded().clamped(to: -limit...limit))
    }

    /// Where a block that starts at `start` shows while a finger drags it by `points`, in points
    /// from where it rests: on the magnet's line the drop will land on (`SnapGrid.nearest`, the
    /// rule `Arranging.moved` commits with), so what lifts is what was seen at every zoom.
    public static func previewPoints(from start: Tick, dragged points: Double, ticksPerPoint: Double,
                                     snap: SnapGrid, meter: MeterMap) -> Double {
        guard ticksPerPoint.isFinite, ticksPerPoint > 0 else { return 0 }
        let target = snap.nearest(start + ticks(dragged: points, ticksPerPoint: ticksPerPoint), meter: meter)
        return Double(target - start) / ticksPerPoint
    }
}

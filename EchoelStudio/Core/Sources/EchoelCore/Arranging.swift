import Foundation

/// The arrangement's decisions as pure functions — bar snapping, hit-testing, song length and
/// which command a tap or a drag becomes — so the arrange view stays thin and this is tested
/// directly. Placements move in whole bars; finer placement is a later grid option.
public enum Arranging {
    /// `tick` rounded to the nearest bar line; never before bar 1.
    public static func nearestBar(_ tick: Tick, signature: TimeSignature) -> Tick {
        let bar = MusicalTime.ticksPerBar(signature)
        guard bar > 0 else { return Swift.max(0, tick) }
        let snapped = (Swift.max(0, tick) + bar / 2) / bar * bar
        return Swift.min(snapped, MusicalTime.maximumTick / bar * bar)
    }

    /// The bar line at or before `tick`; never before bar 1.
    public static func barStart(_ tick: Tick, signature: TimeSignature) -> Tick {
        let bar = MusicalTime.ticksPerBar(signature)
        guard bar > 0 else { return Swift.max(0, tick) }
        return Swift.max(0, tick) / bar * bar
    }

    /// Where a placement stops sounding: one clip length after its start.
    public static func end(of placement: Placement, in track: Track) -> Tick? {
        track.clips.first { $0.id == placement.clip }.map { placement.start + $0.length }
    }

    /// The placement covering `tick`, the latest-starting one if several overlap — the one
    /// drawn on top.
    public static func placement(in track: Track, at tick: Tick) -> Placement? {
        track.placements.last { p in
            guard let stop = Self.end(of: p, in: track) else { return false }
            return p.start <= tick && tick < stop
        }
    }

    /// The song's length in whole bars: up to the end of the last placement, at least one bar.
    public static func songBars(of project: Project) -> Int {
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        guard bar > 0 else { return 1 }
        let last = project.tracks.reduce(Tick(0)) { result, track in
            track.placements.reduce(result) { Swift.max($0, Self.end(of: $1, in: track) ?? 0) }
        }
        return Swift.max(1, Int((last + bar - 1) / bar))
    }

    /// A tap on the track's lane at `tick`. On a placement: nil — the view opens or selects it.
    /// On empty space: the track's clip placed at the bar the tap fell in. Nil for a track
    /// that has no clip yet, or one that plays no notes.
    public static func tap(on track: Track, at tick: Tick, signature: TimeSignature) -> Command? {
        guard track.kind == .instrument, tick >= 0, placement(in: track, at: tick) == nil,
              let clip = track.clips.first else { return nil }
        let start = barStart(tick, signature: signature)
        guard start <= MusicalTime.maximumTick else { return nil }
        return .placeClip(track: track.id, id: PlacementID(), clip: clip.id, start: start)
    }

    /// The command for a placement dragged by `delta` ticks, snapped to the nearest bar.
    /// Nil when it lands where it started.
    public static func moved(_ placement: Placement, in track: Track, byTicks delta: Tick,
                             signature: TimeSignature) -> Command? {
        let target = nearestBar(placement.start + delta, signature: signature)
        guard target != placement.start else { return nil }
        return .movePlacement(track: track.id, placement.id, start: target)
    }

    /// A copy of the placement straight after it, as in any DAW's Duplicate.
    public static func duplicated(_ placement: Placement, in track: Track) -> Command? {
        guard let stop = Self.end(of: placement, in: track), stop <= MusicalTime.maximumTick else { return nil }
        return .placeClip(track: track.id, id: PlacementID(), clip: placement.clip, start: stop)
    }
}

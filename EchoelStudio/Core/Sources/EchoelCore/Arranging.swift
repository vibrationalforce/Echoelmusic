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
    /// The loop length for a stretch of audio `seconds` long: the nearest whole number of bars
    /// at `bpm`, at least one — a loop recorded to the song's tempo comes out exact.
    public static func loopLength(seconds: Double, bpm: Double, signature: TimeSignature) -> Tick {
        let bar = MusicalTime.ticksPerBar(signature)
        guard seconds.isFinite, seconds > 0, bpm.isFinite, bpm > 0, bar > 0 else { return Swift.max(bar, 1) }
        let secondsPerBar = Double(bar) / Double(MusicalTime.ticksPerQuarter) * 60 / bpm
        let bars = Swift.min(Swift.max((seconds / secondsPerBar).rounded(), 1), Double(MusicalTime.maximumTick / bar))
        return Tick(bars) * bar
    }

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

    /// Where an audio region stops, in ticks: the file time it plays, laid over the song's
    /// tempo map from its start. Nil when the song no longer has its file.
    public static func end(of region: AudioRegion, in project: Project) -> Tick? {
        guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite else { return nil }
        let map = project.tempoMap
        return map.tick(atSeconds: map.seconds(at: region.start) + Double(region.length) / file.sampleRate)
    }

    /// The audio region covering `tick`, the latest-starting one if several overlap.
    public static func region(in track: Track, at tick: Tick, project: Project) -> AudioRegion? {
        track.regions.last { r in
            guard let stop = Self.end(of: r, in: project) else { return false }
            return r.start <= tick && tick < stop
        }
    }

    /// The command for a region dragged by `delta` ticks, snapped to the nearest bar.
    /// Nil when it lands where it started.
    public static func moved(_ region: AudioRegion, in track: Track, byTicks delta: Tick,
                             signature: TimeSignature) -> Command? {
        let target = nearestBar(region.start + delta, signature: signature)
        guard target != region.start else { return nil }
        return .moveRegion(track: track.id, region.id, start: target)
    }

    /// The song's length in whole bars: up to the end of the last placement or audio region,
    /// at least one bar.
    public static func songBars(of project: Project) -> Int {
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        guard bar > 0 else { return 1 }
        let last = project.tracks.reduce(Tick(0)) { result, track in
            let clips = track.placements.reduce(result) { Swift.max($0, Self.end(of: $1, in: track) ?? 0) }
            return track.regions.reduce(clips) { Swift.max($0, Self.end(of: $1, in: project) ?? 0) }
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

    public enum Edge: Sendable { case start, end }

    /// The commands for an audio region's edge dragged by `delta` ticks, snapped to the beat.
    /// The end changes how much of the file plays. The start moves where the region begins AND
    /// where in the file it starts, so the audio that stays sits exactly where it sat in the
    /// song; dragged before the file's first frame it stops there. Nil when nothing changes.
    public static func trimmed(_ region: AudioRegion, edge: Edge, byTicks delta: Tick,
                               in track: Track, project: Project) -> [Command]? {
        guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite,
              let stop = end(of: region, in: project) else { return nil }
        let beat = MusicalTime.ticksPerBeat(project.timeSignature)
        let map = project.tempoMap
        func snapped(_ tick: Tick) -> Tick {
            let clamped = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
            return beat > 0 ? (clamped + beat / 2) / beat * beat : clamped
        }
        func frames(from: Tick, to: Tick) -> Int {
            Int(((map.seconds(at: to) - map.seconds(at: from)) * file.sampleRate).rounded())
        }
        switch edge {
        case .end:
            let target = snapped(stop + delta)
            guard target > region.start else { return nil }
            let length = Swift.min(Swift.max(1, frames(from: region.start, to: target)), file.frameCount - region.offset)
            guard length >= 1, length != region.length else { return nil }
            return [.trimRegion(track: track.id, region.id, offset: region.offset, length: length)]
        case .start:
            var target = snapped(region.start + delta)
            var offset = region.offset + frames(from: region.start, to: target)
            if offset < 0 {
                // The file begins later than the drag: the region starts on its first frame.
                offset = 0
                target = map.tick(atSeconds: map.seconds(at: region.start) - Double(region.offset) / file.sampleRate)
            }
            let endFrame = region.offset + region.length
            guard target != region.start, offset < endFrame else { return nil }
            return [.trimRegion(track: track.id, region.id, offset: offset, length: endFrame - offset),
                    .moveRegion(track: track.id, region.id, start: Swift.max(0, target))]
        }
    }

    /// A copy of the placement straight after it, as in any DAW's Duplicate.
    public static func duplicated(_ placement: Placement, in track: Track) -> Command? {
        guard let stop = Self.end(of: placement, in: track), stop <= MusicalTime.maximumTick else { return nil }
        return .placeClip(track: track.id, id: PlacementID(), clip: placement.clip, start: stop)
    }
}

extension Project {
    /// What a WAV export renders: a note that plays in a clip placed on an instrument track, or an
    /// audio region on an audio track whose file the song still has. A song with neither — the
    /// four-track starter's empty Beat — rendered a WAV file of no length (critic 2026-10-22).
    /// Notes and regions only, as the render measures its length: a clip that only moves the
    /// wheel or a controller sounds nothing on its own.
    public var arrangementHasSound: Bool {
        tracks.contains { track in
            switch track.kind {
            case .instrument: track.placedClips.contains { clip in clip.notes.contains { $0.start < clip.length } }
            case .audio: track.regions.contains { $0.length > 0 && mediaFile($0.media) != nil }
            case .returnTrack, .video: false
            }
        }
    }

    /// What a MIDI export writes: a note or a controller move inside a clip placed on an
    /// instrument track. Without one the file held empty tracks.
    public var arrangementHasEvents: Bool {
        tracks.contains { track in
            track.kind == .instrument && track.placedClips.contains { clip in
                clip.notes.contains { $0.start < clip.length } || clip.controls.contains { $0.start < clip.length }
            }
        }
    }
}

extension Track {
    /// The clips the arrangement plays, once each however often they are placed.
    fileprivate var placedClips: [Clip] {
        let placed = Set(placements.map(\.clip))
        return clips.filter { placed.contains($0.id) }
    }
}

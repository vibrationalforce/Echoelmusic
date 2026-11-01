import Foundation

/// The hits of the song's video (CUT, 2026-11-01): the moments in a video file a sound should land
/// on — where a sound in the video's own audio begins, and where its picture cuts hard — laid onto
/// the timeline where the video parts play them, and the snapping that puts a clip or an audio
/// region on one. The app finds them in the files (EchoelDSP's `OnsetDetector` and `CutDetector`);
/// they are derived and never stored in the song, so no format field: a song opens the same without
/// them, and they are found again from the files.
public enum Hits {
    /// What one file holds, in seconds from its start, rising.
    public struct FileHits: Equatable, Sendable {
        /// Where a sound in the file's own audio begins.
        public let sounds: [Double]
        /// The first frame of each new shot.
        public let cuts: [Double]

        /// Times that are not a number or fall before the file's start are left out; the rest are sorted.
        public init(sounds: [Double], cuts: [Double]) {
            self.sounds = sounds.filter { $0.isFinite && $0 >= 0 }.sorted()
            self.cuts = cuts.filter { $0.isFinite && $0 >= 0 }.sorted()
        }

        public static let none = FileHits(sounds: [], cuts: [])
    }

    /// One hit on the timeline.
    public struct Hit: Hashable, Sendable {
        public enum Kind: Hashable, Sendable {
            /// A sound in the video's own audio begins.
            case sound
            /// The picture cuts to a new shot.
            case cut
        }

        public let tick: Tick
        public let kind: Kind

        public init(tick: Tick, kind: Kind) {
            self.tick = tick
            self.kind = kind
        }
    }

    /// The hits a video part shows: each moment of its file inside the stretch it plays, at the tick
    /// it plays at — the song's tempo map laid over the file's seconds, as the picture runs — rising.
    /// None for a part whose file is not a usable video.
    public static func hits(of region: AudioRegion, in project: Project, file hits: FileHits) -> [Hit] {
        guard let file = project.mediaFile(region.media), file.kind == .video, file.sampleRate.isFinite,
              file.sampleRate > 0, region.length > 0 else { return [] }
        let map = project.tempoMap
        let begin = map.seconds(at: region.start)
        let fileStart = Double(region.offset) / file.sampleRate
        let fileEnd = fileStart + Double(region.length) / file.sampleRate
        guard begin.isFinite, fileStart.isFinite, fileEnd.isFinite else { return [] }
        func placed(_ seconds: Double, _ kind: Hit.Kind) -> Hit? {
            guard seconds >= fileStart, seconds < fileEnd else { return nil }
            let position = map.position(atSeconds: begin + (seconds - fileStart))
            guard position.isFinite, position >= 0 else { return nil }
            return Hit(tick: Swift.min(MusicalTime.integer(position.rounded()), MusicalTime.maximumTick), kind: kind)
        }
        let found = hits.sounds.compactMap { placed($0, .sound) } + hits.cuts.compactMap { placed($0, .cut) }
        return found.sorted { $0.tick != $1.tick ? $0.tick < $1.tick : $0.kind == .cut && $1.kind == .sound }
    }

    /// Every hit the song's video tracks show, rising, each tick once — what a clip or a region
    /// snaps to.
    public static func ticks(in project: Project, files: [MediaID: FileHits]) -> [Tick] {
        var ticks = Set<Tick>()
        for track in project.tracks where track.kind == .video {
            for region in track.regions {
                guard let found = files[region.media] else { continue }
                for hit in hits(of: region, in: project, file: found) { ticks.insert(hit.tick) }
            }
        }
        return ticks.sorted()
    }

    /// The hit nearest `tick`, at most `tolerance` ticks away; of two as near, the earlier. Nil when
    /// none is that near.
    public static func nearest(to tick: Tick, in hits: [Tick], tolerance: Tick) -> Tick? {
        var best: Tick?
        for hit in hits {
            let distance = Swift.abs(hit - tick)
            guard distance <= tolerance else { continue }
            if let chosen = best, Swift.abs(chosen - tick) <= distance { continue }
            best = hit
        }
        return best
    }

    /// The first hit after `tick`; nil when there is none.
    public static func next(after tick: Tick, in hits: [Tick]) -> Tick? {
        hits.filter { $0 > tick }.min()
    }

    /// The command that starts a placed clip exactly on `tick`; nil when it starts there already.
    public static func placed(_ placement: Placement, in track: Track, at tick: Tick) -> Command? {
        let start = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        guard start != placement.start else { return nil }
        return .movePlacement(track: track.id, placement.id, start: start)
    }

    /// The command that starts an audio region exactly on `tick`; nil when it starts there already.
    public static func placed(_ region: AudioRegion, in track: Track, at tick: Tick) -> Command? {
        let start = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        guard start != region.start else { return nil }
        return .moveRegion(track: track.id, region.id, start: start)
    }
}

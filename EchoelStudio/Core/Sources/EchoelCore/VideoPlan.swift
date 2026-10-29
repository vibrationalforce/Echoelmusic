import Foundation

/// What the song's video tracks show, as pure functions of the song (wave W7): the picture at a
/// position of the song clock, how a player that drifted off that clock gets back onto it, and the
/// cut list a video export lays over the mix. No AVFoundation, no clock of its own — the app hands
/// in the position the engine plays, so picture and sound share one timeline.
///
/// Which part shows: the top video track (song order) that is not muted and has a part there, and
/// within a track the part that starts later — the stacking rule of every video editor: cut the
/// top track and the one below shows through. A video's own sound is never played.
public enum VideoPlan {
    /// The picture at one moment: which part, and where in its file.
    public struct Shot: Equatable, Sendable {
        public let track: TrackID
        public let region: RegionID
        public let media: MediaID
        /// Seconds into the file. Finite, at or after the part's first frame, before its last.
        public let fileSeconds: Double

        public init(track: TrackID, region: RegionID, media: MediaID, fileSeconds: Double) {
            self.track = track
            self.region = region
            self.media = media
            self.fileSeconds = fileSeconds
        }
    }

    /// The picture at `position` (fractional ticks of the song clock), nil in a gap.
    public static func shot(in project: Project, at position: Double) -> Shot? {
        guard position.isFinite else { return nil }
        let map = project.tempoMap
        return shot(in: project, atSeconds: map.seconds(atPosition: position), map: map)
    }

    /// The picture at `seconds` of song time, nil in a gap.
    public static func shot(in project: Project, atSeconds seconds: Double) -> Shot? {
        shot(in: project, atSeconds: seconds, map: project.tempoMap)
    }

    private static func shot(in project: Project, atSeconds now: Double, map: TempoMap) -> Shot? {
        guard now.isFinite else { return nil }
        for track in project.tracks where shows(track) {
            // Regions are kept sorted by start: the last one covering `now` started latest.
            for region in track.regions.reversed() {
                guard let span = span(of: region, in: project, map: map) else { continue }
                let elapsed = now - span.begin
                guard elapsed >= 0, elapsed < span.duration else { continue }
                return Shot(track: track.id, region: region.id, media: region.media,
                            fileSeconds: span.fileStart + elapsed)
            }
        }
        return nil
    }

    // MARK: - Staying on the clock

    /// How a running player gets back onto the song clock.
    public enum Correction: Equatable, Sendable {
        /// Within one frame: leave it — a seek here would only add a visible hitch.
        case hold
        /// Run at this rate for now. Always within `1 ± maxSlew`, and continuous with `hold` at the
        /// deadband's edge, so drift hovering there never flickers the speed.
        case nudge(rate: Double)
        /// Too far to slew back in a useful time: jump to the file position the clock asks for.
        case seek(toSeconds: Double)
    }

    /// One frame at 30 fps. Drift up to this is held.
    public static let deadbandSeconds: Double = 1.0 / 30.0
    /// Drift beyond this is sought, not slewed.
    public static let seekBeyondSeconds: Double = 0.25
    /// The largest rate change a nudge makes (±3 %), small enough not to read as a speed change.
    public static let maxSlew: Double = 0.03
    /// Rate change per second of drift beyond the deadband.
    public static let slewPerSecondOfDrift: Double = 0.5

    /// The correction for a player showing `observed` seconds of its file while the clock asks for
    /// `expected`. Drift above 0 means the picture runs ahead (slow down), below 0 behind (speed up).
    /// Only the drift beyond the deadband is corrected, so the rate leaves 1 continuously.
    public static func correction(expected: Double, observed: Double) -> Correction {
        guard expected.isFinite else { return .hold }
        guard observed.isFinite else { return .seek(toSeconds: Swift.max(0, expected)) }
        let drift = observed - expected
        let size = abs(drift)
        if size <= deadbandSeconds { return .hold }
        if size > seekBeyondSeconds { return .seek(toSeconds: Swift.max(0, expected)) }
        let slew = Swift.min(Swift.max((size - deadbandSeconds) * slewPerSecondOfDrift, 0), maxSlew)
        return .nudge(rate: drift > 0 ? 1 - slew : 1 + slew)
    }

    // MARK: - The cut list of an export

    /// One stretch of the exported picture: `duration` seconds of a file from `fileSeconds`, at
    /// `songSeconds` of the export.
    public struct Segment: Equatable, Sendable {
        public let region: RegionID
        public let media: MediaID
        public let fileSeconds: Double
        public let songSeconds: Double
        public let duration: Double

        public init(region: RegionID, media: MediaID, fileSeconds: Double, songSeconds: Double, duration: Double) {
            self.region = region
            self.media = media
            self.fileSeconds = fileSeconds
            self.songSeconds = songSeconds
            self.duration = duration
        }

        public var songEnd: Double { songSeconds + duration }
    }

    /// The song's picture as a cut list, in song order: what `shot` shows at every moment, each
    /// stretch from one part, gaps left out (the export shows black there). Never cuts a part
    /// shorter than the song shows it; the export decides its own length from this and the mix,
    /// whichever is longer, so neither is cut to fit the other.
    public static func program(of project: Project) -> [Segment] {
        let map = project.tempoMap
        var points = Set<Double>()
        for track in project.tracks where shows(track) {
            for region in track.regions {
                guard let span = span(of: region, in: project, map: map) else { continue }
                points.insert(span.begin)
                points.insert(span.begin + span.duration)
            }
        }
        let sorted = points.sorted()
        var segments: [Segment] = []
        for (from, to) in zip(sorted, sorted.dropFirst()) where to > from {
            let middle = (from + to) / 2
            guard let shot = shot(in: project, atSeconds: middle, map: map) else { continue }
            let fileStart = shot.fileSeconds - (middle - from)
            if let last = segments.last, last.region == shot.region, abs(last.songEnd - from) < 1e-9,
               abs(last.fileSeconds + last.duration - fileStart) < 1e-6 {
                segments[segments.count - 1] = Segment(region: last.region, media: last.media, fileSeconds: last.fileSeconds,
                                                       songSeconds: last.songSeconds, duration: to - last.songSeconds)
            } else {
                segments.append(Segment(region: shot.region, media: shot.media, fileSeconds: fileStart,
                                        songSeconds: from, duration: to - from))
            }
        }
        return segments
    }

    /// Where the song's picture ends, in seconds; 0 without one.
    public static func programEnd(of project: Project) -> Double {
        program(of: project).last?.songEnd ?? 0
    }

    // MARK: - Shared

    private static func shows(_ track: Track) -> Bool {
        track.kind == .video && !track.mixer.isMuted
    }

    /// A part's place in song seconds and in its file, nil when its file is not a usable video.
    private static func span(of region: AudioRegion, in project: Project, map: TempoMap)
        -> (begin: Double, duration: Double, fileStart: Double)? {
        guard let file = project.mediaFile(region.media), file.kind == .video,
              file.sampleRate.isFinite, file.sampleRate > 0, region.length > 0 else { return nil }
        let begin = map.seconds(at: region.start)
        guard begin.isFinite else { return nil }
        return (begin, Double(region.length) / file.sampleRate, Double(region.offset) / file.sampleRate)
    }
}

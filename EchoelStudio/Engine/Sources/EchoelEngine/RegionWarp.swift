import EchoelCore
import EchoelDSP
import Foundation

/// Warp (AUD-2): an audio region that follows the song's tempo, pitch unchanged. The stretch is
/// done OFF the render thread — once per region and tempo, kept by its `Key` — into a buffer at
/// the file's own rate whose frame `t` sounds `t` file-rate frames after the region's start in
/// song time. The snapshot plays that buffer like any region; the render thread only reads it.
///
/// The read position follows the song's tempo map frame by frame: through a step change and
/// through a ramp (`TempoMap`'s linear ramps) alike, so the warped region stays on its beats and
/// ends exactly where `Arranging.end` draws it. A region whose stretch is not ready yet is silent,
/// never played at the wrong speed; an export prepares every stretch before it renders
/// (`OfflineRender`), so what it writes is what plays once the stretch is in.
public enum RegionWarp {
    /// What a stretch depends on. The tempo enters as the bpm where it is the same across the
    /// region — then the region's place does not matter and a moved region keeps its stretch —
    /// and as the region's start with the song's tempo changes where it moves.
    public struct Key: Hashable, Sendable {
        let media: MediaID
        let offset: Int
        let length: Int
        let nativeBPM: Double
        let fileRate: Double
        let tempo: Tempo

        enum Tempo: Hashable, Sendable {
            case constant(Double)
            case moving(start: Tick, bpm: Double, changes: [TempoChange])
        }
    }

    /// The longest stretch, in file frames: 20 minutes at 192 kHz.
    public static let maximumFrames = 20 * 60 * 192_000

    /// The key of a warped region, nil for one that plays at the file's own speed or whose file is
    /// not loaded.
    public static func key(of region: AudioRegion, in project: Project, buffer: SampleBuffer) -> Key? {
        guard let native = region.warpBPM, region.offset >= 0, region.length > 0,
              buffer.sampleRate > 0, buffer.sampleRate.isFinite,
              let stop = project.position(of: region, atFileFrames: Double(region.length)) else { return nil }
        let map = project.tempoMap
        let end = MusicalTime.integer(stop.rounded(.up))
        // The same tempo across the region: one segment holds both ends and does not ramp.
        let constant = !map.segments.contains { $0.startTick > region.start && $0.startTick < end } && !map.isRamp(at: region.start)
        let tempo: Key.Tempo = constant ? .constant(map.bpm(at: region.start))
            : .moving(start: region.start, bpm: project.tempo, changes: project.tempoChanges)
        return Key(media: region.media, offset: region.offset, length: Swift.min(region.length, buffer.frameCount - region.offset),
                   nativeBPM: native, fileRate: buffer.sampleRate, tempo: tempo)
    }

    /// The stretched frames of a warped region, at the file's rate. Nil when there is nothing to
    /// stretch. Allocates and takes time: never on the render thread, nor in a view body.
    public static func render(_ region: AudioRegion, in project: Project, buffer: SampleBuffer) -> SampleBuffer? {
        guard let native = region.warpBPM, region.offset >= 0, region.offset < buffer.frameCount else { return nil }
        let rate = buffer.sampleRate
        let length = Swift.min(region.length, buffer.frameCount - region.offset)
        guard length > 0, rate > 0, rate.isFinite else { return nil }
        let map = project.tempoMap
        let startSeconds = map.seconds(at: region.start)
        let ticksPerQuarter = Double(MusicalTime.ticksPerQuarter)
        // Where the file's last frame sounds, in song time.
        let endPosition = Double(region.start) + Double(length) / rate * native / 60 * ticksPerQuarter
        let seconds = map.seconds(atPosition: endPosition) - startSeconds
        guard seconds.isFinite, seconds > 0 else { return nil }
        let outputCount = Int((seconds * rate).rounded())
        guard outputCount > 0, outputCount <= maximumFrames else { return nil }
        let start = Double(region.start)
        return buffer.stretched(offset: region.offset, length: length, outputCount: outputCount) { (frame: Int) -> Double in
            // The song position `frame` file-rate frames after the region's start, and the file
            // frame its native tempo puts there.
            let position = map.position(atSeconds: startSeconds + Double(frame) / rate)
            return (position - start) / ticksPerQuarter * 60 / native * rate
        }
    }

    /// Every warped region of `project` whose file `samples` holds, with its key, once per key.
    public static func pending(in project: Project, samples: [MediaID: SampleBuffer]) -> [(Key, AudioRegion, SampleBuffer)] {
        var seen = Set<Key>()
        var result: [(Key, AudioRegion, SampleBuffer)] = []
        for track in project.tracks where track.kind == .audio {
            // The pieces a comp plays, each its own stretch (Recovery 4).
            for region in track.playedRegions(in: project) {
                guard let buffer = samples[region.media], let key = key(of: region, in: project, buffer: buffer),
                      seen.insert(key).inserted else { continue }
                result.append((key, region, buffer))
            }
        }
        return result
    }

    /// Every stretch `project` needs, rendered now: what an export or a bake plays.
    public static func prepare(_ project: Project, samples: [MediaID: SampleBuffer]) -> [Key: SampleBuffer] {
        var stretched: [Key: SampleBuffer] = [:]
        for (key, region, buffer) in pending(in: project, samples: samples) {
            if let result = render(region, in: project, buffer: buffer) { stretched[key] = result }
        }
        return stretched
    }
}

extension RegionWarp {
    /// One past the last output sample a warped region of `project` writes, its stretch rendered or
    /// not — what a render's length needs before it renders. 0 without warped regions.
    static func end(of project: Project, samples: [MediaID: SampleBuffer], sampleRate: Double) -> Int64 {
        let map = project.tempoMap
        var end: Int64 = 0
        for track in project.tracks where track.kind == .audio {
            for region in track.playedRegions(in: project) where region.warpBPM != nil && samples[region.media] != nil {
                guard let stop = project.position(of: region, atFileFrames: Double(region.length)) else { continue }
                let seconds = map.seconds(atPosition: stop)
                guard seconds.isFinite, seconds > 0 else { continue }
                end = Swift.max(end, MusicalTime.integer((seconds * sampleRate).rounded(.up)))
            }
        }
        return end
    }

    /// Whether a track plays a warped region whose file is loaded.
    static func plays(_ track: TrackID, in project: Project, samples: [MediaID: SampleBuffer]) -> Bool {
        project.track(track)?.regions.contains { $0.warpBPM != nil && samples[$0.media] != nil } ?? false
    }
}

import EchoelCore
import EchoelDSP
import Foundation

/// Warp (AUD-2): an audio region that follows the song's tempo, pitch unchanged — or, transposed
/// (W-4), keeps its timing with its pitch moved. The stretch is
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
        /// How it stretches (W-3): an unknown stored name stretches as Tones and shares its key.
        let mode: WarpMode
        /// The transposition, in cents (W-4); 0 for none.
        let cents: Double

        enum Tempo: Hashable, Sendable {
            case constant(Double)
            case moving(start: Tick, bpm: Double, changes: [TempoChange])
            /// A region at the file's own speed, transposed: the song's tempo does not enter.
            case fileSpeed
        }
    }

    /// The longest stretch, in file frames: 20 minutes at 192 kHz.
    public static let maximumFrames = 20 * 60 * 192_000

    /// Whether a region plays a buffer made for it here: it follows the song's tempo, or it is
    /// transposed (W-4). Any other region plays its file as it is.
    public static func isStretched(_ region: AudioRegion) -> Bool {
        region.warpBPM != nil || region.playedTransposeCents != 0
    }

    /// The key of a warped or transposed region, nil for one that plays its file as it is or whose
    /// file is not loaded.
    public static func key(of region: AudioRegion, in project: Project, buffer: SampleBuffer) -> Key? {
        let cents = region.playedTransposeCents
        guard region.warpBPM != nil else {
            guard cents != 0, region.offset >= 0, region.length > 0, region.offset < buffer.frameCount,
                  buffer.sampleRate > 0, buffer.sampleRate.isFinite else { return nil }
            return Key(media: region.media, offset: region.offset, length: Swift.min(region.length, buffer.frameCount - region.offset),
                       nativeBPM: 0, fileRate: buffer.sampleRate, tempo: .fileSpeed, mode: .tones, cents: cents)
        }
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
                   nativeBPM: native, fileRate: buffer.sampleRate, tempo: tempo, mode: region.warpMode, cents: cents)
    }

    /// The stretched frames of a warped or transposed region, at the file's rate. Nil when there is
    /// nothing to stretch, or when a buffer it makes on the way would pass `limit` frames per
    /// channel. Allocates and takes time: never on the render thread, nor in a view body.
    public static func render(_ region: AudioRegion, in project: Project, buffer: SampleBuffer,
                              limit: Int = maximumFrames) -> SampleBuffer? {
        guard region.offset >= 0, region.offset < buffer.frameCount else { return nil }
        let rate = buffer.sampleRate
        let length = Swift.min(region.length, buffer.frameCount - region.offset)
        guard length > 0, rate > 0, rate.isFinite else { return nil }
        let cents = region.playedTransposeCents
        let outputCount: Int
        let mode: WarpMode
        // The file frame that sounds `frame` file-rate frames after the region's start.
        let readAt: (Double) -> Double
        if let native = region.warpBPM {
            let map = project.tempoMap
            let startSeconds = map.seconds(at: region.start)
            let ticksPerQuarter = Double(MusicalTime.ticksPerQuarter)
            // Where the file's last frame sounds, in song time.
            let endPosition = Double(region.start) + Double(length) / rate * native / 60 * ticksPerQuarter
            let seconds = map.seconds(atPosition: endPosition) - startSeconds
            guard seconds.isFinite, seconds > 0 else { return nil }
            outputCount = Int((seconds * rate).rounded())
            mode = region.warpMode
            let start = Double(region.start)
            // The song position `frame` file-rate frames after the region's start, and the file
            // frame its native tempo puts there.
            readAt = { (frame: Double) -> Double in
                let position = map.position(atSeconds: startSeconds + frame / rate)
                return (position - start) / ticksPerQuarter * 60 / native * rate
            }
        } else {
            // At the file's own speed: only a transposition makes a buffer.
            guard cents != 0 else { return nil }
            outputCount = length
            mode = .tones
            readAt = { (frame: Double) -> Double in frame }
        }
        guard outputCount > 0, outputCount <= limit else { return nil }
        let splice = Swift.max(1, Int((spliceSeconds * rate).rounded()))
        guard cents != 0 else {
            switch mode {
            case .tones:
                return buffer.stretched(offset: region.offset, length: length, outputCount: outputCount) { (frame: Int) -> Double in
                    readAt(Double(frame))
                }
            case .beats:
                guard let sides = buffer.sides(offset: region.offset, length: length) else { return nil }
                let out = WSOLAStretcher().stretch(sides, outputCount: outputCount, anchors: onsets(in: sides, rate: rate),
                                                   splice: splice) { (frame: Int) -> Double in readAt(Double(frame)) }
                return buffer.withSides(out)
            case .rePitch:
                guard let sides = buffer.sides(offset: region.offset, length: length) else { return nil }
                return buffer.withSides(WSOLAStretcher.resample(sides, outputCount: outputCount) { (frame: Int) -> Double in
                    readAt(Double(frame))
                })
            }
        }
        // W-4: stretched by the pitch ratio with the timing the mode gives, then read back faster
        // or slower by the same ratio — the pitch moves, every frame still sounds where it did.
        // The stretched buffer is up to four times the region (two octaves up) and is held to the
        // same limit as the region's own output, so a transposition never makes it four times
        // the memory an untransposed stretch may take.
        let ratio = Foundation.pow(2, cents / 1_200)
        guard ratio.isFinite, ratio > 0 else { return nil }
        let wanted = (Double(outputCount) * ratio).rounded(.up) + 2
        guard wanted.isFinite, wanted <= Double(limit) else { return nil }
        let longer = Int(wanted)
        guard longer > 2,
              let sides = buffer.sides(offset: region.offset, length: length) else { return nil }
        let stretcher = WSOLAStretcher()
        let timed: [[Float]]
        switch mode {
        case .tones:
            timed = stretcher.stretch(sides, outputCount: longer) { (frame: Int) -> Double in readAt(Double(frame) / ratio) }
        case .beats:
            timed = stretcher.stretch(sides, outputCount: longer, anchors: onsets(in: sides, rate: rate),
                                      splice: splice) { (frame: Int) -> Double in readAt(Double(frame) / ratio) }
        case .rePitch:
            // Played like a record first, so its pitch follows the tempo, then transposed on top.
            let played = WSOLAStretcher.resample(sides, outputCount: outputCount) { (frame: Int) -> Double in readAt(Double(frame)) }
            timed = stretcher.stretch(played, outputCount: longer) { (frame: Int) -> Double in Double(frame) / ratio }
        }
        return buffer.withSides(WSOLAStretcher.resample(timed, outputCount: outputCount) { (frame: Int) -> Double in
            Double(frame) * ratio
        })
    }

    /// Beats (W-3): how long the piece before an attack fades out while the attack's piece fades in.
    static let spliceSeconds = 0.002

    /// The frames of `sides` where a sound starts, from their mono sum, rising.
    static func onsets(in sides: [[Float]], rate: Double) -> [Int] {
        guard let first = sides.first, !first.isEmpty else { return [] }
        var mono = first
        if sides.count > 1 {
            let scale = 1 / Float(sides.count)
            for i in mono.indices {
                var sum: Float = 0
                for side in sides where i < side.count { sum += side[i] }
                mono[i] = sum * scale
            }
        }
        var detector = OnsetDetector(sampleRate: rate)
        detector.process(mono)
        return detector.onsets.compactMap { (seconds: Double) -> Int? in
            let frame = (seconds * rate).rounded()
            guard frame.isFinite, frame > 0, frame < Double(mono.count) else { return nil }
            return Int(frame)
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
            for region in track.playedRegions(in: project) where isStretched(region) && samples[region.media] != nil {
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
        project.track(track)?.regions.contains { isStretched($0) && samples[$0.media] != nil } ?? false
    }
}

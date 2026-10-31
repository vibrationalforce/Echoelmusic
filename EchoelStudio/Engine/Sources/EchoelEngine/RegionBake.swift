import EchoelCore
import EchoelDSP
import EchoelKernels
import Foundation

/// Bake Effects: one audio region played through its track's inserts, rendered offline into the
/// frames of a new file. The original file is never touched; the app writes these frames as a new
/// media file and swaps the region in one undo step.
///
/// What is baked and what is not, so the baked region plays as the original did:
/// · **the inserts and their automation** — the lanes on this track's inserts stay, so an effect
///   that moves over the region moves in the bake too;
/// · **not the fader, the pan, the sends or the master** — the baked region goes back onto a track
///   with a fader of its own, and baking the fader in would apply it twice;
/// · **not the body.** The song's modulation routes are left out, so a live pulse or breath can
///   never change a bake: two bakes of the same song give the same frames (offline-export freeze).
///   MIDI mappings are left out for the same reason.
///
/// The region keeps its place on the timeline during the render, so a tempo-synced effect sees the
/// beat it sees in playback. The frames start at the region's start and run on while the effects
/// still sound (a reverb's tail), up to `OfflineRender.maximumRingOutSeconds`.
public enum RegionBake {
    /// The song cut down to the one region on its own track, as the bake renders it. Nil when the
    /// track or the region does not exist or the track is not an audio track.
    public static func project(_ song: Project, track id: TrackID, region regionID: RegionID) -> Project? {
        guard let source = song.track(id), source.kind == .audio,
              let index = source.regionIndex(regionID) else { return nil }
        var track = source
        track.regions = [source.regions[index]]
        track.clips = []
        track.placements = []
        track.slots = []
        track.sends = []
        track.mixer = MixerStrip()
        track.output = nil
        track.input = nil
        let inserts = Set(track.inserts.map(\.id))
        var cut = song
        cut.tracks = [track]
        cut.master = MixerStrip()
        cut.masterInserts = []
        cut.modRoutes = []
        cut.midiMappings = []
        cut.automation = song.automation.filter { lane in
            switch lane.target.owner {
            case .project:
                return true
            case .master:
                return false
            case .track(let owner):
                guard owner == id, case .insert(let insert)? = lane.target.key.pluginParameter?.unit else { return false }
                return inserts.contains(insert)
            }
        }
        return cut
    }

    /// The region through its track's `effects`, as mono frames at `sampleRate`, from the region's
    /// start to where the sound dies away. `effects` are units made for this render alone (as for
    /// an export), in the track's insert order. Nil when there is nothing to bake.
    ///
    /// The track's bus is stereo and Echoel's audio files are mono: the two sides are summed, and
    /// the centre pan's −3 dB is taken back out, so a mono effect bakes to exactly the level it
    /// plays at and a wide one (the harmonizer's spread voices) folds to the middle.
    public static func render(_ song: Project, track: TrackID, region: RegionID, sampleRate: Double,
                              samples: [MediaID: SampleBuffer], effects: [any HostedProcessor]) -> [Float]? {
        guard let cut = project(song, track: track, region: region),
              let start = cut.track(track)?.regions.first?.start else { return nil }
        let result = OfflineRender.render(cut, sampleRate: sampleRate, tailSeconds: 0, samples: samples,
                                          effects: effects.isEmpty ? [:] : [track: effects])
        let time = TimeConversion(tempoMap: cut.tempoMap, sampleRate: result.sampleRate)
        let first = Int(Swift.max(0, Swift.min(time.sample(at: start), Int64(result.left.count))))
        guard first < result.left.count, result.left.count == result.right.count else { return nil }
        // Centre pan is cos(π/4) on each side: (L + R) / 2 / cos(π/4) = (L + R) / √2.
        let scale = Float(1 / 2.0.squareRoot())
        var frames: [Float] = []
        frames.reserveCapacity(result.left.count - first)
        for i in first..<result.left.count {
            let value = (result.left[i] + result.right[i]) * scale
            frames.append(value.isFinite ? value : 0)
        }
        return frames
    }
}

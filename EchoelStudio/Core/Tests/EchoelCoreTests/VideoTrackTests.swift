import Foundation
import XCTest
@testable import EchoelCore

/// Format 4 (wave W7): a video track shows video files on the timeline, cut like audio and never
/// heard — the song's mix is the sound of a video export.
final class VideoTrackTests: XCTestCase {
    private let take = MediaFile(name: "Take", path: "Media/take.mov", frameCount: 480_000, sampleRate: 48_000,
                                 kind: .video)
    private let loop = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    private func song() throws -> (Project, video: TrackID, audio: TrackID, keys: TrackID) {
        var project = Project()
        let video = TrackID(), audio = TrackID(), keys = TrackID()
        try Command.addTrack(id: video, name: "Video 1", kind: .video, index: nil).apply(to: &project)
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addMedia(take).apply(to: &project)
        try Command.addMedia(loop).apply(to: &project)
        return (project, video, audio, keys)
    }

    func testAVideoIsMeasuredInTheTimeBaseOfTheMix() {
        XCTAssertEqual(MediaFile.videoTimeBase, 48_000)
        XCTAssertEqual(MediaFile.videoLength(seconds: 10), 480_000)
        XCTAssertEqual(MediaFile.videoLength(seconds: 0.5), 24_000)
        XCTAssertNil(MediaFile.videoLength(seconds: 0))
        XCTAssertNil(MediaFile.videoLength(seconds: -1))
        XCTAssertNil(MediaFile.videoLength(seconds: .nan))
        XCTAssertNil(MediaFile.videoLength(seconds: .infinity))
    }

    func testAVideoTrackShowsVideoFilesAndAnAudioTrackPlaysAudioFiles() throws {
        var (p, video, audio, _) = try song()
        let before = p
        XCTAssertThrowsError(try Command.placeVideo(track: audio, id: RegionID(), media: take.id, start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.placeVideo(track: video, id: RegionID(), media: loop.id, start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.placeAudio(track: audio, id: RegionID(), media: take.id, start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.placeAudio(track: video, id: RegionID(), media: loop.id, start: 0).apply(to: &p))
        XCTAssertEqual(p, before, "a refused placement leaves the song as it was")

        let shot = RegionID()
        try Command.placeVideo(track: video, id: shot, media: take.id, start: 3_840).apply(to: &p)
        let region = try XCTUnwrap(p.track(video)?.regions.first)
        XCTAssertEqual(region.id, shot)
        XCTAssertEqual(region.start, 3_840)
        XCTAssertEqual(region.offset, 0)
        XCTAssertEqual(region.length, 480_000, "the whole take")
        XCTAssertEqual(Arranging.end(of: region, in: p), 3_840 + 10 * 1_920, "ten seconds at 120 BPM are five bars")

        // Moved and trimmed like any region; the file is never touched.
        try Command.moveRegion(track: video, shot, start: 0).apply(to: &p)
        try Command.trimRegion(track: video, shot, offset: 48_000, length: 96_000).apply(to: &p)
        XCTAssertEqual(p.track(video)?.regions.first?.offset, 48_000)
        XCTAssertEqual(p.mediaFile(take.id), take)
        XCTAssertNoThrow(try p.validate())
    }

    func testAVideoTrackHasNothingThatSounds() throws {
        var (p, video, _, keys) = try song()
        let back = TrackID()
        try Command.addTrack(id: back, name: "Room", kind: .returnTrack, index: nil).apply(to: &p)
        let before = p
        let effect = PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("dely"),
                                     manufacturer: PluginComponent.code("Echl"), name: "Delay", manufacturerName: "Echoel")
        XCTAssertThrowsError(try Command.addInsert(track: video, id: InsertID(), plugin: effect, index: nil).apply(to: &p))
        XCTAssertThrowsError(try Command.setSend(track: video, to: back, db: -6).apply(to: &p))
        XCTAssertThrowsError(try Command.setOutput(video, channel: 2).apply(to: &p))
        XCTAssertThrowsError(try Command.createClip(track: video, id: ClipID(), name: "C", length: 3_840).apply(to: &p))
        XCTAssertThrowsError(try Command.setInstrumentSample(keys, take.id).apply(to: &p), "a sampler plays sound")
        XCTAssertEqual(p, before)
        XCTAssertNoThrow(try Command.setSend(track: video, to: back, db: nil).apply(to: &p), "clearing nothing is fine")
    }

    func testAnAudioClipPlaysAnAudioFileOnly() throws {
        var (p, _, audio, _) = try song()
        XCTAssertThrowsError(try Command.createAudioClip(track: audio, id: ClipID(), name: "C", length: 3_840,
                                                         audio: ClipAudio(media: take.id, length: 48_000)).apply(to: &p))
    }

    /// C5: a cut on a bar line keeps every frame — the two parts play what the one did.
    func testASplitCutsARegionInTwoWithoutLosingMaterial() throws {
        var (p, video, audio, _) = try song()
        let shot = RegionID(), tail = RegionID()
        try Command.placeVideo(track: video, id: shot, media: take.id, start: 0).apply(to: &p)
        let before = p
        XCTAssertThrowsError(try Command.splitRegion(track: video, shot, at: 0, newID: tail).apply(to: &p), "at its start")
        XCTAssertThrowsError(try Command.splitRegion(track: video, shot, at: 10 * 1_920, newID: tail).apply(to: &p),
                             "at its end")
        XCTAssertThrowsError(try Command.splitRegion(track: video, shot, at: 1_920, newID: shot).apply(to: &p),
                             "the second part needs its own id")
        XCTAssertThrowsError(try Command.splitRegion(track: audio, shot, at: 1_920, newID: tail).apply(to: &p))
        XCTAssertEqual(p, before)

        // Bar 2 at 120 BPM in 4/4 is two seconds in.
        try Command.splitRegion(track: video, shot, at: 3_840, newID: tail).apply(to: &p)
        let parts = try XCTUnwrap(p.track(video)?.regions)
        XCTAssertEqual(parts.map(\.id), [shot, tail])
        XCTAssertEqual(parts.map(\.start), [0, 3_840])
        XCTAssertEqual(parts.map(\.offset), [0, 96_000])
        XCTAssertEqual(parts.map(\.length), [96_000, 384_000])
        XCTAssertEqual(parts.map(\.length).reduce(0, +), take.frameCount, "nothing of the take is lost")
        XCTAssertNoThrow(try p.validate())

        // Under a tempo change the cut still falls where the tick sounds.
        var slow = before
        try Command.setTempoChange(at: 1_920, bpm: 60).apply(to: &slow)
        try Command.splitRegion(track: video, shot, at: 2_880, newID: tail).apply(to: &slow)
        XCTAssertEqual(slow.track(video)?.regions.first?.length, 96_000, "1 s at 120, then 1 s at 60")
    }

    func testAudioRegionsSplitTheSameWay() throws {
        var (p, _, audio, _) = try song()
        let region = RegionID(), tail = RegionID()
        try Command.placeAudio(track: audio, id: region, media: loop.id, start: 0).apply(to: &p)
        try Command.splitRegion(track: audio, region, at: 1_920, newID: tail).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.map(\.length), [48_000, 48_000])
        XCTAssertEqual(p.track(audio)?.regions.last?.offset, 48_000)
    }

    /// A video is shown, never decoded: it costs no audio memory and plays nothing.
    func testAVideoIsNeverLoadedAsAudio() throws {
        var (p, video, audio, _) = try song()
        try Command.placeVideo(track: video, id: RegionID(), media: take.id, start: 0).apply(to: &p)
        try Command.placeAudio(track: audio, id: RegionID(), media: loop.id, start: 0).apply(to: &p)
        XCTAssertEqual(p.audibleMedia, [loop.id])
        let plan = p.mediaLoadPlan(budget: .max)
        XCTAssertEqual(plan.load.map(\.id), [loop.id])
        XCTAssertTrue(plan.skipped.isEmpty)
        XCTAssertTrue(p.arrangementHasSound, "the audio region still sounds")
        var silent = p
        try Command.removeTrack(audio).apply(to: &silent)
        XCTAssertFalse(silent.arrangementHasSound, "a picture alone is no sound to export")
    }

    func testAVideoTrackSurvivesARoundTripAndOnlyAVideoStoresItsKind() throws {
        var (p, video, _, _) = try song()
        try Command.placeVideo(track: video, id: RegionID(), media: take.id, start: 960).apply(to: &p)
        let data = try ProjectCodec.encode(p)
        XCTAssertEqual(try ProjectCodec.decode(data), p)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["formatVersion"] as? Int, 4)
        let media = try XCTUnwrap(root["media"] as? [[String: Any]])
        XCTAssertEqual(media.first?["kind"] as? String, "video")
        XCTAssertEqual(Set(try XCTUnwrap(media.last).keys), ["id", "name", "path", "frameCount", "sampleRate"],
                       "an audio file writes what it wrote before format 4")
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        XCTAssertEqual(tracks.first?["kind"] as? String, "video")
    }

    func testASongThatBreaksTheVideoRulesIsRefused() throws {
        var (p, video, audio, _) = try song()
        var wrongFile = p
        let v = try XCTUnwrap(wrongFile.trackIndex(audio))
        wrongFile.tracks[v].regions = [AudioRegion(media: take.id, start: 0, length: 1_000)]
        XCTAssertThrowsError(try wrongFile.validate(), "a picture on an audio track")

        try Command.placeVideo(track: video, id: RegionID(), media: take.id, start: 0).apply(to: &p)
        var effect = p
        let t = try XCTUnwrap(effect.trackIndex(video))
        effect.tracks[t].output = 2
        XCTAssertThrowsError(try effect.validate(), "a video track has no output")
        var clip = p
        clip.tracks[t].clips = [Clip(name: "C", length: 960)]
        XCTAssertThrowsError(try clip.validate(), "a video track has no clips")
    }
}

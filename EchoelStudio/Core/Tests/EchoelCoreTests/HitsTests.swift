import Foundation
import XCTest
@testable import EchoelCore

final class HitsTests: XCTestCase {
    /// Twelve seconds of video, at the 48 000 units per second of every video file.
    private let take = MediaFile(name: "Take", path: "Media/take.mov", frameCount: 576_000, sampleRate: 48_000,
                                 kind: .video)
    private let loop = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    /// A song at 120 BPM in 4/4 (a beat is half a second, 960 ticks) with a video track, an audio
    /// track and an instrument track holding one placed clip.
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

    /// A part from bar 2 (two seconds in) playing seconds 1 … 5 of its file shows the file's hits in
    /// that stretch, each at the tick it plays at; the rest of the file shows nothing.
    func testAVideoPartShowsItsFilesHitsWhereItPlaysThem() throws {
        var (p, video, _, _) = try song()
        let part = RegionID()
        try Command.placeVideo(track: video, id: part, media: take.id, start: 3_840).apply(to: &p)
        try Command.trimRegion(track: video, part, offset: 48_000, length: 192_000).apply(to: &p)
        let region = try XCTUnwrap(p.track(video)?.regions.first)
        let file = Hits.FileHits(sounds: [0.5, 1.5, 2.25], cuts: [3.0, 5.5])
        XCTAssertEqual(Hits.hits(of: region, in: p, file: file), [
            Hits.Hit(tick: 4_800, kind: .sound),
            Hits.Hit(tick: 6_240, kind: .sound),
            Hits.Hit(tick: 7_680, kind: .cut),
        ])
    }

    /// The tempo map decides where a second of the picture falls: after a change to 60 BPM a beat
    /// is a second.
    func testAHitFollowsTheTempoMap() throws {
        var (p, video, _, _) = try song()
        try Command.setTempoChange(at: 3_840, bpm: 60).apply(to: &p)
        try Command.placeVideo(track: video, id: RegionID(), media: take.id, start: 0).apply(to: &p)
        let region = try XCTUnwrap(p.track(video)?.regions.first)
        // Two seconds reach bar 2 at 120 BPM; one more second at 60 BPM is one more beat.
        let hits = Hits.hits(of: region, in: p, file: Hits.FileHits(sounds: [3], cuts: []))
        let expected: [Tick] = [3_840 + 960]
        XCTAssertEqual(hits.map(\.tick), expected)
    }

    /// Every video track's hits, once each and rising; an audio file and a file without hits show none.
    func testTheSongsHitsComeFromItsVideoTracksOnly() throws {
        var (p, video, audio, _) = try song()
        let second = TrackID()
        try Command.addTrack(id: second, name: "Video 2", kind: .video, index: nil).apply(to: &p)
        try Command.placeVideo(track: video, id: RegionID(), media: take.id, start: 0).apply(to: &p)
        try Command.placeVideo(track: second, id: RegionID(), media: take.id, start: 1_920).apply(to: &p)
        try Command.placeAudio(track: audio, id: RegionID(), media: loop.id, start: 0).apply(to: &p)
        let files = [take.id: Hits.FileHits(sounds: [1, 2], cuts: []), loop.id: Hits.FileHits(sounds: [0.5], cuts: [])]
        // The first part's hits at 1 s and 2 s, the second's (a second later) at 2 s and 3 s.
        XCTAssertEqual(Hits.ticks(in: p, files: files), [1_920, 3_840, 5_760])
        XCTAssertEqual(Hits.ticks(in: p, files: [:]), [])
    }

    /// Times that are not a number or lie before the file's start are no hits.
    func testAFileKeepsOnlyTimesInsideIt() {
        let file = Hits.FileHits(sounds: [2, .nan, -1, 0.5, .infinity], cuts: [3, 1])
        XCTAssertEqual(file.sounds, [0.5, 2])
        XCTAssertEqual(file.cuts, [1, 3])
    }

    func testADragSnapsToTheNearestHitWithinReach() {
        let hits: [Tick] = [1_000, 2_000, 5_000]
        XCTAssertEqual(Hits.nearest(to: 1_900, in: hits, tolerance: 200), 2_000)
        XCTAssertEqual(Hits.nearest(to: 1_500, in: hits, tolerance: 500), 1_000, "of two as near, the earlier")
        XCTAssertNil(Hits.nearest(to: 3_500, in: hits, tolerance: 400), "too far from any: the bar snapping decides")
        XCTAssertNil(Hits.nearest(to: 0, in: [], tolerance: 1_000))
    }

    func testTheNextHitIsTheFirstAfterTheStart() {
        let hits: [Tick] = [1_000, 2_000, 5_000]
        XCTAssertEqual(Hits.next(after: 0, in: hits), 1_000)
        XCTAssertEqual(Hits.next(after: 1_000, in: hits), 2_000, "a clip already on a hit goes to the next")
        XCTAssertNil(Hits.next(after: 5_000, in: hits))
    }

    /// Placing on a hit is one move command that lands exactly there; a clip or region already
    /// there needs none.
    func testAClipAndARegionArePlacedExactlyOnAHit() throws {
        var (p, _, audio, keys) = try song()
        let clip = ClipID(), placement = PlacementID(), region = RegionID()
        try Command.createClip(track: keys, id: clip, name: "Hit", length: 960).apply(to: &p)
        try Command.placeClip(track: keys, id: placement, clip: clip, start: 0).apply(to: &p)
        try Command.placeAudio(track: audio, id: region, media: loop.id, start: 3_840).apply(to: &p)
        let keysTrack = try XCTUnwrap(p.track(keys)), audioTrack = try XCTUnwrap(p.track(audio))
        let placed = try XCTUnwrap(keysTrack.placements.first), audioRegion = try XCTUnwrap(audioTrack.regions.first)

        try XCTUnwrap(Hits.placed(placed, in: keysTrack, at: 4_801)).apply(to: &p)
        try XCTUnwrap(Hits.placed(audioRegion, in: audioTrack, at: 6_241)).apply(to: &p)
        XCTAssertEqual(p.track(keys)?.placements.first?.start, 4_801, "not rounded to a bar or a beat")
        XCTAssertEqual(p.track(audio)?.regions.first?.start, 6_241)
        XCTAssertNil(Hits.placed(placed, in: keysTrack, at: 0))
        XCTAssertNil(Hits.placed(audioRegion, in: audioTrack, at: 3_840))
    }
}

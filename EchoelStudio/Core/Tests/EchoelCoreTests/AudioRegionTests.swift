import XCTest
@testable import EchoelCore

final class AudioRegionTests: XCTestCase {
    private let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    private func project() throws -> (Project, audio: TrackID, keys: TrackID) {
        var project = Project()
        let audio = TrackID(), keys = TrackID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addMedia(file).apply(to: &project)
        return (project, audio, keys)
    }

    func testAnAudioClipIsASessionLoopOfAFileOnAnAudioTrack() throws {
        var (p, audio, keys) = try project()
        let clip = ClipID(), scene = SceneID()
        let loop = ClipAudio(media: file.id, length: 96_000)
        try Command.addScene(id: scene, name: "A", index: nil).apply(to: &p)
        let before = p
        XCTAssertThrowsError(try Command.createAudioClip(track: keys, id: clip, name: "L", length: 3_840, audio: loop).apply(to: &p))
        XCTAssertThrowsError(try Command.createAudioClip(track: audio, id: clip, name: "L", length: 3_840,
                                                         audio: ClipAudio(media: file.id, offset: 90_000, length: 10_000)).apply(to: &p),
                             "past the end of the file")
        XCTAssertEqual(p, before)

        try Command.createAudioClip(track: audio, id: clip, name: "Loop", length: 3_840, audio: loop).apply(to: &p)
        try Command.setSlot(track: audio, scene: scene, clip: clip).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.clipInSlot(scene), clip)
        XCTAssertThrowsError(try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 10)]).apply(to: &p))
        XCTAssertThrowsError(try Command.placeClip(track: audio, id: PlacementID(), clip: clip, start: 0).apply(to: &p),
                             "session-only")
        try Command.setClipLength(clip, length: 7_680).apply(to: &p)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)).clip(clip), p.clip(clip))

        // 2 s at 120 BPM is one 4/4 bar; 7.9 s is four; a click is still one.
        XCTAssertEqual(Arranging.loopLength(seconds: 2, bpm: 120, signature: .common), 3_840)
        XCTAssertEqual(Arranging.loopLength(seconds: 7.9, bpm: 120, signature: .common), 4 * 3_840)
        XCTAssertEqual(Arranging.loopLength(seconds: 0.1, bpm: 120, signature: .common), 3_840)
        XCTAssertEqual(Arranging.loopLength(seconds: .nan, bpm: 120, signature: .common), 3_840)

        try Command.removeMedia(file.id).apply(to: &p)
        XCTAssertNil(p.clip(clip), "a clip goes with its file")
        XCTAssertNil(p.track(audio)?.clipInSlot(scene))
    }

    func testAPlacedFilePlaysWholeAndRegionsStaySortedByStart() throws {
        var (p, audio, _) = try project()
        let late = RegionID(), early = RegionID()
        try Command.placeAudio(track: audio, id: late, media: file.id, start: 3_840).apply(to: &p)
        try Command.placeAudio(track: audio, id: early, media: file.id, start: 0).apply(to: &p)
        let regions = try XCTUnwrap(p.track(audio)?.regions)
        XCTAssertEqual(regions.map(\.id), [early, late])
        XCTAssertEqual(regions.first?.offset, 0)
        XCTAssertEqual(regions.first?.length, 96_000)

        try Command.moveRegion(track: audio, early, start: 7_680).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.map(\.id), [late, early])
    }

    func testOnlyAnAudioTrackTakesAudioAndBadInputLeavesTheSongAlone() throws {
        var (p, audio, keys) = try project()
        let before = p
        XCTAssertThrowsError(try Command.placeAudio(track: keys, id: RegionID(), media: file.id, start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.placeAudio(track: audio, id: RegionID(), media: MediaID(), start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.placeAudio(track: audio, id: RegionID(), media: file.id, start: -1).apply(to: &p))
        XCTAssertThrowsError(try Command.moveRegion(track: audio, RegionID(), start: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.removeRegion(track: audio, RegionID()).apply(to: &p))
        XCTAssertEqual(p, before)

        let region = RegionID()
        try Command.placeAudio(track: audio, id: region, media: file.id, start: 0).apply(to: &p)
        XCTAssertThrowsError(try Command.placeAudio(track: audio, id: region, media: file.id, start: 960).apply(to: &p),
                             "a region id is unique")
    }

    func testATrimStaysInsideTheFile() throws {
        var (p, audio, _) = try project()
        let region = RegionID()
        try Command.placeAudio(track: audio, id: region, media: file.id, start: 0).apply(to: &p)
        try Command.trimRegion(track: audio, region, offset: 48_000, length: 48_000).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions.first?.offset, 48_000)
        XCTAssertEqual(p.track(audio)?.regions.first?.length, 48_000)

        let before = p
        for (offset, length) in [(-1, 10), (96_000, 1), (48_000, 48_001), (0, 0)] {
            XCTAssertThrowsError(try Command.trimRegion(track: audio, region, offset: offset, length: length).apply(to: &p),
                                 "\(offset)/\(length)")
        }
        XCTAssertEqual(p, before)
    }

    func testRemovingTheFileRemovesItsRegions() throws {
        var (p, audio, _) = try project()
        try Command.placeAudio(track: audio, id: RegionID(), media: file.id, start: 0).apply(to: &p)
        try Command.removeMedia(file.id).apply(to: &p)
        XCTAssertEqual(p.track(audio)?.regions, [])
    }

    func testRegionsSurviveTheCodecAndAnOlderSongHasNone() throws {
        var (p, audio, _) = try project()
        try Command.placeAudio(track: audio, id: RegionID(), media: file.id, start: 1_920).apply(to: &p)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)), p)

        let older = #"{"id":"\#(UUID().uuidString)","name":"Old","kind":"audio","colorIndex":0,"#
            + #""mixer":{"volumeDB":0,"pan":0,"isMuted":false,"isSoloed":false},"clips":[],"placements":[],"slots":[]}"#
        let track = try JSONDecoder().decode(Track.self, from: Data(older.utf8))
        XCTAssertEqual(track.regions, [])
    }

    func testTheRegionCommandsAreInTheCatalog() {
        let names = Set(CommandCatalog.all.map(\.name))
        for name in ["audio.place", "audio.move", "audio.trim", "audio.remove"] {
            XCTAssertTrue(names.contains(name), name)
        }
    }
}

import XCTest
@testable import EchoelCore

final class ArrangingTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func project(clipBars: Tick = 2) throws -> (Project, TrackID, ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "A", length: clipBars * bar).apply(to: &project)
        return (project, track, clip)
    }

    func testSnappingGoesToBarLines() {
        XCTAssertEqual(Arranging.nearestBar(bar / 2 - 1, signature: .common), 0)
        XCTAssertEqual(Arranging.nearestBar(bar / 2, signature: .common), bar)
        XCTAssertEqual(Arranging.nearestBar(-bar, signature: .common), 0)
        XCTAssertEqual(Arranging.barStart(2 * bar - 1, signature: .common), bar)
        XCTAssertLessThanOrEqual(Arranging.nearestBar(.max / 2, signature: .common), MusicalTime.maximumTick)
    }

    func testATapOnEmptySpacePlacesTheClipAtThatBar() throws {
        var (p, track, clip) = try project()
        let t = try XCTUnwrap(p.track(track))
        let command = try XCTUnwrap(Arranging.tap(on: t, at: 3 * bar + 17, signature: .common))
        guard case let .placeClip(tr, _, c, start) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(tr, track)
        XCTAssertEqual(c, clip)
        XCTAssertEqual(start, 3 * bar)
        try command.apply(to: &p)
        XCTAssertEqual(p.track(track)?.placements.map(\.start), [3 * bar])
    }

    func testATapOnAPlacementPlacesNothing() throws {
        var (p, track, clip) = try project()
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        XCTAssertNil(Arranging.tap(on: t, at: 2 * bar - 1, signature: .common))
        XCTAssertNotNil(Arranging.tap(on: t, at: 2 * bar, signature: .common), "the placement ends at bar 3")
    }

    func testATrackWithoutAClipCannotBeTapped() throws {
        var p = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Empty", kind: .instrument, index: nil).apply(to: &p)
        XCTAssertNil(Arranging.tap(on: try XCTUnwrap(p.track(track)), at: 0, signature: .common))
    }

    func testTheTopmostPlacementIsHit() throws {
        var (p, track, clip) = try project()
        let first = PlacementID(), second = PlacementID()
        try Command.placeClip(track: track, id: first, clip: clip, start: 0).apply(to: &p)
        try Command.placeClip(track: track, id: second, clip: clip, start: bar).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        XCTAssertEqual(Arranging.placement(in: t, at: bar + 1)?.id, second)
        XCTAssertEqual(Arranging.placement(in: t, at: bar - 1)?.id, first)
        XCTAssertNil(Arranging.placement(in: t, at: 3 * bar))
    }

    func testADragMovesByWholeBarsAndAShortDragDoesNothing() throws {
        var (p, track, clip) = try project()
        let id = PlacementID()
        try Command.placeClip(track: track, id: id, clip: clip, start: bar).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let placement = try XCTUnwrap(t.placements.first)
        XCTAssertNil(Arranging.moved(placement, in: t, byTicks: bar / 3, signature: .common))
        XCTAssertEqual(Arranging.moved(placement, in: t, byTicks: 2 * bar - 10, signature: .common),
                       .movePlacement(track: track, id, start: 3 * bar))
        XCTAssertEqual(Arranging.moved(placement, in: t, byTicks: -5 * bar, signature: .common),
                       .movePlacement(track: track, id, start: 0))
    }

    func testDuplicatePlacesACopyRightAfter() throws {
        var (p, track, clip) = try project(clipBars: 2)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: bar).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let command = try XCTUnwrap(Arranging.duplicated(try XCTUnwrap(t.placements.first), in: t))
        try command.apply(to: &p)
        XCTAssertEqual(p.track(track)?.placements.map(\.start), [bar, 3 * bar])
        XCTAssertEqual(Set(p.track(track)?.placements.map(\.clip) ?? []), [clip])
    }

    func testTheSongEndsWithItsLastPlacement() throws {
        var (p, track, clip) = try project(clipBars: 2)
        XCTAssertEqual(Arranging.songBars(of: p), 1, "an empty song is one bar")
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 5 * bar).apply(to: &p)
        XCTAssertEqual(Arranging.songBars(of: p), 7)
    }

    /// The export doors open only on what the file would hold: a placed clip without a note
    /// renders no length, a clip in no place is not in the file, a controller move alone is MIDI
    /// but no sound, and an audio region sounds once the song has its file.
    func testAnExportIsOfferedOnlyForWhatTheArrangementPlays() throws {
        var (p, track, clip) = try project()
        XCTAssertFalse(p.arrangementHasSound)
        XCTAssertFalse(p.arrangementHasEvents)

        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 480)]).apply(to: &p)
        XCTAssertFalse(p.arrangementHasSound, "a note in a clip that is in no place is not in the file")
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: bar).apply(to: &p)
        XCTAssertTrue(p.arrangementHasSound)
        XCTAssertTrue(p.arrangementHasEvents)

        let wheel = ClipID()
        var moves = Project()
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &moves)
        try Command.createClip(track: keys, id: wheel, name: "Wheel", length: bar).apply(to: &moves)
        try Command.placeClip(track: keys, id: PlacementID(), clip: wheel, start: 0).apply(to: &moves)
        XCTAssertFalse(moves.arrangementHasEvents, "an empty placed clip")
        try Command.setControls(wheel, [ControlChange(kind: .controller(number: 1), start: 0, value: 90)]).apply(to: &moves)
        XCTAssertTrue(moves.arrangementHasEvents)
        XCTAssertFalse(moves.arrangementHasSound, "a controller move sounds nothing on its own")

        var audio = Project()
        let lane = TrackID()
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 48_000, sampleRate: 48_000)
        try Command.addTrack(id: lane, name: "Audio", kind: .audio, index: nil).apply(to: &audio)
        try Command.addMedia(file).apply(to: &audio)
        XCTAssertFalse(audio.arrangementHasSound)
        try Command.placeAudio(track: lane, id: RegionID(), media: file.id, start: 0).apply(to: &audio)
        XCTAssertTrue(audio.arrangementHasSound)
        XCTAssertFalse(audio.arrangementHasEvents, "audio is not in the MIDI file")

        for starter in StarterProject.allCases {
            let song = try starter.project()
            XCTAssertFalse(song.arrangementHasSound, "\(starter)")
            XCTAssertFalse(song.arrangementHasEvents, "\(starter)")
        }
    }

    func testAnAudioRegionLastsAsLongAsItsFileAtTheSongsTempo() throws {
        var p = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        // Four seconds of audio is two bars of 4/4 at 120 BPM.
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 192_000, sampleRate: 48_000)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: track, id: region, media: file.id, start: bar).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let placed = try XCTUnwrap(t.regions.first)

        XCTAssertEqual(Arranging.end(of: placed, in: p), 3 * bar)
        XCTAssertEqual(Arranging.songBars(of: p), 3)
        XCTAssertEqual(Arranging.region(in: t, at: 2 * bar, project: p)?.id, region)
        XCTAssertNil(Arranging.region(in: t, at: 3 * bar, project: p))

        let command = try XCTUnwrap(Arranging.moved(placed, in: t, byTicks: bar + bar / 3, signature: .common))
        guard case let .moveRegion(_, id, start) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(id, region)
        XCTAssertEqual(start, 2 * bar)
        XCTAssertNil(Arranging.moved(placed, in: t, byTicks: bar / 3, signature: .common))
    }

}

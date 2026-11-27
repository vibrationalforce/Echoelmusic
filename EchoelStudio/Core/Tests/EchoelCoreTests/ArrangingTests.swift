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

    // MARK: - Clip edges (2026-11-19)

    /// A four-bar clip at bar 3 with a note at the start of each of its bars.
    private func placedClip() throws -> (Project, TrackID, ClipID, Placement) {
        var (p, track, clip) = try project(clipBars: 4)
        let placement = Placement(clip: clip, start: 2 * bar)
        try Command.placeClip(track: track, id: placement.id, clip: clip, start: placement.start).apply(to: &p)
        try Command.addNotes(clip, (0..<4).map { Note(pitch: 60 + $0, start: Tick($0) * bar, length: 480) }).apply(to: &p)
        return (p, track, clip, placement)
    }

    private func applied(_ commands: [Command]?, to project: Project) throws -> Project {
        var p = project
        for command in try XCTUnwrap(commands) { try command.apply(to: &p) }
        return p
    }

    func testDraggingAClipsEndShortensAndLengthensIt() throws {
        let (p, track, clip, placement) = try placedClip()
        let shorter = try applied(Arranging.trimmed(placement, edge: .end, byTicks: -2 * bar, in: try XCTUnwrap(p.track(track)),
                                                    project: p, snap: .bar), to: p)
        let short = try XCTUnwrap(shorter.track(track)?.clips.first { $0.id == clip })
        XCTAssertEqual(short.length, 2 * bar)
        XCTAssertEqual(short.notes.map(\.pitch), [60, 61], "what starts past the new end goes")
        let longer = try applied(Arranging.trimmed(placement, edge: .end, byTicks: 3 * bar, in: try XCTUnwrap(p.track(track)),
                                                   project: p, snap: .bar), to: p)
        XCTAssertEqual(longer.track(track)?.clips.first { $0.id == clip }?.length, 7 * bar)
    }

    func testDraggingAClipsStartKeepsEveryNoteWhereItSounds() throws {
        let (p, track, clip, placement) = try placedClip()
        let trimmed = try applied(Arranging.trimmed(placement, edge: .start, byTicks: bar, in: try XCTUnwrap(p.track(track)),
                                                    project: p, snap: .bar), to: p)
        let t = try XCTUnwrap(trimmed.track(track))
        let held = try XCTUnwrap(t.clips.first { $0.id == clip })
        XCTAssertEqual(t.placements.first?.start, 3 * bar)
        XCTAssertEqual(held.length, 3 * bar)
        XCTAssertEqual(held.notes.map(\.pitch), [61, 62, 63], "the note before the new start goes")
        XCTAssertEqual(held.notes.map { $0.start + 3 * bar }, [3 * bar, 4 * bar, 5 * bar], "the others sound where they did")
        let extended = try applied(Arranging.trimmed(placement, edge: .start, byTicks: -bar, in: try XCTUnwrap(p.track(track)),
                                                     project: p, snap: .bar), to: p)
        let e = try XCTUnwrap(extended.track(track))
        XCTAssertEqual(e.placements.first?.start, bar)
        XCTAssertEqual(e.clips.first { $0.id == clip }?.notes.first?.start, bar, "an empty bar before the first note")
        XCTAssertNoThrow(try ProjectCodec.decode(ProjectCodec.encode(extended)))
    }

    func testAnEdgeStopsAtTheNextClipAndAtBarOne() throws {
        var (p, track, clip, placement) = try placedClip()
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 8 * bar).apply(to: &p)
        let commands = Arranging.trimmed(placement, edge: .end, byTicks: 20 * bar, in: try XCTUnwrap(p.track(track)),
                                         project: p, snap: .bar, newClip: ClipID())
        let longer = try applied(commands, to: p)
        let own = try XCTUnwrap(longer.track(track)?.placements.first { $0.id == placement.id })
        XCTAssertEqual(longer.track(track)?.clips.first { $0.id == own.clip }?.length, 6 * bar, "stops where the next clip starts")
        let earliest = try applied(Arranging.trimmed(placement, edge: .start, byTicks: -20 * bar, in: try XCTUnwrap(p.track(track)),
                                                     project: p, snap: .bar), to: p)
        XCTAssertEqual(earliest.track(track)?.placements.first { $0.id == placement.id }?.start, 0, "never before bar 1")
    }

    func testTrimmingALinkedCopyLeavesTheOtherPlacesAlone() throws {
        var (p, track, clip, placement) = try placedClip()
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 10 * bar).apply(to: &p)
        let fresh = ClipID()
        let trimmed = try applied(Arranging.trimmed(placement, edge: .end, byTicks: -2 * bar, in: try XCTUnwrap(p.track(track)),
                                                    project: p, snap: .bar, newClip: fresh), to: p)
        let t = try XCTUnwrap(trimmed.track(track))
        XCTAssertEqual(t.placements.first { $0.id == placement.id }?.clip, fresh)
        XCTAssertEqual(t.clips.first { $0.id == fresh }?.length, 2 * bar)
        XCTAssertEqual(t.clips.first { $0.id == clip }?.length, 4 * bar, "the other copy keeps four bars")
    }

    func testAnEdgeThatDoesNotMoveIsNoChange() throws {
        let (p, track, _, placement) = try placedClip()
        XCTAssertNil(Arranging.trimmed(placement, edge: .end, byTicks: 10, in: try XCTUnwrap(p.track(track)), project: p, snap: .bar))
        XCTAssertNil(Arranging.trimmed(placement, edge: .start, byTicks: 4 * bar, in: try XCTUnwrap(p.track(track)), project: p,
                                       snap: .bar), "the start never reaches the end")
    }

    /// Placements may overlap; one that lies over this clip does not stop its edge, or a drag
    /// outward would pull the edge inward.
    func testAnOverlappingClipDoesNotTurnTheDragAround() throws {
        var (p, track, _, placement) = try placedClip()
        let over = ClipID()
        try Command.createClip(track: track, id: over, name: "Over", length: 2 * bar).apply(to: &p)
        try Command.placeClip(track: track, id: PlacementID(), clip: over, start: 4 * bar).apply(to: &p)
        try Command.placeClip(track: track, id: PlacementID(), clip: over, start: bar).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let longer = try applied(Arranging.trimmed(placement, edge: .end, byTicks: bar, in: t, project: p, snap: .bar), to: p)
        XCTAssertEqual(longer.track(track)?.clips.first { $0.id == placement.clip }?.length, 5 * bar, "one bar longer, not shorter")
        let earlier = try applied(Arranging.trimmed(placement, edge: .start, byTicks: -bar, in: t, project: p, snap: .bar), to: p)
        XCTAssertEqual(earlier.track(track)?.placements.first { $0.id == placement.id }?.start, bar, "one bar earlier, not later")
    }

    /// A start dragged later keeps the controller value in effect at the new start: a pedal held
    /// down before it is still down there.
    func testAStartDraggedLaterCarriesThePedalThatWasDown() throws {
        var (p, track, clip, placement) = try placedClip()
        try Command.setControls(clip, [ControlChange(kind: .controller(number: 64), start: bar / 2, value: 127),
                                       ControlChange(kind: .pitchBend, start: bar / 4, value: 9_000),
                                       ControlChange(kind: .pitchBend, start: 2 * bar, value: 8_192)]).apply(to: &p)
        let trimmed = try applied(Arranging.trimmed(placement, edge: .start, byTicks: bar, in: try XCTUnwrap(p.track(track)),
                                                    project: p, snap: .bar), to: p)
        let controls = try XCTUnwrap(trimmed.track(track)?.clips.first { $0.id == clip }?.controls)
        XCTAssertEqual(controls.filter { $0.kind == .controller(number: 64) }.map(\.start), [0], "the pedal is down from the start")
        XCTAssertEqual(controls.filter { $0.kind == .controller(number: 64) }.map(\.value), [127])
        XCTAssertEqual(controls.filter { $0.kind == .pitchBend }.map(\.start), [0, bar], "the bend in effect, then its return")
        XCTAssertNoThrow(try ProjectCodec.decode(ProjectCodec.encode(trimmed)))
    }

    /// The song's loop runs to the end of its last clip, as its bars are counted: a four-bar clip
    /// with a note only in bar 1 is a four-bar song, and loops four bars (2026-11-18).
    func testTheLoopAndTheBarCountShareOneEnd() throws {
        var (p, track, clip) = try project(clipBars: 4)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &p)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 480)]).apply(to: &p)
        XCTAssertEqual(Arranging.placedEnd(of: p), 4 * bar)
        XCTAssertEqual(Arranging.songBars(of: p), 4)
        XCTAssertEqual(Arranging.songLoop(songEnd: Arranging.placedEnd(of: p), meter: p.meterMap), 0..<(4 * bar))
        XCTAssertEqual(Arranging.placedEnd(of: Project()), 0, "an empty song")
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

    /// A one-bar loop drawn two and a half bars longer: two whole copies and a third cut at the
    /// half bar, all in one step (Michael, 10085: loops were duplicated copy by copy).
    func testAnAudioRegionDrawnPastItsFileRepeatsUpToTheDrag() throws {
        var p = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: track, id: region, media: file.id, start: 0).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let placed = try XCTUnwrap(t.regions.first)

        let commands = try XCTUnwrap(Arranging.extended(placed, byTicks: 2 * bar + bar / 2, in: t, project: p, snap: .beat))
        let looped = try applied(commands, to: p)
        let regions = try XCTUnwrap(looped.track(track)).regions.sorted { $0.start < $1.start }
        XCTAssertEqual(regions.map(\.start), [0, bar, 2 * bar, 3 * bar])
        XCTAssertEqual(regions.map(\.length), [96_000, 96_000, 96_000, 48_000])
        XCTAssertEqual(regions.last.flatMap { Arranging.end(of: $0, in: looped) }, 3 * bar + bar / 2)
    }

    /// Inside its file a longer drag only trims, and a shorter one trims as before.
    func testAnAudioRegionDrawnInsideItsFileOnlyTrims() throws {
        var p = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: track, id: region, media: file.id, start: 0).apply(to: &p)
        try Command.trimRegion(track: track, region, offset: 0, length: 48_000).apply(to: &p)
        let t = try XCTUnwrap(p.track(track))
        let placed = try XCTUnwrap(t.regions.first)

        let longer = try applied(Arranging.extended(placed, byTicks: bar / 4, in: t, project: p, snap: .beat), to: p)
        XCTAssertEqual(try XCTUnwrap(longer.track(track)).regions.map(\.length), [72_000])
        let shorter = try applied(Arranging.extended(placed, byTicks: -bar / 4, in: t, project: p, snap: .beat), to: p)
        XCTAssertEqual(try XCTUnwrap(shorter.track(track)).regions.map(\.length), [24_000])
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


    /// A drag on the loop strip draws whole bars, in either direction; a touch inside a bar draws
    /// that bar, a drag that ends on a bar line ends there, and nothing lies before bar 1.
    func testADragOnTheLoopStripDrawsWholeBars() throws {
        let meter = Project().meterMap
        let bar = meter.ticksPerBar(at: 0)
        XCTAssertEqual(Arranging.loopRegion(from: 100, to: 200, meter: meter), 0..<bar, "a touch inside bar 1 draws bar 1")
        XCTAssertEqual(Arranging.loopRegion(from: bar + 10, to: 100, meter: meter), 0..<(2 * bar), "right to left as left to right")
        XCTAssertEqual(Arranging.loopRegion(from: 0, to: bar, meter: meter), 0..<bar, "ending on a bar line ends there")
        XCTAssertEqual(Arranging.loopRegion(from: 2 * bar + 5, to: 4 * bar - 1, meter: meter), (2 * bar)..<(4 * bar), "bars 3 and 4")
        XCTAssertEqual(Arranging.loopRegion(from: -500, to: 10, meter: meter), 0..<bar, "nothing before bar 1")
        let last = try XCTUnwrap(Arranging.loopRegion(from: MusicalTime.maximumTick - 10, to: MusicalTime.maximumTick + 99, meter: meter))
        XCTAssertLessThanOrEqual(last.upperBound, MusicalTime.maximumTick)
        XCTAssertFalse(last.isEmpty)
        // A meter of three: bars of three quarters.
        var waltz = Project()
        waltz.timeSignature = TimeSignature(3, 4)
        let three = waltz.meterMap.ticksPerBar(at: 0)
        XCTAssertEqual(three, 3 * MusicalTime.ticksPerQuarter)
        XCTAssertEqual(Arranging.loopRegion(from: three + 1, to: three + 2, meter: waltz.meterMap), three..<(2 * three))
    }

    /// The note editor's playhead stands inside the clip where a placement of it plays, and
    /// nowhere else.
    func testTheEditorsPlayheadIsWhereAPlacementOfTheClipPlays() throws {
        var project = Project()
        let track = TrackID(), clip = ClipID(), other = ClipID()
        let bar = project.meterMap.ticksPerBar(at: 0)
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "A", length: bar).apply(to: &project)
        try Command.createClip(track: track, id: other, name: "B", length: bar).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: other, start: bar).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 2 * bar).apply(to: &project)
        XCTAssertEqual(Arranging.position(inClip: clip, of: project, atSongTick: 100.5), 100.5)
        XCTAssertNil(Arranging.position(inClip: clip, of: project, atSongTick: Double(bar) + 10), "clip B plays there")
        XCTAssertEqual(Arranging.position(inClip: clip, of: project, atSongTick: Double(2 * bar) + 960), 960, "its second placement")
        XCTAssertNil(Arranging.position(inClip: clip, of: project, atSongTick: Double(3 * bar)), "after its last placement")
        XCTAssertNil(Arranging.position(inClip: clip, of: project, atSongTick: .nan))
        XCTAssertNil(Arranging.position(inClip: ClipID(), of: project, atSongTick: 0), "no such clip")
    }
}

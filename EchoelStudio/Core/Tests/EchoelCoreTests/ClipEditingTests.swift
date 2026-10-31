import XCTest
@testable import EchoelCore

/// Splitting and joining what the arrangement plays: placed clips and audio regions.
final class ClipEditingTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    /// A Keys track with a two-bar clip placed at bar 2.
    private func keys(notes: [Note], controls: [ControlChange] = []) throws -> (Project, TrackID, PlacementID, ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID(), placement = PlacementID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Riff", length: 2 * bar).apply(to: &project)
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.setControls(clip, controls).apply(to: &project)
        try Command.placeClip(track: track, id: placement, clip: clip, start: bar).apply(to: &project)
        return (project, track, placement, clip)
    }

    private func events(_ project: Project) -> [PlaybackPlan.NoteEvent] {
        PlaybackPlan(compiling: project).tracks.first?.events ?? []
    }

    func testASplitClipPlaysWhatItPlayedBefore() throws {
        let notes = [Note(pitch: 60, start: 0, length: 480), Note(pitch: 64, start: bar, length: 960),
                     Note(pitch: 67, start: bar + 960, length: 480)]
        var (p, track, placement, clip) = try keys(notes: notes)
        let before = events(p)
        let head = ClipID(), tail = ClipID(), second = PlacementID()
        try Command.splitPlacement(track: track, placement, at: 2 * bar, head: head, tail: tail, placement: second).apply(to: &p)

        XCTAssertEqual(events(p), before, "a cut between notes changes nothing that sounds")
        let t = try XCTUnwrap(p.track(track))
        XCTAssertEqual(t.placements.map(\.id), [placement, second])
        XCTAssertEqual(t.placements.map(\.start), [bar, 2 * bar])
        XCTAssertEqual(t.placements.map(\.clip), [head, tail])
        XCTAssertNil(p.clip(clip), "the old clip goes when nothing plays it")
        XCTAssertEqual(t.clips.map(\.id), [head, tail])
        XCTAssertEqual(p.clip(head)?.length, bar)
        XCTAssertEqual(p.clip(tail)?.length, bar)
        XCTAssertEqual(p.clip(tail)?.notes.map(\.start), [0, 960])
        XCTAssertEqual(p.clip(head)?.name, "Riff")
        XCTAssertNoThrow(try p.validate())
    }

    func testANoteAcrossTheCutEndsThereAndSoundsAgainFromIt() throws {
        let held = Note(pitch: 60, start: bar - 480, length: 960)
        var (p, track, placement, _) = try keys(notes: [held])
        let head = ClipID(), tail = ClipID()
        try Command.splitPlacement(track: track, placement, at: 2 * bar, head: head, tail: tail, placement: PlacementID()).apply(to: &p)

        XCTAssertEqual(p.clip(head)?.notes.map(\.length), [480])
        XCTAssertEqual(p.clip(tail)?.notes.map(\.start), [0])
        XCTAssertEqual(p.clip(tail)?.notes.map(\.length), [480])
        let ons = events(p).filter { if case .noteOn = $0.kind { return true } else { return false } }.map(\.tick)
        XCTAssertEqual(ons, [2 * bar - 480, 2 * bar])
        XCTAssertNoThrow(try p.validate())
    }

    func testABendHeldAcrossTheCutIsHeldInTheTail() throws {
        let bend = ControlChange(kind: .pitchBend, start: 0, value: 12_000)
        let volume = ControlChange(kind: .controller(number: 7), start: 0, value: 90)
        var (p, track, placement, _) = try keys(notes: [], controls: [bend, volume])
        let head = ClipID(), tail = ClipID()
        try Command.splitPlacement(track: track, placement, at: 2 * bar, head: head, tail: tail, placement: PlacementID()).apply(to: &p)

        let restated = try XCTUnwrap(p.clip(tail)?.controls)
        XCTAssertEqual(restated.map(\.kind), [.pitchBend, .controller(number: 7)])
        XCTAssertEqual(restated.map(\.value), [12_000, 90])
        XCTAssertEqual(restated.map(\.start), [0, 0])
        // At the cut the head's return to centre comes first, then the tail bends again.
        let atCut = events(p).filter { $0.tick == 2 * bar }.map(\.kind)
        XCTAssertEqual(atCut.last(where: { if case .pitchBend = $0 { return true } else { return false } }), .pitchBend(12_000))
    }

    func testAClipASlotStillUsesStays() throws {
        var (p, track, placement, clip) = try keys(notes: [])
        let scene = SceneID()
        try Command.addScene(id: scene, name: "A", index: nil).apply(to: &p)
        try Command.setSlot(track: track, scene: scene, clip: clip).apply(to: &p)
        try Command.splitPlacement(track: track, placement, at: 2 * bar, head: ClipID(), tail: ClipID(), placement: PlacementID()).apply(to: &p)
        XCTAssertNotNil(p.clip(clip))
        XCTAssertEqual(p.track(track)?.clipInSlot(scene), clip)
    }

    func testABadSplitLeavesTheSongAlone() async throws {
        let (start, track, placement, clip) = try keys(notes: [Note(pitch: 60, start: 0, length: 10)])
        var p = start
        let taken = PlacementID()
        try Command.placeClip(track: track, id: taken, clip: clip, start: 8 * bar).apply(to: &p)
        let before = p
        let cases: [Command] = [
            .splitPlacement(track: track, placement, at: bar, head: ClipID(), tail: ClipID(), placement: PlacementID()),
            .splitPlacement(track: track, placement, at: 3 * bar, head: ClipID(), tail: ClipID(), placement: PlacementID()),
            .splitPlacement(track: track, PlacementID(), at: 2 * bar, head: ClipID(), tail: ClipID(), placement: PlacementID()),
            .splitPlacement(track: TrackID(), placement, at: 2 * bar, head: ClipID(), tail: ClipID(), placement: PlacementID()),
            .splitPlacement(track: track, placement, at: 2 * bar, head: clip, tail: ClipID(), placement: PlacementID()),
            .splitPlacement(track: track, placement, at: 2 * bar, head: ClipID(), tail: ClipID(), placement: taken),
        ]
        for command in cases {
            XCTAssertThrowsError(try command.apply(to: &p), "\(command)")
        }
        let same = ClipID()
        XCTAssertThrowsError(try Command.splitPlacement(track: track, placement, at: 2 * bar, head: same, tail: same,
                                                        placement: PlacementID()).apply(to: &p))
        XCTAssertEqual(p, before)

        // Through the store: one undo step takes both halves back.
        let cut = 2 * bar
        try await MainActor.run {
            let store = ProjectStore(project: before)
            try store.perform(.splitPlacement(track: track, placement, at: cut, head: ClipID(), tail: ClipID(),
                                              placement: PlacementID()))
            XCTAssertEqual(store.project.track(track)?.placements.count, 3)
            XCTAssertEqual(store.undoTitle, "Split Clip")
            store.undo()
            XCTAssertEqual(store.project, before)
        }
    }

    // MARK: - Audio

    /// 120 BPM, a 4 s file of 48 kHz on an audio track from bar 2: one beat is 24 000 frames.
    private func audio() throws -> (Project, TrackID, RegionID, MediaFile) {
        let file = MediaFile(name: "Take", path: "Media/take.wav", frameCount: 192_000, sampleRate: 48_000)
        var p = Project()
        let track = TrackID(), region = RegionID()
        try Command.setTempo(bpm: 120).apply(to: &p)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(file).apply(to: &p)
        try Command.placeAudio(track: track, id: region, media: file.id, start: bar).apply(to: &p)
        try Command.trimRegion(track: track, region, offset: 12_000, length: 120_000).apply(to: &p)
        return (p, track, region, file)
    }

    func testASplitRegionPlaysOnFromTheSameFile() throws {
        var (p, track, region, file) = try audio()
        let tail = RegionID()
        try Command.splitRegion(track: track, region, at: bar + 960, newID: tail).apply(to: &p)
        let regions = try XCTUnwrap(p.track(track)?.regions)
        XCTAssertEqual(regions.map(\.id), [region, tail])
        XCTAssertEqual(regions.map(\.media), [file.id, file.id])
        XCTAssertEqual(regions.map(\.start), [bar, bar + 960])
        XCTAssertEqual(regions.map(\.offset), [12_000, 36_000])
        XCTAssertEqual(regions.map(\.length), [24_000, 96_000])
        XCTAssertEqual(p.media.count, 1, "no audio is copied")
        XCTAssertNoThrow(try p.validate())
    }

    func testABadAudioSplitLeavesTheSongAlone() throws {
        var (p, track, region, _) = try audio()
        let other = RegionID()
        try Command.splitRegion(track: track, region, at: 2 * bar, newID: other).apply(to: &p)
        let before = p
        for command: Command in [
            .splitRegion(track: track, region, at: bar, newID: RegionID()),
            .splitRegion(track: track, region, at: 2 * bar, newID: RegionID()),
            .splitRegion(track: track, region, at: bar - 1, newID: RegionID()),
            .splitRegion(track: track, region, at: bar + 960, newID: other),
            .splitRegion(track: track, RegionID(), at: bar + 960, newID: RegionID()),
            .splitRegion(track: track, region, at: -1, newID: RegionID()),
        ] {
            XCTAssertThrowsError(try command.apply(to: &p), "\(command)")
        }
        XCTAssertEqual(p, before)
    }

    // MARK: - Consolidating

    func testConsolidatedPlacementsPlayWhatTheyPlayed() throws {
        let notes = [Note(pitch: 60, start: 0, length: 480), Note(pitch: 62, start: bar + 960, length: 1_920)]
        var (p, track, placement, clip) = try keys(notes: notes)
        let copy = PlacementID(), overlapping = PlacementID()
        try Command.placeClip(track: track, id: copy, clip: clip, start: 3 * bar).apply(to: &p)
        // Starts a little after the copy: its 60 and 62 cut the copy's short, in playback and after.
        try Command.placeClip(track: track, id: overlapping, clip: clip, start: 3 * bar + 240).apply(to: &p)
        let before = events(p)
        let joined = ClipID()
        try Command.consolidatePlacements(track: track, [overlapping, placement, copy], clip: joined).apply(to: &p)

        XCTAssertEqual(events(p), before)
        let t = try XCTUnwrap(p.track(track))
        XCTAssertEqual(t.placements.map(\.id), [placement])
        XCTAssertEqual(t.placements.map(\.clip), [joined])
        XCTAssertEqual(t.placements.map(\.start), [bar])
        XCTAssertEqual(p.clip(joined)?.length, 4 * bar + 240)
        XCTAssertEqual(p.clip(joined)?.notes.count, 6)
        XCTAssertEqual(p.clip(joined)?.name, "Riff")
        XCTAssertNil(p.clip(clip), "nothing plays the old clip any more")
        XCTAssertNoThrow(try p.validate())
    }

    func testASplitThenConsolidatedClipPlaysTheOriginal() throws {
        let notes = [Note(pitch: 60, start: 0, length: 480), Note(pitch: 64, start: bar, length: 960)]
        var (p, track, placement, _) = try keys(notes: notes)
        let before = events(p)
        let tail = PlacementID()
        try Command.splitPlacement(track: track, placement, at: 2 * bar, head: ClipID(), tail: ClipID(), placement: tail).apply(to: &p)
        let joined = ClipID()
        try Command.consolidatePlacements(track: track, [placement, tail], clip: joined).apply(to: &p)
        XCTAssertEqual(events(p), before)
        XCTAssertEqual(p.track(track)?.clips.map(\.id), [joined])
        XCTAssertEqual(p.clip(joined)?.notes.map(\.start), [0, bar])
    }

    func testABendEndingInsideTheSpanReturnsToRestThere() throws {
        var (p, track, placement, clip) = try keys(notes: [], controls: [ControlChange(kind: .pitchBend, start: 0, value: 12_000)])
        let later = PlacementID()
        try Command.placeClip(track: track, id: later, clip: clip, start: 4 * bar).apply(to: &p)
        let before = events(p)
        let joined = ClipID()
        try Command.consolidatePlacements(track: track, [placement, later], clip: joined).apply(to: &p)
        XCTAssertEqual(events(p), before)
        XCTAssertEqual(p.clip(joined)?.controls.map(\.value), [12_000, ControlChange.bendCentre, 12_000])
    }

    func testABadConsolidationLeavesTheSongAlone() throws {
        var (p, track, placement, clip) = try keys(notes: [])
        let other = PlacementID()
        try Command.placeClip(track: track, id: other, clip: clip, start: 3 * bar).apply(to: &p)
        let before = p
        for command: Command in [
            .consolidatePlacements(track: track, [placement], clip: ClipID()),
            .consolidatePlacements(track: track, [placement, placement], clip: ClipID()),
            .consolidatePlacements(track: track, [placement, PlacementID()], clip: ClipID()),
            .consolidatePlacements(track: track, [placement, other], clip: clip),
            .consolidatePlacements(track: TrackID(), [placement, other], clip: ClipID()),
        ] {
            XCTAssertThrowsError(try command.apply(to: &p), "\(command)")
        }
        XCTAssertEqual(p, before)
    }

    func testSplitAudioJoinsBackIntoTheRegionItWas() throws {
        var (p, track, region, _) = try audio()
        try Command.setTempo(bpm: 97).apply(to: &p)
        let original = try XCTUnwrap(p.track(track)?.regions.first)
        let tail = RegionID()
        try Command.splitRegion(track: track, region, at: bar + 1_237, newID: tail).apply(to: &p)
        try Command.consolidateRegions(track: track, [tail, region]).apply(to: &p)
        XCTAssertEqual(p.track(track)?.regions, [original])
    }

    func testAudioThatWouldNeedABounceIsRefused() throws {
        var (p, track, region, file) = try audio()
        let second = MediaFile(name: "Other", path: "Media/other.wav", frameCount: 48_000, sampleRate: 48_000)
        try Command.addMedia(second).apply(to: &p)
        let overlapping = RegionID(), elsewhere = RegionID(), otherFile = RegionID()
        try Command.placeAudio(track: track, id: overlapping, media: file.id, start: bar + 960).apply(to: &p)
        try Command.placeAudio(track: track, id: elsewhere, media: file.id, start: 20 * bar).apply(to: &p)
        try Command.placeAudio(track: track, id: otherFile, media: second.id, start: 40 * bar).apply(to: &p)
        let before = p
        for command: Command in [
            .consolidateRegions(track: track, [region, overlapping]),
            .consolidateRegions(track: track, [region, elsewhere]),
            .consolidateRegions(track: track, [elsewhere, otherFile]),
            .consolidateRegions(track: track, [region]),
            .consolidateRegions(track: track, [region, region]),
            .consolidateRegions(track: track, [region, RegionID()]),
        ] {
            XCTAssertThrowsError(try command.apply(to: &p), "\(command)")
        }
        XCTAssertEqual(p, before)
    }

    // MARK: - What a tap in the arrangement becomes

    func testTheArrangementSplitsOnlyInsideAndJoinsTheRunATouchingPlacementSitsIn() throws {
        var (p, track, placement, clip) = try keys(notes: [Note(pitch: 60, start: 0, length: 10)])
        let touching = PlacementID(), apart = PlacementID()
        try Command.placeClip(track: track, id: touching, clip: clip, start: 3 * bar).apply(to: &p)
        try Command.placeClip(track: track, id: apart, clip: clip, start: 8 * bar).apply(to: &p)
        var t = try XCTUnwrap(p.track(track))
        let first = try XCTUnwrap(t.placements.first { $0.id == placement })
        let lone = try XCTUnwrap(t.placements.first { $0.id == apart })

        XCTAssertNil(Arranging.split(first, in: t, at: bar), "on its first tick")
        XCTAssertNil(Arranging.split(first, in: t, at: 3 * bar), "where it ends")
        XCTAssertNil(Arranging.consolidated(lone, in: t))
        let join = try XCTUnwrap(Arranging.consolidated(first, in: t))
        guard case let .consolidatePlacements(_, ids, _) = join else { return XCTFail("\(join)") }
        XCTAssertEqual(ids, [placement, touching])

        let cut = try XCTUnwrap(Arranging.split(first, in: t, at: 2 * bar))
        try cut.apply(to: &p)
        t = try XCTUnwrap(p.track(track))
        XCTAssertEqual(t.placements.map(\.start), [bar, 2 * bar, 3 * bar, 8 * bar])
    }

    func testTheArrangementJoinsAudioOnlyWhereNoBounceIsNeeded() throws {
        var (p, track, region, file) = try audio()
        try Command.splitRegion(track: track, region, at: bar + 960, newID: RegionID()).apply(to: &p)
        var t = try XCTUnwrap(p.track(track))
        let head = try XCTUnwrap(t.regions.first { $0.id == region })
        let join = try XCTUnwrap(Arranging.consolidated(head, in: t, project: p))
        guard case let .consolidateRegions(_, ids) = join else { return XCTFail("\(join)") }
        XCTAssertEqual(ids.count, 2)

        // The same file again on top: both would sound, so only a bounce could join them.
        try Command.placeAudio(track: track, id: RegionID(), media: file.id, start: bar + 480).apply(to: &p)
        t = try XCTUnwrap(p.track(track))
        XCTAssertNil(Arranging.consolidated(head, in: t, project: p))
    }

    func testADuplicatedRegionPlaysTheSameStretchRightAfterIt() async throws {
        let (start, track, region, _) = try audio()
        let original = try XCTUnwrap(start.track(track)?.regions.first { $0.id == region })
        let stop = try XCTUnwrap(Arranging.end(of: original, in: start))
        let commands = try XCTUnwrap(Arranging.duplicated(original, in: try XCTUnwrap(start.track(track)), project: start))
        let first = original.start
        try await MainActor.run {
            let store = ProjectStore(project: start)
            try store.perform(commands, title: "Duplicate Audio")
            let regions = store.project.track(track)?.regions ?? []
            XCTAssertEqual(regions.map(\.start), [first, stop])
            XCTAssertEqual(regions.map(\.offset), [12_000, 12_000])
            XCTAssertEqual(regions.map(\.length), [120_000, 120_000])
            XCTAssertEqual(store.project.media.count, 1)
            store.undo()
            XCTAssertEqual(store.project, start)
        }
    }

    func testTheSplitAndJoinCommandsAreInTheCatalog() {
        let names = Set(CommandCatalog.all.map(\.name))
        XCTAssertTrue(names.contains("arrangement.split"))
        XCTAssertTrue(names.contains("region.split"))
        XCTAssertTrue(names.contains("arrangement.consolidate"))
        XCTAssertTrue(names.contains("audio.consolidate"))
    }
}

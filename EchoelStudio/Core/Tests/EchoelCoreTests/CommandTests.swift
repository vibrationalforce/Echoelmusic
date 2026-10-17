import XCTest
@testable import EchoelCore

final class CommandTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func projectWithInstrument() throws -> (Project, TrackID, ClipID) {
        var project = Project()
        let track = TrackID()
        let clip = ClipID()
        try Command.addTrack(id: track, name: "Bass", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Riff", length: bar).apply(to: &project)
        return (project, track, clip)
    }

    func testTicksPerBarFollowsTheTimeSignature() {
        XCTAssertEqual(MusicalTime.ticksPerBar(.common), 3_840)
        XCTAssertEqual(MusicalTime.ticksPerBar(TimeSignature(7, 8)), 3_360)
        XCTAssertEqual(MusicalTime.ticksPerBar(TimeSignature(3, 4)), 2_880)
        XCTAssertEqual(MusicalTime.ticksPerBeat(TimeSignature(6, 8)), 480)
    }

    func testTempoOutsideTheRangeOrNotFiniteIsRefused() {
        var project = Project()
        for bpm in [19.9, 1_000, .nan, .infinity] {
            XCTAssertThrowsError(try Command.setTempo(bpm: bpm).apply(to: &project), "\(bpm)")
        }
        XCTAssertEqual(project.tempo, Tempo.defaultBPM)
        XCTAssertNoThrow(try Command.setTempo(bpm: 174).apply(to: &project))
        XCTAssertEqual(project.tempo, 174)
    }

    func testTimeSignatureMustBeMusical() {
        var project = Project()
        XCTAssertThrowsError(try Command.setTimeSignature(TimeSignature(4, 3)).apply(to: &project))
        XCTAssertThrowsError(try Command.setTimeSignature(TimeSignature(0, 4)).apply(to: &project))
        XCTAssertNoThrow(try Command.setTimeSignature(TimeSignature(7, 8)).apply(to: &project))
        XCTAssertEqual(project.timeSignature, TimeSignature(7, 8))
    }

    func testTracksAreAddedAtTheIndexAndNamesAreTrimmed() throws {
        var project = Project()
        let a = TrackID(), b = TrackID()
        try Command.addTrack(id: a, name: "  Drums ", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: b, name: "Vox", kind: .audio, index: 0).apply(to: &project)
        XCTAssertEqual(project.tracks.map(\.id), [b, a])
        XCTAssertEqual(project.track(a)?.name, "Drums")
        XCTAssertThrowsError(try Command.addTrack(id: a, name: "Again", kind: .audio, index: nil).apply(to: &project))
        XCTAssertThrowsError(try Command.addTrack(id: TrackID(), name: "   ", kind: .audio, index: nil).apply(to: &project))
        XCTAssertThrowsError(try Command.addTrack(id: TrackID(), name: "X", kind: .audio, index: 5).apply(to: &project))
    }

    func testMoveTrackReordersTheList() throws {
        var project = Project()
        let ids = [TrackID(), TrackID(), TrackID()]
        for (n, id) in ids.enumerated() {
            try Command.addTrack(id: id, name: "T\(n)", kind: .instrument, index: nil).apply(to: &project)
        }
        try Command.moveTrack(ids[0], toIndex: 2).apply(to: &project)
        XCTAssertEqual(project.tracks.map(\.id), [ids[1], ids[2], ids[0]])
        XCTAssertThrowsError(try Command.moveTrack(ids[0], toIndex: 3).apply(to: &project))
    }

    func testMixerValuesAreRangeChecked() throws {
        var (project, track, _) = try projectWithInstrument()
        try Command.setVolume(.track(track), db: -6).apply(to: &project)
        try Command.setPan(.master, pan: 0.25).apply(to: &project)
        XCTAssertEqual(project.track(track)?.mixer.volumeDB, -6)
        XCTAssertEqual(project.master.pan, 0.25)
        XCTAssertThrowsError(try Command.setVolume(.track(track), db: 7).apply(to: &project))
        XCTAssertThrowsError(try Command.setVolume(.master, db: .nan).apply(to: &project))
        XCTAssertThrowsError(try Command.setPan(.track(track), pan: -1.01).apply(to: &project))
        XCTAssertThrowsError(try Command.setVolume(.track(TrackID()), db: 0).apply(to: &project))
    }

    func testMIDIClipsBelongOnInstrumentTracksOnly() throws {
        var project = Project()
        let audio = TrackID(), ret = TrackID()
        try Command.addTrack(id: audio, name: "Vox", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: ret, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        for track in [audio, ret] {
            XCTAssertThrowsError(try Command.createClip(track: track, id: ClipID(), name: "C", length: 960).apply(to: &project))
        }
    }

    func testClipIDsAreUniqueAcrossTheProject() throws {
        var (project, _, clip) = try projectWithInstrument()
        let other = TrackID()
        try Command.addTrack(id: other, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertThrowsError(try Command.createClip(track: other, id: clip, name: "Dup", length: 960).apply(to: &project)) {
            XCTAssertEqual($0 as? CommandError, .duplicateID(clip.description))
        }
    }

    func testNotesAreValidatedAgainstTheClipAndKeptInOrder() throws {
        var (project, _, clip) = try projectWithInstrument()
        let late = Note(pitch: 40, start: 1_920, length: 240)
        let early = Note(pitch: 36, start: 0, length: 240)
        try Command.addNotes(clip, [late, early]).apply(to: &project)
        XCTAssertEqual(project.clip(clip)?.notes.map(\.id), [early.id, late.id])

        let outside = Note(pitch: 36, start: bar, length: 10)
        XCTAssertThrowsError(try Command.addNotes(clip, [outside]).apply(to: &project))
        XCTAssertThrowsError(try Command.addNotes(clip, [Note(pitch: 128, start: 0, length: 10)]).apply(to: &project))
        XCTAssertThrowsError(try Command.addNotes(clip, [Note(pitch: 60, velocity: 0, start: 0, length: 10)]).apply(to: &project))
        XCTAssertThrowsError(try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 0)]).apply(to: &project))
        XCTAssertThrowsError(try Command.addNotes(clip, [early]).apply(to: &project), "the same note id twice")
    }

    func testUpdateAndRemoveNotesNeedKnownIDs() throws {
        var (project, _, clip) = try projectWithInstrument()
        var note = Note(pitch: 60, start: 0, length: 480)
        try Command.addNotes(clip, [note]).apply(to: &project)
        note.pitch = 62
        note.velocity = 80
        try Command.updateNotes(clip, [note]).apply(to: &project)
        XCTAssertEqual(project.clip(clip)?.notes, [note])
        XCTAssertThrowsError(try Command.updateNotes(clip, [Note(pitch: 1, start: 0, length: 1)]).apply(to: &project))
        XCTAssertThrowsError(try Command.removeNotes(clip, [NoteID()]).apply(to: &project))
        try Command.removeNotes(clip, [note.id]).apply(to: &project)
        XCTAssertEqual(project.clip(clip)?.notes, [])
    }

    func testDeletingAClipRemovesItsPlacementsAndSlots() throws {
        var (project, track, clip) = try projectWithInstrument()
        let scene = SceneID()
        try Command.addScene(id: scene, name: "Intro", index: nil).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.setSlot(track: track, scene: scene, clip: clip).apply(to: &project)
        try Command.deleteClip(clip).apply(to: &project)
        let t = try XCTUnwrap(project.track(track))
        XCTAssertTrue(t.clips.isEmpty)
        XCTAssertTrue(t.placements.isEmpty)
        XCTAssertTrue(t.slots.isEmpty)
    }

    func testPlacementsStayInTimelineOrder() throws {
        var (project, track, clip) = try projectWithInstrument()
        let first = PlacementID(), second = PlacementID()
        try Command.placeClip(track: track, id: first, clip: clip, start: 4 * bar).apply(to: &project)
        try Command.placeClip(track: track, id: second, clip: clip, start: 0).apply(to: &project)
        XCTAssertEqual(project.track(track)?.placements.map(\.id), [second, first])
        try Command.movePlacement(track: track, second, start: 8 * bar).apply(to: &project)
        XCTAssertEqual(project.track(track)?.placements.map(\.id), [first, second])
        XCTAssertThrowsError(try Command.placeClip(track: track, id: PlacementID(), clip: ClipID(), start: 0).apply(to: &project))
        XCTAssertThrowsError(try Command.movePlacement(track: track, first, start: -1).apply(to: &project))
    }

    func testASlotHoldsOneClipAndRemovingASceneEmptiesIt() throws {
        var (project, track, clip) = try projectWithInstrument()
        let second = ClipID()
        try Command.createClip(track: track, id: second, name: "B", length: bar).apply(to: &project)
        let scene = SceneID()
        try Command.addScene(id: scene, name: "Drop", index: nil).apply(to: &project)
        try Command.setSlot(track: track, scene: scene, clip: clip).apply(to: &project)
        try Command.setSlot(track: track, scene: scene, clip: second).apply(to: &project)
        XCTAssertEqual(project.track(track)?.clipInSlot(scene), second)
        XCTAssertEqual(project.track(track)?.slots.count, 1)
        try Command.setSlot(track: track, scene: scene, clip: nil).apply(to: &project)
        XCTAssertNil(project.track(track)?.clipInSlot(scene))
        try Command.setSlot(track: track, scene: scene, clip: clip).apply(to: &project)
        try Command.removeScene(scene).apply(to: &project)
        XCTAssertEqual(project.track(track)?.slots, [])
    }

    func testEveryCommandKindHasAUniqueCatalogName() {
        let names = CommandCatalog.all.map(\.name)
        XCTAssertEqual(names.count, Command.Kind.allCases.count)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(CommandCatalog.all.allSatisfy { !$0.title.isEmpty && !$0.summary.isEmpty })
    }
}

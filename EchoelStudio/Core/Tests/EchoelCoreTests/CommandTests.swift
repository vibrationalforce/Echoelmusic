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

    func testShorteningAClipDropsWhatLiesPastItsEndAndTheSongStillOpens() throws {
        var (project, _, clip) = try projectWithInstrument()
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 480),
                                    Note(pitch: 64, start: bar / 2, length: 480)]).apply(to: &project)
        try Command.setControls(clip, [ControlChange(kind: .pitchBend, start: bar / 2, value: 9_000)]).apply(to: &project)
        try Command.setClipLength(clip, length: bar / 4).apply(to: &project)

        let shortened = try XCTUnwrap(project.clipLocation(clip).map { project.tracks[$0.track].clips[$0.clip] })
        XCTAssertEqual(shortened.notes.map(\.pitch), [60])
        XCTAssertTrue(shortened.controls.isEmpty)
        XCTAssertNoThrow(try ProjectCodec.decode(ProjectCodec.encode(project)), "a shortened clip must not lock the song")
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

    func testADerivedClipNameFitsWhateverTheTrackIsCalled() throws {
        let long = String(repeating: "x", count: Names.maximumLength)
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: long, kind: .instrument, index: nil).apply(to: &project)

        // The hand-built name the views used to compose is one word too long and is refused.
        XCTAssertThrowsError(try Command.createClip(track: track, id: ClipID(), name: "\(long) Clip", length: bar)
            .apply(to: &project))

        let derived = Names.derived(long, suffix: "Clip")
        XCTAssertEqual(derived.count, Names.maximumLength)
        XCTAssertTrue(derived.hasSuffix(" Clip"))
        try Command.createClip(track: track, id: ClipID(), name: derived, length: bar).apply(to: &project)
        XCTAssertEqual(project.tracks[0].clips.count, 1)

        XCTAssertEqual(Names.derived("Bass", suffix: "Clip"), "Bass Clip")
        XCTAssertEqual(Names.derived("Bass", suffix: "3"), "Bass 3")
        XCTAssertEqual(Names.derived("   ", suffix: "3"), "3")
        XCTAssertEqual(Names.derived("Bass", suffix: ""), "Bass")
        XCTAssertEqual(Names.derived("", suffix: ""), "Untitled")
        XCTAssertEqual(Names.derived(long, suffix: long).count, Names.maximumLength)
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

    func testASongHoldsNoMoreTracksOfAKindThanTheEngineCanPlay() throws {
        var project = Project()
        for kind in TrackKind.allCases {
            for n in 0..<Track.limit(for: kind) {
                try Command.addTrack(id: TrackID(), name: "\(kind) \(n)", kind: kind, index: nil).apply(to: &project)
            }
            XCTAssertFalse(project.canAddTrack(kind))
            let full = project
            XCTAssertThrowsError(try Command.addTrack(id: TrackID(), name: "One more", kind: kind, index: nil).apply(to: &project))
            XCTAssertEqual(project, full, "a refused track leaves the song as it was")
        }
        XCTAssertEqual(Track.limit(for: .instrument), 32)
        XCTAssertEqual(Track.limit(for: .returnTrack), 8)
        let instrument = try XCTUnwrap(project.tracks.first { $0.kind == .instrument })
        try Command.removeTrack(instrument.id).apply(to: &project)
        XCTAssertTrue(project.canAddTrack(.instrument), "removing one makes room again")
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

    /// A new track takes the first free number, never a name another track carries.
    func testANewNameTakesTheFirstFreeNumber() {
        XCTAssertEqual(Names.firstFree("Drums", taken: []), "Drums 1")
        XCTAssertEqual(Names.firstFree("Drums", taken: ["Drums 1", "Drums 2"]), "Drums 3")
        XCTAssertEqual(Names.firstFree("Drums", taken: ["Drums 1", "Drums 3"]), "Drums 2", "a gap is filled")
        XCTAssertEqual(Names.firstFree("Drums", taken: ["Drums", "Drums 2"]), "Drums 1")
    }

    /// A numbered name passes the door whatever its base is called: a base of 128 characters still
    /// gives a free "… 1", shortened on the base, never on the number.
    func testAFirstFreeNameAlwaysPassesTheDoor() throws {
        let long = String(repeating: "x", count: Names.maximumLength)
        let numbered = Names.firstFree(long, taken: [])
        XCTAssertEqual(numbered.count, Names.maximumLength)
        XCTAssertTrue(numbered.hasSuffix(" 1"))
        XCTAssertNotEqual(Names.firstFree(long, taken: [numbered]), numbered)
        XCTAssertEqual(Names.firstFree("  ", taken: []), "Untitled 1", "nothing at all is named as `derived` names it")
        var project = Project()
        try Command.addTrack(id: TrackID(), name: numbered, kind: .instrument, index: nil).apply(to: &project)
        XCTAssertEqual(project.tracks.map(\.name), [numbered])
    }

    /// A name the app composes from another one ("Keys Baked", "Melody MIDI", a track name a MIDI
    /// file carries) stays as it is while it is free, and takes " 2", " 3" … once a name in the
    /// song carries it.
    func testAComposedNameThatIsTakenIsNumberedFromTwo() {
        XCTAssertEqual(Names.unique("Keys Baked", taken: ["Keys"]), "Keys Baked")
        XCTAssertEqual(Names.unique("Keys Baked", taken: ["Keys", "Keys Baked"]), "Keys Baked 2")
        XCTAssertEqual(Names.unique("Keys Baked", taken: ["Keys Baked", "Keys Baked 2"]), "Keys Baked 3")
        XCTAssertEqual(Names.unique("  Drums ", taken: []), "Drums", "trimmed as the door trims")
        XCTAssertEqual(Names.unique("", taken: ["Untitled"]), "Untitled 2")
        let long = String(repeating: "x", count: Names.maximumLength + 10)
        let first = Names.unique(long, taken: [])
        XCTAssertEqual(first.count, Names.maximumLength)
        let second = Names.unique(long, taken: [first])
        XCTAssertEqual(second.count, Names.maximumLength)
        XCTAssertTrue(second.hasSuffix(" 2"))
    }

    /// A baked track is named after its track and numbered when that name is taken: baking one
    /// track twice leaves "Keys Baked" and "Keys Baked 2", never two tracks of one name.
    func testABakedTrackWhoseNameIsTakenGetsTwo() throws {
        var project = Project()
        try Command.addTrack(id: TrackID(), name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        let baked = Names.derived("Keys", suffix: "Baked")
        XCTAssertEqual(project.uniqueTrackName(baked), "Keys Baked")
        try Command.addTrack(id: TrackID(), name: project.uniqueTrackName(baked), kind: .audio, index: nil)
            .apply(to: &project)
        XCTAssertEqual(project.uniqueTrackName(baked), "Keys Baked 2")
    }

    /// A take is numbered one above the highest take, never by count: after "Take 1" and "Take 3"
    /// (Take 2 deleted) comes "Take 4", so a newer take never reads as older than one beside it in
    /// a take folder. Audio and video takes of a song count as one row.
    func testATakeAfterTakeOneAndTakeThreeIsTakeFour() throws {
        XCTAssertEqual(Names.after("Take", taken: ["Take 1", "Take 3"]), "Take 4")
        XCTAssertEqual(Names.number(after: "Take", taken: ["Take 1", "Take 3"]), 4)
        XCTAssertEqual(Names.after("Take", taken: []), "Take 1")
        let others = ["Take", "Takeover 9", "Take 2 (baked)", "Recovered Take 7", "take 5", "Take 2"]
        XCTAssertEqual(Names.after("Take", taken: others), "Take 3", "only “Take <number>” counts")
        XCTAssertEqual(Names.after("Take", taken: ["Take 9999999999"]), "Take 1", "a number past nine digits is not a take")
        XCTAssertEqual(Names.after("", taken: ["Untitled 1"]), "Untitled 2", "the name it gives is the name it counts")

        var project = Project()
        let audio = [MediaFile(name: "Take 1", path: "Media/a.caf", frameCount: 48_000, sampleRate: 48_000),
                     MediaFile(name: "Take 3", path: "Media/b.caf", frameCount: 48_000, sampleRate: 48_000)]
        for file in audio { try Command.addMedia(file).apply(to: &project) }
        XCTAssertEqual(project.nextTakeName(), "Take 4")
        let video = MediaFile(name: "Take 4", path: "Media/c.mov", frameCount: 240_000,
                              sampleRate: MediaFile.videoTimeBase, kind: .video)
        try Command.addMedia(video).apply(to: &project)
        XCTAssertEqual(project.nextTakeName(), "Take 5")
    }

    /// Add Scene takes the first number no scene carries — after a deleted scene, its number —
    /// never the count, which repeated the name of the last scene.
    func testASceneAfterADeletedOneTakesTheFreeNumber() throws {
        var project = Project()
        let scenes = [SceneID(), SceneID(), SceneID()]
        for id in scenes {
            try Command.addScene(id: id, name: project.nextSceneName(), index: nil).apply(to: &project)
        }
        XCTAssertEqual(project.scenes.map(\.name), ["Scene 1", "Scene 2", "Scene 3"])
        try Command.removeScene(scenes[1]).apply(to: &project)
        XCTAssertEqual(project.nextSceneName(), "Scene 2", "the count would say Scene 3, which is there")
        try Command.addScene(id: SceneID(), name: project.nextSceneName(), index: nil).apply(to: &project)
        XCTAssertEqual(project.nextSceneName(), "Scene 4")
    }

    /// A new clip is "<track> Clip", then "<track> Clip 2", "<track> Clip 3" … — the first no clip
    /// of its track carries — so two numbers never stand in a row: on the track "Drums 2" a clip
    /// "Drums 2 1" is easy to mix up, "Drums 2 Clip" is not. By count, a deleted clip made the next
    /// one repeat a name, and the first session clip on the starter's Drums, whose only clip is
    /// "Beat", was called "Drums 2" — the name of a track.
    func testANewClipIsNamedAfterItsTrackAndNeverRepeatsAName() throws {
        var project = Project()
        let drums = TrackID()
        try Command.addTrack(id: drums, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: drums, id: ClipID(), name: "Beat", length: bar).apply(to: &project)
        XCTAssertEqual(project.track(drums)?.nextClipName(), "Drums Clip")
        var made: [ClipID] = []
        for _ in 0..<3 {
            let clip = ClipID()
            let name = try XCTUnwrap(project.track(drums)?.nextClipName())
            try Command.createClip(track: drums, id: clip, name: name, length: bar).apply(to: &project)
            made.append(clip)
        }
        XCTAssertEqual(project.track(drums)?.clips.map(\.name), ["Beat", "Drums Clip", "Drums Clip 2", "Drums Clip 3"])
        try Command.deleteClip(made[1]).apply(to: &project)
        XCTAssertEqual(project.track(drums)?.nextClipName(), "Drums Clip 2", "a gap is filled")
        let names = try XCTUnwrap(project.track(drums)?.clips.map(\.name))
        XCTAssertFalse(names.contains(try XCTUnwrap(project.track(drums)?.nextClipName())))

        let numbered = TrackID()
        try Command.addTrack(id: numbered, name: "Drums 2", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertEqual(project.track(numbered)?.nextClipName(), "Drums 2 Clip", "never “Drums 2 1”")

        let long = TrackID()
        try Command.addTrack(id: long, name: String(repeating: "x", count: Names.maximumLength), kind: .instrument,
                             index: nil).apply(to: &project)
        for _ in 0..<2 {
            let name = try XCTUnwrap(project.track(long)?.nextClipName())
            XCTAssertNoThrow(try Command.createClip(track: long, id: ClipID(), name: name, length: bar).apply(to: &project))
        }
        let longNames = try XCTUnwrap(project.track(long)?.clips.map(\.name))
        XCTAssertEqual(Set(longNames).count, 2, "a track named with 128 characters gets two clips of two names")
    }

    /// A new track takes the first colour no track carries, so a deletion never leaves two tracks
    /// of one colour beside a free one; with all twelve in use the count deals it, as before. A
    /// song built without deletions gets the same colours under both rules.
    func testANewTrackTakesTheFirstColourNoTrackCarries() throws {
        var project = Project()
        let ids = [TrackID(), TrackID(), TrackID()]
        for (n, id) in ids.enumerated() {
            try Command.addTrack(id: id, name: "T\(n)", kind: .instrument, index: nil).apply(to: &project)
        }
        XCTAssertEqual(project.tracks.map(\.colorIndex), [0, 1, 2])
        try Command.removeTrack(ids[1]).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "New", kind: .audio, index: nil).apply(to: &project)
        XCTAssertEqual(project.tracks.map(\.colorIndex), [0, 2, 1], "by count it would take 2 a second time")

        var full = Project()
        for n in 0..<Palette.trackColorCount {
            try Command.addTrack(id: TrackID(), name: "T\(n)", kind: .instrument, index: nil).apply(to: &full)
        }
        let dealt: [Int] = Array(0..<Palette.trackColorCount)
        XCTAssertEqual(full.tracks.map(\.colorIndex), dealt)
        try Command.addTrack(id: TrackID(), name: "One More", kind: .audio, index: nil).apply(to: &full)
        XCTAssertEqual(full.tracks.last?.colorIndex, 0, "all twelve in use: by count, 12 tracks → colour 0")
    }
}

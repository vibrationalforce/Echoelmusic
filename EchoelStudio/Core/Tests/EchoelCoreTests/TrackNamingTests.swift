import XCTest
@testable import EchoelCore

/// Track names that two or more tracks carry — the two "Drums 2" of recordings 10083 and 10088,
/// left in songs by a numbering by count fixed on 2026-11-20: found in song order, said in one
/// line, numbered in one undo step, and said while a rename types a name another track carries.
final class TrackNamingTests: XCTestCase {
    /// A song whose instrument tracks carry `names`, in that order, and their ids.
    private func song(_ names: [String]) throws -> (Project, [TrackID]) {
        var project = Project()
        var ids: [TrackID] = []
        for name in names {
            let id = TrackID()
            try Command.addTrack(id: id, name: name, kind: .instrument, index: nil).apply(to: &project)
            ids.append(id)
        }
        return (project, ids)
    }

    func testTheNamesTwoOrMoreTracksCarryAreFoundInSongOrder() throws {
        let (project, _) = try song(["Bass", "Drums 2", "Keys", "Drums 2", "Bass", "Bass"])
        XCTAssertEqual(TrackNaming.shared(in: project), ["Bass", "Drums 2"], "each once, in the order of its first track")
        let (alone, _) = try song(["Keys", "Bass"])
        XCTAssertEqual(TrackNaming.shared(in: alone), [])
    }

    /// Every track after the first of a name is renamed: a name ending in a number takes the next
    /// number above it that no track carries, any other name the first free number from 2.
    func testNumberingLeavesNoNameShared() throws {
        let fixture = try song(["Drums 2", "Keys", "Drums 2", "Bass", "Bass", "Drums 3", "Bass"])
        var project = fixture.0
        let commands = TrackNaming.numbering(in: project)
        for command in commands { try command.apply(to: &project) }
        XCTAssertEqual(project.tracks.map(\.name), ["Drums 2", "Keys", "Drums 4", "Bass", "Bass 2", "Drums 3", "Bass 3"])
        XCTAssertEqual(TrackNaming.shared(in: project), [])
        XCTAssertEqual(commands.count, 3, "one rename for each track after the first of its name")
        XCTAssertEqual(project.track(fixture.1[0])?.name, "Drums 2", "the first track of a name keeps it")
    }

    /// The Body voice keeps "Body" wherever it stands: the Instrument page finds its track by that
    /// name, so another track called "Body", even one above it, is numbered instead. Numbered the
    /// other way, the switch would read off and switching on would add a second voice.
    func testNumberingLeavesTheBodyVoiceItsName() throws {
        var project = try StarterProject.empty.project()
        let audio = TrackID()
        try Command.addTrack(id: audio, name: BodyVoice.trackName, kind: .audio, index: nil).apply(to: &project)
        let switchedOn = try XCTUnwrap(BodyVoice.switching(true, in: project))
        for command in switchedOn.commands { try command.apply(to: &project) }
        let voice = try XCTUnwrap(BodyVoice.track(in: project)?.id)
        XCTAssertEqual(TrackNaming.shared(in: project), [BodyVoice.trackName])
        for command in TrackNaming.numbering(in: project) { try command.apply(to: &project) }
        XCTAssertEqual(BodyVoice.track(in: project)?.id, voice, "the Instrument page still finds the voice")
        XCTAssertTrue(BodyVoice.isOn(in: project))
        XCTAssertEqual(project.track(audio)?.name, "Body 2")
        XCTAssertEqual(TrackNaming.shared(in: project), [])
    }

    func testANameNoOtherTrackCarriesIsUntouched() throws {
        let (project, ids) = try song(["Keys", "Bass", "Bass"])
        XCTAssertEqual(TrackNaming.numbering(in: project), [.renameTrack(ids[2], name: "Bass 2")])
    }

    func testNothingSharedGivesNoCommandsAndNoLine() throws {
        let (project, _) = try song(["Keys", "Bass", "Drums 1"])
        XCTAssertEqual(TrackNaming.numbering(in: project), [])
        XCTAssertNil(TrackNaming.notice(in: project))
        XCTAssertNil(TrackNaming.notice(in: Project()))
    }

    func testNumberingIsOneUndoStep() async throws {
        let fixture = try song(["Drums 2", "Drums 2", "Bass", "Bass"])
        try await MainActor.run {
            let store = ProjectStore(project: fixture.0)
            try store.perform(TrackNaming.numbering(in: store.project), title: TrackNaming.title)
            XCTAssertEqual(store.project.tracks.map(\.name), ["Drums 2", "Drums 3", "Bass", "Bass 2"])
            XCTAssertEqual(store.undoStack.count, 1)
            store.undo()
            XCTAssertEqual(store.project, fixture.0, "one undo gives every name back")
        }
    }

    func testTheLineSaysWhichNamesAreShared() throws {
        let (two, _) = try song(["Drums 2", "Keys", "Drums 2"])
        XCTAssertEqual(TrackNaming.notice(in: two), "Two tracks are called “Drums 2”.")
        let (three, _) = try song(["Bass", "Bass", "Bass"])
        XCTAssertEqual(TrackNaming.notice(in: three), "Three tracks are called “Bass”.")
        let (both, _) = try song(["Drums 2", "Bass", "Drums 2", "Bass"])
        XCTAssertEqual(TrackNaming.notice(in: both), "Tracks share the names “Drums 2” and “Bass”.")
        let (more, _) = try song(["A", "A", "B", "B", "C", "C"])
        XCTAssertEqual(TrackNaming.notice(in: more), "Tracks share the names “A”, “B” and “C”.")
    }

    /// The rename sheet says it while the typed name is another track's — and still renames, since
    /// two tracks may share a name on purpose.
    func testRenameSaysWhileAnotherTrackCarriesTheTypedName() throws {
        let (project, ids) = try song(["Keys", "Bass", "Drums 2", "Drums 2"])
        XCTAssertEqual(TrackNaming.caption(renaming: ids[0], to: " Bass ", in: project), "Another track is called “Bass”.")
        XCTAssertNil(TrackNaming.caption(renaming: ids[0], to: "Keys", in: project), "its own name is no other track's")
        XCTAssertNil(TrackNaming.caption(renaming: ids[0], to: "Lead", in: project))
        XCTAssertNil(TrackNaming.caption(renaming: ids[0], to: "   ", in: project))
        XCTAssertEqual(TrackNaming.caption(renaming: ids[2], to: "Drums 2", in: project), "Another track is called “Drums 2”.",
                       "a shared name is said as soon as the sheet opens")
    }
}

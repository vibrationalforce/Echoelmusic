import XCTest
@testable import EchoelCore

/// The tracks the keys on the screen can be pointed at, and how the menu over them reads.
final class LiveTrackChoiceTests: XCTestCase {
    /// A song of these tracks, in this order, and their ids.
    private func song(_ tracks: [(name: String, kind: TrackKind)]) throws -> (Project, [TrackID]) {
        var project = Project()
        var ids: [TrackID] = []
        for track in tracks {
            let id = TrackID()
            try Command.addTrack(id: id, name: track.name, kind: track.kind, index: nil).apply(to: &project)
            ids.append(id)
        }
        return (project, ids)
    }

    func testOnlyInstrumentTracksCanBeChosenInSongOrder() throws {
        let (project, ids) = try song([("Keys", .instrument), ("Vocal", .audio), ("Bass", .instrument),
                                       ("Space", .returnTrack), ("Picture", .video), ("Drums", .instrument)])
        let choices = LiveTrackChoice.choices(in: project)
        XCTAssertEqual(choices.map(\.id), [ids[0], ids[2], ids[5]])
        XCTAssertEqual(choices.map(\.label), ["Keys", "Bass", "Drums"])
    }

    func testANameTwoTracksShareIsToldApartByTheTracksPlaceInTheSong() throws {
        // The song of the 10088 recording: two tracks called "Drums 2".
        let (project, _) = try song([("Keys", .instrument), ("Drums 2", .instrument), ("Vocal", .audio),
                                     ("Drums 2", .instrument)])
        XCTAssertEqual(LiveTrackChoice.choices(in: project).map(\.label), ["Keys", "Drums 2, track 2", "Drums 2, track 4"])
    }

    func testATrackThatCannotBeChosenMakesNoNameAmbiguous() throws {
        let (project, _) = try song([("Drums 2", .audio), ("Drums 2", .instrument)])
        XCTAssertEqual(LiveTrackChoice.choices(in: project).map(\.label), ["Drums 2"],
                       "the menu lists one Drums 2, so it needs no place")
    }

    func testTheOrderFollowsAMoveOfATrack() throws {
        let (start, ids) = try song([("Keys", .instrument), ("Bass", .instrument)])
        var project = start
        try Command.moveTrack(ids[1], toIndex: 0).apply(to: &project)
        XCTAssertEqual(LiveTrackChoice.choices(in: project).map(\.label), ["Bass", "Keys"])
    }

    func testASongWithoutAnInstrumentTrackOffersNothing() throws {
        let (project, _) = try song([("Vocal", .audio), ("Space", .returnTrack)])
        XCTAssertTrue(LiveTrackChoice.choices(in: project).isEmpty)
        XCTAssertEqual(LiveTrackChoice.header(live: nil, in: project), "No instrument track")
        XCTAssertEqual(LiveTrackChoice.header(live: nil, in: Project()), "No instrument track")
    }

    func testTheHeaderSaysWhichTrackTheKeysPlay() throws {
        let (project, ids) = try song([("Keys", .instrument), ("Vocal", .audio), ("Bass", .instrument)])
        XCTAssertEqual(LiveTrackChoice.header(live: ids[0], in: project), "Plays Keys")
        XCTAssertEqual(LiveTrackChoice.header(live: ids[2], in: project), "Plays Bass")
    }

    func testTheHeaderTellsASharedNameApartAsTheMenuDoes() throws {
        let (project, ids) = try song([("Drums 2", .instrument), ("Keys", .instrument), ("Drums 2", .instrument)])
        XCTAssertEqual(LiveTrackChoice.header(live: ids[2], in: project), "Plays Drums 2, track 3")
    }

    /// The engine plays the first instrument track when the chosen one is gone or plays nothing
    /// from keys (`AudioEngine.liveTrackID(in:)`); the header says what the keys then play.
    func testATrackThatIsGoneOrCannotPlayReadsAsTheFirstInstrumentTrack() throws {
        let (project, ids) = try song([("Vocal", .audio), ("Keys", .instrument), ("Bass", .instrument)])
        XCTAssertEqual(LiveTrackChoice.header(live: TrackID(), in: project), "Plays Keys")
        XCTAssertEqual(LiveTrackChoice.header(live: ids[0], in: project), "Plays Keys")
        XCTAssertEqual(LiveTrackChoice.header(live: nil, in: project), "Plays Keys")
    }

    func testEveryChoiceReadsDifferently() throws {
        let (project, _) = try song([("Drums", .instrument), ("Drums", .instrument), ("Drums", .instrument),
                                     ("Bass", .instrument)])
        let labels = LiveTrackChoice.choices(in: project).map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count, "\(labels)")
    }

    /// A take is written to the track that was armed when it began, so while one records the keys
    /// stay on it: what is heard is what is written.
    func testTheHeaderIsAMenuOnlyWithAChoiceToMakeAndNoTakeRecording() throws {
        let (two, _) = try song([("Keys", .instrument), ("Bass", .instrument)])
        let choices = LiveTrackChoice.choices(in: two)
        XCTAssertTrue(LiveTrackChoice.offersMenu(choices, recording: false))
        XCTAssertFalse(LiveTrackChoice.offersMenu(choices, recording: true), "not while a take records")
        let (one, _) = try song([("Keys", .instrument), ("Vocal", .audio)])
        XCTAssertFalse(LiveTrackChoice.offersMenu(LiveTrackChoice.choices(in: one), recording: false),
                       "one instrument track leaves nothing to choose")
        XCTAssertFalse(LiveTrackChoice.offersMenu([], recording: false))
    }

    /// Record writes to the armed track, and with nothing armed arms the track the keys play — so an
    /// instrument track stays armed after its first take. A choice in the keys' menu then takes the
    /// arm along, or the next take would land on a track the keys no longer play.
    func testAChoiceTakesAnArmedInstrumentTracksArmAlong() throws {
        let (project, ids) = try song([("Keys", .instrument), ("Vocal", .audio), ("Bass", .instrument)])
        XCTAssertTrue(LiveTrackChoice.movesArm(to: ids[2], armed: ids[0], in: project),
                      "Keys armed, Bass chosen: the next take goes to Bass")
        XCTAssertFalse(LiveTrackChoice.movesArm(to: ids[0], armed: ids[0], in: project), "the armed track itself stays armed")
        XCTAssertFalse(LiveTrackChoice.movesArm(to: ids[2], armed: nil, in: project),
                       "nothing armed: Record takes the track the keys play")
        XCTAssertFalse(LiveTrackChoice.movesArm(to: ids[2], armed: ids[1], in: project),
                       "an armed audio track records its input, whatever the keys play")
        XCTAssertFalse(LiveTrackChoice.movesArm(to: ids[2], armed: TrackID(), in: project), "an armed track that is gone")
        XCTAssertFalse(LiveTrackChoice.movesArm(to: ids[1], armed: ids[0], in: project), "the keys play no audio track")
    }
}

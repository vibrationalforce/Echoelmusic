import XCTest
@testable import EchoelCore

/// Convert to MIDI (A2M): notes heard in an audio region become a clip at the region's place,
/// on the grid and in the key when asked, through the one door as one step.
final class AudioToMIDITests: XCTestCase {
    private let rate = 48_000.0
    private let quarter = MusicalTime.ticksPerQuarter

    /// A song at 120 BPM with an audio track holding a two-and-a-half-second region at bar 2.
    private func song() throws -> (project: Project, track: TrackID, region: RegionID) {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let file = MediaFile(name: "Melody", path: "Media/melody.wav", frameCount: 120_000, sampleRate: rate)
        try Command.addTrack(id: track, name: "Voice", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(file).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: file.id, start: 4 * quarter).apply(to: &project)
        return (project, track, region)
    }

    /// C4, E4 and G4, half a second each, a quarter second apart.
    private let melody = [
        HeardNote(start: 0.25, length: 0.5, hertz: 261.63, velocity: 90),
        HeardNote(start: 1.0, length: 0.5, hertz: 329.63, velocity: 100),
        HeardNote(start: 1.75, length: 0.5, hertz: 392.0, velocity: 110),
    ]

    private func region(_ project: Project, _ track: TrackID, _ id: RegionID) throws -> AudioRegion {
        try XCTUnwrap(project.track(track)?.regions.first { $0.id == id })
    }

    func testTheHeardNotesBecomeTicksFromTheRegionsStart() throws {
        let (project, track, id) = try song()
        let made = try XCTUnwrap(AudioToMIDI.clip(heard: melody, region: try region(project, track, id), in: project))
        // At 120 BPM a second is two quarters.
        XCTAssertEqual(made.notes.map(\.pitch), [60, 64, 67])
        XCTAssertEqual(made.notes.map(\.start), [quarter / 2, 2 * quarter, 7 * quarter / 2])
        XCTAssertEqual(made.notes.map(\.length), [quarter, quarter, quarter])
        XCTAssertEqual(made.notes.map(\.velocity), [90, 100, 110])
        XCTAssertEqual(made.length, 5 * quarter, "the clip spans the region")
    }

    func testTheGridMovesTheNotesOntoItsLines() throws {
        let (project, track, id) = try song()
        let late = [HeardNote(start: 0.27, length: 0.46, hertz: 261.63, velocity: 90)]
        let free = try XCTUnwrap(AudioToMIDI.clip(heard: late, region: try region(project, track, id), in: project))
        XCTAssertNotEqual(free.notes.first?.start, quarter / 2, "off keeps the note where it was heard")
        let snapped = try XCTUnwrap(AudioToMIDI.clip(heard: late, region: try region(project, track, id), in: project,
                                                     options: .init(snap: .eighth)))
        XCTAssertEqual(snapped.notes.first?.start, quarter / 2)
        XCTAssertEqual(snapped.notes.first?.length, quarter)
    }

    func testTheKeyMovesAPitchIntoTheScale() throws {
        var (project, track, id) = try song()
        try Command.setScale(.major).apply(to: &project)
        let sharp = [HeardNote(start: 0, length: 0.5, hertz: 369.99, velocity: 90)] // F♯4
        let free = try XCTUnwrap(AudioToMIDI.clip(heard: sharp, region: try region(project, track, id), in: project))
        XCTAssertEqual(free.notes.first?.pitch, 66)
        let keyed = try XCTUnwrap(AudioToMIDI.clip(heard: sharp, region: try region(project, track, id), in: project,
                                                   options: .init(snapsToKey: true)))
        XCTAssertEqual(keyed.notes.first?.pitch, 65, "between F and G, the lower one")
    }

    func testTheClipStaysOneVoice() throws {
        let (project, track, id) = try song()
        let overlapping = [
            HeardNote(start: 0, length: 1, hertz: 261.63, velocity: 90),
            HeardNote(start: 0.5, length: 0.5, hertz: 293.66, velocity: 90),
            HeardNote(start: 0.5, length: 0.5, hertz: 440, velocity: 90),
            HeardNote(start: .nan, length: 0.5, hertz: 440, velocity: 90),
            HeardNote(start: 2, length: 0.2, hertz: 0, velocity: 90),
            HeardNote(start: 9, length: 0.2, hertz: 440, velocity: 90),
        ]
        let made = try XCTUnwrap(AudioToMIDI.clip(heard: overlapping, region: try region(project, track, id), in: project))
        XCTAssertEqual(made.notes.map(\.pitch), [60, 62])
        XCTAssertEqual(made.notes.first?.length, quarter, "it ends where the next note begins")
    }

    func testConvertIsOneUndoStepOnANewTrackAfterTheRegionsTrack() async throws {
        let (project, track, id) = try song()
        let newTrack = TrackID()
        let commands = try XCTUnwrap(AudioToMIDI.commands(heard: melody, region: id, on: track, in: project,
                                                          destination: .newTrack(newTrack)))
        let place = 4 * quarter
        try await MainActor.run {
            let store = ProjectStore(project: project)
            try store.perform(commands, title: AudioToMIDI.title)
            XCTAssertEqual(store.undoStack.count, 1)
            XCTAssertEqual(store.project.tracks.map(\.id), [track, newTrack])
            let made = try XCTUnwrap(store.project.track(newTrack))
            XCTAssertEqual(made.kind, .instrument)
            XCTAssertEqual(made.clips.first?.notes.map(\.pitch), [60, 64, 67])
            XCTAssertEqual(made.placements.first?.start, place, "at the region's place")
            store.undo()
            XCTAssertEqual(store.project, project)
        }
    }

    func testConvertOntoAChosenInstrumentTrack() throws {
        var (project, track, id) = try song()
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        let commands = try XCTUnwrap(AudioToMIDI.commands(heard: melody, region: id, on: track, in: project,
                                                          destination: .track(keys)))
        for command in commands { try command.apply(to: &project) }
        XCTAssertEqual(project.track(keys)?.clips.first?.name, "Melody")
        XCTAssertEqual(project.tracks.count, 2)
    }

    func testNothingHeardOrNoInstrumentTrackGivesNoCommands() throws {
        let (project, track, id) = try song()
        XCTAssertNil(AudioToMIDI.commands(heard: [], region: id, on: track, in: project, destination: .newTrack(TrackID())))
        XCTAssertNil(AudioToMIDI.commands(heard: melody, region: id, on: track, in: project, destination: .track(track)),
                     "an audio track holds no MIDI clip")
        XCTAssertNil(AudioToMIDI.commands(heard: melody, region: RegionID(), on: track, in: project,
                                          destination: .newTrack(TrackID())))
    }

    func testThePitchOfAFrequency() {
        XCTAssertEqual(AudioToMIDI.pitch(ofHertz: 440), 69)
        XCTAssertEqual(AudioToMIDI.pitch(ofHertz: 442, concertPitch: 442), 69)
        XCTAssertEqual(AudioToMIDI.pitch(ofHertz: 261.63), 60)
        XCTAssertNil(AudioToMIDI.pitch(ofHertz: 0))
        XCTAssertNil(AudioToMIDI.pitch(ofHertz: .nan))
        XCTAssertEqual(AudioToMIDI.pitch(ofHertz: 1e9), 127)
    }
}

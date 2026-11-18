import XCTest
@testable import EchoelCore

final class ClipLengthTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    /// A track with a one-bar clip placed at bar 1, holding a kick on beat 1 and a snare on beat 3.
    private func beat() throws -> (Project, TrackID, ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Beat", length: bar).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 36, start: 0, length: 240),
                                    Note(pitch: 38, start: bar / 2, length: 240)]).apply(to: &project)
        return (project, track, clip)
    }

    private func apply(_ result: Result<[Command], ClipLength.Refusal>, to project: inout Project) throws {
        for command in try result.get() { try command.apply(to: &project) }
    }

    private func clip(_ id: ClipID, in project: Project) throws -> Clip {
        let location = try XCTUnwrap(project.clipLocation(id))
        return project.tracks[location.track].clips[location.clip]
    }

    func testAOneBarBeatRepeatedToSixteenBarsPlaysItSixteenTimes() throws {
        var (project, _, id) = try beat()
        try apply(ClipLength.commands(for: id, bars: 16, repeating: true, in: project), to: &project)
        let long = try clip(id, in: project)
        XCTAssertEqual(long.length, 16 * bar)
        XCTAssertEqual(long.notes.count, 32, "two hits in each of sixteen bars")
        XCTAssertEqual(long.notes.filter { $0.pitch == 36 }.map(\.start), (0..<16).map { Tick($0) * bar })
        XCTAssertEqual(Set(long.notes.map(\.id)).count, 32, "every copy is a note of its own")
        XCTAssertEqual(ClipLength.bars(of: long, in: project), 16)
        XCTAssertNoThrow(try ProjectCodec.decode(ProjectCodec.encode(project)), "the song still opens")
    }

    func testLongerWithoutRepeatingAddsEmptyBarsAndShorterDropsWhatLiesPastTheEnd() throws {
        var (project, _, id) = try beat()
        try apply(ClipLength.commands(for: id, bars: 4, repeating: false, in: project), to: &project)
        XCTAssertEqual(try clip(id, in: project).length, 4 * bar)
        XCTAssertEqual(try clip(id, in: project).notes.count, 2)
        try apply(ClipLength.commands(for: id, bars: 1, repeating: true, in: project), to: &project)
        XCTAssertEqual(try clip(id, in: project).length, bar)
        XCTAssertEqual(try clip(id, in: project).notes.count, 2, "shortening never repeats")
    }

    func testANoteThatRangPastTheOldEndIsCutThereInEveryCopy() throws {
        var (project, _, id) = try beat()
        let long = Note(pitch: 48, start: 3 * bar / 4, length: bar / 2)   // beat 4, two beats long
        try Command.addNotes(id, [long]).apply(to: &project)
        try apply(ClipLength.commands(for: id, bars: 2, repeating: true, in: project), to: &project)
        let held = try clip(id, in: project).notes.filter { $0.pitch == 48 }
        XCTAssertEqual(held.map(\.start), [3 * bar / 4, bar + 3 * bar / 4])
        XCTAssertEqual(held.map(\.length), [bar / 4, bar / 4], "it sounded to the bar line, and still does")
    }

    func testRepeatingCarriesTheControllerChanges() throws {
        var (project, _, id) = try beat()
        try Command.setControls(id, [ControlChange(kind: .pitchBend, start: bar / 4, value: 9_000)]).apply(to: &project)
        try apply(ClipLength.commands(for: id, bars: 2, repeating: true, in: project), to: &project)
        XCTAssertEqual(try clip(id, in: project).controls.map(\.start), [bar / 4, bar + bar / 4])
    }

    func testTheSameLengthIsNoChange() throws {
        let (project, _, id) = try beat()
        XCTAssertEqual(try ClipLength.commands(for: id, bars: 1, repeating: true, in: project).get(), [])
    }

    func testALongerClipMayNotRunIntoTheNextClipOnItsTrack() throws {
        var (project, track, id) = try beat()
        try Command.placeClip(track: track, id: PlacementID(), clip: id, start: 4 * bar).apply(to: &project)
        XCTAssertNoThrow(try ClipLength.commands(for: id, bars: 4, repeating: true, in: project).get(),
                         "four bars end where the second placement starts")
        XCTAssertEqual(ClipLength.commands(for: id, bars: 8, repeating: true, in: project), .failure(.runsIntoNextClip))
    }

    func testAnAudioClipIsRefused() throws {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        project.tracks[0].clips.append(Clip(id: clip, name: "Take", length: bar,
                                            audio: ClipAudio(media: MediaID(), length: 96_000)))
        XCTAssertEqual(ClipLength.commands(for: clip, bars: 2, repeating: true, in: project), .failure(.audio))
    }

    func testEveryChoiceIsAWholeNumberOfBarsInThreeFour() throws {
        var (project, _, id) = try beat()
        try Command.setTimeSignature(TimeSignature(3, 4)).apply(to: &project)
        for bars in ClipLength.choices {
            XCTAssertEqual(ClipLength.ticks(bars: bars, of: id, in: project), Tick(bars) * MusicalTime.ticksPerBar(TimeSignature(3, 4)))
        }
    }
}

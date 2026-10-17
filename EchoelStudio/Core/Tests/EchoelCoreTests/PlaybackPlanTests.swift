import XCTest
@testable import EchoelCore

final class PlaybackPlanTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func makeProject(notes: [Note], clipLength: Tick? = nil, placementsAt starts: [Tick]) throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: clipLength ?? bar).apply(to: &project)
        try Command.addNotes(clip, notes).apply(to: &project)
        for start in starts {
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: start).apply(to: &project)
        }
        return (project, track)
    }

    private func events(_ plan: PlaybackPlan) -> [String] {
        plan.tracks.flatMap(\.events).map { event -> String in
            switch event.kind {
            case .noteOn(let velocity): "\(event.tick) on \(event.pitch) v\(velocity)"
            case .noteOff: "\(event.tick) off \(event.pitch)"
            }
        }
    }

    func testANotePlaysAtItsPlacementInSongTime() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 60, velocity: 90, start: 480, length: 240)],
                                       placementsAt: [2 * bar])
        let plan = PlaybackPlan(compiling: project)
        XCTAssertEqual(events(plan), ["\(2 * bar + 480) on 60 v90", "\(2 * bar + 720) off 60"])
        XCTAssertEqual(plan.songEnd, 2 * bar + 720)
    }

    func testANoteIsCutAtTheEndOfItsClip() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 48, start: 3 * 960, length: 4 * 960)],
                                       placementsAt: [0])
        XCTAssertEqual(events(PlaybackPlan(compiling: project)), ["2880 on 48 v100", "3840 off 48"])
    }

    func testAnUnplacedClipPlaysNothing() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 60, start: 0, length: 960)], placementsAt: [])
        XCTAssertEqual(events(PlaybackPlan(compiling: project)), [])
        XCTAssertEqual(PlaybackPlan(compiling: project).songEnd, 0)
    }

    func testBackToBackNotesOfOnePitchEndBeforeTheyRestart() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 60, start: 0, length: 960),
                                               Note(pitch: 60, start: 960, length: 960)],
                                       placementsAt: [0])
        XCTAssertEqual(events(PlaybackPlan(compiling: project)),
                       ["0 on 60 v100", "960 off 60", "960 on 60 v100", "1920 off 60"])
    }

    func testOverlappingPlacementsCutTheEarlierNoteOfTheSamePitch() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 60, start: 0, length: 3_000)],
                                       placementsAt: [0, 960])
        XCTAssertEqual(events(PlaybackPlan(compiling: project)),
                       ["0 on 60 v100", "960 off 60", "960 on 60 v100", "3960 off 60"])
    }

    func testChordNotesStayIndependent() throws {
        let (project, _) = try makeProject(notes: [Note(pitch: 64, start: 0, length: 960),
                                               Note(pitch: 60, start: 0, length: 1_920)],
                                       placementsAt: [0])
        XCTAssertEqual(events(PlaybackPlan(compiling: project)),
                       ["0 on 60 v100", "0 on 64 v100", "960 off 64", "1920 off 60"])
    }

    func testOnlyInstrumentTracksArePlanned() throws {
        var (project, track) = try makeProject(notes: [Note(pitch: 60, start: 0, length: 960)], placementsAt: [0])
        try Command.addTrack(id: TrackID(), name: "Vox", kind: .audio, index: nil).apply(to: &project)
        let plan = PlaybackPlan(compiling: project)
        XCTAssertEqual(plan.tracks.map(\.track), [track])
    }

    func testMuteDoesNotChangeTheNotes() throws {
        var (project, track) = try makeProject(notes: [Note(pitch: 60, start: 0, length: 960)], placementsAt: [0])
        let before = PlaybackPlan(compiling: project)
        try Command.setMute(track, true).apply(to: &project)
        XCTAssertEqual(PlaybackPlan(compiling: project), before)
    }

    func testFirstIndexFindsThePlayheadPosition() {
        let events = [0, 960, 960, 1_920].map {
            PlaybackPlan.NoteEvent(tick: Tick($0), pitch: 60, kind: .noteOff)
        }
        XCTAssertEqual(PlaybackPlan.firstIndex(in: events, atOrAfter: 0), 0)
        XCTAssertEqual(PlaybackPlan.firstIndex(in: events, atOrAfter: 1), 1)
        XCTAssertEqual(PlaybackPlan.firstIndex(in: events, atOrAfter: 960), 1)
        XCTAssertEqual(PlaybackPlan.firstIndex(in: events, atOrAfter: 1_921), 4)
        XCTAssertEqual(PlaybackPlan.firstIndex(in: [], atOrAfter: 0), 0)
    }

    func testTimeConversionAt120BPM() {
        let time = TimeConversion(bpm: 120, sampleRate: 48_000)
        // One quarter note at 120 BPM is half a second.
        XCTAssertEqual(time.seconds(at: 960), 0.5, accuracy: 1e-12)
        XCTAssertEqual(time.sample(at: 960), 24_000)
        XCTAssertEqual(time.sample(at: MusicalTime.ticksPerBar(.common)), 96_000)
        XCTAssertEqual(time.tick(atSample: 24_000), 960)
        XCTAssertEqual(time.samplesPerTick(at: 0), 25, accuracy: 1e-12)
    }
}

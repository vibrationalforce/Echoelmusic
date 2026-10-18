import XCTest
@testable import EchoelCore

@MainActor
final class AgentToolsTests: XCTestCase {
    private func run(_ actions: [AgentAction], on store: ProjectStore) throws {
        for action in actions {
            let commands = try AgentTools.commands(for: action, in: store.project)
            try store.perform(commands, title: "Agent", coalescingKey: "agent.turn")
        }
        store.endGesture()
    }

    func testANewDrumTrackAt120WithFourOnTheFloorIsOneUndoStep() throws {
        let store = ProjectStore(project: Project(tempo: 90))
        try run([
            .setTempo(bpm: 120),
            .addTrack(name: "Drums", kind: "drums", sound: nil),
            .drumPattern(track: "drums", drum: "kick", steps: "x...x...x...x...", bar: 1, bars: 1),
        ], on: store)

        XCTAssertEqual(store.project.tempo, 120)
        let drums = try XCTUnwrap(store.project.tracks.first)
        XCTAssertEqual(drums.instrument.device, .drums)
        XCTAssertEqual(drums.clips.count, 1, "the pattern lands in the track's first clip, not a second one")
        let kicks = drums.clips[0].notes.filter { $0.pitch == 36 }.map(\.start).sorted()
        XCTAssertEqual(kicks, [0, 960, 1_920, 2_880], "a kick on every beat")

        XCTAssertEqual(store.undoStack.count, 1)
        store.undo()
        XCTAssertEqual(store.project.tempo, 90)
        XCTAssertTrue(store.project.tracks.isEmpty)
    }

    func testAPatternRepeatsOverItsBarsAndReplacesOnlyItsDrum() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Beat", kind: "drums", sound: nil),
            .drumPattern(track: "1", drum: "Snare", steps: "....X.......X...", bar: 1, bars: 2),
            .drumPattern(track: "1", drum: "hi-hat", steps: "x.x.", bar: 1, bars: 2),
            .drumPattern(track: "1", drum: "hihat", steps: "x...", bar: 1, bars: 2),
        ], on: store)
        let clip = try XCTUnwrap(store.project.tracks.first?.clips.first)
        XCTAssertEqual(clip.length, 2 * 3_840, "the clip grew to two bars")
        let snares = clip.notes.filter { $0.pitch == 38 }
        XCTAssertEqual(snares.map(\.start).sorted(), [960, 2_880, 4_800, 6_720])
        XCTAssertTrue(snares.allSatisfy { $0.velocity == StepEditing.accentVelocity })
        XCTAssertEqual(clip.notes.filter { $0.pitch == 42 }.count, 8, "the second hat pattern replaced the first")
    }

    func testNotesAreWrittenByNameBeatAndLength() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Keys", kind: "instrument", sound: "soft keys"),
            .writeNotes(track: "keys", notes: "C4+E4+G4 1 4, Bb3 3.5 0.5 90", bar: 2, bars: 1, replace: false),
        ], on: store)
        let track = try XCTUnwrap(store.project.tracks.first)
        XCTAssertEqual(track.instrument.preset, "Soft Keys")
        XCTAssertEqual(track.placements.map(\.start), [3_840], "bar 2")
        let notes = track.clips[0].notes.sorted { ($0.start, $0.pitch) < ($1.start, $1.pitch) }
        XCTAssertEqual(notes.map(\.pitch), [60, 64, 67, 58])
        XCTAssertEqual(notes.map(\.start), [0, 0, 0, 2_400])
        XCTAssertEqual(notes.map(\.length), [3_840, 3_840, 3_840, 480])
        XCTAssertEqual(notes.last?.velocity, 90)

        try run([.writeNotes(track: "Keys", notes: "D4 1 1", bar: 2, bars: 1, replace: true)], on: store)
        XCTAssertEqual(store.project.tracks[0].clips[0].notes.map(\.pitch), [62])
    }

    func testMistakesComeBackAsSentencesAndChangeNothing() throws {
        var project = Project()
        try Command.addTrack(id: TrackID(), name: "Bass", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "Bass 2", kind: .instrument, index: nil).apply(to: &project)
        func message(_ action: AgentAction) -> String {
            do {
                _ = try AgentTools.commands(for: action, in: project)
                return ""
            } catch {
                return String(describing: error)
            }
        }
        XCTAssertTrue(message(.removeTrack(track: "Lead")).contains("Bass, Bass 2"), "names the tracks there are")
        XCTAssertTrue(message(.removeTrack(track: "Ba")).contains("several"))
        XCTAssertEqual(try AgentTools.track("bass", in: project).name, "Bass", "an exact name wins over a prefix")
        XCTAssertTrue(message(.drumPattern(track: "Bass", drum: "kick", steps: "x", bar: 1, bars: 1)).contains("not a drum track"))
        XCTAssertTrue(message(.setTempo(bpm: .nan)).contains("BPM"))
        XCTAssertTrue(message(.setSound(track: "Bass", sound: "Hyper Saw")).contains("Sub Bass"), "lists the sounds")
        XCTAssertTrue(message(.writeNotes(track: "Bass", notes: "H2 1 1", bar: 1, bars: 1, replace: false)).contains("not a note"))
        XCTAssertTrue(message(.writeNotes(track: "Bass", notes: "C2 5 1", bar: 1, bars: 1, replace: false)).contains("after the end"))
        XCTAssertTrue(message(.mix(track: "master", volumeDB: nil, pan: nil, mute: true, solo: nil)).contains("master"))
        XCTAssertTrue(message(.mix(track: "Bass", volumeDB: nil, pan: 3, mute: nil, solo: nil)).contains("Pan"))
    }

    func testEffectsGoOnTheChainAndAClipRepeatsBackToBack() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Drums", kind: "drums", sound: nil),
            .addEffect(track: "Drums", effect: "comp"),
            .addEffect(track: "Drums", effect: "Reverb"),
            .repeatClip(track: "Drums", bar: 1, times: 3),
        ], on: store)
        let drums = try XCTUnwrap(store.project.tracks.first)
        XCTAssertEqual(drums.inserts.map { StandardEffect(component: $0.plugin) }, [.compressor, .reverb])
        XCTAssertEqual(drums.placements.map(\.start).sorted(), [0, 3_840, 7_680, 11_520])
        XCTAssertEqual(Set(drums.placements.map(\.clip)).count, 1, "the copies play the same clip")
        XCTAssertTrue(AgentTools.describe(store.project).contains("effects Compressor → Reverb"))

        try run([.removeEffect(track: "Drums", effect: "verb")], on: store)
        XCTAssertEqual(store.project.tracks[0].inserts.count, 1)
        XCTAssertThrowsError(try AgentTools.commands(for: .removeEffect(track: "Drums", effect: "delay"), in: store.project))
        XCTAssertThrowsError(try AgentTools.commands(for: .addEffect(track: "Drums", effect: "flanger"), in: store.project))
        XCTAssertThrowsError(try AgentTools.commands(for: .repeatClip(track: "Drums", bar: 9, times: 1), in: store.project))
    }

    func testAPatternOnPartOfALongerClipKeepsTheRestAndASharedClipIsNotStretched() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Drums", kind: "drums", sound: nil),
            .drumPattern(track: "Drums", drum: "kick", steps: "x...", bar: 1, bars: 4),
            .drumPattern(track: "Drums", drum: "kick", steps: "x.......", bar: 1, bars: 1),
        ], on: store)
        let kicks = try XCTUnwrap(store.project.tracks.first?.clips.first).notes.filter { $0.pitch == 36 }
        XCTAssertEqual(kicks.count, 2 + 12, "bar 1 rewritten, bars 2–4 kept")

        let sharing = ProjectStore()
        try run([.addTrack(name: "Beat", kind: "drums", sound: nil), .repeatClip(track: "Beat", bar: 1, times: 2)], on: sharing)
        let shared = sharing.project
        XCTAssertThrowsError(try AgentTools.commands(for: .drumPattern(track: "Beat", drum: "kick", steps: "x", bar: 1, bars: 2),
                                                     in: shared)) { error in
            XCTAssertTrue(String(describing: error).contains("plays elsewhere"))
        }
    }

    func testWildNumbersFromTheModelAreRefusedNotCrashing() throws {
        var project = Project()
        try Command.addTrack(id: TrackID(), name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertThrowsError(try AgentTools.commands(for: .writeNotes(track: "Keys", notes: "C4 1e300 1", bar: 1, bars: 1, replace: false), in: project))
        XCTAssertNoThrow(try AgentTools.commands(for: .writeNotes(track: "Keys", notes: "C4 1 1e300", bar: 1, bars: 1, replace: false), in: project),
                         "an endless note is cut at the end of the region")
        XCTAssertThrowsError(try AgentTools.commands(for: .writeNotes(track: "Keys", notes: "C4 1 1", bar: Int.max, bars: 1, replace: false), in: project))
        XCTAssertThrowsError(try AgentTools.commands(for: .repeatClip(track: "Keys", bar: Int.max, times: 1), in: project))
    }

    func testAMovementReplacesItsBarsOfTheLaneAndKeepsTheRest() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Bass", kind: "instrument", sound: "Sub Bass"),
            .automate(track: "Bass", parameter: "volume", fromBar: 1, toBar: 9, from: 0, to: 0, curve: 0),
            .automate(track: "Bass", parameter: "filter", fromBar: 5, toBar: 9, from: 300, to: 4_000, curve: 0.5),
            .automate(track: "Bass", parameter: "Volume", fromBar: 7, toBar: 9, from: 0, to: -144, curve: -0.5),
        ], on: store)
        let id = try XCTUnwrap(store.project.tracks.first?.id)
        let fade = try XCTUnwrap(store.project.automation(for: .volume(id))).points
        let ticks: [Tick] = fade.map(\.tick)
        let expected: [Tick] = [0, 6 * 3_840, 8 * 3_840]
        XCTAssertEqual(ticks, expected, "the first point stays, 7–9 is replaced")
        XCTAssertEqual(fade.last?.value, -144)
        let cutoff = try XCTUnwrap(store.project.automation(for: ParameterAddress(.track(id), SynthParameter.cutoff.key)))
        XCTAssertEqual(cutoff.value(at: 4 * 3_840), 300)
        XCTAssertEqual(cutoff.value(at: 8 * 3_840), 4_000)
        XCTAssertEqual(store.undoStack.count, 1)

        func message(_ action: AgentAction) -> String {
            do { _ = try AgentTools.commands(for: action, in: store.project); return "" } catch { return String(describing: error) }
        }
        XCTAssertTrue(message(.automate(track: "Bass", parameter: "pan", fromBar: 1, toBar: 2, from: 0, to: 2, curve: 0)).contains("-1"))
        XCTAssertTrue(message(.automate(track: "Bass", parameter: "wobble", fromBar: 1, toBar: 2, from: 0, to: 1, curve: 0)).contains("cutoff"))
        XCTAssertTrue(message(.automate(track: "Bass", parameter: "pan", fromBar: 3, toBar: 3, from: 0, to: 1, curve: 0)).contains("later"))
        XCTAssertNoThrow(try AgentTools.commands(for: .automate(track: "master", parameter: "volume", fromBar: 1, toBar: 2,
                                                                from: 0, to: -12, curve: 0), in: store.project))
    }

    func testNoteNamesAndDrumNames() {
        XCTAssertEqual(AgentTools.pitch("C4"), 60)
        XCTAssertEqual(AgentTools.pitch("a4"), 69)
        XCTAssertEqual(AgentTools.pitch("F#3"), 54)
        XCTAssertEqual(AgentTools.pitch("Bb2"), 46)
        XCTAssertEqual(AgentTools.pitch("C-1"), 0)
        XCTAssertNil(AgentTools.pitch("G10"))
        XCTAssertEqual(AgentTools.drumPitch("Open Hat"), 46)
        XCTAssertEqual(AgentTools.drumPitch("clap"), 39)
        XCTAssertNil(AgentTools.drumPitch("cowbell bell"))
    }

    func testTheDescriptionNamesEveryTrackByNumber() throws {
        let store = ProjectStore()
        try run([
            .addTrack(name: "Drums", kind: "drums", sound: nil),
            .addTrack(name: "Bass", kind: "instrument", sound: "Sub Bass"),
            .mix(track: "Bass", volumeDB: -6, pan: nil, mute: true, solo: nil),
        ], on: store)
        let text = AgentTools.describe(store.project)
        XCTAssertTrue(text.contains("120 BPM, 4/4"))
        XCTAssertTrue(text.contains("1. Drums, drums, clips at bar 1."))
        XCTAssertTrue(text.contains("2. Bass, synth, sound Sub Bass, muted, -6 dB."))
    }
}

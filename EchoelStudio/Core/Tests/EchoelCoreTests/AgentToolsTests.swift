import XCTest
@testable import EchoelCore

final class AgentToolsTests: XCTestCase {
    @MainActor private static func run(_ actions: [AgentAction], on store: ProjectStore) throws {
        for action in actions {
            let commands = try AgentTools.commands(for: action, in: store.project)
            try store.perform(commands, title: "Agent", coalescingKey: "agent.turn")
        }
        store.endGesture()
    }

    func testANewDrumTrackAt120WithFourOnTheFloorIsOneUndoStep() async throws {
        try await MainActor.run {
            let store = ProjectStore(project: Project(tempo: 90))
            try AgentToolsTests.run([
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
    }

    func testAPatternRepeatsOverItsBarsAndReplacesOnlyItsDrum() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
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
    }

    func testNotesAreWrittenByNameBeatAndLength() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
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

            try AgentToolsTests.run([.writeNotes(track: "Keys", notes: "D4 1 1", bar: 2, bars: 1, replace: true)], on: store)
            XCTAssertEqual(store.project.tracks[0].clips[0].notes.map(\.pitch), [62])
        }
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

    func testEffectsGoOnTheChainAndAClipRepeatsBackToBack() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
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

            try AgentToolsTests.run([.removeEffect(track: "Drums", effect: "verb")], on: store)
            XCTAssertEqual(store.project.tracks[0].inserts.count, 1)
            XCTAssertThrowsError(try AgentTools.commands(for: .removeEffect(track: "Drums", effect: "delay"), in: store.project))
            XCTAssertThrowsError(try AgentTools.commands(for: .addEffect(track: "Drums", effect: "vocoder"), in: store.project),
                                 "an effect Echoel does not have")
            XCTAssertThrowsError(try AgentTools.commands(for: .repeatClip(track: "Drums", bar: 9, times: 1), in: store.project))
        }
    }

    func testEveryEffectIsFoundByItsTitleAndACommonWord() throws {
        for effect in StandardEffect.allCases {
            XCTAssertEqual(try AgentTools.standardEffect(effect.title), effect, effect.title)
        }
        XCTAssertEqual(try AgentTools.standardEffect("lo-fi"), .bitcrusher)
        XCTAssertEqual(try AgentTools.standardEffect("ring mod"), .ringModulator)
        XCTAssertEqual(try AgentTools.standardEffect("Freq Shift"), .frequencyShifter)
        XCTAssertEqual(try AgentTools.standardEffect("Autotune"), .pitchCorrection)
        XCTAssertEqual(try AgentTools.standardEffect("harmony"), .harmonizer)
        XCTAssertEqual(try AgentTools.standardEffect("Echoel Grain"), .granular)
    }

    func testAPatternOnPartOfALongerClipKeepsTheRestAndASharedClipIsNotStretched() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
                .addTrack(name: "Drums", kind: "drums", sound: nil),
                .drumPattern(track: "Drums", drum: "kick", steps: "x...", bar: 1, bars: 4),
                .drumPattern(track: "Drums", drum: "kick", steps: "x.......", bar: 1, bars: 1),
            ], on: store)
            let kicks = try XCTUnwrap(store.project.tracks.first?.clips.first).notes.filter { $0.pitch == 36 }
            XCTAssertEqual(kicks.count, 2 + 12, "bar 1 rewritten, bars 2–4 kept")

            let sharing = ProjectStore()
            try AgentToolsTests.run([.addTrack(name: "Beat", kind: "drums", sound: nil), .repeatClip(track: "Beat", bar: 1, times: 2)], on: sharing)
            let shared = sharing.project
            XCTAssertThrowsError(try AgentTools.commands(for: .drumPattern(track: "Beat", drum: "kick", steps: "x", bar: 1, bars: 2),
                                                         in: shared)) { error in
                XCTAssertTrue(String(describing: error).contains("plays elsewhere"))
            }
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
        XCTAssertNil(AgentTools.pitch("C9223372036854775807"), "an octave past any key is no note")
        XCTAssertNil(AgentTools.pitch("C-9223372036854775808"))
        XCTAssertEqual(AgentTools.pitch("B#-2"), 0, "an enharmonic spelling at the edge still names its key")
        XCTAssertThrowsError(try AgentTools.track("-9223372036854775808", in: project), "a track number below one is no track")
        XCTAssertThrowsError(try AgentTools.commands(for: .removeTrack(track: "0"), in: project))
    }

    func testAMovementReplacesItsBarsOfTheLaneAndKeepsTheRest() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
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

            // A local function does NOT inherit the enclosing closure's main-actor isolation
            // (Linux run #4, Swift 6.2.4, 2026-10-19: "main actor-isolated property 'project'
            // can not be referenced from a nonisolated context"); it is spelled out.
            @MainActor func message(_ action: AgentAction) -> String {
                do { _ = try AgentTools.commands(for: action, in: store.project); return "" } catch { return String(describing: error) }
            }
            XCTAssertTrue(message(.automate(track: "Bass", parameter: "pan", fromBar: 1, toBar: 2, from: 0, to: 2, curve: 0)).contains("-1"))
            XCTAssertTrue(message(.automate(track: "Bass", parameter: "wobble", fromBar: 1, toBar: 2, from: 0, to: 1, curve: 0)).contains("cutoff"))
            XCTAssertTrue(message(.automate(track: "Bass", parameter: "pan", fromBar: 3, toBar: 3, from: 0, to: 1, curve: 0)).contains("later"))
            XCTAssertNoThrow(try AgentTools.commands(for: .automate(track: "master", parameter: "volume", fromBar: 1, toBar: 2,
                                                                    from: 0, to: -12, curve: 0), in: store.project))
        }
    }

    /// A parameter is found among the rows of the device the track plays, the rows its lanes play
    /// and the Automate menu lists: the sampler's and the kit's too, not only the synth's.
    func testAParameterIsFoundAmongThePlayingDevicesRows() throws {
        var project = Project()
        let beat = TrackID(), loop = TrackID(), keys = TrackID()
        try Command.addTrack(id: beat, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: loop, name: "Loop", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentDevice(beat, .drums).apply(to: &project)
        try Command.setInstrumentDevice(loop, .sampler).apply(to: &project)
        XCTAssertEqual(try AgentTools.parameter("level", on: "Beat", in: project),
                       ParameterAddress(.track(beat), SynthParameter.drumsLevel.key))
        XCTAssertEqual(try AgentTools.parameter("Root Key", on: "Loop", in: project),
                       ParameterAddress(.track(loop), SynthParameter.samplerRoot.key))
        XCTAssertEqual(try AgentTools.parameter("level", on: "Loop", in: project),
                       ParameterAddress(.track(loop), SynthParameter.samplerLevel.key))
        XCTAssertEqual(try AgentTools.parameter("filter", on: "Keys", in: project),
                       ParameterAddress(.track(keys), SynthParameter.cutoff.key))
        XCTAssertThrowsError(try AgentTools.parameter("cutoff", on: "Loop", in: project)) { error in
            XCTAssertTrue(String(describing: error).contains("root key"), "the refusal names the sampler's rows")
        }
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

    func testTheDescriptionNamesEveryTrackByNumber() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
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

    func testTheDescriptionGivesTheTempoToTheHundredth() throws {
        var project = Project(name: "Jam")
        try Command.setTempo(bpm: 100.25).apply(to: &project)
        XCTAssertTrue(AgentTools.describe(project).contains("100.25 BPM"), "not 100.2")
        try Command.setTempo(bpm: 100.5).apply(to: &project)
        XCTAssertTrue(AgentTools.describe(project).contains("100.5 BPM"))
    }

    /// The description goes into the on-device model's small window on every request; a clip
    /// repeated over a long song must not list every bar, or the song alone outgrows the window
    /// (audit 2026-10-23).
    func testARepeatedClipIsOneRangeAndALongSongStaysShort() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            for index in 1...8 {
                try AgentToolsTests.run([
                    .addTrack(name: "Drums \(index)", kind: "drums", sound: nil),
                    .repeatClip(track: "\(index)", bar: 1, times: 64),
                ], on: store)
            }
            let text = AgentTools.describe(store.project)
            XCTAssertTrue(text.contains("1. Drums 1, drums, clips at bars 1–65 (one 1-bar clip, 65 times)."), text)
            XCTAssertFalse(text.contains("bar 2,"), "a run back to back is one range, not 65 bars")
            XCTAssertLessThan(text.count, 1_500, "eight tracks of 65 bars each fit the model's window")

            // Different clips side by side, and a gap, stay separate ranges.
            let first = try XCTUnwrap(store.project.tracks.first)
            let second = Clip(name: "Fill", length: 3_840)
            try store.perform([.createClip(track: first.id, id: second.id, name: second.name, length: second.length),
                               .placeClip(track: first.id, id: PlacementID(), clip: second.id, start: 3_840 * 70)],
                              title: "Fill")
            XCTAssertTrue(AgentTools.describe(store.project).contains("clips at bars 1–65 (one 1-bar clip, 65 times), bar 71."))
        }
    }

    /// A repeated clip that is not whole bars is named in beats: the 4/4 bars of a song switched
    /// to 3/4 are four beats each, and 65 of them run to bar 87 (review 2026-10-23).
    func testARepeatedClipThatIsNotWholeBarsIsNamedInBeats() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try AgentToolsTests.run([
                .addTrack(name: "Drums", kind: "drums", sound: nil),
                .repeatClip(track: "1", bar: 1, times: 64),
            ], on: store)
            try store.perform([.setTimeSignature(TimeSignature(3, 4))], title: "3/4")
            let text = AgentTools.describe(store.project)
            XCTAssertTrue(text.contains("clips at bars 1–87 (one 4-beat clip, 65 times)."), text)
        }
    }
}

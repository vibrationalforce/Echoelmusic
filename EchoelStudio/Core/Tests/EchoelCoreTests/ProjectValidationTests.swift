import XCTest
@testable import EchoelCore

/// The reader's rules and the commands' rules are one set (ultra-audit B4/B9). A state the
/// commands reach and the reader refuses would be a song the app saves and never opens again;
/// a state the reader takes and the commands could never make is a door for damaged files.
final class ProjectValidationTests: XCTestCase {
    /// A small deterministic generator, so a failure names a step that reproduces.
    private struct Walk {
        var state: UInt64
        mutating func next(_ count: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(Swift.max(count, 1)))
        }
        mutating func pick<T>(_ items: [T]) -> T? { items.isEmpty ? nil : items[next(items.count)] }
        mutating func chance(_ percent: Int) -> Bool { next(100) < percent }
    }

    private let names = ["Keys", "  Lead ", "Bass", "", "   ", String(repeating: "x", count: 129)]
    private let loop = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)

    /// One command drawn from the song as it stands, mostly aimed at what exists so most of them
    /// change something, and sometimes at what does not, so the refusals are walked too.
    private func command(_ walk: inout Walk, _ project: Project) -> Command {
        let tracks = project.tracks
        let track = walk.pick(tracks)?.id ?? TrackID()
        let clips = tracks.flatMap { t in t.clips.map { (t.id, $0) } }
        let clip = walk.pick(clips)
        let clipID = clip?.1.id ?? ClipID()
        let scene = walk.pick(project.scenes)?.id ?? SceneID()
        let media = walk.pick(project.media)?.id ?? loop.id
        let tick = Tick(walk.next(16)) * 480 - (walk.chance(5) ? 960 : 0)
        let name = walk.pick(names) ?? "Name"
        switch walk.next(34) {
        case 0: return .addTrack(id: TrackID(), name: name, kind: .instrument, index: walk.chance(30) ? walk.next(tracks.count + 2) : nil)
        case 1: return .addTrack(id: TrackID(), name: name, kind: .audio, index: nil)
        case 2: return .addTrack(id: walk.chance(10) ? track : TrackID(), name: name, kind: .returnTrack, index: nil)
        case 3: return .removeTrack(track)
        case 4: return .renameTrack(track, name: name)
        case 5: return .moveTrack(track, toIndex: walk.next(tracks.count + 1))
        case 6: return .createClip(track: track, id: walk.chance(10) ? clipID : ClipID(), name: name, length: Tick(walk.next(5)) * 960)
        case 7:
            return .createAudioClip(track: track, id: ClipID(), name: name, length: 3_840,
                                    audio: ClipAudio(media: media, offset: walk.next(2) * 1_000, length: 1 + walk.next(96_000)))
        case 8: return .deleteClip(clipID)
        case 9: return .renameClip(clipID, name: name)
        case 10: return .setClipLength(clipID, length: Tick(walk.next(6)) * 480)
        case 11:
            let reuse = clip?.1.notes.first?.id
            let note = Note(id: walk.chance(15) ? (reuse ?? NoteID()) : NoteID(), pitch: walk.next(140), start: tick, length: 1 + Tick(walk.next(960)))
            return .addNotes(clipID, [note])
        case 12:
            guard var note = clip?.1.notes.first else { return .addNotes(clipID, []) }
            note.pitch = walk.next(128)
            note.start = tick
            return .updateNotes(clipID, [note])
        case 13: return .removeNotes(clipID, clip?.1.notes.prefix(1).map(\.id) ?? [NoteID()])
        case 14:
            return .setControls(clipID, [ControlChange(kind: walk.chance(50) ? .pitchBend : .controller(number: walk.next(130)),
                                                       start: tick, value: walk.next(17_000))])
        case 15: return .placeClip(track: track, id: walk.chance(10) ? (tracks.first?.placements.first?.id ?? PlacementID()) : PlacementID(),
                                   clip: clipID, start: tick)
        case 16:
            let owner = walk.pick(tracks.filter { !$0.placements.isEmpty })
            return .movePlacement(track: owner?.id ?? track, owner?.placements.first?.id ?? PlacementID(), start: tick)
        case 17:
            let owner = walk.pick(tracks.filter { !$0.placements.isEmpty })
            return .removePlacement(track: owner?.id ?? track, owner?.placements.first?.id ?? PlacementID())
        case 18:
            let id = walk.chance(20) ? media : MediaID()
            return .addMedia(MediaFile(id: id, name: walk.chance(10) ? "" : "Take", path: walk.chance(5) ? "../x.wav" : "Media/take.wav",
                                       frameCount: 48_000, sampleRate: 48_000))
        case 19: return .removeMedia(media)
        case 20: return .placeAudio(track: track, id: RegionID(), media: media, start: tick)
        case 21:
            let owner = walk.pick(tracks.filter { !$0.regions.isEmpty })
            let region = owner?.regions.first?.id ?? RegionID()
            switch walk.next(3) {
            case 0: return .moveRegion(track: owner?.id ?? track, region, start: tick)
            case 1: return .trimRegion(track: owner?.id ?? track, region, offset: walk.next(50_000), length: 1 + walk.next(60_000))
            default: return .removeRegion(track: owner?.id ?? track, region)
            }
        case 22: return .addScene(id: walk.chance(10) ? scene : SceneID(), name: name, index: nil)
        case 23: return walk.chance(50) ? .removeScene(scene) : .renameScene(scene, name: name)
        case 24: return .setSlot(track: track, scene: scene, clip: walk.chance(20) ? nil : clipID)
        case 25: return .setSend(track: track, to: walk.pick(tracks)?.id ?? track, db: walk.chance(20) ? nil : Double(walk.next(12)) - 9)
        case 26:
            switch walk.next(4) {
            case 0: return .setMute(track, walk.chance(50))
            case 1: return .setSolo(track, walk.chance(50))
            case 2: return .setVolume(walk.chance(20) ? .master : .track(track), db: Double(walk.next(20)) - 14)
            default: return .setPan(.track(track), pan: Double(walk.next(5)) / 2 - 1)
            }
        case 27: return .setInstrumentDevice(track, walk.pick([InstrumentDevice.synth, .drums, .sampler, .plugin]) ?? .synth)
        case 28: return .setInstrumentSample(track, walk.chance(30) ? nil : media)
        case 29: return .setInstrumentPlugin(track, walk.chance(30) ? nil : OwnPlugin.synth.component)
        case 30:
            let effect = walk.pick(StandardEffect.allCases)?.component ?? OwnPlugin.effects.component
            return walk.chance(80) ? .addInsert(track: track, id: InsertID(), plugin: effect, index: nil)
                                   : .addMasterInsert(id: InsertID(), plugin: effect, index: nil)
        case 31:
            let points = [AutomationPoint(tick: 0, value: -6), AutomationPoint(tick: 1_920, value: Double(walk.next(10)) - 8)]
            return .setAutomation(ParameterAddress(.track(track), .volume), points: walk.chance(20) ? [] : points)
        case 32:
            return .mapMIDI(MIDIControl(channel: UInt8(walk.next(16)), number: UInt8(walk.next(128))),
                            ParameterAddress(.track(track), .pan))
        default:
            switch walk.next(5) {
            case 0: return .setTempoChange(at: 960 * Tick(1 + walk.next(8)), bpm: Double(60 + walk.next(120)))
            case 1: return .setKeyRoot(walk.next(13))
            case 2: return .setScale(walk.pick(Scale.allCases) ?? .major)
            case 3: return .setMonitor(track, walk.chance(50) ? .off : .auto)
            default: return .renameProject(name: name)
            }
        }
    }

    func testEveryStateTheCommandsReachPassesTheReader() throws {
        var walk = Walk(state: 0x5EED_EC40)
        var project = Project()
        try Command.addMedia(loop).apply(to: &project)
        var applied = 0
        for step in 0..<3_000 {
            let next = command(&walk, project)
            var draft = project
            do {
                try next.apply(to: &draft)
            } catch {
                XCTAssertEqual(draft, project, "step \(step): a refused \(next) left the song changed")
                continue
            }
            project = draft
            applied += 1
            do {
                try project.validate()
            } catch {
                return XCTFail("step \(step): \(next) made a song the reader refuses: \(error)")
            }
        }
        XCTAssertGreaterThan(applied, 300, "the walk makes real changes, not only refusals")
        XCTAssertGreaterThan(project.tracks.count, 2, "and ends with a song to check")
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
    }

    // MARK: - Each rule refuses what breaks it

    private struct Song {
        var project: Project
        var keys: TrackID, audio: TrackID, room: TrackID
        var clip: ClipID, scene: SceneID
    }

    /// One of each kind of track, a clip in the session, a region: a song every rule passes.
    private func song() throws -> Song {
        var p = Project(name: "Song")
        let keys = TrackID(), audio = TrackID(), room = TrackID(), clip = ClipID(), scene = SceneID()
        let commands: [Command] = [
            .addTrack(id: keys, name: "Keys", kind: .instrument, index: nil),
            .addTrack(id: audio, name: "Vox", kind: .audio, index: nil),
            .addTrack(id: room, name: "Room", kind: .returnTrack, index: nil),
            .addMedia(loop),
            .placeAudio(track: audio, id: RegionID(), media: loop.id, start: 0),
            .createClip(track: keys, id: clip, name: "Verse", length: 3_840),
            .addNotes(clip, [Note(pitch: 60, start: 0, length: 480)]),
            .placeClip(track: keys, id: PlacementID(), clip: clip, start: 0),
            .addScene(id: scene, name: "A", index: nil),
            .setSlot(track: keys, scene: scene, clip: clip),
        ]
        for edit in commands { try edit.apply(to: &p) }
        try p.validate()
        return Song(project: p, keys: keys, audio: audio, room: room, clip: clip, scene: scene)
    }

    private func refuses(_ change: (inout Song) -> Void, _ message: String, line: UInt = #line) throws {
        var s = try song()
        change(&s)
        XCTAssertThrowsError(try s.project.validate(), message, line: line)
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(s.project)), "and the reader refuses the file", line: line)
    }

    private func index(_ track: TrackID, _ s: Song) -> Int { s.project.tracks.firstIndex { $0.id == track } ?? 0 }

    func testScenesAreUniqueAndNamed() throws {
        try refuses({ s in s.project.scenes.append(Scene(id: s.scene, name: "B")) }, "two scenes with one id")
        try refuses({ s in s.project.scenes[0].name = "  " }, "a scene without a name")
    }

    func testASlotHoldsItsOwnTracksClipInAnExistingSceneOncePerScene() throws {
        try refuses({ s in
            let k = self.index(s.keys, s)
            s.project.tracks[k].slots = [SlotAssignment(scene: SceneID(), clip: s.clip)]
        }, "a slot in a scene that does not exist")
        try refuses({ s in
            let k = self.index(s.keys, s)
            s.project.tracks[k].slots = [SlotAssignment(scene: s.scene, clip: ClipID())]
        }, "a slot holding no clip of this track")
        try refuses({ s in
            let k = self.index(s.keys, s)
            s.project.tracks[k].slots.append(SlotAssignment(scene: s.scene, clip: s.clip))
        }, "two clips in one scene")
    }

    func testIdsAreUniqueWhereTheCommandsKeepThemUnique() throws {
        try refuses({ s in s.project.media.append(MediaFile(id: s.project.media[0].id, name: "Again", path: "Media/again.wav",
                                                            frameCount: 10, sampleRate: 48_000)) }, "two files with one id")
        try refuses({ s in
            let k = self.index(s.keys, s)
            s.project.tracks[k].clips[0].notes.append(s.project.tracks[k].clips[0].notes[0])
        }, "two notes with one id in a clip")
        try refuses({ s in
            let k = self.index(s.keys, s)
            s.project.tracks[k].placements.append(s.project.tracks[k].placements[0])
        }, "two placements with one id on a track")

        // Only as unique as the commands keep them: one note id in two clips is a song the
        // commands can make, so it opens.
        var s = try song()
        let k = index(s.keys, s)
        var copy = s.project.tracks[k].clips[0]
        copy.id = ClipID()
        s.project.tracks[k].clips.append(copy)
        XCTAssertNoThrow(try s.project.validate())
    }

    func testATrackHoldsWhatItsKindHolds() throws {
        try refuses({ s in
            let a = self.index(s.audio, s), k = self.index(s.keys, s)
            s.project.tracks[k].regions = s.project.tracks[a].regions
            s.project.tracks[a].regions = []
        }, "audio regions on an instrument track")
        try refuses({ s in
            let a = self.index(s.audio, s), k = self.index(s.keys, s)
            var midi = s.project.tracks[k].clips[0]
            midi.id = ClipID()
            s.project.tracks[a].clips.append(midi)
        }, "a MIDI clip on an audio track")
        try refuses({ s in
            let r = self.index(s.room, s), k = self.index(s.keys, s)
            var midi = s.project.tracks[k].clips[0]
            midi.id = ClipID()
            s.project.tracks[r].clips.append(midi)
        }, "a clip on a return track")
    }

    /// G-A M10–M12 and the limit, on a whole song: a route on nothing, a repeated id, a depth past
    /// ±1 and a 65th route each refuse the file; one good route on the keys' volume opens.
    func testARouteMovesAParameterOfTheSongWithinItsLimits() throws {
        var s = try song()
        let route = ModulationRoute(source: .heartRate, target: .volume(s.keys), depth: 0.5)
        s.project.modRoutes = [route]
        XCTAssertNoThrow(try s.project.validate())
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(s.project)).modRoutes, [route])
        try refuses({ s in s.project.modRoutes = [ModulationRoute(source: .hrv, target: .volume(TrackID()), depth: 0.2)] },
                    "a route on a track that is not in the song")
        try refuses({ s in s.project.modRoutes = [route, route] }, "two routes with one id")
        try refuses({ s in s.project.modRoutes = [ModulationRoute(source: .breath, target: .masterPan, depth: 1.01)] },
                    "a depth past 1")
        try refuses({ s in s.project.modRoutes = [ModulationRoute(source: .breath, target: .masterPan, depth: .nan)] },
                    "a depth that is not a number")
        try refuses({ s in
            s.project.modRoutes = (0...Modulation.routeLimit).map { (_: Int) -> ModulationRoute in
                ModulationRoute(source: .macro1, target: .masterPan, depth: 0.1, enabled: false)
            }
        }, "one route past the limit, disabled ones counted")
    }

    func testEveryNameIsNonEmptyAndWithinTwiceTheEditorsLimit() throws {
        try refuses({ s in s.project.name = "" }, "a song without a name")
        try refuses({ s in s.project.tracks[0].name = " \n" }, "a track without a name")
        try refuses({ s in s.project.tracks[0].clips[0].name = "" }, "a clip without a name")
        try refuses({ s in s.project.media[0].name = "" }, "a file without a name")
        try refuses({ s in s.project.tracks[0].name = String(repeating: "x", count: 2 * Names.maximumLength + 1) },
                    "a name past twice the limit")
        var s = try song()
        s.project.tracks[0].name = String(repeating: "x", count: Names.maximumLength + 1)
        XCTAssertNoThrow(try s.project.validate(), "a name just past the editor's limit still opens")
    }
}

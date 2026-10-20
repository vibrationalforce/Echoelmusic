import XCTest
@testable import EchoelCore

final class ProjectCodecTests: XCTestCase {
    private func sampleProject() throws -> Project {
        var project = Project(name: "Demo")
        let track = TrackID(), clip = ClipID(), scene = SceneID()
        let commands: [Command] = [
            .setTempo(bpm: 128),
            .setTimeSignature(TimeSignature(6, 8)),
            .addTrack(id: track, name: "Lead", kind: .instrument, index: nil),
            .addTrack(id: TrackID(), name: "Verb", kind: .returnTrack, index: nil),
            .createClip(track: track, id: clip, name: "Hook", length: 2_880),
            .addNotes(clip, [Note(pitch: 64, velocity: 90, start: 0, length: 480)]),
            .placeClip(track: track, id: PlacementID(), clip: clip, start: 2_880),
            .addScene(id: scene, name: "A", index: nil),
            .setSlot(track: track, scene: scene, clip: clip),
            .setVolume(.track(track), db: -4.5),
        ]
        for command in commands { try command.apply(to: &project) }
        return project
    }

    func testAProjectSurvivesARoundTrip() throws {
        let project = try sampleProject()
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(project))
        XCTAssertEqual(decoded, project)
    }

    func testTheSameProjectAlwaysProducesTheSameBytes() throws {
        let project = try sampleProject()
        XCTAssertEqual(try ProjectCodec.encode(project), try ProjectCodec.encode(project))
    }

    func testAFileFromANewerVersionIsRefused() throws {
        XCTAssertThrowsError(try ProjectCodec.decode(withFormatNumber(99))) {
            XCTAssertEqual($0 as? ProjectCodec.DecodeError, .newerFormat(found: 99, supported: Project.currentFormatVersion))
        }
    }

    /// No build ever wrote a format below 1, so such a file is damaged, not old.
    func testAFormatNumberBelowOneIsRefused() throws {
        for number in [0, -1] {
            XCTAssertThrowsError(try ProjectCodec.decode(withFormatNumber(number))) {
                XCTAssertEqual($0 as? ProjectCodec.DecodeError, .invalidFormatVersion(number))
            }
        }
    }

    /// A saved empty song whose format number is replaced by `number`.
    private func withFormatNumber(_ number: Int) throws -> Data {
        let today = "\"formatVersion\" : \(Project.currentFormatVersion)"
        let json = try XCTUnwrap(String(data: ProjectCodec.encode(Project()), encoding: .utf8))
        XCTAssertTrue(json.contains(today), "the encoder's spacing changed; the replacement would not land")
        return Data(json.replacingOccurrences(of: today, with: "\"formatVersion\" : \(number)").utf8)
    }

    func testAFileWithoutAVersionIsRefused() {
        XCTAssertThrowsError(try ProjectCodec.decode(Data("{}".utf8))) {
            XCTAssertEqual($0 as? ProjectCodec.DecodeError, .missingFormatVersion)
        }
    }

    /// A file edited by hand or damaged on disk must not reach the engine: a denominator of 0
    /// or a tempo of 0 would stop the render thread, a pitch of 300 the playback plan.
    func testAFileThatBreaksTheRulesIsRefused() throws {
        let valid = try sampleProject()
        var broken: [Project] = []
        var signature = valid
        signature.timeSignature = TimeSignature(4, 0)
        broken.append(signature)
        var tempo = valid
        tempo.tempo = 0
        broken.append(tempo)
        var pitch = valid
        pitch.tracks[0].clips[0].notes[0].pitch = 300
        broken.append(pitch)
        var pan = valid
        pan.tracks[0].mixer.pan = 5
        broken.append(pan)
        var escape = valid
        escape.media = [MediaFile(name: "x", path: "../../etc/passwd", frameCount: 1, sampleRate: 48_000)]
        broken.append(escape)
        var notAnEffect = valid
        notAnEffect.tracks[0].inserts = [Insert(plugin: PluginComponent(type: PluginComponent.code("aumu"), subtype: 1,
                                                                         manufacturer: 1, name: "Synth", manufacturerName: "X"))]
        broken.append(notAnEffect)
        for project in broken {
            let data = try ProjectCodec.encode(project)
            XCTAssertThrowsError(try ProjectCodec.decode(data)) { error in
                guard case .invalidContent = error as? ProjectCodec.DecodeError else { return XCTFail("\(error)") }
            }
        }
    }

    func testCommandsThemselvesAreCodable() throws {
        let command = Command.addNotes(ClipID(), [Note(pitch: 60, start: 0, length: 240)])
        let data = try JSONEncoder().encode(command)
        XCTAssertEqual(try JSONDecoder().decode(Command.self, from: data), command)
    }
}

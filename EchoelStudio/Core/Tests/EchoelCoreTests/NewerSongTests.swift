import Foundation
import XCTest
@testable import EchoelCore

/// Reading a song a newer build saved (FWD, 2026-11-05; `docs/FORMAT.md`, "Reading newer songs"):
/// what can be left out of the playback opens and is kept, byte for byte; what cannot refuses the
/// song with the name that is missing; and no command can make or reach a kept part.
final class NewerSongTests: XCTestCase {
    private let future = FormatGoldenTests.formatFourFromTheFuture
    private let keys = TrackID(UUID(uuidString: "7A000000-0000-4000-8000-0000000000F1") ?? UUID())
    private let unknownRoute = UUID(uuidString: "40D00000-0000-4000-8000-0000000000F2") ?? UUID()
    private let keptInsert = InsertID(UUID(uuidString: "1F500000-0000-4000-8000-000000000003") ?? UUID())

    private static func json(_ data: Data) throws -> [String: StoredJSON] {
        guard case .object(let root) = try JSONDecoder().decode(StoredJSON.self, from: data) else {
            throw CommandError.invalidValue(parameter: "test", reason: "not an object")
        }
        return root
    }

    /// The bytes the codec's encoder writes for one stored value.
    private static func bytes(_ value: StoredJSON?) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value ?? .null)
    }

    private static func trackInserts(_ root: [String: StoredJSON]) -> StoredJSON? {
        guard case .array(let tracks)? = root["tracks"], case .object(let first)? = tracks.first else { return nil }
        return first["inserts"]
    }

    func testASongFromTheFutureOpensAndSaysWhatItKeeps() throws {
        let project = try ProjectCodec.decode(future)
        XCTAssertEqual(project.keptFromNewerBuild, 5)
        XCTAssertEqual(project.keptRouteCount, 3)
        XCTAssertEqual(project.keptMasterInsertCount, 1)
        XCTAssertEqual(project.tracks.first?.keptInsertCount, 1)
        XCTAssertEqual(project.newerBuildNotice,
                       "This song was saved by a newer Echoelmusic. 5 items are kept but inactive until you update.")
        XCTAssertNil(Project().newerBuildNotice, "a song with nothing kept says nothing")
    }

    func testWhatIsKeptIsInactive() throws {
        let project = try ProjectCodec.decode(future)
        // Only the route this build knows moves anything; the kept ones are not among the routes.
        XCTAssertEqual(project.modRoutes.map(\.source), [.heartRate])
        XCTAssertFalse(project.modRoutes.contains { $0.id == unknownRoute })
        // The kept inserts are not on any chain the engine plays: the master keeps its EQ only.
        XCTAssertEqual(project.masterInserts.map(\.plugin.name), ["Echoelmusic EQ"])
        XCTAssertEqual(project.tracks.first?.inserts, [])
    }

    func testSavingWritesTheKeptPartsBackByteForByte() throws {
        let saved = try ProjectCodec.encode(ProjectCodec.decode(future))
        let before = try Self.json(future), after = try Self.json(saved)
        XCTAssertEqual(try Self.bytes(after["modRoutes"]), try Self.bytes(before["modRoutes"]))
        XCTAssertEqual(try Self.bytes(after["masterInserts"]), try Self.bytes(before["masterInserts"]))
        XCTAssertEqual(try Self.bytes(Self.trackInserts(after)), try Self.bytes(Self.trackInserts(before)))
        // And again: the second save is the first, to the byte.
        XCTAssertEqual(try ProjectCodec.encode(ProjectCodec.decode(saved)), saved)
    }

    func testAKeptPartMovesOverWhenAnEditRemovesTheRoutesBeforeIt() throws {
        var project = try ProjectCodec.decode(future)
        project.modRoutes = []
        let root = try Self.json(ProjectCodec.encode(project))
        guard case .array(let routes)? = root["modRoutes"] else { return XCTFail("no routes") }
        XCTAssertEqual(routes.count, 3, "every kept route is still written")
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)).keptRouteCount, 3)
    }

    func testANameWithNoStandInRefusesTheSongAndNamesWhatIsMissing() throws {
        let earliest = try XCTUnwrap(String(data: future, encoding: .utf8))
        let cases: [(String, String, String, String)] = [
            ("\"kind\": \"instrument\"", "\"kind\": \"hologram\"", "track kind", "hologram"),
            ("\"target\": \"master/mixer.pan\"", "\"target\": \"scene/mixer.pan\"", "parameter owner", "scene"),
        ]
        for (from, to, field, name) in cases {
            let later = earliest.replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(later, earliest, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(later.utf8))) { error in
                XCTAssertEqual(error as? ProjectCodec.DecodeError, .needsNewerBuild(field: field, name: name))
                XCTAssertEqual((error as? ProjectCodec.DecodeError)?.isFromNewerBuild, true)
                XCTAssertEqual((error as? ProjectCodec.DecodeError)?.missingName,
                               "It uses the \(field) “\(name)”, which this build does not know.")
            }
        }
    }

    func testAMediaKindAndAnEngineFromANewerBuildRefuseTheSong() throws {
        var project = Project(name: "Engines")
        project.media = [MediaFile(id: MediaID(), name: "Still", path: "Media/still.png", frameCount: 48_000, sampleRate: 48_000)]
        var track = Track(name: "Synth", kind: .instrument)
        track.instrument.values["synth.engine"] = 11
        project.tracks = [track]
        let text = try XCTUnwrap(String(data: ProjectCodec.encode(project), encoding: .utf8))
        XCTAssertThrowsError(try ProjectCodec.decode(Data(text.utf8))) { error in
            XCTAssertEqual(error as? ProjectCodec.DecodeError, .needsNewerBuild(field: "synth.engine", name: "11"))
        }
        let picture = text.replacingOccurrences(of: "\"name\" : \"Still\"", with: "\"kind\" : \"image\", \"name\" : \"Still\"")
            .replacingOccurrences(of: "\"name\": \"Still\"", with: "\"kind\": \"image\", \"name\": \"Still\"")
        XCTAssertNotEqual(picture, text, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(picture.utf8))) { error in
            XCTAssertEqual(error as? ProjectCodec.DecodeError, .needsNewerBuild(field: "media kind", name: "image"))
        }
    }

    func testTheDoorRefusesToReachOrShadowAKeptPart() async throws {
        let project = try ProjectCodec.decode(future)
        let keys = self.keys, unknownRoute = self.unknownRoute, keptInsert = self.keptInsert
        try await MainActor.run {
            let store = ProjectStore(project: project)
            // A kept route is not this build's to remove or to overwrite.
            XCTAssertThrowsError(try store.perform(.removeModRoute(unknownRoute)))
            let shadow = ModulationRoute(id: unknownRoute, source: .lfo1, target: .masterVolume, depth: 0.5)
            XCTAssertThrowsError(try store.perform(.setModRoute(shadow)))
            // A kept insert's id is taken, and its place on the chain too.
            let eq = StandardEffect.equalizer.component
            XCTAssertThrowsError(try store.perform(.addInsert(track: keys, id: keptInsert, plugin: eq, index: nil)))
            XCTAssertThrowsError(try store.perform(.removeInsert(track: keys, keptInsert)))
            for _ in 0..<7 { try store.perform(.addInsert(track: keys, id: InsertID(), plugin: eq, index: nil)) }
            XCTAssertThrowsError(try store.perform(.addInsert(track: keys, id: InsertID(), plugin: eq, index: nil)),
                                 "the kept insert holds the eighth place")
            XCTAssertEqual(store.project.keptFromNewerBuild, 5, "nothing the door refused reached the song")
            // What the door let through still opens.
            XCTAssertNoThrow(try ProjectCodec.decode(ProjectCodec.encode(store.project)))
        }
    }

    func testRemovingATrackTakesTheKeptRoutesOnItAndTheSongStillOpens() async throws {
        let project = try ProjectCodec.decode(future)
        let keys = self.keys
        try await MainActor.run {
            let store = ProjectStore(project: project)
            try store.perform(.removeTrack(keys))
            let reopened = try ProjectCodec.decode(ProjectCodec.encode(store.project))
            XCTAssertEqual(reopened.keptRouteCount, 2, "the route on the track's parameter went with it")
            XCTAssertEqual(reopened.keptFromNewerBuild, 3)
        }
    }

    func testAnInstrumentInAnInsertSlotIsStillDamage() throws {
        var project = Project(name: "Odd")
        project.masterInserts = [Insert(plugin: OwnPlugin.synth.component)]
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(project))) { error in
            guard case .invalidContent = error as? ProjectCodec.DecodeError else { return XCTFail("\(error)") }
        }
    }
}

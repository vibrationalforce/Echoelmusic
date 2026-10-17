import XCTest
@testable import EchoelCore

final class InsertTests: XCTestCase {
    private func effect(_ name: String) -> PluginComponent {
        PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code(String(name.prefix(4))),
                        manufacturer: PluginComponent.code("Acme"), name: name, manufacturerName: "Acme")
    }

    private func project() throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Bass", kind: .audio, index: nil).apply(to: &project)
        return (project, track)
    }

    func testEffectsAreAddedInOrderMovedBypassedAndRemoved() throws {
        var (p, track) = try project()
        let delay = InsertID(), verb = InsertID(), comp = InsertID()
        try Command.addInsert(track: track, id: delay, plugin: effect("Dely"), index: nil).apply(to: &p)
        try Command.addInsert(track: track, id: verb, plugin: effect("Verb"), index: nil).apply(to: &p)
        try Command.addInsert(track: track, id: comp, plugin: effect("Comp"), index: 0).apply(to: &p)
        XCTAssertEqual(p.track(track)?.inserts.map(\.id), [comp, delay, verb])

        try Command.moveInsert(track: track, comp, toIndex: 2).apply(to: &p)
        XCTAssertEqual(p.track(track)?.inserts.map(\.id), [delay, verb, comp])

        try Command.setInsertBypass(track: track, verb, true).apply(to: &p)
        XCTAssertEqual(p.track(track)?.inserts.map(\.isBypassed), [false, true, false])

        try Command.setInsertState(track: track, delay, Data([1, 2, 3])).apply(to: &p)
        XCTAssertEqual(p.track(track)?.inserts.first?.state, Data([1, 2, 3]))

        try Command.removeInsert(track: track, verb).apply(to: &p)
        XCTAssertEqual(p.track(track)?.inserts.map(\.id), [delay, comp])
    }

    func testTheDoorRefusesWhatAChainCannotHold() throws {
        var (p, track) = try project()
        let before = p
        let instrument = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                         manufacturer: PluginComponent.code("Acme"), name: "Mini", manufacturerName: "Acme")
        XCTAssertThrowsError(try Command.addInsert(track: track, id: InsertID(), plugin: instrument, index: nil).apply(to: &p))
        XCTAssertThrowsError(try Command.addInsert(track: track, id: InsertID(), plugin: effect("Dely"), index: 1).apply(to: &p))
        XCTAssertThrowsError(try Command.removeInsert(track: track, InsertID()).apply(to: &p))
        XCTAssertEqual(p, before)

        let id = InsertID()
        try Command.addInsert(track: track, id: id, plugin: effect("Dely"), index: nil).apply(to: &p)
        XCTAssertThrowsError(try Command.addInsert(track: track, id: id, plugin: effect("Dely"), index: nil).apply(to: &p))
        XCTAssertThrowsError(try Command.moveInsert(track: track, id, toIndex: 1).apply(to: &p))
        XCTAssertThrowsError(try Command.setInsertState(track: track, id, Data(count: PluginComponent.maximumStateBytes + 1)).apply(to: &p))
        for _ in 1..<Insert.maximumPerTrack {
            try Command.addInsert(track: track, id: InsertID(), plugin: effect("Dely"), index: nil).apply(to: &p)
        }
        XCTAssertThrowsError(try Command.addInsert(track: track, id: InsertID(), plugin: effect("Dely"), index: nil).apply(to: &p))
    }

    func testInsertsSurviveTheFileAndAnOlderFileHasNone() throws {
        var (p, track) = try project()
        try Command.addInsert(track: track, id: InsertID(), plugin: effect("Verb"), index: nil).apply(to: &p)
        try Command.setInsertBypass(track: track, p.track(track)?.inserts.first?.id ?? InsertID(), true).apply(to: &p)
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: data), p)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var tracks = try XCTUnwrap(object["tracks"] as? [[String: Any]])
        tracks[0]["inserts"] = nil
        object["tracks"] = tracks
        let older = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(older.track(track)?.inserts, [])
    }
}

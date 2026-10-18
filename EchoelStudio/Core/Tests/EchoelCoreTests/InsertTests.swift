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

    func testTheMasterChainAddsMovesBypassesStoresAndRemoves() throws {
        var (p, _) = try project()
        let limiter = InsertID(), eq = InsertID()
        try Command.addMasterInsert(id: limiter, plugin: effect("Limt"), index: nil).apply(to: &p)
        try Command.addMasterInsert(id: eq, plugin: effect("EQ"), index: 0).apply(to: &p)
        XCTAssertEqual(p.masterInserts.map(\.id), [eq, limiter])
        try Command.moveMasterInsert(eq, toIndex: 1).apply(to: &p)
        XCTAssertEqual(p.masterInserts.map(\.id), [limiter, eq])
        try Command.setMasterInsertBypass(eq, true).apply(to: &p)
        try Command.setMasterInsertState(limiter, Data([7])).apply(to: &p)
        XCTAssertEqual(p.masterInserts.map(\.isBypassed), [false, true])
        XCTAssertEqual(p.masterInserts.first?.state, Data([7]))
        try Command.removeMasterInsert(eq).apply(to: &p)
        XCTAssertEqual(p.masterInserts.map(\.id), [limiter])
        XCTAssertNoThrow(try p.validate())
    }

    func testAnInsertIdBelongsToOneChainOnly() throws {
        var (p, track) = try project()
        let id = InsertID()
        try Command.addInsert(track: track, id: id, plugin: effect("Dely"), index: nil).apply(to: &p)
        XCTAssertThrowsError(try Command.addMasterInsert(id: id, plugin: effect("Dely"), index: nil).apply(to: &p))
        let other = InsertID()
        try Command.addMasterInsert(id: other, plugin: effect("Limt"), index: nil).apply(to: &p)
        XCTAssertThrowsError(try Command.addInsert(track: track, id: other, plugin: effect("Limt"), index: nil).apply(to: &p))
        XCTAssertThrowsError(try Command.removeInsert(track: track, other).apply(to: &p), "a master insert is not the track's")
    }

    func testTheMasterDoorRefusesWhatTheChainCannotHold() throws {
        var (p, _) = try project()
        let instrument = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                         manufacturer: PluginComponent.code("Acme"), name: "Mini", manufacturerName: "Acme")
        XCTAssertThrowsError(try Command.addMasterInsert(id: InsertID(), plugin: instrument, index: nil).apply(to: &p))
        XCTAssertThrowsError(try Command.addMasterInsert(id: InsertID(), plugin: effect("Dely"), index: 1).apply(to: &p))
        XCTAssertThrowsError(try Command.removeMasterInsert(InsertID()).apply(to: &p))
        for _ in 0..<Insert.maximumPerTrack {
            try Command.addMasterInsert(id: InsertID(), plugin: effect("Dely"), index: nil).apply(to: &p)
        }
        XCTAssertThrowsError(try Command.addMasterInsert(id: InsertID(), plugin: effect("Dely"), index: nil).apply(to: &p))
        let id = try XCTUnwrap(p.masterInserts.first?.id)
        XCTAssertThrowsError(try Command.setMasterInsertState(id, Data(count: PluginComponent.maximumStateBytes + 1)).apply(to: &p))
    }

    func testRemovingAMasterEffectForgetsItsLanesAndMappings() throws {
        var (p, _) = try project()
        let id = InsertID()
        try Command.addMasterInsert(id: id, plugin: effect("Limt"), index: nil).apply(to: &p)
        let address = ParameterAddress(.master, .plugin(PluginParameter(.insert(id), address: 3)))
        XCTAssertEqual(p.descriptor(for: address)?.title, "Master Limt #3")
        try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: 0.5)]).apply(to: &p)
        XCTAssertEqual(p.automation.count, 1)
        try Command.removeMasterInsert(id).apply(to: &p)
        XCTAssertTrue(p.automation.isEmpty)
        XCTAssertNil(p.descriptor(for: address))
    }

    func testTheMasterChainSurvivesTheFileAndAnOlderFileHasNone() throws {
        var (p, _) = try project()
        try Command.addMasterInsert(id: InsertID(), plugin: effect("Limt"), index: nil).apply(to: &p)
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: data), p)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["masterInserts"] = nil
        let older = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(older.masterInserts.isEmpty)
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

import XCTest
@testable import EchoelCore

final class SendTests: XCTestCase {
    private func project() throws -> (Project, TrackID, TrackID) {
        var project = Project()
        let keys = TrackID(), verb = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        return (project, keys, verb)
    }

    func testASendIsSetChangedAndRemoved() throws {
        var (p, keys, verb) = try project()
        try Command.setSend(track: keys, to: verb, db: -6).apply(to: &p)
        XCTAssertEqual(p.track(keys)?.send(to: verb)?.levelDB, -6)
        try Command.setSend(track: keys, to: verb, db: -12).apply(to: &p)
        XCTAssertEqual(p.track(keys)?.sends.count, 1)
        XCTAssertEqual(p.track(keys)?.send(to: verb)?.levelDB, -12)
        try Command.setSend(track: keys, to: verb, db: nil).apply(to: &p)
        XCTAssertEqual(p.track(keys)?.sends, [])
    }

    func testSendsGoOnlyFromATrackIntoAReturn() throws {
        var (p, keys, verb) = try project()
        let other = TrackID()
        try Command.addTrack(id: other, name: "Bass", kind: .audio, index: nil).apply(to: &p)
        let before = p
        XCTAssertThrowsError(try Command.setSend(track: keys, to: other, db: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.setSend(track: verb, to: verb, db: 0).apply(to: &p))
        XCTAssertThrowsError(try Command.setSend(track: keys, to: verb, db: .infinity).apply(to: &p))
        XCTAssertThrowsError(try Command.setSend(track: keys, to: verb, db: 99).apply(to: &p))
        XCTAssertEqual(p, before)
    }

    func testRemovingAReturnRemovesTheSendsIntoIt() throws {
        var (p, keys, verb) = try project()
        try Command.setSend(track: keys, to: verb, db: -6).apply(to: &p)
        try Command.removeTrack(verb).apply(to: &p)
        XCTAssertEqual(p.track(keys)?.sends, [])
        XCTAssertNoThrow(try p.validate())
    }
}

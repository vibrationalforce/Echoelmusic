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

    func testASendIsAParameterLikeAFader() throws {
        var (p, keys, verb) = try project()
        let address = ParameterAddress.send(keys, to: verb)
        XCTAssertEqual(address.key.sendTarget, verb)
        XCTAssertEqual(p.value(of: address), MixerStrip.volumeRange.lowerBound, "no send yet reads as silence")
        XCTAssertTrue(p.parameters.contains { $0.address == address })
        let command = try XCTUnwrap(Command.setParameter(address, to: -9))
        try command.apply(to: &p)
        XCTAssertEqual(p.value(of: address), -9)
        XCTAssertEqual(p.descriptor(for: address)?.title, "Keys → Reverb")
        XCTAssertNil(p.value(of: .send(verb, to: verb)), "a return has no sends")
    }
}

final class TrackOutputTests: XCTestCase {
    func testATrackPlaysOnAnEvenPairAfterTheMasterOrBackInTheMaster() throws {
        var p = Project()
        let deck = TrackID()
        try Command.addTrack(id: deck, name: "Deck A", kind: .instrument, index: nil).apply(to: &p)
        try Command.setOutput(deck, channel: 2).apply(to: &p)
        XCTAssertEqual(p.track(deck)?.output, 2)
        for bad in [0, 1, 3, -2, Track.outputChannelLimit] {
            XCTAssertThrowsError(try Command.setOutput(deck, channel: bad).apply(to: &p), "\(bad)")
        }
        try Command.setOutput(deck, channel: nil).apply(to: &p)
        XCTAssertNil(p.track(deck)?.output)
    }

    func testAnAudioTrackRecordsFromTheInputItNames() throws {
        var p = Project()
        let vocal = TrackID(), keys = TrackID()
        try Command.addTrack(id: vocal, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        try Command.setInput(vocal, channel: 3).apply(to: &p)
        XCTAssertEqual(p.track(vocal)?.input, 3)
        let before = p
        for bad in [-1, Track.inputChannelLimit] {
            XCTAssertThrowsError(try Command.setInput(vocal, channel: bad).apply(to: &p), "\(bad)")
        }
        XCTAssertThrowsError(try Command.setInput(keys, channel: 0).apply(to: &p), "an instrument track does not record")
        XCTAssertEqual(p, before)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)).track(vocal)?.input, 3)
        try Command.setInput(vocal, channel: nil).apply(to: &p)
        XCTAssertNil(p.track(vocal)?.input)
    }

    func testAnAudioTrackChoosesWhenItHearsItsInput() throws {
        var p = Project()
        let vocal = TrackID(), keys = TrackID()
        try Command.addTrack(id: vocal, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        XCTAssertEqual(p.track(vocal)?.monitor, .auto, "a new track monitors while armed")
        try Command.setMonitor(vocal, .input).apply(to: &p)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)).track(vocal)?.monitor, .input)
        let before = p
        XCTAssertThrowsError(try Command.setMonitor(keys, .off).apply(to: &p), "an instrument track has no input")
        XCTAssertEqual(p, before)
        let index = try XCTUnwrap(p.tracks.firstIndex { $0.id == keys })
        p.tracks[index].monitor = .off
        XCTAssertThrowsError(try p.validate(), "and a document that says otherwise is refused")
        XCTAssertEqual(CommandCatalog.spec(for: .setMonitor).name, "track.monitor")
    }
}

import XCTest
@testable import EchoelCore

final class MIDIMappingTests: XCTestCase {
    func testAControlMapsReplacesAndForgets() throws {
        var p = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        let knob = MIDIControl(channel: 0, number: 21)
        try Command.mapMIDI(knob, .volume(track)).apply(to: &p)
        try Command.mapMIDI(knob, .pan(track)).apply(to: &p)
        XCTAssertEqual(p.midiMappings, [MIDIMapping(control: knob, target: .pan(track))])
        try Command.unmapMIDI(knob).apply(to: &p)
        XCTAssertEqual(p.midiMappings, [])
        XCTAssertThrowsError(try Command.unmapMIDI(knob).apply(to: &p))
    }

    func testTheDoorRefusesWhatCannotBeMapped() throws {
        var p = Project()
        XCTAssertThrowsError(try Command.mapMIDI(MIDIControl(channel: 16, number: 1), .masterVolume).apply(to: &p))
        XCTAssertThrowsError(try Command.mapMIDI(MIDIControl(channel: 0, number: 128), .masterVolume).apply(to: &p))
        XCTAssertThrowsError(try Command.mapMIDI(MIDIControl(channel: 0, number: 1), .volume(TrackID())).apply(to: &p))
        XCTAssertNoThrow(try Command.mapMIDI(MIDIControl(channel: 0, number: 1), .masterVolume).apply(to: &p))
    }

    func testDeletingATrackForgetsTheControlsThatMovedIt() throws {
        var p = Project()
        let keys = TrackID(), verb = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        try Command.addTrack(id: verb, name: "Verb", kind: .returnTrack, index: nil).apply(to: &p)
        try Command.mapMIDI(MIDIControl(channel: 0, number: 1), .send(keys, to: verb)).apply(to: &p)
        try Command.mapMIDI(MIDIControl(channel: 0, number: 2), .volume(keys)).apply(to: &p)
        try Command.mapMIDI(MIDIControl(channel: 0, number: 3), .masterVolume).apply(to: &p)
        try Command.removeTrack(verb).apply(to: &p)
        XCTAssertEqual(p.midiMappings.map(\.control.number), [2, 3])
        try Command.removeTrack(keys).apply(to: &p)
        XCTAssertEqual(p.midiMappings.map(\.control.number), [3])
    }
}

import Foundation
import XCTest
@testable import EchoelCore

/// A/B per device (PRO-W1 slice 4): two settings side by side, each switch one undo step.
final class DeviceComparisonTests: XCTestCase {
    private typealias Pair = DeviceComparison.Pair

    private func sound(_ cutoff: Double) -> DeviceComparison.Settings {
        .sound(preset: "Init", values: ["synth.cutoff": cutoff])
    }

    func testTheFirstSwitchCopiesWhatPlaysAndLaterSwitchesBringTheOtherSideBack() {
        var pair = Pair()
        XCTAssertEqual(pair.active, .a)
        XCTAssertNil(pair.toggle(current: sound(1_000)), "B starts as a copy of A")
        XCTAssertEqual(pair.active, .b)
        XCTAssertEqual(pair.b, sound(1_000))
        // The musician turns the cutoff on B, then goes back to A.
        XCTAssertEqual(pair.toggle(current: sound(4_000)), sound(1_000))
        XCTAssertEqual(pair.active, .a)
        XCTAssertEqual(pair.b, sound(4_000), "what B played is kept")
        XCTAssertEqual(pair.toggle(current: sound(1_000)), sound(4_000))
    }

    func testCopyingOntoThePlayingSideBringsItBack() {
        var pair = Pair()
        _ = pair.toggle(current: sound(1_000))                     // on B
        XCTAssertNil(pair.copy(.b, to: .a, current: sound(2_000)), "A is not playing")
        XCTAssertEqual(pair.a, sound(2_000))
        XCTAssertNil(pair.copy(.a, to: .b, current: sound(2_000)), "the same settings change nothing")
        _ = pair.toggle(current: sound(3_000))                     // B kept 3 000, now on A
        XCTAssertEqual(pair.copy(.b, to: .a, current: sound(2_000)), sound(3_000))
        XCTAssertNil(pair.copy(.a, to: .a, current: sound(2_000)))
    }

    func testABuiltInSoundIsRestoredThroughTheDoorAsOneUndoStep() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            try store.perform(.addTrack(id: track, name: "Lead", kind: .instrument, index: nil))
            try store.perform(.setInstrumentParameter(track, key: "synth.cutoff", value: 800))
            let device = DeviceComparison.Device.instrument(track)
            var pair = Pair()
            let a = try XCTUnwrap(DeviceComparison.current(device, in: store.project))
            XCTAssertNil(pair.toggle(current: a))
            try store.perform(.setInstrumentParameter(track, key: "synth.cutoff", value: 5_000))
            let b = try XCTUnwrap(DeviceComparison.current(device, in: store.project))
            let back = try XCTUnwrap(pair.toggle(current: b))
            let command = try XCTUnwrap(DeviceComparison.command(restoring: back, on: device, in: store.project))
            try store.perform(command)
            XCTAssertEqual(store.project.track(track)?.instrument.values["synth.cutoff"], 800)
            XCTAssertEqual(store.undoTitle, "Compare Sound")
            store.undo()
            XCTAssertEqual(store.project.track(track)?.instrument.values["synth.cutoff"], 5_000)
        }
    }

    func testAnEffectsSettingsComeBackAsItsInsertState() throws {
        var project = Project()
        let track = TrackID(), insert = InsertID(), master = InsertID()
        let effect = PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("xDly"),
                                     manufacturer: PluginComponent.code("Echl"), name: "Delay", manufacturerName: "Echoel")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addInsert(track: track, id: insert, plugin: effect, index: nil).apply(to: &project)
        try Command.addMasterInsert(id: master, plugin: effect, index: nil).apply(to: &project)
        XCTAssertNil(DeviceComparison.current(.insert(insert), in: project), "no settings stored yet")
        try Command.setInsertState(track: track, insert, Data([1])).apply(to: &project)
        XCTAssertEqual(DeviceComparison.current(.insert(insert), in: project), .state(Data([1])))
        XCTAssertEqual(DeviceComparison.command(restoring: .state(Data([2])), on: .insert(insert), in: project),
                       .setInsertState(track: track, insert, Data([2])))
        XCTAssertEqual(DeviceComparison.command(restoring: .state(Data([2])), on: .insert(master), in: project),
                       .setMasterInsertState(master, Data([2])))
        XCTAssertNil(DeviceComparison.command(restoring: sound(1), on: .insert(insert), in: project))
        XCTAssertNil(DeviceComparison.command(restoring: .state(Data([2])), on: .insert(InsertID()), in: project))
    }

    func testTheSoundCommandRefusesWhatAnInstrumentCannotHold() throws {
        var project = Project()
        let track = TrackID(), audio = TrackID()
        try Command.addTrack(id: track, name: "Lead", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: audio, name: "Vox", kind: .audio, index: nil).apply(to: &project)
        let before = project
        for command: Command in [
            .setInstrumentSound(audio, preset: "Init", values: [:]),
            .setInstrumentSound(track, preset: " ", values: [:]),
            .setInstrumentSound(track, preset: "Init", values: ["synth.cutoff": .nan]),
            .setInstrumentSound(track, preset: "Init", values: ["no.such.key": 1]),
        ] {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
            XCTAssertEqual(project, before)
        }
    }
}

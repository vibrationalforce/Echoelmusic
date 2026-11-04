import EchoelCore
import XCTest
@testable import EchoelEngine

/// Recovery 9: the phone's motion moves a song live, never its export — an offline render reads
/// no `ModulationInputs` (`.claude/skills/offline-export-freeze`), so a second export after the
/// phone moved is the same file, and a motion route adds nothing to it.
final class PhoneMotionExportTests: XCTestCase {
    private func song(withMotionRoutes: Bool) throws -> Project {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 960)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        guard withMotionRoutes else { return project }
        for route in [ModulationRoute(source: .motionEnergy, target: .volume(track), depth: -1),
                      ModulationRoute(source: .motionTiltX, target: .pan(track), depth: 1, polarity: .bipolar),
                      ModulationRoute(source: .motionRotation, target: ParameterAddress(.track(track), SynthParameter.cutoff.key),
                                      depth: 1, polarity: .bipolar)] {
            try Command.setModRoute(route).apply(to: &project)
        }
        return project
    }

    func testASecondExportIsTheSameWhateverThePhoneDid() throws {
        let project = try song(withMotionRoutes: true)
        let live = ModulationInputs()
        let first = OfflineRender.render(project, sampleRate: 48_000, tailSeconds: 0.5)
        for (source, value) in zip(PhoneMotion.sources, [1.0, 0.0, 1.0, 1.0]) { live.set(source, value) }
        let second = OfflineRender.render(project, sampleRate: 48_000, tailSeconds: 0.5)
        XCTAssertGreaterThan(first.peak, 0.01, "the song sounds")
        XCTAssertEqual(first.left, second.left)
        XCTAssertEqual(first.right, second.right)
        let unrouted = OfflineRender.render(try song(withMotionRoutes: false), sampleRate: 48_000, tailSeconds: 0.5)
        XCTAssertEqual(first.left, unrouted.left, "a motion route adds nothing to an export")
        XCTAssertEqual(first.right, unrouted.right)
    }

    /// Live, the same routes compile and follow the cells; offline (no inputs) none compiles.
    func testMotionRoutesCompileLiveAndNotOffline() throws {
        let project = try song(withMotionRoutes: true)
        let rate = 48_000.0
        func snapshot(_ inputs: ModulationInputs?) -> EngineSnapshot {
            var slots = SlotAssigner(capacity: EngineCore(sampleRate: rate).slotCapacity)
            slots.update(for: project)
            return EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                  sampleRate: rate, generation: 1, modulation: inputs)
        }
        let inputs = ModulationInputs()
        let lane = try XCTUnwrap(snapshot(inputs).lanes.first)
        let mix = try XCTUnwrap(lane.mix, "the motion routes move the track's gains live")
        XCTAssertFalse(lane.patchRoutes.isEmpty, "and the synth's cutoff")
        let still = mix.gains(at: 0)
        inputs.set(.motionEnergy, 1)
        let shaken = mix.gains(at: 0)
        XCTAssertLessThan(shaken.0 + shaken.1, still.0 + still.1, "movement turns the track down")
        let offline = try XCTUnwrap(snapshot(nil).lanes.first)
        XCTAssertNil(offline.mix)
        XCTAssertTrue(offline.patchRoutes.isEmpty)
    }

    /// Motion's provenance is the camera's: its values may be handed to MIDI out.
    func testMotionValuesAreShareableLikeTheCamera() {
        let inputs = ModulationInputs()
        inputs.set(.motionTiltY, 0.7, mayLeaveDevice: BioEgressPolicy.allowsEgress(.motion))
        XCTAssertEqual(inputs.value(.motionTiltY), 0.7)
        XCTAssertEqual(inputs.shareableValue(.motionTiltY), 0.7)
        XCTAssertNil(inputs.value(.motionTiltX), "one motion source does not fill another")
    }
}

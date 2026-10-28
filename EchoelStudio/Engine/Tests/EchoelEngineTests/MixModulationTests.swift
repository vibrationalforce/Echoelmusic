import EchoelCore
import XCTest
@testable import EchoelEngine

/// A route moves a track's or the master's fader and pan as a lane does (W2 E2/E3): exactly the
/// stored value while the source is absent, along the control's travel while it is measured,
/// and nothing in an offline render, which passes no inputs.
final class MixModulationTests: XCTestCase {
    private let rate = 48_000.0

    private func song(_ routes: (TrackID) -> [ModulationRoute]) throws -> (Project, TrackID) {
        var project = Project()
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        for route in routes(keys) { try Command.setModRoute(route).apply(to: &project) }
        return (project, keys)
    }

    private func snapshot(_ project: Project, inputs: ModulationInputs?) -> EngineSnapshot {
        var slots = SlotAssigner(capacity: EngineCore(sampleRate: rate).slotCapacity)
        slots.update(for: project)
        return EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                              sampleRate: rate, generation: 1, modulation: inputs)
    }

    func testAnAbsentSourceLeavesTheFaderWhereItIs() throws {
        let (project, _) = try song { [ModulationRoute(source: .heartRate, target: .volume($0), depth: -1)] }
        let lane = try XCTUnwrap(snapshot(project, inputs: ModulationInputs()).lanes.first)
        let mix = try XCTUnwrap(lane.mix, "a route moves the track's gains")
        let (left, right) = mix.gains(at: 0)
        XCTAssertEqual(left, lane.gainLeft, accuracy: 1e-6)
        XCTAssertEqual(right, lane.gainRight, accuracy: 1e-6)
    }

    func testAMeasuredSourceMovesTheFaderAlongItsTravel() throws {
        let (project, _) = try song { [ModulationRoute(source: .heartRate, target: .volume($0), depth: -1)] }
        let inputs = ModulationInputs()
        let lane = try XCTUnwrap(snapshot(project, inputs: inputs).lanes.first)
        let mix = try XCTUnwrap(lane.mix)
        inputs.set(.heartRate, 1)
        XCTAssertEqual(mix.gains(at: 0).0, 0, accuracy: 1e-6, "full depth down closes the fader")
        inputs.set(.heartRate, 0.5)
        let half = mix.gains(at: 0).0
        XCTAssertGreaterThan(half, 0)
        XCTAssertLessThan(half, lane.gainLeft, "half the source, part of the way down")
        inputs.set(.heartRate, nil)
        XCTAssertEqual(mix.gains(at: 0).0, lane.gainLeft, accuracy: 1e-6, "absent again, back where it was")
    }

    func testABipolarRouteSwingsThePanBothWays() throws {
        let (project, _) = try song { [ModulationRoute(source: .breath, target: .pan($0), depth: 0.5, polarity: .bipolar)] }
        let inputs = ModulationInputs()
        let mix = try XCTUnwrap(snapshot(project, inputs: inputs).lanes.first?.mix)
        inputs.set(.breath, 1)
        let (rightLeft, rightRight) = mix.gains(at: 0)
        XCTAssertGreaterThan(rightRight, rightLeft, "breath in pans right")
        inputs.set(.breath, 0)
        let (leftLeft, leftRight) = mix.gains(at: 0)
        XCTAssertGreaterThan(leftLeft, leftRight, "breath out pans left")
    }

    func testAMasterRouteMovesEveryTrackThroughTheMaster() throws {
        let (project, _) = try song { _ in [ModulationRoute(source: .coherence, target: .masterVolume, depth: -1)] }
        let inputs = ModulationInputs()
        let mix = try XCTUnwrap(snapshot(project, inputs: inputs).lanes.first?.mix, "the master's route moves the track too")
        inputs.set(.coherence, 1)
        XCTAssertEqual(mix.gains(at: 0).0, 0, accuracy: 1e-6)
    }

    /// An offline render never reads a live sensor: without inputs nothing moves.
    func testWithoutInputsNoRouteMovesAnything() throws {
        let (project, _) = try song { [ModulationRoute(source: .heartRate, target: .volume($0), depth: -1)] }
        XCTAssertNil(snapshot(project, inputs: nil).lanes.first?.mix)
    }

    /// A route on a synth value compiles to the lane's patch routes, with the row's index, and
    /// moves the value along the row's travel; the lane's automation, if any, is its base.
    func testARouteOnASynthValueBecomesAPatchRoute() throws {
        let cutoff = SynthParameter.cutoff.key
        var (project, keys) = try song { [ModulationRoute(source: .heartRate, target: ParameterAddress(.track($0), cutoff),
                                                          depth: 1)] }
        try Command.setAutomation(ParameterAddress(.track(keys), cutoff), points: [AutomationPoint(tick: 0, value: 400)])
            .apply(to: &project)
        let inputs = ModulationInputs()
        let built = snapshot(project, inputs: inputs)
        XCTAssertTrue(built.modulatesPatches)
        let lane = try XCTUnwrap(built.lanes.first)
        let route = try XCTUnwrap(lane.patchRoutes.first)
        XCTAssertEqual(route.index, InstrumentDevice.synth.parameters.firstIndex { $0.key == cutoff })
        XCTAssertNotNil(route.lane, "the automated cutoff is the route's base")
        XCTAssertEqual(route.routes.value(400), 400, accuracy: 1e-9, "no pulse, the lane's value")
        inputs.set(.heartRate, 1)
        XCTAssertGreaterThan(route.routes.value(400), 400, "the pulse opens the filter")
        XCTAssertNil(snapshot(project, inputs: nil).lanes.first?.patchRoutes.first, "an offline render compiles none")
    }

    func testADisabledRouteMovesNothing() throws {
        let (project, _) = try song { [ModulationRoute(source: .heartRate, target: .volume($0), depth: -1, enabled: false)] }
        XCTAssertNil(snapshot(project, inputs: ModulationInputs()).lanes.first?.mix)
    }
}

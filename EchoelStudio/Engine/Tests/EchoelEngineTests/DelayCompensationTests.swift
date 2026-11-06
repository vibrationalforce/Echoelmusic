import EchoelCore
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// An insert that passes its input through and reports a latency the test sets.
private final class LateInsert: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    var latency: Int
    var isBypassed = false
    var latencyFrames: Int { latency }

    init(latency: Int, sampleRate: Double = 48_000) {
        self.latency = latency
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {}
}

/// A plugin instrument that plays nothing and reports a latency.
private final class LateInstrument: HostedInstrument, @unchecked Sendable {
    let sampleRate: Double = 48_000
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    let latencyFrames: Int

    init(latency: Int) { latencyFrames = latency }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}
    func noteOn(pitch: UInt8, velocity: UInt8, offset: Int) {}
    func noteOff(pitch: UInt8, offset: Int) {}
    func control(status: UInt8, _ data1: UInt8, _ data2: UInt8, offset: Int) {}
    func allNotesOff(offset: Int) {}
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                gainLeft: Float, gainRight: Float) {}
}

/// Plugin delay compensation, slice 1: the plan of how long each lane waits (WS-PDC).
final class DelayCompensationTests: XCTestCase {
    private let rate = 48_000.0

    // MARK: - The plan

    func testWithoutLatencyNothingWaits() {
        let a = TrackID(), b = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: 0, buses: [0]), .init(track: b, latency: 0)],
                                     returns: [.init(track: verb, bus: 0, latency: 0)], master: 0)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.total, 0)
        XCTAssertEqual(plan.longestDelay, 0)
        XCTAssertEqual(plan.tracks.map(\.delay), [0, 0])
        XCTAssertEqual(plan.tracks.map(\.directDelay), [0, 0])
        XCTAssertEqual(plan.returns.map(\.delay), [0])
        XCTAssertEqual(DelayCompensation.none.total, 0)
    }

    func testOneLateTrackDelaysEveryOtherTrackByItsLatency() {
        let tuned = TrackID(), drums = TrackID(), bass = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: drums, latency: 0), .init(track: tuned, latency: 912),
                                              .init(track: bass, latency: 0)], returns: [], master: 0)
        XCTAssertEqual(plan.delay(of: tuned)?.delay, 0, "the late track waits for nobody")
        XCTAssertEqual(plan.delay(of: drums)?.delay, 912)
        XCTAssertEqual(plan.delay(of: bass)?.delay, 912)
        XCTAssertEqual(plan.trackLatency, 912)
        XCTAssertEqual(plan.total, 912)
        XCTAssertEqual(plan.longestDelay, 912)
        // Each track's chain plus its wait is the same for all: they line up.
        XCTAssertEqual(Set(plan.tracks.map { $0.latency + $0.delay }), [912])
    }

    func testASendReachesItsReturnInTimeAndTheDryTrackWaitsForTheReturnChain() {
        let tuned = TrackID(), dry = TrackID(), verb = TrackID(), room = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: tuned, latency: 912, buses: [0]),
                                              .init(track: dry, latency: 0, buses: [0, 1])],
                                     returns: [.init(track: verb, bus: 0, latency: 85), .init(track: room, bus: 1, latency: 0)],
                                     master: 0)
        // Stage 1: the sends tap after the wait, so both reach the returns at 912.
        XCTAssertEqual(plan.delay(of: dry)?.delay, 912)
        XCTAssertEqual(plan.delay(of: tuned)?.delay, 0)
        // Stage 2: the late return's chain (85) is waited for by the other return and by every
        // track's own output.
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 0)
        XCTAssertEqual(plan.delay(ofReturn: 1)?.delay, 85)
        XCTAssertEqual(plan.tracks.map(\.directDelay), [85, 85])
        XCTAssertEqual(plan.total, 997)
        // Every path to the master arrives at the same frame.
        for track in plan.tracks {
            XCTAssertEqual(track.latency + track.delay + track.directDelay, plan.total, "dry path")
        }
        for back in plan.returns {
            XCTAssertEqual(plan.trackLatency + back.latency + back.delay, plan.total, "return path")
        }
    }

    func testAReturnNothingFeedsDelaysNoTrack() {
        let a = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: 0)],
                                     returns: [.init(track: verb, bus: 0, latency: 912)], master: 0)
        XCTAssertEqual(plan.returnLatency, 0)
        XCTAssertEqual(plan.delay(of: a)?.directDelay, 0)
        XCTAssertTrue(plan.isEmpty)
    }

    func testALaneOnItsOwnPairWaitsForTheMastersEffects() {
        let mixed = TrackID(), outboard = TrackID(), verb = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: mixed, latency: 0, buses: [0]),
                                              .init(track: outboard, latency: 0, ownOutput: true)],
                                     returns: [.init(track: verb, bus: 0, latency: 0, ownOutput: true)], master: 85)
        XCTAssertEqual(plan.delay(of: mixed)?.directDelay, 0, "the master's effects delay it already")
        XCTAssertEqual(plan.delay(of: outboard)?.directDelay, 85)
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 85)
        XCTAssertEqual(plan.total, 85)
    }

    func testANegativeOrHugeLatencyIsBounded() {
        XCTAssertEqual(DelayCompensation.chain([-5, 10]), 10)
        XCTAssertEqual(DelayCompensation.chain([Int.max, Int.max]), 2 * DelayCompensation.maximumUnitLatency)
        let a = TrackID(), b = TrackID()
        let plan = DelayCompensation(tracks: [.init(track: a, latency: -40), .init(track: b, latency: 10)], returns: [], master: -3)
        XCTAssertEqual(plan.delay(of: a)?.delay, 10)
        XCTAssertEqual(plan.masterLatency, 0)
    }

    func testAUnitsLatencyInFramesIsRoundedAndBounded() {
        XCTAssertEqual(PluginLatency.frames(seconds: 0.019, sampleRate: 48_000), 912)
        XCTAssertEqual(PluginLatency.frames(seconds: 85.0 / 48_000, sampleRate: 48_000), 85)
        XCTAssertEqual(PluginLatency.frames(seconds: .nan, sampleRate: 48_000), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: -1, sampleRate: 48_000), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: 0.01, sampleRate: .infinity), 0)
        XCTAssertEqual(PluginLatency.frames(seconds: 30, sampleRate: 48_000), 48_000, "one second at the most")
    }

    // MARK: - The snapshot

    private func snapshot(_ project: Project, effects: [TrackID: [any HostedProcessor]],
                          masterEffects: [any HostedProcessor] = [], units: [TrackID: any HostedInstrument] = [:],
                          slots: [TrackID: Int] = [:], outputChannels: Int = 2) -> EngineSnapshot {
        EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots, sampleRate: rate,
                       generation: 1, units: units, effects: effects, outputChannels: outputChannels,
                       masterEffects: masterEffects)
    }

    func testTheSnapshotReadsEachInsertsLatencyAndALatencyThatChangesRebuildsThePlan() throws {
        var project = Project(tempo: 120)
        let tuned = TrackID(), drums = TrackID()
        try Command.addTrack(id: tuned, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        let pitch = LateInsert(latency: 912)
        let first = snapshot(project, effects: [tuned: [pitch, LateInsert(latency: 0)]])
        XCTAssertEqual(first.compensation.delay(of: drums)?.delay, 912)
        XCTAssertEqual(first.compensation.delay(of: tuned)?.delay, 0)

        pitch.latency = 85
        let second = snapshot(project, effects: [tuned: [pitch]])
        XCTAssertEqual(second.compensation.delay(of: drums)?.delay, 85, "the next snapshot asks the unit again")
        XCTAssertNotEqual(first.compensation, second.compensation)

        pitch.isBypassed = true
        let third = snapshot(project, effects: [tuned: [pitch]])
        XCTAssertTrue(third.compensation.isEmpty, "a bypassed insert is skipped, and so is its latency")

        let otherRate = snapshot(project, effects: [tuned: [LateInsert(latency: 912, sampleRate: 44_100)]])
        XCTAssertTrue(otherRate.compensation.isEmpty, "an insert left out of the chain brings no latency")
    }

    func testTheSnapshotCompensatesSendsReturnsAndTheMaster() throws {
        var project = Project(tempo: 120)
        let tuned = TrackID(), dry = TrackID(), verb = TrackID(), outboard = TrackID()
        try Command.addTrack(id: tuned, name: "Vocal", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: dry, name: "Guitar", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: outboard, name: "Click", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: dry, to: verb, db: 0).apply(to: &project)
        try Command.setOutput(outboard, channel: 2).apply(to: &project)
        let shot = snapshot(project, effects: [tuned: [LateInsert(latency: 912)], verb: [LateInsert(latency: 85)]],
                            masterEffects: [LateInsert(latency: 64)], outputChannels: 4)
        let plan = shot.compensation
        XCTAssertEqual(plan.delay(of: dry)?.delay, 912, "its send reaches the return in time with the vocal")
        XCTAssertEqual(plan.delay(of: dry)?.directDelay, 85, "its dry sound waits for the reverb's chain")
        XCTAssertEqual(plan.delay(of: tuned)?.directDelay, 85)
        XCTAssertEqual(plan.delay(of: outboard)?.directDelay, 85 + 64, "its own pair waits for the master's effects")
        XCTAssertEqual(plan.delay(ofReturn: 0)?.delay, 0)
        XCTAssertEqual(plan.total, 912 + 85 + 64)
    }

    func testAPluginInstrumentsLatencyCountsInItsTracksChain() throws {
        var project = Project(tempo: 120)
        let keys = TrackID(), drums = TrackID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Late"),
                                     manufacturer: PluginComponent.code("Test"), name: "Late", manufacturerName: "Test")
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(keys, plugin).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        var slots = SlotAssigner(capacity: 8)
        slots.update(for: project)
        let shot = snapshot(project, effects: [keys: [LateInsert(latency: 36)]], units: [keys: LateInstrument(latency: 64)],
                            slots: slots.slots)
        XCTAssertEqual(shot.compensation.delay(of: keys)?.latency, 100)
        XCTAssertEqual(shot.compensation.delay(of: drums)?.delay, 100)
    }
}

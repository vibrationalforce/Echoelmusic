import AudioToolbox
import EchoelCore
import XCTest
@testable import EchoelEngine

/// A stand-in Audio Unit effect: pulls its input and writes it scaled. `ownBuffers` decides
/// whether it hands the pull block buffers of its own or asks to be pointed at the host's.
private final class FakeEffect: @unchecked Sendable {
    let scale: Float
    let ownBuffers: Bool
    private let left = UnsafeMutablePointer<Float>.allocate(capacity: 4_096)
    private let right = UnsafeMutablePointer<Float>.allocate(capacity: 4_096)
    private let input = AudioBufferList.allocate(maximumBuffers: 2)

    init(scale: Float, ownBuffers: Bool) {
        self.scale = scale
        self.ownBuffers = ownBuffers
    }

    deinit {
        left.deallocate()
        right.deallocate()
        free(input.unsafeMutablePointer)
    }

    func makeEffect(sampleRate: Double, bypassed: Bool = false) -> HostedEffect {
        HostedEffect(render: { [self] flags, stamp, frames, _, output, pull in
            let bytes = UInt32(Int(frames) * MemoryLayout<Float>.size)
            input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: ownBuffers ? bytes : 0,
                                   mData: ownBuffers ? UnsafeMutableRawPointer(left) : nil)
            input[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: ownBuffers ? bytes : 0,
                                   mData: ownBuffers ? UnsafeMutableRawPointer(right) : nil)
            guard let pull, pull(flags, stamp, frames, 0, input.unsafeMutablePointer) == noErr else { return -1 }
            for (index, buffer) in UnsafeMutableAudioBufferListPointer(output).enumerated() {
                guard let out = buffer.mData?.assumingMemoryBound(to: Float.self),
                      let source = input[index].mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<Int(frames) { out[i] = source[i] * scale }
            }
            return noErr
        }, sampleRate: sampleRate, maximumFrames: 4_096, isBypassed: bypassed, owner: nil)
    }
}

final class HostedEffectTests: XCTestCase {
    private let rate = 48_000.0

    /// An instrument track playing a hosted unit that outputs a constant 0.5 on both channels.
    private func constantSong() throws -> (Project, TrackID, HostedUnit) {
        var project = Project(tempo: 120)
        let track = TrackID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Cnst"),
                                     manufacturer: PluginComponent.code("Test"), name: "Constant", manufacturerName: "Test")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, plugin).apply(to: &project)
        let unit = HostedUnit(render: { _, _, frames, _, list, _ in
            for buffer in UnsafeMutableAudioBufferListPointer(list) {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<Int(frames) { data[i] = 0.5 }
            }
            return noErr
        }, scheduleMIDI: nil, sampleRate: rate, maximumFrames: 4_096, owner: nil)
        return (project, track, unit)
    }

    private func render(_ project: Project, track: TrackID, unit: HostedUnit, effects: [HostedEffect],
                        master: [HostedEffect] = [], engine: EngineCore? = nil) -> [Float] {
        let engine = engine ?? EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, units: [track: unit], effects: [track: effects],
                                      masterEffects: master))
        var left = [Float](repeating: 0, count: 1_024)
        var right = [Float](repeating: 0, count: 1_024)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                engine.render(frameCount: 1_024, left: lp, right: rp)
            }
        }
        return left
    }

    private let panLaw = Float(0.5).squareRoot()

    func testAnInsertProcessesTheTracksBusBeforeItsGains() throws {
        let (project, track, unit) = try constantSong()
        for own in [true, false] {
            let effect = FakeEffect(scale: 0.5, ownBuffers: own).makeEffect(sampleRate: rate)
            let out = render(project, track: track, unit: unit, effects: [effect])
            XCTAssertEqual(out[500], 0.25 * panLaw, accuracy: 1e-5, "own buffers: \(own)")
        }
    }

    func testInsertsRunInOrderAndABypassedOnePassesTheBusThrough() throws {
        let (project, track, unit) = try constantSong()
        let chain = [FakeEffect(scale: 0.5, ownBuffers: true).makeEffect(sampleRate: rate),
                     FakeEffect(scale: 0.1, ownBuffers: false).makeEffect(sampleRate: rate, bypassed: true),
                     FakeEffect(scale: 0.5, ownBuffers: false).makeEffect(sampleRate: rate)]
        let out = render(project, track: track, unit: unit, effects: chain)
        XCTAssertEqual(out[10], 0.125 * panLaw, accuracy: 1e-5)
    }

    func testASendFeedsAReturnThatSolosDoNotSilence() throws {
        var (project, track, unit) = try constantSong()
        let verb = TrackID()
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        let direct = 0.5 * panLaw
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], direct, accuracy: 1e-5)

        try Command.setSend(track: track, to: verb, db: 0).apply(to: &project)
        // The send is post-fader and post-pan, then the return's own centre pan.
        let both = direct + direct * panLaw
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], both, accuracy: 1e-5)

        try Command.setSolo(track, true).apply(to: &project)
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], both, accuracy: 1e-5)

        try Command.setMute(verb, true).apply(to: &project)
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], direct, accuracy: 1e-5)

        try Command.setMute(verb, false).apply(to: &project)
        try Command.setMute(track, true).apply(to: &project)
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], 0, accuracy: 1e-6,
                       "a muted track sends nothing")
    }

    func testASoloedReturnPlaysAloneWithWhatIsSentToIt() throws {
        var (project, track, unit) = try constantSong()
        let verb = TrackID()
        try Command.addTrack(id: verb, name: "Reverb", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: track, to: verb, db: 0).apply(to: &project)
        let direct = 0.5 * panLaw
        try Command.setSolo(verb, true).apply(to: &project)
        // The track's own output goes quiet; its send still reaches the soloed return.
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], direct * panLaw, accuracy: 1e-5)

        try Command.setMute(track, true).apply(to: &project)
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [])[10], 0, accuracy: 1e-6,
                       "a muted track feeds no return, soloed or not")
    }

    func testTheMasterChainRunsOnTheMixAfterTheMasterFader() throws {
        var (project, track, unit) = try constantSong()
        try Command.setVolume(.master, db: -6).apply(to: &project)
        let fader = Float(pow(10, -6.0 / 20))
        let plain = render(project, track: track, unit: unit, effects: [])[500]
        XCTAssertEqual(plain, 0.5 * panLaw * fader, accuracy: 1e-4)
        let chain = [FakeEffect(scale: 0.5, ownBuffers: true).makeEffect(sampleRate: rate),
                     FakeEffect(scale: 0.1, ownBuffers: false).makeEffect(sampleRate: rate, bypassed: true)]
        XCTAssertEqual(render(project, track: track, unit: unit, effects: [], master: chain)[500], plain * 0.5, accuracy: 1e-5)
    }

    func testTheMasterMeterReadsAfterTheMasterChain() throws {
        let (project, track, unit) = try constantSong()
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        _ = render(project, track: track, unit: unit, effects: [],
                   master: [FakeEffect(scale: 0.5, ownBuffers: true).makeEffect(sampleRate: rate)], engine: engine)
        XCTAssertEqual(engine.meters.level(engine.masterMeter).left, 0.25 * panLaw, accuracy: 1e-4)
    }

    func testAMasterEffectPreparedForAnotherRateIsLeftOut() throws {
        let (project, track, unit) = try constantSong()
        let out = render(project, track: track, unit: unit, effects: [],
                         master: [FakeEffect(scale: 0, ownBuffers: true).makeEffect(sampleRate: 44_100)])
        XCTAssertEqual(out[10], 0.5 * panLaw, accuracy: 1e-5)
    }

    func testAnEffectPreparedForAnotherRateIsLeftOut() throws {
        let (project, track, unit) = try constantSong()
        let out = render(project, track: track, unit: unit,
                         effects: [FakeEffect(scale: 0, ownBuffers: true).makeEffect(sampleRate: 44_100)])
        XCTAssertEqual(out[10], 0.5 * panLaw, accuracy: 1e-5)
    }
}

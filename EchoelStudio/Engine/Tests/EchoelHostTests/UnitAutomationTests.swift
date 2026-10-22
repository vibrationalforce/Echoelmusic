import AudioToolbox
import EchoelCore
import XCTest
@testable import EchoelEngine
@testable import EchoelHost

/// A stand-in Audio Unit that renders silence and notes every parameter it is sent.
private final class FakeParameterUnit: @unchecked Sendable {
    private(set) var sent: [(address: UInt64, value: Float, ramp: UInt32)] = []

    func makeUnit(sampleRate: Double) -> HostedUnit {
        HostedUnit(render: { _, _, frames, _, list, _ in
            for buffer in UnsafeMutableAudioBufferListPointer(list) {
                buffer.mData?.assumingMemoryBound(to: Float.self).update(repeating: 0, count: Int(frames))
            }
            return noErr
        }, scheduleMIDI: nil, sampleRate: sampleRate, maximumFrames: 4_096, owner: nil,
        scheduleParameter: { [self] _, ramp, address, value in sent.append((address, value, ramp)) },
        parameterRanges: [7: 20...20_000])
    }
}

final class UnitAutomationTests: XCTestCase {
    private let rate = 48_000.0

    func testAPluginParameterSweepsWithTheLaneAndRestsWhenTheLaneDoes() throws {
        var project = Project(tempo: 120)
        let track = TrackID()
        let plugin = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Fake"),
                                     manufacturer: PluginComponent.code("Test"), name: "Fake", manufacturerName: "Test")
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentPlugin(track, plugin).apply(to: &project)
        // Two beats, 48,000 frames at 120 BPM, from the bottom of the range to the top.
        let points = [AutomationPoint(tick: 0, value: 0), AutomationPoint(tick: 1_920, value: 1)]
        try Command.setAutomation(.plugin(track, PluginParameter(.instrument, address: 7)), points: points).apply(to: &project)
        try Command.setAutomation(.plugin(track, PluginParameter(.instrument, address: 99)), points: points).apply(to: &project)

        let fake = FakeParameterUnit()
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        var slots = SlotAssigner(capacity: engine.slotCapacity)
        slots.update(for: project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, units: [track: fake.makeUnit(sampleRate: rate)]))
        engine.play()
        var left = [Float](repeating: 0, count: 512), right = left
        let render = { (blocks: Int) in
            for _ in 0..<blocks {
                left.withUnsafeMutableBufferPointer { l in
                    right.withUnsafeMutableBufferPointer { r in
                        guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                        engine.render(frameCount: 512, left: lp, right: rp)
                    }
                }
            }
        }
        render(100)                                       // 51,200 frames: past the lane's end

        XCTAssertTrue(fake.sent.allSatisfy { $0.address == 7 }, "a parameter the unit does not have is never sent")
        XCTAssertGreaterThan(fake.sent.count, 1_000, "a step every 32 frames")
        XCTAssertTrue(fake.sent.allSatisfy { $0.ramp == 32 }, "each step glides into the next")
        let values = fake.sent.map(\.value)
        XCTAssertEqual(values.first ?? 0, 20, accuracy: 1)
        XCTAssertEqual(values.last ?? 0, 20_000, accuracy: 1)
        XCTAssertEqual(values, values.sorted(), "it only rises")
        let steps = zip(values, values.dropFirst()).map { $1 - $0 }.dropLast()
        XCTAssertLessThan(steps.max() ?? .infinity, 15, "no jumps")
        XCTAssertGreaterThan(steps.min() ?? 0, 12, "even steps: the lane is read between ticks, not on them")

        let count = fake.sent.count
        render(20)
        XCTAssertEqual(fake.sent.count, count, "a held value is not sent again")
    }
}

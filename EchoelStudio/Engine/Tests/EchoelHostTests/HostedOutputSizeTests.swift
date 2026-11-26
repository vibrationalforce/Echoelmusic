import AVFoundation
import AudioToolbox
import XCTest
@testable import EchoelHost

/// Memory a unit hands back instead of filling ours: `given` samples it declares, then a
/// sentinel it never declared, so a read past the declared size shows in the result.
private final class UnitMemory: @unchecked Sendable {
    static let sentinel: Float = 7
    let samples: UnsafeMutablePointer<Float>
    let capacity: Int

    init(capacity: Int, given: Int, value: Float) {
        self.capacity = capacity
        samples = .allocate(capacity: capacity)
        samples.initialize(repeating: Self.sentinel, count: capacity)
        samples.update(repeating: value, count: given)
    }

    deinit {
        samples.deinitialize(count: capacity)
        samples.deallocate()
    }

    /// Points every output buffer at this memory and declares `given` samples in each.
    func handBack(_ output: UnsafeMutablePointer<AudioBufferList>, given: Int) {
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        for index in 0..<buffers.count {
            buffers[index].mData = UnsafeMutableRawPointer(samples)
            buffers[index].mDataByteSize = UInt32(given * MemoryLayout<Float>.size)
        }
    }
}

/// A unit may point its output at memory of its own, and then says how much it holds
/// (`mDataByteSize`). Fewer samples than the block asked for is a refused block: reading on would
/// read memory the unit never declared (render audit 2026-11-25, priority 9). The input side
/// already reads no more than the unit's buffer declares (`HostedEffect.fill`).
final class HostedOutputSizeTests: XCTestCase {
    private let frames = 256
    private let short = 128

    func testAnEffectThatHandsBackLessThanTheBlockLeavesTheBusAndCountsTheBlock() {
        let memory = UnitMemory(capacity: frames, given: short, value: 0.25)
        let declared = short
        let effect = HostedEffect(render: { _, _, _, _, output, _ in
            memory.handBack(output, given: declared)
            return noErr
        }, sampleRate: 48_000, maximumFrames: frames, owner: nil)
        var left = [Float](repeating: 0.5, count: frames)
        var right = [Float](repeating: 0.5, count: frames)
        effect.process(frames: frames, left: &left, right: &right)
        XCTAssertEqual(effect.renderFailures, 1, "a short buffer is a refused block, so an export fails")
        XCTAssertEqual(left, [Float](repeating: 0.5, count: frames), "the bus stays as it was")
        XCTAssertEqual(right, [Float](repeating: 0.5, count: frames), "on both sides")
    }

    func testAnInstrumentThatHandsBackLessThanTheBlockAddsNothingAndCountsTheBlock() {
        let memory = UnitMemory(capacity: frames, given: short, value: 0.25)
        let declared = short
        let unit = HostedUnit(render: { _, _, _, _, output, _ in
            memory.handBack(output, given: declared)
            return noErr
        }, scheduleMIDI: nil, sampleRate: 48_000, maximumFrames: frames, owner: nil)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        unit.render(frames: frames, left: &left, right: &right, gainLeft: 1, gainRight: 1)
        XCTAssertEqual(unit.renderFailures, 1, "a short buffer is a refused block, so an export fails")
        XCTAssertEqual(left, [Float](repeating: 0, count: frames), "nothing is added")
        XCTAssertEqual(right, [Float](repeating: 0, count: frames), "on either side")
    }

    /// The counterweight: memory of its own that holds the whole block plays, as it always did.
    func testAUnitThatHandsBackTheWholeBlockInItsOwnMemoryPlays() {
        let whole = frames
        let effectMemory = UnitMemory(capacity: frames, given: whole, value: 0.25)
        let effect = HostedEffect(render: { _, _, _, _, output, _ in
            effectMemory.handBack(output, given: whole)
            return noErr
        }, sampleRate: 48_000, maximumFrames: frames, owner: nil)
        var busLeft = [Float](repeating: 0.5, count: frames)
        var busRight = [Float](repeating: 0.5, count: frames)
        effect.process(frames: frames, left: &busLeft, right: &busRight)
        XCTAssertEqual(effect.renderFailures, 0)
        XCTAssertEqual(busLeft, [Float](repeating: 0.25, count: frames), "the effect's output replaces the bus")
        XCTAssertEqual(busRight, [Float](repeating: 0.25, count: frames))

        let unitMemory = UnitMemory(capacity: frames, given: whole, value: 0.25)
        let unit = HostedUnit(render: { _, _, _, _, output, _ in
            unitMemory.handBack(output, given: whole)
            return noErr
        }, scheduleMIDI: nil, sampleRate: 48_000, maximumFrames: frames, owner: nil)
        var mixLeft = [Float](repeating: 0, count: frames)
        var mixRight = [Float](repeating: 0, count: frames)
        unit.render(frames: frames, left: &mixLeft, right: &mixRight, gainLeft: 1, gainRight: 1)
        XCTAssertEqual(unit.renderFailures, 0)
        XCTAssertEqual(mixLeft, [Float](repeating: 0.25, count: frames), "the instrument's output is added")
        XCTAssertEqual(mixRight, [Float](repeating: 0.25, count: frames))
    }
}

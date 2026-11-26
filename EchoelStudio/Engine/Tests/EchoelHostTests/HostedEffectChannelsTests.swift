import AVFoundation
import AudioToolbox
import XCTest
@testable import EchoelHost

/// What a plain render block plays with: the input list it hands the pull block, and what it heard.
private final class Probe: @unchecked Sendable {
    let input = AudioBufferList.allocate(maximumBuffers: 2)
    var heard: [Float] = []

    deinit { free(input.unsafeMutablePointer) }
}

/// An effect whose busses differ from the bus it sits on: one channel in and two out, or two in
/// and one out. The one-channel input without a buffer of its own is filled in the host's buffer,
/// which no other test reaches (the AUv3-host review of a843e0e).
final class HostedEffectChannelsTests: XCTestCase {
    private let frames = 64

    func testAMonoInputWithoutABufferOfItsOwnHearsTheBusSummedInTheHostsBuffer() throws {
        let probe = Probe()
        let effect = HostedEffect(render: { flags, stamp, count, _, output, pull in
            probe.input.count = 1
            probe.input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
            guard let pull, pull(flags, stamp, count, 0, probe.input.unsafeMutablePointer) == noErr,
                  let mono = probe.input[0].mData?.assumingMemoryBound(to: Float.self) else {
                return kAudioUnitErr_NoConnection
            }
            probe.heard = Array(UnsafeBufferPointer(start: mono, count: Int(count)))
            for buffer in UnsafeMutableAudioBufferListPointer(output) {
                buffer.mData?.assumingMemoryBound(to: Float.self).update(from: mono, count: Int(count))
            }
            return noErr
        }, sampleRate: 48_000, maximumFrames: 256, owner: nil)
        var left = [Float](repeating: 1, count: frames)
        var right = [Float](repeating: 0.5, count: frames)
        effect.process(frames: frames, left: &left, right: &right)
        XCTAssertEqual(effect.renderFailures, 0)
        let summed = [Float](repeating: 0.75, count: frames)
        XCTAssertEqual(probe.heard, summed, "the bus summed at half each")
        XCTAssertEqual(left, summed, "the one channel plays on the left")
        XCTAssertEqual(right, summed, "and on the right")
    }

    func testAStereoInputIntoAMonoOutputPlaysOnBothSides() throws {
        let probe = Probe()
        let effect = HostedEffect(render: { flags, stamp, count, _, output, pull in
            probe.input.count = 2
            probe.input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
            probe.input[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
            guard let pull, pull(flags, stamp, count, 0, probe.input.unsafeMutablePointer) == noErr,
                  let inLeft = probe.input[0].mData?.assumingMemoryBound(to: Float.self),
                  let inRight = probe.input[1].mData?.assumingMemoryBound(to: Float.self),
                  let out = UnsafeMutableAudioBufferListPointer(output)[0].mData?.assumingMemoryBound(to: Float.self) else {
                return kAudioUnitErr_NoConnection
            }
            for i in 0..<Int(count) { out[i] = inLeft[i] - inRight[i] }
            return noErr
        }, sampleRate: 48_000, maximumFrames: 256, owner: nil, outputChannels: 1)
        var left = [Float](repeating: 1, count: frames)
        var right = [Float](repeating: 0.25, count: frames)
        effect.process(frames: frames, left: &left, right: &right)
        XCTAssertEqual(effect.renderFailures, 0)
        let difference = [Float](repeating: 0.75, count: frames)
        XCTAssertEqual(left, difference, "the unit heard both sides apart")
        XCTAssertEqual(right, difference, "its one channel plays on both")
    }
}

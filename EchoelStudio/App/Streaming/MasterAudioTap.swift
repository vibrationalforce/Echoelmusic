import AVFoundation
import Darwin
import Foundation

/// The live stream's ear on the master (wave W14): a tap on the engine's source node — the whole
/// mix as the musician hears it, no microphone. `AudioEngine` installs it while a stream runs and
/// again after every graph rebuild (`AudioEngine.setStreamTap`).
///
/// AVFoundation delivers a tap on its own thread, not the render thread, so the render block is
/// never touched. The tap block still only copies: into a ring of buffers allocated when the tap is
/// installed, then it names the filled slot to `blocks`. The ring has more slots than `blocks` can
/// hold plus the one being sent, so a slot is never rewritten while the publisher reads it; when
/// the publisher falls behind, the oldest blocks are dropped, never a slot overwritten in use.
final class MasterAudioTap: @unchecked Sendable {
    /// One filled slot: its buffer (stereo, float, non-interleaved) and the host time it began.
    struct Block: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        let time: AVAudioTime
        /// Keeps the ring alive while a block of it is in flight after a rebuild replaced it.
        fileprivate let ring: Ring
    }

    fileprivate final class Ring: @unchecked Sendable {
        let slots: [AVAudioPCMBuffer]
        /// Written only on the tap's thread.
        var next = 0

        init?(format: AVAudioFormat) {
            var made: [AVAudioPCMBuffer] = []
            for _ in 0..<MasterAudioTap.slotCount {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: MasterAudioTap.frameCapacity)
                else { return nil }
                made.append(buffer)
            }
            slots = made
        }
    }

    /// iOS hands a tap 100 ms or more at a time whatever size is asked for; one slot holds 16384
    /// frames (a third of a second at 48 kHz), more is cut and counted.
    static let frameCapacity: AVAudioFrameCount = 16_384
    static let slotCount = 16
    private static let pending = 8

    let blocks: AsyncStream<Block>
    private let continuation: AsyncStream<Block>.Continuation

    init() {
        let stream = AsyncStream.makeStream(of: Block.self, bufferingPolicy: .bufferingNewest(Self.pending))
        blocks = stream.stream
        continuation = stream.continuation
    }

    /// Installs the tap on bus 0 of `node`. False when no ring could be made for its format.
    func install(on node: AVAudioNode) -> Bool {
        let source = node.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let stereo = AVAudioFormat(standardFormatWithSampleRate: source.sampleRate, channels: 2),
              let ring = Ring(format: stereo) else { return false }
        let continuation = continuation
        node.installTap(onBus: 0, bufferSize: 4_096, format: source) { @Sendable buffer, when in
            Self.copy(buffer, when: when, into: ring, continuation: continuation)
        }
        return true
    }

    func finish() {
        continuation.finish()
    }

    private static func copy(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, into ring: Ring,
                             continuation: AsyncStream<Block>.Continuation) {
        guard let input = buffer.floatChannelData, buffer.format.channelCount > 0 else { return }
        let slot = ring.slots[ring.next]
        ring.next = (ring.next + 1) % ring.slots.count
        guard let output = slot.floatChannelData else { return }
        let frames = Swift.min(buffer.frameLength, slot.frameCapacity)
        let bytes = Int(frames) * MemoryLayout<Float>.size
        // A mono source fills both sides; a multichannel interface sends its first pair.
        let right = buffer.format.channelCount > 1 ? 1 : 0
        memcpy(output[0], input[0], bytes)
        memcpy(output[1], input[right], bytes)
        slot.frameLength = frames
        let time = when.isHostTimeValid ? when : AVAudioTime(hostTime: mach_absolute_time())
        continuation.yield(Block(buffer: slot, time: time, ring: ring))
    }
}

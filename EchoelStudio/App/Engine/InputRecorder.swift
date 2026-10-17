import AVFoundation
import EchoelEngine
import Foundation
import Synchronization

/// The render-thread half of recording: a sink node hands every input block to `receive`,
/// which copies the first input channel into a ring while a take is armed and notes the
/// playhead at the take's first frame. No locks, no allocation, no I/O — the file is written
/// by a `TakeWriter` that drains the ring.
final class InputRecorder: @unchecked Sendable {
    let ring: AudioRing
    private let core: EngineCore
    private let armed = Atomic<Bool>(false)
    private let start = Atomic<Int64>(-1)
    private let scratch: UnsafeMutablePointer<Float>
    private static let scratchFrames = 8_192

    /// Ten seconds of headroom: the writer drains every 50 ms, so only a stalled disk drops audio.
    init(core: EngineCore, sampleRate: Double) {
        self.core = core
        ring = AudioRing(capacity: Int(Swift.max(sampleRate, 8_000) * 10))
        scratch = .allocate(capacity: Self.scratchFrames)
        scratch.initialize(repeating: 0, count: Self.scratchFrames)
    }

    deinit {
        scratch.deallocate()
    }

    /// Main thread: the next input block starts a take.
    func arm() {
        start.store(-1, ordering: .releasing)
        armed.store(true, ordering: .releasing)
    }

    /// Main thread: input after this is no longer recorded.
    func disarm() {
        armed.store(false, ordering: .releasing)
    }

    /// The output sample the playhead stood at when the take's first frame arrived; −1 before.
    var startSample: Int64 { start.load(ordering: .acquiring) }

    /// Render thread.
    func receive(_ list: UnsafePointer<AudioBufferList>, frames: Int) {
        guard frames > 0, armed.load(ordering: .acquiring) else { return }
        if start.load(ordering: .relaxed) < 0 {
            // The playhead has already moved past the block that plays with this input block.
            start.store(Swift.max(0, core.positionSample - Int64(frames)), ordering: .releasing)
        }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        guard let channel = buffers.first, let data = channel.mData?.assumingMemoryBound(to: Float.self) else { return }
        let stride = Swift.max(1, Int(channel.mNumberChannels))
        // Never read past the buffer, whatever the frame count claims.
        let held = Swift.min(frames, Int(channel.mDataByteSize) / (MemoryLayout<Float>.size * stride))
        guard stride > 1 else {
            ring.write(data, count: held)
            return
        }
        // Interleaved input: take channel 1.
        var done = 0
        while done < held {
            let n = Swift.min(held - done, Self.scratchFrames)
            for i in 0..<n { scratch[i] = data[(done + i) * stride] }
            ring.write(scratch, count: n)
            done += n
        }
    }

    nonisolated static func makeSinkNode(_ recorder: InputRecorder) -> AVAudioSinkNode {
        AVAudioSinkNode { @Sendable _, frameCount, list in
            recorder.receive(list, frames: Int(frameCount))
            return noErr
        }
    }
}

/// Writes a take to a mono 32-bit float CAF file from the recorder's ring, off the main thread.
actor TakeWriter {
    enum WriterError: Error { case noFormat }

    private var file: AVAudioFile?
    private let chunk: AVAudioPCMBuffer
    private let ring: AudioRing
    private var frames = 0

    init(url: URL, sampleRate: Double, ring: AudioRing) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1,
                                         interleaved: false),
              let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            throw WriterError.noFormat
        }
        file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32,
                               interleaved: false)
        self.chunk = chunk
        self.ring = ring
        // A block that arrived as the previous take was stopped would otherwise open this one.
        ring.discardAvailable()
    }

    /// Writes whatever is waiting in the ring.
    func drain() throws {
        guard let file, let data = chunk.floatChannelData?[0] else { return }
        while true {
            let n = ring.read(into: data, count: Int(chunk.frameCapacity))
            guard n > 0 else { return }
            chunk.frameLength = AVAudioFrameCount(n)
            try file.write(from: chunk)
            frames += n
        }
    }

    /// Writes the rest, closes the file and returns its length in frames.
    func finish() throws -> Int {
        try drain()
        file = nil
        return frames
    }
}

/// A finished take, ready to become a region.
struct RecordedTake: Sendable {
    let url: URL
    let sampleRate: Double
    /// See `InputRecorder.startSample`.
    let startSample: Int64
    /// Output plus input latency in samples, as the session reported it when the take began.
    let latency: Int64
}

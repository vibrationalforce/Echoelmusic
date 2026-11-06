import AVFoundation
import EchoelCore
import EchoelEngine
import Foundation
import Synchronization

/// The render-thread half of recording: a sink node hands every input block to `receive`,
/// which copies the track's input channel — or its pair, left and right side by side — into a
/// ring while a take is armed and notes the
/// playhead at the take's first frame. No locks, no allocation, no I/O — the file is written
/// by a `TakeWriter` that drains the ring. One recorder per built graph: a take keeps the one it
/// began on until its file is written, and a rebuilt graph gets a new one (`TakeLifecycle`).
final class InputRecorder: @unchecked Sendable {
    let ring: AudioRing
    private let core: EngineCore
    private let armed = Atomic<Bool>(false)
    private let start = Atomic<Int64>(-1)
    private let startPlayedFrames = Atomic<Int64>(-1)
    private let channel = Atomic<Int>(0)
    private let paired = Atomic<Bool>(false)
    private let scratch: UnsafeMutablePointer<Float>
    private static let scratchFrames = 8_192

    /// Ten seconds of headroom for a pair: the writer drains every 50 ms, so only a stalled disk
    /// drops audio. The capacity is even, so a full ring drops whole stereo frames, never a side.
    init(core: EngineCore, sampleRate: Double) {
        self.core = core
        ring = AudioRing(capacity: Int(Swift.max(sampleRate, 8_000) * 10) * 2)
        scratch = .allocate(capacity: Self.scratchFrames)
        scratch.initialize(repeating: 0, count: Self.scratchFrames)
    }

    deinit {
        scratch.deallocate()
    }

    /// Main thread: the next input block starts a take, from input `channel` (0-based) — with
    /// `pair`, from it and the input after it, interleaved left, right in the ring.
    func arm(channel: Int, pair: Bool) {
        self.channel.store(Swift.max(0, channel), ordering: .releasing)
        paired.store(pair, ordering: .releasing)
        start.store(-1, ordering: .releasing)
        startPlayedFrames.store(-1, ordering: .releasing)
        armed.store(true, ordering: .releasing)
    }

    /// Main thread: input after this is no longer recorded. Idempotent.
    func disarm() {
        armed.store(false, ordering: .releasing)
    }

    /// The output sample the playhead stood at when the take's first frame arrived; −1 before.
    var startSample: Int64 { start.load(ordering: .acquiring) }

    /// `EngineCore.playedFrames` when the take's first frame arrived: the clock a loop's wraps are
    /// counted on, so the file can be cut into passes (Loop record).
    var startPlayed: Int64 { startPlayedFrames.load(ordering: .acquiring) }

    /// Render thread.
    func receive(_ list: UnsafePointer<AudioBufferList>, frames: Int) {
        guard frames > 0 else { return }
        monitor(list, frames: frames)
        guard armed.load(ordering: .acquiring) else { return }
        if start.load(ordering: .relaxed) < 0 {
            // The playhead has already moved past the block that plays with this input block.
            startPlayedFrames.store(core.playedFrames - Int64(frames), ordering: .releasing)
            start.store(Swift.max(0, core.positionSample - Int64(frames)), ordering: .releasing)
        }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        let wanted = channel.load(ordering: .acquiring)
        let pair = paired.load(ordering: .acquiring)
        // One buffer per channel, or all channels interleaved in one; a channel the input lacks
        // records the first, and a pair's missing right records its left (`InputLanes`).
        let perBuffer = buffers.count > 0 ? Int(buffers[0].mNumberChannels) : 1
        guard let lanes = InputLanes.resolve(left: wanted, right: pair ? wanted + 1 : wanted,
                                             buffers: buffers.count, channelsPerBuffer: perBuffer),
              let left = source(buffers, lanes.left, frames: frames) else { return }
        guard pair else {
            copy(left.data, lane: left.lane, stride: left.stride, held: left.held) { ring.write($0, count: $1) }
            return
        }
        guard let right = source(buffers, lanes.right, frames: frames) else { return }
        // Left and right side by side; a frame is written whole or not at all.
        let whole = Swift.min(left.held, right.held)
        let step = Self.scratchFrames / 2
        var done = 0
        while done < whole {
            let n = Swift.min(whole - done, step)
            for i in 0..<n {
                scratch[2 * i] = left.data[(done + i) * left.stride + left.lane]
                scratch[2 * i + 1] = right.data[(done + i) * right.stride + right.lane]
            }
            ring.write(scratch, count: 2 * n)
            done += n
        }
    }

    /// One input's samples in the block: its buffer's data, its lane and stride there, and the
    /// frames the buffer really holds, whatever the frame count claims.
    private func source(_ buffers: UnsafeMutableAudioBufferListPointer, _ place: InputLanes.Lane,
                        frames: Int) -> (data: UnsafeMutablePointer<Float>, lane: Int, stride: Int, held: Int)? {
        guard place.buffer < buffers.count else { return nil }
        let buffer = buffers[place.buffer]
        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return nil }
        let stride = Swift.max(1, Int(buffer.mNumberChannels))
        guard place.lane < stride else { return nil }
        return (data, place.lane, stride, held(buffer, frames: frames, stride: stride))
    }

    /// Every input a track monitors, to the engine — whether or not a take runs.
    private func monitor(_ list: UnsafePointer<AudioBufferList>, frames: Int) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        let inputs = core.inputs
        // One block of every input at once: the render lines a pair's two sides up only between
        // two of them, never with one side written and the other not yet.
        inputs.writeBlock { copyMonitored(buffers, to: inputs, frames: frames) }
    }

    private func copyMonitored(_ buffers: UnsafeMutableAudioBufferListPointer, to inputs: InputMonitor, frames: Int) {
        if buffers.count > 1 {
            for (channel, buffer) in buffers.enumerated() where inputs.isWanted(channel) {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let stride = Swift.max(1, Int(buffer.mNumberChannels))
                copy(data, lane: 0, stride: stride, held: held(buffer, frames: frames, stride: stride)) {
                    inputs.write(channel: channel, $0, count: $1)
                }
            }
        } else if let buffer = buffers.first, let data = buffer.mData?.assumingMemoryBound(to: Float.self) {
            let stride = Swift.max(1, Int(buffer.mNumberChannels))
            for channel in 0..<Swift.min(stride, InputMonitor.channelLimit) where inputs.isWanted(channel) {
                copy(data, lane: channel, stride: stride, held: held(buffer, frames: frames, stride: stride)) {
                    inputs.write(channel: channel, $0, count: $1)
                }
            }
        }
    }

    /// Frames the buffer really holds, whatever the frame count claims.
    private func held(_ buffer: AudioBuffer, frames: Int, stride: Int) -> Int {
        Swift.min(frames, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * stride))
    }

    /// One channel of a buffer, de-interleaved through `scratch` when it must be.
    private func copy(_ data: UnsafeMutablePointer<Float>, lane: Int, stride: Int, held: Int,
                      to write: (UnsafePointer<Float>, Int) -> Void) {
        guard stride > 1 else {
            write(UnsafePointer(data), held)
            return
        }
        var done = 0
        while done < held {
            let n = Swift.min(held - done, Self.scratchFrames)
            for i in 0..<n { scratch[i] = data[(done + i) * stride + lane] }
            write(UnsafePointer(scratch), n)
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

/// Writes a take to a 32-bit float CAF file of one or two channels from the recorder's ring —
/// a pair arrives left, right side by side — off the main thread.
actor TakeWriter {
    enum WriterError: Error { case noFormat }

    /// 1 for one input, 2 for a pair.
    nonisolated let channels: Int
    private var file: AVAudioFile?
    private let chunk: AVAudioPCMBuffer
    /// A pair's samples as the ring holds them, before they are split into the two channels;
    /// empty for one input.
    private var woven: [Float]
    private let ring: AudioRing
    private var frames = 0
    /// A take may not outgrow what the song can load again: longer audio is never written, so
    /// the take ends at the limit instead of being refused whole when it is read back.
    private let maximumFrames: Int

    /// Whether the take reached the length limit and later input was dropped.
    private(set) var reachedLimit = false

    init(url: URL, sampleRate: Double, channels: Int, ring: AudioRing) throws {
        let width = channels == 2 ? 2 : 1
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: AVAudioChannelCount(width), interleaved: false),
              let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            throw WriterError.noFormat
        }
        file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32,
                               interleaved: false)
        self.chunk = chunk
        self.channels = width
        woven = [Float](repeating: 0, count: width == 2 ? 2 * Int(chunk.frameCapacity) : 0)
        self.ring = ring
        maximumFrames = Int(AudioFileImport.longestSeconds(atRate: sampleRate) * sampleRate)
        // A block that arrived as the previous take was stopped would otherwise open this one.
        ring.discardAvailable()
    }

    /// Writes whatever is waiting in the ring.
    func drain() throws {
        guard let file, let channelData = chunk.floatChannelData else { return }
        let data = channelData[0]
        let capacity = Int(chunk.frameCapacity)
        while true {
            // In frames: the ring holds whole ones, so a pair always reads an even count.
            let n: Int
            if channels == 2 {
                let right = channelData[1]
                let ring = ring
                n = woven.withUnsafeMutableBufferPointer { pair -> Int in
                    guard let base = pair.baseAddress else { return 0 }
                    let got = ring.read(into: base, count: 2 * capacity) / 2
                    for i in 0..<got {
                        data[i] = base[2 * i]
                        right[i] = base[2 * i + 1]
                    }
                    return got
                }
            } else {
                n = ring.read(into: data, count: capacity)
            }
            guard n > 0 else { return }
            let kept = Swift.min(n, Swift.max(0, maximumFrames - frames))
            if kept < n { reachedLimit = true }
            guard kept > 0 else { continue }
            chunk.frameLength = AVAudioFrameCount(kept)
            try file.write(from: chunk)
            frames += kept
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
    /// 1 for one input, 2 for a pair (`TakeWriter.channels`).
    let channels: Int
    /// See `InputRecorder.startPlayed`.
    let startPlayed: Int64
    /// Output plus input latency in samples, as the session reported it when the take began.
    let latency: Int64
    /// The tempo map the engine played when the take began — a followed clock's, not the song's,
    /// while following one. `startSample` was stamped against it, so the take is placed with it:
    /// the map at the stop may be a drifted clock's, under which the same sample is a later tick
    /// (`RecordingPlacement`, review 2026-10-28, 2.2).
    let tempoMap: TempoMap
    /// The loop the song ran over while the take recorded, nil while it did not loop; and
    /// `EngineCore.playedFrames` at each of its wraps. The take's passes are cut from them.
    let loop: Range<Tick>?
    let wraps: [Int64]
}

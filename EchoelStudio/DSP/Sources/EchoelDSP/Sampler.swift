import Foundation

/// One audio sample in memory, ready to play: mono frames at the rate it was recorded, and
/// the key it sounds at unshifted. Built off the render thread; the frames are written once in
/// `init` and never again, so the render thread reads them without a lock.
///
/// The frames live in manual memory, not a Swift array, so reading them never retains or
/// copies anything. The owner must keep the buffer alive while any `Sampler` plays it, and
/// must release it off the render thread (the engine does both, as it does for snapshots).
public final class SampleBuffer: @unchecked Sendable {
    public let frameCount: Int
    public let sampleRate: Double
    /// The MIDI note that plays the sample at its original speed.
    public let rootPitch: UInt8
    let frames: UnsafeMutablePointer<Float>

    /// Copies `samples`; non-finite values become silence. Nil for an empty sample or a
    /// sample rate that is not a positive number.
    public init?(samples: [Float], sampleRate: Double, rootPitch: UInt8 = 60) {
        guard !samples.isEmpty, sampleRate.isFinite, sampleRate > 0 else { return nil }
        frameCount = samples.count
        self.sampleRate = sampleRate
        self.rootPitch = Swift.min(rootPitch, 127)
        frames = .allocate(capacity: samples.count)
        for (i, s) in samples.enumerated() { (frames + i).initialize(to: s.isFinite ? s : 0) }
    }

    deinit {
        frames.deinitialize(count: frameCount)
        frames.deallocate()
    }
}

extension SampleBuffer {
    /// Adds a stretch of the sample — `length` frames from frame `offset` — into `buffer`, as
    /// heard `elapsed` output frames after the stretch began, advancing `step` sample frames per
    /// output frame with linear interpolation. Output frames before the stretch or after its end
    /// (or the sample's) add nothing. Each read position is computed from its output index, never
    /// accumulated, so the result does not depend on how the output is split into blocks.
    /// Within `fade` sample frames of either edge the level ramps from silence, so a stretch
    /// that starts or stops mid-waveform never clicks. Render-thread safe.
    public func add(into buffer: UnsafeMutableBufferPointer<Float>, elapsed: Int64, step: Double,
                    offset: Double, length: Double, fade: Double) {
        guard step.isFinite, step > 0, offset.isFinite, offset >= 0, length.isFinite, length > 0 else { return }
        let stop = Swift.min(offset + length, Double(frameCount))
        for i in buffer.indices {
            let frame = elapsed + Int64(i)
            guard frame >= 0 else { continue }
            let read = offset + Double(frame) * step
            guard read < stop else { return }
            let index = Int(read)
            let a = frames[index]
            let b = index + 1 < frameCount ? frames[index + 1] : a
            var value = a + (b - a) * Float(read - Double(index))
            if fade > 0 {
                let edge = Swift.min(read - offset, stop - read)
                if edge < fade { value *= Float(edge / fade) }
            }
            buffer[i] += value
        }
    }
}

public struct SamplerPatch: Equatable, Sendable {
    public var envelope: Envelope.Settings
    /// Play to the end of the sample regardless of note-off — the drum-pad behaviour.
    public var oneShot: Bool
    public var level: Float

    public init(envelope: Envelope.Settings = .init(attack: 0.001, decay: 0.1, sustain: 1, release: 0.15),
                oneShot: Bool = false, level: Float = 0.8) {
        self.envelope = envelope
        self.oneShot = oneShot
        self.level = level
    }
}

/// A polyphonic sample player: each note plays the sample transposed by its distance from
/// the root note, with linear interpolation and an amplitude envelope. Fixed voices, all
/// allocated in `init`; nothing allocates while rendering.
public struct Sampler: Sendable {
    public static let defaultVoiceCount = 16

    public private(set) var patch: SamplerPatch
    private var sample: SampleBuffer?
    private var voices: [SamplerVoice]
    private let sampleRate: Float
    private var nextOrder: UInt64 = 0

    public init(patch: SamplerPatch = SamplerPatch(), voiceCount: Int = defaultVoiceCount, sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.patch = patch
        self.sampleRate = rate
        voices = Array(repeating: SamplerVoice(envelope: patch.envelope, sampleRate: rate), count: Swift.max(1, voiceCount))
    }

    public var activeVoiceCount: Int { voices.reduce(0) { $0 + ($1.isActive ? 1 : 0) } }

    /// Swaps the sample. Every sounding voice stops at once: its read position belonged to the
    /// old sample. The caller keeps the old buffer alive until it knows rendering moved on.
    public mutating func setSample(_ buffer: SampleBuffer?) {
        guard buffer !== sample else { return }
        sample = buffer
        for i in voices.indices { voices[i].silence() }
    }

    public mutating func setPatch(_ patch: SamplerPatch) {
        self.patch = patch
        for i in voices.indices { voices[i].envelope.update(patch.envelope) }
    }

    public mutating func noteOn(pitch: UInt8, velocity: UInt8) {
        guard let sample, velocity > 0 else { return }
        nextOrder &+= 1
        let index = voiceIndex(for: pitch)
        let semitones = Double(Int(Swift.min(pitch, 127)) - Int(sample.rootPitch))
        let increment = sample.sampleRate / Double(sampleRate) * Foundation.pow(2, semitones / 12)
        voices[index].start(pitch: pitch, velocity: velocity, increment: increment, order: nextOrder)
    }

    public mutating func noteOff(pitch: UInt8) {
        guard !patch.oneShot else { return }
        for i in voices.indices where voices[i].isActive && voices[i].isHeld && voices[i].pitch == pitch {
            voices[i].release()
        }
    }

    public mutating func allNotesOff() {
        guard !patch.oneShot else { return }
        for i in voices.indices where voices[i].isHeld { voices[i].release() }
    }

    public mutating func reset() {
        for i in voices.indices { voices[i].silence() }
    }

    /// Adds every sounding voice into `buffer`; the caller clears it first.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard let sample, !buffer.isEmpty else { return }
        let level = patch.level.isFinite ? Swift.min(Swift.max(patch.level, 0), 1) : 0
        voices.withUnsafeMutableBufferPointer { all in
            for i in all.indices where all[i].isActive {
                all[i].render(into: buffer, sample: sample, level: level)
            }
        }
    }

    private func voiceIndex(for pitch: UInt8) -> Int {
        var free: Int?
        var oldest: (index: Int, order: UInt64)?
        for (i, voice) in voices.enumerated() {
            if !voice.isActive {
                if free == nil { free = i }
            } else if oldest.map({ voice.startOrder < $0.order }) ?? true {
                oldest = (i, voice.startOrder)
            }
        }
        return free ?? oldest?.index ?? 0
    }
}

struct SamplerVoice: Sendable {
    private(set) var pitch: UInt8 = 0
    private(set) var isHeld = false
    private(set) var startOrder: UInt64 = 0
    var envelope: Envelope
    private var position: Double = 0
    private var increment: Double = 0
    private var gain: Float = 0

    init(envelope: Envelope.Settings, sampleRate: Float) {
        self.envelope = Envelope(settings: envelope, sampleRate: sampleRate)
    }

    var isActive: Bool { envelope.isActive }

    mutating func start(pitch: UInt8, velocity: UInt8, increment: Double, order: UInt64) {
        self.pitch = pitch
        isHeld = true
        startOrder = order
        self.increment = increment.isFinite && increment > 0 ? increment : 1
        position = 0
        let v = Float(Swift.min(velocity, 127)) / 127
        gain = v * v
        envelope.kill()
        envelope.gateOn()
    }

    mutating func release() {
        isHeld = false
        envelope.gateOff()
    }

    mutating func silence() {
        isHeld = false
        envelope.kill()
    }

    @inline(__always)
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sample: SampleBuffer, level: Float) {
        let last = sample.frameCount - 1
        for i in buffer.indices {
            let index = Int(position)
            guard index < last || (index == last && position == Double(last)) else {
                silence()
                return
            }
            let a = sample.frames[index]
            let b = index < last ? sample.frames[index + 1] : a
            let t = Float(position - Double(index))
            buffer[i] += (a + (b - a) * t) * envelope.next() * gain * level
            position += increment
            if !envelope.isActive { return }
        }
    }
}

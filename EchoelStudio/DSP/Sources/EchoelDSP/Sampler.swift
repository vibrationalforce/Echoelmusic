import Foundation

/// One audio sample in memory, ready to play: mono frames at the rate it was recorded, and
/// the key it sounds at unshifted. Built off the render thread; the frames are written once in
/// `init` and never again, so the render thread reads them without a lock.
///
/// The frames live in manual memory (`malloc`, so a short fill can hand its unwritten room back),
/// not a Swift array, so reading them never retains or copies anything. The owner must keep the
/// buffer alive while any `Sampler` plays it, and must release it off the render thread (the
/// engine does both, as it does for snapshots).
public final class SampleBuffer: @unchecked Sendable {
    public let frameCount: Int
    /// The frames the buffer holds in memory: what the allocator keeps for its block — `frameCount`
    /// up to the allocator's next size after a shrink, or the whole room a short fill was given
    /// when it was kept (see `init(capacity:…)`). A memory plan counts this.
    public let heldFrames: Int
    /// The frames that are initialized, which `deinit` releases: `frameCount` after a shrink, the
    /// whole room otherwise.
    private let initializedFrames: Int
    public let sampleRate: Double
    /// The MIDI note that plays the sample at its original speed.
    public let rootPitch: UInt8
    let frames: UnsafeMutablePointer<Float>

    /// Copies `samples`; non-finite values become silence. Nil for an empty sample or a
    /// sample rate that is not a positive number.
    public init?(samples: [Float], sampleRate: Double, rootPitch: UInt8 = 60) {
        guard !samples.isEmpty, sampleRate.isFinite, sampleRate > 0,
              let storage = Self.allocate(samples.count) else { return nil }
        frameCount = samples.count
        heldFrames = samples.count
        initializedFrames = samples.count
        self.sampleRate = sampleRate
        self.rootPitch = Swift.min(rootPitch, 127)
        frames = storage
        for (i, s) in samples.enumerated() { (frames + i).initialize(to: s.isFinite ? s : 0) }
    }

    /// Allocates `capacity` frames and lets `fill` write them where they stay, keeping the count it
    /// returns (at most `capacity`); non-finite values become silence. A file decoded straight into
    /// the buffer is held in memory once — decoded into an array and copied, it briefly cost twice
    /// its size (second night review, 2026-10-23). When `fill` writes fewer frames than `capacity`
    /// (a file whose header promised more than it holds) and at most half of them, `realloc` gives
    /// the room back where it is, so the peak stays near the size the header asked for, the size a
    /// song's memory plan checks before the decode — a copy into a block of its own size put up to
    /// half that room above the budget (eighth night review, as 9d8b08152 had said once before).
    /// Only a shrink into a smaller size class makes the allocator copy, and then at most that
    /// class's largest block (ninth night review). `heldFrames` is then read from the block itself on
    /// Darwin, whose `realloc` rounds both sizes and keeps a block that would shrink by less than
    /// half of its rounded size — a fill just under half stays whole there, and counted as shrunk it
    /// was a count that lies (seventh night review). Above half the block stays whole and is counted
    /// whole. Nil when `fill` writes no frame or the rate is not a positive number; throws
    /// `OutOfMemory` when the memory is not there, and an error from `fill` on.
    public init?(capacity: Int, sampleRate: Double, rootPitch: UInt8 = 60,
                 fill: (UnsafeMutableBufferPointer<Float>) throws -> Int) throws {
        guard capacity > 0, sampleRate.isFinite, sampleRate > 0 else { return nil }
        guard let storage = Self.allocate(capacity) else { throw OutOfMemory() }
        storage.initialize(repeating: 0, count: capacity)
        let written: Int
        do {
            written = Swift.min(capacity, Swift.max(0, try fill(UnsafeMutableBufferPointer(start: storage, count: capacity))))
        } catch {
            storage.deinitialize(count: capacity)
            free(storage)
            throw error
        }
        guard written > 0 else {
            storage.deinitialize(count: capacity)
            free(storage)
            return nil
        }
        for i in 0..<written where !storage[i].isFinite { storage[i] = 0 }
        var kept = storage
        var held = capacity
        var initialized = capacity
        if written <= capacity / 2 {
            (storage + written).deinitialize(count: capacity - written)
            if let shrunk = realloc(storage, written * MemoryLayout<Float>.stride) {
                kept = shrunk.bindMemory(to: Float.self, capacity: written)
                initialized = written
                held = Self.framesHeld(by: kept, asked: written, whole: capacity)
            } else {
                // Refused: the block stays as it was, and is counted.
                (storage + written).initialize(repeating: 0, count: capacity - written)
            }
        }
        frameCount = written
        heldFrames = held
        initializedFrames = initialized
        self.sampleRate = sampleRate
        self.rootPitch = Swift.min(rootPitch, 127)
        frames = kept
    }

    /// A copy of the frames, for saving the sample. Allocates: never on the render thread.
    public func copyFrames() -> [Float] {
        Array(UnsafeBufferPointer(start: frames, count: frameCount))
    }

    /// The frames read where they are, valid only inside `body` — for saving the sample as bytes
    /// without an array on the way, where memory is tight (the plugin extension).
    public func withFrames<Value>(_ body: (UnsafeBufferPointer<Float>) throws -> Value) rethrows -> Value {
        try body(UnsafeBufferPointer(start: frames, count: frameCount))
    }

    /// The memory a sample asked for was not there, or its size does not fit in an `Int`: a file
    /// that is readable, only not here and now — said as such, not as a file with no audio.
    public struct OutOfMemory: Error, Equatable {
        public init() {}
    }

    /// The frames the allocator holds for `block`, shrunk by `realloc` to `asked` from `whole`: on
    /// Darwin the block's own size, which can be the whole block (see `init(capacity:…)`);
    /// elsewhere the shrink is taken at its word.
    private static func framesHeld(by block: UnsafeMutablePointer<Float>, asked: Int, whole: Int) -> Int {
        #if canImport(Darwin)
        return Swift.min(whole, Swift.max(asked, malloc_size(block) / MemoryLayout<Float>.stride))
        #else
        return asked
        #endif
    }

    /// `count` frames from `malloc`, which `realloc` can shrink and `deinit` frees; nil when the
    /// size overflows or the memory is not there.
    private static func allocate(_ count: Int) -> UnsafeMutablePointer<Float>? {
        let (bytes, overflow) = count.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
        guard !overflow, let raw = malloc(bytes) else { return nil }
        return raw.bindMemory(to: Float.self, capacity: count)
    }

    deinit {
        frames.deinitialize(count: initializedFrames)
        free(frames)
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

/// One started note: the voice it sounds on and the start that put it there. A voice is reused
/// when it is stolen, reset or the sample is swapped, and every start has its own `order`, so a
/// handle kept past that moment names nothing and releasing it does nothing. Two notes of the
/// same pitch have two handles, so one can end without the other (Codex handover S2, 2026-10-26).
public struct SamplerVoiceHandle: Equatable, Sendable {
    let index: Int
    let order: UInt64
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
    /// The level the voices play at. It glides toward `patch.level` in about 5 ms, as the synth's
    /// level and the kit's do, so a moved or automated level never steps; a note on a silent
    /// sampler starts at the level instead of gliding to it.
    private var levelNow: Float
    private let levelGlide: Float

    public init(patch: SamplerPatch = SamplerPatch(), voiceCount: Int = defaultVoiceCount, sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.patch = patch
        self.sampleRate = rate
        voices = Array(repeating: SamplerVoice(envelope: patch.envelope, sampleRate: rate), count: Swift.max(1, voiceCount))
        levelNow = Self.playable(patch.level)
        levelGlide = 1 - expf(-1 / (0.005 * rate))
    }

    /// A level the voices can play: 0 … 1, and silence for a value that is not finite.
    private static func playable(_ level: Float) -> Float {
        level.isFinite ? Swift.min(Swift.max(level, 0), 1) : 0
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
        if activeVoiceCount == 0 { levelNow = Self.playable(patch.level) }
    }

    /// Starts a note and names the voice it sounds on; nil when nothing starts (no sample, or
    /// velocity 0). Callers that end notes by pitch can ignore the handle.
    @discardableResult
    public mutating func noteOn(pitch: UInt8, velocity: UInt8) -> SamplerVoiceHandle? {
        guard let sample, velocity > 0 else { return nil }
        if activeVoiceCount == 0 { levelNow = Self.playable(patch.level) }
        nextOrder &+= 1
        let index = voiceIndex(for: pitch)
        let semitones = Double(Int(Swift.min(pitch, 127)) - Int(sample.rootPitch))
        let increment = sample.sampleRate / Double(sampleRate) * Foundation.pow(2, semitones / 12)
        voices[index].start(pitch: pitch, velocity: velocity, increment: increment, order: nextOrder)
        return SamplerVoiceHandle(index: index, order: nextOrder)
    }

    /// Whether the note `handle` started still sounds held: false once released, stolen, reset,
    /// or the sample was swapped.
    public func isHolding(_ handle: SamplerVoiceHandle) -> Bool {
        guard voices.indices.contains(handle.index) else { return false }
        let voice = voices[handle.index]
        return voice.isActive && voice.isHeld && voice.startOrder == handle.order
    }

    /// Releases the one note `handle` started, and no other voice of the same pitch. A handle
    /// whose voice has moved on does nothing. A one-shot plays out, as with `noteOff(pitch:)`.
    public mutating func noteOff(_ handle: SamplerVoiceHandle) {
        guard !patch.oneShot, isHolding(handle) else { return }
        voices[handle.index].release()
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

    /// Adds every sounding voice into `buffer`; the caller clears it first. While the level
    /// glides it moves in a straight line across the buffer; at rest every frame gets the level
    /// itself, exactly.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard let sample, !buffer.isEmpty else { return }
        let target = Self.playable(patch.level)
        let start = levelNow
        var step: Float = 0
        if start != target {
            var end = target + (start - target) * powf(1 - levelGlide, Float(buffer.count))
            // A Float glide stalls just short of its target; close enough is the target.
            if Swift.abs(end - target) < 1e-6 || !end.isFinite { end = target }
            step = (end - start) / Float(buffer.count)
            levelNow = end
        }
        voices.withUnsafeMutableBufferPointer { all in
            for i in all.indices where all[i].isActive {
                all[i].render(into: buffer, sample: sample, level: start, step: step)
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
    /// A stolen voice first fades out what it was playing — its read position would jump, a
    /// click (ultra-audit A9) — and starts the new note when the fade has run: `fadeLeft` frames
    /// of the old note, from `fadePosition` at `fadeIncrement`, at the level it had when stolen.
    private var fadeLeft = 0
    private var fadePosition: Double = 0
    private var fadeIncrement: Double = 0
    private var fadeGain: Float = 0
    /// 2.7 ms at 48 kHz: long enough not to click, short enough not to be heard as a delay.
    static let stealFadeFrames = 128
    /// Output frames over which a voice that reaches its sample's end fades to 0, as an audio
    /// region's edge does: a sample cut mid-waveform otherwise fell from its last frame to 0 in
    /// one sample, a click at the end of every one-shot (audit 2026-10-23).
    static let endFadeFrames = 64

    init(envelope: Envelope.Settings, sampleRate: Float) {
        self.envelope = Envelope(settings: envelope, sampleRate: sampleRate)
    }

    var isActive: Bool { envelope.isActive || fadeLeft > 0 }

    mutating func start(pitch: UInt8, velocity: UInt8, increment: Double, order: UInt64) {
        let stolen = envelope.isActive
        if stolen {
            fadeLeft = Self.stealFadeFrames
            fadePosition = position
            fadeIncrement = self.increment
            fadeGain = gain * envelope.level
        }
        self.pitch = pitch
        isHeld = true
        startOrder = order
        self.increment = increment.isFinite && increment > 0 ? increment : 1
        position = 0
        let v = Float(Swift.min(velocity, 127)) / 127
        gain = v * v
        envelope.kill()
        if !stolen { envelope.gateOn() }
    }

    mutating func release() {
        isHeld = false
        envelope.gateOff()
    }

    mutating func silence() {
        isHeld = false
        fadeLeft = 0
        envelope.kill()
    }

    /// Frame `i` of `buffer` plays at `level + step × i`.
    @inline(__always)
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sample: SampleBuffer, level: Float, step: Float) {
        let last = sample.frameCount - 1
        var first = buffer.startIndex
        if fadeLeft > 0 {
            let fadeEndScale = 1 / (Double(Self.endFadeFrames) * fadeIncrement)
            let end = Swift.min(first + fadeLeft, buffer.endIndex)
            while first < end {
                let index = Int(fadePosition)
                guard index < last || (index == last && fadePosition == Double(last)) else {
                    fadeLeft = 0
                    break
                }
                let a = sample.frames[index]
                let b = index < last ? sample.frames[index + 1] : a
                let t = Float(fadePosition - Double(index))
                let ramp = Float(fadeLeft) / Float(Self.stealFadeFrames)
                    * Float(Swift.min(1, (Double(last) - fadePosition) * fadeEndScale))
                buffer[first] += (a + (b - a) * t) * fadeGain * ramp * (level + step * Float(first - buffer.startIndex))
                fadePosition += fadeIncrement
                fadeLeft -= 1
                first += 1
            }
            guard fadeLeft == 0 else { return }
            // Faded out: the new note starts here — released at once if its key already came up.
            envelope.gateOn()
            if !isHeld { envelope.gateOff() }
        }
        let endScale = 1 / (Double(Self.endFadeFrames) * increment)
        for i in first..<buffer.endIndex {
            let index = Int(position)
            guard index < last || (index == last && position == Double(last)) else {
                silence()
                return
            }
            let a = sample.frames[index]
            let b = index < last ? sample.frames[index + 1] : a
            let t = Float(position - Double(index))
            let toEnd = Float(Swift.min(1, (Double(last) - position) * endScale))
            buffer[i] += (a + (b - a) * t) * envelope.next() * gain * toEnd * (level + step * Float(i - buffer.startIndex))
            position += increment
            if !envelope.isActive { return }
        }
    }
}

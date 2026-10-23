import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// An instrument kernel that plays a sample the user chooses.
public protocol SampleLoadingKernel: InstrumentKernel {
    /// Hands `buffer` (or no sample) to the render thread. Call from one thread at a time,
    /// never the render thread. False when the render thread has fallen 63 loads behind — it
    /// is not running; the caller keeps the sample and offers it again.
    @discardableResult func load(_ buffer: SampleBuffer?) -> Bool
}

/// The built-in sampler as a plugin plays it: notes transpose the sample from its root key,
/// with attack, release, level and gate/one-shot. Shared by the Echoel Sampler Audio Unit and
/// its tests. Nothing allocates on the render thread.
///
/// A new sample reaches the render thread through a ring of slots and a sequence number; the
/// loading side keeps every buffer it handed over alive until the render thread has moved past
/// it, so no buffer is ever freed on the render thread or freed while it might still be read.
public final class SamplerKernel: SampleLoadingKernel, @unchecked Sendable {
    /// The sampler's Core table (`InstrumentDevice.sampler`); the address of a row is its index.
    public static let parameters = InstrumentDevice.sampler.parameters.map(InstrumentKernelParameter.init)
    /// Computed, not stored: the render thread reads it, and a stored static is a lazy global.
    private static var ringSize: Int { 64 }

    /// Where each row sits, looked up by its Core key once, in `init`.
    private let rootAddress: Int, attackAddress: Int, releaseAddress: Int, levelAddress: Int, modeAddress: Int
    /// What the table does not set (decay and sustain), copied once from `SamplerPatch()` — the
    /// counterpart of `SynthPatch.parameterBase`. At the table's defaults the kernel plays exactly
    /// `SamplerPatch()`.
    private let base = SamplerPatch()

    public let sampleRate: Double
    public let maximumFrames: Int

    private let values: UnsafeMutablePointer<Float>
    private let ranges: [ClosedRange<Float>]
    private let version = Atomic<UInt64>(0)
    private var appliedVersion: UInt64 = .max
    private var sampler: Sampler
    private let mono: UnsafeMutablePointer<Float>
    /// Notes are shifted so the sample's root key plays it at its own speed.
    private var transpose = 0
    /// Where each held note sounded, so its note-off finds it after the root key moved.
    private let sounding: UnsafeMutablePointer<UInt8>

    // The sample hand-over.
    private let slots: UnsafeMutablePointer<UnsafeMutableRawPointer?>
    private let published = Atomic<Int>(0)
    private let installed = Atomic<Int>(0)
    private var renderSequence = 0
    private var nextSequence = 0
    private var held: [(sequence: Int, buffer: SampleBuffer)] = []

    public init(sampleRate: Double, maximumFrames: Int = 4_096) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.maximumFrames = Swift.max(1, maximumFrames)
        ranges = Self.parameters.map { Float($0.range.lowerBound)...Float($0.range.upperBound) }
        rootAddress = Self.address(of: .samplerRoot)
        attackAddress = Self.address(of: .samplerAttack)
        releaseAddress = Self.address(of: .samplerRelease)
        levelAddress = Self.address(of: .samplerLevel)
        modeAddress = Self.address(of: .samplerMode)
        values = .allocate(capacity: Self.parameters.count)
        for (i, parameter) in Self.parameters.enumerated() { values[i] = Float(parameter.defaultValue) }
        sampler = Sampler(sampleRate: Float(rate))
        mono = .allocate(capacity: self.maximumFrames)
        mono.initialize(repeating: 0, count: self.maximumFrames)
        sounding = .allocate(capacity: 128)
        // Each key starts as itself, so a note-off for a key that never sounded releases its own
        // pitch (nothing), not pitch 0 — what the app's engine always did.
        for key in 0..<128 { (sounding + key).initialize(to: UInt8(key)) }
        slots = .allocate(capacity: Self.ringSize)
        slots.initialize(repeating: nil, count: Self.ringSize)
    }

    deinit {
        values.deallocate()
        mono.deallocate()
        sounding.deallocate()
        slots.deallocate()
    }

    /// Any thread. Clamped to the parameter's range; a value that is not finite is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard address >= 0, address < ranges.count, value.isFinite else { return }
        let range = ranges[address]
        values[address] = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        version.add(1, ordering: .releasing)
    }

    public func parameter(_ address: Int) -> Float {
        address >= 0 && address < ranges.count ? values[address] : 0
    }

    /// The row's index in the table. Every sampler row is in it (`InstrumentTablesTests`), so the
    /// fallback 0 only keeps a broken table memory-safe on the render thread.
    private static func address(of row: InstrumentParameter) -> Int {
        InstrumentDevice.sampler.parameters.firstIndex { $0.key == row.key } ?? 0
    }

    @discardableResult public func load(_ buffer: SampleBuffer?) -> Bool {
        let done = installed.load(ordering: .acquiring)
        held.removeAll { $0.sequence < done }
        guard nextSequence + 1 - done < Self.ringSize else { return false }
        nextSequence += 1
        slots[nextSequence % Self.ringSize] = buffer.map { Unmanaged.passUnretained($0).toOpaque() }
        if let buffer { held.append((nextSequence, buffer)) }
        published.store(nextSequence, ordering: .releasing)
        return true
    }

    // MARK: - Render thread

    public func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        let note = Int(data1 & 0x7F)
        switch status & 0xF0 {
        case 0x90 where data2 & 0x7F > 0:
            // A host sends a change and a note at the same offset before any render: the note
            // hears the root key, the patch and the sample that came with it (audit 2026-10-23).
            // Both are one atomic compare when nothing changed.
            takeNewSample()
            commitParameters()
            let pitch = UInt8(Swift.min(Swift.max(note + transpose, 0), 127))
            sounding[note] = pitch
            sampler.noteOn(pitch: pitch, velocity: data2 & 0x7F)
        case 0x80, 0x90:
            sampler.noteOff(pitch: sounding[note])
        case 0xB0 where data1 == 123: sampler.allNotesOff()
        case 0xB0 where data1 == 120: sampler.reset()
        default: break
        }
    }

    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain: Float) {
        takeNewSample()
        commitParameters()
        var done = 0
        while done < frames {
            let n = Swift.min(frames - done, maximumFrames)
            mono.update(repeating: 0, count: n)
            sampler.render(into: UnsafeMutableBufferPointer(start: mono, count: n))
            for i in 0..<n {
                let sample = mono[i].isFinite ? mono[i] * gain : 0
                left[done + i] = sample
                right[done + i] = sample
            }
            done += n
        }
    }

    /// Render thread. Applies values set since the last call, so the next note already hears them.
    public func commitParameters() {
        let current = version.load(ordering: .acquiring)
        guard current != appliedVersion else { return }
        appliedVersion = current
        applyPatch()
    }

    /// Render thread. Whether a voice is sounding.
    public var isSounding: Bool { sampler.activeVoiceCount > 0 }

    /// Render thread. All sound off (CC 120).
    public func reset() { sampler.reset() }

    /// Render thread, for the app's engine: plays `buffer` from now on (nil: no sample). The caller
    /// owns the buffer's lifetime and keeps it alive until it knows rendering moved on — the engine
    /// already does that for its snapshot. Never mix this with `load` on one kernel: `load` keeps
    /// its own list of buffers and would not know about this one.
    public func assign(_ buffer: SampleBuffer?) {
        sampler.setSample(buffer)
    }

    private func takeNewSample() {
        let newest = published.load(ordering: .acquiring)
        guard newest != renderSequence else { return }
        renderSequence = newest
        let buffer = slots[newest % Self.ringSize].map { Unmanaged<SampleBuffer>.fromOpaque($0).takeUnretainedValue() }
        sampler.setSample(buffer)
        installed.store(newest, ordering: .releasing)
    }

    private func applyPatch() {
        // The sampler plays its buffer's root (60) unshifted; the root key moves every note.
        transpose = 60 - Int(values[rootAddress].rounded())
        var patch = base
        patch.envelope.attack = values[attackAddress]
        patch.envelope.release = values[releaseAddress]
        patch.oneShot = values[modeAddress] >= 0.5
        patch.level = values[levelAddress]
        sampler.setPatch(patch)
    }
}

import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The built-in synth as a plugin plays it: the parameters of `SynthParameter.all` by index,
/// MIDI bytes in, stereo out. Shared by the Echoel Synth Audio Unit and its tests.
///
/// Threading: `setParameter` may be called from any thread (host automation, the plugin's view);
/// it writes one float and raises a version the render thread compares. Everything else is the
/// render thread's. Nothing allocates after `init`.
public final class SynthKernel: @unchecked Sendable {
    /// The patch parameters by index; `parameters` (InstrumentKernel) publishes the same list.
    static let patchParameters = SynthParameter.all
    public let sampleRate: Double

    private let values: UnsafeMutablePointer<Float>
    private let version = Atomic<UInt64>(0)
    private var appliedVersion: UInt64 = .max
    private var synth: PolySynth
    private let mono: UnsafeMutablePointer<Float>
    public let maximumFrames: Int
    /// The patch field each value sets, looked up once: the render thread never touches a lazily
    /// initialised global or an array it could retain.
    private let fields: UnsafeMutablePointer<PatchField?>
    /// `SynthPatch.parameterBase`, copied once for the same reason.
    private let base: SynthPatch
    private let count: Int
    private let ranges: [ClosedRange<Float>]

    public init(sampleRate: Double, maximumFrames: Int = 4_096) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.maximumFrames = Swift.max(1, maximumFrames)
        count = Self.patchParameters.count
        base = SynthPatch.parameterBase
        fields = .allocate(capacity: Self.patchParameters.count)
        for (i, parameter) in Self.patchParameters.enumerated() { (fields + i).initialize(to: PatchField(parameter.key)) }
        ranges = Self.patchParameters.map { Float($0.range.lowerBound)...Float($0.range.upperBound) }
        values = .allocate(capacity: Self.patchParameters.count)
        for (i, parameter) in Self.patchParameters.enumerated() { values[i] = Float(parameter.defaultValue) }
        synth = PolySynth(sampleRate: Float(rate))
        mono = .allocate(capacity: self.maximumFrames)
        mono.initialize(repeating: 0, count: self.maximumFrames)
    }

    deinit {
        values.deallocate()
        fields.deinitialize(count: count)
        fields.deallocate()
        mono.deallocate()
    }

    /// Any thread. A value outside the parameter's range is clamped; one that is not finite is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard address >= 0, address < count, value.isFinite else { return }
        let range = ranges[address]
        values[address] = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        version.add(1, ordering: .releasing)
    }

    public func parameter(_ address: Int) -> Float {
        address >= 0 && address < count ? values[address] : 0
    }

    // MARK: - Render thread

    /// One MIDI 1.0 channel message: note on/off, all notes off (CC 123), all sound off (CC 120).
    public func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        switch status & 0xF0 {
        case 0x90: synth.noteOn(pitch: data1 & 0x7F, velocity: data2 & 0x7F)
        case 0x80: synth.noteOff(pitch: data1 & 0x7F)
        case 0xB0 where data1 == 123: synth.allNotesOff()
        case 0xB0 where data1 == 120: synth.reset()
        default: break
        }
    }

    /// Writes `frames` into `left` and `right` (overwriting them). `gain` scales the output, for
    /// the plugin's demo mode.
    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain: Float = 1) {
        let current = version.load(ordering: .acquiring)
        if current != appliedVersion {
            appliedVersion = current
            synth.setPatch(patch())
        }
        var done = 0
        while done < frames {
            let n = Swift.min(frames - done, maximumFrames)
            mono.update(repeating: 0, count: n)
            synth.render(into: UnsafeMutableBufferPointer(start: mono, count: n))
            for i in 0..<n {
                let sample = mono[i].isFinite ? mono[i] * gain : 0
                left[done + i] = sample
                right[done + i] = sample
            }
            done += n
        }
    }

    /// The patch for the current values, through the same `PatchField` mapping a song's track
    /// uses — arithmetic only, so the render thread may build it.
    private func patch() -> SynthPatch {
        var patch = base
        for i in 0..<count {
            fields[i]?.apply(Double(values[i]), to: &patch)
        }
        return patch
    }
}

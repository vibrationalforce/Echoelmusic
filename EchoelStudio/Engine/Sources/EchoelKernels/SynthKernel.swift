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
    /// A host's parameter ramp, per address, run by the render thread (`rampParameter`): where it
    /// goes, how far each frame moves it, the frames left, and the value it wrote last — a value
    /// set since from another thread (the plugin's view) is newer than the ramp and ends it.
    private let rampTarget: UnsafeMutablePointer<Float>
    private let rampStep: UnsafeMutablePointer<Float>
    private let rampFrames: UnsafeMutablePointer<Int>
    private let rampWritten: UnsafeMutablePointer<Float>
    /// Whether an address may glide: a choice (engine, waveform, filter) takes its value at once.
    private let ramps: UnsafeMutablePointer<Bool>
    private var activeRamps = 0
    /// A running ramp moves the values in steps of this many frames (0.67 ms at 48 kHz): finer
    /// than any control the voices read, coarse enough that the patch is not rebuilt per sample.
    static let rampStepFrames = 32

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
        rampTarget = .allocate(capacity: count)
        rampTarget.initialize(repeating: 0, count: count)
        rampStep = .allocate(capacity: count)
        rampStep.initialize(repeating: 0, count: count)
        rampFrames = .allocate(capacity: count)
        rampFrames.initialize(repeating: 0, count: count)
        rampWritten = .allocate(capacity: count)
        rampWritten.initialize(repeating: 0, count: count)
        ramps = .allocate(capacity: count)
        for (i, parameter) in Self.patchParameters.enumerated() { ramps[i] = parameter.taper != .stepped }
    }

    deinit {
        values.deallocate()
        fields.deinitialize(count: count)
        fields.deallocate()
        mono.deallocate()
        rampTarget.deallocate()
        rampStep.deallocate()
        rampFrames.deallocate()
        rampWritten.deallocate()
        ramps.deallocate()
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

    /// Render thread: a host's parameter ramp (`AURenderEventParameterRamp`) — `address` moves from
    /// where it is to `value` over `frames` frames of the following renders, in straight steps,
    /// instead of jumping to its end at once (audit 2026-11-04). A choice takes its value at once,
    /// and so does a ramp of no length.
    public func rampParameter(_ address: Int, to value: Float, frames: Int) {
        guard address >= 0, address < count, value.isFinite else { return }
        guard frames > 0, ramps[address] else {
            if rampFrames[address] > 0 { rampFrames[address] = 0; activeRamps -= 1 }
            setParameter(address, value)
            return
        }
        let range = ranges[address]
        let goal = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        if rampFrames[address] == 0 { activeRamps += 1 }
        rampTarget[address] = goal
        rampStep[address] = (goal - values[address]) / Float(frames)
        rampFrames[address] = frames
        rampWritten[address] = values[address]
    }

    /// Moves every running ramp on by `frames`.
    private func advanceRamps(by frames: Int) {
        var moved = false
        for i in 0..<count where rampFrames[i] > 0 {
            if values[i] != rampWritten[i] {
                // Set from elsewhere since the ramp began: that value stands.
                rampFrames[i] = 0
                activeRamps -= 1
                continue
            }
            let step = Swift.min(frames, rampFrames[i])
            rampFrames[i] -= step
            values[i] = rampFrames[i] == 0 ? rampTarget[i] : values[i] + rampStep[i] * Float(step)
            rampWritten[i] = values[i]
            if rampFrames[i] == 0 { activeRamps -= 1 }
            moved = true
        }
        if moved { version.add(1, ordering: .releasing) }
    }

    /// One MIDI 1.0 channel message: note on/off, the pitch wheel, and the controllers the synth
    /// reads (`PolySynth.controller` — modulation, sustain, all sound off, reset, all notes off),
    /// the same reading the app's engine uses.
    public func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        switch status & 0xF0 {
        case 0x90:
            // A value a host set at the note's own offset reaches the note, not the next render.
            commitParameters()
            synth.noteOn(pitch: data1 & 0x7F, velocity: data2 & 0x7F)
        case 0x80: synth.noteOff(pitch: data1 & 0x7F)
        case 0xB0: synth.controller(data1 & 0x7F, data2 & 0x7F)
        case 0xE0: synth.pitchBend(Int(data1 & 0x7F) | Int(data2 & 0x7F) << 7)
        default: break
        }
    }

    /// Writes `frames` into `left` and `right` (overwriting them). `gain` scales the output, for
    /// the plugin's demo mode.
    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain: Float = 1) {
        commitParameters()
        var done = 0
        while done < frames {
            var n = Swift.min(frames - done, maximumFrames)
            if activeRamps > 0 {
                // A ramp's next step reaches the voices before these frames sound.
                n = Swift.min(n, Self.rampStepFrames)
                advanceRamps(by: n)
                commitParameters()
            }
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

    /// Render thread. Applies values set since the last call. The patch reaches the synth only
    /// when it differs from the one it plays: `setPatch` restarts each voice's control-rate
    /// counter, so re-sending equal values would move the sound by a few samples.
    public func commitParameters() {
        let current = version.load(ordering: .acquiring)
        guard current != appliedVersion else { return }
        appliedVersion = current
        let next = patch()
        if next != synth.patch { synth.setPatch(next) }
    }

    /// Render thread. The tuning the next notes start in (`EngineInstrumentKernel.retune`).
    public func retune(_ temperament: Temperament) {
        if temperament != synth.temperament { synth.setTemperament(temperament) }
    }

    /// Render thread. Whether a voice is sounding.
    public var isSounding: Bool { synth.activeVoiceCount > 0 }

    /// Render thread, for the app's engine: starts the synth over for a new owner — every voice
    /// silenced at once (CC 120) and every controller at rest without a glide, so the next note
    /// sounds as on a fresh kernel. A host's CC 120 goes through `receive` and leaves the
    /// controllers alone.
    public func reset() {
        for i in 0..<count { rampFrames[i] = 0 }
        activeRamps = 0
        synth.reset()
        synth.resetControllers()
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

import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The built-in synth as a plugin plays it: the parameters of `SynthParameter.all` by index,
/// MIDI bytes in, stereo out. Shared by the Echoel Synth Audio Unit and its tests.
///
/// Threading: `setParameter` may be called from any thread (host automation, the plugin's view);
/// it stores one word — the value's bits and a count of sets — and raises a version the render
/// thread compares. Only `setParameter` writes that word (from the plugin's view, and from the
/// render thread for a host's immediate set); each set draws its own count. The render thread plays its own copy
/// (`playing`), runs a host's ramp on that copy, and tells other threads where it is through a
/// second word only it writes (`reported`), so no write of one side can overwrite the other's.
/// Nothing allocates after `init`.
public final class SynthKernel: @unchecked Sendable {
    /// The patch parameters by index; `parameters` (InstrumentKernel) publishes the same list.
    static let patchParameters = SynthParameter.all
    public let sampleRate: Double

    /// Per address, the value set last: its bits in the low half, the count of sets in the high
    /// half — so setting the value a ramp passes through is still a new set. Written only by
    /// `setParameter`.
    private let values: UnsafeMutablePointer<Atomic<UInt64>>
    /// Per address, the sets so far: every set draws a count of its own here, so two setters on
    /// two threads never store the same word.
    private let sets: UnsafeMutablePointer<Atomic<UInt64>>
    /// Per address, the render thread's value and the set it started from (same packing).
    /// Written only by the render thread; `parameter` reads it while it belongs to the newest set.
    private let reported: UnsafeMutablePointer<Atomic<UInt64>>
    /// Render thread: the values the voices play, and the word of `values` each was taken from.
    private let playing: UnsafeMutablePointer<Float>
    private let taken: UnsafeMutablePointer<UInt64>
    private var playingMoved = true
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
    /// A host's parameter ramp, per address, run by the render thread (`rampParameter`) on
    /// `playing`: where it goes, how far each frame moves it, and the frames left. A value set
    /// since from another thread (the plugin's view) is newer than the ramp and ends it.
    private let rampTarget: UnsafeMutablePointer<Float>
    private let rampStep: UnsafeMutablePointer<Float>
    private let rampFrames: UnsafeMutablePointer<Int>
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
        reported = .allocate(capacity: Self.patchParameters.count)
        sets = .allocate(capacity: Self.patchParameters.count)
        playing = .allocate(capacity: Self.patchParameters.count)
        taken = .allocate(capacity: Self.patchParameters.count)
        for (i, parameter) in Self.patchParameters.enumerated() {
            let value = Float(parameter.defaultValue)
            let word = Self.word(count: 0, value)
            (values + i).initialize(to: Atomic(word))
            (reported + i).initialize(to: Atomic(word))
            (sets + i).initialize(to: Atomic(0))
            (playing + i).initialize(to: value)
            (taken + i).initialize(to: word)
        }
        synth = PolySynth(sampleRate: Float(rate))
        mono = .allocate(capacity: self.maximumFrames)
        mono.initialize(repeating: 0, count: self.maximumFrames)
        rampTarget = .allocate(capacity: count)
        rampTarget.initialize(repeating: 0, count: count)
        rampStep = .allocate(capacity: count)
        rampStep.initialize(repeating: 0, count: count)
        rampFrames = .allocate(capacity: count)
        rampFrames.initialize(repeating: 0, count: count)
        ramps = .allocate(capacity: count)
        for (i, parameter) in Self.patchParameters.enumerated() { ramps[i] = parameter.taper != .stepped }
    }

    deinit {
        values.deinitialize(count: count)
        values.deallocate()
        reported.deinitialize(count: count)
        reported.deallocate()
        sets.deinitialize(count: count)
        sets.deallocate()
        playing.deallocate()
        taken.deallocate()
        fields.deinitialize(count: count)
        fields.deallocate()
        mono.deallocate()
        rampTarget.deallocate()
        rampStep.deallocate()
        rampFrames.deallocate()
        ramps.deallocate()
    }

    /// Any thread. A value outside the parameter's range is clamped; one that is not finite is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard address >= 0, address < count, value.isFinite else { return }
        let range = ranges[address]
        let clamped = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        // Two setters racing each store a word of their own; the one stored last wins, as with
        // any last write, and the render thread sees it as new either way.
        let set = sets[address].wrappingAdd(1, ordering: .relaxed).newValue
        values[address].store(Self.word(count: set, clamped), ordering: .relaxed)
        version.add(1, ordering: .releasing)
    }

    /// Any thread: the value set last, or — once the render thread has taken that set — where it
    /// plays it, a host's ramp included.
    public func parameter(_ address: Int) -> Float {
        guard address >= 0, address < count else { return 0 }
        let set = values[address].load(ordering: .relaxed)
        let rendered = reported[address].load(ordering: .relaxed)
        return Self.value(rendered >> 32 == set >> 32 ? rendered : set)
    }

    private static func word(count: UInt64, _ value: Float) -> UInt64 {
        (count & 0xFFFF_FFFF) << 32 | UInt64(value.bitPattern)
    }

    private static func value(_ word: UInt64) -> Float {
        Float(bitPattern: UInt32(truncatingIfNeeded: word))
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
        // A value set before the ramp is where it starts.
        takeSets()
        if rampFrames[address] == 0 { activeRamps += 1 }
        rampTarget[address] = goal
        rampStep[address] = (goal - playing[address]) / Float(frames)
        rampFrames[address] = frames
    }

    /// Moves every running ramp on by `frames`. Only `playing` moves; a set that arrived since
    /// is taken first and ends its ramp (`takeSets`). The caller commits the patch once.
    private func advanceRamps(by frames: Int) {
        takeSets()
        for i in 0..<count where rampFrames[i] > 0 {
            let step = Swift.min(frames, rampFrames[i])
            rampFrames[i] -= step
            playing[i] = rampFrames[i] == 0 ? rampTarget[i] : playing[i] + rampStep[i] * Float(step)
            report(i)
            if rampFrames[i] == 0 { activeRamps -= 1 }
            playingMoved = true
        }
    }

    /// Render thread: publishes where `address` plays, tagged with the set it started from.
    private func report(_ address: Int) {
        reported[address].store(Self.word(count: taken[address] >> 32, playing[address]), ordering: .relaxed)
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

    /// Render thread. Applies values set since the last call — a set ends a running ramp on its
    /// address, because it is newer — and the steps a ramp moved. The patch reaches the synth only
    /// when it differs from the one it plays: `setPatch` restarts each voice's control-rate
    /// counter, so re-sending equal values would move the sound by a few samples.
    public func commitParameters() {
        takeSets()
        guard playingMoved else { return }
        playingMoved = false
        let next = patch()
        if next != synth.patch { synth.setPatch(next) }
    }

    /// Render thread: takes every set that arrived since the last call into `playing`.
    private func takeSets() {
        let current = version.load(ordering: .acquiring)
        if current != appliedVersion {
            appliedVersion = current
            for i in 0..<count {
                let set = values[i].load(ordering: .relaxed)
                guard set != taken[i] else { continue }
                taken[i] = set
                playing[i] = Self.value(set)
                if rampFrames[i] > 0 { rampFrames[i] = 0; activeRamps -= 1 }
                report(i)
                playingMoved = true
            }
        }
    }

    /// Render thread: the cycles the wavetable engine plays from now on (nil: the factory shapes).
    /// The caller keeps the bank alive until it knows rendering moved on.
    public func assignWavetable(_ bank: WavetableBank?) {
        synth.setWavetable(bank)
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
            fields[i]?.apply(Double(playing[i]), to: &patch)
        }
        return patch
    }
}

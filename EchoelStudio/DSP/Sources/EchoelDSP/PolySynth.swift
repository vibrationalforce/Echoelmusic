import Foundation

/// The sound of one synth track: everything a preset stores.
public struct SynthPatch: Equatable, Codable, Sendable {
    public var waveform: Oscillator.Waveform
    public var filterMode: SVFilter.Mode
    /// Hz, before the filter envelope.
    public var cutoff: Float
    public var resonance: Float
    /// How far the filter envelope opens the cutoff at full level, in octaves (0…8).
    public var filterEnvelopeAmount: Float
    public var filterEnvelope: Envelope.Settings
    public var ampEnvelope: Envelope.Settings
    /// Output gain, linear (0…1).
    public var level: Float

    public init(
        waveform: Oscillator.Waveform = .saw,
        filterMode: SVFilter.Mode = .lowpass,
        cutoff: Float = 800,
        resonance: Float = 0.3,
        filterEnvelopeAmount: Float = 3,
        filterEnvelope: Envelope.Settings = .init(attack: 0.002, decay: 0.3, sustain: 0.2, release: 0.3),
        ampEnvelope: Envelope.Settings = .init(attack: 0.003, decay: 0.2, sustain: 0.7, release: 0.25),
        level: Float = 0.25
    ) {
        self.waveform = waveform
        self.filterMode = filterMode
        self.cutoff = cutoff
        self.resonance = resonance
        self.filterEnvelopeAmount = filterEnvelopeAmount
        self.filterEnvelope = filterEnvelope
        self.ampEnvelope = ampEnvelope
        self.level = level
    }
}

/// One note's signal path: oscillator → filter (opened by its own envelope) → amp envelope.
public struct SynthVoice: Sendable {
    public private(set) var pitch: UInt8 = 0
    public private(set) var isHeld = false
    /// Let go while the sustain pedal is down: sounds on until the pedal comes up.
    public private(set) var isPedalled = false
    /// Rises with every note-on across the synth; the smallest is the oldest.
    public private(set) var startOrder: UInt64 = 0

    var oscillator = Oscillator()
    var filter: SVFilter
    var ampEnvelope: Envelope
    var filterEnvelope: Envelope
    private var increment: Float = 0
    /// The velocity's gain now and where it is going: a fresh note takes it at once, a note
    /// struck again while it sounds glides there like the level does, because a jump from a hard
    /// to a soft velocity mid-waveform is a click (audit 2026-10-23).
    private var gain: Float = 0
    private var gainTarget: Float = 0
    private var controlCountdown = 0
    /// Cutoff (in octaves above 1 Hz), resonance and level glide towards the patch instead of
    /// jumping, so an automated sweep or a 7-bit MIDI knob sounds continuous.
    private var cutoffOctaves: Float
    private var resonance: Float
    private var level: Float
    private let cutoffPole: Float
    private let resonancePole: Float
    private let levelPole: Float

    /// Glide time constants, in seconds. Short enough to follow a fast ride, long enough that a
    /// step of one MIDI value — or of one automation update — is never heard as a step.
    static let cutoffGlide: Float = 0.008
    static let resonanceGlide: Float = 0.008
    static let levelGlide: Float = 0.005

    /// Samples between filter coefficient updates: the filter envelope and the gliding cutoff
    /// move at this rate (0.33 ms at 48 kHz) and the prewarp `tan` runs 1/16 as often as a
    /// per-sample update would.
    static let controlInterval = 16

    init(patch: SynthPatch, sampleRate: Float) {
        cutoffOctaves = Self.octaves(patch.cutoff)
        resonance = Self.clampedResonance(patch.resonance)
        level = Self.clampedLevel(patch.level)
        cutoffPole = Self.pole(Self.cutoffGlide, sampleRate)
        resonancePole = Self.pole(Self.resonanceGlide, sampleRate)
        levelPole = Self.pole(Self.levelGlide, sampleRate)
        filter = SVFilter(mode: patch.filterMode, cutoff: patch.cutoff, resonance: patch.resonance, sampleRate: sampleRate)
        ampEnvelope = Envelope(settings: patch.ampEnvelope, sampleRate: sampleRate)
        filterEnvelope = Envelope(settings: patch.filterEnvelope, sampleRate: sampleRate)
        oscillator.waveform = patch.waveform
    }

    public var isActive: Bool { ampEnvelope.isActive }

    /// One-pole coefficient for a time constant.
    static func pole(_ seconds: Float, _ sampleRate: Float) -> Float {
        guard seconds > 0, sampleRate > 0 else { return 0 }
        return expf(-1 / (seconds * sampleRate))
    }

    static func octaves(_ hz: Float) -> Float { log2f(hz.isFinite ? Swift.max(hz, 1) : 1_000) }
    static func clampedResonance(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 0), 0.95) : 0.3 }
    static func clampedLevel(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 0), 1) : 0 }

    mutating func start(pitch: UInt8, velocity: UInt8, order: UInt64, sampleRate: Float, patch: SynthPatch) {
        let wasSilent = !ampEnvelope.isActive
        self.pitch = pitch
        isHeld = true
        isPedalled = false
        startOrder = order
        increment = 440 * powf(2, (Float(pitch) - 69) / 12) / sampleRate
        let v = Float(Swift.min(velocity, 127)) / 127
        gainTarget = v * v
        if wasSilent {
            gain = gainTarget
            oscillator.reset()
            filter.reset()
            // A fresh note starts where the patch is; only a sounding note glides.
            cutoffOctaves = Self.octaves(patch.cutoff)
            resonance = Self.clampedResonance(patch.resonance)
            level = Self.clampedLevel(patch.level)
            filter.setResonance(resonance)
        }
        controlCountdown = 0
        ampEnvelope.gateOn()
        filterEnvelope.gateOn()
    }

    /// The key is up but the pedal holds the note.
    mutating func pedal() {
        isHeld = false
        isPedalled = true
    }

    mutating func release() {
        isHeld = false
        isPedalled = false
        ampEnvelope.gateOff()
        filterEnvelope.gateOff()
    }

    mutating func silence() {
        isHeld = false
        isPedalled = false
        ampEnvelope.kill()
        filterEnvelope.kill()
    }

    mutating func apply(_ patch: SynthPatch) {
        oscillator.waveform = patch.waveform
        filter.mode = patch.filterMode
        ampEnvelope.update(patch.ampEnvelope)
        filterEnvelope.update(patch.filterEnvelope)
        controlCountdown = 0
    }

    /// Adds this voice into `buffer`. Nothing here allocates. `pitch` holds the wheels' frequency
    /// ratio for each sample of the buffer, from its first; without it every sample plays at
    /// `ratio`.
    @inline(__always)
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, patch: SynthPatch,
                         pitch: [Float]? = nil, ratio: Float = 1) {
        guard ampEnvelope.isActive else { return }
        let first = buffer.startIndex
        let amount = patch.filterEnvelopeAmount.isFinite ? Swift.min(Swift.max(patch.filterEnvelopeAmount, 0), 8) : 0
        let targetOctaves = Self.octaves(patch.cutoff)
        let targetResonance = Self.clampedResonance(patch.resonance)
        let targetLevel = Self.clampedLevel(patch.level)
        for i in buffer.indices {
            cutoffOctaves = targetOctaves + (cutoffOctaves - targetOctaves) * cutoffPole
            resonance = targetResonance + (resonance - targetResonance) * resonancePole
            level = targetLevel + (level - targetLevel) * levelPole
            gain = gainTarget + (gain - gainTarget) * levelPole
            let modulation = filterEnvelope.next()
            if controlCountdown <= 0 {
                filter.setResonance(resonance)
                filter.setCutoff(exp2f(cutoffOctaves + amount * modulation))
                controlCountdown = Self.controlInterval
            }
            controlCountdown -= 1
            let bend = pitch?[i - first] ?? ratio
            let sample = filter.process(oscillator.next(increment: increment * bend)) * ampEnvelope.next()
            buffer[i] += sample * gain * level
            if !ampEnvelope.isActive { break }
        }
    }
}

/// A polyphonic synth with a fixed number of voices, all allocated up front.
///
/// Voice allocation, in order: the same pitch retriggers its own voice; else a free voice;
/// else the oldest released voice; else the oldest held one. A stolen voice restarts from
/// its current level, so stealing never clicks.
///
/// Owned by the render thread: call every method from that thread. Nothing allocates after
/// `init`.
public struct PolySynth: Sendable {
    public static let defaultVoiceCount = 16

    public private(set) var patch: SynthPatch
    public private(set) var voices: [SynthVoice]
    private let sampleRate: Float
    private var nextOrder: UInt64 = 1
    /// Pitch-bend frequency ratio now, and where the wheel wants it.
    private var bend: Float = 1
    private var bendTarget: Float = 1
    private var isSustaining = false
    /// Vibrato depth 0…1 now and where the modulation wheel wants it, and the vibrato's phase 0..<1.
    private var vibrato: Float = 0
    private var vibratoTarget: Float = 0
    private var vibratoPhase: Float = 0
    /// How far the bend and the vibrato depth move toward their wheels per sample: ~5 ms and
    /// ~50 ms, so a wheel never steps. Per sample, not per buffer: a glide takes the same time
    /// however the song is cut into render calls — live at any buffer size and in the export
    /// alike (audit 2026-10-23).
    private let bendPole: Float
    private let vibratoPole: Float
    /// The wheels' ratio for each sample of the piece being rendered, written before the voices
    /// read it. Allocated once.
    private var pitchCurve: [Float]

    /// Semitones the wheel bends at either end: the General MIDI default.
    public static let bendRange: Float = 2
    /// Semitones the vibrato swings either side with the modulation wheel all the way up — the
    /// General MIDI 2 default modulation depth (±50 cents) — and how fast it swings.
    public static let vibratoRange: Float = 0.5
    public static let vibratoRate: Float = 5.5
    /// Seconds the bend takes to settle on a new wheel position (its time constant).
    static let bendGlide: Float = 0.005
    static let vibratoGlide: Float = 0.05
    /// The longest piece rendered against one `pitchCurve`.
    static let curveLength = 256

    public init(patch: SynthPatch = SynthPatch(), voiceCount: Int = defaultVoiceCount, sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.patch = patch
        self.sampleRate = rate
        bendPole = expf(-1 / (Self.bendGlide * rate))
        vibratoPole = expf(-1 / (Self.vibratoGlide * rate))
        pitchCurve = Array(repeating: 1, count: Self.curveLength)
        voices = Array(repeating: SynthVoice(patch: patch, sampleRate: rate), count: Swift.max(1, voiceCount))
    }

    public var activeVoiceCount: Int { voices.reduce(0) { $0 + ($1.isActive ? 1 : 0) } }

    public mutating func setPatch(_ patch: SynthPatch) {
        self.patch = patch
        for i in voices.indices { voices[i].apply(patch) }
    }

    public mutating func noteOn(pitch: UInt8, velocity: UInt8) {
        guard pitch <= 127 else { return }
        guard velocity > 0 else { noteOff(pitch: pitch); return }
        let index = voiceIndex(for: pitch)
        if activeVoiceCount == 0 {
            // Nothing sounds, and the engine renders nothing then: a wheel moved since the last
            // note is where this one starts, not a scoop or a fading vibrato over its first
            // buffer. A synth rendered while silent (the Audio Unit) is there already (audit
            // 2026-10-23).
            bend = bendTarget
            vibrato = vibratoTarget
            if vibratoTarget == 0 { vibratoPhase = 0 }
        }
        voices[index].start(pitch: pitch, velocity: velocity, order: nextOrder, sampleRate: sampleRate, patch: patch)
        nextOrder &+= 1
    }

    public mutating func noteOff(pitch: UInt8) {
        for i in voices.indices where voices[i].isHeld && voices[i].pitch == pitch {
            if isSustaining { voices[i].pedal() } else { voices[i].release() }
        }
    }

    /// The pitch wheel, 0…16383 with 8192 at rest, over ±`bendRange` semitones.
    public mutating func pitchBend(_ value: Int) {
        let centred = Float(Swift.min(Swift.max(value, 0), 16_383) - 8_192) / 8_192
        bendTarget = powf(2, centred * Self.bendRange / 12)
    }

    /// The sustain pedal (controller 64): while down, a released key keeps sounding; up releases
    /// every note it held.
    public mutating func sustain(_ down: Bool) {
        isSustaining = down
        guard !down else { return }
        for i in voices.indices where voices[i].isPedalled { voices[i].release() }
    }

    /// The modulation wheel (controller 1), 0…127: vibrato up to ±`vibratoRange` semitones at
    /// `vibratoRate`. The depth glides toward the wheel, so moving it never steps.
    public mutating func modulation(_ value: UInt8) {
        vibratoTarget = Float(Swift.min(value, 127)) / 127
    }

    /// One MIDI controller as a General MIDI synth reads it: 1 modulation, 64 sustain, 120 all
    /// sound off, 121 reset all controllers, 123 all notes off. Every other number is ignored.
    /// The one reading for the app's engine and the Audio Unit, so they cannot disagree.
    public mutating func controller(_ number: UInt8, _ value: UInt8) {
        switch number {
        case 1: modulation(value)
        case 64: sustain(value >= 64)
        case 120: reset()
        case 121:
            pitchBend(8_192)
            sustain(false)
            modulation(0)
        case 123: allNotesOff()
        default: break
        }
    }

    /// Releases every held note (the transport stopped, a MIDI all-notes-off), lifts the pedal,
    /// centres the wheel and lets the modulation wheel down.
    public mutating func allNotesOff() {
        isSustaining = false
        bendTarget = 1
        vibratoTarget = 0
        for i in voices.indices where voices[i].isHeld || voices[i].isPedalled { voices[i].release() }
    }

    /// Silences everything at once (panic). Use `allNotesOff` when a click is not wanted.
    public mutating func reset() {
        for i in voices.indices { voices[i].silence() }
    }

    /// Puts every controller at rest at once — pedal up, pitch wheel centred, modulation wheel
    /// down, the vibrato back at its start — without the glide a played wheel gets, so the next
    /// note sounds as on a fresh synth. For a synth whose voices are silent (`reset` first), such
    /// as one handed to another track: on a sounding one the pitch would jump. Controller 121
    /// glides instead, as a reset played into a sounding synth should.
    public mutating func resetControllers() {
        sustain(false)
        bend = 1
        bendTarget = 1
        vibrato = 0
        vibratoTarget = 0
        vibratoPhase = 0
    }

    /// Adds every sounding voice into `buffer`; the caller clears it first.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard !buffer.isEmpty else { return }
        let patch = self.patch
        guard bend != bendTarget || vibrato > 0 || vibratoTarget > 0 else {
            // The wheels rest: one ratio for the whole buffer.
            let ratio = bend
            voices.withUnsafeMutableBufferPointer { all in
                for i in all.indices where all[i].isActive {
                    all[i].render(into: buffer, patch: patch, ratio: ratio)
                }
            }
            return
        }
        // A wheel moves: its ratio sample by sample, a piece at a time.
        var done = 0
        while done < buffer.count {
            let n = Swift.min(Self.curveLength, buffer.count - done)
            for k in 0..<n {
                let ratio = nextRatio()
                pitchCurve[k] = ratio
            }
            let curve = pitchCurve
            let offset = buffer.startIndex + done
            let piece = UnsafeMutableBufferPointer(rebasing: buffer[offset..<(offset + n)])
            voices.withUnsafeMutableBufferPointer { all in
                for i in all.indices where all[i].isActive {
                    all[i].render(into: piece, patch: patch, pitch: curve)
                }
            }
            done += n
        }
    }

    /// The wheels' frequency ratio for the next sample: the bend and the vibrato depth one sample
    /// further toward their wheels, the vibrato one sample on.
    private mutating func nextRatio() -> Float {
        let next = bendTarget + (bend - bendTarget) * bendPole
        // A Float glide stops moving about 120 ulps short of its target, far outside 1e-7; where
        // it stops it takes the target, so a wheel let go rests exactly in tune (review 2026-10-23).
        bend = (next == bend || Swift.abs(next - bendTarget) < 1e-7) ? bendTarget : next
        guard vibrato > 0 || vibratoTarget > 0 else { return bend }
        vibrato = vibratoTarget + (vibrato - vibratoTarget) * vibratoPole
        vibratoPhase += Self.vibratoRate / sampleRate
        if vibratoPhase >= 1 { vibratoPhase -= 1 }
        if vibratoTarget == 0, vibrato < 1e-4 {
            vibrato = 0
            vibratoPhase = 0
            return bend
        }
        return bend * vibratoRatio()
    }

    /// The vibrato's frequency ratio at its current depth and phase.
    private func vibratoRatio() -> Float {
        exp2f(vibrato * Self.vibratoRange * sinf(2 * Float.pi * vibratoPhase) / 12)
    }

    private func voiceIndex(for pitch: UInt8) -> Int {
        var free: Int?
        var oldestReleased: (index: Int, order: UInt64)?
        var oldestHeld: (index: Int, order: UInt64)?
        for (i, voice) in voices.enumerated() {
            if voice.isActive, voice.pitch == pitch { return i }
            if !voice.isActive {
                if free == nil { free = i }
            } else if !voice.isHeld {
                if oldestReleased.map({ voice.startOrder < $0.order }) ?? true { oldestReleased = (i, voice.startOrder) }
            } else if oldestHeld.map({ voice.startOrder < $0.order }) ?? true {
                oldestHeld = (i, voice.startOrder)
            }
        }
        return free ?? oldestReleased?.index ?? oldestHeld?.index ?? 0
    }
}

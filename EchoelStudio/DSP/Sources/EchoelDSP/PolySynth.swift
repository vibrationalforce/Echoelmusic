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
    /// Rises with every note-on across the synth; the smallest is the oldest.
    public private(set) var startOrder: UInt64 = 0

    var oscillator = Oscillator()
    var filter: SVFilter
    var ampEnvelope: Envelope
    var filterEnvelope: Envelope
    private var increment: Float = 0
    private var gain: Float = 0
    private var controlCountdown = 0

    /// Samples between cutoff updates: the filter envelope moves smoothly at this rate and
    /// the prewarp `tan` runs 1/32 as often as a per-sample update would.
    static let controlInterval = 32

    init(patch: SynthPatch, sampleRate: Float) {
        filter = SVFilter(mode: patch.filterMode, cutoff: patch.cutoff, resonance: patch.resonance, sampleRate: sampleRate)
        ampEnvelope = Envelope(settings: patch.ampEnvelope, sampleRate: sampleRate)
        filterEnvelope = Envelope(settings: patch.filterEnvelope, sampleRate: sampleRate)
        oscillator.waveform = patch.waveform
    }

    public var isActive: Bool { ampEnvelope.isActive }

    mutating func start(pitch: UInt8, velocity: UInt8, order: UInt64, sampleRate: Float) {
        let wasSilent = !ampEnvelope.isActive
        self.pitch = pitch
        isHeld = true
        startOrder = order
        increment = 440 * powf(2, (Float(pitch) - 69) / 12) / sampleRate
        let v = Float(Swift.min(velocity, 127)) / 127
        gain = v * v
        if wasSilent {
            oscillator.reset()
            filter.reset()
        }
        controlCountdown = 0
        ampEnvelope.gateOn()
        filterEnvelope.gateOn()
    }

    mutating func release() {
        isHeld = false
        ampEnvelope.gateOff()
        filterEnvelope.gateOff()
    }

    mutating func silence() {
        isHeld = false
        ampEnvelope.kill()
        filterEnvelope.kill()
    }

    mutating func apply(_ patch: SynthPatch) {
        oscillator.waveform = patch.waveform
        filter.mode = patch.filterMode
        filter.setResonance(patch.resonance)
        ampEnvelope.update(patch.ampEnvelope)
        filterEnvelope.update(patch.filterEnvelope)
        controlCountdown = 0
    }

    /// Adds this voice into `buffer`. Nothing here allocates.
    @inline(__always)
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, patch: SynthPatch) {
        guard ampEnvelope.isActive else { return }
        let amount = patch.filterEnvelopeAmount.isFinite ? Swift.min(Swift.max(patch.filterEnvelopeAmount, 0), 8) : 0
        let level = patch.level.isFinite ? Swift.min(Swift.max(patch.level, 0), 1) : 0
        for i in buffer.indices {
            let modulation = filterEnvelope.next()
            if controlCountdown <= 0 {
                filter.setCutoff(patch.cutoff * exp2f(amount * modulation))
                controlCountdown = Self.controlInterval
            }
            controlCountdown -= 1
            let sample = filter.process(oscillator.next(increment: increment)) * ampEnvelope.next()
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

    public init(patch: SynthPatch = SynthPatch(), voiceCount: Int = defaultVoiceCount, sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.patch = patch
        self.sampleRate = rate
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
        voices[index].start(pitch: pitch, velocity: velocity, order: nextOrder, sampleRate: sampleRate)
        nextOrder &+= 1
    }

    public mutating func noteOff(pitch: UInt8) {
        for i in voices.indices where voices[i].isHeld && voices[i].pitch == pitch {
            voices[i].release()
        }
    }

    /// Releases every held note (the transport stopped, a MIDI all-notes-off).
    public mutating func allNotesOff() {
        for i in voices.indices where voices[i].isHeld { voices[i].release() }
    }

    /// Silences everything at once (panic). Use `allNotesOff` when a click is not wanted.
    public mutating func reset() {
        for i in voices.indices { voices[i].silence() }
    }

    /// Adds every sounding voice into `buffer`; the caller clears it first.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard !buffer.isEmpty else { return }
        let patch = self.patch
        voices.withUnsafeMutableBufferPointer { all in
            for i in all.indices where all[i].isActive {
                all[i].render(into: buffer, patch: patch)
            }
        }
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

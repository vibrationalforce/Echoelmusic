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
    /// What makes the raw tone (`SynthEngine`); the classic oscillator plays `waveform`.
    public var engine: SynthEngine = .classic
    /// The engine's one control, 0…1 (`SynthEngine`).
    public var character: Float = 0.5
    /// Which filter shapes the tone: the clean state-variable one in `filterMode`, or the
    /// four-pole ladder, always lowpass (EchoelTools A2).
    public var filterModel: FilterModel = .stateVariable
    /// The vibrato's depth with the modulation wheel at rest, 0…1 of `PolySynth.vibratoRange` (W12):
    /// a value a modulation route can move — the Body voice's pulse — where the wheel is a player's
    /// hand. The deeper of the two sets the swing.
    public var vibrato: Float = 0
    /// Slide (EchoelTools A2, the bass-line glide): seconds a note takes to glide from the note it
    /// overlaps — a key struck while another is still held, not at the same moment — on the same
    /// voice, its envelopes not struck again. 0 is off: every note its own voice.
    public var slide: Float = 0
    /// Accent (A2): how much a note struck at velocity `PolySynth.accentVelocity` or harder opens
    /// the filter envelope further and plays louder, 0…1. 0 is off.
    public var accent: Float = 0
    /// The texture engine (A10): which of its eight rules evolves the row (`TextureSource.ruleNumber`),
    /// how many harmonics may sound (0 … 1), generations per second (0 … 40, 0 holds the row) and
    /// the row a note starts from.
    public var textureRule: Int = 0
    public var textureDensity: Float = 0.6
    public var textureRate: Float = 8
    public var textureSeed: UInt32 = 0

    public enum FilterModel: String, CaseIterable, Codable, Sendable {
        case stateVariable, ladder
    }

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
    var source: EngineSource
    var filter: SVFilter
    var ladder: LadderFilter
    var ampEnvelope: Envelope
    var filterEnvelope: Envelope
    private var increment: Float = 0
    /// While a slide glides: the increment it goes to (`slide(…)`), in octaves, and how far it
    /// moves each sample. `glideOctaves` is where it is.
    private var glideOctaves: Float = 0
    private var glideTarget: Float = 0
    private var glidePole: Float = 0
    private var isGliding = false
    /// Struck at accent velocity: the filter envelope opens further.
    private var accented = false
    /// The velocity's gain now and where it is going: a fresh note takes it at once, a note
    /// struck again while it sounds glides there like the level does, because a jump from a hard
    /// to a soft velocity mid-waveform is a click (audit 2026-10-23).
    private var gain: Float = 0
    private var gainTarget: Float = 0
    private var controlCountdown = 0
    /// Cutoff (in octaves above 1 Hz), resonance, level and the engine's Character glide towards
    /// the patch instead of jumping, so an automated sweep, a 7-bit MIDI knob or a body route
    /// sounds continuous. Character most of all: it is the FM index, the morph's position and the
    /// sub's level, written straight into the waveform, so a step in it was a step in the sound
    /// (click hunt, 2026-11-01).
    private var cutoffOctaves: Float
    private var resonance: Float
    private var level: Float
    private var character: Float
    private let cutoffPole: Float
    private let resonancePole: Float
    private let levelPole: Float
    private let characterPole: Float
    private let sampleRate: Float

    /// Glide time constants, in seconds. Short enough to follow a fast ride, long enough that a
    /// step of one MIDI value — or of one automation update — is never heard as a step.
    static let cutoffGlide: Float = 0.008
    static let resonanceGlide: Float = 0.008
    static let levelGlide: Float = 0.005
    static let characterGlide: Float = 0.008

    /// Samples between filter coefficient updates: the filter envelope and the gliding cutoff
    /// move at this rate (0.33 ms at 48 kHz) and the prewarp `tan` runs 1/16 as often as a
    /// per-sample update would.
    static let controlInterval = 16

    init(patch: SynthPatch, sampleRate: Float) {
        cutoffOctaves = Self.octaves(patch.cutoff)
        resonance = Self.clampedResonance(patch.resonance)
        level = Self.voiceLevel(patch)
        character = Self.clampedCharacter(patch.character)
        source = EngineSource(sampleRate: sampleRate)
        self.sampleRate = sampleRate
        cutoffPole = Self.pole(Self.cutoffGlide, sampleRate)
        resonancePole = Self.pole(Self.resonanceGlide, sampleRate)
        levelPole = Self.pole(Self.levelGlide, sampleRate)
        characterPole = Self.pole(Self.characterGlide, sampleRate)
        filter = SVFilter(mode: patch.filterMode, cutoff: patch.cutoff, resonance: patch.resonance, sampleRate: sampleRate)
        ladder = LadderFilter(cutoff: patch.cutoff, resonance: patch.resonance, sampleRate: sampleRate)
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
    /// The level a voice plays at: the patch's, times its engine's loudness trim.
    static func voiceLevel(_ patch: SynthPatch) -> Float { clampedLevel(patch.level) * patch.engine.loudnessTrim }
    static func clampedLevel(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 0), 1) : 0 }
    static func clampedCharacter(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 0), 1) : 0.5 }

    /// `temperament` places the note: the song's tone system and concert pitch.
    mutating func start(pitch: UInt8, velocity: UInt8, order: UInt64, sampleRate: Float, patch: SynthPatch,
                        temperament: Temperament = .standard) {
        let wasSilent = !ampEnvelope.isActive
        self.pitch = pitch
        isHeld = true
        isPedalled = false
        startOrder = order
        increment = temperament.frequency(of: Int(pitch)) / sampleRate
        isGliding = false
        gainTarget = Self.velocityGain(velocity, patch: patch)
        accented = Self.isAccented(velocity, patch: patch)
        if wasSilent {
            gain = gainTarget
            oscillator.reset()
            source.reset()
            filter.reset()
            ladder.reset()
            // A fresh note starts where the patch is; only a sounding note glides.
            cutoffOctaves = Self.octaves(patch.cutoff)
            resonance = Self.clampedResonance(patch.resonance)
            level = Self.voiceLevel(patch)
            character = Self.clampedCharacter(patch.character)
            filter.setResonance(resonance)
            ladder.setResonance(resonance)
        }
        if patch.engine == .texture { source.setTexture(patch, sampleRate: sampleRate) }
        // Every key strikes, a repeated one too: a mallet rings again on top of its tail, and the
        // DDSP's noise takes a sequence of its own from the note counter.
        source.strike(character: patch.character, order: order, pitch: pitch, sampleRate: sampleRate, dt: increment)
        controlCountdown = 0
        ampEnvelope.gateOn()
        filterEnvelope.gateOn()
    }

    /// The gain a velocity plays at: its square, raised by the patch's accent at accent velocity.
    static func velocityGain(_ velocity: UInt8, patch: SynthPatch) -> Float {
        let v = Float(Swift.min(velocity, 127)) / 127
        let accent = isAccented(velocity, patch: patch) ? 1 + PolySynth.accentGain * clampedAccent(patch.accent) : 1
        return v * v * accent
    }

    static func isAccented(_ velocity: UInt8, patch: SynthPatch) -> Bool {
        velocity >= PolySynth.accentVelocity && clampedAccent(patch.accent) > 0
    }

    static func clampedAccent(_ value: Float) -> Float { value.isFinite ? Swift.min(Swift.max(value, 0), 1) : 0 }

    /// A slide: this sounding, held voice glides to `pitch` over the patch's slide time and takes
    /// the new note's velocity and order. The envelopes go on where they are, the source is not
    /// struck again — the line is one note that moves (A2).
    mutating func slide(to pitch: UInt8, velocity: UInt8, order: UInt64, sampleRate: Float, patch: SynthPatch,
                        temperament: Temperament) {
        let target = temperament.frequency(of: Int(pitch)) / sampleRate
        guard target.isFinite, target > 0, increment.isFinite, increment > 0 else { return }
        self.pitch = pitch
        startOrder = order
        glideOctaves = log2f(increment)
        glideTarget = log2f(target)
        let seconds = patch.slide.isFinite ? Swift.min(Swift.max(patch.slide, 0.001), 10) : 0.001
        // A time constant of a third of the slide: the glide is 95 % there when the time is up.
        glidePole = Self.pole(seconds / 3, sampleRate)
        isGliding = true
        gainTarget = Self.velocityGain(velocity, patch: patch)
        accented = Self.isAccented(velocity, patch: patch)
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
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, patch: SynthPatch, table: WavetableView,
                         pitch: [Float]? = nil, ratio: Float = 1) {
        guard ampEnvelope.isActive else { return }
        let first = buffer.startIndex
        var amount = patch.filterEnvelopeAmount.isFinite ? Swift.min(Swift.max(patch.filterEnvelopeAmount, 0), 8) : 0
        if accented { amount += PolySynth.accentOctaves * Self.clampedAccent(patch.accent) }
        let targetOctaves = Self.octaves(patch.cutoff)
        let targetResonance = Self.clampedResonance(patch.resonance)
        let targetLevel = Self.voiceLevel(patch)
        let targetCharacter = Self.clampedCharacter(patch.character)
        let usesLadder = patch.filterModel == .ladder
        if patch.engine == .pluck { source.setPluckRing(decaySeconds: patch.ampEnvelope.decay, sustain: patch.ampEnvelope.sustain,
                                                             sampleRate: sampleRate) }
        if patch.engine == .texture { source.setTexture(patch, sampleRate: sampleRate) }
        for i in buffer.indices {
            cutoffOctaves = targetOctaves + (cutoffOctaves - targetOctaves) * cutoffPole
            resonance = targetResonance + (resonance - targetResonance) * resonancePole
            level = targetLevel + (level - targetLevel) * levelPole
            character = targetCharacter + (character - targetCharacter) * characterPole
            gain = gainTarget + (gain - gainTarget) * levelPole
            let modulation = filterEnvelope.next()
            if controlCountdown <= 0 {
                let hz = exp2f(cutoffOctaves + amount * modulation)
                if usesLadder {
                    ladder.setResonance(resonance)
                    ladder.setCutoff(hz)
                } else {
                    filter.setResonance(resonance)
                    filter.setCutoff(hz)
                }
                controlCountdown = Self.controlInterval
            }
            controlCountdown -= 1
            if isGliding {
                glideOctaves = glideTarget + (glideOctaves - glideTarget) * glidePole
                if Swift.abs(glideOctaves - glideTarget) < 1e-6 {
                    glideOctaves = glideTarget
                    isGliding = false
                }
                increment = exp2f(glideOctaves)
            }
            let bend = pitch?[i - first] ?? ratio
            let tone = source.next(patch.engine, character: character, main: &oscillator, dt: increment * bend, table: table)
            let shaped = usesLadder ? ladder.process(tone) : filter.process(tone)
            let sample = shaped * ampEnvelope.next()
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
    /// Where each pitch class sounds: the song's tone system and concert pitch (`Temperament`).
    /// Twelve equal steps at A = 440 Hz until the engine sets it; a plugin in another host keeps that.
    public private(set) var temperament = Temperament.standard
    private let sampleRate: Float
    private var nextOrder: UInt64 = 1
    /// Pitch-bend frequency ratio now, and where the wheel wants it.
    private var bend: Float = 1
    private var bendTarget: Float = 1
    private var isSustaining = false
    /// Samples rendered so far, and when each note started: a slide joins a note struck while an
    /// earlier one still sounds, never two struck at the same moment (a chord).
    private var clock: UInt64 = 0
    private var lastStartClock: UInt64 = .max
    /// Vibrato depth 0…1 now and where the modulation wheel wants it, and the vibrato's phase 0..<1.
    /// The depth goes where the wheel or the patch's own vibrato wants it, whichever is deeper
    /// (`vibratoGoal`).
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
    /// The cycles the wavetable engine plays: a sample's (`setWavetable`) or the factory shapes.
    /// Held here, so its `view` stays valid while the voices read it.
    public private(set) var wavetable: WavetableBank
    private var table: WavetableView
    /// The factory bank, taken once where the synth is made: the render thread never touches the
    /// lazily built global.
    private let factory: WavetableBank

    /// The velocity from which a note is accented (A2), and what a full accent adds: octaves of
    /// filter envelope and a share of level.
    public static let accentVelocity: UInt8 = 100
    static let accentOctaves: Float = 2
    static let accentGain: Float = 0.5

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
        factory = WavetableBank.factory
        wavetable = factory
        table = factory.view
        // One voice each, never `Array(repeating:)`: a voice's plucked string owns its delay line,
        // and copies of one voice would share it.
        voices = (0..<Swift.max(1, voiceCount)).map { _ in SynthVoice(patch: patch, sampleRate: rate) }
    }

    public var activeVoiceCount: Int { voices.reduce(0) { $0 + ($1.isActive ? 1 : 0) } }

    /// The tuning the next notes start in. A note already sounding keeps its pitch: retuning it
    /// would be a jump in the middle of a held tone. Arithmetic only: render-safe.
    public mutating func setTemperament(_ temperament: Temperament) {
        self.temperament = temperament
    }

    /// Plays `bank` on the wavetable engine from the next sample; nil returns to the factory
    /// shapes. A sounding note goes on at its phase and position. Render-safe: the caller keeps the
    /// bank it hands over alive until it knows rendering moved on, so none is released here.
    public mutating func setWavetable(_ bank: WavetableBank?) {
        let next = bank ?? factory
        guard next !== wavetable else { return }
        wavetable = next
        table = next.view
    }

    public mutating func setPatch(_ patch: SynthPatch) {
        self.patch = patch
        for i in voices.indices { voices[i].apply(patch) }
    }

    public mutating func noteOn(pitch: UInt8, velocity: UInt8) {
        guard pitch <= 127 else { return }
        guard velocity > 0 else { noteOff(pitch: pitch); return }
        if let held = slideVoice(for: pitch) {
            voices[held].slide(to: pitch, velocity: velocity, order: nextOrder, sampleRate: sampleRate, patch: patch,
                               temperament: temperament)
            nextOrder &+= 1
            lastStartClock = clock
            return
        }
        let index = voiceIndex(for: pitch)
        if activeVoiceCount == 0 {
            // Nothing sounds, and the engine renders nothing then: a wheel moved since the last
            // note is where this one starts, not a scoop or a fading vibrato over its first
            // buffer. A synth rendered while silent (the Audio Unit) is there already (audit
            // 2026-10-23). The vibrato starts from its beginning: how long a silent synth went on
            // rendering is the end of the host's buffer, so a phase carried through the rest made
            // playback and export differ (review 2026-10-23).
            bend = bendTarget
            vibrato = vibratoGoal
            vibratoPhase = 0
        }
        voices[index].start(pitch: pitch, velocity: velocity, order: nextOrder, sampleRate: sampleRate, patch: patch,
                            temperament: temperament)
        nextOrder &+= 1
        lastStartClock = clock
    }

    /// The voice a new key slides on: with Slide on, the newest held voice of another pitch, if it
    /// started before this sample — a key struck at the same moment is a chord, not a slide.
    private func slideVoice(for pitch: UInt8) -> Int? {
        guard patch.slide.isFinite, patch.slide > 0, lastStartClock != clock else { return nil }
        var newest: (index: Int, order: UInt64)?
        for (i, voice) in voices.enumerated() where voice.isActive && voice.isHeld {
            if voice.pitch == pitch { return nil }
            if newest.map({ voice.startOrder > $0.order }) ?? true { newest = (i, voice.startOrder) }
        }
        return newest?.index
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
        clock &+= UInt64(buffer.count)
        let patch = self.patch
        let table = self.table
        guard bend != bendTarget || vibrato > 0 || vibratoGoal > 0 else {
            // The wheels rest: one ratio for the whole buffer.
            let ratio = bend
            voices.withUnsafeMutableBufferPointer { all in
                for i in all.indices where all[i].isActive {
                    all[i].render(into: buffer, patch: patch, table: table, ratio: ratio)
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
                    all[i].render(into: piece, patch: patch, table: table, pitch: curve)
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
        let goal = vibratoGoal
        guard vibrato > 0 || goal > 0 else { return bend }
        vibrato = goal + (vibrato - goal) * vibratoPole
        vibratoPhase += Self.vibratoRate / sampleRate
        if vibratoPhase >= 1 { vibratoPhase -= 1 }
        if goal == 0, vibrato < 1e-4 {
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

    /// Where the vibrato depth goes: the modulation wheel's, or the patch's own (`SynthPatch.vibrato`,
    /// W12) where that is deeper. A value that is not a number counts as none. Arithmetic only:
    /// render-safe.
    private var vibratoGoal: Float {
        let own = patch.vibrato.isFinite ? Swift.min(Swift.max(patch.vibrato, 0), 1) : 0
        return Swift.max(vibratoTarget, own)
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

import Foundation

/// A voice avatar played as an instrument (VA-3): notes sung in the colour of a `VoiceAvatar`, from
/// keys or from a frequency. Each note is a bank of up to sixty-four harmonics at whole multiples of
/// its frequency, as in `DDSPSource`; under the notes runs a breath of noise. The avatar sets how
/// loud each part is.
///
/// **Harmonics.** Each harmonic sounds at the level the avatar's voiced envelope has at the
/// harmonic's own frequency in hertz, read on the avatar's grid as `VoiceAvatar.level(at:character:)`
/// reads it. So the formants stay where the avatar has them on every note: an octave up, the second
/// harmonic sits where the fourth sat, at the same level against the others, where a timbre kept
/// per harmonic number would move the formants with the pitch. Character morphs the envelope
/// between the avatar's snapshots, its darkest at 0 and its brightest at 1, band by band in
/// decibels, as `VoiceAvatar.envelope(character:)` does. Harmonics fade out from 85 % of Nyquist
/// over a smoothstep and are silent from Nyquist up, and they start at the quadratic spread of
/// phases that keeps `DDSPSource`'s peaks low. A harmonic glides to a new level in about 4 ms, so a
/// turned Character, a vibrato or a swapped avatar never steps; one that has glided out leaves the
/// note's loop. Below 250 Hz the sixty-fourth harmonic lies below 16 kHz: the envelope above it is
/// not played.
///
/// **Breath.** One white noise for the whole source, through seventeen band-passes half an octave
/// apart, 62.5 Hz to 16 kHz, each as loud as the avatar's noise envelope at its centre. A band is
/// two TPT stages in a row (the form `ZDFStage` uses, its coefficients worked out once), so
/// neighbours meet 3 dB down and a band two octaves away lets through about 34 dB less. Every other
/// band is turned over, as in `ChannelVocoder`: two neighbours meet 131° apart in phase, so summed
/// alike they nearly cancel there, and a flat noise envelope breathed with notches down to −26 dB;
/// turned over they meet 49° apart, and it breathes flat within about 1.1 dB from 200 Hz to 10 kHz
/// (both worked out from the bands' responses at 48 kHz). So the breath follows the noise envelope
/// at the bands' resolution. The notes do not each have a noise: the breath sounds as loud as the
/// notes' breath would add up in power — one note at its own level, four notes twice as loud — and
/// a note's envelope and velocity carry it as they carry the tone. The avatar's `breath` is the
/// share of the power that is breath; an avatar without a snapshot is breath only.
///
/// **Loudness.** The harmonics and the breath are each scaled to the K-weighted power of a
/// full-scale sine — K-weighting is what BS.1770 measures loudness through (`LoudnessMeter`) — whatever
/// the note, the Character and the avatar. So every note and every Character sings at about one
/// loudness: from A2 to D♯5 at Character 0, ½ and 1 on the tests' avatar, a quarter of it breath,
/// the loudest and the quietest lie 0.063 LU apart (0.008 LU without the breath), measured on
/// Linux by `AvatarSourceTests`, which holds them within 0.2 LU. A held note at full velocity and
/// `level` 1 measures about −3.7 LUFS on one channel.
///
/// **Vibrato.** The avatar's own, at its rate, and its depth times `Settings.vibrato`, setting in
/// over a note's first `vibratoOnset` seconds as a singer's does. Each note swings on its own, from
/// the start of its swing. An avatar without a vibrato holds its pitch.
///
/// **Notes** are taken as `PolySynth` takes them: the same key strikes its own voice again, else a
/// free voice, else the oldest released one, else the oldest held one; a voice taken while it sounds
/// goes on from where it is, so taking it never clicks. A note rises over `attack` and falls over
/// `release` (`Envelope`, from where it is; neither shorter than 5 ms), at the square of its
/// velocity. A note on a voice that was silent starts the same way every time — its phases and its
/// vibrato from their beginning, and the breath from its beginning too when nothing else sounds —
/// so an export renders what playback played. A frequency that is not a finite number above zero and
/// below Nyquist sings nothing, and a note its vibrato carries there falls silent at once — its
/// harmonics have faded under the taper by then: silence, never a number that is not one.
///
/// **Render thread.** Owned by it: call every method from that thread. Everything is allocated in
/// `init`; `setAvatar` copies the avatar's tables into that storage between two renders, allocating
/// and freeing nothing — the caller keeps the avatar it hands over alive, as `PolySynth.setWavetable`
/// asks of a bank. `render` adds into the buffer; the caller clears it first.
///
/// **Cost**, derived from the code, not measured on a device: per sounding note and sample, about
/// twenty operations for each harmonic below the taper (all sixty-four at 220 Hz, twenty-three at
/// 1 kHz, none for an avatar of breath only); for the breath, once for all notes, about 360 (none for
/// an avatar without breath). Every 32 samples a note's vibrato, a pass over its harmonics that lets
/// the ones that have faded out go and, once its pitch has moved by a cent or the envelope has
/// changed, its harmonics' levels, one `exp2f` each.
public struct AvatarSource: Sendable {
    /// How the notes are sung. Every value is held to its range by `clamped`.
    public struct Settings: Equatable, Sendable {
        /// Where the voice sits between the avatar's darkest snapshot (0) and its brightest (1).
        public var character: Float
        /// Seconds a note takes to rise, within `times`.
        public var attack: Float
        /// Seconds a released note takes to fall silent, within `times`.
        public var release: Float
        /// How much of the avatar's vibrato depth the notes sing with, 0 … 1.
        public var vibrato: Float
        /// Output gain, linear, 0 … 1.
        public var level: Float

        /// The seconds an attack or a release may take: never shorter than 5 ms, so a note never
        /// starts or stops faster than a voice can.
        public static let times: ClosedRange<Float> = 0.005 ... 10

        public init(character: Float = 0.5, attack: Float = 0.02, release: Float = 0.3, vibrato: Float = 1,
                    level: Float = 0.25) {
            self.character = character
            self.attack = attack
            self.release = release
            self.vibrato = vibrato
            self.level = level
        }

        /// Every value inside its range; one that is not a number takes its default.
        public var clamped: Settings {
            let base = Settings()
            func held(_ value: Float, _ range: ClosedRange<Float>, _ fallback: Float) -> Float {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(character: held(character, 0 ... 1, base.character),
                            attack: held(attack, Self.times, base.attack),
                            release: held(release, Self.times, base.release),
                            vibrato: held(vibrato, 0 ... 1, base.vibrato),
                            level: held(level, 0 ... 1, base.level))
        }
    }

    // MARK: Constants

    /// The voices a source has unless asked for another number: each sounding note costs about one
    /// `DDSPSource` voice.
    public static let defaultVoiceCount = 8
    /// The most harmonics a note sings: `DDSPSource`'s bank.
    public static let partialCount = 64
    /// Seconds over which a note's vibrato sets in, from none to its full depth.
    public static let vibratoOnset: Float = 0.2

    /// Samples between two control steps of a note — its vibrato, its pitch and, when they moved,
    /// its harmonics' levels — and of the breath's gains: 0.67 ms at 48 kHz.
    static let controlInterval = 32
    /// The longest piece rendered at once: the notes' breath levels for it are added up in storage
    /// of this size, set aside in `init`.
    static let chunk = 256
    /// How far a note's pitch moves before its harmonics' levels are read again: a cent, in octaves.
    static let pitchStep: Float = 1 / 1_200
    /// How far Character moves before the envelope is morphed again.
    static let characterStep: Float = 1e-4
    /// Per-sample glide of each harmonic toward its level: `DDSPSource`'s, about 4 ms at 48 kHz.
    static let amplitudeGlide: Float = 0.005
    /// A harmonic or a breath gain quieter than this is silence. A harmonic gliding toward nothing is
    /// set to zero once it falls below it, at every control step (`DDSPSource` flushes its partials
    /// so), and a breath gain this close to its target takes it: none glides into the subnormal
    /// range, where a processor slows down many times over, or sticks there short of zero.
    static let amplitudeFloor: Float = 1e-20
    /// Seconds the level and the velocity take to follow a change (per sample), the tone and the
    /// breath a swapped avatar (per control step), and the vibrato's depth.
    static let levelGlide: Float = 0.005
    static let vibratoGlide: Float = 0.05
    /// The breath's bands: centres at `breathLowestHertz` · 2^(b/2) for b = 0 … 16, and the damping
    /// 1/Q of each of a band's two stages — two stages in a row half an octave apart meet 3 dB down
    /// at Q = √(√2 − 1) / (2^¼ − 2^−¼), about 1.85.
    static let breathBandCount = 17
    static let breathLowestHertz = 62.5
    static let breathDamping = Float((Foundation.pow(2, 0.25) - Foundation.pow(2, -0.25)) / (2.0.squareRoot() - 1).squareRoot())
    /// Where each part of the breath's storage starts (`breathBank`), in floats: the two stages'
    /// states, the coefficients, the gains now and where they go.
    static let breathLanes = 9 * breathBandCount
    /// Decibels to octaves of amplitude: log₂(10) / 20, so a level in decibels is one `exp2f`.
    static let decibelsToOctaves: Float = 0.166_096_4

    // MARK: State

    /// What every note reads from the source as it renders: the envelope at the current Character,
    /// the weights that make the loudness one, the tone's share, the vibrato.
    struct Shared: Sendable {
        /// The voiced envelope at Character, in decibels, bands 0 … 47; the floor everywhere for an
        /// avatar of breath only.
        var envelope = SIMD64<Float>(repeating: VoiceAvatar.floorDecibels)
        /// The K-weighting's power gain at each band centre (`loudnessWeights`).
        var weights = SIMD64<Float>(repeating: 1)
        /// Moves whenever `envelope` changes, so a note knows to read its harmonics' levels again.
        var generation: UInt32 = 0
        /// The tone's part of the sound as an amplitude: √(1 − breath), 0 for an avatar of breath only.
        var tone: Float = 1
        /// The vibrato's rate in hertz, and its depth in cents: the avatar's, times `Settings.vibrato`.
        var vibratoRate: Float = 0
        var vibratoDepth: Float = 0
        var level: Float = 0.25
        var sampleRate: Float = 48_000
        /// One-pole coefficients: per sample for the level, per control step for the balance and the
        /// vibrato's depth; and how far a note's vibrato sets in per control step.
        var levelPole: Float = 0
        var balancePole: Float = 0
        var vibratoPole: Float = 0
        var onsetStep: Float = 0
    }

    public private(set) var settings: Settings
    /// Where each key sounds: twelve equal steps at A = 440 Hz until set (`setTemperament`).
    public private(set) var temperament = Temperament.standard
    private var voices: [Voice]
    private var shared = Shared()
    /// The avatar's snapshots, `VoiceAvatar.maximumSnapshots` tables of `VoiceAvatar.bandCount` levels
    /// side by side; the first `snapshotCount` hold the avatar's.
    private var snapshots: [Float]
    private var snapshotCount = 0
    /// The Character `shared.envelope` was morphed at.
    private var morphedCharacter: Float = .nan
    /// The avatar's vibrato: hertz and cents, zero for none.
    private var avatarVibratoRate: Float = 0
    private var avatarVibratoDepth: Float = 0
    /// The breath bank, `breathLanes` floats: per band its first stage's two states, its second
    /// stage's two, its three TPT coefficients, its gain now and its gain to come.
    private var breathBank: [Float]
    /// The notes' breath levels, squared and added, for the piece being rendered.
    private var breathLevels: [Float]
    /// The breath bands' K-weighted cross-powers, entry b · 17 + c (`breathCrossPowers`).
    private let breathPowers: [Float]
    /// The breath is computed while the avatar has one or its gains are still gliding out.
    private var breathing = false
    private var hasBreath = false
    /// xorshift32 state of the breath's noise; never zero.
    private var breathNoise: UInt32 = Self.breathSeed
    private var breathCountdown = 0
    private static let breathSeed: UInt32 = 0x1234_5678
    private let sampleRate: Float
    private var nextOrder: UInt64 = 1

    /// A source singing `avatar`. Allocates everything it will need: call off the render thread.
    public init(avatar: VoiceAvatar, settings: Settings = Settings(), voiceCount: Int = defaultVoiceCount,
                sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.settings = settings.clamped
        let interval = Float(Self.controlInterval)
        var tables = Shared()
        tables.sampleRate = rate
        tables.weights = Self.loudnessWeights(sampleRate: rate)
        tables.levelPole = expf(-1 / (Self.levelGlide * rate))
        tables.balancePole = expf(-interval / (Self.levelGlide * rate))
        tables.vibratoPole = expf(-interval / (Self.vibratoGlide * rate))
        tables.onsetStep = interval / (Self.vibratoOnset * rate)
        shared = tables
        let coefficients = Self.breathCoefficients(sampleRate: rate)
        breathPowers = Self.breathCrossPowers(coefficients, sampleRate: rate)
        breathBank = [Float](repeating: 0, count: Self.breathLanes)
        let bands = Self.breathBandCount
        for band in 0..<bands {
            breathBank[4 * bands + band] = coefficients[band]
            breathBank[5 * bands + band] = coefficients[bands + band]
            breathBank[6 * bands + band] = coefficients[2 * bands + band]
        }
        breathLevels = [Float](repeating: 0, count: Self.chunk)
        snapshots = [Float](repeating: VoiceAvatar.floorDecibels, count: VoiceAvatar.maximumSnapshots * VoiceAvatar.bandCount)
        let timing = Self.noteEnvelope(self.settings)
        voices = (0..<Swift.max(1, voiceCount)).map { (_: Int) -> Voice in Voice(timing: timing, sampleRate: rate) }
        // `DDSPSource`'s tables are read here, off the render thread, so the first note finds them
        // initialised (see `DDSPSource`).
        _ = DDSPSource.startPhases
        _ = DDSPSource.ratios
        _ = DDSPSource.log2Ratios
        _ = Voice.partialLanes
        setAvatar(avatar)
        settleBreath()
    }

    /// How many notes sound, released ones still falling included. Counted over the voices in place,
    /// so nothing is copied or allocated, even unoptimised: render-safe.
    public var activeVoiceCount: Int {
        voices.withUnsafeBufferPointer { (all: UnsafeBufferPointer<Voice>) -> Int in
            var count = 0
            for index in all.indices where all[index].isActive { count += 1 }
            return count
        }
    }

    /// How many harmonics the sounding notes compute, all together: what the tone costs (see the
    /// type). For tests and a meter; render-safe.
    var harmonicsInPlay: Int {
        voices.withUnsafeBufferPointer { (all: UnsafeBufferPointer<Voice>) -> Int in
            var count = 0
            for index in all.indices where all[index].isActive { count += all[index].harmonicsInPlay }
            return count
        }
    }

    /// Whether any note sounds: the voices read in place until the first one that does.
    private var isSounding: Bool {
        voices.withUnsafeBufferPointer { (all: UnsafeBufferPointer<Voice>) -> Bool in
            for index in all.indices where all[index].isActive { return true }
            return false
        }
    }

    // MARK: Changing it

    /// Sings `avatar` from the next sample: its snapshots, breath and vibrato are copied into the
    /// storage `init` set aside, with nothing allocated or freed, and every sounding note glides to
    /// the new colour. Render-safe; the caller keeps `avatar` alive until this returns.
    public mutating func setAvatar(_ avatar: VoiceAvatar) {
        let count = Swift.min(avatar.snapshots.count, VoiceAvatar.maximumSnapshots)
        let width = VoiceAvatar.bandCount
        snapshots.withUnsafeMutableBufferPointer { (storage: inout UnsafeMutableBufferPointer<Float>) in
            for index in 0..<count {
                avatar.snapshots[index].withUnsafeBufferPointer { (table: UnsafeBufferPointer<Float>) in
                    for band in 0..<Swift.min(width, table.count) { storage[index * width + band] = table[band] }
                }
            }
        }
        snapshotCount = count
        avatarVibratoRate = avatar.vibrato?.rate ?? 0
        avatarVibratoDepth = avatar.vibrato?.depth ?? 0

        // The breath: each band as loud as the noise envelope at its centre, every other one turned
        // over (see the type), the whole scaled to the K-weighted power of a full-scale sine times
        // its share; the cross-powers count each pair's signs.
        let bands = Self.breathBandCount
        let powers = breathPowers
        let share = count > 0 ? avatar.breath : 1
        let scale = breathBank.withUnsafeMutableBufferPointer { (lanes: inout UnsafeMutableBufferPointer<Float>) -> Float in
            let targets = 8 * bands
            for band in 0..<bands {
                let sign: Float = band % 2 == 0 ? 1 : -1
                lanes[targets + band] = sign * exp2f(avatar.noiseLevel(at: Float(Self.breathCentre(band))) * Self.decibelsToOctaves)
            }
            var power: Float = 0
            for b in 0..<bands {
                for c in 0..<bands { power += lanes[targets + b] * lanes[targets + c] * powers[b * bands + c] }
            }
            let scale: Float = power > 0 && share > 0 ? (0.5 * share / power).squareRoot() : 0
            for band in 0..<bands { lanes[targets + band] *= scale }
            return scale
        }
        hasBreath = scale > 0
        if hasBreath { breathing = true }
        shared.tone = count > 0 ? (1 - share).squareRoot() : 0
        morph(always: true)
        follow()
    }

    /// New settings from the next sample. A running note keeps its stage and takes the new times
    /// from where it is; the level glides, and so do the harmonics to a new Character. Render-safe.
    public mutating func setSettings(_ settings: Settings) {
        let clamped = settings.clamped
        guard clamped != self.settings else { return }
        self.settings = clamped
        let timing = Self.noteEnvelope(clamped)
        for index in voices.indices { voices[index].retime(timing) }
        morph()
        follow()
    }

    /// The tuning the next notes start in; a sounding note keeps its pitch. Render-safe.
    public mutating func setTemperament(_ temperament: Temperament) {
        self.temperament = temperament
    }

    // MARK: Notes

    /// A key at the pitch `temperament` gives it.
    public mutating func noteOn(pitch: UInt8, velocity: UInt8) {
        guard pitch <= 127 else { return }
        noteOn(pitch: pitch, velocity: velocity, hertz: temperament.frequency(of: Int(pitch)))
    }

    /// A key sung at `hertz`, whatever its name: a pitch tracked from a voice, a harmony above it.
    /// `pitch` is how `noteOff` finds the note again. A frequency that is not a finite number above
    /// zero and below Nyquist sings nothing and takes no voice; velocity 0 is a key let go.
    public mutating func noteOn(pitch: UInt8, velocity: UInt8, hertz: Float) {
        guard pitch <= 127 else { return }
        guard velocity > 0 else {
            noteOff(pitch: pitch)
            return
        }
        guard hertz.isFinite, hertz > 0, hertz < 0.5 * sampleRate else { return }
        // Nothing sounds: the breath starts from its beginning, as the note does, so the same note
        // struck into silence sings the same samples every time.
        if !isSounding { settleBreath() }
        let index = voiceIndex(for: pitch)
        voices[index].start(pitch: pitch, hertz: hertz, velocity: velocity, order: nextOrder, shared: shared)
        nextOrder &+= 1
    }

    public mutating func noteOff(pitch: UInt8) {
        for index in voices.indices where voices[index].isHeld && voices[index].pitch == pitch {
            voices[index].release()
        }
    }

    /// Releases every held note.
    public mutating func allNotesOff() {
        for index in voices.indices where voices[index].isHeld { voices[index].release() }
    }

    /// Silences everything at once (panic); `allNotesOff` when a click is not wanted.
    public mutating func reset() {
        for index in voices.indices { voices[index].silence() }
    }

    /// Adds every sounding note, and the breath under them, into `buffer`; the caller clears it
    /// first. In pieces of at most `chunk` samples. Nothing allocates.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard !buffer.isEmpty, isSounding else { return }
        let shared = self.shared
        // The levels' storage is held aside for the render (an empty array allocates nothing), so the
        // notes write into it while the source's own storage is not being read.
        var levels: [Float] = []
        swap(&levels, &breathLevels)
        var done = 0
        while done < buffer.count {
            let count = Swift.min(Self.chunk, buffer.count - done)
            let start = buffer.startIndex + done
            let piece = UnsafeMutableBufferPointer(rebasing: buffer[start..<(start + count)])
            levels.withUnsafeMutableBufferPointer { (breath: inout UnsafeMutableBufferPointer<Float>) in
                for index in 0..<count { breath[index] = 0 }
                voices.withUnsafeMutableBufferPointer { (all: inout UnsafeMutableBufferPointer<Voice>) in
                    for index in all.indices where all[index].isActive {
                        all[index].render(into: piece, breath: breath, shared: shared)
                    }
                }
            }
            if breathing { addBreath(into: piece, levels: levels) }
            done += count
        }
        swap(&levels, &breathLevels)
    }

    // MARK: Inside

    /// The envelope at the current Character: between the two snapshots around it, band by band in a
    /// straight line in decibels — `VoiceAvatar.envelope(character:)`'s rule — and the floor for an
    /// avatar of breath only. Only when Character has moved, unless `always`.
    private mutating func morph(always: Bool = false) {
        let character = settings.character
        guard always || !(Swift.abs(character - morphedCharacter) < Self.characterStep) else { return }
        morphedCharacter = character
        var levels = SIMD64<Float>(repeating: VoiceAvatar.floorDecibels)
        if snapshotCount > 0 {
            let width = VoiceAvatar.bandCount
            let position = character * Float(snapshotCount - 1)
            let lower = Swift.min(Int(position), snapshotCount - 1)
            let upper = Swift.min(lower + 1, snapshotCount - 1)
            let t = position - Float(lower)
            for band in 0..<width {
                let darker = snapshots[lower * width + band], brighter = snapshots[upper * width + band]
                levels[band] = darker + (brighter - darker) * t
            }
        }
        shared.envelope = levels
        shared.generation &+= 1
    }

    /// The level and the vibrato the notes follow, from the settings and the avatar.
    private mutating func follow() {
        shared.level = settings.level
        shared.vibratoRate = avatarVibratoRate
        shared.vibratoDepth = avatarVibratoDepth * settings.vibrato
    }

    /// The breath from its beginning: the noise's seed, the bands empty, the gains where they go.
    private mutating func settleBreath() {
        breathNoise = Self.breathSeed
        breathCountdown = 0
        breathing = hasBreath
        let bands = Self.breathBandCount
        breathBank.withUnsafeMutableBufferPointer { (lanes: inout UnsafeMutableBufferPointer<Float>) in
            for index in 0..<(4 * bands) { lanes[index] = 0 }
            for band in 0..<bands { lanes[7 * bands + band] = lanes[8 * bands + band] }
        }
    }

    /// The breath under `piece`: the noise through the bands at their gains, at each sample as loud
    /// as the notes' breath levels add up in power (`levels`, squared and added). The gains glide
    /// toward their targets once per control step; once they have glided out, the breath stops.
    private mutating func addBreath(into piece: UnsafeMutableBufferPointer<Float>, levels: [Float]) {
        let bands = Self.breathBandCount
        let k = Self.breathDamping
        let pole = shared.balancePole, smallest = Self.amplitudeFloor
        let keep = hasBreath
        var noise = breathNoise, countdown = breathCountdown, sounding = true
        levels.withUnsafeBufferPointer { (strengths: UnsafeBufferPointer<Float>) in
            breathBank.withUnsafeMutableBufferPointer { (lanes: inout UnsafeMutableBufferPointer<Float>) in
                let gains = 7 * bands, targets = 8 * bands
                for index in piece.indices {
                    if countdown <= 0 {
                        countdown = AvatarSource.controlInterval
                        var loudest: Float = 0
                        for band in 0..<bands {
                            var gain = lanes[targets + band] + (lanes[gains + band] - lanes[targets + band]) * pole
                            if Swift.abs(gain - lanes[targets + band]) < smallest { gain = lanes[targets + band] }
                            lanes[gains + band] = gain
                            loudest = Swift.max(loudest, Swift.abs(gain))
                        }
                        if !keep, loudest < smallest { sounding = false }
                    }
                    countdown -= 1
                    noise ^= noise << 13
                    noise ^= noise >> 17
                    noise ^= noise << 5
                    let white = Float(Int32(bitPattern: noise)) / Float(Int32.max)
                    var sum: Float = 0
                    for band in 0..<bands {
                        let a1 = lanes[4 * bands + band], a2 = lanes[5 * bands + band], a3 = lanes[6 * bands + band]
                        // The first stage, its band output at unity peak, into the second.
                        var ic1 = lanes[band], ic2 = lanes[bands + band]
                        var v3 = white - ic2
                        var v1 = a1 * ic1 + a2 * v3
                        var v2 = ic2 + a2 * ic1 + a3 * v3
                        lanes[band] = 2 * v1 - ic1
                        lanes[bands + band] = 2 * v2 - ic2
                        let passed = v1 * k
                        ic1 = lanes[2 * bands + band]
                        ic2 = lanes[3 * bands + band]
                        v3 = passed - ic2
                        v1 = a1 * ic1 + a2 * v3
                        v2 = ic2 + a2 * ic1 + a3 * v3
                        lanes[2 * bands + band] = 2 * v1 - ic1
                        lanes[3 * bands + band] = 2 * v2 - ic2
                        sum += lanes[gains + band] * v1 * k
                    }
                    let strength = strengths[index]
                    if strength > 0 { piece[index] += sum * strength.squareRoot() }
                }
            }
        }
        breathNoise = noise
        breathCountdown = countdown
        if !sounding {
            breathing = false
            settleBreath()
        }
    }

    /// The voice a key strikes: its own while it sounds, else a free one, else the oldest released,
    /// else the oldest held (`PolySynth`'s order). The voices are read in place, none copied.
    private func voiceIndex(for pitch: UInt8) -> Int {
        voices.withUnsafeBufferPointer { (all: UnsafeBufferPointer<Voice>) -> Int in
            var free: Int?
            var oldestReleased: (index: Int, order: UInt64)?
            var oldestHeld: (index: Int, order: UInt64)?
            for index in all.indices {
                let order = all[index].startOrder
                if all[index].isActive, all[index].pitch == pitch { return index }
                if !all[index].isActive {
                    if free == nil { free = index }
                } else if !all[index].isHeld {
                    // Orders start at 1 and only rise: none reaches the largest one.
                    if order < (oldestReleased?.order ?? .max) { oldestReleased = (index, order) }
                } else if order < (oldestHeld?.order ?? .max) {
                    oldestHeld = (index, order)
                }
            }
            return free ?? oldestReleased?.index ?? oldestHeld?.index ?? 0
        }
    }

    /// A note's envelope: the attack and release asked for, held at full level between them.
    static func noteEnvelope(_ settings: Settings) -> Envelope.Settings {
        Envelope.Settings(attack: settings.attack, decay: 0.001, sustain: 1, release: settings.release)
    }

    /// The centre of breath band `band`, in hertz: 62.5 · 2^(band / 2).
    static func breathCentre(_ band: Int) -> Double {
        breathLowestHertz * Foundation.pow(2, Double(band) / 2)
    }

    /// The breath bands' TPT coefficients at `sampleRate` — the ones `ZDFStage.process` works out on
    /// every sample, a₁ = 1 / (1 + g(g + k)), a₂ = g·a₁, a₃ = g·a₂ — all a₁ first, then the a₂, then the
    /// a₃. Allocates: `init` only.
    static func breathCoefficients(sampleRate: Float) -> [Float] {
        let bands = breathBandCount
        var coefficients = [Float](repeating: 0, count: 3 * bands)
        let k = breathDamping
        for band in 0..<bands {
            let g = ZDFStage.g(breathCentre(band), sampleRate: Double(sampleRate))
            let first = 1 / (1 + g * (g + k))
            coefficients[band] = first
            coefficients[bands + band] = g * first
            coefficients[2 * bands + band] = g * g * first
        }
        return coefficients
    }

    /// The K-weighting's power gain at each band centre of the avatar grid, at `sampleRate`: the
    /// weighting BS.1770 measures loudness through (`KWeighting`), read from its impulse response,
    /// 100 ms long, by which time it has rung out. A centre at or above Nyquist takes the last one
    /// below it: nothing sounds there. Allocates: `init` only.
    static func loudnessWeights(sampleRate: Float) -> SIMD64<Float> {
        let rate = Double(sampleRate)
        var weighting = KWeighting(sampleRate: rate)
        let length = Swift.max(1, Int(rate * 0.1))
        let response = (0..<length).map { (index: Int) -> Double in weighting.process(index == 0 ? 1 : 0) }
        var weights = SIMD64<Float>(repeating: 1)
        for band in 0..<VoiceAvatar.bandCount {
            let hertz = Double(VoiceAvatar.centre(ofBand: band))
            guard hertz < rate / 2 else {
                weights[band] = band > 0 ? weights[band - 1] : 1
                continue
            }
            let step = 2 * Double.pi * hertz / rate
            let turnCos = Foundation.cos(step), turnSin = Foundation.sin(step)
            var cosine = 1.0, sine = 0.0, re = 0.0, im = 0.0
            for x in response {
                re += x * cosine
                im -= x * sine
                (cosine, sine) = (cosine * turnCos - sine * turnSin, sine * turnCos + cosine * turnSin)
            }
            weights[band] = Float(re * re + im * im)
        }
        return weights
    }

    /// How much K-weighted power the breath bands pass together for white noise uniform in −1 … 1:
    /// entry b · 17 + c is the mean of band b's output times band c's, both K-weighted, worked out
    /// from their impulse responses — the noise's variance, ⅓, times the sum of their products —
    /// 100 ms long, by which time the lowest band has rung out. Allocates: `init` only.
    static func breathCrossPowers(_ coefficients: [Float], sampleRate: Float) -> [Float] {
        let bands = breathBandCount
        let rate = Double(sampleRate)
        let length = Swift.max(1, Int(rate * 0.1))
        let k = Double(breathDamping)
        var responses: [[Double]] = []
        for band in 0..<bands {
            var weighting = KWeighting(sampleRate: rate)
            let a1 = Double(coefficients[band]), a2 = Double(coefficients[bands + band]), a3 = Double(coefficients[2 * bands + band])
            var first = (0.0, 0.0), second = (0.0, 0.0)
            var response = [Double](repeating: 0, count: length)
            for index in 0..<length {
                var v3 = (index == 0 ? 1.0 : 0.0) - first.1
                var v1 = a1 * first.0 + a2 * v3
                var v2 = first.1 + a2 * first.0 + a3 * v3
                first = (2 * v1 - first.0, 2 * v2 - first.1)
                v3 = v1 * k - second.1
                v1 = a1 * second.0 + a2 * v3
                v2 = second.1 + a2 * second.0 + a3 * v3
                second = (2 * v1 - second.0, 2 * v2 - second.1)
                response[index] = weighting.process(v1 * k)
            }
            responses.append(response)
        }
        var powers = [Float](repeating: 0, count: bands * bands)
        for b in 0..<bands {
            for c in b..<bands {
                var sum = 0.0
                for index in 0..<length { sum += responses[b][index] * responses[c][index] }
                powers[b * bands + c] = Float(sum / 3)
                powers[c * bands + b] = Float(sum / 3)
            }
        }
        return powers
    }
}

extension AvatarSource {
    /// A note's harmonics side by side in memory, so the loops in `sumPartials` and `rebuild` run
    /// over plain floats — `DDSPSource.Partials`, for the same reason: arithmetic on wide SIMD values
    /// compiles element by element.
    struct Partials {
        /// Each harmonic's place in its cycle, 0 ..< 1.
        var phases: SIMD64<Float>
        /// Each harmonic's amplitude now, gliding toward `targets`.
        var amplitudes: SIMD64<Float>
        /// The amplitudes for the pitch and the envelope of the last control step.
        var targets: SIMD64<Float>
        /// The harmonic numbers 1 … 64.
        var ratios: SIMD64<Float>
        /// Scratch: what each harmonic plays this sample, before the sum.
        var heard: SIMD64<Float>
    }

    /// One note's signal path: harmonics, an envelope, a vibrato; its breath level for the source.
    struct Voice: Sendable {
        private(set) var pitch: UInt8 = 0
        private(set) var isHeld = false
        /// Rises with every note-on across the source; the smallest is the oldest.
        private(set) var startOrder: UInt64 = 0
        private var envelope: Envelope
        /// The note's frequency before the vibrato, in hertz.
        private var hertz: Float = 0
        /// The velocity's gain now and where it is going, and the level now.
        private var gain: Float = 0
        private var gainTarget: Float = 0
        private var level: Float = 0
        /// The tone's part of the sound now, gliding to the source's.
        private var tone: Float = 0
        private var vibratoPhase: Float = 0
        /// How far the vibrato has set in, 0 … 1, and its depth now, in cents.
        private var vibratoShare: Float = 0
        private var vibratoDepth: Float = 0
        /// The increment now, in cycles per sample, how far it moves each sample, and where the last
        /// control step sent it.
        private var increment: Float = 0
        private var incrementStep: Float = 0
        private var incrementGoal: Float = 0
        /// The pitch (log₂ of the increment) and the envelope the harmonics' levels were read for.
        private var tableOctaves: Float = .nan
        private var tableGeneration: UInt32 = 0
        /// Struck on a silent voice and not yet stepped: the first step takes the pitch and the
        /// harmonics' levels at once.
        private var fresh = true
        private var countdown = 0
        /// How many harmonics, from the first, the loop runs over: up to the last one still sounding,
        /// below the taper or above it and still gliding out (`flush`).
        private var audible = 0
        private var partials: Partials
        private let amplitudeLane: Int
        private let targetLane: Int
        private let ratioLane: Int
        private let heardLane: Int
        static let partialLanes = 5 * 64

        init(timing: Envelope.Settings, sampleRate: Float) {
            envelope = Envelope(settings: timing, sampleRate: sampleRate)
            partials = Partials(phases: DDSPSource.startPhases, amplitudes: SIMD64(repeating: 0), targets: SIMD64(repeating: 0),
                                ratios: DDSPSource.ratios, heard: SIMD64(repeating: 0))
            let float = MemoryLayout<Float>.stride
            let bank = MemoryLayout<SIMD64<Float>>.stride / float
            amplitudeLane = (MemoryLayout<Partials>.offset(of: \Partials.amplitudes) ?? bank * float) / float
            targetLane = (MemoryLayout<Partials>.offset(of: \Partials.targets) ?? 2 * bank * float) / float
            ratioLane = (MemoryLayout<Partials>.offset(of: \Partials.ratios) ?? 3 * bank * float) / float
            heardLane = (MemoryLayout<Partials>.offset(of: \Partials.heard) ?? 4 * bank * float) / float
        }

        var isActive: Bool { envelope.isActive }

        /// The harmonics the loop runs over now (`audible`); none while the tone is silent.
        var harmonicsInPlay: Int { tone > 0 ? audible : 0 }

        /// A key struck this voice. On a silent voice everything starts from its beginning: the
        /// phases, the vibrato, the level.
        mutating func start(pitch: UInt8, hertz: Float, velocity: UInt8, order: UInt64, shared: Shared) {
            let wasSilent = !envelope.isActive
            self.pitch = pitch
            isHeld = true
            startOrder = order
            self.hertz = hertz
            let strength = Float(Swift.min(velocity, 127)) / 127
            gainTarget = strength * strength
            if wasSilent {
                gain = gainTarget
                level = shared.level
                tone = shared.tone
                partials.phases = DDSPSource.startPhases
                partials.amplitudes = SIMD64(repeating: 0)
                vibratoPhase = 0
                vibratoShare = 0
                vibratoDepth = shared.vibratoDepth
                fresh = true
            }
            countdown = 0
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

        mutating func retime(_ timing: Envelope.Settings) {
            envelope.update(timing)
        }

        /// Adds this note's harmonics into `buffer` and its breath level, squared, into `breath`.
        /// Nothing allocates.
        @inline(__always)
        mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, breath: UnsafeMutableBufferPointer<Float>,
                             shared: Shared) {
            guard envelope.isActive else { return }
            for index in buffer.indices {
                if countdown <= 0 {
                    guard control(shared) else {
                        silence()
                        return
                    }
                    countdown = AvatarSource.controlInterval
                }
                countdown -= 1
                level = shared.level + (level - shared.level) * shared.levelPole
                gain = gainTarget + (gain - gainTarget) * shared.levelPole
                increment += incrementStep
                let strength = envelope.next() * gain * level
                var sample: Float = 0
                if tone > 0, audible > 0 { sample = sumPartials(increment: increment) * tone * strength }
                guard sample.isFinite, strength.isFinite else {
                    silence()
                    return
                }
                buffer[index] += sample
                breath[index] += strength * strength
                if !envelope.isActive { return }
            }
        }

        /// Every `controlInterval` samples: the vibrato a step on and the pitch it puts the note at,
        /// the harmonics' levels when the pitch or the envelope moved, the faded ones let go
        /// (`flush`), the tone's share toward the source's. False when the pitch is one no harmonic
        /// can sound at.
        private mutating func control(_ shared: Shared) -> Bool {
            let interval = Float(AvatarSource.controlInterval)
            vibratoDepth = shared.vibratoDepth + (vibratoDepth - shared.vibratoDepth) * shared.vibratoPole
            vibratoShare = Swift.min(1, vibratoShare + shared.onsetStep)
            var cents: Float = 0
            if shared.vibratoRate > 0 {
                vibratoPhase += shared.vibratoRate * interval / shared.sampleRate
                vibratoPhase -= vibratoPhase.rounded(.down)
                cents = vibratoDepth * vibratoShare * sinf(2 * Float.pi * vibratoPhase)
            }
            let goal = hertz * exp2f(cents / 1_200) / shared.sampleRate
            guard goal.isFinite, goal > 0, goal < 0.5 else { return false }
            if fresh {
                increment = goal
                incrementStep = 0
            } else {
                increment = incrementGoal
                incrementStep = (goal - increment) / interval
            }
            incrementGoal = goal
            // An avatar of breath only has no harmonics to read.
            let voiced = shared.tone > 0 || tone > 0
            if voiced, fresh || shared.generation != tableGeneration
                || !(Swift.abs(log2f(goal) - tableOctaves) < AvatarSource.pitchStep) {
                rebuild(increment: goal, shared: shared)
            }
            if fresh {
                partials.amplitudes = partials.targets
                fresh = false
            }
            flush()
            tone = shared.tone + (tone - shared.tone) * shared.balancePole
            if Swift.abs(tone - shared.tone) < 1e-6 { tone = shared.tone }
            return true
        }

        /// Each harmonic's level for the increment `dt`: the envelope at its frequency in hertz,
        /// faded by the taper, the set scaled to the K-weighted power of a full-scale sine.
        private mutating func rebuild(increment dt: Float, shared: Shared) {
            tableGeneration = shared.generation
            tableOctaves = log2f(dt)
            let last = VoiceAvatar.bandCount - 1
            // The note's distance above the grid's first centre in octaves, and bands per octave.
            let offset = log2f(dt * shared.sampleRate / VoiceAvatar.lowestHertz)
            let perOctave = Float(last) / log2f(VoiceAvatar.highestHertz / VoiceAvatar.lowestHertz)
            let levels = shared.envelope, weights = shared.weights
            let logs = DDSPSource.log2Ratios
            let taperStart = DDSPSource.taperStart, taperScale = DDSPSource.taperScale
            let toOctaves = AvatarSource.decibelsToOctaves, smallest = AvatarSource.amplitudeFloor
            let t = targetLane, r = ratioLane
            let total = AvatarSource.partialCount
            withUnsafeMutablePointer(to: &partials) { (state: UnsafeMutablePointer<Partials>) in
                state.withMemoryRebound(to: Float.self, capacity: Self.partialLanes) { (lanes: UnsafeMutablePointer<Float>) in
                    var power: Float = 0
                    for i in 0..<total {
                        let position = (lanes[r + i] * dt - taperStart) * taperScale
                        let fade = Swift.min(Swift.max(position, 0), 1)
                        let taper = 1 - fade * fade * (3 - fade * 2)
                        guard taper > 0 else {
                            lanes[t + i] = 0
                            continue
                        }
                        let band = Swift.min(Swift.max((logs[i] + offset) * perOctave, 0), Float(last))
                        let lower = Swift.min(Int(band), last)
                        let upper = Swift.min(lower + 1, last)
                        let share = band - Float(lower)
                        let decibels = levels[lower] + (levels[upper] - levels[lower]) * share
                        let weight = weights[lower] + (weights[upper] - weights[lower]) * share
                        let amplitude = exp2f(decibels * toOctaves) * taper
                        lanes[t + i] = amplitude
                        power += amplitude * amplitude * weight
                    }
                    let scale: Float = power > 0 ? 1 / power.squareRoot() : 0
                    for i in 0..<total {
                        let amplitude = lanes[t + i] * scale
                        lanes[t + i] = amplitude < smallest ? 0 : amplitude
                    }
                }
            }
        }

        /// Every control step, once the levels are read: a harmonic gliding toward silence is set to
        /// zero as soon as it is quieter than `amplitudeFloor`, and the loop ends after the last
        /// harmonic still sounding — so one left above the taper by a higher note, a vibrato or a
        /// taken voice glides out and then costs nothing, and none sticks in the subnormal range,
        /// where the glide stops short of zero. `DDSPSource.updateTaper` flushes its partials so.
        private mutating func flush() {
            let a = amplitudeLane, t = targetLane
            let smallest = AvatarSource.amplitudeFloor
            let total = AvatarSource.partialCount
            audible = withUnsafeMutablePointer(to: &partials) { (state: UnsafeMutablePointer<Partials>) -> Int in
                state.withMemoryRebound(to: Float.self, capacity: Self.partialLanes) { (lanes: UnsafeMutablePointer<Float>) -> Int in
                    var sounding = 0
                    for i in 0..<total {
                        if lanes[t + i] == 0, Swift.abs(lanes[a + i]) < smallest { lanes[a + i] = 0 }
                        if lanes[t + i] != 0 || lanes[a + i] != 0 { sounding = i + 1 }
                    }
                    return sounding
                }
            }
        }

        /// Every harmonic one step on — its phase by its frequency, its amplitude toward its target —
        /// and the sum of what they play; `DDSPSource.sumPartials`'s two loops.
        @inline(__always)
        private mutating func sumPartials(increment dt: Float) -> Float {
            let glide = AvatarSource.amplitudeGlide
            let a = amplitudeLane, t = targetLane, r = ratioLane, h = heardLane
            let count = audible
            return withUnsafeMutablePointer(to: &partials) { (state: UnsafeMutablePointer<Partials>) -> Float in
                state.withMemoryRebound(to: Float.self, capacity: Self.partialLanes) { (lanes: UnsafeMutablePointer<Float>) -> Float in
                    for i in 0..<count {
                        var phase = lanes[i] + lanes[r + i] * dt
                        phase -= phase.rounded(.down)
                        lanes[i] = phase
                        let amplitude = lanes[a + i] + (lanes[t + i] - lanes[a + i]) * glide
                        lanes[a + i] = amplitude
                        lanes[h + i] = DDSPSource.sine(phase) * amplitude
                    }
                    var sum: Float = -0.0
                    for i in 0..<count { sum += lanes[h + i] }
                    return sum
                }
            }
        }
    }
}

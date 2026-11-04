import Foundation

/// A synthesized drum kit: eight one-shot voices on the General MIDI drum map, so a pattern
/// sounds without a single sample file. Render-thread safe — every voice is preallocated, every
/// decay is a precomputed per-sample multiplier, the noise is a 32-bit xorshift.
public struct DrumKit: Sendable {
    public enum Piece: Int, CaseIterable, Sendable {
        case kick, snare, clap, lowTom, highTom, closedHat, openHat, crash

        /// The General MIDI drum notes each piece answers to; anything else is ignored.
        public static func forPitch(_ pitch: UInt8) -> Piece? {
            switch pitch {
            case 35, 36: .kick
            case 38, 40: .snare
            case 37, 39: .clap
            case 41, 43, 45: .lowTom
            case 47, 48, 50: .highTom
            case 42, 44: .closedHat
            case 46: .openHat
            case 49, 51, 52, 55, 57, 59: .crash
            default: nil
            }
        }
    }

    /// One piece's sound on top of what it is: its tune in semitones (−24 … 24), its decay as a
    /// factor on its own length (0.1 … 4) and its level as a factor (0 … 1). The defaults play the
    /// piece exactly as it always sounded.
    public struct PieceSound: Equatable, Sendable {
        public var tune: Float
        public var decay: Float
        public var level: Float

        public init(tune: Float = 0, decay: Float = 1, level: Float = 1) {
            self.tune = tune
            self.decay = decay
            self.level = level
        }

        /// The sound a voice can play: finite and inside its range.
        var playable: PieceSound {
            PieceSound(tune: tune.isFinite ? Swift.min(Swift.max(tune, -24), 24) : 0,
                       decay: decay.isFinite ? Swift.min(Swift.max(decay, 0.1), 4) : 1,
                       level: level.isFinite ? Swift.min(Swift.max(level, 0), 1) : 1)
        }
    }

    /// The hats' sound: filtered noise (as the kit always played them), or six detuned square
    /// waves through a highpass — the metal of an analog drum machine's hats.
    public enum HatModel: Int, Sendable { case noise, metal }
    /// The toms' sound: a sine with a pitch drop (as always), or a struck membrane — six modal
    /// resonators at the circular membrane's mode ratios, the higher modes dying sooner.
    public enum TomModel: Int, Sendable { case sine, modal }

    private var voices: [DrumVoice]
    private let sampleRate: Float

    public init(sampleRate: Float = 48_000) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        voices = Piece.allCases.map { DrumVoice(piece: $0, sampleRate: rate) }
    }

    public var activeVoiceCount: Int { voices.reduce(0) { $0 + ($1.isActive ? 1 : 0) } }

    public mutating func noteOn(pitch: UInt8, velocity: UInt8) {
        guard velocity > 0, let piece = Piece.forPitch(pitch) else { return }
        // A closed hat cuts the open one off, as on every drum machine.
        if piece == .closedHat { voices[Piece.openHat.rawValue].choke() }
        voices[piece.rawValue].trigger(velocity: velocity)
    }

    /// The piece's tune, decay and level from its next hit on: a ringing hit keeps its sound, so
    /// a change never steps inside one. Render-safe.
    public mutating func setSound(_ sound: PieceSound, for piece: Piece) {
        voices[piece.rawValue].sound = sound.playable
    }

    public func sound(of piece: Piece) -> PieceSound { voices[piece.rawValue].sound }

    /// How far the kick's pitch falls on a hit, as a factor on the kit's own drop (1): 0 is a flat
    /// sine, 4 the long dive of an 808 kick. From the next hit on; render-safe.
    public mutating func setKickGlide(_ amount: Float) {
        voices[Piece.kick.rawValue].glide = amount.isFinite ? Swift.min(Swift.max(amount, 0), 4) : 1
    }

    /// Both hats' model from their next hit on. Render-safe.
    public mutating func setHatModel(_ model: HatModel) {
        voices[Piece.closedHat.rawValue].metal = model == .metal
        voices[Piece.openHat.rawValue].metal = model == .metal
    }

    /// Both toms' model from their next hit on. Render-safe.
    public mutating func setTomModel(_ model: TomModel) {
        voices[Piece.lowTom.rawValue].modal = model == .modal
        voices[Piece.highTom.rawValue].modal = model == .modal
    }

    /// Drums are one-shots: a note-off changes nothing.
    public mutating func noteOff(pitch: UInt8) {}

    /// Lets ringing hits finish; there is nothing held to release.
    public mutating func allNotesOff() {}

    public mutating func reset() {
        for i in voices.indices { voices[i].silence() }
    }

    /// Adds every sounding piece into `buffer`; the caller clears it first.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard !buffer.isEmpty else { return }
        voices.withUnsafeMutableBufferPointer { all in
            for i in all.indices where all[i].isActive {
                all[i].render(into: buffer)
            }
        }
    }
}

struct DrumVoice: Sendable {
    let piece: DrumKit.Piece
    private let sampleRate: Float

    private(set) var isActive = false
    /// What the next hit plays: tune, decay and level, the kick's glide, the hats' and toms' model.
    var sound = DrumKit.PieceSound()
    var glide: Float = 1
    var metal = false
    var modal = false
    /// The tune as a frequency ratio, taken at the hit.
    private var ratio: Float = 1
    /// The model the sounding hit plays; a change waits for the next hit.
    private var playsMetal = false
    private var playsModal = false
    /// The metal hat's six square oscillators (lanes 0 … 5) and the membrane's six modes.
    private var squarePhase = SIMD8<Float>(repeating: 0)
    private var squareStep = SIMD8<Float>(repeating: 0)
    private var modeA1 = SIMD8<Float>(repeating: 0)
    private var modeA2 = SIMD8<Float>(repeating: 0)
    private var modeY1 = SIMD8<Float>(repeating: 0)
    private var modeY2 = SIMD8<Float>(repeating: 0)
    private var gain: Float = 0
    private var amp: Float = 0
    private var ampDecay: Float = 1
    /// Pitch sweep for kick and toms: `sweep` decays toward 0 and adds to the base frequency.
    private var sweep: Float = 0
    private var sweepDecay: Float = 1
    private var phase: Float = 0
    private var elapsed: Int = 0
    private var noise: UInt32 = 0x9E37_79B9
    private var filter: SVFilter
    /// A hit on a voice that still rings starts its waveform over at phase 0, while the old one
    /// stood wherever it was: what the voice played last carries over and fades in ~2.5 ms, so a
    /// tom or kick roll does not click on every hit (audit 2026-10-23).
    private var lastOutput: Float = 0
    private var carry: Float = 0
    private let carryDecay: Float
    static let carrySeconds: Float = 0.0025

    /// −60 dB: below this a voice is inaudible and stops.
    private static let floor: Float = 1e-3

    init(piece: DrumKit.Piece, sampleRate: Float) {
        self.piece = piece
        self.sampleRate = sampleRate
        carryDecay = Self.coefficient(seconds: Self.carrySeconds, sampleRate: sampleRate)
        let setup: (mode: SVFilter.Mode, cutoff: Float) = switch piece {
        case .snare: (.bandpass, 1_800)
        case .clap: (.bandpass, 1_200)
        case .closedHat, .openHat: (.highpass, 7_000)
        case .crash: (.highpass, 5_000)
        case .kick, .lowTom, .highTom: (.lowpass, 8_000)
        }
        filter = SVFilter(mode: setup.mode, cutoff: setup.cutoff, resonance: 0.2, sampleRate: sampleRate)
    }

    /// Seconds for the amplitude to fall by a factor of e.
    private var decaySeconds: Float {
        switch piece {
        case .kick: 0.32
        case .snare: 0.13
        case .clap: 0.12
        case .lowTom: 0.28
        case .highTom: 0.22
        case .closedHat: 0.035
        case .openHat: 0.30
        case .crash: 0.80
        }
    }

    private var baseHz: Float {
        switch piece {
        case .kick: 48
        case .snare: 185
        case .lowTom: 95
        case .highTom: 150
        default: 0
        }
    }

    private var sweepHz: Float {
        switch piece {
        case .kick: 120
        case .lowTom, .highTom: 60
        default: 0
        }
    }

    /// The analog drum machine's hat oscillators (Hz): six square waves at inharmonic ratios.
    static let metalHz = SIMD8<Float>(205.3, 304.4, 369.6, 522.7, 540, 800, 0, 0)
    static let metalStart = SIMD8<Float>(0, 0.37, 0.71, 0.13, 0.52, 0.89, 0, 0)
    /// The circular membrane's first six mode ratios (zeros of the Bessel functions) and how loud
    /// each mode is struck.
    static let membraneRatios = SIMD8<Float>(1, 1.593, 2.136, 2.296, 2.653, 2.917, 0, 0)
    static let membraneLevels = SIMD8<Float>(1, 0.55, 0.4, 0.3, 0.2, 0.15, 0, 0)

    mutating func trigger(velocity: UInt8) {
        carry = isActive ? lastOutput : 0
        let v = Float(velocity) / 127
        // The level factor 1 leaves the gain exactly as it always was.
        gain = sound.level == 1 ? v * v : v * v * sound.level
        ratio = sound.tune == 0 ? 1 : exp2f(sound.tune / 12)
        playsMetal = metal && (piece == .closedHat || piece == .openHat)
        playsModal = modal && (piece == .lowTom || piece == .highTom)
        amp = 1
        let seconds = sound.decay == 1 ? decaySeconds : decaySeconds * sound.decay
        ampDecay = Self.coefficient(seconds: seconds, sampleRate: sampleRate)
        sweep = piece == .kick && glide != 1 ? sweepHz * glide : sweepHz
        sweepDecay = Self.coefficient(seconds: piece == .kick ? 0.03 : 0.05, sampleRate: sampleRate)
        phase = 0
        elapsed = 0
        filter.reset()
        // A tuned noise piece moves its filter; the default cutoff is the one `init` set.
        if ratio != 1, let cutoff = noiseCutoff {
            filter.setCutoff(Swift.min(cutoff * ratio, 0.45 * sampleRate))
        } else if let cutoff = noiseCutoff {
            filter.setCutoff(cutoff)
        }
        if playsMetal {
            // Spread starts, the same on every hit: six squares that all start high would sum to
            // one spike on the first sample.
            squarePhase = Self.metalStart
            squareStep = Self.metalHz * (ratio / sampleRate)
        }
        if playsModal {
            // Each mode a two-pole resonator, struck once: it rings sin(ωn)·rⁿ from 0, so the hit
            // starts without a step. The higher modes die sooner, as a skin's do.
            let base = baseHz * ratio
            for k in 0..<6 {
                let hz = Swift.min(base * Self.membraneRatios[k], 0.45 * sampleRate)
                let w = 2 * Float.pi * hz / sampleRate
                let r = Self.coefficient(seconds: seconds * 1.5 / (1 + 0.8 * Float(k)), sampleRate: sampleRate)
                modeA1[k] = 2 * r * cosf(w)
                modeA2[k] = -r * r
                modeY1[k] = Self.membraneLevels[k] * sinf(w)
                modeY2[k] = 0
            }
        }
        isActive = true
    }

    /// The filter cutoff of a piece that filters noise; nil for the tonal ones.
    private var noiseCutoff: Float? {
        switch piece {
        case .snare: 1_800
        case .clap: 1_200
        case .closedHat, .openHat: 7_000
        case .crash: 5_000
        case .kick, .lowTom, .highTom: nil
        }
    }

    /// A fast fade instead of a hard stop, so the choke never clicks.
    mutating func choke() {
        guard isActive else { return }
        ampDecay = Self.coefficient(seconds: 0.004, sampleRate: sampleRate)
    }

    mutating func silence() {
        isActive = false
        amp = 0
        carry = 0
        lastOutput = 0
        filter.reset()
    }

    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        let twoPi = 2 * Float.pi
        let clapGap = Int(0.010 * sampleRate)
        for i in buffer.indices {
            var sample: Float
            switch piece {
            case .lowTom where playsModal, .highTom where playsModal:
                // y[n] plays, then the resonators step on: the first sample is y[0] = 0.
                sample = 0.7 * modeY2.sum()
                let y = modeA1 * modeY1 + modeA2 * modeY2
                modeY2 = modeY1
                modeY1 = y
            case .kick, .lowTom, .highTom:
                let hz = ratio == 1 ? baseHz + sweep : (baseHz + sweep) * ratio
                phase += hz / sampleRate
                if phase >= 1 { phase -= 1 }
                sample = sinf(twoPi * phase)
                sweep *= sweepDecay
                if piece == .kick, elapsed < Int(0.002 * sampleRate) {
                    sample += 0.3 * nextNoise()
                }
            case .snare:
                phase += (ratio == 1 ? baseHz : baseHz * ratio) / sampleRate
                if phase >= 1 { phase -= 1 }
                let tone = sinf(twoPi * phase) * amp
                sample = 0.4 * tone + 0.8 * filter.process(nextNoise())
            case .clap:
                // Three quick bursts, then the tail: the hand-clap shape.
                let burst = elapsed < 3 * clapGap ? Float(1) - Float(elapsed % Swift.max(1, clapGap)) / Float(Swift.max(1, clapGap)) : 0
                sample = filter.process(nextNoise()) * Swift.max(burst, elapsed >= 3 * clapGap ? 1 : 0)
            case .closedHat where playsMetal, .openHat where playsMetal:
                squarePhase += squareStep
                squarePhase -= squarePhase.rounded(.down)
                let squares = SIMD8<Float>(repeating: 1).replacing(with: -1, where: squarePhase .>= 0.5)
                var sum: Float = 0
                for k in 0..<6 { sum += squares[k] }
                sample = 0.7 * filter.process(sum)
            case .closedHat, .openHat, .crash:
                sample = filter.process(nextNoise())
            }
            let output = sample * amp * gain * 0.8 + carry
            buffer[i] += output
            lastOutput = output
            carry *= carryDecay
            amp *= ampDecay
            elapsed &+= 1
            if amp < Self.floor {
                silence()
                return
            }
        }
    }

    private mutating func nextNoise() -> Float {
        noise ^= noise << 13
        noise ^= noise >> 17
        noise ^= noise << 5
        return Float(noise) / Float(UInt32.max) * 2 - 1
    }

    static func coefficient(seconds: Float, sampleRate: Float) -> Float {
        guard seconds > 0, sampleRate > 0 else { return 0 }
        return expf(-1 / (seconds * sampleRate))
    }
}

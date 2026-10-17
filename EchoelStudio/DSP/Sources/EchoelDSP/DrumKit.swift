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

    /// −60 dB: below this a voice is inaudible and stops.
    private static let floor: Float = 1e-3

    init(piece: DrumKit.Piece, sampleRate: Float) {
        self.piece = piece
        self.sampleRate = sampleRate
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

    mutating func trigger(velocity: UInt8) {
        let v = Float(velocity) / 127
        gain = v * v
        amp = 1
        ampDecay = Self.coefficient(seconds: decaySeconds, sampleRate: sampleRate)
        sweep = sweepHz
        sweepDecay = Self.coefficient(seconds: piece == .kick ? 0.03 : 0.05, sampleRate: sampleRate)
        phase = 0
        elapsed = 0
        filter.reset()
        isActive = true
    }

    /// A fast fade instead of a hard stop, so the choke never clicks.
    mutating func choke() {
        guard isActive else { return }
        ampDecay = Self.coefficient(seconds: 0.004, sampleRate: sampleRate)
    }

    mutating func silence() {
        isActive = false
        amp = 0
        filter.reset()
    }

    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        let twoPi = 2 * Float.pi
        let clapGap = Int(0.010 * sampleRate)
        for i in buffer.indices {
            var sample: Float
            switch piece {
            case .kick, .lowTom, .highTom:
                let hz = baseHz + sweep
                phase += hz / sampleRate
                if phase >= 1 { phase -= 1 }
                sample = sinf(twoPi * phase)
                sweep *= sweepDecay
                if piece == .kick, elapsed < Int(0.002 * sampleRate) {
                    sample += 0.3 * nextNoise()
                }
            case .snare:
                phase += baseHz / sampleRate
                if phase >= 1 { phase -= 1 }
                let tone = sinf(twoPi * phase) * amp
                sample = 0.4 * tone + 0.8 * filter.process(nextNoise())
            case .clap:
                // Three quick bursts, then the tail: the hand-clap shape.
                let burst = elapsed < 3 * clapGap ? Float(1) - Float(elapsed % Swift.max(1, clapGap)) / Float(Swift.max(1, clapGap)) : 0
                sample = filter.process(nextNoise()) * Swift.max(burst, elapsed >= 3 * clapGap ? 1 : 0)
            case .closedHat, .openHat, .crash:
                sample = filter.process(nextNoise())
            }
            buffer[i] += sample * amp * gain * 0.8
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

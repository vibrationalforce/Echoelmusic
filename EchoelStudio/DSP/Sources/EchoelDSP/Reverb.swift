import Foundation

/// A stereo reverb: a pre-delay, four allpass diffusers, then an eight-line feedback delay
/// network mixed by a Householder matrix (lossless, so the decay is set by the line gains alone).
///
/// Three modes voice that one network (`Settings.Mode`): Hall, the sound it has always had; Plate,
/// shorter lines and denser diffusion, so the first 50 ms fill sooner, and a brighter tail; Room,
/// shorter lines, shorter and earlier diffusers and about half the decay. A mode only moves the
/// targets `update()` computes — line lengths, gains, damping, diffusers — inside the buffers
/// `init` allocated for Hall, the longest, so switching it allocates nothing and the lines glide.
///
/// Each line's gain is derived from the decay time, so every line falls by 60 dB in `decay`
/// seconds whatever its length — the tail stays smooth instead of fluttering. A lowpass in
/// each line darkens the tail the way air does. Size moves the line lengths with a glide, so a
/// size change bends the tail rather than clicking it.
///
/// A sustained tone on one of the network's modes builds up by 1/(1 − g) for a loop gain g: a
/// 0.5 sine came out at 8.6 — +24.7 dB — at Size 1, Decay 20 s, Damping 20 kHz, Mix 1, and by
/// +16 dB at the default decay (audit 2026-11-04). Eight lines have too few modes per hertz for
/// any loudness normalisation to fix that without making the whole reverb ~15 dB quieter, so the
/// wet signal has a guard instead: it never rises above `guardRatio` times the input's peak, a
/// peak that falls as fast as the tail does (60 dB in `decay`). A tail that starts under that
/// bound stays under it, so the guard is silent on ordinary material and only a resonance meets it.
///
/// Owned by the render thread; allocated in `init`, nothing allocates after that.
public final class Reverb: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// How the network is voiced. The order is stored (an effect's choice stores its index), so a
        /// new mode goes at the end.
        public enum Mode: String, Codable, Sendable, CaseIterable {
            case hall, plate, room

            public var title: String {
                switch self {
                case .hall: "Hall"
                case .plate: "Plate"
                case .room: "Room"
                }
            }

            /// The mode at a choice's index; anything outside the list plays Hall. A switch, not
            /// `allCases`, so the render thread can call it without building an array.
            public init(index: Double) {
                guard index.isFinite else {
                    self = .hall
                    return
                }
                switch index.rounded() {
                case 1: self = .plate
                case 2: self = .room
                default: self = .hall
                }
            }
        }

        /// Room size 0 … 1.
        public var size: Double
        /// Seconds to fall by 60 dB, 0.2 … 20.
        public var decay: Double
        /// Lowpass of the tail in Hz, 500 … 20 000.
        public var damping: Double
        /// Seconds before the tail starts, 0 … 0.2.
        public var predelay: Double
        /// Dry 0 … wet 1.
        public var mix: Double
        /// Hall, Plate or Room; Hall is the sound before modes existed.
        public var mode: Mode

        public init(size: Double = 0.6, decay: Double = 2.2, damping: Double = 7_000, predelay: Double = 0.02,
                    mix: Double = 0.2, mode: Mode = .hall) {
            self.size = size
            self.decay = decay
            self.damping = damping
            self.predelay = predelay
            self.mix = mix
            self.mode = mode
        }

        private enum CodingKeys: String, CodingKey {
            case size, decay, damping, predelay, mix, mode
        }

        /// Settings stored before modes existed have no mode; they decode as Hall, as they sounded.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(size: try container.decode(Double.self, forKey: .size),
                      decay: try container.decode(Double.self, forKey: .decay),
                      damping: try container.decode(Double.self, forKey: .damping),
                      predelay: try container.decode(Double.self, forKey: .predelay),
                      mix: try container.decode(Double.self, forKey: .mix),
                      mode: try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .hall)
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(size: clamp(size, 0...1, base.size), decay: clamp(decay, 0.2...20, base.decay),
                            damping: clamp(damping, 500...20_000, base.damping),
                            predelay: clamp(predelay, 0...Reverb.maximumPredelay, base.predelay),
                            mix: clamp(mix, 0...1, base.mix), mode: mode)
        }

        /// How long the wet sound goes on after the input stops, in seconds: the pre-delay, the
        /// longest line once more, and the time the network takes to fall by 60 dB in this mode
        /// (Room's decay is shorter than the one set). Damping and the guard only shorten it.
        public var tailSeconds: Double {
            let s = clamped
            let voicing = Reverb.Voicing.of(s.mode)
            let longest = (Reverb.lineMilliseconds.max() ?? 0) * 0.001 * (0.5 + s.size) * voicing.lines
            return s.predelay + longest + s.decay * voicing.decay
        }
    }

    /// What a mode does to the network, as factors on what Hall computes. Hall's are all exactly 1
    /// (and its diffusion the 0.6 it always had), and a product with 1 is exact, so Hall renders bit
    /// for bit as before. Every factor is at most 1 where a buffer is sized for Hall (the lines, the
    /// diffusers), so a mode never needs more room than `init` allocated.
    struct Voicing: Equatable {
        /// Line lengths.
        var lines: Double
        /// The decay time.
        var decay: Double
        /// The tail's lowpass (capped at 20 kHz, as the setting is).
        var brightness: Double
        /// The diffusers' allpass coefficient.
        var diffusion: Float
        /// The diffusers' lengths.
        var diffusers: Double

        static func of(_ mode: Settings.Mode) -> Voicing {
            switch mode {
            case .hall: Voicing(lines: 1, decay: 1, brightness: 1, diffusion: 0.6, diffusers: 1)
            case .plate: Voicing(lines: 0.55, decay: 1, brightness: 2.5, diffusion: 0.7, diffusers: 1)
            case .room: Voicing(lines: 0.5, decay: 0.45, brightness: 0.8, diffusion: 0.6, diffusers: 0.5)
            }
        }
    }

    public static let maximumPredelay = 0.2
    /// Line lengths in milliseconds at size 0.5; mutually prime-ish so no echoes line up.
    static let lineMilliseconds: [Double] = [29.7, 37.1, 41.1, 43.7, 47.3, 53.9, 59.3, 67.1]
    static let diffuserMilliseconds: [Double] = [4.77, 3.59, 2.73, 1.79]
    static let lines = 8
    /// How far the wet signal may rise above the input's peak: +6 dB.
    public static let guardRatio: Float = 2

    public var settings: Settings {
        didSet { settings = settings.clamped; update() }
    }

    public let sampleRate: Double
    private let lineCapacity: Int
    private let line: UnsafeMutablePointer<Float>
    private var lineWrite = 0
    private let length: UnsafeMutablePointer<Double>
    private let target: UnsafeMutablePointer<Double>
    private let gain: UnsafeMutablePointer<Float>
    /// Each line's gain as it plays now, gliding toward `gain` like the lengths toward `target`.
    /// The gain sits on the line's tap, so a new decay set at once stepped the whole tail — 12 %
    /// of the level for 0.2 s thrown to 20 s (click hunt, 2026-11-01).
    private let gainNow: UnsafeMutablePointer<Float>
    private let gainGlide: Float
    private let damp: UnsafeMutablePointer<Float>
    private let outputs: UnsafeMutablePointer<Float>
    private var dampCoefficient: Float = 1
    /// The diffusers' allpass coefficient, set by the mode.
    private var diffusion: Float = 0.6
    private let glide: Double
    /// Until the first sample runs, a new size takes effect at once (see `StereoDelay`).
    private var hasRun = false
    /// The mix as it sounds now, gliding to a new one in ~10 ms (see `StereoDelay`).
    private var wetNow: Float = 0
    private let mixGlide: Float
    /// The guard: the input's peak falling at the tail's rate, the wet's peak, and the gain on the
    /// wet, which falls in ~2 ms and recovers in ~40 ms.
    private var inputPeak: Float = 0
    private var inputPeakFall: Float = 0
    private var wetPeak: Float = 0
    private let wetPeakFall: Float
    private var guardGain: Float = 1
    private let guardAttack: Float
    private let guardRecovery: Float

    private let preCapacity: Int
    private let pre: UnsafeMutablePointer<Float>
    private var preWrite = 0
    private var preLength = 0

    private let diffuserCapacity: Int
    private let diffuser: UnsafeMutablePointer<Float>
    private let diffuserLength: UnsafeMutablePointer<Int>
    private let diffuserWrite: UnsafeMutablePointer<Int>

    public init(sampleRate: Double, settings: Settings = Settings()) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        // Size 1 stretches the lines by 1.5.
        lineCapacity = Int((Self.lineMilliseconds.max() ?? 70) * 0.0015 * rate) + 4
        line = .allocate(capacity: Self.lines * lineCapacity)
        line.initialize(repeating: 0, count: Self.lines * lineCapacity)
        length = .allocate(capacity: Self.lines)
        length.initialize(repeating: 1, count: Self.lines)
        target = .allocate(capacity: Self.lines)
        target.initialize(repeating: 1, count: Self.lines)
        gain = .allocate(capacity: Self.lines)
        gain.initialize(repeating: 0, count: Self.lines)
        gainNow = .allocate(capacity: Self.lines)
        gainNow.initialize(repeating: 0, count: Self.lines)
        damp = .allocate(capacity: Self.lines)
        damp.initialize(repeating: 0, count: Self.lines)
        outputs = .allocate(capacity: Self.lines)
        outputs.initialize(repeating: 0, count: Self.lines)
        glide = 1 - Foundation.exp(-1 / (0.1 * rate))
        gainGlide = Float(glide)
        mixGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * rate)))
        wetPeakFall = Float(Foundation.exp(-1 / (0.02 * rate)))
        guardAttack = Float(1 - Foundation.exp(-1 / (0.002 * rate)))
        guardRecovery = Float(1 - Foundation.exp(-1 / (0.04 * rate)))
        preCapacity = Int(Self.maximumPredelay * rate) + 2
        pre = .allocate(capacity: preCapacity)
        pre.initialize(repeating: 0, count: preCapacity)
        let diffusers = Self.diffuserMilliseconds.map { Swift.max(1, Int($0 * 0.001 * rate)) }
        diffuserLength = .allocate(capacity: 4)
        diffuserLength.initialize(from: diffusers, count: 4)
        diffuserCapacity = (diffusers.max() ?? 1) + 1
        diffuser = .allocate(capacity: 4 * diffuserCapacity)
        diffuser.initialize(repeating: 0, count: 4 * diffuserCapacity)
        diffuserWrite = .allocate(capacity: 4)
        diffuserWrite.initialize(repeating: 0, count: 4)
        self.settings = settings.clamped
        update()
        for i in 0..<Self.lines {
            length[i] = target[i]
            gainNow[i] = gain[i]
        }
    }

    deinit {
        line.deallocate()
        length.deallocate()
        target.deallocate()
        gain.deallocate()
        gainNow.deallocate()
        damp.deallocate()
        outputs.deallocate()
        pre.deallocate()
        diffuser.deallocate()
        diffuserWrite.deallocate()
        diffuserLength.deallocate()
    }

    /// Silences the tail at once.
    public func reset() {
        line.update(repeating: 0, count: Self.lines * lineCapacity)
        pre.update(repeating: 0, count: preCapacity)
        diffuser.update(repeating: 0, count: 4 * diffuserCapacity)
        damp.update(repeating: 0, count: Self.lines)
        for i in 0..<Self.lines {
            length[i] = target[i]
            gainNow[i] = gain[i]
        }
        hasRun = false
        wetNow = Float(settings.mix)
        inputPeak = 0
        wetPeak = 0
        guardGain = 1
    }

    /// Where the settings become the network's targets. It allocates nothing: the mode only moves
    /// lengths inside the buffers `init` sized for Hall.
    private func update() {
        let voicing = Voicing.of(settings.mode)
        let stretch = 0.5 + settings.size
        let decay = settings.decay * voicing.decay
        for i in 0..<Self.lines {
            let samples = Swift.min(Self.lineMilliseconds[i] * 0.001 * stretch * sampleRate * voicing.lines,
                                    Double(lineCapacity - 3))
            target[i] = Swift.max(samples, 2)
            // −60 dB after `decay` seconds: g^(decay·rate / length) = 10^-3.
            gain[i] = Float(Foundation.pow(10, -3 * target[i] / (decay * sampleRate)))
        }
        inputPeakFall = Float(Foundation.pow(10, -3 / (decay * sampleRate)))
        let cutoff = Swift.min(settings.damping * voicing.brightness, 20_000)
        dampCoefficient = Float(1 - Foundation.exp(-2 * Double.pi * cutoff / sampleRate))
        diffusion = voicing.diffusion
        for d in 0..<4 {
            let samples = Swift.max(1, Int(Self.diffuserMilliseconds[d] * 0.001 * voicing.diffusers * sampleRate))
            diffuserLength[d] = Swift.min(samples, diffuserCapacity - 1)
        }
        preLength = Swift.min(Int(settings.predelay * sampleRate), preCapacity - 1)
        if !hasRun {
            for i in 0..<Self.lines {
                length[i] = target[i]
                gainNow[i] = gain[i]
            }
            wetNow = Float(settings.mix)
        }
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        let scale: Float = 2 / Float(Self.lines)
        if frames > 0 { hasRun = true }
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: mixGlide)
            let dry = 1 - wet
            // A bad input sample reads as silence; it never reaches the lines.
            let inLeft = left[i].isFinite ? left[i] : 0, inRight = right[i].isFinite ? right[i] : 0
            // Pre-delay.
            pre[preWrite] = (inLeft + inRight) * 0.5
            var read = preWrite - preLength
            if read < 0 { read += preCapacity }
            var x = pre[read]
            preWrite = preWrite + 1 < preCapacity ? preWrite + 1 : 0
            // Diffusion: four Schroeder allpasses.
            for d in 0..<4 {
                let buffer = diffuser + d * diffuserCapacity
                var at = diffuserWrite[d] - diffuserLength[d]
                if at < 0 { at += diffuserCapacity }
                let delayed = buffer[at]
                let v = x + diffusion * delayed
                buffer[diffuserWrite[d]] = v
                x = delayed - diffusion * v
                diffuserWrite[d] = diffuserWrite[d] + 1 < diffuserCapacity ? diffuserWrite[d] + 1 : 0
            }
            // Read every line, damp it, apply its decay gain.
            var sum: Float = 0
            for l in 0..<Self.lines {
                length[l] += (target[l] - length[l]) * glide
                var position = Double(lineWrite) - length[l]
                if position < 0 { position += Double(lineCapacity) }
                let index = Int(position)
                let fraction = Float(position - Double(index))
                let next = index + 1 < lineCapacity ? index + 1 : 0
                let base = line + l * lineCapacity
                let value = base[index] + (base[next] - base[index]) * fraction
                damp[l] += (value - damp[l]) * dampCoefficient
                gainNow[l] += (gain[l] - gainNow[l]) * gainGlide
                outputs[l] = damp[l] * gainNow[l]
                sum += outputs[l]
            }
            // Householder feedback: each line gets the input minus 2/N of the sum, plus itself.
            let mixed = sum * scale
            var wetLeft: Float = 0, wetRight: Float = 0
            for l in 0..<Self.lines {
                let feed = outputs[l] - mixed + x
                (line + l * lineCapacity)[lineWrite] = feed
                if l % 2 == 0 { wetLeft += outputs[l] } else { wetRight += outputs[l] }
            }
            lineWrite = lineWrite + 1 < lineCapacity ? lineWrite + 1 : 0
            guard wetLeft.isFinite, wetRight.isFinite else {
                reset()
                left[i] = inLeft * dry
                right[i] = inRight * dry
                continue
            }
            // The guard (see the type's note).
            inputPeak = Swift.max(Swift.max(Swift.abs(inLeft), Swift.abs(inRight)), inputPeak * inputPeakFall)
            wetPeak = Swift.max(Swift.max(Swift.abs(wetLeft), Swift.abs(wetRight)) * 0.5, wetPeak * wetPeakFall)
            let bound = Self.guardRatio * inputPeak
            let guardTarget: Float = wetPeak > bound ? bound / wetPeak : 1
            guardGain += (guardTarget - guardGain) * (guardTarget < guardGain ? guardAttack : guardRecovery)
            let wetGain = 0.5 * wet * guardGain
            left[i] = inLeft * dry + wetLeft * wetGain
            right[i] = inRight * dry + wetRight * wetGain
        }
        wetNow = Swift.abs(wetTarget - wet) < 1e-6 ? wetTarget : wet
        for l in 0..<Self.lines where Swift.abs(damp[l]) < 1e-20 { damp[l] = 0 }
        if inputPeak < 1e-20 { inputPeak = 0 }
        if wetPeak < 1e-20 { wetPeak = 0 }
    }
}

import Foundation

/// A stereo hall reverb: a pre-delay, four allpass diffusers, then an eight-line feedback delay
/// network mixed by a Householder matrix (lossless, so the decay is set by the line gains alone).
///
/// Each line's gain is derived from the decay time, so every line falls by 60 dB in `decay`
/// seconds whatever its length — the tail stays smooth instead of fluttering. A lowpass in
/// each line darkens the tail the way air does. Size moves the line lengths with a glide, so a
/// size change bends the tail rather than clicking it.
///
/// Owned by the render thread; allocated in `init`, nothing allocates after that.
public final class Reverb: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
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

        public init(size: Double = 0.6, decay: Double = 2.2, damping: Double = 7_000, predelay: Double = 0.02,
                    mix: Double = 0.2) {
            self.size = size
            self.decay = decay
            self.damping = damping
            self.predelay = predelay
            self.mix = mix
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
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    public static let maximumPredelay = 0.2
    /// Line lengths in milliseconds at size 0.5; mutually prime-ish so no echoes line up.
    static let lineMilliseconds: [Double] = [29.7, 37.1, 41.1, 43.7, 47.3, 53.9, 59.3, 67.1]
    static let diffuserMilliseconds: [Double] = [4.77, 3.59, 2.73, 1.79]
    static let lines = 8

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
    private let damp: UnsafeMutablePointer<Float>
    private let outputs: UnsafeMutablePointer<Float>
    private var dampCoefficient: Float = 1
    private let glide: Double

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
        damp = .allocate(capacity: Self.lines)
        damp.initialize(repeating: 0, count: Self.lines)
        outputs = .allocate(capacity: Self.lines)
        outputs.initialize(repeating: 0, count: Self.lines)
        glide = 1 - Foundation.exp(-1 / (0.1 * rate))
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
        for i in 0..<Self.lines { length[i] = target[i] }
    }

    deinit {
        line.deallocate()
        length.deallocate()
        target.deallocate()
        gain.deallocate()
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
        for i in 0..<Self.lines { length[i] = target[i] }
    }

    private func update() {
        let stretch = 0.5 + settings.size
        for i in 0..<Self.lines {
            let samples = Swift.min(Self.lineMilliseconds[i] * 0.001 * stretch * sampleRate, Double(lineCapacity - 3))
            target[i] = Swift.max(samples, 2)
            // −60 dB after `decay` seconds: g^(decay·rate / length) = 10^-3.
            gain[i] = Float(Foundation.pow(10, -3 * target[i] / (settings.decay * sampleRate)))
        }
        dampCoefficient = Float(1 - Foundation.exp(-2 * Double.pi * settings.damping / sampleRate))
        preLength = Swift.min(Int(settings.predelay * sampleRate), preCapacity - 1)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let wet = Float(settings.mix), dry = 1 - wet
        let scale: Float = 2 / Float(Self.lines)
        for i in 0..<frames {
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
                let v = x + 0.6 * delayed
                buffer[diffuserWrite[d]] = v
                x = delayed - 0.6 * v
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
                outputs[l] = damp[l] * gain[l]
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
            left[i] = inLeft * dry + wetLeft * 0.5 * wet
            right[i] = inRight * dry + wetRight * 0.5 * wet
        }
        for l in 0..<Self.lines where Swift.abs(damp[l]) < 1e-20 { damp[l] = 0 }
    }
}

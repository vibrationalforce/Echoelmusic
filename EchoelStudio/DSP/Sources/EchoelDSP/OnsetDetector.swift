import Foundation

/// Where sounds begin in a recording (CUT, 2026-11-01) — in a video's own sound, the moments a sound
/// effect should land on: a door, a step, a clap, a hit. By spectral flux: how much the magnitude
/// spectrum grows from one short frame to the next, summed over the frequencies that grow, on a log
/// scale so a quiet sound starting counts beside a loud one. The peaks of that curve that stand
/// clearly above its running median are onsets, each moved back to where its sound's envelope
/// starts to rise — to the millisecond, finer than a video frame.
///
/// A steady sound (a held tone, room noise) has no onset; a slow swell has none either. Streaming:
/// feed blocks with `process`, then read `onsets` once. It keeps one frame of samples, one value
/// per 10 ms and the peak of every millisecond (about 15 MB for an hour). Offline only — it
/// allocates. Non-finite samples count as silence.
public struct OnsetDetector: Sendable {
    public let sampleRate: Double
    /// Samples per analysis frame: the power of two nearest 46 ms.
    let frameSize: Int
    /// Samples between frames: 10 ms.
    let hop: Int
    /// Samples per envelope step: 1 ms.
    let envelopeStep: Int

    /// A peak of the flux must reach this share of the largest one …
    static let floorShare: Float = 0.1
    /// … and this much at least: the rise of a short hit at about −57 dBFS. Below it nothing is
    /// heard starting — a held tone's frames wobble by a hundredth of it.
    static let audibleFlux: Float = 1
    /// … and stand this many times over the running median, plus `riseShare` of the largest peak.
    static let medianRatio: Float = 1.5
    static let riseShare: Float = 0.05
    /// Frames either side for the running median (±250 ms) and for the local peak (±30 ms).
    static let medianRadius = 25
    static let peakRadius = 3
    /// Two onsets are at least this far apart, in seconds; of two closer ones the stronger stays.
    public static let shortestGap = 0.05
    /// An onset starts where its envelope first reaches this share of the way from the quiet before
    /// it to its peak.
    static let attackShare: Float = 0.25

    private let window: [Float]
    private let fft: FFT
    /// The last `frameSize` samples, oldest at `ringStart`.
    private var ring: [Float]
    private var ringStart = 0
    private var sinceFrame = 0
    private var real: [Float]
    private var imaginary: [Float]
    /// The last frame's log magnitudes, bins 1 ..< frameSize / 2.
    private var previous: [Float]
    /// One value per frame; frame `n` ends at sample `(n + 1) · hop`.
    private var flux: [Float] = []
    /// The peak of every `envelopeStep` samples.
    private var envelope: [Float] = []
    private var stepPeak: Float = 0
    private var stepFill = 0
    /// Samples taken in, until the first frame is full: before that a frame is mostly the zeros it
    /// starts with, and the sound filling it would read as an onset at the very start of every file.
    private var taken = 0
    private var primed = false

    public init(sampleRate: Double) {
        let rate = sampleRate.isFinite && sampleRate >= 1_000 ? sampleRate : 48_000
        self.sampleRate = rate
        let exponent = Swift.min(Swift.max(Foundation.log2(0.046 * rate).rounded(), 8), 13)
        frameSize = 1 << Int(exponent)
        hop = Swift.max(1, Int((rate / 100).rounded()))
        envelopeStep = Swift.max(1, Int((rate / 1_000).rounded()))
        let size = frameSize
        window = (0..<size).map { (index: Int) -> Float in
            Float(0.5 - 0.5 * Foundation.cos(2 * Double.pi * Double(index) / Double(size)))
        }
        fft = FFT(size: size)
        ring = [Float](repeating: 0, count: size)
        real = [Float](repeating: 0, count: size)
        imaginary = [Float](repeating: 0, count: size)
        previous = [Float](repeating: 0, count: size / 2)
    }

    public mutating func process(_ samples: UnsafePointer<Float>, count: Int) {
        for index in 0..<Swift.max(0, count) {
            let raw = samples[index]
            let sample = raw.isFinite ? raw : 0
            ring[ringStart] = sample
            ringStart = (ringStart + 1) % frameSize
            stepPeak = Swift.max(stepPeak, Swift.abs(sample))
            stepFill += 1
            if stepFill == envelopeStep {
                envelope.append(stepPeak)
                stepPeak = 0
                stepFill = 0
            }
            if taken < frameSize { taken += 1 }
            sinceFrame += 1
            if sinceFrame == hop {
                sinceFrame = 0
                analyseFrame()
            }
        }
    }

    public mutating func process(_ samples: [Float]) {
        samples.withUnsafeBufferPointer { buffer in
            guard let start = buffer.baseAddress else { return }
            process(start, count: buffer.count)
        }
    }

    /// The flux of the frame that ends at the newest sample. Until the first frame is full its
    /// flux is 0, and the first full frame only sets what the next is compared with: a sound that
    /// is there from the first sample did not start inside the file.
    private mutating func analyseFrame() {
        guard taken >= frameSize else {
            flux.append(0)
            return
        }
        let size = frameSize
        for index in 0..<size {
            real[index] = ring[(ringStart + index) % size] * window[index]
            imaginary[index] = 0
        }
        fft.transform(real: &real, imaginary: &imaginary)
        // A full-scale sine reads 1 in its bin.
        let scale = Float(4) / Float(size)
        var sum: Float = 0
        for bin in 1..<(size / 2) {
            let magnitude = (real[bin] * real[bin] + imaginary[bin] * imaginary[bin]).squareRoot() * scale
            let level = Float(Foundation.log1p(100 * Double(magnitude)))
            let rise = level - previous[bin]
            if rise > 0 { sum += rise }
            previous[bin] = level
        }
        flux.append(primed && sum.isFinite ? sum : 0)
        primed = true
    }

    /// The onsets heard so far, in seconds from the first sample, rising.
    public var onsets: [Double] {
        let count = flux.count
        guard count >= 3, let top = flux.max(), top >= Self.audibleFlux else { return [] }
        let floor = Swift.max(Self.floorShare * top, Self.audibleFlux)
        var picked: [(seconds: Double, strength: Float)] = []
        var neighbourhood: [Float] = []
        neighbourhood.reserveCapacity(2 * Self.medianRadius + 1)
        for frame in 0..<count {
            let value = flux[frame]
            guard value >= floor, isLocalPeak(frame) else { continue }
            neighbourhood.removeAll(keepingCapacity: true)
            for other in Swift.max(0, frame - Self.medianRadius)...Swift.min(count - 1, frame + Self.medianRadius) {
                neighbourhood.append(flux[other])
            }
            neighbourhood.sort()
            let median = neighbourhood[neighbourhood.count / 2]
            guard value >= Self.medianRatio * median + Self.riseShare * top else { continue }
            let seconds = attackStart(ofFrame: frame)
            if let last = picked.last, seconds - last.seconds < Self.shortestGap {
                if value > last.strength { picked[picked.count - 1] = (seconds, value) }
            } else {
                picked.append((seconds, value))
            }
        }
        return picked.map(\.seconds)
    }

    /// The frame's flux is the largest within ±`peakRadius` frames — the earliest of equal ones.
    private func isLocalPeak(_ frame: Int) -> Bool {
        let value = flux[frame]
        let low = Swift.max(0, frame - Self.peakRadius), high = Swift.min(flux.count - 1, frame + Self.peakRadius)
        for other in low...high where other != frame {
            if other < frame ? flux[other] >= value : flux[other] > value { return false }
        }
        return true
    }

    /// Where the sound found in `frame` starts, in seconds: from the loudest millisecond around the
    /// frame back to where the envelope first rose a quarter of the way up from the quiet before it.
    private func attackStart(ofFrame frame: Int) -> Double {
        let end = (frame + 1) * hop
        let fallback = Double(Swift.max(0, end - frameSize / 2)) / sampleRate
        guard !envelope.isEmpty else { return fallback }
        let first = Swift.max(0, (end - frameSize) / envelopeStep)
        let last = Swift.min(envelope.count - 1, (end + frameSize / 2) / envelopeStep)
        guard first <= last else { return fallback }
        var loudest = first
        for step in first...last where envelope[step] > envelope[loudest] { loudest = step }
        var quiet = envelope[loudest]
        for step in first...loudest { quiet = Swift.min(quiet, envelope[step]) }
        let threshold = quiet + Self.attackShare * (envelope[loudest] - quiet)
        var start = loudest
        while start > first, envelope[start - 1] >= threshold { start -= 1 }
        return Double(start * envelopeStep) / sampleRate
    }
}

/// A radix-2 fast Fourier transform of one power-of-two size, in place.
struct FFT: Sendable {
    let size: Int
    private let cosines: [Float]
    private let sines: [Float]
    private let reversed: [Int]

    init(size requested: Int) {
        var size = 1
        while size < Swift.max(2, requested) { size <<= 1 }
        self.size = size
        let half = size / 2
        cosines = (0..<half).map { (index: Int) -> Float in Float(Foundation.cos(2 * Double.pi * Double(index) / Double(size))) }
        sines = (0..<half).map { (index: Int) -> Float in Float(Foundation.sin(2 * Double.pi * Double(index) / Double(size))) }
        var bits = 0
        while (1 << bits) < size { bits += 1 }
        reversed = (0..<size).map { (index: Int) -> Int in
            var value = index, result = 0
            for _ in 0..<bits {
                result = (result << 1) | (value & 1)
                value >>= 1
            }
            return result
        }
    }

    /// The forward transform of `real` + i·`imaginary`, both `size` long.
    func transform(real: inout [Float], imaginary: inout [Float]) {
        guard real.count == size, imaginary.count == size else { return }
        for index in 0..<size {
            let other = reversed[index]
            if other > index {
                real.swapAt(index, other)
                imaginary.swapAt(index, other)
            }
        }
        var length = 2
        while length <= size {
            let half = length / 2
            let stride = size / length
            var start = 0
            while start < size {
                for offset in 0..<half {
                    let cosine = cosines[offset * stride], sine = sines[offset * stride]
                    let a = start + offset, b = a + half
                    // × e^(−2πi·offset/length)
                    let turnedReal = real[b] * cosine + imaginary[b] * sine
                    let turnedImaginary = imaginary[b] * cosine - real[b] * sine
                    real[b] = real[a] - turnedReal
                    imaginary[b] = imaginary[a] - turnedImaginary
                    real[a] += turnedReal
                    imaginary[a] += turnedImaginary
                }
                start += length
            }
            length <<= 1
        }
    }
}

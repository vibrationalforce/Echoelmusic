import Foundation

/// The strongest partials of a block of sound: up to `SpectralPeaks.capacity` frequencies with
/// their amplitudes, strongest first. A plain value — no array, so handing it on allocates nothing.
public struct SpectralPeaks: Equatable, Sendable {
    public static let capacity = 8

    /// Hertz, strongest first; the slots past `count` are 0.
    public private(set) var frequencies = SIMD8<Double>(repeating: 0)
    /// Linear amplitude of each partial, 1 = a full-scale sine; the slots past `count` are 0.
    public private(set) var amplitudes = SIMD8<Double>(repeating: 0)
    public private(set) var count = 0

    public init() {}

    /// Silence: no partial at all.
    public static let silent = SpectralPeaks()

    /// Builds peaks from pairs, for tests and callers that already know their partials. Pairs
    /// past `capacity`, non-finite or non-positive values are dropped; the rest are sorted.
    public init(_ pairs: [(frequency: Double, amplitude: Double)]) {
        for pair in pairs where pair.frequency.isFinite && pair.frequency > 0
            && pair.amplitude.isFinite && pair.amplitude > 0 {
            insert(frequency: pair.frequency, amplitude: pair.amplitude)
        }
    }

    /// Keeps the strongest `capacity` partials, strongest first. Allocation-free.
    mutating func insert(frequency: Double, amplitude: Double) {
        var slot = count
        while slot > 0, amplitudes[slot - 1] < amplitude { slot -= 1 }
        guard slot < Self.capacity else { return }
        var index = Swift.min(count, Self.capacity - 1)
        while index > slot {
            frequencies[index] = frequencies[index - 1]
            amplitudes[index] = amplitudes[index - 1]
            index -= 1
        }
        frequencies[slot] = frequency
        amplitudes[slot] = amplitude
        count = Swift.min(count + 1, Self.capacity)
    }
}

/// Finds the strongest partials of the last `size` samples of a signal: a Hann window, a radix-2
/// FFT, the local maxima of the magnitude spectrum, each refined by a parabola through its three
/// bins (the peak's frequency to a fraction of a bin) and scaled by the window's coherent gain,
/// so a full-scale sine reads as amplitude 1.
///
/// Feed it with `push`, ask with `analyze`. Every buffer is allocated in `init`; `push` and
/// `analyze` allocate nothing, so the caller may run them on any thread it owns — never two at
/// once: one analyzer belongs to one thread at a time.
public final class SpectrumAnalyzer: @unchecked Sendable {
    /// The partials searched: from the lowest bass string to where a plate's figures stop being
    /// legible (`ChladniPlate`'s finest mode sits under this).
    public static let lowestHertz = 30.0
    public static let highestHertz = 8_000.0
    /// A partial weaker than this (−66 dBFS) is not reported: room noise, a fading tail.
    public static let floor = 0.0005

    public let sampleRate: Double
    /// The window, a power of two: 4096 at 44.1 or 48 kHz, about 85 ms and an 11.7 Hz bin.
    public let size: Int

    private let ring: UnsafeMutablePointer<Float>
    private let window: UnsafeMutablePointer<Double>
    private let real: UnsafeMutablePointer<Double>
    private let imaginary: UnsafeMutablePointer<Double>
    private let magnitude: UnsafeMutablePointer<Double>
    private let cosines: UnsafeMutablePointer<Double>
    private let sines: UnsafeMutablePointer<Double>
    private let reversed: UnsafeMutablePointer<Int>
    private let windowSum: Double
    private var write = 0

    public init(sampleRate: Double, size: Int = 4_096) {
        self.sampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        var power = 64
        while power < size, power < 65_536 { power *= 2 }
        self.size = power
        ring = .allocate(capacity: power)
        ring.initialize(repeating: 0, count: power)
        window = .allocate(capacity: power)
        real = .allocate(capacity: power)
        real.initialize(repeating: 0, count: power)
        imaginary = .allocate(capacity: power)
        imaginary.initialize(repeating: 0, count: power)
        magnitude = .allocate(capacity: power / 2 + 1)
        magnitude.initialize(repeating: 0, count: power / 2 + 1)
        cosines = .allocate(capacity: power / 2)
        sines = .allocate(capacity: power / 2)
        reversed = .allocate(capacity: power)
        var sum = 0.0
        for index in 0..<power {
            let value = 0.5 - 0.5 * Foundation.cos(2 * Double.pi * Double(index) / Double(power))
            window[index] = value
            sum += value
        }
        windowSum = sum
        for index in 0..<(power / 2) {
            let angle = -2 * Double.pi * Double(index) / Double(power)
            cosines[index] = Foundation.cos(angle)
            sines[index] = Foundation.sin(angle)
        }
        var bits = 0
        while (1 << bits) < power { bits += 1 }
        for index in 0..<power {
            var value = index, out = 0
            for _ in 0..<bits {
                out = (out << 1) | (value & 1)
                value >>= 1
            }
            reversed[index] = out
        }
    }

    deinit {
        ring.deallocate()
        window.deallocate()
        real.deallocate()
        imaginary.deallocate()
        magnitude.deallocate()
        cosines.deallocate()
        sines.deallocate()
        reversed.deallocate()
    }

    /// Appends `count` samples; the analyzer keeps the newest `size`. Non-finite samples are silence.
    public func push(_ samples: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        for index in 0..<count {
            let sample = samples[index]
            ring[write] = sample.isFinite ? sample : 0
            write = (write + 1) % size
        }
    }

    /// Forgets everything pushed: the next analysis reads silence.
    public func reset() {
        ring.update(repeating: 0, count: size)
        write = 0
    }

    /// The strongest partials of the newest `size` samples.
    public func analyze() -> SpectralPeaks {
        for index in 0..<size {
            let sample = Double(ring[(write + index) % size]) * window[index]
            let target = reversed[index]
            real[target] = sample
            imaginary[target] = 0
        }
        transform()
        let half = size / 2
        let scale = 2 / windowSum
        for bin in 0...half {
            let re = real[bin], im = imaginary[bin]
            magnitude[bin] = (re * re + im * im).squareRoot() * scale
        }
        let binHertz = sampleRate / Double(size)
        let first = Swift.max(2, Int((Self.lowestHertz / binHertz).rounded(.down)))
        let last = Swift.min(half - 2, Int((Self.highestHertz / binHertz).rounded(.up)))
        var peaks = SpectralPeaks()
        guard first <= last else { return peaks }
        for bin in first...last {
            let centre = magnitude[bin]
            guard centre >= Self.floor, centre > magnitude[bin - 1], centre >= magnitude[bin + 1] else { continue }
            // A parabola through the log magnitudes of the three bins: the peak's true place and
            // height, for a Hann window within a few hundredths of a bin.
            let left = Foundation.log(Swift.max(magnitude[bin - 1], 1e-12))
            let middle = Foundation.log(centre)
            let right = Foundation.log(Swift.max(magnitude[bin + 1], 1e-12))
            let curve = left - 2 * middle + right
            let offset = curve < 0 ? Swift.min(0.5, Swift.max(-0.5, 0.5 * (left - right) / curve)) : 0
            let height = Foundation.exp(middle - 0.25 * (left - right) * offset)
            peaks.insert(frequency: (Double(bin) + offset) * binHertz, amplitude: height)
        }
        return peaks
    }

    /// In-place iterative radix-2 FFT over the bit-reversed `real`/`imaginary`.
    private func transform() {
        var span = 2
        while span <= size {
            let halfSpan = span / 2
            let stride = size / span
            var start = 0
            while start < size {
                for offset in 0..<halfSpan {
                    let twiddle = offset * stride
                    let wr = cosines[twiddle], wi = sines[twiddle]
                    let a = start + offset, b = a + halfSpan
                    let br = real[b] * wr - imaginary[b] * wi
                    let bi = real[b] * wi + imaginary[b] * wr
                    real[b] = real[a] - br
                    imaginary[b] = imaginary[a] - bi
                    real[a] += br
                    imaginary[a] += bi
                }
                start += span
            }
            span *= 2
        }
    }
}

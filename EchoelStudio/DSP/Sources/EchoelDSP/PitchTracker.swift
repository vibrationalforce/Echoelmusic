import Foundation

/// The fundamental of a voice or a single-note instrument as it arrives, sample by sample: YIN
/// (de Cheveigné & Kawahara, 2002) — the difference function, its cumulative-mean normalisation,
/// the absolute threshold and a parabolic refinement — over the last few tens of milliseconds.
/// Ported from the earlier app's `PitchTracker` (one window in, one frequency out), which read
/// imported files; here it runs on the render thread under the pitch correction and the
/// harmonizer, so it keeps its own buffers and never allocates after `init`.
///
/// The input is averaged down to about 24 kHz before the analysis (a box filter over `factor`
/// samples), which holds the cost near 20 million multiply-adds a second at any rate and loses
/// nothing a fundamental of at most 1 kHz needs. The window holds two periods of the lowest
/// pitch, 70 Hz (a low male voice, a bass guitar's A string is lower and reads as unvoiced). An
/// analysis runs every `hop` input samples, about 5 ms. Below −60 dBFS, or where the signal is
/// not periodic enough to cross the threshold, the tracker reports no pitch (`period` 0) — a
/// consonant, a breath, a chord.
///
/// Owned by the render thread: call `push` and `reset` from that thread.
public final class PitchTracker: @unchecked Sendable {
    public static let minimumHertz = 70.0
    public static let maximumHertz = 1_000.0
    /// YIN's aperiodicity gate: lower is stricter.
    public static let threshold = 0.15

    public let sampleRate: Double
    /// Input samples averaged into one analysed sample.
    public let factor: Int
    /// Input samples between two analyses.
    public let hop: Int
    /// The last period found, in input samples; 0 while there is none.
    public private(set) var period: Double = 0

    /// The last fundamental found, in hertz; 0 while there is none.
    public var frequency: Double { period > 0 ? sampleRate / period : 0 }

    private let rate: Double
    private let tauMin: Int
    private let tauMax: Int
    private let window: Int
    private let ring: UnsafeMutablePointer<Float>
    private let flat: UnsafeMutablePointer<Float>
    private let difference: UnsafeMutablePointer<Double>
    private var write = 0
    private var filled = 0
    private var sum: Float = 0
    private var summed = 0
    private var sinceAnalysis = 0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        factor = Swift.max(1, Int((self.sampleRate / 24_000).rounded()))
        rate = self.sampleRate / Double(factor)
        tauMax = Int(rate / Self.minimumHertz)
        tauMin = Swift.max(2, Int(rate / Self.maximumHertz))
        window = 2 * tauMax
        hop = 128 * factor
        ring = .allocate(capacity: window)
        ring.initialize(repeating: 0, count: window)
        flat = .allocate(capacity: window)
        flat.initialize(repeating: 0, count: window)
        difference = .allocate(capacity: tauMax + 1)
        difference.initialize(repeating: 0, count: tauMax + 1)
    }

    deinit {
        ring.deallocate()
        flat.deallocate()
        difference.deallocate()
    }

    /// Forgets what it heard.
    public func reset() {
        ring.update(repeating: 0, count: window)
        write = 0
        filled = 0
        sum = 0
        summed = 0
        sinceAnalysis = 0
        period = 0
    }

    /// One input sample. Returns true when an analysis ran on this sample, so `period` is new.
    @discardableResult
    public func push(_ sample: Float) -> Bool {
        sum += sample.isFinite ? sample : 0
        summed += 1
        if summed == factor {
            ring[write] = sum / Float(factor)
            write = write + 1 < window ? write + 1 : 0
            filled = Swift.min(filled + 1, window)
            sum = 0
            summed = 0
        }
        sinceAnalysis += 1
        guard sinceAnalysis >= hop else { return false }
        sinceAnalysis = 0
        period = analyze() * Double(factor)
        return true
    }

    /// The fundamental of a whole recording, for work off the render thread (a clip, a test).
    /// Allocates. Nil where the last window holds no pitch.
    public static func frequency(of samples: [Float], sampleRate: Double) -> Double? {
        let tracker = PitchTracker(sampleRate: sampleRate)
        for sample in samples { tracker.push(sample) }
        return tracker.period > 0 ? tracker.frequency : nil
    }

    /// YIN over the window, oldest sample first; the period in analysed samples, or 0.
    private func analyze() -> Double {
        guard filled == window else { return 0 }
        var energy: Float = 0
        for i in 0..<window {
            let x = ring[(write + i) % window]
            flat[i] = x
            energy += x * x
        }
        guard energy / Float(window) > 1e-6 else { return 0 }
        // The difference over a fixed span of `tauMax` samples, so every lag is measured alike.
        let span = window - tauMax
        difference[0] = 1
        var running = 0.0
        for tau in 1...tauMax {
            var total: Float = 0
            for i in 0..<span {
                let delta = flat[i] - flat[i + tau]
                total += delta * delta
            }
            running += Double(total)
            // The cumulative-mean normalised difference, written over the raw one in place.
            difference[tau] = running > 0 ? Double(total) * Double(tau) / running : 1
        }
        var estimate = -1
        var tau = tauMin + 1
        while tau < tauMax {
            if difference[tau] < Self.threshold {
                while tau + 1 <= tauMax, difference[tau + 1] < difference[tau] { tau += 1 }
                estimate = tau
                break
            }
            tau += 1
        }
        guard estimate > 0 else { return 0 }
        var refined = Double(estimate)
        if estimate > tauMin, estimate < tauMax {
            let before = difference[estimate - 1], at = difference[estimate], after = difference[estimate + 1]
            let curve = before + after - 2 * at
            if abs(curve) > 1e-12 { refined += 0.5 * (before - after) / curve }
        }
        guard refined.isFinite, refined >= Double(tauMin), refined <= Double(tauMax) else { return 0 }
        return refined
    }
}

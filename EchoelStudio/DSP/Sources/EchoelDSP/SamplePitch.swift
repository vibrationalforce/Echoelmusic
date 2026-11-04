import Foundation

/// The note a sample sounds at, measured from the file (the media browser, Recovery 7): the same
/// YIN estimate the wavetable cuts its cycles by (`WavetableAnalysis.estimate`), taken in windows
/// across the sample's opening seconds and kept only where the windows agree. A sound with no
/// steady pitch — noise, a snare, a kick that sweeps, a chord — gives no note rather than a guess.
///
/// Off the render thread (allocates). Deterministic: the same samples give the same result.
public enum SamplePitch {
    public struct Reading: Equatable, Sendable {
        /// The fundamental, in hertz.
        public let hertz: Double
        /// The nearest MIDI note (60 is middle C), 0 … 127.
        public let note: Int
        /// How far the sound sits from that note, −50 … +50 cents.
        public let cents: Double
        /// How sure the reading is, 0 … 1: the share of sounding windows that agree on the pitch,
        /// times how periodic they are.
        public let confidence: Double
    }

    /// Below this a reading is not given as a note.
    public static let minimumConfidence = 0.6
    /// How much of a sample is looked at.
    public static let analysedSeconds = 4.0
    /// Windows at most this far from the median period count as agreeing: about ±50 cents.
    static let agreement = 0.03
    /// A window quieter than this (−60 dBFS RMS) is not counted at all.
    static let silence: Float = 1e-3
    /// At least this many sounding windows, or the sample is too short to tell.
    static let minimumWindows = 4
    /// At most this many windows are measured.
    static let maximumWindows = 24

    /// The reading of a sample, or nil where no note can be told with `minimumConfidence`.
    public static func reading(of buffer: SampleBuffer) -> Reading? {
        let frames = Swift.min(buffer.frameCount, Int(analysedSeconds * buffer.sampleRate))
        guard frames > 0 else { return nil }
        var mono = [Float](repeating: 0, count: frames)
        for i in 0..<frames { mono[i] = buffer.mono(i) }
        return reading(of: mono, sampleRate: buffer.sampleRate)
    }

    /// The reading of `samples` at `sampleRate` (one channel), or nil where no note can be told.
    public static func reading(of samples: [Float], sampleRate: Double) -> Reading? {
        guard let measured = measure(samples, sampleRate: sampleRate), measured.confidence >= minimumConfidence else {
            return nil
        }
        return measured
    }

    /// The reading whatever its confidence (for the tests and for a caller that shows doubt).
    static func measure(_ samples: [Float], sampleRate: Double) -> Reading? {
        guard sampleRate.isFinite, sampleRate > 0 else { return nil }
        let x = Array(samples.prefix(Int(analysedSeconds * sampleRate))).map { $0.isFinite ? $0 : 0 }
        let window = WavetableAnalysis.window
        // Windows every 50 ms, at most `maximumWindows` of them: the cost stays bounded.
        let hop = Swift.max(1, Int(0.05 * sampleRate), x.count / maximumWindows)
        var sounding = 0
        var found: [(period: Double, aperiodicity: Float)] = []
        var centre = window
        while centre + window < x.count {
            var energy: Float = 0
            let from = Swift.max(0, centre - window / 2)
            let to = Swift.min(x.count, from + window)
            for i in from..<to { energy += x[i] * x[i] }
            if (energy / Float(Swift.max(1, to - from))).squareRoot() >= silence {
                sounding += 1
                if let estimate = WavetableAnalysis.estimate(of: x, around: centre, sampleRate: sampleRate) {
                    found.append(estimate)
                }
            }
            centre += hop
        }
        guard sounding >= minimumWindows, !found.isEmpty else { return nil }
        let periods = found.map(\.period).sorted()
        let median = periods[periods.count / 2]
        guard median > 0 else { return nil }
        let agreeing = found.filter { abs($0.period - median) / median <= agreement }
        guard !agreeing.isEmpty else { return nil }
        let period = agreeing.map(\.period).reduce(0, +) / Double(agreeing.count)
        let roughness = agreeing.map { Double($0.aperiodicity) }.sorted()[agreeing.count / 2]
        let confidence = Swift.min(1, Swift.max(0, Double(agreeing.count) / Double(sounding) * (1 - roughness)))
        let hertz = sampleRate / period
        guard hertz.isFinite, hertz > 0 else { return nil }
        let exact = 69 + 12 * log2(hertz / 440)
        let note = Int(exact.rounded())
        guard (0...127).contains(note) else { return nil }
        return Reading(hertz: hertz, note: note, cents: (exact - Double(note)) * 100, confidence: confidence)
    }
}

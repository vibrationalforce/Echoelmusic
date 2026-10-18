import Foundation

/// Integrated loudness after ITU-R BS.1770-4 / EBU R 128 and the true peak, for a stereo file
/// measured once from start to end: K-weighting (a high shelf, then a high pass), 400 ms
/// blocks every 100 ms, the absolute gate at −70 LUFS and the relative gate 10 LU below.
/// True peak is the sample peak of the signal oversampled four times. Offline only — it keeps
/// one value per block.
public struct LoudnessMeter: Sendable {
    /// Silence, or no full block measured: no loudness to report.
    public static let silent = -Double.infinity

    private var left: KWeighting
    private var right: KWeighting
    private var leftPeak: TruePeak
    private var rightPeak: TruePeak
    private let hop: Int
    private var hopSum: Double = 0
    private var hopFill = 0
    /// The last four hops' sums of squares, both channels: one 400 ms block.
    private var recent: [Double] = []
    private var blocks: [Double] = []

    public init(sampleRate: Double) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        left = KWeighting(sampleRate: rate)
        right = KWeighting(sampleRate: rate)
        leftPeak = TruePeak()
        rightPeak = TruePeak()
        hop = Swift.max(1, Int((rate / 10).rounded()))
    }

    public mutating func process(left l: UnsafePointer<Float>, right r: UnsafePointer<Float>, count: Int) {
        for i in 0..<Swift.max(0, count) {
            let a = l[i].isFinite ? l[i] : 0, b = r[i].isFinite ? r[i] : 0
            leftPeak.add(a)
            rightPeak.add(b)
            let x = left.process(Double(a)), y = right.process(Double(b))
            hopSum += x * x + y * y
            hopFill += 1
            if hopFill == hop { closeHop() }
        }
    }

    private mutating func closeHop() {
        recent.append(hopSum)
        if recent.count > 4 { recent.removeFirst() }
        if recent.count == 4 { blocks.append(recent.reduce(0, +) / Double(4 * hop)) }
        hopSum = 0
        hopFill = 0
    }

    /// The song's integrated loudness in LUFS; `silent` when nothing passed the gates.
    public var integratedLoudness: Double {
        func loudness(_ meanSquare: Double) -> Double { -0.691 + 10 * Foundation.log10(meanSquare) }
        let absolute = blocks.filter { $0 > 0 && loudness($0) > -70 }
        guard !absolute.isEmpty else { return Self.silent }
        let relative = loudness(absolute.reduce(0, +) / Double(absolute.count)) - 10
        let gated = absolute.filter { loudness($0) > relative }
        guard !gated.isEmpty else { return Self.silent }
        return loudness(gated.reduce(0, +) / Double(gated.count))
    }

    /// The louder channel's true peak in dBTP; `silent` for silence.
    public var truePeak: Double {
        let peak = Swift.max(leftPeak.peak, rightPeak.peak)
        return peak > 0 ? 20 * Foundation.log10(Double(peak)) : Self.silent
    }
}

/// The two K-weighting biquads of BS.1770, at any sample rate (the standard's constants).
struct KWeighting: Sendable {
    private var shelf: Biquad
    private var highPass: Biquad

    init(sampleRate fs: Double) {
        do {
            let f0 = 1681.974450955533, gain = 3.999843853973347, q = 0.7071752369554196
            let k = tan(Double.pi * f0 / fs)
            let vh = pow(10, gain / 20), vb = pow(vh, 0.4996667741545416)
            let a0 = 1 + k / q + k * k
            shelf = Biquad(b0: (vh + vb * k / q + k * k) / a0, b1: 2 * (k * k - vh) / a0,
                           b2: (vh - vb * k / q + k * k) / a0, a1: 2 * (k * k - 1) / a0, a2: (1 - k / q + k * k) / a0)
        }
        do {
            let f0 = 38.13547087602444, q = 0.5003270373238773
            let k = tan(Double.pi * f0 / fs)
            let a0 = 1 + k / q + k * k
            highPass = Biquad(b0: 1, b1: -2, b2: 1, a1: 2 * (k * k - 1) / a0, a2: (1 - k / q + k * k) / a0)
        }
    }

    mutating func process(_ x: Double) -> Double { highPass.process(shelf.process(x)) }

    struct Biquad: Sendable {
        let b0, b1, b2, a1, a2: Double
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
            self.b0 = b0; self.b1 = b1; self.b2 = b2; self.a1 = a1; self.a2 = a2
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }
}

/// A channel's true peak: the samples between the samples, by four-times oversampling through a
/// windowed-sinc interpolator (12 taps per phase), and the samples themselves.
struct TruePeak: Sendable {
    static let taps = 12
    static let phases = 4
    /// `phases × taps` coefficients; phase p interpolates the point p/4 of a sample after the
    /// centre of the history.
    static let coefficients: [Float] = {
        var c = [Float](repeating: 0, count: phases * taps)
        let half = Double(taps) / 2
        for p in 0..<phases {
            var sum = 0.0
            for k in 0..<taps {
                let t = Double(k) - half + 1 - Double(p) / Double(phases)
                let sinc = t == 0 ? 1 : sin(Double.pi * t) / (Double.pi * t)
                let window = 0.5 + 0.5 * cos(Double.pi * t / (half + 1))
                c[p * taps + k] = Float(sinc * window)
                sum += sinc * window
            }
            // Unity gain at DC for every phase.
            for k in 0..<taps { c[p * taps + k] = Float(Double(c[p * taps + k]) / sum) }
        }
        return c
    }()

    private var history = [Float](repeating: 0, count: taps)
    private var position = 0
    private(set) var peak: Float = 0

    mutating func add(_ sample: Float) {
        history[position] = sample
        position = (position + 1) % Self.taps
        peak = Swift.max(peak, Swift.abs(sample))
        for p in 1..<Self.phases {
            var y: Float = 0
            for k in 0..<Self.taps {
                y += Self.coefficients[p * Self.taps + k] * history[(position + k) % Self.taps]
            }
            peak = Swift.max(peak, Swift.abs(y))
        }
    }
}

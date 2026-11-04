import Foundation

/// A wavetable: `frameCount` single cycles of a sound, each kept at ten band limits — one per
/// octave — so a high note reads a cycle that carries no harmonic above the output's Nyquist and
/// nothing folds back as aliasing (the "Wavetable" engine, EchoelTools: a synth you feed with your
/// own sample). Level `k` holds the harmonics up to 512 ÷ 2ᵏ in a table of 2048 ÷ 2ᵏ points — four
/// points per highest harmonic, so the linear read between two points stays close to the curve.
///
/// Built off the render thread — from basic shapes (`factory`) or from a sample's cycles
/// (`init?(sample:frames:)`) — and never written again, so the render thread reads it without a
/// lock. The values live in manual memory: reading them retains nothing. The owner keeps the bank
/// alive while a synth plays it and releases it off the render thread (the engine does, as for a
/// sampler's buffer).
public final class WavetableBank: @unchecked Sendable {
    /// Points of one cycle at the fullest level.
    public static let cycleLength = 2048
    /// Band-limited levels, one octave apart.
    public static let levels = 10
    /// The most cycles a bank holds.
    public static let maximumFrames = 64

    public let frameCount: Int
    private let values: UnsafeMutablePointer<Float>
    private let valueCount: Int
    /// Where each level's block starts in `values`: `levels` entries.
    private let starts: UnsafeMutablePointer<Int>

    /// The level `k` table length.
    @inline(__always)
    static func length(level k: Int) -> Int { cycleLength >> k }
    /// The highest harmonic level `k` keeps.
    @inline(__always)
    static func harmonics(level k: Int) -> Int { (cycleLength / 4) >> k }

    /// One cycle per entry of `spectra`: each the sine and cosine amplitudes of harmonics 1, 2, …
    /// (index 0 is harmonic 1). Each cycle is normalized to a peak of 1 at its fullest level; a
    /// silent one stays silent. Without a cycle, one silent cycle.
    init(spectra: [(sine: [Float], cosine: [Float])]) {
        let frames = Swift.max(1, Swift.min(spectra.count, Self.maximumFrames))
        frameCount = frames
        var total = 0
        starts = .allocate(capacity: Self.levels)
        for k in 0..<Self.levels {
            starts[k] = total
            total += frames * (Self.length(level: k) + 1)
        }
        valueCount = total
        // One transform per level size, shared by every cycle (`FFT` in OnsetDetector).
        let transforms = (0..<Self.levels).map { (k: Int) -> FFT in FFT(size: Self.length(level: k)) }
        values = .allocate(capacity: total)
        values.initialize(repeating: 0, count: total)
        for f in 0..<frames where f < spectra.count {
            let spectrum = spectra[f]
            var scale: Float = 0
            for k in 0..<Self.levels {
                let n = Self.length(level: k)
                var re = [Float](repeating: 0, count: n), im = [Float](repeating: 0, count: n)
                let top = Swift.min(Self.harmonics(level: k), spectrum.sine.count, spectrum.cosine.count)
                for h in 1..<(top + 1) {
                    // x[t] = Σ s·sin(2πht/n) + c·cos(2πht/n): bin h holds (c − i·s)/2, bin n − h its mirror.
                    let s = spectrum.sine[h - 1], c = spectrum.cosine[h - 1]
                    guard s.isFinite, c.isFinite else { continue }
                    re[h] += c / 2
                    im[h] -= s / 2
                    re[n - h] += c / 2
                    im[n - h] += s / 2
                }
                // The inverse through the forward: conj(FFT(conj(X))), unscaled.
                for i in 0..<n { im[i] = -im[i] }
                transforms[k].transform(real: &re, imaginary: &im)
                if k == 0 {
                    let peak = re.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
                    scale = peak > 1e-6 ? 1 / peak : 0
                }
                let table = values + starts[k] + f * (n + 1)
                for i in 0..<n { table[i] = re[i] * scale }
                // One point past the end repeats the first, so a read never wraps.
                table[n] = table[0]
            }
        }
    }

    deinit {
        values.deinitialize(count: valueCount)
        values.deallocate()
        starts.deallocate()
    }

    /// What a synth reads: pointers into this bank, no reference to it.
    public var view: WavetableView {
        WavetableView(values: UnsafePointer(values), starts: UnsafePointer(starts), frameCount: frameCount)
    }

    /// The bytes the bank holds: what a memory plan counts.
    public var heldBytes: Int { valueCount * MemoryLayout<Float>.stride }

    /// Point `i` of cycle `frame` at level `k`, for tests and drawing. Off the render thread.
    public func value(frame: Int, level k: Int, at i: Int) -> Float {
        guard frame >= 0, frame < frameCount, k >= 0, k < Self.levels, i >= 0, i <= Self.length(level: k) else { return 0 }
        return values[starts[k] + frame * (Self.length(level: k) + 1) + i]
    }

    /// The tables a synth plays without a sample: eight shapes from soft to bright — sine,
    /// triangle, saw, square, 25 % and 12.5 % pulse, organ (the drawbars 16′ 8′ 4′ 2⅔′ 2′ 1′) and
    /// a vowel-like formant cycle. Built once, the first time a synth is made.
    public static let factory: WavetableBank = {
        let count = cycleLength / 4
        func shape(_ amplitude: (Int) -> (Float, Float)) -> (sine: [Float], cosine: [Float]) {
            var sine = [Float](repeating: 0, count: count), cosine = [Float](repeating: 0, count: count)
            for h in 1...count {
                let (s, c) = amplitude(h)
                sine[h - 1] = s
                cosine[h - 1] = c
            }
            return (sine, cosine)
        }
        func pulse(_ width: Float) -> (sine: [Float], cosine: [Float]) {
            // A pulse high for `width` of the cycle, without its offset.
            shape { h in
                let a = 2 / (Float.pi * Float(h))
                let angle = 2 * Float.pi * Float(h) * width
                return (a * (1 - cosf(angle)), a * sinf(angle))
            }
        }
        let spectra: [(sine: [Float], cosine: [Float])] = [
            shape { h in (h == 1 ? 1 : 0, 0) },
            shape { h in (h % 2 == 1 ? ((h / 2) % 2 == 0 ? 1 : -1) / Float(h * h) : 0, 0) },
            shape { h in (-1 / Float(h), 0) },
            shape { h in (h % 2 == 1 ? 1 / Float(h) : 0, 0) },
            pulse(0.25),
            pulse(0.125),
            shape { h in ([1: 1, 2: 0.8, 4: 0.6, 3: 0.5, 6: 0.4, 8: 0.3][h] ?? 0, 0) },
            shape { h in
                // Harmonics gathered around two formants, near 600 Hz and 1 200 Hz for a 150 Hz note.
                let x = Float(h)
                return (expf(-((x - 4) * (x - 4)) / 3) + 0.6 * expf(-((x - 8) * (x - 8)) / 4) + 0.3 / x, 0)
            },
        ]
        return WavetableBank(spectra: spectra)
    }()
}

/// What a voice reads of a `WavetableBank`: pointers and a count, a trivial value. Valid while
/// the bank lives; the synth that holds a view holds the bank too.
public struct WavetableView: @unchecked Sendable {
    let values: UnsafePointer<Float>
    let starts: UnsafePointer<Int>
    let frameCount: Int

    /// One sample: `position` 0 … 1 across the cycles, `phase` 0 ..< 1 in the cycle, `dt` the
    /// increment, which picks the band limit. Between two cycles and between two levels it reads
    /// both and crossfades, so a moving position or a gliding note never steps. Render-safe.
    @inline(__always)
    func sample(position: Float, phase: Float, dt: Float) -> Float {
        let place = (position.isFinite ? Swift.min(Swift.max(position, 0), 1) : 0) * Float(frameCount - 1)
        let f0 = Swift.min(Int(place), frameCount - 1)
        let f1 = Swift.min(f0 + 1, frameCount - 1)
        let between = place - Float(f0)
        // Level k is alias-free while 512·2⁻ᵏ·dt ≤ ½, i.e. k ≥ log₂(1024·dt); one level higher,
        // faded in as the note rises, keeps both levels read inside that bound.
        let u = Swift.max(0, log2f(Swift.max(dt, 1e-9) * 1024) + 1)
        let top = WavetableBank.levels - 1
        let a = Swift.min(Int(u), top)
        let b = Swift.min(a + 1, top)
        let toward = a == top ? 0 : u - Float(a)
        let low = read(level: a, f0, f1, between, phase)
        guard toward > 0 else { return low }
        return low + (read(level: b, f0, f1, between, phase) - low) * toward
    }

    @inline(__always)
    private func read(level k: Int, _ f0: Int, _ f1: Int, _ between: Float, _ phase: Float) -> Float {
        let n = WavetableBank.length(level: k)
        var p = phase * Float(n)
        if !(p >= 0) { p = 0 }
        var i = Int(p)
        var t = p - Float(i)
        if i >= n { i = n - 1; t = 1 }
        let block = values + starts[k]
        let first = block + f0 * (n + 1)
        let x = first[i] + (first[i + 1] - first[i]) * t
        guard between > 0, f1 != f0 else { return x }
        let second = block + f1 * (n + 1)
        let y = second[i] + (second[i + 1] - second[i]) * t
        return x + (y - x) * between
    }
}

extension WavetableBank {
    /// A wavetable cut from a sample (the user's own sound): `frames` single cycles spread evenly
    /// across the file. At each place the cycle's length comes from a pitch estimate there
    /// (`WavetableAnalysis.period`); the cycle runs from a rising zero crossing to the rising
    /// crossing one period on, is resampled to 2048 points, loses its offset, and is band-limited
    /// per octave like every table. The same file and frame count always give the same bank — no
    /// randomness, no clock. Nil for a file with no sound in it. Allocates and takes time: never
    /// on the render thread.
    public convenience init?(sample: SampleBuffer, frames: Int) {
        let count = Swift.min(Swift.max(frames, 1), Self.maximumFrames)
        let length = sample.frameCount
        guard length >= 64 else { return nil }
        var mono = [Float](repeating: 0, count: length)
        for i in 0..<length { mono[i] = sample.mono(i) }
        let rate = sample.sampleRate
        var spectra: [(sine: [Float], cosine: [Float])] = []
        var heard = false
        var lastPeriod: Double?
        for j in 0..<count {
            let centre = Int((Double(j) + 0.5) / Double(count) * Double(length))
            let period = WavetableAnalysis.period(of: mono, around: centre, sampleRate: rate) ?? lastPeriod
                ?? WavetableAnalysis.fallbackPeriod(sampleRate: rate)
            lastPeriod = period
            guard let cycle = WavetableAnalysis.cycle(of: mono, around: centre, period: period) else {
                spectra.append(spectra.last ?? (sine: [], cosine: []))
                continue
            }
            if cycle.contains(where: { Swift.abs($0) > 1e-5 }) { heard = true }
            spectra.append(WavetableAnalysis.spectrum(of: cycle))
        }
        guard heard else { return nil }
        self.init(spectra: spectra)
    }
}

/// How a sample becomes cycles (`WavetableBank.init?(sample:frames:)`). Off the render thread.
enum WavetableAnalysis {
    /// The pitches a cycle is looked for between.
    static let lowestHertz = 30.0
    static let highestHertz = 2_000.0
    /// The difference window of the pitch estimate, in samples.
    static let window = 1_024
    /// YIN's threshold on the normalized difference: below it, the first dip is the period.
    static let threshold: Float = 0.15

    /// A cycle's length where no pitch is found (a noise, a drum): 1024 samples at 48 kHz.
    static func fallbackPeriod(sampleRate: Double) -> Double { 1_024 * sampleRate / 48_000 }

    /// The period in samples of the sound around `centre`, by YIN (de Cheveigné & Kawahara 2002):
    /// the cumulative-mean-normalized difference function, its first dip under the threshold,
    /// refined between samples by a parabola. Nil where the sound has no clear period or is silent.
    static func period(of x: [Float], around centre: Int, sampleRate: Double) -> Double? {
        guard sampleRate > 0, sampleRate.isFinite else { return nil }
        let shortest = Swift.max(2, Int(sampleRate / highestHertz))
        let longest = Int(sampleRate / lowestHertz)
        let span = window + longest + 2
        guard x.count > span else { return nil }
        let start = Swift.min(Swift.max(0, centre - span / 2), x.count - span)
        var energy: Float = 0
        for i in start..<(start + window) { energy += x[i] * x[i] }
        guard energy > 1e-8 else { return nil }
        var normalized = [Float](repeating: 1, count: longest + 2)
        x.withUnsafeBufferPointer { (samples: UnsafeBufferPointer<Float>) in
            guard let base = samples.baseAddress else { return }
            let first = base + start
            var running: Float = 0
            for tau in 1...(longest + 1) {
                var d: Float = 0
                let later = first + tau
                for i in 0..<window {
                    let delta = first[i] - later[i]
                    d += delta * delta
                }
                running += d
                normalized[tau] = running > 0 ? d * Float(tau) / running : 1
            }
        }
        var tau = shortest
        while tau < longest {
            if normalized[tau] < threshold {
                while tau + 1 < longest, normalized[tau + 1] < normalized[tau] { tau += 1 }
                let a = normalized[tau - 1], b = normalized[tau], c = normalized[tau + 1]
                let bend = a - 2 * b + c
                let shift = bend > 0 ? Double(0.5 * (a - c) / bend) : 0
                return Double(tau) + Swift.min(Swift.max(shift, -1), 1)
            }
            tau += 1
        }
        return nil
    }

    /// The cycle that starts at the rising zero crossing nearest `centre` and ends at the rising
    /// crossing nearest one period later, resampled to `WavetableBank.cycleLength` points without
    /// its offset. Nil where the file ends before the cycle does.
    static func cycle(of x: [Float], around centre: Int, period: Double) -> [Float]? {
        guard period.isFinite, period >= 2 else { return nil }
        let reach = Int(period.rounded(.up))
        let from = rising(in: x, near: Double(centre), within: reach) ?? Double(centre)
        let to = rising(in: x, near: from + period, within: Swift.max(1, reach / 4)) ?? from + period
        guard to > from + 2, Int(to.rounded(.up)) + 2 < x.count, from >= 1 else { return nil }
        let n = WavetableBank.cycleLength
        var cycle = [Float](repeating: 0, count: n)
        let step = (to - from) / Double(n)
        for k in 0..<n { cycle[k] = cubic(x, at: from + Double(k) * step) }
        let mean = cycle.reduce(0, +) / Float(n)
        for k in 0..<n { cycle[k] -= mean }
        return cycle
    }

    /// The rising zero crossing nearest `position`, within `within` samples either side, to a
    /// fraction of a sample.
    static func rising(in x: [Float], near position: Double, within: Int) -> Double? {
        let centre = Int(position)
        var best: Double?
        for offset in 0...within {
            for i in [centre - offset, centre + offset] where i >= 0 && i + 1 < x.count {
                guard x[i] <= 0, x[i + 1] > 0 else { continue }
                let crossing = Double(i) + Double(x[i] / (x[i] - x[i + 1]))
                if best.map({ Swift.abs(crossing - position) < Swift.abs($0 - position) }) ?? true { best = crossing }
            }
            if best != nil { return best }
        }
        return best
    }

    /// Catmull-Rom between the four samples around `t`.
    static func cubic(_ x: [Float], at t: Double) -> Float {
        let i = Int(t.rounded(.down))
        let f = Float(t - Double(i))
        func at(_ k: Int) -> Float { x[Swift.min(Swift.max(k, 0), x.count - 1)] }
        let p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
        let a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
        let b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3
        let c = -0.5 * p0 + 0.5 * p2
        return ((a * f + b) * f + c) * f + p1
    }

    /// The sine and cosine amplitudes of harmonics 1 … `cycleLength` / 4 of one cycle.
    static func spectrum(of cycle: [Float]) -> (sine: [Float], cosine: [Float]) {
        let n = cycle.count
        var re = cycle, im = [Float](repeating: 0, count: n)
        FFT(size: n).transform(real: &re, imaginary: &im)
        let count = WavetableBank.cycleLength / 4
        var sine = [Float](repeating: 0, count: count), cosine = [Float](repeating: 0, count: count)
        for h in 1...count where h < n / 2 {
            cosine[h - 1] = 2 * re[h] / Float(n)
            sine[h - 1] = -2 * im[h] / Float(n)
        }
        return (sine, cosine)
    }
}

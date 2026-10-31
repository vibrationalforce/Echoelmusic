import Foundation

/// Echoel Grain as an insert: a cloud of short windowed grains read from the last four seconds of
/// the input, each at its own place, pan and pitch, blended with the dry sound. Ported from the
/// earlier app's `GrainCloud` (which read a prepared file) with its scheduler intact; the source is
/// now a ring the input writes into, so the cloud follows what is playing.
///
/// What carries over, and why:
/// · **Grains start on a constant accumulator**, so the hop is uniform (`length / overlap`). Hann
///   windows at a uniform hop sum to `overlap / 2`, and dividing by that (never by less than 1)
///   holds the level at density 0.5 and above; below it the cloud thins. The randomness is in
///   WHERE a grain reads and its pan, never in WHEN it starts. The accumulator starts full, so the
///   first grain begins on the first sample.
/// · **The window starts and ends at exactly zero** — a grain cannot click.
/// · **A fixed pool of eight grains**; a grain with no free slot is dropped, never grown.
/// · **A seeded generator**, mixed before use: the same seed and input give the same output.
///
/// New for a live source: a grain must never read past the newest sample. A grain pitched up by a
/// ratio `r` gains `r − 1` samples a sample on the input, so it starts at least `length × (r − 1)`
/// behind; one pitched down falls back, so it starts early enough to stay inside the ring.
/// `position` is how far behind the input the grains read, in seconds.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. Everything is
/// allocated in `init`.
public final class Granulator: @unchecked Sendable {
    public struct Settings: Equatable, Sendable {
        /// Grain length in seconds, 0.01 … 0.5.
        public var size: Double
        /// 0 … 1 → 0.5 … 3.5 grains at once.
        public var density: Double
        /// Grain transposition in semitones, −24 … 24.
        public var pitch: Double
        /// How far behind the input the grains read, in seconds, 0 … 2.
        public var position: Double
        /// How far around `position` a grain may start, in seconds, 0 … 0.5.
        public var spray: Double
        /// 0: every grain in the middle, 1: scattered hard left and right.
        public var spread: Double
        /// Dry 0 … wet 1.
        public var mix: Double

        public init(size: Double = 0.08, density: Double = 0.5, pitch: Double = 0, position: Double = 0.25,
                    spray: Double = 0.05, spread: Double = 0.5, mix: Double = 0.5) {
            self.size = size
            self.density = density
            self.pitch = pitch
            self.position = position
            self.spray = spray
            self.spread = spread
            self.mix = mix
        }

        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(size: clamp(size, 0.01...0.5, base.size), density: clamp(density, 0...1, base.density),
                            pitch: clamp(pitch, -24...24, base.pitch), position: clamp(position, 0...2, base.position),
                            spray: clamp(spray, 0...0.5, base.spray), spread: clamp(spread, 0...1, base.spread),
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The grain pool.
    public static let maxGrains = 8
    /// The input the grains can reach, in seconds: the farthest position and spray, plus a grain
    /// two octaves down.
    public static let memorySeconds = 4.0

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double

    private struct Grain {
        var active = false
        /// Samples behind the newest input sample, now.
        var distance: Double = 0
        /// Input samples read per output sample.
        var ratio: Double = 1
        var position: Float = 0
        var length: Float = 1
        var gainLeft: Float = 1
        var gainRight: Float = 1
    }

    private let capacity: Int
    private let ring: UnsafeMutablePointer<Float>
    private var newest = 0
    private let grains: UnsafeMutablePointer<Grain>
    private var accumulator: Float = 1
    private let seed: UInt64
    private var random: UInt64
    private var mixNow: Float
    private let mixGlide: Float

    public init(sampleRate: Double, settings: Settings = Settings(), seed: UInt64 = 0x9E37_79B9_7F4A_7C15) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? Swift.min(sampleRate, 384_000) : 48_000
        capacity = Int(Self.memorySeconds * self.sampleRate)
        ring = .allocate(capacity: capacity)
        ring.initialize(repeating: 0, count: capacity)
        grains = .allocate(capacity: Self.maxGrains)
        grains.initialize(repeating: Grain(), count: Self.maxGrains)
        self.seed = seed
        random = Self.mixed(seed)
        mixGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        mixNow = Float(self.settings.mix)
    }

    deinit {
        ring.deallocate()
        grains.deinitialize(count: Self.maxGrains)
        grains.deallocate()
    }

    /// How many grains are sounding. For tests; not on the render thread.
    public var activeGrainCount: Int {
        var count = 0
        for i in 0..<Self.maxGrains where grains[i].active { count += 1 }
        return count
    }

    /// Silences every grain, empties the ring and rewinds the seed.
    public func reset() {
        ring.update(repeating: 0, count: capacity)
        newest = 0
        for i in 0..<Self.maxGrains { grains[i] = Grain() }
        accumulator = 1
        random = Self.mixed(seed)
        mixNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let s = settings
        let length = Swift.max(2, Float(s.size * sampleRate))
        let ratio = Foundation.pow(2, s.pitch / 12)
        let overlap = Float(0.5 + 3 * s.density)
        let perSample = overlap / length
        let norm = 1 / Swift.max(1, overlap * 0.5)
        let mixTarget = Float(s.mix)
        var mix = mixNow
        for i in 0..<frames {
            let inLeft = left[i].isFinite ? left[i] : 0
            let inRight = right[i].isFinite ? right[i] : 0
            newest = newest + 1 < capacity ? newest + 1 : 0
            ring[newest] = 0.5 * (inLeft + inRight)
            accumulator += perSample
            while accumulator >= 1 {
                accumulator -= 1
                spawn(length: Double(length), ratio: ratio, settings: s)
            }
            var wetLeft: Float = 0
            var wetRight: Float = 0
            for g in 0..<Self.maxGrains where grains[g].active {
                let window = 0.5 - 0.5 * cosf(2 * Float.pi * grains[g].position / grains[g].length)
                let sample = read(grains[g].distance) * window
                wetLeft += sample * grains[g].gainLeft
                wetRight += sample * grains[g].gainRight
                grains[g].distance += 1 - grains[g].ratio
                grains[g].position += 1
                if grains[g].position >= grains[g].length { grains[g].active = false }
            }
            mix = Compressor.glided(mix, toward: mixTarget, by: mixGlide)
            let outLeft = inLeft * (1 - mix) + wetLeft * norm * mix
            let outRight = inRight * (1 - mix) + wetRight * norm * mix
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                mix = mixNow
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        mixNow = mix
    }

    /// Starts one grain in the first free slot, or none when the pool is full.
    private func spawn(length: Double, ratio: Double, settings s: Settings) {
        var slot = -1
        for i in 0..<Self.maxGrains where !grains[i].active {
            slot = i
            break
        }
        guard slot >= 0 else { return }
        let nearest = ratio > 1 ? length * (ratio - 1) + 2 : 2
        let farthest = Double(capacity - 3) - (ratio < 1 ? length * (1 - ratio) : 0)
        guard nearest <= farthest else { return }
        let wanted = s.position * sampleRate + Double(next01() * 2 - 1) * s.spray * sampleRate
        let pan = (next01() * 2 - 1) * Float(s.spread)
        // Equal power, unity in the middle.
        grains[slot] = Grain(active: true, distance: Swift.min(Swift.max(wanted, nearest), farthest), ratio: ratio,
                             position: 0, length: Float(length),
                             gainLeft: (Swift.max(0, 1 - pan)).squareRoot(),
                             gainRight: (Swift.max(0, 1 + pan)).squareRoot())
    }

    /// The ring `distance` samples behind the newest sample, linearly interpolated.
    @inline(__always)
    private func read(_ distance: Double) -> Float {
        let back = Swift.min(Swift.max(distance, 0), Double(capacity - 2))
        var position = Double(newest) - back
        if position < 0 { position += Double(capacity) }
        let index = Swift.min(Int(position), capacity - 1)
        let fraction = Float(position - Double(index))
        let next = index + 1 < capacity ? index + 1 : 0
        return ring[index] + (ring[next] - ring[index]) * fraction
    }

    /// The seed through splitmix64's finaliser, so a small seed does not start on near-zero draws.
    private static func mixed(_ seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Numerical Recipes LCG.
    @inline(__always)
    private func next01() -> Float {
        random = random &* 1_664_525 &+ 1_013_904_223
        return Float(random >> 40) / Float(1 << 24)
    }
}

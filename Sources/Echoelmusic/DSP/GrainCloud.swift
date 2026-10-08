import Foundation

/// GMMW GA-9 — Echoel Grain: a cloud of short windowed grains read from a SOURCE BUFFER (a file's
/// samples), each at its own place, length, pan and pitch. The kernel only: no door, no device, no
/// caller yet — GA-10 renders it as an insert on an audio track, fed by the managed file.
///
/// ⭐ PORTED, NOT INVENTED. `EchoelGranular` (2026-08-21 → #1305) ran the same scheduler over a ring of
/// the MICROPHONE and went with the audio input (`docs/dev/HISTORY_ARCHIVE.md` B5: "PORT ALGORITHM —
/// the source must become a buffer or clip, not the mic"). What carries over, with the reasons it
/// learned the hard way:
/// · **Spawning is driven by an accumulator incremented by a CONSTANT**, so the grain hop is uniform
///   (`length / overlap`). Hann windows at a uniform hop sum to `overlap / 2` — the COLA condition —
///   so dividing by that keeps a dense cloud at the source's level instead of letting density double
///   as a volume control. The randomness is in WHERE a grain reads and its pan, never in WHEN it
///   starts; make spawning stochastic and the normalisation stops being exact.
/// · **The raised-cosine window starts and ends at exactly zero** — the whole reason a grain cannot
///   click.
/// · **A pitched grain's read is BUDGETED, not just offset.** A long up-shifted grain reads
///   `length × ratio` source samples; where the buffer is too short for that, the grain is SHORTENED
///   so its pitch stays true for its whole life (the old ring version silently stopped shifting for
///   its tail instead — no click, so it would never have surfaced as a bug report).
/// · **The RNG is local on purpose**: `DSP/` must not reach for a Sequencer type
///   (`TheDSPLayerStaysFoundationOnlyTests`), and this file is also compiled into the AUv3 extension,
///   which sees `DSP/` alone.
///
/// ⚠️ THE THREAD CONTRACT. `init` and `prepare(source:)` ALLOCATE; `process(left:right:frameCount:)`
/// never does — no array, no string, no lock, no Foundation call but C math. `prepare` swaps the
/// source buffer and must not run while `process` does; the caller that renders it (GA-10) hands a
/// new source over the way `SamplerVoice` hands a sample over, never by calling `prepare` from the
/// render thread. The six parameters are plain control-plane reads, sanitised on every use.
public final class GrainCloud: @unchecked Sendable {

    // MARK: - Control-plane parameters (plain reads on the audio thread)

    /// Where in the source the grains read, 0 (start) … 1 (end).
    public var position: Float = 0
    /// Grain length in milliseconds, 10 … 500. Short reads as texture, long as a smeared cloud.
    public var grainMilliseconds: Float = 80
    /// 0 … 1 → overlap 0.5 … 3.5 grains. Never zero: an enabled cloud that schedules nothing reads
    /// as broken.
    public var density: Float = 0.5
    /// How far around `position` a grain may start, in seconds, 0 … 0.5.
    public var spraySeconds: Float = 0.05
    /// Grain transposition in semitones, −24 … +24.
    public var pitchSemitones: Float = 0
    /// 0 = every grain centred, 1 = grains scattered hard left and right.
    public var stereoSpread: Float = 0.5

    // MARK: - Limits

    /// The grain pool. A hard cap: a launch with no free slot is dropped, never grown.
    public static let maxGrains = 8
    /// The longest source kept, in seconds; `prepare` keeps the first this-many seconds.
    public static let maxSourceSeconds: Float = 30

    /// The raised-cosine grain envelope — 0 at both ends, 1 in the middle, 0 outside 0…1 and for a
    /// non-finite position. Exposed because it carries the no-click promise.
    @inline(__always)
    public static func window(_ position01: Float) -> Float {
        guard position01.isFinite, position01 >= 0, position01 <= 1 else { return 0 }
        return 0.5 - 0.5 * cosf(2.0 * Float.pi * position01)
    }

    // MARK: - State

    private struct Grain {
        var active = false
        var readIndex: Double = 0   // fractional source frame — Double: a Float index loses the
                                    // fraction past 2^24 frames (≈ 6 min at 48 kHz) and steps coarsely long before
        var step: Double = 1        // source frames per output frame — the pitch ratio
        var position: Float = 0     // 0 … length, in output frames
        var length: Float = 1
        var gainL: Float = 1
        var gainR: Float = 1
    }

    public let sampleRate: Float
    private let grains: UnsafeMutablePointer<Grain>
    private var source: UnsafeMutablePointer<Float>?
    private var sourceCount = 0
    private var spawnAccumulator: Float = 0
    private var rngState: UInt64
    private let seed: UInt64

    /// ALLOCATES the grain pool. `seed` pins the grain pattern: two clouds with the same seed and
    /// source render the same output.
    public init(sampleRate: Float = 48_000, seed: UInt64 = 0x9E37_79B9_7F4A_7C15) {
        // Bounded above as well, so `maxSourceSeconds × sampleRate` always fits an `Int`.
        self.sampleRate = (sampleRate.isFinite && sampleRate >= 1 && sampleRate <= 768_000) ? sampleRate : 48_000
        self.grains = UnsafeMutablePointer<Grain>.allocate(capacity: Self.maxGrains)
        self.grains.initialize(repeating: Grain(), count: Self.maxGrains)
        self.seed = seed
        self.rngState = seed
    }

    deinit {
        grains.deinitialize(count: Self.maxGrains)
        grains.deallocate()
        source?.deallocate()
    }

    /// ALLOCATES. Copies `samples` (mono, at `sampleRate`) into the cloud's own buffer — at most
    /// `maxSourceSeconds`, every non-finite sample as silence — and resets the grains and the seed.
    /// Control plane only, never while `process` runs.
    public func prepare(source samples: [Float]) {
        source?.deallocate()
        source = nil
        sourceCount = 0
        reset()
        let cap = Int(Self.maxSourceSeconds * sampleRate)
        let count = Swift.min(samples.count, Swift.max(0, cap))
        guard count > 0 else { return }
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: count)
        for i in 0..<count {
            let x = samples[i]
            buffer[i] = x.isFinite ? x : 0
        }
        source = buffer
        sourceCount = count
    }

    /// Whether a source is loaded (at least two frames — one interpolation step).
    public var isPrepared: Bool { sourceCount > 1 }

    /// How many grains are sounding. Test-facing; nothing on the audio thread reads it.
    public var activeGrainCount: Int {
        var n = 0
        for i in 0..<Self.maxGrains where grains[i].active { n += 1 }
        return n
    }

    /// Silence every grain and rewind the seed — a reset cloud renders what a freshly prepared one
    /// does. Keeps the source.
    public func reset() {
        for i in 0..<Self.maxGrains { grains[i] = Grain() }
        spawnAccumulator = 0
        rngState = seed
    }

    // MARK: - Render

    /// NEVER ALLOCATES. Writes `frameCount` frames of the cloud into `left` and `right` (it writes,
    /// it does not add — the caller mixes). No source, or a non-positive count: silence.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                        frameCount: Int) {
        guard frameCount > 0 else { return }
        guard let src = source, sourceCount > 1 else {
            for f in 0..<frameCount {
                left[f] = 0
                right[f] = 0
            }
            return
        }
        let lengthSamples = Swift.max(1, Self.bounded(grainMilliseconds, 10, 500, fallback: 80) * 0.001 * sampleRate)
        let overlap = 0.5 + 3.0 * Self.bounded(density, 0, 1, fallback: 0.5)
        let grainsPerSample = overlap / lengthSamples
        let norm = 1.0 / Swift.max(1.0, overlap * 0.5)
        for f in 0..<frameCount {
            spawnAccumulator += grainsPerSample
            while spawnAccumulator >= 1 {
                spawnAccumulator -= 1
                spawn(lengthSamples: lengthSamples)
            }
            var wetL: Float = 0
            var wetR: Float = 0
            for i in 0..<Self.maxGrains where grains[i].active {
                let g = Self.window(grains[i].position / grains[i].length)
                let s = Self.read(src, count: sourceCount, at: grains[i].readIndex)
                wetL += s * g * grains[i].gainL
                wetR += s * g * grains[i].gainR
                grains[i].position += 1
                grains[i].readIndex += grains[i].step
                if grains[i].position >= grains[i].length { grains[i].active = false }
            }
            let outL = wetL * norm
            let outR = wetR * norm
            left[f] = outL.isFinite ? outL : 0
            right[f] = outR.isFinite ? outR : 0
        }
    }

    // MARK: - Private

    /// Launch one grain in the first free slot — or none, when the pool is full.
    private func spawn(lengthSamples: Float) {
        var slot = -1
        for i in 0..<Self.maxGrains where !grains[i].active {
            slot = i
            break
        }
        guard slot >= 0 else { return }
        let ratio = Double(powf(2.0, Self.bounded(pitchSemitones, -24, 24, fallback: 0) / 12.0))
        // The budget: a grain reads `length × ratio` source frames and must stay inside the buffer,
        // so a grain the buffer cannot hold at this ratio is shortened, never left to run off the end.
        let usable = Double(sourceCount - 2)
        let length = Swift.max(1, Swift.min(Double(lengthSamples), usable / ratio))
        let span = Swift.min(usable, length * ratio)
        let centre = Double(Self.bounded(position, 0, 1, fallback: 0)) * Double(sourceCount - 1)
        let spray = Double(Self.bounded(spraySeconds, 0, 0.5, fallback: 0.05) * sampleRate)
        let wanted = centre + Double(next01() * 2 - 1) * spray
        let start = Swift.min(Swift.max(wanted, 0), Swift.max(0, usable - span))
        let pan = (next01() * 2 - 1) * Self.bounded(stereoSpread, 0, 1, fallback: 0.5)   // −1 … +1
        grains[slot] = Grain(active: true,
                             readIndex: start,
                             step: ratio,
                             position: 0,
                             length: Float(length),
                             gainL: sqrtf(Swift.max(0, 0.5 * (1 - pan))),
                             gainR: sqrtf(Swift.max(0, 0.5 * (1 + pan))))
    }

    /// Linear interpolation at a fractional frame, held inside the buffer (a stray index reads the
    /// nearest edge, never past it).
    @inline(__always)
    private static func read(_ src: UnsafeMutablePointer<Float>, count: Int, at index: Double) -> Float {
        let last = Double(count - 2)
        let x = index.isFinite ? Swift.min(Swift.max(index, 0), last) : 0
        let i0 = Int(x)
        let frac = Float(x - Double(i0))
        return src[i0] + (src[i0 + 1] - src[i0]) * frac
    }

    /// A parameter on use: non-finite → its default, otherwise clamped.
    @inline(__always)
    private static func bounded(_ value: Float, _ low: Float, _ high: Float, fallback: Float) -> Float {
        value.isFinite ? Swift.min(Swift.max(value, low), high) : fallback
    }

    /// Numerical Recipes LCG — local by the layering rule in the header, not a duplicate to fold.
    @inline(__always)
    private func next01() -> Float {
        rngState = rngState &* 1_664_525 &+ 1_013_904_223
        return Float(rngState >> 40) / Float(1 << 24)
    }
}

import Foundation

/// The amplitudes a texture voice glides, allocated once per voice where the voice is made —
/// never on the render thread — and released with it. Five lanes of `TextureSource.partialCount`
/// floats: each partial's weight (tilt × density), its target, its amplitude now, its tapered gain
/// now and the gain's ramp per sample until the next control step.
final class TextureLanes: @unchecked Sendable {
    static let laneCount = 5
    let values: UnsafeMutablePointer<Float>

    init() {
        let count = Self.laneCount * TextureSource.partialCount
        values = .allocate(capacity: count)
        values.initialize(repeating: 0, count: count)
    }

    deinit {
        values.deallocate()
    }
}

/// A texture (EchoelTools A10, the core of the earlier app's `EchoelCellular`, ported, not copied):
/// a one-dimensional cellular automaton whose row of cells shapes the partials of the note.
///
/// Sixty-four cells on a ring live in one `UInt64`; a generation is Wolfram's elementary rule
/// applied to every cell at once, by bit operations on the whole row — the earlier engine updated
/// its cells in place, so each cell already saw its left neighbour's NEW state; here every cell
/// reads the previous generation, as the rule is defined. The row is read as sixteen groups of four
/// cells: group 0 is the fundamental (always half there, so the note keeps its pitch), groups
/// 1 … 15 the harmonics 2 … 16, each as loud as the share of its four cells alive.
///
/// The controls, all from the patch: `rule` one of eight elementary rules (`ruleNumber`), `density`
/// how many of the harmonics may sound (0 the fundamental alone, 1 all sixteen), `rate` the
/// generations per second (0 holds the row), `seed` the row a note starts from (0 a single cell in
/// the middle, the classic start; any other number a row drawn from it). `character` tilts the
/// partials from dark (1/n²) to bright (1/√n). Every note starts from its seed's row, so the same
/// seed, rule and rate sound the same note the same way, live and in an export. Each partial's
/// amplitude glides to its target — a quarter of a generation, 4 … 80 ms — so a new generation is
/// a movement, never a click; partials fade out towards Nyquist and are not computed above it.
///
/// Render thread: nothing here allocates; the lanes come from the voice's `init`.
struct TextureSource: Sendable {
    static let partialCount = 16
    /// Samples between rebuilds of the weights (tilt × density): 0.67 ms at 48 kHz.
    static let controlInterval = 32
    /// The most generations a second; above it the row flickers into noise.
    static let maximumRate: Float = 40
    /// The anti-alias band, as the DDSP's: a partial fades from 85 % of Nyquist, silent at it.
    static let taperStart: Float = 0.425
    static let taperScale: Float = 1 / 0.075

    /// The elementary rule behind a stored choice. A song stores the INDEX of the choice, so a new
    /// rule goes at the end (`SynthParameter.textureRule`). A switch, not a table: the render
    /// thread reads it, and a stored static is initialised lazily.
    @inline(__always)
    static func ruleNumber(index: Int) -> UInt8 {
        switch index {
        case 1: 30    // chaos, noise-like
        case 2: 110   // order and chaos mixed
        case 3: 150   // additive, symmetric
        case 4: 184   // traffic: the row drifts
        case 5: 45    // chaos, leaning to one side
        case 6: 73    // islands
        case 7: 105   // the complementary Sierpinski
        default: 90   // Sierpinski, a fractal: the default
        }
    }

    /// One generation of `rule` on a ring of sixty-four cells: bit `i` of the result is bit
    /// `(left · 4 + centre · 2 + right)` of the rule, read from the row before.
    @inline(__always)
    static func evolve(_ row: UInt64, rule: UInt8) -> UInt64 {
        let left = (row << 1) | (row >> 63)
        let right = (row >> 1) | (row << 63)
        let centre = row
        var next: UInt64 = 0
        for pattern in 0..<8 where (rule >> UInt8(pattern)) & 1 == 1 {
            let l = pattern & 4 != 0 ? left : ~left
            let c = pattern & 2 != 0 ? centre : ~centre
            let r = pattern & 1 != 0 ? right : ~right
            next |= l & c & r
        }
        return next
    }

    /// The row a note starts from. Seed 0 is the single middle cell; any other a row drawn from
    /// it by SplitMix64, never empty.
    static func initialRow(seed: UInt32) -> UInt64 {
        guard seed != 0 else { return 1 << 32 }
        var z = UInt64(seed) &* 0x9E37_79B9_7F4A_7C15 &+ 0x6A09_E667_F3BC_C909
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return z == 0 ? 1 << 32 : z
    }

    private let lanes: TextureLanes
    private var row: UInt64 = 1 << 32
    /// Where the row is between two generations, 0 ..< 1.
    private var generation: Float = 0
    /// The note's position in its cycle, 0 ..< 1.
    private var phase: Float = 0
    private var normalization: Float = 1
    private var tableCharacter: Float = -1
    private var tableDensity: Float = -1
    private var controlCountdown = 0
    /// How many partials, from the first, sit below Nyquist at the last control step.
    private var audible = 0
    /// Samples since the last control step: how far each gain has ramped.
    private var ramped = 0
    /// The targets must be built again: a strike, a generation or new weights.
    private var stale = true
    /// A fresh note takes its targets at once; the amp envelope is its attack.
    private var snap = true

    // Set from the patch before each render (`configure`).
    private var rule: UInt8 = 90
    private var density: Float = 0.6
    /// Generations per sample.
    private var step: Float = 0
    /// Glide of each amplitude toward its target, per control step.
    private var glide: Float = 0.01
    private var seed: UInt32 = 0

    init() {
        lanes = TextureLanes()
    }

    /// Silent and still: a fresh note starts from nothing.
    mutating func reset() {
        lanes.values.update(repeating: 0, count: TextureLanes.laneCount * Self.partialCount)
        phase = 0
        generation = 0
        tableCharacter = -1
        tableDensity = -1
        controlCountdown = 0
        audible = 0
        ramped = 0
        stale = true
        snap = true
    }

    /// The patch's texture, before each render. Every value is made safe here: a rule index out
    /// of range plays rule 90, a density or rate that is not a number plays its default.
    mutating func configure(ruleIndex: Int, density: Float, rate: Float, seed: UInt32, sampleRate: Float) {
        rule = Self.ruleNumber(index: ruleIndex)
        self.density = density.isFinite ? Swift.min(Swift.max(density, 0), 1) : 0.6
        let r = rate.isFinite ? Swift.min(Swift.max(rate, 0), Self.maximumRate) : 0
        let sr = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        step = r / sr
        // A quarter of a generation, never faster than 4 ms, never slower than 80 ms.
        let seconds = r > 0 ? Swift.min(Swift.max(0.25 / r, 0.004), 0.08) : 0.08
        // Per control step: the amplitudes move once every `controlInterval` samples.
        glide = 1 - expf(-Float(Self.controlInterval) / (seconds * sr))
        self.seed = seed
    }

    /// A key struck this voice: the row starts again from the seed, the generation from its start.
    /// On a sounding voice the partials glide from where they are to the new row.
    mutating func strike() {
        row = Self.initialRow(seed: seed)
        generation = 0
        stale = true
    }

    /// One sample. `dt` is the note's increment in cycles per sample (finite, 0 < dt < 0.5, as
    /// `EngineSource` guarantees); `character` is 0 … 1.
    ///
    /// The per-sample work is one loop over the audible partials: two Clenshaw sums, the gains and
    /// their linear ramps. Everything else — the generation's targets, the glide
    /// toward them, the taper below Nyquist and how many partials are audible — moves once every
    /// `controlInterval` samples, at a fixed count from the note's start, so a block size changes
    /// nothing.
    @inline(__always)
    mutating func next(character: Float, dt: Float) -> Float {
        generation += step
        if generation >= 1 {
            generation -= 1
            row = Self.evolve(row, rule: rule)
            stale = true
        }
        if controlCountdown <= 0 {
            controlCountdown = Self.controlInterval
            control(character: character, dt: dt)
        }
        controlCountdown -= 1

        // Σ (gₖ + t·dₖ)·sin(kθ) for the audible partials, t the samples since the control step,
        // as two Clenshaw sums: bₖ = xₖ + 2cosθ·bₖ₊₁ − bₖ₊₂, and the sum is b₁·sinθ. One read per
        // partial and sum, nothing written, no partial's own oscillator to drift.
        let gain = lanes.values + 3 * Self.partialCount, slope = lanes.values + 4 * Self.partialCount
        let angle = 2 * Float.pi * phase
        let s1 = sinf(angle)
        let twoCos = 2 * cosf(angle)
        var g1: Float = 0, g2: Float = 0, d1: Float = 0, d2: Float = 0
        var k = audible
        while k > 0 {
            k -= 1
            let g0 = gain[k] + twoCos * g1 - g2
            g2 = g1
            g1 = g0
            let d0 = slope[k] + twoCos * d1 - d2
            d2 = d1
            d1 = d0
        }
        let sum = (g1 + Float(ramped) * d1) * s1
        ramped += 1
        phase += dt
        if phase >= 1 { phase -= 1 }
        return sum.isFinite ? sum : 0
    }

    /// Once per `controlInterval`: new weights if Character or density moved, new targets if the
    /// row did, each amplitude one glide step toward its target, and the ramp each partial's gain
    /// takes there over the next interval — tapered from 85 % of Nyquist, silent at it.
    private mutating func control(character: Float, dt: Float) {
        let n = Self.partialCount
        let weight = lanes.values, target = lanes.values + n, amplitude = lanes.values + 2 * n
        let gain = lanes.values + 3 * n, slope = lanes.values + 4 * n
        if Swift.abs(character - tableCharacter) > 1e-4 || density != tableDensity {
            rebuildWeights(character: character, into: weight)
            stale = true
        }
        if stale {
            stale = false
            for k in 0..<n {
                let cells = Float(((row >> UInt64(4 * k)) & 0xF).nonzeroBitCount) / 4
                let share = k == 0 ? 0.5 + 0.5 * cells : cells
                target[k] = weight[k] * normalization * share
            }
        }
        let fresh = snap
        snap = false
        // The gains where the last interval's ramps have taken them.
        if ramped > 0 {
            let travelled = Float(ramped)
            for k in 0..<n { gain[k] += slope[k] * travelled }
        }
        ramped = 0
        let step = 1 / Float(Self.controlInterval)
        var count = 0
        for k in 0..<n {
            let frequency = Float(k + 1) * dt
            let taper = Swift.min(Swift.max((0.5 - frequency) * Self.taperScale, 0), 1)
            let a = fresh ? target[k] : amplitude[k] + (target[k] - amplitude[k]) * glide
            amplitude[k] = a
            let end = a * taper
            if fresh { gain[k] = end }
            slope[k] = (end - gain[k]) * step
            // A partial that has just crossed out of the band falls to nothing over the interval
            // instead of being cut; once there it is not computed.
            if taper <= 0, Swift.abs(gain[k]) < 1e-7 {
                gain[k] = 0
                slope[k] = 0
            } else {
                count = k + 1
            }
        }
        audible = count
    }

    /// The weight of each partial — the tilt Character sets, times whether density lets it sound —
    /// and the gain that brings a row of all-living cells to the power of one full sine.
    private mutating func rebuildWeights(character: Float, into weight: UnsafeMutablePointer<Float>) {
        tableCharacter = character
        tableDensity = density
        let exponent = 2 - 1.5 * character
        let reach = density * Float(Self.partialCount - 1)
        var power: Float = 0
        for k in 0..<Self.partialCount {
            let tilt = exp2f(-exponent * log2f(Float(k + 1)))
            let allowed: Float = k == 0 ? 1 : Swift.min(Swift.max(reach - Float(k - 1), 0), 1)
            let w = tilt * allowed
            weight[k] = w
            power += w * w
        }
        normalization = power > 0 ? 1 / power.squareRoot() : 0
    }
}

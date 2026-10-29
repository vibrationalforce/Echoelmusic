import Foundation

/// Turn a `VibeParameters` plus a seed and a role into a bar's worth of notes (wave W11.1c).
/// Pure function: the same `(vibe, seed, role, bars)` always returns the same notes — so the
/// musician gets a reproducible sketch, keeps authorship over the result, and can regenerate
/// variations by picking another seed.
///
/// No randomness that reaches the system: `SplitMix64` is seeded from the caller and runs on
/// pure arithmetic, so the generator is testable, deterministic on every platform, and never
/// touches Foundation's non-sendable `SystemRandomNumberGenerator`.
public enum PatternGenerator {

    /// What a note's role is in the loop. The role shapes pitch, octave band and rhythm — a
    /// drums pattern lives on fixed GM pitches, a bass pattern on the root in a low octave,
    /// chords on scale triads around the middle, a lead on scale tones high up.
    public enum Role: String, Codable, Sendable {
        case drums, bass, chords, lead
    }

    /// Generate `bars` of notes for `role`. `signature` sets the bar length; `seed` is the
    /// explicit seed — pass `vibe.defaultSeed` to get the vibe's canonical pattern.
    public static func generate(vibe: VibeParameters,
                                seed: UInt64,
                                role: Role,
                                bars: Int = 1,
                                signature: TimeSignature = .common) -> [Note] {
        let bars = Swift.min(Swift.max(1, bars), 16)
        let ticksPerBar = MusicalTime.ticksPerBar(signature)
        var rng = SplitMix64(seed: seed &+ roleSalt(role))
        var notes: [Note] = []

        for bar in 0..<bars {
            let barOffset = Tick(bar) * ticksPerBar
            switch role {
            case .drums:
                notes.append(contentsOf: drums(vibe: vibe, rng: &rng, barOffset: barOffset, ticksPerBar: ticksPerBar))
            case .bass:
                notes.append(contentsOf: bass(vibe: vibe, rng: &rng, barOffset: barOffset, ticksPerBar: ticksPerBar))
            case .chords:
                notes.append(contentsOf: chords(vibe: vibe, rng: &rng, barOffset: barOffset, ticksPerBar: ticksPerBar))
            case .lead:
                notes.append(contentsOf: lead(vibe: vibe, rng: &rng, barOffset: barOffset, ticksPerBar: ticksPerBar))
            }
        }
        return notes
    }

    // MARK: - Roles

    private static func drums(vibe: VibeParameters,
                              rng: inout SplitMix64,
                              barOffset: Tick,
                              ticksPerBar: Tick) -> [Note] {
        let step = ticksPerBar / 16
        var out: [Note] = []
        // Kick on 1 and (energy-dependent) 3; vibe `energy` adds off-beat kicks.
        out.append(Note(pitch: 36, velocity: velocity(0.9, vibe: vibe),
                        start: barOffset, length: step))
        if vibe.energy > 0.3 {
            out.append(Note(pitch: 36, velocity: velocity(0.8, vibe: vibe),
                            start: barOffset + 8 * step, length: step))
        }
        if vibe.energy > 0.7 && rng.unit() < vibe.energy {
            out.append(Note(pitch: 36, velocity: velocity(0.7, vibe: vibe),
                            start: barOffset + 10 * step, length: step))
        }
        // Snare on 2 and 4.
        out.append(Note(pitch: 38, velocity: velocity(0.85, vibe: vibe),
                        start: barOffset + 4 * step, length: step))
        out.append(Note(pitch: 38, velocity: velocity(0.85, vibe: vibe),
                        start: barOffset + 12 * step, length: step))
        // Hi-hats: density picks how many 16th cells carry one.
        let hatProbability = 0.3 + vibe.density * 0.65
        for cell in 0..<16 {
            if rng.unit() < hatProbability {
                let hat = (vibe.energy > 0.7 && cell % 2 == 1) ? 44 : 42 // pedal vs closed
                out.append(Note(pitch: hat, velocity: velocity(0.55, vibe: vibe),
                                start: barOffset + Tick(cell) * step, length: step / 2))
            }
        }
        return out
    }

    private static func bass(vibe: VibeParameters,
                             rng: inout SplitMix64,
                             barOffset: Tick,
                             ticksPerBar: Tick) -> [Note] {
        let step = ticksPerBar / 8  // eighths
        let rootLow = 36 + vibe.targetKeyRoot // one octave below middle C
        let scaleDegrees = Array(vibe.targetScale.intervals).sorted()
        var out: [Note] = []
        for cell in 0..<8 {
            let play = (cell == 0) || rng.unit() < (0.25 + vibe.density * 0.5)
            if !play { continue }
            let degree = cell == 0 ? 0 : scaleDegrees.randomPick(&rng)
            let pitch = Swift.min(72, rootLow + degree)
            out.append(Note(pitch: pitch,
                            velocity: velocity(0.75, vibe: vibe),
                            start: barOffset + Tick(cell) * step,
                            length: step))
        }
        return out
    }

    private static func chords(vibe: VibeParameters,
                               rng: inout SplitMix64,
                               barOffset: Tick,
                               ticksPerBar: Tick) -> [Note] {
        // One chord per beat for dense vibes, one per two beats for sparser ones.
        let chordsPerBar = vibe.density > 0.55 ? 4 : 2
        let step = ticksPerBar / Tick(chordsPerBar)
        let rootMid = 60 + vibe.targetKeyRoot
        let scaleDegrees = Array(vibe.targetScale.intervals).sorted()
        guard scaleDegrees.count >= 3 else { return [] }
        var out: [Note] = []
        for cell in 0..<chordsPerBar {
            let anchor = cell == 0 ? 0 : scaleDegrees.randomPick(&rng)
            let third = scaleDegrees.first(where: { $0 > anchor + 2 }) ?? scaleDegrees[2]
            let fifth = scaleDegrees.first(where: { $0 > third + 2 }) ?? scaleDegrees[scaleDegrees.count - 1]
            let start = barOffset + Tick(cell) * step
            for degree in [anchor, third, fifth] {
                out.append(Note(pitch: Swift.min(84, rootMid + degree),
                                velocity: velocity(0.6, vibe: vibe),
                                start: start, length: step))
            }
        }
        return out
    }

    private static func lead(vibe: VibeParameters,
                             rng: inout SplitMix64,
                             barOffset: Tick,
                             ticksPerBar: Tick) -> [Note] {
        let step = ticksPerBar / 16
        let rootHigh = 72 + vibe.targetKeyRoot
        let scaleDegrees = Array(vibe.targetScale.intervals).sorted()
        var out: [Note] = []
        let density = 0.2 + vibe.density * 0.5 + vibe.energy * 0.15
        for cell in 0..<16 {
            if rng.unit() >= density { continue }
            let degree = scaleDegrees.randomPick(&rng)
            out.append(Note(pitch: Swift.min(96, rootHigh + degree),
                            velocity: velocity(0.7, vibe: vibe),
                            start: barOffset + Tick(cell) * step,
                            length: step * 2))
        }
        return out
    }

    // MARK: - Helpers

    private static func velocity(_ base: Double, vibe: VibeParameters) -> Int {
        let scaled = base * (0.65 + vibe.energy * 0.35)
        return Swift.min(127, Swift.max(1, Int((scaled * 127).rounded())))
    }

    private static func roleSalt(_ role: Role) -> UInt64 {
        switch role {
        case .drums:  return 0xD1C7_B057_E0A7_D061
        case .bass:   return 0xBA55_1E55_15B0_55ED
        case .chords: return 0xC0D5_C0D5_C0D5_C0D5
        case .lead:   return 0x1EAD_1EAD_1EAD_1EAD
        }
    }
}

// MARK: - Deterministic PRNG

/// A fast, seedable PRNG. Not for crypto. SplitMix64 is standard and reproducible —
/// the same seed on any platform yields the same stream.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }

    /// A uniform double in `[0, 1)`.
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

private extension Array where Element == Int {
    func randomPick(_ rng: inout SplitMix64) -> Int {
        guard !isEmpty else { return 0 }
        let i = Int(rng.next() % UInt64(count))
        return self[i]
    }
}

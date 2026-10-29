import Foundation

/// What a Loop-Generator request asks for in one value (wave W11, `scratchpads/PLAN_v11_LOOP_GENERATOR_2026-10-29.md`).
/// A `VibeParameters` is a snapshot of the musician's intent — genre, energy, density, brightness
/// of sound, a target tempo and key — that a deterministic pattern generator turns into notes.
/// Pure value; it stores nothing in the project, carries no reference, holds no state.
///
/// Authorship stays with the musician: a `VibeParameters` is a hint, never a decision. The same
/// parameters plus the same seed always produce the same notes, so the result is reproducible
/// and the user is the sole author of what gets rendered.
public struct VibeParameters: Codable, Equatable, Sendable, Hashable {

    /// Four families this build knows. A later build adds a case at the end of this list and in
    /// `StoredNamesTests` in the same commit; a stored vibe with an unknown genre reads as `.chill`
    /// so an older song still opens.
    public enum Genre: String, Codable, CaseIterable, Sendable {
        case hipHop, chill, score, edm
    }

    /// How much drive the loop should carry, 0 (calm) … 1 (intense). The pattern generator maps
    /// it to velocity floor, pattern complexity and the presence of accent hits.
    public var energy: Double

    /// How full the loop should feel, 0 (sparse) … 1 (busy). Maps to the fraction of grid steps
    /// that carry a note and to the layering of ornament voices.
    public var density: Double

    /// Timbral brightness, 0 (dark) … 1 (bright). The pattern generator does not render sound; it
    /// writes brightness into a per-note hint that a later layer (W11.2 UI, W11.3 engine binding)
    /// turns into filter cutoff or sample choice.
    public var brightness: Double

    public var genre: Genre

    /// The master tempo the loop should land on, in beats per minute. The generator does not run
    /// time-stretch; it writes notes against this tempo and the `MatchEngine` (W11.3) applies it
    /// to imported audio.
    public var targetBPM: Double

    /// The tonic the generator uses to spell notes, 0 = C … 11 = B. A song's `MusicalContext.root`
    /// is the usual source; a Loop-Generator request may override it for one bar.
    public var targetKeyRoot: Int

    /// The scale the generator stays in. Defaults to `.minor` for Hip Hop/Trap, `.minorPentatonic`
    /// for Chill and EDM, `.dorian` for Score — see `VibeMatrix` for the preset defaults.
    public var targetScale: Scale

    public init(genre: Genre,
                energy: Double,
                density: Double,
                brightness: Double,
                targetBPM: Double,
                targetKeyRoot: Int,
                targetScale: Scale) {
        self.genre = genre
        self.energy = Self.unit(energy)
        self.density = Self.unit(density)
        self.brightness = Self.unit(brightness)
        self.targetBPM = Self.bpm(targetBPM)
        self.targetKeyRoot = Self.pitchClass(targetKeyRoot)
        self.targetScale = targetScale
    }

    /// The deterministic seed a pattern generator uses when none is given. The same parameters
    /// always hash to the same value — so a saved vibe always recreates the same default pattern,
    /// and a Loop-Generator request without an explicit seed is still reproducible.
    public var defaultSeed: UInt64 {
        var hasher = Hasher()
        hasher.combine("echoel.vibe.v1")
        hasher.combine(genre.rawValue)
        hasher.combine(Int((energy * 1000).rounded()))
        hasher.combine(Int((density * 1000).rounded()))
        hasher.combine(Int((brightness * 1000).rounded()))
        hasher.combine(Int((targetBPM * 100).rounded()))
        hasher.combine(targetKeyRoot)
        hasher.combine(targetScale.rawValue)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    // MARK: - Door

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, value))
    }

    private static func bpm(_ value: Double) -> Double {
        guard value.isFinite else { return 90 }
        return Swift.min(240, Swift.max(40, value))
    }

    private static func pitchClass(_ value: Int) -> Int {
        let modulo = value % 12
        return modulo < 0 ? modulo + 12 : modulo
    }
}

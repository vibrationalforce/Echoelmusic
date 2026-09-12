//
//  GenreIdiom.swift
//  Echoelmusic — Sequencer
//
//  "ES SOLL NIE GLEICH KLINGEN ABER TROTZDEM SEHR MUSIKALISCH UND AUTHENTISCH" (founder
//  2026-09-11). This is the second half of that sentence's machinery: `PadGrammar` (G2) gave a
//  genre ONE authored figure, fixed for every take. This type says WHICH legal option a given
//  take reaches for INSIDE that genre — and, just as importantly, how narrow the set of legal
//  options is, so a variation is a different performance of the same piece rather than a
//  different piece.
//
//  ⛔ DIAGNOSIS FIRST, measured before this was written (§3 of `PLAN_GENRE_WELT_2026-09-11.md`),
//  because the obvious reading of "it always sounds the same" is wrong. RANDOMNESS IS NOT WHAT
//  IS MISSING: `structureSeed = override ?? bioSeed(frame)` already differs on almost every
//  Generate with a live body. What is thin is AUTHORED MATERIAL. The Studio path passes
//  `suggestJourney: true`, so `composeHarmonic` takes the `if let sc = suggest` branch and the
//  three `structureRNG` draws in its `else` are never consumed; the lead block that holds
//  another is asleep (`leadDensity == 0` everywhere, `LeadRoleAbsenceTests`). What is left to
//  separate two takes is the journey pick, the inversion and the velocity jitter — and every
//  `sustained` genre shares ONE onset producer. More entropy would make the take WORSE. What is
//  needed is breadth of legal movement, and that is what an envelope is.
//
//  THE ENVELOPE IS THE DIFFERENCE BETWEEN "VARIES" AND "DRIFTS AWAY". Each genre that claims an
//  idiom also states the FINITE set it may move within: which rotations of its OWN progression
//  are legal entry points, how far the register may lean, which authored cells it may choose
//  between. Nothing is generated; everything is selected from a list a human wrote. That is why
//  `TheVariationEnvelopesNeverCollideTests` can enumerate the full hull of every offered genre
//  and assert that no realised variant lands on another genre's identity — a property no amount
//  of seeding could give us.
//
//  ⭐ THE CALM BODY GETS THE CANONICAL OPTION. `amount = max(varyFloor, 1 - coherence)`, so a
//  settled player hears the genre's own first answer and an unsettled one hears the breadth.
//  This is the SAME polarity as `genreAnchorCount` (floor 0.34, full by coherence 0.7) and for
//  the same reason (#81/#125, founder: "erst eine individuelle Variation und dann klingt
//  plötzlich alles gleich"): the settling body is the state in which a listener judges whether
//  the genre is itself. Variation NARROWS as the body settles; it never inverts.
//
//  ⚠️ THREE FIELDS ARE FORBIDDEN TO A VARIANT, and the guard pins that negatively:
//  `arpeggiated`, `sustained`, `leadDensity`. The first two are what make a Fläche a Fläche —
//  a variant that flips either has changed the genre, not performed it. The third would wake the
//  five sleeping lead paths `LeadRoleAbsenceTests` keeps asleep. An envelope carries roots,
//  register and cells; it can never reach a `HarmonicProfile` field.
//
//  ⚠️ THE TABLE IS EMPTY IN THIS SLICE, ON PURPOSE (G3a) — the `PadGrammar` precedent, and for
//  the same reason: the mechanism ships in a commit that provably changes no sound, so the
//  byte-identity is a measurement rather than an argument inside a commit that also changes how
//  a genre sounds. The set empties over G5…G15.
//
//  NO RNG OF ITS OWN, and that is a hard requirement rather than a style: every selection below
//  is a hash of the take's seed. A draw here would shift `rng`/`structureRNG` for every later
//  note in the take and change note IDENTITIES (`nextUUID`), which is what
//  `TheIdiomVariationDrawsNoRNGTests` measures by comparing UUID SEQUENCES, not just counts.
//
//  Pure Foundation value types, no audio, no SwiftUI — assertable in CI. Whether a variant is
//  MUSICAL is a device question.
//

import Foundation

/// How a genre is allowed to differ from take to take, while staying itself.
public enum GenreIdiom: String, CaseIterable, Sendable, Codable {
    /// No movement at all — the take is the canonical one, every time. NOT the absence of an
    /// idiom: `deepDrone` and the chant families get this ON PURPOSE, because unmovingness IS
    /// their quality. `nil` means "not yet decided"; `.fixed` means "decided: it does not move".
    case fixed
    /// The entry point into the genre's OWN progression rotates (maqām/makam sayr: the line
    /// travels to a fourth or a fifth and returns). Roots only — never a borrowed chromatic.
    case modalDrift
    /// Two interlocking parts lean by an octave against each other (the gamelan kotekan shape).
    /// Register only; the pitch classes are untouched.
    case registerInterlock
    /// Ascending and descending forms differ, and a permitted degree may be omitted on one of
    /// them (the rāga ārohana/avarohana shape, varjya from a per-scale legal set).
    case ascentDescent
    /// Silence is material: onsets are OMITTED from the authored figure rather than added to it.
    /// Named for the Japanese aesthetic term for the charged interval between sounds; it is a
    /// musical technique here, nothing else.
    case maSpacing
    /// Two authored cells alternate as statement and answer.
    case callResponse
}

/// The FINITE set of legal movement for one genre. Everything a variant may do is in here.
public struct VariationEnvelope: Equatable, Sendable {
    /// Legal rotations of the genre's OWN progression, as offsets. `[0]` = the genre always
    /// enters on its own first chord. The anchored roots still come only from the genre's
    /// progression (#77/#81/#125 untouched) — the take ENTERS it at another legal place.
    public let rootOffsets: [Int]
    /// How far the register may lean, in octaves. `0...0` = not at all.
    public let registerDrift: ClosedRange<Int>
    /// Indices of the authored cells this genre may choose between. `[0]` = one cell, no choice.
    public let cellChoices: [Int]

    public init(rootOffsets: [Int], registerDrift: ClosedRange<Int>, cellChoices: [Int]) {
        self.rootOffsets = rootOffsets.isEmpty ? [0] : rootOffsets
        self.registerDrift = registerDrift
        self.cellChoices = cellChoices.isEmpty ? [0] : cellChoices
    }

    /// The envelope that permits nothing — every selection below returns the canonical option.
    public static let still = VariationEnvelope(rootOffsets: [0], registerDrift: 0...0,
                                                cellChoices: [0])
}

/// What a genre owns on this axis: its idiom and the envelope it moves inside.
public struct GenreIdiomProfile: Equatable, Sendable {
    public let idiom: GenreIdiom
    public let envelope: VariationEnvelope

    public init(idiom: GenreIdiom, envelope: VariationEnvelope) {
        self.idiom = idiom
        self.envelope = envelope
    }
}

/// One take's resolved position inside its genre's envelope. Built once per compose, read by
/// the four hooks; carries no mutable state and draws no RNG.
public struct IdiomControl: Equatable, Sendable {
    public let idiom: GenreIdiom
    public let envelope: VariationEnvelope
    /// Derived from the take's skeleton seed WITHOUT consuming either compose RNG stream — the
    /// `chordSeed` pattern in `composeHarmonic`, for exactly the same reason.
    public let seed: UInt64
    /// 0 = the canonical option, 1 = the whole envelope. Never negative, never above 1.
    public let amount: Float

    public init(idiom: GenreIdiom, envelope: VariationEnvelope, seed: UInt64, amount: Float) {
        self.idiom = idiom
        self.envelope = envelope
        self.seed = seed
        self.amount = amount.isFinite ? Swift.min(Swift.max(amount, 0), 1) : 0
    }

    /// The control that moves nothing. `amount == 0` resolves to this behaviourally.
    public static let neutral = IdiomControl(idiom: .fixed, envelope: .still, seed: 0, amount: 0)

    // MARK: - Selection

    /// SplitMix64 finaliser. A hash, not a generator: the same seed and channel always give the
    /// same answer, and asking one channel never moves another.
    private static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Pick from `options` inside the window `amount` opens. `.fixed`, an empty window and
    /// `amount == 0` all land on `options[0]` — the genre's own canonical answer.
    ///
    /// ⚠️ THE WINDOW IS A PREFIX, and that is the design: the options are written in the
    /// genre's own order of canonicity, so widening the window ADDS the less obvious answers
    /// without ever removing the obvious one. A window that moved instead of grew would make a
    /// calm body hear one variant and a slightly calmer body hear a different one.
    private func pick(_ options: [Int], channel: UInt64) -> Int {
        guard let first = options.first else { return 0 }
        guard idiom != .fixed, amount > 0, options.count > 1 else { return first }
        let span = Swift.max(1, Swift.min(options.count,
                                          Int((Float(options.count) * amount).rounded(.up))))
        let idx = Int(Self.mix(seed &+ channel) % UInt64(span))
        return options[idx]
    }

    /// Which legal entry point into the genre's own progression this take uses.
    public var rootOffset: Int { pick(envelope.rootOffsets, channel: 0x1) }

    /// How far this take leans in register, in octaves, inside the envelope's range.
    public var registerOffset: Int {
        let lo = envelope.registerDrift.lowerBound
        let hi = envelope.registerDrift.upperBound
        guard lo != hi else { return lo }
        return pick(Array(lo...hi), channel: 0x2)
    }

    /// Which authored cell this take plays.
    public var cellIndex: Int { pick(envelope.cellChoices, channel: 0x3) }
}


public extension MusicStyle {
    /// The idiom and envelope this genre owns, or `nil` = it does not vary, byte-identically.
    ///
    /// ⚠️ EVERY GENRE IS `nil` TODAY and the switch is written out rather than collapsed to a
    /// bare `return nil`, so that G5…G15 add an arm instead of rediscovering where the table
    /// lives. Opt-in by design, so `default:` is the honest arm here and NOT the exhaustiveness
    /// dodge the rest of `MusicStyle` avoids: a genre that has not been given an envelope plays
    /// the one take it always played.
    var idiomProfile: GenreIdiomProfile? {
        switch self {
        default: return nil
        }
    }
}

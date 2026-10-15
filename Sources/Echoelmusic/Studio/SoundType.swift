// SoundType.swift
// Echoel — the sound list's Type column and filter (founder 2026-10-15, after the Analog Console
// preset browser: Name · Type · favourite). A patch's type is DERIVED from its own parameters, never
// stored: no field on `SynthPatch`, no schema change, and a user patch is classified by what it is
// now. The rules are an ear decision and therefore named here, in one place; the guard
// `TheSoundListShowsItsTypeTests` pins every factory sound to its type, so a re-tuning is a visible
// diff. "Arp" is left out on purpose: an arpeggio is a note pattern, not a property of a patch.

import Foundation

/// What kind of sound a patch is, derived from its parameters.
public enum SoundType: String, CaseIterable, Sendable {
    case pad, lead, bass, keys, pluck, bell, orchestral

    public var label: String {
        switch self {
        case .pad:        return String(localized: "Pad")
        case .lead:       return String(localized: "Lead")
        case .bass:       return String(localized: "Bass")
        case .keys:       return String(localized: "Keys")
        case .pluck:      return String(localized: "Pluck")
        case .bell:       return String(localized: "Bell")
        case .orchestral: return String(localized: "Orchestral")
        }
    }

    /// The instrument timbres a patch can blend toward — a literal mirror of
    /// `EchoelDDSP.InstrumentTimbre` (which sits behind `canImport(Accelerate)`); the guard pins the
    /// two sets as equal.
    static let orchestralTimbres: Set<String> = ["violin", "flute", "trumpet", "cello", "clarinet", "oboe"]

    /// The first rule that matches wins. A non-finite field fails every comparison and falls
    /// through to `.lead`.
    public static func of(_ p: SynthPatch) -> SoundType {
        if orchestralTimbres.contains(p.timbreProfile.lowercased()) && p.timbreBlend >= 0.5 { return .orchestral }
        if p.attack >= 0.1 { return .pad }
        if p.filterCutoff <= 1000 { return .bass }
        if p.sustain <= 0.05 { return .pluck }
        let shape = p.spectralShape.lowercased()
        if shape == "bell" || shape == "metallic" { return .bell }
        if p.decay >= 0.5 && p.sustain <= 0.55 { return .keys }
        if p.release >= 1.2 && p.brightness < 0.5 { return .pad }
        return .lead
    }
}

/// The sound list's filter — per-view state, never persisted.
public enum SoundFilter: Hashable, Sendable {
    case all
    case favorites
    case type(SoundType)

    public static var choices: [SoundFilter] { [.all, .favorites] + SoundType.allCases.map { .type($0) } }

    public var label: String {
        switch self {
        case .all:            return String(localized: "All")
        case .favorites:      return String(localized: "Favorites")
        case .type(let type): return type.label
        }
    }

    public func admits(_ patch: SynthPatch, favorite: Bool) -> Bool {
        switch self {
        case .all:            return true
        case .favorites:      return favorite
        case .type(let type): return SoundType.of(patch) == type
        }
    }
}

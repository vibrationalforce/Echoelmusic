import Foundation

// OutputStatusWord.swift
// Echoelmusic — Studio (interface audit 2026-09-30: "Status-Leiter in Wörtern … an Puls und
// Ausgabe"). This is the OUTPUT half; the pulse half is `Bio/PulseLadder.swift`.
//
// WHY. The audit's finding — "Status ist Farbe oder Zahl, nie ein Satz" — held for the two output
// tiles in the head as much as for the pulse pill: the visual monitor was a dim sparkle glyph, a
// pulsing colour, or a small TV glyph; the light monitor a dim bulb or a colour. Each state had a
// PICTURE and no word, and the words existed only for VoiceOver ("Live", "Idle", "On external
// screen", "Sending to fixtures", "No light route"), typed inline in the view. A sighted player
// who does not know the glyph grammar saw a bulb and could not tell "light output off" from
// "light output idle"; a colour-blind one saw a tile. These two types name the rungs ONCE, and the
// tile renders `word` while VoiceOver reads `spoken` from the SAME rung (#416 — the old inline
// strings were a second definition of the state the picture already implied).
//
// THE PICTURE STAYS THE PICTURE. A rung whose tile IS the live output (the visual's own chord
// colour, the exact colour the DMX mapping sends) has `word == nil`: a word over a live colour is
// a contrast that changes every beat, the first thing the contrast guard (the audit's next line)
// would have to catch. The doc's "die Zahl bleibt daneben" has the same shape — the number is
// the pulse's picture and the word joins it only when there is room. Here there is none: the two
// tiles are 54 × 32 and 38 × 32 pt, founder-named reference sizes pinned by
// `OneChromeControlHeightTests`.
//
// PURE. Foundation only, no view, no bridge, no router: `rung(...)` is a total function of the
// booleans the tiles already compute, so the truth table is unit-tested and transcribable (§0).

/// The one measure both tiles share: how long a visible word may be. The light tile is 38 pt wide
/// and its glyph takes 11 of them, so a word longer than this shrinks below legibility before it
/// truncates. "Screen" is the longest word in use and sets the number.
public enum OutputStatusWord {
    public static let maxLength = 6
}

/// The visual monitor's three rungs — WHERE the picture is.
public enum VisualMonitorRung: Equatable, CaseIterable, Sendable {
    /// A second screen is connected AND wired: the picture left the phone (`ExternalStageBridge`).
    case externalScreen
    /// The body drives the visual: the tile shows the visual's own colour, no word.
    case live
    /// Nothing drives it yet.
    case idle

    /// External wins over live: a projector that has the picture is the fact the performer
    /// needs, whether or not a pulse is running behind them.
    public static func rung(onExternalScreen: Bool, active: Bool) -> VisualMonitorRung {
        if onExternalScreen { return .externalScreen }
        return active ? .live : .idle
    }

    /// The visible word beside the glyph — nil where the tile shows the picture itself.
    public var word: String? {
        switch self {
        case .externalScreen: return "Screen"
        case .live: return nil
        case .idle: return "Idle"
        }
    }

    /// What VoiceOver reads as the tile's value.
    public var spoken: String {
        switch self {
        case .externalScreen: return "On external screen"
        case .live: return "Live"
        case .idle: return "Idle"
        }
    }
}

/// The light monitor's two rungs — whether a DMX route is armed.
public enum LightMonitorRung: Equatable, CaseIterable, Sendable {
    /// An enabled route reaches `artnet.out` or `sacn.out`: the tile shows the colour the
    /// fixtures receive, no word.
    case sending
    /// No enabled light route: light output is off.
    case noRoute

    public static func rung(routeEnabled: Bool) -> LightMonitorRung {
        routeEnabled ? .sending : .noRoute
    }

    /// The visible word beside the bulb — nil while the colour is the status.
    public var word: String? {
        switch self {
        case .sending: return nil
        case .noRoute: return "Off"
        }
    }

    /// What VoiceOver reads as the tile's value.
    public var spoken: String {
        switch self {
        case .sending: return "Sending to fixtures"
        case .noRoute: return "No light route"
        }
    }
}

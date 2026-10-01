// SkillLevel.swift
// Echoel — "for everyone, from noob to pro." One progressive-disclosure dial that
// keeps the default UI minimal (the core USP: heartbeat → music → meditate/export)
// and reveals depth as the producer wants it. Nothing is ever removed — higher
// levels only ADD surfaces. Pure value type, fully unit-tested.
//
// ⭐ ITS FIRST CONSUMER (interface audit 2026-09-30, "SkillLevel anschließen: Einsteiger =
// drei Chips"): the Instrument stage's chip strip, `EchoelStudioView.chips(for:)`. Until then
// this type had ZERO readers — "nichts ändert sich, wenn man es umstellt". The two gates
// below keep their names from a tab plan that never shipped (Songs · Sessions · Connect);
// what they GATE today is written at each one. ⛔ The level is the USER's choice, persisted
// under `StudioDefaultKeys.skillLevel`, and its default is `.pro`: a fresh install sees the
// whole strip. The one time the strip was thinned WITHOUT a choice (a first-run filter,
// #568) the founder rejected it on device — "Du hast mega viel gelöscht" (#572). Beginner
// is something you pick, never a first impression.

import Foundation

/// How much of the studio is on screen. Each level is a superset of the previous.
public enum SkillLevel: String, CaseIterable, Sendable, Identifiable, Comparable {
    /// Essentials only — the three chips the head does not already carry: Sound · Mood ·
    /// Save/Export (the pulse pill and the visual tile sit in the head at every level).
    case beginner
    /// Adds the shaping and song-building chips — FX · Mix · Tempo · Field · Workstation.
    case producer
    /// Adds Master — the whole strip, today's default.
    case pro

    public var id: String { rawValue }

    /// Sort order for `Comparable` (beginner < producer < pro).
    private var rank: Int {
        switch self {
        case .beginner: return 0
        case .producer: return 1
        case .pro:      return 2
        }
    }

    public static func < (lhs: SkillLevel, rhs: SkillLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var displayName: String {
        switch self {
        case .beginner: return String(localized: "Beginner")
        case .producer: return String(localized: "Producer")
        case .pro:      return String(localized: "Pro")
        }
    }

    /// One-line description for the picker.
    public var blurb: String {
        switch self {
        case .beginner: return String(localized: "Just the essentials — Sound, Mood, Save & Export.")
        case .producer: return String(localized: "Adds FX, Mix, Tempo, Field and the Workstation.")
        case .pro:      return String(localized: "Adds Master — the whole strip.")
        }
    }

    // MARK: - Surface gates (each higher level a superset)

    /// From Producer up. The NAME dates from the Songs tab that never shipped; what it gates
    /// today is the shaping and song-building chips of the Instrument strip — FX · Mix ·
    /// Tempo · Field · Workstation (`EchoelStudioView.chips(for:)`).
    public var showsSongs: Bool { self >= .producer }

    /// Pro only. The NAME dates from the Sessions/Connect tabs that never shipped; what it
    /// gates today is the Master chip (`EchoelStudioView.chips(for:)`).
    public var showsProTabs: Bool { self >= .pro }
}

import Foundation

// PulseLadder.swift
// Echoelmusic — Bio (interface audit 2026-09-30: "Status-Leiter in Wörtern — Suche · fast · da ·
// verloren; die Zahl bleibt daneben").
//
// WHY. The audit's finding, confirmed against the pulse pill: "Status ist Farbe oder Zahl, nie
// ein Satz". While the camera was still finding a pulse the pill's value slot showed "—" (the
// `.finding` cue is deliberately not actionable, so `showCue` is false), then a number in accent
// green, and after a lock dropped "—" again — one glyph for "not started", "nearly there" and
// "gone". The trace's COLOUR carried the difference, and colour is the one channel a glance at a
// phone in daylight, a colour-blind performer or VoiceOver cannot read. This type names the four
// rungs in plain words; the number stays beside the word.
//
// PURE. Foundation only, no view, no publisher: `step(...)` is a total function of four facts
// `CameraRPPGBioPublisher` already exposes, so it is unit-tested end-to-end and transcribable
// (§0). The camera is the ONLY source with a confidence; strap, HealthKit and the simulator keep
// their own words (`strapStatus`, "Demo") and pass no ladder.
//
// NOT A COACHING CUE. `PulseCue` says what to DO with the finger and wins the slot whenever it is
// actionable (`showCue`); the ladder says WHERE the search stands and fills the slot only when no
// remedy is due. "Lost" + "Cover lens" would be two words for one moment — the remedy is the one
// the performer needs, so the pill shows it alone.

/// The four rungs, in the order a take climbs them.
public enum PulseLadderStep: String, CaseIterable, Equatable, Sendable {
    /// No lock yet, confidence below halfway to the gate — the normal first seconds.
    case searching
    /// No lock yet, but at least halfway to the gate: keep still, it is coming.
    case nearly
    /// Locked — a real pulse is on the wire; the number beside the word is it.
    case found
    /// Locked earlier in THIS take, not locked now, frames still flowing: the finger moved,
    /// the light changed, or the grip loosened. Different from `.searching` on purpose — a
    /// performer who HAD a pulse and reads "Searching" thinks the app forgot; "Lost" says what
    /// happened and that it can be had back.
    case lost

    /// The word in the pill's value slot. ≤ 12 characters — the slot law
    /// `AStalledAcquisitionSaysSoTests` states for every short label that shares it.
    public var word: String {
        switch self {
        case .searching: return String(localized: "Searching")
        case .nearly:    return String(localized: "Almost")
        case .found:     return String(localized: "Found")
        case .lost:      return String(localized: "Lost")
        }
    }

    /// The sentence VoiceOver reads for the three rungs that have no number to read. `.found`
    /// is spoken as the BPM sentence itself (`PulseMonitorMini.accessibilityText`); its line
    /// here is the fallback for a lock with no displayable number, which `shouldPublish`
    /// forbids — stated rather than trapped.
    public var spoken: String {
        switch self {
        case .searching: return String(localized: "Searching for your pulse")
        case .nearly:    return String(localized: "Almost there — keep your finger still")
        case .found:     return String(localized: "Pulse found")
        case .lost:      return String(localized: "Pulse lost — keep your finger still")
        }
    }
}

public enum PulseLadder {
    /// "Almost" begins halfway to the lock gate: `confidence >= lockThreshold * nearlyShare`.
    /// `confidence` is the publisher's 0…1 lock PROGRESS and `lockThreshold` (0.35 today,
    /// `CameraRPPGBioPublisher.lockThreshold`) is where a trustworthy reading may publish, so
    /// half of it is the honest "more than half way there". A share, not an absolute, so the
    /// rung moves if the gate ever moves (#416). The FEEL of the boundary is a device fact —
    /// NEEDS-FOUNDER-VERIFY: place a finger, watch "Searching" become "Almost" before the number.
    public static let nearlyShare = 0.5

    /// The rung for one tick of the camera source.
    /// - locked:        `CameraRPPGBioPublisher.isLocked` (frames flowing AND a trustworthy reading).
    /// - confidence:    the publisher's 0…1 lock progress.
    /// - lockSeen:      `lockSeenThisTake` — a lock happened earlier in this take.
    /// - lockThreshold: the publisher's lock gate.
    /// Non-finite or non-positive inputs read as `.searching` — the NaN law: nothing here
    /// traps, and a broken number never claims a rung above the bottom one.
    public static func step(locked: Bool, confidence: Double, lockSeen: Bool,
                            lockThreshold: Double) -> PulseLadderStep {
        if locked { return .found }
        if lockSeen { return .lost }
        guard confidence.isFinite, lockThreshold.isFinite, lockThreshold > 0 else { return .searching }
        return confidence >= lockThreshold * nearlyShare ? .nearly : .searching
    }
}

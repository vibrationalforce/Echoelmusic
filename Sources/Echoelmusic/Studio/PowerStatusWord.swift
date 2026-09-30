// PowerStatusWord.swift
// Echoelmusic — Studio (interface audit 2026-09-30, Zug 3: "Status-Leiter in Worten für jeden
// Hardware-Pfad … Sparmodus"). The last of the six paths: the quality governor. Siblings:
// `OutputStatusWord.swift` (tiles), `Bio/PulseLadder.swift` (pulse), `AudioRouteStatusWord.swift`
// (route), `Bio/HealthSourceStatus.swift` (wrist), `MIDIStatusWord.swift` (cable). Read by the
// Field panel's "Power" row (`EchoelStudioView.PowerStatusRow`).
//
// WHY. `ResourceGovernor` has stepped visual detail and the bio→OSC rate down on heat, Low Power
// Mode, a low battery and dropped frames since 2026-06-23 — silently. A performer whose field
// went coarse mid-set had no sentence telling them the phone is hot rather than the app broken,
// and nothing to do about it. `AdaptiveQuality.pressure(…)` now names the one condition holding
// the tier down; this file gives that condition and the tier their words.
//
// WHAT THE WORDS MAY CLAIM, measured, not assumed: the tier drives `visualDetailScale`
// (`MetalBioView`, `TheDrawableFollowsTheTierTests`) and the bio egress ceiling
// (`PollingRateCeiling.setBioHz`). It does NOT drive the frame rate — `MetalBioView` pins
// `preferredFramesPerSecond = 60` — so the Full caption says so, and no rung promises a frame
// rate. `.balanced` and `.high` differ only in the bio ceiling, so both read as Full.
//
// PURE. Foundation only; internal on purpose (the blocking bundle reaches it via `@testable`).

import Foundation

/// The governor's tier in a person's words.
enum PowerRung: Equatable, CaseIterable, Sendable {
    case full
    case reduced
    case saving

    static func rung(tier: QualityTier) -> PowerRung {
        switch tier {
        case .high, .balanced: return .full
        case .low: return .reduced
        case .minimal: return .saving
        }
    }

    var word: String {
        switch self {
        case .full: return String(localized: "Full")
        case .reduced: return String(localized: "Reduced")
        case .saving: return String(localized: "Saving")
        }
    }

    /// The row's text: the word, then the cause while anything is held back.
    func line(pressure: QualityPressure) -> String {
        switch self {
        case .full: return word + String(localized: " · detail and bio stream at full rate")
        case .reduced, .saving: return word + " · " + pressure.cause
        }
    }

    /// The remedy beneath the line — the cause's own, or what the governor does on its own.
    func caption(pressure: QualityPressure) -> String {
        switch self {
        case .full:
            return String(localized: "Visual detail steps down on its own when the phone gets hot or the battery runs low, and comes back when it can. The frame rate stays at 60.")
        case .reduced, .saving:
            return pressure.remedy
        }
    }

    func spoken(pressure: QualityPressure) -> String {
        switch self {
        case .full: return String(localized: "Power full, detail and bio stream at full rate")
        case .reduced: return String(localized: "Power reduced, ") + pressure.cause
        case .saving: return String(localized: "Power saving, ") + pressure.cause
        }
    }
}

extension QualityPressure {
    /// What is holding the tier down, as the tail of a sentence.
    var cause: String {
        switch self {
        case .none: return String(localized: "nothing is holding it back")
        case .thermal: return String(localized: "the phone is hot")
        case .lowPowerMode: return String(localized: "Low Power Mode is on")
        case .battery: return String(localized: "the battery is low")
        case .frameRate: return String(localized: "frames were dropping")
        }
    }

    /// What a person can do — or, where they cannot, what the governor will do.
    var remedy: String {
        switch self {
        case .none: return String(localized: "Nothing is held back.")
        case .thermal: return String(localized: "Visual detail is stepped down so the phone can cool. It comes back when the phone has cooled.")
        case .lowPowerMode: return String(localized: "Turn Low Power Mode off in Settings › Battery for full detail.")
        case .battery: return String(localized: "Charge the phone. Full detail returns as the battery fills.")
        case .frameRate: return String(localized: "The visual dropped frames, so detail stepped down for a while. It comes back when frames hold.")
        }
    }
}

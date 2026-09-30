import Foundation

// AudioRouteStatusWord.swift
// Echoelmusic — Studio (interface audit 2026-09-30, Zug 3: "Status-Leiter in Worten für jeden
// Hardware-Pfad … zuerst Audio-Route"). The output tiles' ladder is `OutputStatusWord.swift`, the
// pulse's is `Bio/PulseLadder.swift`; this is the AUDIO ROUTE's, read by the master panel's
// "Audio route" row (`EchoelStudioView.AudioRouteRow`).
//
// WHY. The panel had a buffer tier and a timing tally and no sentence about WHERE the sound goes.
// The one sentence that decides a Bluetooth evening — call mode is mono and band-limited, the
// music too — existed in `AudioConfiguration.RouteCodec.note` and reached no screen. Three rungs,
// named once; the row renders `line`, VoiceOver reads `spoken`, and the remedy beneath the line
// is `RouteCodec.note` itself (one definition of that sentence, #416).
//
// ACCESS. Internal, not `public`, on purpose: `AudioConfiguration.RouteCodec` is internal, and a
// public function cannot take an internal parameter type (the CLAUDE.md build-error table's
// "public let foo: InternalType" row). The blocking bundle reaches it via `@testable import`.
//
// PURE. Foundation only: `rung(...)` is a total function of two facts the row already has, so the
// truth table is unit-tested and transcribable (§0 of `Tests/CISmoke/CLAUDE.md`).

/// Where the sound goes, in a word.
enum AudioRouteRung: Equatable, CaseIterable, Sendable {
    /// The engine is not running: nothing plays yet, whatever the route.
    case off
    /// Running on a full-bandwidth route.
    case playing
    /// Running while Bluetooth is in call mode (named by iOS, or inferred from the rate): mono,
    /// band-limited — the music too. `RouteCodec.note` carries the remedy.
    case callMode

    /// Off wins over everything: a call-mode route with nothing playing is a fact for later, not
    /// a warning now.
    static func rung(isRunning: Bool, codec: AudioConfiguration.RouteCodec) -> AudioRouteRung {
        guard isRunning else { return .off }
        switch codec {
        case .wideband: return .playing
        case .telephony, .telephonySuspected: return .callMode
        }
    }

    /// The visible word at the head of the line.
    var word: String {
        switch self {
        case .off: return String(localized: "Off")
        case .playing: return String(localized: "Playing")
        case .callMode: return String(localized: "Call mode")
        }
    }

    /// The whole value line: word · output ports · the route's delay floor. Off says only that
    /// nothing plays — the floor of a route nobody hears is a number without a use.
    func line(outputs: String, floorText: String) -> String {
        switch self {
        case .off: return word + String(localized: " · nothing plays yet")
        case .playing, .callMode: return word + " · " + outputs + " · " + floorText
        }
    }

    /// What VoiceOver reads as the row's value.
    func spoken(outputs: String) -> String {
        switch self {
        case .off: return String(localized: "Off, nothing plays yet")
        case .playing: return String(localized: "Playing over ") + outputs
        case .callMode: return String(localized: "Call mode over ") + outputs + String(localized: ", mono and band-limited")
        }
    }

    /// The dim sentence under the line when the route has nothing to warn about.
    static let caption = String(localized: "Where the sound goes and the delay this route adds. Changes with headphones, Bluetooth and the speaker.")
}

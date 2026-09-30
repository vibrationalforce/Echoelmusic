import Foundation
#if canImport(Observation)
import Observation
#endif

// HealthSourceStatus.swift
// Echoelmusic — Bio (interface audit 2026-09-30, Zug 3: "Status-Leiter in Worten für jeden
// Hardware-Pfad … Apple Health"). The output tiles' ladder is `Studio/OutputStatusWord.swift`,
// the pulse's `PulseLadder.swift`, the audio route's `Studio/AudioRouteStatusWord.swift`, the
// network dot's `NetworkSendState`. This is APPLE HEALTH's: the wrist path, read by the bio
// panel's "Apple Health" row (`EchoelStudioView.HealthSourceStatusRow`), shown only while Health
// is the chosen source.
//
// WHY A SEPARATE STATUS OBJECT, and not a handle to the publisher. `HealthKitBioPublisher` is
// owned at APP level (#1319; `TheHealthSourceIsOwnedByTheAppTests`), and the Studio layer holds
// no code reference to it (`ThePickerDoesNotOwnEverySourceTests` claim 2) — so a second lifecycle
// owner cannot appear there by accident (BLE-3: a patchbay edit once killed a strap mid-
// performance). A status row must READ the publisher without being able to START or STOP it.
// This object is exactly that boundary: the publisher writes it, the app injects it, the row
// reads it. The two flags live HERE and the publisher's `isAuthorized`/`isPublishing` FORWARD to
// them — one definition (#416), never a mirror that can drift.
//
// ⚠️ WHAT "UNAVAILABLE" CAN AND CANNOT MEAN — measured in `EchoelBioEngine.requestAuthorization`,
// not assumed. Apple hides READ denial: `authorizationStatus(for:)` reports SHARING status, the
// app shares nothing, so after the sheet the status is `.notDetermined` and the engine returns
// `true` whether or not the person allowed reading. `couldNotStart` therefore flips only when
// HealthKit is absent on the device, a quantity type is missing, or the request THREW — never
// on a declined sheet. A declined sheet looks like SILENCE, which is why the `waiting` rung's
// caption carries the Health-app remedy and `unavailable` does not pretend to know more.

/// The read-only face of `HealthKitBioPublisher` for the Studio layer.
///
/// Written by the publisher alone (`internal(set)`), injected once by `EchoelmusicApp`
/// (`.environment(healthBio.status)`), read by `HealthSourceStatusRow`. Changes at the rate of a
/// start, a stop or a failed start — never per frame — so a leaf may read it freely.
@MainActor
@Observable
public final class HealthSourceStatus {

    /// Mirrors what `EchoelBioEngine.requestAuthorization()` returned — see the header for what
    /// that does NOT tell you about a declined sheet.
    public internal(set) var isAuthorized = false

    /// The poll loop is running and `publishIfFresh` is being asked every 500 ms.
    public internal(set) var isPublishing = false

    /// `start(publishing:)` reached its authorisation guard and could not pass it. Cleared by a
    /// later start that succeeds. NOT set by a declined read permission (header).
    public internal(set) var couldNotStart = false

    public init() {}
}

/// The four rungs of the Apple Health path, as words. Pure; the row derives it from the status
/// object and from whether the newest usable frame on the bus is the wrist's.
public enum HealthSourceRung: Equatable, CaseIterable, Sendable {
    /// Health is chosen but the publisher has not been started — the ask fires at the first Play.
    case off
    /// Publishing, but no usable wrist frame on the bus (at rest the Watch writes minutes apart;
    /// a declined read permission looks exactly like this — the caption says so).
    case waiting
    /// The newest usable frame on the bus is `.healthKit`.
    case receiving
    /// The publisher could not start: HealthKit absent, a type missing, or the request threw.
    case unavailable

    /// `couldNotStart` wins over everything — a failed start is a fact about THIS device, and
    /// `isPublishing` cannot be true beside it (the publisher clears it on the same success path
    /// that sets `isPublishing`). Then off before the loop runs; then the frame decides.
    public static func rung(isPublishing: Bool, couldNotStart: Bool,
                            wristFrameFresh: Bool) -> HealthSourceRung {
        if couldNotStart { return .unavailable }
        guard isPublishing else { return .off }
        return wristFrameFresh ? .receiving : .waiting
    }

    /// One word, for the eye.
    public var word: String {
        switch self {
        case .off:         return "Off"
        case .waiting:     return "Waiting"
        case .receiving:   return "Receiving"
        case .unavailable: return "Unavailable"
        }
    }

    /// The value cell: the word, a middle dot, a few words of what that means right now.
    public var line: String {
        switch self {
        case .off:         return word + " · starts with Play"
        case .waiting:     return word + " · no reading yet"
        case .receiving:   return word + " · your Watch"
        case .unavailable: return word + " · Health can't be opened"
        }
    }

    /// The dim line beneath: what to expect, or what to do. The remedy for a declined sheet
    /// sits on `waiting`, because that is where a declined sheet SHOWS UP (file header).
    public var caption: String {
        switch self {
        case .off:
            return "Apple Health starts with the music. Your Watch feeds heart rate in through "
                 + "Health, a few seconds behind the wrist."
        case .waiting:
            return "At rest the Watch writes minutes apart. If you declined Health access, allow "
                 + "it in the Health app under Privacy › Apps & Services."
        case .receiving:
            return "Heart rate from Apple Health, a few seconds behind the wrist. Coherence is "
                 + "not available from this source."
        case .unavailable:
            return "Apple Health could not be opened on this device. Choose another bio source — "
                 + "the camera light or a Bluetooth strap."
        }
    }

    /// What VoiceOver reads for the whole row.
    public var spoken: String {
        switch self {
        case .off:         return "Apple Health is off. It starts with Play"
        case .waiting:     return "Waiting for a reading from Apple Health"
        case .receiving:   return "Receiving heart rate from Apple Health, your Watch"
        case .unavailable: return "Apple Health is unavailable on this device"
        }
    }
}

// MIDIStatusWord.swift
// Echoelmusic — Studio (interface audit 2026-09-30, Zug 3: "Status-Leiter in Worten für jeden
// Hardware-Pfad … MIDI"). The output tiles' ladder is `OutputStatusWord.swift`, the pulse's is
// `Bio/PulseLadder.swift`, the audio route's `AudioRouteStatusWord.swift`, the wrist's
// `Bio/HealthSourceStatus.swift`. This is the MIDI CABLE's, both directions, read by the Routing
// surface's "MIDI" card (`PatchbayView` → `MIDIStatusRow`).
//
// WHY. Routing carried three switches for MIDI out and one for wireless MIDI, and not one word
// about what the cable is DOING: whether a controller is connected, whether notes arrive, whether
// the out port opened at all. `MIDIInput.isConnected`/`deviceName` had no reader in the Studio
// layer; `MIDIOutput.isReady` had none either — a port that failed to open (#837, `client create
// failed (-2)` after a SIGABRT) looked exactly like a port nobody had routed.
//
// TWO LADDERS, because the two directions fail differently. IN: No controller / Connected /
// Playing — "playing" is a fresh `MIDIBusPublisher.lastEventTimestamp`, the stamp the publisher
// writes on every event (an `@ObservationIgnored` field, so the row POLLS it on its own clock and
// never becomes a per-note observer). OUT: Off / On / Unavailable — Off is the route switch,
// Unavailable is `enabled && !isReady` (the port did not open; the app re-arms it on foreground
// return, `EchoelmusicApp` → `MIDIOutput.rearmIfDead()`).
//
// `playingWindow` is this ladder's own decision, not a copy of `NetworkSendState.freshnessWindow`:
// that one says when a network SENDER has gone quiet, this one says when a HAND has left the keys.
// They happen to agree today; if one moves, the other need not.
//
// PURE. Foundation only; every rung is a total function of facts the row already has, so the
// truth tables are unit-tested and transcribable (§0 of `Tests/CISmoke/CLAUDE.md`). Internal on
// purpose: the blocking bundle reaches it via `@testable import`.

import Foundation

/// The inbound cable: is a controller connected, and is a hand on it.
enum MIDIInRung: Equatable, CaseIterable, Sendable {
    case off
    case connected
    case playing

    /// How long after the last received event the row still says "Playing".
    static let playingWindow: TimeInterval = 3.0

    static func rung(sourceConnected: Bool, lastEvent: TimeInterval, now: TimeInterval) -> MIDIInRung {
        guard sourceConnected else { return .off }
        guard lastEvent > 0, now - lastEvent < playingWindow else { return .connected }
        return .playing
    }

    var word: String {
        switch self {
        case .off: return String(localized: "No controller")
        case .connected: return String(localized: "Connected")
        case .playing: return String(localized: "Playing")
        }
    }

    /// The row's text. `source` is the controller's name; only the connected rungs show it.
    func line(source: String) -> String {
        switch self {
        case .off: return word + String(localized: " · plug in or pair one")
        case .connected, .playing: return word + " · " + source
        }
    }

    var caption: String {
        switch self {
        case .off: return String(localized: "A USB or Bluetooth MIDI keyboard plays the synth directly.")
        case .connected: return String(localized: "Notes from the controller play the synth. None received yet.")
        case .playing: return String(localized: "Receiving notes from the controller.")
        }
    }

    func spoken(source: String) -> String {
        switch self {
        case .off: return String(localized: "No MIDI controller connected")
        case .connected: return String(localized: "Connected to ") + source + String(localized: ", no notes yet")
        case .playing: return String(localized: "Playing from ") + source
        }
    }
}

/// The outbound cable: is the route on, and did the port open.
enum MIDIOutRung: Equatable, CaseIterable, Sendable {
    case off
    case on
    case unavailable

    static func rung(enabled: Bool, isReady: Bool) -> MIDIOutRung {
        guard enabled else { return .off }
        return isReady ? .on : .unavailable
    }

    var word: String {
        switch self {
        case .off: return String(localized: "Off")
        case .on: return String(localized: "On")
        case .unavailable: return String(localized: "Unavailable")
        }
    }

    /// `destinations` is what `MIDIOutput.send` fans out to (hardware, other apps' inputs, a
    /// network peer); the "Echoelmusic" virtual SOURCE is offered regardless, so zero
    /// destinations is not silence — a host recording the source still hears every note.
    func line(destinations: Int) -> String {
        switch self {
        case .off: return word + String(localized: " · route MIDI out to send")
        case .on:
            switch destinations {
            case ..<1: return word + String(localized: " · offered as a source")
            case 1: return word + String(localized: " · source + 1 destination")
            default: return word + String(localized: " · source + ") + "\(destinations)" + String(localized: " destinations")
            }
        case .unavailable: return word + String(localized: " · the MIDI port did not open")
        }
    }

    var caption: String {
        switch self {
        case .off: return String(localized: "Switch the MIDI out route on in this Routing view. Nothing is sent while it is off.")
        case .on: return String(localized: "Hosts record the “Echoelmusic” source. Hardware and other apps receive as destinations.")
        case .unavailable: return String(localized: "CoreMIDI refused the port on this device. It is retried when the app returns to the front.")
        }
    }

    func spoken(destinations: Int) -> String {
        switch self {
        case .off: return String(localized: "MIDI out is off")
        case .on: return destinations < 1
            ? String(localized: "MIDI out is on, offered as a source")
            : String(localized: "MIDI out is on, source and ") + "\(destinations)"
              + (destinations == 1 ? String(localized: " destination") : String(localized: " destinations"))
        case .unavailable: return String(localized: "MIDI out is unavailable, the port did not open")
        }
    }
}

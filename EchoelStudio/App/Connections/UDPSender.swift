import Foundation
import Network
import Synchronization

/// The one place in Echoel Studio's Connections module that opens a socket (CLAUDE.md law 10;
/// `studio.yml`'s "Network only where named" lists this file and no other under Connections/).
/// One UDP connection to one host and port, unicast, plain text as every one of these protocols
/// is on the wire — opened when the musician switches a connection on and cancelled when they
/// switch it off, so a connection that is off has no socket at all. It sends what it is handed and
/// reports its state; it decides nothing about content, and never sees the body or the song.
///
/// Sends are bounded: at most `maximumInFlight` datagrams await the stack at any moment, and one
/// offered beyond that is dropped and counted rather than queued. The caller re-reads the state it
/// describes on its next tick, so the newest state always wins and a slow network never builds a
/// backlog of stale cues (the G-B contract's "bounded queue, drop or coalesce").
final class UDPSender: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case preparing
        case ready
        case waiting(String)
        case failed(String)
        case cancelled
    }

    /// What the stack has taken, refused or never seen, for the status line.
    struct Counters: Equatable, Sendable {
        var inFlight = 0
        var handedOver = 0
        var dropped = 0
        var failed = 0
    }

    /// Every track of a full song can say its position and its gain in one tick (32 tracks, two
    /// messages each) and still fit; anything past that waits for the next tick's fresh values.
    static let maximumInFlight = 64

    let host: String
    let port: UInt16
    /// Confined to `queue`: the connection is started there and every callback runs there.
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.connections", qos: .utility)
    private let counters = Mutex(Counters())

    /// Nil for an empty host or a port that is not one. `onState` is called on the sender's own
    /// queue, never on the main actor — the caller hops.
    init?(host: String, port: UInt16, onState: @escaping @Sendable (State) -> Void) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }
        self.host = trimmed
        self.port = port
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        connection = NWConnection(host: NWEndpoint.Host(trimmed), port: endpointPort, using: parameters)
        connection.stateUpdateHandler = { @Sendable state in
            switch state {
            case .setup, .preparing: onState(.preparing)
            case .ready: onState(.ready)
            case .waiting(let error): onState(.waiting(error.localizedDescription))
            case .failed(let error): onState(.failed(error.localizedDescription))
            case .cancelled: onState(.cancelled)
            @unknown default: break
            }
        }
        connection.start(queue: queue)
    }

    /// Hands one datagram to the stack. False when the bound was reached and it was dropped.
    @discardableResult
    func send(_ data: Data) -> Bool {
        let admitted = counters.withLock { (tally: inout Counters) -> Bool in
            guard tally.inFlight < Self.maximumInFlight else {
                tally.dropped += 1
                return false
            }
            tally.inFlight += 1
            return true
        }
        guard admitted else { return false }
        let tallies = counters
        connection.send(content: data, completion: .contentProcessed { @Sendable error in
            tallies.withLock { (tally: inout Counters) in
                tally.inFlight -= 1
                if error == nil { tally.handedOver += 1 } else { tally.failed += 1 }
            }
        })
        return true
    }

    var statistics: Counters { counters.withLock { $0 } }

    /// Closes the socket. The connection is gone for good; a new one is a new sender.
    func cancel() {
        connection.cancel()
    }
}

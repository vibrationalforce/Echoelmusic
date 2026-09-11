//
//  OSCReceiver.swift
//  Echoelmusic — Sync
//
//  #1255 (Grand Council 2026-09-10 step 4, ultraplan row 15): the app's FIRST inbound socket —
//  and deliberately a narrow one. A UDP `NWListener` that accepts a WHITELIST of control cues
//  under `/echoelmusic/ctrl/` (tempo while the BPM is locked · key · scale · genre · visual
//  look · blackout) so TouchDesigner, Resolume, QLab or a lighting console can SEND Echoel a
//  cue instead of only receiving its body. Off by default (`StudioDefaultKeys.oscInEnabled`),
//  with a sender allowlist by IP, because an open UDP port on a festival Wi-Fi is a different
//  consent from pointing an output somewhere (the `networkMIDI` argument, one protocol over).
//
//  ⛔ WHAT IS NOT ACCEPTED, stated where the socket lives:
//    · no bio value — `/echoelmusic/bio/*` is an OUTPUT namespace; a heart rate arriving from
//      the network would be a second, unmeasured body on the bus (#639's provenance flag exists
//      precisely so a rig can tell whose body it hears);
//    · no `play`/`stop` — a remote start would be a FOURTH session-start path, and
//      `OneStartControlTests` pins the count at three by founder decision (three asks for ONE
//      Start button). Whether a cue may start the session is his call, not a merge;
//    · `bpm` only under `.studioLocked` (T1/T2): the Flow tempo belongs to the body, and the
//      cue names itself `TempoSource.remoteControl` in the transport log;
//    · no bundles, blobs or timetags — a datagram that is not a plain message is ignored.
//
//  Every accepted datagram is ONE main-actor hop. That is the shape the 10.76.48 law forbids
//  for a 30 fps source and allows here: cues are sparse by nature, and the allowlist is the
//  defence against a hostile sender. Decoding and whitelist parsing are pure, nonisolated and
//  driven END-TO-END in `TheOSCControlInputIsAWhitelistTests` (including a loopback datagram).
//

import Foundation

// MARK: - OSC 1.0 decoding (the mirror of `OSCSender.encode`)

public enum OSCDecoder {

    public enum Argument: Equatable, Sendable {
        case float(Float)
        case int(Int32)
        case string(String)
        case bool(Bool)

        /// The numeric reading a control cue accepts: `f`, `i` and `T`/`F`; a string is not a number.
        public var number: Double? {
            switch self {
            case .float(let f): return Double(f)
            case .int(let i):   return Double(i)
            case .bool(let b):  return b ? 1 : 0
            case .string:       return nil
            }
        }
    }

    public struct Message: Equatable, Sendable {
        public let address: String
        public let arguments: [Argument]
        public init(address: String, arguments: [Argument]) {
            self.address = address; self.arguments = arguments
        }
    }

    /// One OSC 1.0 message: padded address, padded type-tag string, then the arguments.
    /// Returns nil for a bundle (`#bundle`), an unknown type tag, or a truncated payload —
    /// never a partial message.
    public nonisolated static func decode(_ data: Data) -> Message? {
        let bytes = [UInt8](data)
        var i = 0
        guard let address = readString(bytes, &i), address.hasPrefix("/") else { return nil }
        guard i < bytes.count else { return Message(address: address, arguments: []) }
        guard let tags = readString(bytes, &i), tags.hasPrefix(",") else { return nil }
        var args: [Argument] = []
        for tag in tags.dropFirst() {
            switch tag {
            case "f":
                guard let v = readUInt32(bytes, &i) else { return nil }
                args.append(.float(Float(bitPattern: v)))
            case "i":
                guard let v = readUInt32(bytes, &i) else { return nil }
                args.append(.int(Int32(bitPattern: v)))
            case "s":
                guard let s = readString(bytes, &i) else { return nil }
                args.append(.string(s))
            case "T": args.append(.bool(true))
            case "F": args.append(.bool(false))
            default:  return nil
            }
        }
        return Message(address: address, arguments: args)
    }

    /// Null-terminated, then padded to the next 4-byte boundary (`OSCSender.paddedOSCString`).
    private nonisolated static func readString(_ bytes: [UInt8], _ i: inout Int) -> String? {
        guard i < bytes.count, let end = bytes[i...].firstIndex(of: 0) else { return nil }
        guard let s = String(bytes: bytes[i..<end], encoding: .utf8) else { return nil }
        i = end + 1
        while i % 4 != 0 { i += 1 }
        return s
    }

    private nonisolated static func readUInt32(_ bytes: [UInt8], _ i: inout Int) -> UInt32? {
        guard i + 4 <= bytes.count else { return nil }
        let v = UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16
            | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3])
        i += 4
        return v
    }
}

// MARK: - The whitelist

/// A control cue Echoel accepts from the network. The enum IS the whitelist: an address that
/// does not parse into one of these cases is dropped before anything downstream sees it.
public enum OSCControlCommand: Equatable, Sendable {
    /// `/echoelmusic/ctrl/bpm <f|i>` — applied ONLY while the BPM is locked (T1/T2).
    case tempo(Double)
    /// `/echoelmusic/ctrl/key <i>` — root pitch class 0 (C) … 11 (B).
    case key(Int)
    /// `/echoelmusic/ctrl/scale <s>` — a `Scale` raw value (`major`, `dorian`, …).
    case scale(String)
    /// `/echoelmusic/ctrl/genre <s>` — a `MusicStyle` raw value (`techHouse`, `jazz`, …).
    case genre(String)
    /// `/echoelmusic/ctrl/visualStyle <i>` — look 0…9 (`EchoelStudioView.visualStyle`'s index space).
    case visualStyle(Int)
    /// `/echoelmusic/ctrl/blackout <T|F|i>` — Art-Net + sACN blackout, together.
    case blackout(Bool)

    public static let prefix = "/echoelmusic/ctrl/"
    /// Every address the receiver honours, in the order the routing card lists them.
    public static let addresses: [String] = ["bpm", "key", "scale", "genre", "visualStyle", "blackout"]
        .map { prefix + $0 }

    /// The whitelist gate. Bounds are checked HERE so a value the app cannot hold never reaches
    /// a `UserDefaults` write: a key of 12, a look of 10, a scale name no enum knows, a NaN
    /// tempo — all nil, all counted as ignored by the receiver.
    public nonisolated static func parse(_ message: OSCDecoder.Message) -> OSCControlCommand? {
        guard message.address.hasPrefix(prefix) else { return nil }
        let name = String(message.address.dropFirst(prefix.count))
        let first = message.arguments.first
        switch name {
        case "bpm":
            guard let v = first?.number, v.isFinite, v > 0 else { return nil }
            return .tempo(v)
        case "key":
            guard let v = first?.number, v.isFinite else { return nil }
            let root = Int(v.rounded())
            guard (0...11).contains(root) else { return nil }
            return .key(root)
        case "scale":
            guard case .string(let raw)? = first, Scale(rawValue: raw) != nil else { return nil }
            return .scale(raw)
        case "genre":
            guard case .string(let raw)? = first, MusicStyle(rawValue: raw) != nil else { return nil }
            return .genre(raw)
        case "visualStyle":
            guard let v = first?.number, v.isFinite else { return nil }
            let look = Int(v.rounded())
            guard (0...9).contains(look) else { return nil }
            return .visualStyle(look)
        case "blackout":
            guard let v = first?.number, v.isFinite else { return nil }
            return .blackout(v != 0)
        default:
            return nil
        }
    }

    /// One line for the routing card and the diag log.
    public var summary: String {
        switch self {
        case .tempo(let bpm):     return "bpm \(Int(bpm.rounded()))"
        case .key(let root):      return "key \(root)"
        case .scale(let raw):     return "scale \(raw)"
        case .genre(let raw):     return "genre \(raw)"
        case .visualStyle(let i): return "visualStyle \(i)"
        case .blackout(let on):   return on ? "blackout on" : "blackout off"
        }
    }
}

#if canImport(Network)
import Network
#if canImport(Observation)
import Observation
#endif

// MARK: - The socket

@MainActor
@Observable
public final class OSCReceiver {

    /// UDP port to listen on. 0 = let the OS pick (the loopback test); persisted otherwise.
    public var port: UInt16 {
        didSet { Self.persist(port: port, allowedHosts: allowedHosts); if isActive { stop(); start() } }
    }

    /// Comma-separated sender IPs. EMPTY = any sender on the network the OS delivers from.
    public var allowedHosts: String {
        didSet { Self.persist(port: port, allowedHosts: allowedHosts) }
    }

    public private(set) var isActive = false
    /// The port actually bound once the listener is ready (differs from `port` only for 0).
    public private(set) var boundPort: UInt16 = 0
    /// `CFAbsoluteTimeGetCurrent()` of the last ACCEPTED cue — the routing card's status line.
    public private(set) var lastReceivedTimestamp: TimeInterval = 0
    public private(set) var lastCommandSummary = ""
    /// Datagrams that decoded but were not on the whitelist (or out of range).
    public private(set) var ignoredCount = 0
    /// Senders turned away by the allowlist.
    public private(set) var refusedCount = 0
    public private(set) var lastError: String?

    /// The ONE dispatch, installed by `EchoelmusicApp` — the receiver knows no engine.
    @ObservationIgnored public var onCommand: ((OSCControlCommand) -> Void)?

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connections: [NWConnection] = []

    private static let portKey = "net.osc.in.port"
    private static let allowKey = "net.osc.in.allow"
    /// `nonisolated` on purpose (#1255b): Xcode's toolchain isolates an immutable `static let`
    /// of a `@MainActor` class, so a nonisolated reader — the guard's `XCTAssertEqual`
    /// autoclosure — broke `Build for Testing` (CLAUDE.md error table, SE-0434 row).
    nonisolated public static let defaultPort: UInt16 = 8001

    public init(port: UInt16 = OSCReceiver.defaultPort) {
        let d = UserDefaults.standard
        let p = d.integer(forKey: Self.portKey)
        self.port = (p > 0 && p <= 65_535) ? UInt16(p) : port
        self.allowedHosts = d.string(forKey: Self.allowKey) ?? ""
    }

    private static func persist(port: UInt16, allowedHosts: String) {
        let d = UserDefaults.standard
        d.set(Int(port), forKey: portKey)
        d.set(allowedHosts, forKey: allowKey)
    }

    /// Reads the persisted opt-in and opens or closes the socket — the same funnel at launch
    /// (`applyRouting`) and from the routing card's switch, so the key has ONE reader.
    public func applyPreference() {
        let on = UserDefaults.standard.object(forKey: StudioDefaultKeys.oscInEnabled.key) as? Bool
            ?? StudioDefaultKeys.oscInEnabled.value
        if on { start() } else { stop() }
    }

    public func start() {
        guard !isActive else { return }
        let nwPort: NWEndpoint.Port = port == 0 ? .any : (NWEndpoint.Port(rawValue: port) ?? .any)
        let newListener: NWListener
        do {
            newListener = try NWListener(using: .udp, on: nwPort)
        } catch {
            lastError = "OSC in: cannot listen on \(port) — \(error.localizedDescription)"
            EchoelCrashLog.breadcrumb("osc in: listen failed on \(port)")
            return
        }
        // Both handlers run on `.main` (the start queue) — the senders' `assumeIsolated` shape
        // (`ArtNetSender`), so nothing non-Sendable is captured into a Task.
        newListener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.listenerState(state) }
        }
        newListener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        newListener.start(queue: .main)
        listener = newListener
        isActive = true
        lastError = nil
        EchoelCrashLog.breadcrumb("osc in: listening on \(port == 0 ? "any" : String(port))")
    }

    public func stop() {
        guard isActive else { return }
        listener?.cancel()
        listener = nil
        for c in connections { c.cancel() }
        connections.removeAll()
        isActive = false
        boundPort = 0
        EchoelCrashLog.breadcrumb("osc in: closed")
    }

    private func listenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            boundPort = listener?.port?.rawValue ?? port
        case .failed(let error):
            lastError = "OSC in: \(error.localizedDescription)"
            EchoelCrashLog.breadcrumb("osc in: failed — \(error)")
            stop()
        default:
            break
        }
    }

    /// The allowlist, applied BEFORE a byte is read: a refused sender never reaches the decoder.
    private func accept(_ connection: NWConnection) {
        guard Self.isAllowed(endpoint: connection.endpoint, allowedHosts: allowedHosts) else {
            refusedCount += 1
            connection.cancel()
            return
        }
        connections.append(connection)
        connection.start(queue: .main)
        receive(from: ObjectIdentifier(connection))
    }

    /// One `receiveMessage` per datagram, re-armed until the connection ends. Runs on `.main`;
    /// the closure captures only the connection's IDENTITY (Sendable), never the object, and
    /// looks it up again — a cancelled connection is simply no longer in the list.
    private func receive(from id: ObjectIdentifier) {
        guard let connection = connections.first(where: { ObjectIdentifier($0) == id }) else { return }
        connection.receiveMessage { [weak self] data, _, _, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data, !data.isEmpty { self.handle(datagram: data) }
                if error == nil {
                    self.receive(from: id)
                } else {
                    self.connections.removeAll { ObjectIdentifier($0) == id }
                }
            }
        }
    }

    /// Empty allowlist = any sender. Otherwise the remote host's textual address must equal an
    /// entry (an IPv6 scope suffix such as `%en0` is ignored).
    nonisolated static func isAllowed(endpoint: NWEndpoint, allowedHosts: String) -> Bool {
        let entries = allowedHosts.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !entries.isEmpty else { return true }
        guard case .hostPort(let host, _) = endpoint else { return false }
        let raw: String
        switch host {
        case .ipv4(let a):    raw = "\(a)"
        case .ipv6(let a):    raw = "\(a)"
        case .name(let n, _): raw = n
        @unknown default:     raw = "\(host)"
        }
        let name = raw.split(separator: "%").first.map(String.init) ?? raw
        return entries.contains(name)
    }

    private func handle(datagram: Data) {
        guard let message = OSCDecoder.decode(datagram),
              let command = OSCControlCommand.parse(message) else {
            ignoredCount += 1
            return
        }
        lastReceivedTimestamp = CFAbsoluteTimeGetCurrent()
        lastCommandSummary = command.summary
        EchoelCrashLog.breadcrumb("osc in: \(command.summary)")
        onCommand?(command)
    }
}
#endif

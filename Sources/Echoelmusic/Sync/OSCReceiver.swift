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
//  Spatial S1 (founder 2026-10-03, "Live Set · Spatial Audio · immersive"): the same socket
//  also accepts ADM-OSC object POSITIONS (`/adm/obj/{n}/…`, `ADMObjectInput`) so a spatial
//  controller can move the piece's tracks. It shares the opt-in and the allowlist — one port,
//  one consent — and takes its own dispatch, because a trajectory is a stream, not a cue.
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
    ///
    /// ⛔ #1321 — AND FOR THREE OF THE SIX ADDRESSES THAT SENTENCE WAS A DESCRIPTION OF WHAT THE
    /// CODE MEANT, NOT OF WHAT IT DID. `key` and `visualStyle` converted with `Int(v.rounded())`
    /// ONE LINE BEFORE their range test, and `Int(_:)` TRAPS in Swift for anything past
    /// `Int.max` — a finite `1e30` passes `isFinite` and kills the app. `bpm` had no upper bound
    /// at all and handed the unbounded value to `summary`, which converts on every accepted cue.
    /// The value comes off the wire as `Float(bitPattern:)` of four raw bytes, and until T18
    /// (2026-10-08) from ANY sender on the network while the allowlist was empty (then the
    /// documented default), so this was one datagram from a remote kill mid-performance.
    ///
    /// ⭐ THE SHAPE OF THE FIX IS THE LESSON: **bound in the DOUBLE, then convert.** A range test
    /// after a lossy conversion is not a range test — the conversion is where the program dies.
    /// `.claude/rules/swift-audio.md` already bans force-unwraps and unguarded division for the
    /// same reason; `Int(someDouble)` belongs in that family and was not named.
    ///
    /// ⚠️ ONE BEHAVIOUR CHANGE, DELIBERATE AND NOT A SIDE EFFECT. `bpm` now also has an UPPER
    /// bound, and its lower bound rises from `> 0` to `Transport.minTempo`. A console sending
    /// 10 or 500 BPM used to parse and be silently CLAMPED by the consumer
    /// (`EchoelmusicApp`); it is now IGNORED and counted as ignored, which is what this doc
    /// block claims and what a performer can actually see and fix. The consumer's clamp stays —
    /// it owns its own contract and is now a no-op for this path.
    public nonisolated static func parse(_ message: OSCDecoder.Message) -> OSCControlCommand? {
        guard message.address.hasPrefix(prefix) else { return nil }
        let name = String(message.address.dropFirst(prefix.count))
        let first = message.arguments.first
        switch name {
        case "bpm":
            // Bounded HERE, in the Double, and against the transport's own constants rather
            // than a second spelling of them (#416).
            guard let v = first?.number, v.isFinite,
                  v >= Transport.minTempo, v <= Transport.maxTempo else { return nil }
            return .tempo(v)
        case "key":
            // The bound is tested on the DOUBLE — `Int(_:)` after it can no longer see a value
            // outside `Int`. Comparing integral bounds in `Double` is exact at this magnitude.
            guard let v = first?.number, v.isFinite,
                  (0...11).contains(v.rounded()) else { return nil }
            return .key(Int(v.rounded()))
        case "scale":
            guard case .string(let raw)? = first, Scale(rawValue: raw) != nil else { return nil }
            return .scale(raw)
        case "genre":
            guard case .string(let raw)? = first, MusicStyle(rawValue: raw) != nil else { return nil }
            return .genre(raw)
        case "visualStyle":
            // Same shape as `key` above: bound the Double, then convert.
            guard let v = first?.number, v.isFinite,
                  (0...9).contains(v.rounded()) else { return nil }
            return .visualStyle(Int(v.rounded()))
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
        // ⚠️ CLAMPED, NOT BECAUSE `parse` CAN STILL HAND THIS A HUGE VALUE — it cannot since
        // #1321 — but because this enum is `public` and any caller can construct
        // `.tempo(1e30)` directly. A diagnostic line is the last place that may take the app
        // down; `clamped(to:)` is the NaN-safe one (`Core/FloatingPointClamp`).
        case .tempo(let bpm):
            return "bpm \(Int(bpm.clamped(to: Transport.minTempo...Transport.maxTempo).rounded()))"
        case .key(let root):      return "key \(root)"
        case .scale(let raw):     return "scale \(raw)"
        case .genre(let raw):     return "genre \(raw)"
        case .visualStyle(let i): return "visualStyle \(i)"
        case .blackout(let on):   return on ? "blackout on" : "blackout off"
        }
    }
}

// MARK: - ADM-OSC object input (Spatial S1)

/// One object move from an external spatial controller — Grapes, L-ISA, SPAT, a console's
/// object panner — in the ADM-OSC v1.0 object namespace Echoel already SENDS (`SpatialSceneOSC`,
/// `ADMOSCSender`). Same leaves, same sign convention (positive azimuth = left), same 1-based
/// object index, so a rig that reads Echoel's objects can also write them.
///
/// THE OBJECT INDEX IS THE SCENE ARRAY. Object `n` is `SpatialSceneStore.scene.objects[n - 1]` —
/// the piece's tracks in order, the same table the outgoing stream numbers. An index past the
/// last track moves nothing (`SpatialSceneStore.apply`).
///
/// LENIENT RECEIVER, STRICT SENDER: a finite value outside its ADM range is CLAMPED here, in the
/// Double, before any conversion (#1321 — bound, then convert). A non-finite value, a string, a
/// bool, a wrong argument count or an unknown leaf is refused. The spec's packed forms (`/aed`,
/// `/xyz`) are the ones a receiver must handle; the single leaves are accepted too because
/// Echoel's own sender still emits them when only part of a position is measured.
///
/// What this does NOT do yet, stated where the type lives: no smoothing (a jittery controller
/// moves the object as jittery as it sends), and no render — the object moves in the scene and
/// in the outgoing ADM-OSC stream; nothing in the app's own audio is panned by it.
public struct ADMObjectInput: Equatable, Sendable {

    public enum Value: Equatable, Sendable {
        case azimuth(Float)
        case elevation(Float)
        case distance(Float)
        case polar(azimuth: Float, elevation: Float, distance: Float)
        case x(Float)
        case y(Float)
        case z(Float)
        case cartesian(x: Float, y: Float, z: Float)
        case gain(Float)
    }

    /// 1-based ADM object index.
    public let object: Int
    public let value: Value

    public static let prefix = "/adm/obj/"
    /// The highest object index accepted — far above any piece's track count, low enough that a
    /// hostile index is refused before it is ever looked up.
    public static let maxObject = 128
    /// Every leaf the receiver honours, in the spec table's order.
    public static let leaves = ["azim", "elev", "dist", "aed", "x", "y", "z", "xyz", "gain"]

    public init(object: Int, value: Value) {
        self.object = object
        self.value = value
    }

    public nonisolated static func parse(_ message: OSCDecoder.Message) -> ADMObjectInput? {
        guard message.address.hasPrefix(prefix) else { return nil }
        let parts = message.address.dropFirst(prefix.count)
            .split(separator: "/", omittingEmptySubsequences: false)
        // `Int(_:)` on a String returns nil on overflow — it does not trap.
        guard parts.count == 2, let n = Int(parts[0]), (1...maxObject).contains(n) else { return nil }
        var numbers: [Double] = []
        for argument in message.arguments {
            switch argument {
            case .float(let f): numbers.append(Double(f))
            case .int(let i):   numbers.append(Double(i))
            case .string, .bool: return nil
            }
        }
        guard numbers.allSatisfy({ $0.isFinite }) else { return nil }
        func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Float { Float(Swift.min(Swift.max(v, lo), hi)) }
        func one(_ lo: Double, _ hi: Double) -> Float? {
            numbers.count == 1 ? clamp(numbers[0], lo, hi) : nil
        }
        let value: Value
        switch parts[1] {
        case "azim": guard let v = one(-180, 180) else { return nil }; value = .azimuth(v)
        case "elev": guard let v = one(-90, 90) else { return nil }; value = .elevation(v)
        case "dist": guard let v = one(0, 1) else { return nil }; value = .distance(v)
        case "aed":
            guard numbers.count == 3 else { return nil }
            value = .polar(azimuth: clamp(numbers[0], -180, 180),
                           elevation: clamp(numbers[1], -90, 90),
                           distance: clamp(numbers[2], 0, 1))
        case "x": guard let v = one(-1, 1) else { return nil }; value = .x(v)
        case "y": guard let v = one(-1, 1) else { return nil }; value = .y(v)
        case "z": guard let v = one(-1, 1) else { return nil }; value = .z(v)
        case "xyz":
            guard numbers.count == 3 else { return nil }
            value = .cartesian(x: clamp(numbers[0], -1, 1), y: clamp(numbers[1], -1, 1), z: clamp(numbers[2], -1, 1))
        case "gain": guard let v = one(0, 1) else { return nil }; value = .gain(v)
        default: return nil
        }
        return ADMObjectInput(object: n, value: value)
    }

    /// The cube point a controller last sent for one object, and the position it produced.
    ///
    /// ADM-OSC Cartesian space is the cube [-1, 1]³; the scene is a sphere. Projecting each
    /// single leaf onto the sphere and merging the NEXT leaf into the projection made the result
    /// depend on arrival order (review of 6097629b6: front, then `/x 0.8`, `/y 0.8` landed at
    /// −38° while `/y` then `/x` landed at −45°, the packed `/xyz 0.8 0.8 0` answer). The hold
    /// keeps the UNPROJECTED point, so single leaves merge in the cube and only the result is
    /// projected. It is trusted only while the object still sits where it put it (`produced`):
    /// a polar leaf, the Touch surface or automation moving the object invalidates it.
    public struct CartesianHold: Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var z: Float
        public var produced: SpatialPosition
    }

    /// Pure merge: the object with this move applied. A single leaf changes ONE component and
    /// keeps the others. A Cartesian leaf merges into the held cube point when it is still valid,
    /// else into the object's current Cartesian position (`SpatialPosition.cartesian`, the same
    /// derivation the sender uses). Returns the hold to keep for the next leaf.
    public func applied(to object: SpatialObject,
                        hold: CartesianHold?) -> (object: SpatialObject, hold: CartesianHold?) {
        var o = object
        let p = o.position
        let c = p.cartesian
        let valid: CartesianHold? = hold?.produced == p ? hold : nil
        var cube = (x: valid?.x ?? c.x, y: valid?.y ?? c.y, z: valid?.z ?? c.z)
        switch value {
        case .azimuth(let a):   o.position = SpatialPosition(azimuth: a, elevation: p.elevation, distance: p.distance)
        case .elevation(let e): o.position = SpatialPosition(azimuth: p.azimuth, elevation: e, distance: p.distance)
        case .distance(let d):  o.position = SpatialPosition(azimuth: p.azimuth, elevation: p.elevation, distance: d)
        case .polar(let a, let e, let d): o.position = SpatialPosition(azimuth: a, elevation: e, distance: d)
        case .gain(let g):
            o.gain = g   // already clamped to 0…1 by `parse`
            return (o, valid)
        case .x(let x): cube.x = x
        case .y(let y): cube.y = y
        case .z(let z): cube.z = z
        case .cartesian(let x, let y, let z): cube = (x, y, z)
        }
        switch value {
        case .x, .y, .z, .cartesian:
            let produced = Self.position(x: cube.x, y: cube.y, z: cube.z)
            o.position = produced
            return (o, CartesianHold(x: cube.x, y: cube.y, z: cube.z, produced: produced))
        default:
            return (o, nil)
        }
    }

    /// The merge without a hold — each Cartesian leaf merges into the current projection.
    public func applied(to object: SpatialObject) -> SpatialObject {
        applied(to: object, hold: nil).object
    }

    /// The inverse of `SpatialPosition.cartesian` (x right, y front, z up; positive azimuth =
    /// left). A point outside the unit sphere (a cube corner) lands on its surface: distance is
    /// room-relative 0…1, and `SpatialPosition` clamps it.
    public static func position(x: Float, y: Float, z: Float) -> SpatialPosition {
        let d = (x * x + y * y + z * z).squareRoot()
        guard d.isFinite, d > 1e-6 else { return SpatialPosition(azimuth: 0, elevation: 0, distance: 0) }
        let azimuth = atan2f(-x, y) * 180 / .pi
        let elevation = asinf(Swift.min(Swift.max(z / d, -1), 1)) * 180 / .pi
        return SpatialPosition(azimuth: azimuth, elevation: elevation, distance: d)
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

    /// Comma-separated sender IPs that may send from the NETWORK. EMPTY = this device only
    /// (T18, 2026-10-08) — see `isAllowed`.
    public var allowedHosts: String {
        didSet { Self.persist(port: port, allowedHosts: allowedHosts) }
    }

    public private(set) var isActive = false
    /// The port actually bound once the listener is ready (differs from `port` only for 0).
    public private(set) var boundPort: UInt16 = 0
    /// `CFAbsoluteTimeGetCurrent()` of the last ACCEPTED cue — the routing card's status line.
    public private(set) var lastReceivedTimestamp: TimeInterval = 0
    public private(set) var lastCommandSummary = ""
    /// Datagrams that decoded but were not on the whitelist (or out of range). NOT observed:
    /// a spatial controller streams leaves Echoel does not take (width, mute, name …) at its
    /// full send rate, so this counter moves per datagram — an observed one would make every
    /// reader a stream-rate observer (the 10.76.50 law). The status leaf POLLS it on its 0.5 s
    /// `TimelineView` tick, exactly like `lastObjectMoveAt`.
    @ObservationIgnored public private(set) var ignoredCount = 0
    /// Senders turned away by the allowlist. NOT observed, for the same reason: a refused
    /// sender floods at its own rate.
    @ObservationIgnored public private(set) var refusedCount = 0
    public private(set) var lastError: String?

    /// The ONE dispatch, installed by `EchoelmusicApp` — the receiver knows no engine.
    @ObservationIgnored public var onCommand: ((OSCControlCommand) -> Void)?
    /// Spatial S1 — the dispatch for ADM-OSC object moves, installed by `EchoelmusicApp`
    /// (it writes `SpatialSceneStore.apply`). The receiver knows no scene either.
    @ObservationIgnored public var onObjectMove: ((ADMObjectInput) -> Void)?
    /// Object moves accepted since launch. NOT observed on purpose: a controller sends
    /// trajectories at tens of messages per object per second, and an observed counter would
    /// make every reader a high-rate observer (the 10.76.50 law).
    @ObservationIgnored public private(set) var objectMovesAccepted = 0
    /// `CFAbsoluteTimeGetCurrent()` of the last accepted object move — NOT observed, for the
    /// same reason. The routing card's status leaf POLLS it on its own 0.5 s `TimelineView`
    /// tick, so a moving controller reads as traffic instead of "nothing received" (review of
    /// 6097629b6) without making the card a stream-rate observer.
    @ObservationIgnored public private(set) var lastObjectMoveAt: TimeInterval = 0

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connections: [NWConnection] = []
    @ObservationIgnored private var lastCommand: OSCControlCommand?
    @ObservationIgnored private var lastBreadcrumbAt: TimeInterval = 0
    @ObservationIgnored private var lastMove: ADMObjectInput?
    @ObservationIgnored private var objectsAnnounced = false

    private static let portKey = "net.osc.in.port"
    private static let allowKey = "net.osc.in.allow"
    /// `nonisolated` on purpose (#1255b): Xcode's toolchain isolates an immutable `static let`
    /// of a `@MainActor` class, so a nonisolated reader — the guard's `XCTAssertEqual`
    /// autoclosure — broke `Build for Testing` (CLAUDE.md error table, SE-0434 row).
    nonisolated public static let defaultPort: UInt16 = 8001
    /// UDP gives every new sender address its own `NWConnection`. Without a ceiling, datagrams
    /// from many spoofed source ports grow `connections` without bound. At the ceiling the
    /// OLDEST connection is dropped, so a fresh sender still gets through.
    nonisolated public static let maxConnections = 16
    /// A console that re-sends the same value at 60 Hz is not 60 cues. An identical command
    /// inside this window is dropped — lossless, the state already holds it. A CHANGED value
    /// always passes.
    nonisolated public static let repeatWindow: TimeInterval = 0.1

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
        // T18 (security audit 2026-10-08) — never on a cellular interface. A cue socket belongs
        // to the venue network the operator chose; a carrier IPv6 address can be globally
        // routable, and the allowlist is the only other wall in front of the decoder.
        let parameters = NWParameters.udp
        parameters.prohibitedInterfaceTypes = [.cellular]
        let newListener: NWListener
        do {
            newListener = try NWListener(using: parameters, on: nwPort)
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
        lastCommand = nil
        lastMove = nil
        objectsAnnounced = false
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
        if connections.count >= Self.maxConnections {
            connections.removeFirst().cancel()
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

    /// THIS DEVICE (loopback) is always allowed, and an EMPTY list means THIS DEVICE ONLY: a
    /// sender on the network gets in only by being listed.
    ///
    /// ⛔ T18 (security audit 2026-10-08): until then an empty list meant "any sender", and
    /// empty was the default — switching OSC input on opened the port to every machine on a
    /// festival Wi-Fi, the opposite of the consent the switch's own hint describes ("from the
    /// senders you allow"). The Routing field now says "empty = this device only", and a
    /// refused network sender shows up as "N refused" in the status line, so the operator sees
    /// why a console is not heard.
    ///
    /// A listed entry must equal the sender's textual address. An IPv6 scope suffix (`%en0`) is
    /// ignored, and an IPv4 sender that a dual-stack socket reports as IPv4-mapped IPv6
    /// (`::ffff:192.168.1.9`) is compared in its IPv4 form — without that, a correctly typed
    /// IPv4 entry could never match such a sender.
    nonisolated static func isAllowed(endpoint: NWEndpoint, allowedHosts: String) -> Bool {
        guard case .hostPort(let host, _) = endpoint else { return false }
        let raw: String
        switch host {
        case .ipv4(let a):
            if a.isLoopback { return true }
            raw = "\(a)"
        case .ipv6(let a):
            if a.isLoopback { return true }
            if a.isIPv4Mapped, let v4 = a.asIPv4 {
                if v4.isLoopback { return true }
                raw = "\(v4)"
            } else {
                raw = "\(a)"
            }
        case .name(let n, _):
            if n.lowercased() == "localhost" { return true }
            raw = n
        @unknown default:
            raw = "\(host)"
        }
        let entries = allowedHosts.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let name = raw.split(separator: "%").first.map(String.init) ?? raw
        return entries.contains(name)
    }

    private func handle(datagram: Data) {
        guard let message = OSCDecoder.decode(datagram) else {
            ignoredCount += 1
            return
        }
        // Spatial S1 — the ADM-OSC object namespace is checked FIRST and leaves on its own
        // path: it is a stream, not a cue, so it skips the cue's observed summary and its
        // per-change diag line (a trajectory changes on every message).
        if let move = ADMObjectInput.parse(message) {
            accept(move: move)
            return
        }
        guard let command = OSCControlCommand.parse(message) else {
            ignoredCount += 1
            return
        }
        let now = CFAbsoluteTimeGetCurrent()
        if command == lastCommand, now - lastReceivedTimestamp < Self.repeatWindow { return }
        let summary = command.summary
        let changed = summary != lastCommandSummary
        lastCommand = command
        lastReceivedTimestamp = now
        lastCommandSummary = summary
        // The diag log is a file written with write(2): one line per CHANGE, at most ten a
        // second, so a flooding sender cannot fill the disk or bury the lifecycle ladder.
        if changed, now - lastBreadcrumbAt >= Self.repeatWindow {
            lastBreadcrumbAt = now
            EchoelCrashLog.breadcrumb("osc in: \(summary)")
        }
        onCommand?(command)
    }

    /// One object move. Identical repeats inside the window are dropped (lossless — the scene
    /// already holds the value). ONE diag line per socket session, written BEFORE the first
    /// dispatch (a ladder rung stands before its call), never one per move: a trajectory would
    /// otherwise bury the lifecycle ladder a crash read depends on (SEC-1).
    private func accept(move: ADMObjectInput) {
        let now = CFAbsoluteTimeGetCurrent()
        if move == lastMove, now - lastObjectMoveAt < Self.repeatWindow { return }
        lastMove = move
        lastObjectMoveAt = now
        objectMovesAccepted &+= 1
        if !objectsAnnounced {
            objectsAnnounced = true
            EchoelCrashLog.breadcrumb("osc in: adm object moves arriving")
        }
        onObjectMove?(move)
    }
}
#endif

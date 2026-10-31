import EchoelCore
import EchoelEngine
import Foundation
import Observation
import os

/// The Connections module (wave W4): OSC, ADM-OSC, Art-Net and sACN out of the song, and — only
/// while the musician keeps body sharing on — out of the body. Everything is off at every launch
/// and nothing of that is stored; a connection that is off has no socket (`UDPSender`).
///
/// One low-rate tick on the main actor reads the engine's transport — the one timebase every
/// output shares with the Field — the meters and the strap, builds packets with the pure Core
/// builders (`ConnectionsOSC`, `ADMObject`, `LightFixture`, the packet encoders) and hands bytes
/// to one `UDPSender` per connection. Nothing here runs on the render thread; nothing here is
/// read by a view body that hosts a menu — the panel reads the cold settings, and one leaf reads
/// `activity`, which moves about once a second.
///
/// Every message that could carry a body passes `BioEgressPolicy.allowsEgress(address:source:
/// consent:)` at the moment it is sent, with the consent as it is then: switching body sharing off
/// silences the body on the next tick and forgets the last body batch, so nothing waits to be sent.
@MainActor
@Observable
final class ConnectionsController {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case osc
        case admOSC
        case artNet
        case sacn

        var id: Self { self }

        var title: String {
            switch self {
            case .osc: "OSC"
            case .admOSC: "ADM-OSC"
            case .artNet: "Art-Net"
            case .sacn: "sACN (E1.31)"
            }
        }

        /// What the connection sends, in one line for the panel.
        var sends: String {
            switch self {
            case .osc: "The song's tempo, key, beat and level to a visual or sound tool (/echoelmusic/music/…); with body sharing on, the pulse, HRV and coherence (/echoelmusic/bio/…)."
            case .admOSC: "Every track as an audio object for an immersive renderer: its pan as the position, its level as the gain (/adm/obj/n/…)."
            case .artNet: "One DMX fixture — dimmer, red, green, blue — in the key's color, lit by the level and the beat, to a node or a lighting desk."
            case .sacn: "The same fixture as sACN, for a desk or node that speaks E1.31."
            }
        }

        var defaultPort: UInt16 {
            switch self {
            case .osc: 8000
            case .admOSC: 4001
            case .artNet: ArtDMXPacket.standardPort
            case .sacn: E131Packet.standardPort
            }
        }

        var isLight: Bool { self == .artNet || self == .sacn }
    }

    struct Target: Equatable, Sendable {
        var host: String
        var port: UInt16
    }

    /// What a live connection reports, for the status leaf. Moves on a state change and about
    /// once a second otherwise.
    struct Activity: Equatable, Sendable {
        var state: UDPSender.State
        var counters: UDPSender.Counters
    }

    private(set) var targets: [Kind: Target]
    private(set) var enabled: Set<Kind> = []
    private(set) var consent = BioEgressPolicy.Consent()
    /// Art-Net's 15-bit port address (0 by default) and sACN's universe (1 by default).
    private(set) var artNetUniverse: Int
    private(set) var sacnUniverse: Int
    private(set) var resolution: LightFixture.Resolution
    /// The fixture's first DMX slot, 1-based.
    private(set) var startChannel: Int
    private(set) var activity: [Kind: Activity] = [:]
    /// Why a connection could not be switched on, until it is tried again.
    private(set) var refusals: [Kind: String] = [:]

    nonisolated static let defaultHost = "192.168.1.100"
    nonisolated static let tickInterval: Duration = .milliseconds(50)
    /// A receiver that hears nothing for a while forgets the sender: the song and the objects are
    /// re-stated once a second even when nothing moved, the light a little more often (an Art-Net
    /// node holds or blacks out after about four seconds, an sACN receiver after 2.5).
    nonisolated static let restateSeconds = 1.0
    nonisolated static let lightRestateSeconds = 0.8
    /// How many stream-terminated packets say goodbye when sACN is switched off (the standard
    /// asks for three, so one lost datagram does not leave the receiver waiting out its timeout).
    nonisolated static let goodbyeCount = 3

    @ObservationIgnored private var engine: AudioEngine?
    @ObservationIgnored private var store: ProjectStore?
    @ObservationIgnored private var strap: HeartRateStrap?
    @ObservationIgnored private var senders: [Kind: UDPSender] = [:]
    /// Which opening of each connection is the current one; a state report from an earlier socket
    /// is ignored.
    @ObservationIgnored private var generations: [Kind: Int] = [:]
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastTick: ContinuousClock.Instant?
    @ObservationIgnored private var lastActivityRefresh: ContinuousClock.Instant?
    // What each connection last said, and when: a tick sends only what changed, plus a restatement.
    @ObservationIgnored private var lastMusic: [OSCMessage] = []
    @ObservationIgnored private var lastMusicSent: ContinuousClock.Instant?
    @ObservationIgnored private var lastBody: [OSCMessage] = []
    @ObservationIgnored private var lastBodySent: ContinuousClock.Instant?
    @ObservationIgnored private var lastObjects: [Int: ADMObject] = [:]
    @ObservationIgnored private var lastObjectsSent: ContinuousClock.Instant?
    @ObservationIgnored private var slew = LightSlew()
    @ObservationIgnored private var lastChannels: [UInt8] = []
    @ObservationIgnored private var lastLightSent: ContinuousClock.Instant?
    @ObservationIgnored private var artNetSequence: UInt8 = 0
    @ObservationIgnored private var sacnSequence: UInt8 = 0
    /// The E1.31 component identifier, made once for this installation and kept.
    @ObservationIgnored private let cid: [UInt8]
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "connections")

    private nonisolated static func hostKey(_ kind: Kind) -> String { "connections.\(kind.rawValue).host" }
    private nonisolated static func portKey(_ kind: Kind) -> String { "connections.\(kind.rawValue).port" }
    private static let artNetUniverseKey = "connections.artNet.universe"
    private static let sacnUniverseKey = "connections.sacn.universe"
    private static let resolutionKey = "connections.light.resolution"
    private static let startChannelKey = "connections.light.startChannel"
    private static let cidKey = "connections.sacn.cid"

    init() {
        let defaults = UserDefaults.standard
        var stored: [Kind: Target] = [:]
        for kind in Kind.allCases {
            let host = defaults.string(forKey: Self.hostKey(kind)) ?? Self.defaultHost
            let port = defaults.object(forKey: Self.portKey(kind)) as? Int
            stored[kind] = Target(host: host, port: port.flatMap { UInt16(exactly: $0) } ?? kind.defaultPort)
        }
        targets = stored
        artNetUniverse = Self.clamp(defaults.object(forKey: Self.artNetUniverseKey) as? Int ?? 0, to: ArtDMXPacket.universeRange)
        sacnUniverse = Self.clamp(defaults.object(forKey: Self.sacnUniverseKey) as? Int ?? 1, to: E131Packet.universeRange)
        resolution = LightFixture.Resolution(rawValue: defaults.string(forKey: Self.resolutionKey) ?? "") ?? .eightBit
        startChannel = Self.clamp(defaults.object(forKey: Self.startChannelKey) as? Int ?? 1, to: LightFixture.channelRange)
        if let saved = defaults.array(forKey: Self.cidKey) as? [Int], saved.count == 16 {
            cid = saved.map { UInt8(truncatingIfNeeded: $0) }
        } else {
            let fresh = withUnsafeBytes(of: UUID().uuid) { Array($0) }
            defaults.set(fresh.map { Int($0) }, forKey: Self.cidKey)
            cid = fresh
        }
    }

    /// Where the tick reads from. Called once by the root view; nothing is sent before a
    /// connection is switched on.
    func attach(engine: AudioEngine, store: ProjectStore, strap: HeartRateStrap) {
        self.engine = engine
        self.store = store
        self.strap = strap
    }

    // MARK: - Settings

    func target(_ kind: Kind) -> Target {
        targets[kind] ?? Target(host: Self.defaultHost, port: kind.defaultPort)
    }

    func isOn(_ kind: Kind) -> Bool { enabled.contains(kind) }

    func setHost(_ host: String, for kind: Kind) {
        var target = self.target(kind)
        target.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        targets[kind] = target
        UserDefaults.standard.set(target.host, forKey: Self.hostKey(kind))
        reopenIfOn(kind)
    }

    func setPort(_ port: UInt16, for kind: Kind) {
        var target = self.target(kind)
        target.port = port
        targets[kind] = target
        UserDefaults.standard.set(Int(port), forKey: Self.portKey(kind))
        reopenIfOn(kind)
    }

    func setUniverse(_ universe: Int, for kind: Kind) {
        switch kind {
        case .artNet:
            artNetUniverse = Self.clamp(universe, to: ArtDMXPacket.universeRange)
            UserDefaults.standard.set(artNetUniverse, forKey: Self.artNetUniverseKey)
        case .sacn:
            sacnUniverse = Self.clamp(universe, to: E131Packet.universeRange)
            UserDefaults.standard.set(sacnUniverse, forKey: Self.sacnUniverseKey)
        case .osc, .admOSC:
            break
        }
    }

    func universe(_ kind: Kind) -> Int {
        kind == .sacn ? sacnUniverse : artNetUniverse
    }

    func setResolution(_ resolution: LightFixture.Resolution) {
        self.resolution = resolution
        UserDefaults.standard.set(resolution.rawValue, forKey: Self.resolutionKey)
        startChannel = Self.clamp(startChannel, to: startChannelRange)
    }

    /// The first slot may sit anywhere the fixture still fits in the universe.
    var startChannelRange: ClosedRange<Int> {
        1...(LightFixture.channelRange.upperBound - resolution.channelCount + 1)
    }

    func setStartChannel(_ channel: Int) {
        startChannel = Self.clamp(channel, to: startChannelRange)
        UserDefaults.standard.set(startChannel, forKey: Self.startChannelKey)
    }

    /// Body sharing: the one switch that lets a measured body reach any connection. Not stored.
    func setSharesBody(_ on: Bool) {
        consent.sharesBody = on
        // Nothing of the body waits to be sent once it is off; the next batch starts from nothing.
        lastBody = []
        lastBodySent = nil
        log.info("connections: body sharing \(on ? "on" : "off", privacy: .public)")
    }

    // MARK: - On and off

    func setOn(_ on: Bool, _ kind: Kind) {
        if on {
            guard !enabled.contains(kind) else { return }
            guard open(kind) else { return }
            enabled.insert(kind)
            if loop == nil { startLoop() }
        } else {
            guard enabled.contains(kind) else { return }
            enabled.remove(kind)
            close(kind)
            if enabled.isEmpty {
                loop?.cancel()
                loop = nil
                lastTick = nil
            }
        }
        log.info("connections: \(kind.rawValue, privacy: .public) \(on ? "on" : "off", privacy: .public)")
    }

    /// Opens the socket for a connection and forgets what it last said, so the first tick says
    /// everything. False when the target cannot be a socket (an empty host).
    private func open(_ kind: Kind) -> Bool {
        let target = self.target(kind)
        let generation = (generations[kind] ?? 0) + 1
        generations[kind] = generation
        guard let sender = UDPSender(host: target.host, port: target.port, onState: { [weak self] state in
            Task { @MainActor [weak self] in self?.senderChanged(kind, generation: generation, to: state) }
        }) else {
            refusals[kind] = "Type the receiver's address first."
            return false
        }
        refusals[kind] = nil
        senders[kind]?.cancel()
        senders[kind] = sender
        activity[kind] = Activity(state: .preparing, counters: UDPSender.Counters())
        forgetLastSent(kind)
        return true
    }

    private func close(_ kind: Kind) {
        guard let sender = senders.removeValue(forKey: kind) else { return }
        generations[kind] = (generations[kind] ?? 0) + 1
        if kind == .sacn {
            // Three goodbyes, then the socket goes; a moment later, so they are on their way.
            for _ in 0..<Self.goodbyeCount {
                sacnSequence = E131Packet.nextSequence(sacnSequence)
                sender.send(E131Packet.packet(universe: sacnUniverse, sequence: sacnSequence, cid: cid, channels: lastChannels,
                                              options: E131Packet.streamTerminatedOption))
            }
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                sender.cancel()
            }
        } else {
            sender.cancel()
        }
        activity[kind] = nil
        forgetLastSent(kind)
    }

    private func reopenIfOn(_ kind: Kind) {
        guard enabled.contains(kind) else { return }
        if !open(kind) {
            enabled.remove(kind)
            if enabled.isEmpty {
                loop?.cancel()
                loop = nil
            }
        }
    }

    private func forgetLastSent(_ kind: Kind) {
        switch kind {
        case .osc:
            lastMusic = []
            lastMusicSent = nil
            lastBody = []
            lastBodySent = nil
        case .admOSC:
            lastObjects = [:]
            lastObjectsSent = nil
        case .artNet, .sacn:
            // Both lights share the slew and the last channels; a restart of either re-sends.
            lastChannels = []
            lastLightSent = nil
        }
    }

    private func senderChanged(_ kind: Kind, generation: Int, to state: UDPSender.State) {
        guard generations[kind] == generation, let sender = senders[kind] else { return }
        activity[kind] = Activity(state: state, counters: sender.statistics)
        if case .failed(let reason) = state {
            log.error("connections: \(kind.rawValue, privacy: .public) failed: \(reason, privacy: .public)")
        }
    }

    // MARK: - The tick

    private func startLoop() {
        lastTick = nil
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: ConnectionsController.tickInterval)
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let engine, let store, !enabled.isEmpty else { return }
        let now = ContinuousClock.now
        let elapsed = lastTick.map { Self.seconds(now - $0) } ?? Self.seconds(Self.tickInterval)
        lastTick = now

        let project = store.project
        let playhead = engine.playheadTick(in: project)
        let master = engine.meterLevel(nil)
        let level = Double(Swift.max(master.left, master.right)).squareRoot()
        let body = bodyReading()
        // The body reaches a frame only shared AND from a source that may leave the device.
        let bodyMayLeave = consent.sharesBody && (body.map { BioEgressPolicy.allowsEgress($0.source) } ?? false)
        let frame = FieldFrame.at(tick: Double(playhead), signature: project.timeSignature, context: project.context,
                                  level: level, pulse: nil, hrv: nil,
                                  coherence: bodyMayLeave ? body?.coherence : nil, isPlaying: engine.isPlaying)

        if enabled.contains(.osc) {
            let tempo = engine.playedTempoMap(of: project).bpm(at: playhead)
            sendMusic(tempo: tempo, root: project.context.root, frame: frame, now: now)
            sendBody(body, now: now)
        }
        if enabled.contains(.admOSC) {
            sendObjects(project: project, engine: engine, now: now)
        }
        if enabled.contains(.artNet) || enabled.contains(.sacn) {
            sendLight(frame: frame, elapsed: elapsed, now: now)
        }
        refreshActivity(now: now)
    }

    /// The strap's values, each nil while not measured, with their source. The strap is the one
    /// body producer of this build; a camera or Health source joins here, not at the senders.
    private func bodyReading() -> BodyEgressReading? {
        guard let strap, let engine, strap.isOn else { return nil }
        let inputs = engine.modulation
        return BodyEgressReading(source: strap.pulse.source ?? .ble,
                                 beatsPerMinute: strap.beatsPerMinute.map(Double.init),
                                 hrv: strap.measuring.contains(.hrv) ? inputs.value(.hrv) : nil,
                                 coherence: strap.measuring.contains(.coherence) ? inputs.value(.coherence) : nil)
    }

    private func sendMusic(tempo: Double, root: Int, frame: FieldFrame, now: ContinuousClock.Instant) {
        let messages = ConnectionsOSC.musicMessages(tempo: tempo, root: root, beatPhase: frame.beatPhase, masterLevel: frame.level)
            .filter { BioEgressPolicy.allowsEgress(address: $0.address, source: nil, consent: consent) }
        guard messages != lastMusic || isDue(lastMusicSent, now: now, after: Self.restateSeconds) else { return }
        send(.osc, messages)
        lastMusic = messages
        lastMusicSent = now
    }

    private func sendBody(_ reading: BodyEgressReading?, now: ContinuousClock.Instant) {
        guard consent.sharesBody, let reading else { return }
        let messages = ConnectionsOSC.bioMessages(for: reading)
            .filter { BioEgressPolicy.allowsEgress(address: $0.address, source: reading.source, consent: consent) }
        guard !messages.isEmpty else { return }
        guard messages != lastBody || isDue(lastBodySent, now: now, after: Self.restateSeconds) else { return }
        send(.osc, messages)
        lastBody = messages
        lastBodySent = now
    }

    private func sendObjects(project: Project, engine: AudioEngine, now: ContinuousClock.Instant) {
        let restate = isDue(lastObjectsSent, now: now, after: Self.restateSeconds)
        var current: [Int: ADMObject] = [:]
        var messages: [OSCMessage] = []
        for (offset, track) in project.tracks.enumerated() {
            let meter = engine.meterLevel(track.id)
            // In steps of 1/200, so a meter's flicker is not a message on every tick.
            let level = (Double(Swift.max(meter.left, meter.right)).squareRoot() * 200).rounded() / 200
            let object = ADMObject.track(index: offset + 1, pan: track.mixer.pan, level: level)
            current[object.index] = object
            let previous = lastObjects[object.index]
            if restate || previous.map({ !$0.hasSamePosition(as: object) }) ?? true { messages.append(object.positionMessage) }
            if restate || previous?.gain != object.gain { messages.append(object.gainMessage) }
        }
        guard !messages.isEmpty else { return }
        send(.admOSC, messages)
        lastObjects = current
        if restate { lastObjectsSent = now }
    }

    private func sendLight(frame: FieldFrame, elapsed: Double, now: ContinuousClock.Instant) {
        let look = slew.next(towards: LightFixture.look(for: frame, sharesBody: consent.sharesBody), after: elapsed)
        let channels = LightFixture.channels(look, resolution: resolution, startChannel: startChannel)
        guard channels != lastChannels || isDue(lastLightSent, now: now, after: Self.lightRestateSeconds) else { return }
        if let sender = senders[.artNet] {
            artNetSequence = ArtDMXPacket.nextSequence(artNetSequence)
            sender.send(ArtDMXPacket.packet(universe: artNetUniverse, sequence: artNetSequence, channels: channels))
        }
        if let sender = senders[.sacn] {
            sacnSequence = E131Packet.nextSequence(sacnSequence)
            sender.send(E131Packet.packet(universe: sacnUniverse, sequence: sacnSequence, cid: cid, channels: channels))
        }
        lastChannels = channels
        lastLightSent = now
    }

    private func send(_ kind: Kind, _ messages: [OSCMessage]) {
        guard let sender = senders[kind] else { return }
        for message in messages { sender.send(message.encoded) }
    }

    /// The counters, about once a second, for the status leaf — never every tick.
    private func refreshActivity(now: ContinuousClock.Instant) {
        guard isDue(lastActivityRefresh, now: now, after: Self.restateSeconds) else { return }
        lastActivityRefresh = now
        for (kind, sender) in senders {
            let counters = sender.statistics
            if var current = activity[kind], current.counters != counters {
                current.counters = counters
                activity[kind] = current
            }
        }
    }

    private func isDue(_ last: ContinuousClock.Instant?, now: ContinuousClock.Instant, after seconds: Double) -> Bool {
        guard let last else { return true }
        return Self.seconds(now - last) >= seconds
    }

    nonisolated static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
    }

    nonisolated static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, value))
    }
}

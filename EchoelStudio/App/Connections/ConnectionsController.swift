import EchoelCore
import EchoelEngine
import Foundation
import Observation
import os
#if canImport(UIKit)
import UIKit
#endif

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

        /// The light protocol's name in the lit-ledger; nil for OSC and ADM-OSC.
        var litOutput: LitLedger.Output? {
            switch self {
            case .artNet: .artNet
            case .sacn: .sacn
            case .osc, .admOSC: nil
            }
        }
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
    /// The longest step a light's flash guard takes in one tick. A tick after a suspension sees
    /// seconds pass; the light still fades at the flash limit's rate instead of jumping.
    nonisolated static let longestLightStep = 0.2

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
    /// Each light output has its own flash guard and its own memory of what it last said, so
    /// switching one on, off or to a new receiver fades that one alone, from dark.
    @ObservationIgnored private var slews: [Kind: LightSlew] = [:]
    @ObservationIgnored private var lastChannels: [Kind: [UInt8]] = [:]
    @ObservationIgnored private var lastLightSent: [Kind: ContinuousClock.Instant] = [:]
    // The song's light show (CUES), played instead of the one-fixture light while the song has a rig.
    /// The cue the show last started, by GO or by the timeline; nil before the first.
    private(set) var liveCue: CueID?
    /// Blackout: every light fades to 0 at the flash limit's rate, position holds. Not stored.
    private(set) var blackout = false
    @ObservationIgnored private var showGuards: [Kind: RigFlashGuard] = [:]
    /// What the show asked for last, before the blackout: a GO fades from here.
    @ObservationIgnored private var showTarget: RigState?
    /// A cue started by GO, with what it fades from and when; the timeline takes over again when
    /// the playhead crosses one of its cues.
    @ObservationIgnored private var manual: (cue: CueID, from: RigState, start: ContinuousClock.Instant)?
    @ObservationIgnored private var lastTimelineIndex: Int?
    @ObservationIgnored private var lastUniverses: [Kind: [Int: [UInt8]]] = [:]
    /// Universes an output no longer addresses, still to be told dark: one zero frame each tick
    /// until `goodbyeCount` were admitted, so a full send queue or a lost burst does not leave
    /// one lit (`UDPSender` refuses past its bound and expects the caller to say it again).
    @ObservationIgnored private var darkening: [Kind: [Int: (length: Int, said: Int)]] = [:]
    /// The app is in the background: no studio window is in the foreground (`presence`). While the
    /// song plays there (audio runs on) the lights go on; while it stands the app is about to be
    /// suspended, and the rig is left dark (`letGo`).
    @ObservationIgnored private var inBackground = false
    /// The studio windows and their phases; one controller serves them all.
    @ObservationIgnored private var presence = ScenePresence()
    /// The rig was left dark and nothing has lit it since.
    @ObservationIgnored private var leftDark = false
    /// Every DMX frame is numbered per output and per universe on the wire, as both standards
    /// count. Kept for the whole run and never reset — not by switching an output off and on, not
    /// by a new receiver — so a universe's numbers never run backwards (`WireSequences`).
    @ObservationIgnored private var wireSequences = WireSequences()
    /// Per light output, every universe on the wire it has sent to since it last went dark, with the
    /// longest frame there. Leaving the rig darkens each of them, and a universe the output stops
    /// addressing — a fixture moved or removed, another song, a new universe setting — is darkened
    /// at once: a node holds the last frame it heard.
    @ObservationIgnored private var lit: [Kind: [Int: Int]] = [:]
    @ObservationIgnored private var lastDarkSent: ContinuousClock.Instant?
    /// Every universe of every receiver lit and not yet said dark, kept in the defaults across
    /// launches (`LitLedger`): what it holds at launch was left lit by a run that crashed, hung or
    /// was ended while suspended. It is said dark only when the musician switches that output on to
    /// that receiver again — never at launch, which would open a connection nobody switched on.
    @ObservationIgnored private var litLedger: LitLedger
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?
    /// The app as a whole entered the background: the backstop for a window that left without
    /// reporting its own phase (`ScenePresence.appEnteredBackground`).
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?
    #if canImport(UIKit)
    @ObservationIgnored private var darkTask: UIBackgroundTaskIdentifier = .invalid
    #endif
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
    private static let litLedgerKey = "connections.light.litLedger"

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
        litLedger = LitLedger.decoded(defaults.data(forKey: Self.litLedgerKey))
        if let saved = defaults.array(forKey: Self.cidKey) as? [Int], saved.count == 16 {
            cid = saved.map { UInt8(truncatingIfNeeded: $0) }
        } else {
            let fresh = withUnsafeBytes(of: UUID().uuid) { Array($0) }
            defaults.set(fresh.map { Int($0) }, forKey: Self.cidKey)
            cid = fresh
        }
    }

    /// Where the tick reads from. Called once by the app; nothing is sent before a connection is
    /// switched on.
    func attach(engine: AudioEngine, store: ProjectStore, strap: HeartRateStrap) {
        self.engine = engine
        self.store = store
        self.strap = strap
        // The song paused from outside in the background (a call, another app's audio) and the
        // engine is about to stop: the rig goes dark NOW, before the app can be suspended between
        // two ticks with its lamps on their last frame.
        engine.onSuspending(self) { [weak self] in
            guard let self, self.inBackground else { return }
            self.letGo()
        }
        #if canImport(UIKit)
        // The app as a whole left the foreground: no window is in front, whatever each one last
        // reported.
        if backgroundObserver == nil {
            backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                        object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.presence.appEnteredBackground()
                    self.followPresence()
                }
            }
        }
        // The app is quit while it drives a rig (swiped away while the song plays): the dark
        // frame goes out on its way down. A suspended app is not told; `letGo` covers that.
        if terminationObserver == nil {
            terminationObserver = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification,
                                                                         object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.darkenAll()
                    // A moment for the datagrams to leave before the process ends.
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
        #endif
    }

    // MARK: - Settings

    func target(_ kind: Kind) -> Target {
        targets[kind] ?? Target(host: Self.defaultHost, port: kind.defaultPort)
    }

    func isOn(_ kind: Kind) -> Bool { enabled.contains(kind) }

    func setHost(_ host: String, for kind: Kind) {
        var target = self.target(kind)
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        // The same receiver again opens nothing: a reopen leaves the rig dark and fades it up.
        guard trimmed != target.host else { return }
        target.host = trimmed
        targets[kind] = target
        UserDefaults.standard.set(target.host, forKey: Self.hostKey(kind))
        reopenIfOn(kind)
    }

    func setPort(_ port: UInt16, for kind: Kind) {
        var target = self.target(kind)
        guard port != target.port else { return }
        target.port = port
        targets[kind] = target
        UserDefaults.standard.set(Int(port), forKey: Self.portKey(kind))
        reopenIfOn(kind)
    }

    func setUniverse(_ universe: Int, for kind: Kind) {
        switch kind {
        case .artNet:
            let next = Self.clamp(universe, to: ArtDMXPacket.universeRange)
            guard next != artNetUniverse else { return }
            artNetUniverse = next
            UserDefaults.standard.set(artNetUniverse, forKey: Self.artNetUniverseKey)
            // The old universe goes dark on the next frame; the new one fades up from dark.
            resetLightGuards(.artNet)
        case .sacn:
            let next = Self.clamp(universe, to: E131Packet.universeRange)
            guard next != sacnUniverse else { return }
            sacnUniverse = next
            UserDefaults.standard.set(sacnUniverse, forKey: Self.sacnUniverseKey)
            resetLightGuards(.sacn)
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
        // MPE Out's pressure and slide and the live stream's picture are wires off the device too:
        // the same switch governs them.
        engine?.setBodyConsent(consent)
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
            // The socket of the old address says goodbye; nothing keeps sending behind a switch
            // that shows off.
            if let old = senders.removeValue(forKey: kind) {
                retire(old, kind)
                activity[kind] = nil
            }
            return false
        }
        refusals[kind] = nil
        // A new receiver: the old one is left dark, not on its last frame, and the new one fades
        // up from dark.
        if let old = senders[kind] { retire(old, kind) }
        if kind.isLight { resetLightGuards(kind) }
        senders[kind] = sender
        activity[kind] = Activity(state: .preparing, counters: UDPSender.Counters())
        forgetLastSent(kind)
        adoptLeftLit(kind, through: sender)
        return true
    }

    private func close(_ kind: Kind) {
        guard let sender = senders.removeValue(forKey: kind) else { return }
        generations[kind] = (generations[kind] ?? 0) + 1
        retire(sender, kind)
        // Switched on again, the light fades up from dark at the flash limit's rate.
        if kind.isLight { resetLightGuards(kind) }
        activity[kind] = nil
        forgetLastSent(kind)
    }

    /// A socket that stops: a light output leaves every universe it lit dark, sACN adds its three
    /// stream-terminated goodbyes, and the socket closes a moment later, so they are on their way.
    private func retire(_ sender: UDPSender, _ kind: Kind) {
        guard kind.isLight else {
            sender.cancel()
            return
        }
        let frames = darken(kind, through: sender)
        if kind == .sacn {
            for _ in 0..<Self.goodbyeCount {
                for wire in frames.keys.sorted() {
                    guard let channels = frames[wire] else { continue }
                    sendDMX(.sacn, wire: wire, channels, through: sender, options: E131Packet.streamTerminatedOption)
                }
            }
        }
        // This socket's universes are said dark; the next socket starts its own ledger.
        lit[kind] = [:]
        darkening[kind] = nil
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            sender.cancel()
        }
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
            lastChannels[kind] = nil
            lastLightSent[kind] = nil
            lastUniverses[kind] = nil
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
        let elapsed = Swift.min(lastTick.map { Self.seconds(now - $0) } ?? Self.seconds(Self.tickInterval),
                                Self.longestLightStep)
        lastTick = now
        // In the background with the song standing — or a transport left set over an engine that
        // stopped — the app may be suspended at any moment and stop sending: the lights are left
        // dark, and stay so until the song plays again. OSC and ADM-OSC go on meanwhile.
        let parked = inBackground && !(engine.isPlaying && engine.isRunning)
        if parked {
            letGo(now: now)
        } else if leftDark {
            comeBack()
        }

        let project = store.project
        let playhead = engine.playheadTick(in: project)
        let master = engine.meterLevel(nil)
        let level = Double(Swift.max(master.left, master.right)).squareRoot()
        let body = bodyReading()
        // The body reaches a frame only shared AND from a source that may leave the device.
        let bodyMayLeave = consent.sharesBody && (body.map { BioEgressPolicy.allowsEgress($0.source) } ?? false)
        let frame = FieldFrame.at(tick: Double(playhead), meter: engine.playedMeterMap(of: project), context: project.context,
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
        if !parked, enabled.contains(.artNet) || enabled.contains(.sacn) {
            if project.lighting.fixtures.isEmpty {
                sendLight(frame: frame, elapsed: elapsed, now: now)
            } else {
                sendShow(project: project, engine: engine, playhead: playhead, frame: frame, elapsed: elapsed, now: now)
            }
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
        // Blackout darkens the one fixture too, at the flash limit's rate, as it does a rig.
        let wanted = blackout ? LightFixture.Look.dark : LightFixture.look(for: frame, sharesBody: consent.sharesBody)
        for kind in [Kind.artNet, .sacn] {
            guard enabled.contains(kind), let sender = senders[kind] else { continue }
            var slew = slews[kind] ?? LightSlew()
            let look = slew.next(towards: wanted, after: elapsed)
            slews[kind] = slew
            let channels = LightFixture.channels(look, resolution: resolution, startChannel: startChannel)
            let wire = singleWire(kind)
            darkenDropped(kind, keeping: [wire])
            sayDarkening(kind, through: sender)
            guard channels != lastChannels[kind] || isDue(lastLightSent[kind], now: now, after: Self.lightRestateSeconds)
            else { continue }
            sendDMX(kind, wire: wire, channels, through: sender)
            noteLit(kind, wire: wire, channels, through: sender)
            lastChannels[kind] = channels
            lastLightSent[kind] = now
        }
    }

    // MARK: - Leaving the rig

    /// A studio window reported its phase (`scenePhase`). The controller belongs to the app, not
    /// to a window, so the rig follows the app: it is let go only once no window is in the
    /// foreground (`ScenePresence`) — one of two iPad windows going inactive or to the background
    /// while the other stays in front changes nothing.
    func scene(_ id: UUID, is phase: ScenePresence.Phase) {
        presence.report(phase, for: id)
        followPresence()
    }

    /// A studio window closed. The connections stay on for the windows left; when it was the last
    /// one, the app is away and the rig is let go as in the background.
    func sceneLeft(_ id: UUID) {
        presence.remove(id)
        followPresence()
    }

    private func followPresence() {
        let away = presence.isAway
        guard away != inBackground else { return }
        if away { enterBackground() } else { enterForeground() }
    }

    /// The app went to the background: its last window left the foreground. Audio may run on
    /// there; the lights follow the song while it plays and are left dark when it stands (`tick`).
    private func enterBackground() {
        inBackground = true
        if let engine, !(engine.isPlaying && engine.isRunning) { letGo() }
    }

    private func enterForeground() {
        inBackground = false
    }

    /// Leaves the rig dark on every light output — once, and again at the restatement rate while
    /// the app still runs, so one lost burst does not leave a lamp lit — and asks for a moment of
    /// background time, so the frames leave before the app is suspended.
    private func letGo(now: ContinuousClock.Instant = .now) {
        guard enabled.contains(where: \.isLight) else { return }
        guard !leftDark || isDue(lastDarkSent, now: now, after: Self.lightRestateSeconds) else { return }
        if !leftDark {
            log.info("connections: lights left dark (background)")
            holdBackgroundTime()
        }
        darkenAll()
        leftDark = true
        lastDarkSent = now
    }

    /// Lighting again after `letGo`: the light fades back up from dark at the flash limit's rate.
    private func comeBack() {
        leftDark = false
        lastDarkSent = nil
        resetLightGuards(.artNet)
        resetLightGuards(.sacn)
    }

    private func darkenAll() {
        for kind in [Kind.artNet, .sacn] where enabled.contains(kind) {
            darken(kind, through: senders[kind])
        }
    }

    /// The output's guards start from dark and its next frame states everything.
    private func resetLightGuards(_ kind: Kind) {
        slews[kind] = nil
        showGuards[kind] = nil
        lastChannels[kind] = nil
        lastUniverses[kind] = nil
        lastLightSent[kind] = nil
    }

    /// The dark frame, `goodbyeCount` times, on every universe `kind` has lit: the rig's leaving
    /// frame where the song's rig sits (every light at 0, heads where they stand,
    /// `Lighting.leavingUniverses`), the one fixture at 0 without a rig, zeros on any other
    /// universe it lit. Returns what it sent, by universe on the wire.
    @discardableResult
    private func darken(_ kind: Kind, through sender: UDPSender?) -> [Int: [UInt8]] {
        guard let sender, let store else { return [:] }
        let lighting = store.project.lighting
        var frames: [Int: [UInt8]] = [:]
        if lighting.fixtures.isEmpty {
            frames[singleWire(kind)] = LightFixture.channels(.dark, resolution: resolution, startChannel: startChannel)
        } else {
            for (universe, channels) in lighting.leavingUniverses(from: showTarget) {
                frames[showWire(kind, universe)] = channels
            }
        }
        for (wire, length) in lit[kind] ?? [:] where frames[wire] == nil {
            frames[wire] = [UInt8](repeating: 0, count: length)
        }
        for (wire, entry) in darkening[kind] ?? [:] where frames[wire] == nil {
            frames[wire] = [UInt8](repeating: 0, count: entry.length)
        }
        // Every universe hears its first dark frame before any hears its second.
        for _ in 0..<Self.goodbyeCount {
            for wire in frames.keys.sorted() {
                guard let channels = frames[wire] else { continue }
                sendDMX(kind, wire: wire, channels, through: sender)
            }
        }
        // They stay in the ledger, so a restatement (`letGo`) says each of them dark again.
        darkening[kind] = nil
        lit[kind] = frames.mapValues(\.count)
        // Said dark: a crash from here on leaves this receiver dark, so the next launch owes it nothing.
        if let output = kind.litOutput {
            keepLitLedger(litLedger.forget(output, host: sender.host, port: sender.port))
        }
        return frames
    }

    /// Switched on to a receiver the lit-ledger says an earlier run left lit: those universes join
    /// this output's own (`lit`), so the first tick darkens each one it does not address — one zero
    /// frame a tick until `goodbyeCount` were admitted (`darkenDropped`, `sayDarkening`) — pads its
    /// first frames to their old length on Art-Net, and switching off again darkens them all
    /// (`darken`). Only through the socket the musician just switched on.
    private func adoptLeftLit(_ kind: Kind, through sender: UDPSender) {
        guard let output = kind.litOutput else { return }
        let left = litLedger.leftLit(output, host: sender.host, port: sender.port)
        guard !left.isEmpty else { return }
        for (wire, length) in left {
            lit[kind, default: [:]][wire] = Swift.max(lit[kind]?[wire] ?? 0, length)
        }
        log.info("connections: \(kind.rawValue, privacy: .public) darkens \(left.count) universes an earlier run left lit")
    }

    /// Writes the lit-ledger to the defaults when it `changed` — on a newly lit universe or one
    /// said dark, never on every frame.
    private func keepLitLedger(_ changed: Bool) {
        guard changed else { return }
        if litLedger.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.litLedgerKey)
        } else {
            UserDefaults.standard.set(litLedger.encoded(), forKey: Self.litLedgerKey)
        }
    }

    /// A frame that may light `wire` went out through `sender`: the lit-ledger learns it.
    private func noteLit(_ kind: Kind, wire: Int, _ channels: [UInt8], through sender: UDPSender) {
        guard let output = kind.litOutput else { return }
        keepLitLedger(litLedger.lit(output, host: sender.host, port: sender.port, universe: wire, channels: channels,
                                    frameLength: lit[kind]?[wire] ?? 0))
    }

    /// A universe `kind` lit before and does not address now goes to `darkening`; one it
    /// addresses again leaves it.
    private func darkenDropped(_ kind: Kind, keeping wires: Set<Int>) {
        for wire in wires { darkening[kind]?[wire] = nil }
        guard let addressed = lit[kind] else { return }
        for (wire, length) in addressed where !wires.contains(wire) {
            darkening[kind, default: [:]][wire] = (length, 0)
            lit[kind]?[wire] = nil
        }
    }

    /// One zero frame to each universe in `darkening`, counted only when the socket admitted
    /// it; a universe leaves once `goodbyeCount` were admitted.
    private func sayDarkening(_ kind: Kind, through sender: UDPSender) {
        guard let pending = darkening[kind], !pending.isEmpty else { return }
        for wire in pending.keys.sorted() {
            guard var entry = darkening[kind]?[wire] else { continue }
            let admitted = sendDMX(kind, wire: wire, [UInt8](repeating: 0, count: entry.length), through: sender)
            // `sendDMX` remembers the wire as addressed; it is not lit, it is being darkened.
            lit[kind]?[wire] = nil
            if admitted { entry.said += 1 }
            let done = entry.said >= Self.goodbyeCount
            darkening[kind]?[wire] = done ? nil : entry
            if done, let output = kind.litOutput {
                keepLitLedger(litLedger.forget(output, host: sender.host, port: sender.port, universe: wire))
            }
        }
    }

    /// One DMX frame out: numbered per universe on the wire and remembered in `lit`. On Art-Net a
    /// frame shorter than one sent there before is padded with zeros, so slots past it are not
    /// left on their last value (sACN always sends all 512).
    @discardableResult
    private func sendDMX(_ kind: Kind, wire: Int, _ channels: [UInt8], through sender: UDPSender,
                         options: UInt8 = 0) -> Bool {
        let longest = lit[kind]?[wire] ?? 0
        var frame = channels
        if frame.count < longest { frame.append(contentsOf: [UInt8](repeating: 0, count: longest - frame.count)) }
        let packet: Data
        switch kind {
        case .artNet:
            let sequence = wireSequences.next(.artNet, universe: wire)
            packet = ArtDMXPacket.packet(universe: wire, sequence: sequence, channels: frame)
        case .sacn:
            let sequence = wireSequences.next(.sacn, universe: wire)
            packet = E131Packet.packet(universe: wire, sequence: sequence, cid: cid, channels: frame, options: options)
        case .osc, .admOSC:
            return false
        }
        lit[kind, default: [:]][wire] = Swift.max(longest, frame.count)
        return sender.send(packet)
    }

    /// The universe on the wire of the one fixture, and of rig universe `universe`.
    private func singleWire(_ kind: Kind) -> Int { kind == .sacn ? sacnUniverse : artNetUniverse }
    private func showWire(_ kind: Kind, _ universe: Int) -> Int {
        kind == .sacn ? sacnAddress(of: universe) : artNetAddress(of: universe)
    }

    #if canImport(UIKit)
    /// A moment of background time, so the dark frames leave before the app is suspended.
    private func holdBackgroundTime() {
        guard darkTask == .invalid else { return }
        darkTask = UIApplication.shared.beginBackgroundTask(withName: "Lights dark") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTime() }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.endBackgroundTime()
        }
    }

    private func endBackgroundTime() {
        guard darkTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(darkTask)
        darkTask = .invalid
    }
    #else
    private func holdBackgroundTime() {}
    #endif

    // MARK: - The light show

    /// Starts the cue after the one showing (the first when none is), fading from what shows now.
    func go(in project: Project) {
        let cues = project.lighting.cues
        guard !cues.isEmpty else { return }
        let next = liveCue.flatMap { live in cues.firstIndex { $0.id == live } }.map { $0 + 1 } ?? 0
        go(to: cues[next < cues.count ? next : 0].id, in: project)
    }

    /// Starts `cue` now, fading from what shows now over the cue's fade.
    func go(to cue: CueID, in project: Project) {
        guard project.lighting.cue(cue) != nil else { return }
        manual = (cue, showTarget ?? project.lighting.restState, ContinuousClock.now)
        liveCue = cue
        log.info("connections: light GO")
    }

    func setBlackout(_ on: Bool) {
        blackout = on
        log.info("connections: blackout \(on ? "on" : "off", privacy: .public)")
    }

    /// Universe `n` of the rig on the wire: the universe set in Connections is the rig's first.
    private func artNetAddress(of universe: Int) -> Int {
        Self.clamp(artNetUniverse + universe - 1, to: ArtDMXPacket.universeRange)
    }

    private func sacnAddress(of universe: Int) -> Int {
        Self.clamp(sacnUniverse + universe - 1, to: E131Packet.universeRange)
    }

    private func sendShow(project: Project, engine: AudioEngine, playhead: Tick, frame: FieldFrame, elapsed: Double,
                          now: ContinuousClock.Instant) {
        let lighting = project.lighting
        let look = LightFixture.look(for: frame, sharesBody: consent.sharesBody)
        let map = engine.playedTempoMap(of: project)
        // The timeline takes over from a GO when the playhead crosses one of its cues.
        let index = engine.isPlaying ? lighting.placements.lastIndex { $0.tick <= playhead } : nil
        if let index, index != lastTimelineIndex {
            manual = nil
            liveCue = lighting.placements[index].cue
        }
        lastTimelineIndex = index
        var target: RigState
        if let manual, let cue = lighting.cue(manual.cue) {
            target = Lighting.interpolate(from: manual.from, to: lighting.target(of: cue, songLook: look),
                                          progress: Lighting.progress(elapsed: Self.seconds(now - manual.start), fade: cue.fade))
        } else if engine.isPlaying,
                  let timeline = lighting.timelineTarget(atSeconds: map.seconds(at: playhead), tempoMap: map, songLook: { _ in look }) {
            target = timeline
        } else {
            target = showTarget ?? lighting.restState
        }
        // A fixture patched since the last tick rests until a cue sets it; a removed one is gone.
        target = target.filter { lighting.fixture($0.key) != nil }
        for (id, values) in lighting.restState where target[id] == nil { target[id] = values }
        showTarget = target
        let goal = blackout ? RigFlashGuard.dark(target) : target
        for kind in [Kind.artNet, .sacn] {
            guard enabled.contains(kind), let sender = senders[kind] else { continue }
            var guardRail = showGuards[kind] ?? RigFlashGuard()
            let universes = lighting.universes(guardRail.next(towards: goal, after: elapsed))
            showGuards[kind] = guardRail
            darkenDropped(kind, keeping: Set(universes.keys.map { showWire(kind, $0) }))
            sayDarkening(kind, through: sender)
            guard universes != lastUniverses[kind] || isDue(lastLightSent[kind], now: now, after: Self.lightRestateSeconds)
            else { continue }
            for universe in universes.keys.sorted() {
                guard let channels = universes[universe] else { continue }
                let wire = showWire(kind, universe)
                sendDMX(kind, wire: wire, channels, through: sender)
                noteLit(kind, wire: wire, channels, through: sender)
            }
            lastUniverses[kind] = universes
            lastLightSent[kind] = now
        }
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

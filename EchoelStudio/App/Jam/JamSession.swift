import AVFoundation
import Darwin
import EchoelCore
import EchoelEngine
import Foundation
import Observation
import UIKit

/// The jam (W16, founder 2026-10-31): host one, or join one nearby, and play to one bar. Off until
/// the musician hosts or joins on the Jam page (Song menu, Connect); `leave()` ends it, and nothing
/// of it is stored. The host owns the tempo, the time signature, Play and Stop and its bar lines and
/// speaks when they change (`JamBeacon`). A guest follows on the path of an external MIDI clock —
/// the engine plays the host's tempo and time signature in place of the song's
/// (`AudioEngine.externalTempo`, `externalSignature`), the song itself is never written, and the
/// same `PhaseLock` keeps the bars together (`JamFollower`). One external clock at a time: joining
/// turns Follow MIDI Clock off. Only timing travels — no audio, no song, no body value.
///
/// Nothing here moves at the rate it measures where a view can see it: the page and the transport
/// read `role`, `nearby`, `members`, the followed tempo and time signature and `followPhase`, which
/// change only when the jam does; anchors, clock offsets and pings stay unobserved (Law 6).
@MainActor
@Observable
final class JamSession {
    enum Role: Equatable {
        case off
        case hosting
        /// Looking for a jam nearby (Join a Jam).
        case looking
        case joining(JamPeer)
        case joined(JamPeer)
    }

    private(set) var role: Role = .off
    /// Jams found nearby while looking.
    private(set) var nearby: [JamPeer] = []
    /// Everyone in the jam as the list reads them, the host first.
    private(set) var members: [String] = []
    /// While a guest follows: the host's tempo and time signature, which this phone plays.
    private(set) var followedTempo: Double?
    private(set) var followedSignature: TimeSignature?
    private(set) var followPhase: JamFollower.Phase = .waiting
    /// What went wrong, in words, until the next Host a Jam or Join a Jam.
    private(set) var problem: String?

    /// A guest follows the host's clock: the tempo field is locked, Follow MIDI Clock waits.
    var followsJam: Bool {
        if case .joined = role { return true }
        return false
    }

    @ObservationIgnored private var engine: AudioEngine?
    @ObservationIgnored private var store: ProjectStore?
    @ObservationIgnored private var midi: MIDIInput?
    @ObservationIgnored private var link: JamLink?
    @ObservationIgnored private var follower = JamFollower()
    @ObservationIgnored private var beacon = JamBeacon()
    @ObservationIgnored private var guests: [JamPeer] = []
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var joinTimer: Task<Void, Never>?
    @ObservationIgnored private var pings: UInt32 = 0
    @ObservationIgnored private var loopTurn = 0

    func attach(engine: AudioEngine, store: ProjectStore, midi: MIDIInput) {
        self.engine = engine
        self.store = store
        self.midi = midi
    }

    /// This phone's name for the others. iOS gives an app "iPhone" unless it holds a special
    /// entitlement; `JamPeer.labels` tells two of them apart.
    private var myName: String {
        let name = UIDevice.current.name
        return name.isEmpty ? JamPeer.fallbackName : name
    }

    // MARK: - Host, look, join, leave

    /// Hosts a jam: phones nearby can find this one and join it.
    func host() {
        guard role == .off else { return }
        problem = nil
        let link = makeLink()
        guests = []
        beacon = JamBeacon()
        members = JamPeer.labels([myName])
        role = .hosting
        link.host()
        startLoop()
        DiagnosticLog.app.note("jam: host")
    }

    /// Looks for a jam nearby (Join a Jam).
    func look() {
        guard role == .off else { return }
        problem = nil
        nearby = []
        let link = makeLink()
        role = .looking
        link.browse()
        DiagnosticLog.app.note("jam: look")
    }

    /// Asks a jam found nearby to take this phone in.
    func join(_ host: JamPeer) {
        guard role == .looking, let link else { return }
        guard link.join(host) else {
            nearby.removeAll { $0 == host }
            return
        }
        problem = nil
        role = .joining(host)
        joinTimer?.cancel()
        joinTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(JamLink.joinTimeout + 5))
            guard !Task.isCancelled, let self, self.role == .joining(host) else { return }
            self.joinFailed(host)
        }
    }

    /// Leaves the jam — for the host, ends it; the others play on at the last tempo. This phone's
    /// song plays its own tempo and time signature again.
    func leave() {
        let closing = link
        link = nil
        if role == .hosting, let closing {
            closing.send(.leave, reliably: true)
            // A moment for the word to go out before the connections close.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                closing.close()
            }
        } else {
            closing?.close()
        }
        loop?.cancel()
        loop = nil
        startTask?.cancel()
        startTask = nil
        joinTimer?.cancel()
        joinTimer = nil
        stopFollowing()
        role = .off
        nearby = []
        members = []
        guests = []
        DiagnosticLog.app.note("jam: leave")
    }

    private func makeLink() -> JamLink {
        let token = String(UUID().uuidString.prefix(6))
        let link = JamLink(linkName: JamPeer.linkName(name: myName, token: token), onEvent: { [weak self] event in
            Task { @MainActor [weak self] in self?.handle(event) }
        })
        self.link = link
        return link
    }

    private func joinFailed(_ host: JamPeer) {
        role = .looking
        problem = "\(host.name) did not let this phone in. Try again, or ask whether the jam is still open."
    }

    // MARK: - What the link says

    private func handle(_ event: JamLink.Event) {
        switch event {
        case .found(let peer):
            if case .looking = role, !nearby.contains(peer) { nearby.append(peer) }
        case .lost(let peer):
            nearby.removeAll { $0 == peer }
        case .connected(let peer):
            connected(peer)
        case .disconnected(let peer):
            disconnected(peer)
        case .received(let message, from: let peer, at: let time):
            received(message, from: peer, at: time)
        case .newer:
            guard role != .hosting else { return }
            leave()
            problem = "This jam runs a newer Echoel. Update Echoel on this phone to join it."
        case .refused(let error):
            DiagnosticLog.app.note("jam: refused", error: error)
            leave()
            problem = "Echoel cannot reach phones nearby. Allow Local Network for Echoel in Settings, Privacy & Security, then try again."
        }
    }

    private func connected(_ peer: JamPeer) {
        switch role {
        case .hosting:
            if !guests.contains(peer) { guests.append(peer) }
            rosterChanged()
            beacon.reset()
            DiagnosticLog.app.note("jam: a phone joined", [("phones", Double(guests.count + 1))])
        case .joining(let host) where host == peer:
            joinTimer?.cancel()
            joinTimer = nil
            link?.stopBrowsing()
            nearby = []
            role = .joined(host)
            members = JamPeer.labels([host.name, myName])
            // One external clock at a time: the jam's.
            if midi?.followedSource != nil { midi?.follow(nil) }
            follower = JamFollower()
            follower.joined(at: JamTime.now())
            publishPhase()
            startLoop()
            DiagnosticLog.app.note("jam: joined")
        default:
            break
        }
    }

    private func disconnected(_ peer: JamPeer) {
        switch role {
        case .hosting:
            guests.removeAll { $0 == peer }
            rosterChanged()
        case .joining(let host) where host == peer:
            joinTimer?.cancel()
            joinTimer = nil
            joinFailed(host)
        case .joined(let host) where host == peer:
            follower.linkDropped()
            publishPhase()
            DiagnosticLog.app.note("jam: host lost", because: "link")
        default:
            break
        }
    }

    private func received(_ message: JamMessage, from peer: JamPeer, at time: Double) {
        // A host hears pings, answered on the link already, and a guest's leave, which the link's
        // disconnect reports too: only a guest acts on what arrives.
        guard case .joined(let host) = role, host == peer, let engine else { return }
        switch message.kind {
        case .state:
            guard let state = message.state else { return }
            let action = follower.received(state, at: time, playing: engine.isPlaying)
            followHostClock()
            apply(action)
        case .pong:
            guard let pong = message.pong else { return }
            follower.received(pong, at: time)
        case .roster:
            guard let roster = message.roster else { return }
            let labels = JamPeer.labels(roster)
            if labels != members { members = labels }
        case .leave:
            follower.hostLeft()
            DiagnosticLog.app.note("jam: host ended the jam")
        case .ping:
            break
        }
        publishPhase()
    }

    // MARK: - Hosting

    private func rosterChanged() {
        let names = [myName] + guests.map(\.name)
        members = JamPeer.labels(names)
        link?.send(JamMessage(roster: names), reliably: true)
    }

    /// The host's word, when its beacon says it is due: what it plays, anchored where it is heard.
    private func speak() {
        guard let link, let engine, let store, !guests.isEmpty else { return }
        let project = store.project
        let map = engine.playedTempoMap(of: project)
        let state: JamState
        if engine.isPlaying {
            let now = mach_absolute_time()
            // The first buffer after Play is not heard yet: the anchor waits for it.
            guard let heard = engine.heardPosition(atHostTime: now) else { return }
            let position = Swift.max(0, heard.tick)
            state = JamState(tempo: map.bpm(at: MusicalTime.integer(position.rounded(.down))), signature: project.timeSignature,
                             isPlaying: true, anchorTick: position, anchorTime: JamTime.seconds(now))
        } else {
            let position = engine.playheadTick(in: project)
            state = JamState(tempo: map.bpm(at: position), signature: project.timeSignature, isPlaying: false,
                             anchorTick: Double(position), anchorTime: JamTime.now())
        }
        if let due = beacon.due(state) {
            link.send(JamMessage(state: due), reliably: true)
        }
    }

    // MARK: - Following

    /// The engine plays the host's tempo and time signature: set when they change, never written
    /// into the song.
    private func followHostClock() {
        guard let engine, let state = follower.state else { return }
        if followedTempo != state.tempo { followedTempo = state.tempo }
        if followedSignature != state.signature { followedSignature = state.signature }
        if engine.externalTempo != state.tempo { engine.externalTempo = state.tempo }
        if engine.externalSignature != state.signature { engine.externalSignature = state.signature }
        if !engine.followsExternalClock { engine.followsExternalClock = true }
    }

    /// The song's own tempo and time signature again — unless a MIDI clock is followed, which the
    /// jam never set.
    private func stopFollowing() {
        follower = JamFollower()
        if followedTempo != nil { followedTempo = nil }
        if followedSignature != nil { followedSignature = nil }
        publishPhase()
        guard let engine, engine.followsExternalClock, midi?.followedSource == nil else { return }
        engine.followsExternalClock = false
        engine.externalTempo = nil
        engine.externalSignature = nil
    }

    private func apply(_ action: JamFollower.Action) {
        switch action {
        case .none:
            break
        case .pause:
            startTask?.cancel()
            startTask = nil
            guard let engine, engine.isPlaying else { return }
            engine.pauseFromOutside(nil)
            store?.endGesture()
        case .start(let start):
            schedule(start)
        }
    }

    /// Starts the transport so the bar line is heard when the host hears it: early by the output's
    /// latency and one and a half buffers, since the audio begins with the next buffer. The first
    /// phase check takes out what is left (`JamFollower.correct`).
    private func schedule(_ start: JamStart) {
        startTask?.cancel()
        let session = AVAudioSession.sharedInstance()
        let latency = Self.bounded(session.outputLatency, 0.25)
        let buffer = Self.bounded(session.ioBufferDuration, 0.1)
        let wait = start.localTime - latency - 1.5 * buffer - JamTime.now()
        startTask = Task { @MainActor [weak self] in
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self?.begin(start)
        }
    }

    private func begin(_ start: JamStart) {
        startTask = nil
        guard let engine, follower.phase == .starting else { return }
        engine.seek(toTick: start.songTick(loop: engine.activeLoop))
        engine.play()
        follower.started(engine.isPlaying)
        publishPhase()
        DiagnosticLog.app.note("jam: start", [("tick", start.hostTick)])
        // The first phase check as soon as a buffer is heard, not a quarter second later.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            self?.correctPhase()
        }
    }

    /// What this phone hears against the host's bar, and the follower's answer.
    private func correctPhase() {
        guard let engine, engine.isPlaying else { return }
        let now = mach_absolute_time()
        guard let heard = engine.heardPosition(atHostTime: now) else { return }
        switch follower.correct(heard: heard.tick, atLocal: JamTime.seconds(now)) {
        case .none:
            break
        case .nudge(let seconds):
            engine.nudge(seconds: seconds)
        case .relock(let gap):
            engine.relock(byTicks: gap, samplesPerTick: heard.samplesPerTick)
        }
    }

    private func ping() {
        pings &+= 1
        link?.send(JamMessage(ping: JamPing(id: pings, sentAt: JamTime.now())), reliably: false)
    }

    private func publishPhase() {
        if followPhase != follower.phase { followPhase = follower.phase }
    }

    private static func bounded(_ seconds: Double, _ most: Double) -> Double {
        seconds.isFinite ? Swift.min(Swift.max(seconds, 0), most) : 0
    }

    // MARK: - The loop

    /// Eight times a second while hosting or joined.
    private func startLoop() {
        loop?.cancel()
        loopTurn = 0
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(125))
            }
        }
    }

    private func tick() {
        loopTurn &+= 1
        switch role {
        case .hosting:
            if loopTurn % 2 == 0 { speak() }
        case .joined:
            guard let engine else { return }
            // Eight pings a second for the first second, so the clocks are measured before the
            // host's next bar; then two.
            if loopTurn <= 8 || loopTurn % 4 == 0 { ping() }
            apply(follower.check(at: JamTime.now(), playing: engine.isPlaying))
            if loopTurn % 2 == 0 { correctPhase() }
            publishPhase()
        case .off, .looking, .joining:
            break
        }
    }

    // MARK: - In words

    /// What the follow does, in a sentence, for the page.
    var followText: String {
        switch followPhase {
        case .waiting: "Waiting for the host's timing."
        case .stopped: "The host is stopped. You come in on its next bar when it plays."
        case .starting: "Coming in on the host's next bar."
        case .following: "Following the Jam."
        case .sittingOut: "Stopped here while the host plays. Tap Play to come back in, or wait for the host's next start."
        case .hostLost: "Jam host lost. Playing on at \(tempoText)."
        case .ended: "The host ended the jam. Playing on at \(tempoText)."
        }
    }

    /// The host went quiet or ended the jam: what the page and the transport mark as a warning.
    var hostIsGone: Bool { followPhase == .hostLost || followPhase == .ended }

    /// The jam in one line under the transport; nil without one.
    var transportLine: (text: String, warning: Bool)? {
        switch role {
        case .hosting:
            return (text: "Hosting a Jam.", warning: false)
        case .joined:
            return (text: followText, warning: hostIsGone)
        case .off, .looking, .joining:
            return nil
        }
    }

    private var tempoText: String {
        followedTempo.map { NumberText.string($0, decimalsUpTo: 2, unit: "BPM") } ?? "the last tempo"
    }
}

import EchoelCore
import Foundation
import Observation

/// The tempo lock (W12): Fixed plays the song's own tempo — what the studio always did; Flow lets
/// the pulse move it through `FlowTempo` (trusted, folded, a bounded step at each of the song's bar
/// lines, a two-second glide). Flow plays on the engine's one tempo path (`AudioEngine.flowTempo`,
/// read by its `playing(_:)`): never written into the song while it flows, and no second clock — it
/// steps on the bar lines the engine plays, so it moves while the song plays and waits while it is
/// stopped. Closing the lock keeps where Flow got to as the song's tempo: one undo step, a gesture
/// (T1). While a jam's host or a MIDI clock sets the pace, Flow is off and cannot be chosen.
///
/// The tempo Flow plays follows the body, so it leaves the device only as the body does: while a
/// MIDI clock goes out, this phone hosts a jam or the OSC connection is on, Flow follows the pulse
/// only with Share Body Data on (`BioEgressPolicy.allowsFollowingThePulse`). Without it Flow holds
/// the tempo where it is and says so (`holdsForSharing`).
///
/// Owned by `StudioView`, so Flow goes on while another view is open. Its observed values change
/// when the lock, the trust or the shown tempo does, so a view reading them is not redrawn by each
/// look (Law 6).
@MainActor
@Observable
final class FlowController {
    /// The lock as the musician set it.
    private(set) var lock: TempoLock = .fixed
    /// The pulse is trusted and Flow follows it.
    private(set) var isFollowing = false
    /// What Flow plays, to a tenth; nil while Fixed.
    private(set) var shownTempo: Double?
    /// The trusted pulse, whole beats a minute, while Flow follows it.
    private(set) var shownPulse: Int?
    /// Where the pulse takes the tempo, whole beats a minute, while Flow follows it.
    private(set) var shownTarget: Int?
    /// Flow is on and holds the tempo, because the tempo leaves this device and Share Body Data
    /// is off.
    private(set) var holdsForSharing = false

    @ObservationIgnored private var flow = FlowTempo()
    @ObservationIgnored private var engine: AudioEngine?
    @ObservationIgnored private var store: ProjectStore?
    @ObservationIgnored private var strap: HeartRateStrap?
    @ObservationIgnored private var camera: CameraPulseSource?
    @ObservationIgnored private var midi: MIDIInput?
    @ObservationIgnored private var jam: JamSession?
    @ObservationIgnored private var connections: ConnectionsController?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastLook: ContinuousClock.Instant?
    @ObservationIgnored private var lastBar: Int64?
    @ObservationIgnored private var looksSinceWrite = 0
    /// The song Flow began in: another song opened ends Flow without writing into either.
    @ObservationIgnored private var generation = 0

    /// Four looks a second: the pulse arrives about once a second, and a glide moves smoothly.
    nonisolated static let lookMilliseconds = 250
    /// The engine takes a new tempo every other look at most — twice a second, like a followed MIDI
    /// clock — since each one times the song again.
    nonisolated static let looksPerWrite = 2

    func attach(engine: AudioEngine, store: ProjectStore, strap: HeartRateStrap, camera: CameraPulseSource,
                midi: MIDIInput, jam: JamSession, connections: ConnectionsController) {
        self.connections = connections
        self.engine = engine
        self.store = store
        self.strap = strap
        self.camera = camera
        self.midi = midi
        self.jam = jam
    }

    /// Whether Flow can be chosen: neither a jam's host nor a MIDI clock sets the pace.
    var canFlow: Bool {
        midi?.followedSource == nil && jam?.followsJam != true
    }

    /// The musician turned the lock.
    func setLock(_ next: TempoLock) {
        switch next {
        case .flow: open()
        case .fixed: close(keepingTheTempo: true)
        }
    }

    private func open() {
        guard lock == .fixed, canFlow, let engine, let store else { return }
        let project = store.project
        let start = engine.playedTempoMap(of: project).bpm(at: engine.playheadTick(in: project))
        flow.open(at: start)
        guard let tempo = flow.tempo else { return }
        lock = .flow
        generation = store.documentGeneration
        lastLook = ContinuousClock.now
        lastBar = nil
        looksSinceWrite = 0
        engine.flowTempo = tempo
        publishShown()
        DiagnosticLog.app.note("tempo: flow", [("tempo", tempo)])
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Self.lookMilliseconds))
                self?.look()
            }
        }
    }

    /// Back to Fixed. A musician closing the lock keeps where Flow got to as the song's tempo — one
    /// undo step; a jam or a clock taking the pace, or another song, ends Flow and writes nothing.
    private func close(keepingTheTempo keeping: Bool) {
        guard lock == .flow else { return }
        ticker?.cancel()
        ticker = nil
        let kept = flow.close()
        lock = .fixed
        publishShown()
        if keeping, let kept, let store, let engine, store.documentGeneration == generation {
            try? store.perform(.setTempo(bpm: kept))
            store.endGesture()
            // The engine plays the song's new tempo before Flow's goes, so nothing jumps between.
            engine.update(store.project)
        }
        engine?.flowTempo = nil
        if keeping {
            DiagnosticLog.app.note("tempo: fixed", [("tempo", kept ?? 0)])
        } else {
            DiagnosticLog.app.note("tempo: flow off", because: "a clock or another song sets the pace")
        }
    }

    /// One look: the pulse, the song's bar line, the glide; the engine and the views when they moved.
    private func look() {
        guard lock == .flow, let engine, let store else { return }
        guard canFlow, store.documentGeneration == generation else {
            close(keepingTheTempo: false)
            return
        }
        let now = ContinuousClock.now
        let parts = (now - (lastLook ?? now)).components
        lastLook = now
        // An app back from the background may have slept for minutes: the glide ends, nothing more.
        let seconds = Swift.min(1, Double(parts.seconds) + Double(parts.attoseconds) * 1e-18)
        let before = flow.target
        // No pulse handed in is a pulse Flow does not trust: the tempo holds where it is.
        flow.advance(seconds: seconds, pulse: mayFollowThePulse ? measuredPulse : nil)
        // The song's own bar lines, while it plays: one step at each.
        if engine.isPlaying {
            let project = store.project
            let bar = engine.playedMeterMap(of: project).bar(at: engine.playheadTick(in: project))
            if let lastBar, bar != lastBar { flow.bar() }
            lastBar = bar
        } else {
            lastBar = nil
        }
        if let before, let after = flow.target, after != before {
            // T1: every change of where the tempo goes is named, with its source — Flow. The
            // pulse itself is not written: the log is a file the musician can share.
            DiagnosticLog.app.note("tempo: flow step", [("from", before), ("to", after)])
        }
        looksSinceWrite += 1
        if let tempo = flow.tempo, looksSinceWrite >= Self.looksPerWrite,
           Swift.abs((engine.flowTempo ?? 0) - tempo) >= 0.01 {
            looksSinceWrite = 0
            engine.flowTempo = tempo
        }
        publishShown()
    }

    /// The tempo this phone plays leaves it now: a MIDI clock goes out, this phone hosts a jam, or
    /// the OSC connection — which carries the tempo and the beat — is on.
    private var tempoLeaves: Bool {
        if let engine, engine.clock.isSending { return true }
        if let jam, jam.role == .hosting { return true }
        if let connections, connections.isOn(.osc) { return true }
        return false
    }

    /// Whether Flow may follow the pulse now: always while the tempo stays on this device, and
    /// with Share Body Data on while it leaves.
    private var mayFollowThePulse: Bool {
        BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: tempoLeaves, consent: engine?.bodyConsent ?? .off)
    }

    /// The pulse of the body source that is on, while it is measured.
    private var measuredPulse: Double? {
        if let strap, strap.isOn { return strap.beatsPerMinute.map(Double.init) }
        if let camera, camera.isOn { return camera.beatsPerMinute.map(Double.init) }
        return nil
    }

    /// The observed values, each written only when it changed.
    private func publishShown() {
        let tempo = flow.shownTempo
        if tempo != shownTempo { shownTempo = tempo }
        let following = flow.isFollowing
        if following != isFollowing { isFollowing = following }
        let pulse = following ? flow.pulse.map { Int($0.rounded()) } : nil
        if pulse != shownPulse { shownPulse = pulse }
        let target = following ? flow.wanted.map { Int($0.rounded()) } : nil
        if target != shownTarget { shownTarget = target }
        let holds = lock == .flow && !mayFollowThePulse
        if holds != holdsForSharing {
            holdsForSharing = holds
            if holds {
                DiagnosticLog.app.note("tempo: flow holds", because: "the tempo leaves this device and body sharing is off")
            }
        }
    }
}

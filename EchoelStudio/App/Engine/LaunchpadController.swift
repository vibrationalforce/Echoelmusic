import CoreMIDI
import EchoelCore
import EchoelEngine
import Foundation
import Observation
import os

/// A Novation Launchpad as the session's clip grid: tracks across, scenes down, the right-hand
/// column launches scenes, the arrows move the grid over a larger song. Its pads light with the
/// clips — track colour, flashing while queued, pulsing while playing. Found by name whenever
/// one is plugged in; its notes never reach an instrument.
@MainActor
@Observable
final class LaunchpadController {
    /// Names of the Launchpads in use, for the song menu.
    private(set) var connected: [String] = []

    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let midi: MIDIInput
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    /// What one Launchpad's lights last showed; nil until the first frame is sent.
    private struct Output {
        var shown: ClipGrid?
        /// The device's CoreMIDI unique id: whether our MIDI clock is sent to it.
        var id: MIDIUniqueID = 0
        /// Whether its pads flashed and pulsed in the frame last sent.
        var animated = true
        /// What the device may keep from our clock: it keeps flashing to that clock after ours stops.
        var kept = Launchpad.KeptClock()
    }

    @ObservationIgnored private var outputs: [MIDIEndpointRef: Output] = [:]
    /// The fastest tempo each Launchpad may keep from our clock (`Launchpad.KeptClock.bpm`), by its
    /// CoreMIDI unique id, kept on this device across a reconnect and a relaunch: a Launchpad that
    /// stays powered keeps the last clock it heard. One whose power was cut, or that another app has
    /// since sent a slower clock, has let it go, which nothing here can see: its pads stay steady
    /// until a slower clock of ours has run long enough, and for good while ours is never sent to it.
    @ObservationIgnored private var keptTempos: [MIDIUniqueID: Double]
    private static let keptTemposKey = "launchpadKeptClockBPM"
    /// A property list holds no infinity: an unknown tempo is stored as this, which counts the same.
    private static let unknownStoredBPM = 1_000_000.0
    @ObservationIgnored private var trackOffset = 0
    @ObservationIgnored private var sceneOffset = 0
    @ObservationIgnored private var lightTask: Task<Void, Never>?
    /// The light loop's time base.
    @ObservationIgnored private let started = ContinuousClock.now
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    init(store: ProjectStore, engine: AudioEngine, midi: MIDIInput) {
        self.store = store
        self.engine = engine
        self.midi = midi
        keptTempos = Self.storedKeptTempos()
    }

    /// What `keptTempos` held at the last save; an entry that is not a tempo is left out.
    private static func storedKeptTempos() -> [MIDIUniqueID: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: keptTemposKey) ?? [:]
        var tempos: [MIDIUniqueID: Double] = [:]
        for (key, value) in stored {
            guard let id = MIDIUniqueID(key), id != 0, let bpm = value as? Double, !bpm.isNaN else { continue }
            tempos[id] = bpm
        }
        return tempos
    }

    private func saveKeptTempos() {
        var stored: [String: Double] = [:]
        for (id, bpm) in keptTempos { stored[String(id)] = Swift.min(bpm, Self.unknownStoredBPM) }
        UserDefaults.standard.set(stored, forKey: Self.keptTemposKey)
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoelmusic Grid" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.refresh() }
        }
        guard status == noErr, MIDIOutputPortCreate(client, "Echoelmusic Grid Out" as CFString, &port) == noErr else {
            log.error("midi: grid port failed \(status, privacy: .public)")
            return
        }
        midi.onGridPress = { [weak self] press in self?.handle(press) }
        refresh()
    }

    /// Finds the Launchpads: their inputs go to the grid, their outputs get Programmer mode.
    private func refresh() {
        var found: [MIDIEndpointRef: Output] = [:]
        var names: [String] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0, let title = Self.displayName(endpoint), let model = Launchpad.model(named: title) else { continue }
            if let known = outputs[endpoint] {
                found[endpoint] = known
            } else {
                log.info("midi: Launchpad \(title, privacy: .public)")
                send([Launchpad.programmerMode(model)], to: endpoint)
                var id: MIDIUniqueID = 0
                _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
                // A Launchpad seen before may still run the clock it kept then.
                let kept = id == 0 ? Launchpad.KeptClock() : Launchpad.KeptClock(bpm: keptTempos[id])
                found[endpoint] = Output(id: id, kept: kept)
            }
            names.append(title)
        }
        outputs = found
        connected = names
        var sources: Set<MIDIUniqueID> = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0, let title = Self.displayName(endpoint), Launchpad.model(named: title) != nil else { continue }
            var id: MIDIUniqueID = 0
            if MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id) == noErr { sources.insert(id) }
        }
        midi.setGridSources(sources)
        if outputs.isEmpty {
            lightTask?.cancel()
            lightTask = nil
        } else if lightTask == nil {
            lightTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.updateLights()
                    try? await Task.sleep(for: .milliseconds(40))
                }
            }
        }
    }

    private func grid() -> ClipGrid {
        ClipGrid(project: store.project, playing: engine.session.playing, queued: engine.session.queued,
                 trackOffset: trackOffset, sceneOffset: sceneOffset)
    }

    /// Sends each Launchpad only the lights that changed.
    private func updateLights() {
        let now = grid()
        trackOffset = now.trackOffset
        sceneOffset = now.sceneOffset
        // The tempo our clock sends: the song as the engine plays it, a followed clock's or Flow's
        // tempo in place of its own; unknown while a followed clock is not measured yet, or while
        // a timecode paces the song.
        let fastest = Launchpad.clockBPM(playing: engine.playing(store.project),
                                         followsClock: engine.followsExternalClock,
                                         clockTempo: engine.externalTempo, chasesTimecode: engine.timecodeRuns)
        // No pulse leaves while the song is stopped or counts in, or while the engine is down.
        let transportRuns = engine.isRunning && engine.isPlaying && !engine.countsIn
        let renders = engine.renderCount
        let elapsed = ContinuousClock.now - started
        var keptChanged = false
        for (endpoint, output) in outputs {
            // The device flashes to our clock, and after it stops to the last tempo it heard from
            // us: past three a second the pads stay steady.
            var kept = output.kept
            kept.look(clockChosen: engine.clock.chosen.contains(output.id), transportRuns: transportRuns,
                      renderCount: renders, fastestBPM: fastest, now: elapsed)
            if output.id != 0, keptTempos[output.id] != kept.bpm {
                keptTempos[output.id] = kept.bpm
                keptChanged = true
            }
            let animated = Launchpad.animates(keptClockBPM: kept.bpm)
            let previous = animated == output.animated ? output.shown : nil
            let messages = Launchpad.lights(now, previous: previous, animated: animated)
            if !messages.isEmpty { send(messages, to: endpoint) }
            outputs[endpoint] = Output(shown: now, id: output.id, animated: animated, kept: kept)
        }
        if keptChanged { saveKeptTempos() }
    }

    private func handle(_ press: Launchpad.Press) {
        let current = grid()
        switch press {
        case let .pad(column, row):
            guard let slot = current.slot(column: column, row: row) else { return }
            if let clip = store.project.track(slot.track)?.clipInSlot(slot.scene) {
                engine.launch(clip, on: slot.track)
            } else {
                engine.stopClip(on: slot.track)
            }
        case .scene(let row):
            guard let scene = current.scene(row: row) else { return }
            engine.launch(scene, in: store.project)
        case .up: sceneOffset = current.sceneOffset - 1
        case .down: sceneOffset = current.sceneOffset + 1
        case .left: trackOffset = current.trackOffset - 1
        case .right: trackOffset = current.trackOffset + 1
        }
        updateLights()
    }

    /// Sends messages as Universal MIDI Packets, one packet per event list, in order.
    private func send(_ messages: [[UInt8]], to endpoint: MIDIEndpointRef) {
        for message in messages {
            for packetWords in UniversalMIDI.packets(message) {
                var words = packetWords
                var list = MIDIEventList()
                withUnsafeMutablePointer(to: &list) { pointer in
                    let packet = MIDIEventListInit(pointer, ._1_0)
                    _ = MIDIEventListAdd(pointer, MemoryLayout<MIDIEventList>.size, packet, 0, words.count, &words)
                    MIDISendEventList(port, endpoint, pointer)
                }
            }
        }
    }

    private static func displayName(_ endpoint: MIDIEndpointRef) -> String? {
        var name: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }
}

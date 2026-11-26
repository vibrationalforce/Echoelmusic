import CoreMIDI
import EchoelCore
import EchoelEngine
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
        /// The fastest tempo the device may keep from our clock, nil while our clock never could
        /// have reached it (`Launchpad.keptClockBPM`): it keeps flashing to that clock after ours stops.
        var keptClockBPM: Double?
    }

    @ObservationIgnored private var outputs: [MIDIEndpointRef: Output] = [:]
    @ObservationIgnored private var trackOffset = 0
    @ObservationIgnored private var sceneOffset = 0
    @ObservationIgnored private var lightTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    init(store: ProjectStore, engine: AudioEngine, midi: MIDIInput) {
        self.store = store
        self.engine = engine
        self.midi = midi
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
                found[endpoint] = Output(id: id)
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
        let project = store.project
        let fastest = project.tempoChanges.reduce(project.tempo) { Swift.max($0, $1.bpm) }
        // Our clock's pulses leave only while the song plays: none while stopped or counting in.
        let clockRuns = engine.isPlaying && !engine.countsIn
        for (endpoint, output) in outputs {
            // The device flashes to our clock, and after it stops to the last tempo it heard from
            // us: past three a second the pads stay steady.
            let chosen = engine.clock.chosen.contains(output.id)
            let kept = Launchpad.keptClockBPM(previous: output.keptClockBPM, clockChosen: chosen,
                                              clockRunning: clockRuns, fastestBPM: fastest)
            let animated = Launchpad.animates(keptClockBPM: kept)
            let previous = animated == output.animated ? output.shown : nil
            let messages = Launchpad.lights(now, previous: previous, animated: animated)
            if !messages.isEmpty { send(messages, to: endpoint) }
            outputs[endpoint] = Output(shown: now, id: output.id, animated: animated, keptClockBPM: kept)
        }
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

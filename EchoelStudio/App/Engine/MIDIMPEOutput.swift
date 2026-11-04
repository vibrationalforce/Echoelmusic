import CoreMIDI
import Darwin
import EchoelCore
import EchoelEngine
import Foundation
import Observation
import Synchronization
import os

/// MPE out (wave W5b): the live track's notes go to the outputs the musician picked as an MPE
/// lower zone — every note on a member channel of its own, so a receiving MPE synth (in AUM, a
/// Seaboard-class synth, an MPE track in a DAW) bends, presses and slides each note apart. The
/// body sets two of the three per-note dimensions: pressure and slide follow the modulation
/// sources chosen here (breath and coherence until changed), absent sources send nothing.
///
/// Off until an output is chosen in the Song menu; then the engine times the live track's notes
/// (`EngineCore.setNoteOut(slot:)`) and a 2 ms pump here turns them into zone messages with
/// `MPEZone` and schedules them at their host time plus the output latency, like the MIDI clock.
/// Per-note pitch bend is stated (centred) at every note-on; nothing in Studio bends a single
/// note yet, and a track's pitch-bend lane goes to the master channel, which bends the zone.
/// This is MPE OUT only — Studio reads no MPE zone from an input.
///
/// A second source, off by default (Song menu, Connect, "MIDI 2.0 Out (UMP)"): a virtual
/// source "Echoel MPE (MIDI 2.0)" that sends the same zone over the MIDI 2.0 protocol, values
/// scaled up and each note's bend as its per-note pitch bend (`MIDI2Translator`). The MIDI 1.0
/// output above is untouched by it. No MIDI-CI, no Property Exchange: the receiver must be set
/// to MIDI 2.0 by hand.
@MainActor
@Observable
final class MIDIMPEOutput {
    struct Destination: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
    }

    /// What the body may drive: the modulation sources that measure it.
    static let bodySources: [ModulationSource] = [.breath, .coherence, .hrv, .heartRate]

    private(set) var destinations: [Destination] = []
    /// Chosen outputs, by CoreMIDI unique id; kept on this device.
    private(set) var chosen: Set<MIDIUniqueID>
    /// The source pressure follows, nil for none; kept on this device.
    private(set) var pressureSource: ModulationSource?
    /// The source slide (CC 74) follows, nil for none; kept on this device.
    private(set) var slideSource: ModulationSource?
    private(set) var lastError: String?
    /// The MIDI 2.0 source is on; kept on this device.
    private(set) var midi2Enabled: Bool

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var midi2Source = MIDIEndpointRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private let pump = MPEPump()
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private var slot: Int?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    private static let destinationsKey = "midi.mpeOut.destinations"
    private static let pressureKey = "midi.mpeOut.pressure"
    private static let slideKey = "midi.mpeOut.slide"
    private static let midi2Key = "midi.ump.out"

    init() {
        let defaults = UserDefaults.standard
        let stored = defaults.array(forKey: Self.destinationsKey) as? [Int] ?? []
        chosen = Set(stored.map { MIDIUniqueID(truncatingIfNeeded: $0) })
        pressureSource = Self.source(defaults.string(forKey: Self.pressureKey), default: .breath)
        slideSource = Self.source(defaults.string(forKey: Self.slideKey), default: .coherence)
        midi2Enabled = defaults.bool(forKey: Self.midi2Key)
        pump.setSources(pressure: pressureSource, slide: slideSource)
    }

    /// A stored name: "" is none, a name this build does not know falls back to the default.
    private static func source(_ stored: String?, default fallback: ModulationSource) -> ModulationSource? {
        guard let stored else { return fallback }
        if stored.isEmpty { return nil }
        return ModulationSource(rawValue: stored) ?? fallback
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoel MPE" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.refresh() }
        }
        guard status == noErr else { return fail("client", status) }
        let portStatus = MIDIOutputPortCreate(client, "Echoel MPE Out" as CFString, &port)
        guard portStatus == noErr else { return fail("port", portStatus) }
        pump.start(port: port)
        if midi2Enabled { openMIDI2Source() }
        refresh()
    }

    /// Switches the MIDI 2.0 source on or off. Off, every note it started ends first and the
    /// source goes away; the MIDI 1.0 outputs are not touched either way.
    func setMIDI2(_ on: Bool) {
        guard on != midi2Enabled else { return }
        midi2Enabled = on
        UserDefaults.standard.set(on, forKey: Self.midi2Key)
        guard client != 0 else { return }
        if on {
            openMIDI2Source()
        } else if midi2Source != 0 {
            pump.closeMIDI2Source()
            midi2Source = MIDIEndpointRef()
        }
        applySlot()
    }

    private func openMIDI2Source() {
        guard midi2Source == 0 else { return }
        var source = MIDIEndpointRef()
        let status = MIDISourceCreateWithProtocol(client, "Echoel MPE (MIDI 2.0)" as CFString, ._2_0, &source)
        guard status == noErr else { return fail("midi 2.0 source", status) }
        midi2Source = source
        pump.openMIDI2Source(source)
        log.info("mpe out: MIDI 2.0 source on")
    }

    /// The core whose notes are sent, its rate, how long after its render call a frame is heard,
    /// and the live body values.
    func attach(_ core: EngineCore, sampleRate: Double, latency: TimeInterval, modulation: ModulationInputs) {
        self.core = core
        pump.set(core: core, sampleRate: sampleRate, latency: latency, modulation: modulation)
        applySlot()
    }

    /// The slot of the track whose notes go out: the live track.
    func setSlot(_ slot: Int?) {
        guard slot != self.slot else { return }
        self.slot = slot
        applySlot()
    }

    func isChosen(_ destination: Destination) -> Bool { chosen.contains(destination.id) }

    func toggle(_ destination: Destination) {
        if chosen.contains(destination.id) { chosen.remove(destination.id) } else { chosen.insert(destination.id) }
        UserDefaults.standard.set(chosen.map { Int($0) }, forKey: Self.destinationsKey)
        refresh()
    }

    func setPressure(_ source: ModulationSource?) {
        pressureSource = source
        UserDefaults.standard.set(source?.rawValue ?? "", forKey: Self.pressureKey)
        pump.setSources(pressure: pressureSource, slide: slideSource)
    }

    func setSlide(_ source: ModulationSource?) {
        slideSource = source
        UserDefaults.standard.set(source?.rawValue ?? "", forKey: Self.slideKey)
        pump.setSources(pressure: pressureSource, slide: slideSource)
    }

    static func title(_ source: ModulationSource?) -> String {
        switch source {
        case .breath: "Breath"
        case .coherence: "Coherence"
        case .hrv: "HRV"
        case .heartRate: "Heart Rate"
        case .some: "Other"
        case nil: "Off"
        }
    }

    /// Lists every destination and hands the chosen ones that exist to the pump.
    private func refresh() {
        var found: [Destination] = []
        var endpoints: [MIDIEndpointRef] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { continue }
            var id: MIDIUniqueID = 0
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id) == noErr else { continue }
            var name: Unmanaged<CFString>?
            let title = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr
                ? (name?.takeRetainedValue() as String?) ?? "MIDI Out" : "MIDI Out"
            found.append(Destination(id: id, name: title))
            if chosen.contains(id) { endpoints.append(endpoint) }
        }
        destinations = found
        pump.setEndpoints(endpoints)
        applySlot()
    }

    /// The engine times the slot's notes only while an output can hear them.
    private func applySlot() {
        core?.setNoteOut(slot: pump.hasNoOutput ? nil : slot)
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("mpe out: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "MPE out is not available (\(status))."
    }
}

/// The background half: drains the core's note ring every 2 ms, spreads it over the zone with
/// `MPEZone`, follows the body's pressure and slide, and schedules each message with a CoreMIDI
/// timestamp. Never touches the main actor.
final class MPEPump: Sendable {
    private struct State: @unchecked Sendable {
        var core: EngineCore?
        var modulation: ModulationInputs?
        var sampleRate: Double = 48_000
        var latency: TimeInterval = 0
        var endpoints: [MIDIEndpointRef] = []
        var port = MIDIPortRef()
        var zone = MPEZone()
        var pressure: ModulationSource?
        var slide: ModulationSource?
        /// The MIDI 2.0 source and its translator, both only while it is on.
        var midi2Source = MIDIEndpointRef()
        var midi2: MIDI2Translator?

        var hasOutput: Bool { !endpoints.isEmpty || midi2Source != 0 }
    }

    /// Messages for some endpoints, at one host time (0: now), and the same messages as MIDI 2.0
    /// words for the MIDI 2.0 source (nil: not for it).
    private struct Batch {
        var endpoints: [MIDIEndpointRef]
        var time: MIDITimeStamp
        var messages: [MPEZone.Message]
        var midi2Source = MIDIEndpointRef()
        var midi2Words: [UInt32]?
    }

    private let state = Mutex(State())
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.mpe", qos: .userInteractive)
    /// Runs only while an output is chosen. Set from the main actor only (`start`, `setEndpoints`).
    nonisolated(unsafe) private var timer: DispatchSourceTimer?
    private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    /// Neither a chosen output nor the MIDI 2.0 source.
    var hasNoOutput: Bool { state.withLock { !$0.hasOutput } }

    func start(port: MIDIPortRef) {
        state.withLock { $0.port = port }
        runWhileChosen()
    }

    func set(core: EngineCore, sampleRate: Double, latency: TimeInterval, modulation: ModulationInputs) {
        state.withLock {
            $0.core = core
            $0.modulation = modulation
            $0.sampleRate = sampleRate > 0 ? sampleRate : 48_000
            $0.latency = Swift.max(0, latency.isFinite ? latency : 0)
        }
    }

    func setSources(pressure: ModulationSource?, slide: ModulationSource?) {
        state.withLock {
            $0.pressure = pressure
            $0.slide = slide
        }
    }

    /// A newly chosen output hears the zone announced first; one let go hears every note end.
    func setEndpoints(_ endpoints: [MIDIEndpointRef]) {
        let batches = state.withLock { (current: inout State) -> [Batch] in
            let added = endpoints.filter { !current.endpoints.contains($0) }
            let removed = current.endpoints.filter { !endpoints.contains($0) }
            var out: [Batch] = []
            if !removed.isEmpty {
                var copy = current.zone
                out.append(Batch(endpoints: removed, time: 0, messages: copy.allNotesOff()))
            }
            if !added.isEmpty {
                out.append(Batch(endpoints: added, time: 0, messages: current.zone.configuration()))
            }
            if endpoints.isEmpty, current.midi2Source == 0 { _ = current.zone.allNotesOff() }
            current.endpoints = endpoints
            return out
        }
        let port = state.withLock { $0.port }
        for batch in batches { send(batch, port: port) }
        runWhileChosen()
    }

    /// The MIDI 2.0 source opens: it hears the zone announced (as MIDI 2.0 RPNs) first.
    func openMIDI2Source(_ source: MIDIEndpointRef) {
        let batch = state.withLock { (current: inout State) -> Batch in
            current.midi2Source = source
            var translator: MIDI2Translator? = MIDI2Translator()
            let words = MPEOutputWords.midi2(current.zone.configuration(), translator: &translator)
            current.midi2 = translator
            return Batch(endpoints: [], time: 0, messages: [], midi2Source: source, midi2Words: words)
        }
        send(batch, port: 0)
        runWhileChosen()
    }

    /// The MIDI 2.0 source closes: every note it sounds ends on it, then it is disposed on the
    /// pump's queue, after any drain that still holds it.
    func closeMIDI2Source() {
        let (batch, source) = state.withLock { (current: inout State) -> (Batch, MIDIEndpointRef) in
            let source = current.midi2Source
            var copy = current.zone
            let offs = copy.allNotesOff()
            let words = MPEOutputWords.midi2(offs, translator: &current.midi2)
            if current.endpoints.isEmpty { _ = current.zone.allNotesOff() }
            current.midi2Source = MIDIEndpointRef()
            current.midi2 = nil
            return (Batch(endpoints: [], time: 0, messages: [], midi2Source: source, midi2Words: words), source)
        }
        send(batch, port: 0)
        if source != 0 { queue.async { MIDIEndpointDispose(source) } }
        runWhileChosen()
    }

    private func runWhileChosen() {
        let (chosen, hasPort) = state.withLock { ($0.hasOutput, $0.port != 0) }
        if chosen, hasPort, timer == nil {
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(500))
            source.setEventHandler { @Sendable [weak self] in self?.drain() }
            source.resume()
            timer = source
        } else if !chosen, let running = timer {
            running.cancel()
            timer = nil
            // What the ring still holds has nobody to hear it.
            queue.async { [weak self] in self?.drain() }
        }
    }

    private func drain() {
        let (batches, port) = state.withLock { (current: inout State) -> ([Batch], MIDIPortRef) in
            guard let core = current.core else { return ([], current.port) }
            var out: [Batch] = []
            while let message = core.noteOut.pop() {
                guard current.hasOutput else { continue }
                let messages = Self.translate(message, zone: &current.zone)
                guard !messages.isEmpty else { continue }
                let time = timestamp(message, sampleRate: current.sampleRate, latency: current.latency)
                let words = MPEOutputWords.midi2(messages, translator: &current.midi2)
                out.append(Batch(endpoints: current.endpoints, time: time, messages: messages,
                                 midi2Source: current.midi2Source, midi2Words: words))
            }
            if current.hasOutput, let modulation = current.modulation {
                var expression: [MPEZone.Message] = []
                // Only a value that may leave the device: an Apple Health reading never goes out (REC-1).
                if let source = current.pressure { expression += current.zone.setPressure(modulation.shareableValue(source)) }
                if let source = current.slide { expression += current.zone.setSlide(modulation.shareableValue(source)) }
                if !expression.isEmpty {
                    let words = MPEOutputWords.midi2(expression, translator: &current.midi2)
                    out.append(Batch(endpoints: current.endpoints, time: 0, messages: expression,
                                     midi2Source: current.midi2Source, midi2Words: words))
                }
            }
            return (out, current.port)
        }
        for batch in batches { send(batch, port: port) }
    }

    /// One channel message of the live track, as the zone plays it.
    private static func translate(_ message: TimedMIDIMessage, zone: inout MPEZone) -> [MPEZone.Message] {
        switch message.status & 0xF0 {
        case 0x90 where message.data2 > 0: return zone.noteOn(pitch: message.data1, velocity: message.data2)
        case 0x80, 0x90: return zone.noteOff(pitch: message.data1)
        case 0xE0: return zone.masterBend(Int(message.data1) | Int(message.data2) << 7)
        case 0xB0 where message.data1 == 123 || message.data1 == 120: return zone.allNotesOff()
        // The wheel, the pedal and every other controller reach the whole zone on its master.
        case 0xB0: return [MPEZone.Message(0xB0 | MPEZone.masterChannel, message.data1, message.data2)]
        default: return []
        }
    }

    /// Universal MIDI Packets, message type 2 (MIDI 1.0 channel voice), in order, 32 words to a
    /// list (`MIDIEventList` holds one packet of 64); then, for the MIDI 2.0 source, its words.
    private func send(_ batch: Batch, port: MIDIPortRef) {
        if let words = batch.midi2Words, batch.midi2Source != 0, !words.isEmpty {
            sendMIDI2(words, time: batch.time, source: batch.midi2Source)
        }
        guard port != 0, !batch.endpoints.isEmpty else { return }
        let words = MPEOutputWords.midi1(batch.messages)
        var start = 0
        while start < words.count {
            var chunk = Array(words[start..<Swift.min(start + 32, words.count)])
            var list = MIDIEventList()
            withUnsafeMutablePointer(to: &list) { pointer in
                let packet = MIDIEventListInit(pointer, ._1_0)
                _ = MIDIEventListAdd(pointer, MemoryLayout<MIDIEventList>.size, packet, batch.time, chunk.count, &chunk)
                for endpoint in batch.endpoints { MIDISendEventList(port, endpoint, pointer) }
            }
            start += chunk.count
        }
    }

    /// Message type 4 (MIDI 2.0 channel voice, two words each), 32 words to a list, received
    /// from the virtual source by whoever listens to it.
    private func sendMIDI2(_ words: [UInt32], time: MIDITimeStamp, source: MIDIEndpointRef) {
        var start = 0
        while start + 1 < words.count {
            var chunk = Array(words[start..<Swift.min(start + 32, words.count)])
            var list = MIDIEventList()
            withUnsafeMutablePointer(to: &list) { pointer in
                let packet = MIDIEventListInit(pointer, ._2_0)
                _ = MIDIEventListAdd(pointer, MemoryLayout<MIDIEventList>.size, packet, time, chunk.count, &chunk)
                MIDIReceivedEventList(source, pointer)
            }
            start += chunk.count
        }
    }

    /// When the frame is heard, in host ticks; 0 (now) for a message without a host time.
    private func timestamp(_ message: TimedMIDIMessage, sampleRate: Double, latency: TimeInterval) -> MIDITimeStamp {
        guard message.hostTime > 0 else { return 0 }
        let nanos = (Double(message.frame) / sampleRate + latency) * 1e9
        let ticks = nanos * Double(timebase.denom) / Double(timebase.numer)
        guard ticks.isFinite, ticks >= 0 else { return message.hostTime }
        return message.hostTime &+ MIDITimeStamp(ticks)
    }
}

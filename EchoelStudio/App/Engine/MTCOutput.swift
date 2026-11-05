import CoreMIDI
import Darwin
import EchoelEngine
import Foundation
import Observation
import Synchronization
import os

/// MIDI Time Code out (W17-TC): a lighting desk, QLab, Reaper or a video player follows the song
/// as SMPTE timecode — quarter frames while it plays, a full frame at a start, a locate and a
/// stop. Off until switched on in the Song menu (Connect, Timecode). The render thread times every
/// message from the engine's sample counter (`EngineCore.timecodeOut`); a 2 ms pump here only
/// schedules them at their host time plus the output latency, as the MIDI clock does. Out through
/// a virtual source, "Echoel Timecode", that any app on the device can listen to, and through the
/// outputs picked. The rate and the start (01:00:00:00 by default, where the EDL starts) are kept
/// on this device; the chase reads the same start.
@MainActor
@Observable
final class MTCOutput {
    struct Destination: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
    }

    private(set) var isOn: Bool
    private(set) var rate: MTCRate
    /// The hour the song's first sample is labelled with: HH:00:00:00.
    private(set) var startHour: Int
    private(set) var destinations: [Destination] = []
    private(set) var chosen: Set<MIDIUniqueID>
    private(set) var lastError: String?

    static let rates: [MTCRate] = [.fps24, .fps25, .fps29_97DropFrame, .fps30]
    static let hours = Array(0..<24)

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var source = MIDIEndpointRef()
    @ObservationIgnored private let pump = TimecodePump()
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    private static let onKey = "mtc.out.on"
    private static let rateKey = "mtc.rate"
    private static let hourKey = "mtc.startHour"
    private static let destinationsKey = "mtc.out.destinations"

    init() {
        let defaults = UserDefaults.standard
        isOn = defaults.bool(forKey: Self.onKey)
        rate = (defaults.object(forKey: Self.rateKey) as? Int).flatMap(MTCRate.init(rawValue:)) ?? .fps25
        let hour = defaults.object(forKey: Self.hourKey) as? Int ?? 1
        startHour = (0..<24).contains(hour) ? hour : 1
        let stored = defaults.array(forKey: Self.destinationsKey) as? [Int] ?? []
        chosen = Set(stored.map { MIDIUniqueID(truncatingIfNeeded: $0) })
    }

    /// The label of the song's first sample.
    var start: Timecode { Timecode(hours: startHour, minutes: 0, seconds: 0, frames: 0) }

    /// The core whose timecode is sent, its rate, and how long after its render call a frame is heard.
    func attach(_ core: EngineCore, sampleRate: Double, latency: TimeInterval) {
        self.core = core
        pump.set(core: core, sampleRate: sampleRate, latency: latency)
        apply()
    }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        UserDefaults.standard.set(on, forKey: Self.onKey)
        if on { open() } else { close() }
        apply()
    }

    func setRate(_ rate: MTCRate) {
        self.rate = rate
        UserDefaults.standard.set(rate.rawValue, forKey: Self.rateKey)
        apply()
    }

    func setStartHour(_ hour: Int) {
        guard (0..<24).contains(hour) else { return }
        startHour = hour
        UserDefaults.standard.set(hour, forKey: Self.hourKey)
        apply()
    }

    func isChosen(_ destination: Destination) -> Bool { chosen.contains(destination.id) }

    func toggle(_ destination: Destination) {
        if chosen.contains(destination.id) { chosen.remove(destination.id) } else { chosen.insert(destination.id) }
        UserDefaults.standard.set(chosen.map { Int($0) }, forKey: Self.destinationsKey)
        refresh()
    }

    /// At launch: what was on stays on.
    func begin() {
        if isOn { open() }
        apply()
    }

    /// The client, the port and the virtual source — made only when MTC out is switched on.
    private func open() {
        if client == 0 {
            let status = MIDIClientCreateWithBlock("Echoel Timecode" as CFString, &client) { @Sendable notification in
                guard notification.pointee.messageID == .msgSetupChanged else { return }
                Task { @MainActor [weak self] in self?.refresh() }
            }
            guard status == noErr else { return fail("client", status) }
            let portStatus = MIDIOutputPortCreate(client, "Echoel Timecode Out" as CFString, &port)
            guard portStatus == noErr else { return fail("port", portStatus) }
        }
        if source == 0 {
            var made = MIDIEndpointRef()
            let status = MIDISourceCreateWithProtocol(client, "Echoel Timecode" as CFString, ._1_0, &made)
            guard status == noErr else { return fail("source", status) }
            source = made
        }
        lastError = nil
        pump.open(port: port, source: source)
        refresh()
        log.info("mtc out: on")
    }

    private func close() {
        pump.close()
        if source != 0 {
            MIDIEndpointDispose(source)
            source = MIDIEndpointRef()
        }
        log.info("mtc out: off")
    }

    /// Tells the render thread what to time, or nothing while it is off.
    private func apply() {
        let frames = start.frameCount(rate: rate) ?? 0
        core?.setTimecodeOut(rate: isOn ? rate : nil, startFrames: frames)
    }

    /// Lists every destination and hands the chosen ones that exist to the pump.
    private func refresh() {
        guard client != 0 else { return }
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
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("mtc out: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "Timecode is not available (\(status))."
    }
}

/// The background half: drains the core's timecode ring every 2 ms while MTC out is on and sends
/// each message with a CoreMIDI timestamp — quarter frames as one system-common word, a full frame
/// as two System Exclusive packets. No array is made per message. Never touches the main actor.
final class TimecodePump: Sendable {
    private struct State: @unchecked Sendable {
        var core: EngineCore?
        var sampleRate: Double = 48_000
        var latency: TimeInterval = 0
        var endpoints: [MIDIEndpointRef] = []
        var port = MIDIPortRef()
        var source = MIDIEndpointRef()
    }

    private let state = Mutex(State())
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.timecode", qos: .userInteractive)
    /// Set from the main actor only (`open`, `close`).
    nonisolated(unsafe) private var timer: DispatchSourceTimer?
    private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    func set(core: EngineCore, sampleRate: Double, latency: TimeInterval) {
        state.withLock {
            $0.core = core
            $0.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
            $0.latency = Swift.max(0, latency.isFinite ? latency : 0)
        }
    }

    func setEndpoints(_ endpoints: [MIDIEndpointRef]) {
        state.withLock { $0.endpoints = endpoints }
    }

    func open(port: MIDIPortRef, source: MIDIEndpointRef) {
        state.withLock {
            $0.port = port
            $0.source = source
        }
        guard timer == nil else { return }
        let made = DispatchSource.makeTimerSource(queue: queue)
        made.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(500))
        made.setEventHandler { @Sendable [weak self] in self?.drain() }
        made.resume()
        timer = made
    }

    func close() {
        timer?.cancel()
        timer = nil
        state.withLock { $0.source = MIDIEndpointRef() }
        // What the ring still holds has nobody to hear it.
        queue.async { [weak self] in self?.drain() }
    }

    private func drain() {
        let current = state.withLock { $0 }
        guard let core = current.core else { return }
        while let message = core.timecodeOut.pop() {
            guard current.source != 0 || !current.endpoints.isEmpty else { continue }
            let time = timestamp(message, sampleRate: current.sampleRate, latency: current.latency)
            var words: (UInt32, UInt32, UInt32, UInt32)
            let count: Int
            if let full = message.fullFrame {
                words = full.universalPackets
                count = 4
            } else {
                // A Universal MIDI Packet, message type 1: system common, F1 and its data byte.
                words = (UInt32(0x1) << 28 | UInt32(MTCQuarterFrame.status) << 16 | UInt32(message.data & 0x7F) << 8, 0, 0, 0)
                count = 1
            }
            withUnsafeMutableBytes(of: &words) { raw in
                guard let base = raw.bindMemory(to: UInt32.self).baseAddress else { return }
                var list = MIDIEventList()
                withUnsafeMutablePointer(to: &list) { pointer in
                    let packet = MIDIEventListInit(pointer, ._1_0)
                    _ = MIDIEventListAdd(pointer, MemoryLayout<MIDIEventList>.size, packet, time, count, base)
                    for endpoint in current.endpoints { MIDISendEventList(current.port, endpoint, pointer) }
                    if current.source != 0 { MIDIReceivedEventList(current.source, pointer) }
                }
            }
        }
    }

    /// When the frame is heard, in host ticks; 0 (now) for a message without a host time.
    private func timestamp(_ message: TimecodeMessage, sampleRate: Double, latency: TimeInterval) -> MIDITimeStamp {
        guard message.hostTime > 0 else { return 0 }
        let nanos = (Double(message.frame) / sampleRate + latency) * 1e9
        let ticks = nanos * Double(timebase.denom) / Double(timebase.numer)
        guard ticks.isFinite, ticks >= 0, ticks < 1e15 else { return message.hostTime }
        return message.hostTime &+ MIDITimeStamp(ticks)
    }
}

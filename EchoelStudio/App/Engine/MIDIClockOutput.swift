import CoreMIDI
import Darwin
import EchoelEngine
import Foundation
import Observation
import Synchronization
import os

/// Sends the engine's MIDI clock to the outputs the musician picked — a DJ mixer's effects, a
/// drum machine, another app — so they follow Echoel's tempo and transport. The render thread
/// times every message; a 2 ms pump here only schedules them, at their host time plus the
/// output latency, so the clock lands with the sound, not with the pump.
@MainActor
@Observable
final class MIDIClockOutput {
    struct Destination: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
    }

    private(set) var destinations: [Destination] = []
    /// Chosen outputs, by CoreMIDI unique id; kept on this device across songs.
    private(set) var chosen: Set<MIDIUniqueID>
    private(set) var lastError: String?
    /// Milliseconds the clock is sent late (+) or early (−) against the sound, for a device that
    /// reacts slower or faster than it should; kept on this device.
    private(set) var offsetMilliseconds: Double
    static let offsetChoices: [Double] = [-20, -10, -5, -2, 0, 2, 5, 10, 20, 40]

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private let pump = ClockPump()
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    private static let defaultsKey = "midi.clockOut.destinations"
    private static let offsetKey = "midi.clockOut.offset"

    init() {
        let stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Int] ?? []
        chosen = Set(stored.map { MIDIUniqueID(truncatingIfNeeded: $0) })
        offsetMilliseconds = UserDefaults.standard.double(forKey: Self.offsetKey)
        pump.setOffset(offsetMilliseconds / 1000)
    }

    func setOffset(milliseconds: Double) {
        guard milliseconds.isFinite else { return }
        offsetMilliseconds = milliseconds
        UserDefaults.standard.set(milliseconds, forKey: Self.offsetKey)
        pump.setOffset(milliseconds / 1000)
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoel Clock" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.refresh() }
        }
        guard status == noErr else { return fail("client", status) }
        let portStatus = MIDIOutputPortCreate(client, "Echoel Clock Out" as CFString, &port)
        guard portStatus == noErr else { return fail("port", portStatus) }
        pump.start(port: port)
        refresh()
    }

    /// The core whose clock is sent, its rate, and how long after its render call a frame is heard.
    func attach(_ core: EngineCore, sampleRate: Double, latency: TimeInterval) {
        self.core = core
        pump.set(core: core, sampleRate: sampleRate, latency: latency)
        core.setClockOutEnabled(!pump.endpointsAreEmpty)
    }

    func isChosen(_ destination: Destination) -> Bool { chosen.contains(destination.id) }

    func toggle(_ destination: Destination) {
        if chosen.contains(destination.id) { chosen.remove(destination.id) } else { chosen.insert(destination.id) }
        UserDefaults.standard.set(chosen.map { Int($0) }, forKey: Self.defaultsKey)
        refresh()
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
        core?.setClockOutEnabled(!endpoints.isEmpty)
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("midi clock: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "MIDI clock is not available (\(status))."
    }
}

/// The background half: drains the core's clock ring every 2 ms and schedules each message
/// with a CoreMIDI timestamp. Never touches the main actor.
final class ClockPump: Sendable {
    private struct State: @unchecked Sendable {
        var core: EngineCore?
        var sampleRate: Double = 48_000
        var latency: TimeInterval = 0
        var offset: TimeInterval = 0
        var endpoints: [MIDIEndpointRef] = []
        var port = MIDIPortRef()
    }

    private let state = Mutex(State())
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.clock", qos: .userInteractive)
    /// Set once from `start`, then only kept alive.
    nonisolated(unsafe) private var timer: DispatchSourceTimer?
    /// Host ticks per nanosecond, as a ratio.
    private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    var endpointsAreEmpty: Bool { state.withLock { $0.endpoints.isEmpty } }

    func start(port: MIDIPortRef) {
        state.withLock { $0.port = port }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(500))
        source.setEventHandler { @Sendable [weak self] in self?.drain() }
        source.resume()
        timer = source
    }

    func set(core: EngineCore, sampleRate: Double, latency: TimeInterval) {
        state.withLock {
            $0.core = core
            $0.sampleRate = sampleRate > 0 ? sampleRate : 48_000
            $0.latency = Swift.max(0, latency.isFinite ? latency : 0)
        }
    }

    /// Bounded so a stored value can never schedule a clock seconds away.
    func setOffset(_ seconds: TimeInterval) {
        let bounded = seconds.isFinite ? Swift.min(Swift.max(seconds, -0.05), 0.1) : 0
        state.withLock { $0.offset = bounded }
    }

    func setEndpoints(_ endpoints: [MIDIEndpointRef]) {
        state.withLock { $0.endpoints = endpoints }
    }

    private func drain() {
        let current = state.withLock { $0 }
        guard let core = current.core else { return }
        while let message = core.clockOut.pop() {
            guard !current.endpoints.isEmpty else { continue }
            let time = timestamp(message, sampleRate: current.sampleRate, latency: current.latency + current.offset)
            // A Universal MIDI Packet, message type 1: system common and real-time.
            let word = UInt32(0x1) << 28 | UInt32(message.status) << 16 | UInt32(message.data1) << 8
                | UInt32(message.data2)
            var list = MIDIEventList()
            var words = [word]
            withUnsafeMutablePointer(to: &list) { pointer in
                let packet = MIDIEventListInit(pointer, ._1_0)
                _ = MIDIEventListAdd(pointer, MemoryLayout<MIDIEventList>.size, packet, time, 1, &words)
                for endpoint in current.endpoints { MIDISendEventList(current.port, endpoint, pointer) }
            }
        }
    }

    /// When the frame is heard, in host ticks; 0 (now) for a message without a host time.
    private func timestamp(_ message: TimedMIDIMessage, sampleRate: Double, latency: TimeInterval) -> MIDITimeStamp {
        guard message.hostTime > 0 else { return 0 }
        let nanos = (Double(message.frame) / sampleRate + latency) * 1e9
        let ticks = nanos * Double(timebase.denom) / Double(timebase.numer)
        // Early beyond the render call means now: CoreMIDI sends a past timestamp at once.
        guard ticks > 0 else { return message.hostTime }
        return message.hostTime &+ MIDITimeStamp(ticks)
    }
}

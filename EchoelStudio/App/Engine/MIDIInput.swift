import CoreMIDI
import Darwin
import EchoelCore
import EchoelEngine
import Observation
import Synchronization
import os

/// Where live MIDI goes: the engine core that is playing and the slot of the track that plays
/// along. Read on the MIDI thread, written on the main thread.
final class LiveRouter: Sendable {
    private struct Target: @unchecked Sendable {
        var core: EngineCore?
        var slot: Int?
    }

    private let target = Mutex(Target())

    func set(core: EngineCore?, slot: Int?) {
        target.withLock { $0 = Target(core: core, slot: slot) }
    }

    /// MIDI thread.
    func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        let (core, slot) = target.withLock { ($0.core, $0.slot) }
        guard let core, let slot else { return }
        core.playLive(slot: slot, status: status, data1, data2)
    }
}

/// Controller moves waiting for the main thread: the latest value per control, and at most one
/// hop to the main actor in flight however fast a knob turns.
final class ControlInbox: Sendable {
    private let latest = Mutex<[MIDIControl: UInt8]>([:])
    private let scheduled = Atomic<Bool>(false)

    /// MIDI thread. True when the main thread must be asked to drain.
    func post(_ control: MIDIControl, _ value: UInt8) -> Bool {
        latest.withLock { $0[control] = value }
        return !scheduled.exchange(true, ordering: .acquiringAndReleasing)
    }

    /// Main thread.
    func take() -> [MIDIControl: UInt8] {
        scheduled.store(false, ordering: .releasing)
        return latest.withLock { values in
            defer { values.removeAll(keepingCapacity: true) }
            return values
        }
    }
}

/// Clock and transport messages from the followed source, waiting for the main thread, each
/// with the host time it arrived. At most one hop to the main actor in flight.
final class ClockInbox: Sendable {
    struct Message: Sendable {
        var status: UInt8
        var data1: UInt8
        var data2: UInt8
        var hostTime: UInt64
    }

    /// The connection tag of the source to follow; 0 follows none.
    let followed = Atomic<Int>(0)
    private let waiting = Mutex<[Message]>([])
    private let scheduled = Atomic<Bool>(false)

    /// MIDI thread. True when the main thread must be asked to drain.
    func post(_ message: Message) -> Bool {
        waiting.withLock { $0.append(message) }
        return !scheduled.exchange(true, ordering: .acquiringAndReleasing)
    }

    /// Main thread.
    func take() -> [Message] {
        scheduled.store(false, ordering: .releasing)
        return waiting.withLock { messages in
            defer { messages.removeAll(keepingCapacity: true) }
            return messages
        }
    }
}

/// Every MIDI source on the device — USB and Bluetooth controllers, network sessions, other
/// apps' virtual ports — connected to one input port. Notes go to the live track; controllers
/// move the parameters the song mapped them to, or are learned; sources that appear later are
/// connected when they do.
@MainActor
@Observable
final class MIDIInput {
    struct Source: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
    }

    private(set) var sourceNames: [String] = []
    private(set) var sources: [Source] = []
    /// The source whose MIDI clock drives tempo and transport; kept on this device.
    private(set) var followedSource: MIDIUniqueID?
    /// The tempo the followed clock runs at, once known.
    private(set) var clockTempo: Double?
    private(set) var lastError: String?
    /// MIDI Learn: while on, the next control that moves is mapped to `learnTarget`.
    private(set) var isLearning = false
    private(set) var learnTarget: ParameterAddress?
    /// The control that moved last, for the learn banner.
    private(set) var lastControl: MIDIControl?

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var connected: Set<MIDIEndpointRef> = []
    @ObservationIgnored private let router: LiveRouter
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let inbox = ControlInbox()
    @ObservationIgnored private let clockInbox = ClockInbox()
    @ObservationIgnored private var follower = ClockFollower()
    @ObservationIgnored private var lastTempoWrite: UInt64 = 0
    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let writer: ParameterWriter
    private static let followKey = "midi.clockIn.source"
    @ObservationIgnored private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()
    @ObservationIgnored private var gestureEnd: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    init(router: LiveRouter, store: ProjectStore, engine: AudioEngine, writer: ParameterWriter) {
        self.router = router
        self.store = store
        self.engine = engine
        self.writer = writer
        if let stored = UserDefaults.standard.object(forKey: Self.followKey) as? Int {
            followedSource = MIDIUniqueID(truncatingIfNeeded: stored)
        }
    }

    /// Follow this source's MIDI clock, or none.
    func follow(_ source: MIDIUniqueID?) {
        followedSource = source
        clockTempo = nil
        follower = ClockFollower()
        if let source { UserDefaults.standard.set(Int(source), forKey: Self.followKey) } else {
            UserDefaults.standard.removeObject(forKey: Self.followKey)
        }
        clockInbox.followed.store(source.map(Self.tag) ?? 0, ordering: .relaxed)
        store.endGesture()
    }

    /// A non-zero connection tag for a source.
    nonisolated private static func tag(_ id: MIDIUniqueID) -> Int { Int(UInt32(bitPattern: id)) | 1 << 40 }

    /// Main thread: the followed clock's messages since the last drain, through the follower.
    private func drainClock() {
        for message in clockInbox.take() {
            let time = Double(message.hostTime) * Double(timebase.numer) / Double(timebase.denom) / 1e9
            guard let action = follower.receive(status: message.status, message.data1, message.data2, at: time) else {
                continue
            }
            switch action {
            case .start:
                engine.seek(toTick: 0)
                engine.play()
            case .resume:
                engine.play()
            case .stop:
                engine.pause()
                store.endGesture()
            case .position(let sixteenths):
                engine.seek(toTick: Tick(sixteenths) * MusicalTime.ticksPerQuarter / 4)
            }
        }
        applyClockTempo()
    }

    /// The clock's tempo into the song, twice a second at most and only when it moved: one
    /// undo step for the whole time the clock ran.
    private func applyClockTempo() {
        guard let tempo = follower.tempo else { return }
        clockTempo = tempo
        let now = mach_absolute_time()
        let halfSecond = UInt64(5e8 * Double(timebase.denom) / Double(timebase.numer))
        guard abs(store.project.tempo - tempo) >= 0.05, now &- lastTempoWrite >= halfSecond else { return }
        lastTempoWrite = now
        try? store.perform(.setTempo(bpm: tempo), coalescingKey: "midi.clock.tempo")
    }

    func setLearning(_ on: Bool) {
        isLearning = on
        learnTarget = nil
    }

    /// While learning: the parameter the next moved control will move.
    func choose(_ target: ParameterAddress) {
        guard isLearning else { return }
        learnTarget = target
    }

    func forget(_ target: ParameterAddress) {
        for mapping in store.project.midiMappings where mapping.target == target {
            try? store.perform(.unmapMIDI(mapping.control))
        }
    }

    func mapping(for target: ParameterAddress) -> MIDIControl? {
        store.project.midiMappings.first { $0.target == target }?.control
    }

    /// Main thread: applies every control that moved since the last drain.
    private func drainControls() {
        for (control, value) in inbox.take() {
            lastControl = control
            if isLearning {
                if let target = learnTarget {
                    try? store.perform(.mapMIDI(control, target))
                    learnTarget = nil
                }
                continue
            }
            for mapping in store.project.midiMappings where mapping.control == control {
                guard let descriptor = store.project.descriptor(for: mapping.target) else { continue }
                // One undo step per turn of the knob: the step closes when it rests. With
                // automation write armed, the turn is written into the lane.
                writer.set(mapping.target, to: descriptor.value(forNormalized: Double(value) / 127),
                           coalescingKey: "midi.\(control.description)")
            }
        }
        gestureEnd?.cancel()
        gestureEnd = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.writer.endGesture()
        }
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoel" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.connectSources() }
        }
        guard status == noErr else { return fail("client", status) }
        let router = self.router, inbox = self.inbox, clockInbox = self.clockInbox
        let portStatus = MIDIInputPortCreateWithProtocol(client, "Echoel In" as CFString, ._1_0, &port) {
            @Sendable [weak self] list, tag in
            let followed = clockInbox.followed.load(ordering: .relaxed)
            let fromFollowed = followed != 0 && Int(bitPattern: tag) == followed
            let (controls, clock) = Self.receive(list, router: router, inbox: inbox,
                                                 clock: fromFollowed ? clockInbox : nil)
            // One hop: two tasks would each send the captured `self` across actors.
            guard controls || clock else { return }
            Task { @MainActor in
                if controls { self?.drainControls() }
                if clock { self?.drainClock() }
            }
        }
        guard portStatus == noErr else { return fail("port", portStatus) }
        clockInbox.followed.store(followedSource.map(Self.tag) ?? 0, ordering: .relaxed)
        connectSources()
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("midi: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "MIDI is not available (\(status))."
    }

    /// Connects every source not yet connected and lists them all by name.
    private func connectSources() {
        var names: [String] = []
        var found: [Source] = []
        var seen: Set<MIDIEndpointRef> = []
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }
            seen.insert(source)
            var id: MIDIUniqueID = 0
            let hasID = MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &id) == noErr
            // The tag tells the receive block which source a packet came from.
            let tag = hasID ? UnsafeMutableRawPointer(bitPattern: Self.tag(id)) : nil
            if !connected.contains(source), MIDIPortConnectSource(port, source, tag) == noErr {
                connected.insert(source)
            }
            var name: Unmanaged<CFString>?
            let title = MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name) == noErr
                ? (name?.takeRetainedValue() as String?) : nil
            if let title { names.append(title) }
            if hasID { found.append(Source(id: id, name: title ?? "MIDI In")) }
        }
        connected.formIntersection(seen)
        sourceNames = names
        sources = found
    }

    /// MIDI thread: MIDI 1.0 channel voice messages in Universal MIDI Packets (message type 2).
    /// True when controller moves are waiting for the main thread.
    nonisolated private static func receive(_ list: UnsafePointer<MIDIEventList>, router: LiveRouter,
                                            inbox: ControlInbox, clock: ClockInbox?) -> (Bool, Bool) {
        var drain = false
        var drainClock = false
        for packet in list.unsafeSequence() {
            let words = Array(MIDIEventPacket.WordCollection(packet))
            var i = 0
            while i < words.count {
                let word = words[i]
                let type = word >> 28
                if type == 0x1, let clock {
                    // System real-time and song position: the followed clock.
                    let status = UInt8((word >> 16) & 0xFF)
                    if [0xF8, 0xFA, 0xFB, 0xFC, 0xF2].contains(status) {
                        let stamp = packet.pointee.timeStamp
                        let message = ClockInbox.Message(status: status, data1: UInt8((word >> 8) & 0x7F),
                                                         data2: UInt8(word & 0x7F),
                                                         hostTime: stamp == 0 ? mach_absolute_time() : stamp)
                        if clock.post(message) { drainClock = true }
                    }
                } else if type == 0x2 {
                    let status = UInt8((word >> 16) & 0xFF), data1 = UInt8((word >> 8) & 0x7F), data2 = UInt8(word & 0x7F)
                    if status & 0xF0 == 0xB0, data1 != 120, data1 != 123 {
                        if inbox.post(MIDIControl(channel: status & 0x0F, number: data1), data2) { drain = true }
                    } else {
                        router.receive(status: status, data1, data2)
                    }
                }
                // Message length by type: 0–2 one word, 3–4 two, 5 four; the rest one.
                i += type == 3 || type == 4 ? 2 : type == 5 ? 4 : 1
            }
        }
        return (drain, drainClock)
    }
}

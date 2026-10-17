import CoreMIDI
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

/// Every MIDI source on the device — USB and Bluetooth controllers, network sessions, other
/// apps' virtual ports — connected to one input port. Notes go to the live track; controllers
/// move the parameters the song mapped them to, or are learned; sources that appear later are
/// connected when they do.
@MainActor
@Observable
final class MIDIInput {
    private(set) var sourceNames: [String] = []
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
    @ObservationIgnored private var gestureEnd: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    init(router: LiveRouter, store: ProjectStore) {
        self.router = router
        self.store = store
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
                guard let descriptor = store.project.descriptor(for: mapping.target),
                      let command = Command.setParameter(mapping.target,
                                                         to: descriptor.value(forNormalized: Double(value) / 127)) else { continue }
                // One undo step per turn of the knob: the step closes when it rests.
                try? store.perform(command, coalescingKey: "midi.\(control.description)")
            }
        }
        gestureEnd?.cancel()
        gestureEnd = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.store.endGesture()
        }
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoel" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.connectSources() }
        }
        guard status == noErr else { return fail("client", status) }
        let router = self.router, inbox = self.inbox
        let portStatus = MIDIInputPortCreateWithProtocol(client, "Echoel In" as CFString, ._1_0, &port) {
            @Sendable [weak self] list, _ in
            let drain = Self.receive(list, router: router, inbox: inbox)
            if drain { Task { @MainActor in self?.drainControls() } }
        }
        guard portStatus == noErr else { return fail("port", portStatus) }
        connectSources()
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("midi: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "MIDI is not available (\(status))."
    }

    /// Connects every source not yet connected and lists them all by name.
    private func connectSources() {
        var names: [String] = []
        var seen: Set<MIDIEndpointRef> = []
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }
            seen.insert(source)
            if !connected.contains(source), MIDIPortConnectSource(port, source, nil) == noErr {
                connected.insert(source)
            }
            var name: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name) == noErr, let name {
                names.append(name.takeRetainedValue() as String)
            }
        }
        connected.formIntersection(seen)
        sourceNames = names
    }

    /// MIDI thread: MIDI 1.0 channel voice messages in Universal MIDI Packets (message type 2).
    /// True when controller moves are waiting for the main thread.
    nonisolated private static func receive(_ list: UnsafePointer<MIDIEventList>, router: LiveRouter,
                                            inbox: ControlInbox) -> Bool {
        var drain = false
        for packet in list.unsafeSequence() {
            let words = Array(MIDIEventPacket.WordCollection(packet))
            var i = 0
            while i < words.count {
                let word = words[i]
                let type = word >> 28
                if type == 0x2 {
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
        return drain
    }
}

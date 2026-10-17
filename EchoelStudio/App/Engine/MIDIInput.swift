import CoreMIDI
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

/// Every MIDI source on the device — USB and Bluetooth controllers, network sessions, other
/// apps' virtual ports — connected to one input port. Notes go to the live track; sources
/// that appear later are connected when they do.
@MainActor
@Observable
final class MIDIInput {
    private(set) var sourceNames: [String] = []
    private(set) var lastError: String?

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var connected: Set<MIDIEndpointRef> = []
    @ObservationIgnored private let router: LiveRouter
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")

    init(router: LiveRouter) {
        self.router = router
    }

    func start() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("Echoel" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.connectSources() }
        }
        guard status == noErr else { return fail("client", status) }
        let router = self.router
        let portStatus = MIDIInputPortCreateWithProtocol(client, "Echoel In" as CFString, ._1_0, &port) { @Sendable list, _ in
            Self.receive(list, router: router)
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
    nonisolated private static func receive(_ list: UnsafePointer<MIDIEventList>, router: LiveRouter) {
        for packet in list.unsafeSequence() {
            let words = Array(MIDIEventPacket.WordCollection(packet))
            var i = 0
            while i < words.count {
                let word = words[i]
                let type = word >> 28
                if type == 0x2 {
                    router.receive(status: UInt8((word >> 16) & 0xFF), UInt8((word >> 8) & 0x7F), UInt8(word & 0x7F))
                }
                // Message length by type: 0–2 one word, 3–4 two, 5 four; the rest one.
                i += type == 3 || type == 4 ? 2 : type == 5 ? 4 : 1
            }
        }
    }
}

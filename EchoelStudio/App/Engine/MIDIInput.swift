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
        /// The held keys, each with the slot and the pitch it sounds: a key released after the
        /// live track changed still ends the note it started.
        var keys = LiveKeys()
        /// Slots that last heard the sustain pedal down: lifting it releases them all.
        var pedalDown: UInt64 = 0
    }

    private let target = Mutex(Target())

    /// A note, bend or controller as it was played while a MIDI take records: the output sample
    /// the engine had reached, and the message.
    struct Captured: Sendable {
        let sample: Int64
        let status: UInt8
        let data1: UInt8
        let data2: UInt8
    }

    /// Nil while nothing records. The MIDI thread appends; never the render thread.
    private let capture = Mutex<[Captured]?>(nil)

    /// `lock` maps each key to the pitch it plays (`LiveKeys.lock(for:device:)`); nil plays every
    /// key as itself. A held key keeps the pitch it struck when the lock changes.
    func set(core: EngineCore?, slot: Int?, lock: [UInt8]?) {
        target.withLock { (state: inout Target) in
            // Another core has none of the old one's notes; the same core keeps them to release.
            if state.core !== core { state = Target() }
            state.core = core
            state.slot = slot
            state.keys.lock = lock
        }
    }

    /// Main thread: notes played from now on are kept for the take.
    func startCapture() {
        capture.withLock { $0 = [] }
    }

    /// Main thread: the notes played since `startCapture`, and capturing stops.
    func stopCapture() -> [Captured] {
        capture.withLock { (events: inout [Captured]?) -> [Captured] in
            let taken = events ?? []
            events = nil
            return taken
        }
    }

    /// MIDI thread.
    func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        let kind = status & 0xF0
        let channel = status & 0x0F
        let isNote = kind == 0x80 || kind == 0x90
        let (core, slot, alsoReleased, notes) = target.withLock {
            (state: inout Target) -> (EngineCore?, Int?, UInt64, LiveKeys.Output) in
            guard let core = state.core, let slot = state.slot else { return (nil, nil, 0, LiveKeys.Output()) }
            let bit: UInt64 = slot < 64 ? 1 << UInt64(slot) : 0
            switch kind {
            case 0x90 where data2 > 0:
                return (core, slot, 0, state.keys.press(channel: channel, key: data1, velocity: data2, slot: slot))
            case 0x80, 0x90:
                return (core, slot, 0, state.keys.release(channel: channel, key: data1))
            case 0xB0 where data1 == 64:
                if data2 >= 64 {
                    state.pedalDown |= bit
                } else {
                    let others = state.pedalDown & ~bit
                    state.pedalDown = 0
                    return (core, slot, others, LiveKeys.Output())
                }
            default:
                break
            }
            return (core, slot, 0, LiveKeys.Output())
        }
        guard let core, let slot else { return }
        if isNote {
            // A note plays as the held keys decide, and the take keeps what was heard.
            for note in notes { core.playLive(slot: note.slot, status: note.status, note.pitch, note.velocity) }
        } else {
            core.playLive(slot: slot, status: status, data1, data2)
            var others = alsoReleased
            while others != 0 {
                let other = others.trailingZeroBitCount
                others &= others - 1
                core.playLive(slot: other, status: status, data1, data2)
            }
            guard kind == 0xB0 || kind == 0xE0 else { return }
        }
        let sample = core.positionSample
        capture.withLock { events in
            guard events != nil else { return }
            if isNote {
                for note in notes {
                    events?.append(Captured(sample: sample, status: note.status, data1: note.pitch, data2: note.velocity))
                }
            } else {
                events?.append(Captured(sample: sample, status: status, data1: data1, data2: data2))
            }
        }
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

    /// The controls the song maps to a parameter. Those move only their parameter; every other
    /// controller also plays the live instrument (S-16b).
    private let mapped = Mutex<Set<MIDIControl>>([])

    /// Main thread, whenever the song's mappings may have changed.
    func setMapped(_ controls: Set<MIDIControl>) {
        mapped.withLock { $0 = controls }
    }

    /// MIDI thread.
    func isMapped(_ control: MIDIControl) -> Bool {
        mapped.withLock { $0.contains(control) }
    }

    /// MIDI Learn is on. A controller then waits for its mapping and plays nothing: a hosted
    /// plugin that answered it by moving one of its own parameters would make that parameter the
    /// learn target, and the knob would end up on the plugin instead (review 2026-10-20).
    private let learning = Atomic<Bool>(false)

    /// Main thread.
    func setLearning(_ on: Bool) {
        learning.store(on, ordering: .releasing)
    }

    /// MIDI thread: whether a controller also plays the live instrument. The sustain pedal
    /// always does, since it holds the notes being played. While learning, a pedal — sustain,
    /// sostenuto, soft, hold 2 — plays only when it is let go, so one held from before can still
    /// release what it holds (review 2026-10-21).
    func playsLive(_ control: MIDIControl, value: UInt8) -> Bool {
        let isLearning = learning.load(ordering: .acquiring)
        switch control.number {
        case 64: return !isLearning || value < 64
        case 66, 67, 69: return isLearning ? value < 64 : !isMapped(control)
        default: return !isLearning && !isMapped(control)
        }
    }

    /// MIDI thread: whether another channel message reaches the live instrument. Always, except
    /// while learning: then notes pass, and what returns a held control to rest — the pitch wheel
    /// at its centre, pressure at zero — so nothing stays bent or pressed when learning ends. The
    /// rest are held back: a hosted plugin answering a bend, pressure or a program change by
    /// moving one of its parameters would take the learn target just as a knob would.
    func playsLive(status: UInt8, _ data1: UInt8, _ data2: UInt8) -> Bool {
        guard learning.load(ordering: .acquiring) else { return true }
        switch status & 0xF0 {
        // Notes, and the controllers that only ever stop or reset things — All Sound Off, Reset
        // All Controllers, All Notes Off: no learn target is at stake, and a panic must work.
        case 0x80, 0x90, 0xB0: return true
        // The wheel at rest: its centre, 8192, give or take what a spring or a dead band leaves.
        case 0xE0: return abs((Int(data2) << 7 | Int(data1)) - 8192) <= 128
        case 0xD0: return data1 == 0
        case 0xA0: return data2 == 0
        default: return false
        }
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

/// Messages from grid controllers (a Launchpad), waiting for the main thread. Their sources
/// are known by connection tag; nothing from them is played or learned.
final class GridInbox: Sendable {
    private let tags = Mutex<Set<Int>>([])
    private let waiting = Mutex<[Launchpad.Press]>([])
    private let scheduled = Atomic<Bool>(false)

    func setTags(_ new: Set<Int>) { tags.withLock { $0 = new } }

    /// MIDI thread.
    func isGrid(_ tag: Int) -> Bool { tags.withLock { $0.contains(tag) } }

    /// MIDI thread. True when the main thread must be asked to drain.
    func post(_ press: Launchpad.Press) -> Bool {
        waiting.withLock { $0.append(press) }
        return !scheduled.exchange(true, ordering: .acquiringAndReleasing)
    }

    /// Main thread.
    func take() -> [Launchpad.Press] {
        scheduled.store(false, ordering: .releasing)
        return waiting.withLock { presses in
            defer { presses.removeAll(keepingCapacity: true) }
            return presses
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
    /// MIDI over the network (RTP-MIDI): a Mac's Audio MIDI Setup, another iPad, any rtpMIDI host
    /// on Windows. While on, the session is one more source and destination like a cable.
    private(set) var networkEnabled = false

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var connected: Set<MIDIEndpointRef> = []
    @ObservationIgnored private let router: LiveRouter
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private let inbox = ControlInbox()
    @ObservationIgnored private let clockInbox = ClockInbox()
    @ObservationIgnored private let gridInbox = GridInbox()
    /// Called on the main thread for each press on a grid controller.
    @ObservationIgnored var onGridPress: ((Launchpad.Press) -> Void)?
    @ObservationIgnored private var follower = ClockFollower()
    @ObservationIgnored private var phase = PhaseLock()
    @ObservationIgnored private var lastPhaseCheck: Double = 0
    /// Set by a start, continue or song position: the first measurement after it jumps straight
    /// onto the clock instead of nudging the start-up gap away over many seconds.
    @ObservationIgnored private var needsLock = false
    @ObservationIgnored private var lastTempoWrite: UInt64 = 0
    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let writer: ParameterWriter
    private static let followKey = "midi.clockIn.source"
    private static let networkKey = "midi.network"
    @ObservationIgnored private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()
    @ObservationIgnored private var gestureEnd: Task<Void, Never>?
    /// The network session's connections change without any MIDI setup change.
    @ObservationIgnored private var networkObserver: NSObjectProtocol?
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
        phase.reset()
        engine.externalTempo = nil
        engine.followsExternalClock = source != nil
        if let source { UserDefaults.standard.set(Int(source), forKey: Self.followKey) } else {
            UserDefaults.standard.removeObject(forKey: Self.followKey)
        }
        clockInbox.followed.store(source.map(Self.tag) ?? 0, ordering: .relaxed)
        applyClockSource()
        store.endGesture()
    }

    /// Tells the engine whether the followed source is connected, after a choice and whenever the
    /// sources change. The network session stays listed while it is on, with nobody connected; it
    /// counts only with a connection, so an empty session does not keep the engine up.
    private func applyClockSource() {
        engine.clockSourceConnected = followedSource.map { id in
            sources.contains { $0.id == id }
                && (id != Self.networkSourceID || !MIDINetworkSession.default().connections().isEmpty)
        } ?? false
    }

    /// The unique ID of the network session's source.
    private static var networkSourceID: MIDIUniqueID? {
        let endpoint = MIDINetworkSession.default().sourceEndpoint()
        var id: MIDIUniqueID = 0
        guard endpoint != 0, MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id) == noErr else { return nil }
        return id
    }

    /// The sources that are grid controllers; their messages go to `onGridPress` only.
    func setGridSources(_ ids: Set<MIDIUniqueID>) {
        gridInbox.setTags(Set(ids.map(Self.tag)))
    }

    private func drainGrid() {
        for press in gridInbox.take() { onGridPress?(press) }
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
            phase.reset()
            needsLock = action != .stop
            switch action {
            case .start:
                engine.seek(toTick: 0)
                engine.play()
            case .resume:
                engine.play()
            case .stop:
                engine.pauseFromOutside(nil)
                store.endGesture()
            case .position(let sixteenths):
                engine.seek(toTick: Tick(sixteenths) * MusicalTime.ticksPerQuarter / 4)
            }
        }
        applyClockTempo()
        keepInPhase()
    }

    /// Four times a second: how far the song is heard ahead of or behind the clock, and the
    /// correction for it — a nudge of a fraction of a millisecond, or a jump when it is far off.
    private func keepInPhase() {
        let host = mach_absolute_time()
        let now = Double(host) * Double(timebase.numer) / Double(timebase.denom) / 1e9
        guard now - lastPhaseCheck >= 0.25, let theirs = follower.position(at: now), let tempo = follower.tempo,
              let heard = engine.heardPosition(atHostTime: host) else { return }
        lastPhaseCheck = now
        let gap = theirs - heard.tick
        let secondsPerTick = 60 / (tempo * Double(MusicalTime.ticksPerQuarter))
        if needsLock {
            needsLock = false
            if abs(gap * secondsPerTick) > PhaseLock.deadband { relock(by: gap, heard.samplesPerTick, at: now) }
            return
        }
        switch phase.correct(error: -gap * secondsPerTick) {
        case .none: break
        case .nudge(let seconds): engine.nudge(seconds: seconds)
        case .relock: relock(by: gap, heard.samplesPerTick, at: now)
        }
    }

    /// A jump onto the clock. The next check waits an extra quarter second, so it cannot measure
    /// a buffer rendered before the jump and jump a second time.
    private func relock(by ticks: Double, _ samplesPerTick: Double, at now: Double) {
        engine.relock(byTicks: ticks, samplesPerTick: samplesPerTick)
        phase.reset()
        lastPhaseCheck = now + 0.25
    }

    /// The clock's tempo to the engine, twice a second at most and only when it moved. Never into
    /// the song: a tempo write there would close the open undo step of any other edit and clear
    /// the redo stack each time the clock drifted.
    private func applyClockTempo() {
        guard let tempo = follower.tempo else { return }
        clockTempo = tempo
        let now = mach_absolute_time()
        let halfSecond = UInt64(5e8 * Double(timebase.denom) / Double(timebase.numer))
        // To the follower's own hundredth: a coarser step would leave a steady drift for the
        // phase lock to chase.
        if let played = engine.externalTempo, abs(played - tempo) < 0.01 { return }
        guard now &- lastTempoWrite >= halfSecond else { return }
        lastTempoWrite = now
        engine.externalTempo = tempo
    }

    func setLearning(_ on: Bool) {
        isLearning = on
        learnTarget = nil
        inbox.setLearning(on)
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

    /// Main thread: called on every change to the song, so a newly learned control stops playing
    /// the instrument and a removed mapping lets it play again.
    func projectChanged(_ project: Project) {
        inbox.setMapped(Set(project.midiMappings.map(\.control)))
    }

    func start() {
        guard client == 0 else { return }
        projectChanged(store.project)
        let status = MIDIClientCreateWithBlock("Echoel" as CFString, &client) { @Sendable notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor [weak self] in self?.connectSources() }
        }
        guard status == noErr else { return fail("client", status) }
        let router = self.router, inbox = self.inbox, clockInbox = self.clockInbox, gridInbox = self.gridInbox
        let portStatus = MIDIInputPortCreateWithProtocol(client, "Echoel In" as CFString, ._1_0, &port) {
            @Sendable [weak self] list, tag in
            let followed = clockInbox.followed.load(ordering: .relaxed)
            let fromFollowed = followed != 0 && Int(bitPattern: tag) == followed
            if gridInbox.isGrid(Int(bitPattern: tag)) {
                guard Self.receiveGrid(list, inbox: gridInbox) else { return }
                Task { @MainActor in self?.drainGrid() }
                return
            }
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
        engine.followsExternalClock = followedSource != nil
        networkObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(MIDINetworkNotificationSessionDidChange), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyClockSource() }
        }
        if UserDefaults.standard.bool(forKey: Self.networkKey) { setNetwork(true) }
        connectSources()
    }

    /// Turns the network session on or off. Off by default: turning it on is what asks for
    /// local-network access, so it happens when the musician asks for it, not at launch.
    func setNetwork(_ on: Bool) {
        let session = MIDINetworkSession.default()
        session.isEnabled = on
        // Anyone on the local network may connect, as a cable plugged in would.
        session.connectionPolicy = on ? .anyone : .noOne
        networkEnabled = on
        UserDefaults.standard.set(on, forKey: Self.networkKey)
        applyClockSource()
        log.info("midi: network \(on ? "on" : "off", privacy: .public) as \(session.networkName, privacy: .private)")
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
        applyClockSource()
    }

    /// MIDI thread: a grid controller's presses. True when some are waiting for the main thread.
    nonisolated private static func receiveGrid(_ list: UnsafePointer<MIDIEventList>, inbox: GridInbox) -> Bool {
        var drain = false
        for packet in list.unsafeSequence() {
            for word in MIDIEventPacket.WordCollection(packet) where word >> 28 == 0x2 {
                let press = Launchpad.press(status: UInt8((word >> 16) & 0xFF), UInt8((word >> 8) & 0x7F), UInt8(word & 0x7F))
                if let press, inbox.post(press) { drain = true }
            }
        }
        return drain
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
                    // All Sound Off, Reset All Controllers and All Notes Off are never learned.
                    if status & 0xF0 == 0xB0, data1 != 120, data1 != 121, data1 != 123 {
                        let control = MIDIControl(channel: status & 0x0F, number: data1)
                        if inbox.post(control, data2) { drain = true }
                        // A controller the song does not map plays the live instrument — the mod
                        // wheel, expression, a filter knob — and a take records it. The sustain
                        // pedal always plays: it holds the live instrument's notes (S-16b).
                        if inbox.playsLive(control, value: data2) { router.receive(status: status, data1, data2) }
                    } else if inbox.playsLive(status: status, data1, data2) {
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

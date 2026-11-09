import CoreMIDI
import Darwin
import EchoelEngine
import Foundation
import Observation
import Synchronization
import os

/// MTC chase (W17-TC): the song follows an external MIDI Time Code — QLab, a video player, a
/// lighting desk. A full frame locates it; quarter frames start it and keep it in step (a nudge
/// inside the tolerance, a jump beyond it); four frames without one stop it. The sender's start
/// label is the song's first sample (the start set for MTC out, 01:00:00:00 by default). Off until
/// a source is chosen in the Song menu (Connect, Timecode); never while a MIDI clock or a jam sets
/// the pace. Its own client and port, connected to the chosen source only, so the MIDI input of
/// notes and controllers is not touched. The decision is `MTCChase`; this class only carries it out.
@MainActor
@Observable
final class MTCChaseInput {
    struct Source: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
    }

    private(set) var sources: [Source] = []
    /// The source whose timecode the song follows; nil for none. Kept on this device.
    private(set) var chased: MIDIUniqueID?
    /// The sender's timecode runs. The engine's song loop rests meanwhile (`timecodeRuns`).
    private(set) var isLocked = false {
        didSet {
            guard isLocked != oldValue else { return }
            engine?.timecodeRuns = isLocked
        }
    }
    private(set) var lastError: String?

    @ObservationIgnored weak var engine: AudioEngine?
    /// The label of the song's first sample, read at every message.
    @ObservationIgnored var start: @MainActor () -> Timecode = { Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0) }
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var connected = MIDIEndpointRef()
    @ObservationIgnored private let inbox = MTCInbox()
    @ObservationIgnored private let reader = SysExAssembly()
    @ObservationIgnored private var follower = MTCChase(start: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "midi")
    private static let chaseKey = "mtc.chase.source"
    private let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    init() {
        if let stored = UserDefaults.standard.object(forKey: Self.chaseKey) as? Int {
            chased = MIDIUniqueID(truncatingIfNeeded: stored)
        }
    }

    /// At launch: a chase chosen before goes on, nothing is made while none is.
    func begin() {
        if chased != nil { open() }
    }

    /// Chase this source's timecode, or none.
    func chase(_ source: MIDIUniqueID?) {
        chased = source
        if let source { UserDefaults.standard.set(Int(source), forKey: Self.chaseKey) } else {
            UserDefaults.standard.removeObject(forKey: Self.chaseKey)
        }
        follower = MTCChase(start: start())
        isLocked = false
        if source == nil {
            disconnect()
            watchdog?.cancel()
            watchdog = nil
        } else {
            open()
        }
    }

    private func open() {
        if client == 0 {
            let status = MIDIClientCreateWithBlock("Echoel Timecode In" as CFString, &client) { @Sendable notification in
                guard notification.pointee.messageID == .msgSetupChanged else { return }
                Task { @MainActor [weak self] in self?.refresh() }
            }
            guard status == noErr else { return fail("client", status) }
            let inbox = self.inbox, reader = self.reader
            let portStatus = MIDIInputPortCreateWithProtocol(client, "Echoel Timecode In" as CFString, ._1_0, &port) {
                @Sendable [weak self] list, _ in
                guard Self.receive(list, inbox: inbox, reader: reader) else { return }
                Task { @MainActor in self?.drain() }
            }
            guard portStatus == noErr else { return fail("port", portStatus) }
        }
        refresh()
        if watchdog == nil {
            // Twenty times a second: has the sender gone quiet? Only while a source is chased.
            watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(20))
                    guard let self else { return }
                    self.checkTimeout()
                }
            }
        }
    }

    /// Lists the sources and connects the chased one, only it.
    private func refresh() {
        guard client != 0 else { return }
        var found: [Source] = []
        var target = MIDIEndpointRef()
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }
            var id: MIDIUniqueID = 0
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id) == noErr else { continue }
            var name: Unmanaged<CFString>?
            let title = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr
                ? (name?.takeRetainedValue() as String?) ?? "MIDI In" : "MIDI In"
            // Our own timecode out is no source to chase: it would follow itself.
            guard title != "Echoelmusic Timecode" else { continue }
            found.append(Source(id: id, name: title))
            if id == chased { target = endpoint }
        }
        sources = found
        guard target != connected else { return }
        disconnect()
        if target != 0, MIDIPortConnectSource(port, target, nil) == noErr { connected = target }
    }

    private func disconnect() {
        guard connected != 0 else { return }
        MIDIPortDisconnectSource(port, connected)
        connected = MIDIEndpointRef()
    }

    private func secondsOf(_ hostTime: UInt64) -> Double {
        Double(hostTime) * Double(timebase.numer) / Double(timebase.denom) / 1e9
    }

    /// Main thread: every waiting message through the chase, and what it decides to the engine.
    private func drain() {
        follower.start = start()
        while let event = inbox.next() {
            let action = event.fullFrame.map { follower.receiveFullFrame($0) }
                ?? follower.receiveQuarterFrame(event.data, at: secondsOf(event.hostTime))
            if let action { carry(action, hostTime: event.hostTime) }
        }
    }

    private func checkTimeout() {
        guard chased != nil, let action = follower.check(at: secondsOf(mach_absolute_time())) else { return }
        carry(action, hostTime: mach_absolute_time())
    }

    /// `isLocked` rests the song's loop (`AudioEngine.timecodeRuns`). It changes only where the song
    /// cannot run across the loop's end meanwhile: after a pause, or after `clockWillMovePlayhead`
    /// (which ends a take on the loop it began with) and before the seek that follows it.
    private func carry(_ action: MTCChase.Action, hostTime: UInt64) {
        guard let engine, !engine.followsExternalClock else {
            // A MIDI clock or a jam sets the pace: the chase steps aside and gives the loop back.
            isLocked = false
            return
        }
        switch action {
        case .locate(let seconds):
            if engine.isPlaying { engine.pauseFromOutside(nil) }
            isLocked = false
            engine.clockWillMovePlayhead()
            engine.seek(toSeconds: seconds)
        case .stop:
            if engine.isPlaying { engine.pauseFromOutside(nil) }
            isLocked = false
        case .follow(let seconds, let at):
            // Before the song's first sample the song waits at its start.
            guard seconds >= 0 else {
                if engine.isPlaying { engine.pauseFromOutside(nil) }
                isLocked = true
                return
            }
            let now = mach_absolute_time()
            let along = Swift.max(0, secondsOf(now) - at)
            guard engine.isPlaying, let heard = engine.heardSeconds(atHostTime: hostTime) else {
                // The sender runs and the song does not: start it where the sender is now, plus
                // the output's latency so the first frame heard is the sender's.
                engine.clockWillMovePlayhead()
                isLocked = true
                engine.seek(toSeconds: seconds + along + engine.outputLatencySeconds)
                engine.play()
                return
            }
            switch follower.correction(gap: seconds - heard) {
            case .nudge(let by):
                isLocked = true
                if by != 0 { engine.nudge(seconds: by) }
            case .relocate:
                engine.clockWillMovePlayhead()
                isLocked = true
                engine.seek(toSeconds: seconds + along + engine.outputLatencySeconds)
            }
        }
    }

    private func fail(_ step: String, _ status: OSStatus) {
        log.error("mtc chase: \(step, privacy: .public) failed \(status, privacy: .public)")
        lastError = "Timecode in is not available (\(status))."
    }

    /// MIDI thread: quarter frames (message type 1, F1) and full frames (type 3) into the inbox.
    /// True when the main thread must be asked to drain. No allocation.
    nonisolated private static func receive(_ list: UnsafePointer<MIDIEventList>, inbox: MTCInbox,
                                            reader: SysExAssembly) -> Bool {
        var drain = false
        for packet in list.unsafeSequence() {
            let stamp = packet.pointee.timeStamp
            let hostTime = stamp == 0 ? mach_absolute_time() : stamp
            let words = MIDIEventPacket.WordCollection(packet)
            var i = words.startIndex
            while i < words.endIndex {
                let word = words[i]
                let type = word >> 28
                if type == 0x1, (word >> 16) & 0xFF == UInt32(MTCQuarterFrame.status) {
                    let event = MTCInbox.Event(hostTime: hostTime, data: UInt8((word >> 8) & 0x7F), fullFrame: nil)
                    if inbox.post(event) { drain = true }
                } else if type == 0x3, words.index(after: i) < words.endIndex {
                    let second = words[words.index(after: i)]
                    if let frame = reader.read(word, second) {
                        if inbox.post(MTCInbox.Event(hostTime: hostTime, data: 0, fullFrame: frame)) { drain = true }
                    }
                }
                let length = UMP.wordCount(messageType: type)
                i = words.index(i, offsetBy: length, limitedBy: words.endIndex) ?? words.endIndex
            }
        }
        return drain
    }
}

/// The full-frame reader between the MIDI thread's callbacks: a System Exclusive can span packets.
final class SysExAssembly: Sendable {
    private let reader = Mutex(MTCSysExReader())

    func read(_ word0: UInt32, _ word1: UInt32) -> MTCFullFrame? {
        reader.withLock { $0.read(word0, word1) }
    }
}

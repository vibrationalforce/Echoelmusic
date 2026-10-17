import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The render-thread half of the engine: plays the newest `EngineSnapshot` sample-accurately
/// into one `PolySynth` per instrument track, mixes them to the master pair (or a track's own
/// interface pair) and adds the metronome.
///
/// Threading — two sides, never mixed:
/// - **Main thread:** `publish`, `play`, `stop`, `seek`, `setClickEnabled`. A snapshot is
///   handed over through one atomic pointer; the main thread keeps every published snapshot
///   alive until the render thread has acknowledged a newer one, so the render thread never
///   frees memory.
/// - **Render thread:** `render` only. No locks, no allocation, no Objective-C, no I/O: every
///   buffer and synth is allocated in `init`.
///
/// Editing a track's notes while playing releases that track's sounding notes and re-seeks, so
/// a deleted note can never hang; a mix change keeps every note. A note that already sounded is
/// never fired twice.
public final class EngineCore: @unchecked Sendable {
    public static let maximumFrames = 4_096

    public let sampleRate: Double
    public let slotCapacity: Int
    /// Return tracks the engine has buses for; ones beyond it stay silent.
    public static let returnCapacity = 8

    // Main → render.
    private let isPlayingFlag = Atomic<Bool>(false)
    private let clickFlag = Atomic<Bool>(true)
    private let seekRequest = Atomic<Int64>(-1)
    private let pending = Atomic<UnsafeMutableRawPointer?>(nil)
    // Render → main.
    private let acknowledged = Atomic<UInt64>(0)
    private let position = Atomic<Int64>(0)
    /// Controller → render: notes played live, each packed as slot · status · data1 · data2.
    private let live = EventRing()
    private let clockFlag = Atomic<Bool>(false)
    /// Render → MIDI sender: clock (24 per quarter), start/continue/stop and song position,
    /// written only while `setClockOutEnabled(true)`.
    public let clockOut = MIDIClockRing()

    /// MIDI clock ticks per quarter note.
    public static let clocksPerQuarter: Tick = 24
    /// Main → render: session launches, stops and returns to the arrangement.
    private let launchRequests = SPSCRing(capacity: 256, filler: LaunchRequest(slot: -1, action: .stop))
    /// Render → main: what each slot's clip did, for the session view.
    public let launchReports = SPSCRing(capacity: 1_024, filler: LaunchReport(slot: -1, clip: nil, state: .stopped))
    /// Ticks a launch waits for: −1 one bar of the song's signature, 0 none.
    private let launchQuantum = Atomic<Int64>(-1)

    // Render thread only.
    private var current: SnapshotBox?
    private let synths: UnsafeMutablePointer<PolySynth>
    private let drums: UnsafeMutablePointer<DrumKit>
    private let samplers: UnsafeMutablePointer<Sampler>
    private let devices: UnsafeMutablePointer<InstrumentDevice>
    private let owners: UnsafeMutablePointer<TrackID?>
    private let cursors: UnsafeMutablePointer<Int>
    private let sessions: UnsafeMutablePointer<SessionSlot>
    /// The events revision each slot last played; a different one means its notes were edited.
    private let revisions: UnsafeMutablePointer<UInt64>
    private let scratch: UnsafeMutablePointer<Float>
    /// One stereo bus per slot, `maximumFrames` each: a track renders into its bus, its inserts
    /// process the bus, then the bus is mixed at the track's gains. Plus one bus audio tracks
    /// take in turn.
    private let busLeft: UnsafeMutablePointer<Float>
    private let busRight: UnsafeMutablePointer<Float>
    private let audioLeft: UnsafeMutablePointer<Float>
    private let audioRight: UnsafeMutablePointer<Float>
    private let returnLeft: UnsafeMutablePointer<Float>
    private let returnRight: UnsafeMutablePointer<Float>
    /// The channels of the chunk being rendered, offset into the caller's buffers; 0/1 is the
    /// master mix, a routed track adds into its own pair.
    private let outputs: UnsafeMutablePointer<UnsafeMutablePointer<Float>>
    private var outputCount = 2
    /// The right half of the mix when the device has one channel.
    private let monoRight: UnsafeMutablePointer<Float>
    private var metronome: Metronome
    private var playhead: Int64 = 0
    private var wasPlaying = false
    private var nextBeat: Tick = 0
    private var nextClock: Tick = 0
    /// Host time of the current render call, and where the current chunk starts in it.
    private var callHostTime: UInt64 = 0
    private var chunkStart = 0

    // Main thread only.
    private var published: [SnapshotBox] = []

    public init(sampleRate: Double, slotCapacity: Int = 32) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.slotCapacity = Swift.max(1, slotCapacity)
        synths = .allocate(capacity: self.slotCapacity)
        for i in 0..<self.slotCapacity {
            // One by one: copies of a single synth would share voice storage and copy it on
            // the render thread at the first note.
            (synths + i).initialize(to: PolySynth(sampleRate: Float(rate)))
        }
        drums = .allocate(capacity: self.slotCapacity)
        for i in 0..<self.slotCapacity {
            (drums + i).initialize(to: DrumKit(sampleRate: Float(rate)))
        }
        samplers = .allocate(capacity: self.slotCapacity)
        for i in 0..<self.slotCapacity {
            (samplers + i).initialize(to: Sampler(sampleRate: Float(rate)))
        }
        devices = .allocate(capacity: self.slotCapacity)
        devices.initialize(repeating: .synth, count: self.slotCapacity)
        owners = .allocate(capacity: self.slotCapacity)
        owners.initialize(repeating: nil, count: self.slotCapacity)
        cursors = .allocate(capacity: self.slotCapacity)
        cursors.initialize(repeating: 0, count: self.slotCapacity)
        sessions = .allocate(capacity: self.slotCapacity)
        sessions.initialize(repeating: SessionSlot(), count: self.slotCapacity)
        revisions = .allocate(capacity: self.slotCapacity)
        revisions.initialize(repeating: .max, count: self.slotCapacity)
        scratch = .allocate(capacity: Self.maximumFrames)
        scratch.initialize(repeating: 0, count: Self.maximumFrames)
        busLeft = .allocate(capacity: self.slotCapacity * Self.maximumFrames)
        busLeft.initialize(repeating: 0, count: self.slotCapacity * Self.maximumFrames)
        busRight = .allocate(capacity: self.slotCapacity * Self.maximumFrames)
        busRight.initialize(repeating: 0, count: self.slotCapacity * Self.maximumFrames)
        audioLeft = .allocate(capacity: Self.maximumFrames)
        audioLeft.initialize(repeating: 0, count: Self.maximumFrames)
        audioRight = .allocate(capacity: Self.maximumFrames)
        audioRight.initialize(repeating: 0, count: Self.maximumFrames)
        returnLeft = .allocate(capacity: Self.returnCapacity * Self.maximumFrames)
        returnLeft.initialize(repeating: 0, count: Self.returnCapacity * Self.maximumFrames)
        returnRight = .allocate(capacity: Self.returnCapacity * Self.maximumFrames)
        returnRight.initialize(repeating: 0, count: Self.returnCapacity * Self.maximumFrames)
        monoRight = .allocate(capacity: Self.maximumFrames)
        monoRight.initialize(repeating: 0, count: Self.maximumFrames)
        outputs = .allocate(capacity: Track.outputChannelLimit)
        outputs.initialize(repeating: monoRight, count: Track.outputChannelLimit)
        metronome = Metronome(sampleRate: Float(rate))
    }

    deinit {
        synths.deinitialize(count: slotCapacity)
        synths.deallocate()
        drums.deinitialize(count: slotCapacity)
        drums.deallocate()
        samplers.deinitialize(count: slotCapacity)
        samplers.deallocate()
        devices.deallocate()
        owners.deinitialize(count: slotCapacity)
        owners.deallocate()
        cursors.deallocate()
        sessions.deinitialize(count: slotCapacity)
        sessions.deallocate()
        revisions.deallocate()
        scratch.deallocate()
        busLeft.deallocate()
        busRight.deallocate()
        audioLeft.deallocate()
        audioRight.deallocate()
        returnLeft.deallocate()
        returnRight.deallocate()
        monoRight.deallocate()
        outputs.deallocate()
    }

    // MARK: - Main thread

    public func publish(_ snapshot: EngineSnapshot) {
        // A lane outside the preallocated slots would index past them on the render thread.
        let box = SnapshotBox(snapshot.limited(toSlots: slotCapacity, returnCapacity: Self.returnCapacity))
        published.append(box)
        if let unseen = pending.exchange(Unmanaged.passUnretained(box).toOpaque(), ordering: .acquiringAndReleasing) {
            // The render thread never took this one and now never can; without this, every
            // publish while the output is stopped would keep another snapshot and its buffers.
            let skipped = Unmanaged<SnapshotBox>.fromOpaque(unseen).takeUnretainedValue()
            published.removeAll { $0 === skipped }
        }
        // A box older than the one the render thread acknowledged can no longer be reached:
        // the render thread only ever takes the newest pending one.
        let ack = acknowledged.load(ordering: .acquiring)
        published.removeAll { $0.snapshot.generation < ack }
    }

    public func play() { isPlayingFlag.store(true, ordering: .releasing) }

    /// Stops and returns to the start.
    public func stop() {
        isPlayingFlag.store(false, ordering: .releasing)
        seekRequest.store(0, ordering: .releasing)
    }

    public func seek(toSample sample: Int64) {
        seekRequest.store(Swift.max(0, sample), ordering: .releasing)
    }

    public func setClickEnabled(_ enabled: Bool) { clickFlag.store(enabled, ordering: .relaxed) }

    /// Session: launch a clip on the track in `slot`, stop it, or give the track back to the
    /// arrangement. Launches and stops wait for the launch boundary while playing; stopped, they
    /// take effect at once. Main thread only.
    public func launch(slot: Int, _ action: LaunchAction) {
        guard slot >= 0, slot < slotCapacity else { return }
        launchRequests.push(LaunchRequest(slot: slot, action: action))
    }

    /// How long a launch waits: `nil` one bar, 0 not at all, otherwise that many ticks.
    public func setLaunchQuantum(_ ticks: Tick?) {
        launchQuantum.store(ticks.map { Swift.max(0, $0) } ?? -1, ordering: .relaxed)
    }

    /// Whether the render thread times MIDI clock into `clockOut`. Off while nothing reads it,
    /// so the ring never fills up.
    public func setClockOutEnabled(_ enabled: Bool) { clockFlag.store(enabled, ordering: .relaxed) }

    // MARK: - Controller thread

    /// A MIDI channel message played live into the instrument in `slot`, heard at the start of
    /// the next block. One thread only — the MIDI input's. Note on/off and controllers 120/123.
    public func playLive(slot: Int, status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        guard slot >= 0, slot < slotCapacity, slot <= 0xFF else { return }
        live.push(UInt32(slot) << 24 | UInt32(status) << 16 | UInt32(data1 & 0x7F) << 8 | UInt32(data2 & 0x7F))
    }

    /// The playhead in samples, for a small leaf view — never for a view body that hosts menus.
    public var positionSample: Int64 { position.load(ordering: .relaxed) }

    // MARK: - Render thread

    /// Writes `frameCount` frames into `left` and `right` (overwriting them).
    /// `hostTime` is when the first frame plays; it stamps the MIDI clock this call produces.
    public func render(frameCount: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
                       hostTime: UInt64 = 0) {
        callHostTime = hostTime
        var done = 0
        while done < frameCount {
            chunkStart = done
            let frames = Swift.min(frameCount - done, Self.maximumFrames)
            outputs[0] = left + done
            outputs[1] = right + done
            outputCount = 2
            renderChunk(frames: frames)
            done += frames
        }
    }

    /// Writes `frameCount` frames into each of `channelCount` channels (overwriting them):
    /// the master mix on 1/2, each routed track added into its own pair. A pair the device lacks
    /// plays in the master mix; one channel gets the mix folded to mono.
    public func render(frameCount: Int, channels: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int,
                       hostTime: UInt64 = 0) {
        guard channelCount > 0 else { return }
        callHostTime = hostTime
        let used = Swift.min(channelCount, Track.outputChannelLimit)
        for c in used..<channelCount { channels[c].update(repeating: 0, count: frameCount) }
        var done = 0
        while done < frameCount {
            let frames = Swift.min(frameCount - done, Self.maximumFrames)
            chunkStart = done
            for c in 0..<used { outputs[c] = channels[c] + done }
            if used == 1 { outputs[1] = monoRight }
            outputCount = Swift.max(used, 2)
            renderChunk(frames: frames)
            if used == 1 {
                let mono = outputs[0]
                for i in 0..<frames { mono[i] = (mono[i] + monoRight[i]) * 0.5 }
            }
            done += frames
        }
    }

    /// The pair a lane adds into: its own, or the master mix.
    private func pair(_ output: Int) -> (UnsafeMutablePointer<Float>, UnsafeMutablePointer<Float>) {
        guard output >= 2, output + 1 < outputCount else { return (outputs[0], outputs[1]) }
        return (outputs[output], outputs[output + 1])
    }

    private func renderChunk(frames: Int) {
        for c in 0..<outputCount { outputs[c].update(repeating: 0, count: frames) }
        let left = outputs[0], right = outputs[1]

        takePendingSnapshot()

        let seek = seekRequest.exchange(-1, ordering: .acquiringAndReleasing)
        if seek >= 0 {
            playhead = seek
            position.store(seek, ordering: .relaxed)
            releaseAllNotes()
            resync()
        }
        playLiveEvents()
        let playing = isPlayingFlag.load(ordering: .acquiring)
        let clocking = clockFlag.load(ordering: .relaxed)
        if clocking { sendTransport(playing: playing, sought: seek >= 0) }
        if wasPlaying, !playing {
            releaseAllNotes()
            stopSessionClips()
        }
        if !wasPlaying, playing { resync() }
        wasPlaying = playing
        takeLaunchRequests(playing: playing)
        metronome.isEnabled = clickFlag.load(ordering: .relaxed)

        guard playing, let box = current else {
            renderVoices(0..<frames, left: left, right: right)
            renderUnits(frames: frames)
            mixLanes(frames: frames)
            mixReturns(frames: frames)
            return
        }
        let snapshot = box.snapshot
        let blockEnd = playhead + Int64(frames)
        let beatTicks = MusicalTime.ticksPerBeat(snapshot.timeSignature)
        let barTicks = MusicalTime.ticksPerBar(snapshot.timeSignature)
        var rendered = 0

        while true {
            // The earliest due event: a launch, a session note, an arrangement note, or the next
            // beat. At one sample a launch comes first, so the old clip's notes there never play.
            var due = Due(sample: snapshot.time.sample(at: nextBeat))
            for (index, lane) in snapshot.lanes.enumerated() {
                let session = sessions[lane.slot]
                if case .none = session.pending {} else {
                    due.offer(snapshot.time.sample(at: session.pendingTick), index, .launch)
                }
                if session.index >= 0, session.index < lane.clips.count {
                    let clip = lane.clips[session.index]
                    if session.cursor < clip.events.count {
                        due.offer(snapshot.time.sample(at: session.base + clip.events[session.cursor].tick), index, .session)
                    }
                }
                let cursor = cursors[lane.slot]
                if !session.overrides, cursor < lane.events.count {
                    due.offer(snapshot.time.sample(at: lane.events[cursor].tick), index, .arrangement)
                }
            }
            guard due.sample < blockEnd else { break }

            let offset = Swift.min(Swift.max(Int(due.sample - playhead), rendered), frames)
            renderVoices(rendered..<offset, left: left, right: right)
            rendered = offset

            switch due.kind {
            case .beat:
                metronome.trigger(accent: barTicks > 0 && nextBeat % barTicks == 0)
                nextBeat += Swift.max(beatTicks, 1)
            case .arrangement:
                let lane = snapshot.lanes[due.lane]
                play(lane.events[cursors[lane.slot]], on: lane, offset: offset)
                cursors[lane.slot] += 1
            case .session:
                let lane = snapshot.lanes[due.lane]
                var session = sessions[lane.slot]
                let clip = lane.clips[session.index]
                play(clip.events[session.cursor], on: lane, offset: offset)
                session.cursor += 1
                if session.cursor >= clip.events.count {
                    session.cursor = 0
                    session.base += Swift.max(clip.length, 1)
                }
                sessions[lane.slot] = session
            case .launch:
                fire(snapshot.lanes[due.lane])
            }
        }
        renderVoices(rendered..<frames, left: left, right: right)
        if clocking { sendClocks(snapshot, blockEnd: blockEnd) }
        renderUnits(frames: frames)
        mixLanes(frames: frames)
        renderAudio(snapshot, frames: frames)
        mixReturns(frames: frames)
        playhead = blockEnd
        position.store(playhead, ordering: .relaxed)
    }

    private func play(_ event: PlaybackPlan.NoteEvent, on lane: EngineSnapshot.Lane, offset: Int) {
        switch (event.kind, lane.device) {
        case (.noteOn(let velocity), .synth): synths[lane.slot].noteOn(pitch: event.pitch, velocity: velocity)
        case (.noteOff, .synth): synths[lane.slot].noteOff(pitch: event.pitch)
        case (.noteOn(let velocity), .drums): drums[lane.slot].noteOn(pitch: event.pitch, velocity: velocity)
        case (.noteOff, .drums): drums[lane.slot].noteOff(pitch: event.pitch)
        case (.noteOn(let velocity), .sampler): samplers[lane.slot].noteOn(pitch: event.pitch, velocity: velocity)
        case (.noteOff, .sampler): samplers[lane.slot].noteOff(pitch: event.pitch)
        // A plugin gets the note at its frame in this block and renders the block once, below.
        case (.noteOn(let velocity), .plugin): lane.unit?.noteOn(pitch: event.pitch, velocity: velocity, offset: offset)
        case (.noteOff, .plugin): lane.unit?.noteOff(pitch: event.pitch, offset: offset)
        }
    }

    // MARK: - Session

    private func report(_ slot: Int, _ clip: ClipID?, _ state: LaunchReport.State) {
        launchReports.push(LaunchReport(slot: slot, clip: clip, state: state))
    }

    /// Ends every sounding note of one track's instrument.
    private func silence(_ lane: EngineSnapshot.Lane) {
        synths[lane.slot].allNotesOff()
        samplers[lane.slot].allNotesOff()
        lane.unit?.allNotesOff()
    }

    private func clipIndex(_ clip: ClipID, in lane: EngineSnapshot.Lane) -> Int {
        lane.clips.firstIndex { $0.clip == clip } ?? -1
    }

    private func takeLaunchRequests(playing: Bool) {
        guard let snapshot = current?.snapshot else {
            while launchRequests.pop() != nil {}
            return
        }
        while let request = launchRequests.pop() {
            guard let lane = snapshot.lanes.first(where: { $0.slot == request.slot }) else { continue }
            let tick = snapshot.time.tick(atSample: playhead)
            switch request.action {
            case .backToArrangement:
                silence(lane)
                sessions[lane.slot] = SessionSlot()
                cursors[lane.slot] = PlaybackPlan.firstIndex(in: lane.events, atOrAfter: tick)
                report(lane.slot, nil, .arrangement)
                continue
            case .launch(let clip):
                sessions[lane.slot].pending = .launch(clip)
                report(lane.slot, clip, .queued)
            case .stop:
                guard sessions[lane.slot].clip != nil else {
                    sessions[lane.slot].pending = .none
                    continue
                }
                sessions[lane.slot].pending = .stop
            }
            sessions[lane.slot].pendingTick = playing ? boundary(after: tick, snapshot) : tick
            if !playing { fire(lane) }
        }
    }

    /// The first launch boundary at or after `tick` that has not yet been played.
    private func boundary(after tick: Tick, _ snapshot: EngineSnapshot) -> Tick {
        let stored = launchQuantum.load(ordering: .relaxed)
        let quantum = stored < 0 ? MusicalTime.ticksPerBar(snapshot.timeSignature) : stored
        guard quantum > 0 else { return tick }
        var at = ((tick + quantum - 1) / quantum) * quantum
        if snapshot.time.sample(at: at) < playhead { at += quantum }
        return at
    }

    /// The slot's pending launch or stop takes effect.
    private func fire(_ lane: EngineSnapshot.Lane) {
        var session = sessions[lane.slot]
        switch session.pending {
        case .none:
            return
        case .launch(let clip):
            silence(lane)
            session.overrides = true
            session.clip = clip
            session.index = clipIndex(clip, in: lane)
            session.launchTick = session.pendingTick
            session.base = session.pendingTick
            session.cursor = 0
            if session.index < 0 { session.clip = nil }
            report(lane.slot, session.clip ?? clip, session.index < 0 ? .stopped : .playing)
        case .stop:
            silence(lane)
            report(lane.slot, session.clip, .stopped)
            session.clip = nil
            session.index = -1
        }
        session.pending = .none
        sessions[lane.slot] = session
    }

    /// The transport stopped: every clip stops with it; the tracks stay off the arrangement.
    private func stopSessionClips() {
        for slot in 0..<slotCapacity where sessions[slot].clip != nil || !sessions[slot].isIdle {
            if let clip = sessions[slot].clip { report(slot, clip, .stopped) }
            sessions[slot].clip = nil
            sessions[slot].index = -1
            sessions[slot].pending = .none
        }
    }

    private func takePendingSnapshot() {
        guard let pointer = pending.exchange(nil, ordering: .acquiringAndReleasing) else { return }
        // Unretained: the main thread's `published` list owns it until we acknowledge a
        // newer one, so this assignment's release of the old box never frees on this thread.
        current = Unmanaged<SnapshotBox>.fromOpaque(pointer).takeUnretainedValue()
        guard let snapshot = current?.snapshot else { return }

        // A slot handed to a different track, or no track at all, starts silent.
        for slot in 0..<slotCapacity {
            var owner: TrackID?
            for lane in snapshot.lanes where lane.slot == slot {
                owner = lane.track
                break
            }
            if owners[slot] != owner {
                synths[slot].reset()
                drums[slot].reset()
                samplers[slot].reset()
                owners[slot] = owner
                if sessions[slot].overrides { report(slot, nil, .arrangement) }
                sessions[slot] = SessionSlot()
            }
        }
        // A playing clip follows its edits; a deleted one stops.
        for lane in snapshot.lanes {
            guard let clip = sessions[lane.slot].clip else { continue }
            let index = clipIndex(clip, in: lane)
            sessions[lane.slot].index = index
            if index < 0 {
                sessions[lane.slot].clip = nil
                report(lane.slot, clip, .stopped)
            }
        }
        // Every sampler now points at this snapshot's buffer or none. This happens BEFORE the
        // acknowledgement below: until then the main thread keeps the previous snapshot — and
        // with it every buffer a sampler let go of here — alive, so no buffer is ever freed on
        // this thread.
        for slot in 0..<slotCapacity {
            var sample: SampleBuffer?
            for lane in snapshot.lanes where lane.slot == slot {
                sample = lane.sample
                break
            }
            samplers[slot].setSample(sample)
        }
        // A track that changes instrument starts the new one silent and cuts the old one.
        for lane in snapshot.lanes where devices[lane.slot] != lane.device {
            synths[lane.slot].reset()
            drums[lane.slot].reset()
            samplers[lane.slot].reset()
            devices[lane.slot] = lane.device
        }
        for lane in snapshot.lanes where synths[lane.slot].patch != lane.patch {
            synths[lane.slot].setPatch(lane.patch)
        }
        // Only a track whose notes changed lets go of what it holds: a deleted note must not
        // hang, but a fader, a pan or a send must not cut a held chord.
        for lane in snapshot.lanes where revisions[lane.slot] != lane.eventsRevision {
            silence(lane)
            revisions[lane.slot] = lane.eventsRevision
        }
        resync()
        acknowledged.store(snapshot.generation, ordering: .releasing)
    }

    private func playLiveEvents() {
        while let event = live.pop() {
            let slot = Int(event >> 24)
            let status = UInt8((event >> 16) & 0xFF), pitch = UInt8((event >> 8) & 0x7F), value = UInt8(event & 0x7F)
            guard slot < slotCapacity else { continue }
            let kind = status & 0xF0
            let on = kind == 0x90 && value > 0
            let off = kind == 0x80 || (kind == 0x90 && value == 0)
            let allOff = kind == 0xB0 && (pitch == 123 || pitch == 120)
            switch devices[slot] {
            case .synth:
                if on { synths[slot].noteOn(pitch: pitch, velocity: value) }
                if off { synths[slot].noteOff(pitch: pitch) }
                if allOff { synths[slot].allNotesOff() }
            case .drums:
                if on { drums[slot].noteOn(pitch: pitch, velocity: value) }
                if off { drums[slot].noteOff(pitch: pitch) }
            case .sampler:
                if on { samplers[slot].noteOn(pitch: pitch, velocity: value) }
                if off { samplers[slot].noteOff(pitch: pitch) }
                if allOff { samplers[slot].allNotesOff() }
            case .plugin:
                guard let unit = current?.snapshot.lanes.first(where: { $0.slot == slot })?.unit else { continue }
                if on { unit.noteOn(pitch: pitch, velocity: value, offset: 0) }
                if off { unit.noteOff(pitch: pitch, offset: 0) }
                if allOff { unit.allNotesOff() }
            }
        }
    }

    /// Points every cursor and the beat counter at the playhead.
    private func resync() {
        guard let snapshot = current?.snapshot else { return }
        let tick = snapshot.time.tick(atSample: playhead)
        for lane in snapshot.lanes {
            // The playhead's tick is rounded down: skip events of that tick that already played.
            var cursor = PlaybackPlan.firstIndex(in: lane.events, atOrAfter: tick)
            while cursor < lane.events.count, snapshot.time.sample(at: lane.events[cursor].tick) < playhead { cursor += 1 }
            cursors[lane.slot] = cursor
        }
        let beatTicks = Swift.max(MusicalTime.ticksPerBeat(snapshot.timeSignature), 1)
        var beat = (tick / beatTicks) * beatTicks
        if snapshot.time.sample(at: beat) < playhead { beat += beatTicks }
        nextBeat = beat
        // A playing clip keeps its loop phase from where it was launched.
        for lane in snapshot.lanes {
            var session = sessions[lane.slot]
            guard session.index >= 0, session.index < lane.clips.count else { continue }
            let clip = lane.clips[session.index]
            let length = Swift.max(clip.length, 1)
            let since = tick - session.launchTick
            let passes = since >= 0 ? since / length : -((-since + length - 1) / length)
            session.base = session.launchTick + passes * length
            var cursor = PlaybackPlan.firstIndex(in: clip.events, atOrAfter: tick - session.base)
            while cursor < clip.events.count,
                  snapshot.time.sample(at: session.base + clip.events[cursor].tick) < playhead { cursor += 1 }
            session.cursor = cursor
            sessions[lane.slot] = session
        }
        let clockTicks = MusicalTime.ticksPerQuarter / Self.clocksPerQuarter
        var clock = ((tick + clockTicks - 1) / clockTicks) * clockTicks
        if snapshot.time.sample(at: clock) < playhead { clock += clockTicks }
        nextClock = clock
    }

    private func emit(_ status: UInt8, _ data1: UInt8 = 0, _ data2: UInt8 = 0, at offset: Int = 0) {
        clockOut.push(TimedMIDIMessage(hostTime: callHostTime, frame: chunkStart + offset,
                                       status: status, data1: data1, data2: data2))
    }

    /// Start from the top, or stop · song position · continue from anywhere else, so a device
    /// following the clock lands on the same sixteenth.
    private func sendTransport(playing: Bool, sought: Bool) {
        if wasPlaying, !playing {
            emit(0xFC)
            return
        }
        guard playing, !wasPlaying || sought else { return }
        if !wasPlaying, playhead == 0 {
            emit(0xFA)
            return
        }
        if wasPlaying { emit(0xFC) }
        let tick = current?.snapshot.time.tick(atSample: playhead) ?? 0
        let sixteenth = Swift.min(Swift.max(tick / (MusicalTime.ticksPerQuarter / 4), 0), 0x3FFF)
        emit(0xF2, UInt8(sixteenth & 0x7F), UInt8(sixteenth >> 7))
        emit(0xFB)
    }

    private func sendClocks(_ snapshot: EngineSnapshot, blockEnd: Int64) {
        let clockTicks = MusicalTime.ticksPerQuarter / Self.clocksPerQuarter
        while true {
            let sample = snapshot.time.sample(at: nextClock)
            guard sample < blockEnd else { break }
            emit(0xF8, at: Int(Swift.max(sample - playhead, 0)))
            nextClock += clockTicks
        }
    }

    private func releaseAllNotes() {
        for slot in 0..<slotCapacity {
            synths[slot].allNotesOff()
            samplers[slot].allNotesOff()
        }
        if let snapshot = current?.snapshot {
            for lane in snapshot.lanes { lane.unit?.allNotesOff() }
        }
    }

    /// Every hosted unit renders every block, playing or not, so its notes ring out and its own
    /// clock never skips.
    private func renderUnits(frames: Int) {
        guard let snapshot = current?.snapshot else { return }
        for lane in snapshot.lanes {
            lane.unit?.render(frames: frames, left: bus(lane.slot, busLeft), right: bus(lane.slot, busRight),
                              gainLeft: 1, gainRight: 1)
        }
    }

    private func bus(_ slot: Int, _ base: UnsafeMutablePointer<Float>) -> UnsafeMutablePointer<Float> {
        base + slot * Self.maximumFrames
    }

    /// Every lane's bus through its inserts, then into the mix at its gains, then cleared. Runs
    /// for silent lanes too, so an effect's tail rings out after the last note.
    private func mixLanes(frames: Int) {
        guard let snapshot = current?.snapshot else { return }
        for lane in snapshot.lanes {
            let (left, right) = pair(lane.output)
            let l = bus(lane.slot, busLeft), r = bus(lane.slot, busRight)
            for effect in lane.inserts { effect.process(frames: frames, left: l, right: r) }
            for i in 0..<frames {
                left[i] += l[i] * lane.gainLeft
                right[i] += r[i] * lane.gainRight
            }
            send(lane.sends, frames: frames, left: l, right: r)
            l.update(repeating: 0, count: frames)
            r.update(repeating: 0, count: frames)
        }
    }

    /// Adds a track's processed bus into the return buses it sends to.
    private func send(_ sends: [EngineSnapshot.SendTap], frames: Int, left: UnsafeMutablePointer<Float>,
                      right: UnsafeMutablePointer<Float>) {
        for tap in sends where tap.bus >= 0 && tap.bus < Self.returnCapacity {
            let l = returnLeft + tap.bus * Self.maximumFrames, r = returnRight + tap.bus * Self.maximumFrames
            for i in 0..<frames {
                l[i] += left[i] * tap.gainLeft
                r[i] += right[i] * tap.gainRight
            }
        }
    }

    /// Every return bus through its effects, into the mix at its fader, then cleared — every
    /// block, so a reverb's tail rings out after the transport stops.
    private func mixReturns(frames: Int) {
        guard let snapshot = current?.snapshot else { return }
        for lane in snapshot.returns {
            let (left, right) = pair(lane.output)
            let l = returnLeft + lane.bus * Self.maximumFrames, r = returnRight + lane.bus * Self.maximumFrames
            for effect in lane.inserts { effect.process(frames: frames, left: l, right: r) }
            for i in 0..<frames {
                left[i] += l[i] * lane.gainLeft
                right[i] += r[i] * lane.gainRight
            }
            l.update(repeating: 0, count: frames)
            r.update(repeating: 0, count: frames)
        }
    }

    /// Output frames of fade at each edge of an audio region.
    static let regionFadeFrames: Double = 64

    /// Audio regions are read straight from the snapshot at the playhead — no voices, no state —
    /// so a seek or an edit lands on the right frame at once.
    private func renderAudio(_ snapshot: EngineSnapshot, frames: Int) {
        let blockEnd = playhead + Int64(frames)
        for lane in snapshot.audioLanes where lane.gainLeft != 0 || lane.gainRight != 0 || !lane.inserts.isEmpty {
            let (left, right) = pair(lane.output)
            audioLeft.update(repeating: 0, count: frames)
            audioRight.update(repeating: 0, count: frames)
            for region in lane.regions {
                guard region.startSample < blockEnd else { break }
                guard region.endSample > playhead else { continue }
                let first = Int(Swift.max(region.startSample - playhead, 0))
                let count = Int(Swift.min(region.endSample, blockEnd) - playhead) - first
                guard count > 0 else { continue }
                let mono = scratch + first
                mono.update(repeating: 0, count: count)
                region.buffer.add(into: UnsafeMutableBufferPointer(start: mono, count: count),
                                  elapsed: playhead + Int64(first) - region.startSample, step: region.step,
                                  offset: region.offset, length: region.length,
                                  fade: Self.regionFadeFrames * region.step)
                for i in 0..<count {
                    audioLeft[first + i] += mono[i]
                    audioRight[first + i] += mono[i]
                }
            }
            for effect in lane.inserts { effect.process(frames: frames, left: audioLeft, right: audioRight) }
            for i in 0..<frames {
                left[i] += audioLeft[i] * lane.gainLeft
                right[i] += audioRight[i] * lane.gainRight
            }
            send(lane.sends, frames: frames, left: audioLeft, right: audioRight)
        }
    }

    private func renderVoices(_ range: Range<Int>, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        guard !range.isEmpty else { return }
        if let snapshot = current?.snapshot {
            for lane in snapshot.lanes {
                let sounding = switch lane.device {
                case .synth: synths[lane.slot].activeVoiceCount > 0
                case .drums: drums[lane.slot].activeVoiceCount > 0
                case .sampler: samplers[lane.slot].activeVoiceCount > 0
                case .plugin: false
                }
                guard sounding else { continue }
                let mono = scratch + range.lowerBound
                mono.update(repeating: 0, count: range.count)
                let buffer = UnsafeMutableBufferPointer(start: mono, count: range.count)
                switch lane.device {
                case .synth: synths[lane.slot].render(into: buffer)
                case .drums: drums[lane.slot].render(into: buffer)
                case .sampler: samplers[lane.slot].render(into: buffer)
                case .plugin: break
                }
                let l = bus(lane.slot, busLeft) + range.lowerBound, r = bus(lane.slot, busRight) + range.lowerBound
                for i in 0..<range.count {
                    l[i] += mono[i]
                    r[i] += mono[i]
                }
            }
        }
        metronome.render(left: left, right: right, range: range)
    }
}

/// The earliest event of a render step. At one sample the higher kind wins; within a kind the
/// first lane does.
private struct Due {
    enum Kind: Int { case beat, arrangement, session, launch }

    var sample: Int64
    var lane = -1
    var kind = Kind.beat

    mutating func offer(_ sample: Int64, _ lane: Int, _ kind: Kind) {
        guard sample < self.sample || (sample == self.sample && kind.rawValue > self.kind.rawValue) else { return }
        self.sample = sample
        self.lane = lane
        self.kind = kind
    }
}

/// A snapshot with an identity, so it can cross threads behind one pointer.
final class SnapshotBox: Sendable {
    let snapshot: EngineSnapshot
    init(_ snapshot: EngineSnapshot) { self.snapshot = snapshot }
}

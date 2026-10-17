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
/// Editing while playing releases the sounding notes and re-seeks, so a deleted note can
/// never hang; a note that was already sounding is not restarted mid-way.
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

    // Render thread only.
    private var current: SnapshotBox?
    private let synths: UnsafeMutablePointer<PolySynth>
    private let drums: UnsafeMutablePointer<DrumKit>
    private let samplers: UnsafeMutablePointer<Sampler>
    private let devices: UnsafeMutablePointer<InstrumentDevice>
    private let owners: UnsafeMutablePointer<TrackID?>
    private let cursors: UnsafeMutablePointer<Int>
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
    public func render(frameCount: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        var done = 0
        while done < frameCount {
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
    public func render(frameCount: Int, channels: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int) {
        guard channelCount > 0 else { return }
        let used = Swift.min(channelCount, Track.outputChannelLimit)
        for c in used..<channelCount { channels[c].update(repeating: 0, count: frameCount) }
        var done = 0
        while done < frameCount {
            let frames = Swift.min(frameCount - done, Self.maximumFrames)
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
        if wasPlaying, !playing { releaseAllNotes() }
        if !wasPlaying, playing { resync() }
        wasPlaying = playing
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
            // The earliest due event: a note on any lane, or the next beat.
            var dueSample = snapshot.time.sample(at: nextBeat)
            var dueLane = -1
            for (index, lane) in snapshot.lanes.enumerated() {
                let cursor = cursors[lane.slot]
                guard cursor < lane.events.count else { continue }
                let sample = snapshot.time.sample(at: lane.events[cursor].tick)
                if sample < dueSample || (sample == dueSample && dueLane == -1) {
                    dueSample = sample
                    dueLane = index
                }
            }
            guard dueSample < blockEnd else { break }

            let offset = Swift.min(Swift.max(Int(dueSample - playhead), rendered), frames)
            renderVoices(rendered..<offset, left: left, right: right)
            rendered = offset

            if dueLane >= 0 {
                let lane = snapshot.lanes[dueLane]
                let event = lane.events[cursors[lane.slot]]
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
                cursors[lane.slot] += 1
            } else {
                metronome.trigger(accent: barTicks > 0 && nextBeat % barTicks == 0)
                nextBeat += Swift.max(beatTicks, 1)
            }
        }
        renderVoices(rendered..<frames, left: left, right: right)
        renderUnits(frames: frames)
        mixLanes(frames: frames)
        renderAudio(snapshot, frames: frames)
        mixReturns(frames: frames)
        playhead = blockEnd
        position.store(playhead, ordering: .relaxed)
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
        releaseAllNotes()
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
            cursors[lane.slot] = PlaybackPlan.firstIndex(in: lane.events, atOrAfter: tick)
        }
        let beatTicks = Swift.max(MusicalTime.ticksPerBeat(snapshot.timeSignature), 1)
        var beat = (tick / beatTicks) * beatTicks
        if snapshot.time.sample(at: beat) < playhead { beat += beatTicks }
        nextBeat = beat
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

/// A snapshot with an identity, so it can cross threads behind one pointer.
final class SnapshotBox: Sendable {
    let snapshot: EngineSnapshot
    init(_ snapshot: EngineSnapshot) { self.snapshot = snapshot }
}

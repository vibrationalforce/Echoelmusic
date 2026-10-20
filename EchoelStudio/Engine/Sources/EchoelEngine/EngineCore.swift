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
    /// Return tracks the engine has buses for: as many as a song may hold.
    public static let returnCapacity = Track.limit(for: .returnTrack)

    // Main → render.
    private let isPlayingFlag = Atomic<Bool>(false)
    private let clickFlag = Atomic<Bool>(true)
    private let seekRequest = Atomic<Int64>(-1)
    /// Samples to move the playhead by without a seek, for phase correction.
    private let nudgeRequest = Atomic<Int64>(0)
    /// Samples to jump by AS a seek (notes released, cues rebuilt), for a far-off phase.
    private let jumpRequest = Atomic<Int64>(0)
    private let pending = Atomic<UnsafeMutableRawPointer?>(nil)
    // Render → main.
    private let acknowledged = Atomic<UInt64>(0)
    private let position = Atomic<Int64>(0)
    /// Where the song stood at the end of the last rendered buffer, written under a sequence
    /// counter (odd while writing) so the main thread reads the four values consistently.
    private let anchorSequence = Atomic<UInt64>(0)
    private let anchorHostTime = Atomic<UInt64>(0)
    private let anchorFrames = Atomic<Int64>(0)
    private let anchorTick = Atomic<UInt64>(0)
    private let anchorSamplesPerTick = Atomic<UInt64>(0)
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
    /// The interface inputs, from the input callback; a monitoring audio lane plays one.
    public let inputs = InputMonitor()
    /// The inputs of the chunk being rendered, `maximumFrames` each, read once per chunk so
    /// two tracks can monitor the same input.
    private let heard: UnsafeMutablePointer<Float>
    /// The right half of the mix when the device has one channel.
    private let monoRight: UnsafeMutablePointer<Float>
    /// One audio lane's mono signal for part of a chunk, before it is faded into the lane.
    private let segment: UnsafeMutablePointer<Float>
    private var metronome: Metronome
    private var playhead: Int64 = 0
    /// How far this chunk's nudge moved the playhead; audio crossfades across it.
    private var nudgedBy: Int64 = 0
    private var wasPlaying = false
    private var nextBeat: Tick = 0
    private var nextClock: Tick = 0
    /// Ticks at the start and end of the chunk being mixed; automated gains ramp between them.
    private var mixFrom: Double = 0
    private var mixTo: Double = 0
    /// The gains each mix point ended the last chunk on (NaN: none yet), so every change —
    /// a hand on a fader, a MIDI knob, an automation jump after a seek — ramps over one chunk
    /// instead of stepping. Points: instrument slots, then audio tracks, then return buses.
    private let gainMemory: UnsafeMutablePointer<Float>
    /// The same for each send, per mix point and return bus.
    private let sendMemory: UnsafeMutablePointer<Float>
    /// Audio tracks whose gains are smoothed; more than this play with fixed steps.
    static let smoothedAudioTracks = Track.limit(for: .audio)
    private var mixPoints: Int { slotCapacity + Self.smoothedAudioTracks + Self.returnCapacity }
    private var sendingPoints: Int { slotCapacity + Self.smoothedAudioTracks }

    /// Peak meters: one per mix point (instrument slot, audio track, return), then the master.
    public let meters: MeterBank
    /// The master's reading in `meters`.
    public var masterMeter: Int { mixPoints }
    /// What a reading falls by over the chunk being rendered.
    private var meterFall: Float = 1

    /// Main thread: which reading in `meters` shows each track of `snapshot`. An audio track
    /// past the ones the mix smooths has none.
    public func meterIndices(for snapshot: EngineSnapshot) -> [TrackID: Int] {
        var indices: [TrackID: Int] = [:]
        for lane in snapshot.lanes { indices[lane.track] = lane.slot }
        for (index, lane) in snapshot.audioLanes.enumerated() where index < Self.smoothedAudioTracks {
            indices[lane.track] = slotCapacity + index
        }
        for lane in snapshot.returns { indices[lane.track] = slotCapacity + Self.smoothedAudioTracks + lane.bus }
        return indices
    }
    /// The next sample at which automated synth parameters are set again.
    private var automationNext: Int64 = 0
    /// The tick unit automation was last sent for; false until the first send after a seek or
    /// a new snapshot.
    private var unitAutomationTick: Double = 0
    private var unitAutomationPrimed = false
    /// Frames between two settings of an automated synth parameter: 0.67 ms at 48 kHz. The
    /// synth glides between them, so the sweep is continuous.
    static let automationStep: Int64 = 32
    /// Host time of the current render call, and where the current chunk starts in it.
    private var callHostTime: UInt64 = 0
    private var chunkStart = 0

    // Main thread only.
    private var published: [SnapshotBox] = []

    public init(sampleRate: Double, slotCapacity: Int = Track.limit(for: .instrument)) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.slotCapacity = Swift.max(1, slotCapacity)
        meters = MeterBank(count: self.slotCapacity + Self.smoothedAudioTracks + Self.returnCapacity + 1)
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
        let points = self.slotCapacity + Self.smoothedAudioTracks + Self.returnCapacity
        gainMemory = .allocate(capacity: points * 2)
        gainMemory.initialize(repeating: .nan, count: points * 2)
        let sending = (self.slotCapacity + Self.smoothedAudioTracks) * Self.returnCapacity
        sendMemory = .allocate(capacity: sending * 2)
        sendMemory.initialize(repeating: .nan, count: sending * 2)
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
        heard = .allocate(capacity: InputMonitor.channelLimit * Self.maximumFrames)
        heard.initialize(repeating: 0, count: InputMonitor.channelLimit * Self.maximumFrames)
        segment = .allocate(capacity: Self.maximumFrames)
        segment.initialize(repeating: 0, count: Self.maximumFrames)
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
        gainMemory.deallocate()
        sendMemory.deallocate()
        scratch.deallocate()
        busLeft.deallocate()
        busRight.deallocate()
        audioLeft.deallocate()
        heard.deallocate()
        audioRight.deallocate()
        returnLeft.deallocate()
        returnRight.deallocate()
        monoRight.deallocate()
        segment.deallocate()
        outputs.deallocate()
    }

    // MARK: - Main thread

    public func publish(_ snapshot: EngineSnapshot) {
        inputs.want(snapshot.audioLanes.map(\.monitor).filter { $0 >= 0 })
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

    /// Stops where it is, as an external clock's Stop asks.
    public func pause() { isPlayingFlag.store(false, ordering: .releasing) }

    /// Stops and returns to the start.
    public func stop() {
        isPlayingFlag.store(false, ordering: .releasing)
        seekRequest.store(0, ordering: .releasing)
    }

    /// Main thread: moves the playhead by a few samples at the next block — no notes released,
    /// nothing re-cued, so it is inaudible. Events the move skips over play at once; events it
    /// moves back over do not play twice. For keeping in phase with an external clock.
    public func nudge(bySamples samples: Int64) {
        nudgeRequest.add(samples, ordering: .relaxed)
    }

    /// Main thread: moves the playhead by `samples` at the next block as a seek does — held
    /// notes released, cues rebuilt. Relative, so it cannot land a buffer off.
    public func jump(bySamples samples: Int64) {
        jumpRequest.add(samples, ordering: .relaxed)
    }

    /// The musical position at a known host time, in the render thread's own time base.
    public struct TimelineAnchor: Equatable, Sendable {
        /// When the first frame of the last buffer plays (the render call's host time).
        public let hostTime: UInt64
        /// Frames in that buffer.
        public let frames: Int64
        /// The position in fractional ticks after that buffer.
        public let tick: Double
        public let samplesPerTick: Double
    }

    /// Main thread: where the song stood after the last buffer, or nil while stopped or when the
    /// device gives no host time. Converted by the snapshot that was rendered, never by a newer
    /// project the render thread has not taken yet.
    public func timelineAnchor() -> TimelineAnchor? {
        for _ in 0..<4 {
            let before = anchorSequence.load(ordering: .acquiring)
            guard before & 1 == 0 else { continue }
            let anchor = TimelineAnchor(hostTime: anchorHostTime.load(ordering: .acquiring),
                                        frames: anchorFrames.load(ordering: .acquiring),
                                        tick: Double(bitPattern: anchorTick.load(ordering: .acquiring)),
                                        samplesPerTick: Double(bitPattern: anchorSamplesPerTick.load(ordering: .acquiring)))
            guard anchorSequence.load(ordering: .acquiring) == before else { continue }
            guard anchor.hostTime != 0, anchor.samplesPerTick > 0, anchor.tick.isFinite else { return nil }
            return anchor
        }
        return nil
    }

    /// Render thread, after a whole buffer.
    private func publishAnchor(frames: Int) {
        anchorSequence.add(1, ordering: .acquiringAndReleasing)
        if callHostTime != 0, wasPlaying, let time = current?.snapshot.time {
            let tick = time.position(atSample: playhead)
            anchorHostTime.store(callHostTime, ordering: .releasing)
            anchorFrames.store(Int64(frames), ordering: .releasing)
            anchorTick.store(tick.bitPattern, ordering: .releasing)
            anchorSamplesPerTick.store(time.samplesPerTick(at: Tick(Swift.max(0, tick))).bitPattern, ordering: .releasing)
        } else {
            anchorHostTime.store(0, ordering: .releasing)
        }
        anchorSequence.add(1, ordering: .acquiringAndReleasing)
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
            processMaster(frames: frames)
            meterMaster(frames: frames)
            done += frames
        }
        publishAnchor(frames: frameCount)
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
            processMaster(frames: frames)
            meterMaster(frames: frames)
            if used == 1 {
                let mono = outputs[0]
                for i in 0..<frames { mono[i] = (mono[i] + monoRight[i]) * 0.5 }
            }
            done += frames
        }
        publishAnchor(frames: frameCount)
    }

    /// The master's inserts on the master pair, every chunk, so a limiter or a reverb tail runs
    /// on whether or not the song plays.
    private func processMaster(frames: Int) {
        guard let effects = current?.snapshot.masterEffects else { return }
        for effect in effects { effect.process(frames: frames, left: outputs[0], right: outputs[1]) }
    }

    /// The master pair's peaks, after everything was mixed into it.
    private func meterMaster(frames: Int) {
        meters.record(masterMeter, left: MeterBank.peak(outputs[0], frames: frames),
                      right: MeterBank.peak(outputs[1], frames: frames), fall: meterFall)
    }

    /// The pair a lane adds into: its own, or the master mix.
    private func pair(_ output: Int) -> (UnsafeMutablePointer<Float>, UnsafeMutablePointer<Float>) {
        guard output >= 2, output + 1 < outputCount else { return (outputs[0], outputs[1]) }
        return (outputs[output], outputs[output + 1])
    }

    private func renderChunk(frames: Int) {
        meterFall = MeterBank.fall(frames: frames, sampleRate: sampleRate)
        for c in 0..<outputCount { outputs[c].update(repeating: 0, count: frames) }
        let left = outputs[0], right = outputs[1]

        takePendingSnapshot()

        // Where the song was heard last block: a stop fades the audio tracks out from here,
        // although Stop has already sent the playhead home.
        let heardAt = playhead
        var seek = seekRequest.exchange(-1, ordering: .acquiringAndReleasing)
        let jump = jumpRequest.exchange(0, ordering: .relaxed)
        if seek < 0, jump != 0 { seek = Swift.max(0, playhead + jump) }
        if seek >= 0 {
            playhead = seek
            position.store(seek, ordering: .relaxed)
            releaseAllNotes()
            resync()
        }
        let shift = nudgeRequest.exchange(0, ordering: .relaxed)
        nudgedBy = 0
        if shift != 0, seek < 0 {
            let moved = Swift.max(0, playhead + shift)
            nudgedBy = moved - playhead
            playhead = moved
            position.store(playhead, ordering: .relaxed)
        }
        playLiveEvents()
        let playing = isPlayingFlag.load(ordering: .acquiring)
        let clocking = clockFlag.load(ordering: .relaxed)
        if clocking { sendTransport(playing: playing, sought: seek >= 0) }
        let stopping = wasPlaying && !playing
        if stopping { releaseAllNotes() }
        if !wasPlaying, playing { resync() }
        wasPlaying = playing
        // A stopping block still fades out the clips that were playing; they stop after it.
        if !stopping { takeLaunchRequests(playing: playing) }
        metronome.isEnabled = clickFlag.load(ordering: .relaxed)

        guard playing, let box = current else {
            let held = current?.snapshot.time.position(atSample: playhead) ?? 0
            mixFrom = held
            mixTo = held
            renderVoices(0..<frames, left: left, right: right)
            renderUnits(frames: frames)
            mixLanes(frames: frames)
            if let snapshot = current?.snapshot {
                renderAudio(snapshot, frames: frames, playing: false, fadingFrom: stopping ? heardAt : nil)
            }
            if stopping {
                stopSessionClips()
                takeLaunchRequests(playing: false)
            }
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
            if snapshot.automatesPatches || !snapshot.unitAutomation.isEmpty { due.offer(automationNext, -1, .automation) }
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
            case .automation:
                let tick = snapshot.time.position(atSample: due.sample)
                applyPatchAutomation(snapshot, at: tick)
                applyUnitAutomation(snapshot, at: tick, offset: offset)
                automationNext = Swift.max(due.sample, playhead) + Self.automationStep
            }
        }
        renderVoices(rendered..<frames, left: left, right: right)
        if clocking { sendClocks(snapshot, blockEnd: blockEnd) }
        renderUnits(frames: frames)
        mixFrom = snapshot.time.position(atSample: playhead)
        mixTo = snapshot.time.position(atSample: blockEnd)
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
        case let (.pitchBend(value), .synth): synths[lane.slot].pitchBend(Int(value))
        case let (.control(number, value), .synth): synths[lane.slot].controller(number, value)
        case let (.pitchBend(value), .plugin):
            lane.unit?.control(status: 0xE0, UInt8(value & 0x7F), UInt8(value >> 7 & 0x7F), offset: offset)
        case let (.control(number, value), .plugin): lane.unit?.control(status: 0xB0, number, value, offset: offset)
        // The kit and the sampler play notes only; the synth reads the wheels and the pedal.
        case (.pitchBend, _), (.control, _): break
        // An instrument from a later build is kept in the song and silent here.
        case (_, .unrecognized): break
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
            guard let lane = snapshot.lanes.first(where: { $0.slot == request.slot }) else {
                if let audio = snapshot.audioLanes.first(where: { $0.slot == request.slot }) {
                    takeAudioLaunch(request.action, on: audio, snapshot, playing: playing)
                }
                continue
            }
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

    /// A launch, stop or return on an audio track's slot. It takes effect at its sample inside
    /// `renderAudio`, or now while the transport is stopped.
    private func takeAudioLaunch(_ action: LaunchAction, on lane: EngineSnapshot.AudioLane, _ snapshot: EngineSnapshot,
                                 playing: Bool) {
        let slot = lane.slot
        guard slot >= 0, slot < slotCapacity else { return }
        let tick = snapshot.time.tick(atSample: playhead)
        switch action {
        case .backToArrangement:
            // At once, but through `renderAudio`, so what played fades into the regions.
            sessions[slot].pending = .arrangement
            sessions[slot].pendingTick = tick
            if !playing { fireAudio(lane) }
            return
        case .launch(let clip):
            sessions[slot].pending = .launch(clip)
            report(slot, clip, .queued)
        case .stop:
            guard sessions[slot].clip != nil else {
                sessions[slot].pending = .none
                return
            }
            sessions[slot].pending = .stop
        }
        sessions[slot].pendingTick = playing ? boundary(after: tick, snapshot) : tick
        if !playing { fireAudio(lane) }
    }

    /// An audio slot's pending launch or stop takes effect. A clip the lane does not have
    /// (its file is missing) reports stopped.
    private func fireAudio(_ lane: EngineSnapshot.AudioLane) {
        let slot = lane.slot
        guard slot >= 0, slot < slotCapacity else { return }
        var session = sessions[slot]
        switch session.pending {
        case .none:
            return
        case .launch(let clip):
            session.overrides = true
            session.launchTick = session.pendingTick
            if lane.loops.contains(where: { $0.clip == clip }) {
                session.clip = clip
                report(slot, clip, .playing)
            } else {
                session.clip = nil
                report(slot, clip, .stopped)
            }
        case .stop:
            report(slot, session.clip, .stopped)
            session.clip = nil
        case .arrangement:
            sessions[slot] = SessionSlot()
            report(slot, nil, .arrangement)
            return
        }
        session.pending = .none
        sessions[slot] = session
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
        case .arrangement:
            // Only audio slots return through a pending state.
            session = SessionSlot()
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
        let previous = current?.snapshot.time
        // Unretained: the main thread's `published` list owns it until we acknowledge a
        // newer one, so this assignment's release of the old box never frees on this thread.
        current = Unmanaged<SnapshotBox>.fromOpaque(pointer).takeUnretainedValue()
        guard let snapshot = current?.snapshot else { return }
        // A new tempo keeps the song where it is: bar 33 stays bar 33, only the time to the next
        // beat changes. Without this the playhead kept its sample and jumped in musical time.
        if let previous, previous != snapshot.time, playhead > 0 {
            playhead = Swift.max(0, snapshot.time.sample(atPosition: previous.position(atSample: playhead)))
            position.store(playhead, ordering: .relaxed)
        }
        unitAutomationPrimed = false

        // A slot handed to a different track, or no track at all, starts silent.
        for slot in 0..<slotCapacity {
            var owner: TrackID?
            for lane in snapshot.lanes where lane.slot == slot {
                owner = lane.track
                break
            }
            if owner == nil {
                for lane in snapshot.audioLanes where lane.slot == slot {
                    owner = lane.track
                    break
                }
            }
            if owners[slot] != owner {
                synths[slot].reset()
                drums[slot].reset()
                samplers[slot].reset()
                owners[slot] = owner
                if sessions[slot].overrides { report(slot, nil, .arrangement) }
                sessions[slot] = SessionSlot()
                // Another track's level is no place to ramp from.
                forget(point: slot)
            }
        }
        // A playing clip follows its edits; a deleted one stops.
        for lane in snapshot.audioLanes where lane.slot >= 0 && lane.slot < slotCapacity {
            guard let clip = sessions[lane.slot].clip, !lane.loops.contains(where: { $0.clip == clip }) else { continue }
            sessions[lane.slot].clip = nil
            report(lane.slot, clip, .stopped)
        }
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
            // 123 all notes off releases; 120 all sound off (panic) silences at once.
            let notesOff = kind == 0xB0 && pitch == 123
            let soundOff = kind == 0xB0 && pitch == 120
            let allOff = notesOff || soundOff
            let bend = kind == 0xE0
            let pedal = kind == 0xB0 && pitch == 64
            switch devices[slot] {
            case .synth:
                if on { synths[slot].noteOn(pitch: pitch, velocity: value) }
                if off { synths[slot].noteOff(pitch: pitch) }
                if bend { synths[slot].pitchBend(Int(pitch) | Int(value) << 7) }
                if kind == 0xB0 { synths[slot].controller(pitch, value) }
            case .drums:
                if on { drums[slot].noteOn(pitch: pitch, velocity: value) }
                if off { drums[slot].noteOff(pitch: pitch) }
                if soundOff { drums[slot].reset() }
            case .sampler:
                if on { samplers[slot].noteOn(pitch: pitch, velocity: value) }
                if off { samplers[slot].noteOff(pitch: pitch) }
                if notesOff { samplers[slot].allNotesOff() }
                if soundOff { samplers[slot].reset() }
            case .plugin:
                guard let unit = current?.snapshot.lanes.first(where: { $0.slot == slot })?.unit else { continue }
                if on { unit.noteOn(pitch: pitch, velocity: value, offset: 0) }
                if off { unit.noteOff(pitch: pitch, offset: 0) }
                if bend || pedal { unit.control(status: status, pitch, value) }
                if allOff { unit.allNotesOff() }
            case .unrecognized:
                break
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
        automationNext = playhead
        unitAutomationPrimed = false
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
            mix(l, r, into: left, right, frames: frames, curve: lane.mix, fixed: (lane.gainLeft, lane.gainRight),
                memory: memory(point: lane.slot), meter: lane.slot)
            send(lane.sends, from: lane.slot, frames: frames, left: l, right: r)
            l.update(repeating: 0, count: frames)
            r.update(repeating: 0, count: frames)
        }
    }

    private func forget(point: Int) {
        guard point >= 0, point < mixPoints else { return }
        gainMemory[point * 2] = .nan
        gainMemory[point * 2 + 1] = .nan
        guard point < sendingPoints else { return }
        for bus in 0..<Self.returnCapacity {
            let index = (point * Self.returnCapacity + bus) * 2
            sendMemory[index] = .nan
            sendMemory[index + 1] = .nan
        }
    }

    private func memory(point: Int) -> UnsafeMutablePointer<Float>? {
        point >= 0 && point < mixPoints ? gainMemory + point * 2 : nil
    }

    /// Frames between two evaluations of a moving gain: a bent lane is followed within 1.3 ms.
    static let gainSegment = 64

    /// Adds a stereo source into a destination at gains that may move. Fixed gains ramp from
    /// where `memory` ended the last chunk; a lane's gains are evaluated every 64 frames and
    /// ramped between, so a curve is followed and nothing steps. `memory` then holds the end.
    private func mix<Curve: GainCurve>(_ sourceLeft: UnsafeMutablePointer<Float>, _ sourceRight: UnsafeMutablePointer<Float>,
                                       into left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>,
                                       frames: Int, curve: Curve?, fixed: (Float, Float),
                                       memory: UnsafeMutablePointer<Float>?, meter: Int = -1) {
        var previous: (Float, Float)?
        if let memory, memory[0].isFinite, memory[1].isFinite { previous = (memory[0], memory[1]) }
        let startGains = previous
        var last = fixed
        if let curve, mixFrom != mixTo {
            var start = 0
            while start < frames {
                let end = Swift.min(start + Self.gainSegment, frames)
                let to = curve.gains(at: tick(at: end, of: frames))
                let from = previous ?? curve.gains(at: tick(at: start, of: frames))
                add(sourceLeft + start, sourceRight + start, into: left + start, right + start, frames: end - start,
                    Ramp(left0: from.0, right0: from.1, left1: to.0, right1: to.1))
                previous = to
                start = end
            }
            last = previous ?? fixed
        } else {
            let target = curve?.gains(at: mixFrom) ?? fixed
            let from = previous ?? target
            add(sourceLeft, sourceRight, into: left, right, frames: frames,
                Ramp(left0: from.0, right0: from.1, left1: target.0, right1: target.1))
            last = target
        }
        if let memory {
            memory[0] = last.0
            memory[1] = last.1
        }
        if meter >= 0 {
            // After the fader: the source's peak at the louder of the gains the chunk ran between.
            let gainLeft = Swift.max(Swift.abs(last.0), Swift.abs(startGains?.0 ?? last.0))
            let gainRight = Swift.max(Swift.abs(last.1), Swift.abs(startGains?.1 ?? last.1))
            meters.record(meter, left: MeterBank.peak(sourceLeft, frames: frames) * gainLeft,
                          right: MeterBank.peak(sourceRight, frames: frames) * gainRight, fall: meterFall)
        }
    }

    /// The song position `offset` frames into the chunk being mixed.
    private func tick(at offset: Int, of frames: Int) -> Double {
        guard frames > 0 else { return mixFrom }
        return mixFrom + (mixTo - mixFrom) * Double(offset) / Double(frames)
    }

    /// Adds a stereo source into a stereo destination, gains moving straight from start to end
    /// over the chunk — no step, so a fader ride never clicks.
    private func add(_ sourceLeft: UnsafeMutablePointer<Float>, _ sourceRight: UnsafeMutablePointer<Float>,
                     into left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>,
                     frames: Int, _ ramp: Ramp) {
        if ramp.isFlat {
            for i in 0..<frames {
                left[i] += sourceLeft[i] * ramp.left0
                right[i] += sourceRight[i] * ramp.right0
            }
            return
        }
        let step = 1 / Float(Swift.max(frames, 1))
        for i in 0..<frames {
            let t = Float(i) * step
            left[i] += sourceLeft[i] * (ramp.left0 + (ramp.left1 - ramp.left0) * t)
            right[i] += sourceRight[i] * (ramp.right0 + (ramp.right1 - ramp.right0) * t)
        }
    }

    /// Moves each automated unit parameter towards its lane's value at `tick`, gliding over one
    /// automation step. A value the lane held since the last step is not sent again, except
    /// after a seek or a new snapshot, when every lane is sent once.
    private func applyUnitAutomation(_ snapshot: EngineSnapshot, at tick: Double, offset: Int) {
        guard !snapshot.unitAutomation.isEmpty else { return }
        let ramp = Int(Self.automationStep)
        for automation in snapshot.unitAutomation {
            guard let value = automation.value(at: tick) else { continue }
            if unitAutomationPrimed, automation.value(at: unitAutomationTick) == value { continue }
            automation.unit.schedule(address: automation.address, value: value, offset: offset, ramp: ramp)
        }
        unitAutomationTick = tick
        unitAutomationPrimed = true
    }

    /// Sets each automated synth parameter to its lane's value at `tick`.
    private func applyPatchAutomation(_ snapshot: EngineSnapshot, at tick: Double) {
        for lane in snapshot.lanes where !lane.patchLanes.isEmpty && lane.device == .synth {
            var patch = lane.patch
            for automation in lane.patchLanes {
                if let value = automation.lane.value(atPosition: tick) { automation.field.apply(value, to: &patch) }
            }
            if synths[lane.slot].patch != patch { synths[lane.slot].setPatch(patch) }
        }
    }

    /// Adds a track's processed bus into the return buses it sends to.
    private func send(_ sends: [EngineSnapshot.SendTap], from point: Int, frames: Int, left: UnsafeMutablePointer<Float>,
                      right: UnsafeMutablePointer<Float>) {
        for tap in sends where tap.bus >= 0 && tap.bus < Self.returnCapacity {
            let l = returnLeft + tap.bus * Self.maximumFrames, r = returnRight + tap.bus * Self.maximumFrames
            let tapMemory = point >= 0 && point < sendingPoints ? sendMemory + (point * Self.returnCapacity + tap.bus) * 2 : nil
            mix(left, right, into: l, r, frames: frames, curve: tap.moving, fixed: (tap.gainLeft, tap.gainRight),
                memory: tapMemory)
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
            let point = slotCapacity + Self.smoothedAudioTracks + lane.bus
            mix(l, r, into: left, right, frames: frames, curve: lane.mix, fixed: (lane.gainLeft, lane.gainRight),
                memory: memory(point: point), meter: point)
            l.update(repeating: 0, count: frames)
            r.update(repeating: 0, count: frames)
        }
    }

    /// Output frames of fade at each edge of an audio region.
    static let regionFadeFrames: Double = 64

    /// Audio regions are read straight from the snapshot at the playhead — no voices, no state —
    /// so a seek or an edit lands on the right frame at once.
    /// Stopped, a lane renders its input if it monitors one and its inserts with silence, so a
    /// reverb or delay rings out; in the block the transport stops, what was playing at
    /// `fadingFrom` fades out over a few milliseconds instead of being cut.
    private func renderAudio(_ snapshot: EngineSnapshot, frames: Int, playing: Bool = true, fadingFrom: Int64? = nil) {
        let blockEnd = playhead + Int64(frames)
        var fetched: UInt32 = 0
        for (index, lane) in snapshot.audioLanes.enumerated() {
            let point = index < Self.smoothedAudioTracks ? slotCapacity + index : -1
            // A track that renders nothing this chunk still lets its reading fall.
            if !playing, lane.monitor < 0, fadingFrom == nil, lane.inserts.isEmpty {
                meters.record(point, left: 0, right: 0, fall: meterFall)
                continue
            }
            // A track just muted still renders this chunk, to ramp down instead of clicking off.
            let fading = point >= 0 && (gainMemory[point * 2] != 0 || gainMemory[point * 2 + 1] != 0)
                && gainMemory[point * 2].isFinite
            let session = lane.slot >= 0 && lane.slot < slotCapacity
            guard lane.gainLeft != 0 || lane.gainRight != 0 || !lane.inserts.isEmpty || lane.mix != nil || fading else {
                meters.record(point, left: 0, right: 0, fall: meterFall)
                // Silent, but a launch still happens on its bar.
                if playing, session, !sessions[lane.slot].isIdle,
                   snapshot.time.sample(at: sessions[lane.slot].pendingTick) < blockEnd { fireAudio(lane) }
                continue
            }
            let (left, right) = pair(lane.output)
            audioLeft.update(repeating: 0, count: frames)
            audioRight.update(repeating: 0, count: frames)
            // Up to the sample a pending launch or stop takes effect, then on from there. What
            // played before the switch fades out over a few milliseconds while what follows
            // fades in, so a launch, stop or return never clicks.
            var from = playing ? 0 : frames
            var fadeStart = 0, fadeEnd = 0
            if !playing, let fadingFrom {
                let length = Swift.min(Int(Self.regionFadeFrames), frames)
                let state = session ? sessions[lane.slot] : SessionSlot()
                let home = playhead
                playhead = fadingFrom
                addAudio(lane, state: state, from: 0, to: length, snapshot, fadeIn: 0..<0, fadeOut: 0..<length)
                playhead = home
            }
            if playing, nudgedBy != 0 {
                // A nudge jumps the read position by a few samples: what would have played fades
                // out while the moved audio fades in, so a sustained sound does not tick.
                let length = Swift.min(Int(Self.regionFadeFrames), frames)
                let state = session ? sessions[lane.slot] : SessionSlot()
                playhead -= nudgedBy
                addAudio(lane, state: state, from: 0, to: length, snapshot, fadeIn: 0..<0, fadeOut: 0..<length)
                playhead += nudgedBy
                fadeEnd = length
            }
            while from < frames {
                var until = frames
                var due = false
                if session, !sessions[lane.slot].isIdle {
                    let at = snapshot.time.sample(at: sessions[lane.slot].pendingTick)
                    if at < blockEnd {
                        until = Swift.min(Swift.max(Int(at - playhead), from), frames)
                        due = true
                    }
                }
                let state = session ? sessions[lane.slot] : SessionSlot()
                addAudio(lane, state: state, from: from, to: until, snapshot, fadeIn: fadeStart..<fadeEnd, fadeOut: nil)
                if due {
                    fireAudio(lane)
                    let next = sessions[lane.slot]
                    if next.overrides != state.overrides || next.clip != state.clip {
                        fadeStart = until
                        fadeEnd = Swift.min(until + Int(Self.regionFadeFrames), frames)
                        addAudio(lane, state: state, from: fadeStart, to: fadeEnd, snapshot, fadeIn: 0..<0,
                                 fadeOut: fadeStart..<fadeEnd)
                    }
                }
                from = until
            }
            // The input, through the same inserts, fader and pan as what the track plays.
            if lane.monitor >= 0, lane.monitor < InputMonitor.channelLimit {
                let input = heard + lane.monitor * Self.maximumFrames
                let bit: UInt32 = 1 << UInt32(lane.monitor)
                if fetched & bit == 0 {
                    inputs.read(channel: lane.monitor, into: input, frames: frames)
                    fetched |= bit
                }
                for i in 0..<frames {
                    audioLeft[i] += input[i]
                    audioRight[i] += input[i]
                }
            }
            for effect in lane.inserts { effect.process(frames: frames, left: audioLeft, right: audioRight) }
            mix(audioLeft, audioRight, into: left, right, frames: frames, curve: lane.mix,
                fixed: (lane.gainLeft, lane.gainRight), memory: memory(point: point), meter: point)
            send(lane.sends, from: point, frames: frames, left: audioLeft, right: audioRight)
        }
    }

    /// Frames `from..<to` of one audio lane, as `state` has it, added into `audioLeft` and
    /// `audioRight` — rising over `fadeIn`, falling over `fadeOut`.
    private func addAudio(_ lane: EngineSnapshot.AudioLane, state: SessionSlot, from: Int, to: Int,
                          _ snapshot: EngineSnapshot, fadeIn: Range<Int>, fadeOut: Range<Int>?) {
        guard to > from else { return }
        segment.update(repeating: 0, count: Self.maximumFrames)
        let start = playhead + Int64(from), end = playhead + Int64(to)
        if state.overrides {
            if let clip = state.clip, let loop = lane.loops.first(where: { $0.clip == clip }) {
                renderLoop(loop, launchTick: state.launchTick, from: start, to: end, snapshot)
            }
        } else {
            for region in lane.regions {
                guard region.startSample < end else { break }
                guard region.endSample > start else { continue }
                let first = Int(Swift.max(region.startSample, start) - playhead)
                let count = Int(Swift.min(region.endSample, end) - playhead) - first
                guard count > 0 else { continue }
                region.buffer.add(into: UnsafeMutableBufferPointer(start: segment + first, count: count),
                                  elapsed: playhead + Int64(first) - region.startSample, step: region.step,
                                  offset: region.offset, length: region.length,
                                  fade: Self.regionFadeFrames * region.step)
            }
        }
        for i in from..<to {
            var gain: Float = 1
            if fadeIn.contains(i) { gain = Float(i - fadeIn.lowerBound + 1) / Float(fadeIn.count + 1) }
            if let fadeOut { gain = 1 - Float(i - fadeOut.lowerBound + 1) / Float(fadeOut.count + 1) }
            let value = segment[i] * gain
            audioLeft[i] += value
            audioRight[i] += value
        }
    }

    /// A clip from its launch into `segment`, restarting every `loopLength` ticks; each pass is
    /// cut at the loop and faded at both ends, so the seam never clicks.
    private func renderLoop(_ loop: EngineSnapshot.AudioLoop, launchTick: Tick, from start: Int64, to end: Int64,
                            _ snapshot: EngineSnapshot) {
        let length = Swift.max(loop.loopLength, 1)
        var position = start
        while position < end {
            let since = snapshot.time.tick(atSample: position) - launchTick
            let pass = since >= 0 ? since / length : -((-since + length - 1) / length)
            let passStart = snapshot.time.sample(at: launchTick + pass * length)
            var passEnd = snapshot.time.sample(at: launchTick + (pass + 1) * length)
            if passEnd <= position { passEnd = position + 1 }
            let stop = Swift.min(end, passEnd)
            let first = Int(position - playhead), count = Int(stop - position)
            let played = Swift.min(loop.length, Double(passEnd - passStart) * loop.step)
            loop.buffer.add(into: UnsafeMutableBufferPointer(start: segment + first, count: count),
                            elapsed: position - passStart, step: loop.step, offset: loop.offset, length: played,
                            fade: Self.regionFadeFrames * loop.step)
            position = stop
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
                case .plugin, .unrecognized: false
                }
                guard sounding else { continue }
                let mono = scratch + range.lowerBound
                mono.update(repeating: 0, count: range.count)
                let buffer = UnsafeMutableBufferPointer(start: mono, count: range.count)
                switch lane.device {
                case .synth: synths[lane.slot].render(into: buffer)
                case .drums: drums[lane.slot].render(into: buffer)
                case .sampler: samplers[lane.slot].render(into: buffer)
                case .plugin, .unrecognized: break
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
    /// Automation comes first at a sample, so a note there already hears the new value.
    enum Kind: Int { case beat, arrangement, session, launch, automation }

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

/// A chunk's gains at its start and end.
private struct Ramp {
    var left0, right0, left1, right1: Float
    var isFlat: Bool { left0 == left1 && right0 == right1 }
}

/// A snapshot with an identity, so it can cross threads behind one pointer.
final class SnapshotBox: Sendable {
    let snapshot: EngineSnapshot
    init(_ snapshot: EngineSnapshot) { self.snapshot = snapshot }
}

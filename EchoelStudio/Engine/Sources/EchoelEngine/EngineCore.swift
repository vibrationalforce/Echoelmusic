import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The render-thread half of the engine: plays the newest `EngineSnapshot` sample-accurately
/// into one `PolySynth` per instrument track, mixes them to stereo and adds the metronome.
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

    // Main → render.
    private let isPlayingFlag = Atomic<Bool>(false)
    private let clickFlag = Atomic<Bool>(true)
    private let seekRequest = Atomic<Int64>(-1)
    private let pending = Atomic<UnsafeMutableRawPointer?>(nil)
    // Render → main.
    private let acknowledged = Atomic<UInt64>(0)
    private let position = Atomic<Int64>(0)

    // Render thread only.
    private var current: SnapshotBox?
    private let synths: UnsafeMutablePointer<PolySynth>
    private let owners: UnsafeMutablePointer<TrackID?>
    private let cursors: UnsafeMutablePointer<Int>
    private let scratch: UnsafeMutablePointer<Float>
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
        owners = .allocate(capacity: self.slotCapacity)
        owners.initialize(repeating: nil, count: self.slotCapacity)
        cursors = .allocate(capacity: self.slotCapacity)
        cursors.initialize(repeating: 0, count: self.slotCapacity)
        scratch = .allocate(capacity: Self.maximumFrames)
        scratch.initialize(repeating: 0, count: Self.maximumFrames)
        metronome = Metronome(sampleRate: Float(rate))
    }

    deinit {
        synths.deinitialize(count: slotCapacity)
        synths.deallocate()
        owners.deinitialize(count: slotCapacity)
        owners.deallocate()
        cursors.deallocate()
        scratch.deallocate()
    }

    // MARK: - Main thread

    public func publish(_ snapshot: EngineSnapshot) {
        let box = SnapshotBox(snapshot)
        published.append(box)
        _ = pending.exchange(Unmanaged.passUnretained(box).toOpaque(), ordering: .acquiringAndReleasing)
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

    /// The playhead in samples, for a small leaf view — never for a view body that hosts menus.
    public var positionSample: Int64 { position.load(ordering: .relaxed) }

    // MARK: - Render thread

    /// Writes `frameCount` frames into `left` and `right` (overwriting them).
    public func render(frameCount: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        var done = 0
        while done < frameCount {
            let frames = Swift.min(frameCount - done, Self.maximumFrames)
            renderChunk(frames: frames, left: left + done, right: right + done)
            done += frames
        }
    }

    private func renderChunk(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        left.update(repeating: 0, count: frames)
        right.update(repeating: 0, count: frames)

        takePendingSnapshot()

        let seek = seekRequest.exchange(-1, ordering: .acquiringAndReleasing)
        if seek >= 0 {
            playhead = seek
            position.store(seek, ordering: .relaxed)
            releaseAllNotes()
            resync()
        }
        let playing = isPlayingFlag.load(ordering: .acquiring)
        if wasPlaying, !playing { releaseAllNotes() }
        if !wasPlaying, playing { resync() }
        wasPlaying = playing
        metronome.isEnabled = clickFlag.load(ordering: .relaxed)

        guard playing, let box = current else {
            renderVoices(0..<frames, left: left, right: right)
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
                switch event.kind {
                case .noteOn(let velocity): synths[lane.slot].noteOn(pitch: event.pitch, velocity: velocity)
                case .noteOff: synths[lane.slot].noteOff(pitch: event.pitch)
                }
                cursors[lane.slot] += 1
            } else {
                metronome.trigger(accent: barTicks > 0 && nextBeat % barTicks == 0)
                nextBeat += Swift.max(beatTicks, 1)
            }
        }
        renderVoices(rendered..<frames, left: left, right: right)
        playhead = blockEnd
        position.store(playhead, ordering: .relaxed)
    }

    private func takePendingSnapshot() {
        guard let pointer = pending.exchange(nil, ordering: .acquiringAndReleasing) else { return }
        // Unretained: the main thread's `published` list owns it until we acknowledge a
        // newer one, so this assignment's release of the old box never frees on this thread.
        current = Unmanaged<SnapshotBox>.fromOpaque(pointer).takeUnretainedValue()
        guard let snapshot = current?.snapshot else { return }
        acknowledged.store(snapshot.generation, ordering: .releasing)

        // A slot handed to a different track, or no track at all, starts silent.
        for slot in 0..<slotCapacity {
            var owner: TrackID?
            for lane in snapshot.lanes where lane.slot == slot {
                owner = lane.track
                break
            }
            if owners[slot] != owner {
                synths[slot].reset()
                owners[slot] = owner
            }
        }
        for lane in snapshot.lanes where synths[lane.slot].patch != lane.patch {
            synths[lane.slot].setPatch(lane.patch)
        }
        releaseAllNotes()
        resync()
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
        for slot in 0..<slotCapacity { synths[slot].allNotesOff() }
    }

    private func renderVoices(_ range: Range<Int>, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        guard !range.isEmpty else { return }
        if let snapshot = current?.snapshot {
            for lane in snapshot.lanes where synths[lane.slot].activeVoiceCount > 0 {
                let mono = scratch + range.lowerBound
                mono.update(repeating: 0, count: range.count)
                synths[lane.slot].render(into: UnsafeMutableBufferPointer(start: mono, count: range.count))
                for i in 0..<range.count {
                    left[range.lowerBound + i] += mono[i] * lane.gainLeft
                    right[range.lowerBound + i] += mono[i] * lane.gainRight
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

#if canImport(AVFoundation)
import Foundation

/// Spatial S-A3a (ADR-008 §2–§5, accepted 2026-10-04): the ring ONE stem is captured through.
/// A render block (a generated voice) or a per-track tap writes into it on the audio thread; one
/// writer thread drains it to disk. One ring per stem, one producer, one consumer.
///
/// THE RULES (each one a decision, not a default):
/// · **The cursor is the ENGINE'S SAMPLE TIME, never a chunk count.** A stem is aligned by
///   `AVAudioTime.sampleTime` (ADR-008 §1) — tap buffer sizes are not guaranteed, so counting
///   chunks drifts the first time CoreAudio hands over an odd size.
/// · **A gap is SILENCE, never a shift.** A block that arrives later than the cursor gets zeros in
///   front of it, so every stem stays as long as the master and starts at the same sample (§5).
/// · **An overlap keeps the first write.** Time already written is not rewritten; the duplicate
///   frames are counted (`overlapFrames`) instead of moving the cursor back.
/// · **A loss is COUNTED, never silent** (ADR-008 "Negativ", Apple: a tap block is no realtime
///   guarantee). When the writer falls more than one ring behind, the frames it can no longer
///   read come out as zeros in their place and land in `lostFrames` — the length and the
///   alignment survive, and the export can say how much is missing.
///
/// ⚠️ AUDIO THREAD (`write`): no allocation, no lock, no ObjC, no I/O, no GCD. The storage is
/// allocated once in `init`; the only cross-thread ordering is `RetroRingCursor`, the
/// release/acquire pair `RetroCapture` already proves (#1413b/#1429) — reused, not copied (#416).
///
/// Built: yes. Wired: NO — nothing writes a stem yet (S-A3b/c will). Device: no.
final class StemCaptureRing: @unchecked Sendable {

    /// One drained slice. `startSampleTime` is the engine sample time of `destination[0]`.
    struct Read: Equatable {
        let startSampleTime: Int64
        let frames: Int
        /// Frames in this slice that were lost to an overrun and came out as zeros.
        let silencedFrames: Int
    }

    /// Smallest ring the type will build, in frames. Below this the overrun accounting is noise.
    static let minimumCapacityFrames = 64

    /// Frames the ring holds, always a power of two.
    let capacityFrames: Int
    /// The sample time every stem of the take starts at (ADR-008 §5).
    let startSampleTime: Int64

    private let mask: Int64
    private let samples: UnsafeMutablePointer<Float>
    /// Producer-owned; published through `RetroRingCursor` only.
    private let writeCursor: UnsafeMutablePointer<Int64>
    /// Consumer-owned.
    private let readCursor: UnsafeMutablePointer<Int64>
    /// Diagnostics. Each has exactly ONE writer: gap and overlap the producer, lost the consumer.
    private let gapCounter: UnsafeMutablePointer<Int64>
    private let overlapCounter: UnsafeMutablePointer<Int64>
    private let lostCounter: UnsafeMutablePointer<Int64>

    /// `capacityFrames` is rounded UP to a power of two, never below `minimumCapacityFrames`.
    init(capacityFrames requested: Int, startSampleTime: Int64) {
        var capacity = Self.minimumCapacityFrames
        while capacity < requested, capacity < (1 << 30) { capacity <<= 1 }
        capacityFrames = capacity
        mask = Int64(capacity - 1)
        self.startSampleTime = startSampleTime
        samples = .allocate(capacity: capacity)
        samples.initialize(repeating: 0, count: capacity)
        writeCursor = .allocate(capacity: 1)
        writeCursor.initialize(to: startSampleTime)
        readCursor = .allocate(capacity: 1)
        readCursor.initialize(to: startSampleTime)
        gapCounter = .allocate(capacity: 1)
        gapCounter.initialize(to: 0)
        overlapCounter = .allocate(capacity: 1)
        overlapCounter.initialize(to: 0)
        lostCounter = .allocate(capacity: 1)
        lostCounter.initialize(to: 0)
    }

    deinit {
        samples.deallocate()
        writeCursor.deallocate()
        readCursor.deallocate()
        gapCounter.deallocate()
        overlapCounter.deallocate()
        lostCounter.deallocate()
    }

    /// Silence inserted for late blocks so far, in frames.
    var gapFrames: Int64 { gapCounter.pointee }
    /// Duplicate frames dropped because their time was already written.
    var overlapFrames: Int64 { overlapCounter.pointee }
    /// Frames the writer could no longer read and returned as zeros.
    var lostFrames: Int64 { lostCounter.pointee }
    /// The sample time the next drained frame belongs to.
    var readSampleTime: Int64 { readCursor.pointee }

    // MARK: Producer — the audio thread

    /// Writes `frameCount` mono frames whose first frame sits at engine time `sampleTime`.
    /// RT-SAFE: index arithmetic, pointer copies and one release fence.
    func write(_ source: UnsafePointer<Float>, frameCount: Int, sampleTime: Int64) {
        guard frameCount > 0 else { return }
        // ⚠️ RAW ON PURPOSE — the producer reading its OWN last publish (the RetroCapture tap
        // does the same and says why). The acquire half belongs to the reader.
        let written = writeCursor.pointee
        var time = sampleTime
        var offset = 0
        var count = frameCount

        if time < written {                                   // overlap: keep the first write
            let duplicate = Int(min(Int64(count), written - time))
            overlapCounter.pointee &+= Int64(duplicate)
            offset += duplicate
            count -= duplicate
            time += Int64(duplicate)
            guard count > 0 else { return }
        }
        if time > written {                                   // gap: silence, never a shift
            let gap = time - written
            gapCounter.pointee &+= gap
            // Only the last ring's worth can still be read; zeroing more would be wasted work.
            // ⚠️ A gap LONGER than the ring is therefore also counted in `lostFrames` by the
            // reader: the zeros it returns are right, the label overstates. Counting it exactly
            // would need a second producer-published cursor; a render that stalls for a whole
            // ring is itself the finding, and `gapFrames` names it.
            let zeroCount = Int(min(gap, Int64(capacityFrames)))
            fill(from: time - Int64(zeroCount), count: zeroCount, with: nil)
        }
        if count > capacityFrames {                           // only the newest ring survives
            let skip = count - capacityFrames
            offset += skip
            time += Int64(skip)
            count = capacityFrames
        }
        fill(from: time, count: count, with: source + offset)
        RetroRingCursor.publish(writeCursor, time + Int64(count))
    }

    /// Copies `count` frames (or zeros when `source` is nil) into the ring at sample time `from`,
    /// splitting at the wrap. No loop per frame beyond the two contiguous runs.
    private func fill(from start: Int64, count: Int, with source: UnsafePointer<Float>?) {
        guard count > 0 else { return }
        let first = Int(start & mask)
        let head = min(count, capacityFrames - first)
        if let source {
            (samples + first).update(from: source, count: head)
            if head < count { samples.update(from: source + head, count: count - head) }
        } else {
            (samples + first).update(repeating: 0, count: head)
            if head < count { samples.update(repeating: 0, count: count - head) }
        }
    }

    // MARK: Consumer — the writer thread

    /// Drains up to `maxFrames` frames into `destination`, oldest first. Frames the producer
    /// overwrote before (or while) they were read come out as zeros and are counted in
    /// `lostFrames`, so the slice is always exactly as long as the time it covers.
    func read(into destination: UnsafeMutablePointer<Float>, maxFrames: Int) -> Read {
        let start = readCursor.pointee
        guard maxFrames > 0 else { return Read(startSampleTime: start, frames: 0, silencedFrames: 0) }
        let written = RetroRingCursor.load(writeCursor)
        let available = written - start
        guard available > 0 else { return Read(startSampleTime: start, frames: 0, silencedFrames: 0) }
        let count = Int(min(available, Int64(maxFrames)))
        for index in 0..<count {
            destination[index] = samples[Int((start + Int64(index)) & mask)]
        }
        // The slot loads above must complete BEFORE the second cursor load; `load` fences only
        // after its own load, so the barrier between them is written out here.
        OSMemoryBarrier()
        let after = RetroRingCursor.load(writeCursor)
        // Every frame older than one ring behind the NEWEST cursor may hold newer audio.
        let oldestIntact = after - Int64(capacityFrames)
        let silenced = Int(max(0, min(Int64(count), oldestIntact - start)))
        if silenced > 0 {
            destination.update(repeating: 0, count: silenced)
            lostCounter.pointee &+= Int64(silenced)
        }
        readCursor.pointee = start + Int64(count)
        return Read(startSampleTime: start, frames: count, silencedFrames: silenced)
    }
}
#endif

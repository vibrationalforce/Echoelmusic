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
/// · **A jump of more than one ring is a DISCONTINUITY, and it is loud** (ADR-008: an
///   interruption or a route change aborts, never silently). Engine time that runs backwards
///   (a restart) or leaps forward (a stall, a bogus timestamp) is neither an overlap to trim nor
///   a gap to fill: the block is refused, nothing moves, and `discontinuities` counts it. The
///   exporter must abort a take whose ring reports one — a stem that silently lost or gained
///   seconds is worse than no stem.
///
/// ⭐ THE CLAIM CURSOR — why there are two producer cursors (audio-thread review, 2026-10-04).
/// The producer overwrites the slots of frames one ring older BEFORE it publishes `writeCursor`.
/// A reader exactly one ring behind could copy those half-overwritten slots, re-load an unchanged
/// `writeCursor`, and accept them as intact audio — the overrun check would be blind to the write
/// in progress. So the producer first publishes `claimCursor` (the end of what it is ABOUT to
/// write) behind a barrier, then fills, then publishes `writeCursor`. The reader validates its
/// copy against `claimCursor`: any slot it read that the producer touched is then older than
/// `claim - capacity` and gets silenced and counted. Seqlock reasoning: producer claim-store,
/// fence, slot-stores; reader slot-loads, fence, claim-load.
///
/// ⚠️ AUDIO THREAD (`write`): no allocation, no lock, no ObjC, no I/O, no GCD, and no trapping
/// arithmetic — every subtraction against a caller-supplied sample time goes through
/// `…ReportingOverflow`. The storage is allocated once in `init`. Ordering is `RetroRingCursor`
/// (#1413b/#1429), reused, not copied (#416), plus the two barriers written out at the claim.
///
/// ⚠️ OWNERSHIP: the owner (the capture session, S-A3b) keeps the ring alive until BOTH the
/// producer and the consumer are done with it. A render block must never hold the last
/// reference — `deinit` frees memory, and that must not run on the audio thread or under a read.
/// The CALLER must also pass only a valid sample time (`AVAudioTime.isSampleTimeValid`, and never
/// `Int64(Double)` of a non-finite value — that conversion traps before this type is reached).
///
/// ⚠️ `lostFrames` IS AN UPPER BOUND, NOT AN EXACT COUNT. A gap longer than the ring minus the
/// block is zero-filled only where it stays inside the ring; the rest the reader silences, and
/// counts as lost even if it was silence. A render block's timeline is continuous, so a gap that
/// long is itself a discontinuity in all but name — the exporter aborts on `discontinuities`,
/// and reports `lostFrames` as "at most".
///
/// ⚠️ ONE PRODUCER PER RING. A ring armed on two tap points has two writers on an SPSC structure.
///
/// ⚠️ DIAGNOSTICS ARE PLAIN 64-BIT CELLS with one writer each (gap, overlap, discontinuity: the
/// producer; lost: the consumer). An aligned 64-bit load does not tear on arm64, so the worst a
/// cross-thread reader sees is a stale number; formally it is a race a sanitizer would name.
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
    /// Largest ring, in frames (16 MiB of Float, ~87 s at 48 kHz). ADR-008 sizes ~2 s per stem;
    /// a request above this is clamped rather than allocating gigabytes.
    static let maximumCapacityFrames = 1 << 22

    /// Frames the ring holds, always a power of two.
    let capacityFrames: Int
    /// The sample time every stem of the take starts at (ADR-008 §5).
    let startSampleTime: Int64

    private let mask: Int64
    private let samples: UnsafeMutablePointer<Float>
    /// Producer-owned: the end of the frames the producer is ABOUT to write (see the claim note).
    private let claimCursor: UnsafeMutablePointer<Int64>
    /// Producer-owned; published through `RetroRingCursor` only.
    private let writeCursor: UnsafeMutablePointer<Int64>
    /// Consumer-owned.
    private let readCursor: UnsafeMutablePointer<Int64>
    private let gapCounter: UnsafeMutablePointer<Int64>
    private let overlapCounter: UnsafeMutablePointer<Int64>
    private let discontinuityCounter: UnsafeMutablePointer<Int64>
    private let lostCounter: UnsafeMutablePointer<Int64>

    /// `capacityFrames` is rounded UP to a power of two, clamped to
    /// `minimumCapacityFrames … maximumCapacityFrames`.
    init(capacityFrames requested: Int, startSampleTime: Int64) {
        var capacity = Self.minimumCapacityFrames
        while capacity < requested, capacity < Self.maximumCapacityFrames { capacity <<= 1 }
        capacityFrames = capacity
        mask = Int64(capacity - 1)
        self.startSampleTime = startSampleTime
        samples = .allocate(capacity: capacity)
        samples.initialize(repeating: 0, count: capacity)   // touch every page now, not on the audio thread
        claimCursor = .allocate(capacity: 1)
        claimCursor.initialize(to: startSampleTime)
        writeCursor = .allocate(capacity: 1)
        writeCursor.initialize(to: startSampleTime)
        readCursor = .allocate(capacity: 1)
        readCursor.initialize(to: startSampleTime)
        gapCounter = .allocate(capacity: 1)
        gapCounter.initialize(to: 0)
        overlapCounter = .allocate(capacity: 1)
        overlapCounter.initialize(to: 0)
        discontinuityCounter = .allocate(capacity: 1)
        discontinuityCounter.initialize(to: 0)
        lostCounter = .allocate(capacity: 1)
        lostCounter.initialize(to: 0)
    }

    deinit {
        samples.deallocate()
        claimCursor.deallocate()
        writeCursor.deallocate()
        readCursor.deallocate()
        gapCounter.deallocate()
        overlapCounter.deallocate()
        discontinuityCounter.deallocate()
        lostCounter.deallocate()
    }

    /// Silence inserted for late blocks so far, in frames.
    var gapFrames: Int64 { gapCounter.pointee }
    /// Duplicate frames dropped because their time was already written.
    var overlapFrames: Int64 { overlapCounter.pointee }
    /// Blocks refused because engine time jumped by more than one ring. Non-zero = abort the take.
    var discontinuities: Int64 { discontinuityCounter.pointee }
    /// Frames the writer could no longer read and returned as zeros.
    var lostFrames: Int64 { lostCounter.pointee }
    /// The sample time the next drained frame belongs to.
    var readSampleTime: Int64 { readCursor.pointee }

    // MARK: Producer — the audio thread

    /// Writes `frameCount` mono frames whose first frame sits at engine time `sampleTime`.
    /// RT-SAFE: index arithmetic, pointer copies, two fences, no trapping arithmetic.
    func write(_ source: UnsafePointer<Float>, frameCount: Int, sampleTime: Int64) {
        guard frameCount > 0 else { return }
        // ⚠️ RAW ON PURPOSE — the producer reading its OWN last publish (the RetroCapture tap
        // does the same and says why). The acquire half belongs to the reader.
        let written = writeCursor.pointee
        let ring = Int64(capacityFrames)
        let (lead, leadOverflow) = sampleTime.subtractingReportingOverflow(written)
        // A jump of more than one ring either way is a discontinuity, never a gap or an overlap.
        guard !leadOverflow, lead <= ring, lead >= -ring else {
            discontinuityCounter.pointee &+= 1
            return
        }
        var time = sampleTime
        var offset = 0
        var count = frameCount

        if lead < 0 {                                         // overlap: keep the first write
            let duplicate = Int(min(Int64(count), -lead))
            overlapCounter.pointee &+= Int64(duplicate)
            offset += duplicate
            count -= duplicate
            time &+= Int64(duplicate)
            guard count > 0 else { return }
        }
        let gap = time &- written                             // ≥ 0 here, ≤ ring
        if count > capacityFrames {                           // only the newest ring survives
            let skip = count - capacityFrames
            offset += skip
            time &+= Int64(skip)
            count = capacityFrames
        }
        let (end, endOverflow) = time.addingReportingOverflow(Int64(count))
        guard !endOverflow else {
            discontinuityCounter.pointee &+= 1
            return
        }
        // CLAIM before touching a slot: a reader validating against the claim sees this write
        // even while it is in progress (see the claim note in the type's doc).
        claimCursor.pointee = end
        OSMemoryBarrier()
        if gap > 0 {                                          // silence in place, never a shift
            gapCounter.pointee &+= gap
            // Only the slots that will still be inside the ring after this write need zeros.
            let zeroCount = Int(min(gap, Int64(capacityFrames - count)))
            fill(from: time &- Int64(zeroCount), count: zeroCount, with: nil)
        }
        fill(from: time, count: count, with: source + offset)
        RetroRingCursor.publish(writeCursor, end)
    }

    /// Copies `count` frames (or zeros when `source` is nil) into the ring at sample time `from`,
    /// splitting at the wrap.
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
    /// overwrote before or while they were read come out as zeros and are counted in
    /// `lostFrames`, so the slice is always exactly as long as the time it covers.
    ///
    /// ⛔ THE FIRST TWO-RUN VERSION OF THIS COPY READ PAST THE BUFFER (audio-thread review
    /// 2026-10-04, second pass). `count` is NOT bounded by the ring — a reader more than a ring
    /// behind drains more frames than the ring holds — so a copy of `count` frames from `samples`
    /// ran off the allocation. Frames older than `written - capacity` are gone before the copy
    /// starts; they are zero-filled WITHOUT touching `samples`, and only the at-most-one-ring
    /// tail is copied. The claim check below still decides what of that tail is intact.
    func read(into destination: UnsafeMutablePointer<Float>, maxFrames: Int) -> Read {
        let start = readCursor.pointee
        guard maxFrames > 0 else { return Read(startSampleTime: start, frames: 0, silencedFrames: 0) }
        let written = RetroRingCursor.load(writeCursor)
        let available = written &- start
        guard available > 0 else { return Read(startSampleTime: start, frames: 0, silencedFrames: 0) }
        let ring = Int64(capacityFrames)
        let count = Int(min(available, Int64(maxFrames)))
        // Already overwritten before we start: never read from `samples` for these.
        let gone = Int(min(Int64(count), max(0, (written &- ring) &- start)))
        if gone > 0 { destination.update(repeating: 0, count: gone) }
        let copyCount = count - gone                       // ≤ capacityFrames by construction
        if copyCount > 0 {
            let first = Int((start &+ Int64(gone)) & mask)
            let head = min(copyCount, capacityFrames - first)
            (destination + gone).update(from: samples + first, count: head)
            if head < copyCount { (destination + gone + head).update(from: samples, count: copyCount - head) }
        }
        // The slot loads above must complete BEFORE the claim load (arm64 reorders load-load).
        OSMemoryBarrier()
        let claimed = claimCursor.pointee
        // Every frame older than one ring behind the newest CLAIM may hold newer audio, including
        // a write that has not published yet. `claimed ≥ written`, so this covers `gone` too.
        let oldestIntact = claimed &- ring
        let silenced = Int(max(0, min(Int64(count), oldestIntact &- start)))
        if silenced > 0 {
            destination.update(repeating: 0, count: silenced)
            lostCounter.pointee &+= Int64(silenced)
        }
        readCursor.pointee = start &+ Int64(count)
        return Read(startSampleTime: start, frames: count, silencedFrames: silenced)
    }
}
#endif

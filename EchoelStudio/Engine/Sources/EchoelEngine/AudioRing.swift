import EchoelCore
import Synchronization

/// A single-producer, single-consumer ring of samples between the render thread and a writer.
/// The producer never waits and never allocates: what does not fit is dropped and counted, so a
/// stalled writer costs a gap in the take, never a glitch in the output.
///
/// Exactly one thread writes and exactly one thread reads; the storage is allocated in `init`.
public final class AudioRing: @unchecked Sendable {
    public let capacity: Int
    private let storage: UnsafeMutablePointer<Float>
    /// Totals since creation; the difference is what is waiting.
    private let written = Atomic<Int>(0)
    private let consumed = Atomic<Int>(0)
    private let droppedTotal = Atomic<Int>(0)

    public init(capacity: Int) {
        self.capacity = Swift.max(1, capacity)
        storage = .allocate(capacity: self.capacity)
        storage.initialize(repeating: 0, count: self.capacity)
    }

    deinit {
        storage.deallocate()
    }

    /// Samples waiting to be read.
    public var available: Int {
        written.load(ordering: .acquiring) - consumed.load(ordering: .acquiring)
    }

    /// Samples the producer could not fit, since creation.
    public var dropped: Int { droppedTotal.load(ordering: .relaxed) }

    /// Producer side. Copies as many of `count` samples as fit and returns how many that was.
    @discardableResult
    public func write(_ source: UnsafePointer<Float>, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let w = written.load(ordering: .relaxed)
        let r = consumed.load(ordering: .acquiring)
        let n = Swift.min(count, capacity - (w - r))
        if n > 0 {
            let at = w % capacity
            let first = Swift.min(n, capacity - at)
            (storage + at).update(from: source, count: first)
            if first < n { storage.update(from: source + first, count: n - first) }
            written.store(w + n, ordering: .releasing)
        }
        if n < count { droppedTotal.add(count - n, ordering: .relaxed) }
        return n
    }

    /// Consumer side. Throws away everything waiting — the rest of an earlier take.
    public func discardAvailable() {
        consumed.store(written.load(ordering: .acquiring), ordering: .releasing)
    }

    /// Consumer side. Copies up to `count` waiting samples into `destination` and returns how
    /// many that was.
    @discardableResult
    public func read(into destination: UnsafeMutablePointer<Float>, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let r = consumed.load(ordering: .relaxed)
        let w = written.load(ordering: .acquiring)
        let n = Swift.min(count, w - r)
        guard n > 0 else { return 0 }
        let at = r % capacity
        let first = Swift.min(n, capacity - at)
        destination.update(from: storage + at, count: first)
        if first < n { (destination + first).update(from: storage, count: n - first) }
        consumed.store(r + n, ordering: .releasing)
        return n
    }
}

/// Where a recorded take belongs on the timeline.
public enum RecordingPlacement {
    /// The take's first frame was captured while the playhead stood at output sample
    /// `startSample`, and the input reaches the app `latency` samples after the sound it answers
    /// left the speaker (output plus input latency). Its true start is therefore
    /// `startSample - latency`. The region starts at the first tick at or after that, and skips
    /// `offset` frames of the take so its audio lines up with the beat it was played to.
    public static func place(startSample: Int64, latency: Int64, time: TimeConversion) -> (start: Tick, offset: Int) {
        let truth = startSample - Swift.max(0, latency)
        guard truth > 0 else { return (0, Int(-truth)) }
        var tick = time.tick(atSample: truth)
        if time.sample(at: tick) < truth { tick += 1 }
        return (tick, Int(time.sample(at: tick) - truth))
    }
}

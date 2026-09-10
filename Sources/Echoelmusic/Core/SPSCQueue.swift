// SPSCQueue.swift
// Echoelmusic - Lock-Free Single Producer Single Consumer Queue
//
// High-performance lock-free queue for real-time video frame transfer.
// Zero-copy design with automatic memory management.
//
// Supported Platforms: iOS, macOS, watchOS, tvOS, visionOS
// (⛔ "Linux" stood here — the fences are libkern `OSMemoryBarrier`, and no CI job builds
// this package on ubuntu; corrected with #1237, which also removed the last `OSAtomic*` calls.)
// Created 2026-01-16

import Foundation

// MARK: - Lock-Free SPSC Queue

/// Single Producer Single Consumer Lock-Free Queue
///
/// Designed for real-time video pipeline:
/// - Producer: CameraManager (capture thread)
/// - Consumer: StreamEngine (render thread)
///
/// Features:
/// - Lock-free using atomic operations
/// - Cache-line aligned to prevent false sharing
/// - Zero allocation during operation
/// - Overflow drops the INCOMING element and reports `false` (see `enqueue` — this
///   said "drops oldest" until #155, which is the behaviour that broke the invariant
///   below by writing the consumer's index from the producer)
///
/// Performance: ~2ns per operation on Apple Silicon
///
/// Thread Safety:
/// - Exactly ONE producer thread may call `enqueue()`
/// - Exactly ONE consumer thread may call `dequeue()`
/// - Multiple threads may call `count` and `isEmpty`

public final class SPSCQueue<Element> {

    // MARK: - Constants

    /// Cache line size for padding (64 bytes on most architectures)
    private static var cacheLineSize: Int { 64 }

    /// Slots per padded word: every index AND every counter is allocated with this stride
    /// so that no two of them share a cache line (#1237). The three counters used to be
    /// `allocate(capacity: 1)` — 16-byte malloc quanta, so all three typically sat on ONE
    /// line that the producer (dropped/enqueue) and the consumer (dequeue) both wrote on
    /// every operation, while the header above promised "cache-line aligned to prevent
    /// false sharing". True for the indices, false for the counters, and the counters are
    /// bumped on the render thread per dequeued command.
    private static var paddedWordCapacity: Int { cacheLineSize / MemoryLayout<Int>.size }

    // MARK: - Storage

    // All six pointers are `let` (#1239): each is assigned once in `init` and never again, and a
    // `var` stored property of a class carries Swift's DYNAMIC exclusivity check — every
    // `self.head` read on the render thread could pay a `swift_beginAccess` (a TLS lookup, not a
    // lock, but a call per index read on the one lock-free spine). A `let` has no access
    // tracking; the pointee stays mutable through the pointer. Found by the #1237 review.

    /// Ring buffer storage
    private let buffer: UnsafeMutablePointer<Element?>

    /// Buffer capacity (always power of 2 for fast modulo)
    private let capacity: Int

    /// Mask for fast modulo operation (capacity - 1)
    private let mask: Int

    // MARK: - Atomic Indices (Cache-Line Padded)

    /// Head index (consumer reads, producer checks)
    /// Padded to prevent false sharing
    private let head: UnsafeMutablePointer<Int>

    /// Tail index (producer writes, consumer checks)
    /// Padded to prevent false sharing
    private let tail: UnsafeMutablePointer<Int>

    // MARK: - Metrics (Cache-Line Padded, ONE writer each)

    /// Each counter has exactly ONE writer — `_droppedCount` and `_enqueueCount` the
    /// producer, `_dequeueCount` the consumer — so a plain `pointee += 1` is the whole
    /// operation (#1237). The `OSAtomicIncrement64Barrier` that stood here was a full
    /// `dmb ish` fence per increment for a counter nobody races on; the readers
    /// (`droppedCount` & co.) are diagnostics, read as a single aligned word on any
    /// thread, exactly as `head`/`tail` are read by `count`/`isEmpty`. A reader may see a
    /// value one increment stale; it can never see a torn one. `&+=` on purpose: the old
    /// atomic wrapped at `Int.max`, a checked `+=` would trap — never on the render thread,
    /// even for a count nobody reaches.

    /// Number of dropped elements due to overflow (producer writes)
    private let _droppedCount: UnsafeMutablePointer<Int>

    /// Total enqueue operations (producer writes)
    private let _enqueueCount: UnsafeMutablePointer<Int>

    /// Total dequeue operations (consumer writes)
    private let _dequeueCount: UnsafeMutablePointer<Int>

    // MARK: - Initialization

    /// Create a new SPSC queue with the given capacity
    ///
    /// - Parameter capacity: Maximum number of elements. Will be rounded up to power of 2.
    public init(capacity: Int = 16) {
        // Round capacity up to next power of 2
        let powerOf2Capacity = max(2, 1 << Int(ceil(log2(Double(capacity)))))
        self.capacity = powerOf2Capacity
        self.mask = powerOf2Capacity - 1

        // Allocate ring buffer
        buffer = UnsafeMutablePointer<Element?>.allocate(capacity: powerOf2Capacity)
        buffer.initialize(repeating: nil, count: powerOf2Capacity)

        // Allocate cache-line padded indices
        head = UnsafeMutablePointer<Int>.allocate(capacity: SPSCQueue.paddedWordCapacity)
        head.initialize(to: 0)

        tail = UnsafeMutablePointer<Int>.allocate(capacity: SPSCQueue.paddedWordCapacity)
        tail.initialize(to: 0)

        // Allocate metrics — same stride as the indices, one line each (#1237)
        _droppedCount = UnsafeMutablePointer<Int>.allocate(capacity: SPSCQueue.paddedWordCapacity)
        _droppedCount.initialize(to: 0)

        _enqueueCount = UnsafeMutablePointer<Int>.allocate(capacity: SPSCQueue.paddedWordCapacity)
        _enqueueCount.initialize(to: 0)

        _dequeueCount = UnsafeMutablePointer<Int>.allocate(capacity: SPSCQueue.paddedWordCapacity)
        _dequeueCount.initialize(to: 0)
    }

    deinit {
        // Clean up remaining elements
        while dequeue() != nil {}

        buffer.deinitialize(count: capacity)
        buffer.deallocate()

        head.deinitialize(count: 1)
        head.deallocate()

        tail.deinitialize(count: 1)
        tail.deallocate()

        _droppedCount.deinitialize(count: 1)
        _droppedCount.deallocate()

        _enqueueCount.deinitialize(count: 1)
        _enqueueCount.deallocate()

        _dequeueCount.deinitialize(count: 1)
        _dequeueCount.deallocate()
    }

    // MARK: - Producer API (Single Thread Only)

    /// Enqueue an element (producer thread only)
    ///
    /// If the queue is full the INCOMING element is dropped and `false` is returned;
    /// everything already queued is left untouched.
    ///
    /// ⛔ THIS USED TO DROP THE OLDEST, AND THAT WAS UNSOUND (#155). Evicting the
    /// oldest means advancing `head` — the CONSUMER's index — from the producer, which
    /// contradicts this type's own stated invariant three doc-comments above.
    ///
    /// THE FAILURE IS A LOST UPDATE, AND ITS SIGNATURE IS "THE QUEUE CLAIMS TO BE
    /// EMPTY WHILE HOLDING LIVE ELEMENTS". `dequeue()` publishes `head` with a PLAIN
    /// store computed from a value it read earlier; two producer drops can land inside
    /// that window (capacity 4, head=0, tail=3, elements at 0,1,2):
    ///
    ///     consumer: reads head=0, takes buffer[0]        ← its store of head=1 not issued yet
    ///     producer: full → CAS head 0→1 ✓, buffer[3]=A, tail=0
    ///     producer: full → CAS head 1→2 ✓, buffer[0]=B, tail=1
    ///     consumer: plain store lands → head = 1         ← CLOBBERS the CAS's 2
    ///     result:   head=1, tail=1 → isEmpty == true, count == 0, FOUR live elements
    ///
    /// `dequeue()` then returns nil until the producer writes again — a drain loop reads
    /// that as "nothing pending" while the data sits in the ring.
    ///
    /// ⛔ A FIRST VERSION OF THIS COMMENT CLAIMED A SECOND, SINGLE-THREADED FAILURE:
    /// that a LOST CAS left `tail` behind `head` and mis-indexed the ring permanently.
    /// Review refuted it and the refutation matters, because that claim would have sent
    /// the next session hunting a corruption that cannot happen. When the CAS loses, the
    /// producer still writes `tail = its own index + 1`, and the consumer can never
    /// reclaim that index (it stops at `head == tail`), so the state is CONSISTENT —
    /// `count == capacity-1` is simply what a full ring reads. The old author's deleted
    /// comment said exactly this. The race needs a concurrent consumer; there is no
    /// single-threaded corruption.
    ///
    /// THE RACE IS LATENT, NOT OBSERVED. All three `enqueue()` queues are single-
    /// threaded end to end today: `bioFrames` has no consumer at all, and both
    /// `controllerEvents` and `bioEvents` have `@MainActor` producers AND consumers.
    /// It is worth closing anyway because `EngineBus` declares these queues as having
    /// "audio-thread consumers" by design — the mine goes off the day someone honours
    /// that declaration. Do not cite this fix as the cause of any shipped symptom.
    ///
    /// SCOPE, since I got this wrong once: the voice queues (`PolySynthVoice`,
    /// `SubBassVoice`, `SamplerVoice`, `BioReactiveSynthVoice`) all use `tryEnqueue`,
    /// which never touched `head` and is untouched here. The ONLY production callers of
    /// `enqueue` are the three publishes in `EngineBus`.
    ///
    /// THE COST, STATED PLAINLY: for a final-state stream, drop-oldest was the SAFER
    /// policy and this trade gives that up. `controllerEvents` feeds a monophonic latch
    /// (`BioReactiveSynthVoice.apply(controller:)`) — a rejected `.noteOff` strands its
    /// `.noteOn` and the note drones until the next MIDI event clears it. That needs 128
    /// events queued with the consumer stopped, and it self-clears on the next drain, so
    /// it is accepted rather than dismissed. For bio scalars the staleness is bounded by
    /// republication at ~10 Hz. If a future queue genuinely needs "newest wins", the
    /// right structure is a single atomic mailbox, NOT a ring whose producer reaches
    /// into the consumer's index.
    ///
    /// - Parameter element: Element to enqueue
    /// - Returns: `true` if stored, `false` if the queue was full and the element was dropped
    @discardableResult
    @inline(__always)
    public func enqueue(_ element: Element) -> Bool {
        // Plain loads, the `tryEnqueue` form (#1237). `OSAtomicAdd64Barrier(0, …)` stood
        // here for both: an atomic read-modify-write of `head` — a STORE to the consumer's
        // padded line on every enqueue, the false sharing the padding exists to prevent —
        // plus a full fence on the producer's own `tail`. Neither buys ordering the ring
        // needs: the slot store below is control-dependent on the `head` load (a store is
        // never made visible ahead of the branch that guards it), and the consumer's own
        // barrier before its `head` publish guarantees its slot load has completed before
        // this producer can observe the freed index. `tryEnqueue` has shipped on exactly
        // this pairing since the ring was written; the two paths now differ only in the
        // dropped-count bookkeeping.
        let currentTail = tail.pointee
        let currentHead = head.pointee

        let nextTail = (currentTail + 1) & mask

        // Full: the only slot we could take belongs to the consumer. Refuse, count it,
        // and touch NOTHING — no head write, and no tail publish either (publishing a
        // tail we did not fill is what corrupted the ring above).
        if nextTail == currentHead {
            _droppedCount.pointee &+= 1
            return false
        }

        // Store element
        buffer[currentTail] = element

        // Publish tail (memory barrier ensures element is visible)
        OSMemoryBarrier()
        tail.pointee = nextTail

        _enqueueCount.pointee &+= 1

        return true
    }

    /// Try to enqueue without dropping
    ///
    /// - Parameter element: Element to enqueue
    /// - Returns: `true` if successful, `false` if queue is full
    @inline(__always)
    public func tryEnqueue(_ element: Element) -> Bool {
        let currentTail = tail.pointee
        let currentHead = head.pointee

        let nextTail = (currentTail + 1) & mask

        // Check if full
        if nextTail == currentHead {
            return false
        }

        // Store element
        buffer[currentTail] = element

        // Publish tail
        OSMemoryBarrier()
        tail.pointee = nextTail

        _enqueueCount.pointee &+= 1

        return true
    }

    // MARK: - Consumer API (Single Thread Only)

    /// Dequeue an element (consumer thread only)
    ///
    /// - Returns: The oldest element, or `nil` if queue is empty
    @inline(__always)
    public func dequeue() -> Element? {
        let currentHead = head.pointee
        let currentTail = tail.pointee

        // Check if empty
        if currentHead == currentTail {
            return nil
        }

        // Acquire barrier: pair with the producer's release barrier before the
        // tail publish. Without it, on arm64 (non-TSO) the slot load below may be
        // satisfied BEFORE the tail load above — for pointer-carrying payloads
        // (SamplerVoice slabs) a stale slot after ring wrap would resurrect an
        // already-freed pointer on the consumer thread.
        OSMemoryBarrier()

        // Load element
        let element = buffer[currentHead]
        buffer[currentHead] = nil

        // Publish head
        OSMemoryBarrier()
        head.pointee = (currentHead + 1) & mask

        _dequeueCount.pointee &+= 1

        return element
    }

    /// Peek at the next element without removing it
    ///
    /// - Returns: The oldest element, or `nil` if queue is empty
    @inline(__always)
    public func peek() -> Element? {
        let currentHead = head.pointee
        let currentTail = tail.pointee

        if currentHead == currentTail {
            return nil
        }

        // Acquire barrier — same pairing as dequeue() (see comment there).
        OSMemoryBarrier()

        return buffer[currentHead]
    }

    // MARK: - Status (Thread Safe)

    /// Number of elements currently in queue
    public var count: Int {
        let h = head.pointee
        let t = tail.pointee
        return (t - h + capacity) & mask
    }

    /// Whether queue is empty
    public var isEmpty: Bool {
        head.pointee == tail.pointee
    }

    /// Whether queue is full
    public var isFull: Bool {
        ((tail.pointee + 1) & mask) == head.pointee
    }

    /// Number of dropped elements due to overflow
    public var droppedCount: Int {
        _droppedCount.pointee
    }

    /// Total enqueue operations
    public var enqueueCount: Int {
        _enqueueCount.pointee
    }

    /// Total dequeue operations
    public var dequeueCount: Int {
        _dequeueCount.pointee
    }

    /// Reset metrics
    public func resetMetrics() {
        _droppedCount.pointee = 0
        _enqueueCount.pointee = 0
        _dequeueCount.pointee = 0
    }
}

// MARK: - Video Frame Queue

/// Specialized SPSC queue for video frames
///
/// Holds Metal textures with timestamps for zero-copy frame transfer.

public final class VideoFrameQueue {

    /// Video frame with texture and timing
    public struct Frame {
        /// Metal texture (or platform-specific texture handle)
        public let textureHandle: UInt64

        /// Presentation timestamp
        public let presentationTime: Double

        /// Frame number (monotonic)
        public let frameNumber: UInt64

        /// Width in pixels
        public let width: Int

        /// Height in pixels
        public let height: Int

        public init(textureHandle: UInt64, presentationTime: Double, frameNumber: UInt64, width: Int, height: Int) {
            self.textureHandle = textureHandle
            self.presentationTime = presentationTime
            self.frameNumber = frameNumber
            self.width = width
            self.height = height
        }
    }

    /// Underlying SPSC queue
    private let queue: SPSCQueue<Frame>

    /// Frame counter
    private var nextFrameNumber: UInt64 = 0

    /// Initialize with capacity
    public init(capacity: Int = 8) {
        queue = SPSCQueue<Frame>(capacity: capacity)
    }

    /// Enqueue a frame (producer thread)
    @discardableResult
    public func enqueue(textureHandle: UInt64, presentationTime: Double, width: Int, height: Int) -> Bool {
        let frame = Frame(
            textureHandle: textureHandle,
            presentationTime: presentationTime,
            frameNumber: nextFrameNumber,
            width: width,
            height: height
        )
        nextFrameNumber += 1
        return queue.enqueue(frame)
    }

    /// Dequeue a frame (consumer thread)
    public func dequeue() -> Frame? {
        queue.dequeue()
    }

    /// Peek at next frame
    public func peek() -> Frame? {
        queue.peek()
    }

    /// Number of frames in queue
    public var count: Int { queue.count }

    /// Whether queue is empty
    public var isEmpty: Bool { queue.isEmpty }

    /// Number of dropped frames
    public var droppedFrames: Int { queue.droppedCount }
}

// MARK: - Bio Data Queue

/// Specialized SPSC queue for biometric data
///
/// Designed for streaming bio data from HealthKit to audio/visual engines.

public final class BioDataQueue {

    /// Biometric data sample
    public struct Sample {
        /// Timestamp
        public let timestamp: Double

        /// Heart rate (BPM)
        public let heartRate: Float

        /// HRV coherence (HeartMath scale 0-100)
        public let hrvCoherence: Float

        /// Breathing phase (0-1)
        public let breathPhase: Float

        /// Normalized coherence (0-1) - pre-calculated for performance
        public var normalizedCoherence: Float {
            min(max(hrvCoherence / 100.0, 0.0), 1.0)
        }

        public init(timestamp: Double, heartRate: Float, hrvCoherence: Float, breathPhase: Float) {
            self.timestamp = timestamp
            self.heartRate = heartRate
            self.hrvCoherence = hrvCoherence
            self.breathPhase = breathPhase
        }
    }

    /// Underlying queue
    private let queue: SPSCQueue<Sample>

    /// Initialize with capacity
    public init(capacity: Int = 32) {
        queue = SPSCQueue<Sample>(capacity: capacity)
    }

    /// Enqueue a sample (producer thread)
    @discardableResult
    public func enqueue(heartRate: Float, hrvCoherence: Float, breathPhase: Float) -> Bool {
        let sample = Sample(
            timestamp: CFAbsoluteTimeGetCurrent(),
            heartRate: heartRate,
            hrvCoherence: hrvCoherence,
            breathPhase: breathPhase
        )
        return queue.enqueue(sample)
    }

    /// Dequeue a sample (consumer thread)
    public func dequeue() -> Sample? {
        queue.dequeue()
    }

    /// Number of samples in queue
    public var count: Int { queue.count }

    /// Whether queue is empty
    public var isEmpty: Bool { queue.isEmpty }
}

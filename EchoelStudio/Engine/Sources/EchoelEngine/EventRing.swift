import Synchronization

/// A single-producer, single-consumer ring of small events — MIDI from a controller to the
/// render thread. The producer never waits and never allocates; an event that does not fit is
/// dropped (a controller sends far fewer than the ring holds per block).
public final class EventRing: @unchecked Sendable {
    public let capacity: Int
    private let storage: UnsafeMutablePointer<UInt32>
    private let written = Atomic<Int>(0)
    private let consumed = Atomic<Int>(0)

    public init(capacity: Int = 1_024) {
        self.capacity = Swift.max(1, capacity)
        storage = .allocate(capacity: self.capacity)
        storage.initialize(repeating: 0, count: self.capacity)
    }

    deinit {
        storage.deallocate()
    }

    /// Producer side. False when the ring is full.
    @discardableResult
    public func push(_ event: UInt32) -> Bool {
        let w = written.load(ordering: .relaxed)
        guard w - consumed.load(ordering: .acquiring) < capacity else { return false }
        storage[w % capacity] = event
        written.store(w + 1, ordering: .releasing)
        return true
    }

    /// Consumer side. The oldest waiting event, or nil.
    public func pop() -> UInt32? {
        let r = consumed.load(ordering: .relaxed)
        guard r < written.load(ordering: .acquiring) else { return nil }
        let event = storage[r % capacity]
        consumed.store(r + 1, ordering: .releasing)
        return event
    }
}

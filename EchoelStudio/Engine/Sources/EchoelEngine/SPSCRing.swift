import Synchronization

/// A message the engine timed for a MIDI output: clock, start, continue, stop and song position
/// pointer (`clockOut`), or a channel message of the slot `noteOut` carries.
public struct TimedMIDIMessage: Sendable, Equatable {
    /// Host time of the first frame of the render call that produced it (0 when the caller
    /// gave none, as offline).
    public let hostTime: UInt64
    /// Frames after that first frame.
    public let frame: Int
    public let status: UInt8
    public let data1: UInt8
    public let data2: UInt8

    /// Bytes on the wire: song position carries two data bytes, real-time none; a channel message
    /// two, program change and channel pressure one.
    public var bytes: [UInt8] {
        switch status {
        case 0xF2: [status, data1, data2]
        case 0xF0...0xFF: [status]
        case 0xC0...0xDF: [status, data1]
        default: [status, data1, data2]
        }
    }
}

/// The engine's clock to a MIDI sender.
public typealias MIDIClockRing = SPSCRing<TimedMIDIMessage>

extension SPSCRing where Element == TimedMIDIMessage {
    public convenience init(capacity: Int = 2_048) {
        self.init(capacity: capacity, filler: TimedMIDIMessage(hostTime: 0, frame: 0, status: 0, data1: 0, data2: 0))
    }
}

/// A single-producer, single-consumer ring of plain values between two threads, one of them
/// the render thread. Neither side waits or allocates; a value that does not fit is dropped.
/// `Element` must hold no references, so a copy on the render thread never retains.
public final class SPSCRing<Element: Sendable>: @unchecked Sendable {
    public let capacity: Int
    private let storage: UnsafeMutablePointer<Element>
    private let written = Atomic<Int>(0)
    private let consumed = Atomic<Int>(0)

    public init(capacity: Int, filler: Element) {
        self.capacity = Swift.max(1, capacity)
        storage = .allocate(capacity: self.capacity)
        storage.initialize(repeating: filler, count: self.capacity)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    @discardableResult
    func push(_ element: Element) -> Bool {
        let w = written.load(ordering: .relaxed)
        guard w - consumed.load(ordering: .acquiring) < capacity else { return false }
        storage[w % capacity] = element
        written.store(w + 1, ordering: .releasing)
        return true
    }

    public func pop() -> Element? {
        let r = consumed.load(ordering: .relaxed)
        guard r < written.load(ordering: .acquiring) else { return nil }
        let element = storage[r % capacity]
        consumed.store(r + 1, ordering: .releasing)
        return element
    }
}

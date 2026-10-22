import Foundation

/// The keys a musician holds on the live instrument. Each held key remembers the slot it went to
/// and the pitch it sounds, so its release ends exactly that note, whatever changed while it was
/// down: the live track, the key, the scale. Pure and fixed-size: the MIDI thread hands it a key
/// and gets back the notes to send, at most three, without allocating.
///
/// The instrument hears no MIDI channel (a built-in kernel takes the bytes without it, a hosted
/// unit gets every note on channel 1), so two keys that sound one pitch in one slot share one
/// note there. Three rules keep every slot's pitches paired, one note-on, then its note-off:
/// - A release ends the pitch latched at the press, never the key's pitch as it maps now.
/// - A key that sounds a pitch another held key already sounds strikes it again (off, then on);
///   the pitch ends with the last key that holds it.
/// - A held key struck again without a release first ends what it held, also in another slot.
/// A release of a key that was never pressed sends nothing: a note-off for a pitch it did not
/// start would cut one the arrangement or another key plays.
public struct LiveKeys: Sendable {
    /// One note to send.
    public struct Message: Equatable, Sendable {
        public let slot: Int
        public let channel: UInt8
        public let pitch: UInt8
        /// 0 ends the note.
        public let velocity: UInt8

        /// Note-on, or note-off for velocity 0.
        public var status: UInt8 { (velocity > 0 ? 0x90 : 0x80) | channel }
    }

    /// The notes one key produces, in the order to send them: none, one, or a release before a strike.
    public struct Output: RandomAccessCollection, Equatable, Sendable {
        public private(set) var count = 0
        private var first = Output.none, second = Output.none, third = Output.none
        private static let none = Message(slot: 0, channel: 0, pitch: 0, velocity: 0)

        public init() {}

        public var startIndex: Int { 0 }
        public var endIndex: Int { count }

        public subscript(position: Int) -> Message {
            switch position {
            case 0: first
            case 1: second
            default: third
            }
        }

        mutating func append(_ message: Message) {
            switch count {
            case 0: first = message
            case 1: second = message
            default: third = message
            }
            count = Swift.min(count + 1, 3)
        }
    }

    /// The pitch each key plays, by key: 128 entries. Nil plays every key as itself, and so does a
    /// table of another length.
    public var lock: [UInt8]?

    /// By channel × key: the slot a held key sounds in, -1 while it is up, and the pitch it sounds.
    private var slots = [Int16](repeating: -1, count: 16 * 128)
    private var pitches = [UInt8](repeating: 0, count: 16 * 128)

    public init(lock: [UInt8]? = nil) {
        self.lock = lock
    }

    /// No key is held any more; sends nothing. For a new engine core, which has none of the notes.
    public mutating func reset() {
        for index in slots.indices { slots[index] = -1 }
    }

    /// A key went down on `channel`, to sound in `slot`. Velocity 0 is a release.
    public mutating func press(channel: UInt8, key: UInt8, velocity: UInt8, slot: Int) -> Output {
        guard velocity & 0x7F > 0 else { return release(channel: channel, key: key) }
        let channel = channel & 0x0F, index = Self.index(channel, key)
        let slot = Int16(clamping: slot)
        var output = Output()
        if slots[index] >= 0 {
            // Struck again without a release: what it held ends first, in its own slot.
            output = release(channel: channel, key: key)
        }
        let pitch = sounding(key & 0x7F)
        if holder(slot: slot, pitch: pitch, besides: index) != nil {
            output.append(Message(slot: Int(slot), channel: channel, pitch: pitch, velocity: 0))
        }
        slots[index] = slot
        pitches[index] = pitch
        output.append(Message(slot: Int(slot), channel: channel, pitch: pitch, velocity: velocity & 0x7F))
        return output
    }

    /// A key came up on `channel`.
    public mutating func release(channel: UInt8, key: UInt8) -> Output {
        let channel = channel & 0x0F, index = Self.index(channel, key)
        let slot = slots[index]
        var output = Output()
        guard slot >= 0 else { return output }
        slots[index] = -1
        let pitch = pitches[index]
        if holder(slot: slot, pitch: pitch, besides: index) == nil {
            output.append(Message(slot: Int(slot), channel: channel, pitch: pitch, velocity: 0))
        }
        return output
    }

    /// The pitch `key` sounds now.
    private func sounding(_ key: UInt8) -> UInt8 {
        guard let lock, lock.count == 128 else { return key }
        return lock[Int(key)] & 0x7F
    }

    /// Another held key that sounds `pitch` in `slot`, on any channel.
    private func holder(slot: Int16, pitch: UInt8, besides index: Int) -> Int? {
        for other in slots.indices where other != index && slots[other] == slot && pitches[other] == pitch {
            return other
        }
        return nil
    }

    private static func index(_ channel: UInt8, _ key: UInt8) -> Int {
        Int(channel & 0x0F) * 128 + Int(key & 0x7F)
    }
}

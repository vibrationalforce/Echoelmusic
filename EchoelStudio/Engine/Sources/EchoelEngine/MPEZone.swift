import Foundation

/// MPE out (MIDI Polyphonic Expression, MMA/AMEI RP-053), the lower zone: master channel 1, member
/// channels 2 … 1 + `memberCount`. Every sounding note gets a member channel of its own, so a
/// receiving MPE synth bends, presses and slides each note apart from the others (wave W5b).
///
/// The rules this value keeps, each pinned by `MPEZoneTests` against bytes worked out by hand:
/// - **Announce first.** `configuration()` is the MPE Configuration Message (RPN 6 on the master
///   channel) and the pitch-bend sensitivity (RPN 0) of the master and every member channel, then
///   the null RPN, so a later data entry cannot change either by accident.
/// - **One note, one channel.** A note-on takes the free member channel that was released longest
///   ago, so a release tail on the channel just freed is not cut by the next note. With every
///   channel sounding, the oldest note is ended first and its channel reused (voice steal).
/// - **Expression before the note.** A member channel's pitch bend (centred), slide (CC 74) and
///   pressure are stated BEFORE its note-on, so the note never starts with what the channel's
///   previous note left there.
/// - **A pitch sounds once.** A note-on for a pitch that already sounds ends that note first; a
///   note-off ends the note on the channel it started on; one for a pitch that does not sound
///   sends nothing.
/// - **All notes off** ends every sounding note by its own note-off and then sends CC 123 on every
///   member channel, so nothing can hang on a receiver that missed a message.
///
/// The body's expression (`setPressure`, `setSlide`) is zone-wide: it reaches every sounding note,
/// on each channel only when its 7-bit value changed. An absent value (nil) or one that is not
/// finite sends nothing and keeps what was sent (G-A contract: absent adds nothing).
///
/// Off the render thread: the messages come back in an array. MPE IN is a different matter and is
/// not implied by any of this.
public struct MPEZone: Sendable, Equatable {
    /// One channel message to send, its channel in the low nibble of `status`.
    public struct Message: Equatable, Sendable {
        public let status: UInt8
        public let data1: UInt8
        public let data2: UInt8

        public init(_ status: UInt8, _ data1: UInt8, _ data2: UInt8 = 0) {
            self.status = status
            self.data1 = data1 & 0x7F
            self.data2 = data2 & 0x7F
        }

        public var channel: UInt8 { status & 0x0F }
        /// Program change and channel pressure carry one data byte, the rest two.
        public var bytes: [UInt8] { (0xC0...0xDF).contains(status) ? [status, data1] : [status, data1, data2] }
    }

    public static let masterChannel: UInt8 = 0
    /// How many member channels a lower zone can have: channels 2 … 16.
    public static let memberLimit: ClosedRange<Int> = 1...15
    /// The controller MPE calls slide (the third dimension, "timbre").
    public static let slideController: UInt8 = 74
    /// Pitch bend in its centre, 14 bits.
    public static let bendCentre = 8_192
    /// The default sensitivities of RP-053: 48 semitones on a member, 2 on the master.
    public static let defaultMemberBendRange = 48
    public static let defaultMasterBendRange = 2

    public private(set) var memberCount: Int
    public let memberBendRange: Int
    public let masterBendRange: Int

    private struct Voice: Equatable, Sendable {
        let pitch: UInt8
        let channel: UInt8
        let startedAt: UInt64
    }

    /// The sounding notes, oldest first.
    private var voices: [Voice] = []
    /// Per member (index 0 is channel 2): when it was last released, 0 for never.
    private var releasedAt: [UInt64]
    /// Per member: the pressure and slide last sent on it.
    private var sentPressure: [UInt8]
    private var sentSlide: [UInt8]
    private var counter: UInt64 = 0
    /// The body's expression now, stated at every note-on.
    private var pressure: UInt8 = 0
    private var slide: UInt8 = 64

    public init(members: Int = 15, memberBendRange: Int = MPEZone.defaultMemberBendRange,
                masterBendRange: Int = MPEZone.defaultMasterBendRange) {
        memberCount = Swift.min(Swift.max(members, Self.memberLimit.lowerBound), Self.memberLimit.upperBound)
        self.memberBendRange = Swift.min(Swift.max(memberBendRange, 1), 96)
        self.masterBendRange = Swift.min(Swift.max(masterBendRange, 1), 96)
        releasedAt = Array(repeating: 0, count: 15)
        sentPressure = Array(repeating: 0, count: 15)
        sentSlide = Array(repeating: 64, count: 15)
    }

    /// The member channels in use by this zone, 0-based (1 is MIDI channel 2).
    public var memberChannels: ClosedRange<UInt8> { 1...UInt8(memberCount) }

    /// The member channel a pitch sounds on, or nil.
    public func channel(of pitch: UInt8) -> UInt8? { voices.first { $0.pitch == pitch & 0x7F }?.channel }

    public var soundingCount: Int { voices.count }

    // MARK: - Zone

    /// The zone and the bend sensitivities, to send when the output opens and after a receiver
    /// appears.
    public func configuration() -> [Message] {
        var out = Self.rpn(channel: Self.masterChannel, number: 6, value: UInt8(memberCount), fine: nil)
        out += Self.rpn(channel: Self.masterChannel, number: 0, value: UInt8(masterBendRange), fine: 0)
        for channel in memberChannels {
            out += Self.rpn(channel: channel, number: 0, value: UInt8(memberBendRange), fine: 0)
        }
        return out
    }

    /// A different number of member channels: every note ends first, then the new zone is announced.
    public mutating func reconfigure(members: Int) -> [Message] {
        var out = allNotesOff()
        memberCount = Swift.min(Swift.max(members, Self.memberLimit.lowerBound), Self.memberLimit.upperBound)
        releasedAt = Array(repeating: 0, count: 15)
        out += configuration()
        return out
    }

    // MARK: - Notes

    public mutating func noteOn(pitch: UInt8, velocity: UInt8) -> [Message] {
        let key = pitch & 0x7F, strike = velocity & 0x7F
        guard strike > 0 else { return noteOff(pitch: key) }
        var out = noteOff(pitch: key)
        let channel: UInt8
        if let free = freeChannel() {
            channel = free
        } else if let oldest = voices.first {
            out += end(oldest)
            channel = oldest.channel
        } else {
            return out
        }
        counter += 1
        let member = Int(channel) - 1
        out.append(Message(0xE0 | channel, UInt8(Self.bendCentre & 0x7F), UInt8(Self.bendCentre >> 7)))
        out.append(Message(0xB0 | channel, Self.slideController, slide))
        out.append(Message(0xD0 | channel, pressure))
        sentSlide[member] = slide
        sentPressure[member] = pressure
        out.append(Message(0x90 | channel, key, strike))
        voices.append(Voice(pitch: key, channel: channel, startedAt: counter))
        return out
    }

    public mutating func noteOff(pitch: UInt8) -> [Message] {
        guard let voice = voices.first(where: { $0.pitch == pitch & 0x7F }) else { return [] }
        return end(voice)
    }

    /// Every sounding note ends, and every member channel hears all notes off.
    public mutating func allNotesOff() -> [Message] {
        var out: [Message] = []
        while let voice = voices.first { out += end(voice) }
        for channel in memberChannels { out.append(Message(0xB0 | channel, 123, 0)) }
        return out
    }

    // MARK: - Expression

    /// One note's pitch bend, in semitones from where it was struck, within the member range.
    public func bend(pitch: UInt8, semitones: Double) -> [Message] {
        guard semitones.isFinite, let channel = channel(of: pitch) else { return [] }
        let steps = Double(Self.bendCentre) * semitones / Double(memberBendRange)
        let value = Int(Swift.min(Swift.max((Double(Self.bendCentre) + steps).rounded(), 0), 16_383))
        return [Message(0xE0 | channel, UInt8(value & 0x7F), UInt8(value >> 7))]
    }

    /// The whole zone's pitch bend on the master channel, 14 bits (a track's bend lane).
    public func masterBend(_ value: Int) -> [Message] {
        let clamped = Swift.min(Swift.max(value, 0), 16_383)
        return [Message(0xE0 | Self.masterChannel, UInt8(clamped & 0x7F), UInt8(clamped >> 7))]
    }

    /// Pressure 0 … 1 for every sounding note; nil (absent) or not finite sends nothing.
    public mutating func setPressure(_ value: Double?) -> [Message] {
        guard let level = Self.sevenBit(value) else { return [] }
        pressure = level
        var out: [Message] = []
        for voice in voices where sentPressure[Int(voice.channel) - 1] != level {
            sentPressure[Int(voice.channel) - 1] = level
            out.append(Message(0xD0 | voice.channel, level))
        }
        return out
    }

    /// Slide (CC 74) 0 … 1 for every sounding note; nil (absent) or not finite sends nothing.
    public mutating func setSlide(_ value: Double?) -> [Message] {
        guard let level = Self.sevenBit(value) else { return [] }
        slide = level
        var out: [Message] = []
        for voice in voices where sentSlide[Int(voice.channel) - 1] != level {
            sentSlide[Int(voice.channel) - 1] = level
            out.append(Message(0xB0 | voice.channel, Self.slideController, level))
        }
        return out
    }

    // MARK: - Helpers

    private mutating func end(_ voice: Voice) -> [Message] {
        voices.removeAll { $0 == voice }
        counter += 1
        releasedAt[Int(voice.channel) - 1] = counter
        return [Message(0x80 | voice.channel, voice.pitch, 0)]
    }

    /// The free member channel released longest ago; the lowest of equals.
    private func freeChannel() -> UInt8? {
        var best: UInt8?
        for channel in memberChannels where !voices.contains(where: { $0.channel == channel }) {
            guard let current = best else {
                best = channel
                continue
            }
            if releasedAt[Int(channel) - 1] < releasedAt[Int(current) - 1] { best = channel }
        }
        return best
    }

    private static func sevenBit(_ value: Double?) -> UInt8? {
        guard let value, value.isFinite else { return nil }
        return UInt8(Swift.min(Swift.max((value * 127).rounded(), 0), 127))
    }

    /// A registered parameter, then the null RPN.
    private static func rpn(channel: UInt8, number: UInt8, value: UInt8, fine: UInt8?) -> [Message] {
        var out = [Message(0xB0 | channel, 101, 0), Message(0xB0 | channel, 100, number),
                   Message(0xB0 | channel, 6, value)]
        if let fine { out.append(Message(0xB0 | channel, 38, fine)) }
        out += [Message(0xB0 | channel, 101, 127), Message(0xB0 | channel, 100, 127)]
        return out
    }
}

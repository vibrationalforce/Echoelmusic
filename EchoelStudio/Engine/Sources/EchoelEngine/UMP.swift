/// MIDI 2.0 channel voice messages in Universal MIDI Packets (message type 4, two words), and the
/// value scaling between MIDI 1.0 and MIDI 2.0 resolutions — pure values, no CoreMIDI, so every
/// rule here is tested as behaviour (`UMPTests`).
///
/// The rules, from the M2-104-UM (UMP and MIDI 2.0 Protocol) specification:
/// - **Scaling up keeps minimum, centre and maximum** (Appendix D, "Min-Center-Max"): a value at
///   or below the source centre is shifted left; above it, the bits below the top bit are
///   repeated into the new low bits, so the source maximum becomes the destination maximum.
/// - **Scaling down is a right shift.** 16 → 7 bit velocity, 32 → 7 bit controllers, 32 → 14 bit
///   pitch bend. A MIDI 2.0 note-on whose velocity shifts to 0 becomes velocity 1: in MIDI 1.0 a
///   note-on at velocity 0 is a note-off, in MIDI 2.0 it is not.
/// - **Invalid packets are dropped**, never guessed: a message type other than 4, the undefined
///   opcode 7, and a note, controller or bank byte with its top bit set (reserved in the
///   specification) parse to nil.
///
/// Off the render thread: CoreMIDI's input queue and the MPE pump call this. MIDI-CI and Property
/// Exchange are not part of it — Echoel neither answers nor sends a MIDI-CI message.
public enum UMP {
    // MARK: - Scaling

    /// Min-Center-Max scaling from `sourceBits` to more `destinationBits` (1 … 32 each).
    public static func scaleUp(_ value: UInt32, from sourceBits: Int, to destinationBits: Int) -> UInt32 {
        guard sourceBits >= 1, destinationBits <= 32, sourceBits <= destinationBits else { return value }
        let source = UInt64(value) & ((1 << UInt64(sourceBits)) - 1)
        let scaleBits = destinationBits - sourceBits
        var shifted = source << UInt64(scaleBits)
        let centre: UInt64 = 1 << UInt64(sourceBits - 1)
        guard source > centre, sourceBits > 1 else { return UInt32(truncatingIfNeeded: shifted) }
        let repeatBits = sourceBits - 1
        var repeatValue = source & ((1 << UInt64(repeatBits)) - 1)
        if scaleBits > repeatBits {
            repeatValue <<= UInt64(scaleBits - repeatBits)
        } else {
            repeatValue >>= UInt64(repeatBits - scaleBits)
        }
        while repeatValue != 0 {
            shifted |= repeatValue
            repeatValue >>= UInt64(repeatBits)
        }
        return UInt32(truncatingIfNeeded: shifted)
    }

    /// Scaling from `sourceBits` to fewer `destinationBits`: the low bits are dropped.
    public static func scaleDown(_ value: UInt32, from sourceBits: Int, to destinationBits: Int) -> UInt32 {
        guard destinationBits >= 0, sourceBits <= 32, destinationBits <= sourceBits else { return value }
        let source = UInt64(value) & ((1 << UInt64(sourceBits)) - 1)
        return UInt32(truncatingIfNeeded: source >> UInt64(sourceBits - destinationBits))
    }

    /// The centre of a 32-bit bend, and of every bipolar 32-bit controller.
    public static let centre32: UInt32 = 0x8000_0000

    // MARK: - MIDI 1.0 channel voice

    /// One MIDI 1.0 channel voice message: the status (kind and 0-based channel) and two 7-bit
    /// data bytes; program change and channel pressure leave `data2` at 0.
    public struct Channel1: Equatable, Sendable {
        public let status: UInt8
        public let data1: UInt8
        public let data2: UInt8

        public init(_ status: UInt8, _ data1: UInt8, _ data2: UInt8 = 0) {
            self.status = status
            self.data1 = data1 & 0x7F
            self.data2 = data2 & 0x7F
        }
    }

    /// A MIDI 1.0 channel voice message as one UMP word, message type 2, in `group`.
    public static func midi1Word(_ message: Channel1, group: UInt8 = 0) -> UInt32 {
        UInt32(0x2) << 28 | UInt32(group & 0x0F) << 24 | UInt32(message.status) << 16
            | UInt32(message.data1) << 8 | UInt32(message.data2)
    }

    // MARK: - MIDI 2.0 channel voice

    /// What a MIDI 2.0 channel voice message says. Channels are 0-based (0 is MIDI channel 1).
    public enum Kind: Equatable, Sendable {
        /// A note's own controller; `registered` for the specification's list (1 modulation,
        /// 3 pitch 7.25, 7 volume, 10 pan, 74 brightness …), else assignable.
        case perNoteController(note: UInt8, registered: Bool, index: UInt8, value: UInt32)
        /// RPN (`registered`) or NRPN, absolute, 32 bits.
        case parameter(registered: Bool, bank: UInt8, index: UInt8, value: UInt32)
        /// RPN or NRPN, relative: a signed step.
        case relativeParameter(registered: Bool, bank: UInt8, index: UInt8, step: Int32)
        case perNotePitchBend(note: UInt8, value: UInt32)
        case noteOff(note: UInt8, velocity: UInt16, attributeType: UInt8, attribute: UInt16)
        case noteOn(note: UInt8, velocity: UInt16, attributeType: UInt8, attribute: UInt16)
        case polyPressure(note: UInt8, value: UInt32)
        case controlChange(index: UInt8, value: UInt32)
        /// The bank is nil when the bank-valid flag is clear.
        case programChange(program: UInt8, bank: (msb: UInt8, lsb: UInt8)?)
        case channelPressure(value: UInt32)
        case pitchBend(value: UInt32)
        /// Per-note management: `detach` the note's controllers, `reset` them to their defaults.
        case perNoteManagement(note: UInt8, detach: Bool, reset: Bool)

        public static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case let (.programChange(p1, b1), .programChange(p2, b2)):
                return p1 == p2 && b1?.msb == b2?.msb && b1?.lsb == b2?.lsb
            case let (.perNoteController(n1, r1, i1, v1), .perNoteController(n2, r2, i2, v2)):
                return n1 == n2 && r1 == r2 && i1 == i2 && v1 == v2
            case let (.parameter(r1, b1, i1, v1), .parameter(r2, b2, i2, v2)):
                return r1 == r2 && b1 == b2 && i1 == i2 && v1 == v2
            case let (.relativeParameter(r1, b1, i1, s1), .relativeParameter(r2, b2, i2, s2)):
                return r1 == r2 && b1 == b2 && i1 == i2 && s1 == s2
            case let (.perNotePitchBend(n1, v1), .perNotePitchBend(n2, v2)): return n1 == n2 && v1 == v2
            case let (.noteOff(n1, v1, t1, a1), .noteOff(n2, v2, t2, a2)),
                 let (.noteOn(n1, v1, t1, a1), .noteOn(n2, v2, t2, a2)):
                return n1 == n2 && v1 == v2 && t1 == t2 && a1 == a2
            case let (.polyPressure(n1, v1), .polyPressure(n2, v2)): return n1 == n2 && v1 == v2
            case let (.controlChange(i1, v1), .controlChange(i2, v2)): return i1 == i2 && v1 == v2
            case let (.channelPressure(v1), .channelPressure(v2)): return v1 == v2
            case let (.pitchBend(v1), .pitchBend(v2)): return v1 == v2
            case let (.perNoteManagement(n1, d1, r1), .perNoteManagement(n2, d2, r2)):
                return n1 == n2 && d1 == d2 && r1 == r2
            default: return false
            }
        }
    }

    /// One MIDI 2.0 channel voice message (UMP message type 4).
    public struct Message: Equatable, Sendable {
        public let group: UInt8
        public let channel: UInt8
        public let kind: Kind

        public init(group: UInt8 = 0, channel: UInt8, _ kind: Kind) {
            self.group = group & 0x0F
            self.channel = channel & 0x0F
            self.kind = kind
        }

        /// The two words of the packet. Seven-bit fields are masked, so a built message always
        /// parses back to itself when its fields were in range.
        public var words: (UInt32, UInt32) {
            func head(_ opcode: UInt32, _ byte3: UInt8, _ byte4: UInt8) -> UInt32 {
                UInt32(0x4) << 28 | UInt32(group) << 24 | opcode << 20 | UInt32(channel) << 16
                    | UInt32(byte3) << 8 | UInt32(byte4)
            }
            switch kind {
            case let .perNoteController(note, registered, index, value):
                return (head(registered ? 0x0 : 0x1, note & 0x7F, index), value)
            case let .parameter(registered, bank, index, value):
                return (head(registered ? 0x2 : 0x3, bank & 0x7F, index & 0x7F), value)
            case let .relativeParameter(registered, bank, index, step):
                return (head(registered ? 0x4 : 0x5, bank & 0x7F, index & 0x7F), UInt32(bitPattern: step))
            case let .perNotePitchBend(note, value):
                return (head(0x6, note & 0x7F, 0), value)
            case let .noteOff(note, velocity, type, attribute):
                return (head(0x8, note & 0x7F, type), UInt32(velocity) << 16 | UInt32(attribute))
            case let .noteOn(note, velocity, type, attribute):
                return (head(0x9, note & 0x7F, type), UInt32(velocity) << 16 | UInt32(attribute))
            case let .polyPressure(note, value):
                return (head(0xA, note & 0x7F, 0), value)
            case let .controlChange(index, value):
                return (head(0xB, index & 0x7F, 0), value)
            case let .programChange(program, bank):
                let second = UInt32(program & 0x7F) << 24 | UInt32((bank?.msb ?? 0) & 0x7F) << 8 | UInt32((bank?.lsb ?? 0) & 0x7F)
                return (head(0xC, 0, bank == nil ? 0 : 1), second)
            case let .channelPressure(value):
                return (head(0xD, 0, 0), value)
            case let .pitchBend(value):
                return (head(0xE, 0, 0), value)
            case let .perNoteManagement(note, detach, reset):
                return (head(0xF, note & 0x7F, (detach ? 2 : 0) | (reset ? 1 : 0)), 0)
            }
        }

        /// The message in two words, or nil when they are not a valid MIDI 2.0 channel voice
        /// message.
        public init?(_ first: UInt32, _ second: UInt32) {
            guard first >> 28 == 0x4 else { return nil }
            let group = UInt8((first >> 24) & 0x0F), opcode = UInt8((first >> 20) & 0x0F)
            let channel = UInt8((first >> 16) & 0x0F)
            let byte3 = UInt8((first >> 8) & 0xFF), byte4 = UInt8(first & 0xFF)
            func seven(_ byte: UInt8) -> Bool { byte & 0x80 == 0 }
            let kind: Kind
            switch opcode {
            case 0x0, 0x1:
                guard seven(byte3) else { return nil }
                kind = .perNoteController(note: byte3, registered: opcode == 0x0, index: byte4, value: second)
            case 0x2, 0x3:
                guard seven(byte3), seven(byte4) else { return nil }
                kind = .parameter(registered: opcode == 0x2, bank: byte3, index: byte4, value: second)
            case 0x4, 0x5:
                guard seven(byte3), seven(byte4) else { return nil }
                kind = .relativeParameter(registered: opcode == 0x4, bank: byte3, index: byte4,
                                          step: Int32(bitPattern: second))
            case 0x6:
                guard seven(byte3) else { return nil }
                kind = .perNotePitchBend(note: byte3, value: second)
            case 0x8, 0x9:
                guard seven(byte3) else { return nil }
                let velocity = UInt16(second >> 16), attribute = UInt16(second & 0xFFFF)
                kind = opcode == 0x8
                    ? .noteOff(note: byte3, velocity: velocity, attributeType: byte4, attribute: attribute)
                    : .noteOn(note: byte3, velocity: velocity, attributeType: byte4, attribute: attribute)
            case 0xA:
                guard seven(byte3) else { return nil }
                kind = .polyPressure(note: byte3, value: second)
            case 0xB:
                guard seven(byte3) else { return nil }
                kind = .controlChange(index: byte3, value: second)
            case 0xC:
                let program = UInt8((second >> 24) & 0xFF), msb = UInt8((second >> 8) & 0xFF), lsb = UInt8(second & 0xFF)
                guard seven(program), seven(msb), seven(lsb) else { return nil }
                kind = .programChange(program: program, bank: byte4 & 1 == 1 ? (msb, lsb) : nil)
            case 0xD:
                kind = .channelPressure(value: second)
            case 0xE:
                kind = .pitchBend(value: second)
            case 0xF:
                guard seven(byte3) else { return nil }
                kind = .perNoteManagement(note: byte3, detach: byte4 & 2 != 0, reset: byte4 & 1 != 0)
            default:
                // Opcode 7 is undefined.
                return nil
            }
            self.init(group: group, channel: channel, kind)
        }

        /// The registered per-note controller "Pitch 7.25" (absolute pitch): no MIDI 1.0 form.
        public static let pitch725Controller: UInt8 = 3

        /// What a MIDI 1.0 engine hears of this message, or nil when MIDI 1.0 has no counterpart
        /// (relative RPN/NRPN, assignable per-note controllers, registered per-note pitch 7.25) —
        /// the caller counts those, so none is lost without a trace. An empty array is a message
        /// with nothing to do (per-note management: Echoel keeps no per-note controller state).
        ///
        /// A per-note pitch bend becomes the channel's bend and a registered per-note controller
        /// the channel's controller of the same number: the engine bends and controls a channel,
        /// which is exactly the note on an MPE-style controller that plays one note per channel.
        /// Note attributes (pitch 7.9 and the rest) are not heard; `hasUnheardAttribute` says so.
        public var midi1: [Channel1]? {
            let channel = self.channel
            func bend(_ value: UInt32) -> [Channel1] {
                let fourteen = scaleDown(value, from: 32, to: 14)
                return [Channel1(0xE0 | channel, UInt8(fourteen & 0x7F), UInt8(fourteen >> 7))]
            }
            func seven(_ value: UInt32) -> UInt8 { UInt8(scaleDown(value, from: 32, to: 7)) }
            switch kind {
            case let .noteOff(note, velocity, _, _):
                return [Channel1(0x80 | channel, note, UInt8(scaleDown(UInt32(velocity), from: 16, to: 7)))]
            case let .noteOn(note, velocity, _, _):
                let strike = UInt8(scaleDown(UInt32(velocity), from: 16, to: 7))
                return [Channel1(0x90 | channel, note, Swift.max(strike, 1))]
            case let .polyPressure(note, value):
                return [Channel1(0xA0 | channel, note, seven(value))]
            case let .controlChange(index, value):
                return [Channel1(0xB0 | channel, index, seven(value))]
            case let .programChange(program, bank):
                var out: [Channel1] = []
                if let bank { out += [Channel1(0xB0 | channel, 0, bank.msb), Channel1(0xB0 | channel, 32, bank.lsb)] }
                return out + [Channel1(0xC0 | channel, program)]
            case let .channelPressure(value):
                return [Channel1(0xD0 | channel, seven(value))]
            case let .pitchBend(value):
                return bend(value)
            case let .perNotePitchBend(_, value):
                return bend(value)
            case let .parameter(registered, bank, index, value):
                let fourteen = scaleDown(value, from: 32, to: 14)
                return [Channel1(0xB0 | channel, registered ? 101 : 99, bank),
                        Channel1(0xB0 | channel, registered ? 100 : 98, index),
                        Channel1(0xB0 | channel, 6, UInt8(fourteen >> 7)),
                        Channel1(0xB0 | channel, 38, UInt8(fourteen & 0x7F))]
            case let .perNoteController(_, registered, index, value):
                guard registered, index < 128, index != Self.pitch725Controller else { return nil }
                return [Channel1(0xB0 | channel, index, seven(value))]
            case .relativeParameter:
                return nil
            case .perNoteManagement:
                return []
            }
        }

        /// A note-on or note-off whose attribute (pitch 7.9, articulation …) the engine cannot hear.
        public var hasUnheardAttribute: Bool {
            switch kind {
            case let .noteOn(_, _, type, _), let .noteOff(_, _, type, _): return type != 0
            default: return false
            }
        }

        /// A controller's value as 0 … 1 at its full resolution, for a learned mapping.
        public var normalizedControl: Double? {
            guard case let .controlChange(_, value) = kind else { return nil }
            return Double(value) / Double(UInt32.max)
        }
    }

    // MARK: - Packets

    /// How many words a UMP of `messageType` takes (M2-104-UM table 4).
    public static func wordCount(messageType: UInt32) -> Int {
        switch messageType & 0xF {
        case 0x0, 0x1, 0x2, 0x6, 0x7: 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: 2
        case 0xB, 0xC: 3
        default: 4
        }
    }
}

/// MPE out as MIDI 2.0: the zone's MIDI 1.0 messages (`MPEZone`) translated for a receiver that
/// speaks the MIDI 2.0 protocol. Values are scaled up with Min-Center-Max; a member channel's
/// pitch bend becomes the per-note pitch bend of the note sounding on it; the zone's RPN
/// sequences (CC 101/100/6/38, then the null RPN) become MIDI 2.0 RPN messages. One value per
/// output, mutated on the pump's queue.
public struct MIDI2Translator: Sendable, Equatable {
    /// Per channel: the note sounding on it, the member bend waiting for that note, and the RPN
    /// selected by CC 101/100 (127/127 is none).
    private var note: [UInt8?] = Array(repeating: nil, count: 16)
    private var pendingBend: [UInt32?] = Array(repeating: nil, count: 16)
    private var parameterMSB: [UInt8] = Array(repeating: 127, count: 16)
    private var parameterLSB: [UInt8] = Array(repeating: 127, count: 16)
    private var dataMSB: [UInt8] = Array(repeating: 0, count: 16)

    public init() {}

    /// The MIDI 2.0 words for one zone message (`MPEZone.masterChannel` is the master).
    public mutating func translate(_ message: MPEZone.Message) -> [UInt32] {
        let channel = message.channel, index = Int(channel)
        let isMember = channel != MPEZone.masterChannel
        func out(_ kind: UMP.Kind) -> [UInt32] {
            let words = UMP.Message(channel: channel, kind).words
            return [words.0, words.1]
        }
        switch message.status & 0xF0 {
        case 0x90 where message.data2 > 0:
            note[index] = message.data1
            var words = out(.noteOn(note: message.data1, velocity: UInt16(UMP.scaleUp(UInt32(message.data2), from: 7, to: 16)),
                                    attributeType: 0, attribute: 0))
            if isMember {
                let bend = pendingBend[index] ?? UMP.centre32
                pendingBend[index] = nil
                words += out(.perNotePitchBend(note: message.data1, value: bend))
            }
            return words
        case 0x80, 0x90:
            if note[index] == message.data1 { note[index] = nil }
            return out(.noteOff(note: message.data1, velocity: UInt16(UMP.scaleUp(UInt32(message.data2), from: 7, to: 16)),
                                attributeType: 0, attribute: 0))
        case 0xE0:
            let value = UMP.scaleUp(UInt32(message.data1) | UInt32(message.data2) << 7, from: 14, to: 32)
            guard isMember else { return out(.pitchBend(value: value)) }
            guard let sounding = note[index] else {
                // Stated before the note-on (MPE's "expression before the note"): it goes out as
                // the note's own bend right after the note starts.
                pendingBend[index] = value
                return []
            }
            return out(.perNotePitchBend(note: sounding, value: value))
        case 0xD0:
            return out(.channelPressure(value: UMP.scaleUp(UInt32(message.data1), from: 7, to: 32)))
        case 0xA0:
            return out(.polyPressure(note: message.data1, value: UMP.scaleUp(UInt32(message.data2), from: 7, to: 32)))
        case 0xC0:
            return out(.programChange(program: message.data1, bank: nil))
        case 0xB0:
            return controller(message, channel: channel)
        default:
            return []
        }
    }

    private mutating func controller(_ message: MPEZone.Message, channel: UInt8) -> [UInt32] {
        let index = Int(channel)
        func parameter(_ value14: UInt32) -> [UInt32] {
            guard parameterMSB[index] != 127 || parameterLSB[index] != 127 else { return [] }
            let words = UMP.Message(channel: channel, .parameter(registered: true, bank: parameterMSB[index],
                                                                 index: parameterLSB[index],
                                                                 value: UMP.scaleUp(value14, from: 14, to: 32))).words
            return [words.0, words.1]
        }
        switch message.data1 {
        case 101:
            parameterMSB[index] = message.data2
            return []
        case 100:
            parameterLSB[index] = message.data2
            return []
        case 6:
            dataMSB[index] = message.data2
            return parameter(UInt32(message.data2) << 7)
        case 38:
            return parameter(UInt32(dataMSB[index]) << 7 | UInt32(message.data2))
        case 123, 120:
            note[index] = nil
            pendingBend[index] = nil
            fallthrough
        default:
            let words = UMP.Message(channel: channel, .controlChange(index: message.data1,
                                                                     value: UMP.scaleUp(UInt32(message.data2), from: 7, to: 32))).words
            return [words.0, words.1]
        }
    }
}

/// What one batch of zone messages sends: the MIDI 1.0 words for the chosen outputs — exactly the
/// words MPE out always sent — and, only while the MIDI 2.0 source is on, its MIDI 2.0 words.
public enum MPEOutputWords {
    public static func midi1(_ messages: [MPEZone.Message]) -> [UInt32] {
        messages.map { UMP.midi1Word(UMP.Channel1($0.status, $0.data1, $0.data2)) }
    }

    /// Nil while the MIDI 2.0 source is off: nothing is translated and nothing is sent.
    public static func midi2(_ messages: [MPEZone.Message], translator: inout MIDI2Translator?) -> [UInt32]? {
        guard translator != nil else { return nil }
        var words: [UInt32] = []
        for message in messages { words += translator?.translate(message) ?? [] }
        return words
    }
}

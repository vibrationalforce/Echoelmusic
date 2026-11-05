import Synchronization

// MIDI Time Code (W17-TC): SMPTE timecode over MIDI for theatre, video and installation — a
// lighting desk, QLab, Reaper or a video player follows Echoel's song, or Echoel follows theirs.
// Everything here is pure arithmetic on plain values: the render thread generates quarter frames
// with it, the MIDI threads decode with it, and the tests run it without a device.
// References: MIDI 1.0 Detailed Specification, "MIDI Time Code" (quarter frame F1, full frame
// F0 7F cc 01 01 hh mm ss ff F7); SMPTE 12M for the drop-frame count.

/// The four rates MTC carries, by the two-bit code it sends (bits 5–6 of the hours byte).
public enum MTCRate: Int, CaseIterable, Sendable {
    case fps24 = 0
    case fps25 = 1
    /// 29.97 fps drop-frame: labels 00 and 01 are skipped at the start of every minute except
    /// every tenth, so the label keeps up with the clock at 30 000/1001 frames a second.
    case fps29_97DropFrame = 2
    case fps30 = 3

    /// Frames a timecode second counts.
    public var nominal: Int {
        switch self {
        case .fps24: 24
        case .fps25: 25
        case .fps29_97DropFrame, .fps30: 30
        }
    }

    /// Frames in one second of clock time.
    public var framesPerSecond: Double {
        switch self {
        case .fps29_97DropFrame: 30_000.0 / 1_001.0
        default: Double(nominal)
        }
    }

    public var isDropFrame: Bool { self == .fps29_97DropFrame }

    /// `framesPerSecond` as a fraction, for arithmetic that must land on the exact sample.
    var fraction: (numerator: Int64, denominator: Int64) {
        isDropFrame ? (30_000, 1_001) : (Int64(nominal), 1)
    }

    /// Frames from 00:00:00:00 to 24:00:00:00, where the label wraps.
    public var framesPerDay: Int64 {
        isDropFrame ? 24 * 6 * Int64(MTCRate.dropFramesPerTenMinutes) : Int64(nominal) * 86_400
    }

    public var title: String {
        switch self {
        case .fps24: "24 fps"
        case .fps25: "25 fps"
        case .fps29_97DropFrame: "29.97 fps Drop-Frame"
        case .fps30: "30 fps"
        }
    }

    /// Ten minutes of drop-frame: 18 000 labels less 9 × 2 dropped.
    static let dropFramesPerTenMinutes = 17_982
    /// A minute of drop-frame that drops: 1 800 labels less 2.
    static let dropFramesPerMinute = 1_798
}

/// A timecode label, HH:MM:SS:FF.
public struct Timecode: Equatable, Hashable, Sendable {
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var frames: Int

    public init(hours: Int, minutes: Int, seconds: Int, frames: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
    }

    /// The label of the frame `count` frames after 00:00:00:00 — every frame sent counts, so in
    /// drop-frame the labels skip — wrapping at 24 hours. Arithmetic only: render-safe.
    public init(frameCount count: Int64, rate: MTCRate) {
        let day = rate.framesPerDay
        var n = count % day
        if n < 0 { n += day }
        if rate.isDropFrame {
            let tens = n / Int64(MTCRate.dropFramesPerTenMinutes)
            let rest = n % Int64(MTCRate.dropFramesPerTenMinutes)
            // Two labels dropped per minute, nine minutes in ten; the first minute of ten drops none.
            n += 18 * tens + (rest > 1 ? 2 * ((rest - 2) / Int64(MTCRate.dropFramesPerMinute)) : 0)
        }
        let nominal = Int64(rate.nominal)
        frames = Int(n % nominal)
        seconds = Int((n / nominal) % 60)
        minutes = Int((n / (nominal * 60)) % 60)
        hours = Int((n / (nominal * 3_600)) % 24)
    }

    /// Frames from 00:00:00:00 to this label, or nil when it is no label of `rate` — a field out of
    /// range, or one of the labels drop-frame skips (00 and 01 of a minute that is not a tenth).
    public func frameCount(rate: MTCRate) -> Int64? {
        guard (0..<24).contains(hours), (0..<60).contains(minutes), (0..<60).contains(seconds),
              (0..<rate.nominal).contains(frames) else { return nil }
        let nominal = Int64(rate.nominal)
        let labels = ((Int64(hours) * 60 + Int64(minutes)) * 60 + Int64(seconds)) * nominal + Int64(frames)
        guard rate.isDropFrame else { return labels }
        guard !(seconds == 0 && frames < 2 && minutes % 10 != 0) else { return nil }
        let totalMinutes = Int64(hours) * 60 + Int64(minutes)
        return labels - 2 * (totalMinutes - totalMinutes / 10)
    }

    /// Seconds of clock time from 00:00:00:00 to this label at `rate`, or nil for no label of it.
    public func seconds(rate: MTCRate) -> Double? {
        frameCount(rate: rate).map { Double($0) / rate.framesPerSecond }
    }

    /// "01:00:00:00"; drop-frame separates the frames with a semicolon, as editors write it.
    public func text(rate: MTCRate) -> String {
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return "\(two(hours)):\(two(minutes)):\(two(seconds))\(rate.isDropFrame ? ";" : ":")\(two(frames))"
    }
}

/// The eight quarter-frame messages (status F1) that spell one timecode over two frames.
public enum MTCQuarterFrame {
    public static let status: UInt8 = 0xF1

    /// The data byte of piece `piece` (0 … 7) of `timecode` at `rate`: the piece number in the
    /// high nibble, four bits of the label in the low one — frames, seconds, minutes, hours, each
    /// low nibble first; the last piece carries the rate beside the hours' top bit.
    public static func data(piece: Int, of timecode: Timecode, rate: MTCRate) -> UInt8 {
        let p = piece & 7
        let nibble: Int
        switch p {
        case 0: nibble = timecode.frames & 0x0F
        case 1: nibble = (timecode.frames >> 4) & 0x01
        case 2: nibble = timecode.seconds & 0x0F
        case 3: nibble = (timecode.seconds >> 4) & 0x03
        case 4: nibble = timecode.minutes & 0x0F
        case 5: nibble = (timecode.minutes >> 4) & 0x03
        case 6: nibble = timecode.hours & 0x0F
        default: nibble = (rate.rawValue << 1) | ((timecode.hours >> 4) & 0x01)
        }
        return UInt8(p << 4 | nibble)
    }
}

/// Puts the eight pieces back together. A timecode is complete with piece 7 after 0 … 6 in
/// order; a piece out of order starts over, so a dropped message costs one sequence, never a wrong
/// time. Forward only: a sender running backwards (pieces 7 … 0) is not read.
public struct MTCQuarterFrameDecoder: Sendable {
    public struct Decoded: Equatable, Sendable {
        /// The label piece 0 began: the frame the sequence describes.
        public let timecode: Timecode
        public let rate: MTCRate

        /// Piece 7 arrives a frame and three quarters after the frame the sequence describes.
        public static let latencyFrames = 1.75
    }

    private var nibbles: UInt32 = 0
    private var expected = 0

    public init() {}

    public mutating func reset() {
        nibbles = 0
        expected = 0
    }

    public mutating func receive(_ data: UInt8) -> Decoded? {
        let piece = Int(data >> 4) & 0x07
        guard piece == expected else {
            reset()
            guard piece == 0 else { return nil }
            return receive(data)
        }
        nibbles |= UInt32(data & 0x0F) << (4 * UInt32(piece))
        expected += 1
        guard piece == 7 else { return nil }
        let value = nibbles
        reset()
        func nibble(_ i: UInt32) -> Int { Int((value >> (4 * i)) & 0x0F) }
        guard let rate = MTCRate(rawValue: (nibble(7) >> 1) & 0x03) else { return nil }
        let timecode = Timecode(hours: nibble(6) | (nibble(7) & 0x01) << 4,
                                minutes: nibble(4) | (nibble(5) & 0x03) << 4,
                                seconds: nibble(2) | (nibble(3) & 0x03) << 4,
                                frames: nibble(0) | (nibble(1) & 0x01) << 4)
        guard timecode.frameCount(rate: rate) != nil else { return nil }
        return Decoded(timecode: timecode, rate: rate)
    }
}

/// The full-frame message: the whole label at once, sent at a locate and a stop, when quarter
/// frames do not run. F0 7F <device> 01 01 hh mm ss ff F7, hh carrying the rate in bits 5–6.
public struct MTCFullFrame: Equatable, Sendable {
    public let timecode: Timecode
    public let rate: MTCRate

    public init(timecode: Timecode, rate: MTCRate) {
        self.timecode = timecode
        self.rate = rate
    }

    /// 7F (all devices) means everyone.
    public static let allDevices: UInt8 = 0x7F

    var hoursByte: UInt8 { UInt8(rate.rawValue << 5 | (timecode.hours & 0x1F)) }

    /// The ten bytes on a MIDI 1.0 wire: F0, 7F (real time, universal), device, 01 (MTC),
    /// 01 (full message), hh mm ss ff, F7.
    public var bytes: [UInt8] {
        [0xF0, 0x7F, Self.allDevices, 0x01, 0x01, hoursByte, UInt8(timecode.minutes & 0x3F),
         UInt8(timecode.seconds & 0x3F), UInt8(timecode.frames & 0x1F), 0xF7]
    }

    /// The same as two Universal MIDI Packets of message type 3 (System Exclusive 7-bit, group 1):
    /// a start packet with the first six payload bytes and an end packet with the last two; the
    /// F0 and F7 are not carried. Arithmetic only, no array.
    public var universalPackets: (UInt32, UInt32, UInt32, UInt32) {
        let minutes = UInt32(timecode.minutes & 0x3F), seconds = UInt32(timecode.seconds & 0x3F)
        let frames = UInt32(timecode.frames & 0x1F)
        let start = UInt32(0x3) << 28 | UInt32(0x1) << 20 | 6 << 16 | UInt32(0x7F) << 8 | UInt32(Self.allDevices)
        let startRest = UInt32(0x01) << 24 | UInt32(0x01) << 16 | UInt32(hoursByte) << 8 | minutes
        let end = UInt32(0x3) << 28 | UInt32(0x3) << 20 | 2 << 16 | seconds << 8 | frames
        return (start, startRest, end, 0)
    }

    /// The full frame in the eight payload bytes between F0 and F7, or nil when they are another
    /// message or no label of their rate. Any device id is read.
    init?(payload: UInt64) {
        func byte(_ index: Int) -> Int { Int((payload >> UInt64(8 * (7 - index))) & 0xFF) }
        guard byte(0) == 0x7F, byte(2) == 0x01, byte(3) == 0x01,
              let rate = MTCRate(rawValue: (byte(4) >> 5) & 0x03) else { return nil }
        let timecode = Timecode(hours: byte(4) & 0x1F, minutes: byte(5), seconds: byte(6), frames: byte(7))
        guard timecode.frameCount(rate: rate) != nil else { return nil }
        self.init(timecode: timecode, rate: rate)
    }
}

/// Reads full frames out of a stream of message-type-3 packets (how CoreMIDI hands a System
/// Exclusive to a Universal MIDI Packet port). Holds at most eight bytes in one integer; anything
/// longer is another message and is skipped to its end. Arithmetic only: safe on the MIDI thread.
public struct MTCSysExReader: Sendable {
    private var payload: UInt64 = 0
    private var count = 0
    private var collecting = false

    public init() {}

    /// One 64-bit packet. Returns the full frame its end completes, if it is one.
    public mutating func read(_ word0: UInt32, _ word1: UInt32) -> MTCFullFrame? {
        guard word0 >> 28 == 0x3 else { return nil }
        let status = (word0 >> 20) & 0x0F
        let length = Swift.min(Int((word0 >> 16) & 0x0F), 6)
        if status == 0 || status == 1 {
            payload = 0
            count = 0
            collecting = true
        } else if !collecting {
            return nil
        }
        for index in 0..<length {
            guard count < 8 else {
                collecting = false
                return nil
            }
            payload = payload << 8 | UInt64(Self.byte(index, of: word0, word1))
            count += 1
        }
        guard status == 0 || status == 3 else { return nil }
        collecting = false
        guard count == 8 else { return nil }
        return MTCFullFrame(payload: payload)
    }

    /// Payload byte `index` (0 … 5) of a 64-bit System Exclusive packet.
    private static func byte(_ index: Int, of word0: UInt32, _ word1: UInt32) -> UInt32 {
        index < 2 ? (word0 >> (8 * UInt32(1 - index))) & 0xFF : (word1 >> (8 * UInt32(5 - index))) & 0xFF
    }
}

/// Follows an external MTC (chase): locates at a full frame, runs along with the quarter frames,
/// and stops when they have stayed away four frames. Positions are seconds of the SONG — the
/// timecode less the start offset (01:00:00:00 is bar 1 by default, as the EDL counts). Pure:
/// it is handed each message with the time it arrived, on any steady clock in seconds.
public struct MTCChase: Sendable {
    public enum Action: Equatable, Sendable {
        /// Stand at this song second, not running (a full frame).
        case locate(seconds: Double)
        /// The sender runs: at `time` its song stood at `seconds`. Before the song's start it is
        /// held at 0 (`seconds` is then negative and the caller waits).
        case follow(seconds: Double, at: Double)
        /// Quarter frames stopped coming.
        case stop
    }

    /// What to do with the gap between the sender and what is heard.
    public enum Correction: Equatable, Sendable {
        /// Within the tolerance: move by this much without a seek (0: leave it).
        case nudge(seconds: Double)
        /// Too far off: jump onto the sender.
        case relocate
    }

    /// Frames without a quarter frame after which the sender counts as stopped.
    public static let timeoutFrames = 4.0
    /// A gap below this is left alone: MIDI arrives with a jitter of about a millisecond.
    public static let deadband = 0.002

    /// The sender's label for the song's first sample; in seconds at whatever rate it speaks.
    public var start: Timecode
    /// Frames the heard song may stand off the sender before it jumps.
    public var toleranceFrames: Double
    public private(set) var isRunning = false
    /// The rate the sender last spoke.
    public private(set) var rate: MTCRate?
    private var decoder = MTCQuarterFrameDecoder()
    private var lastQuarter: Double?

    public init(start: Timecode, toleranceFrames: Double = 2) {
        self.start = start
        self.toleranceFrames = toleranceFrames.isFinite ? Swift.max(toleranceFrames, 0.25) : 2
    }

    public mutating func receiveFullFrame(_ frame: MTCFullFrame) -> Action? {
        guard let seconds = frame.timecode.seconds(rate: frame.rate) else { return nil }
        rate = frame.rate
        isRunning = false
        lastQuarter = nil
        decoder.reset()
        return .locate(seconds: Swift.max(seconds - offset(frame.rate), 0))
    }

    public mutating func receiveQuarterFrame(_ data: UInt8, at time: Double) -> Action? {
        guard time.isFinite else { return nil }
        lastQuarter = time
        guard let decoded = decoder.receive(data), let frames = decoded.timecode.frameCount(rate: decoded.rate) else {
            return nil
        }
        rate = decoded.rate
        isRunning = true
        let seconds = (Double(frames) + MTCQuarterFrameDecoder.Decoded.latencyFrames) / decoded.rate.framesPerSecond
        return .follow(seconds: seconds - offset(decoded.rate), at: time)
    }

    /// `start` in seconds of `rate`; a label the rate has not (a dropped one) counts as 0.
    private func offset(_ rate: MTCRate) -> Double { start.seconds(rate: rate) ?? 0 }

    /// Called now and then: a running sender silent for `timeoutFrames` has stopped.
    public mutating func check(at time: Double) -> Action? {
        guard isRunning, let last = lastQuarter, time.isFinite else { return nil }
        let frame = 1 / (rate ?? .fps30).framesPerSecond
        guard time - last > Self.timeoutFrames * frame else { return nil }
        isRunning = false
        lastQuarter = nil
        decoder.reset()
        return .stop
    }

    /// The correction for `gap` seconds (sender minus heard): within the tolerance, half of it as
    /// a nudge, so jitter is smoothed and a steady offset still closes; beyond it, a jump.
    public func correction(gap: Double) -> Correction {
        guard gap.isFinite else { return .nudge(seconds: 0) }
        let frame = 1 / (rate ?? .fps30).framesPerSecond
        if abs(gap) > toleranceFrames * frame { return .relocate }
        return .nudge(seconds: abs(gap) > Self.deadband ? gap / 2 : 0)
    }
}

/// A timecode message the render thread timed for the MTC sender: a quarter frame, or a full
/// frame at a locate or a stop. Plain values only, so the ring never retains on the render thread.
public struct TimecodeMessage: Sendable, Equatable {
    /// Host time of the first frame of the render call (0 offline).
    public let hostTime: UInt64
    /// Frames after that first frame.
    public let frame: Int
    /// `MTCQuarterFrame.status` (F1) or F0 for a full frame.
    public let status: UInt8
    /// A quarter frame's data byte.
    public let data: UInt8
    /// A full frame's position, in frames from 00:00:00:00.
    public let frameCount: Int64
    public let rate: MTCRate

    /// A full frame's label; nil for a quarter frame.
    public var fullFrame: MTCFullFrame? {
        status == 0xF0 ? MTCFullFrame(timecode: Timecode(frameCount: frameCount, rate: rate), rate: rate) : nil
    }
}

public typealias TimecodeRing = SPSCRing<TimecodeMessage>

extension SPSCRing where Element == TimecodeMessage {
    public convenience init(capacity: Int = 1_024) {
        self.init(capacity: capacity, filler: TimecodeMessage(hostTime: 0, frame: 0, status: 0, data: 0,
                                                              frameCount: 0, rate: .fps25))
    }
}

/// Generates MTC from the engine's sample counter: the song's sample 0 is the start offset, and
/// every quarter frame falls on the first sample at or after its moment — the timecode never reads
/// a wall clock. The eight-piece sequences start on even frames counted from 00:00:00:00, so a
/// receiver sees the same pieces whatever the locate. Render-safe: arithmetic and a ring push.
public struct MTCGenerator: Sendable {
    public let sampleRate: Double
    /// The sample rate as a whole number when it is one (every interface's is), so a quarter
    /// frame's sample is exact integer arithmetic; 0 for a fractional rate.
    private let wholeRate: Int64
    public private(set) var rate: MTCRate = .fps25
    public private(set) var startFrames: Int64 = 0
    /// The next quarter frame to send, counted from 00:00:00:00; −1 until the next locate.
    private var nextQuarter: Int64 = -1

    public init(sampleRate: Double) {
        let rate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        self.sampleRate = rate
        wholeRate = rate == rate.rounded() && rate < 10_000_000 ? Int64(rate) : 0
    }

    /// True when the rate or the start changed (the receiver must be told with a full frame).
    @discardableResult
    public mutating func configure(rate: MTCRate, startFrames: Int64) -> Bool {
        let start = Swift.max(0, startFrames)
        guard rate != self.rate || start != self.startFrames else { return false }
        self.rate = rate
        self.startFrames = start
        nextQuarter = -1
        return true
    }

    /// The quarter frames start again from wherever the next block begins.
    public mutating func locate() { nextQuarter = -1 }

    /// The first sample at or after quarter frame `quarter`.
    public func sample(ofQuarter quarter: Int64) -> Int64 {
        let (numerator, denominator) = rate.fraction
        let quarters = quarter - 4 * startFrames
        if wholeRate > 0, abs(quarters) < 1 << 31 {
            // ceil(quarters / 4 / fps × rate), in integers.
            let top = quarters * wholeRate * denominator, bottom = 4 * numerator
            return top >= 0 ? (top + bottom - 1) / bottom : -((-top) / bottom)
        }
        let seconds = (Double(quarter) / 4 - Double(startFrames)) / rate.framesPerSecond
        let first = (seconds * sampleRate).rounded(.up)
        guard first.isFinite else { return 0 }
        return Int64(Swift.min(Swift.max(first, -9e15), 9e15))
    }

    /// The frame sounding at `sample`, in frames from 00:00:00:00.
    public func frameCount(atSample sample: Int64) -> Int64 {
        let (numerator, denominator) = rate.fraction
        if wholeRate > 0, sample >= 0, sample < 1 << 40 {
            return startFrames + sample * numerator / (wholeRate * denominator)
        }
        let frames = (Double(sample) * rate.framesPerSecond / sampleRate).rounded(.down)
        guard frames.isFinite else { return startFrames }
        return startFrames + Int64(Swift.min(Swift.max(frames, 0), 9e15))
    }

    /// The first quarter frame due at or after `sample`.
    func quarter(atOrAfter position: Int64) -> Int64 {
        let estimate = (Double(startFrames) + Double(position) * rate.framesPerSecond / sampleRate) * 4
        var quarter = Int64(Swift.min(Swift.max(estimate.rounded(.down), 0), 9e15))
        while quarter > 0, sample(ofQuarter: quarter - 1) >= position { quarter -= 1 }
        while sample(ofQuarter: quarter) < position { quarter += 1 }
        return quarter
    }

    /// The data byte of quarter frame `quarter`: its piece, of the label of the even frame its
    /// sequence began on.
    public func data(ofQuarter quarter: Int64) -> UInt8 {
        let sequenceFrame = (quarter / 8) * 2
        return MTCQuarterFrame.data(piece: Int(quarter % 8), of: Timecode(frameCount: sequenceFrame, rate: rate), rate: rate)
    }

    /// Times every quarter frame due in `from ..< to` (song samples) into `ring`, `chunkStart`
    /// frames into the render call that began at `hostTime`.
    mutating func sendQuarterFrames(from: Int64, to: Int64, into ring: TimecodeRing, hostTime: UInt64, chunkStart: Int) {
        guard to > from else { return }
        // After a locate, or a nudge that skipped more than a frame: on from here.
        if nextQuarter < 0 || sample(ofQuarter: nextQuarter) < from - Int64(sampleRate / rate.framesPerSecond) {
            nextQuarter = quarter(atOrAfter: from)
        }
        while true {
            let due = sample(ofQuarter: nextQuarter)
            guard due < to else { break }
            ring.push(TimecodeMessage(hostTime: hostTime, frame: chunkStart + Int(Swift.max(due - from, 0)),
                                      status: MTCQuarterFrame.status, data: data(ofQuarter: nextQuarter),
                                      frameCount: 0, rate: rate))
            nextQuarter += 1
        }
    }

    /// Times a full frame of the position at song sample `sample`.
    func sendFullFrame(atSample sample: Int64, into ring: TimecodeRing, hostTime: UInt64, frame: Int) {
        ring.push(TimecodeMessage(hostTime: hostTime, frame: frame, status: 0xF0, data: 0,
                                  frameCount: frameCount(atSample: sample), rate: rate))
    }
}

/// Timecode from a MIDI thread to the main thread: quarter frames and full frames, each with the
/// host time it arrived. One producer (the input port's callback), one consumer.
public final class MTCInbox: Sendable {
    public struct Event: Sendable, Equatable {
        public let hostTime: UInt64
        /// A quarter frame's data byte; ignored for a full frame.
        public let data: UInt8
        /// Set for a full frame.
        public let fullFrame: MTCFullFrame?

        public init(hostTime: UInt64, data: UInt8, fullFrame: MTCFullFrame?) {
            self.hostTime = hostTime
            self.data = data
            self.fullFrame = fullFrame
        }
    }

    private let ring = SPSCRing<Event>(capacity: 512, filler: Event(hostTime: 0, data: 0, fullFrame: nil))
    private let scheduled = Atomic<Bool>(false)

    public init() {}

    /// MIDI thread. True when the main thread must be asked to drain (at most one ask in flight).
    public func post(_ event: Event) -> Bool {
        ring.push(event)
        return !scheduled.exchange(true, ordering: .acquiringAndReleasing)
    }

    /// Main thread: the next waiting event; nil clears the ask, so the next post asks again.
    public func next() -> Event? {
        if let event = ring.pop() { return event }
        scheduled.store(false, ordering: .releasing)
        return ring.pop()
    }
}

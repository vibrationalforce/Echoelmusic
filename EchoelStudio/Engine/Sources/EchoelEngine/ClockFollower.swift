import EchoelCore

/// Follows an external MIDI clock: the tempo from the spacing of its 24-per-quarter pulses,
/// and what its transport messages ask for. Pure and clock-agnostic — it is handed each
/// message with the time it arrived, so it is tested without a device.
public struct ClockFollower: Sendable {
    public enum Action: Equatable, Sendable {
        /// Start from the top.
        case start
        /// Go on from the current position.
        case resume
        /// Stop where it is.
        case stop
        /// Jump to this many sixteenths from the top.
        case position(Int)
    }

    /// Pulses averaged for the tempo: one quarter note.
    public static let window = 24
    /// A gap this many times the average is a pause (the sender stopped clocking), not a slow beat.
    static let gapFactor = 4.0

    /// The tempo of the clock, or nil until a quarter note's worth of steady pulses came in.
    public private(set) var tempo: Double?
    private var intervals: [Double] = []
    private var lastPulse: Double?

    public init() {}

    /// One message, at `time` seconds on any steady clock. Returns what the transport should do.
    public mutating func receive(status: UInt8, _ data1: UInt8 = 0, _ data2: UInt8 = 0, at time: Double) -> Action? {
        switch status {
        case 0xF8:
            pulse(at: time)
            return nil
        case 0xFA:
            lastPulse = nil
            return .start
        case 0xFB:
            lastPulse = nil
            return .resume
        case 0xFC:
            return .stop
        case 0xF2:
            return .position(Int(data1 & 0x7F) | Int(data2 & 0x7F) << 7)
        default:
            return nil
        }
    }

    private mutating func pulse(at time: Double) {
        defer { lastPulse = time }
        guard let last = lastPulse, time.isFinite else { return }
        let interval = time - last
        guard interval > 0 else { return }
        if let tempo, interval > Self.gapFactor * 60 / (tempo * Double(Self.window)) { return }
        intervals.append(interval)
        if intervals.count > Self.window { intervals.removeFirst(intervals.count - Self.window) }
        guard intervals.count == Self.window else { return }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60 / (mean * Double(Self.window))
        // To a hundredth of a BPM: a sender's jitter must not make the tempo wander.
        tempo = Swift.min(Swift.max((bpm * 100).rounded() / 100, Tempo.range.lowerBound), Tempo.range.upperBound)
    }
}

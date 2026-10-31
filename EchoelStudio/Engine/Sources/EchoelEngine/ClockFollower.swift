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
    /// Long intervals set aside as pauses. When a few in a row agree, the sender has really
    /// slowed down, and they become the new tempo instead of being ignored for ever.
    private var longIntervals: [Double] = []
    static let slowdownEvidence = 3

    /// Ticks one pulse spans.
    public static let ticksPerPulse = MusicalTime.ticksPerQuarter / Tick(window)
    /// Where the sender's song stands: the position of its next pulse after a start, continue or
    /// song position, then counted on per pulse.
    private var anchor: Tick = 0
    private var pulsesSinceAnchor = -1
    private var lastPulseTime: Double?
    /// The sender's transport runs.
    public private(set) var isRunning = false

    public init() {}

    /// One message, at `time` seconds on any steady clock. Returns what the transport should do.
    public mutating func receive(status: UInt8, _ data1: UInt8 = 0, _ data2: UInt8 = 0, at time: Double) -> Action? {
        switch status {
        case 0xF8:
            pulse(at: time)
            if isRunning, time.isFinite {
                pulsesSinceAnchor += 1
                lastPulseTime = time
            }
            return nil
        case 0xFA:
            lastPulse = nil
            reanchor(at: 0)
            isRunning = true
            return .start
        case 0xFB:
            lastPulse = nil
            reanchor(at: nextPulsePosition)
            isRunning = true
            return .resume
        case 0xFC:
            reanchor(at: nextPulsePosition)
            isRunning = false
            return .stop
        case 0xF2:
            let sixteenths = Int(data1 & 0x7F) | Int(data2 & 0x7F) << 7
            reanchor(at: Tick(sixteenths) * MusicalTime.ticksPerQuarter / 4)
            return .position(sixteenths)
        default:
            return nil
        }
    }

    /// The tick the sender's next pulse stands for.
    private var nextPulsePosition: Tick { anchor + Tick(pulsesSinceAnchor + 1) * Self.ticksPerPulse }

    private mutating func reanchor(at tick: Tick) {
        anchor = tick
        pulsesSinceAnchor = -1
        lastPulseTime = nil
    }

    /// Where the sender's song stood at `time` (same clock as `receive`), in fractional ticks:
    /// its last pulse, carried on at its tempo for at most one pulse. Nil while it is stopped or
    /// before its first pulse.
    public func position(at time: Double) -> Double? {
        guard isRunning, pulsesSinceAnchor >= 0, let pulseTime = lastPulseTime, time.isFinite else { return nil }
        let base = Double(anchor + Tick(pulsesSinceAnchor) * Self.ticksPerPulse)
        guard let tempo else { return base }
        let interval = 60 / (tempo * Double(Self.window))
        let along = Swift.min(Swift.max((time - pulseTime) / interval, 0), 1)
        return base + along * Double(Self.ticksPerPulse)
    }

    private mutating func pulse(at time: Double) {
        defer { lastPulse = time }
        guard let last = lastPulse, time.isFinite else { return }
        let interval = time - last
        guard interval > 0 else { return }
        if let tempo, interval > Self.gapFactor * 60 / (tempo * Double(Self.window)) {
            longIntervals.append(interval)
            guard longIntervals.count >= Self.slowdownEvidence,
                  let low = longIntervals.min(), let high = longIntervals.max(), high <= low * 1.1 else {
                if longIntervals.count >= Self.slowdownEvidence { longIntervals.removeFirst() }
                return
            }
            intervals = longIntervals
            longIntervals.removeAll()
            self.tempo = nil
            return
        }
        longIntervals.removeAll()
        intervals.append(interval)
        if intervals.count > Self.window { intervals.removeFirst(intervals.count - Self.window) }
        guard intervals.count == Self.window else { return }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60 / (mean * Double(Self.window))
        // To a hundredth of a BPM: a sender's jitter must not make the tempo wander.
        tempo = Swift.min(Swift.max((bpm * 100).rounded() / 100, Tempo.range.lowerBound), Tempo.range.upperBound)
    }
}

extension ClockFollower {
    /// The song as the engine plays it while a followed clock sets the tempo: the clock's `tempo`
    /// in place of the song's, within `Tempo.range`, and none of the song's own tempo changes —
    /// they would run the song off the clock. Nil, or a tempo that is not a number, keeps the
    /// song's tempo until the clock's is known. The song itself is never written: it keeps its
    /// tempo and its undo history while another device sets the pace.
    ///
    /// Every snapshot the engine publishes, every seek, every placement and every automation
    /// point goes through this one function while following, so none of them is computed from
    /// the song's own map while the clock plays another (review 2026-10-28, 2.2).
    ///
    /// A jam's host (W16) also owns the time signature: `signature`, when it is one a song can
    /// have, is played in place of the song's, so the click and the bar lines are the host's. A MIDI
    /// clock carries none and passes nil; the song's own signature, like its tempo, waits
    /// underneath unchanged.
    public static func played(_ project: Project, tempo: Double?, signature: TimeSignature? = nil) -> Project {
        var played = project
        played.tempoChanges = []
        if let tempo, tempo.isFinite {
            played.tempo = Swift.min(Swift.max(tempo, Tempo.range.lowerBound), Tempo.range.upperBound)
        }
        if let signature, signature.isValid {
            played.timeSignature = signature
        }
        return played
    }
}

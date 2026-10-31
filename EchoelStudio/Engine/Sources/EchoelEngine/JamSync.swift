import EchoelCore
import Foundation

/// The host's clock as a guest reads it, from pings and NTP's arithmetic: each answer gives the
/// offset between the two clocks (host minus guest) and the round trip it took. An answer that
/// waited in a queue on one leg is off by half the wait, so the estimate is the median offset of the
/// faster half of the newest answers — several measurements, never one.
public struct JamClockEstimate: Equatable, Sendable {
    public struct Sample: Equatable, Sendable {
        /// Host time minus guest time, in seconds.
        public let offset: Double
        /// Network time of the exchange, the host's own pause taken out.
        public let roundTrip: Double
    }

    /// Answers kept: the newest, so two clocks that drift apart are followed.
    public static let capacity = 16
    /// Answers needed before there is an estimate.
    public static let minimumSamples = 4
    /// A slower answer says more about a queue than about the clocks.
    public static let longestRoundTrip = 0.5

    public private(set) var samples: [Sample] = []

    public init() {}

    /// One answer, `receivedAt` on the guest's clock. False — and nothing kept — for one that
    /// cannot be: a number that is not finite, an answer before its question, a round trip below
    /// zero or longer than `longestRoundTrip`.
    @discardableResult
    public mutating func add(_ pong: JamPong, receivedAt: Double) -> Bool {
        let sent = pong.guestSentAt, arrived = pong.hostReceivedAt, answered = pong.hostSentAt
        guard sent.isFinite, arrived.isFinite, answered.isFinite, receivedAt.isFinite,
              answered >= arrived, receivedAt >= sent else { return false }
        let roundTrip = (receivedAt - sent) - (answered - arrived)
        guard roundTrip >= 0, roundTrip <= Self.longestRoundTrip else { return false }
        samples.append(Sample(offset: ((arrived - sent) + (answered - receivedAt)) / 2, roundTrip: roundTrip))
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
        return true
    }

    /// Host time minus guest time, in seconds; nil before `minimumSamples` answers came back.
    public var offset: Double? {
        guard samples.count >= Self.minimumSamples else { return nil }
        let fastest = samples.sorted { $0.roundTrip < $1.roundTrip }
        let kept = Array(fastest.prefix(Swift.max(Self.minimumSamples / 2, fastest.count / 2)))
        return Self.median(kept.map { $0.offset })
    }

    /// The median round trip, for the page; nil like `offset`.
    public var roundTrip: Double? {
        guard samples.count >= Self.minimumSamples else { return nil }
        return Self.median(samples.map { $0.roundTrip })
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

/// The host's song as the others follow it: where it stands at any moment on the host's clock,
/// carried on from the last anchor at the host's tempo, and where its bar lines fall.
public struct JamTimeline: Equatable, Sendable {
    public let state: JamState

    public init(_ state: JamState) {
        self.state = state
    }

    /// Ticks per second at the host's tempo.
    public var ticksPerSecond: Double {
        state.tempo * Double(MusicalTime.ticksPerQuarter) / 60
    }

    /// One bar of the host's time signature, in ticks (a quarter-note bar of four for a signature
    /// no song can have, which a guest never follows anyway).
    public var barTicks: Double {
        let signature = state.signature.isValid ? state.signature : TimeSignature.common
        return Double(Swift.max(MusicalTime.ticksPerBar(signature), 1))
    }

    /// The host's position at `time` on its own clock: carried on at its tempo while it plays,
    /// standing still while it is stopped.
    public func position(atHostTime time: Double) -> Double {
        guard state.isPlaying else { return state.anchorTick }
        return state.anchorTick + (time - state.anchorTime) * ticksPerSecond
    }

    /// When the host hears `tick`, on its own clock; nil while it is stopped.
    public func hostTime(ofTick tick: Double) -> Double? {
        guard state.isPlaying, ticksPerSecond > 0 else { return nil }
        return state.anchorTime + (tick - state.anchorTick) / ticksPerSecond
    }

    /// The first bar line at or after `position`, counted from the start of the song.
    public func barLine(atOrAfter position: Double) -> Double {
        (position / barTicks).rounded(.up) * barTicks
    }

    /// The host's next bar line at least `lead` seconds after `now` on the guest's clock, and when
    /// the guest hears it there (`offset`: host minus guest); nil while the host is stopped.
    public func start(afterLocal now: Double, offset: Double, lead: Double) -> JamStart? {
        guard state.isPlaying, now.isFinite, offset.isFinite, lead.isFinite else { return nil }
        let line = barLine(atOrAfter: position(atHostTime: now + offset + Swift.max(0, lead)))
        guard let host = hostTime(ofTick: line) else { return nil }
        return JamStart(hostTick: line, localTime: host - offset)
    }

    /// `ticks` folded into one bar around zero, −½ … +½ bar. Phones keep the same bar lines, not the
    /// same song position: each plays its own song, and two loops of whole bars stay in step this
    /// way whatever their lengths (Ableton Link keeps a phase the same way).
    public static func phase(_ ticks: Double, bar: Double) -> Double {
        guard ticks.isFinite, bar > 0 else { return 0 }
        return ticks - (ticks / bar).rounded() * bar
    }
}

/// Where and when a guest comes in: on the host's next bar line, far enough ahead to prepare.
public struct JamStart: Equatable, Sendable {
    /// The host's bar line, in its song's ticks.
    public let hostTick: Double
    /// When the host hears it, on the guest's clock.
    public let localTime: Double

    /// The guest's own position to start from: the host's bar, folded into the guest's loop while it
    /// loops, so a four-bar loop comes in on the bar of the host's phrase it belongs to.
    public func songTick(loop: Range<Tick>?) -> Tick {
        let tick = Swift.max(0, MusicalTime.integer(hostTick.rounded()))
        guard let loop, loop.upperBound > loop.lowerBound, tick >= loop.lowerBound else { return tick }
        return loop.lowerBound + (tick - loop.lowerBound) % (loop.upperBound - loop.lowerBound)
    }
}

/// What a following phone does about its phase.
public enum JamCorrection: Equatable, Sendable {
    case none
    /// Move the playhead by this many seconds (negative: back). No note is cut.
    case nudge(seconds: Double)
    /// Jump by this many ticks, as a seek: too far off to nudge.
    case relock(ticks: Double)
}

/// A guest's side of the jam, decided without a clock or a device, so it is tested: what the
/// host's last word says, when to come in, how far this phone's bar is from the host's, and what
/// a silence means. The app feeds it what arrived and what the engine hears, and does what it
/// answers. A guest follows the host's Play and Stop, but a phone stopped by hand while the host
/// plays sits out — it is not pulled back in at every bar — until it plays again or the host starts
/// anew.
public struct JamFollower: Sendable {
    public enum Phase: Equatable, Sendable {
        /// Waiting for the host's first word, or for the clocks to be measured.
        case waiting
        /// The host is stopped, and so is this phone.
        case stopped
        /// The host plays; this phone comes in on its next bar.
        case starting
        /// In step with the host.
        case following
        /// Stopped by hand while the host plays.
        case sittingOut
        /// No word from the host for `silenceLimit`, or the link dropped: this phone plays on at
        /// the host's last tempo.
        case hostLost
        /// The host ended the jam: this phone plays on at the host's last tempo.
        case ended
    }

    public enum Action: Equatable, Sendable {
        case none
        /// The host stopped: stop where the song is.
        case pause
        /// The host plays: come in here.
        case start(JamStart)
    }

    /// Seconds without a word from the host — a state or an answer to a ping — before it counts
    /// as lost. The host speaks at least once a second and answers twice a second.
    public static let silenceLimit = 3.0
    /// How far ahead a start is planned, so the app can wake and the audio can begin in time.
    public static let startLead = 0.25
    /// After a jump or the first trim, the next check waits this long: the buffers heard until then
    /// were rendered before it.
    public static let settle = 0.25
    /// Right after a start an error up to this size is taken out at once, by a nudge (no note is
    /// cut); a larger one relocks.
    public static let trimLimit = PhaseLock.relockThreshold

    public private(set) var phase: Phase = .waiting
    public private(set) var timeline: JamTimeline?
    public private(set) var clock = JamClockEstimate()
    private var lastHeard: Double?
    private var lock = PhaseLock()
    private var needsLock = false
    private var settledAt = -Double.infinity

    public init() {}

    /// The host's last state — the tempo and time signature this phone plays while it follows.
    public var state: JamState? { timeline?.state }

    /// The link to the host is up, `now` on this phone's clock: the silence is counted from here.
    public mutating func joined(at now: Double) {
        guard now.isFinite else { return }
        lastHeard = now
    }

    /// The host's state arrived at `now`; `playing`: this phone's transport runs.
    public mutating func received(_ state: JamState, at now: Double, playing: Bool) -> Action {
        guard state.isValid, now.isFinite else { return .none }
        lastHeard = now
        timeline = JamTimeline(state)
        guard state.isPlaying else {
            phase = .stopped
            return playing ? .pause : .none
        }
        switch phase {
        case .starting, .following, .sittingOut:
            return .none
        case .waiting, .stopped, .hostLost, .ended:
            if playing {
                comeIntoStep()
                return .none
            }
            return plan(at: now)
        }
    }

    /// An answer to a ping arrived at `now`.
    public mutating func received(_ pong: JamPong, at now: Double) {
        guard clock.add(pong, receivedAt: now) else { return }
        lastHeard = now
    }

    /// The app's regular look, a few times a second.
    public mutating func check(at now: Double, playing: Bool) -> Action {
        guard now.isFinite else { return .none }
        if let lastHeard, now - lastHeard > Self.silenceLimit, phase != .hostLost, phase != .ended {
            phase = .hostLost
            return .none
        }
        switch phase {
        case .waiting:
            guard let timeline, timeline.state.isPlaying else { return .none }
            if playing {
                comeIntoStep()
                return .none
            }
            return plan(at: now)
        case .following:
            if !playing { phase = .sittingOut }
            return .none
        case .sittingOut:
            if playing { comeIntoStep() }
            return .none
        case .stopped, .starting, .hostLost, .ended:
            return .none
        }
    }

    /// The app started the transport for a planned start: in step from the next check — or, when
    /// the audio refused, waiting for the next bar.
    public mutating func started(_ playing: Bool) {
        guard phase == .starting else { return }
        if playing {
            comeIntoStep()
        } else {
            phase = .waiting
        }
    }

    /// The link to the host went down.
    public mutating func linkDropped() {
        if phase != .ended { phase = .hostLost }
    }

    /// The host said it ends the jam.
    public mutating func hostLeft() {
        phase = .ended
    }

    /// One phase check while this phone plays: `heard` is the tick it hears at `now` on its own
    /// clock. Folded into the host's bar, so loops of any whole-bar length stay in step.
    public mutating func correct(heard: Double, atLocal now: Double) -> JamCorrection {
        guard phase == .following, let timeline, timeline.state.isPlaying, let offset = clock.offset,
              heard.isFinite, now.isFinite, now >= settledAt else { return .none }
        let gap = JamTimeline.phase(timeline.position(atHostTime: now + offset) - heard, bar: timeline.barTicks)
        let error = -gap / timeline.ticksPerSecond
        guard error.isFinite else { return .none }
        if needsLock {
            needsLock = false
            lock.reset()
            guard Swift.abs(error) > PhaseLock.deadband else { return .none }
            settledAt = now + Self.settle
            return Swift.abs(error) <= Self.trimLimit ? .nudge(seconds: -error) : .relock(ticks: gap)
        }
        switch lock.correct(error: error) {
        case .none:
            return .none
        case .nudge(let seconds):
            return .nudge(seconds: seconds)
        case .relock:
            settledAt = now + Self.settle
            return .relock(ticks: gap)
        }
    }

    private mutating func comeIntoStep() {
        phase = .following
        needsLock = true
    }

    /// The host plays and this phone does not: its next bar, once the clocks are measured.
    private mutating func plan(at now: Double) -> Action {
        guard let timeline, let offset = clock.offset,
              let start = timeline.start(afterLocal: now, offset: offset, lead: Self.startLead) else {
            phase = .waiting
            return .none
        }
        phase = .starting
        return .start(start)
    }
}

/// When the host speaks: at once when Play, the tempo or the time signature changed, or when its
/// song left the bar phase its last word promised (a seek, a jump, a clock it follows itself); and
/// at least once a second, so the guests' anchor never ages. Not at every check: an anchor that
/// still holds says nothing new.
public struct JamBeacon: Equatable, Sendable {
    /// The longest the host stays quiet while anyone listens.
    public static let interval = 1.0
    /// A drift from the promised phase smaller than this is left to the guests' own phase lock.
    public static let tolerance = 0.002

    private var last: JamState?

    public init() {}

    /// Someone joined: the next state goes out whatever it says.
    public mutating func reset() {
        last = nil
    }

    /// `current` when it is due, else nil.
    public mutating func due(_ current: JamState) -> JamState? {
        guard current.isValid else { return nil }
        if let last, Self.stillHolds(last, at: current) { return nil }
        last = current
        return current
    }

    static func stillHolds(_ last: JamState, at current: JamState) -> Bool {
        guard last.isPlaying == current.isPlaying, last.tempo == current.tempo, last.signature == current.signature,
              current.anchorTime >= last.anchorTime, current.anchorTime - last.anchorTime < interval else { return false }
        guard current.isPlaying else { return last.anchorTick == current.anchorTick }
        let timeline = JamTimeline(current)
        let promised = JamTimeline(last).position(atHostTime: current.anchorTime)
        let drift = JamTimeline.phase(current.anchorTick - promised, bar: timeline.barTicks) / timeline.ticksPerSecond
        return Swift.abs(drift) <= tolerance
    }
}

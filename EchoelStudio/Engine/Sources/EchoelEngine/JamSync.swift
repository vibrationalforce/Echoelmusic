import EchoelCore
import Foundation

/// The host's clock as a guest reads it, from pings and NTP's arithmetic: each answer gives the
/// offset between the two clocks (host minus guest) and the round trip it took. No leg of a trip
/// takes less than nothing, so each answer bounds the true offset to its own ± half its round trip;
/// the estimate is the middle of where the newest answers all agree — several measurements, never
/// one, and an answer that waited in a queue only widens its own bound.
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

    /// Host time minus guest time, in seconds; nil before `minimumSamples` answers came back. The
    /// middle of the bounds all kept answers agree on (an intersection, as NTP's), which keeps two
    /// phones' errors small enough not to add up past a few milliseconds; should the bounds not meet —
    /// clocks that drifted apart further than the answers are wide — the median offset of the faster
    /// half.
    public var offset: Double? {
        guard samples.count >= Self.minimumSamples else { return nil }
        let low = samples.map { $0.offset - $0.roundTrip / 2 }.max() ?? -Double.infinity
        let high = samples.map { $0.offset + $0.roundTrip / 2 }.min() ?? Double.infinity
        if low <= high { return (low + high) / 2 }
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
    /// the guest hears it there (`offset`: host minus guest); nil while the host is stopped. Never
    /// before the anchor: a start the host announced ahead (`JamCountIn`) is joined on its own
    /// downbeat, also from more than a bar away — not a bar early.
    public func start(afterLocal now: Double, offset: Double, lead: Double) -> JamStart? {
        guard state.isPlaying, now.isFinite, offset.isFinite, lead.isFinite else { return nil }
        let line = barLine(atOrAfter: Swift.max(position(atHostTime: now + offset + Swift.max(0, lead)), state.anchorTick))
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

    /// The first check after a start, for a guest and for the host alike: inside `PhaseLock.deadband`
    /// nothing; up to `JamFollower.trimLimit` a nudge for the whole error, which cuts no note; beyond
    /// it a relock. `gap`: the ticks the song is behind, folded into one bar.
    static func firstTrim(gap: Double, ticksPerSecond: Double) -> JamCorrection {
        let error = -gap / ticksPerSecond
        guard error.isFinite, Swift.abs(error) > PhaseLock.deadband else { return .none }
        return Swift.abs(error) <= JamFollower.trimLimit ? .nudge(seconds: -error) : .relock(ticks: gap)
    }
}

/// A host's Play while phones are connected (founder 2026-10-31): not at once, but on the next bar
/// line of the jam's grid — the host's clock cut into bars of its tempo and time signature, counted
/// from the clock's zero — at least `lead` ahead, so the word reaches every phone first and everyone
/// comes in on the same downbeat, their bar 1 (Ableton Link starts the same way). The song starts
/// from the start of the bar its playhead stands in. The host announces the start before anyone
/// hears it, and holds itself to that word with the same first trim a guest takes (`correction`).
/// A phone the word reaches too late for that downbeat comes in on the bar line after it.
public struct JamCountIn: Equatable, Sendable {
    /// A quarter second for the word to reach the phones, and then their own `JamFollower.startLead`
    /// to prepare the audio.
    public static let lead = JamFollower.startLead + 0.25

    /// The start as the host announces it: its song from `anchorTick`, heard at `anchorTime` on its clock.
    public let state: JamState

    /// Nil for a tempo outside `Tempo.range`, a signature no song can have, or a time that is not one.
    public init?(playhead: Tick, now: Double, tempo: Double, signature: TimeSignature, lead: Double = JamCountIn.lead) {
        guard now.isFinite, lead.isFinite, tempo.isFinite, Tempo.range.contains(tempo), signature.isValid else { return nil }
        let bar = MusicalTime.ticksPerBar(signature)
        let barSeconds = Double(bar) * 60 / (tempo * Double(MusicalTime.ticksPerQuarter))
        guard bar > 0, barSeconds > 0 else { return nil }
        let time = ((now + Swift.max(0, lead)) / barSeconds).rounded(.up) * barSeconds
        state = JamState(tempo: tempo, signature: signature, isPlaying: true,
                         anchorTick: Double(Swift.max(0, playhead) / bar * bar), anchorTime: time)
    }

    /// The host's first check after its start: what it hears at `time` on its own clock, brought onto
    /// what it announced.
    public func correction(heard: Double, atHostTime time: Double) -> JamCorrection {
        guard heard.isFinite, time.isFinite else { return .none }
        let timeline = JamTimeline(state)
        let gap = JamTimeline.phase(timeline.position(atHostTime: time) - heard, bar: timeline.barTicks)
        return JamCorrection.firstTrim(gap: gap, ticksPerSecond: timeline.ticksPerSecond)
    }
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
            let trim = JamCorrection.firstTrim(gap: gap, ticksPerSecond: timeline.ticksPerSecond)
            if trim != .none { settledAt = now + Self.settle }
            return trim
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

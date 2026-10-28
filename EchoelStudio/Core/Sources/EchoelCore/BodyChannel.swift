import Foundation

/// One body measurement, already normalized to 0 … 1 (pulse, HRV, coherence or breath each own
/// one), and the rules that decide whether it may move anything: wave W1, the G-A contract in
/// `.claude/skills/g-a-body-modulation/references/CONTRACT.md`, whose state vectors
/// `BodyChannelTests` replays.
///
/// A value is there only while it is real: switched on, allowed, not suspended, from the source
/// and run (`epoch`) that is selected, in order, captured no later than now, of enough quality,
/// and no older than `maximumAgeMilliseconds` by its CAPTURE time, not its arrival. Every other
/// case leaves no value — never a stand-in like 72 bpm or 0.5. Each start, stop, permission
/// change, suspension and resume begins a new run, so a callback from an earlier run is ignored.
///
/// Pure: time is the caller's monotonic host clock in milliseconds; nothing here reads a clock,
/// a sensor or the main actor.
public struct BodyChannel: Equatable, Sendable {
    public enum Source: String, Sendable { case camera, ble, health }
    public enum Permission: String, Sendable { case granted, denied, unknown }
    public enum State: String, Sendable { case off, waiting, denied, suspended, valid, invalid, stale }
    /// What became of one event.
    public enum Outcome: String, Sendable {
        case accepted
        /// From another source or an earlier run.
        case ignoredGeneration
        /// The channel cannot take a sample now: off, suspended, denied, or a camera or strap
        /// without granted access.
        case ignoredInactive
        /// A sequence or capture time that does not move forward: a duplicate cannot keep a
        /// frozen sensor alive, and an older capture cannot roll the value back.
        case ignoredOrder
        case invalid
        case stale
    }

    /// One reading from a producer. Optional fields are what a producer may fail to deliver; a
    /// sample with any of them missing is invalid, not a guess.
    public struct Sample: Equatable, Sendable {
        public var source: Source
        public var epoch: UInt64
        public var sequence: Int64?
        public var capturedMilliseconds: Int64?
        public var value: Double?
        public var quality: Double?

        public init(source: Source, epoch: UInt64, sequence: Int64?, capturedMilliseconds: Int64?,
                    value: Double?, quality: Double?) {
            self.source = source
            self.epoch = epoch
            self.sequence = sequence
            self.capturedMilliseconds = capturedMilliseconds
            self.value = value
            self.quality = quality
        }
    }

    public enum Event: Equatable, Sendable {
        case start(Source, Permission)
        case stop
        /// A permission answer, tagged with the source and run that asked for it.
        case permission(Permission, source: Source, epoch: UInt64)
        case suspend
        case resume
        case sample(Sample)
        /// Time passed; a value may have grown stale.
        case tick
    }

    /// What the channel holds after an event.
    public struct Step: Equatable, Sendable {
        public let state: State
        public let epoch: UInt64
        public let value: Double?
        public let outcome: Outcome
    }

    /// The host clock went backwards: a fault in the caller, never a negative age.
    public struct ClockWentBack: Error, Equatable {}

    /// Proposed by the contract, not measured sensor limits: each real producer sets its own.
    public let maximumAgeMilliseconds: Int64
    public let minimumQuality: Double

    public private(set) var state: State = .off
    public private(set) var epoch: UInt64 = 0
    public private(set) var value: Double?
    public private(set) var source: Source?
    private var now: Int64 = 0
    private var enabled = false
    private var permission: Permission = .unknown
    private var suspended = false
    private var captured: Int64?
    private var sequence: Int64 = -1
    private var lastCaptured: Int64 = -1

    public init(maximumAgeMilliseconds: Int64 = 2_000, minimumQuality: Double = 0.7) {
        self.maximumAgeMilliseconds = Swift.max(1, maximumAgeMilliseconds)
        self.minimumQuality = minimumQuality.isFinite ? Swift.min(Swift.max(minimumQuality, 0), 1) : 1
    }

    /// Applies `event` at host time `nowMilliseconds`, which never goes back.
    public mutating func step(_ event: Event, at nowMilliseconds: Int64) throws -> Step {
        guard nowMilliseconds >= now, nowMilliseconds >= 0 else { throw ClockWentBack() }
        now = nowMilliseconds
        var outcome = Outcome.accepted
        switch event {
        case let .start(newSource, newPermission):
            newRun()
            enabled = true
            source = newSource
            permission = newPermission
            // Suspension belongs to the owner: choosing another source does not lift it.
            state = availability
        case let .permission(answer, answeringSource, answeringEpoch):
            if answeringSource != source || answeringEpoch != epoch {
                outcome = .ignoredGeneration
            } else {
                newRun()
                permission = answer
                state = availability
            }
        case .stop:
            newRun()
            enabled = false
            state = availability
        case .suspend, .resume:
            newRun()
            suspended = event == .suspend
            state = availability
        case let .sample(sample):
            outcome = take(sample)
        case .tick:
            break
        }
        if state == .valid, let captured, now - captured > maximumAgeMilliseconds {
            clear(as: .stale)
        }
        return Step(state: state, epoch: epoch, value: value, outcome: outcome)
    }

    private var availability: State {
        if !enabled { return .off }
        if suspended { return .suspended }
        if permission == .denied { return .denied }
        return .waiting
    }

    private mutating func take(_ sample: Sample) -> Outcome {
        // Health read access cannot be read back from the system; fresh data is the evidence.
        guard enabled, !suspended, permission != .denied, permission == .granted || source == .health else {
            return .ignoredInactive
        }
        guard sample.source == source, sample.epoch == epoch else { return .ignoredGeneration }
        guard let number = sample.sequence, let capture = sample.capturedMilliseconds, number >= 0, capture >= 0 else {
            clear(as: .invalid)
            return .invalid
        }
        guard number > sequence, capture > lastCaptured else { return .ignoredOrder }
        guard capture <= now else {
            clear(as: .invalid)
            return .invalid
        }
        sequence = number
        lastCaptured = capture
        guard let reading = sample.value, let quality = sample.quality,
              reading.isFinite, (0...1).contains(reading), quality.isFinite, (0...1).contains(quality),
              quality >= minimumQuality else {
            clear(as: .invalid)
            return .invalid
        }
        guard now - capture <= maximumAgeMilliseconds else {
            clear(as: .stale)
            return .stale
        }
        value = reading
        captured = capture
        state = .valid
        return .accepted
    }

    private mutating func newRun() {
        epoch &+= 1
        sequence = -1
        lastCaptured = -1
        value = nil
        captured = nil
    }

    private mutating func clear(as newState: State) {
        value = nil
        captured = nil
        state = newState
    }
}

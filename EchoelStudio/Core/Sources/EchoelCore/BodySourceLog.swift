import Foundation

/// What a body source did while it was on, as lines for the diagnostics log (`DiagnosticLog`): the
/// musician turned it on, it stopped measuring, it measured again, the musician turned it off (BR-8).
/// The log is a file the musician shares, so a line holds fixed words and durations only: how long
/// the source had measured before a loss, how long it was absent before it measured again. It never
/// holds a value measured from the person (no pulse, no HRV, no breath, no tilt), and this type cannot
/// write one: all it is told is whether the source measures, and when.
///
/// The source's owner keeps one and tells it three things on its own clock: `start`, `measures` (as
/// often as it likes; only a change between measuring and not becomes a line) and `stop`. The first
/// measurement after `start` is no line, because the loss after it says how long the source had
/// measured. `DiagnosticReport` reads the lines back.
///
/// Pure: time is the owner's monotonic clock in milliseconds; nothing here reads a clock or a sensor.
public struct BodySourceLog: Equatable, Sendable {
    /// The four body sources, each with its own words in the log.
    public enum Source: CaseIterable, Sendable {
        /// A Bluetooth chest strap.
        case strap
        /// A fingertip on the rear camera.
        case camera
        /// Apple Health's heart rate.
        case health
        /// The phone's own motion.
        case motion
    }

    /// Why a source stopped measuring, as far as its owner knows.
    public enum Loss: CaseIterable, Sendable {
        /// No reading came in time: a strap without a plausible packet, a camera without a trusted
        /// pulse, Apple Health without a recent reading, the phone without motion samples.
        case noReading
        /// The strap's Bluetooth link ended.
        case disconnected
        /// iOS holds the camera for a while (a call, Control Centre, the background) and gives it back
        /// by itself.
        case interrupted
        /// A video take holds the camera, which films first, and gives it back when the take ends.
        case takeHoldsCamera
        /// The camera stopped and could not be restarted: it waits to be turned off and on again.
        case failed

        /// A pause the app or iOS made on purpose and ends by itself; nothing about the source to fix.
        var isPause: Bool { self == .interrupted || self == .takeHoldsCamera }
    }

    /// One line for the log.
    public struct Line: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            /// The musician turned the source on.
            case started
            /// It stopped measuring after `measuredSeconds` of measuring.
            case lost(Loss, measuredSeconds: Double)
            /// It measures again after `absentSeconds` without.
            case regained(absentSeconds: Double)
            /// The musician turned it off; `measuredSeconds` is the measuring that ended with it, 0
            /// when it was not measuring.
            case stopped(measuredSeconds: Double)
        }

        public let source: Source
        public let kind: Kind
    }

    /// The field a loss and a stop carry: seconds measured.
    static let measuredField: StaticString = "measured_s"
    /// The field a regain carries: seconds absent.
    static let absentField: StaticString = "absent_s"

    public let source: Source
    public private(set) var isOn = false
    /// When the current stretch of measuring began, while there is one.
    private var measuringSince: Int64?
    /// When the source last stopped measuring while on; nil before its first loss and while it measures.
    private var absentSince: Int64?

    public init(_ source: Source) {
        self.source = source
    }

    /// The musician turned the source on; nil when it already was.
    public mutating func start(at nowMilliseconds: Int64) -> Line? {
        guard !isOn else { return nil }
        isOn = true
        measuringSince = nil
        absentSince = nil
        return Line(source: source, kind: .started)
    }

    /// Whether the source measures now. A line only when that changed while the source is on: a loss,
    /// with `loss` as its reason, or a regain; the first measurement after `start` is none.
    public mutating func measures(_ measuring: Bool, at nowMilliseconds: Int64, losing loss: Loss = .noReading) -> Line? {
        guard isOn else { return nil }
        if measuring {
            guard measuringSince == nil else { return nil }
            measuringSince = nowMilliseconds
            guard let since = absentSince else { return nil }
            absentSince = nil
            return Line(source: source, kind: .regained(absentSeconds: Self.seconds(from: since, to: nowMilliseconds)))
        }
        guard let since = measuringSince else { return nil }
        measuringSince = nil
        absentSince = nowMilliseconds
        return Line(source: source, kind: .lost(loss, measuredSeconds: Self.seconds(from: since, to: nowMilliseconds)))
    }

    /// The musician turned the source off; nil when it was not on. Turning off is no loss.
    public mutating func stop(at nowMilliseconds: Int64) -> Line? {
        guard isOn else { return nil }
        let measured = measuringSince.map { Self.seconds(from: $0, to: nowMilliseconds) } ?? 0
        isOn = false
        measuringSince = nil
        absentSince = nil
        return Line(source: source, kind: .stopped(measuredSeconds: measured))
    }

    /// Seconds between two times on the owner's clock, never negative. In `Double`, so no clock value
    /// can overflow the subtraction.
    private static func seconds(from start: Int64, to end: Int64) -> Double {
        Swift.max(0, (Double(end) - Double(start)) / 1_000)
    }
}

// MARK: - The words

extension BodySourceLog.Source {
    /// The event of each line, in the log's own words; `DiagnosticReport` matches the same words.
    var startedEvent: StaticString {
        switch self {
        case .strap: "body: strap started"
        case .camera: "body: camera started"
        case .health: "body: apple health started"
        case .motion: "body: phone motion started"
        }
    }

    var lostEvent: StaticString {
        switch self {
        case .strap: "body: strap lost"
        case .camera: "body: camera lost"
        case .health: "body: apple health lost"
        case .motion: "body: phone motion lost"
        }
    }

    var regainedEvent: StaticString {
        switch self {
        case .strap: "body: strap regained"
        case .camera: "body: camera regained"
        case .health: "body: apple health regained"
        case .motion: "body: phone motion regained"
        }
    }

    var stoppedEvent: StaticString {
        switch self {
        case .strap: "body: strap stopped"
        case .camera: "body: camera stopped"
        case .health: "body: apple health stopped"
        case .motion: "body: phone motion stopped"
        }
    }
}

extension BodySourceLog.Loss {
    /// The reason a loss line gives in parentheses.
    var reason: StaticString {
        switch self {
        case .noReading: "no reading"
        case .disconnected: "disconnected"
        case .interrupted: "paused by iOS"
        case .takeHoldsCamera: "a video take holds the camera"
        case .failed: "failed"
        }
    }
}

extension DiagnosticLog {
    /// Writes a line of a body source's life: its fixed words, and a duration where the line has one.
    @discardableResult
    public func note(_ line: BodySourceLog.Line) -> String {
        switch line.kind {
        case .started:
            note(line.source.startedEvent)
        case let .lost(loss, measured):
            note(line.source.lostEvent, because: loss.reason, [(BodySourceLog.measuredField, measured)])
        case let .regained(absent):
            note(line.source.regainedEvent, [(BodySourceLog.absentField, absent)])
        case let .stopped(measured):
            note(line.source.stoppedEvent, [(BodySourceLog.measuredField, measured)])
        }
    }
}

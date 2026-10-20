/// When the app's audio graph is tried again after a start that failed (ultra-audit R1). A start
/// fails when the session cannot be activated — the app launched or came back during a call, the
/// media services were reset, another app holds the hardware — and a failure that is final until
/// relaunch leaves Play greyed out. So a failure waits a short settle and tries again, a few
/// times, each wait longer; anything that can change the outcome (the app back in the foreground,
/// an interface plugged in or out, an interruption ended, the user asking) starts the count again.
public struct AudioRecoveryPolicy: Equatable, Sendable {
    /// The first wait; the n-th retry waits n times as long.
    public static var settle: Duration { .milliseconds(300) }
    /// Automatic tries after the first failure, before it waits for one of the events above.
    public static var retryLimit: Int { 3 }

    public private(set) var failures = 0

    public init() {}

    /// A start failed. Returns how long to wait before the next automatic try, or nil when the
    /// automatic tries are used up.
    public mutating func failed() -> Duration? {
        failures += 1
        guard failures <= Self.retryLimit else { return nil }
        return Self.settle * failures
    }

    /// The graph started, or something happened that can change the outcome: the count starts
    /// again.
    public mutating func reset() {
        failures = 0
    }
}

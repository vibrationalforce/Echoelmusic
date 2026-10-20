/// Whether the last launch reached a steady state (ultra-audit R4). A launch that dies before it
/// does — a song that traps while it opens, decodes or plays — must not be repeated by reopening
/// that song on every launch: the next launch starts a new song instead, and every song stays in
/// the list. The app keeps `isPending` in its defaults; this type only decides.
public struct LaunchRecord: Equatable, Sendable {
    /// Seconds after the launch began at which it counts as healthy.
    public static var steadySeconds: Double { 10 }
    /// A launch that goes to the background after at least this long counts as healthy too. A
    /// quicker exit cannot be told apart from a crash, and is taken as one.
    public static var leaveFloorSeconds: Double { 3 }

    /// True from the start of a launch until it is confirmed.
    public private(set) var isPending: Bool

    public init(isPending: Bool = false) {
        self.isPending = isPending
    }

    /// Called once per launch, before a song opens. Returns whether the previous launch ended
    /// before it was confirmed.
    public mutating func begin() -> Bool {
        let previousDied = isPending
        isPending = true
        return previousDied
    }

    /// Confirms the running launch `seconds` after it began; `leaving` when the app is going to
    /// the background. Returns whether it confirmed now.
    @discardableResult
    public mutating func confirm(after seconds: Double, leaving: Bool) -> Bool {
        guard isPending, seconds.isFinite else { return false }
        guard seconds >= (leaving ? Self.leaveFloorSeconds : Self.steadySeconds) else { return false }
        isPending = false
        return true
    }
}

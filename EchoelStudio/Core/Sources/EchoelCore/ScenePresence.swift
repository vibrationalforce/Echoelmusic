import Foundation

/// Which of the app's windows are in the foreground, for the light outputs (Q2). On an iPad the
/// studio can stand in two windows at once; the rig belongs to the app, not to a window. So the
/// lights are let go — left dark while the song stands, because the app may be suspended at any
/// moment — only when NO window is in the foreground any more: the last one went to the
/// background or closed. One window closing, going inactive or to the background while another
/// stays in front changes nothing on the rig.
///
/// A value type: each window reports its phase and its leaving; the app does what `isAway` says.
public struct ScenePresence: Equatable, Sendable {
    /// A window's phase, as the system reports it.
    public enum Phase: Equatable, Sendable {
        /// In front and taking touches.
        case active
        /// On screen but not taking touches: a system sheet over it, the app switcher, a window
        /// that just lost the focus to its neighbour. Still in the foreground.
        case inactive
        /// Not on screen.
        case background

        var isForeground: Bool { self != .background }
    }

    private var phases: [UUID: Phase] = [:]

    public init() {}

    /// The window `scene` is now in `phase`; a window not seen before joins.
    public mutating func report(_ phase: Phase, for scene: UUID) {
        phases[scene] = phase
    }

    /// The window `scene` closed; it no longer keeps the app in front.
    public mutating func remove(_ scene: UUID) {
        phases[scene] = nil
    }

    /// The whole app went to the background (the system says so for the app, not per window):
    /// every known window is in the background now. A window torn down without a last report of
    /// its own would otherwise stay in front forever and keep the rig lit.
    public mutating func appEnteredBackground() {
        for scene in phases.keys { phases[scene] = .background }
    }

    /// How many windows are known, in any phase.
    public var count: Int { phases.count }

    /// True when no known window is in the foreground — every one is in the background, or none
    /// is left.
    public var isAway: Bool { Self.isAway(Array(phases.values)) }

    /// The decision on its own: the app is away from the rig exactly when none of `phases` is in
    /// the foreground. No window at all counts as away: nothing on screen holds the app awake.
    public static func isAway(_ phases: [Phase]) -> Bool {
        !phases.contains { $0.isForeground }
    }
}
